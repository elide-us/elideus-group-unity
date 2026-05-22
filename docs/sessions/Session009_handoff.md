# Session 009 handoff — contracts_providers_* and primitive services scope

## Architectural lock

The eight-layer + four-cross-cutting contracts model is locked. Reference the
saved SVG (canonical layer stack) for the visual. Restating the namespaces:

**Eight layers (top to bottom, inbound to service):**
- Layer 8 — `contracts_transports_*` — transport primitives (HTTP, WebSocket, SSE, Discord client)
- Layer 7 — `contracts_adapters_*` — IO providers that speak one transport (FastAPI app, Discord bot, MCP server)
- Layer 6 — `contracts_endpoints_*` — IO normalization to canonical RPC shape (/rpc routes, slash commands, MCP tools)
- Layer 5 — `contracts_rpc_*` — RPC dispatch and security gate (domains, subdomains, operations)
- Layers 4 + 3 — `contracts_modules_*` — manager (4) and executor (3) tiers, distinguished by pub/priv flags and metadata, sharing a single namespace
- Layer 2 — `contracts_providers_*` — function interface to primitive services (database, storage, api, oauth)
- Layer 1 — primitive services as rows inside `contracts_primitives_*` (MSSQL, Discord API, Azure Blob, OS crypto, specific Python libs)

**Four cross-cutting registries:**
- `contracts_packages_*` — ownership, every row carries `ref_package_guid`, kernel = UUID5(1)
- `contracts_primitives_*` — atomic substrate: types, enums, services, db operations, OS-level deps. Foundational kernel seed; never dissolves into anything else.
- `contracts_models_*` — unified registry of composed models. Every function references one input model and one output model. No per-function parameter or return tables. Multi-input is expressed as a composed wrapper model.
- `contracts_security_*` — users, roles, grants. Joins at the RPC layer only.

**Symmetry:** three layers in (transport → adapter → endpoint) → logic and
security core (RPC → modules → providers → primitive service) → three layers
out (mirror, same shape). Every external interaction conforms to this contract.

**Dual flags on every row:**
- `ref_package_guid` — ownership; drives uninstall cascade
- `pub_bootstrap_element` — substrate status; drives "must exist before DB can
  be queried for anything else." Bootstrap is a strict subset of kernel package.

## Scope for the next session

Two work-units, in order:

### Unit 1 — Migrate `contracts_db_*` into `contracts_providers_*`

The current schema has `contracts_db_operations`, `contracts_db_operations_models`,
and `contracts_db_operations_models_fields`. These are the layer-2 operation
registry for the database provider, but they live in a DB-specific namespace
that conflates layer-2 with the database service primitive.

Under the canonical model:
- `contracts_providers_*` holds the layer-2 contracts for ALL providers
  (database, storage, api, oauth) — not just database
- The current 22 bootstrap DDL queries currently in `contracts_db_operations`
  become rows in `contracts_primitives_database_operations` (they are layer-1
  primitive operations on the MSSQL service primitive, not layer-2 provider
  operations)
- The model and field definition tables fold into the unified `contracts_models_*`
  registry (one models table, one fields table; primitives stay distinct in
  `contracts_primitives_*`)

Steps:
1. Author the new tables: `contracts_providers_providers`,
   `contracts_providers_operations`, `contracts_models_models`,
   `contracts_models_fields`, `contracts_primitives_database_operations`.
2. Decide migration shape: full schema swap (drop and reauthor) or migrate-in-place.
   Greenfield context favors full swap since the existing data is throwaway.
3. Move the 22 bootstrap DDL queries into `contracts_primitives_database_operations`
   with `pub_bootstrap_element=1` and `ref_package_guid` = kernel UUID5(1).
4. Move existing model/field rows into the unified registry.
5. Update `DatabaseOperationsModule.startup()` to read from the new table location.
6. Surviving artifacts from Session 008 keep their shape:
   - `ComposedDatabaseManagementProvider` two-verb ABC (`generate`, `alter`)
   - `MssqlManagementProvider._generate_create_table` placeholder
   - The `pub_bootstrap` → `pub_bootstrap_element` column-name fix

### Unit 2 — Lock the primitive services contract

Define what a primitive service IS and what it CAN'T DO. This is the layer-1
contract — the rules for what kinds of things qualify as a service primitive
and what surface they expose to layer 2.

Open questions to resolve:
- What rows go in `contracts_primitives_services`? (MSSQL is one, Discord API
  is one — but is "OS crypto" one? "Python's `datetime` module"? Where's the
  line between a primitive service and just a Python import?)
- What sub-tables hang off `contracts_primitives_services`? (Operations like
  `contracts_primitives_database_operations` — does each service primitive
  get its own operations table, or is there a unified operations table with
  a service FK?)
- What's the contract surface a layer-2 provider can rely on from its bound
  primitive service? What's NOT allowed across that boundary?
- How does the package system handle primitive services that ship from
  outside the kernel (e.g., a third-party package adding a Postgres primitive
  alongside MSSQL)?

This is design work, not code work yet. The output of Unit 2 is clarity on
rules, not new tables — though it will inform what tables Unit 1 needs.

## What is explicitly NOT in scope for the next session

- Sketching out the entire database table structure for all ten namespaces.
  That work happens incrementally as each layer's contracts get authored.
- Authoring `contracts_modules_*`, `contracts_rpc_*`, `contracts_endpoints_*`,
  `contracts_adapters_*`, `contracts_transports_*`. Those come after providers
  and primitives are locked.
- The four developer scenarios (functional module, primitive service provider,
  data exchange interface, UX slug) and the Component Builder UX work. Those
  are downstream of having the underlying contract tables in place.

## Working-style contract reminders

- Read the repo via Filesystem MCP before any proposals. Use
  `read_multiple_files` for efficiency.
- All file production goes to `/mnt/user-data/outputs/` via bash tool. No
  write access to the repo.
- Corrections are delivered as single terse sentences identifying the pattern
  violation. When a correction lands, update mental model immediately and
  stop the line of reasoning that produced it.
- Sessions close with corrections logs and handoff documents.

## Locked decisions to carry forward (do not relitigate)

1. Eight layers + four cross-cutting namespaces as listed above
2. `contracts_primitives_*` does not absorb anything; it is foundational
3. Models are unified across all functions — one input model, one output model
   per function, multi-input via composed wrapper models
4. Layers 3 + 4 share `contracts_modules_*`, distinguished by pub/priv metadata
5. Primitive services live as rows in `contracts_primitives_*`, not their own
   namespace
6. Bootstrap is a flag on rows, orthogonal to package ownership
7. Database = throwaway; full schema rebuild is acceptable
8. Reference counter + FK constraints together make shared ownership safe;
   uninstall cascade is the second line of defense, not the first
