import logging

from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelConfigurationModule
# ----------------------------------------------------------------------------
# Key/value configuration lookup backed by `system_configuration`.
#
# Bootstrap-phase registry module. Loads ALL config rows at startup into
# an in-memory cache keyed by pub_key. All access is synchronous against
# the cache — config values are critical path and must be available
# without async overhead.
#
# No lazy-load path. If a key is missing from the cache it was not seeded.
# This is deliberate: config must be fully loaded at startup so callers
# can depend on synchronous access without async overhead. Module restart
# recaches the whole table.
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
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# ----------------------------------------------------------------------------

class KernelConfigurationModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[str, str | None] = {}

  async def startup(self):
    db = self.get_module(DatabaseExecutionModule)
    await db.on_sealed()

    bootstrap_sql = """
      SELECT pub_key, pub_value
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
      self._cache[entry["pub_key"]] = entry.get("pub_value")

    logger.info("Loaded %d config entries", len(self._cache))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def get(self, key: str) -> str | None:
    if key in self._cache:
      return self._cache[key]
    logger.warning("Key '%s' not in cache", key)
    return None

  def get_all(self) -> dict[str, str | None]:
    return dict(self._cache)

  def flush(self):
    self._cache.clear()
    logger.info("Cache flushed")