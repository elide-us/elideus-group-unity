import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule
from .workflow_management_module import WorkflowManagementModule, WorkflowSteps

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowMaintenanceModule
# ----------------------------------------------------------------------------
# Manager (Maintenance) for the Workflow subsystem: the declaration surface.
# A definition is declared by name; the manager validates its step document
# against the contract (shape, then every callee resolves to a loaded module
# function), copies the definition onto a new queue row with a batch number,
# and returns the instance key. Nothing is executed here: the executor's
# worker claims the row on its own cadence.
#
# Definitions are package data; this manager reads them and never writes them.
#
# -- Contract ----------------------------------------------------------------
#   definitions() -> dict[str, dict]                [sync, cache-only]
#   validate(name) -> None                          raises ValueError on a bad definition
#   declare(name, package_guid=None) -> str         the instance key
#   status(key_guid) -> dict | None
#
# -- Dependencies ------------------------------------------------------------
#   WorkflowManagementModule
# ----------------------------------------------------------------------------

class WorkflowMaintenanceModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: WorkflowManagementModule | None = None

  async def startup(self):
    self._execution = self.get_module(WorkflowManagementModule)
    await self._execution.await_ready()
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
      self._execution.resolve_contract(step.contract)

  async def declare(self, name: str, package_guid: str | None = None) -> str:
    self.validate(name)
    row = self._require(name)
    key_guid = str(uuid.uuid4()).upper()
    await self._execution.declare({
      "key_guid": key_guid,
      "ref_package_guid": package_guid,
      "ref_definition_guid": row["key_guid"],
      "ref_status_enum_guid": self._execution.status_guid("PENDING"),
      "ref_disposition_enum_guid": row["ref_disposition_enum_guid"],
      "pub_batch_number": await self._execution.next_batch_number(),
      "pub_steps": row["pub_steps"],
      "pub_can_retry": row["pub_can_retry"],
      "pub_max_attempts": row["pub_max_attempts"],
    })
    return key_guid

  async def status(self, key_guid: str) -> dict | None:
    return await self._execution.instance(key_guid)

  def _require(self, name: str) -> dict:
    row = self._execution.definition(name)
    if row is None:
      raise KeyError("workflow definition '%s' not found" % name)
    return row

  async def on_seal(self):
    # The audit the step contract calls for: every definition is checked
    # against the loaded modules once the whole graph is up; a bad one is
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
