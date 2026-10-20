import logging
from typing import Iterable

from fastapi import FastAPI

from server.kernel import BaseModule
from .security_roles_operations_module import SecurityRolesOperationsModule
from .security_entitlements_operations_module import SecurityEntitlementsOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Security subsystem: evaluation. Reads the role
# and entitlement catalogues through their managers (the catalogues are those
# subsystems' tables, not this one's) and answers lookups by name. A role
# grants a domain, an entitlement grants a subdomain; a role that is a group
# grants every role it contains, transitively. The user mapping tables and
# the RPC registry add the domain / subdomain / function checks here.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                     [sync, cache-only]
#   entitlements() -> dict[str, dict]              [sync, cache-only]
#   role_guid(name: str) -> str | None             [sync, cache-only]
#   entitlement_guid(name: str) -> str | None      [sync, cache-only]
#   effective_roles(names: Iterable[str]) -> set[str]   the names plus every role they contain
#
# -- Dependencies ------------------------------------------------------------
#   SecurityRolesOperationsModule, SecurityEntitlementsOperationsModule
# ----------------------------------------------------------------------------

class SecurityExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._roles: SecurityRolesOperationsModule | None = None
    self._entitlements: SecurityEntitlementsOperationsModule | None = None

  async def startup(self):
    self._roles = self.get_module(SecurityRolesOperationsModule)
    await self._roles.await_ready()
    self._entitlements = self.get_module(SecurityEntitlementsOperationsModule)
    await self._entitlements.await_ready()
    self.raise_ready()

  def roles(self) -> dict[str, dict]:
    return self._roles.roles()

  def entitlements(self) -> dict[str, dict]:
    return self._entitlements.entitlements()

  def role_guid(self, name: str) -> str | None:
    return self._roles.resolve_role(name)

  def entitlement_guid(self, name: str) -> str | None:
    return self._entitlements.resolve_entitlement(name)

  def effective_roles(self, names: Iterable[str]) -> set[str]:
    effective: set[str] = set()
    for name in names:
      effective.add(name)
      effective |= self._roles.members_of(name)
    return effective

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._roles = None
    self._entitlements = None
