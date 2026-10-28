import asyncio, importlib, inspect, logging, uuid
from abc import ABC, abstractmethod
from fastapi import FastAPI
from pydantic import BaseModel, ValidationError
from typing import Dict, NoReturn, Type, TypeVar

from server.helpers import discover_classes, deterministic_guid, pascal_to_snake
from server.kernel import BaseModule, ModuleListing, PackageManifestRow, T
from .kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from .kernel.environment_variables_module import EnvironmentVariablesModule

logger = logging.getLogger(__name__.split('.')[-1])

# The module listing (every contracts_modules row) and the package manifest:
# both kernel bootstrap operations, cached before seal.
MODULES_READ_ALL = "db:contracts:modules:read_all:1"
MANIFEST_ROWS = "db:contracts:db:list_manifest_rows:1"
# The module_role members that are module files; providers and workers are
# loaded by their executors.
LOADABLE_ROLES = ("MANAGER", "EXECUTOR")
KERNEL_PACKAGE = "kernel"

R = TypeVar("R", bound=BaseModel)


# ----------------------------------------------------------------------------
# KernelModuleManager
# ----------------------------------------------------------------------------
# Module lifecycle manager. Discovers, instantiates, and
# manages the startup/shutdown lifecycle of all modules. Independent of
# the application lifecycle (lifespan) — the lifespan calls into the
# manager, not the other way around.
#
# -- Lifecycle phases --------------------------------------------------------
#
#   startup():
#     Phase 1: _discover()             Sync. The kernel bootstrap: discover
#              server/kernel/*_module.py from its folder, import,
#              instantiate, register by class type. No async work.
#              _start_all(kernel)      Async. Concurrent startup() on the
#              kernel modules; they open the database the listing needs.
#
#     Phase 2: _discover_listed()      Async. Read the module listing (the
#              contracts_modules rows) and the package manifest through
#              DatabaseOperationsModule, each row validated into its model.
#              Gate the kernel (every phase-1 class must be listed, every
#              loadable kernel row must be a phase-1 class), then resolve
#              every loadable listed module, then register them all.
#              _start_all(listed)      Async. Concurrent startup() on the
#              listed modules: the same multi-fire init. Ordering emerges
#              from await_ready() waits, on kernel modules already ready
#              and on each other.
#
#     Phase 3: _seal()                 Async. Concurrent on_seal() on all
#              modules. Post-init work (reconciliation, finalization).
#              After all on_seal() calls complete: _sealed_event.set().
#
#   shutdown():
#     Phase 1: _drain_all()            Async. Concurrent on_unseal() on all
#              modules. Pre-shutdown signal — stop accepting work.
#
#     Phase 2: _stop_all()             Async. Concurrent shutdown() on all
#              modules. Clear caches, close pools, null references.
#              Clears the instance registry.
#
#     Phase 3: _unseal()               Sync. _sealed_event.clear(). Manager
#              cleanup after all modules are down.
#
# -- Design principles -------------------------------------------------------
#
# The module manager only calls the contract. It does not:
#   - Pass references between modules
#   - Know which module depends on which
#   - Enforce ordering beyond the phase boundaries
#
# Modules are self-sufficient. They use get_module() to find each other
# and await_ready() to sequence themselves. The manager's job ends at
# invoking the five contract methods at the right phase.
#
# -- The listing is the gate (Aaron 2026-10-21) ------------------------------
# A module loads only if it has a row in etg.contracts_modules. The table is
# scanned, not the folder. The kernel loads first from its own folder
# because it opens the database the scan needs; once the listing is read,
# a kernel module without a row is the same critical error.
#
# Loadable rows: role MANAGER or EXECUTOR (keys by formula from NS_HASH),
# not abstract. A loadable row in the kernel package must name a phase-1
# class (already loaded); one in a SEALED package is resolved below; one in
# an unsealed package (a half-finished install) is a CRITICAL STARTUP ERROR.
# Order: package name, then module name.
#
# Resolution, per loadable row:
#   1. _load_from_table()   the promotion hook: a module promoted into the
#                           database loads from its stored form. Today it
#                           always returns None (no stored-source column).
#   2. _load_from_file()    the file bridge: server/<package>/
#                           <pascal_to_snake(pub_name)>.py, class pub_name,
#                           a concrete BaseModule. Anything else, or a file
#                           that raises on import, returns None.
#   3. neither              CRITICAL STARTUP ERROR.
#
# Every refusal goes through _refuse(): one CRITICAL STARTUP ERROR line and
# a RuntimeError, which the lifespan turns into 'Startup refused', a
# shutdown of the kernel modules that started, and exit 1. The refusals: a
# listing or manifest query that returns nothing or a row its model
# rejects; an unlisted kernel module; a loadable kernel row with no kernel
# class; a loadable row whose package is not in the manifest; a listed
# module that cannot be loaded. Every listed module is resolved before any
# is registered, so a refused start drains only the kernel modules.
#
# -- Sealed state ------------------------------------------------------------
# _sealed_event is an asyncio.Event, unset by default. Set at the end
# of _seal(). Cleared at the end of
# _unseal(). Modules check via the public `is_sealed`
# property (sync) or wait via `await_sealed()` (async). Not persisted —
# full shutdown/startup clears and re-raises it.
#
# -- Circular dependency guard -----------------------------------------------
# No runtime detection. Two modules that each await the other's
# await_ready() will deadlock silently. This is a code error. The
# dependency graph must be a DAG.
#
# ----------------------------------------------------------------------------

class LifecycleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self._instances: Dict[type, BaseModule] = {}
    self._sealed_event: asyncio.Event = asyncio.Event()

  @property
  def is_sealed(self) -> bool:
    return self._sealed_event.is_set()

  async def await_sealed(self):
    await self._sealed_event.wait()

  async def startup(self):
    self.app.state.module_manager = self

    kernel = self._discover()
    await self._start_all(kernel)
    listed = await self._discover_listed(kernel)
    await self._start_all(listed)
    await self._seal()

  async def shutdown(self):
    await self._drain_all()
    await self._stop_all()
    self._unseal()

  async def restart(self):
    for module_class in self._instances.keys():
      await self._restart(module_class)
    logger.info("Restart complete")

  async def _restart(self, module_type: Type[T]) -> T:
    instance = self._get_module(module_type)
    await instance.shutdown()
    new_instance = module_type(self.app)
    self._instances[module_type] = new_instance
    await new_instance.startup()
    return new_instance

  def _get_module(self, module_type: Type[T]) -> T:
    instance = self._instances.get(module_type)
    if instance is None:
      logger.error("'%s' not registered", module_type.__name__)
      return None
    return instance

  def get_module_by_name(self, name: str) -> BaseModule | None:
    # A contract names a module by its class name (a workflow step, later an
    # RPC contract row); the registry answers by name as it does by type.
    for module_class, instance in self._instances.items():
      if module_class.__name__ == name:
        return instance
    logger.error("'%s' not registered", name)
    return None

  # -- Startup ---------------------------------------------------------------

  def _discover(self) -> list[type]:
    kernel = list(discover_classes(__package__, "_module").values())
    for module_class in kernel:
      self._instances[module_class] = module_class(self.app)
    return kernel

  async def _discover_listed(self, kernel: list[type]) -> list[type]:
    database = self._get_module(DatabaseOperationsModule)
    listings = await self._read_rows(database, MODULES_READ_ALL, ModuleListing)
    manifest = {package.key_guid: package for package in await self._read_rows(database, MANIFEST_ROWS, PackageManifestRow)}

    listed_names = {listing.pub_name for listing in listings}
    for module_class in kernel:
      if module_class.__name__ not in listed_names:
        self._refuse("kernel module %s is not listed in contracts_modules" % module_class.__name__)

    namespace = uuid.UUID(self._get_module(EnvironmentVariablesModule).get("NS_HASH"))
    roles = {deterministic_guid(namespace, "contracts_primitives_enums", "module_role.%s" % role) for role in LOADABLE_ROLES}
    kernel_names = {module_class.__name__ for module_class in kernel}
    loadable: list[tuple[str, ModuleListing]] = []
    for listing in listings:
      if listing.ref_role_enum_guid not in roles or listing.pub_is_abstract:
        continue
      package = manifest.get(listing.ref_package_guid)
      if package is None:
        self._refuse("module %s is listed in package %s, which is not in the package manifest" % (listing.pub_name, listing.ref_package_guid))
      if package.pub_name == KERNEL_PACKAGE:
        if listing.pub_name not in kernel_names:
          self._refuse("module %s (package %s) is listed but cannot be loaded from the table or from disk" % (listing.pub_name, KERNEL_PACKAGE))
        continue
      if not package.pub_is_sealed:
        # A half-installed package (register ran, seal did not) must not boot
        # without its modules: DO NOT LOAD means stop the application.
        self._refuse("module %s is listed in package %s, which is not sealed" % (listing.pub_name, package.pub_name))
      loadable.append((package.pub_name, listing))
    loadable.sort(key=lambda entry: (entry[0], entry[1].pub_name))

    resolved: list[type] = []
    from_table = 0
    for package, listing in loadable:
      module_class = self._load_from_table(listing)
      if module_class is not None:
        from_table += 1
      else:
        module_class = self._load_from_file(listing, package)
      if module_class is None:
        self._refuse("module %s (package %s) is listed but cannot be loaded from the table or from disk" % (listing.pub_name, package))
      resolved.append(module_class)

    for module_class in resolved:
      self._instances[module_class] = module_class(self.app)
    logger.info("discover - %d kernel modules from disk, %d listed modules loaded (%d from table, %d from file)",
                len(kernel), len(resolved), from_table, len(resolved) - from_table)
    return resolved

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

  def _load_from_table(self, listing: ModuleListing) -> type | None:
    """The promotion hook: contracts_modules has no stored-source column yet, so nothing loads from the table."""
    return None

  def _load_from_file(self, listing: ModuleListing, package: str) -> type | None:
    path = "server.%s.%s" % (package, pascal_to_snake(listing.pub_name))
    try:
      found = getattr(importlib.import_module(path), listing.pub_name)
    except (ImportError, AttributeError) as e:
      logger.error("'%s' cannot be loaded from %s: %s", listing.pub_name, path, e)
      return None
    except Exception:
      logger.exception("'%s' raised while importing %s", listing.pub_name, path)
      return None
    if not (isinstance(found, type) and issubclass(found, BaseModule) and not inspect.isabstract(found)):
      logger.error("'%s' in %s is not a concrete BaseModule", listing.pub_name, path)
      return None
    return found

  async def _start_all(self, module_classes: list[type]):
    async def _start_module(module_class: type, module: BaseModule):
      await module.startup()
      logger.info("'%s' started", module_class.__name__)

    await asyncio.gather(*(
      _start_module(module_class, self._instances[module_class]) for module_class in module_classes
    ))
    logger.info("start_all successful")

  async def _seal(self):
    async def _on_seal_module(module: BaseModule):
      await module.on_seal()

    await asyncio.gather(*(
      _on_seal_module(module) for module in self._instances.values()
    ))

    self._sealed_event.set()
    logger.info("seal - sealed")

  # -- Shutdown --------------------------------------------------------------

  async def _drain_all(self):
    async def _unseal_module(module: BaseModule):
      await module.on_unseal()

    await asyncio.gather(*(
      _unseal_module(module) for module in self._instances.values()
    ))
    logger.info("drain_all - %d modules drained", len(self._instances))

  async def _stop_all(self):
    async def _stop_module(module_class: type, module: BaseModule):
      await module.shutdown()
      logger.info("'%s' stopped", module_class.__name__)

    await asyncio.gather(*(
      _stop_module(module_class, module) for module_class, module in self._instances.items()
    ))
    self._instances.clear()
    logger.info("stop_all successful")

  def _unseal(self):
    self._sealed_event.clear()
    logger.info("unseal - unsealed")
