import logging
from abc import ABC, abstractmethod
from typing import Any

logger = logging.getLogger(__name__)

# ----------------------------------------------------------------------------
# BaseDatabaseProvider
# ----------------------------------------------------------------------------
# Core provider contract for SQL execution. One concrete implementation
# per supported database engine. The DatabaseExecutionModule selects one
# at startup based on SQL_PROVIDER and owns the instance for the lifetime
# of the application.
#
# -- Contract ----------------------------------------------------------------
#   connect()                    -> opens connection pool
#   disconnect()                 -> closes connection pool
#   query(sql, params)           -> parsed JSON (dict | list) | None
#   execute(sql, params)         -> rowcount (int)
#
# All SELECTs use FOR JSON PATH. The provider concatenates fragmented
# JSON rows and returns parsed Python objects. `execute` returns rowcount
# as a success code.
#
# -- Implementations ---------------------------------------------------------
#   mssql_provider.MssqlProvider (aioodbc, MSSQL / Azure SQL)
#
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
# BaseDatabaseManagementProvider
# ----------------------------------------------------------------------------
# Extended provider contract for DDL operations. Composes with an existing
# BaseDatabaseProvider instance — does NOT own the connection pool. The
# execution provider handles DML (query/execute); this provider handles
# schema introspection and DDL emission.
#
# Constructed during startup_finally() by the DatabaseManagementModule,
# which receives the live provider reference from DatabaseExecutionModule.
# After construction, the ModuleManager sets _sealed = True; all methods
# check sealed state before executing.
#
# -- Contract ----------------------------------------------------------------
#
#   Schema introspection:
#     read_tables(schema)                -> list of table metadata dicts
#     read_columns(table, schema)        -> list of column metadata dicts
#     read_indexes(table, schema)        -> list of index metadata dicts
#     read_constraints(table, schema)    -> list of constraint metadata dicts
#
#   DDL emission:
#     create_table(spec)                 -> bool (success/failure)
#     alter_column(table, spec)          -> bool
#     create_index(spec)                 -> bool
#     drop_constraint(table, name)       -> bool
#     drop_index(table, name)            -> bool
#
#   Capability reporting:
#     supports_online_index_rebuild()    -> bool
#     supports_native_vector()           -> bool
#
# -- Implementations ---------------------------------------------------------
#   mssql_management.MssqlManagementProvider
#
# -- Security ----------------------------------------------------------------
# This provider is only accessible through the DatabaseManagementModule,
# which is only callable by DatabaseMaintenanceModule during bootstrap
# reconciliation. Not exposed via RPC, MCP, or any external interface.
#
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