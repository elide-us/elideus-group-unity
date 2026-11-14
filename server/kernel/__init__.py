from abc import ABC, abstractmethod
from fastapi import FastAPI
from pydantic import BaseModel, ConfigDict
from typing import Dict, TypeVar, Type
import asyncio, logging, os, uuid

from server.helpers import deterministic_guid, instance_key

logger = logging.getLogger(__name__.split('.')[-1])

# Database schema version this kernel is built for. Setup mode compares it
# with the database_version configuration row; the installer and migration
# scripts are generated from it.
DATABASE_VERSION = "0.2.3"

# The code a host ends its process with when its registry row says
# RELOADING, for the host runtime to restart it on: neither 0 (setup mode's
# clean stop) nor 1 (a refused start). 75 is EX_TEMPFAIL.
RELOAD_EXIT_CODE = 75

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
# Abstract base for all modules. The module loader is the gather
# (ModuleManager.discover): it walks the whole server/ folder and imports every
# file whose name ends in _module.py; the suffix is the only rule, the class is
# named from the file stem, one instance of each is registered. No folder list,
# no package filter, no order. The listing (etg.contracts_modules) does not
# choose what loads: after start_all the LifecycleManager's listing gate
# refuses the boot when a loaded module has no row, or a loadable row in a
# sealed package was not loaded.
#
# -- Lifecycle contract ------------------------------------------------------
#
#   __init__(app)   Synchronous. Initialize empty caches, null references.
#                   No async work. No dependency resolution. Called by
#                   ModuleManager.discover() for every module gathered.
#
#   startup()       Async. Resolve dependencies via get_module() + await_ready().
#                   Load data, open resources, raise_ready(). Called by
#                   ModuleManager.start_all(): every module at once via
#                   asyncio.gather; ordering emerges from await_ready()
#                   waits, not dispatch order.
#
#   on_seal()       Async. Post-init work. All modules are live and ready.
#                   Called by LifecycleManager._seal() after the listing
#                   gate. Runs concurrently across all modules. After all
#                   on_seal() calls complete, the lifecycle's _sealed_event
#                   is raised. Use this for reconciliation, finalization,
#                   or any work that requires the full module graph to be
#                   initialized.
#
#   on_unseal()     Async. Pre-shutdown signal. Stop accepting new work,
#                   flush in-flight operations, release external holds.
#                   Called by LifecycleManager._drain_all().
#                   Runs concurrently across all modules.
#
#   shutdown()      Async. Teardown. Clear caches, close resources, null
#                   references. Called by ModuleManager.stop_all().
#
# -- Dependency resolution ---------------------------------------------------
#
#   get_module(T)   Returns the registered instance of module type T.
#                   Call during startup() to get references to other modules.
#                   It also notes the pair (this class name, T's class name)
#                   with the lifecycle (app.state.lifecycle_manager
#                   .note_dependency) and nothing more: same argument, same
#                   return, no refusal, no ordering. The note is an
#                   observation for the boot gate, which the lifecycle runs
#                   after start_all against contracts_modules_dependencies.
#                   It cannot refuse at call time: the rows are unreadable
#                   until the Database modules are up.
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
# Every module starts concurrently. Ordering is implicit: a module that
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
#   Lifecycle-sealed  All modules have completed on_seal() and the full
#                   application graph is initialized. Set by the
#                   LifecycleManager at the end of _seal(); observed via
#                   `app.state.lifecycle_manager.is_sealed` (sync read) or
#                   `await app.state.lifecycle_manager.await_sealed()`
#                   (async wait). Backed by the lifecycle's _sealed_event.
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

  def get_module(self, module_type: Type[T]) -> T:
    self.app.state.lifecycle_manager.note_dependency(type(self).__name__, module_type.__name__)
    return self.app.state.module_manager.get(module_type)


# ----------------------------------------------------------------------------
# ModuleListing: one row of etg.contracts_modules, as the module listing
# operation (db:contracts:modules:read_all:1) returns it.
# ----------------------------------------------------------------------------
# The listing is the gate: the LifecycleManager refuses the boot when a
# gathered module has no row here, or a loadable row (role MANAGER, EXECUTOR
# or PRIMITIVE, not abstract) in a sealed package was not gathered. Role,
# component and package are GUIDs (module_role enum, contracts_components
# row, package manifest row); BaseModule itself has no role. The boot gate
# compares the components of a noted get_module pair by
# ref_component_guid. The lifecycle filters by role, abstract flag and
# package in Python.
# ----------------------------------------------------------------------------

