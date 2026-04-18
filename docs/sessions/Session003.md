# Unity Platform — Session 4 Handoff

## Project Context

You are working with Elideus on `elideus-group-unity` — a greenfield rebuild
of TheOracleRPC CMS. Code is the engine, data is the application. The Python
codebase is a thin lifecycle engine hosting modules that self-describe their
behavior through database rows.

Repository: `C:\__Repositories\elideus-group-unity` (active)
Legacy reference: `C:\__Repositories\elideus-group` (read-only, do not modify)

## What Session 3 Accomplished

This session completed the maintenance/management module scaffolding, settled
the table naming convention for the long term, executed a full schema rebuild
under the new convention, and standardized logging across the codebase.

### Maintenance and Management Modules — Scaffolded and Running

**DatabaseMaintenanceModule** (`server/modules/database_maintenance_module.py`)
— interface surface for all maintenance activities. Currently stub methods for
`declare_ddl_task`, `reconcile_schema`, `reindex`, `update_statistics`,
`snapshot_schema`. Resolves `DatabaseOperationsModule` in startup. Will grow to
be the single entry point for all maintenance operations — DDL declaration,
index maintenance, statistics refresh, dacpac-style schema snapshots for
audit/investigative records. Callers never talk to the management module
directly.

**DatabaseManagementModule** (`server/modules/database_management_module.py`)
— mechanism layer. Composes a `DatabaseManagementProvider` during `startup()`
by calling `DatabaseExecutionModule.get_base_provider()` to borrow the live
`DatabaseTransactionProvider` (shared pool, not a parallel one). Starts an
internal monitoring loop in `on_seal()` that polls the task queue table
(`service_tasks_ddl`) at a rate configurable via `system_configuration`
(`TaskDdlPollRate`, defaults to 5.0 seconds). The loop currently no-ops —
`_process_pending_tasks` is a pass. Drains cleanly via `on_drain()` → sets
loop stop event → awaits task completion.

**Design principle enforced**: maintenance and management do not share
in-process calls. Maintenance declares tasks into `service_tasks_ddl`, the
management loop picks them up on its own cadence. The task table is the
boundary.

### Provider Contracts — Shared Pool via Composition

Both provider ABCs now live in `server/modules/database_execution_providers/__init__.py`:

**DatabaseTransactionProvider** (renamed from BaseDatabaseProvider)
— owns the connection pool. Contract: `connect()`, `disconnect()`, `query()`,
`execute()`.

**DatabaseManagementProvider** (renamed from BaseDatabaseManagementProvider)
— composes with a live `DatabaseTransactionProvider` instance passed in via
constructor. Does NOT own the pool, borrows it. Contract: `read_tables`,
`read_columns`, `read_indexes`, `read_constraints`, `create_table`,
`alter_column`, `create_index`, `drop_constraint`, `drop_index`,
`supports_online_index_rebuild`, `supports_native_vector`.

Concrete implementations:
- `MssqlProvider` in `mssql_transaction_provider.py` (renamed from mssql_provider.py)
- `MssqlManagementProvider` in `mssql_management_provider.py` — stub; `read_*` methods return `[]`, DDL methods return `False`, capability methods return `True`.

**New method on DatabaseExecutionModule**: `get_base_provider()` returns the
live `DatabaseTransactionProvider` as contract. This is the composition seam
— management module receives the provider through the contract, not via
private attribute access. This is the Manager/Executor/Provider pattern with
composition extension: management gets transactional capabilities via the
composed contract, plus its own DDL surface.

### Module Self-Manifest Pattern — Wired into BaseModule

`BaseModule.on_seal()` now concrete (no longer abstract). Every module's
seal step runs through `_seal_manifest()`, which calls three extensible hooks
in sequence:

```python
async def _hook_fetch_seed_package(self): pass        # fetch the install payload
async def _hook_check_version(self) -> bool: return True  # already installed?
async def _hook_install_seed_package(self): pass      # run the install
```

Default implementations no-op (fetch does nothing, check returns True meaning
"already installed", install does nothing). Modules override as needed. The
machinery is fully in place; implementations land when modules start shipping
seed packages.

When `_hook_install_seed_package` completes cleanly, the manifest row is
written to `service_modules_manifest` with `pub_is_sealed = 1`. Failed
installs leave no row — module retries from scratch next boot. Idempotent.

