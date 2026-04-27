# The Contract Layer

**Product:** TheOracleRPC
**Codename:** Unity

**Spec document — `docs/CONTRACTS.md`**
**Status:** authoritative definition of the application as a type graph,
and of the contract layer as a runtime security boundary.

---

## 1. What the application is

This application is a type graph.

Every function in the system is a typed transformation from one model to another.
Every model is a named, ordered composition of typed fields. Every field's type
is one of the entries in the platform type catalog (`service_types`).

Three tables define the application's complete behavioral surface:

- `contracts_api_functions` — one row per named function, referencing input and output models
- `contracts_api_models` — one row per named model (input or output shape)
- `contracts_api_model_fields` — one row per field in a model, joined to `service_types`

Joined through `service_types`, these three tables are the **canonical definition
of the application**. The implementation — currently Python, eventually whatever
best serves each module — is a materialization of these tables. The tables are
the source of truth; the code is downstream.

This is not a documentation style. This is the architecture.

---

## 2. This layer is a security boundary

The contract tables are not a dictionary. They are not documentation. They are
not a generated artifact that describes the runtime.

**They are the runtime.**

The running application reads these tables to determine what functions exist,
what data those functions accept, what data those functions return, and what
is permitted to be rendered to a client. A function that does not have a row
in `contracts_api_functions` does not exist from the dispatcher's point of
view. A field that does not have a row in `contracts_api_model_fields` is
not serialized to the client, regardless of what the Python code places in
its return value.

This makes the contract layer an active participant in the security
perimeter of the application. The implications are not negotiable:

- **Code without a contract row is invisible to the gateway.** It cannot be
  dispatched to. If implementation introduces a function that has no contract
  row, that function is unreachable through the sanctioned path. Any path
  that does reach it is a hole in the security model, not a clever
  workaround.
- **Fields without a contract row are not transmitted.** Adding a field to a
  Python model without adding it to the contract tables does not expose the
  field to clients — it exposes a drift between implementation and contract,
  which is a defect.
- **Contract rows are the allow-list.** The tables do not describe what the
  system *might* do. They define what the system *is permitted to do*.
  Expanding capability requires expanding the tables first.

The contract layer is therefore load-bearing in the strongest possible sense.
Violations are not style issues or documentation lapses. They are
vulnerabilities, bugs, or both.

---

## 3. The rule

Before proposing any function, model, data shape, or inter-module interaction:

**Query the contract tables.**

If the needed shape exists as a row, match it exactly. If it does not exist,
the missing row must be added to the contract tables **first**. Implementation
follows definition. Never the reverse. Not during initial development, not
during refactoring, not for helpers that seem obviously small, not under
any circumstance whatsoever.

Code that does not correspond to a contract row does not exist from the
architecture's point of view, and — because the runtime reads the tables —
it does not exist from the security model's point of view either. The
resolution is always the same: update the contract tables to reflect the
intended behavior, then align the implementation. There is no valid path
that runs in the reverse order.

This rule is not a workflow recommendation. It is the invariant the runtime
depends on to stay secure.

---

## 4. How to query it

The contract layer is accessible via MCP. To retrieve the signature of any
named function:

1. Query `contracts_api_functions` by `pub_name`, retrieve input and output model GUIDs.
2. Join `contracts_api_models` on each model GUID for the model definitions.
3. Join `contracts_api_model_fields` on each model GUID for the ordered field list.
4. Join `service_types` on each field's type GUID for the field's platform type.

The result of this four-step join is the complete signature of the function
across every supported language and transport: Python type, TypeScript type,
JSON type, database type, ODBC code. A function's signature is not an opinion.
It is a query result.

When an implementation's signature does not match the query result, the
implementation is incorrect. When the query result does not match the
desired behavior, the contract is incomplete and must be updated before
the implementation is modified. In both cases, the tables are authoritative.

---

## 5. Why this exists

The application was previously expressed primarily in code, with prose
documentation orbiting it. This failed reproducibly: across rewrites, the
architectural shape would be rediscovered, articulated clearly, and then
erode again as prose compressed and implementation drifted.

Worse, the erosion had no enforcement surface. A drift between "what the
architecture says" and "what the code does" was resolvable only by careful
reading. Security invariants that live only in prose are security invariants
that can be lost to a compression pass.

The contract layer ends this cycle by making the type graph the runtime's
source of truth. The shape lives in tables that cannot be compressed, cannot
drift silently, can be queried, and are read by the dispatch and rendering
machinery to decide what is reachable and what is transmitted. Diagrams
and documents become views over the table data. Security becomes a join.

A second consequence follows directly: **the contract layer defines behavior,
not implementation.** The rows specify what a function takes, what it returns,
and what is permitted to cross the boundary. They do not specify the language
the function is written in, the runtime that hosts it, or the transport that
reaches it. A module currently implemented in Python may be reimplemented in
Go, Rust, or C++ without altering a single contract row, provided the new
implementation satisfies the same signature. The contract is the stable
surface; the implementation is a materialization target. This is the property
that keeps the architecture portable across the decades the system is
intended to operate.

---

## 6. What lives elsewhere

The contract layer defines *what data flows through the application*. It
does not define:

- **Lifecycle and module assembly** — how modules are constructed, sealed,
  and shut down. See `docs/module_lifecycle.md`.
- **Persistence schema** — the database tables, columns, and constraints.
  Defined in `objects_schema_*` tables; see `docs/database.md`.
- **Authentication protocols** — IDP providers and identity resolution.
  Will be defined in a future `contracts_auth_*` cluster.
- **Transport / IO gateways** — HTTP, RPC, WebSocket handlers. Will be
  defined in a future `contracts_io_*` cluster.

All of these layers reference the contract layer for the data shapes they
operate on, but they are not the contract layer.

---

## 7. The naming cluster

Current and planned tables under the `contracts_*` prefix:

| Cluster            | Subject                                    | Status   |
| ------------------ | ------------------------------------------ | -------- |
| `contracts_api_*`  | Application function catalog               | v1.0.1   |
| `contracts_db_*`   | Database query contracts                   | Future   |
| `contracts_auth_*` | IDP provider and authentication protocols  | Future   |
| `contracts_io_*`   | Transport gateway contracts                | Future   |

Every `contracts_*` cluster follows the same discipline: it defines
boundaries, not implementations. A row in a `contracts_*` table is a
permanent statement about what something must be. Implementation satisfies
the row, or the row is wrong, or the runtime is compromised.