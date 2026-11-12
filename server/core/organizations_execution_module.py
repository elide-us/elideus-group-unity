import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# OrganizationsExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Organizations component: reads and writes
# system_organizations and system_organization_members through the
# account:organizations and account:organization_members operations.
#
# STUB — contract to be defined with the account:organizations ops; no
# behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule
# ----------------------------------------------------------------------------

class OrganizationsExecutionModule(BaseModule):
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
