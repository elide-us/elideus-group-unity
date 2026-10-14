import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .gateway_execution_module import GatewayExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# GatewayInterfaceModule
# ----------------------------------------------------------------------------
# Manager (Interface) for the IoGateway subsystem: the symmetrical public
# contract — everything entering or leaving the application crosses here, in a
# common envelope.
#
# STUB — contract to be defined with the DAG tables; no behaviour yet.
#
# -- Dependencies ------------------------------------------------------------
#   GatewayExecutionModule
# ----------------------------------------------------------------------------

class GatewayInterfaceModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: GatewayExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(GatewayExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
