# This is the public interface that calls the kernel database provider

import logging

from server.kernel import BaseProvider

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseGatewayProvider(BaseProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass
