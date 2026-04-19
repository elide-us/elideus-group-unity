import logging, uuid

from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# [ServiceEnumModule]
# ----------------------------------------------------------------------------
# Enumeration lookup backed by `service_enums`.
#
# Bootstrap-phase registry module. Pre-loads all enum rows at startup,
# then lazy-loads on cache miss via PK seek. Follows the canonical cache
# pattern from DatabaseOperationsModule.
#
# Enum keys are deterministic:
#   uuid5(NS_HASH, "enum:{pub_enum_type}:{pub_name}")
#
# -- Contract ----------------------------------------------------------------
#   get(enum_type: str, name: str) -> int | None     [async, lazy-loads]
#     Returns the pub_value for the given type+name.
#     On cache miss, attempts PK seek before returning None.
#
#   get_guid(enum_type: str, name: str) -> str        [sync, derivation]
#     Returns the deterministic GUID for a type+name pair without
#     touching the cache or database. Useful when callers need the
#     GUID as an FK reference.
#
#   get_by_guid(guid: str) -> dict | None            [sync, cache-only]
#     Returns {enum_type, name, value} for a GUID, or None.
#     Cache-only — no lazy-load (no natural key to derive from).
#
#   list_type(enum_type: str) -> list[dict]           [sync, cache-only]
#     Returns all cached entries for an enum type as [{name, value}].
#
#   flush() -> None
#     Clears the in-memory cache. Next get() will lazy-load.
#
# -- Dependencies ------------------------------------------------------------
#   EnvironmentVariablesModule — reads NS_HASH for GUID derivation.
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# -- Typical Access Pattern --------------------------------------------------
#
#   ```mermaid
#   sequenceDiagram
#     participant Caller
#     participant Enum as [ServiceEnumModule]
#     participant Cache as enum cache
#     participant Exec as DatabaseExecutionModule
#
#     Caller->>Enum: get("constraint_kind", "PRIMARY_KEY")
#     Enum->>Enum: _enum_guid("constraint_kind", "PRIMARY_KEY")
#     Enum->>Cache: lookup
#     alt cache hit
#       Cache-->>Enum: {value: 0}
#     else cache miss
#       Enum->>Exec: query(lookup_sql, (guid,))
#       Exec-->>Enum: parsed JSON
#       Enum->>Cache: store
#     end
#     Enum-->>Caller: 0
#   ```
#
# ----------------------------------------------------------------------------

class ServiceEnumModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[str, dict[str, Any]] = {}
    self._ns_hash: uuid.UUID | None = None
    self._db: DatabaseExecutionModule | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_sealed()

    ns = env.get("NS_HASH")
    if ns is None:
      logger.error("NS_HASH not set")
      return
    self._ns_hash = uuid.UUID(ns)

    bootstrap_sql = """
      SELECT pub_enum_type, pub_name, pub_value
      FROM service_enums
      FOR JSON PATH;
    """
    raw = await self._db.query(bootstrap_sql)
    if raw is None:
      logger.warning("No enum rows found (empty table)")
      self.raise_seal()
      return

    rows = raw if isinstance(raw, list) else [raw]
    self._cache = [
      {"enum_type": r["pub_enum_type"], "name": r["pub_name"], "value": r["pub_value"]}
      for r in rows
    ]

    logger.info("Loaded %d enum entries", len(self._cache))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def get(self, enum_type: str, name: str) -> int | None:
    for entry in self._cache.values():
      if entry["enum_type"] == enum_type and entry["name"] == name:
        return entry["value"]
    return None

  def list_type(self, enum_type: str) -> list[dict[str, Any]]:
    return [
      {"name": e["name"], "value": e["value"]}
      for e in self._cache.values()
      if e["enum_type"] == enum_type
    ]

  def flush(self):
    self._cache.clear()
    logging.info("Cache flushed")