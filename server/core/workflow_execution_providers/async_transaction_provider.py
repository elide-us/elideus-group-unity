import logging

from server.kernel import SecurityContext
from server.kernel.database_operations_module import DBRequest
from . import BaseWorkflowTaskProvider, WorkflowHistoryRecord, WorkflowQueueClaim, WorkflowQueueInstance, WorkflowQueueRow

logger = logging.getLogger(__name__.split('.')[-1])

# The registry operations this provider dispatches (core-owned rows). Every
# request carries the context the caller handed in; the provider chooses none.
DECLARE = "db:workflow:queue:declare:1"
CLAIM = "db:workflow:queue:claim:1"
COMPLETE = "db:workflow:queue:complete:1"
FAIL = "db:workflow:queue:fail:1"
RETRY = "db:workflow:queue:retry:1"
RELEASE_STALE = "db:workflow:queue:release_stale:1"
READ = "db:workflow:queue:read:1"
SEQUENCE_ALLOCATE = "db:system:sequence:allocate:1"
SEQUENCE_NEXT = "db:system:sequence:next:1"
RECORD_HISTORY = "db:workflow:history:record:1"


class AsyncTransactionProvider(BaseWorkflowTaskProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def declare(self, context: SecurityContext, row: WorkflowQueueRow) -> None:
    # Parameter order is the operation's input model order.
    await self._one(context, DECLARE, {
      "key_guid": row.key_guid,
      "ref_package_guid": row.ref_package_guid,
      "ref_definition_guid": row.ref_definition_guid,
      "ref_status_enum_guid": row.ref_status_enum_guid,
      "ref_disposition_enum_guid": row.ref_disposition_enum_guid,
      "pub_batch_number": row.pub_batch_number,
      "pub_steps": row.pub_steps,
      "pub_can_retry": row.pub_can_retry,
      "pub_max_attempts": row.pub_max_attempts,
      "ref_principal_guid": row.ref_principal_guid,
      "ref_context_guid": row.ref_context_guid,
    })

  async def claim(self, context: SecurityContext, pending: str, running: str) -> WorkflowQueueClaim | None:
    # One statement moves the oldest pending row to running and returns it:
    # the atomic claim is the only multi-node coordination point.
    raw = await self._database.query(DBRequest(CLAIM, {
      "ref_status_enum_guid": pending,
      "ref_claimed_enum_guid": running,
    }, context))
    row = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    return None if row is None else WorkflowQueueClaim.model_validate(row)

  async def complete(self, context: SecurityContext, key_guid: str, status: str) -> None:
    await self._one(context, COMPLETE, {"ref_status_enum_guid": status, "key_guid": key_guid})

  async def fail(self, context: SecurityContext, key_guid: str, status: str, error: str) -> None:
    await self._one(context, FAIL, {"ref_status_enum_guid": status, "pub_error": error, "key_guid": key_guid})

  async def retry(self, context: SecurityContext, key_guid: str, status: str, error: str) -> None:
    await self._one(context, RETRY, {"ref_status_enum_guid": status, "pub_error": error, "key_guid": key_guid})

  async def release_stale(self, context: SecurityContext, pending: str, running: str, grace_seconds: int) -> int:
    affected = await self._database.execute(DBRequest(RELEASE_STALE, {
      "ref_status_enum_guid": pending,
      "ref_stale_enum_guid": running,
      "pub_grace_seconds": grace_seconds,
    }, context))
    if affected is None or affected < 0:
      raise RuntimeError("%s did not run" % RELEASE_STALE)
    return affected

  async def read(self, context: SecurityContext, key_guid: str) -> WorkflowQueueInstance | None:
    raw = await self._database.query(DBRequest(READ, {"key_guid": key_guid}, context))
    row = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    return None if row is None else WorkflowQueueInstance.model_validate(row)

  async def allocate(self, context: SecurityContext, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    return await self._issue(context, SEQUENCE_ALLOCATE, sequence_guid, module_guid, consumer_guid)

  async def next(self, context: SecurityContext, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    return await self._issue(context, SEQUENCE_NEXT, sequence_guid, module_guid, consumer_guid)

  async def record_history(self, context: SecurityContext, record: WorkflowHistoryRecord) -> None:
    # Parameter order is the operation's input model order.
    await self._one(context, RECORD_HISTORY, {
      "key_guid": record.key_guid,
      "ref_package_guid": record.ref_package_guid,
      "ref_definition_guid": record.ref_definition_guid,
      "ref_instance_guid": record.ref_instance_guid,
      "ref_host_guid": record.ref_host_guid,
      "ref_principal_guid": record.ref_principal_guid,
      "ref_status_enum_guid": record.ref_status_enum_guid,
      "ref_disposition_enum_guid": record.ref_disposition_enum_guid,
      "pub_name": record.pub_name,
      "pub_batch_number": record.pub_batch_number,
      "pub_attempts": record.pub_attempts,
      "pub_started_on": record.pub_started_on,
      "pub_finished_on": record.pub_finished_on,
      "pub_duration_ms": record.pub_duration_ms,
      "pub_error": record.pub_error,
      "ref_actor_guid": record.ref_actor_guid,
      "ref_context_guid": record.ref_context_guid,
    })

  async def _issue(self, context: SecurityContext, op: str, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    # The procedure commits the sequence advance and the audit row before it
    # returns; once it returns, the numbers are burned. The allocation row's
    # context column stays NULL: a draw writes no context row.
    raw = await self._database.query(DBRequest(op, {
      "ref_sequence_guid": sequence_guid,
      "ref_module_guid": module_guid,
      "ref_consumer_guid": consumer_guid,
      "ref_context_guid": None,
    }, context))
    issued = raw if isinstance(raw, dict) else (raw[0] if raw else None)
    if not issued:
      raise RuntimeError("%s returned nothing" % op)
    return issued

  async def _one(self, context: SecurityContext, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params, context))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))
