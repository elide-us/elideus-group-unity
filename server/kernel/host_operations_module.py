import logging
from enum import IntEnum

from fastapi import FastAPI

from . import BaseModule, SecurityContext
from .host_execution_module import HostExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# HostOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the Host subsystem: the API the application calls
# about this instance and, later, about the application's instances in the
# AKS cluster (containers, start/stop, scale up and out). Today the API is
# the registered instance's key and state: who is running, its SEALED /
# DRAINING / STOPPED state as the lifecycle manager reaches each boundary,
# a RELOADING request onto a sealed host, and the wait on that request.
# Nothing here is part of the module lifecycle; the lifecycle manager calls
# in, never the reverse.
#
# -- Contract ----------------------------------------------------------------
#   host_key() -> str                 this process's boot GUID, its service_hosts key
#   seal(context) -> None             SEALED, stamping the core manifest version
#   set_status(context, member) -> None   a host_status member onto the own row
#   reload(context, key_guid) -> None the target host, live and SEALED, becomes RELOADING
#   await_reload() -> None            resolves once the own row has read RELOADING
#
# Each write runs under the caller's context: the lifecycle passes the
# kernel context, a workflow step its run context.
#
# -- Dependencies ------------------------------------------------------------
#   HostExecutionModule
# ----------------------------------------------------------------------------

class HostOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: HostExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(HostExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  def host_key(self) -> str:
    return self._execution.host_key()

  async def seal(self, context: SecurityContext) -> None:
    await self._execution.seal(context)

  async def set_status(self, context: SecurityContext, member: IntEnum) -> None:
    await self._execution.set_status(context, member)

  async def reload(self, context: SecurityContext, key_guid: str) -> None:
    await self._execution.reload(context, key_guid)

  async def await_reload(self) -> None:
    await self._execution.await_reload()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
