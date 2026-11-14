import logging
import uuid
from typing import Iterable

from fastapi import FastAPI
from pydantic import BaseModel

from server.kernel import AccessDenied, BaseModule, SecurityContext, kernel_context
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.helpers import deterministic_guid
from .entitlements_operations_module import EntitlementsOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# Decoration: what one account holds, resolved for one unit of work.
# ----------------------------------------------------------------------------
# ref_user_guid is the account (the context's actor); roles are role
# key_guids with every group expanded to the roles it contains; entitlements
# are entitlement key_guids. Upper-case GUIDs. Built per unit of work from the
# active grant rows and never cached: a verdict is never carried across
# requests.
# ----------------------------------------------------------------------------

class Decoration(BaseModel):
  ref_user_guid: str
  roles: list[str]
  entitlements: list[str]


# ----------------------------------------------------------------------------
# SecurityExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security subsystem: owns the roles catalogue
# (service_security_roles) and its nested groups (service_security_role_groups),
# resolves an account's decoration and evaluates it. Security has no provider
# layer: it has no external client and never leaves the application, so this
# module dispatches the registry operations itself through
# DatabaseOperationsModule. Every write is one statement the kernel commits,
# so every call is atomic by itself; a write that affects any number of rows
# other than one is an error, raised, never swallowed.
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
# one's: entitlement lookups go through EntitlementsOperationsModule.
#
# -- The two gates -----------------------------------------------------------
# resolve_decoration reads the context's ACTOR: the account row, then its
# active role grants and its active entitlement grants. An account that is
# not found, is not enabled, or cannot be read raises
# AccessDenied(AUTHORIZATION, DISABLED_ACCOUNT): nothing is supplied in its
# place. The refusal is a check inside the caller's unit of work: the caller
# (RpcExecutionModule.dispatch) holds the URN and writes the denial row under
# its own context before it answers.
#
# evaluate is true only when one of the function's roles is in the
# decoration's roles AND one of the function's entitlements is in the
# decoration's entitlements. Two independent gates; an empty list on either
# side is false; anything that is not a Decoration is false.
#
# -- The boot gate -----------------------------------------------------------
# startup refuses the boot (RuntimeError) when no enabled INTERACTIVE account
# holds an active grant of ROLE_GLOBAL_ADMIN: run `init admin`. It lives here,
# not in KernelSecurity: the role catalogue is core's.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                [sync, cache-only]
#   role_guid(name: str) -> str | None        [sync, cache-only]
#   groups() -> dict[str, set[str]]           [sync, cache-only]  {group: {member, ...}}
#   members_of(group: str) -> set[str]        [sync, cache-only]  transitive
#   entitlements() -> dict[str, dict]         [sync, cache-only]
#   entitlement_guid(name: str) -> str | None [sync, cache-only]
#   effective_roles(names: Iterable[str]) -> set[str]   the names plus every role they contain
#   resolve_decoration(context) -> Decoration           raises AccessDenied (DISABLED_ACCOUNT)
#   evaluate(decoration, role_guids, entitlement_guids) -> bool   [sync]
#   create(context, name, display, notes=None, package_guid=None) -> str   (the key)
#   update(context, name, display=None, notes=None) -> None
#   delete(context, name) -> None
#   add_member(context, group, member, package_guid=None) -> str           (the key)
#   remove_member(context, group, member) -> None
#     Unknown name raises KeyError; duplicates and cycles raise ValueError.
#     A mutator's write and the reload after it run under the caller's context.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule
#   EnvironmentVariablesModule (NS_HASH and the hostname: the kernel context
#     for the startup reads)
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
USERS_READ = "db:account:users:read:1"
USER_ROLES_READ_ACTIVE = "db:account:user_roles:read_active:1"
USER_ENTITLEMENTS_READ_ACTIVE = "db:account:user_entitlements:read_active:1"
USER_ROLES_READ_ADMINISTRATORS = "db:account:user_roles:read_administrators:1"

