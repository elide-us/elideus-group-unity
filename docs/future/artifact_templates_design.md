# Artifact Templates — Design Note

Status: deferred. Captured at the close of session 008 to record the design
intent so it isn't lost when subsequent sessions move past it. Implementation
is the planned follow-on once the bootstrap operations migration is complete.

## Motivation

`scriptlib.py`'s `dump()` and `_merge()` and `_build_*()` functions all share a
pattern: take structured data from `contracts_db_*` rows and wrap it in
repeated text scaffolding to produce an installable artifact (a SQL file,
a JSON seed file, eventually a marketplace-distributable installer). The
scaffolding is currently hardcoded as Python string literals and f-strings.

Examples of what's hardcoded today and shouldn't be:

- `-- Generated <timestamp> UTC` header line
- `SET ANSI_NULLS ON;\nGO\nSET QUOTED_IDENTIFIER ON;\nGO` MSSQL prelude
- Section dividers like `-- ===== Static prelude: types table =====`
- The `CREATE TABLE [<schema>].[<name>] (...)` wrapper that
  `_build_create_table` assembles
- The `ALTER TABLE [<schema>].[<name>] ADD CONSTRAINT [<name>] <body>;`
  wrapper in `_build_constraint`
- The `INSERT INTO [<schema>].[<table>] (<cols>) VALUES (...), (...);`
  multi-row wrapper in `_build_table_seed`
- The `MERGE INTO [<table>] AS T USING (...) AS S ON ... WHEN MATCHED ...
  WHEN NOT MATCHED ...` block that `_merge` builds
- The `CREATE [UNIQUE] INDEX [<name>] ON [<schema>].[<table>] (<cols>);`
  in `_build_create_index`

All of these are templates with substitution slots. They're also engine-
specific — square brackets are an MSSQL-ism, `dbo` is a default schema
convention, the `MERGE` syntax shape varies between MSSQL/Postgres/MySQL.

The data-driven philosophy says these belong as rows in a table, not as
string literals in code.

## Naming

- `contracts_artifact_templates` — the template rows themselves
- `contracts_artifact_elements` — junction table for declared substitution
  slots

The word "artifact" is chosen over "output" / "script" / "emission" because
these templates produce installable artifacts, not just scripts. SQL today,
but the design accommodates JSON, TypeScript, Python module surfaces, and
eventually whatever the marketplace format ends up being.

The word "element" for the junction is chosen because slots are *parts* of
the template — borrowing the same vocabulary as `pub_seed_element` and
`pub_bootstrap_element` and the other `_element` flags used elsewhere.

## Shape (proposed)

```
contracts_artifact_templates
  key_guid              UUID  PK
  ref_package_guid      UUID  NULL  FK -> service_modules_manifest (cascade)
  ref_engine_guid       UUID  NULL  FK -> contracts_db_engines
                                    NULL = engine-agnostic (e.g. JSON output)
  pub_name              STRING(128)  e.g. 'create_table_block'
  pub_body              TEXT         the template text with substitution markers
  pub_notes             STRING(512)  NULL
  priv_created_on, priv_modified_on
  UQ on (ref_engine_guid, pub_name)
```

```
contracts_artifact_elements
  key_guid              UUID  PK
  ref_template_guid     UUID  NOT NULL  FK -> contracts_artifact_templates
  ref_package_guid      UUID  NULL      FK -> service_modules_manifest (cascade)
  ref_type_guid         UUID  NOT NULL  FK -> contracts_primitives_types
  pub_name              STRING(128)     slot name as it appears in pub_body
  pub_ordinal           INT             order of substitution
  pub_is_required       BOOL
  pub_notes             STRING(512)  NULL
  priv_created_on, priv_modified_on
  UQ on (ref_template_guid, pub_name)
  UQ on (ref_template_guid, pub_ordinal)
```

Follows the same input/output model + fields shape used by
`contracts_db_operations_models` / `contracts_db_operations_models_fields`.
Intentional: same conceptual shape (a contract with named slots), so the
tables look alike.

## Substitution marker convention

Open question for implementation. Two candidates:

- `{{slot_name}}` — common, easy to scan visually, no SQL collision risk in
  practice (double-brace isn't valid SQL syntax)
- `${slot_name}` — also common, but `$` has meaning in some SQL dialects
  (Postgres dollar-quoting in particular)

Leaning `{{slot_name}}` for safety across engines.

## Composition

Templates compose: the SQL output for a full table includes a `CREATE TABLE`
block, a series of column DDLs (each a small sub-template), and a series of
constraint blocks. The current Python code does this assembly inline. The
data-driven version has nested templates: a `create_table_block` template
whose `column_lines` slot is filled by repeated application of a
`column_ddl` template, one per column row.

This means slot values can themselves be the result of running another
template. The dispatcher that walks the templates needs to handle that —
probably just by giving callers a way to render a template into a string,
and letting the caller pass the resulting string in as a slot value when
rendering the parent.

## Engine binding

Like `contracts_types_ddl_mapping` and `contracts_enums_ddl_mapping`, an
artifact template is engine-specific when the artifact format is
engine-specific. SQL DDL templates carry a `ref_engine_guid`. JSON output
templates don't (engine-agnostic, NULL). Same pattern.

## What stays in code

The Python that *walks* the data and applies the templates stays in code.
The data is the templates; the engine that applies them to row data is
logic, and logic legitimately lives in code. The line between "data" and
"code" is: if the same shape can be expressed declaratively as rows, it's
data. The control flow that consumes those rows is code.

## Relationship to operations

Operations and templates are categorically distinct and should not be
conflated:

- An **operation** is a query that runs against the database and returns
  rows. Has input/output models. Lives in `contracts_db_operations`.
- A **template** is text scaffolding that wraps query results to produce
  an output artifact. Has slots. Lives in `contracts_artifact_templates`.

They compose: `dump` runs operations to read schema rows, then walks
templates to wrap those rows into installable SQL. Separate tables,
separate dispatch, both data-driven.

## Out of scope for the next session

- Versioning of templates (a template's `pub_body` evolving over time —
  do we track previous versions? probably yes, but defer)
- Validation that all required slots are filled before render
- ContentForge / authoring UI integration
- Marketplace export format

## Migration plan when this is implemented

1. Add the two tables (schema migration, MERGE-based).
2. Author the kernel-package template rows for the existing hardcoded
   strings. Each Python literal in scriptlib that emits engine-specific
   text becomes one template row.
3. Update scriptlib's emitters to read the template row and apply it,
   replacing the inline literal. One emitter at a time, smallest first
   (e.g. start with the file-header template, work up to MERGE).
4. Round-trip the dump and confirm output is byte-for-byte identical.
5. Continue until no Python f-string in scriptlib produces engine-specific
   text.

After that the path is open to porting scriptlib to other engines purely
by authoring template rows for those engines.
