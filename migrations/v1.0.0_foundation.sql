-- =============================================================================
-- elideus-group-unity :: Foundation Schema — DDL
-- =============================================================================
-- v1.0.0_foundation.sql
--
-- Install order matches dependency order. No forward references.
--
-- Tables:
--   1. service_types                       (EDT — platform type system)
--   2. service_enums                       (enum values, magic number avoidance)
--   3. objects_schema_tables             (table definitions)
--   4. objects_schema_columns            (column definitions)
--   5. objects_schema_indexes            (index definitions)
--   6. objects_schema_index_columns      (index ↔ column junction)
--   7. objects_schema_constraints        (constraint definitions)
--   8. objects_schema_constraint_columns (constraint ↔ column junction)
--
-- Column prefix conventions:
--   key_*  — Primary key
--   pub_*  — Functional / public data
--   priv_* — Audit fields
--   ref_*  — Foreign key references
--   ext_*  — Extension package columns (future, added by modules)
--
-- Deterministic keys:
--   namespace: DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB  (env: NS_HASH)
--   formula:   uuid5(namespace, '{entity_type}:{natural_key}')
-- =============================================================================

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- =============================================================================
-- 1. service_types
-- =============================================================================
-- The platform type system. Every column in every table references a type
-- row that defines its representation across all supported database engines,
-- Python, TypeScript, JSON, and ODBC.
--
-- Identity columns are expressed through the type system (INT64_IDENTITY),
-- not through column flags or constraints.
--
-- Column-level pub_max_length overrides the type-level pub_default_length
-- when present. STRING type requires a column-level override (type has no
-- default length).
--
-- Deterministic key: uuid5(NS_HASH, "service_types:{pub_name}")

-- =============================================================================

CREATE TABLE [dbo].[service_types] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(64)      NOT NULL,
  [pub_mssql_type]        NVARCHAR(128)     NOT NULL,
  [pub_postgresql_type]   NVARCHAR(128)     NULL,
  [pub_mysql_type]        NVARCHAR(128)     NULL,
  [pub_python_type]       NVARCHAR(64)      NOT NULL,
  [pub_typescript_type]   NVARCHAR(64)      NOT NULL,
  [pub_json_type]         NVARCHAR(64)      NOT NULL,
  [pub_odbc_type_code]    SMALLINT          NOT NULL,
  [pub_default_length]    INT               NULL,
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_service_types] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_st_name] UNIQUE ([pub_name])
);
GO

-- =============================================================================
-- 2. service_enums
-- =============================================================================
-- Enumeration values for avoiding magic numbers throughout the platform.
-- Grouped by pub_enum_type, each value is a tinyint (0-255).
-- Modules lazy-load enumerations by type at runtime.
--
-- Deterministic key: uuid5(NS_HASH, "service_enums:{pub_enum_type}.{pub_name}")
-- =============================================================================

CREATE TABLE [dbo].[service_enums] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_enum_type]         NVARCHAR(128)     NOT NULL,
  [pub_name]              NVARCHAR(128)     NOT NULL,
  [pub_value]             TINYINT           NOT NULL,
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_service_enums] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_se_type_value] UNIQUE ([pub_enum_type], [pub_value]),
  CONSTRAINT [UQ_se_type_name] UNIQUE ([pub_enum_type], [pub_name])
);
GO

-- =============================================================================
-- 3. objects_schema_tables
-- =============================================================================
-- One row per table in the application schema.
--
-- Deterministic key: uuid5(NS_HASH, "objects_schema_tables:{pub_schema}.{pub_name}")
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_tables] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(128)     NOT NULL,
  [pub_schema]            NVARCHAR(64)      NOT NULL DEFAULT ('dbo'),
  [pub_alias]             NVARCHAR(16)      NOT NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_tables] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_ost_schema_name] UNIQUE ([pub_schema], [pub_name]),
  CONSTRAINT [UQ_ost_alias] UNIQUE ([pub_alias])
);
GO

