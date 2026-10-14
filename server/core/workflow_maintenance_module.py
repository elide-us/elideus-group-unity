import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .workflow_management_module import WorkflowManagementModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowMaintenanceModule
# ----------------------------------------------------------------------------
# Manager (Maintenance) for the Workflow subsystem: the privileged declaration
# surface — tasks, schedules and lifecycle workflows (seal / unseal, package
# install and update) are declared here, never executed here.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   WorkflowManagementModule
# ----------------------------------------------------------------------------

class WorkflowMaintenanceModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._management: WorkflowManagementModule | None = None

  async def startup(self):
    self._management = self.get_module(WorkflowManagementModule)
    await self._management.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._management = None
