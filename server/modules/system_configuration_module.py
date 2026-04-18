import logging, uuid

from typing import Any
from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from .environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# [ServiceConfigurationModule]
# ----------------------------------------------------------------------------
# Key/value configuration lookup backed by `service_configuration`.
#
# Bootstrap-phase registry module. Loads ALL config rows at startup into
# an in-memory cache. All access is synchronous against the cache — config
# values are critical path and must be available without async overhead.
#
# Config keys are deterministic:
#   uuid5(NS_HASH, "service_configuration:{pub_key}")
#
# -- Contract ----------------------------------------------------------------
#   get(key: str) -> str | None                          [sync, cache-only]
#     Returns the pub_value for the given pub_key, or None if not found.
#     A None return means the key was never seeded — this is a code error,
#     not a runtime condition.
#
#   get_all() -> dict[str, str]                          [sync, cache-only]
#     Returns a copy of the full cache as {pub_key: pub_value}.
#
#   flush() -> None
#     Clears the in-memory cache.
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
#     participant Cfg as [ServiceConfigurationModule]
#     participant Cache as config cache
#
#     Caller->>Cfg: get("StorageCacheTime")
#     Cfg->>Cfg: _key_guid("StorageCacheTime")
#     Cfg->>Cache: lookup
#     Cache-->>Cfg: {key, value}
#     Cfg-->>Caller: "300"
#   ```
#
# No lazy-load path. If a key is missing from the cache it was not seeded.
# This is deliberate: config must be fully loaded at startup so callers
# can depend on synchronous access without async overhead.
#
# ----------------------------------------------------------------------------

class SystemConfigurationModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[str, dict[str, Any]] = {}
    self._ns_hash: uuid.UUID | None = None

  async def startup(self):
    env = self.get_module(EnvironmentVariablesModule)
    await env.on_sealed()

    db = self.get_module(DatabaseExecutionModule)
    await db.on_sealed()

    ns = env.get("NS_HASH")
    if ns is None:
      logger.error("NS_HASH not set")
      return
    self._ns_hash = uuid.UUID(ns)

    bootstrap_sql = """
      SELECT key_guid, pub_key, pub_value
      FROM system_configuration
      FOR JSON PATH;
    """
    raw = await db.query(bootstrap_sql)
    if raw is None:
      logger.warning("No config rows (empty table)")
      self.raise_seal()
      return

    rows = raw if isinstance(raw, list) else [raw]
    for entry in rows:
      self._cache[entry["key_guid"]] = {
        "key": entry["pub_key"],
        "value": entry.get("pub_value")
      }

    logger.info("Loaded %d config entries", len(self._cache))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def _key_guid(self, key: str) -> str:
    return deterministic_guid(self._ns_hash, "system_configuration", key)

  def get(self, key: str) -> str | None:
    guid = self._key_guid(key)
    entry = self._cache.get(guid)
    if entry is not None:
      return entry["value"]
    logger.warning("Key '%s' not in cache", key)
    return None

  def get_all(self) -> dict[str, str]:
    return {e["key"]: e["value"] for e in self._cache.values()}

  def flush(self):
    self._cache.clear()
    logger.info("Cache flushed")