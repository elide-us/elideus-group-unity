import asyncio, logging, time
from typing import Awaitable, Callable

import discord
from discord.ext import commands
from pydantic import BaseModel

from server.kernel import DATABASE_VERSION
from server.helpers import pascal_to_snake
from . import BaseGatewayProvider, DiscordGuild, IoRequest, IoResponse

logger = logging.getLogger(__name__.split('.')[-1])

# The operation this channel performs through handle().
SEND = "send"
RATE_LIMITED = "Discord logging rate limited, resuming."
# discord.py's own loggers stay at WARNING: their INFO lines are not ours.
DISCORD_LOGGERS = ("discord", "discord.http", "discord.client", "discord.gateway")


# ----------------------------------------------------------------------------
# DiscordSendParams: the parameters of the 'send' operation, the model an
# IoRequest names (by its registry name, discord_send_params) and writes its
# params in. channel_id NULL means the system channel.
# ----------------------------------------------------------------------------

class DiscordSendParams(BaseModel):
  channel_id: int | None = None
  text: str


SEND_PARAMS_MODEL = pascal_to_snake(DiscordSendParams.__name__)


# ----------------------------------------------------------------------------
# DiscordGatewayProvider
# ----------------------------------------------------------------------------
# The Discord channel of the IoGateway: the PRIMARY provider, the one owner of
# the discord.py client (the v2.5 bot pattern). Constructed with the values it
# needs: the bot token (env DISCORD_SECRET), the system channel id, the bot
# name, the command prefix, the send interval, the rate-limit delay and the
# maximum message length (configuration rows). The executor sets the two guild
# callbacks after construction: on_guild_join and on_guild_remove (async, no
# arguments), awaited when discord.py reports the bot joined or left a guild;
# one that raises is logged, never fatal to the client.
#
#   connect()     login, the connect task, wait until ready, then resolve the
#                 system channel. On ready the bot posts "<bot name> Online.
#                 Version: <DATABASE_VERSION>" to the system channel. A
#                 connection that ends before it is ready, or a system channel
#                 that does not resolve to a send-capable channel, raises: a
#                 broken provider stops the seal.
#   disconnect()  close the client and await the connect task.
#   send(channel_id, text) -> None
#                 resolve the channel, split the text into chunks of the
#                 maximum length, send each at least the send interval apart;
#                 an HTTP 429 sleeps the rate-limit delay, says so, waits the
#                 send interval, and resends once; a resend that fails again
#                 is logged at ERROR with the chunk length (that chunk is lost).
#   guilds() -> list[DiscordGuild]
#                 [sync] the guilds the client is in, as it reports them.
#   handle(IoRequest) -> IoResponse
#                 'send': params in discord_send_params {channel_id?, text},
#                 channel_id defaulting to the system channel. Any other
#                 operation, or params in any other model, is refused;
#                 params that do not validate against the model raise.
# ----------------------------------------------------------------------------

