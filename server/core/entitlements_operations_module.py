import logging

from fastapi import FastAPI

from server.kernel import BaseModule
from .entitlements_execution_module import EntitlementsExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# EntitlementsOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Entitlements subsystem: the API the application
# uses to read and change the entitlements catalogue. Create, update and
# delete entitlements; it does NOT assign entitlements to users (another
# subsystem). No provider layer: entitlements never leave the application.
# The RPC path exposes these as contracted functions gated by a role.
#
# -- Contract ----------------------------------------------------------------
#   entitlements() -> dict[str, dict]                [sync, cache-only]
#   get(name: str) -> dict | None                    [sync, cache-only]
#   resolve_entitlement(name: str) -> str | None     [sync, cache-only]
#   create(name, display, notes=None, package_guid=None) -> str   (the key)
#   update(name, display=None, notes=None) -> None
#   delete(name) -> None
#
# -- Dependencies ------------------------------------------------------------
#   EntitlementsExecutionModule
# ----------------------------------------------------------------------------

class EntitlementsOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: EntitlementsExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(EntitlementsExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  def entitlements(self) -> dict[str, dict]:
    return self._execution.entitlements()

  def get(self, name: str) -> dict | None:
    return self._execution.entitlements().get(name)

  def resolve_entitlement(self, name: str) -> str | None:
    return self._execution.entitlement_guid(name)

  async def create(self, name: str, display: str, notes: str | None = None, package_guid: str | None = None) -> str:
    name = (name or "").strip()
    display = (display or "").strip()
    if not name or not display:
      raise ValueError("an entitlement needs a name and a display")
    return await self._execution.create(name, display, notes, package_guid)

  async def update(self, name: str, display: str | None = None, notes: str | None = None) -> None:
    if display is None and notes is None:
      raise ValueError("nothing to update")
    await self._execution.update(name, display, notes)

  async def delete(self, name: str) -> None:
    await self._execution.delete(name)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
