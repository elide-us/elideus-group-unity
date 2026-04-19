import logging

from dataclasses import dataclass, field
from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule

logger = logging.getLogger(__name__.split('.')[-1])

@dataclass
class DBRequest:
  op: str
  params: dict[str, Any] = field(default_factory=dict)

# ----------------------------------------------------------------------------
# DatabaseOperationsModule
# ----------------------------------------------------------------------------
# Named-operation dispatch over the execution layer.
#
# Callers submit a `DBRequest(op, params)` — `op` is a short human-readable
# name registered in `service_database_operations`; `params` is a dict whose
# values are bound positionally to the resolved SQL. The module looks the
# op name up in an in-memory cache and dispatches the cached SQL through
# `DatabaseExecutionModule`. On cache miss the row is lazy-loaded by
# natural-key seek against the UQ_sdo_op unique constraint.
#
# The SQL text itself is chosen per active provider — the startup match on
# SQL_PROVIDER fixes `_query_column` to one of `pub_query_mssql`,
# `pub_query_postgres`, or `pub_query_mysql`. Callers never see which
# variant ran.
#
# -- Contract ----------------------------------------------------------------
#   query(DBRequest)   -> parsed JSON (dict | list) | None
#   execute(DBRequest) -> rowcount (int) | None
#   flush()            -> clears entire registry cache
#
# A return of `None` from `query`/`execute` means the op name did not
# resolve — either unknown, or its row has no SQL for the active provider.
# Successful execution of a query that returns no rows yields whatever the
# provider returns for empty `FOR JSON PATH` (typically `None`); callers
# cannot distinguish "no rows" from "unknown op" on `query`. On `execute`,
# the distinction is `None` (unknown op) vs `0` (op ran, no rows affected).
#
# -- Dependencies ------------------------------------------------------------
#   EnvironmentVariablesModule — reads SQL_PROVIDER to select the query column.
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# -- Typical Access Pattern --------------------------------------------------
# Application modules and RPC handlers call this module; bootstrap-phase
# modules call `DatabaseExecutionModule` directly and do not use this layer.
#
#   ```mermaid
#   sequenceDiagram
#     participant Caller
#     participant Ops as DatabaseOperationsModule
#     participant Cache as registry cache
#     participant Exec as DatabaseExecutionModule
#
#     Caller->>Ops: query(DBRequest("user_by_guid", {"guid": g}))
#     Ops->>Cache: lookup by pub_op
#     alt cache hit
#       Cache-->>Ops: {query: "..."}
#     else cache miss
#       Ops->>Exec: query(lookup_sql, (op,))
#       Exec-->>Ops: {query: "..."}
#       Ops->>Cache: store
#     end
#     Ops->>Exec: query(resolved_sql, (g,))
#     Exec-->>Ops: parsed JSON
#     Ops-->>Caller: parsed JSON
#   ```
#
# ----------------------------------------------------------------------------

class DatabaseOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._registry: dict[str, str] = {}
    self._db: DatabaseExecutionModule | None = None
    self._query_column: str | None = None

  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_sealed()

    env = self.get_module(EnvironmentVariablesModule)

    match env.get("SQL_PROVIDER"):
      case "AZURE_SQL_CONNECTION_STRING":
        self._query_column = "pub_query_mssql"
      case "POSTGRESQL_CONNECTION_STRING":
        self._query_column = "pub_query_postgres"
      case "MYSQL_CONNECTION_STRING":
        self._query_column = "pub_query_mysql"
      case _:
        logger.error("Unknown provider")
        return

    bootstrap_sql = f"""
      SELECT pub_op, {self._query_column} AS query
      FROM service_database_operations
      WHERE pub_bootstrap = 1 AND {self._query_column} IS NOT NULL
      FOR JSON PATH;
    """
    raw = await self._db.query(bootstrap_sql)
    if raw is None:
      logger.info("No operations found (empty or unseeded)")
      self.raise_seal()
      return

    ops = raw if isinstance(raw, list) else [raw]
    for entry in ops:
      self._registry[entry["pub_op"]] = entry["query"]

    logger.info("Loaded %d operations", len(self._registry))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._registry.clear()

  async def _load_op(self, op: str) -> str | None:
    sql = f"""
      SELECT {self._query_column} AS query
      FROM service_database_operations
      WHERE pub_op = ?
      AND {self._query_column} IS NOT NULL
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    """
    raw = await self._db.query(sql, (op,))
    if raw is None:
      logger.error("Unable to load op '%s'", op)
      return None
    self._registry[op] = raw["query"]
    return self._registry[op]

  def _flush(self, op: str):
    removed = self._registry.pop(op, None)
    if removed:
      logger.info("Flushed op '%s'", op)

  async def query(self, request: DBRequest) -> Any:
    sql = self._registry.get(request.op)
    if sql is None:
      sql = await self._load_op(request.op)
      if sql is None:
        logger.error("Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.query(sql, params)

  async def execute(self, request: DBRequest) -> int | None:
    sql = self._registry.get(request.op)
    if sql is None:
      sql = await self._load_op(request.op)
      if sql is None:
        logger.error("Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.execute(sql, params)

  def flush(self):
    self._registry.clear()
    logger.info("Registry cache flushed")