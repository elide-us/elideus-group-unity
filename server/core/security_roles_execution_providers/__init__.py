import logging
from abc import abstractmethod

from server.kernel import BaseProvider
from server.kernel.database_operations_module import DatabaseOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# BaseSecurityRolesProvider
# ----------------------------------------------------------------------------
# Provider contract for the roles catalogue (service_security_roles) and its
# nested groups (service_security_role_groups). One registry operation per
# verb, each a single statement the kernel commits, so every call is atomic
# by itself. A write that affects any number of rows other than one is an
# error, raised, never swallowed.
#
#   read_all() -> list[dict]        rows {key_guid, pub_name, pub_display, pub_notes}
#   create(row) -> None             row {key_guid, ref_package_guid, pub_name, pub_display, pub_notes}
#   update(row) -> None             row {pub_display, pub_notes, key_guid}
#   delete(key_guid) -> None
#   read_groups() -> list[dict]     rows {key_guid, ref_group_guid, ref_member_guid}
#   create_group(row) -> None       row {key_guid, ref_package_guid, ref_group_guid, ref_member_guid}
#   delete_group(key_guid) -> None
# ----------------------------------------------------------------------------

class BaseSecurityRolesProvider(BaseProvider):
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

  @abstractmethod
  async def read_groups(self) -> list[dict]:
    pass

  @abstractmethod
  async def create_group(self, row: dict) -> None:
    pass

  @abstractmethod
  async def delete_group(self, key_guid: str) -> None:
    pass
