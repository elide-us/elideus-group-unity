Session 007 Handoff — DDL Operations Migration
Where we are
v1.0.0 kernel is locked, checked in, and promoted to all branches. Wipe-install-dump is a verified clean cycle. Foundation is solid.
We just started the next phase: moving the DDL queries currently embedded in scripts/scriptlib.py (_build_create_table, _build_create_index, _build_constraint, plus the introspection queries) into rows in contracts_db_operations, with full input/output contract definitions.
The current task (where to pick up)
Goal: schema additions to support DDL ops as data, then migrate the queries.
Method: throwaway sequential SQL migration scripts that take the DB from v1.0.0 state to the new shape. Once the DB is right, REPL regenerates v1.0.0_kernel.sql and v1.0.0_kernel_seed.json as the new canonical artifacts. Do NOT use populate — it's dead. The kernel SQL file is canonical schema source.
Schema delta needed:

New table contracts_db_operations_models — model identity rows (PK key_guid, pub_name UNIQUE, pub_notes, timestamps).
New table contracts_db_operations_models_fields — field rows on those models. Mirrors contracts_db_columns shape minus ref_table_guid. FKs to the model table and to contracts_primitives_types. UNIQUE on (model, name) and (model, ordinal).
New columns on contracts_db_operations: ref_input_model_guid and ref_output_model_guid (both nullable UNIQUEIDENTIFIER, FK to the new models table). Each operation gets exactly one input model and one output model — no role-enum, two explicit FKs.
Self-describing rows for all of the above: rows in contracts_db_tables, contracts_db_columns, contracts_db_indexes, contracts_db_index_columns, contracts_db_constraints, contracts_db_constraint_columns.

After schema is in place: each """...""" query block in scriptlib.py becomes a row in contracts_db_operations with model rows defining its inputs/outputs. Queries move as-is, no templating. The literal query text is what gets stored.
Op naming convention (QueryRegistry URN format): db:contracts:db:<operation>:<version> — outer db: is the URN namespace, inner db is the domain (because these ops affect the database itself), then operation name and version. The doubling reads weird at first but is correct.
Out of scope right now (was discussed but explicitly deferred):

JWKS / signing / checksums on rows. Don't bring this up until user does.
API contracts (contracts_api_*) and RPC contracts (contracts_rpc_*). These will follow the same pattern but are separate from DDL contracts.
The kernel manifest row (_guid('service_modules_manifest', 'kernel')). Discussed conceptually — kernel IS a package, the package that defines itself. Not blocking the current task.
pub_bootstrap_element flag handling — already exists, marks ops invoked during install/materialize itself.

What I (Claude) was failing at right before handoff

Writing migration SQL without reading the canonical v1.0.0_kernel.sql file first to verify current state. Resulted in scripts that would conflict with reality. Always read the canonical file before writing migrations against it.
Was about to write INSERT statements where the system convention is MERGE for idempotency.
Conversation context was huge and I was losing thread on things explicitly stated multiple turns earlier.

Architectural rules and conventions (THE IMPORTANT PART)
These are the rules Elideus consistently has to re-explain. Internalize them.
Workflow rules

Elideus runs SQL/REPL commands. Claude does NOT have DB access. Don't propose to run things; propose the SQL/code and Elideus runs it.
Claude proposes API surface, SQL, and data. Elideus writes all server/kernel/ module code by hand. Authorship boundary.
Claude may write: scriptlib, repl, seed JSON, generator scripts, migration scripts, throwaway SQL.
Throwaway migration scripts are how schema changes get made. Numbered, sequential, run against current state, discardable. Once DB is in target state, REPL regenerates kernel.sql and seed JSON.
REPL regenerates artifacts. Don't hand-edit kernel.sql or kernel_seed.json unless absolutely forced (e.g. database is wiped and there's no other way).
populate is dead. Kernel SQL is canonical schema source.
When unsure of current state, READ THE FILE. Don't guess. Files at migrations/v1.0.0_kernel.sql and migrations/v1.0.0_kernel_seed.json are authoritative.

Design principles

Data-driven everywhere. The architecture is the prompt. If logic can live in a row, it lives in a row. Hardcoded type maps, override dicts, inline constants — all bandaids to be eliminated.
Primitives tables are foundational. contracts_primitives_types, contracts_primitives_enum_types, contracts_primitives_enums have NO outbound FKs. They're the substrate, owned by no package.
Everything else is a package. The kernel itself is a package — "the package that defines itself." Future user packages follow the same shape with no special-casing.
Deterministic GUIDs via UUID5. Namespace is DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB (env var NS_HASH). Pattern: uuid5(NS_HASH, 'entity_type:natural_key'). Example: _guid('contracts_db_tables', 'dbo.foo').
Naming: pub_*_element flags = set membership (e.g. pub_seed_element, pub_exclude_element, pub_bootstrap_element). pub_is_* flags = behavioral attributes (e.g. pub_is_nullable, pub_is_unique, pub_is_sealed). Distinction held strictly.
Self-describing schema: every table the kernel knows about has rows in contracts_db_tables / contracts_db_columns / contracts_db_indexes / contracts_db_constraints / contracts_db_constraint_columns describing it. New tables MUST have these rows added.
Survival of authored data: install pipeline is purely additive (MERGE-only, never DELETE). Authored flag values (pub_exclude_element etc.) survive install→populate→install cycles via the dump's authored-overrides UPDATE block.
Module ownership by package: most tables have ref_package_guid (nullable, FK to service_modules_manifest). This identifies which package owns the row. Primitives tables are the exception — foundational.
Boundaries: database_management_module calls operations BY OP NAME. Provider/worker is the only thing that ever reads pub_query_* text. Modules pass typed inputs against input contracts, get typed outputs against output contracts, never touch query strings. Generic dict dispatch at the provider boundary today; typed contracts at the management module layer.
DDL queries move as-is. No Python templating, no placeholders. Literal query text stored in pub_query_mssql etc. The structural helpers (column DDL builders, etc.) stay in Python; they're what assemble the kwargs/values that get passed in to a parameterized query.

Anti-patterns to avoid

Don't apologize for tools you haven't used yet. Read the file first, then act.
Don't over-engineer. Elideus values: simplest correct solution, deletion over patching when design is wrong, no scope creep.
Don't defensively null-check keys that are guaranteed by constraints.
Don't reflexively try to wrap up sessions when Elideus isn't done. Elideus has called this out repeatedly.
Don't hardcode GUIDs in emitted SQL — compute deterministically from natural keys.
Don't propose tests/validation unless asked. Wipe-rebuild IS the test, and it's intentionally destructive.
Memories surface naturally — no "based on what I know about you" framing.

Communication style

Short and conversational. Elideus uses Claude as scribe and external memory. Unsolicited content generation is not helpful.
Match the energy. When Elideus is fired up about progress, match it. When called out for fucking up, own it cleanly without spiraling into self-flagellation.
No reflexive bullet-pointing. Prose is fine. Bullets when structure genuinely helps.

File locations

Repo root: /Users/elideus/dev/elideus-group-unity/
Kernel SQL (canonical): migrations/v1.0.0_kernel.sql
Kernel seed (canonical): migrations/v1.0.0_kernel_seed.json
scriptlib (where the queries currently live): scripts/scriptlib.py
REPL: scripts/repl.py
Kernel Python modules (Elideus authors): server/kernel/
Session docs: docs/sessions/
Architecture docs: docs/kernel_architecture.md, docs/CONTRACTS.md, docs/naming_conventions.md, etc.