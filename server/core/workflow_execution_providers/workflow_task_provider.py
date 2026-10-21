import logging

from server.kernel.database_operations_module import DBRequest
from . import BaseWorkflowTaskProvider

logger = logging.getLogger(__name__.split('.')[-1])

# The registry operations this provider dispatches (core-owned rows).
DECLARE = "db:workflow:queue:declare:1"
CLAIM = "db:workflow:queue:claim:1"
COMPLETE = "db:workflow:queue:complete:1"
FAIL = "db:workflow:queue:fail:1"
RETRY = "db:workflow:queue:retry:1"
RELEASE_STALE = "db:workflow:queue:release_stale:1"
READ = "db:workflow:queue:read:1"
SEQUENCE_ALLOCATE = "db:sequence:allocate:1"
SEQUENCE_NEXT = "db:sequence:next:1"


class WorkflowTaskProvider(BaseWorkflowTaskProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def declare(self, row: dict) -> None:
    # Parameter order is the operation's input model order.
    await self._one(DECLARE, {
      "key_guid": row["key_guid"],
      "ref_package_guid": row.get("ref_package_guid"),
      "ref_definition_guid": row["ref_definition_guid"],
      "ref_status_enum_guid": row["ref_status_enum_guid"],
      "ref_disposition_enum_guid": row["ref_disposition_enum_guid"],
      "pub_batch_number": row["pub_batch_number"],
      "pub_steps": row["pub_steps"],
      "pub_can_retry": row["pub_can_retry"],
      "pub_max_attempts": row["pub_max_attempts"],
    })

  async def claim(self, pending: str, running: str) -> dict | None:
    # One statement moves the oldest pending row to running and returns it:
    # the atomic claim is the only multi-node coordination point.
    raw = await self._database.query(DBRequest(CLAIM, {
      "ref_status_enum_guid": pending,
      "ref_claimed_enum_guid": running,
    }))
    return raw if isinstance(raw, dict) else (raw[0] if raw else None)

  async def complete(self, key_guid: str, status: str) -> None:
    await self._one(COMPLETE, {"ref_status_enum_guid": status, "key_guid": key_guid})

  async def fail(self, key_guid: str, status: str, error: str) -> None:
    await self._one(FAIL, {"ref_status_enum_guid": status, "pub_error": error, "key_guid": key_guid})

  async def retry(self, key_guid: str, status: str, error: str) -> None:
    await self._one(RETRY, {"ref_status_enum_guid": status, "pub_error": error, "key_guid": key_guid})

  async def release_stale(self, pending: str, running: str, grace_seconds: int) -> int:
    affected = await self._database.execute(DBRequest(RELEASE_STALE, {
      "ref_status_enum_guid": pending,
      "ref_stale_enum_guid": running,
      "pub_grace_seconds": grace_seconds,
    }))
    if affected is None or affected < 0:
      raise RuntimeError("%s did not run" % RELEASE_STALE)
    return affected

  async def read(self, key_guid: str) -> dict | None:
    raw = await self._database.query(DBRequest(READ, {"key_guid": key_guid}))
    return raw if isinstance(raw, dict) else (raw[0] if raw else None)

  async def allocate(self, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    return await self._issue(SEQUENCE_ALLOCATE, sequence_guid, module_guid, consumer_guid)

  async def next(self, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    return await self._issue(SEQUENCE_NEXT, sequence_guid, module_guid, consumer_guid)

  async def _issue(self, op: str, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    # The procedure commits the sequence advance and the audit row before it
    # returns; once it returns, the numbers are burned.
    raw = await self._database.query(DBRequest(op, {
      "ref_sequence_guid": sequence_guid,
      "ref_module_guid": module_guid,
      "ref_consumer_guid": consumer_guid,
    }))
    issued = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    if not issued:
      raise RuntimeError("%s returned nothing" % op)
    return issued

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))
