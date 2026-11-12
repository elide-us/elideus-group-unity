import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .discord_execution_module import DiscordExecutionModule, DiscordGuildRow, GuildSyncResult
from .gateway_execution_providers import DiscordGuild

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# DiscordOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Discord component: managing Discord
# interactions (Aaron 2026-11-03). Guild management and channel management
# are its two main items, not exclusively; it knows guilds, channels and its
# own configuration. Users and their linking are the account system's; RPC
# commands arriving over Discord are the IoGateway's; the bot connection is
# an IoGateway channel. A guild is an organization of kind DISCORD_GUILD; the
# mapping onto system_organizations is the executor's, when it lands.
#
# -- Contract ----------------------------------------------------------------
#   sync_guilds(current) -> GuildSyncResult   the registry follows the guilds
#                                             the client reports (the Gateway's
#                                             discord_guild_sync step hands them over)
#   guilds() -> list[DiscordGuildRow]         the registry as it stands
#   assign_guild_owner(guild_id, user_guid)   the one account user who owns
#                                             the guild; changeable. Credits
#                                             and billing belong to a Finance
#                                             package, not built, not here.
#
# -- Dependencies ------------------------------------------------------------
#   DiscordExecutionModule
# ----------------------------------------------------------------------------

class DiscordOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: DiscordExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(DiscordExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  async def sync_guilds(self, current: list[DiscordGuild]) -> GuildSyncResult:
    return await self._execution.sync_guilds(current)

  async def guilds(self) -> list[DiscordGuildRow]:
    return await self._execution.guilds()

  async def assign_guild_owner(self, guild_id: int, user_guid: str) -> None:
    await self._execution.assign_guild_owner(guild_id, user_guid)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
