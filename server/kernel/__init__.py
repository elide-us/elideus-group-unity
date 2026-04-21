from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, TypeVar, Type
import asyncio, logging, os, importlib

from server.helpers import snake_to_pascal

logger = logging.getLogger(__name__.split('.')[-1])

MODULES_FOLDER = os.path.dirname(__file__)

T = TypeVar("T", bound="BaseModule")


# ----------------------------------------------------------------------------
# BaseWorker
# ----------------------------------------------------------------------------
# Minimal abstract interface for long-running worker classes. A Worker is
# instantiated and owned by a module; it is not autodiscovered. The Worker
# role-name occupies the Provider slot in the Manager/Executor/Provider
# taxonomy (see docs/kernel_architecture.md §3) for subsystems that perform
# dispatched work rather than mediating an external resource.
#
#   start()   Begin the worker's work loop as a background task.
#   stop()    Signal the loop to stop and await its completion.
# ----------------------------------------------------------------------------

class BaseWorker(ABC):
  @abstractmethod
  async def start(self) -> None:
    pass

  @abstractmethod
  async def stop(self) -> None:
    pass


# ----------------------------------------------------------------------------
# BaseModule
# ----------------------------------------------------------------------------
# Abstract base for all modules. Every module file matching
# *_module.py is autodiscovered, instantiated, and registered by the
# ModuleManager during _on_startup_init().
#
# -- Lifecycle contract ------------------------------------------------------
#
#   __init__(app)   Synchronous. Initialize empty caches, null references.
#                   No async work. No dependency resolution. Called during
#                   ModuleManager._on_startup_init() (Phase 1).
#
#   startup()       Async. Resolve dependencies via get_module() + on_sealed().
#                   Load data, open resources, raise_seal(). Called during
#                   ModuleManager._on_startup_all() (Phase 2). All modules
#                   run concurrently via asyncio.gather; ordering emerges
#                   from on_sealed() waits, not dispatch order.
#
#   on_seal()       Async. Post-init work. All modules are live and ready.
#                   Called during ModuleManager._on_startup_complete()
#                   (Phase 3). Runs concurrently across all modules. After
#                   all on_seal() calls complete, the manager's _sealed_event
#                   is raised. Use this for reconciliation, finalization,
#                   or any work that requires the full module graph to be
#                   initialized.
#
#   on_drain()      Async. Pre-shutdown signal. Stop accepting new work,
#                   flush in-flight operations, release external holds.
#                   Called during ModuleManager._on_shutdown_init().
#                   Runs concurrently across all modules.
#
#   shutdown()      Async. Teardown. Clear caches, close resources, null
#                   references. Called during ModuleManager._on_shutdown_all().
#
# -- Dependency resolution ---------------------------------------------------
#
#   get_module(T)   Returns the registered instance of module type T.
#                   Call during startup() to get references to other modules.
#
#   on_sealed()     Awaits until the target module has called raise_seal().
#                   Use after get_module() to ensure the dependency is
#                   initialized before using it.
#
#   raise_seal()    Signals that this module is initialized and safe for
#                   dependents to call into. Call at the end of startup()
#                   after all resources are live.
#
# -- Dependency graph --------------------------------------------------------
# All modules start concurrently. Ordering is implicit: a module that
# calls `await dep.on_sealed()` in its startup() will park until the
# dependency signals. This forms a dynamic DAG at runtime. The only
# constraint is no circular dependencies — two modules that each await
# the other's on_sealed() will deadlock.
#
# Modules get their own references. The ModuleManager does not
# orchestrate composition, pass references, or know which module
# depends on which. It only calls the contract methods.
#
# -- Sealed state ------------------------------------------------------------
# "Sealed" has two distinct scopes:
#
#   Module-sealed   This module has finished startup() and its contract
#                   is safe to call. Set by raise_seal(); observed by
#                   dependents via `await dep.on_sealed()`. Backed by
#                   this module's own _sealed_event.
#
#   Manager-sealed  All modules have completed on_seal() and the full
#                   application graph is initialized. Set by the
#                   ModuleManager at the end of _on_startup_complete();
#                   observed via `manager.is_sealed` (sync read) or
#                   `await manager.on_sealed()` (async wait). Backed by
#                   the manager's _sealed_event.
#
# Both events are in-memory only. A full shutdown/startup cycle clears
# and re-raises them through the normal phase boundaries.
#
# ----------------------------------------------------------------------------

class BaseModule(ABC):
  def __init__(self, app: FastAPI):
    self.app = app
    self._sealed_event = asyncio.Event()

  @abstractmethod
  async def startup(self):
    pass

  async def on_seal(self):
    await self._seal_manifest()

  async def _hook_fetch_seed_package(self):
    pass

  async def _hook_check_version(self) -> bool:
    return True

  async def _hook_install_seed_package(self):
    pass

  async def _seal_manifest(self):
    await self._hook_fetch_seed_package()
    if await self._hook_check_version():
      return
    try:
      await self._hook_install_seed_package()
    except Exception as e:
      logger.error("%s: _hook_install_seed_package failed: %s", self.__class__.__name__, e)
      return
    logger.info("%s: Sealed", self.__class__.__name__)

  @abstractmethod
  async def on_drain(self):
    pass

  @abstractmethod
  async def shutdown(self):
    pass

  def raise_seal(self):
    self._sealed_event.set()

  async def on_sealed(self):
    await self._sealed_event.wait()

  @property
  def module_manager(self) -> "ModuleManager":
    return self.app.state.module_manager

  def get_module(self, module_type: Type[T]) -> T:
    return self.module_manager._get_module(module_type)


