import logging
from abc import abstractmethod

from pydantic import BaseModel

from server.kernel import BaseProvider, BaseWorker
from server.helpers import pascal_to_snake

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# The IoGateway envelope: IoRequest in, IoResponse out.
# ----------------------------------------------------------------------------
# The normalization layer every crossing of the application boundary passes
# through, in or out: HTTPRequest -> RPCRequest -> IoRequest -> Provider ->
# IoResponse -> RPCResponse -> HTTPResponse. The shape follows the workflow
# step document: the request names its channel (the provider's stem, e.g.
# 'discord'), the operation that channel performs, the name of the model its
# parameters are written in, and the parameters themselves as JSON text; the
# correlation key ties a response and its log lines to the request. The
# response says whether the operation succeeded, names the model its result
# is written in ('void' when there is none), and carries the result as JSON
# text or the error.
# ----------------------------------------------------------------------------

class IoRequest(BaseModel):
  channel: str
  operation: str
  model: str
  params: str
  correlation_key: str


class IoResponse(BaseModel):
  ok: bool
  model: str
  result: str | None = None
  error: str | None = None


class DiscordGuild(BaseModel):
  guild_id: int
  name: str
  owner_id: int | None = None
  member_count: int | None = None
  region: str | None = None


# ----------------------------------------------------------------------------
# BaseGatewayProvider
# ----------------------------------------------------------------------------
# Provider contract for one IoGateway CHANNEL: one <channel>_gateway_provider
# per external thing. A provider is constructed with the values it needs,
# never with modules; the executor reads them from configuration and the
# environment and hands them over.
#
#   connect() -> None       open the channel (the executor calls it at seal)
#   disconnect() -> None    close it (at the end of drain)
#   handle(IoRequest) -> IoResponse
#                           perform one operation on the channel. The default
#                           raises: a channel that does not implement it is a
#                           stub, and a dispatch to a stub fails loud.
# ----------------------------------------------------------------------------

class BaseGatewayProvider(BaseProvider):
  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  async def handle(self, io_request: IoRequest) -> IoResponse:
    channel = pascal_to_snake(type(self).__name__).removesuffix("_gateway_provider")
    raise NotImplementedError("gateway channel '%s' does not handle operations (stub provider)" % channel)


# ----------------------------------------------------------------------------
# BaseGatewayWorker
# ----------------------------------------------------------------------------
# A channel's outbound queue drainer, owned by the gateway executor. It waits
# for the manager to seal; then it has the executor deliver queued messages
# until the queue is empty, and sleeps on its cadence only when it is.
# ----------------------------------------------------------------------------

class BaseGatewayWorker(BaseWorker):
  @abstractmethod
  async def start(self) -> None:
    pass

  @abstractmethod
  async def stop(self) -> None:
    pass
