# Session 006 Handoff — REPL→Management Module Migration

**Status:** end-of-session checkpoint, queued for resumption with fresh context.
**Scope:** moving install/uninstall/dump/populate logic out of `scripts/scriptlib.py`
and onto its proper home in the kernel's database subsystem.

---

## 1. Architectural framing — read this first

The next session needs to keep the architecture's shape in mind. The
last session drifted into shorthand ("type graph") and lost some of
the load-bearing distinctions. Anchor on these documents before
proposing any code:

- `docs/n_contracts.md` — the contracts framing. The application IS
  a type graph; every typed entity is a row; `contracts_db_*` is the
  database operation surface.
- `docs/database.md` — the Database subsystem MEP. Six modules, two
  parallel stacks (Operations hot-path, Maintenance privileged), one
  shared connection pool.
- `docs/kernel_architecture.md` — the Manager/Executor/Provider
  pattern. Three slots × multiple role-names per slot.
- `docs/provider_composition.md` — how `DatabaseManagementModule`
  borrows the live transaction provider from `DatabaseExecutionModule`.
- `docs/module_lifecycle.md` — how modules start, seal, and shut down.
- `docs/naming_conventions.md` — table prefixes, column prefixes,
  op string format.

### What the application is

The application is a type graph. Every part of the system that has a
typed identity — every named function, model, field, type, *operation* —
is a row in a contracts table with a deterministic GUID and foreign
keys to the rows it depends on. This is not documentation. It is the
runtime.

`contracts_db_*` catalogs database operations. Every piece of SQL
the application runs is a row. The kernel reads the table, dispatches
the row's SQL, returns the result. SQL never lives in code.

### What scriptlib currently is

`scripts/scriptlib.py` is a development tool. It hard-codes every
piece of SQL it runs — populate's introspection queries, dump's read
queries, materialize's helpers, the MERGE template, uninstall's
queries. **This is a violation of the architecture.** The scriptlib
SQL strings are operations that belong in `contracts_db_operations`,
dispatched through `DatabaseOperationsModule.query()` /
`DatabaseManagementModule`'s composed provider.

The scriptlib was acceptable as scaffolding to bootstrap the kernel
seed work. It is not acceptable as the long-term home.

### What the next session is doing

Migrating the scriptlib's SQL into `contracts_db_operations` rows
(seeded as part of the kernel package), and moving the
orchestration logic (install, uninstall, dump, populate, materialize)
into the kernel's database subsystem — specifically the
`DatabaseManagementModule` composed provider.

The REPL becomes a thin client that calls into kernel modules. It
does not contain SQL. It does not contain orchestration logic. It
contains: argument parsing, output formatting, and tool calls.

---

## 2. Code authorship boundary

**Hand-coded by Elideus exclusively:** everything in `server/kernel/`,
including the management module, providers, workers, and contracts.
Claude proposes API surface, operation row content (`pub_op` names,
`pub_query_mssql` strings), and design. Elideus writes the module
code that consumes those operations.

**Claude may write:** the REPL changes, scriptlib changes (if any
remain), the kernel seed JSON, generator scripts, package JSON files,
proposed operation rows.

This boundary held through session 006 and needs to keep holding.
Scope creep into module code is the failure mode to watch for.

---

## 3. Where the lookup logic goes

There are two related but distinct concerns:

### 3.1 Operation dispatch (already exists)

`DatabaseOperationsModule` already exists and implements the lookup
pattern correctly:

- Holds `_registry: dict[str, str]` mapping `pub_op` → SQL text.
- On startup, bulk-loads ops with `pub_bootstrap = 1` from
  `contracts_db_operations` so the hot path doesn't need a round
  trip on first call.
- On `query(DBRequest)` / `execute(DBRequest)`, looks up the op,
  lazy-loads on cache miss, dispatches through `DatabaseExecutionModule`.
- Provider-aware: `_query_column` is set to `pub_query_mssql`,
  `pub_query_postgres`, or `pub_query_mysql` based on `SQL_PROVIDER`
  env var. Callers never see which variant runs.

This is the dispatch surface for application-level operations.
**The kernel seed needs to populate this table.** Right now it's
empty. The scriptlib's SQL strings are the first content for it.

### 3.2 Schema management (currently stubs)

`DatabaseManagementModule` exists with:
- `_mgmt_provider: ComposedDatabaseManagementProvider | None`
- `_worker: BaseDatabaseManagementWorker | None`

The composed provider ABC (`ComposedDatabaseManagementProvider`) is
defined with method stubs in three groups:

**Schema introspection:** `read_tables`, `read_columns`,
`read_indexes`, `read_constraints` — these read the live database
schema (i.e., what's in the previous session's `populate` and `dump`).

**DDL emission:** `create_table`, `alter_column`, `create_index`,
`drop_constraint`, `drop_index` — these are what `materialize` and
`uninstall` need.

**Capability reporting:** `supports_online_index_rebuild`,
`supports_native_vector` — engine feature flags.

The MSSQL implementation (`MssqlManagementProvider`) is currently
all `return []` / `return False` stubs.

### 3.3 The migration plan

