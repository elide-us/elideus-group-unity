import asyncio, logging

from .. import BaseWorker, ModuleManager
from . import DatabaseManagementProvider

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseManagementWorker(BaseWorker):
  def __init__(self, module_manager: ModuleManager, provider: DatabaseManagementProvider, poll_rate: float):
    self._module_manager = module_manager
    self._provider = provider
    self._poll_rate = poll_rate
    self._loop_task: asyncio.Task | None = None
    self._loop_stop: asyncio.Event = asyncio.Event()

  async def start(self) -> None:
    self._loop_task = asyncio.create_task(self._monitor_loop())

  async def stop(self) -> None:
    self._loop_stop.set()
    if self._loop_task is not None:
      await self._loop_task
      self._loop_task = None

  async def _monitor_loop(self):
    await self._module_manager.on_sealed()
    recovered = await self._provider.recover_stale_claims()
    if recovered:
      logger.info("Recovered %d stale claims", recovered)
    logger.info("Worker loop started (rate=%.2fs)", self._poll_rate)
    while not self._loop_stop.is_set():
      try:
        await self._drain_pending()
      except Exception as e:
        logger.error("Loop iteration error: %s", e)
      try:
        await asyncio.wait_for(self._loop_stop.wait(), timeout=self._poll_rate)
      except asyncio.TimeoutError:
        pass
    logger.info("Worker loop stopped")

  async def _drain_pending(self):
    while not self._loop_stop.is_set():
      claim = await self._provider.claim_next_task()
      if claim is None:
        return
      await self._dispatch(claim)

  async def _dispatch(self, claim):
    # Resolve claim.action_guid through reflection_rpc_functions and invoke
    # the bound provider method with claim.payload. Apply disposition
    # semantics (retry on failure if retryable, rollback if reversible).
    # Full dispatch logic specified in docs/database_management.md.
    pass
