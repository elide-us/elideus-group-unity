import logging, uuid

from dataclasses import dataclass, field
from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid

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
# values are bound positionally to the resolved SQL. The module resolves the
# op name to a deterministic GUID, looks the GUID up in an in-memory cache,
# and dispatches the cached SQL through `DatabaseExecutionModule`. On cache
# miss the row is lazy-loaded from the ops table by PK seek.
#
# The SQL text itself is chosen per active provider — the startup match on
# SQL_PROVIDER fixes `_query_column` to one of `pub_query_mssql`,
# `pub_query_postgres`, or `pub_query_mysql`. Callers never see which
# variant ran.
#
# This module is the canonical reference pattern for bootstrap-phase
# registry modules: deterministic-GUID key, bootstrap SELECT with
# `FOR JSON PATH`, in-memory cache, PK-seek lazy load on miss, private
# `_flush(op)` and public `flush()` for invalidation.
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
#   EnvironmentVariablesModule — reads NS_HASH for GUID derivation and
#   SQL_PROVIDER to select the query column.
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
#     Ops->>Ops: _op_guid("user_by_guid")
#     Ops->>Cache: lookup
#     alt cache hit
#       Cache-->>Ops: {query: "..."}
#     else cache miss
#       Ops->>Exec: query(lookup_sql, (guid,))
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
    self._registry: dict[str, dict[str, Any]] = {}
    self._ns_hash: uuid.UUID | None = None
    self._db: DatabaseExecutionModule | None = None

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass
  
  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_ready()

    env = self.get_module(EnvironmentVariablesModule)

    ns = env.get("NS_HASH")
    if ns is None:
        logger.error("NS_HASH not set")
        return
    self._ns_hash = uuid.UUID(ns)

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
      self.mark_ready()
      return

    ops = raw if isinstance(raw, list) else [raw]
    for entry in ops:
      guid = self._op_guid(entry["pub_op"])
      self._registry[guid] = {"query": entry["query"]}

    logger.info("Loaded %d operations", len(self._registry))
    self.mark_ready()



  async def shutdown(self):
    self._registry.clear()

  def _op_guid(self, op: str) -> str:
    return deterministic_guid(self._ns_hash, "database_operation", op)

  async def _load_op(self, guid: str) -> dict[str, Any] | None:
    sql = f"""
      SELECT {self._query_column} AS query
      FROM service_database_operations
      WHERE key_guid = ?
      AND {self._query_column} IS NOT NULL
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    """
    raw = await self._db.query(sql, (guid,))
    if raw is None:
      logger.error("Unable to load query by key '%s'", guid)
      return None
    self._registry[guid] = {"query": raw["query"]}
    return self._registry[guid]

  def _flush(self, op: str):
    guid = self._op_guid(op)
    removed = self._registry.pop(guid, None)
    if removed:
      logger.info("Flushed op '%s'", op)

  async def query(self, request: DBRequest) -> Any:
    guid = self._op_guid(request.op)
    entry = self._registry.get(guid)
    if entry is None:
      entry = await self._load_op(guid)
      if entry is None:
        logger.error("Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.query(entry["query"], params)

  async def execute(self, request: DBRequest) -> int | None:
    guid = self._op_guid(request.op)
    entry = self._registry.get(guid)
    if entry is None:
      entry = await self._load_op(guid)
      if entry is None:
        logger.error("Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.execute(entry["query"], params)

  def flush(self):
    self._registry.clear()
    logger.info("Registry cache flushed")
      