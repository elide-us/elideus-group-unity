import asyncio, logging

from . import BaseWorkflowTaskWorker

logger = logging.getLogger(__name__.split('.')[-1])

# Seconds the loop sleeps when it finds the queue empty. A backlog runs at
# full speed: the cadence gates only the empty queue.
POLL_SECONDS = 5


class WorkflowTaskWorker(BaseWorkflowTaskWorker):
  def __init__(self, executor):
    self._executor = executor
    self._stop = asyncio.Event()
    self._task: asyncio.Task | None = None

  async def start(self) -> None:
    self._stop.clear()
    self._task = asyncio.create_task(self._run())

  async def stop(self) -> None:
    self._stop.set()
    if self._task is not None:
      await self._task
      self._task = None

  async def _run(self) -> None:
    # Operational work waits for the application to seal.
    await self._executor.module_manager.await_sealed()
    logger.info("Workflow worker running (cadence %ds)", POLL_SECONDS)
    while not self._stop.is_set():
      try:
        while await self._executor.run_once():
          if self._stop.is_set():
            break
      except Exception as e:
        logger.error("Workflow worker pass failed: %s", e)
      try:
        await asyncio.wait_for(self._stop.wait(), timeout=POLL_SECONDS)
      except asyncio.TimeoutError:
        pass
    logger.info("Workflow worker stopped")
