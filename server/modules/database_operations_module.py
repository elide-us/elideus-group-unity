import logging, uuid

from dataclasses import dataclass, field
from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule
from helpers import deterministic_guid

## STATUS: Work in Progress - bootstrap, query lookup, op type dropped, replace request with query and execute interfaces for provider

@dataclass
class DBRequest:
  op: str
  params: dict[str, Any] = field(default_factory=dict)


class DatabaseOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._registry: dict[str, dict[str, Any]] = {}
    self._ns_hash: uuid.UUID | None = None
    self._db: DatabaseExecutionModule | None = None

  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_ready()

    env = self.get_module(EnvironmentVariablesModule)

    ns = env.get("NS_HASH")
    if ns is None:
        logging.error("DatabaseOperationsModule: NS_HASH not set")
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
        logging.error("DatabaseOperationsModule: Unknown provider")
        return

    bootstrap_sql = f"""
      SELECT pub_op, {self._query_column} AS query
      FROM service_database_operations
      WHERE pub_bootstrap = 1 AND {self._query_column} IS NOT NULL
      FOR JSON PATH;
    """
    raw = await self._db.query(bootstrap_sql)
    if raw is None:
      logging.error("DatabaseOperationsModule: Failed to load ops registry")
      return

    ops = raw if isinstance(raw, list) else [raw]
    for entry in ops:
      guid = self._op_guid(entry["pub_op"])
      self._registry[guid] = {"query": entry["query"]}

    logging.info("DatabaseOperationsModule: Loaded %d operations", len(self._registry))
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
      logging.error("DatabaseOperationsModule: Unable to load query by key '%s'", guid)
      return None
    self._registry[guid] = {"query": raw["query"]}
    return self._registry[guid]

  def _flush(self, op: str):
    guid = self._op_guid(op)
    removed = self._registry.pop(guid, None)
    if removed:
      logging.info("DatabaseOperationsModule: Flushed op '%s'", op)

  async def query(self, request: DBRequest) -> Any:
    guid = self._op_guid(request.op)
    entry = self._registry.get(guid)
    if entry is None:
      entry = await self._load_op(guid)
      if entry is None:
        logging.error("DatabaseOperationsModule: Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.query(entry["query"], params)

  async def execute(self, request: DBRequest) -> int | None:
    guid = self._op_guid(request.op)
    entry = self._registry.get(guid)
    if entry is None:
      entry = await self._load_op(guid)
      if entry is None:
        logging.error("DatabaseOperationsModule: Unknown op '%s'", request.op)
        return None
    params = tuple(request.params.values()) if request.params else ()
    return await self._db.execute(entry["query"], params)

  def flush(self):
    self._registry.clear()
    logging.info("DatabaseOperationsModule: Registry cache flushed")
      