import asyncio, logging

from . import BaseGatewayWorker

logger = logging.getLogger(__name__.split('.')[-1])


class DiscordGatewayWorker(BaseGatewayWorker):
  def __init__(self, executor, poll_seconds: int):
    # Seconds the loop sleeps when it finds the outbound queue empty (the
    # discord_send_interval_seconds configuration row). A backlog runs as fast
    # as the provider paces it: the cadence gates only the empty queue.
    self._executor = executor
    self._poll = poll_seconds
    self._stop = asyncio.Event()
    self._task: asyncio.Task | None = None

  async def start(self) -> None:
    self._stop.clear()
    self._task = asyncio.create_task(self._run())

  async def stop(self) -> None:
    self._stop.set()
    if self._task is not None:
      if not self._executor.app.state.lifecycle_manager.is_sealed:
        # Never sealed (a startup that failed): the loop is still parked on
        # await_sealed() and would never see the stop.
        self._task.cancel()
      try:
        await self._task
      except asyncio.CancelledError:
        pass
      self._task = None

  async def _run(self) -> None:
    # Operational work waits for the application to seal.
    await self._executor.app.state.lifecycle_manager.await_sealed()
    logger.info("Discord gateway worker running (cadence %ds)", self._poll)
    while not self._stop.is_set():
      try:
        while await self._executor.deliver_next():
          if self._stop.is_set():
            break
      except Exception as e:
        logger.error("Discord gateway worker pass failed: %s", e)
      try:
        await asyncio.wait_for(self._stop.wait(), timeout=self._poll)
      except asyncio.TimeoutError:
        pass
    logger.info("Discord gateway worker stopped")
