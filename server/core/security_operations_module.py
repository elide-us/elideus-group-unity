import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .security_execution_module import SecurityExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Security subsystem: the public contract gateway
# providers call to evaluate a user's roles and entitlements against a domain
# / subdomain / function before dispatch. No provider layer: security never
# leaves the application.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   SecurityExecutionModule
# ----------------------------------------------------------------------------

class SecurityOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: SecurityExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(SecurityExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
