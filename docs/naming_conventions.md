# Naming Conventions

**Product:** TheOracleRPC
**Codename:** Unity

**Spec document — `docs/naming_conventions.md`**
**Status:** authoritative reference for naming across code and data.

---

## 1. Purpose

This document is about terms. Which words Unity uses for which
things, and why the vocabulary is shaped the way it is. It is not
a catalog of existing names — the schema file holds the tables,
the module files hold the modules, the role-name taxonomy holds
the role-names. This doc holds the reasoning that lets a reader
meet a new name and know where to place it.

---

## 2. The black-box principle

All things are black boxes; all things know only of themselves. A
module knows its own name and its own contract. It does not know
what the tables it touches are named. A table knows its own
columns. It does not know which module reads it.

Code and data therefore share no vocabulary. A module named
`KernelConfigurationModule` reading from a table named
`system_configuration` is not a naming inconsistency — the module
name describes the module's role in the runtime; the table name
describes the row's role in the data. They answer different
questions and neither answer is authoritative over the other.

The one exception is the **op string**. Op strings are the
single surface where code and data agree on a name, and they do
it by naming a shared concept — the op string's domain segment
matches a table prefix because both refer to the same
concept-cluster, not because either side is aligned to the other.

---

## 3. The vocabulary of module roles

Modules describe themselves using a shared vocabulary of role-names.
A module's name combines the subsystem it serves with the role it
plays within that subsystem: `DatabaseOperationsModule`,
`AuthExecutionModule`. New subsystems should prefer terms already
defined here rather than inventing local ones — the vocabulary is
shared because a role-name means something when multiple subsystems
agree on it.

Broadly, role-names describe three kinds of position.
**Public-contract** names (Operations, Maintenance, Interface)
describe how callers reach the subsystem. **Dispatch** names
(Execution, Management) describe how work moves from the contract
to the resource. **Leaf** names (Provider, Worker, Gateway)
describe what the work actually touches. A module picks the name
that fits its position; when a position is new, the vocabulary
extends rather than a subsystem going its own way.

Kernel's own platform-substrate modules — the ones that sit outside
any subsystem — carry the `Kernel*` prefix.

---

## 4. Table prefixes as concept-clusters

A table's prefix names a concept-cluster: the coherent area of
the system where the table conceptually lives. Every table has
one prefix; the prefix declares the table's primary domain, not
exclusive ownership. Cross-cluster relationships are foreign keys
(§5), not naming decisions.

Prefixes are open-ended. `service_`, `system_`, and `objects_`
are in use today for platform substrate, runtime configuration,
and self-referential platform metadata respectively. More appear
as subsystems and domains land — `database_`, `auth_`, `finance_`,
`token_`, whatever the concept earns. New prefixes are cheap when
a concept-cluster emerges that doesn't fit the ones already in
use; there is no fixed list to expand, only a vocabulary that
grows.

Two-segment names (`<prefix>_<thing>`) are preferred because the
prefix is doing the conceptual work and a second segment is
usually enough to name the thing. When a sub-concept refines into
its own domain, the child table's prefix is the parent's
suffix — `account_users` → `users_tokens` → `tokens_sessions` —
so the chain of names shows lineage. This is a readability
aesthetic; it doesn't need to be forced.

---

## 5. Column prefixes as row-role

A column's prefix names its role in the row. Five prefixes,
answering five questions about any column a reader encounters:

- `key_*` — is this the primary key?
- `pub_*` — is this functional data?
- `priv_*` — is this written by the platform, not the caller?
- `ref_*` — is this a foreign key to another row?
- `ext_*` — is this added by an extension package?

The prefix answers the question faster than the type does, which
is the point. A reader scanning a row sees its shape before its
content.

---

## 6. Identity by formula

Primary keys are deterministic UUID5 values, computed from the
table name and a natural key:
`uuid5(NS_HASH, "{table_name}:{natural_key}")`. The namespace is
fixed (`DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB`); the natural key
is whatever uniquely identifies the row in its table.

Deterministic keys mean identity is a function of meaning rather
than of insertion order. The same conceptual row has the same
GUID in every environment and across every reseed. Seed data
ships with literal GUIDs and stays correct. Code never caches a
GUID because code never needed the GUID to be stable across
runs — the formula does that work.

---

## 7. Op strings

Op strings name operations with five segments:
`{scope}:{domain}:{subdomain}:{verb_noun}:{version}`. Two scopes
are in use — `db:` for database operations resolved against the
operation registry, `urn:` for RPC operations resolved by the
gateway.

The domain segment is the alignment surface described in §2. A
`db:service:...` operation conceptually touches the `service_`
cluster; a `db:finance:...` operation conceptually touches
`finance_`. The alignment is in the concept, not in any
mechanical coupling — any module may issue any op.

Versions are positive integers, independent of the platform
version. An op's version changes when the op's contract changes
incompatibly; the platform version (§8) tracks the platform.

---

## 8. Platform version

The platform version is four parts: `Major.Minor.Schema.Build`.
Pre-release, all movement is on Minor; Major is reserved. Schema
increments independently when the database schema changes within
a Minor, without tagging a release. Build is CI-driven.

The four-part shape exists because the version is stored in the
database and the database version moves on its own cadence. A
schema change inside a release cycle needs to show up in the
running instance's reported version without forcing a release
tag. Splitting Schema from Build lets the database say what it
is without lying about what code is running against it.

Bumps are driven by a REPL CLI — `update version major`,
`update version minor`, `update version schema`. Major and minor
bumps tag and commit; schema bumps update the database and
preserve the build counter.

Migration filenames carry the full four-part version:
`v{Major}.{Minor}.{Schema}.{Build}_<short_description>.sql`.

---

## 9. Names that cross

A few names appear in both code and data surfaces — op strings,
enum type names, service-type names, module-manifest names.
These are the names most prone to drift, because code and data
can each change independently without noticing.

The discipline is one-way: **the data row is authoritative; code
resolves by lookup.** Code addresses rows by their natural key
and lets the registry produce the GUID on resolution. This is
the practical expression of §2 — code doesn't hold data's
identifiers, only data's names, and names are cheap to change.
