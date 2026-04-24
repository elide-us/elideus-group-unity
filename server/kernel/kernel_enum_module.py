import logging

from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelEnumModule
# ----------------------------------------------------------------------------
# Enumeration lookup backed by `service_enums`.
#
# The `service_enums` table is the definitive record of valid values for
# categorical fields. Other tables reference it by FK for referential
# integrity; `pub_value` is a sequencing number, not a performance
# optimization — callers pass names, not numbers.
#
# This module loads the full table at startup and exposes a single
# synchronous accessor. Additional access patterns are not provided
# until a concrete caller needs them.
#
# -- Contract ----------------------------------------------------------------
#   get(enum_type: str, name: str) -> int | None     [sync, cache-only]
#     Returns the pub_value for the given type+name, or None if not found.
#
#   flush() -> None
#     Clears the in-memory cache. The next module restart repopulates it.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseExecutionModule — all SQL goes through its contract.
#
# ----------------------------------------------------------------------------

class KernelEnumModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[tuple[str, str], int] = {}
    self._db: DatabaseExecutionModule | None = None

  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_sealed()

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
    for row in rows:
      self._cache[(row["pub_enum_type"], row["pub_name"])] = row["pub_value"]

    logger.info("Loaded %d enum entries", len(self._cache))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def get(self, enum_type: str, name: str) -> int | None:
    value = self._cache.get((enum_type, name))
    if value is None:
      logger.warning("Enum '%s.%s' not in cache", enum_type, name)
      return None
    return value

  def flush(self):
    self._cache.clear()
    logger.info("Cache flushed")
