from abc import ABC, abstractmethod
from fastapi import FastAPI
from typing import Dict, TypeVar, Type
import asyncio, logging

logger = logging.getLogger(__name__.split('.')[-1])

# Database schema version this kernel is built for. Setup mode compares it
# with the database_version configuration row; the installer and migration
# scripts are generated from it.
DATABASE_VERSION = "0.1.2"

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



class BaseProvider(ABC):
  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

# ----------------------------------------------------------------------------
# BaseModule
# ----------------------------------------------------------------------------
# Abstract base for all modules. Every module file matching
# *_module.py is autodiscovered, instantiated, and registered by the
# ModuleManager during _discover().
#
# -- Lifecycle contract ------------------------------------------------------
#
#   __init__(app)   Synchronous. Initialize empty caches, null references.
#                   No async work. No dependency resolution. Called during
#                   ModuleManager._discover() (Phase 1).
#
#   startup()       Async. Resolve dependencies via get_module() + await_ready().
#                   Load data, open resources, raise_ready(). Called during
#                   ModuleManager._start_all() (Phase 2). All modules
#                   run concurrently via asyncio.gather; ordering emerges
#                   from await_ready() waits, not dispatch order.
#
#   on_seal()       Async. Post-init work. All modules are live and ready.
#                   Called during ModuleManager._seal()
#                   (Phase 3). Runs concurrently across all modules. After
#                   all on_seal() calls complete, the manager's _sealed_event
#                   is raised. Use this for reconciliation, finalization,
#                   or any work that requires the full module graph to be
#                   initialized.
#
#   on_unseal()     Async. Pre-shutdown signal. Stop accepting new work,
#                   flush in-flight operations, release external holds.
#                   Called during ModuleManager._drain_all().
#                   Runs concurrently across all modules.
#
#   shutdown()      Async. Teardown. Clear caches, close resources, null
#                   references. Called during ModuleManager._stop_all().
#
# -- Dependency resolution ---------------------------------------------------
#
#   get_module(T)   Returns the registered instance of module type T.
#                   Call during startup() to get references to other modules.
#
#   await_ready()   Awaits until the target module has called raise_ready().
#                   Use after get_module() to ensure the dependency is
#                   initialized before using it.
#
#   raise_ready()   Signals that this module is initialized and safe for
#                   dependents to call into. Call at the end of startup()
#                   after all resources are live.
#
# -- Dependency graph --------------------------------------------------------
# All modules start concurrently. Ordering is implicit: a module that
# calls `await dep.await_ready()` in its startup() will park until the
# dependency signals. This forms a dynamic DAG at runtime. The only
# constraint is no circular dependencies — two modules that each await
# the other's await_ready() will deadlock.
#
# Modules get their own references. The ModuleManager does not
# orchestrate composition, pass references, or know which module
# depends on which. It only calls the contract methods.
#
# -- Ready and sealed state --------------------------------------------------
# Two distinct states, two words:
#
#   Module-ready    This module has finished startup() and its contract
#                   is safe to call. Set by raise_ready(); observed by
#                   dependents via `await dep.await_ready()`. Backed by
#                   this module's own _ready_event.
#
#   Manager-sealed  All modules have completed on_seal() and the full
#                   application graph is initialized. Set by the
#                   ModuleManager at the end of _seal();
#                   observed via `manager.is_sealed` (sync read) or
#                   `await manager.await_sealed()` (async wait). Backed by
#                   the manager's _sealed_event.
#
# Both events are in-memory only. A full shutdown/startup cycle clears
# and re-raises them through the normal phase boundaries.
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
      logger.error("%s: _hook_install_seed_package failed: %s", self.__class__.__name__, e)
      return
    logger.info("%s: Sealed", self.__class__.__name__)

  @abstractmethod
  async def on_unseal(self):
    pass

  @abstractmethod
  async def shutdown(self):
    pass

  def raise_ready(self):
    self._ready_event.set()

  async def await_ready(self):
    await self._ready_event.wait()

  @property
  def module_manager(self) -> "KernelModuleManager":
    return self.app.state.module_manager

  def get_module(self, module_type: Type[T]) -> T:
    return self.module_manager._get_module(module_type)

# This late import is required to resolve the circlar dependency 
# between the KernelModuleManager and the Kernel re-export
from .kernel_module_manager import KernelModuleManager
__all__ = ["KernelModuleManager"]
