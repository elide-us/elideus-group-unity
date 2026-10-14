import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .users_execution_module import UsersExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# UsersOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Users subsystem: the public contract for
# accounts — the internal user GUID, IdP links, user-editable profile data.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   UsersExecutionModule
# ----------------------------------------------------------------------------

class UsersOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: UsersExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(UsersExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
