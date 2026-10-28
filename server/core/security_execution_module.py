import logging
import uuid
from typing import Iterable

from fastapi import FastAPI

from server.kernel import BaseModule
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid
from .entitlements_operations_module import EntitlementsOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security subsystem: owns the roles catalogue
# (service_security_roles) and its nested groups (service_security_role_groups),
# and evaluates them. Security has no provider layer: it has no external
# client and never leaves the application, so this module dispatches the
# registry operations itself through DatabaseOperationsModule. Every write is
# one statement the kernel commits, so every call is atomic by itself; a write
# that affects any number of rows other than one is an error, raised, never
# swallowed.
#
# Holds roles and groups in memory, keys new rows by formula (uuid5 over
# NS_HASH), and reloads both caches after every write so memory and table
# never disagree. A role grants a domain, an entitlement grants a subdomain;
# a role that is a group grants every role it contains, transitively.
#
# A group is a role that contains other roles. Membership is a role-to-role
# row keyed 'service_security_role_groups:<group>.<member>'. A cycle is
# refused at add time so the closure always terminates.
#
# The entitlements catalogue is the Entitlements subsystem's table, not this
# one's: entitlement lookups go through EntitlementsOperationsModule. This is
# the catalogue, not the assignment: user-to-role mapping is another
# subsystem. The user mapping tables and the RPC registry add the domain /
# subdomain / function checks here.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                [sync, cache-only]
#   role_guid(name: str) -> str | None        [sync, cache-only]
#   groups() -> dict[str, set[str]]           [sync, cache-only]  {group: {member, ...}}
#   members_of(group: str) -> set[str]        [sync, cache-only]  transitive
#   entitlements() -> dict[str, dict]         [sync, cache-only]
#   entitlement_guid(name: str) -> str | None [sync, cache-only]
#   effective_roles(names: Iterable[str]) -> set[str]   the names plus every role they contain
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#   add_member(group, member, package_guid=None) -> str           (the key)
#   remove_member(group, member) -> None
#     Unknown name raises KeyError; duplicates and cycles raise ValueError.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH)
#   EntitlementsOperationsModule
# ----------------------------------------------------------------------------

TABLE = "service_security_roles"
GROUPS_TABLE = "service_security_role_groups"

# The registry operations this module dispatches (core-owned rows).
READ_ALL = "db:security:roles:read_all:1"
CREATE = "db:security:roles:create:1"
UPDATE = "db:security:roles:update:1"
DELETE = "db:security:roles:delete:1"
GROUPS_READ_ALL = "db:security:role_groups:read_all:1"
GROUPS_CREATE = "db:security:role_groups:create:1"
GROUPS_DELETE = "db:security:role_groups:delete:1"


class SecurityExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._entitlements: EntitlementsOperationsModule | None = None
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
    self._entitlements = self.get_module(EntitlementsOperationsModule)
    await self._entitlements.await_ready()
    await self._reload()
    self.raise_ready()

  async def _reload(self):
    self._roles = {row["pub_name"]: row for row in await self._rows(READ_ALL)}
    by_guid = {row["key_guid"].upper(): name for name, row in self._roles.items()}
    self._groups = {}
    self._group_keys = {}
    for row in await self._rows(GROUPS_READ_ALL):
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

  def entitlements(self) -> dict[str, dict]:
    return self._entitlements.entitlements()

  def entitlement_guid(self, name: str) -> str | None:
    return self._entitlements.resolve_entitlement(name)

  def effective_roles(self, names: Iterable[str]) -> set[str]:
    effective: set[str] = set()
    for name in names:
      effective.add(name)
      effective |= self.members_of(name)
    return effective

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    if name in self._roles:
      raise ValueError("security role '%s' already exists" % name)
    key_guid = deterministic_guid(self._namespace, TABLE, name)
    # Parameter order is the operation's input model order.
    await self._one(CREATE, {
      "key_guid": key_guid,
      "ref_package_guid": package_guid,
      "pub_name": name,
      "pub_display": display,
      "pub_notes": notes,
    })
    await self._reload()
    logger.info("Created security role '%s' (%s)", name, key_guid)
    return key_guid

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    row = self._require(name)
    await self._one(UPDATE, {
      "pub_display": row["pub_display"] if display is None else display,
      "pub_notes": row.get("pub_notes") if notes is None else notes,
      "key_guid": row["key_guid"],
    })
    await self._reload()
    logger.info("Updated security role '%s'", name)

  async def delete(self, name: str) -> None:
    row = self._require(name)
    await self._one(DELETE, {"key_guid": row["key_guid"]})
    await self._reload()
    logger.info("Deleted security role '%s'", name)

  async def add_member(self, group: str, member: str, package_guid: str | None = None) -> str:
    group_row, member_row = self._require(group), self._require(member)
    if group == member or group in self.members_of(member):
      raise ValueError("adding '%s' to '%s' would make a cycle" % (member, group))
    if member in self._groups.get(group, ()):
      raise ValueError("'%s' is already a member of '%s'" % (member, group))
    key_guid = deterministic_guid(self._namespace, GROUPS_TABLE, "%s.%s" % (group, member))
    # Parameter order is the operation's input model order.
    await self._one(GROUPS_CREATE, {
      "key_guid": key_guid,
      "ref_package_guid": package_guid,
      "ref_group_guid": group_row["key_guid"],
      "ref_member_guid": member_row["key_guid"],
    })
    await self._reload()
    logger.info("Added '%s' to group '%s'", member, group)
    return key_guid

  async def remove_member(self, group: str, member: str) -> None:
    key_guid = self._group_keys.get((group, member))
    if key_guid is None:
      raise KeyError("'%s' is not a member of '%s'" % (member, group))
    await self._one(GROUPS_DELETE, {"key_guid": key_guid})
    await self._reload()
    logger.info("Removed '%s' from group '%s'", member, group)

  def _require(self, name: str) -> dict:
    row = self._roles.get(name)
    if row is None:
      raise KeyError("security role '%s' not found" % name)
    return row

  async def _rows(self, op: str) -> list[dict]:
    raw = await self._database.query(DBRequest(op))
    return [] if raw is None else raw if isinstance(raw, list) else [raw]

  async def _one(self, op: str, params: dict) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))

  async def on_seal(self):
    pass

  async def on_unseal(self):
    self._roles.clear()
    self._groups.clear()
    self._group_keys.clear()

  async def shutdown(self):
    self._roles.clear()
    self._groups.clear()
    self._group_keys.clear()
    self._entitlements = None
    self._database = None
