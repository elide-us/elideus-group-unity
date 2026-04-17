# Unity Platform — Session 3 Handoff

## Project Context

You are working with Elideus on `elideus-group-unity` — a greenfield rebuild
of TheOracleRPC CMS. Code is the engine, data is the application. The Python
codebase is a thin lifecycle engine hosting modules that self-describe their
behavior through database rows.

Repository: `C:\__Repositories\elideus-group-unity` (active)
Legacy reference: `C:\__Repositories\elideus-group` (read-only, do not modify)

## What Exists in the Repo Today

### Infrastructure
- Dockerfile (Python 3.13-trixie, ODBC 18.6.2)
- Pinned requirements.txt (FastAPI, MCP SDK, discord.py, aioodbc, etc.)
- `helpers.py` — `deterministic_guid(ns_hash, entity_type, natural_key)`
  using uuid5. Namespace: `DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB`.
  Also: `snake_to_pascal`, `pascal_to_snake`, `camel_to_snake`, `snake_to_camel`.

### Module System (`server/modules/__init__.py`)

**BaseModule** — abstract base with four lifecycle hooks:
- `startup()` — resolve deps via `get_module()` + `await on_ready()`,
  load data, open resources, call `mark_ready()`.
- `on_seal()` — post-init work after all modules are live. Runs
  concurrently. `_sealed = True` set AFTER all on_seal() calls complete.
- `on_drain()` — pre-shutdown signal. Stop accepting work.
- `shutdown()` — teardown.

Dependency pattern: modules call `get_module(T)` then `await T.on_ready()`.
Always declare every dependency explicitly — never rely on transitive
readiness through another module. The graph must be a DAG; circular
`on_ready()` waits deadlock silently.

**ModuleManager** — three-phase startup, three-phase shutdown:
- `_on_startup_init()` — sync autodiscovery of `*_module.py` files
- `_on_startup_all()` — concurrent `startup()` via `asyncio.gather`
- `_on_startup_complete()` — concurrent `on_seal()`, then `_sealed = True`
- `_on_shutdown_init()` — concurrent `on_drain()`
- `_on_shutdown_all()` — concurrent `shutdown()`, clear registry
- `_on_shutdown_complete()` — `_sealed = False`

The manager only calls the contract. It does not orchestrate composition,
pass references, or know dependency order. Modules are self-sufficient.

### Bootstrap Modules (deployed, running)

| Module | Table | Pattern |
|---|---|---|
| `EnvironmentVariablesModule` | reads `.env` | sync load, `mark_ready()` |
| `DatabaseExecutionModule` | none (pool) | selects provider by `SQL_PROVIDER`, opens aioodbc pool |
| `DatabaseOperationsModule` | `service_database_operations` | bootstrap cache + lazy-load, `DBRequest(op, params)` |
| `SystemConfigurationModule` | `system_configuration` | full bootstrap cache, sync `get(key)`, no lazy-load |
| `SystemEnumModule` | `system_objects_enums` | bootstrap cache + async `get()` with lazy-load on miss |

### Provider Layer (`server/modules/database_execution_providers/`)

**`BaseDatabaseProvider`** (ABC in `__init__.py`):
- `connect()`, `disconnect()`, `query()` → parsed JSON, `execute()` → int

**`BaseDatabaseManagementProvider`** (ABC in `__init__.py`):
- Composes with `BaseDatabaseProvider` (borrows pool, does not own it)
- Constructed during the management module's `startup()` via
  `get_module(DatabaseExecutionModule)` + `on_ready()`, then wrapping
  `exec_module._provider`.
- Schema introspection: `read_tables`, `read_columns`, `read_indexes`,
  `read_constraints`
- DDL emission: `create_table`, `alter_column`, `create_index`,
  `drop_constraint`, `drop_index`
- Capability reporting: `supports_online_index_rebuild`,
  `supports_native_vector`

**`MssqlProvider`** (`mssql_provider.py`) — concrete execution provider, running.

**`MssqlManagementProvider`** — NOT in repo yet. Stub drafted, needs commit.

