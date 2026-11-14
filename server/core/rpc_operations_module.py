import logging

from fastapi import FastAPI

from server.kernel import BaseModule, SecurityContext
from .rpc_execution_module import RpcExecutionModule, RpcRequest, RpcResponse

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# RpcOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Rpc component: the one door to a urn
# function. The gateway hands it a request under the session context it
# minted; the workflow hands it each step under the run context. Every gate
# runs in the executor; a refusal is recorded and answered, never raised.
# There is no other public function: nothing is callable around the gates.
#
# -- Contract ----------------------------------------------------------------
#   dispatch(session, request) -> RpcResponse
#   registered(urn) -> bool        [sync, cache-only] the URN is in the RPC
#                                  registry (the workflow validates a step)
#
# -- Dependencies ------------------------------------------------------------
#   RpcExecutionModule
# ----------------------------------------------------------------------------

class RpcOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: RpcExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(RpcExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def dispatch(self, session: SecurityContext, request: RpcRequest) -> RpcResponse:
    return await self._execution.dispatch(session, request)

  def registered(self, urn: str) -> bool:
    if self._execution is None:
      return False
    return self._execution.registered(urn)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
