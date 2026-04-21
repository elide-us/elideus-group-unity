# Unity Platform — Session 6 Handoff (clean-state review context)

## Project context

You are working with Elideus on `elideus-group-unity`, a greenfield rebuild of TheOracleRPC CMS. Code is the engine, data is the application. The Python codebase is a thin lifecycle engine hosting modules that self-describe their behavior through database rows. OS-kernel quality and efficiency standards apply within the constraints of a Python app.

- **Product:** TheOracleRPC
- **Codename:** Unity
- **Active repository:** `C:\__Repositories\elideus-group-unity`
- **Legacy repository (reference only, no pattern copying):** `C:\__Repositories\elideus-group`

Filesystem MCP has access to both repositories. Claude does not have write access through MCP — file deliverables go through the create_file tool to `/mnt/user-data/outputs/`, then get presented for Elideus to drop into the repo manually.

## Critical orientation

**The legacy repo is reference-only.** It demonstrates exemplary workflows and ideas worth drawing from at the *concept* level — not at the *schema* or *naming* level. Unity uses an entirely different column convention (`key_*` / `pub_*` / `priv_*` / `ref_*`) and a different entity decomposition. Reading legacy tables to seed Unity schema thinking contaminates alignment with the project. If the user asks for reference to legacy, it's for concepts (workflow state semantics, disposition classifications, worker-dispatch shapes) — never for column names, table layouts, or direct code patterns.

**Unity naming conventions (from `migrations/v1.0.0_foundation.sql`):**
- `key_*` — primary key columns (e.g., `key_guid`)
- `pub_*` — functional/public data
- `priv_*` — audit fields (timestamps, error text)
- `ref_*` — foreign key references
- `ext_*` — reserved for future extension package columns

**Deterministic GUIDs** are computed as `uuid5(NS_HASH, "{entity_type}:{natural_key}")` where `NS_HASH = DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB`.

## Current state of work

Session 5 and this session produced a three-spec documentation set plus a code refactor of the database management axis. The user is about to do a holistic review of the documents in a clean context.

### Documents in the repo

Read these in order before doing anything else:

1. **`docs/module_lifecycle.md`** — foundational; owns module contract, phases, seal protocol, manager mechanics. Completed in Session 4.
2. **`docs/kernel_architecture.md`** — the Manager/Executor/Provider pattern, the three-slot taxonomy, and the three kernel subsystems (Database, Auth, IoGateway). Produced this session. Not yet reviewed holistically.
3. **`docs/provider_composition.md`** — provider ABC contracts, primary vs composed, `get_base_provider()` handoff, composition-over-inheritance rationale. Produced earlier session.
4. **`docs/database_management.md`** — specifies the Maintenance/Management axis of the Database subsystem: `service_tasks_ddl`, task lifecycle, worker mechanics, the DDL-specific application of the M/E/P pattern with Worker-role provider. Produced this session.

### Key taxonomy locked in `kernel_architecture.md` §3

Three abstract roles, each with a finite set of concrete role-names:

- **Manager** slot: `Operations` (hot-path), `Maintenance` (privileged), `Interface` (symmetrical)
- **Executor** slot: `Execution` (direct dispatch), `Management` (queue-mediated)
- **Provider** slot: `Provider` (mediates a resource), `Worker` (performs dispatched work), `Gateway` (bidirectional shape normalization)

The naming is deliberately finite and decouples the pattern slot from the work-type description.

### Code changes shipped this session

The database management axis was refactored to extract loop mechanics into a dedicated Worker class:

- `server/kernel/__init__.py` — added `BaseWorker` ABC at the top of the file (minimal `start()` / `stop()` contract).
- `server/kernel/database_execution_providers/database_management_worker.py` — new file. Owns the poll loop, claim-and-dispatch mechanics, stale-claim recovery. Not a module; instantiated by `DatabaseManagementModule` after provider selection.
- `server/kernel/database_execution_providers/__init__.py` — added `DdlTaskClaim` dataclass; added four queue-operation methods to `DatabaseManagementProvider` ABC (`claim_next_task`, `mark_task_completed`, `mark_task_failed`, `recover_stale_claims`).
- `server/kernel/database_execution_providers/mssql_management_provider.py` — stubs for the new queue methods.
- `server/kernel/database_management_module.py` — worker construction moved inside the provider-selection match block. `on_drain` signals worker stop, `shutdown` clears references.

**Known code alignment issues the spec calls out but are not yet fixed:**
- Worker imports in `database_management_worker.py` are relative but treat the file as if still in `server/kernel/` — should be `from .. import BaseWorker, ModuleManager` and `from . import DatabaseManagementProvider`.
- `DdlTaskClaim` dataclass field names still predate the table design. Spec target shape in `database_management.md` §11.
- `DatabaseMaintenanceModule.declare_ddl_task` signature predates the enum-GUID design. Spec target shape in `database_management.md` §7.

### Database schema state (v1.0.0)

`migrations/v1.0.0_foundation.sql` and `migrations/v1.0.0_seed.sql` create and seed the foundation:
- `service_types` (19 platform types including UUID, INT64_IDENTITY, VECTOR, DATETIME_TZ, etc.)
- `service_enums` (grouped by `pub_enum_type`, one table for all enums)
- `service_modules_manifest` (module install registry)
- `service_tasks_ddl` (the DDL work queue)
- `service_database_operations` (named-op registry for `DatabaseOperationsModule`)
- `objects_schema_*` family (self-describing schema: tables, columns, indexes, index_columns, constraints, constraint_columns)
- `system_configuration` (key/value config store)

