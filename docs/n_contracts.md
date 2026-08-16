# Contracts

## What a contract is

A contract is the typed interface between two parts of the system.
Wherever the application has a boundary between parts — between a
module and an external caller, between a module and the data it acts
on, between a module and the runtime substrate underneath it — that
boundary is described by a contract. The contract names what crosses
the boundary, names the shape of what crosses, and names the types of
the values inside that shape. Nothing crosses a boundary in this
system that is not described by a contract.

This is not "the contract layer." There is no single contract layer.
Contracts are the wiring discipline of the entire application. Every
inter-part boundary in every surface of the system has contracts
describing it, and they are all instantiations of the same pattern.

## The application as a type graph

The application is a type graph. Every part of the system that has a
typed identity — every named function, every named model, every named
field, every named type — is a row in a contracts table, with a
deterministic GUID, with foreign keys to the rows it depends on. The
graph is fully connected and fully walkable. Starting from any
function row and following the foreign keys leads to its input model,
its input model's fields, the types of those fields, and ultimately
the atomic primitive types at the leaves. Same for the output side.
Same for every other entity in the graph.

This is the application's self-description. It is data, not code.
It is queryable, reflectable, and the source of truth that code is
expected to match. When the type graph and the code disagree, the
code is wrong.

The mechanical implication is that the application's surface — the
set of things it can be asked to do, the set of things it can do
internally, the set of things it depends on externally — is
enumerable by query, end to end. There is no part of the application's
typed structure that exists only in code.

## Surfaces and clusters

The application has multiple surfaces — multiple kinds of boundary
between parts. Each surface gets its own contract cluster. The
clusters are parallel applications of the same pattern, distinguished
by which boundary they describe.

The pattern, in every cluster: named entities (with deterministic
GUIDs), typed models composed of typed fields, foreign keys walking
down to the atomic vocabulary. The cluster prefix names the surface.
The structural shape inside the cluster is uniform.

### The cluster set

The clusters listed below are the ones built, being designed, or
reserved for surfaces we already know need typed description. The
application will almost certainly gain surfaces beyond these — when
it does, those surfaces get their own clusters following the same
pattern. The list isn't closed; it's the current view.

- **`contracts_primitives_*`** — the atomic vocabulary. Types, enums,
  and the call surfaces (internal, SQL, external) the rest of the
  application is built on. Every other contract cluster bottoms out
  here. See `contracts_for_primitives.md`.
- **`contracts_api_*`** — the module API surface. Named functions
  exposed by modules, with typed input and output models. The
  application's public method catalog. See `contracts_for_api.md`.
- **`contracts_db_*`** — the database operation surface. Named
  queries and mutations against the data model, fully decomposed into
  tables, columns, predicates, parameters, expressions. See
  `contracts_for_database.md`.
- **`contracts_rpc_*`** — *(anticipated)* a likely cluster for the RPC
  dispatch surface, covering whatever needs typed description in the
  bindings between RPC entry points and the API functions they
  dispatch to. Currently described informally in `security.md`. Shape
  pending design.
- **`contracts_auth_*`** — *(anticipated)* a likely cluster for the
  authentication surface — IDP providers, protocol bindings, identity
  resolution. Currently described informally in `auth.md`, which
  predates this contracts framing. Shape pending design.
- **`contracts_io_*`** — *(anticipated)* a likely cluster for the
  gateway/transport surface, where HTTP-to-RPC-to-DB payload
  transformations would live if they need typed description as
  contracts. Whether this surface needs its own cluster, or whether
  the relevant contracts live elsewhere, is itself an open question.

When the application gains a new surface — a new boundary at which
typed things cross — that surface gets its own contract cluster. The
clusters above are today's set; new ones are added as needed.

## The pattern, stated precisely

Every contract cluster instantiates the same structural pattern:

1. **Entity rows.** The named things the cluster catalogs. Functions
   in `contracts_api_*`, operations in `contracts_db_*`, primitives in
   `contracts_primitives_*`. Each entity has a `key_guid` (deterministic
   UUID5), a `pub_name` (the human-meaningful identifier), and
   `pub_notes` for design rationale.
2. **Model rows.** Named typed shapes. The same model can be the
   input or output of multiple entities; models are reusable within a
   cluster. The `VoidModel` row exists in every cluster that has a
   model catalog, representing the empty shape (used by entities with
   no meaningful input or output).
3. **Field rows.** The decomposition of a model into ordered, named,
   typed parts. A field references its containing model and the type
   of its value. Fields are the leaves of the model-side graph and
   the bridge into the type catalog.
4. **Type references.** Field type references walk into
   `contracts_primitives_*` — either a scalar in
   `contracts_primitives_types` or a named enumerated type in
   `contracts_primitives_enums`. Eventually a type reference may also
   point at a nested model, when the type system supports nested
   composition.
5. **Cluster-specific extensions.** Where a cluster has structural
   needs beyond the entity/model/field triad, additional tables hang
   off the entity rows. `contracts_db_*` has the largest extension —
   the full query decomposition graph — because the database surface
   has the richest internal structure. `contracts_api_*` is mostly
   pure pattern. `contracts_primitives_*` extends with call-surface-
   specific metadata (versioning, endpoints, auth) on the external
   primitive catalog.

