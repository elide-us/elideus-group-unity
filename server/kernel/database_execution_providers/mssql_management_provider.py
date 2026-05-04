import logging

from typing import Any

from . import BaseDatabaseTransactionProvider, ComposedDatabaseManagementProvider

logger = logging.getLogger(__name__.split('.')[-1])


class MssqlManagementProvider(ComposedDatabaseManagementProvider):
  def __init__(self, provider: BaseDatabaseTransactionProvider):
    super().__init__(provider)

  async def generate(self, target: str, **params: Any) -> Any:
    match target:
      case "create_table":
        return await self._generate_create_table(params["table"])
      case _:
        logger.error("Unknown generate target '%s'", target)
        return None

  async def alter(self, target: str, **params: Any) -> Any:
    logger.error("alter target '%s' not implemented", target)
    return None

  async def _generate_create_table(self, table: str) -> Any:
    sql = """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         c.name AS pub_name,
         ty.name AS sys_type,
         c.max_length AS sys_max_length,
         c.precision AS sys_precision,
         c.scale AS sys_scale,
         c.is_nullable AS pub_is_nullable,
         c.is_identity AS sys_is_identity,
         c.column_id AS pub_ordinal,
         OBJECT_DEFINITION(c.default_object_id) AS pub_default_value
       FROM sys.columns c
       JOIN sys.tables t ON c.object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.types ty ON c.user_type_id = ty.user_type_id
       WHERE t.name = ?
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
    return await self._provider.query(sql, (table,))
