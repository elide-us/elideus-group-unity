import logging

from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_connection_providers import BaseDatabaseProvider


class DatabaseExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._provider: BaseDatabaseProvider | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_ready()

    provider_name = env.get("SQL_PROVIDER")
    if provider_name is None:
      logging.error("Environment variable: 'SQL_PROVIDER' is not present.")
      return
    
    if not provider_name:
      logging.error("Environment Variable: 'SQL_PROVIDER' is not set. You must configure one database provider.")
      return

    if provider_name == "AZURE_SQL_CONNECTION_STRING":
      from .database_connection_providers.mssql_provider import MssqlProvider
      dsn = env.get(provider_name)
      if dsn is None:
        logging.error("DatabaseExecutionModule: %s not available", provider_name)
        return
      self._provider = MssqlProvider(dsn)

    # elif provider_name == "POSTGRESQL_CONNECTION_STRING":
    #   from .database_connection_providers.postgres_provider import PostgresProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = PostgresProvider(dsn)

    # elif provider_name == "MYSQL_CONNECTION_STRING":
    #   from .database_connection_providers.mysql_provider import MysqlProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = MysqlProvider(dsn)

    else:
      logging.error("DatabaseExecutionModule: Unknown provider '%s'", provider_name)
      return

    await self._provider.connect()
    self.mark_ready()

  async def shutdown(self):
    if self._provider:
      await self._provider.disconnect()
      self._provider = None
  
  async def query(self, query: str, params: tuple | None = None) -> Any:
    if self._provider is None:
      logging.error("DatabaseExecutionModule: No active provider")
      return None
    return await self._provider.query(query, params)

  async def execute(self, query: str, params: tuple | None = None) -> int:
    if self._provider is None:
      logging.error("DatabaseExecutionModule: No active provider")
      return 0
    return await self._provider.execute(query, params)
  