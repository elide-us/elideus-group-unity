import json
import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI
from pydantic import BaseModel

from server.kernel import BaseModule, SecurityContext, kernel_context
from server.kernel.database_operations_module import DatabaseOperationsModule, DBRequest
from server.kernel.environment_variables_module import EnvironmentVariablesModule
from server.kernel.kernel_configuration_module import KernelConfigurationModule
from server.kernel.kernel_security_operations_module import KernelSecurityOperationsModule
from server.helpers import discover_classes, deterministic_guid, instance_key
from .rpc_operations_module import RpcOperationsModule
from .rpc_execution_module import FAILED, RpcRequest
from .workflow_execution_providers import BaseWorkflowTaskProvider, BaseWorkflowTaskWorker, WorkflowHistoryRecord, WorkflowQueueClaim, WorkflowQueueInstance, WorkflowQueueRow

logger = logging.getLogger(__name__.split('.')[-1])

# ----------------------------------------------------------------------------
# The step document: the contract a workflow definition is written in.
# ----------------------------------------------------------------------------
# A definition's pub_steps column holds one WorkflowSteps document. Each step
# names the callee by its RPC URN (urn:<domain>:<subdomain>:<function>:<version>,
# a function of the RPC registry), the name of that callee's input model, and
# the literal parameter values keyed by the model's field names. The
# definition is copied onto the queue row at declaration and the instance
# runs from its copy.
# ----------------------------------------------------------------------------

class WorkflowStep(BaseModel):
  contract: str
  model: str
  params: dict[str, Any]


class WorkflowSteps(BaseModel):
  steps: list[WorkflowStep]


# ----------------------------------------------------------------------------
# WorkflowExecutionModule
# ----------------------------------------------------------------------------
# Executor (Execution) for the Workflow subsystem: holds the definitions
# catalogue (service_workflow_definitions) in memory, owns the queue provider
# and the worker that claims and dispatches instances, draws batch numbers
# from the workflow_batch sequence, and sweeps stale claims when the
# application seals. Every read and write goes to the providers, which
# dispatch the registry operations under the context handed to them.
#
# An instance is one row of system_workflow_queue: the copy of its
# definition plus status, attempts, a batch number and the principal on
# whose behalf it was declared. The worker claims
# the oldest pending row (one atomic statement), mints the run context for
# it, dispatches its steps in order through RPC, and records COMPLETE, or
# FAILED when the attempts are spent, or PENDING again when they are not.
# Stale RUNNING rows (a node that died mid-run) go back to PENDING on seal;
# the attempt they consumed counts.
#
# -- Contexts ----------------------------------------------------------------
# The kernel context (kernel_context(NS_HASH, hostname), derived here, never
# passed in): the definitions read at startup, the stale sweep and the claim.
# The caller's context: declare and the batch-number draw it triggers.
# The run context, minted per claimed instance through
# KernelSecurityOperationsModule.mint (parent = the queue row's
# ref_context_guid when it has one, actor = the job's ref_actor_guid,
# principal = the queue row's ref_principal_guid, channel WORKFLOW, sealed):
# every step, complete, fail, retry and the history row of that instance.
# It is carried in memory: a run writes no context row. The context columns
# of the queue, history and allocation rows stay NULL; they are the
# provider's to fill when it logs a table flagged in the audit setup, which
# is not built.
#
# A step is RpcOperationsModule.dispatch(run context, RpcRequest(urn =
# step.contract, params = the step's params as JSON text, correlation_key =
# the instance key)). A refusal is terminal: a response with ok False sends
# the run straight to FAILED with its history row under the run context,
# its error (the denial reason name) as the message, whatever pub_can_retry
# and the attempts say (a denial does not change on retry, and every retry
# would write another denial row). A raise while dispatching a step,
# including one the target function raises, keeps the retry path: PENDING
# while attempts remain, then FAILED.
#
# A TERMINAL outcome (COMPLETE, or the FAILED that spends the attempts) also
# writes one system_workflow_history row: the narrow record a review of the
# system's history reads (name, package, outcome, disposition, batch,
# attempts, when it started and finished, how long it ran, which host ran
# it, the error, the principal and the actor). A retry back to PENDING is
# not history.
#
# -- Contract ----------------------------------------------------------------
#   definitions() -> dict[str, dict]                [sync, cache-only]
#   definition(name) -> dict | None                 [sync, cache-only]
#   status_guid(name) -> str                        [sync]  task_status row key by formula
#   disposition_guid(name) -> str                   [sync]  task_disposition row key by formula
#   next_batch_number(context) -> int               draws from the cached block, allocating
#                                                   under context when empty
#   declare(context, row: WorkflowQueueRow) -> None writes one queue row (the manager builds it)
#   instance(context, key_guid) -> WorkflowQueueInstance | None
#   run_once() -> bool                              claim, mint, dispatch, record; False when
#                                                   the queue is empty
#
# -- Dependencies ------------------------------------------------------------
#   DatabaseOperationsModule, EnvironmentVariablesModule (NS_HASH, hostname),
#   KernelConfigurationModule (stale_grace_seconds = the stale-claim sweep,
#   workflow_poll_seconds = the worker cadence on an empty queue),
#   KernelSecurityOperationsModule (the run context),
#   RpcOperationsModule (each step)
#   workflow_execution_providers/*_provider, *_worker
# ----------------------------------------------------------------------------

