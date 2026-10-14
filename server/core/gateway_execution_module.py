import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.helpers import discover_classes

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# GatewayExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the IoGateway subsystem: owns the gateway providers
# (rpc, mcp, discord, idp, database, storage, azure apis) and dispatches
# through them.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   SecurityOperationsModule (verify before dispatch)
#   kernel DatabaseExecutionModule (database gateway provider routes through it)
#   gateway_execution_providers/*_gateway_provider
# ----------------------------------------------------------------------------

class GatewayExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._providers: dict[str, type] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    self._providers = discover_classes(f"{__package__}.gateway_execution_providers", "_provider")
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._database = None
    self._providers.clear()