# The boot gate: an enabled INTERACTIVE account holding this role must exist.
ADMINISTRATOR_ROLE = "ROLE_GLOBAL_ADMIN"
INTERACTIVE_KIND = "account_kind.INTERACTIVE"


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
    kernel = kernel_context(self._namespace, env.get_hostname())
    await self._reload(kernel)
    await self._require_administrator(kernel)
    self.raise_ready()

  async def _require_administrator(self, context: SecurityContext) -> None:
    # Deny path first: no role row, no answer, or no account is a refused boot.
    role = self.role_guid(ADMINISTRATOR_ROLE)
    if role is None:
      raise RuntimeError("%s is not in the roles catalogue: the boot is refused; run `init admin` once the catalogue is installed" % ADMINISTRATOR_ROLE)
    # Parameter order is the operation's input model order.
    rows = await self._rows(USER_ROLES_READ_ADMINISTRATORS, {
      "ref_role_guid": role,
      "ref_kind_enum_guid": deterministic_guid(self._namespace, "contracts_primitives_enums", INTERACTIVE_KIND),
    }, context)
    if not rows:
      raise RuntimeError("no enabled INTERACTIVE account holds %s: the boot is refused; run `init admin`" % ADMINISTRATOR_ROLE)
    logger.info("Administrator check passed (%d account(s))", len(rows))

  async def _reload(self, context: SecurityContext):
    self._roles = {row["pub_name"]: row for row in await self._rows(READ_ALL, {}, context)}
    by_guid = {row["key_guid"].upper(): name for name, row in self._roles.items()}
    self._groups = {}
    self._group_keys = {}
    for row in await self._rows(GROUPS_READ_ALL, {}, context):
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

  async def resolve_decoration(self, context: SecurityContext) -> Decoration:
    # Deny path first: any failure to read the actor, an unknown actor, a
    # row for another key, or an account that is not enabled is a refusal.
    # Nothing here supplies an identity in its place. The caller writes the
    # denial row (it holds the URN and the unit of work).
    if not isinstance(context, SecurityContext):
      raise AccessDenied("AUTHORIZATION", "DISABLED_ACCOUNT", USERS_READ)
    actor = context.ref_actor_guid
    try:
      account = await self._database.query(DBRequest(USERS_READ, {"key_guid": actor}, context))
      if not isinstance(account, dict):
        raise AccessDenied("AUTHORIZATION", "DISABLED_ACCOUNT", USERS_READ)
      if str(account.get("key_guid") or "").upper() != actor.upper():
        raise AccessDenied("AUTHORIZATION", "DISABLED_ACCOUNT", USERS_READ)
      if account.get("pub_is_enabled") is not True:
        raise AccessDenied("AUTHORIZATION", "DISABLED_ACCOUNT", USERS_READ)
      role_rows = await self._rows(USER_ROLES_READ_ACTIVE, {"ref_user_guid": actor}, context)
      entitlement_rows = await self._rows(USER_ENTITLEMENTS_READ_ACTIVE, {"ref_user_guid": actor}, context)
    except AccessDenied:
      raise
    except Exception as e:
      # An exception inside the check is a refusal; the account is not named.
      logger.error("Decoration read failed: %s", type(e).__name__)
      raise AccessDenied("AUTHORIZATION", "DISABLED_ACCOUNT", USERS_READ)
    held = {str(row["ref_role_guid"]).upper() for row in role_rows if row.get("ref_role_guid")}
    # Groups expand by name through the catalogue; a held key the catalogue
    # does not know stays as held and contains nothing.
    by_guid = {row["key_guid"].upper(): name for name, row in self._roles.items()}
    roles = set(held)
    for name in self.effective_roles(by_guid[g] for g in held if g in by_guid):
      key = self.role_guid(name)
      if key is not None:
        roles.add(key.upper())
    entitlements = {str(row["ref_entitlement_guid"]).upper() for row in entitlement_rows if row.get("ref_entitlement_guid")}
    return Decoration(ref_user_guid=actor.upper(), roles=sorted(roles), entitlements=sorted(entitlements))

  def evaluate(self, decoration: Decoration, role_guids: list[str], entitlement_guids: list[str]) -> bool:
    # Two independent gates, both required; an empty list on either side is false.
    if not isinstance(decoration, Decoration):
      return False
    if not role_guids or not entitlement_guids or not decoration.roles or not decoration.entitlements:
      return False
    held_roles = {g.upper() for g in decoration.roles}
    held_entitlements = {g.upper() for g in decoration.entitlements}
    role_ok = any(isinstance(g, str) and g.upper() in held_roles for g in role_guids)
    entitlement_ok = any(isinstance(g, str) and g.upper() in held_entitlements for g in entitlement_guids)
    return role_ok and entitlement_ok

  async def create(self, context: SecurityContext, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
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
    }, context)
    await self._reload(context)
    logger.info("Created security role '%s' (%s)", name, key_guid)
    return key_guid

  async def update(self, context: SecurityContext, name: str, display: str | None = None, notes: str | None = None) -> None:
    row = self._require(name)
    await self._one(UPDATE, {
      "pub_display": row["pub_display"] if display is None else display,
      "pub_notes": row.get("pub_notes") if notes is None else notes,
      "key_guid": row["key_guid"],
    }, context)
    await self._reload(context)
    logger.info("Updated security role '%s'", name)

  async def delete(self, context: SecurityContext, name: str) -> None:
    row = self._require(name)
    await self._one(DELETE, {"key_guid": row["key_guid"]}, context)
    await self._reload(context)
    logger.info("Deleted security role '%s'", name)

  async def add_member(self, context: SecurityContext, group: str, member: str, package_guid: str | None = None) -> str:
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
    }, context)
    await self._reload(context)
    logger.info("Added '%s' to group '%s'", member, group)
    return key_guid

  async def remove_member(self, context: SecurityContext, group: str, member: str) -> None:
    key_guid = self._group_keys.get((group, member))
    if key_guid is None:
      raise KeyError("'%s' is not a member of '%s'" % (member, group))
    await self._one(GROUPS_DELETE, {"key_guid": key_guid}, context)
    await self._reload(context)
    logger.info("Removed '%s' from group '%s'", member, group)

  def _require(self, name: str) -> dict:
    row = self._roles.get(name)
    if row is None:
      raise KeyError("security role '%s' not found" % name)
    return row

  async def _rows(self, op: str, params: dict, context: SecurityContext) -> list[dict]:
    raw = await self._database.query(DBRequest(op, params, context))
    return [] if raw is None else raw if isinstance(raw, list) else [raw]

  async def _one(self, op: str, params: dict, context: SecurityContext) -> None:
    # One statement, one row, committed by the kernel: atomic by construction.
    affected = await self._database.execute(DBRequest(op, params, context))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (op, affected))

  async def on_seal(self):
    pass

  async def on_unseal(self):
    # The catalogue stays through the drain: work already admitted (a workflow
    # run finishing its steps) is still authorized against it, and an empty
    # catalogue would answer NO_GRANT for a caller that holds the grant.
    # shutdown() clears it once everything has drained.
    pass

  async def shutdown(self):
    self._roles.clear()
    self._groups.clear()
    self._group_keys.clear()
    self._entitlements = None
    self._database = None
