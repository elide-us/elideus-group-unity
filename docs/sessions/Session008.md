Session 008 Handoff — Bootstrap Operations & Cascade Machinery

Where we are
The operations table is populated. 22 bootstrap DDL queries from scriptlib.py are now rows in contracts_db_operations, each with input/output model contracts. The cascade-on-delete machinery is in place and verified — install/uninstall round-trips cleanly with one DELETE on the manifest row triggering full cleanup via FK cascade. The constraint contract gained a pub_delete_disposition flag and a constraint_disposition primitive enum to drive ON DELETE clause emission. New canonical artifacts (kernel.sql + kernel_seed.json) are in migrations/ as VERIFY files, awaiting destructive-loop merge.

This closes the "DDL queries as data" arc that started in Session 007. The next phase is wiring the kernel database tier to actually dispatch these rows.

What got committed in this session (artifacts)

- migrate_002_ddl_ops_models.sql — added contracts_db_operations_models, contracts_db_operations_models_fields, ref_input_model_guid + ref_output_model_guid on contracts_db_operations. Self-describing rows for all of it. Applied & verified.
- migrate_003_resolve_package_op.sql — first POC operation row: db:contracts:db:resolve_package:1. One input model (pub_name STRING(256)), one output model (4 fields). Validated that the op-row + model-rows + field-rows shape works end-to-end.
- migrate_004_cascade.sql — added constraint_disposition enum_type with NO_ACTION/CASCADE/SET_NULL/SET_DEFAULT enum rows; added pub_delete_disposition TINYINT NULL on contracts_db_constraints (integer storage, not UUID-FK — storage is the system reality, the enum is a human readability layer); marked the 10 FK_*_package constraints as CASCADE; dropped and re-added those 10 physical FKs with ON DELETE CASCADE. scriptlib's _build_constraint reads the enum mapping at runtime via contracts_enums_ddl_mapping rather than holding any hardcoded value→keyword dict.
- migrate_005_bootstrap_operations.sql — 21 operations migrated as data (resolve_package was already there from migrate_003). Breakdown: 8 contract reads (read_tables, read_columns, read_indexes, read_index_columns, read_constraints, read_constraint_columns, read_seed_table_list, read_seed_column_projection); 5 package management (list_manifest_rows, list_package_owned_tables, list_package_ext_columns, set_manifest_sealed, delete_manifest_row); 6 engine introspection (list_physical_tables, check_table_has_package_column, list_physical_tables_with_package_column, check_physical_table_exists, list_indexes_on_column, list_fks_on_column); 2 maintenance (update_statistics, free_proc_cache). All under URN db:contracts:db:<op>:1. pub_query_mssql holds the literal query body verbatim from scriptlib; postgres/mysql columns NULL pending separate authoring. pub_bootstrap_element=1 on every row.
- docs/future/artifact_templates_design.md — captured design intent for contracts_artifact_templates + contracts_artifact_elements (the table that will hold the boilerplate scaffolding currently hardcoded as Python f-strings in scriptlib's emitters — the SET ANSI_NULLS prelude, the CREATE TABLE wrapper, the MERGE block, the INSERT block, the section dividers). Deferred to a future session.
- v1.0.0_kernel_VERIFY.sql + v1.0.0_kernel_seed_VERIFY.json — new canonical artifacts in migrations/ pending destructive-loop merge into v1.0.0_kernel.sql / v1.0.0_kernel_seed.json.

Known imperfections in the current state (deferred, NOT to be acted on)

- Some operations belong in db:contracts:packages:* not db:contracts:db:*. This is a regeneration cost so we're not chasing it now.
- The DDL mapping tables are named contracts_types_ddl_mapping and contracts_enums_ddl_mapping; better names would be contracts_ddl_types_mapping and contracts_ddl_enums_mapping. Same regeneration cost.
- DatabaseOperationsModule.startup() filters bootstrap pre-cache on `pub_bootstrap = 1` but the column is `pub_bootstrap_element`. Functional fallback through _load_op() works fine; the pre-cache just doesn't pre-warm. One of three small bootstrap-query updates needed in the kernel modules.
- DatabaseManagementModule wires up the management provider via startup() but never calls into it after that — the seam where the worker would dispatch is not yet built. This is the next session's work.
- BaseDatabaseManagementWorker is a placeholder per docstring, awaiting the task automation substrate.
- MssqlManagementWorker subclass exists but management module instantiates the base class directly. Inconsistency to clean up when the worker contract gets defined.

The current task (where to pick up)

Goal: implement the management provider's introspection methods to actually dispatch the bootstrap operation rows we just migrated. This is the first concrete instance of the data-driven DDL dispatch flow.

The dispatch flow is:
  1. Inbound request hits IoGateway (someday; for now, REPL injection)
  2. database_maintenance_module receives the high-level request inside one of its public methods (install_package, etc.) and writes a task record describing the work
  3. database_management_worker (running its own loop, polling task table — this part is the placeholder we're stubbing) picks up the task
  4. Worker calls the typed method on database_management_provider (the composed one)
  5. Management provider resolves the op URN via DatabaseOperationsModule (URN → SQL string for active engine), then dispatches via the transaction provider it composes
  6. Worker writes the task result back; maintenance module orchestrates whatever next step depends on it

For this work cycle the worker's poll loop is deferred. The REPL acts as the task system — it synthesizes a task record and hands it directly to a process_task(record) method on the worker, which is the minimum viable surface that survives once the real task system lands. The poll-and-claim logic gets built then; the process-one-task contract gets built now.

First concrete deliverable: implement MssqlManagementProvider.read_tables, read_columns, read_indexes, read_constraints. Each method should resolve its corresponding URN (db:contracts:db:read_tables:1 etc.) via DatabaseOperationsModule, then dispatch via self._provider (the composed transaction provider). Validates the operation rows from migrate_005 against real dispatch end-to-end.

Open question that must be resolved before writing those methods: where does URN-to-method mapping live? Three options discussed:
  (1) Hardcoded dict in the worker. Cheap, scales poorly, dies when first new op is added.
  (2) Separate dispatch table contracts_module_dispatch_map FK-linking URNs to module/method. Most data-driven; lots of plumbing.
  (3) Metadata column on the operation row (pub_dispatch_method or similar). Each op declares the provider method it dispatches to. Couples op rows to Python method names.
  Lean (3) for now with eventual migration to (2) when there are enough modules to justify the indirection. This is the actual decision that needs to be made before the first method gets written.

Method signatures on the management provider currently take typed parameters (read_columns(table, schema)) but the migrated ops are mostly parameterless full-table reads. Three reasonable resolutions:
  (a) Drop the typed parameters from the provider signatures — they read everything, callers filter client-side.
  (b) Author additional ops that take filter parameters.
  (c) Provider does client-side filtering after running unfiltered op.
  No commitment yet — pick this when the first method gets written, based on what feels honest for the use case.

Three small bootstrap queries embedded in the kernel modules need updating because the schema has shifted:
  - DatabaseOperationsModule pub_bootstrap → pub_bootstrap_element (mentioned above)
  - Two more somewhere in the kernel — user expects "very few if any changes needed beyond updating those tiny bootstrap queries, I think there are three total in the kernel"
  Locate and fix as part of wiring the dispatch path.

Out of scope right now (was discussed but explicitly deferred)

- Artifact templates implementation — captured in docs/future/artifact_templates_design.md. Naming locked: contracts_artifact_templates and contracts_artifact_elements. Implementation deferred until DDL dispatch is wired.
- DDL mapping table renames (contracts_*_ddl_mapping → contracts_ddl_*_mapping). Regeneration cost.
- URN domain re-classification (some db:contracts:db:* belongs in db:contracts:packages:*). Regeneration cost.
- contracts_api_* (the API surface table for module public functions — the precursor to the eventual signed module-as-code-in-database). Mentioned as the move after this DDL work, requires auth/signing infrastructure first which is itself deferred.
- ON DELETE CASCADE behavior in the constraint contract is now declared via pub_delete_disposition; ON UPDATE companion (pub_update_disposition) is symmetric and can be added when needed without re-shaping data.
- Postgres/MySQL versions of the migrated query bodies. Per-engine authoring work that happens when porting.
- The kernel manifest row. Still conceptual.
- JWKS / signing / row checksums.
- Async task system. The worker's process_task contract is the minimum surface that survives that future build-out.

The big picture (THE FRAMING THAT MATTERS)

The application IS the type graph. Code is a rendering target, not the system itself. Migrations populate regions of the graph. Each region opens edges to adjacent ones. At critical mass the system becomes self-bootstrapping — adding functionality is graph manipulation, not code authoring. The Python and TypeScript runtimes are interpreters for the graph.

This is what every individual decision points back to. "Where does this column go" — it goes in the row that represents its concept; the FK from there to its parent makes the edge real. "Where does this enum live" — it lives in the enum table because it's queryable data, never as a Python constant because that breaks the graph. "Should this dispatch table exist or be a metadata column on the operation row" — either choice is a graph shape, the question is which shape the rest of the graph wants to grow into. The orientation is consistent.

The end state is: TypeScript components streamed from the server (materialized from component→bindings→operations→models row chains, serialized as TS, hot-reloadable as the graph mutates), Python module code loaded from packages that ship as graph fragments with cryptographic signatures on the nodes, all installable from a marketplace where validation is graph-fragment FK consistency. The visualization will be epic — every module is a box, every contract is a typed pipe with names written on it, primitives terminate in a bound cluster, externals are knots into that cluster, and clicking through walks the same FK chains the runtime walks. 85%+ of classic web app bugs vanish because the chain that's mentally traced today is a structural query tomorrow.

Version landscape (so you don't get confused later)

- v0.11 = current production. Fully shipped, no longer evolving.
- v0.12 = hack project that reduced v0.11 down to auth-only. Done.
- v0.13 = currently running ContentForge POC on test. Demos ComponentBuilder building itself in dev mode with full object tree. Reflection data in that database is stale and worthless.
- v0.15 = loose label for current work. Not actually tagged anywhere.
- v1.0.0 = the version stamped on the artifacts we're producing here.
- The application doesn't track its own version right now.
- This is a full greenfield rebuild. Zero shared lineage with prior versions. They are pure inspiration, nothing else.

Architectural rules and conventions (re-emphasized for next session)

The rules from Session 007 still apply, with these clarifications and additions:

- Composition not inheritance for the management provider. ComposedDatabaseManagementProvider HAS-A BaseDatabaseTransactionProvider (passed in constructor as self._provider, calls delegated through). Don't model it as IS-A; the user said IS-A in conversation but the actual code is composition.
- pub_delete_disposition is TINYINT (integer storage), not UUID FK. The integer is the system reality; the enum_type and enum rows are the human-readability layer. Code that needs the keyword form (CASCADE, SET NULL, SET DEFAULT) reads it from contracts_enums_ddl_mapping at runtime, never holds a Python dict. This generalizes: any time we'd hardcode a value→name lookup in code, the data already has it.
- The repl is the POC testing library. The eventual home for that logic is the kernel database modules (Manager/Executor/Provider/Worker). Some shortcuts in scriptlib ("emulate the kernel_enum_module by joining manually") are acceptable as POC concessions; the real code goes through the kernel_enum_module when it exists.
- Operation rows store query bodies verbatim. No Python templating. No placeholders. The literal text is the contract.
- Each operation = one input model + one output model (or NULL for either). Models are defined per-op for now; reuse can be extracted later when a clear shared shape emerges. Don't share models prematurely.
- URN format: db:contracts:<domain>:<operation>:<version>. Outer db: is namespace, version is non-dotted sequential integer starting at 1. Companion domains will be db:contracts:api:* and db:contracts:rpc:*; possibly db:contracts:packages:*.
- All FK_*_package constraints cascade. Uninstall = DELETE manifest row, cascade does the rest. Junction tables clean up via their own ref_package_guid (also cascade-flagged), not via parent-child cascade. Primitives have no ref_package_guid by design and are untouchable by package cascade.
- The query column for the active engine is selected once at module startup based on SQL_PROVIDER env var. DatabaseOperationsModule._query_column is set to pub_query_mssql / pub_query_postgres / pub_query_mysql at startup; callers never see which.
- BaseModule lifecycle: __init__ (sync, no async, no deps) → startup (async, get_module + on_sealed waits, raise_seal at end) → on_seal (async, post-init, all modules live) → on_drain (pre-shutdown) → shutdown (teardown). All seal-waits compose into a runtime DAG; no orchestrator manages composition.

What I (Claude) should remember at session start

- Read kernel.sql and kernel_seed.json (or VERIFY versions if present) before writing any migration. Know the live state.
- Read the relevant module file before proposing changes to it. Don't guess about composition vs inheritance, dispatch shape, or method signatures.
- MERGE-based, idempotent migrations. INSERT is wrong; UPDATE/DELETE without WHERE is wrong; hand-edited canonical files is wrong. Migrations are throwaway, REPL regenerates canonical artifacts.
- Deterministic GUIDs via UUID5 from natural keys, NS_HASH = DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB. Never random. Never hardcoded except in throwaway scripts (where they should still be computed and labeled).
- Do not propose tests; wipe-rebuild IS the test.
- Memories surface naturally; no "based on what I know about you" framing.
- Match the energy. Do not collapse into self-flagellation when corrected. Own the mistake, fix it, move on.
- The framing "the application IS the type graph" is the orienting principle. Every decision points back to it. Don't lose it under the weight of tactical schema work.

File locations

- Repo root: C:\__Repositories\elideus-group-unity (or /Users/elideus/dev/elideus-group-unity in WSL/macOS context).
- Migrations: migrations/ — v1.0.0_kernel.sql + v1.0.0_kernel_seed.json are canonical; VERIFY versions are pending merge; migrate_*.sql are throwaways.
- scriptlib (POC test library): scripts/scriptlib.py.
- REPL: scripts/repl.py.
- Kernel modules: server/kernel/.
- Provider implementations: server/kernel/database_execution_providers/.
- Helpers: server/helpers.py (deterministic_guid lives here).
- Session docs: docs/sessions/.
- Future / deferred design: docs/future/.
- Architecture docs: docs/kernel_architecture.md, docs/CONTRACTS.md, docs/naming_conventions.md, etc.
