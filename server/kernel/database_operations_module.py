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
# Callers submit a `DBRequest(op, params)` — `op` is the operation's URN,
# db:<domain>:<subdomain>:<function>:<version>; `params` is a dict whose
# values are bound positionally to the resolved SQL. The module looks the
# op name up in an in-memory cache and dispatches the cached SQL through
# `DatabaseExecutionModule`. On cache miss the row is lazy-loaded by seeking
# the URN registry by the five segments: namespace, domain and subdomain are
# vocabulary rows (etg.contracts_urn_namespaces, _domains, _subdomains, each
# unique on name) and the function row (etg.contracts_urn_functions) composes
# them with its own name and version; the operation row
# (etg.contracts_db_operations) hangs off the function row by
# ref_function_guid. The string is composed from the rows, never stored.
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
#     Caller->>Ops: query(DBRequest("db:security:roles:read_all:1"))
#     Ops->>Cache: lookup by URN
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
    await self._db.await_ready()

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
      SELECT
        CONCAT([cun].[pub_name], N':', [cud].[pub_name], N':', [cus].[pub_name], N':', [cuf].[pub_name], N':', [cuf].[pub_version]) AS [pub_urn],
        [cdo].[{self._query_column}]
      FROM [etg].[contracts_db_operations] AS [cdo]
      JOIN [etg].[contracts_urn_functions] AS [cuf] ON [cuf].[key_guid] = [cdo].[ref_function_guid]
      JOIN [etg].[contracts_urn_namespaces] AS [cun] ON [cun].[key_guid] = [cuf].[ref_namespace_guid]
      JOIN [etg].[contracts_urn_domains] AS [cud] ON [cud].[key_guid] = [cuf].[ref_domain_guid]
      JOIN [etg].[contracts_urn_subdomains] AS [cus] ON [cus].[key_guid] = [cuf].[ref_subdomain_guid]
      WHERE [cdo].[pub_bootstrap_element] = 1
        AND [cdo].[{self._query_column}] IS NOT NULL
      FOR JSON PATH;
    """
    raw = await self._db.query(bootstrap_sql)
    if raw is None:
      logger.info("No operations found (empty or unseeded)")
      self.raise_ready()
      return

    ops = raw if isinstance(raw, list) else [raw]
    for entry in ops:
      self._registry[entry["pub_urn"]] = entry[self._query_column]

    logger.info("Loaded %d operations", len(self._registry))
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._registry.clear()

  async def _load_op(self, op: str) -> str | None:
    # The URN's five segments seek the registry; a segment with no row makes the op unknown.
    segments = op.split(":")
    if len(segments) != 5 or not segments[4].isdigit():
      logger.error("Op '%s' is not a <namespace>:<domain>:<subdomain>:<function>:<version> URN", op)
      return None
    namespace, domain, subdomain, function, version = segments
    sql = f"""
      SELECT
        [cdo].[{self._query_column}]
      FROM [etg].[contracts_db_operations] AS [cdo]
      JOIN [etg].[contracts_urn_functions] AS [cuf] ON [cuf].[key_guid] = [cdo].[ref_function_guid]
      JOIN [etg].[contracts_urn_namespaces] AS [cun] ON [cun].[key_guid] = [cuf].[ref_namespace_guid]
      JOIN [etg].[contracts_urn_domains] AS [cud] ON [cud].[key_guid] = [cuf].[ref_domain_guid]
      JOIN [etg].[contracts_urn_subdomains] AS [cus] ON [cus].[key_guid] = [cuf].[ref_subdomain_guid]
      WHERE [cun].[pub_name] = ?
        AND [cud].[pub_name] = ?
        AND [cus].[pub_name] = ?
        AND [cuf].[pub_name] = ?
        AND [cuf].[pub_version] = ?
        AND [cdo].[{self._query_column}] IS NOT NULL
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    """
    raw = await self._db.query(sql, (namespace, domain, subdomain, function, int(version)))
    if raw is None:
      logger.error("Unable to load op '%s'", op)
      return None
    self._registry[op] = raw[self._query_column]
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