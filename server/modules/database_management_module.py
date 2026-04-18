import asyncio, logging

from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_module import DatabaseExecutionModule
from .system_configuration_module import SystemConfigurationModule
from .database_execution_providers import DatabaseManagementProvider

logger = logging.getLogger(__name__.split('.')[-1])

class DatabaseManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._mgmt_provider: DatabaseManagementProvider | None = None
    self._loop_task: asyncio.Task | None = None
    self._loop_stop: asyncio.Event = asyncio.Event()
    self._poll_rate: float = 5.0

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_ready()

    exec_mod = self.get_module(DatabaseExecutionModule)
    await exec_mod.on_ready()

    cfg = self.get_module(SystemConfigurationModule)
    await cfg.on_ready()

    rate_str = cfg.get("TaskDdlPollRate")
    if rate_str is not None:
      self._poll_rate = float(rate_str)

    base = exec_mod.get_base_provider()
    if base is None:
      logger.error("No base provider available")
      return

    match env.get("SQL_PROVIDER"):
      case "AZURE_SQL_CONNECTION_STRING":
        from .database_execution_providers.mssql_management_provider import MssqlManagementProvider
        self._mgmt_provider = MssqlManagementProvider(base)
      case _:
        logger.error("Unknown provider")
        return

    self.mark_ready()

  async def on_seal(self):
    await super().on_seal()
    self._loop_task = asyncio.create_task(self._monitor_loop())

  async def on_drain(self):
    self._loop_stop.set()
    if self._loop_task is not None:
      await self._loop_task
      self._loop_task = None

  async def shutdown(self):
    self._mgmt_provider = None

  async def _monitor_loop(self):
    logger.info("Monitor loop started (rate=%.2fs)", self._poll_rate)
    while not self._loop_stop.is_set():
      try:
        await self._process_pending_tasks()
      except Exception as e:
        logger.error("Loop iteration error: %s", e)
      try:
        await asyncio.wait_for(self._loop_stop.wait(), timeout=self._poll_rate)
      except asyncio.TimeoutError:
        pass
    logger.info("Monitor loop stopped")

  async def _process_pending_tasks(self):
    pass