The scriptlib's logic decomposes onto these surfaces:

| scriptlib function | Goes to |
|---|---|
| `populate()` introspection queries | Operation rows in `contracts_db_operations`, dispatched by `DatabaseOperationsModule`. The orchestration (calling each query in sequence) lives in `DatabaseManagementModule` (or a method on the composed provider). |
| `dump()` read queries | Same — operations dispatched through `DatabaseOperationsModule`. |
| `dump()` DDL builders (`_build_create_table` etc.) | These are pure transformations. They live as methods on the composed provider since they're engine-specific. The MSSQL implementation generates MSSQL DDL; a Postgres implementation would generate Postgres DDL. |
| `_materialize()` | A method on `DatabaseManagementModule` that calls the composed provider's introspection + DDL methods. |
| `install()` orchestration (register, seed_schema, materialize, seed_data, seal) | A method on `DatabaseManagementModule`. |
| `uninstall()` orchestration | A method on `DatabaseManagementModule`. |
| `list_packages()` | A method on `DatabaseManagementModule` that dispatches a couple of operations. |
| `make_package()` (planned) | A method on `DatabaseManagementModule`. |
| MERGE template | An operation in `contracts_db_operations`. |

The composed provider (MssqlManagementProvider) stops being all-stubs
and becomes a real implementation that consumes the dispatch surface
of `DatabaseOperationsModule` for its read/write SQL, while owning
the engine-specific DDL string generation.

---

## 4. Bootstrap problem

How do we read `contracts_db_operations` to get the query that reads
`contracts_db_operations`?

The infrastructure already handles this: `DatabaseOperationsModule.startup()`
issues a literal SQL string to bulk-load operations. That literal
string is the only hardcoded SQL in the module:

```sql
SELECT pub_op, {self._query_column} AS query
FROM contracts_db_operations
WHERE pub_bootstrap = 1 AND {self._query_column} IS NOT NULL
FOR JSON PATH;
```

This is the bootstrap escape hatch. Every other operation lives in
the table.

The lazy-load fallback (`_load_op`) is also hardcoded SQL but is the
same pattern — these are the only two SQL strings in the kernel that
aren't operations.

---

## 5. API surface to define

Before writing any code, the next session needs to lock these. A
proposed shape (Claude's suggestion, subject to Elideus's review):

### 5.1 `DatabaseManagementModule` public methods

Schema operations (consumed by REPL and by future installation hooks):

```python
async def populate(self) -> dict[str, int]
async def dump(self, prefix: str = "schema") -> str  # returns filename
async def install(self, package_path: str) -> InstallResult
async def install_seed(self, seed_path: str) -> SeedResult
async def uninstall(self, package_name: str, confirm: bool = False) -> UninstallResult
async def list_packages(self) -> list[PackageInfo]
async def make_package(self, package_name: str, output_path: str) -> str
```

Each method returns a structured result (Pydantic models, conforming
to `contracts_api_*` rows). The REPL formats those results for
display. SQL is dispatched through the composed provider, which in
turn dispatches through `DatabaseOperationsModule`.

### 5.2 `ComposedDatabaseManagementProvider` additions

The current ABC has introspection + DDL + capability methods. The
migration likely needs to add:

- DDL string builders (or keep them in the executor module — TBD).
- Maybe higher-level operations like `materialize_missing_tables(declarations)` if it makes sense to encapsulate.

This needs design discussion in the next session. The shape isn't
obvious from where session 006 ended.

### 5.3 Operation rows for `contracts_db_operations`

Roughly 25 ops. Naming follows the op-string convention from
`naming_conventions.md` §7: `db:<domain>:<subdomain>:<verb_noun>:<version>`.

Proposed cluster:

- `db:contracts:tables:read_all:1` — populate's tables query
- `db:contracts:columns:read_all:1` — populate's columns query
- `db:contracts:indexes:read_all:1` — populate's indexes query
- ... (~5 more populate queries)
- `db:contracts:tables:read_for_dump:1` — dump's tables read
- ... (~5 more dump queries)
- `db:meta:sys_tables:list:1` — sys.tables existence check (for materialize)
- `db:meta:sys_columns:list_for_table:1` — sys.columns lookup
- `db:contracts:operations:bootstrap:1` — the bootstrap query itself (or maybe leave hardcoded)
- ... (~7 uninstall queries)
- `db:contracts:row:merge:1` — generic MERGE template

The exact names and SQL bodies need to be drafted — that's a Claude
deliverable for the next session.

### 5.4 REPL surface

After migration, REPL commands look like:

```
populate          → mgmt.populate()
dump [name]       → mgmt.dump(name)
install <file>    → mgmt.install(file)
seed <file>       → mgmt.install_seed(file)
uninstall <name>  → mgmt.uninstall(name)
uninstall <name> confirm → mgmt.uninstall(name, confirm=True)
list packages     → mgmt.list_packages()
make package <name> <out> → mgmt.make_package(name, out)
```

The REPL becomes a thin shell over the management module.

---

## 6. State at end of session 006

### Working / in repo

