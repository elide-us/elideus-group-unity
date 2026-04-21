import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

logger = logging.getLogger(__name__)


# ----------------------------------------------------------------------------
# DdlTaskClaim
# ----------------------------------------------------------------------------
# Minimum shape returned by the management provider's claim operation.
# Fields:
#   task_id       Identifier for subsequent mark_completed / mark_failed calls.
#   action_guid   FK into reflection_rpc_functions. Worker resolves this to
#                 the implementing method and dispatches.
#   disposition   FK into system_dispositions. Governs retry and rollback
#                 eligibility. See docs/database_management.md.
#   payload       Action input. Opaque to the worker; interpreted by the
#                 resolved action function.
#   retry_count   Number of prior attempts on this task. The worker enforces
#                 retry-limit policy against this.
# ----------------------------------------------------------------------------

@dataclass
class DdlTaskClaim:
  task_id: int
  action_guid: str
  disposition: int
  payload: dict[str, Any]
  retry_count: int


# ----------------------------------------------------------------------------
# DatabaseTransactionProvider
# ----------------------------------------------------------------------------
# Primary provider contract. Owns the connection pool for the lifetime of
# DatabaseExecutionModule. One concrete implementation per SQL engine.
# All SELECTs use FOR JSON PATH; query returns parsed JSON; execute returns
# rowcount with -1 as the failure sentinel.
# ----------------------------------------------------------------------------

class DatabaseTransactionProvider(ABC):
  def __init__(self, dsn: str):
    self._dsn = dsn

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def query(self, query: str, params: tuple | None = None) -> Any:
    pass

  @abstractmethod
  async def execute(self, query: str, params: tuple | None = None) -> int:
    pass


# ----------------------------------------------------------------------------
# DatabaseManagementProvider
# ----------------------------------------------------------------------------
# Composed provider contract. Borrows the primary provider's handle via
# DatabaseExecutionModule.get_base_provider(); does not own the connection
# pool. Three method groups:
#
#   Schema introspection — live schema reads used by the worker to compute
#   deltas against declared schema.
#
#   DDL emission — forward mutation methods invoked by the worker to apply
#   declared schema changes.
#
#   Queue operations — claim/complete/fail/recover against the DDL task
#   table. Engine-specific SQL lives in the concrete implementation;
#   the worker never writes SQL directly.
#
# Capability reporting methods expose engine features that influence how
# a DDL is emitted.
# ----------------------------------------------------------------------------

class DatabaseManagementProvider(ABC):
  def __init__(self, provider: DatabaseTransactionProvider):
    self._provider = provider

  # -- Schema introspection --------------------------------------------------

  @abstractmethod
  async def read_tables(self, schema: str = "dbo") -> list[dict[str, Any]]:
    pass

  @abstractmethod
  async def read_columns(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    pass

  @abstractmethod
  async def read_indexes(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    pass

  @abstractmethod
  async def read_constraints(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    pass

  # -- DDL emission ----------------------------------------------------------

  @abstractmethod
  async def create_table(self, spec: dict[str, Any]) -> bool:
    pass

  @abstractmethod
  async def alter_column(self, table: str, spec: dict[str, Any]) -> bool:
    pass

  @abstractmethod
  async def create_index(self, spec: dict[str, Any]) -> bool:
    pass

  @abstractmethod
  async def drop_constraint(self, table: str, constraint_name: str) -> bool:
    pass

  @abstractmethod
  async def drop_index(self, table: str, index_name: str) -> bool:
    pass

  # -- Queue operations ------------------------------------------------------

  @abstractmethod
  async def claim_next_task(self) -> DdlTaskClaim | None:
    pass

  @abstractmethod
  async def mark_task_completed(self, task_id: int, result: dict[str, Any] | None = None) -> bool:
    pass

  @abstractmethod
  async def mark_task_failed(self, task_id: int, error: str) -> bool:
    pass

  @abstractmethod
  async def recover_stale_claims(self) -> int:
    pass

  # -- Capability reporting --------------------------------------------------

  @abstractmethod
  def supports_online_index_rebuild(self) -> bool:
    pass

  @abstractmethod
  def supports_native_vector(self) -> bool:
    pass