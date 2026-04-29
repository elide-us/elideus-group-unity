import logging
from enum import IntEnum

from fastapi import FastAPI

from . import BaseModule
from .database_execution_module import DatabaseExecutionModule
from server.helpers import snake_to_pascal

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelEnumModule
# ----------------------------------------------------------------------------
# Enumeration lookup backed by the contracts_primitives_enum_types (header)
# and contracts_primitives_enums (line) tables.
#
# Each enum type is a row in the header table with a name (e.g.
# "constraint_kind", "schema_source"). Each member is a row in the line
# table FK'd to the header. This module loads the full join at startup
# and constructs one IntEnum class per type via Python's functional API.
#
# The constructed classes are not declared statically anywhere. The
# database is canonical; if code disagrees with the database, code is
# wrong. There is no static class to disagree with.
#
# -- Contract ----------------------------------------------------------------
#   get(enum_type: str) -> type[IntEnum] | None     [sync, cache-only]
#     Returns the IntEnum class for the given type, or None if not found.
#     Caller uses standard IntEnum access on the result:
#       SchemaSource = enum_module.get("schema_source")
#       value = SchemaSource.PRIMARY      # IntEnum member, == int(0)
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
    self._cache: dict[str, type[IntEnum]] = {}
    self._db: DatabaseExecutionModule | None = None

  async def startup(self):
    self._db = self.get_module(DatabaseExecutionModule)
    await self._db.on_sealed()

    bootstrap_sql = """
      SELECT
        et.pub_name AS type_name,
        (
          SELECT e.pub_name AS name, e.pub_value AS value
          FROM contracts_primitives_enums e
          WHERE e.ref_enum_type_guid = et.key_guid
          ORDER BY e.pub_value
          FOR JSON PATH
        ) AS members
      FROM contracts_primitives_enum_types et
      ORDER BY et.pub_name
      FOR JSON PATH;
    """
    raw = await self._db.query(bootstrap_sql)
    if raw is None:
      logger.warning("No enum types found (empty tables)")
      self.raise_seal()
      return

    rows = raw if isinstance(raw, list) else [raw]
    for row in rows:
      type_name = row["type_name"]
      members = row["members"]
      if not members:
        logger.warning("Enum type '%s' has no members; no class constructed", type_name)
        continue
      self._cache[type_name] = IntEnum(
        snake_to_pascal(type_name),
        {m["name"]: int(m["value"]) for m in members}
      )

    logger.info("Loaded %d enum classes (%d total members)",
                len(self._cache),
                sum(len(c) for c in self._cache.values()))
    self.raise_seal()

  async def on_seal(self):
    pass

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._cache.clear()

  def get(self, enum_type: str) -> type[IntEnum] | None:
    cls = self._cache.get(enum_type)
    if cls is None:
      logger.warning("Enum type '%s' not in cache", enum_type)
      return None
    return cls

  def flush(self):
    self._cache.clear()
    logger.info("Cache flushed")