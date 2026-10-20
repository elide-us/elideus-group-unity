import asyncio, logging
from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, Type

from server.helpers import discover_classes
from server.kernel import BaseModule, T

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
#     Phase 1: _discover()             Sync. Discover *_module.py files,
#              import, instantiate, register by class type. Module
#              constructors run here. No async work.
#
#     Phase 2: _start_all()            Async. Concurrent startup() on all
#              modules via asyncio.gather. Modules resolve dependencies,
#              load data, open pools, raise_ready(). Ordering emerges
#              from await_ready() waits in the dependency graph.
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
# -- Autodiscovery -----------------------------------------------------------
# Scans the modules folder for files matching *_module.py. Converts
# filenames to PascalCase class names via snake_to_pascal(). Imports
# the module, expects a class with the converted name, instantiates it.
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

class KernelModuleManager:
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

    self._discover()
    await self._start_all()
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

  def _discover_and_register(self):
    for module_class in discover_classes(__package__, "_module").values():
      self._instances[module_class] = module_class(self.app)

  # -- Startup ---------------------------------------------------------------

  def _discover(self):
    self._discover_and_register()
    logger.info("discover - %d modules registered", len(self._instances))

  async def _start_all(self):
    async def _start_module(module_class: type, module: BaseModule):
      await module.startup()
      logger.info("'%s' started", module_class.__name__)

    await asyncio.gather(*(
      _start_module(module_class, module) for module_class, module in self._instances.items()
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
    