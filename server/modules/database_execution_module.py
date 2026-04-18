import logging

from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_providers import DatabaseTransactionProvider

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# DatabaseExecutionModule
# ----------------------------------------------------------------------------
# Provider-agnostic SQL execution.
#
# Selects one concrete database provider at startup based on the SQL_PROVIDER
# environment variable, opens its connection pool, and exposes two methods —
# `query` and `execute` — that route through the `BaseDatabaseProvider`
# contract. Callers above this layer never import or reference a provider
# class directly; the provider is an implementation detail of this module.
#
# This module is the single point of coupling between the provider contract
# and a concrete implementation. Adding a new database backend means: write
# a `BaseDatabaseProvider` subclass, add a branch to the match in `startup()`.
#
# -- Contract ----------------------------------------------------------------
#   query(sql, params)   -> parsed JSON (dict | list) | None
#   execute(sql, params) -> rowcount (int)
#
# `query` returns parsed JSON because every provider is required to run
# SELECTs as `FOR JSON PATH` and return the parsed structure. `execute`
# returns rowcount as a success code; this is not nullable.
#
# -- Dependencies ------------------------------------------------------------
#   EnvironmentVariablesModule — reads SQL_PROVIDER and the DSN env var that
#   SQL_PROVIDER names.
#
# -- Typical Access Pattern --------------------------------------------------
# `DatabaseOperationsModule` is the canonical caller.
#
#   ```mermaid
#   sequenceDiagram
#     participant Ops as DatabaseOperationsModule
#     participant Exec as DatabaseExecutionModule
#     participant Prov as BaseDatabaseProvider
#     participant Impl as MssqlProvider
#
#     Ops->>Exec: query(sql, params)
#     Exec->>Prov: query(sql, params)
#     Prov->>Impl: query(sql, params)
#     Impl-->>Prov: parsed JSON
#     Prov-->>Exec: parsed JSON
#     Exec-->>Ops: parsed JSON
#   ```
# Bootstrap-phase modules directly access this module during startup for a 
# pre-cache of filtered bootstrapping queries.
#
# ----------------------------------------------------------------------------

class DatabaseExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._provider: DatabaseTransactionProvider | None = None

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass
  
  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    provider_name = env.get("SQL_PROVIDER")
    if provider_name is None:
      logger.error("Variable '%s' is not present.", provider_name)
      return
    
    if not provider_name:
      logger.error("Variable '%s' is not set. You must configure one database provider.", provider_name)
      return

    if provider_name == "AZURE_SQL_CONNECTION_STRING":
      from .database_execution_providers.mssql_transaction_provider import MssqlProvider
      dsn = env.get(provider_name)
      if dsn is None:
        logger.error("Provider '%s' not available", provider_name)
        return
      self._provider = MssqlProvider(dsn)

    # elif provider_name == "POSTGRESQL_CONNECTION_STRING":
    #   from .database_execution_providers.postgres_provider import PostgresProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = PostgresProvider(dsn)

    # elif provider_name == "MYSQL_CONNECTION_STRING":
    #   from .database_execution_providers.mysql_provider import MysqlProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = MysqlProvider(dsn)

    else:
      logger.error("Unknown provider '%s'", provider_name)
      return

    await self._provider.connect()
    self.raise_seal()

  async def shutdown(self):
    if self._provider:
      await self._provider.disconnect()
      self._provider = None
  
  async def query(self, query: str, params: tuple | None = None) -> Any:
    if self._provider is None:
      logger.error("No active provider")
      return None
    return await self._provider.query(query, params)

  async def execute(self, query: str, params: tuple | None = None) -> int:
    if self._provider is None:
      logger.error("No active provider")
      return 0
    return await self._provider.execute(query, params)
  
  def get_base_provider(self) -> DatabaseTransactionProvider | None:
    if self._provider is None:
      logger.error("No active provider")
      return None
    return self._provider
  