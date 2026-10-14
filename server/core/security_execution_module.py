import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security subsystem: resolves a user's roles,
# groups and entitlements from the mapping tables and builds the security
# decoration.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   GatewayInterfaceModule (database access via the gateway)
# ----------------------------------------------------------------------------

class SecurityExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._database = None
