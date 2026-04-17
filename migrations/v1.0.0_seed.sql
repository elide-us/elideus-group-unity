-- =============================================================================
-- elideus-group-unity :: Foundation Schema — Seed Data
-- =============================================================================
-- v1.0.0_seed.sql
--
-- Seed data for:
--   1. system_objects_types  (19 platform types)
--   2. system_objects_enums  (constraint_kind: 4 values)
--
-- All GUIDs are deterministic UUID5 from:
--   namespace: DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB
--   types:     uuid5(NS_HASH, "type:{pub_name}")
--   enums:     uuid5(NS_HASH, "enum:{pub_enum_type}:{pub_name}")
--
-- MSSQL type strings are UPPERCASE to match SSMS conventions and ensure
-- consistent casing in generated DDL. Postgres types are lowercase per
-- their convention. MySQL types are lowercase per convention.
-- =============================================================================

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- =============================================================================
-- 1. Platform Types (19 rows)
-- =============================================================================

INSERT INTO [dbo].[system_objects_types]
  ([key_guid], [pub_name], [pub_mssql_type], [pub_postgresql_type], [pub_mysql_type],
   [pub_python_type], [pub_typescript_type], [pub_json_type],
   [pub_odbc_type_code], [pub_default_length], [pub_notes])
VALUES

  -- ── Boolean ────────────────────────────────────────────────────────────────

  ('6864F659-8032-5F1E-92D9-609420184802', 'BOOL',
   'BIT', 'boolean', 'tinyint(1)',
   'bool', 'boolean', 'boolean',
   -7, 1,
   'Boolean flag.'),

  -- ── Integer types ──────────────────────────────────────────────────────────

  ('6A3122BA-DCBD-533E-B522-B6290AB84DFA', 'INT8',
   'TINYINT', 'smallint', 'tinyint unsigned',
   'int', 'number', 'integer',
   -6, 1,
   '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),

  ('4245E3A0-2828-53AB-A0AE-47DED6EBC019', 'INT16',
   'SMALLINT', 'smallint', 'smallint',
   'int', 'number', 'integer',
   5, 2,
   '16-bit signed integer (-32768 to 32767).'),

  ('E6F8C8D8-B864-567D-9470-83F800EE6E03', 'INT32',
   'INT', 'integer', 'int',
   'int', 'number', 'integer',
   4, 4,
   '32-bit signed integer.'),

  ('27E7D400-13AC-5CDB-8E1E-E7D4D1D93AFD', 'INT64',
   'BIGINT', 'bigint', 'bigint',
   'int', 'number', 'integer',
   -5, 8,
   '64-bit signed integer.'),

  ('2A7BC471-E212-5BDA-93B3-16C3AF0D592C', 'INT64_IDENTITY',
   'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment',
   'int', 'number', 'integer',
   -5, 8,
   'Auto-incrementing 64-bit integer. Used for key_id columns. Identity is intrinsic to the type.'),

  -- ── Floating point (IEEE 754) ──────────────────────────────────────────────

  ('A2D65D45-7578-59A1-938B-081111A546AB', 'FLOAT32',
   'REAL', 'real', 'float',
   'float', 'number', 'number',
   7, 4,
   '32-bit IEEE 754 floating point. Sensor data, approximate values.'),

  ('497BC2DC-A324-531F-AF35-94A912D4EB9C', 'FLOAT64',
   'FLOAT', 'double precision', 'double',
   'float', 'number', 'number',
   6, 8,
   '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),

  -- ── Fixed-precision decimals ───────────────────────────────────────────────

  ('5A1D1D8A-0488-5D99-8EA8-A1855830B014', 'DECIMAL_19_5',
   'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)',
   'float', 'number', 'number',
   3, NULL,
   'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),

  ('CCFEB061-F0CE-52CB-8A57-4FCACB7D11D0', 'DECIMAL_28_12',
   'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)',
   'float', 'number', 'number',
   3, NULL,
   'High-precision decimal (28,12). Staging tables, pre-quantization, intermediate calculations.'),

  ('E6DD1A9C-A8DD-5865-8B06-76233AF00571', 'DECIMAL_38_18',
   'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)',
   'float', 'number', 'number',
   3, NULL,
   'Maximum-precision decimal (38,18). Scientific computation, unit conversions, full-precision intermediates.'),

  -- ── String types ───────────────────────────────────────────────────────────

  ('4AF8304B-1008-5CAB-BBF0-9C6F024A8491', 'STRING',
   'NVARCHAR', 'varchar', 'varchar',
   'str', 'string', 'string',
   -9, NULL,
   'Variable-length Unicode string. Column-level pub_max_length required.'),

  ('CE95137C-CD9E-5021-900D-2F23B8A01DDB', 'TEXT',
   'NVARCHAR(MAX)', 'text', 'longtext',
   'str', 'string', 'string',
   -10, NULL,
   'Unlimited-length Unicode text.'),

  -- ── Identifiers ────────────────────────────────────────────────────────────

  ('4C81F8D6-3CBA-58A7-AA1B-4900EAA31CB3', 'UUID',
   'UNIQUEIDENTIFIER', 'uuid', 'char(36)',
   'str', 'string', 'string',
   -11, 16,
   '128-bit UUID / GUID.'),

  -- ── Date and time ──────────────────────────────────────────────────────────

  ('A0D695B6-2111-5101-AEE1-1317F4BF1B0B', 'DATE',
   'DATE', 'date', 'date',
   'str', 'string', 'string',
   91, 3,
   'Date without time component.'),

  ('26075637-87DB-576A-9339-1CEEA0D40022', 'DATETIME_TZ',
   'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)',
   'str', 'string', 'string',
   -155, NULL,
   'Timestamp with timezone offset. Platform standard for all timestamps.'),

  -- ── Binary ─────────────────────────────────────────────────────────────────

  ('2216342E-169D-56D2-A591-93C296B83C74', 'BINARY',
   'VARBINARY(MAX)', 'bytea', 'longblob',
   'bytes', 'Uint8Array', 'string',
   -4, NULL,
   'Variable-length binary data.'),

  -- ── Structured ─────────────────────────────────────────────────────────────

  ('EA09C252-BF9D-58CD-B31F-FDC8CECBB8B1', 'JSON_DOC',
   'NVARCHAR(MAX)', 'jsonb', 'json',
   'dict', 'object', 'object',
   -10, NULL,
   'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),

  -- ── Vector ─────────────────────────────────────────────────────────────────

  ('1C632121-A9F1-5266-8F11-B6CE39204441', 'VECTOR',
   'VECTOR', 'vector', 'vector',
   'list[float]', 'number[]', 'array',
   -10, NULL,
   'Vector embedding for similarity search. Dimension count specified per column via pub_max_length. MSSQL and Azure SQL native (GA). Postgres via pgvector. MySQL 9.0+ native.');
GO

-- =============================================================================
-- 2. Enumerations — constraint_kind (4 values)
-- =============================================================================
-- Key formula: uuid5(NS_HASH, "enum:constraint_kind:{pub_name}")
--
-- Used by system_objects_database_constraints.ref_kind_enum_guid.
--
-- DEFAULT is not a constraint kind — it is a column attribute (pub_default_value).
-- IDENTITY is not a constraint kind — it is encoded in the type reference.
-- =============================================================================

INSERT INTO [dbo].[system_objects_enums]
  ([key_guid], [pub_enum_type], [pub_name], [pub_value], [pub_notes])
VALUES
  ('404DB2A0-9BF0-5220-ACAA-C9F4E6A7A21F', 'constraint_kind', 'PRIMARY_KEY', 0,
   'Primary key constraint. One per table. Columns via constraint_columns junction.'),

  ('D606B21A-BFDA-5293-88AC-A058626D1AB3', 'constraint_kind', 'FOREIGN_KEY', 1,
   'Foreign key constraint. Source and target columns via constraint_columns junction.'),

  ('6E2AC86B-B5D3-51B5-83EB-ACB1D180BB1F', 'constraint_kind', 'UNIQUE',      2,
   'Unique constraint. Columns via constraint_columns junction.'),

  ('A200A3F3-0DA7-53D0-B9E6-FBBA4F35337B', 'constraint_kind', 'CHECK',       3,
   'Check constraint. pub_expression on the constraint row holds the predicate.');
GO

-- =============================================================================
-- 3. Reflection: system_configuration table definition
-- =============================================================================
-- Table, columns, and constraints for system_configuration registered in
-- the schema definition tables. This is bootstrap exception seeding —
-- normally the management engine handles this.
-- =============================================================================

-- Table row
INSERT INTO [dbo].[system_objects_database_tables]
  ([key_guid], [pub_name], [pub_schema])
VALUES
  ('F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0', 'system_configuration', 'dbo');
GO

-- Column rows
INSERT INTO [dbo].[system_objects_database_columns]
  ([key_guid], [ref_table_guid], [ref_type_guid],
   [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length])
VALUES
  ('8625AC28-4712-5F1D-B583-C2DDEB2343F1',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '4C81F8D6-3CBA-58A7-AA1B-4900EAA31CB3',  -- UUID
   'key_guid', 1, 0, NULL, NULL),

  ('5C4053C2-BF46-57CD-9364-116BC4F17A80',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '4AF8304B-1008-5CAB-BBF0-9C6F024A8491',  -- STRING
   'pub_key', 2, 0, NULL, 256),

  ('0C3C8FDC-D928-51C4-B5B8-0E825411174A',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   'CE95137C-CD9E-5021-900D-2F23B8A01DDB',  -- TEXT
   'pub_value', 3, 1, NULL, NULL),

  ('6C696AA0-7AD7-5601-9367-8181C77BC0F8',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '26075637-87DB-576A-9339-1CEEA0D40022',  -- DATETIME_TZ
   'priv_created_on', 4, 0, 'SYSDATETIMEOFFSET()', NULL),

  ('38989CB1-8436-586E-BD9A-47CFBB8AFE0F',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '26075637-87DB-576A-9339-1CEEA0D40022',  -- DATETIME_TZ
   'priv_modified_on', 5, 0, 'SYSDATETIMEOFFSET()', NULL);
GO

-- Constraint rows
INSERT INTO [dbo].[system_objects_database_constraints]
  ([key_guid], [ref_table_guid], [ref_kind_enum_guid],
   [ref_referenced_table_guid], [pub_name], [pub_expression])
VALUES
  -- PRIMARY KEY on key_guid
  ('EB6729AD-6DA0-5609-BA44-5F8CABB87C86',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '404DB2A0-9BF0-5220-ACAA-C9F4E6A7A21F',  -- PRIMARY_KEY
   NULL, 'PK_system_configuration', NULL),

  -- UNIQUE on pub_key
  ('D5A58171-4A94-5444-B42D-027CBAA441F6',
   'F9178DB7-B26B-5FA5-B3C6-F6FAAAD9ABF0',  -- system_configuration
   '6E2AC86B-B5D3-51B5-83EB-ACB1D180BB1F',  -- UNIQUE
   NULL, 'UQ_sc_key', NULL);
GO

-- Constraint column rows
INSERT INTO [dbo].[system_objects_database_constraint_columns]
  ([ref_constraint_guid], [ref_column_guid],
   [ref_referenced_column_guid], [pub_ordinal])
VALUES
  -- PK → key_guid
  ('EB6729AD-6DA0-5609-BA44-5F8CABB87C86',  -- PK_system_configuration
   '8625AC28-4712-5F1D-B583-C2DDEB2343F1',  -- key_guid column
   NULL, 1),

  -- UQ → pub_key
  ('D5A58171-4A94-5444-B42D-027CBAA441F6',  -- UQ_sc_key
   '5C4053C2-BF46-57CD-9364-116BC4F17A80',  -- pub_key column
   NULL, 1);
GO

-- =============================================================================
-- 4. Enumerations — task_status (5 values)
-- =============================================================================
-- Key formula: uuid5(NS_HASH, "enum:task_status:{pub_name}")
--
-- Used by service_tasks_ddl.ref_status_enum_guid (and future task tables:
-- service_tasks_scheduled, service_tasks_async).
-- =============================================================================

INSERT INTO [dbo].[system_objects_enums]
  ([key_guid], [pub_enum_type], [pub_name], [pub_value], [pub_notes])
VALUES
  ('E2C76297-83EF-5EE0-AAB6-BE9FF08A4944', 'task_status', 'PENDING',    0,
   'Declared, awaiting pickup by the consuming module.'),

  ('476F98F1-0FAE-5B4A-82AD-28F53984DE64', 'task_status', 'RUNNING',    1,
   'Picked up and actively executing.'),

  ('11455D5D-1736-5D11-8787-C2D819864A7C', 'task_status', 'COMPLETE',   2,
   'Executed successfully.'),

  ('E1DA6733-4B35-588D-9D2F-D96874834F56', 'task_status', 'FAILED',     3,
   'Execution failed. priv_error holds the failure detail.'),

  ('42366FE0-C77D-5BCF-A375-CED9F8CEB46B', 'task_status', 'CANCELLING', 4,
   'Cancellation requested. Consumer should abort and transition to failed or complete.');
GO

-- =============================================================================
-- 5. Enumerations — task_operation_ddl (5 values)
-- =============================================================================
-- Key formula: uuid5(NS_HASH, "enum:task_operation_ddl:{pub_name}")
--
-- Used by service_tasks_ddl.ref_operation_enum_guid. Operations align with
-- the BaseDatabaseManagementProvider DDL contract. Values are unordered;
-- new operations added later do not disturb existing values.
-- =============================================================================

INSERT INTO [dbo].[system_objects_enums]
  ([key_guid], [pub_enum_type], [pub_name], [pub_value], [pub_notes])
VALUES
  ('5D5B3828-3CDA-5B00-AE5C-3443BF820493', 'task_operation_ddl', 'CREATE_TABLE',    0,
   'Create a new table. pub_spec holds full table/column spec.'),

  ('01F79F67-FF0F-54E8-B4AD-B5C23BC79A33', 'task_operation_ddl', 'ALTER_COLUMN',    1,
   'Alter an existing column. pub_spec holds table + column spec.'),

  ('82568665-FA86-56EF-B841-0ADBDB6888D7', 'task_operation_ddl', 'CREATE_INDEX',    2,
   'Create a new index. pub_spec holds index spec + column membership.'),

  ('049B4B1B-BA45-5E81-8249-F2A766A4A16B', 'task_operation_ddl', 'DROP_CONSTRAINT', 3,
   'Drop a constraint by name. pub_spec holds table + constraint name.'),

  ('362067A6-D84B-58A3-A03A-885ABE8FA92B', 'task_operation_ddl', 'DROP_INDEX',      4,
   'Drop an index by name. pub_spec holds table + index name.');
GO

-- =============================================================================
-- 6. Enumerations — task_disposition (4 values)
-- =============================================================================
-- Key formula: uuid5(NS_HASH, "enum:task_disposition:{pub_name}")
--
-- Used by service_tasks_ddl.ref_disposition_enum_guid (and future task
-- tables). Disposition describes the reversal semantics of the task —
-- informs the healable workflow system's rollback and cancellation logic.
-- =============================================================================

INSERT INTO [dbo].[system_objects_enums]
  ([key_guid], [pub_enum_type], [pub_name], [pub_value], [pub_notes])
VALUES
  ('956C0D2A-04CE-5A93-9655-C663514C5EB9', 'task_disposition', 'REVERSIBLE',   0,
   'Task effect can be undone via a compensating task (e.g., create_index → drop_index).'),

  ('E6E806CE-E92C-5F52-9DC2-3C290B1E4E49', 'task_disposition', 'IRREVERSIBLE', 1,
   'Task effect cannot be undone through the system (e.g., drop_table). Requires external recovery.'),

  ('90FA6362-D66D-5F8C-9E16-C881C996785B', 'task_disposition', 'TRANSIENT',    2,
   'Task has no persistent effect; safe to discard mid-execution.'),

  ('7156DA58-D2F8-506E-BAC6-66B045D5316C', 'task_disposition', 'CANCELLABLE',  3,
   'Task may be cancelled before or during execution without a compensating task.');
GO