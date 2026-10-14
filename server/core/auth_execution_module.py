import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.helpers import discover_classes

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# AuthExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Auth subsystem: selects the identity providers
# at startup and resolves subjects through them.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   GatewayInterfaceModule (database access via the gateway)
#   auth_execution_providers/*_identity_provider
# ----------------------------------------------------------------------------

class AuthExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._providers: dict[str, type] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    self._providers = discover_classes(f"{__package__}.auth_execution_providers", "_provider")
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._database = None
    self._providers.clear()
