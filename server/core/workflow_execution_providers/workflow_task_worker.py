import logging

from server.kernel import BaseWorker

logger = logging.getLogger(__name__.split('.')[-1])


class WorkflowTaskWorker(BaseWorker):
  async def start(self) -> None:
    pass

  async def stop(self) -> None:
    pass
