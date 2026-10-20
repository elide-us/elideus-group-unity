import logging
from typing import Iterable

from fastapi import FastAPI

from server.kernel import BaseModule
from .security_execution_module import SecurityExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# SecurityOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Security subsystem: the public contract gateway
# providers call to evaluate a user's roles and entitlements against a domain
# / subdomain / function before dispatch. No provider layer: security never
# leaves the application. Security is the first layer consulted after the
# database connection; nothing goes around it.
#
# First pass: role and entitlement resolution by name, and the effective
# role set through nested groups. The domain / subdomain / function checks
# arrive with the user mapping tables and the RPC registry.
#
# -- Contract ----------------------------------------------------------------
#   roles() -> dict[str, dict]                     [sync, cache-only]
#   entitlements() -> dict[str, dict]              [sync, cache-only]
#   resolve_role(name: str) -> str | None          [sync, cache-only]
#   resolve_entitlement(name: str) -> str | None   [sync, cache-only]
#   effective_roles(names: Iterable[str]) -> set[str]
#
# -- Dependencies ------------------------------------------------------------
#   SecurityExecutionModule
# ----------------------------------------------------------------------------

class SecurityOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: SecurityExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(SecurityExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  def roles(self) -> dict[str, dict]:
    return self._execution.roles()

  def entitlements(self) -> dict[str, dict]:
    return self._execution.entitlements()

  def resolve_role(self, name: str) -> str | None:
    return self._execution.role_guid(name)

  def resolve_entitlement(self, name: str) -> str | None:
    return self._execution.entitlement_guid(name)

  def effective_roles(self, names: Iterable[str]) -> set[str]:
    return self._execution.effective_roles(names)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