- `migrations/v1.0.0_kernel.sql` — kernel canon, 11 tables, all
  package-deployable tables have `ref_package_guid` + FK to manifest.
- `migrations/v1.0.0_kernel_seed.json` — 224 rows in old `rows`
  format. Successfully installs via `install seed`.
- `migrations/test_widgets.json` — POC package, schema/data format,
  installs cleanly.
- `scripts/scriptlib.py` — has full pipeline working: populate,
  dump, apply, install_seed, install (5-phase: register →
  seed_schema → materialize → seed_data → seal), list_packages,
  uninstall (dry run + confirm). Auto-injects `ref_package_guid`
  in seed phases.
- `scripts/repl.py` — exposes all the above commands.
- `scripts/gen_kernel_seed.py` — hand-encoded kernel schema,
  generates the seed JSON deterministically.

### Stubs awaiting implementation

- `server/kernel/database_management_module.py` — module exists,
  startup runs, composed provider attached, worker started. No
  real methods yet.
- `server/kernel/database_execution_providers/mssql_management_provider.py` —
  all 9 contract methods are stubs.

### Verified end-to-end flow

```
1. Drop database
2. Apply v1.0.0_kernel.sql
3. install seed migrations/v1.0.0_kernel_seed.json   # 224 rows
4. install migrations/test_widgets.json              # 12 schema + 3 data + manifest
5. Verify: SELECT * FROM test_widgets returns 3 rows
6. Verify: SELECT * FROM service_modules_manifest shows kernel + test_widgets
```

This is the regression test for the migration. After moving
everything into the management module, this same flow (driven via
REPL → management module → composed provider → operations module →
execution module → MSSQL) must produce the same results.

---

## 7. Pending design decisions (in priority order)

### 7.1 Auto-inject `ref_package_guid` column at materialize

Open from session 006. Decision: **option A** — the materialize
step physically adds `ref_package_guid UNIQUEIDENTIFIER NULL` to
every CREATE TABLE it generates AND auto-MERGEs a corresponding
`contracts_db_columns` row so the data graph stays consistent.

This is a small change but needs to land before `make_package`
works correctly, because make_package will read rows by
`ref_package_guid`, and currently test_widgets's data rows have
no such column.

### 7.2 Disambiguate `install seed` vs `install`

Decision: rename `install seed <file>` to `seed <file>`. Different
verb makes it obvious it's a different operation (direct row import
without the package pipeline).

### 7.3 `make package <name> <outpath>`

The mirror of install. Reads manifest row by name to get pkg_guid;
queries every pkg-aware table for owned rows; emits a
`{package, version, schema, data}` JSON file. Strips
`ref_package_guid` from output rows since install will re-inject.

When this works for the kernel package, it replaces
`gen_kernel_seed.py` as the source of truth for
`v1.0.0_kernel_seed.json`. The kernel describes itself by being run.

### 7.4 Operation rows for `contracts_db_operations`

The ~25 operations need to be drafted with their SQL bodies.
Bootstrap-flag analysis: which need `pub_bootstrap = 1`? The
populate/dump/materialize/install operations are infrequent; only
a small set of "always-needed" ops (probably the basic MERGE, the
existence checks) need bootstrap loading.

### 7.5 DDL string generation in the composed provider

The current `MssqlManagementProvider` stub methods return placeholder
values. The real implementations need to generate MSSQL DDL strings.
Options:

- Keep the dump-style builders (`_build_create_table` etc.) inside
  the provider, since they're engine-specific.
- Move builders to a helper module that the provider imports.
- Move builders into operation rows as templates with placeholder
  substitution. (Probably overkill.)

Recommendation: keep them as methods on the concrete provider.
DDL generation is one of the things that genuinely differs per
engine.

---

## 8. What NOT to do in the next session

- Do not edit `server/kernel/` files. That is Elideus's hand-coded
  territory. Propose, don't implement.
- Do not add SQL strings to scriptlib that should be operations.
- Do not invent new architectural concepts. The patterns are
  defined in the docs; consult them.
- Do not rush past the API surface design step. The shape of
  `DatabaseManagementModule`'s public methods is the load-bearing
  decision; get it right before writing operation content.
- Do not assume scriptlib's behavior is correct. Several things
  about it (the ordering, the auto-injection logic, the dry-run
  flow) are session-006 design decisions that should be re-examined
  when they land in the kernel.

---

## 9. Resumption checklist

When the next session starts:

1. Read this file.
2. Read `docs/n_contracts.md` (the contracts framing).
3. Read `docs/database.md` (the subsystem layout).
4. Read `docs/kernel_architecture.md` and `docs/provider_composition.md`.
5. Read `server/kernel/database_management_module.py`,
   `server/kernel/database_operations_module.py`, and
   `server/kernel/database_execution_providers/__init__.py` and
   `mssql_management_provider.py`.
6. Re-read `scripts/scriptlib.py` to confirm the SQL inventory.
7. Propose the API surface for `DatabaseManagementModule` (§5.1
   above is a starting point, not authoritative).
8. Wait for Elideus's adjustments before drafting operation rows.

Don't start coding before steps 1–7.
</content>