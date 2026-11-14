import asyncio
import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule, SecurityContext, kernel_context
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.kernel.kernel_configuration_module import KernelConfigurationModule
from server.kernel.kernel_security_operations_module import KernelSecurityOperationsModule
from server.helpers import deterministic_guid, discover_classes
from .gateway_execution_providers import BaseGatewayProvider, BaseGatewayWorker, IoRequest, IoResponse
from .rpc_operations_module import RpcOperationsModule
from .workflow_operations_module import WorkflowOperationsModule
from .discord_operations_module import DiscordOperationsModule
from .discord_execution_module import GuildSyncResult

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# GatewayExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the IoGateway subsystem: the normalization layer
# every crossing of the application boundary passes through, in or out. Owns
# the gateway providers (one <channel>_gateway_provider per external thing),
# keyed by channel (the provider's stem: 'discord' for
# discord_gateway_provider) and the Discord outbound worker. The guild
# registry (system_discord_guilds) is the Discord component's: the sync hands
# the client's guild list to DiscordOperationsModule (Aaron 2026-11-03).
# Security is not a provider and is not here.
#
# Two channels are built: Discord (outbound, and the guild registry) and RPC
# (inbound). Every other provider is a stub; a dispatch to a stub raises from
# the base handle(), a send to one raises here: never a silent no-op.
#
# The RPC channel: on seal the gateway mints ONE anonymous session context
# (KernelSecurityOperationsModule.mint: no parent, actor and principal the
# anonymous account system_users:anonymous by formula, channel RPC, sealed).
# It lives in memory: every anonymous request runs under it and nothing is
# written for it unless a refusal is recorded under it.
# The RPC provider is constructed with RpcOperationsModule.dispatch, a getter
# for that session (None before seal and from unseal on) and the gateway's
# denial writer; it refuses a request that presents a credential (IDENTITY,
# NO_IDENTITY) and dispatches everything else under the session. The gateway
# decides nothing else: every other gate is RPC's.
#
# The guild registry is kept by a WORKFLOW, never by a direct call: the
# discord_guild_sync definition's one step is urn:system:discord:sync_guilds:1
# (GatewayOperationsModule.sync_guilds, dispatched through RPC under the run
# context). The gateway declares an instance under the kernel context on
# seal, after Discord has connected, and again whenever the client joins or
# leaves a guild (the provider's on_guild_join / on_guild_remove callbacks);
# the workflow worker claims and runs it.
#
#   startup()    construct the providers with their configuration and the
#                bot token (the RPC provider with the dispatch callable, the
#                session getter and the denial writer), set the Discord guild
#                callbacks, and start the worker (it waits for the seal); no
#                Discord connection
#   on_seal()    mint the anonymous RPC session; connect Discord (a provider
#                that cannot connect raises and stops the seal), then declare
#                discord_guild_sync under the kernel context. The seal
#                completes only after every on_seal(), so the worker's first
#                pass finds Discord connected.
#   on_unseal()  drop the RPC session (every inbound request is refused from
#                here on), mark the gateway draining (send() refuses from here
#                on), stop the worker, drain what is queued best-effort
#                through the same pass the worker runs, disconnect
#   shutdown()   teardown
#
# -- Contract ----------------------------------------------------------------
#   dispatch(IoRequest) -> IoResponse    route to the request's channel provider
#   send(channel, text) -> None          [sync] enqueue an outbound text on the
#                                        channel's queue (its system channel);
#                                        raises RuntimeError once draining
#   deliver_next() -> bool               one worker pass: send one queued text
#                                        through the provider; False when the
#                                        queue is empty
#   sync_guilds(context) -> GuildSyncResult
#                                        hand the guilds the client is in to
#                                        the Discord component under the
#                                        caller's context (the workflow run's)
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule
#   EnvironmentVariablesModule (DISCORD_SECRET = the bot token; never logged,
#   never a row. NS_HASH and the hostname = the kernel context and the
#   anonymous account key)
#   KernelConfigurationModule (the discord_* configuration rows)
#   KernelSecurityOperationsModule (mints the session, writes the gateway's
#   denials)
#   RpcOperationsModule (the RPC provider's dispatch)
#   WorkflowOperationsModule (declares discord_guild_sync)
#   DiscordOperationsModule (the guild registry)
#   gateway_execution_providers/*_gateway_provider, *_worker
# ----------------------------------------------------------------------------

