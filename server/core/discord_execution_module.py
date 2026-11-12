import logging
import uuid

from fastapi import FastAPI
from pydantic import BaseModel

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid
from .gateway_execution_providers import DiscordGuild

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# DiscordGuildRow: one row of system_discord_guilds, as the registry
# operations return it. A guild is an organization (system_organizations,
# kind DISCORD_GUILD); ref_organization_guid is NULL until this executor maps
# it (tracked). ref_owner_user_guid is the one account user who owns the
# guild, assigned through assign_guild_owner; pub_owner_id is the Discord
# owner's snowflake, retained for billing. A guild row carries no financial
# data: credits belong to a Finance package, not built (Aaron 2026-11-03).
# ----------------------------------------------------------------------------

class DiscordGuildRow(BaseModel):
  key_guid: str
  ref_package_guid: str | None = None
  ref_organization_guid: str | None = None
  ref_owner_user_guid: str | None = None
  pub_guild_id: int
  pub_name: str
  pub_owner_id: int | None = None
  pub_region: str | None = None
  pub_member_count: int | None = None
  pub_notes: str | None = None
  pub_joined_on: str
  pub_left_on: str | None = None


# ----------------------------------------------------------------------------
# GuildSyncResult: what a guild sync reports back to the Gateway's step.
# ----------------------------------------------------------------------------

class GuildSyncResult(BaseModel):
  synced: int
  left: int


# ----------------------------------------------------------------------------
# DiscordExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Discord component: the logic of managing
# Discord interactions. Today: guild management (system_discord_guilds), read
# and written through the Database Manager's registry operations, one per
# verb, each a single statement the kernel commits. Channel management and
# the component's own configuration come next (Aaron 2026-11-03). The bot
# connection is an IoGateway channel and is not here. Rows are keyed by
# formula over NS_HASH and the guild snowflake; core owns them.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
# ----------------------------------------------------------------------------

GUILDS_TABLE = "system_discord_guilds"
GUILDS_UPSERT = "db:discord:guilds:upsert:1"
GUILDS_READ_ALL = "db:discord:guilds:read_all:1"
GUILDS_MARK_LEFT = "db:discord:guilds:mark_left:1"
GUILDS_ASSIGN_OWNER = "db:discord:guilds:assign_owner:1"


class DiscordExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._namespace: uuid.UUID | None = None
    self._core_guid: str | None = None

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._core_guid = deterministic_guid(self._namespace, "service_packages_manifest", "core")
    self.raise_ready()

  async def sync_guilds(self, current: list[DiscordGuild]) -> GuildSyncResult:
    seen = set()
    for guild in current:
      key_guid = deterministic_guid(self._namespace, GUILDS_TABLE, str(guild.guild_id))
      # Parameter order is the operation's input model order.
      await self._one(GUILDS_UPSERT, {
        "key_guid": key_guid,
        "ref_package_guid": self._core_guid,
        "pub_guild_id": guild.guild_id,
        "pub_name": guild.name,
        "pub_owner_id": guild.owner_id,
        "pub_region": guild.region,
        "pub_member_count": guild.member_count,
      })
      seen.add(guild.guild_id)
    left = 0
    for row in await self.guilds():
      if row.pub_left_on is None and row.pub_guild_id not in seen:
        await self._one(GUILDS_MARK_LEFT, {"pub_guild_id": row.pub_guild_id})
        left += 1
    logger.info("Discord guild sync: %d guild(s) synced, %d marked left", len(current), left)
    return GuildSyncResult(synced=len(current), left=left)

  async def guilds(self) -> list[DiscordGuildRow]:
    raw = await self._database.query(DBRequest(GUILDS_READ_ALL))
    rows = [] if raw is None else raw if isinstance(raw, list) else [raw]
    return [DiscordGuildRow.model_validate(row) for row in rows]

  async def assign_guild_owner(self, guild_id: int, user_guid: str) -> None:
    # One account user owns a guild; the assignment can change. A guild the
    # registry does not hold affects no row and raises.
    await self._one(GUILDS_ASSIGN_OWNER, {"ref_owner_user_guid": user_guid, "pub_guild_id": guild_id})

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._database = None
