import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .security_roles_execution_module import SecurityRolesExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityRolesOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Security Roles subsystem: the API the
# application uses to read and change the roles catalogue and its nested
# groups. Create, update and delete roles; add and remove group members. It
# does NOT assign roles to users (another subsystem). Roles are created in
# the context of a package; the package-authoring surface supplies the
# package and enforces that.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                [sync, cache-only]
#   get(name: str) -> dict | None             [sync, cache-only]
#   resolve_role(name: str) -> str | None     [sync, cache-only]
#   groups() -> dict[str, set[str]]           [sync, cache-only]
#   members_of(group: str) -> set[str]        [sync, cache-only]  transitive
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#   add_member(group, member, package_guid=None) -> str           (the key)
#   remove_member(group, member) -> None
#
# -- Dependencies ------------------------------------------------------------
#   SecurityRolesExecutionModule
# ----------------------------------------------------------------------------

class SecurityRolesOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: SecurityRolesExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(SecurityRolesExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  def roles(self) -> dict[str, dict]:
    return self._execution.roles()

  def get(self, name: str) -> dict | None:
    return self._execution.roles().get(name)

  def resolve_role(self, name: str) -> str | None:
    return self._execution.role_guid(name)

  def groups(self) -> dict[str, set[str]]:
    return self._execution.groups()

  def members_of(self, group: str) -> set[str]:
    return self._execution.members_of(group)

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    name = (name or "").strip()
    display = (display or "").strip()
    if not name or not display:
      raise ValueError("a security role needs a name and a display")
    return await self._execution.create(name, display, notes, package_guid)

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    if display is None and notes is None:
      raise ValueError("nothing to update")
    await self._execution.update(name, display, notes)

  async def delete(self, name: str) -> None:
    await self._execution.delete(name)

  async def add_member(self, group: str, member: str, package_guid: str | None = None) -> str:
    return await self._execution.add_member(group, member, package_guid)

  async def remove_member(self, group: str, member: str) -> None:
    await self._execution.remove_member(group, member)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
