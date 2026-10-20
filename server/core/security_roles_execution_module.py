import logging
import uuid

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import discover_classes, deterministic_guid
from .security_roles_execution_providers import BaseSecurityRolesProvider

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityRolesExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security Roles subsystem: owns the roles
# catalogue (service_security_roles) and its nested groups
# (service_security_role_groups). Holds both in memory, keys new rows by
# formula (uuid5 over NS_HASH), and hands every read and write to its
# provider, which dispatches the registry operations. Both caches reload
# after every write so memory and table never disagree.
#
# A group is a role that contains other roles. Membership is a role-to-role
# row keyed 'service_security_role_groups:<group>.<member>'. A cycle is
# refused at add time so the closure always terminates.
#
# This is the catalogue, not the assignment: user-to-role mapping is another
# subsystem.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                [sync, cache-only]
#   role_guid(name: str) -> str | None        [sync, cache-only]
#   groups() -> dict[str, set[str]]           [sync, cache-only]  {group: {member, ...}}
#   members_of(group: str) -> set[str]        [sync, cache-only]  transitive
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#   add_member(group, member, package_guid=None) -> str           (the key)
#   remove_member(group, member) -> None
#     Unknown name raises KeyError; duplicates and cycles raise ValueError.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
#   security_roles_execution_providers/*_provider
# ----------------------------------------------------------------------------

TABLE = "service_security_roles"
GROUPS_TABLE = "service_security_role_groups"
PROVIDER = "database_security_roles_provider"


class SecurityRolesExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._provider: BaseSecurityRolesProvider | None = None
    self._namespace: uuid.UUID | None = None
    self._roles: dict[str, dict] = {}
    self._groups: dict[str, set[str]] = {}
    self._group_keys: dict[tuple[str, str], str] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    providers = discover_classes(f"{__package__}.security_roles_execution_providers", "_provider")
    self._provider = providers[PROVIDER](self._database)
    await self._provider.connect()
    await self._reload()
    self.raise_ready()

  async def _reload(self):
    self._roles = {row["pub_name"]: row for row in await self._provider.read_all()}
    by_guid = {row["key_guid"].upper(): name for name, row in self._roles.items()}
    self._groups = {}
    self._group_keys = {}
    for row in await self._provider.read_groups():
      group = by_guid.get(row["ref_group_guid"].upper())
      member = by_guid.get(row["ref_member_guid"].upper())
      if group is None or member is None:
        logger.error("Group row %s references a role that is not in the catalogue", row["key_guid"])
        continue
      self._groups.setdefault(group, set()).add(member)
      self._group_keys[(group, member)] = row["key_guid"]
    if self._roles:
      logger.info("Loaded %d security roles, %d group memberships", len(self._roles), len(self._group_keys))
    else:
      logger.warning("No security roles loaded (empty table or operation not found)")

  def roles(self) -> dict[str, dict]:
    return self._roles

  def role_guid(self, name: str) -> str | None:
    row = self._roles.get(name)
    return row["key_guid"] if row else None

  def groups(self) -> dict[str, set[str]]:
    return self._groups

  def members_of(self, group: str) -> set[str]:
    # Transitive closure over the group graph; cycles are refused on add.
    seen: set[str] = set()
    pending = list(self._groups.get(group, ()))
    while pending:
      name = pending.pop()
      if name in seen:
        continue
      seen.add(name)
      pending.extend(self._groups.get(name, ()))
    return seen

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    if name in self._roles:
      raise ValueError("security role '%s' already exists" % name)
    key_guid = deterministic_guid(self._namespace, TABLE, name)
    await self._provider.create({
      "key_guid": key_guid, "ref_package_guid": package_guid,
      "pub_name": name, "pub_display": display, "pub_notes": notes,
    })
    await self._reload()
    logger.info("Created security role '%s' (%s)", name, key_guid)
    return key_guid

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    row = self._require(name)
    await self._provider.update({
      "pub_display": row["pub_display"] if display is None else display,
      "pub_notes": row.get("pub_notes") if notes is None else notes,
      "key_guid": row["key_guid"],
    })
    await self._reload()
    logger.info("Updated security role '%s'", name)

  async def delete(self, name: str) -> None:
    row = self._require(name)
    await self._provider.delete(row["key_guid"])
    await self._reload()
    logger.info("Deleted security role '%s'", name)

  async def add_member(self, group: str, member: str, package_guid: str | None = None) -> str:
    group_row, member_row = self._require(group), self._require(member)
    if group == member or group in self.members_of(member):
      raise ValueError("adding '%s' to '%s' would make a cycle" % (member, group))
    if member in self._groups.get(group, ()):
      raise ValueError("'%s' is already a member of '%s'" % (member, group))
    key_guid = deterministic_guid(self._namespace, GROUPS_TABLE, "%s.%s" % (group, member))
    await self._provider.create_group({
      "key_guid": key_guid, "ref_package_guid": package_guid,
      "ref_group_guid": group_row["key_guid"], "ref_member_guid": member_row["key_guid"],
    })
    await self._reload()
    logger.info("Added '%s' to group '%s'", member, group)
    return key_guid

  async def remove_member(self, group: str, member: str) -> None:
    key_guid = self._group_keys.get((group, member))
    if key_guid is None:
      raise KeyError("'%s' is not a member of '%s'" % (member, group))
    await self._provider.delete_group(key_guid)
    await self._reload()
    logger.info("Removed '%s' from group '%s'", member, group)

  def _require(self, name: str) -> dict:
    row = self._roles.get(name)
    if row is None:
      raise KeyError("security role '%s' not found" % name)
    return row

  async def on_seal(self):
    pass

  async def on_unseal(self):
    self._roles.clear()
    self._groups.clear()
    self._group_keys.clear()

  async def shutdown(self):
    if self._provider:
      await self._provider.disconnect()
      self._provider = None
    self._roles.clear()
    self._groups.clear()
    self._group_keys.clear()
    self._database = None
