# Unity Platform — Session 5 Handoff

## Project Context

You are working with Elideus on `elideus-group-unity` — a greenfield rebuild
of TheOracleRPC CMS. Code is the engine, data is the application. The Python
codebase is a thin lifecycle engine hosting modules that self-describe their
behavior through database rows.

- **Product:** TheOracleRPC
- **Codename:** Unity
- **Active repository:** `C:\__Repositories\elideus-group-unity`
- **Legacy reference (read-only):** `C:\__Repositories\elideus-group`

## What Session 4 Accomplished

### Documentation

The first spec document landed: `docs/module_lifecycle.md`. It is the
authoritative reference for the module system and supersedes any
docstrings that disagree. Six diagrams, all mermaid: concurrent
startup with dependency waits, class relationships, full lifecycle,
seal manifest hook chain, operational loop across phases, two-axis
database pattern, module state machine.

### Codebase changes

1. **Renamed `server/modules/` → `server/kernel/`.** The kernel now
   hosts the module manager plus six concrete kernel modules
   (environment, database execution, database operations, database
   maintenance, database management, system configuration, service
   enum). Auth and IoGateway will live here too. Everything else —
   extensions, packages, application modules — lives outside.
2. **`ModuleManager._sealed: bool` → `_sealed_event: asyncio.Event`.**
   Single event backs two access modes: `is_sealed` (sync property,
   `Event.is_set()`) for rejection checks, `on_sealed()` (async,
   `Event.wait()`) for background tasks to park until the app is up.
3. **`DatabaseManagementModule` monitor loop rewired.** Task creation
   moved from `on_seal()` into `startup()`; loop body gates on
   `await self.module_manager.on_sealed()`. `on_seal()` is now `pass`.
4. **Vocabulary lock: `raise_seal` / `on_sealed` / `on_seal` / `is_sealed`.**
   Completed a codebase rename from the older `mark_ready`/`on_ready`
   names. VSCode LSP handled symbol rename; comment text required
   manual updates. A few header docstrings in `server/kernel/__init__.py`
   still carry stale pre-rename terms — flagged in the spec doc §11
   as a cosmetic backlog item.
5. **GUID derivation removed from all three lookup modules.**
   `service_enum_module`, `system_configuration_module`, and
   `database_operations_module` no longer compute deterministic GUIDs
   at runtime. They cache by natural key and lazy-load (where
   applicable) via `WHERE pub_<natural_key> = ?` against the table's
   UQ constraint. `deterministic_guid` has zero runtime callers as of
   end of session — it remains a helper for seed generation and any
   future module that *creates* rows with known natural keys.
6. **Error handling tightened on the execution path.** `execute` now
   uses `-1` as a failure sentinel (distinct from `0` "ran, zero rows
   affected"). The MSSQL transaction provider wraps its cursor
   operation in try/except with logging. The module layer returns
   `-1` when no provider is active.

### Current kernel module inventory

| Module | Role |
|---|---|
| `EnvironmentVariablesModule` | Reads `.env`, exposes `get(var_name)` |
| `DatabaseExecutionModule` | Provider-agnostic executor (query/execute) |
| `DatabaseOperationsModule` | Named-op dispatch (bootstrap + lazy-load by `pub_op`) |
| `DatabaseMaintenanceModule` | Public API for maintenance declarations |
| `DatabaseManagementModule` | Privileged executor via monitor loop against `service_tasks_ddl` |
| `SystemConfigurationModule` | Sync key/value cache (full table load) |
| `ServiceEnumModule` | Sync enum cache (full table load, flat list) |

Provider layer: `DatabaseTransactionProvider` and
`DatabaseManagementProvider` ABCs in
`server/kernel/database_execution_providers/__init__.py`. Concrete:
`MssqlProvider` (transaction), `MssqlManagementProvider` (management
— still a stub, all DDL methods return `False`).

## Kernel Scope — Locked

The kernel will host exactly three subsystems:

1. **Database** — done (six modules + providers)
2. **Auth** — next functional build
3. **IoGateway** — after auth; providers implemented alongside
   database and auth in the same Manager/Executor/Provider model

Open question: is storage a fourth kernel concern or an IoGateway?
Not blocking anything yet; will be decided when storage work begins.

Everything else (application modules, extensions, packages, the
future CMS rendering engine) lives outside the kernel. The kernel is
the thin runtime layer. Features are data.

## Documentation Plan — Remaining

The Session 3 plan listed six spec documents. One is done. The rest,
in priority order:

| # | Status | Document |
|---|---|---|
| 1 | ✅ done | `docs/module_lifecycle.md` |
| 2 | **next** | `docs/provider_composition.md` |
| 3 | | `docs/database_management.md` |
| 4 | | `docs/naming_conventions.md` |
| 5 | | `docs/security.md` |
| 6 | | `docs/coding_standards.md` |

Note the path change: docs live at `docs/`, not `docs/specs/` as the
original plan had it. Keep the flat layout.

Work on one at a time. Propose the outline, Elideus reviews, draft,
iterate. Diagrams are mermaid, embedded in markdown.

## Next Document: `docs/provider_composition.md`

Scope per Session 3's brief:

> Transaction provider contract · Management provider contract ·
> Composition via shared pool (`get_base_provider`) · Why composition
> over inheritance · Manager/Executor/Provider model generalization ·
> Mermaid diagram of request flow through the composed providers.

Scope boundary against the already-written `module_lifecycle.md`:

- **`module_lifecycle.md` owns** the six-module pattern at the module
  level, the two axes (operations/maintenance), the queue boundary
  between maintenance and management, and the Manager/Executor/Provider
  *pattern name*.
- **`provider_composition.md` owns** the provider-layer mechanics:
  ABC contracts, `get_base_provider()`, pool ownership, composition
  vs inheritance rationale, and the generalization of the M/E/P model
  for future subsystems (auth, IoGateway).
- **`database_management.md` will own** the task queue semantics,
  monitor loop cadence, task lifecycle, drainstop coordination.

Files to read first before proposing the outline:

- `server/kernel/database_execution_providers/__init__.py` (both ABCs)
- `server/kernel/database_execution_providers/mssql_transaction_provider.py`
- `server/kernel/database_execution_providers/mssql_management_provider.py`
- `server/kernel/database_execution_module.py` (owns the pool,
  exposes `get_base_provider()`)
- `server/kernel/database_management_module.py` (composes the
  management provider during `startup()`)

## Key Alignments for Future Context Sessions

These are orientations that saved time in Session 4 or that previous
sessions had to rediscover.

### Filesystem MCP is wired to both repositories

Tool access confirmed for both `elideus-group-unity` (active) and
`elideus-group` (legacy reference). Use `Filesystem:read_text_file`
and friends directly — no need to ask for permission.

### Claude does not have write access through Filesystem MCP

File deliverables go through the create_file tool (Claude's computer,
under `/mnt/user-data/outputs/`), then `present_files` to surface
them as downloads. Elideus drops them into the repo manually. This
path has been clean and fast.

Claude Code via the hosted branch-PR flow has **not** been productive
— one attempt produced a polluted branch with +703/-299 of unrelated
noise and a wrong merge target. Stick with the artifact-drop pattern
unless the environment gets cleaned up.

### Behavioral discipline that worked

- **Re-read code before answering.** Handoff docs drift from reality.
  Every session, re-verify assumptions against the actual files.
- **Propose outlines before drafting.** Especially for documents.
  Iterating on a 12-bullet outline is cheaper than iterating on a
  3000-word draft.
- **Name things once, then stop overloading.** The seal vocabulary
  (`raise_seal` / `on_sealed` / `on_seal` / `is_sealed`) was
  worked out carefully in Session 4. Don't reinvent it.
- **Push back on overcomplication.** Several times in Session 4,
  Elideus caught me spiraling into unnecessary abstraction (codegen
  discussions, three-pattern participation models, GUID-vs-natural-key
  edifice). The good answers were consistently the simpler ones.
  Trust "do less."

### Behavioral failure modes to avoid

- **Pattern-inventing.** Documenting "here are three ways to do X"
  when really there are just two (and the third was a mistake the
  code was making). Describe the implementation, not the decision
  space.
- **Explaining what not to do.** Negative framing puts ideas into the
  reader's head. "Don't extend `on_seal`" made the reader wonder how
  they'd extend it. Prefer positive framing that simply shows the
  pattern.
- **Irrelevant context bloat.** Listing specific modules that use a
  given pattern is noise if the reader is writing a new module. Cut
  it.
- **Over-indexing on handoff text vs current code.** Handoffs are
  snapshots; code is truth. When they disagree, the code wins.

### Writing style preferences

- Prose, not bullets, unless the content is genuinely list-shaped.
- Mermaid for diagrams, embedded in markdown.
- Code examples are illustrative snippets, not full module bodies.
- Tables are fine when comparing N things across M axes.
- 2-space Python indent, snake_case files, PascalCase classes, `%s`
  log formatting, match/case over if/elif, `logger.error` + graceful
  return rather than raise for control flow.

## Architectural Decisions Made in Session 4 (Not Yet in Spec Docs)

These need to land in the appropriate future spec:

- **Manager/Executor/Provider is the generalized pattern name.** Auth
  and IoGateway will use it. Goes in `provider_composition.md`.
- **Queue-mediated boundary between manager and executor is the safety
  pattern for privileged subsystems.** Goes in `database_management.md`
  (specific) and referenced from `security.md` (generalized).
- **`deterministic_guid` is seed-generation infrastructure, not
  runtime lookup infrastructure.** Runtime modules cache by natural
  key. Goes in `coding_standards.md` or `naming_conventions.md`
  (whichever feels like a better home).
- **`-1` is the failure sentinel for `execute`; `None` is the failure
  sentinel for `query`.** The `query` collision with "no rows found"
  is accepted because pydantic validation downstream enforces the
  distinction. Goes in `coding_standards.md`.
- **No raise/except for control flow.** Graceful `None`/`-1`/`0`
  returns with `logger.error`. This is already practiced in every
  kernel module; should be documented as a rule in
  `coding_standards.md`.

## Known Gaps and Backlog

From the `module_lifecycle.md` §11 plus items accumulated during
Session 4:

- Header docstrings in `server/kernel/__init__.py` still use
  `mark_ready` / `on_ready` in comment text. LSP rename doesn't touch
  comments. Fix on the next touch of that file.
- No circular-dependency detection in the module graph. Intentional —
  seed data prevents it, and the silent deadlock is the designed
  failure mode.
- Seed-package hooks have no-op defaults. Content lands when modules
  start shipping real seed packages.
- `MssqlManagementProvider` read/DDL methods are all stubs. Live
  introspection + diff engine is future work (Session 3's Priority 2
  from its handoff is still open).
- Seed SQL uses `INSERT`; should move to `MERGE` for idempotent
  re-runs when modules start shipping seed packages (Session 3
  backlog item).
- `TaskDdlPollRate` config key has no seeded default. Picked up
  implicitly as 5.0 in code. Will be seeded when management module
  ships a seed package.

## Interaction Style

Elideus writes all production code. Claude is architectural thinking
partner, syntax helper, research assistant, and design reviewer. Do
not generate large code blocks unsolicited. Keep responses focused.
When in doubt about a pattern, ask before generating. Elideus will
tell you when to expand.

For documentation work, code snippets as illustration are fine and
expected. Keep them short; document patterns, don't paste code.