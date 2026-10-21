import logging
from abc import abstractmethod

from pydantic import BaseModel

from server.kernel import BaseProvider, BaseWorker
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
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


# ----------------------------------------------------------------------------
# The Discord guild registry (system_discord_guilds): the guilds the bot is
# connected to, application state.
# ----------------------------------------------------------------------------
# DiscordGuild is what the client reports for one guild (modern discord.py
# exposes no region: None). DiscordGuildRow is one row of the table as the
# read_all operation returns it: its formula key, package, the snowflake, the
# reported fields, the credits and notes an admin owns, when the bot joined
# and when it left (NULL while it is still in). GuildSyncResult is what one
# sync did: guilds upserted, rows newly stamped left.
# ----------------------------------------------------------------------------

class DiscordGuild(BaseModel):
  guild_id: int
  name: str
  owner_id: int | None = None
  member_count: int | None = None
  region: str | None = None


class DiscordGuildRow(BaseModel):
  key_guid: str
  ref_package_guid: str | None = None
  pub_guild_id: int
  pub_name: str
  pub_owner_id: int | None = None
  pub_region: str | None = None
  pub_member_count: int | None = None
  pub_credits: int
  pub_notes: str | None = None
  pub_joined_on: str
  pub_left_on: str | None = None


class GuildSyncResult(BaseModel):
  synced: int
  left: int


# ----------------------------------------------------------------------------
# BaseDiscordGuildProvider
# ----------------------------------------------------------------------------
# Provider contract for the DISCORD GUILD REGISTRY (system_discord_guilds),
# owned by the gateway executor and constructed with the database operations
# module. Not a channel: the contract and its one implementation,
# DiscordGuildRegistry, live in this file, where provider discovery (which
# registers every *_provider file here as a channel) never sees them. One
# registry operation per verb, each a single statement the kernel commits, so
# every call is atomic by itself. A write that affects any number of rows
# other than one is an error, raised, never swallowed.
#
#   upsert(guild, key_guid, package_guid) -> None
#                                 the guild's row by its snowflake: updated (and no
#                                 longer left) when it exists, its region only when
#                                 the client reports one; else inserted under
#                                 key_guid with joined_on now
#   read_all() -> list[DiscordGuildRow]
#   mark_left(guild_id) -> None   stamps left_on on a row not already left
# ----------------------------------------------------------------------------

class BaseDiscordGuildProvider(BaseProvider):
  def __init__(self, database: DatabaseOperationsModule):
    self._database = database

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def upsert(self, guild: DiscordGuild, key_guid: str, package_guid: str) -> None:
    pass

  @abstractmethod
  async def read_all(self) -> list[DiscordGuildRow]:
    pass

  @abstractmethod
  async def mark_left(self, guild_id: int) -> None:
    pass


# ----------------------------------------------------------------------------
# DiscordGuildRegistry: the guild registry provider, on the registry
# operations (core-owned rows).
# ----------------------------------------------------------------------------

GUILDS_UPSERT = "db:discord:guilds:upsert:1"
GUILDS_READ_ALL = "db:discord:guilds:read_all:1"
GUILDS_MARK_LEFT = "db:discord:guilds:mark_left:1"


class DiscordGuildRegistry(BaseDiscordGuildProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def upsert(self, guild: DiscordGuild, key_guid: str, package_guid: str) -> None:
    # Parameter order is the operation's input model order.
    await self._one(GUILDS_UPSERT, {
      "key_guid": key_guid,
      "ref_package_guid": package_guid,
      "pub_guild_id": guild.guild_id,
      "pub_name": guild.name,
      "pub_owner_id": guild.owner_id,
      "pub_region": guild.region,
      "pub_member_count": guild.member_count,
    })

  async def read_all(self) -> list[DiscordGuildRow]:
    raw = await self._database.query(DBRequest(GUILDS_READ_ALL))
    rows = [] if raw is None else raw if isinstance(raw, list) else [raw]
    return [DiscordGuildRow.model_validate(row) for row in rows]

  async def mark_left(self, guild_id: int) -> None:
    await self._one(GUILDS_MARK_LEFT, {"pub_guild_id": guild_id})

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))


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