Seeded enum types: `constraint_kind` (4 values), `task_status` (5 values: PENDING/RUNNING/COMPLETE/FAILED/CANCELLING), `task_operation_ddl` (5 values matching DDL provider methods), `task_disposition` (4 values: REVERSIBLE/IRREVERSIBLE/TRANSIENT/CANCELLABLE).

## Subsystem inventory

### Kernel (bottom tier, mediates external boundaries)

1. **Database** — SQL execution, provider-swappable backend. Two axes:
   - Operations: `DatabaseOperationsModule` → `DatabaseExecutionModule` → `DatabaseTransactionProvider` → `MssqlProvider`
   - Maintenance: `DatabaseMaintenanceModule` → `DatabaseManagementModule` → `DatabaseManagementProvider` → `MssqlManagementProvider`, with `DatabaseManagementWorker` composed inside the executor
2. **Auth** — identity verification. `AuthOperationsModule` + `AuthExecutionModule` + `AuthProvider` ABC. Providers: `GoogleProvider`, `MicrosoftProvider` (consumer MSA), `EntraProvider` (MS tenant), `DiscordProvider`, future `AppleProvider`/`MetaProvider`. Plus token providers `BearerProvider`, `McpDcrProvider`, `StaticApiProvider`. Three-method contract: `resolve_identity`, `resolve_authorization`, `resolve_token`. Default stance is unauthorized; identity creation happens via a hook the core-tier Users module registers.
3. **IoGateway** — bidirectional traffic. `IoGatewayInterfaceModule` + `IoGatewayExecutionModule` + `IoGatewayProvider` ABC. Providers: `RpcProvider` (HTTP/React), `McpProvider`, `ApiProvider`, `DiscordProvider`, plus outbound service providers for external APIs.

### Core (next tier, speculative — not yet built)

1. **Users** — identity records, user creation, profile. Registers hooks with Auth.
2. **Security** — security context, roles, entitlements, request authorization.
3. **Storage** — blob storage. Own Manager/Executor/Provider. First provider: Azure Storage. Future: S3, CDN.
4. **Task Orchestration** — scheduled, async, polling, fan-out workflows. Consumes other subsystems. Persists state in the database. Uses the same Worker-role pattern the DDL subsystem uses, likely with its own tables sharing the `task_status` and `task_disposition` enums.

### Dependency direction

Kernel never imports core. Core never imports application modules. Core extends kernel only through hook surfaces the kernel exposes (e.g., Auth's identity-creation hook). Kernel-only deployments return unauthorized for everything Auth-related and work correctly.

## What the user wants done next (in order)

1. **Holistic review of the four spec documents for alignment.** The user is starting a fresh context specifically for this. Look for:
   - Terminology drift between docs
   - References between docs (some point forward to docs that don't exist yet — `auth.md`, `iogateway.md`, `core_architecture.md`, `security.md`, `coding_standards.md`, `naming_conventions.md`)
   - Cross-references that may be stale after taxonomy changes
   - Scope creep or overlap between docs
   - Places where one doc's canonical content is duplicated in another

2. **Remaining spec documents in rough priority order:**
   - `auth.md` — Auth subsystem spec (three-method contract, provider sub-families, token normalization, per-provider tables, hook surface)
   - `iogateway.md` — IoGateway subsystem spec (envelope normalization, per-transport providers, outbound service providers, RPC handoff)
   - `naming_conventions.md` — column prefixes, table prefixes, deterministic GUID formulas, provider folder scoping, role-name conventions
   - `coding_standards.md` — failure sentinels, logger conventions, no raise-for-control-flow, match/case preferences, 2-space Python indent
   - `security.md` — security considerations for the privileged boundary, RPC authorization, Auth hook-surface trust model
   - `core_architecture.md` — once enough kernel is nailed down to make the core tier specification tractable

3. **Code alignment tasks** flagged in `database_management.md` §14 and §15.

## Interaction style

Elideus writes all production code. Claude is architectural thinking partner, syntax helper, research assistant, and design reviewer. Responses should be focused. Don't generate large code blocks unsolicited. When in doubt about a pattern, ask before generating.

For documentation work:
- Prose, not bullets, unless content is genuinely list-shaped.
- Mermaid for diagrams, embedded in markdown.
- Code examples are illustrative snippets, not full module bodies.
- Tables are fine when comparing N things across M axes.
- Propose outlines before drafting. Iterating on a 12-bullet outline is cheaper than iterating on a 3000-word draft.
- Re-read code before answering. Handoff docs drift from reality.
- Push back on overcomplication. The good answers are consistently the simpler ones.
- Don't pattern-invent. Describe the implementation, not the decision space.
- Don't explain what not to do in positive framing — it puts the bad ideas into the reader's head.

## Failure modes to avoid

- **Legacy contamination.** Reading legacy tables and importing their column conventions into Unity specs. If the task is schema-adjacent, read the Unity foundation migration, not legacy.
- **Overcomplicating with parallel mechanics.** When a new concept feels like it needs its own doc or pattern, first check if it fits as a role-name within the existing Manager/Executor/Provider taxonomy. The user has consistently chosen finite-taxonomy-expansion over new-parallel-patterns.
- **Speculative abstraction.** Every line in a spec or code file earns its place. If something isn't needed in v1.0.0, it probably shouldn't be specified in v1.0.0.
- **Duplicating content across specs.** Pattern docs own pattern content, subsystem docs own subsystem content, lifecycle doc owns lifecycle content. Cross-references, not copies.

Read the four documents first. Don't start proposing changes until you've read them end-to-end.