-- =============================================================================
-- 4. objects_schema_columns
-- =============================================================================
-- One row per column. References the owning table and the type row that
-- defines its representation.
--
-- pub_default_value holds the default value expression for the column (e.g.,
-- 'SYSDATETIMEOFFSET()', 'Default String', '1.00'). This is a 
-- column attribute, not a constraint - the management module emits DEFAULT 
-- constraints from this value during DDL generation.
--
-- pub_is_nullable is the only behavioral flag on the column. Primary key
-- membership is expressed as a constraint row, not a column flag.
--
-- pub_max_length overrides the type's pub_default_length when present.
--
-- Deterministic key: uuid5(NS_HASH, "objects_schema_columns:{schema}.{table}.{column}")
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_columns] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_table_guid]        UNIQUEIDENTIFIER  NOT NULL,
  [ref_type_guid]         UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(128)     NOT NULL,
  [pub_ordinal]           INT               NOT NULL,
  [pub_is_nullable]       BIT               NOT NULL DEFAULT (0),
  [pub_default_value]     NVARCHAR(512)     NULL,
  [pub_max_length]        INT               NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_columns] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_osc_table] FOREIGN KEY ([ref_table_guid])
    REFERENCES [dbo].[objects_schema_tables] ([key_guid]),
  CONSTRAINT [FK_osc_type] FOREIGN KEY ([ref_type_guid])
    REFERENCES [dbo].[service_types] ([key_guid]),
  CONSTRAINT [UQ_osc_table_name] UNIQUE ([ref_table_guid], [pub_name]),
  CONSTRAINT [UQ_osc_table_ordinal] UNIQUE ([ref_table_guid], [pub_ordinal])
);
GO

CREATE INDEX [IX_osc_table_guid]
  ON [dbo].[objects_schema_columns] ([ref_table_guid]);
GO

CREATE INDEX [IX_osc_type_guid]
  ON [dbo].[objects_schema_columns] ([ref_type_guid]);
GO

-- =============================================================================
-- 5. objects_schema_indexes
-- =============================================================================
-- One row per index. Column membership and predicate ordering live in the
-- junction table objects_schema_index_columns.
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_indexes] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_table_guid]        UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(256)     NOT NULL,
  [pub_is_unique]         BIT               NOT NULL DEFAULT (0),
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_indexes] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_osi_table] FOREIGN KEY ([ref_table_guid])
    REFERENCES [dbo].[objects_schema_tables] ([key_guid]),
  CONSTRAINT [UQ_osi_table_name] UNIQUE ([ref_table_guid], [pub_name])
);
GO

CREATE INDEX [IX_osi_table_guid]
  ON [dbo].[objects_schema_indexes] ([ref_table_guid]);
GO

-- =============================================================================
-- 6. objects_schema_index_columns
-- =============================================================================
-- Junction table linking indexes to their constituent columns with ordering.
-- pub_ordinal controls predicate ordering in CREATE INDEX.
--
-- NOTE: Predicate ordering is sensitive to query plan matching. Extension
-- columns (future) that append to an existing index must not reorder
-- existing predicates. Ordinal override logic may be needed when extension
-- packages are implemented.
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_index_columns] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_index_guid]        UNIQUEIDENTIFIER  NOT NULL,
  [ref_column_guid]       UNIQUEIDENTIFIER  NOT NULL,
  [pub_ordinal]           INT               NOT NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_index_columns] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_osic_index] FOREIGN KEY ([ref_index_guid])
    REFERENCES [dbo].[objects_schema_indexes] ([key_guid]),
  CONSTRAINT [FK_osic_column] FOREIGN KEY ([ref_column_guid])
    REFERENCES [dbo].[objects_schema_columns] ([key_guid]),
  CONSTRAINT [UQ_osic_index_ordinal] UNIQUE ([ref_index_guid], [pub_ordinal]),
  CONSTRAINT [UQ_osic_index_column] UNIQUE ([ref_index_guid], [ref_column_guid])
);
GO

CREATE INDEX [IX_osic_index_guid]
  ON [dbo].[objects_schema_index_columns] ([ref_index_guid]);
