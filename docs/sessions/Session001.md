# Unity Platform - Session Handoff v3

## Project Context

You are working with Elideus on `elideus-group-unity` — a greenfield rebuild 
of TheOracleRPC CMS. Everything is data-driven. SQL queries, enumerations, 
component definitions, layouts, and the metadata describing module behavior 
all live in the database as rows. The Python codebase is a thin lifecycle 
engine that hosts modules which self-describe their behavior through data.

Core principle: the only way to add a feature is to add rows. Code is the 
engine, data is the application. Patterns are enforced through contracts 
that cannot be bypassed. LLMs cannot perpetuate bad patterns because there 
are no patterns to copy — there is only one way to do each thing.

Repository paths:
- `C:\__Repositories\elideus-group-unity` — the new build (active)
- `C:\__Repositories\elideus-group` — legacy, reference only, do not modify

## What Exists Today

- Dockerfile (Python 3.13-trixie, ODBC 18.6.2)
- Pinned requirements.txt (23 packages including FastAPI, MCP SDK, discord.py, pyodbc/aioodbc)
- Module system with autodiscovery: BaseModule abstract class, ModuleManager 
  with snake_to_pascal filename-to-class conversion, registry keyed by class type
- EnvironmentVariablesModule — loads .env, exposes get() returning `str | None`, 
  distinguishes "not set" from "empty string" in logging
- DatabaseExecutionModule — routes to a provider via SQL_PROVIDER env var, 
  which holds the NAME of the env var containing the connection string 
  (e.g., "AZURE_SQL_CONNECTION_STRING"). Match statement selects provider.
- MssqlProvider (aioodbc) — connection pool, query() returns parsed JSON from 
  FOR JSON PATH, execute() returns rowcount as `int | None`
- DatabaseOperationsModule — bootstrap cache keyed by deterministic GUID, 
  lazy-load on miss, takes DBRequest(op, params), dispatches to execution 
  module. This is the canonical reference pattern for all registry modules.
- helpers.deterministic_guid(namespace, entity_type, natural_key) using 
  uuid5 with namespace DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB (NS_HASH env var)
- Foundation SQL schema drafted (not yet applied) for three tables:
  service_extended_data_types, service_enumerations, service_database_operations
- Lifespan manager with commented placeholder for MCP session_manager.run() 
  wrapping the yield

## Architectural Decisions Locked In

### Every Registry Module Follows the Same Pattern

Bootstrap-phase registry modules share structure:
- `__init__` initializes empty cache dict and null dependencies
- `startup()` gets dependencies from module manager, awaits their readiness, 
  matches on SQL_PROVIDER to select provider-specific query column, runs a 
  bootstrap SELECT that returns preloaded rows via FOR JSON PATH, caches them 
  by deterministic GUID
- `shutdown()` clears the cache
- A public lookup method (get, query, execute) that checks cache by GUID, 
  lazy-loads on miss via PK seek query, returns the data
- Private `_flush(key)` and public `flush()` for cache invalidation
- `logging.error` on failures, no exceptions raised, graceful degradation
- All return values are tuples (or tuple-shaped dicts from parsed JSON) for 
  contract consistency across modules

### Application Module Registry Pattern (CRITICAL)

Before any other bootstrap module, an ApplicationModuleRegistry tracks 
module initialization state. Every module on startup checks the registry 
by its deterministic GUID:

- Not present → insert registry row, run `_run_initialization()`, mark initialized
- Present, uninitialized → run `_run_initialization()`, mark initialized
- Present, initialized, version matches code → skip init, proceed normally
- Present, initialized, version older than code → run `_run_migration(old_version)`, 
  update stored version

The `_run_initialization()` routine is where a module seeds everything it 
needs to function: table definitions, seed data, RPC operation registrations, 
configuration keys it requires, enums it uses, component registrations. The 
module is responsible for its own data deployment.

This collapses installation, migrations, and package management into one 
pattern. Installing a package = adding a module registry row. First run 
against a fresh database = automatic full deployment. Multi-tenant = same 
code, different database, modules self-initialize against each instance.

Registry table columns:
- key_guid (deterministic from module class name)
- pub_name (module class name)
- pub_state_attr (app.state attribute name)
- pub_module_path (Python import path)
- pub_initialized (BIT, default 0)
- pub_initialized_at (nullable timestamp)
- pub_version (string, module-declared)
- priv_created_on, priv_modified_on

### Bootstrap Phase Is Specialized, Not Generalized

Bootstrap-phase modules are specialized loaders that read their own tables 
directly. They exist to stand the application up. They are NOT instances 
of a generalized registrar abstraction. This was considered and rejected:

