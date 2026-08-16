import asyncio, logging, os, importlib
from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, Type

from server.helpers import snake_to_pascal
from server.kernel import BaseModule, MODULES_FOLDER, T

logger = logging.getLogger(__name__.split('.')[-1])


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

class KernelModuleManager:
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
      module_path = f"{__package__}.{file_stem}"

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
    