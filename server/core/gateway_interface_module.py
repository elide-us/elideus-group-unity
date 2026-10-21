import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .gateway_execution_module import GatewayExecutionModule
from .gateway_execution_providers import GuildSyncResult, IoRequest, IoResponse

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# GatewayInterfaceModule
# ----------------------------------------------------------------------------
# Manager (Interface) for the IoGateway subsystem: the symmetrical public
# contract — everything entering or leaving the application crosses here, in
# the common envelope (IoRequest in, IoResponse out). It fronts the executor
# and holds no state of its own.
#
# -- Contract ----------------------------------------------------------------
#   dispatch(IoRequest) -> IoResponse    perform one operation on a channel
#   send(channel, text) -> None          [sync] enqueue an outbound text on a
#                                        channel (the logger's one call)
#   sync_guilds() -> GuildSyncResult     bring system_discord_guilds in line
#                                        with the guilds the bot is in: the
#                                        contract the discord_guild_sync
#                                        workflow step names (only the workflow
#                                        worker calls it)
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

  async def dispatch(self, io_request: IoRequest) -> IoResponse:
    return await self._execution.dispatch(io_request)

  def send(self, channel: str, text: str) -> None:
    self._execution.send(channel, text)

  async def sync_guilds(self) -> GuildSyncResult:
    return await self._execution.sync_guilds()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
