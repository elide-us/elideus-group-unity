import logging

from typing import Any, Awaitable, Callable
from fastapi import FastAPI

from . import AccessDenied, BaseModule, SecurityContext
from .environment_variables_module import EnvironmentVariablesModule
from server.helpers import discover_classes
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
#   query(sql, params, context)   -> parsed JSON (dict | list) | None
#   execute(sql, params, context) -> rowcount (int)
#
# `query` returns parsed JSON because every provider is required to run
# SELECTs as `FOR JSON PATH` and return the parsed structure. `execute`
# returns rowcount as a success code; this is not nullable.
#
# -- The execution gate ------------------------------------------------------
# Every statement runs under a SecurityContext; its key_guid is handed to the
# provider with the statement (nothing is sent to the database for it). A call
# whose context is not a SecurityContext is refused: a denial row (ACCESS,
# NO_CONTEXT, subject the refused method) is written FIRST, then AccessDenied
# is raised. If the denial write fails it is logged and the refusal still
# raises. The writer is on_refuse: its Manager, DatabaseOperationsModule, sets
# it at startup (it resolves db:security:denials:create:1 and writes under the
# kernel context). This module never reaches the layer above it.
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
#     Ops->>Exec: query(sql, params, context)
#     Exec->>Prov: query(sql, params, context.key_guid)
#     Prov->>Impl: query(sql, params, context_guid)
#     Impl-->>Prov: parsed JSON
#     Prov-->>Exec: parsed JSON
#     Exec-->>Ops: parsed JSON
#   ```
# No other module issues statements through this one; DatabaseManagementModule
# borrows the primary provider for the composed management provider.
#
# ----------------------------------------------------------------------------

class DatabaseExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._provider: BaseDatabaseTransactionProvider | None = None
    # The denial writer, set by the Manager at its startup: takes the subject.
    self.on_refuse: Callable[[str], Awaitable[None]] | None = None

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass
  
  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()

    provider_name = env.get("SQL_PROVIDER")
    if provider_name is None:
      logger.error("Variable 'SQL_PROVIDER' is not present.")
      return
    
    if not provider_name:
      logger.error("Variable 'SQL_PROVIDER' is not set. You must configure one database provider.")
      return

    providers = discover_classes(f"{__package__}.database_execution_providers", "_provider")

    if provider_name == "AZURE_SQL_CONNECTION_STRING":
      dsn = env.get(provider_name)
      if dsn is None:
        logger.error("Provider '%s' not available", provider_name)
        return
      self._provider = providers["mssql_transaction_provider"](dsn)

    # elif provider_name == "POSTGRESQL_CONNECTION_STRING":
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = providers["postgres_transaction_provider"](dsn)

    # elif provider_name == "MYSQL_CONNECTION_STRING":
    #   dsn = env.get(provider_name)
    #   if dsn is None:
    #     logging.error("DatabaseConnectionModule: %s not available", provider_name)
    #     return
    #   self._provider = providers["mysql_transaction_provider"](dsn)

    else:
      logger.error("Unknown provider '%s'", provider_name)
      return

    await self._provider.connect()
    self.raise_ready()

  async def shutdown(self):
    if self._provider:
      await self._provider.disconnect()
      self._provider = None
  
  async def query(self, query: str, params: tuple | None, context: SecurityContext) -> Any:
    if not isinstance(context, SecurityContext):
      await self._refuse("DatabaseExecutionModule.query")
    if self._provider is None:
      logger.error("No active provider")
      return None
    return await self._provider.query(query, params, context.key_guid)

  async def execute(self, query: str, params: tuple | None, context: SecurityContext) -> int:
    if not isinstance(context, SecurityContext):
      await self._refuse("DatabaseExecutionModule.execute")
    if self._provider is None:
      logger.error("No active provider")
      return -1
    return await self._provider.execute(query, params, context.key_guid)

  async def _refuse(self, subject: str) -> None:
    # Deny path: the denial row first, then the raise. A missing writer or a
    # failed write is logged; the refusal raises regardless.
    try:
      if self.on_refuse is None:
        raise RuntimeError("no denial writer: the Manager has not started")
      await self.on_refuse(subject)
    except Exception as e:
      logger.error("Denial write failed (ACCESS NO_CONTEXT %s): %s", subject, e)
    raise AccessDenied("ACCESS", "NO_CONTEXT", subject)


  def get_primary_provider(self) -> BaseDatabaseTransactionProvider | None:
    if self._provider is None:
      logger.error("No active provider")
      return None
    return self._provider