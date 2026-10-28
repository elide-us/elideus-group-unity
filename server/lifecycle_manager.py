import asyncio, logging, os, uuid
from fastapi import FastAPI
from pydantic import BaseModel, ValidationError
from typing import NoReturn, Type, TypeVar

from server.helpers import deterministic_guid
from server.kernel import BaseModule, ModuleListing, PackageManifestRow, RELOAD_EXIT_CODE, T
from server.module_manager import ModuleManager
from .kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from .kernel.environment_variables_module import EnvironmentVariablesModule
from .kernel.host_operations_module import HostOperationsModule
from .kernel.kernel_enum_module import KernelEnumModule

logger = logging.getLogger(__name__.split('.')[-1])

# The module listing (every contracts_modules row) and the package manifest:
# both kernel bootstrap operations, cached before seal.
MODULES_READ_ALL = "db:contracts:modules:read_all:1"
MANIFEST_ROWS = "db:contracts:db:list_manifest_rows:1"
# The module_role members that are module files; providers and workers are
# loaded by their executors.
LOADABLE_ROLES = ("MANAGER", "EXECUTOR")

R = TypeVar("R", bound=BaseModel)


# ----------------------------------------------------------------------------
# LifecycleManager
# ----------------------------------------------------------------------------
# The application lifecycle, handled internally: the hosting environment
# hoists the lifespan and runs nothing after yield, so everything the
# application does to start, seal, drain, stop and exit happens here. The
# lifespan constructs this and calls startup() and shutdown(); nothing else.
#
# It orchestrates two owners and calls their APIs:
#   ModuleManager          loads the modules (the gather: every *_module.py
#                          under server/) and starts them; owns the registry.
#   HostOperationsModule   records this instance's state. The lifecycle
#                          writes SEALED, DRAINING and STOPPED at its own
#                          boundaries; STARTING is the host's registration.
#
# -- Phases ------------------------------------------------------------------
#
#   startup():
#     1. discover + start_all     ModuleManager: gather, instantiate, register,
#                                 concurrent startup(). Ordering emerges from
#                                 await_ready() waits inside the modules.
#     2. _check_listing()         The listing is the gate (Aaron 2026-10-21):
#                                 every loaded module must have its
#                                 contracts_modules row, every loadable row
#                                 in a sealed manifest package must be a
#                                 loaded module. A failure is a CRITICAL
#                                 STARTUP ERROR: a RuntimeError the lifespan
#                                 turns into 'Startup refused', a shutdown
#                                 of what started, and exit 1.
#     3. _seal()                  Concurrent on_seal() on all modules, then
#                                 _sealed_event.set(), then the host row goes
#                                 SEALED and the reload watch starts.
#
#   shutdown():
#     1. host DRAINING, _drain_all()   Concurrent on_unseal(): stop taking work.
#     2. host STOPPED, _stop_all()     STOPPED is written before the stop
#                                      phase closes the pool (Aaron 2026-10-20).
#     3. _unseal()                     _sealed_event.clear().
#
# -- Reload ------------------------------------------------------------------
# The host records a RELOADING request on its own row and raises its reload
# event. The lifecycle parks on it, drains and stops everything through
# shutdown(), and ends the process with RELOAD_EXIT_CODE (1 if the shutdown
# failed) for the host runtime to restart it. This is the application's own
# exit, by design.
#
# -- Sealed state ------------------------------------------------------------
# _sealed_event is set at the end of _seal() and cleared in _unseal(). Modules
# read `is_sealed` (sync) or wait on `await_sealed()` (async) through
# app.state.module_manager, which is this object. Not persisted.
#
# -- Design principles -------------------------------------------------------
# Only the contract is called. No references are passed between modules, no
# module knows which depends on which, no ordering is enforced beyond the
# phase boundaries. Two modules that each await the other's await_ready()
# deadlock silently: a code error, the dependency graph must be a DAG.
# ----------------------------------------------------------------------------

class LifecycleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self.modules = ModuleManager(app)
    self._sealed_event: asyncio.Event = asyncio.Event()
    self._host: HostOperationsModule | None = None
    self._host_status = None
    self._reload_watch: asyncio.Task | None = None

  @property
  def is_sealed(self) -> bool:
    return self._sealed_event.is_set()

  async def await_sealed(self):
    await self._sealed_event.wait()

  async def startup(self):
    self.app.state.module_manager = self

    loaded = self.modules.discover()
    await self.modules.start_all(loaded)
    await self._check_listing(loaded)
    await self._seal()

  async def shutdown(self):
    if self._reload_watch is not None and not self._reload_watch.done():
      self._reload_watch.cancel()
    self._reload_watch = None
    await self._set_host_status("DRAINING")
    await self._drain_all()
    await self._set_host_status("STOPPED")
    await self._stop_all()
    self._unseal()

  async def restart(self):
    for module_class in list(self.modules.instances.keys()):
      await self._restart(module_class)
    logger.info("Restart complete")

  async def _restart(self, module_type: Type[T]) -> T:
    instance = self._get_module(module_type)
    await instance.shutdown()
    new_instance = module_type(self.app)
    self.modules.instances[module_type] = new_instance
    await new_instance.startup()
    return new_instance

  # -- Registry (the module manager's; forwarded for app.state.module_manager)

  def _get_module(self, module_type: Type[T]) -> T:
    return self.modules.get(module_type)

  def get_module_by_name(self, name: str) -> BaseModule | None:
    return self.modules.get_by_name(name)

  # -- Startup ---------------------------------------------------------------

  async def _check_listing(self, loaded: list[type]):
    database = self._get_module(DatabaseOperationsModule)
    listings = await self._read_rows(database, MODULES_READ_ALL, ModuleListing)
    manifest = {package.key_guid: package for package in await self._read_rows(database, MANIFEST_ROWS, PackageManifestRow)}

    listed_names = {listing.pub_name for listing in listings}
    for module_class in loaded:
      if module_class.__name__ not in listed_names:
        self._refuse("module %s is not listed in contracts_modules" % module_class.__name__)

    namespace = uuid.UUID(self._get_module(EnvironmentVariablesModule).get("NS_HASH"))
    roles = {deterministic_guid(namespace, "contracts_primitives_enums", "module_role.%s" % role) for role in LOADABLE_ROLES}
    loaded_names = {module_class.__name__ for module_class in loaded}
    for listing in listings:
      if listing.ref_role_enum_guid not in roles or listing.pub_is_abstract:
        continue
      package = manifest.get(listing.ref_package_guid)
      if package is None:
        self._refuse("module %s is listed in package %s, which is not in the package manifest" % (listing.pub_name, listing.ref_package_guid))
      if not package.pub_is_sealed:
        # A half-installed package (register ran, seal did not) must not boot
        # without its modules: DO NOT LOAD means stop the application.
        self._refuse("module %s is listed in package %s, which is not sealed" % (listing.pub_name, package.pub_name))
      if listing.pub_name not in loaded_names:
        self._refuse("module %s (package %s) is listed but was not loaded" % (listing.pub_name, package.pub_name))
    logger.info("listing - %d modules loaded, every one listed, every loadable row loaded", len(loaded))

  async def _read_rows(self, database: DatabaseOperationsModule, op: str, model: Type[R]) -> list[R]:
    raw = await database.query(DBRequest(op))
    if raw is None:
      self._refuse("%s returned nothing: module loading cannot be checked" % op)
    rows: list[R] = []
    for row in raw if isinstance(raw, list) else [raw]:
      try:
        rows.append(model.model_validate(row))
      except ValidationError as e:
        self._refuse("%s returned a row that is not a %s: %s %s" % (op, model.__name__, row, e.errors(include_url=False)))
    return rows

  def _refuse(self, reason: str) -> NoReturn:
    logger.critical("CRITICAL STARTUP ERROR: %s", reason)
    raise RuntimeError(reason)

  async def _seal(self):
    async def _on_seal_module(module: BaseModule):
      await module.on_seal()

    await asyncio.gather(*(
      _on_seal_module(module) for module in self.modules.instances.values()
    ))

    self._sealed_event.set()
    logger.info("seal - sealed")

    self._host = self._get_module(HostOperationsModule)
    self._host_status = self._get_module(KernelEnumModule).get("host_status")
    await self._host.seal()
    self._reload_watch = asyncio.create_task(self._reload_exit())

  # -- Host state ------------------------------------------------------------

  async def _set_host_status(self, member: str):
    # Only once the host came up and sealed; a refused start writes nothing.
    if self._host is None or self._host_status is None:
      return
    await self._host.set_status(getattr(self._host_status, member))

  async def _reload_exit(self):
    # Park on the host's reload event; drain and stop everything through
    # shutdown(), then end the process. RELOAD_EXIT_CODE only when the
    # shutdown completed; anything else exits 1. Its own task, so the worker
    # it stops is not the one awaiting it.
    await self._host.await_reload()
    logger.warning("Host is RELOADING: draining, then exiting for the host runtime to restart it")
    self._reload_watch = None
    code = 1
    try:
      await self.shutdown()
      code = RELOAD_EXIT_CODE
    except Exception as e:
      logger.error("Shutdown before the reload exit failed: %s", e)
    finally:
      os._exit(code)

  # -- Shutdown --------------------------------------------------------------

  async def _drain_all(self):
    async def _unseal_module(module: BaseModule):
      await module.on_unseal()

    await asyncio.gather(*(
      _unseal_module(module) for module in self.modules.instances.values()
    ))
    logger.info("drain_all - %d modules drained", len(self.modules.instances))

  async def _stop_all(self):
    async def _stop_module(module_class: type, module: BaseModule):
      await module.shutdown()
      logger.info("'%s' stopped", module_class.__name__)

    await asyncio.gather(*(
      _stop_module(module_class, module) for module_class, module in self.modules.instances.items()
    ))
    self.modules.instances.clear()
    self._host = None
    self._host_status = None
    logger.info("stop_all successful")

  def _unseal(self):
    self._sealed_event.clear()
    logger.info("unseal - unsealed")
