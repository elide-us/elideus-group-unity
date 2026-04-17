from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, TypeVar, Type
import asyncio, logging, os, importlib

from server.helpers import snake_to_pascal


MODULES_FOLDER = os.path.dirname(__file__)

T = TypeVar("T", bound="BaseModule")

# ----------------------------------------------------------------------------
# BaseModule
# ----------------------------------------------------------------------------
# Abstract base for all application modules. Every module file matching
# *_module.py is autodiscovered, instantiated, and registered by the
# ModuleManager during startup_init().
#
# -- Lifecycle contract ------------------------------------------------------
#
#   __init__(app)   Synchronous. Initialize empty caches, null references.
#                   No async work. No dependency resolution. Called during
#                   ModuleManager._on_startup_init() (Phase 1).
#
#   startup()       Async. Resolve dependencies via get_module() + on_ready().
#                   Load data, open resources, mark_ready(). Called during
#                   ModuleManager._on_startup_all() (Phase 2). All modules
#                   run concurrently via asyncio.gather; ordering emerges
#                   from on_ready() waits, not dispatch order.
#
#   on_seal()       Async. Post-init work. All modules are live and ready.
#                   Called during ModuleManager._on_startup_complete()
#                   (Phase 3). Runs concurrently across all modules. After
#                   all on_seal() calls complete, _sealed = True. Use this
#                   for reconciliation, finalization, or any work that
#                   requires the full module graph to be initialized.
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
#   on_ready()      Awaits until the target module has called mark_ready().
#                   Use after get_module() to ensure the dependency is
#                   initialized before using it.
#
#   mark_ready()    Signals that this module is initialized and safe for
#                   dependents to call into. Call at the end of startup()
#                   after all resources are live.
#
# -- Dependency graph --------------------------------------------------------
# All modules start concurrently. Ordering is implicit: a module that
# calls `await dep.on_ready()` in its startup() will park until the
# dependency signals. This forms a dynamic DAG at runtime. The only
# constraint is no circular dependencies — two modules that each await
# the other's on_ready() will deadlock.
#
# Modules get their own references. The ModuleManager does not
# orchestrate composition, pass references, or know which module
# depends on which. It only calls the contract methods.
#
# -- Sealed state ------------------------------------------------------------
# After all on_seal() calls complete, ModuleManager._sealed = True.
# Modules that need to restrict post-bootstrap behavior (e.g.,
# DatabaseManagementModule refusing DDL) check this flag on their
# public methods. The flag is in-memory only — restart always unseals.
#
# ----------------------------------------------------------------------------

class BaseModule(ABC):
  def __init__(self, app: FastAPI):
    self.app = app
    self._ready_event = asyncio.Event()

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
      logging.error("%s: _hook_install_seed_pacakge failed: %s", self.__class__.__name__, e)
      return
    logging.info("%s: Sealed", self.__class__.__name__)

  @abstractmethod
  async def on_drain(self):
    pass

  @abstractmethod
  async def shutdown(self):
    pass

  def mark_ready(self):
    self._ready_event.set()

  async def on_ready(self):
    await self._ready_event.wait()

  @property
  def module_manager(self) -> "ModuleManager":
    return self.app.state.module_manager

  def get_module(self, module_type: Type[T]) -> T:
    return self.module_manager._get_module(module_type)


