import logging

from fastapi import FastAPI

from . import BaseModule
from .database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

class DatabaseMaintenanceModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._ops: DatabaseOperationsModule | None = None

  async def startup(self):
    self._ops = self.get_module(DatabaseOperationsModule)
    await self._ops.on_sealed()
    self.raise_seal()

  async def on_seal(self):
    await super().on_seal()

  async def on_drain(self):
    pass

  async def shutdown(self):
    self._ops = None

  async def reconcile_schema(self) -> None:
    pass

  async def reindex(self, table: str) -> None:
    pass

  async def update_statistics(self, table: str) -> None:
    pass

  async def snapshot_schema(self) -> None:
    pass