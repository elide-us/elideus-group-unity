-- =============================================================================
-- elideus-group-unity :: Foundation Schema — Seed Data
-- =============================================================================
-- v1.0.0_seed.sql
--
-- Seed data for:
--   1. service_types  (19 platform types)
--   2. service_enums  (constraint_kind: 4 values)
--
-- All GUIDs are deterministic UUID5 from:
--   namespace: DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB
--   types:     uuid5(NS_HASH, "service_types:{pub_name}")
--   enums:     uuid5(NS_HASH, "service_enums:{pub_enum_type}.{pub_name}")
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

INSERT INTO [dbo].[service_types]
  ([key_guid], [pub_name], [pub_mssql_type], [pub_postgresql_type], [pub_mysql_type],
   [pub_python_type], [pub_typescript_type], [pub_json_type],
   [pub_odbc_type_code], [pub_default_length], [pub_notes])
VALUES

  -- ── Boolean ────────────────────────────────────────────────────────────────

  ('72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'BOOL',
   'BIT', 'boolean', 'tinyint(1)',
   'bool', 'boolean', 'boolean',
   -7, 1,
   'Boolean flag.'),

  -- ── Integer types ──────────────────────────────────────────────────────────

  ('0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'INT8',
   'TINYINT', 'smallint', 'tinyint unsigned',
   'int', 'number', 'integer',
   -6, 1,
   '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),

  ('18667606-C633-5A82-9A3B-2CD27916FC95', 'INT16',
   'SMALLINT', 'smallint', 'smallint',
   'int', 'number', 'integer',
   5, 2,
   '16-bit signed integer (-32768 to 32767).'),

  ('1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'INT32',
   'INT', 'integer', 'int',
   'int', 'number', 'integer',
   4, 4,
   '32-bit signed integer.'),

  ('B96336CD-D4A0-5B24-920E-C818BDC4AE7A', 'INT64',
   'BIGINT', 'bigint', 'bigint',
   'int', 'number', 'integer',
   -5, 8,
   '64-bit signed integer.'),

  ('2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', 'INT64_IDENTITY',
   'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment',
   'int', 'number', 'integer',
   -5, 8,
   'Auto-incrementing 64-bit integer. Used for key_id columns. Identity is intrinsic to the type.'),

  -- ── Floating point (IEEE 754) ──────────────────────────────────────────────

  ('BD61A7EA-38ED-57AC-949F-5C82A0C0173E', 'FLOAT32',
   'REAL', 'real', 'float',
   'float', 'number', 'number',
   7, 4,
   '32-bit IEEE 754 floating point. Sensor data, approximate values.'),

  ('421D6C05-ACBA-58E7-9FE3-27F500497011', 'FLOAT64',
   'FLOAT', 'double precision', 'double',
   'float', 'number', 'number',
   6, 8,
   '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),

  -- ── Fixed-precision decimals ───────────────────────────────────────────────

  ('4DB81F9F-8990-5952-BBEA-4E175B362CDA', 'DECIMAL_19_5',
   'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)',
   'float', 'number', 'number',
   3, NULL,
   'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),

  ('085132BC-DDEB-5591-ACB0-7348445DC92C', 'DECIMAL_28_12',
   'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)',
   'float', 'number', 'number',
   3, NULL,
   'High-precision decimal (28,12). Staging tables, pre-quantization, intermediate calculations.'),

  ('53434CAA-A382-5B45-BAD2-AC3F655ED3A0', 'DECIMAL_38_18',
   'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)',
   'float', 'number', 'number',
   3, NULL,
   'Maximum-precision decimal (38,18). Scientific computation, unit conversions, full-precision intermediates.'),

  -- ── String types ───────────────────────────────────────────────────────────

  ('8579BB4B-746B-5E4B-867B-BFB182D52110', 'STRING',
   'NVARCHAR', 'varchar', 'varchar',
   'str', 'string', 'string',
   -9, NULL,
   'Variable-length Unicode string. Column-level pub_max_length required.'),

  ('8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', 'TEXT',
   'NVARCHAR(MAX)', 'text', 'longtext',
   'str', 'string', 'string',
   -10, NULL,
   'Unlimited-length Unicode text.'),

  -- ── Identifiers ────────────────────────────────────────────────────────────

  ('DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'UUID',
   'UNIQUEIDENTIFIER', 'uuid', 'char(36)',
   'str', 'string', 'string',
   -11, 16,
   '128-bit UUID / GUID.'),

  -- ── Date and time ──────────────────────────────────────────────────────────

  ('CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', 'DATE',
   'DATE', 'date', 'date',
   'str', 'string', 'string',
   91, 3,
   'Date without time component.'),

  ('0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'DATETIME_TZ',
   'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)',
   'str', 'string', 'string',
   -155, NULL,
   'Timestamp with timezone offset. Platform standard for all timestamps.'),

  -- ── Binary ─────────────────────────────────────────────────────────────────

  ('4B286A51-7A0B-5BA2-8391-264E572C8375', 'BINARY',
   'VARBINARY(MAX)', 'bytea', 'longblob',
   'bytes', 'Uint8Array', 'string',
   -4, NULL,
   'Variable-length binary data.'),

  -- ── Structured ─────────────────────────────────────────────────────────────

  ('EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', 'JSON_DOC',
   'NVARCHAR(MAX)', 'jsonb', 'json',
   'dict', 'object', 'object',
   -10, NULL,
   'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),

  -- ── Vector ─────────────────────────────────────────────────────────────────

  ('F4CF3C0D-908E-5682-8FE7-F9973B90C56A', 'VECTOR',
   'VECTOR', 'vector', 'vector',
   'list[float]', 'number[]', 'array',
   -10, NULL,
   'Vector embedding for similarity search. Dimension count specified per column via pub_max_length. MSSQL and Azure SQL native (GA). Postgres via pgvector. MySQL 9.0+ native.');
GO

-- =============================================================================
-- 2. Enumerations — constraint_kind (4 values)
-- =============================================================================
-- Key formula: uuid5(NS_HASH, "service_enums:constraint_kind.{pub_name}")
--
-- Used by objects_schema_constraints.ref_kind_enum_guid.
--
-- DEFAULT is not a constraint kind — it is a column attribute (pub_default_value).
-- IDENTITY is not a constraint kind — it is encoded in the type reference.
-- =============================================================================

INSERT INTO [dbo].[service_enums]
  ([key_guid], [pub_enum_type], [pub_name], [pub_value], [pub_notes])
VALUES
  ('3426C194-B912-5F71-802F-566E2FF1E8FF', 'constraint_kind', 'PRIMARY_KEY', 0,
   'Primary key constraint. One per table. Columns via constraint_columns junction.'),

  ('B6ABA725-1FDB-5454-B164-DDBE11079598', 'constraint_kind', 'FOREIGN_KEY', 1,
   'Foreign key constraint. Source and target columns via constraint_columns junction.'),

  ('4D75333D-E472-5813-A03B-C0162671A00D', 'constraint_kind', 'UNIQUE',      2,
   'Unique constraint. Columns via constraint_columns junction.'),

  ('92400F11-FCFD-5285-B9E2-D682B2496A88', 'constraint_kind', 'CHECK',       3,
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
INSERT INTO [dbo].[objects_schema_tables]
  ([key_guid], [pub_name], [pub_schema], [pub_alias])
VALUES
  ('8DBC35E3-21FF-5AB7-B583-BA4A55DD4606', 'system_configuration', 'dbo', 'sc');
GO

-- Column rows
INSERT INTO [dbo].[objects_schema_columns]
  ([key_guid], [ref_table_guid], [ref_type_guid],
   [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length])
VALUES
  ('1698374C-DCB1-531F-A044-FEDCFC94DF79',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',  -- UUID
   'key_guid', 1, 0, NULL, NULL),

  ('35C0F932-9432-5A29-B158-00277EB56A2E',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '8579BB4B-746B-5E4B-867B-BFB182D52110',  -- STRING
   'pub_key', 2, 0, NULL, 256),

  ('CB53ABC4-4ED8-5C72-BE07-C5D4287B947A',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',  -- TEXT
   'pub_value', 3, 1, NULL, NULL),

  ('C341248F-7BE1-5BAE-972D-047688B098D5',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '0A301083-D3E1-5119-9ADB-09B47A1E00FA',  -- DATETIME_TZ
   'priv_created_on', 4, 0, 'SYSDATETIMEOFFSET()', NULL),

  ('6CF18E0E-5D1D-5301-9488-6FAEA5B021B1',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '0A301083-D3E1-5119-9ADB-09B47A1E00FA',  -- DATETIME_TZ
   'priv_modified_on', 5, 0, 'SYSDATETIMEOFFSET()', NULL);
GO

-- Constraint rows
INSERT INTO [dbo].[objects_schema_constraints]
  ([key_guid], [ref_table_guid], [ref_kind_enum_guid],
   [ref_referenced_table_guid], [pub_name], [pub_expression])
VALUES
  -- PRIMARY KEY on key_guid
  ('A39ED416-B8EE-5847-A10A-49DB5FA2BACF',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '3426C194-B912-5F71-802F-566E2FF1E8FF',  -- PRIMARY_KEY
   NULL, 'PK_system_configuration', NULL),

  -- UNIQUE on pub_key
  ('647B3E57-7C9B-52D9-9BAC-74B7E36D8C1C',
   '8DBC35E3-21FF-5AB7-B583-BA4A55DD4606',  -- system_configuration
   '4D75333D-E472-5813-A03B-C0162671A00D',  -- UNIQUE
   NULL, 'UQ_sc_key', NULL);
GO

-- Constraint column rows
INSERT INTO [dbo].[objects_schema_constraint_columns]
  ([key_guid], [ref_constraint_guid], [ref_column_guid],
   [ref_referenced_column_guid], [pub_ordinal])
VALUES
  -- PK → key_guid
  ('0F85631E-25CA-50B0-986A-F4FF75759245',
   'A39ED416-B8EE-5847-A10A-49DB5FA2BACF',  -- PK_system_configuration
   '1698374C-DCB1-531F-A044-FEDCFC94DF79',  -- key_guid column
   NULL, 1),

  -- UQ → pub_key
  ('0EEB38C5-604D-51D6-A753-3C1BDE394422',
   '647B3E57-7C9B-52D9-9BAC-74B7E36D8C1C',  -- UQ_sc_key
   '35C0F932-9432-5A29-B158-00277EB56A2E',  -- pub_key column
   NULL, 1);
GO

