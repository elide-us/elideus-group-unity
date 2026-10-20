import logging
from abc import abstractmethod

from server.kernel import BaseProvider
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# BaseSecurityEntitlementsProvider
# ----------------------------------------------------------------------------
# Provider contract for the entitlements catalogue (service_security_entitlements). One
# registry operation per verb, each a single statement the kernel commits,
# so every call is atomic by itself. A write that affects any number of rows
# other than one is an error, raised, never swallowed.
#
#   read_all() -> list[dict]        rows {key_guid, pub_name, pub_display, pub_notes}
#   create(row) -> None             row {key_guid, ref_package_guid, pub_name, pub_display, pub_notes}
#   update(row) -> None             row {pub_display, pub_notes, key_guid}
#   delete(key_guid) -> None
# ----------------------------------------------------------------------------

class BaseSecurityEntitlementsProvider(BaseProvider):
  def __init__(self, database: DatabaseOperationsModule):
    self._database = database

  @abstractmethod
  async def connect(self):
    pass

  @abstractmethod
  async def disconnect(self):
    pass

  @abstractmethod
  async def read_all(self) -> list[dict]:
    pass

  @abstractmethod
  async def create(self, row: dict) -> None:
    pass

  @abstractmethod
  async def update(self, row: dict) -> None:
    pass

  @abstractmethod
  async def delete(self, key_guid: str) -> None:
    pass
