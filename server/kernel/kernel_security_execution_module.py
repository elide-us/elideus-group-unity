import asyncio, logging, uuid

from fastapi import FastAPI

from . import BaseModule, SecurityContext, kernel_context
from .database_operations_module import DatabaseOperationsModule, DBRequest
from .environment_variables_module import EnvironmentVariablesModule
from .host_operations_module import HostOperationsModule
from server.helpers import deterministic_guid

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# KernelSecurityExecutionModule
# ----------------------------------------------------------------------------
# Executor for the KernelSecurity component: the kernel half of the security
# model. It builds the security context a unit of work carries, and it owns
# the two rows a refusal rests on: the context row (system_security_contexts)
# and the denial row (system_security_denials). It decides nothing: whether
# to refuse is the calling layer's. It never supplies an identity: every
# actor, principal and parent is the caller's.
#
# A context is carried in memory. It has a row only when a row refers to it:
# the kernel context's row is written at startup (the operations gate records
# its refusals under it), and any other context's row is written the first
# time a denial is recorded under it. A call that is not logged writes
# nothing.
#
# Startup writes the KERNEL context row (kernel_context(NS_HASH, hostname))
# once the host row it points at exists, then raises ready.
#
# -- Contract ----------------------------------------------------------------
#   kernel() -> SecurityContext                                     [sync]
#     The kernel context of this process.
#
#   mint(ref_parent_context_guid, ref_actor_guid, ref_principal_guid, channel, pub_sealed)
#       -> SecurityContext                                          [sync]
#     A new context, in memory: key uuid4, parent the given context key (None
#     for a root), channel the security_channel member NAME (its row key by
#     formula), host and instance this process's registered row. Nothing is
#     written.
#
#   deny(context, layer, reason, subject) -> None
#     One denial row under the given context, whose own row is written first
#     when this process has not written it. layer is a security_layer member
#     name, reason a denial_reason member name, subject the URN or the
#     operation (cut to the column's 256 UTF-16 units). The caller raises or
#     refuses AFTER this returns. A failed write is logged, never raised: the
#     refusal stands either way.
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule — both writes are named operations.
#   EnvironmentVariablesModule — NS_HASH and the hostname.
#   HostOperationsModule — waited on only so the host row the kernel context
#     points at exists before its row is written.
# ----------------------------------------------------------------------------

# The two security operations this executor dispatches (kernel-owned bootstrap rows).
CONTEXTS_CREATE = "db:security:contexts:create:1"
DENIALS_CREATE = "db:security:denials:create:1"
# pub_subject is NVARCHAR(256).
SUBJECT_LENGTH = 256


def _subject(value: object) -> str:
  # The column's limit counts UTF-16 units, not code points, and a lone
  # surrogate cannot be bound. The subject is cut to fit and made bindable,
  # so no caller-supplied text can make a denial write fail.
  return str(value).encode("utf-16-le", "replace")[:SUBJECT_LENGTH * 2].decode("utf-16-le", "ignore")


class KernelSecurityExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._namespace: uuid.UUID | None = None
    self._kernel: SecurityContext | None = None
    # The keys of the contexts this process has written a row for.
    self._recorded: set[str] = set()
    self._recording = asyncio.Lock()

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    host = self.get_module(HostOperationsModule)
    await host.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    kernel = kernel_context(self._namespace, env.get_hostname())
    await self._write_context(kernel)
    self._kernel = kernel
    self._recorded.add(kernel.key_guid)
    logger.info("Kernel context written")
    self.raise_ready()

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._kernel = None
    self._namespace = None
    self._database = None
    self._recorded.clear()

  def kernel(self) -> SecurityContext:
    if self._kernel is None:
      raise RuntimeError("the kernel context is not written")
    return self._kernel

  def mint(self, ref_parent_context_guid: str | None, ref_actor_guid: str, ref_principal_guid: str, channel: str, pub_sealed: bool) -> SecurityContext:
    kernel = self.kernel()
    return SecurityContext(
      key_guid=str(uuid.uuid4()).upper(),
      ref_actor_guid=ref_actor_guid,
      ref_principal_guid=ref_principal_guid,
      ref_parent_context_guid=ref_parent_context_guid,
      ref_channel_enum_guid=self._member("security_channel", channel),
      ref_host_guid=kernel.ref_host_guid,
      ref_instance_guid=kernel.ref_instance_guid,
      pub_sealed=pub_sealed,
    )

  async def deny(self, context: SecurityContext, layer: str, reason: str, subject: str) -> None:
    subject = _subject(subject)
    try:
      # The denial row refers to the context's row: that row first. A write
      # that fails here may still have landed (an insert that committed and
      # was not acknowledged), so the denial insert decides.
      try:
        await self._record(context)
      except Exception as e:
        logger.error("Context row write failed before a denial (%s %s): %s", layer, reason, e)
      # Parameter order is the operation's input model order.
      affected = await self._database.execute(DBRequest(DENIALS_CREATE, {
        "key_guid": str(uuid.uuid4()).upper(),
        "ref_package_guid": None,
        "ref_context_guid": context.key_guid,
        "ref_layer_enum_guid": self._member("security_layer", layer),
        "ref_reason_enum_guid": self._member("denial_reason", reason),
        "ref_host_guid": self.kernel().ref_host_guid,
        "pub_subject": subject,
      }, context))
      if affected != 1:
        raise RuntimeError("%s affected %s rows, expected 1" % (DENIALS_CREATE, affected))
      # The denial landed, so its context row exists.
      self._recorded.add(context.key_guid)
    except Exception as e:
      logger.error("Denial write failed (%s %s %s): %s", layer, reason, subject, e)

  async def _record(self, context: SecurityContext) -> None:
    # A context's row, once per process, the first time a row refers to it.
    # One writer at a time: two refusals under one context must not both
    # insert it.
    async with self._recording:
      if context.key_guid in self._recorded:
        return
      await self._write_context(context)
      self._recorded.add(context.key_guid)

  async def _write_context(self, context: SecurityContext) -> None:
    # Parameter order is the operation's input model order. The row is
    # operational data: no package.
    affected = await self._database.execute(DBRequest(CONTEXTS_CREATE, {
      "key_guid": context.key_guid,
      "ref_package_guid": None,
      "ref_actor_guid": context.ref_actor_guid,
      "ref_principal_guid": context.ref_principal_guid,
      "ref_parent_context_guid": context.ref_parent_context_guid,
      "ref_channel_enum_guid": context.ref_channel_enum_guid,
      "ref_host_guid": context.ref_host_guid,
      "ref_instance_guid": context.ref_instance_guid,
      "pub_sealed": context.pub_sealed,
    }, context))
    if affected != 1:
      raise RuntimeError("%s affected %s rows, expected 1" % (CONTEXTS_CREATE, affected))

  def _member(self, enum_type: str, name: str) -> str:
    # An enum member's row key by formula: <type>.<NAME>. An unknown name
    # yields a key no row has; the write then fails on its foreign key.
    if self._namespace is None:
      raise RuntimeError("the module has not started")
    return deterministic_guid(self._namespace, "contracts_primitives_enums", "%s.%s" % (enum_type, name))
