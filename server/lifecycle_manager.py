import asyncio, logging, os, uuid
from collections import Counter
from fastapi import FastAPI
from pydantic import BaseModel, ValidationError
from typing import NoReturn, Type, TypeVar

from server.helpers import deterministic_guid
from server.kernel import BaseModule, ModuleDependencyRow, ModuleListing, PackageManifestRow, RELOAD_EXIT_CODE, SecurityContext, T, kernel_context
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
# The declared module dependencies, by name (a kernel bootstrap operation).
DEPENDENCIES_READ = "db:contracts:modules:read_dependencies:1"
# The module_role members that are module files; providers and workers are
# loaded by their executors, SERVICE rows (the two kernel services) are
# never loaded.
LOADABLE_ROLES = ("MANAGER", "EXECUTOR", "PRIMITIVE")
# The module_role members another component may depend on (one way in).
CROSS_COMPONENT_ROLES = ("MANAGER", "PRIMITIVE")
# The module_dependency_kind members: INHERITS is a base class (a contract,
# not a get_module call); EXTENDS is the declared privileged composition.
DEPENDENCY_KINDS = ("REQUIRES", "INHERITS", "EXTENDS")

R = TypeVar("R", bound=BaseModel)


# ----------------------------------------------------------------------------
# LifecycleManager
# ----------------------------------------------------------------------------
# RESPONSIBILITY: the status of the application. That is it. Code that is
# not that does not belong here; if it lands here it is called out below.
#
# The application lifecycle, handled internally: the hosting environment
# hoists the lifespan and runs nothing after yield, so everything the
# application does to start, seal, drain, stop and exit happens here. The
# lifespan constructs this and calls startup() and shutdown(); nothing else.
#
# It orchestrates two owners and calls their APIs:
#   ModuleManager          loads the modules (the gather: every *_module.py
#                          under server/), starts and stops them; owns the registry.
#   HostOperationsModule   records this instance's state. The lifecycle
#                          writes SEALED, DRAINING and STOPPED at its own
#                          boundaries; STARTING is the host's registration.
#
# Its own database work (the listing reads, the host state writes) runs under
# the kernel context, derived once the modules have started
# (kernel_context(NS_HASH, hostname)); nothing passes it in.
#
# -- Phases ------------------------------------------------------------------
#
#   startup():
#     1. discover + start_all     ModuleManager: gather, instantiate, register,
#                                 concurrent startup(). Ordering emerges from
#                                 await_ready() waits inside the modules.
#     2. _check_listing()         The listing is the gate (Aaron 2026-10-21):
#                                 every loaded module and both kernel
#                                 services must have their
#                                 contracts_modules row, every loadable row
#                                 (MANAGER, EXECUTOR, PRIMITIVE) in a sealed
#                                 manifest package must be a loaded module.
#                                 Then the boot gate (below). The boot line
#                                 reports the loaded and the checked counts
#                                 by role and the dependency pairs checked.
#                                 A failure is a CRITICAL STARTUP ERROR: a
#                                 RuntimeError the lifespan turns into
#                                 'Startup refused', a shutdown of what
#                                 started, and exit 1.
#     3. _seal()                  Concurrent on_seal() on all modules, then
#                                 _sealed_event.set(), then the host row goes
#                                 SEALED and the reload watch starts.
#
#   shutdown():
#     1. host DRAINING, _drain_all()   Concurrent on_unseal(): stop taking work.
#     2. host STOPPED, modules.stop_all()   STOPPED is written before the stop
#                                      phase closes the pool (Aaron 2026-10-20).
#     3. _unseal()                     _sealed_event.clear().
#
# -- Boot gate (an observer) -------------------------------------------------
# BaseModule.get_module notes every (caller class, target class) pair here
# through note_dependency() and returns what it always returned. The set is
# the lifecycle's; the module manager knows no dependencies. Noting changes
# no ordering, passes no reference and refuses nothing: the gate cannot
# refuse at call time, because the rows it compares against are unreadable
# until the Database modules are up. It refuses after start_all, inside the
# listing gate, under the kernel context, reading
# db:contracts:modules:read_dependencies:1 (an unreadable or empty read
# refuses). The boot is refused for:
#   a. a noted pair with no declared row (an INHERITS row does not declare a
#      get_module call);
#   b. a noted pair with no EXTENDS row whose two modules sit in different
#      components (ref_component_guid of the listing) and whose target's
#      role is not MANAGER or PRIMITIVE;
#   c. a row whose source is a loaded module, whose kind is not INHERITS,
#      and which was never noted.
# Whitelisted: a module on either side of a noted pair with no listing row,
# a listing without a role or a component, a row of an unknown kind, or any
# exception while checking, is a refusal. Each refusal names the pair. The
# gate names no module: it compares the observed graph with the rows.
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
# app.state.lifecycle_manager, which is this object. The registry is the
# module manager's, app.state.module_manager. Not persisted.
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
    self._kernel: SecurityContext | None = None
    self._noted: set[tuple[str, str]] = set()
    self._reload_watch: asyncio.Task | None = None

  @property
  def is_sealed(self) -> bool:
    return self._sealed_event.is_set()

  def note_dependency(self, module: str, dependency: str) -> None:
    # The boot gate's observation: one get_module call, by class name.
    self._noted.add((module, dependency))

  async def await_sealed(self):
    await self._sealed_event.wait()

  async def startup(self):
    self.app.state.module_manager = self.modules
    self.app.state.lifecycle_manager = self

    loaded = self.modules.discover()
    await self.modules.start_all(loaded)
    env = self.modules.get(EnvironmentVariablesModule)
    self._kernel = kernel_context(uuid.UUID(env.get("NS_HASH")), env.get_hostname())
    await self._check_listing(loaded)
    await self._seal()

  async def shutdown(self):
    if self._reload_watch is not None and not self._reload_watch.done():
      self._reload_watch.cancel()
    self._reload_watch = None
    await self._set_host_status("DRAINING")
    await self._drain_all()
    await self._set_host_status("STOPPED")
    await self.modules.stop_all()
    self._host = None
    self._host_status = None
    self._kernel = None
    self._noted.clear()
    self._unseal()

  # -- Restart (application status; the orchestration is not complete) ------
  # restart() is the lifecycle's: it orchestrates the restart of the
  # application, which is the shutdown and restart of the modules AND of the
  # hosts. What it should do, in order: write the host status for the
  # restart, drain (on_unseal) and unseal, unload the modules through the
  # module manager, reload and start them again, re-check the listing, seal,
  # and bring the host row back to SEALED. Today it only cycles each loaded
  # module in place (shutdown, new instance, startup) and touches neither
  # the phases nor the host; the host interface it needs is not built yet,
  # so the host side is left out on purpose (Aaron 2026-10-28). Not called.
  async def restart(self):
    for module_class in list(self.modules.instances.keys()):
      await self._restart(module_class)
    logger.info("Restart complete")

  async def _restart(self, module_type: Type[T]) -> T:
    instance = self.modules.get(module_type)
    await instance.shutdown()
    new_instance = module_type(self.app)
    self.modules.instances[module_type] = new_instance
    await new_instance.startup()
    return new_instance

  # -- Startup ---------------------------------------------------------------

  async def _check_listing(self, loaded: list[type]):
    database = self.modules.get(DatabaseOperationsModule)
    listings = await self._read_rows(database, MODULES_READ_ALL, ModuleListing)
    manifest = {package.key_guid: package for package in await self._read_rows(database, MANIFEST_ROWS, PackageManifestRow)}

    listed_names = {listing.pub_name for listing in listings}
    for module_class in loaded:
      if module_class.__name__ not in listed_names:
        self._refuse("module %s is not listed in contracts_modules" % module_class.__name__)
    # The two kernel services are listed (role SERVICE) and never loaded; the
    # listing is the gate for them as it is for the modules.
    for service in (type(self), type(self.modules)):
      if service.__name__ not in listed_names:
        self._refuse("service %s is not listed in contracts_modules" % service.__name__)

    namespace = uuid.UUID(self.modules.get(EnvironmentVariablesModule).get("NS_HASH"))
    roles = {deterministic_guid(namespace, "contracts_primitives_enums", "module_role.%s" % role): role for role in LOADABLE_ROLES}
    loaded_names = {module_class.__name__ for module_class in loaded}
    role_of = {listing.pub_name: roles.get(listing.ref_role_enum_guid, "OTHER") for listing in listings}
    loaded_by_role = Counter(role_of[name] for name in loaded_names)
    checked_by_role: Counter = Counter()
    for listing in listings:
      if listing.ref_role_enum_guid not in roles or listing.pub_is_abstract:
        continue
      checked_by_role[roles[listing.ref_role_enum_guid]] += 1
      package = manifest.get(listing.ref_package_guid)
      if package is None:
        self._refuse("module %s is listed in package %s, which is not in the package manifest" % (listing.pub_name, listing.ref_package_guid))
      if not package.pub_is_sealed:
        # A half-installed package (register ran, seal did not) must not boot
        # without its modules: DO NOT LOAD means stop the application.
        self._refuse("module %s is listed in package %s, which is not sealed" % (listing.pub_name, package.pub_name))
      if listing.pub_name not in loaded_names:
        self._refuse("module %s (package %s) is listed but was not loaded" % (listing.pub_name, package.pub_name))
    pairs = await self._check_dependencies(database, listings, loaded_names, namespace)
    logger.info("listing - %d modules loaded (%s), every one listed; %d loadable rows checked (%s), every one loaded; %d dependency pairs checked, every one declared and every declared row observed",
                len(loaded), self._by_role(loaded_by_role), sum(checked_by_role.values()), self._by_role(checked_by_role), pairs)

  async def _check_dependencies(self, database: DatabaseOperationsModule, listings: list[ModuleListing], loaded_names: set[str], namespace: uuid.UUID) -> int:
    # The boot gate: the noted get_module pairs against the declared rows.
    # Returns the number of noted pairs checked.
    rows = await self._read_rows(database, DEPENDENCIES_READ, ModuleDependencyRow)
    if not rows:
      self._refuse("%s returned no rows: the module graph cannot be checked" % DEPENDENCIES_READ)
    noted = set(self._noted)
    try:
      by_name = {listing.pub_name: listing for listing in listings}
      open_roles = {deterministic_guid(namespace, "contracts_primitives_enums", "module_role.%s" % role) for role in CROSS_COMPONENT_ROLES}
      declared: dict[tuple[str, str], set[str]] = {}
      for row in rows:
        if row.pub_kind not in DEPENDENCY_KINDS:
          self._refuse("dependency %s -> %s has an unknown kind %s" % (row.pub_module, row.pub_dependency, row.pub_kind))
        declared.setdefault((row.pub_module, row.pub_dependency), set()).add(row.pub_kind)

      for module, dependency in sorted(noted):
        source, target = by_name.get(module), by_name.get(dependency)
        if source is None or target is None:
          self._refuse("dependency %s -> %s was noted, but %s has no contracts_modules row" % (module, dependency, module if source is None else dependency))
        for listing in (source, target):
          if listing.ref_role_enum_guid is None or listing.ref_component_guid is None:
            self._refuse("dependency %s -> %s was noted, but %s has no role or no component" % (module, dependency, listing.pub_name))
        kinds = declared.get((module, dependency), set()) - {"INHERITS"}
        if not kinds:
          self._refuse("dependency %s -> %s was noted at startup and has no row in contracts_modules_dependencies" % (module, dependency))
        if "EXTENDS" not in kinds and source.ref_component_guid != target.ref_component_guid and target.ref_role_enum_guid not in open_roles:
          self._refuse("dependency %s -> %s crosses components to a module whose role is not %s" % (module, dependency, " or ".join(CROSS_COMPONENT_ROLES)))

      for (module, dependency), kinds in sorted(declared.items()):
        if module in loaded_names and kinds - {"INHERITS"} and (module, dependency) not in noted:
          self._refuse("dependency %s -> %s is declared (%s) and was never noted at startup" % (module, dependency, ", ".join(sorted(kinds - {"INHERITS"}))))
    except RuntimeError:
      raise
    except Exception as e:
      self._refuse("the dependency check failed: %s" % e)
    return len(noted)

  def _by_role(self, counts: Counter) -> str:
    names = list(LOADABLE_ROLES) + sorted(set(counts) - set(LOADABLE_ROLES))
    return ", ".join("%s %d" % (name, counts[name]) for name in names if counts[name] or name in LOADABLE_ROLES)

  async def _read_rows(self, database: DatabaseOperationsModule, op: str, model: Type[R]) -> list[R]:
    raw = await database.query(DBRequest(op, {}, self._kernel))
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

    self._host = self.modules.get(HostOperationsModule)
    self._host_status = self.modules.get(KernelEnumModule).get("host_status")
    await self._host.seal(self._kernel)
    self._reload_watch = asyncio.create_task(self._reload_exit())

  # -- Host state ------------------------------------------------------------

  async def _set_host_status(self, member: str):
    # Only once the host came up and sealed; a refused start writes nothing.
    if self._host is None or self._host_status is None:
      return
    await self._host.set_status(self._kernel, getattr(self._host_status, member))

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

  def _unseal(self):
    self._sealed_event.clear()
    logger.info("unseal - unsealed")
