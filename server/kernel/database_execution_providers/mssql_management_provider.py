import logging

from typing import Any

from . import DatabaseTransactionProvider, DatabaseManagementProvider

logger = logging.getLogger(__name__.split('.')[-1])

class MssqlManagementProvider(DatabaseManagementProvider):
  def __init__(self, provider: DatabaseTransactionProvider):
    super().__init__(provider)

  async def read_tables(self, schema: str = "dbo") -> list[dict[str, Any]]:
    return []

  async def read_columns(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    return []

  async def read_indexes(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    return []

  async def read_constraints(self, table: str, schema: str = "dbo") -> list[dict[str, Any]]:
    return []

  async def create_table(self, spec: dict[str, Any]) -> bool:
    return False

  async def alter_column(self, table: str, spec: dict[str, Any]) -> bool:
    return False

  async def create_index(self, spec: dict[str, Any]) -> bool:
    return False

  async def drop_constraint(self, table: str, constraint_name: str) -> bool:
    return False

  async def drop_index(self, table: str, index_name: str) -> bool:
    return False

  def supports_online_index_rebuild(self) -> bool:
    return True

  def supports_native_vector(self) -> bool:
    return True