# ----------------------------------------------------------------------------
# ModuleManager
# ----------------------------------------------------------------------------
# Module lifecycle manager. Discovers, instantiates, and
# manages the startup/shutdown lifecycle of all modules. Independent of
# the application lifecycle (lifespan) — the lifespan calls into the
# manager, not the other way around.
#
# -- Lifecycle phases --------------------------------------------------------
#
#   startup():
#     Phase 1: _on_startup_init()      Sync. Discover *_module.py files,
#              import, instantiate, register by class type. Module
#              constructors run here. No async work.
#
#     Phase 2: _on_startup_all()       Async. Concurrent startup() on all
#              modules via asyncio.gather. Modules resolve dependencies,
#              load data, open pools, raise_seal(). Ordering emerges
#              from on_sealed() waits in the dependency graph.
#
#     Phase 3: _on_startup_complete()  Async. Concurrent on_seal() on all
#              modules. Post-init work (reconciliation, finalization).
#              After all on_seal() calls complete: _sealed_event.set().
#
#   shutdown():
#     Phase 1: _on_shutdown_init()     Async. Concurrent on_drain() on all
#              modules. Pre-shutdown signal — stop accepting work.
#
#     Phase 2: _on_shutdown_all()      Async. Concurrent shutdown() on all
#              modules. Clear caches, close pools, null references.
#              Clears the instance registry.
#
#     Phase 3: _on_shutdown_complete() Sync. _sealed_event.clear(). Manager
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
# and on_sealed() to sequence themselves. The manager's job ends at
# invoking the five contract methods at the right phase.
#
# -- Autodiscovery -----------------------------------------------------------
# Scans the modules folder for files matching *_module.py. Converts
# filenames to PascalCase class names via snake_to_pascal(). Imports
# the module, expects a class with the converted name, instantiates it.
#
# -- Sealed state ------------------------------------------------------------
# _sealed_event is an asyncio.Event, unset by default. Set at the end
# of _on_startup_complete(). Cleared at the end of
# _on_shutdown_complete(). Modules check via the public `is_sealed`
# property (sync) or wait via `on_sealed()` (async). Not persisted —
# full shutdown/startup clears and re-raises it.
#
# -- Circular dependency guard -----------------------------------------------
# No runtime detection. Two modules that each await the other's
# on_sealed() will deadlock silently. This is a code error. The
# dependency graph must be a DAG.
#
# ----------------------------------------------------------------------------

class ModuleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self._instances: Dict[type, BaseModule] = {}
    self._sealed_event: asyncio.Event = asyncio.Event()

  @property
  def is_sealed(self) -> bool:
    return self._sealed_event.is_set()

  async def on_sealed(self):
    await self._sealed_event.wait()

  async def startup(self):
    self.app.state.module_manager = self

    self._on_startup_init()
    await self._on_startup_all()
    await self._on_startup_complete()

  async def shutdown(self):
    await self._on_shutdown_init()
    await self._on_shutdown_all()
    self._on_shutdown_complete()

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

  def _discover_and_register(self):
    for fname in os.listdir(MODULES_FOLDER):
      if not fname.endswith("_module.py") or fname == "__init__.py":
        continue

      file_stem = fname[:-3]
      class_name = snake_to_pascal(file_stem)
      module_path = f"{__name__}.{file_stem}"

      module = importlib.import_module(module_path)

      if not hasattr(module, class_name):
        logger.error("Module '%s' missing expected class '%s'", file_stem, class_name)
        continue

      module_class = getattr(module, class_name)
      instance = module_class(self.app)

      self._instances[module_class] = instance

  # -- Startup ---------------------------------------------------------------

  def _on_startup_init(self):
    self._discover_and_register()
    logger.info("on_startup_init - %d modules registered", len(self._instances))

  async def _on_startup_all(self):
    async def _start_module(module_class: type, module: BaseModule):
      await module.startup()
      logger.info("'%s' started", module_class.__name__)

    await asyncio.gather(*(
      _start_module(module_class, module) for module_class, module in self._instances.items()
    ))
    logger.info("on_startup_all successful")

  async def _on_startup_complete(self):
    async def _on_seal_module(module: BaseModule):
      await module.on_seal()

    await asyncio.gather(*(
      _on_seal_module(module) for module in self._instances.values()
    ))

    self._sealed_event.set()
    logger.info("on_startup_complete - sealed")

  # -- Shutdown --------------------------------------------------------------

  async def _on_shutdown_init(self):
    async def _on_drain_module(module: BaseModule):
      await module.on_drain()

    await asyncio.gather(*(
      _on_drain_module(module) for module in self._instances.values()
    ))
    logger.info("on_shutdown_init - %d modules drained", len(self._instances))

  async def _on_shutdown_all(self):
    async def _stop_module(module_class: type, module: BaseModule):
      await module.shutdown()
      logger.info("'%s' stopped", module_class.__name__)

    await asyncio.gather(*(
      _stop_module(module_class, module) for module_class, module in self._instances.items()
    ))
    self._instances.clear()
    logger.info("on_shutdown_all successful")

  def _on_shutdown_complete(self):
    self._sealed_event.clear()
    logger.info("on_shutdown_complete - unsealed")
    