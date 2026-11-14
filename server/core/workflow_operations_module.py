import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule, SecurityContext
from .rpc_operations_module import RpcOperationsModule
from .workflow_execution_module import WorkflowExecutionModule, WorkflowSteps
from .workflow_execution_providers import WorkflowQueueInstance, WorkflowQueueRow

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Workflow subsystem: the declaration surface.
# A definition is declared by name under the caller's context; the manager
# validates its step document against the contract (shape, then every step's
# URN is a function of the RPC registry), copies the definition onto a new
# queue row with a batch number, and returns the instance key. Nothing is
# executed here: the executor's worker claims the row on its own cadence and
# runs it under a run context minted from what the row holds.
#
# The queue row carries ref_principal_guid = context.ref_principal_guid and
# ref_package_guid = the job's own package (the definition's); the batch
# number is drawn under the same context. Its context column stays NULL: a
# declaration writes no context row (that column is the provider's to fill
# when it logs a table flagged in the audit setup, which is not built).
#
# Definitions are package data; this manager reads them and never writes them.
#
# -- Contract ----------------------------------------------------------------
#   definitions() -> dict[str, dict]                [sync, cache-only]
#   validate(name) -> None                          [sync] raises ValueError on a bad definition
#   declare(context, name) -> str                   the instance key
#   status(context, key_guid) -> WorkflowQueueInstance | None
#
# -- Dependencies ------------------------------------------------------------
#   WorkflowExecutionModule, RpcOperationsModule (registered: the step check)
# ----------------------------------------------------------------------------

class WorkflowOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: WorkflowExecutionModule | None = None
    self._rpc: RpcOperationsModule | None = None

  async def startup(self):
    self._execution = self.get_module(WorkflowExecutionModule)
    await self._execution.await_ready()
    self._rpc = self.get_module(RpcOperationsModule)
    await self._rpc.await_ready()
    self.raise_ready()

  def definitions(self) -> dict[str, dict]:
    return self._execution.definitions()

  def validate(self, name: str) -> None:
    row = self._require(name)
    document = WorkflowSteps.model_validate_json(row["pub_steps"])
    if not document.steps:
      raise ValueError("workflow definition '%s' has no steps" % name)
    for step in document.steps:
      if not step.model:
        raise ValueError("workflow definition '%s': step '%s' names no model" % (name, step.contract))
      if not self._rpc.registered(step.contract):
        raise ValueError("workflow definition '%s': step '%s' is not a registered URN" % (name, step.contract))

  async def declare(self, context: SecurityContext, name: str) -> str:
    self.validate(name)
    row = self._require(name)
    key_guid = str(uuid.uuid4()).upper()
    await self._execution.declare(context, WorkflowQueueRow(
      key_guid=key_guid,
      ref_package_guid=row["ref_package_guid"],
      ref_definition_guid=row["key_guid"],
      ref_status_enum_guid=self._execution.status_guid("PENDING"),
      ref_disposition_enum_guid=row["ref_disposition_enum_guid"],
      pub_batch_number=await self._execution.next_batch_number(context),
      pub_steps=row["pub_steps"],
      pub_can_retry=row["pub_can_retry"],
      pub_max_attempts=row["pub_max_attempts"],
      ref_principal_guid=context.ref_principal_guid,
      ref_context_guid=None,
    ))
    return key_guid

  async def status(self, context: SecurityContext, key_guid: str) -> WorkflowQueueInstance | None:
    return await self._execution.instance(context, key_guid)

  def _require(self, name: str) -> dict:
    row = self._execution.definition(name)
    if row is None:
      raise KeyError("workflow definition '%s' not found" % name)
    return row

  async def on_seal(self):
    # The audit the step contract calls for: every definition is checked
    # against the RPC registry once the whole graph is up; a bad one is
    # logged, never fatal, and fails loud again at declaration.
    for name in self._execution.definitions():
      try:
        self.validate(name)
      except Exception as e:
        logger.error("Workflow definition '%s' is invalid: %s", name, e)

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
    self._rpc = None
