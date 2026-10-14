import logging

from server.kernel import BaseProvider

logger = logging.getLogger(__name__.split('.')[-1])


class WorkflowTaskProvider(BaseProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass
