import logging, uuid

from dataclasses import dataclass
from typing import Any
from fastapi import FastAPI

from . import AccessDenied, BaseModule, SecurityContext, kernel_context
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid

logger = logging.getLogger(__name__.split('.')[-1])

# One named-operation request. All three fields are required, in this order;
# there is no default. params is bound positionally in the operation's input
# model order; context is the unit of work the statement runs under.
@dataclass
class DBRequest:
  op: str
  params: dict[str, Any]
  context: SecurityContext

# The denial this gate writes before it raises (a kernel-owned bootstrap row).
DENIALS_CREATE = "db:security:denials:create:1"
# pub_subject is NVARCHAR(256).
SUBJECT_LENGTH = 256


def _subject(value: object) -> str:
  # The column's limit counts UTF-16 units, not code points, and a lone
  # surrogate cannot be bound. The subject is cut to fit and made bindable,
  # so no caller-supplied text can make a denial write fail.
  return str(value).encode("utf-16-le", "replace")[:SUBJECT_LENGTH * 2].decode("utf-16-le", "ignore")

# ----------------------------------------------------------------------------
# DatabaseOperationsModule
# ----------------------------------------------------------------------------
# Named-operation dispatch over the execution layer.
#
# Callers submit a `DBRequest(op, params, context)` — `op` is the operation's
# URN, db:<domain>:<subdomain>:<function>:<version>; `params` is a dict whose
# values are bound positionally to the resolved SQL; `context` is the
# SecurityContext the statement runs under. The module looks the
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
# -- The operations gate -----------------------------------------------------
# A request whose context is not a SecurityContext is refused before the op
# is resolved: a denial row (ACCESS, NO_CONTEXT, subject the op) is written
# FIRST through db:security:denials:create:1 under the kernel context, then
# AccessDenied is raised. If the denial write fails it is logged and the
# refusal still raises. The same writer is handed to the executor at startup
# (on_refuse), so the execution gate records its refusals without reaching
# up to this module. The registry bootstrap and the lazy lookup below are
# the only inline SQL left in the kernel; both run under the kernel context
# (kernel_context(NS_HASH, hostname), derived here, never passed in).
#
# A return of `None` from `query`/`execute` means the op name did not
# resolve — either unknown, or its row has no SQL for the active provider.
# Successful execution of a query that returns no rows yields whatever the
# provider returns for empty `FOR JSON PATH` (typically `None`); callers
# cannot distinguish "no rows" from "unknown op" on `query`. On `execute`,
# the distinction is `None` (unknown op) vs `0` (op ran, no rows affected).
#
# -- Dependencies ------------------------------------------------------------
#   EnvironmentVariablesModule — SQL_PROVIDER selects the query column;
#     NS_HASH and the hostname derive the kernel context.
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# -- Typical Access Pattern --------------------------------------------------
# Every module that reads or writes the database calls this module, the
# bootstrap-phase modules (configuration, enums, host) included.
#
#   ```mermaid
#   sequenceDiagram
#     participant Caller
#     participant Ops as DatabaseOperationsModule
#     participant Cache as registry cache
#     participant Exec as DatabaseExecutionModule
#
#     Caller->>Ops: query(DBRequest("db:security:roles:read_all:1", {}, context))
#     Ops->>Ops: gate: context is a SecurityContext
#     Ops->>Cache: lookup by URN
#     alt cache hit
#       Cache-->>Ops: {query: "..."}
#     else cache miss
#       Ops->>Exec: query(lookup_sql, segments, kernel context)
#       Exec-->>Ops: {query: "..."}
#       Ops->>Cache: store
#     end
#     Ops->>Exec: query(resolved_sql, params, context)
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
    self._namespace: uuid.UUID | None = None
    self._kernel: SecurityContext | None = None

  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.await_ready()

    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._kernel = kernel_context(self._namespace, env.get_hostname())
    self._db.on_refuse = self._write_denial

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
    raw = await self._db.query(bootstrap_sql, None, self._kernel)
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
    raw = await self._db.query(sql, (namespace, domain, subdomain, function, int(version)), self._kernel)
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
    if not isinstance(request.context, SecurityContext):
      await self._refuse(request.op)
    sql = await self._resolve(request.op)
    if sql is None:
      return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.query(sql, params, request.context)

  async def execute(self, request: DBRequest) -> int | None:
    if not isinstance(request.context, SecurityContext):
      await self._refuse(request.op)
    sql = await self._resolve(request.op)
    if sql is None:
      return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.execute(sql, params, request.context)

  async def _resolve(self, op: str) -> str | None:
    sql = self._registry.get(op)
    if sql is None:
      sql = await self._load_op(op)
      if sql is None:
        logger.error("Unknown op '%s'", op)
    return sql

  async def _refuse(self, op: Any) -> None:
    # Deny path: the denial row first, then the raise. A failed write is
    # logged; the refusal raises regardless.
    subject = _subject(op)
    try:
      await self._write_denial(subject)
    except Exception as e:
      logger.error("Denial write failed (ACCESS NO_CONTEXT %s): %s", subject, e)
    raise AccessDenied("ACCESS", "NO_CONTEXT", subject)

  async def _write_denial(self, subject: str) -> None:
    # Straight to the execution layer under the kernel context: never back
    # through the gate, so a refusal cannot recurse.
    if self._kernel is None or self._namespace is None:
      raise RuntimeError("no kernel context: the module has not started")
    sql = await self._resolve(DENIALS_CREATE)
    if sql is None:
      raise RuntimeError("%s is not resolvable" % DENIALS_CREATE)
    # Parameter order is the operation's input model order.
    params = (
      str(uuid.uuid4()).upper(),
      None,
      self._kernel.key_guid,
      deterministic_guid(self._namespace, "contracts_primitives_enums", "security_layer.ACCESS"),
      deterministic_guid(self._namespace, "contracts_primitives_enums", "denial_reason.NO_CONTEXT"),
      self._kernel.ref_host_guid,
      subject,
    )
    affected = await self._db.execute(sql, params, self._kernel)
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (DENIALS_CREATE, affected))

  def flush(self):
    self._registry.clear()
    logger.info("Registry cache flushed")