class ModuleListing(BaseModel):
  key_guid: str
  ref_role_enum_guid: str | None = None
  ref_component_guid: str | None = None
  ref_package_guid: str | None = None
  pub_name: str
  pub_is_abstract: bool


# ----------------------------------------------------------------------------
# ModuleDependencyRow: one row of etg.contracts_modules_dependencies, as the
# dependency operation (db:contracts:modules:read_dependencies:1) returns it.
# ----------------------------------------------------------------------------
# By name: the module, the module it depends on, and the kind (a
# module_dependency_kind member name: REQUIRES, INHERITS or EXTENDS). The
# boot gate compares these rows with the get_module pairs noted at startup.
# ----------------------------------------------------------------------------

class ModuleDependencyRow(BaseModel):
  pub_module: str
  pub_dependency: str
  pub_kind: str


# ----------------------------------------------------------------------------
# PackageManifestRow: one row of dbo.service_packages_manifest, as the
# manifest operation (db:contracts:db:list_manifest_rows:1, output model
# list_manifest_rows_output) returns it.
# ----------------------------------------------------------------------------
# The listing gate maps a listing's ref_package_guid to its package: a
# loadable row whose package is missing from the manifest, or not sealed,
# refuses the boot.
# ----------------------------------------------------------------------------

class PackageManifestRow(BaseModel):
  key_guid: str
  pub_name: str
  pub_version: str
  pub_is_sealed: bool


# ----------------------------------------------------------------------------
# SecurityContext: who is acting, carried by a unit of work. Frozen: a
# context is never edited. It is not a token (the token is the client's
# bearer) and it lives in memory: it has a system_security_contexts row only
# when a row refers to it.
# ----------------------------------------------------------------------------
# Every database statement runs under one (DBRequest.context).
# GUIDs are upper-case strings. The actor is who acts, the principal on whose
# behalf; the parent is the context this one was minted under (None for a
# root). channel is a security_channel member's row key; host and instance
# are this process's registered service_hosts row. pub_sealed is the flag the
# minting layer sets (False for the kernel context).
# ----------------------------------------------------------------------------

class SecurityContext(BaseModel):
  model_config = ConfigDict(frozen=True)

  key_guid: str
  ref_actor_guid: str
  ref_principal_guid: str
  ref_parent_context_guid: str | None
  ref_channel_enum_guid: str
  ref_host_guid: str
  ref_instance_guid: str
  pub_sealed: bool


# ----------------------------------------------------------------------------
# AccessDenied: a refusal by a security layer, raised AFTER its denial row was
# written (or its write failed and was logged).
# ----------------------------------------------------------------------------
#   layer    a security_layer member name (IDENTITY, AUTHORIZATION, ACCESS)
#   reason   a denial_reason member name (NO_CONTEXT, NO_GRANT, ...)
#   subject  what was refused: the URN, or the operation
# Carries no account GUID.
# ----------------------------------------------------------------------------

class AccessDenied(Exception):
  def __init__(self, layer: str, reason: str, subject: str):
    super().__init__("%s %s %s" % (layer, reason, subject))
    self.layer = layer
    self.reason = reason
    self.subject = subject


# ----------------------------------------------------------------------------
# kernel_context: the context the kernel itself works under (bootstrap reads,
# the host registry, the heartbeat and the stale sweep, the listing gate).
# ----------------------------------------------------------------------------
# Derived by formula over NS_HASH and the hostname EnvironmentVariablesModule
# reads; any module derives it, nothing passes it. Key per process:
# system_security_contexts:kernel.<hostname>.<pid>. Actor and principal are
# the service account (system_users:service); no parent; channel KERNEL; host
# and instance are both this process's registered service_hosts row
# (instance_key). Not sealed. KernelSecurityExecutionModule writes its row
# once the host row exists.
# ----------------------------------------------------------------------------

def kernel_context(namespace: uuid.UUID, hostname: str) -> SecurityContext:
  service = deterministic_guid(namespace, 'system_users', 'service')
  instance = instance_key(namespace, hostname)
  return SecurityContext(
    key_guid=deterministic_guid(namespace, 'system_security_contexts', 'kernel.%s.%d' % (hostname, os.getpid())),
    ref_actor_guid=service,
    ref_principal_guid=service,
    ref_parent_context_guid=None,
    ref_channel_enum_guid=deterministic_guid(namespace, 'contracts_primitives_enums', 'security_channel.KERNEL'),
    ref_host_guid=instance,
    ref_instance_guid=instance,
    pub_sealed=False,
  )
