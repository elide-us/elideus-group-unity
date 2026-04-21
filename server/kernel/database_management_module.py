import logging

from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_module import DatabaseExecutionModule
from .system_configuration_module import SystemConfigurationModule
from .database_execution_providers import DatabaseManagementProvider, DatabaseManagementWorker

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._mgmt_provider: DatabaseManagementProvider | None = None
    self._worker: DatabaseManagementWorker | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    exec_mod = self.get_module(DatabaseExecutionModule)
    await exec_mod.on_sealed()

    cfg = self.get_module(SystemConfigurationModule)
    await cfg.on_sealed()

    poll_rate: float = 5.0
    rate_str = cfg.get("TaskDdlPollRate")
    if rate_str is not None:
      poll_rate = float(rate_str)

    base = exec_mod.get_base_provider()
    if base is None:
      logger.error("No base provider available")
      return

    match env.get("SQL_PROVIDER"):
      case "AZURE_SQL_CONNECTION_STRING":
        from .database_execution_providers.mssql_management_provider import MssqlManagementProvider
        self._mgmt_provider = MssqlManagementProvider(base)
        self._worker = DatabaseManagementWorker(self.module_manager, self._mgmt_provider, poll_rate)
      case _:
        logger.error("Unknown provider")
        return

    await self._worker.start()
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    if self._worker is not None:
      await self._worker.stop()

  async def shutdown(self):
    self._worker = None
    self._mgmt_provider = None
    