CHANNEL_SUFFIX = "_gateway_provider"
DISCORD = "discord"
RPC = "rpc"
# The session the RPC channel dispatches under: the anonymous account, by formula.
ANONYMOUS = "anonymous"
SESSION_CHANNEL = "RPC"
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
# The workflow definition that keeps the Discord guild registry in line with the client.
GUILD_SYNC = "discord_guild_sync"


class GatewayExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._workflow: WorkflowOperationsModule | None = None
    self._providers: dict[str, BaseGatewayProvider] = {}
    self._worker: BaseGatewayWorker | None = None
    self._queue: asyncio.Queue | None = None
    self._discord: DiscordOperationsModule | None = None
    self._rpc: RpcOperationsModule | None = None
    self._kernel_security: KernelSecurityOperationsModule | None = None
    self._namespace: uuid.UUID | None = None
    self._kernel: SecurityContext | None = None
    self._session: SecurityContext | None = None
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
    self._workflow = self.get_module(WorkflowOperationsModule)
    await self._workflow.await_ready()
    self._discord = self.get_module(DiscordOperationsModule)
    await self._discord.await_ready()
    self._kernel_security = self.get_module(KernelSecurityOperationsModule)
    await self._kernel_security.await_ready()
    self._rpc = self.get_module(RpcOperationsModule)
    await self._rpc.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._kernel = kernel_context(self._namespace, env.get_hostname())
    token = env.get(SECRET)
    if not token:
      raise RuntimeError("%s is not set: the Discord gateway has no bot token" % SECRET)
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
      elif channel == RPC:
        self._providers[channel] = provider(self._rpc.dispatch, self._session_context, self._refuse)
      else:
        self._providers[channel] = provider()
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

  async def sync_guilds(self, context: SecurityContext) -> GuildSyncResult:
    # The discord_guild_sync step: the Discord component's registry follows what the client reports.
    return await self._discord.sync_guilds(context, self._providers[DISCORD].guilds())

  async def _declare_guild_sync(self) -> None:
    await self._workflow.declare(self._kernel, GUILD_SYNC)

  def _session_context(self) -> SecurityContext | None:
    return self._session

  async def _refuse(self, layer: str, reason: str, subject: str) -> None:
    # The gateway's denial row: under the session, or under the kernel context
    # when no session exists. deny() logs its own write failure; nothing raises.
    context = self._session if self._session is not None else self._kernel
    try:
      if context is None:
        raise RuntimeError("no context to record the denial under")
      await self._kernel_security.deny(context, layer, reason, subject)
    except Exception as e:
      logger.error("Gateway denial write failed (%s %s): %s", layer, reason, type(e).__name__)

  def _channel(self, channel: str) -> BaseGatewayProvider:
    provider = self._providers.get(channel)
    if provider is None:
      raise KeyError("no gateway channel '%s'" % channel)
    return provider

  async def on_seal(self):
    # The one anonymous session the RPC channel dispatches under: carried in
    # memory, nothing written. A mint that fails raises and stops the seal:
    # no session is supplied instead.
    anonymous = deterministic_guid(self._namespace, "system_users", ANONYMOUS)
    self._session = self._kernel_security.mint(None, anonymous, anonymous, SESSION_CHANNEL, True)
    logger.info("RPC session context minted")
    # A provider that cannot connect raises here and stops the seal.
    await self._providers[DISCORD].connect()
    self._connected = True
    # The first in-app declaration: the guild registry follows the client.
    await self._declare_guild_sync()

  async def on_unseal(self):
    self._session = None
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
    self._worker = None
    self._queue = None
    self._providers.clear()
    self._session = None
    self._kernel = None
    self._namespace = None
    self._rpc = None
    self._kernel_security = None
    self._discord = None
    self._workflow = None
    self._database = None
