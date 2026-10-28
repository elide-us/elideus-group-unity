import asyncio
import logging
import os
import socket
import uuid

from fastapi import FastAPI

from . import BaseModule, DATABASE_VERSION, RELOAD_EXIT_CODE
from .database_operations_module import DatabaseOperationsModule
from .environment_variables_module import EnvironmentVariablesModule
from .kernel_configuration_module import KernelConfigurationModule
from server.helpers import discover_classes, deterministic_guid
from .host_execution_providers import BaseKernelHostProvider, BaseKernelHostWorker

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelHostManagementModule
# ----------------------------------------------------------------------------
# Executor (Management) for the Host subsystem: running-instance tracking,
# this process's row in service_hosts. Owns the registry provider and the
# heartbeat worker. Service management is the kernel's domain, so the kernel
# writes its own row through its lifecycle, keyed by a boot GUID generated at
# startup (host name and pid are display only; containers reuse both):
#
#   startup()    STARTING   registered once the database version is confirmed
#   on_seal()    SEALED     with the core manifest version it sealed with;
#                           then the stale sweep
#   on_unseal()  DRAINING   after the worker has stopped, then STOPPED once
#                           this host's own drain is done (Aaron 2026-10-20:
#                           STOPPED at the end of drain; shutdown() is
#                           teardown only, the pool is already closing)
#
# The worker beats on its cadence and reads the row back. The one write any
# other party makes is reload(): RELOADING onto a sealed target row. When the
# worker reads RELOADING on its own row it stops, and the module drains and
# stops the application through the manager and exits the process with
# RELOAD_EXIT_CODE; a failed shutdown exits 1. This is the application's own
# exit, by design: the lifespan ceases to be relevant at yield (the hosting
# environment hoists it into the server infrastructure and never executes
# anything after yield), so every lifecycle action after startup is the
# kernel's to perform (Aaron 2026-10-20). The host runtime restarts the
# process, and the new process registers a fresh row.
#
# Stale sweep: a row whose heartbeat is older than the grace period is a
# process that died without recording STOPPED; on seal it is marked STOPPED.
# The grace period is the stale_grace_seconds configuration row, which the workflow
# queue's stale-claim sweep uses too: one rule.
#
# -- Contract ----------------------------------------------------------------
#   host_key() -> str           [sync] this process's boot GUID, its service_hosts key
#   reload(key_guid) -> None    the target host, live and SEALED, becomes RELOADING
#   observe() -> bool           one worker pass: heartbeat, read the own row; False
#                               once RELOADING has been seen and the exit has begun
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH),
#   KernelConfigurationModule (gates the first write on the version check;
#   host_heartbeat_seconds = the worker cadence, stale_grace_seconds = the sweep)
#   kernel_host_execution_providers/*_provider, *_worker
# ----------------------------------------------------------------------------

PROVIDER = "kernel_host_provider"
WORKER = "kernel_host_worker"
STATUSES = ("STARTING", "SEALED", "DRAINING", "RELOADING", "STOPPED")
# The worker cadence and the stale grace live in system configuration, not in code.
HEARTBEAT_KEY = "host_heartbeat_seconds"
GRACE_KEY = "stale_grace_seconds"


class KernelHostManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._provider: BaseKernelHostProvider | None = None
    self._worker: BaseKernelHostWorker | None = None
    self._status: dict[str, str] = {}
    self._core_guid: str | None = None
    self._key_guid: str | None = None
    self._exit: asyncio.Task | None = None
    self._grace: int = 0

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    # The row is written only into a database at this kernel's version.
    configuration = self.get_module(KernelConfigurationModule)
    await configuration.await_ready()
    namespace = uuid.UUID(env.get("NS_HASH"))
    self._status = {n: deterministic_guid(namespace, "contracts_primitives_enums", "host_status.%s" % n) for n in STATUSES}
    self._core_guid = deterministic_guid(namespace, "service_packages_manifest", "core")
    providers = discover_classes(f"{__package__}.kernel_host_execution_providers", "_provider")
    workers = discover_classes(f"{__package__}.kernel_host_execution_providers", "_worker")
    self._provider = providers[PROVIDER](self._database)
    await self._provider.connect()
    key_guid = str(uuid.uuid4()).upper()
    await self._provider.register(key_guid, self._status["STARTING"], socket.gethostname(), os.getpid(), DATABASE_VERSION)
    self._key_guid = key_guid
    logger.info("Host %s registered (STARTING, kernel %s, pid %d)", key_guid, DATABASE_VERSION, os.getpid())
    self._grace = int(configuration.get(GRACE_KEY))
    self._worker = workers[WORKER](self, int(configuration.get(HEARTBEAT_KEY)))
    await self._worker.start()
    self.raise_ready()

  def host_key(self) -> str:
    # Who is running: the boot GUID this process registered with.
    if self._key_guid is None:
      raise RuntimeError("host is not registered")
    return self._key_guid

  async def reload(self, key_guid: str) -> None:
    # The workflow side's one write. Only a live, sealed host can be asked to
    # reload; any other target affects no row and raises.
    await self._provider.reload(key_guid, self._status["RELOADING"], self._status["SEALED"])
    logger.info("Host %s marked RELOADING", key_guid)

  async def observe(self) -> bool:
    if self._exit is not None:
      return False
    await self._provider.heartbeat(self._key_guid)
    row = await self._provider.read(self._key_guid)
    if row is None:
      raise RuntimeError("host row %s not found" % self._key_guid)
    if row.ref_status_enum_guid != self._status["RELOADING"]:
      return True
    logger.warning("Host %s is RELOADING: draining, then exiting for the host runtime to restart it", self._key_guid)
    self._exit = asyncio.create_task(self._reload_exit())
    return False

  async def _reload_exit(self):
    # The lifespan's two steps on setup mode's SystemExit: drain and stop
    # every module through the manager, then end the process. RELOAD_EXIT_CODE
    # only when the shutdown completed; anything else exits 1. Its own task,
    # so the worker it stops is not the one awaiting it.
    key_guid, code = self._key_guid, 1
    try:
      await self.module_manager.shutdown()
      code = RELOAD_EXIT_CODE
    except Exception as e:
      logger.error("Host %s: shutdown before the reload exit failed: %s", key_guid, e)
    finally:
      os._exit(code)

  async def on_seal(self):
    await self._provider.seal(self._key_guid, self._status["SEALED"], self._core_guid)
    logger.info("Host %s SEALED", self._key_guid)
    released = await self._provider.release_stale(self._status["STOPPED"], self._grace)
    if released:
      logger.warning("Marked %d stale host(s) STOPPED", released)

  async def on_unseal(self):
    if self._worker is not None:
      await self._worker.stop()
    if self._key_guid is not None:
      await self._provider.set_status(self._key_guid, self._status["DRAINING"])
      logger.info("Host %s DRAINING", self._key_guid)
      await self._provider.set_status(self._key_guid, self._status["STOPPED"])
      logger.info("Host %s STOPPED", self._key_guid)

  async def shutdown(self):
    self._worker = None
    if self._provider:
      await self._provider.disconnect()
    self._provider = None
    self._key_guid = None
    self._database = None
