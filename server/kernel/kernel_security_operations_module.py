import logging

from fastapi import FastAPI

from . import BaseModule, SecurityContext
from .kernel_security_execution_module import KernelSecurityExecutionModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelSecurityOperationsModule
# ----------------------------------------------------------------------------
# Manager (Operations) for the KernelSecurity component: the API the
# security layers above the kernel call to build a unit of work's context
# and to record a refusal. Nothing here decides; the caller does, and the
# caller raises or refuses after deny() returns.
#
# -- Contract ----------------------------------------------------------------
#   kernel() -> SecurityContext                                     [sync]
#     The kernel context of this process.
#
#   mint(ref_parent_context_guid, ref_actor_guid, ref_principal_guid, channel, pub_sealed)
#       -> SecurityContext                                          [sync]
#     A new context (key uuid4) under the parent's key (None for a root),
#     in memory: nothing is written. channel is a security_channel member
#     name.
#
#   deny(context, layer, reason, subject) -> None
#     One denial row under that context; the context's own row is written
#     first when this process has not written it. layer and reason are
#     security_layer and denial_reason member names; subject the URN or the
#     operation.
#
# -- Dependencies ------------------------------------------------------------
#   KernelSecurityExecutionModule
# ----------------------------------------------------------------------------

class KernelSecurityOperationsModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._execution: KernelSecurityExecutionModule | None = None

  async def startup(self):
    self._execution = self.get_module(KernelSecurityExecutionModule)
    await self._execution.await_ready()
    self.raise_ready()

  def kernel(self) -> SecurityContext:
    return self._execution.kernel()

  def mint(self, ref_parent_context_guid: str | None, ref_actor_guid: str, ref_principal_guid: str, channel: str, pub_sealed: bool) -> SecurityContext:
    return self._execution.mint(ref_parent_context_guid, ref_actor_guid, ref_principal_guid, channel, pub_sealed)

  async def deny(self, context: SecurityContext, layer: str, reason: str, subject: str) -> None:
    await self._execution.deny(context, layer, reason, subject)

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._execution = None
