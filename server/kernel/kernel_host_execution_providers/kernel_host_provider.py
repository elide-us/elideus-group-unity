import logging

from server.kernel.database_operations_module import DBRequest
from . import BaseKernelHostProvider, ServiceHost

logger = logging.getLogger(__name__.split('.')[-1])

# The registry operations this provider dispatches (kernel-owned bootstrap rows).
REGISTER = "db:host:register:1"
SEAL = "db:host:seal:1"
SET_STATUS = "db:host:set_status:1"
HEARTBEAT = "db:host:heartbeat:1"
READ = "db:host:read:1"
RELEASE_STALE = "db:host:release_stale:1"
RELOAD = "db:host:reload:1"


class KernelHostProvider(BaseKernelHostProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def register(self, key_guid: str, status: str, host_name: str, pid: int, kernel_version: str) -> None:
    # Parameter order is the operation's input model order.
    await self._one(REGISTER, {
      "key_guid": key_guid,
      "ref_status_enum_guid": status,
      "pub_host_name": host_name,
      "pub_pid": pid,
      "pub_kernel_version": kernel_version,
    })

  async def seal(self, key_guid: str, status: str, core_package_guid: str) -> None:
    await self._one(SEAL, {
      "ref_status_enum_guid": status,
      "ref_core_package_guid": core_package_guid,
      "key_guid": key_guid,
    })

  async def set_status(self, key_guid: str, status: str) -> None:
    await self._one(SET_STATUS, {"ref_status_enum_guid": status, "key_guid": key_guid})

  async def heartbeat(self, key_guid: str) -> None:
    await self._one(HEARTBEAT, {"key_guid": key_guid})

  async def read(self, key_guid: str) -> ServiceHost | None:
    raw = await self._database.query(DBRequest(READ, {"key_guid": key_guid}))
    row = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    return None if row is None else ServiceHost.model_validate(row)

  async def release_stale(self, stopped: str, grace_seconds: int) -> int:
    affected = await self._database.execute(DBRequest(RELEASE_STALE, {
      "ref_status_enum_guid": stopped,
      "ref_stopped_enum_guid": stopped,
      "pub_grace_seconds": grace_seconds,
    }))
    if affected is None or affected < 0:
      raise RuntimeError("%s did not run" % RELEASE_STALE)
    return affected

  async def reload(self, key_guid: str, reloading: str, sealed: str) -> None:
    await self._one(RELOAD, {
      "ref_status_enum_guid": reloading,
      "key_guid": key_guid,
      "ref_sealed_enum_guid": sealed,
    })

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))
