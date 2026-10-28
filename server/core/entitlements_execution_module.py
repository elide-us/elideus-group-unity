import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# EntitlementsExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Entitlements subsystem: owns the entitlements
# catalogue (service_security_entitlements). Entitlements have no provider
# layer: there is no external client and the catalogue never leaves the
# application, so this module dispatches the registry operations itself
# through DatabaseOperationsModule. Every write is one statement the kernel
# commits, so every call is atomic by itself; a write that affects any number
# of rows other than one is an error, raised, never swallowed.
#
# Holds the catalogue in memory, keys new rows by formula (uuid5 over NS_HASH,
# 'service_security_entitlements:<name>'), and reloads the catalogue after
# every write so the cache and the table never disagree.
#
# This is the catalogue, not the assignment: user-to-entitlement mapping is
# another subsystem.
#
# -- Contract ----------------------------------------------------------------
#   entitlements() -> dict[str, dict]                [sync, cache-only]
#   entitlement_guid(name: str) -> str | None        [sync, cache-only]
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#     Unknown name raises KeyError; duplicate name on create raises ValueError.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
# ----------------------------------------------------------------------------

TABLE = "service_security_entitlements"

# The registry operations this module dispatches (core-owned rows).
READ_ALL = "db:security:entitlements:read_all:1"
CREATE = "db:security:entitlements:create:1"
UPDATE = "db:security:entitlements:update:1"
DELETE = "db:security:entitlements:delete:1"


class EntitlementsExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._namespace: uuid.UUID | None = None
    self._entitlements: dict[str, dict] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    await self._reload()
    self.raise_ready()

  async def _reload(self):
    self._entitlements = {row["pub_name"]: row for row in await self._rows(READ_ALL)}
    if self._entitlements:
      logger.info("Loaded %d entitlements", len(self._entitlements))
    else:
      logger.warning("No entitlements loaded (empty table or operation not found)")

  def entitlements(self) -> dict[str, dict]:
    return self._entitlements

  def entitlement_guid(self, name: str) -> str | None:
    row = self._entitlements.get(name)
    return row["key_guid"] if row else None

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    if name in self._entitlements:
      raise ValueError("entitlement '%s' already exists" % name)
    key_guid = deterministic_guid(self._namespace, TABLE, name)
    # Parameter order is the operation's input model order.
    await self._one(CREATE, {
      "key_guid": key_guid,
      "ref_package_guid": package_guid,
      "pub_name": name,
      "pub_display": display,
      "pub_notes": notes,
    })
    await self._reload()
    logger.info("Created entitlement '%s' (%s)", name, key_guid)
    return key_guid

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    row = self._entitlements.get(name)
    if row is None:
      raise KeyError("entitlement '%s' not found" % name)
    await self._one(UPDATE, {
      "pub_display": row["pub_display"] if display is None else display,
      "pub_notes": row.get("pub_notes") if notes is None else notes,
      "key_guid": row["key_guid"],
    })
    await self._reload()
    logger.info("Updated entitlement '%s'", name)

  async def delete(self, name: str) -> None:
    row = self._entitlements.get(name)
    if row is None:
      raise KeyError("entitlement '%s' not found" % name)
    await self._one(DELETE, {"key_guid": row["key_guid"]})
    await self._reload()
    logger.info("Deleted entitlement '%s'", name)

  async def _rows(self, op: str) -> list[dict]:
    raw = await self._database.query(DBRequest(op))
    return [] if raw is None else raw if isinstance(raw, list) else [raw]

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))

  async def on_seal(self):
    pass

  async def on_unseal(self):
    self._entitlements.clear()

  async def shutdown(self):
    self._entitlements.clear()
    self._database = None
