import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .organizations_execution_module import OrganizationsExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# OrganizationsOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Organizations component: the public contract
# for the organization primitive and its user membership (Aaron 2026-11-03:
# one shape for a Discord guild, an Entra tenant, and later an in-game guild;
# members are account users).
#
# STUB — contract to be defined with the account:organizations ops; no
# behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   OrganizationsExecutionModule
# ----------------------------------------------------------------------------

class OrganizationsOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: OrganizationsExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(OrganizationsExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