# ----------------------------------------------------------------------------
# ModuleManager
# ----------------------------------------------------------------------------
# Application module lifecycle manager. Discovers, instantiates, and
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
#              load data, open pools, mark_ready(). Ordering emerges
#              from on_ready() waits in the dependency graph.
#
#     Phase 3: _on_startup_complete()  Async. Concurrent on_seal() on all
#              modules. Post-init work (reconciliation, finalization).
#              After all on_seal() calls complete: _sealed = True.
#
#   shutdown():
#     Phase 1: _on_shutdown_init()     Async. Concurrent on_drain() on all
#              modules. Pre-shutdown signal — stop accepting work.
#
#     Phase 2: _on_shutdown_all()      Async. Concurrent shutdown() on all
#              modules. Clear caches, close pools, null references.
#              Clears the instance registry.
#
#     Phase 3: _on_shutdown_complete() Sync. _sealed = False. Manager
#              cleanup after all modules are down.
#
# -- Design principles -------------------------------------------------------
#
# The module manager only calls the contract. It does not:
#   - Orchestrate composition between modules
#   - Pass provider references or configuration
#   - Know which module depends on which
#   - Enforce ordering beyond the phase boundaries
#
# Modules are self-sufficient. They use get_module() to find each other
# and on_ready() to sequence themselves. Composition of extended
# providers (e.g., management provider onto execution provider) is
# internal to the module that needs it.
#
# -- Autodiscovery -----------------------------------------------------------
# Scans the modules folder for files matching *_module.py. Converts
# filenames to PascalCase class names via snake_to_pascal(). Imports
# the module, expects a class with the converted name, instantiates it.
#
# -- Sealed state ------------------------------------------------------------
# _sealed is an in-memory bool, False by default. Set True at the end
# of _on_startup_complete(). Set False at the end of _on_shutdown_complete().
# Modules check this flag to restrict post-bootstrap operations.
# Not persisted — restart always starts unsealed so reconciliation runs.
#
# -- Circular dependency guard -----------------------------------------------
# No runtime detection. Two modules that each await the other's
# on_ready() will deadlock silently. This is a code error. The
# dependency graph must be a DAG.
#
# ----------------------------------------------------------------------------

class ModuleManager:
  def __init__(self, app: FastAPI):
    self.app = app
    self._instances: Dict[type, BaseModule] = {}
    self._sealed: bool = False

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
    logging.info("[ModuleManager] restart complete")

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
      logging.error("Module '%s' not registered", module_type.__name__)
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
        logging.error("Module '%s' missing expected class '%s'", file_stem, class_name)
        continue

      module_class = getattr(module, class_name)
      instance = module_class(self.app)

      self._instances[module_class] = instance

  # -- Startup ---------------------------------------------------------------

  def _on_startup_init(self):
    self._discover_and_register()
    logging.info("[ModuleManager] on_startup_init — %d modules registered", len(self._instances))

  async def _on_startup_all(self):
    async def _start_module(module_class: type, module: BaseModule):
      await module.startup()
      logging.info("[ModuleManager] %s started", module_class.__name__)

    await asyncio.gather(*(
      _start_module(module_class, module) for module_class, module in self._instances.items()
    ))
    logging.info("[ModuleManager] on_startup_all successful")

  async def _on_startup_complete(self):
    async def _on_seal_module(module: BaseModule):
      await module.on_seal()

    await asyncio.gather(*(
      _on_seal_module(module) for module in self._instances.values()
    ))

    self._sealed = True
    logging.info("[ModuleManager] on_startup_complete — sealed")

  # -- Shutdown --------------------------------------------------------------

  async def _on_shutdown_init(self):
    async def _on_drain_module(module: BaseModule):
      await module.on_drain()

    await asyncio.gather(*(
      _on_drain_module(module) for module in self._instances.values()
    ))
    logging.info("[ModuleManager] on_shutdown_init — %d modules drained", len(self._instances))

  async def _on_shutdown_all(self):
    async def _stop_module(module_class: type, module: BaseModule):
      await module.shutdown()
      logging.info("[ModuleManager] %s stopped", module_class.__name__)

    await asyncio.gather(*(
      _stop_module(module_class, module) for module_class, module in self._instances.items()
    ))
    self._instances.clear()
    logging.info("[ModuleManager] on_shutdown_all successful")

  def _on_shutdown_complete(self):
    self._sealed = False
    logging.info("[ModuleManager] on_shutdown_complete — unsealed")
    