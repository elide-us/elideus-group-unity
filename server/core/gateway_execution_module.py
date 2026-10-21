import asyncio
import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.kernel.kernel_configuration_module import KernelConfigurationModule
from server.helpers import discover_classes, deterministic_guid
from .gateway_execution_providers import BaseDiscordGuildProvider, BaseGatewayProvider, BaseGatewayWorker, DiscordGuildRegistry, GuildSyncResult, IoRequest, IoResponse
from .workflow_maintenance_module import WorkflowMaintenanceModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# GatewayExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the IoGateway subsystem: the normalization layer
# every crossing of the application boundary passes through, in or out. Owns
# the gateway providers (one <channel>_gateway_provider per external thing),
# keyed by channel (the provider's stem: 'discord' for
# discord_gateway_provider), the Discord outbound worker, and the Discord
# guild registry provider (system_discord_guilds: the BaseDiscordGuildProvider
# contract, implemented by DiscordGuildRegistry).
# Security is not a provider and is not here.
#
# One channel is built: Discord. Every other provider is a stub; a dispatch to
# a stub raises from the base handle(), a send to one raises here: never a
# silent no-op.
#
# The guild registry is kept by a WORKFLOW, never by a direct call: the
# discord_guild_sync definition's one step is
# GatewayInterfaceModule.sync_guilds. The gateway declares an instance on
# seal, after Discord has connected, and again whenever the client joins or
# leaves a guild (the provider's on_guild_join / on_guild_remove callbacks);
# the workflow worker claims and runs it.
#
#   startup()    construct the providers with their configuration and the
#                bot token, set the Discord guild callbacks, construct and
#                connect the guild registry (a no-op: it rides the database
#                module), and start the worker (it waits for the seal); no
#                Discord connection
#   on_seal()    connect Discord (a provider that cannot connect raises and
#                stops the seal), then declare discord_guild_sync. The seal
#                completes only after every on_seal(), so the worker's first
#                pass finds Discord connected.
#   on_unseal()  mark the gateway draining (send() refuses from here on), stop
#                the worker, drain what is queued best-effort through the same
#                pass the worker runs, disconnect
#   shutdown()   disconnect the guild registry; teardown
#
# -- Contract ----------------------------------------------------------------
#   dispatch(IoRequest) -> IoResponse    route to the request's channel provider
#   send(channel, text) -> None          [sync] enqueue an outbound text on the
#                                        channel's queue (its system channel);
#                                        raises RuntimeError once draining
#   deliver_next() -> bool               one worker pass: send one queued text
#                                        through the provider; False when the
#                                        queue is empty
#   sync_guilds() -> GuildSyncResult     upsert every guild the client is in;
#                                        stamp left_on on every joined row the
#                                        client no longer reports
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule (the guild registry operations, through the
#   guild registry provider)
#   EnvironmentVariablesModule (DISCORD_SECRET = the bot token; never logged,
#   never a row. NS_HASH = the guild row keys and the core package key)
#   KernelConfigurationModule (the discord_* configuration rows)
#   WorkflowMaintenanceModule (declares discord_guild_sync)
#   gateway_execution_providers/*_gateway_provider, *_worker, and the guild
#   registry provider in its __init__
# ----------------------------------------------------------------------------

CHANNEL_SUFFIX = "_gateway_provider"
DISCORD = "discord"
WORKER = "discord_gateway_worker"
SECRET = "DISCORD_SECRET"
# The Discord channel's tunables live in system configuration, not in code. The
# send interval is also the worker's cadence on an empty queue: sends are
# never closer together than it, so polling at it adds no slower path.
SYSTEM_CHANNEL_KEY = "discord_system_channel_id"
BOT_NAME_KEY = "discord_bot_name"
COMMAND_PREFIX_KEY = "discord_command_prefix"
SEND_INTERVAL_KEY = "discord_send_interval_seconds"
RATE_LIMIT_DELAY_KEY = "discord_rate_limit_delay_seconds"
MAX_LENGTH_KEY = "discord_message_max_length"
# The workflow definition that keeps system_discord_guilds (core package data).
GUILD_SYNC = "discord_guild_sync"
GUILDS_TABLE = "system_discord_guilds"


class GatewayExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._workflow: WorkflowMaintenanceModule | None = None
    self._providers: dict[str, BaseGatewayProvider] = {}
    self._worker: BaseGatewayWorker | None = None
    self._queue: asyncio.Queue | None = None
    self._guilds: BaseDiscordGuildProvider | None = None
    self._namespace: uuid.UUID | None = None
    self._core_guid: str | None = None
    self._system_channel_id: int = 0
    self._connected = False
    self._draining = False

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    configuration = self.get_module(KernelConfigurationModule)
    await configuration.await_ready()
    self._workflow = self.get_module(WorkflowMaintenanceModule)
    await self._workflow.await_ready()
    token = env.get(SECRET)
    if not token:
      raise RuntimeError("%s is not set: the Discord gateway has no bot token" % SECRET)
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._core_guid = deterministic_guid(self._namespace, "service_packages_manifest", "core")
    self._system_channel_id = int(configuration.get(SYSTEM_CHANNEL_KEY))
    providers = discover_classes(f"{__package__}.gateway_execution_providers", "_provider")
    workers = discover_classes(f"{__package__}.gateway_execution_providers", "_worker")
    for stem, provider in providers.items():
      if not stem.endswith(CHANNEL_SUFFIX):
        raise ImportError("gateway provider '%s' is not named <channel>%s" % (stem, CHANNEL_SUFFIX))
      channel = stem.removesuffix(CHANNEL_SUFFIX)
      if channel == DISCORD:
        self._providers[channel] = provider(
          token,
          self._system_channel_id,
          configuration.get(BOT_NAME_KEY),
          configuration.get(COMMAND_PREFIX_KEY),
          int(configuration.get(SEND_INTERVAL_KEY)),
          int(configuration.get(RATE_LIMIT_DELAY_KEY)),
          int(configuration.get(MAX_LENGTH_KEY)),
        )
        self._providers[channel].on_guild_join = self._declare_guild_sync
        self._providers[channel].on_guild_remove = self._declare_guild_sync
      else:
        self._providers[channel] = provider()
    self._guilds = DiscordGuildRegistry(self._database)
    await self._guilds.connect()
    self._queue = asyncio.Queue()
    logger.info("Gateway channels: %s", ", ".join(sorted(self._providers)))
    self._worker = workers[WORKER](self, int(configuration.get(SEND_INTERVAL_KEY)))
    await self._worker.start()
    self.raise_ready()

  async def dispatch(self, io_request: IoRequest) -> IoResponse:
    return await self._channel(io_request.channel).handle(io_request)

  def send(self, channel: str, text: str) -> None:
    # From the start of on_unseal (and after shutdown) the queue has no
    # drainer: refuse instead of enqueueing a message nothing will send.
    if self._draining or self._queue is None:
      raise RuntimeError("gateway is draining")
    self._channel(channel)
    if channel != DISCORD:
      raise NotImplementedError("gateway channel '%s' has no outbound queue" % channel)
    self._queue.put_nowait((self._system_channel_id, text))

  async def deliver_next(self) -> bool:
    # One queued (channel_id, text) through the Discord provider, which paces
    # the sends. A send that raises loses that one message, loudly.
    if self._queue.empty():
      return False
    channel_id, text = self._queue.get_nowait()
    await self._providers[DISCORD].send(channel_id, text)
    return True

  async def sync_guilds(self) -> GuildSyncResult:
    # The discord_guild_sync step: the registry follows what the client reports.
    current = self._providers[DISCORD].guilds()
    seen = set()
    for guild in current:
      key_guid = deterministic_guid(self._namespace, GUILDS_TABLE, str(guild.guild_id))
      await self._guilds.upsert(guild, key_guid, self._core_guid)
      seen.add(guild.guild_id)
    left = 0
    for row in await self._guilds.read_all():
      if row.pub_left_on is None and row.pub_guild_id not in seen:
        await self._guilds.mark_left(row.pub_guild_id)
        left += 1
    logger.info("Discord guild sync: %d guild(s) synced, %d marked left", len(current), left)
    return GuildSyncResult(synced=len(current), left=left)

  async def _declare_guild_sync(self) -> None:
    await self._workflow.declare(GUILD_SYNC)

  def _channel(self, channel: str) -> BaseGatewayProvider:
    provider = self._providers.get(channel)
    if provider is None:
      raise KeyError("no gateway channel '%s'" % channel)
    return provider

  async def on_seal(self):
    # A provider that cannot connect raises here and stops the seal.
    await self._providers[DISCORD].connect()
    self._connected = True
    # The first in-app declaration: the guild registry follows the client.
    await self._declare_guild_sync()

  async def on_unseal(self):
    self._draining = True
    if self._worker is not None:
      await self._worker.stop()
    discord = self._providers.get(DISCORD)
    if discord is None:
      return
    if self._connected:
      drained = 0
      try:
        while await self.deliver_next():
          drained += 1
      except Exception as e:
        logger.error("Discord drain stopped with %d queued message(s) unsent: %s", self._queue.qsize() + 1, e)
      if drained:
        logger.info("Drained %d queued Discord message(s)", drained)
    self._connected = False
    await discord.disconnect()

  async def shutdown(self):
    if self._guilds is not None:
      await self._guilds.disconnect()
    self._worker = None
    self._queue = None
    self._providers.clear()
    self._guilds = None
    self._workflow = None
    self._database = None
