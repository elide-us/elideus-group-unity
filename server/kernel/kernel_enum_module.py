import logging, uuid
from enum import IntEnum

from fastapi import FastAPI

from . import BaseModule, SecurityContext, kernel_context
from .database_operations_module import DatabaseOperationsModule, DBRequest
from .environment_variables_module import EnvironmentVariablesModule
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
# table FK'd to the header. This module loads the full join at startup,
# through the operation db:contracts:enums:read_all:1 under the kernel
# context (rows pub_name, cpe_members), and constructs one IntEnum class per
# type via Python's functional API.
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
#   flush(context: SecurityContext) -> None
#     Clears the in-memory cache. The next module restart repopulates it.
#     The context is the unit of work that asked (an RPC target).
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule — the read goes through a named operation.
#   EnvironmentVariablesModule — NS_HASH and the hostname derive the kernel
#     context.
#
# ----------------------------------------------------------------------------

# The enum operation this module dispatches (a kernel-owned bootstrap row).
READ_ALL = "db:contracts:enums:read_all:1"


class KernelEnumModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._cache: dict[str, type[IntEnum]] = {}
    self._database: DatabaseOperationsModule | None = None

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    kernel = kernel_context(uuid.UUID(env.get("NS_HASH")), env.get_hostname())

    raw = await self._database.query(DBRequest(READ_ALL, {}, kernel))
    if raw is None:
      logger.warning("No enum types found (empty tables)")
      self.raise_ready()
      return

    rows = raw if isinstance(raw, list) else [raw]
    for row in rows:
      type_name = row["pub_name"]
      # A type with no members has no cpe_members key: the nested FOR JSON
      # returns NULL and the key is omitted.
      members = row.get("cpe_members")
      if not members:
        logger.warning("Enum type '%s' has no members; no class constructed", type_name)
        continue
      self._cache[type_name] = IntEnum(
        snake_to_pascal(type_name),
        {m["pub_name"]: int(m["pub_value"]) for m in members}
      )

    logger.info("Loaded %d enum classes (%d total members)",
                len(self._cache),
                sum(len(c) for c in self._cache.values()))
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._cache.clear()
    self._database = None

  def get(self, enum_type: str) -> type[IntEnum] | None:
    cls = self._cache.get(enum_type)
    if cls is None:
      logger.warning("Enum type '%s' not in cache", enum_type)
      return None
    return cls

  def flush(self, context: SecurityContext) -> None:
    self._cache.clear()
    logger.info("Cache flushed")
