import logging

from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_module import DatabaseExecutionModule
from server.helpers import discover_classes
from .database_execution_providers import ComposedDatabaseManagementProvider, BaseDatabaseManagementWorker

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseManagementModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._mgmt_provider: ComposedDatabaseManagementProvider | None = None
    self._worker: BaseDatabaseManagementWorker | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()

    exec_mod = self.get_module(DatabaseExecutionModule)
    await exec_mod.await_ready()

    base = exec_mod.get_primary_provider()
    if base is None:
      logger.error("No base provider available")
      return

    providers = discover_classes(f"{__package__}.database_execution_providers", "_provider")
    workers = discover_classes(f"{__package__}.database_execution_providers", "_worker")

    match env.get("SQL_PROVIDER"):
      case "AZURE_SQL_CONNECTION_STRING":
        self._mgmt_provider = providers["mssql_management_provider"](base)
        self._worker = workers["mssql_management_worker"]()
      case _:
        logger.error("Unknown provider")
        return

    await self._worker.start()
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    if self._worker is not None:
      await self._worker.stop()

  async def shutdown(self):
    self._worker = None
    self._mgmt_provider = None