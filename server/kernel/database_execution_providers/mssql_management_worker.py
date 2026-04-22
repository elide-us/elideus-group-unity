import logging

from . import BaseDatabaseManagementWorker

logger = logging.getLogger(__name__.split('.')[-1])


class MssqlManagementWorker(BaseDatabaseManagementWorker):
  async def start(self) -> None:
    pass

  async def stop(self) -> None:
    pass