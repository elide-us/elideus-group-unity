import logging

from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_module import DatabaseExecutionModule
from .database_execution_providers import BaseDatabaseManagementProvider, BaseDatabaseManagementWorker

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._mgmt_provider: BaseDatabaseManagementProvider | None = None
    self._worker: BaseDatabaseManagementWorker | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    exec_mod = self.get_module(DatabaseExecutionModule)
    await exec_mod.on_sealed()

    base = exec_mod.get_base_provider()
    if base is None:
      logger.error("No base provider available")
      return

    match env.get("SQL_PROVIDER"):
      case "AZURE_SQL_CONNECTION_STRING":
        from .database_execution_providers.mssql_management_provider import MssqlManagementProvider
        self._mgmt_provider = MssqlManagementProvider(base)
        self._worker = BaseDatabaseManagementWorker()
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