# The definitions catalogue (service_workflow_definitions) is an internal accounting read: one registry operation
# dispatched by name through the Database Manager at startup (Aaron 2026-11-02: the ME layer, not a provider).
DEFINITIONS_READ_ALL = "db:workflow:definitions:read_all:1"
TASK_PROVIDER = "async_transaction_provider"
WORKER = "async_transaction_worker"
BATCH_SEQUENCE = "workflow_batch"
STATUSES = ("PENDING", "RUNNING", "COMPLETE", "FAILED", "CANCELLING")
DISPOSITIONS = ("REVERSIBLE", "IRREVERSIBLE", "TRANSIENT", "CANCELLABLE")
# A RUNNING row older than the grace with no outcome is a claim its node abandoned;
# the grace is the stale_grace_seconds configuration row, shared with the host sweep.
GRACE_KEY = "stale_grace_seconds"
POLL_KEY = "workflow_poll_seconds"
# The security_channel member a run context is minted on.
RUN_CHANNEL = "WORKFLOW"


class WorkflowExecutionModule(BaseModule):
  def __init__(self, app: FastAPI):
    super().__init__(app)
    self._database: DatabaseOperationsModule | None = None
    self._security: KernelSecurityOperationsModule | None = None
    self._rpc: RpcOperationsModule | None = None
    self._task_provider: BaseWorkflowTaskProvider | None = None
    self._worker: BaseWorkflowTaskWorker | None = None
    self._namespace: uuid.UUID | None = None
    self._hostname: str | None = None
    self._kernel: SecurityContext | None = None
    self._grace: int = 0
    self._poll: int = 0
    self._definitions: dict[str, dict] = {}
    self._status: dict[str, str] = {}
    self._disposition: dict[str, str] = {}
    self._batch: list[int] = []
    self._sequence_guid: str | None = None
    self._module_guid: str | None = None

  async def startup(self):
    self._database = self.get_module(DatabaseOperationsModule)
    await self._database.await_ready()
    env = self.get_module(EnvironmentVariablesModule)
    await env.await_ready()
    self._namespace = uuid.UUID(env.get("NS_HASH"))
    self._hostname = env.get_hostname()
    self._kernel = kernel_context(self._namespace, self._hostname)
    configuration = self.get_module(KernelConfigurationModule)
    await configuration.await_ready()
    self._grace = int(configuration.get(GRACE_KEY))
    self._poll = int(configuration.get(POLL_KEY))
    self._security = self.get_module(KernelSecurityOperationsModule)
    await self._security.await_ready()
    self._rpc = self.get_module(RpcOperationsModule)
    await self._rpc.await_ready()
    self._status = {n: deterministic_guid(self._namespace, "contracts_primitives_enums", "task_status.%s" % n) for n in STATUSES}
    self._disposition = {n: deterministic_guid(self._namespace, "contracts_primitives_enums", "task_disposition.%s" % n) for n in DISPOSITIONS}
    self._sequence_guid = deterministic_guid(self._namespace, "system_sequences", BATCH_SEQUENCE)
    self._module_guid = deterministic_guid(self._namespace, "contracts_modules", self.__class__.__name__)
    providers = discover_classes(f"{__package__}.workflow_execution_providers", "_provider")
    workers = discover_classes(f"{__package__}.workflow_execution_providers", "_worker")
    self._task_provider = providers[TASK_PROVIDER](self._database)
    await self._task_provider.connect()
    await self._reload()
    self._worker = workers[WORKER](self, self._poll)
    await self._worker.start()
    self.raise_ready()

  async def _reload(self):
    # A startup read: the kernel context.
    raw = await self._database.query(DBRequest(DEFINITIONS_READ_ALL, {}, self._kernel))
    rows = [] if raw is None else raw if isinstance(raw, list) else [raw]
    self._definitions = {row["pub_name"]: row for row in rows}
    if self._definitions:
      logger.info("Loaded %d workflow definitions", len(self._definitions))
    else:
      logger.warning("No workflow definitions loaded (empty table or operation not found)")

  def definitions(self) -> dict[str, dict]:
    return self._definitions

  def definition(self, name: str) -> dict | None:
    return self._definitions.get(name)

  def status_guid(self, name: str) -> str:
    return self._status[name]

  def disposition_guid(self, name: str) -> str:
    return self._disposition[name]

  async def next_batch_number(self, context: SecurityContext) -> int:
    # CACHED sequence: a block is burned at allocation; what this process
    # does not hand out before it stops is lost, by design. The allocation
    # runs under the context of the declaration that found the block empty.
    if not self._batch:
      issued = await self._task_provider.allocate(context, self._sequence_guid, self._module_guid, None)
      self._batch = list(range(int(issued["pub_number_from"]), int(issued["pub_number_to"]) + 1))
      logger.info("Allocated batch numbers %d-%d", self._batch[0], self._batch[-1])
    return self._batch.pop(0)

  async def declare(self, context: SecurityContext, row: WorkflowQueueRow) -> None:
    await self._task_provider.declare(context, row)
    logger.info("Declared workflow instance %s (batch %s)", row.key_guid, row.pub_batch_number)

  async def instance(self, context: SecurityContext, key_guid: str) -> WorkflowQueueInstance | None:
    return await self._task_provider.read(context, key_guid)

  async def run_once(self) -> bool:
    # The claim: the kernel context.
    claimed = await self._task_provider.claim(self._kernel, self._status["PENDING"], self._status["RUNNING"])
    if claimed is None:
      return False
    began = time.monotonic()
    # The run context: the job's actor, the declaring principal. In memory;
    # nothing is written for it.
    run = self._security.mint(claimed.ref_context_guid, claimed.ref_actor_guid, claimed.ref_principal_guid, RUN_CHANNEL, True)
    error, may_retry = await self._run_steps(run, claimed)
    await self._settle(run, claimed, began, error, may_retry)
    return True

  async def _run_steps(self, run: SecurityContext, claimed: WorkflowQueueClaim) -> tuple[str | None, bool]:
    # Each step is one RPC dispatch under the run context, correlated by the
    # instance key. The first refusal or raise ends the run. Returns the
    # error (None when every step answered ok) and whether the run may be
    # retried: a refusal (ok False with a denial reason) is terminal, since a
    # denial does not change on retry; a function that raised (RPC answers
    # FAILED) and a raise here keep the retry path.
    try:
      steps = WorkflowSteps.model_validate_json(claimed.pub_steps)
      for step in steps.steps:
        response = await self._rpc.dispatch(run, RpcRequest(
          urn=step.contract,
          params=json.dumps(step.params),
          correlation_key=claimed.key_guid,
        ))
        if not response.ok:
          if response.error is None:
            return "step %s answered not ok with no error" % step.contract, False
          return response.error, response.error == FAILED
    except Exception as e:
      return "%s: %s" % (type(e).__name__, e), True
    return None, True

  async def _settle(self, context: SecurityContext, claimed: WorkflowQueueClaim, began: float, error: str | None, may_retry: bool) -> None:
    # The one outcome path, under the context handed in: COMPLETE with its
    # history row; PENDING again when the run may retry and the instance can
    # and has attempts left; otherwise FAILED with its history row.
    key_guid = claimed.key_guid
    if error is None:
      await self._task_provider.complete(context, key_guid, self._status["COMPLETE"])
      logger.info("Workflow instance %s complete (batch %s)", key_guid, claimed.pub_batch_number)
      await self._record_history(context, claimed, "COMPLETE", began, None)
      return
    attempts, limit = claimed.pub_attempts, claimed.pub_max_attempts
    if may_retry and claimed.pub_can_retry and attempts < limit:
      await self._task_provider.retry(context, key_guid, self._status["PENDING"], error)
      logger.warning("Workflow instance %s failed on attempt %d of %d, pending retry: %s", key_guid, attempts, limit, error)
      return
    await self._task_provider.fail(context, key_guid, self._status["FAILED"], error)
    logger.error("Workflow instance %s failed on attempt %d of %d, terminal: %s", key_guid, attempts, limit, error)
    await self._record_history(context, claimed, "FAILED", began, error)

  async def _record_history(self, context: SecurityContext, claimed: WorkflowQueueClaim, outcome: str, began: float, error: str | None):
    # One row per terminal outcome, written under the run context: its actor
    # is the row's actor, the principal is the queue row's, and the context
    # column stays NULL (a run has no context row). started_on is the
    # claim's own stamp and the name is the definition's, both returned by
    # the claim; the run time is measured on this process's monotonic clock
    # from the claim to the outcome, so a clock difference between this host
    # and the database cannot skew it.
    await self._task_provider.record_history(context, WorkflowHistoryRecord(
      key_guid=str(uuid.uuid4()).upper(),
      ref_package_guid=claimed.ref_package_guid,
      ref_definition_guid=claimed.ref_definition_guid,
      ref_instance_guid=claimed.key_guid,
      ref_host_guid=instance_key(self._namespace, self._hostname),
      ref_principal_guid=claimed.ref_principal_guid,
      ref_status_enum_guid=self._status[outcome],
      ref_disposition_enum_guid=claimed.ref_disposition_enum_guid,
      pub_name=claimed.pub_name,
      pub_batch_number=claimed.pub_batch_number,
      pub_attempts=claimed.pub_attempts,
      pub_started_on=claimed.pub_started_on,
      pub_finished_on=datetime.now(timezone.utc).isoformat(),
      pub_duration_ms=int((time.monotonic() - began) * 1000),
      pub_error=error,
      ref_actor_guid=context.ref_actor_guid,
      ref_context_guid=None,
    ))

  async def on_seal(self):
    # Stale-claim recovery, under the kernel context: a RUNNING row past the
    # grace period belongs to a node that died; it goes back to PENDING and
    # the attempt it took counts.
    released = await self._task_provider.release_stale(self._kernel, self._status["PENDING"], self._status["RUNNING"], self._grace)
    if released:
      logger.warning("Released %d stale workflow claim(s)", released)

  async def on_unseal(self):
    if self._worker is not None:
      await self._worker.stop()
    self._definitions.clear()
    self._batch.clear()

  async def shutdown(self):
    self._worker = None
    if self._task_provider:
      await self._task_provider.disconnect()
    self._task_provider = None
    self._definitions.clear()
    self._batch.clear()
    self._database = None
    self._security = None
    self._rpc = None
    self._kernel = None
