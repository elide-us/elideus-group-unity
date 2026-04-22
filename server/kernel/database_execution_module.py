import logging

from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .environment_variables_module import EnvironmentVariablesModule
from .database_execution_providers import BaseDatabaseTransactionProvider

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# DatabaseExecutionModule
# ----------------------------------------------------------------------------
# Provider-agnostic SQL execution.
#
# Selects one concrete database provider at startup based on the SQL_PROVIDER
# environment variable, opens its connection pool, and exposes two methods —
# `query` and `execute` — that route through the `BaseDatabaseTransactionProvider`
# contract. Callers above this layer never import or reference a provider
# class directly; the provider is an implementation detail of this module.
#
# This module is the single point of coupling between the provider contract
# and a concrete implementation. Adding a new database backend means: write
# a `BaseDatabaseTransactionProvider` subclass, add a branch to the match in `startup()`.
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
#     participant Prov as BaseDatabaseTransactionProvider
#     participant Impl as MssqlTransactionProvider
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
    self._provider: BaseDatabaseTransactionProvider | None = None

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass
  
  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    provider_name = env.get("SQL_PROVIDER")
    if provider_name is None:
      logger.error("Variable 'SQL_PROVIDER' is not present.")
      return
    
    if not provider_name:
      logger.error("Variable 'SQL_PROVIDER' is not set. You must configure one database provider.")
      return

    if provider_name == "AZURE_SQL_CONNECTION_STRING":
      from .database_execution_providers.mssql_transaction_provider import MssqlTransactionProvider
      dsn = env.get(provider_name)
      if dsn is None:
        logger.error("Provider '%s' not available", provider_name)
        return
      self._provider = MssqlTransactionProvider(dsn)

    # elif provider_name == "POSTGRESQL_CONNECTION_STRING":
    #   from .database_execution_providers.postgres_transaction_provider import PostgresTransactionProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = PostgresTransactionProvider(dsn)

    # elif provider_name == "MYSQL_CONNECTION_STRING":
    #   from .database_execution_providers.mysql_transaction_provider import MysqlTransactionProvider
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = MysqlTransactionProvider(dsn)

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
      return -1
    return await self._provider.execute(query, params)
  
  def get_base_provider(self) -> BaseDatabaseTransactionProvider | None:
    if self._provider is None:
      logger.error("No active provider")
      return None
    return self._provider