GO

-- =============================================================================
-- 7. objects_schema_constraints
-- =============================================================================
-- One row per constraint. ref_kind_enum_guid references service_enums
-- (enum_type = 'constraint_kind'). Supported kinds:
--
--   PRIMARY_KEY (0) — one per table, columns via junction
--   FOREIGN_KEY (1) — source and target columns via junction
--   UNIQUE      (2) — columns via junction
--   CHECK       (3) — pub_expression holds the predicate
--
-- DEFAULT is NOT a constraint — it lives on the column as pub_default.
-- IDENTITY is NOT a constraint — it is encoded in the type reference
-- (INT64_IDENTITY).
--
-- For FOREIGN_KEY constraints, ref_referenced_table_guid points to the
-- target table. The specific column mappings (source → target) are in
-- the constraint_columns junction table.
--
-- For CHECK constraints, pub_expression holds the SQL predicate text.
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_constraints] (
  [key_guid]                    UNIQUEIDENTIFIER  NOT NULL,
  [ref_table_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_kind_enum_guid]          UNIQUEIDENTIFIER  NOT NULL,
  [ref_referenced_table_guid]   UNIQUEIDENTIFIER  NULL,
  [pub_name]                    NVARCHAR(256)     NOT NULL,
  [pub_expression]              NVARCHAR(MAX)     NULL,
  [priv_created_on]             DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]            DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_constraints] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_osco_table] FOREIGN KEY ([ref_table_guid])
    REFERENCES [dbo].[objects_schema_tables] ([key_guid]),
  CONSTRAINT [FK_osco_kind] FOREIGN KEY ([ref_kind_enum_guid])
    REFERENCES [dbo].[service_enums] ([key_guid]),
  CONSTRAINT [FK_osco_ref_table] FOREIGN KEY ([ref_referenced_table_guid])
    REFERENCES [dbo].[objects_schema_tables] ([key_guid]),
  CONSTRAINT [UQ_osco_table_name] UNIQUE ([ref_table_guid], [pub_name])
);
GO

CREATE INDEX [IX_osco_table_guid]
  ON [dbo].[objects_schema_constraints] ([ref_table_guid]);
GO

CREATE INDEX [IX_osco_kind]
  ON [dbo].[objects_schema_constraints] ([ref_kind_enum_guid]);
GO

-- =============================================================================
-- 8. objects_schema_constraint_columns
-- =============================================================================
-- Junction table linking constraints to their constituent columns.
--
-- For PRIMARY_KEY / UNIQUE: one row per column in the constraint.
--   pub_ordinal controls column ordering.
--   ref_referenced_column_guid is NULL.
--
-- For FOREIGN_KEY: one row per column mapping.
--   ref_column_guid is the source (local) column.
--   ref_referenced_column_guid is the target (remote) column.
--   pub_ordinal controls ordering for composite FKs.
--
-- For CHECK: typically no rows (expression is on the constraint itself).
--   Optionally one row per column the check references, for dependency
--   tracking during schema changes.
-- =============================================================================

CREATE TABLE [dbo].[objects_schema_constraint_columns] (
  [key_guid]                    UNIQUEIDENTIFIER  NOT NULL,
  [ref_constraint_guid]         UNIQUEIDENTIFIER  NOT NULL,
  [ref_column_guid]             UNIQUEIDENTIFIER  NOT NULL,
  [ref_referenced_column_guid]  UNIQUEIDENTIFIER  NULL,
  [pub_ordinal]                 INT               NOT NULL,
  [priv_created_on]             DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]             DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_objects_schema_constraint_columns] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_oscc_constraint] FOREIGN KEY ([ref_constraint_guid])
    REFERENCES [dbo].[objects_schema_constraints] ([key_guid]),
  CONSTRAINT [FK_oscc_column] FOREIGN KEY ([ref_column_guid])
    REFERENCES [dbo].[objects_schema_columns] ([key_guid]),
  CONSTRAINT [FK_oscc_ref_column] FOREIGN KEY ([ref_referenced_column_guid])
    REFERENCES [dbo].[objects_schema_columns] ([key_guid]),
  CONSTRAINT [UQ_oscc_constraint_ordinal] UNIQUE ([ref_constraint_guid], [pub_ordinal]),
  CONSTRAINT [UQ_oscc_constraint_column] UNIQUE ([ref_constraint_guid], [ref_column_guid])
);
GO

