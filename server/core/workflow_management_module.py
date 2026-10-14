import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.helpers import discover_classes

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowManagementModule
# ----------------------------------------------------------------------------
# Executor (Management) for the Workflow subsystem: polls declared work on its
# own cadence and dispatches it through the workflow providers and worker.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   GatewayInterfaceModule (database access via the gateway)
#   workflow_execution_providers/*
# ----------------------------------------------------------------------------

class WorkflowManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._providers: dict[str, type] = {}
    self._workers: dict[str, type] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    self._providers = discover_classes(f"{__package__}.workflow_execution_providers", "_provider")
    self._workers = discover_classes(f"{__package__}.workflow_execution_providers", "_worker")
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._database = None
    self._providers.clear()
    self._workers.clear()
