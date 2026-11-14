import logging
from typing import Awaitable, Callable

from server.kernel import SecurityContext
from . import BaseGatewayProvider, IoRequest, IoResponse
from ..rpc_execution_module import RpcRequest, RpcResponse

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# RpcGatewayProvider
# ----------------------------------------------------------------------------
# The RPC channel of the IoGateway: an inbound request becomes one RPC
# dispatch under the anonymous session context the gateway minted at seal.
# There is no identity layer yet: a request that presents a credential is
# refused, never read. Constructed by the gateway executor with three
# callables (they appear only here, in __init__):
#   dispatch(session, RpcRequest) -> RpcResponse   RpcOperationsModule.dispatch
#   session() -> SecurityContext | None            the session minted at seal;
#                                                  None before seal and after unseal
#   refuse(layer, reason, subject) -> None         the executor's denial writer:
#                                                  under the session, or under the
#                                                  kernel context when there is none
#
#   handle(IoRequest) -> IoResponse, deny path first:
#     a credential is present          refuse(IDENTITY, NO_IDENTITY, operation);
#                                      IoResponse(ok False, error NO_IDENTITY)
#     there is no session              refuse(IDENTITY, NO_CONTEXT, operation);
#                                      IoResponse(ok False, error NO_CONTEXT)
#     otherwise                        RpcRequest(urn = operation, params,
#                                      correlation_key) dispatched under the
#                                      session; the RpcResponse as an IoResponse
#   The credential is never logged.
# ----------------------------------------------------------------------------

IDENTITY = "IDENTITY"
VOID = "void"


class RpcGatewayProvider(BaseGatewayProvider):
  def __init__(
    self,
    dispatch: Callable[[SecurityContext, RpcRequest], Awaitable[RpcResponse]],
    session: Callable[[], SecurityContext | None],
    refuse: Callable[[str, str, str], Awaitable[None]],
  ):
    self._dispatch = dispatch
    self._session = session
    self._refuse = refuse

  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def handle(self, io_request: IoRequest) -> IoResponse:
    if io_request.credential is not None:
      await self._refuse(IDENTITY, "NO_IDENTITY", io_request.operation)
      return IoResponse(ok=False, model=VOID, result=None, error="NO_IDENTITY")
    session = self._session()
    if not isinstance(session, SecurityContext):
      await self._refuse(IDENTITY, "NO_CONTEXT", io_request.operation)
      return IoResponse(ok=False, model=VOID, result=None, error="NO_CONTEXT")
    response = await self._dispatch(session, RpcRequest(
      urn=io_request.operation,
      params=io_request.params,
      correlation_key=io_request.correlation_key,
    ))
    return IoResponse(ok=response.ok, model=response.model, result=response.result, error=response.error)