CREATE INDEX [IX_oscc_constraint_guid]
  ON [dbo].[objects_schema_constraint_columns] ([ref_constraint_guid]);
GO

-- =============================================================================
-- 9. system_configuration
-- =============================================================================
-- Key/value configuration store. Feeds the SystemConfigurationModule.
-- Modules register their required config keys during initialization;
-- values are set by operators or by module seed data.
--
-- Deterministic key: uuid5(NS_HASH, "system_configuration:{pub_key}")
-- =============================================================================

CREATE TABLE [dbo].[system_configuration] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_key]               NVARCHAR(256)     NOT NULL,
  [pub_value]             NVARCHAR(MAX)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_system_configuration] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_sc_key] UNIQUE ([pub_key])
);
GO

-- =============================================================================
-- 10. service_modules_manifest
-- =============================================================================
-- Module install completion registry. One row per module that has
-- successfully completed its installation seed during on_seal().
--
-- Installation is idempotent. Modules re-run their seed scripts on every
-- boot until the seed completes cleanly and this row is written with
-- pub_is_sealed = 1. Failed installs leave no trace; the module retries
-- from scratch on next boot.
--
-- pub_version is the module-declared semver. On version bump the module
-- writes its previous version to pub_last_version and the new version
-- to pub_version, enabling multi-version jump tracking.
--
-- pub_is_sealed is the completion gate. Default 0 so a mid-install crash
-- (row inserted, seed fails before flip) still leaves a retry-eligible
-- state. Boot check: row exists AND pub_is_sealed = 1 AND pub_version
-- matches → skip install.
--
-- Deterministic key: uuid5(NS_HASH, "service_modules_manifest:{pub_name}")
-- =============================================================================

CREATE TABLE [dbo].[service_modules_manifest] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(256)     NOT NULL,
  [pub_version]           NVARCHAR(64)      NOT NULL,
  [pub_last_version]      NVARCHAR(64)      NULL,
  [pub_is_sealed]         BIT               NOT NULL DEFAULT (0),
  [priv_installed_on]     DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_service_modules_manifest] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_smm_name] UNIQUE ([pub_name])
);
GO


-- =============================================================================
-- 11. service_database_operations
-- =============================================================================
-- Named database operations registered for dispatch through the
-- DatabaseOperationsModule. Callers submit a DBRequest(op, params);
-- the module resolves the op name to a deterministic GUID, looks up
-- the per-provider SQL text, and dispatches through DatabaseExecutionModule.
--
-- One row per named op. Each row carries the SQL variant for every
-- supported provider — any individual variant may be NULL if the op
-- is not yet implemented for that provider. The active provider is
-- chosen at startup by SQL_PROVIDER and fixes which column the module
-- reads from for the lifetime of the process.
--
-- pub_bootstrap = 1 marks ops that preload into the module's cache at
-- startup (hot path, small set). All other ops lazy-load on first use
-- via PK seek on key_guid.
--
-- Deterministic key: uuid5(NS_HASH, "service_database_operations:{pub_op}")
-- =============================================================================

CREATE TABLE [dbo].[service_database_operations] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_op]                NVARCHAR(128)     NOT NULL,
  [pub_query_mssql]       NVARCHAR(MAX)     NULL,
  [pub_query_postgres]    NVARCHAR(MAX)     NULL,
  [pub_query_mysql]       NVARCHAR(MAX)     NULL,
  [pub_bootstrap]         BIT               NOT NULL DEFAULT (0),
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_service_database_operations] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_sdo_op] UNIQUE ([pub_op])
);
GO
