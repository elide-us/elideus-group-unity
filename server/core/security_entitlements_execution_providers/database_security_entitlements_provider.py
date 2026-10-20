import logging

from server.kernel.database_operations_module import DBRequest
from . import BaseSecurityEntitlementsProvider

logger = logging.getLogger(__name__.split('.')[-1])

# The registry operations this provider dispatches (core-owned rows).
READ_ALL = "db:security:entitlements:read_all:1"
CREATE = "db:security:entitlements:create:1"
UPDATE = "db:security:entitlements:update:1"
DELETE = "db:security:entitlements:delete:1"


class DatabaseSecurityEntitlementsProvider(BaseSecurityEntitlementsProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def read_all(self) -> list[dict]:
    raw = await self._database.query(DBRequest(READ_ALL))
    return [] if raw is None else raw if isinstance(raw, list) else [raw]

  async def create(self, row: dict) -> None:
    # Parameter order is the operation's input model order.
    await self._one(CREATE, {
      "key_guid": row["key_guid"],
      "ref_package_guid": row.get("ref_package_guid"),
      "pub_name": row["pub_name"],
      "pub_display": row["pub_display"],
      "pub_notes": row.get("pub_notes"),
    })

  async def update(self, row: dict) -> None:
    await self._one(UPDATE, {
      "pub_display": row["pub_display"],
      "pub_notes": row.get("pub_notes"),
      "key_guid": row["key_guid"],
    })

  async def delete(self, key_guid: str) -> None:
    await self._one(DELETE, {"key_guid": key_guid})

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))
