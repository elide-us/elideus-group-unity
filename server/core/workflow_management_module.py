import inspect
import logging
import uuid
from typing import Any

from fastapi import FastAPI
from pydantic import BaseModel

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import discover_classes, deterministic_guid
from .workflow_execution_providers import BaseWorkflowManagementProvider, BaseWorkflowTaskProvider, BaseWorkflowTaskWorker

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# The step document: the contract a workflow definition is written in.
# ----------------------------------------------------------------------------
# A definition's pub_steps column holds one WorkflowSteps document. Each step
# names the callee by one string (today the module and function, the RPC
# URN once the RPC registry exists; one form at a time), the name of that
# callee's input model, and the literal parameter values keyed by the model's
# field names. The definition is copied onto the queue row at declaration
# and the instance runs from its copy.
# ----------------------------------------------------------------------------

class WorkflowStep(BaseModel):
  contract: str
  model: str
  params: dict[str, Any]


class WorkflowSteps(BaseModel):
  steps: list[WorkflowStep]


# ----------------------------------------------------------------------------
# WorkflowManagementModule
# ----------------------------------------------------------------------------
# Executor (Management) for the Workflow subsystem: holds the definitions
# catalogue (service_workflow_definitions) in memory, owns the queue provider
# and the worker that claims and dispatches instances, draws batch numbers
# from the workflow_batch sequence, and sweeps stale claims when the
# application seals. Every read and write goes to the providers, which
# dispatch the registry operations.
#
# An instance is one row of system_workflow_queue: the copy of its
# definition plus status, attempts and a batch number. The worker claims the
# oldest pending row (one atomic statement), runs its steps in order, and
# records COMPLETE, or FAILED when the attempts are spent, or PENDING again
# when they are not. Stale RUNNING rows (a node that died mid-run) go back
# to PENDING on seal; the attempt they consumed counts.
#
# -- Contract ----------------------------------------------------------------
#   definitions() -> dict[str, dict]                [sync, cache-only]
#   definition(name) -> dict | None                 [sync, cache-only]
#   status_guid(name) -> str                        [sync]  task_status row key by formula
#   disposition_guid(name) -> str                   [sync]  task_disposition row key by formula
#   next_batch_number() -> int                      draws from the cached block, allocating when empty
#   declare(row) -> None                            writes one queue row (the manager builds it)
#   instance(key_guid) -> dict | None
#   resolve_contract(contract) -> callable          raises when the callee is not a loaded module function
#   run_once() -> bool                              claim, dispatch, record; False when the queue is empty
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
#   workflow_execution_providers/*_provider, *_worker
# ----------------------------------------------------------------------------

DEFINITIONS_PROVIDER = "workflow_management_provider"
TASK_PROVIDER = "workflow_task_provider"
WORKER = "workflow_task_worker"
BATCH_SEQUENCE = "workflow_batch"
STATUSES = ("PENDING", "RUNNING", "COMPLETE", "FAILED", "CANCELLING")
DISPOSITIONS = ("REVERSIBLE", "IRREVERSIBLE", "TRANSIENT", "CANCELLABLE")
# A RUNNING row older than this with no outcome is a claim its node abandoned.
STALE_GRACE_SECONDS = 300


class WorkflowManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._definitions_provider: BaseWorkflowManagementProvider | None = None
    self._task_provider: BaseWorkflowTaskProvider | None = None
    self._worker: BaseWorkflowTaskWorker | None = None
    self._namespace: uuid.UUID | None = None
    self._definitions: dict[str, dict] = {}
    self._status: dict[str, str] = {}
    self._disposition: dict[str, str] = {}
    self._batch: list[int] = []
    self._sequence_guid: str | None = None
    self._module_guid: str | None = None

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._status = {n: deterministic_guid(self._namespace, "contracts_primitives_enums", "task_status.%s" % n) for n in STATUSES}
    self._disposition = {n: deterministic_guid(self._namespace, "contracts_primitives_enums", "task_disposition.%s" % n) for n in DISPOSITIONS}
    self._sequence_guid = deterministic_guid(self._namespace, "service_sequences", BATCH_SEQUENCE)
    self._module_guid = deterministic_guid(self._namespace, "contracts_modules", self.__class__.__name__)
    providers = discover_classes(f"{__package__}.workflow_execution_providers", "_provider")
    workers = discover_classes(f"{__package__}.workflow_execution_providers", "_worker")
    self._definitions_provider = providers[DEFINITIONS_PROVIDER](self._database)
    self._task_provider = providers[TASK_PROVIDER](self._database)
    await self._definitions_provider.connect()
    await self._task_provider.connect()
    await self._reload()
    self._worker = workers[WORKER](self)
    await self._worker.start()
    self.raise_ready()

  async def _reload(self):
    self._definitions = {row["pub_name"]: row for row in await self._definitions_provider.read_all()}
    if self._definitions:
      logger.info("Loaded %d workflow definitions", len(self._definitions))
    else:
      logger.warning("No workflow definitions loaded (empty table or operation not found)")

  def definitions(self) -> dict[str, dict]:
    return self._definitions

  def definition(self, name: str) -> dict | None:
    return self._definitions.get(name)

  def status_guid(self, name: str) -> str:
    return self._status[name]

  def disposition_guid(self, name: str) -> str:
    return self._disposition[name]

  async def next_batch_number(self) -> int:
    # CACHED sequence: a block is burned at allocation; what this process
    # does not hand out before it stops is lost, by design.
    if not self._batch:
      issued = await self._task_provider.allocate(self._sequence_guid, self._module_guid, None)
      self._batch = list(range(int(issued["pub_number_from"]), int(issued["pub_number_to"]) + 1))
      logger.info("Allocated batch numbers %d-%d", self._batch[0], self._batch[-1])
    return self._batch.pop(0)

  async def declare(self, row: dict) -> None:
    await self._task_provider.declare(row)
    logger.info("Declared workflow instance %s (batch %s)", row["key_guid"], row["pub_batch_number"])

  async def instance(self, key_guid: str) -> dict | None:
    return await self._task_provider.read(key_guid)

  def resolve_contract(self, contract: str):
    # "<ModuleClass>.<function>": the module is one the manager loaded, the
    # function one it declares. The RPC URN replaces this string later; the
    # step document does not change when it does.
    module_name, _, function = contract.partition(".")
    if not module_name or not function or function.startswith("_"):
      raise ValueError("step contract '%s' is not <Module>.<function>" % contract)
    instance = self.module_manager.get_module_by_name(module_name)
    if instance is None:
      raise ValueError("step contract '%s': module %s is not loaded" % (contract, module_name))
    fn = getattr(instance, function, None)
    if not callable(fn):
      raise ValueError("step contract '%s': %s has no function %s" % (contract, module_name, function))
    return fn

  async def run_once(self) -> bool:
    claimed = await self._task_provider.claim(self._status["PENDING"], self._status["RUNNING"])
    if claimed is None:
      return False
    key_guid = claimed["key_guid"]
    try:
      steps = WorkflowSteps.model_validate_json(claimed["pub_steps"])
      for step in steps.steps:
        result = self.resolve_contract(step.contract)(**step.params)
        if inspect.isawaitable(result):
          await result
    except Exception as e:
      error = "%s: %s" % (type(e).__name__, e)
      attempts, limit = int(claimed["pub_attempts"]), int(claimed["pub_max_attempts"])
      if claimed["pub_can_retry"] and attempts < limit:
        await self._task_provider.retry(key_guid, self._status["PENDING"], error)
        logger.warning("Workflow instance %s failed on attempt %d of %d, pending retry: %s", key_guid, attempts, limit, error)
      else:
        await self._task_provider.fail(key_guid, self._status["FAILED"], error)
        logger.error("Workflow instance %s failed on attempt %d of %d, terminal: %s", key_guid, attempts, limit, error)
      return True
    await self._task_provider.complete(key_guid, self._status["COMPLETE"])
    logger.info("Workflow instance %s complete (batch %s)", key_guid, claimed["pub_batch_number"])
    return True

  async def on_seal(self):
    # Stale-claim recovery: a RUNNING row past the grace period belongs to a
    # node that died; it goes back to PENDING and the attempt it took counts.
    released = await self._task_provider.release_stale(self._status["PENDING"], self._status["RUNNING"], STALE_GRACE_SECONDS)
    if released:
      logger.warning("Released %d stale workflow claim(s)", released)

  async def on_unseal(self):
    if self._worker is not None:
      await self._worker.stop()
    self._definitions.clear()
    self._batch.clear()

  async def shutdown(self):
    self._worker = None
    for provider in (self._definitions_provider, self._task_provider):
      if provider:
        await provider.disconnect()
    self._definitions_provider = None
    self._task_provider = None
    self._definitions.clear()
    self._batch.clear()
    self._database = None
