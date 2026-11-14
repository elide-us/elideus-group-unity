import logging
from abc import ABC, abstractmethod
from typing import Any

from server.kernel import BaseWorker, BaseProvider, SecurityContext

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# BaseDatabaseTransactionProvider
# ----------------------------------------------------------------------------
# Primary provider contract. Owns the connection pool for the lifetime of
# DatabaseExecutionModule. One concrete implementation per SQL engine.
# All SELECTs use FOR JSON PATH; query returns parsed JSON; execute returns
# rowcount with -1 as the failure sentinel.
#
# Every statement arrives with the key of the security context it runs
# under. Nothing is sent to the database for it. The provider is where a
# table flagged in the audit setup is logged with that context; that logging
# is not built, and until it is the key is carried and unused here.
# ----------------------------------------------------------------------------

class BaseDatabaseTransactionProvider(BaseProvider):
  def __init__(self, dsn: str):
    self._dsn = dsn

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def query(self, query: str, params: tuple | None, context_guid: str) -> Any:
    pass

  @abstractmethod
  async def execute(self, query: str, params: tuple | None, context_guid: str) -> int:
    pass


# ----------------------------------------------------------------------------
# ComposedDatabaseManagementProvider
# ----------------------------------------------------------------------------
# Composed provider contract. Borrows the primary provider's handle (passed
# in constructor as self._provider); does not own the connection pool. The
# transaction provider's query/execute methods are building blocks; this
# layer composes them into higher-level operations that cannot be expressed
# as a single cataloged op row.
#
# Two verbs:
#
#   generate(target, **params) — Composes reads to produce emitted material.
#   The output is a string, dict, or other artifact: a CREATE TABLE DDL
#   built from contract rows, a kernel.sql artifact, a seed JSON document,
#   etc. Does not mutate database state.
#
#   alter(target, **params) — Composes reads and writes to mutate schema.
#   The output is a success/rowcount indicator. Examples: applying a
#   declared schema delta, dropping and rebuilding a constraint, adding
#   a column with data preservation.
#
# Both verbs take the security context first; every statement they issue
# runs under its key.
#
# Single-statement reads belong in DatabaseOperationsModule as cataloged
# op rows, not here. This layer exists for multi-statement, decision-tree
# work whose shape doesn't fit the one-string-in-one-result-out contract.
# ----------------------------------------------------------------------------

class ComposedDatabaseManagementProvider(ABC):
  def __init__(self, provider: BaseDatabaseTransactionProvider):
    self._provider = provider

  @abstractmethod
  async def generate(self, context: SecurityContext, target: str, **params: Any) -> Any:
    pass

  @abstractmethod
  async def alter(self, context: SecurityContext, target: str, **params: Any) -> Any:
    pass


# ----------------------------------------------------------------------------
# BaseDatabaseManagementWorker
# ----------------------------------------------------------------------------
# Subsystem-level ABC extending BaseWorker. Today it carries only the
# lifecycle contract it inherits and serves as the placeholder the Management
# executor instantiates. When the core-tier task orchestration substrate
# lands, this class gains the claim/dispatch contract, and a concrete
# MssqlManagementWorker is written to satisfy it.
#
# See docs/future/task_automation_design.md for substrate design thinking.
# ----------------------------------------------------------------------------

class BaseDatabaseManagementWorker(BaseWorker):
  async def start(self) -> None:
    pass

  async def stop(self) -> None:
    pass