### Database Schema (deployed on Azure SQL)

**Service tables:**
- `service_database_operations` — ops registry with per-provider SQL columns

**Schema definition tables (`system_objects_*`):**
- `system_objects_types` — 19 platform types (BOOL through VECTOR).
  MSSQL types UPPERCASE. `pub_default_length` is the type-level default;
  column-level `pub_max_length` overrides. Identity is a type
  (`INT64_IDENTITY`), not a constraint or flag. `pub_max_length` is
  overloaded for VECTOR (dimension count) — valid because no column
  is both a vector and a string.
- `system_objects_enums` — flat table, `pub_enum_type` as grouping key.
  Seeded: `constraint_kind` with 4 values (PRIMARY_KEY, FOREIGN_KEY,
  UNIQUE, CHECK). DEFAULT is a column attribute (`pub_default_value`),
  not a constraint.
- `system_objects_database_tables` — deterministic GUID from
  `"database_table:{schema}.{name}"`.
- `system_objects_database_columns` — FK to tables + types.
  `pub_ordinal`, `pub_is_nullable`, `pub_default_value`, `pub_max_length`.
  No `pub_is_identity` or `pub_is_primary_key` flags.
- `system_objects_database_indexes` — FK to tables.
- `system_objects_database_index_columns` — junction: FK to indexes +
  columns, `pub_ordinal` for predicate ordering.
- `system_objects_database_constraints` — FK to tables + enums
  (`ref_kind_enum_guid`). `ref_referenced_table_guid` for FKs.
  `pub_expression` for CHECK constraints.
- `system_objects_database_constraint_columns` — junction: FK to
  constraints + columns. `ref_referenced_column_guid` for FK mappings.
- `system_configuration` — `key_guid`, `pub_key`, `pub_value`, audit.
  Reflection data seeded. Table is empty (no config values yet).
- `system_objects_modules` — module registry for self-initialization
  tracking. Table exists but init pattern not wired into BaseModule.

**NOT yet deployed:**
- `system_objects_database_views` / `_view_columns`
- Staging mirror tables for reconciliation
- DDL primitives table

### Deterministic Key Formulas

| Entity | Formula |
|---|---|
| Type | `uuid5(NS_HASH, "type:{pub_name}")` |
| Enum | `uuid5(NS_HASH, "enum:{pub_enum_type}:{pub_name}")` |
| Table | `uuid5(NS_HASH, "database_table:{schema}.{name}")` |
| Column | `uuid5(NS_HASH, "database_column:{table}.{column}")` |
| Constraint | `uuid5(NS_HASH, "database_constraint:{table}.{name}")` |
| Config | `uuid5(NS_HASH, "system_configuration:{pub_key}")` |
| Module | `uuid5(NS_HASH, "module:{pub_name}")` |
| DB Operation | `uuid5(NS_HASH, "database_operation:{pub_op}")` |

## Decisions Locked In (Not Yet Built)

### 1. Two-Module Split for Schema Management

**DatabaseMaintenanceModule** — policy layer:
- Monitors staging tables for pending schema/seed-data changes
- Diffs staged desired-state against deployed state and actual DB state
- Plans DDL sequences (topological sort on FK dependencies)
- Validates plans against system capabilities
- Signals drainstop when needed for destructive operations
- Dispatches `DatabaseManagementModule` to execute planned DDL
- Reconciliation runs during `on_seal()` (all modules live, not yet sealed)

**DatabaseManagementModule** — mechanism layer:
- Structured DDL interface (callers submit specs, not SQL)
- Composes `BaseDatabaseManagementProvider` during `startup()` by
  getting `DatabaseExecutionModule` via `get_module()` + `on_ready()`,
  then wrapping `exec_module._provider` in the management provider.
- DDL methods check `module_manager._sealed` before executing.
- Read methods (schema introspection) are always allowed.
- NOT exposed via RPC/MCP. Internal only.

### 2. Azure SQL System Catalog for Actual-State Verification

The internal `system_objects_database_*` tables are the declared/desired
schema (keyed by deterministic GUIDs). They are the source of truth for
what SHOULD exist.