### Schema Naming Convention — Settled and Applied

The top-level prefix set for all tables:

| Prefix | Semantic |
|---|---|
| `service_*` | Kernel data (types, enums, DB operations, module manifest, DDL tasks) |
| `system_*` | Application data (configuration, API keys, extension toggles) |
| `objects_*` | Meta-description (schema reflection, future: components, contracts, security) |
| `staging_*` | Transient data (reconciliation, imports, exports, merge workflows) |
| `<module>_*` | Domain-owned data |

Three-level naming: `prefix_subdomain_entity` for primary tables.
Four-level for junctions: `prefix_subdomain_entity_joinentity`.

Current schema (12 tables, all deployed under new names):

| Table | Alias |
|---|---|
| `service_types` | `st` |
| `service_enums` | `se` |
| `objects_schema_tables` | `ost` |
| `objects_schema_columns` | `osc` |
| `objects_schema_indexes` | `osi` |
| `objects_schema_index_columns` | `osic` |
| `objects_schema_constraints` | `osco` |
| `objects_schema_constraint_columns` | `oscc` |
| `system_configuration` | `sc` |
| `service_modules_manifest` | `smm` |
| `service_tasks_ddl` | `std` |
| `service_database_operations` | `sdo` |

**New column on `objects_schema_tables`**: `pub_alias NVARCHAR(16) NOT NULL`
with `UQ_ost_alias` unique constraint. Alias is explicit data, used in
query construction. Collision resolution rule: "initials first, extend by
one letter at a time from the last word until unique" — applied manually
for the current 12 tables.

**Rule enforced**: No `NEWID()` defaults on any schema table. All keys are
deterministic. All 5 `DEFAULT (NEWID())` declarations were stripped.

### Deterministic GUID Scheme — Updated

Old scheme: `uuid5(NS_HASH, "{short_token}:{natural_key}")` with tokens like
`type`, `enum`, `database_table`.

New scheme: `uuid5(NS_HASH, "{containing_table}:{natural_key}")` where the
entity type token IS the full name of the table storing the row. Examples:

- Type rows: `service_types:BOOL`
- Enum rows: `service_enums:constraint_kind.PRIMARY_KEY`
- Table reflection: `objects_schema_tables:dbo.system_configuration`
- Column reflection: `objects_schema_columns:dbo.system_configuration.key_guid`
- Constraint reflection: `objects_schema_constraints:dbo.system_configuration.PK_system_configuration`
- Constraint-column junction: `objects_schema_constraint_columns:dbo.system_configuration.PK_system_configuration.key_guid`
- Config: `system_configuration:TaskDdlPollRate`
- Manifest: `service_modules_manifest:DatabaseManagementModule`
- Task rows: `service_tasks_ddl:{operation}.{target}`
- Op rows: `service_database_operations:{pub_op}`

Entity type token uses `.` as natural-key separator where the natural key
has multiple components. Self-describing — the token tells you which table
the row lives in, the natural key tells you exactly what object it describes.

### Schema Rebuild — Executed Successfully

Full drop and rebuild completed. Final seed state: 47 rows across the
12 tables (19 types, 18 enums across four enum types, 10 reflection rows
for `system_configuration` as bootstrap exception).

Reflection is seeded only for `system_configuration` currently. Other
11 tables have no reflection rows yet — the plan is to build a generator
that queries the live database via `INFORMATION_SCHEMA` + `sys.*` and
emits the reflection seed. This generator also serves as the prototype
for the management module's `read_*` introspection methods later.

### Refactor Script — Produced and Preserved

`migrations/generate_v1_rebuild.py` is a Python refactor tool with
composable transformation functions:

- `rename_table(sql, old, new)`
- `rename_constraint(sql, old, new)`
- `rename_index(sql, old, new)`
- `rename_column(sql, table, old, new)`
- `remove_column_default(sql, table, col)` — strips DEFAULT clause from a column
- `add_column(sql, table, col_def, after_column)` — inserts column with matching indentation
- `add_table_constraint(sql, table, constraint_def)` — appends constraint to CREATE TABLE
- `replace_guid(sql, old_guid, new_guid)` — case-insensitive GUID swap
- `update_formula_comment(sql, old, new)` — updates uuid5 documentation in comments

The script reads `v1.0.0_foundation.sql` and `v1.0.0_seed.sql`, applies the
transforms in documented order, writes `.new` versions. Preserved as reference
for the management module's DDL engine — the primitives are what the
management module will eventually need in its structured DDL interface.

**Known bug found during rebuild**: initial `remove_column_default` used a
regex that didn't handle nested parens in `DEFAULT (NEWID())`, leaving stray
`)` after stripping. Fixed in final version. Documented here so the next
iteration of these primitives starts from the corrected implementation.

### Logging — Standardized

All modules adopted `logger = logging.getLogger(__name__.split('.')[-1])`
pattern at module scope. Per-file logger names identify the emitting module
in each log line. Format:

```
INFO:database_management_module:Monitor loop started (rate=5.00s)
INFO:modules:on_startup_complete — sealed
WARNING:system_configuration_module:Key 'TaskDdlPollRate' not in cache
```

The `[ModuleName]: ` prefix was stripped from message strings since the
logger name now carries that context. ModuleManager's own logger emits under
`modules` (from `server.modules.__init__`). Pattern deviations in `%s`
formatting were cleaned up in the same pass.

Empty-cache warnings bumped from info to warning severity:
`SystemConfigurationModule: No config rows (empty table)` and the get()
key-miss log. Running with zero configuration is operationally noticeable;
warning fits better than info.

### Typo to Watch in BaseModule

`_seal_manifest` has a typo in its error log: `_hook_install_seed_pacakge`
(missing `a`). Cosmetic, but worth fixing the next time that file is touched.

## Pending Items for Session 4

### Priority 1: Documentation Pass

The system is stable and the naming convention is settled. Before further
functional work, produce documentation for:

1. **Module pattern and lifecycle** — `docs/specs/module_lifecycle.md`
   - BaseModule contract (startup, on_seal, on_drain, shutdown)
   - ModuleManager phases (startup_init, startup_all, startup_complete)
   - Dependency resolution pattern (get_module + on_ready)
   - Sealed state and its use
   - Manifest self-install flow (hooks, idempotency, seal-on-success)
   - Mermaid sequence diagrams for startup and shutdown

2. **Provider composition pattern** — `docs/specs/provider_composition.md`
   - Transaction provider contract (connect/disconnect/query/execute)
   - Management provider contract (read_*/DDL/capability)
   - Composition via shared pool (get_base_provider)
   - Why composition over inheritance
   - Manager/Executor/Provider model generalization
   - Mermaid diagram of request flow through the composed providers

3. **Maintenance and Management modules** — `docs/specs/database_management.md`
   - Role of each module (interface vs mechanism)
   - Task queue boundary (service_tasks_ddl)
   - Monitor loop cadence (TaskDdlPollRate)
   - Drainstop coordination (pub_requires_drain)
   - Task lifecycle (pending → running → complete/failed, cancelling)
   - Task disposition (reversible/irreversible/transient/cancellable)
   - Sequence diagram: maintenance declares → management picks up → executes

4. **Schema naming convention** — `docs/specs/naming_conventions.md`
   - Five top-level prefixes (service/system/objects/staging/module)
   - Three-level naming, four-level for junctions
   - Column prefixes (key/pub/priv/ref/ext)
   - Alias system and pub_alias column
   - Deterministic GUID formula with entity_type = containing table
   - Constraint/index naming (PK/FK/UQ/IX_alias_detail)

5. **Security model** — `docs/specs/security.md`
   - URN namespace (urn:service:*, urn:system:*, urn:<domain>:*)
   - Role pattern (ROLE_SERVICE_ADMIN, ROLE_SYSTEM_ADMIN, ROLE_<DOMAIN>, REGISTERED_USER, ROLE_MODERATOR)
   - Entitlement pattern for subdomain access
   - RPC dispatch as security boundary
   - Module methods vs RPC operations (internal vs external surface)

6. **Coding standards** — `docs/specs/coding_standards.md`
   - 2-space indentation, snake_case files, PascalCase classes
   - `%s` log formatting (not f-strings)
   - match/case over if/elif
   - Module-scope logger via `__name__.split('.')[-1]`
   - Graceful None/0 returns with logger.error, no control-flow exceptions
   - Deterministic GUIDs only on schema tables (no NEWID())
   - FOR JSON PATH on every SELECT; WITHOUT_ARRAY_WRAPPER for single-row
   - MSSQL UPPERCASE, Postgres/MySQL lowercase in type strings
   - Never reach into another module's internals — contracts only

Claude should propose the document set, Elideus reviews the proposal, and
Claude drafts each in turn. Diagrams should be mermaid embedded in markdown.

### Priority 2: Reflection Seed Generator

A second Python script that connects to the live database, queries
`INFORMATION_SCHEMA.TABLES/COLUMNS` and `sys.indexes/sys.foreign_keys/sys.key_constraints/etc`,
and emits the reflection seed rows for the 11 tables that don't have them yet.

This is also the prototype for `MssqlManagementProvider.read_*` methods. The
queries used in the generator are the ones the management provider will run
for live diffs later. Two uses for one script.

### Priority 3: Management Module Read Methods

`MssqlManagementProvider.read_tables`, `read_columns`, `read_indexes`,
`read_constraints` implementations. Queries drawn from the reflection
generator from Priority 2. Foundation for the diff engine.

### Priority 4: Task Declaration Plumbing

`DatabaseMaintenanceModule.declare_ddl_task(operation, target, spec, disposition)`
implementation. Computes deterministic GUID for the task
(`service_tasks_ddl:{operation}.{target}`), INSERTs into `service_tasks_ddl`
with `pub_status = pending`. No-op if the same task already exists and is
pending or running (dedupe via deterministic key).

### Priority 5: Management Loop Task Processing

`DatabaseManagementModule._process_pending_tasks` implementation. SELECT
pending tasks, UPDATE to running, dispatch to the appropriate management
provider method via operation-enum-guid lookup, UPDATE to complete/failed,
handle drainstop coordination for `pub_requires_drain` tasks.

### Priority 6: Seed Package Mechanism

The `_hook_fetch_seed_package` and `_hook_check_version` machinery currently
returns defaults that skip install. Real implementations — pip wheels, git
archives, whatever delivery mechanism gets decided — slot in via these
hooks. Not urgent; the machinery is in place waiting for content.

### Standing Backlog

- Typo fix in `BaseModule._seal_manifest`: `_pacakge` → `_package`
- Seed SQL idiom: transition INSERTs to MERGE semantics for idempotent re-runs.
  Currently a nuke-and-redo is needed when seed fails partway; MERGE would
  allow re-running the same seed file safely. Important for module seed
  packages shipping later.
- `TaskDdlPollRate` config key should be seeded by DatabaseManagementModule's
  future seed package (or by a system-tier seed that declares all platform
  config keys with defaults).
- `DatabaseManagementProvider` type reference comment in the file header
  still says `BaseDatabaseManagementProvider` in several places — cosmetic.

## Coding Conventions (for quick reference)

- snake_case files, PascalCase classes (mechanical `snake_to_pascal`)
- 2-space indentation
- `logger = logging.getLogger(__name__.split('.')[-1])` at module scope
- `%s` log formatting, not f-strings in log calls
- match/case over if/elif
- No raise/except for control flow; `logger.error` + graceful None/0
- Column prefixes: `key_*` PK, `pub_*` functional, `priv_*` audit,
  `ref_*` FK, `ext_*` extension
- Deterministic UUID5 keys on all schema tables; NEWID() only on
  async-tracking tables (sessions, workflow activities)
- FOR JSON PATH on every SELECT; WITHOUT_ARRAY_WRAPPER for single-row
- MSSQL type strings UPPERCASE in seed; Postgres/MySQL lowercase
- Three-level naming for tables: `prefix_subdomain_entity`
- Four-level for junctions: `prefix_subdomain_entity_joinentity`
- Deterministic GUID natural keys use containing-table name as entity type
- Never reach into another module's internals — contracts only
- References obtained in `startup()`, not `__init__` (async readiness)

## Interaction Style

Elideus writes all production code. Claude is architectural thinking
partner, syntax helper, research assistant, and design reviewer. Do not
generate large code blocks unsolicited. Keep responses focused. When in
doubt about a pattern, ask before generating. Elideus will tell you
when to expand.

For the documentation pass in priority 1, code examples in documents are
fine and expected — but keep them as illustrative snippets, not full
module reproductions. The goal is to document patterns, not paste code.
