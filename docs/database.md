# Database Subsystem

**Product:** TheOracleRPC
**Codename:** Unity

**Spec document — `docs/database.md`**
**Status:** authoritative reference for the Database subsystem of the
kernel.

---

## 1. Purpose

The Database subsystem is the kernel's SQL access layer. It owns the
connection to the active backend and exposes two public contracts —
a hot-path contract for day-to-day reads and writes, and a privileged
contract for schema change and other serialized, auditable work. It
dispatches statements and returns results. It does not interpret the
SQL it runs, does not know what the rows mean, and does not decide
who may call it.

The subsystem is backend-agnostic by design. One concrete backend is
active per deployment, chosen by configuration at startup and fixed
for the lifetime of the process. The public contracts are identical
across backends.

---

## 2. MEP realization

The kernel's Manager/Executor/Provider pattern pairs three roles with
a set of implementations. Roles name the class of responsibility a 
module has; implementations name what kind of work the module does within 
that role. The pair determines the module name. The roles themselves are 
conceptual — they are not base classes in code.

The Database subsystem is the most fully realized example of the 
pattern in the kernel and populates six concrete implementations 
across the three roles.

| Role | Implementations |
|---|---|
| Manager | Operations, Maintenance |
| Executor | Execution, Management |
| Provider | Provider, Worker |

Role and implementation are independent axes. A module's role is 
determined by where it sits in the dispatch chain, not by the kind 
of work it does. Managers are the public contract surface; Executors 
sit behind a Manager and own dispatch machinery; Providers are the 
engine-specific leaves that actually talk to the backend (or, in the 
Worker's case, to the async task system).

The naming can be read against this grid. *Management* is an Executor 
despite the name — it sits behind the Maintenance Manager and layers 
DDL dispatch on top of the Provider contract. *Maintenance* is the 
Manager it serves. Operations and Execution pair the same way on the 
hot path: Operations is the public Manager, Execution is the Executor 
behind it.

---

## 3. Module relationships and contract boundaries

The six modules resolve into two parallel stacks, one per Manager. 
Both stacks dispatch against the same backend through the same 
pool; neither can reach the other's contract.

**Operations (hot path).** The Operations Manager exposes frequent 
request/response work. A caller submits a named operation and 
parameter values; the contract returns result data or a row count. 
Dispatch is immediate — one await per call, no queuing, no persistence 
of the request.

- `DatabaseOperationsModule` HAS-A `DatabaseExecutionModule`
- `DatabaseExecutionModule` HAS-A `DatabaseProviderInterface`
- Engine-specific `MssqlProviderModule` (and siblings) satisfy the 
  Provider interface, which exposes `query` and `execute`.

**Maintenance (privileged).** The Maintenance Manager exposes declared, 
rather than invoked, work. A caller does not run a schema change 
directly; it declares a task against the async task system 
(`server.core.automation`). A Worker claims those tasks on the async 
system's cadence and dispatches the declared operation back through 
Management against the same backend.

- `DatabaseMaintenanceModule` HAS-A `DatabaseManagementModule`
- `DatabaseManagementModule` holds a `DatabaseProviderInterface` and 
  presents Execution's contract plus DDL operations and application-quiesce 
  control. Its contract is a superset of the Provider's.
- `DatabaseWorkerModule` (stubbed) consumes Management's contract to 
  service claims. Engine-specific `MssqlWorkerModule` (and siblings) 
  satisfy the async task system's work contract.

Ownership across the Maintenance stack splits cleanly:

- Maintenance owns the declaration surface — the set of schema changes 
  and other privileged operations a caller can declare.
- The async task system owns the queue, the claim protocol, and the work contract.
- Management owns the Worker's lifecycle, starting and stopping it via `BaseWorker`.
- The Worker owns dispatch of claimed work through Management.

The two boundaries are separate because they are different kinds of 
work with different failure modes. Hot-path operations must be fast 
and may run concurrently; privileged operations must be serialized, 
auditable, and durable across process restarts. Keeping the contracts 
separate means a caller of Operations cannot reach Maintenance methods, 
and vice versa. The sharing mechanism — one resource, two contracts — 
is specified in `provider_composition.md`; from this subsystem's 
perspective, sharing is a guarantee: both boundaries dispatch against 
the same live backend, and neither can take the pool down from under the other.

---

## 4. The named-operation registry

The Operations Manager dispatches through a registry of named
operations rather than through SQL authored inline by callers.
Every piece of SQL the subsystem runs on behalf of an application
caller is a row in the registry, identified by a short
human-readable name.

Naming operations as data has four consequences.

**Operations are addressable.** A module or tool refers to an
operation by name without importing whichever module owns it. Other
subsystems resolve operations by name at runtime.

**Operations are securable.** Each operation is a row, so it can
carry references to the roles permitted to dispatch it. This is
the first concrete application of Unity's securable-element
pattern — the same row-level role-reference approach extends to
module methods, database fields, and other elements as those are
themselves modeled as rows. The Database subsystem does not enforce
authorization; it surfaces the operation and whatever metadata the
row carries.

**Operations are engine-portable.** Each row carries SQL variants
per supported backend. The active backend is chosen at startup and
fixes which variant runs. Callers never see which backend served
them.

**Operations are auditable.** Adding or changing an operation is a
data change with its own history, not a code deploy.

The registry distinguishes *bootstrap* operations — preloaded at
subsystem startup for hot-path speed — from operations resolved on
first use. Bootstrap status is a property of the row. Operations
whose SQL is not defined for the active backend resolve as misses;
callers cannot distinguish "no variant" from "unknown operation"
at the contract.

The registry's mechanism is owned by the subsystem. Its contents
are not. Whichever module installs an operation populates its row;
the Database subsystem resolves and dispatches any operation
uniformly.

---

## 5. Introspection and mutation

The Maintenance side of the subsystem does two things: it reports
the live backend's structure, and it applies declared changes to it.
The Provider contract answers introspection — what tables, columns,
indexes, and constraints currently exist — against whatever backend
is active. The Worker applies declared changes through Management,
which adds DDL operations on top of the Provider's `query` and
`execute`.

The subsystem does not originate those declarations. A caller
elsewhere in the platform decides what the schema should be and
declares the changes needed to get there; the Maintenance side is
the mechanism by which those changes reach the backend.
Reconciliation between a declared target schema and the live one is
not a kernel concern.