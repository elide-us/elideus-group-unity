# This is the public interface that calls the kernel database provider

import logging

from . import BaseGatewayProvider

logger = logging.getLogger(__name__.split('.')[-1])


class DatabaseGatewayProvider(BaseGatewayProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass
