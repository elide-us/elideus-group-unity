import logging
from abc import abstractmethod

from pydantic import BaseModel

from server.kernel import BaseProvider, BaseWorker, SecurityContext
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowQueueRow: one new row of system_workflow_queue, as the declare
# operation writes it (its input model order).
# ----------------------------------------------------------------------------
# The instance's key, the job's own package (NULL when the definition has
# none), its definition, status and disposition, its batch number, its copy of
# the step document, whether and how often it may retry, and the principal on
# whose behalf it was declared (from the declaring SecurityContext, never
# defaulted). The context column is NULL: a declaration writes no context
# row; the provider fills it when it logs a flagged table (not built).
# ----------------------------------------------------------------------------

class WorkflowQueueRow(BaseModel):
  key_guid: str
  ref_package_guid: str | None
  ref_definition_guid: str
  ref_status_enum_guid: str
  ref_disposition_enum_guid: str
  pub_batch_number: int
  pub_steps: str
  pub_can_retry: bool
  pub_max_attempts: int
  ref_principal_guid: str
  ref_context_guid: str | None


# ----------------------------------------------------------------------------
# WorkflowQueueClaim: the claimed queue row, as the claim operation returns it
# (the workflow_queue_claim_output model).
# ----------------------------------------------------------------------------
# The instance's key, its definition and package (NULL when the job has
# none), its batch number, its copy of the step document, whether and how
# often it may retry, the attempts so far (this claim counted), its
# disposition, the started_on stamp the claim wrote, its definition's name
# (the claim joins service_workflow_definitions for it), the principal the
# queue row holds, its context column (NULL unless the row was logged) and
# the job's actor (the definition's ref_actor_guid). The last three are what
# the run context is minted from.
# ----------------------------------------------------------------------------

class WorkflowQueueClaim(BaseModel):
  key_guid: str
  ref_definition_guid: str
  pub_batch_number: int
  pub_steps: str
  pub_can_retry: bool
  pub_max_attempts: int
  pub_attempts: int
  ref_disposition_enum_guid: str
  pub_started_on: str
  ref_package_guid: str | None = None
  pub_name: str
  ref_principal_guid: str
  ref_context_guid: str | None = None
  ref_actor_guid: str


# ----------------------------------------------------------------------------
# WorkflowQueueInstance: one queue row as it stands, as the read operation
# returns it.
# ----------------------------------------------------------------------------

class WorkflowQueueInstance(BaseModel):
  key_guid: str
  ref_definition_guid: str
  ref_status_enum_guid: str
  ref_disposition_enum_guid: str
  pub_batch_number: int
  pub_steps: str
  pub_can_retry: bool
  pub_max_attempts: int
  pub_attempts: int
  pub_started_on: str | None = None
  pub_finished_on: str | None = None
  pub_error: str | None = None


# ----------------------------------------------------------------------------
# WorkflowHistoryRecord: one row of system_workflow_history, as the record
# operation writes it.
# ----------------------------------------------------------------------------
# The narrow record of one TERMINAL outcome (COMPLETE, or the FAILED that
# spent the attempts): its own key, the package of the queue row it ran from,
# the definition and the name it ran as,
# the queue row it ran from (no FK: queue rows may be purged), the host that
# ran it, the principal on whose behalf it ran (the queue row's), the outcome
# and the disposition, the batch number and the attempts, when it started (the
# claim's stamp) and finished, how long it ran, the error when it failed and
# the actor that ran it (the job's). The context column is NULL: a run
# writes no context row.
# ----------------------------------------------------------------------------

class WorkflowHistoryRecord(BaseModel):
  key_guid: str
  ref_package_guid: str | None = None
  ref_definition_guid: str
  ref_instance_guid: str
  ref_host_guid: str
  ref_principal_guid: str
  ref_status_enum_guid: str
  ref_disposition_enum_guid: str
  pub_name: str
  pub_batch_number: int
  pub_attempts: int
  pub_started_on: str
  pub_finished_on: str
  pub_duration_ms: int
  pub_error: str | None = None
  ref_actor_guid: str
  ref_context_guid: str | None


# ----------------------------------------------------------------------------
# BaseWorkflowTaskProvider
# ----------------------------------------------------------------------------
# Provider contract for the QUEUE (system_workflow_queue) and the batch
# numbers it draws (the sequence procedures). One registry operation per
# verb, each a single statement or one procedure call the kernel commits, so
# every call is atomic by itself. A write that affects any number of rows
# other than one is an error, raised, never swallowed. Every verb takes the
# SecurityContext its statement runs under first; the provider chooses none.
#
#   declare(context, row: WorkflowQueueRow) -> None
#   claim(context, pending, running) -> WorkflowQueueClaim | None
#                                 the atomic PENDING -> RUNNING transition on the oldest
#                                 pending row; returns the claimed row or None when empty
#   complete(context, key_guid, status) -> None
#   fail(context, key_guid, status, error) -> None        terminal: stamps finished_on
#   retry(context, key_guid, status, error) -> None       back to pending: finished_on stays NULL
#   release_stale(context, pending, running, grace_seconds) -> int
#   read(context, key_guid) -> WorkflowQueueInstance | None
#   allocate(context, sequence_guid, module_guid, consumer_guid) -> dict
#                                 {pub_number_from, pub_number_to} from sequence_allocate;
#                                 the allocation row's context column stays NULL
#   next(context, sequence_guid, module_guid, consumer_guid) -> dict
#                                 {pub_number_from, pub_number_to} from sequence_next;
#                                 the allocation row's context column stays NULL
#   record_history(context, record) -> None
#                                 one system_workflow_history row (WorkflowHistoryRecord):
#                                 the narrow record of a terminal outcome, for review
# ----------------------------------------------------------------------------

class BaseWorkflowTaskProvider(BaseProvider):
  def __init__(self, database: DatabaseOperationsModule):
    self._database = database

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def declare(self, context: SecurityContext, row: WorkflowQueueRow) -> None:
    pass

  @abstractmethod
  async def claim(self, context: SecurityContext, pending: str, running: str) -> WorkflowQueueClaim | None:
    pass

  @abstractmethod
  async def complete(self, context: SecurityContext, key_guid: str, status: str) -> None:
    pass

  @abstractmethod
  async def fail(self, context: SecurityContext, key_guid: str, status: str, error: str) -> None:
    pass

  @abstractmethod
  async def retry(self, context: SecurityContext, key_guid: str, status: str, error: str) -> None:
    pass

  @abstractmethod
  async def release_stale(self, context: SecurityContext, pending: str, running: str, grace_seconds: int) -> int:
    pass

  @abstractmethod
  async def read(self, context: SecurityContext, key_guid: str) -> WorkflowQueueInstance | None:
    pass

  @abstractmethod
  async def allocate(self, context: SecurityContext, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    pass

  @abstractmethod
  async def next(self, context: SecurityContext, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    pass

  @abstractmethod
  async def record_history(self, context: SecurityContext, record: WorkflowHistoryRecord) -> None:
    pass


# ----------------------------------------------------------------------------
# BaseWorkflowTaskWorker
# ----------------------------------------------------------------------------
# The claim-and-dispatch loop, owned by the Execution module. Operational
# work waits for the manager to seal; then it claims until the queue is
# empty and sleeps on its cadence only when the queue is empty.
# ----------------------------------------------------------------------------

class BaseWorkflowTaskWorker(BaseWorker):
  @abstractmethod
  async def start(self) -> None:
    pass

  @abstractmethod
  async def stop(self) -> None:
    pass