## Conventions, applied uniformly

The conventions below are the working discipline of the contracts
family as currently designed. They apply across every contract
cluster, and a cluster departing from them is a defect within the
current design. The conventions themselves may evolve as the design
matures; when they do, the change applies uniformly across all
clusters and is reflected here.

### Column prefixes

- `key_*` — primary key columns.
- `ref_*` — foreign key columns. Always reference another contracts or
  foundation table by `key_guid`.
- `pub_*` — publicly meaningful columns. Names, notes, descriptions,
  values intended to be read by humans or surfaced in tooling.
- `ext_*` — extension columns added by installed packages to extend a
  core table with package-specific data. The `ext_*` prefix marks the
  column as belonging to a package extension rather than to the core
  table's own concerns. The package system that owns these columns is
  pending its own design pass; the prefix is reserved here so core
  tables don't accidentally collide with future extension columns.
- `priv_*` — private/operational columns. Timestamps, audit data,
  internal bookkeeping not intended to be part of the contract's
  meaning.

Column ordering within a table follows prefix order: `key_*` first,
then `ref_*`, then `pub_*`, then `ext_*` (when present), then `priv_*`.

### Deterministic GUIDs

Every entity row in every contract cluster has a `key_guid` computed
as `uuid5(NS_HASH, "<table_name>:<identifier>")`. The namespace is
fixed (`DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB`). The entity-type token
is the full table name. The identifier is whatever uniquely names the
row within its table — a `pub_name` for most rows, a composite key
for junction rows.

The same identifier produces the same GUID, every time, on every
machine, in every environment. GUIDs are not allocated; they are
computed. Seed files contain placeholder zeros that are replaced at
apply time by the seeding tooling.

### Model and field decomposition

Models compose fields; fields reference types. A model with no fields
is the cluster's `VoidModel`. A field has a position (ordinal) within
its model. Fields are not shared across models — each model's fields
are its own rows. Two structurally identical models still have
distinct field rows.

This is deliberate. The contract is the named shape, not the
structural shape. Two models that happen to have the same fields
today may diverge tomorrow; treating them as the same model would
make that divergence a breaking change rather than an additive one.

### Cross-cluster boundaries

A cluster's entities never reference another cluster's entities
directly except through the primitives catalog at the leaves. The api
cluster does not reference the db cluster's operations; the db
cluster does not reference the api cluster's functions. The wiring
between them — the logic that says "this api function calls this db
operation" — is not part of the type graph yet. It will be its own
cluster (probably under `contracts_rpc_*` or a sibling) when designed.

This means each cluster is independently meaningful. The api catalog
fully describes the api surface without needing to know how its
functions are implemented. The db catalog fully describes the data
operation surface without needing to know which functions invoke
which operations. The clusters are parallel descriptions of parallel
surfaces, joined by code at runtime, not by foreign keys at rest.

## The runtime security invariant

The set of things the application can be asked to do is exactly the
set of rows in `contracts_api_*`. The set of things the application
can do internally is exactly the set of rows in `contracts_primitives_internal`
and `contracts_primitives_sql`. The set of remote services the
application depends on is exactly the set of rows in
`contracts_primitives_external`. The set of database operations the
application can perform is exactly the set of rows in `contracts_db_*`.

A caller must be defined in data before it can be called. Code that
attempts to invoke something not catalogued is a defect, and the
runtime is expected to refuse it. This is the security boundary: the
type graph is the source of truth for what the application is
permitted to do.

This is the long-term enforced invariant. The dispatch machinery that
reads the contracts at runtime and refuses uncatalogued calls is
forthcoming — see `security.md` and the future `contracts_rpc_*`
cluster. Until that machinery is built, the invariant is design
intent rather than runtime enforcement. The data shape supports the
intent; the runtime is catching up.

## What's built now

As of this writing:

- **`contracts_api_*`** has its three core tables defined and seeded
  with `VoidModel` and `env_get` as the first populated rows.
  Schema is locked; remaining kernel module functions populate one
  row at a time.
- **`contracts_primitives_*`** is being designed. The type catalog
  exists in stub form (currently named `service_types`, slated for
  rename into `contracts_primitives_types`). The enum catalog,
  internal call surface, SQL call surface, and external call surface
  are designed in `contracts_for_primitives.md` and pending migration.
- **`contracts_db_*`** is being designed. Full design lives in
  `contracts_for_database.md`. Pending migration.
- **`contracts_rpc_*`**, **`contracts_auth_*`**, **`contracts_io_*`**
  are reserved. No design work yet. Existing `auth.md` and
  `security.md` describe the surfaces these clusters will eventually
  catalog, but their content is informal and predates this contracts
  framing.

The migrations are versioned `v0.15.<schema>.0_<name>.sql`, with each
cluster getting its own schema increment within the v0.15.0.0
foundation pass.

## How to read the rest of this section

The cluster-specific documents are the authoritative references for
their clusters. They assume the reader has read this overview and
will not re-establish the type-graph framing.

- `contracts_for_primitives.md` — the atomic vocabulary cluster.
- `contracts_for_api.md` — the module API surface cluster.
- `contracts_for_database.md` — the database operation surface cluster.

When other cluster documents are written, they are added here.