class DiscordGatewayProvider(BaseGatewayProvider):
  def __init__(self, token: str, system_channel_id: int, bot_name: str, command_prefix: str,
               send_interval_seconds: int, rate_limit_delay_seconds: int, max_message_length: int):
    self._token = token
    self._system_channel_id = system_channel_id
    self._bot_name = bot_name
    self._command_prefix = command_prefix
    self._send_interval = send_interval_seconds
    self._rate_limit_delay = rate_limit_delay_seconds
    self._max_length = max_message_length
    self._bot: commands.Bot | None = None
    self._task: asyncio.Task | None = None
    self._send_lock = asyncio.Lock()
    self._last_sent = 0.0
    self.on_guild_join: Callable[[], Awaitable[None]] | None = None
    self.on_guild_remove: Callable[[], Awaitable[None]] | None = None

  async def connect(self):
    for name in DISCORD_LOGGERS:
      logging.getLogger(name).setLevel(logging.WARNING)
    intents = discord.Intents.default()
    intents.guilds = True
    intents.guild_messages = True
    intents.members = True
    bot = commands.Bot(command_prefix=self._command_prefix, intents=intents)
    # Registered before login so the first ready is heard.
    bot.add_listener(self._on_ready, "on_ready")
    bot.add_listener(self._on_guild_join, "on_guild_join")
    bot.add_listener(self._on_guild_remove, "on_guild_remove")
    self._bot = bot
    await bot.login(self._token)
    self._task = asyncio.create_task(bot.connect())
    ready = asyncio.ensure_future(bot.wait_until_ready())
    done, _ = await asyncio.wait({ready, self._task}, return_when=asyncio.FIRST_COMPLETED)
    if ready not in done:
      # The connection ended before the client was ready: fail loud, never wait forever.
      ready.cancel()
      task, self._task = self._task, None
      error = None if task.cancelled() else task.exception()
      if error is not None:
        raise error
      raise RuntimeError("Discord connection closed before the client was ready")
    # The on_ready post runs as a discord.py event task, where an error never
    # reaches the seal: the system channel is resolved here so a wrong id
    # fails loud.
    await self._resolve(self._system_channel_id)
    logger.info("Discord gateway connected as %s", bot.user)

  async def disconnect(self):
    bot, task = self._bot, self._task
    self._bot = None
    self._task = None
    if bot is not None:
      await bot.close()
    if task is not None:
      try:
        await task
      except asyncio.CancelledError:
        pass

  async def _on_ready(self):
    # The gateway's own announcement (Aaron 2026-10-20), as v2.5 posted it.
    await self.send(self._system_channel_id, "%s Online. Version: %s" % (self._bot_name, DATABASE_VERSION))

  async def _on_guild_join(self, guild):
    logger.info("Joined guild %s (%s)", guild.name, guild.id)
    await self._notify(self.on_guild_join, "guild join")

  async def _on_guild_remove(self, guild):
    logger.info("Left guild %s (%s)", guild.name, guild.id)
    await self._notify(self.on_guild_remove, "guild remove")

  async def _notify(self, callback: Callable[[], Awaitable[None]] | None, event: str):
    # A discord.py event task: an error here reaches no caller, so it is logged.
    if callback is None:
      return
    try:
      await callback()
    except Exception as e:
      logger.error("Discord %s callback failed: %s", event, e)

  def guilds(self) -> list[DiscordGuild]:
    if self._bot is None:
      raise RuntimeError("Discord gateway is not connected")
    return [DiscordGuild(guild_id=g.id, name=g.name, owner_id=g.owner_id, member_count=g.member_count, region=None)
            for g in self._bot.guilds]

  async def send(self, channel_id: int, text: str) -> None:
    channel = await self._resolve(channel_id)
    for start in range(0, len(text), self._max_length):
      await self._send_chunk(channel, text[start:start + self._max_length])

  async def handle(self, io_request: IoRequest) -> IoResponse:
    if io_request.operation != SEND:
      return IoResponse(ok=False, model="void", error="discord: unknown operation '%s'" % io_request.operation)
    if io_request.model != SEND_PARAMS_MODEL:
      return IoResponse(ok=False, model="void", error="discord: operation '%s' takes %s, not '%s'" % (SEND, SEND_PARAMS_MODEL, io_request.model))
    params = DiscordSendParams.model_validate_json(io_request.params)
    channel_id = self._system_channel_id if params.channel_id is None else params.channel_id
    await self.send(channel_id, params.text)
    return IoResponse(ok=True, model="void")

  async def _resolve(self, channel_id: int):
    if self._bot is None:
      raise RuntimeError("Discord gateway is not connected")
    channel = self._bot.get_channel(channel_id)
    if channel is None:
      channel = await self._bot.fetch_channel(channel_id)
    if not isinstance(channel, discord.abc.Messageable):
      raise RuntimeError("Discord channel %s is not send-capable" % channel_id)
    return channel

  async def _send_chunk(self, channel, chunk: str):
    # Consecutive sends at least the send interval apart, one at a time.
    async with self._send_lock:
      wait = self._send_interval - (time.monotonic() - self._last_sent)
      if wait > 0:
        await asyncio.sleep(wait)
      try:
        await channel.send(chunk)
      except discord.HTTPException as e:
        if e.status != 429:
          raise
        await asyncio.sleep(self._rate_limit_delay)
        await channel.send(RATE_LIMITED)
        await asyncio.sleep(self._send_interval)
        try:
          await channel.send(chunk)
        except discord.HTTPException as again:
          logger.error("Discord resend after a rate limit failed (HTTP %s); a %d-character chunk was lost", again.status, len(chunk))
      finally:
        self._last_sent = time.monotonic()