- EnvironmentVariablesModule — reads .env
- DatabaseExecutionModule — connects to database via provider
- DatabaseOperationsModule — loads query registry
- ApplicationModuleRegistry — loads module registry, provides init check
- SystemConfigurationModule — key/value lookup against system_configuration
- ServiceConfigurationModule — key/value lookup against service_configuration 
  (may collapse with SystemConfigurationModule depending on distinction)

EnumerationsModule is DEFERRED. No real enums exist yet. The only candidate 
(database provider selection) is a config value. When enums become necessary 
for post-bootstrap use, they will be RPC calls, not a bootstrap module.

### Post-Bootstrap Goes Through RPC

Once bootstrap is complete, the RPC dispatcher is the SOLE access path to 
application functionality. The application module contract is: modules 
expose RPC-callable operations. No direct module method access from anywhere. 
No backdoors. If an operation is not registered, it does not exist.

The RPC dispatcher becomes the generalized registrar. Every operation 
(data lookup, business logic, component rendering, anything) is an RPC call 
that the dispatcher validates, authorizes, and routes.

### IO Gateway Architecture

Every external transport (HTTP RPC, MCP SSE, Discord WebSocket, REST API, 
future Electron IPC) is an IoService gateway. Two layers of contracts, 
symmetric to the database layer:

1. **Transport Provider ↔ IO Gateway** — each transport has a provider 
   that normalizes inbound requests into a standard GatewayRequest 
   (UserContext + RPC operation string + payload) and serializes outbound 
   GatewayResponse back to transport format. Abstract provider interface: 
   start, stop, normalize_request, serialize_response, extract_credentials.

2. **IO Gateway ↔ Application Module** — after identity resolution and 
   authorization, the gateway dispatches via RPC. Application modules 
   never know which transport originated the call.

Every external path ultimately resolves to an RPC call. The RPC dispatcher 
is the security boundary.

### Discord and MCP Lifecycle

- **Discord**: fire-and-forget background task via `asyncio.create_task()` 
  in module startup. The Discord module is a control surface around the 
  bot process, exposing send/receive/query interfaces. Single worker 
  deployment (no file locks needed).
  
- **MCP**: `session_manager.run()` wraps the lifespan yield. This is a 
  proven pattern and the simplest stable solution. Do not attempt to 
  reach into MCP SDK private internals — pin the SDK version tightly 
  instead. Lifespan structure:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
  module_manager = ModuleManager(app)
  await module_manager.startup_all()
  app.state.module_manager = module_manager
  try:
    # mcp_module = app.state.mcp_io_service
    # if mcp_module and mcp_module.session_manager:
    #   async with mcp_module.session_manager.run():
    #     yield
    # else:
    #   yield
    yield
  except Exception:
    logging.exception("lifespan failed to yield")
  finally:
    await module_manager.shutdown_all()
