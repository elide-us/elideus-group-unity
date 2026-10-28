import asyncio
import logging
import os
import socket
import uuid

from fastapi import FastAPI

from . import BaseModule, DATABASE_VERSION
from .database_operations_module import DatabaseOperationsModule, DBRequest
from .environment_variables_module import EnvironmentVariablesModule
from .kernel_configuration_module import KernelConfigurationModule
from .kernel_enum_module import KernelEnumModule
from server.helpers import deterministic_guid, host_key, instance_key
from .host_execution_providers import ServiceHost
from .host_execution_providers.aca_transaction_worker import AcaTransactionWorker

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# HostExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Host subsystem. The subsystem's scope is the
# application's instances in the AKS cluster: knowing the containers,
# starting and stopping them, scaling up and out, and the other control-plane
# functions. NONE OF THAT IS WIRED. Today the executor does one thing: it
# registers THIS instance in service_hosts with its host_status value, keeps
# that row honest (heartbeat, stale sweep), and records state changes it is
# told about. The future host governor over the AKS control plane is the
# provider slot in host_execution_providers/.
#
# The host subsystem is NOT part of the module lifecycle. It never gates on
# the seal, never drives a phase, never exits the process. The lifecycle
# manager owns the phases and writes this host's phase state through the
# manager API at its own boundaries: seal() once sealed, set_status() for
# DRAINING and STOPPED. STARTING is the registration itself. A RELOADING
# request is recorded and observed here (the reload event); acting on it is
# the lifecycle manager's.
#
# Identity by formula over NS_HASH, derived by any module from kernel-owned
# facts (server/helpers.py): the HOST (pod or machine) by hostname, this
# INSTANCE (one process on it) by hostname and pid. The registered row is the
# instance's; the host row is its parent (the table split lands in v0.1.8,
# until then the instance key is the service_hosts row key). Statuses are the
# host_status enum as the enum module serves it; the ops take the enum row key
# until v0.1.8 moves them to the enum value.
#
# -- Contract ----------------------------------------------------------------
#   host_key() -> str                 the host this process runs on (pod or machine)
#   instance_key() -> str             this process: its registered row
#   seal() -> None                    SEALED, stamping the core manifest version
#   set_status(status) -> None        a host_status member onto the own row
#   reload(key_guid) -> None          the target host, live and SEALED, becomes RELOADING
#   await_reload() -> None            resolves once the own row has read RELOADING
#   observe() -> bool                 one worker pass: heartbeat, read the own row
#
# -- Phase hooks -------------------------------------------------------------
#   on_seal()     the stale sweep (registry housekeeping), then the worker starts
#   on_unseal()   the worker stops
#   No status is written in any hook.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH),
#   KernelConfigurationModule (gates the first write on the version check;
#   host_heartbeat_seconds = the worker cadence, stale_grace_seconds = the sweep)
#   KernelEnumModule (host_status)
#   host_execution_providers/aca_transaction_worker (the heartbeat loop)
# ----------------------------------------------------------------------------

# The registry operations this executor dispatches (kernel-owned bootstrap rows).
REGISTER = "db:service:host:register:1"
SEAL = "db:service:host:seal:1"
SET_STATUS = "db:service:host:set_status:1"
HEARTBEAT = "db:service:host:heartbeat:1"
READ = "db:service:host:read:1"
RELEASE_STALE = "db:service:host:release_stale:1"
RELOAD = "db:service:host:reload:1"

# The worker cadence and the stale grace live in system configuration, not in code.
HEARTBEAT_KEY = "host_heartbeat_seconds"
GRACE_KEY = "stale_grace_seconds"


class HostExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._worker: AcaTransactionWorker | None = None
    self._namespace: uuid.UUID | None = None
    self._host_status = None
    self._core_guid: str | None = None
    self._host_guid: str | None = None
    self._key_guid: str | None = None
    self._grace: int = 0
    self._reload: asyncio.Event = asyncio.Event()

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    # The row is written only into a database at this kernel's version.
    configuration = self.get_module(KernelConfigurationModule)
    await configuration.await_ready()
    enums = self.get_module(KernelEnumModule)
    await enums.await_ready()
    self._host_status = enums.get("host_status")
    namespace = uuid.UUID(env.get("NS_HASH"))
    self._namespace = namespace
    self._core_guid = deterministic_guid(namespace, "service_packages_manifest", "core")
    self._host_guid = host_key(namespace)
    key_guid = instance_key(namespace)
    # Parameter order is the operation's input model order.
    await self._one(REGISTER, {
      "key_guid": key_guid,
      "ref_status_enum_guid": self._status(self._host_status.STARTING),
      "pub_host_name": socket.gethostname(),
      "pub_pid": os.getpid(),
      "pub_kernel_version": DATABASE_VERSION,
    })
    self._key_guid = key_guid
    logger.info("Host %s registered (STARTING, kernel %s, pid %d)", key_guid, DATABASE_VERSION, os.getpid())
    self._grace = int(configuration.get(GRACE_KEY))
    self._worker = AcaTransactionWorker(self, int(configuration.get(HEARTBEAT_KEY)))
    self.raise_ready()

  def host_key(self) -> str:
    # Where this process runs: the host row's key.
    if self._host_guid is None:
      raise RuntimeError("host is not registered")
    return self._host_guid

  def instance_key(self) -> str:
    # Who is running: this process's registered row.
    if self._key_guid is None:
      raise RuntimeError("host is not registered")
    return self._key_guid

  async def seal(self) -> None:
    await self._one(SEAL, {
      "ref_status_enum_guid": self._status(self._host_status.SEALED),
      "ref_core_package_guid": self._core_guid,
      "key_guid": self.instance_key(),
    })
    logger.info("Host %s SEALED", self._key_guid)

  async def set_status(self, status) -> None:
    await self._one(SET_STATUS, {"ref_status_enum_guid": self._status(status), "key_guid": self.instance_key()})
    logger.info("Host %s %s", self._key_guid, status.name)

  async def reload(self, key_guid: str) -> None:
    # The workflow side's one write. Only a live, sealed host can be asked to
    # reload; any other target affects no row and raises.
    await self._one(RELOAD, {
      "ref_status_enum_guid": self._status(self._host_status.RELOADING),
      "key_guid": key_guid,
      "ref_sealed_enum_guid": self._status(self._host_status.SEALED),
    })
    logger.info("Host %s marked RELOADING", key_guid)

  async def await_reload(self) -> None:
    await self._reload.wait()

  async def observe(self) -> bool:
    await self._one(HEARTBEAT, {"key_guid": self.instance_key()})
    raw = await self._database.query(DBRequest(READ, {"key_guid": self._key_guid}))
    row = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    if row is None:
      raise RuntimeError("host row %s not found" % self._key_guid)
    host = ServiceHost.model_validate(row)
    if host.ref_status_enum_guid == self._status(self._host_status.RELOADING) and not self._reload.is_set():
      logger.warning("Host %s is RELOADING", self._key_guid)
      self._reload.set()
    return True

  def _status(self, status) -> str:
    # The enum row key the ops take until v0.1.8 moves them to the value.
    return deterministic_guid(self._namespace, "contracts_primitives_enums", "host_status.%s" % status.name)

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))

  async def on_seal(self):
    affected = await self._database.execute(DBRequest(RELEASE_STALE, {
      "ref_status_enum_guid": self._status(self._host_status.STOPPED),
      "ref_stopped_enum_guid": self._status(self._host_status.STOPPED),
      "pub_grace_seconds": self._grace,
    }))
    if affected is None or affected < 0:
      raise RuntimeError("%s did not run" % RELEASE_STALE)
    if affected:
      logger.warning("Marked %d stale host(s) STOPPED", affected)
    await self._worker.start()

  async def on_unseal(self):
    if self._worker is not None:
      await self._worker.stop()

  async def shutdown(self):
    self._worker = None
    self._host_guid = None
    self._key_guid = None
    self._database = None
