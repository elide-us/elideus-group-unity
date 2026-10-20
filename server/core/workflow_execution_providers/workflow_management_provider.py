import logging

from server.kernel.database_operations_module import DBRequest
from . import BaseWorkflowManagementProvider

logger = logging.getLogger(__name__.split('.')[-1])

# The registry operation this provider dispatches (core-owned row).
READ_ALL = "db:workflow:definitions:read_all:1"


class WorkflowManagementProvider(BaseWorkflowManagementProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass

  async def read_all(self) -> list[dict]:
    raw = await self._database.query(DBRequest(READ_ALL))
    return [] if raw is None else raw if isinstance(raw, list) else [raw]