```

### The Client Is a Render Engine (Future)

The React frontend will be a component library — it knows how to render 
buttons, tables, forms, cards. The composition data (which components 
go where with what props in what layout) comes from the database. Same 
principle as a game engine: load one tree mesh, draw a million tree 
instances. The client almost never changes; the data that drives it does.

No React client is being built for a long time. Validation is JSON responses 
rendered on the home page — the "demo room" pattern from game engine 
development. Every new capability gets a JSON endpoint that proves it works 
before any rendering concern exists.

### Future Concept: Python Import from Database

Not near-term. Captured for architectural awareness so current decisions 
don't preclude it.

Python's execution model: files are loaded, parsed into bytecode, executed 
by the CPython VM. Files are the source of bytecode, not what runs.

Python supports custom import loaders via `importlib.abc.MetaPathFinder` 
and `importlib.abc.Loader`. A custom loader can read module source or 
compiled bytecode from anywhere — including a database.

The lifecycle engine we are building could host a custom loader that 
fetches modules from the database instead of the filesystem. The 
application becomes a pointer into a table. Hot reload by updating the 
row. Multi-tenant by pointing instances at different rows.

This is NOT being built now. The idempotent module initialization pattern 
already delivers the package-as-data value without needing import hooks. 
Modules stay as files on disk (editable in VSCode, trackable in git, 
debuggable with breakpoints). What the module DOES as metadata lives in 
the database and is self-deployed by the module's init routine.

The architecture supports moving to database-loaded modules later without 
changing any established contracts.

### Future Concept: Zero-Downtime Rolling Deployment

Once Python-import-from-database is implemented, the architecture enables 
near-zero-downtime deployments across a multi-instance fleet.

The bytecode cache pattern:
- Database stores module source as canonical truth
- A designated builder instance (or build service) compiles source to 
  Python bytecode on new version, stores version-tagged blobs keyed by 
  (source_guid, python_version)
- Application instances load modules by `marshal.loads()` from the cache 
  blob, not by recompiling source
- First loader of a new version pays compilation cost; subsequent 
  instances get instant load

The deployment flow:
1. Developer pushes new source to database (CLI tool or admin RPC)
2. Builder compiles in background, stores bytecode, flags version ready
3. Drain-stop on first instance: stop accepting new connections, wait for 
   in-flight requests to complete
4. Instance locks clear, process restarts
5. Instance loads from bytecode cache (seconds, not minutes), initializes, 
   runs module migrations automatically via init registry pattern
6. Load balancer re-enables instance
7. Repeat for each instance in the fleet

Total downtime per instance: ~20 seconds of restart. Total downtime for 
the fleet: zero, because only one instance is draining at a time.

Rollback is identical: flip the version pointer back to N, trigger another 
rolling restart. Old bytecode blob is still in the cache.

This requires:
- Python version locking across the fleet (3.13 bytecode won't load on 3.14)
- Version-tagged bytecode storage with fallback to recompile on version mismatch
- Build coordination (one builder at a time, or idempotent parallel builders)
- Invalidation logic (source change triggers recompile, pointer update)

The module initialization registry handles schema migrations automatically 
during the restart cycle — new instances on new version run `_run_migration()` 
if their stored version predates the code version.

Deployment becomes a continuous background process rather than an event. 
Instances pick up new versions on routine restart cycles.

Pure over-engineering for single-instance deployment. The architecture 
accommodates this without rework when the topology justifies it.

## Coding Conventions

- snake_case Python files, PascalCase class names (mechanical conversion)
- 2-space indentation
- `%s` log formatting, not f-strings in log calls
- match/case over if/elif chains
- No raise/except for normal control flow; logging.error + graceful None return
- No bare `except:`
- Column prefixes: key_* (PK), pub_* (functional), priv_* (audit), ref_* (FK), 
  ext_* (extension package columns — column-level only, not table-level)
- Table prefixes: service_* (platform infrastructure), system_* (runtime 
  config), {module}_* for module-specific tables
- Primary keys are deterministic UUID5 from NS_HASH unless the row is 
  user-generated (then NEWID())
- FOR JSON PATH on every SELECT; providers return parsed JSON
- FOR JSON PATH, WITHOUT_ARRAY_WRAPPER for single-row lookups

## Immediate Next Tasks

### Task 1: Documentation Pass

Before writing more code, produce mermaid sequence diagrams for the 
existing code flows. The codebase has been building without extensive 
documentation; this pass corrects that. Diagrams needed:

- Module manager startup sequence (discovery, instantiation, startup_all, 
  lifespan yield, shutdown_all, ready state propagation)
- Database request flow (caller → DBRequest → operations module GUID 
  lookup → cache hit/miss → lazy load → execution module → provider 
  → JSON parse → return)
- Bootstrap sequence (env module → execution module pool connect → 
  operations module bootstrap query → ready state)

Read the existing code files first:
- server/helpers.py
- server/lifespan.py
- server/modules/__init__.py
- server/modules/environment_variables_module.py
- server/modules/database_execution_module.py
- server/modules/database_operations_module.py
- server/modules/database_connection_providers/__init__.py
- server/modules/database_connection_providers/mssql_provider.py

Diagrams should go in a docs/ folder as .md files with embedded mermaid 
blocks.

### Task 2: Apply the Foundation Schema

The SQL scripts for service_extended_data_types, service_enumerations, 
and service_database_operations exist but use TODO placeholders for 
deterministic GUIDs. Write a small Python script that uses 
deterministic_guid() to generate all the GUIDs, then produce the final 
executable seed SQL. Apply to the database.

### Task 3: Build ApplicationModuleRegistry

This is the critical piece that enables the self-initialization pattern. 
Must come before any other module adopts the init pattern. Includes:

- Schema SQL for system_objects_modules with initialization tracking columns
- The module itself, following the DatabaseOperationsModule reference pattern
- Public methods: get_status(guid), register(guid, metadata), 
  mark_initialized(guid, version)
- The base module class gets updated to include the init check in its 
  startup flow

### Task 4: Build SystemConfigurationModule

Following the registry pattern. Same shape as DatabaseOperationsModule. 
Decide whether ServiceConfigurationModule is a second module or the 
same table with a category column.

## User Interaction Style

Elideus writes all production code. Claude's role is architectural thinking 
partner, syntax helper, research assistant, and design reviewer. Do not 
generate large code blocks unsolicited. Do not perpetuate patterns from 
legacy code; the whole point of this rebuild is to eliminate them. When 
in doubt about a pattern, ask before generating code. Keep responses 
focused. Elideus will tell you when to expand.