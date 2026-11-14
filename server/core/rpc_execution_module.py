import base64
import inspect
import json
import logging
import uuid
from dataclasses import dataclass

from fastapi import FastAPI
from pydantic import BaseModel

from server.kernel import AccessDenied, BaseModule, SecurityContext, kernel_context
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.kernel.kernel_security_operations_module import KernelSecurityOperationsModule
from .security_operations_module import SecurityOperationsModule

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# The RPC envelope: RpcRequest in, RpcResponse out.
# ----------------------------------------------------------------------------
# urn is exactly urn:<domain>:<subdomain>:<function>:<version>; params is the
# JSON object text of the function's input fields other than context;
# correlation_key ties the response and its log lines to the request.
# The response says whether the call ran, names the output model ('void' when
# there is no result), and carries the result JSON text or the error: on a
# refusal the denial_reason member name; FAILED when the dispatched function
# itself raised or its return could not be serialized (not a refusal: the
# gates had passed).
# ----------------------------------------------------------------------------

class RpcRequest(BaseModel):
  urn: str
  params: str
  correlation_key: str


class RpcResponse(BaseModel):
  ok: bool
  model: str
  result: str | None = None
  error: str | None = None


# One dispatchable function, as db:contracts:urn:read_functions:1 and
# read_grants:1 describe it. fields are the input model's fields other than
# context, in order; roles and entitlements are the two gates (upper-case keys).
@dataclass(frozen=True)
class RpcFunction:
  key_guid: str
  urn: str
  module: str
  function: str
  role: str
  output_model: str | None
  fields: tuple[str, ...]
  roles: tuple[str, ...]
  entitlements: tuple[str, ...]


# ----------------------------------------------------------------------------
# RpcExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Rpc component: one urn request through the
# security gates to one module function. It holds the RPC registry: every
# function of the urn namespace bound to a module function, with its two
# gates, loaded once at startup under the kernel context. The registry is the
# contract, not a verdict: the decoration is resolved for every request and
# never cached.
#
# -- dispatch(session, request), in order -----------------------------------
# The request runs under the caller's security context as it is handed in
# (the session): it is carried, never copied and never written. Deny path
# first. Every refusal writes its denial row through
# KernelSecurityOperationsModule.deny (layer AUTHORIZATION, the reason, the
# URN as subject) under that context, then answers
# RpcResponse(ok False, model 'void', error <reason>). Nothing raises out.
#   0. the session is a SecurityContext        else NO_CONTEXT (under the kernel context)
#      (a request that is not an RpcRequest is MALFORMED_OP from here on)
#   1. parse the URN, exactly urn:<domain>:<subdomain>:<function>:<version>
#                                              else MALFORMED_OP
#   2. find the function in the registry       else UNKNOWN_TERM
#   3. resolve the decoration of the actor     else DISABLED_ACCOUNT
#   4. evaluate it against the function's roles AND entitlements
#                                              else NO_GRANT
#   5. the target module's role is MANAGER or PRIMITIVE and it resolves, by
#      name through app.state.module_manager.get_by_name, to a public callable
#                                              else UNKNOWN_TERM
#   6. params is a JSON object whose keys are exactly the input fields other
#      than context; a key named context      else MALFORMED_OP
#   7. fn(context, **params), awaited when it returns an awaitable
#   8. the return serialized by the output-model rule: a scalar is
#      {"value": x}, a record {"item": {...}}, a list {"items": [...]}; None
#      is no result and the model is 'void'.
# An exception inside a check is that check's refusal. An AccessDenied raised
# by the function itself was recorded by the layer that raised it; its reason
# is answered as is. Any other failure of the function answers FAILED.
#
# The target is resolved at call time, never awaited at startup: Rpc does not
# wait on the modules it dispatches to (Gateway, Workflow wait on Rpc).
#
# -- Contract ----------------------------------------------------------------
#   dispatch(session, request) -> RpcResponse
#   registered(urn) -> bool          [sync, cache-only] the URN is dispatchable
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule (the registry reads)
#   EnvironmentVariablesModule (NS_HASH and the hostname: the kernel context)
#   KernelSecurityOperationsModule (deny)
#   SecurityOperationsModule (resolve_decoration, evaluate)
# ----------------------------------------------------------------------------

# The registry operations this module dispatches (core-owned rows).
FUNCTIONS_READ = "db:contracts:urn:read_functions:1"
GRANTS_READ = "db:contracts:urn:read_grants:1"
NAMESPACE = "urn"
CONTEXT_FIELD = "context"
LAYER = "AUTHORIZATION"
VOID = "void"
FAILED = "FAILED"
# The module roles a URN may dispatch to: the public surfaces of a component.
DISPATCHABLE_ROLES = ("MANAGER", "PRIMITIVE")


class RpcExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._kernel_security: KernelSecurityOperationsModule | None = None
    self._security: SecurityOperationsModule | None = None
    self._kernel: SecurityContext | None = None
    self._functions: dict[str, RpcFunction] = {}

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._kernel_security = self.get_module(KernelSecurityOperationsModule)
    await self._kernel_security.await_ready()
    self._security = self.get_module(SecurityOperationsModule)
    await self._security.await_ready()
    self._kernel = kernel_context(uuid.UUID(env.get("NS_HASH")), env.get_hostname())
    await self._load(self._kernel)
    self.raise_ready()

  async def _load(self, context: SecurityContext) -> None:
    # A row that does not describe a dispatchable function is left out (and
    # so refused as UNKNOWN_TERM): the registry is a whitelist.
    grants: dict[str, tuple[set[str], set[str]]] = {}
    for row in await self._rows(GRANTS_READ, context):
      key = str(row.get("key_guid") or "").upper()
      if not key:
        continue
      roles, entitlements = grants.setdefault(key, (set(), set()))
      if row.get("ref_role_guid"):
        roles.add(str(row["ref_role_guid"]).upper())
      if row.get("ref_entitlement_guid"):
        entitlements.add(str(row["ref_entitlement_guid"]).upper())
    functions: dict[str, RpcFunction] = {}
    duplicates: set[str] = set()
    for row in await self._rows(FUNCTIONS_READ, context):
      entry = self._entry(row, grants)
      if entry is None:
        continue
      if entry.urn in functions:
        duplicates.add(entry.urn)
        continue
      functions[entry.urn] = entry
    for urn in duplicates:
      logger.error("RPC registry: %s is listed more than once; it is not dispatchable", urn)
      functions.pop(urn, None)
    self._functions = functions
    if self._functions:
      logger.info("Loaded %d RPC functions", len(self._functions))
    else:
      logger.warning("No RPC functions loaded (empty registry or operation not found)")

  def _entry(self, row: dict, grants: dict[str, tuple[set[str], set[str]]]) -> RpcFunction | None:
    names = ("pub_domain", "pub_subdomain", "pub_name", "pub_module", "pub_function", "key_guid")
    if not all(isinstance(row.get(n), str) and row.get(n) for n in names) or not isinstance(row.get("pub_version"), int):
      logger.error("RPC registry: a function row is incomplete; it is not dispatchable")
      return None
    urn = "%s:%s:%s:%s:%d" % (NAMESPACE, row["pub_domain"], row["pub_subdomain"], row["pub_name"], row["pub_version"])
    if row["pub_function"].startswith("_"):
      logger.error("RPC registry: %s names a private function; it is not dispatchable", urn)
      return None
    fields = row.get("pub_fields")
    # pub_fields arrives parsed: a list of field names that includes context.
    if not isinstance(fields, list) or not all(isinstance(f, str) and f for f in fields):
      logger.error("RPC registry: %s has no field list; it is not dispatchable", urn)
      return None
    if not fields or fields[0] != CONTEXT_FIELD or fields.count(CONTEXT_FIELD) != 1 or len(set(fields)) != len(fields):
      logger.error("RPC registry: %s does not take context first; it is not dispatchable", urn)
      return None
    output_model = row.get("pub_output_model")
    key = row["key_guid"].upper()
    roles, entitlements = grants.get(key, (set(), set()))
    return RpcFunction(
      key_guid=key,
      urn=urn,
      module=row["pub_module"],
      function=row["pub_function"],
      role=str(row.get("pub_role") or ""),
      output_model=output_model if isinstance(output_model, str) and output_model else None,
      fields=tuple(fields[1:]),
      roles=tuple(sorted(roles)),
      entitlements=tuple(sorted(entitlements)),
    )

  def registered(self, urn: str) -> bool:
    return isinstance(urn, str) and urn in self._functions

  async def dispatch(self, session: SecurityContext, request: RpcRequest) -> RpcResponse:
    subject = request.urn if isinstance(request, RpcRequest) and isinstance(request.urn, str) else ""
    correlation = request.correlation_key if isinstance(request, RpcRequest) else ""

    # 0. The caller's security context. The request runs under it as it is:
    # carried, never copied, never written.
    if not isinstance(session, SecurityContext):
      return await self._refuse(self._kernel, "NO_CONTEXT", subject, correlation)
    context = session
    if not isinstance(request, RpcRequest):
      return await self._refuse(context, "MALFORMED_OP", subject, correlation)

    # 1. The URN parses.
    if not self._parses(request.urn):
      return await self._refuse(context, "MALFORMED_OP", subject, correlation)

    # 2. The function is registered.
    entry = self._functions.get(request.urn)
    if entry is None:
      return await self._refuse(context, "UNKNOWN_TERM", subject, correlation)

    # 3. The decoration of the actor, for this request.
    try:
      decoration = await self._security.resolve_decoration(context)
    except Exception:
      return await self._refuse(context, "DISABLED_ACCOUNT", subject, correlation)

    # 4. Both gates.
    try:
      granted = self._security.evaluate(decoration, list(entry.roles), list(entry.entitlements))
    except Exception:
      granted = False
    if granted is not True:
      return await self._refuse(context, "NO_GRANT", subject, correlation)

    # 5. The target: a public callable of a loaded MANAGER or PRIMITIVE.
    fn = self._target(entry)
    if fn is None:
      return await self._refuse(context, "UNKNOWN_TERM", subject, correlation)

    # 6. The parameters: exactly the input fields other than context.
    params = self._params(request.params, entry)
    if params is None:
      return await self._refuse(context, "MALFORMED_OP", subject, correlation)

    # 7. The call, under the caller's context.
    try:
      result = fn(context, **params)
      if inspect.isawaitable(result):
        result = await result
    except AccessDenied as e:
      # Recorded by the layer that raised it; answered as is.
      logger.warning("RPC %r refused inside the function (%s): %s %s", subject, correlation, e.layer, e.reason)
      return RpcResponse(ok=False, model=VOID, result=None, error=e.reason)
    except Exception as e:
      logger.error("RPC %r failed (%s): %s", subject, correlation, type(e).__name__)
      return RpcResponse(ok=False, model=VOID, result=None, error=FAILED)

    # 8. The result, by the output-model rule.
    try:
      return self._response(entry, result)
    except Exception as e:
      logger.error("RPC %r returned a result that does not serialize (%s): %s", subject, correlation, type(e).__name__)
      return RpcResponse(ok=False, model=VOID, result=None, error=FAILED)

  async def _refuse(self, context: SecurityContext | None, reason: str, subject: str, correlation: str) -> RpcResponse:
    # The denial row first, then the answer. deny() logs its own write
    # failure; nothing here raises.
    try:
      if context is None:
        raise RuntimeError("no context to record the denial under")
      await self._kernel_security.deny(context, LAYER, reason, subject)
    except Exception as e:
      logger.error("RPC denial write failed (%s %s): %s", LAYER, reason, type(e).__name__)
    logger.warning("RPC refused %r (%s): %s", subject[:256], correlation, reason)
    return RpcResponse(ok=False, model=VOID, result=None, error=reason)

  def _parses(self, urn: str) -> bool:
    if not isinstance(urn, str):
      return False
    segments = urn.split(":")
    if len(segments) != 5 or segments[0] != NAMESPACE:
      return False
    if not all(segments[1:4]):
      return False
    version = segments[4]
    return version.isascii() and version.isdigit()

  def _target(self, entry: RpcFunction):
    try:
      if entry.role not in DISPATCHABLE_ROLES or entry.function.startswith("_"):
        return None
      instance = self.app.state.module_manager.get_by_name(entry.module)
      if instance is None:
        return None
      fn = getattr(instance, entry.function, None)
      return fn if callable(fn) else None
    except Exception:
      return None

  def _params(self, text: str, entry: RpcFunction) -> dict | None:
    try:
      params = json.loads(text) if isinstance(text, str) else None
    except Exception:
      return None
    if not isinstance(params, dict) or CONTEXT_FIELD in params:
      return None
    if set(params) != set(entry.fields):
      return None
    return params

  def _response(self, entry: RpcFunction, result) -> RpcResponse:
    if result is None:
      return RpcResponse(ok=True, model=VOID, result=None, error=None)
    if entry.output_model is None:
      raise TypeError("the function returned a value and the registry names no output model")
    if isinstance(result, BaseModel):
      document = {"item": result.model_dump(mode="json")}
    elif isinstance(result, list):
      document = {"items": [self._plain(item) for item in result]}
    else:
      document = {"value": self._plain(result)}
    return RpcResponse(ok=True, model=entry.output_model, result=json.dumps(document), error=None)

  def _plain(self, value):
    # The reflection's primitives and records; anything else is not a result.
    if isinstance(value, BaseModel):
      return value.model_dump(mode="json")
    if value is None or isinstance(value, (str, bool, int, float)):
      return value
    if isinstance(value, uuid.UUID):
      return str(value).upper()
    if isinstance(value, bytes):
      return base64.b64encode(value).decode("ascii")
    raise TypeError("a %s is not a result type" % type(value).__name__)

  async def _rows(self, op: str, context: SecurityContext) -> list[dict]:
    raw = await self._database.query(DBRequest(op, {}, context))
    rows = [] if raw is None else raw if isinstance(raw, list) else [raw]
    return [row for row in rows if isinstance(row, dict)]

  async def on_seal(self):
    pass

  async def on_unseal(self):
    pass

  async def shutdown(self):
    self._functions = {}
    self._security = None
    self._kernel_security = None
    self._database = None
    self._kernel = None
