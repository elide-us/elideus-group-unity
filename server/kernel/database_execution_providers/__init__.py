import logging
from abc import ABC, abstractmethod
from typing import Any

from server.kernel import BaseWorker

logger = logging.getLogger(__name__.split('.')[-1])

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

  # -- Capability reporting --------------------------------------------------

  @abstractmethod
  def supports_online_index_rebuild(self) -> bool:
    pass

  @abstractmethod
  def supports_native_vector(self) -> bool:
    pass


# ----------------------------------------------------------------------------
# DatabaseManagementWorker
# ----------------------------------------------------------------------------
# Subsystem-level ABC extending BaseWorker. Today it carries only the
# lifecycle contract it inherits and serves as the placeholder the Management
# executor instantiates. When the core-tier task orchestration substrate
# lands, this class gains the claim/dispatch contract, and a concrete
# MssqlManagementWorker is written to satisfy it.
#
# See docs/future/task_automation_design.md for substrate design thinking.
# ----------------------------------------------------------------------------

class DatabaseManagementWorker(BaseWorker):
  async def start(self) -> None:
    pass

  async def stop(self) -> None:
    pass