import asyncio, logging

from server.kernel.host_execution_providers import BaseKernelHostWorker

logger = logging.getLogger(__name__.split('.')[-1])


class AcaTransactionWorker(BaseKernelHostWorker):
  def __init__(self, executor, cadence_seconds: int):
    # Seconds between passes (one heartbeat and one read of the process's own
    # row): the host_heartbeat_seconds configuration row. Must stay well
    # inside the stale grace period, or a live host is swept STOPPED.
    self._executor = executor
    self._cadence = cadence_seconds
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
    logger.info("Host worker running (cadence %ds)", self._cadence)
    while not self._stop.is_set():
      try:
        if not await self._executor.observe():
          break
      except Exception as e:
        logger.error("Host worker pass failed: %s", e)
      try:
        await asyncio.wait_for(self._stop.wait(), timeout=self._cadence)
      except asyncio.TimeoutError:
        pass
    logger.info("Host worker stopped")
