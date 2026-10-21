import logging

from . import BaseGatewayProvider

logger = logging.getLogger(__name__.split('.')[-1])


class AzureStorageGatewayProvider(BaseGatewayProvider):
  async def connect(self):
    pass

  async def disconnect(self):
    pass
