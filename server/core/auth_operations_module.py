import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .auth_execution_module import AuthExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# AuthOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Auth subsystem: the public contract that turns
# the credentials on a request into a user context (internal GUID), or none.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   AuthExecutionModule
# ----------------------------------------------------------------------------

class AuthOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: AuthExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(AuthExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
