import logging
from abc import abstractmethod

from pydantic import BaseModel

from server.kernel import BaseProvider, BaseWorker
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# WorkflowQueueClaim: the claimed queue row, as the claim operation returns it
# (the workflow_queue_claim_output model).
# ----------------------------------------------------------------------------
# The instance's key, its definition and package (NULL when the declaration
# named none), its batch number, its copy of the step document, whether and
# how often it may retry, the attempts so far (this claim counted), its
# disposition, the started_on stamp the claim wrote, and its definition's
# name (the claim joins service_workflow_definitions for it).
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


# ----------------------------------------------------------------------------
# WorkflowHistoryRecord: one row of system_workflow_history, as the record
# operation writes it.
# ----------------------------------------------------------------------------
# The narrow record of one TERMINAL outcome (COMPLETE, or the FAILED that
# spent the attempts): its own key, the package of the queue row it ran from,
# the definition and the name it ran as,
# the queue row it ran from (no FK: queue rows may be purged), the host that
# ran it, the user that declared it (NULL until auth exists), the outcome and
# the disposition, the batch number and the attempts, when it started (the
# claim's stamp) and finished, how long it ran, and the error when it failed.
# ----------------------------------------------------------------------------

class WorkflowHistoryRecord(BaseModel):
  key_guid: str
  ref_package_guid: str | None = None
  ref_definition_guid: str
  ref_instance_guid: str
  ref_host_guid: str
  ref_user_guid: str | None = None
  ref_status_enum_guid: str
  ref_disposition_enum_guid: str
  pub_name: str
  pub_batch_number: int
  pub_attempts: int
  pub_started_on: str
  pub_finished_on: str
  pub_duration_ms: int
  pub_error: str | None = None


# ----------------------------------------------------------------------------
# BaseWorkflowManagementProvider
# ----------------------------------------------------------------------------
# Provider contract for the workflow DEFINITIONS (service_workflow_definitions):
# package data, read whole. One registry operation, a single statement.
#
#   read_all() -> list[dict]   rows {key_guid, ref_disposition_enum_guid, pub_name,
#                              pub_steps, pub_can_retry, pub_max_attempts, pub_notes}
# ----------------------------------------------------------------------------

class BaseWorkflowManagementProvider(BaseProvider):
  def __init__(self, database: DatabaseOperationsModule):
    self._database = database

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def read_all(self) -> list[dict]:
    pass


# ----------------------------------------------------------------------------
# BaseWorkflowTaskProvider
# ----------------------------------------------------------------------------
# Provider contract for the QUEUE (system_workflow_queue) and the batch
# numbers it draws (the sequence procedures). One registry operation per
# verb, each a single statement or one procedure call the kernel commits, so
# every call is atomic by itself. A write that affects any number of rows
# other than one is an error, raised, never swallowed.
#
#   declare(row) -> None          row {key_guid, ref_package_guid, ref_definition_guid,
#                                 ref_status_enum_guid, ref_disposition_enum_guid,
#                                 pub_batch_number, pub_steps, pub_can_retry, pub_max_attempts}
#   claim(pending, running) -> WorkflowQueueClaim | None
#                                 the atomic PENDING -> RUNNING transition on the oldest
#                                 pending row; returns the claimed row or None when empty
#   complete(key_guid, status) -> None
#   fail(key_guid, status, error) -> None        terminal: stamps finished_on
#   retry(key_guid, status, error) -> None       back to pending: finished_on stays NULL
#   release_stale(pending, running, grace_seconds) -> int
#   read(key_guid) -> dict | None
#   allocate(sequence_guid, module_guid, consumer_guid) -> dict
#                                 {pub_number_from, pub_number_to} from sequence_allocate
#   next(sequence_guid, module_guid, consumer_guid) -> dict
#                                 {pub_number_from, pub_number_to} from sequence_next
#   record_history(record) -> None
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
  async def declare(self, row: dict) -> None:
    pass

  @abstractmethod
  async def claim(self, pending: str, running: str) -> WorkflowQueueClaim | None:
    pass

  @abstractmethod
  async def complete(self, key_guid: str, status: str) -> None:
    pass

  @abstractmethod
  async def fail(self, key_guid: str, status: str, error: str) -> None:
    pass

  @abstractmethod
  async def retry(self, key_guid: str, status: str, error: str) -> None:
    pass

  @abstractmethod
  async def release_stale(self, pending: str, running: str, grace_seconds: int) -> int:
    pass

  @abstractmethod
  async def read(self, key_guid: str) -> dict | None:
    pass

  @abstractmethod
  async def allocate(self, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    pass

  @abstractmethod
  async def next(self, sequence_guid: str, module_guid: str, consumer_guid: str | None) -> dict:
    pass

  @abstractmethod
  async def record_history(self, record: WorkflowHistoryRecord) -> None:
    pass


# ----------------------------------------------------------------------------
# BaseWorkflowTaskWorker
# ----------------------------------------------------------------------------
# The claim-and-dispatch loop, owned by the Management executor. Operational
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