For actual-state verification during reconciliation, the maintenance
module uses Azure SQL's system catalog views. These are the full set
available on Azure SQL Database PaaS:

**Object catalog views (sys.*):**

| View | What it provides |
|---|---|
| `sys.objects` | Base view: all schema-scoped objects (tables, views, functions, constraints, etc.) with `object_id`, `type`, `schema_id`, `create_date`, `modify_date` |
| `sys.tables` | Inherits from `sys.objects`. One row per user table. |
| `sys.views` | One row per view. Join to `sys.sql_modules` for view definition SQL. |
| `sys.columns` | Columns for all objects (tables AND views). `object_id`, `column_id`, `name`, `user_type_id`, `max_length`, `precision`, `scale`, `is_nullable`, `is_identity`, `is_computed` |
| `sys.types` | System and user-defined types. Join to `sys.columns` via `user_type_id` for type resolution. `name`, `max_length`, `precision`, `scale` |
| `sys.schemas` | Schema names. Join via `schema_id` on `sys.objects`/`sys.tables`. |
| `sys.identity_columns` | Identity columns with `seed_value`, `increment_value`, `last_value` |
| `sys.computed_columns` | Computed columns with `definition`, `is_persisted` |
| `sys.masked_columns` | Columns with dynamic data masking |
| `sys.indexes` | All indexes including heaps. `index_id`, `type` (clustered/nonclustered), `is_unique`, `is_primary_key`, `is_unique_constraint`, `is_disabled`, `fill_factor` |
| `sys.index_columns` | Index-to-column junction. `index_id`, `column_id`, `key_ordinal`, `is_descending_key`, `is_included_column` |
| `sys.key_constraints` | PK and UNIQUE constraints. `type` = 'PK' or 'UQ'. `unique_index_id` links to `sys.indexes` |
| `sys.foreign_keys` | FK constraints. `parent_object_id` (source table), `referenced_object_id` (target table), `delete_referential_action`, `update_referential_action` |
| `sys.foreign_key_columns` | FK column mappings. `parent_column_id`, `referenced_column_id`, `constraint_column_id` (ordinal) |
| `sys.check_constraints` | CHECK constraints. `definition` holds the SQL predicate, `parent_column_id` for column-level checks |
| `sys.default_constraints` | DEFAULT constraints. `definition` holds the default expression, `parent_column_id` |
| `sys.sql_modules` | SQL definitions for views, procedures, functions, triggers. `definition` column holds the full SQL text |
| `sys.stats` | Statistics objects. One per index + additional auto-created stats |
| `sys.stats_columns` | Statistics-to-column mapping with ordinal |
| `sys.sequences` | Sequence objects (if used) |

**INFORMATION_SCHEMA views (cross-platform compatible):**

| View | What it provides |
|---|---|
| `INFORMATION_SCHEMA.TABLES` | Table/view listing with `TABLE_TYPE` |
| `INFORMATION_SCHEMA.COLUMNS` | Column metadata: type, nullability, defaults, ordinal |
| `INFORMATION_SCHEMA.TABLE_CONSTRAINTS` | PK, FK, UNIQUE, CHECK constraint names and types |
| `INFORMATION_SCHEMA.KEY_COLUMN_USAGE` | Column participation in PK/FK/UNIQUE constraints |
| `INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS` | FK cascade rules, referenced constraint |
| `INFORMATION_SCHEMA.CHECK_CONSTRAINTS` | CHECK constraint expressions |
| `INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE` | Columns referenced by constraints |

**Design decision:** The `sys.*` catalog views are the primary source
for MSSQL. They expose richer metadata than INFORMATION_SCHEMA (index
includes, fill factors, identity seed/increment, computed column
definitions, statistics, masking). INFORMATION_SCHEMA is available as a
cross-provider fallback for Postgres/MySQL providers.

The delta comparison is: declared state (`system_objects_*` tables) vs
actual state (`sys.*` views). The management provider's `read_*` methods
query the system catalog. The maintenance module owns the diff logic.
No internal delta record is maintained — the comparison is always live.

### 3. Views Support Needed

`system_objects_database_views` and `system_objects_database_view_columns`
need to be designed and deployed. Views are managed through the same
maintenance/management pipeline. View definitions stored in
`pub_definition`. Actual state verified against `sys.views` +
`sys.sql_modules` (for the SQL text).

### 4. Staging Table Pattern

Modules declare desired state by writing to `staging_*` mirror tables
during `_run_initialization()` or `_run_migration()`. The maintenance
module reads staging, diffs against live + actual, executes DDL via
management module, merges staging into live on success, clears staging.
Not yet designed or deployed.

### 5. Module Self-Initialization Pattern

`system_objects_modules` table exists. The pattern (check registry →
not present → `_run_initialization()` → mark initialized) is designed
but not wired into BaseModule. Modules currently start up without
checking the registry.

## Stubs Ready to Commit

Three files were drafted in Session 2 but not committed to the repo:

**`database_management_module.py`** — composition during `startup()`:
```python
async def startup(self):
  env = self.get_module(EnvironmentVariablesModule)
  await env.on_ready()
  exec_module = self.get_module(DatabaseExecutionModule)
  await exec_module.on_ready()
  provider_name = env.get("SQL_PROVIDER")
  match provider_name:
    case "AZURE_SQL_CONNECTION_STRING":
      from .database_execution_providers.mssql_management import MssqlManagementProvider
      self._mgmt_provider = MssqlManagementProvider(exec_module._provider)
    case _:
      logging.error("DatabaseManagementModule: Unknown provider '%s'", provider_name)
      return
  self.mark_ready()
```
- DDL methods check `module_manager._sealed` before executing
- Read methods (introspection) always allowed
- `on_seal()` is pass — sealed check is per-call

**`database_maintenance_module.py`** — reconciliation stub:
- `startup()` marks ready (trivially)
- `on_seal()` is where reconciliation will run (currently pass)
- Gets management module via `get_module()` + `on_ready()` in `on_seal()`

**`mssql_management.py`** — concrete provider stub:
- All `read_*` methods return empty lists
- All DDL methods return False
- Capability methods return True (Azure SQL supports both online index
  rebuild and native vector)

## Coding Conventions

- snake_case files, PascalCase classes (mechanical `snake_to_pascal`)
- 2-space indentation
- `%s` log formatting, not f-strings in log calls
- match/case over if/elif
- No raise/except for control flow; `logging.error` + graceful None/0
- Column prefixes: `key_*` PK, `pub_*` functional, `priv_*` audit,
  `ref_*` FK, `ext_*` extension
- Deterministic UUID5 PKs from NS_HASH; NEWID() for user-generated rows
- FOR JSON PATH on every SELECT; WITHOUT_ARRAY_WRAPPER for single-row
- MSSQL type strings UPPERCASE in seed data (matches SSMS conventions)

## Immediate Next Work

### Priority 1: Commit the Three Stubs
Review and drop `database_management_module.py`,
`database_maintenance_module.py`, and `mssql_management.py` into the repo.

### Priority 2: Implement MssqlManagementProvider Introspection
The `read_*` methods should query the `sys.*` catalog views listed above.
This is the foundation for the diff engine. Build the queries, return
structured dicts that can be compared against `system_objects_database_*`
table data.

### Priority 3: Design and Deploy Views Tables
`system_objects_database_views` and `_view_columns`. Add to foundation
DDL and seed.

### Priority 4: Design Staging Tables
Mirror tables for each `system_objects_database_*` table. Modules write
desired state here during init; maintenance reconciles.

### Priority 5: Wire Module Self-Init into BaseModule
Registry check in startup flow. Requires `system_objects_modules` ops
seeded and the init pattern wired.

## Interaction Style

Elideus writes all production code. Claude is architectural thinking
partner, syntax helper, research assistant, and design reviewer. Do not
generate large code blocks unsolicited. Keep responses focused. When in
doubt about a pattern, ask before generating. Elideus will tell you
when to expand.