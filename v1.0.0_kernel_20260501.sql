-- Generated 2026-06-07 00:09:09 UTC
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Kernel Root (etg schema): Type Mappings
-- =====================================================================
CREATE TABLE [etg].[contracts_primitives_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_mssql_sys_type] NVARCHAR(64) NULL,
  [pub_odbc_type_code] SMALLINT NOT NULL,
  [pub_default_length] INT NULL,
  [pub_emits_length] BIT DEFAULT (0) NOT NULL,
  [pub_mssql_type] NVARCHAR(128) NOT NULL,
  [pub_postgresql_type] NVARCHAR(128) NULL,
  [pub_mysql_type] NVARCHAR(128) NULL,
  [pub_python_type] NVARCHAR(64) NOT NULL,
  [pub_typescript_type] NVARCHAR(64) NOT NULL,
  [pub_json_type] NVARCHAR(64) NOT NULL,
  [pub_rust_type] NVARCHAR(64) NOT NULL,
  [pub_lua_type] NVARCHAR(64) NOT NULL,
  [pub_c_type] NVARCHAR(64) NOT NULL,
  [pub_cpp_stl_type] NVARCHAR(64) NOT NULL,
  [pub_cpp_win32_type] NVARCHAR(64) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [PK_contracts_primitives_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [UQ_cpt_name] UNIQUE ([pub_name]);
INSERT INTO [etg].[contracts_primitives_types]
  (key_guid, pub_name, pub_mssql_sys_type, pub_odbc_type_code, pub_default_length, pub_emits_length, pub_mssql_type, pub_postgresql_type, pub_mysql_type, pub_python_type, pub_typescript_type, pub_json_type, pub_rust_type, pub_lua_type, pub_c_type, pub_cpp_stl_type, pub_cpp_win32_type, pub_notes)
VALUES
  ('0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'INT8', 'tinyint', -6, 1, 0, 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', 'u8', 'number', 'uint8_t', 'uint8_t', 'BYTE', '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),
  ('0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'DATETIME_TZ', 'datetimeoffset', -155, NULL, 0, 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Timestamp with timezone offset. Platform standard for all timestamps.'),
  ('4B286A51-7A0B-5BA2-8391-264E572C8375', 'BINARY', NULL, -4, NULL, 0, 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', 'Vec<u8>', 'buffer', 'uint8_t*', 'std::vector<uint8_t>', 'LPBYTE', 'Variable-length binary data.'),
  ('421D6C05-ACBA-58E7-9FE3-27F500497011', 'FLOAT64', 'float', 6, 8, 0, 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),
  ('18667606-C633-5A82-9A3B-2CD27916FC95', 'INT16', 'smallint', 5, 2, 0, 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 'i16', 'number', 'int16_t', 'int16_t', 'SHORT', '16-bit signed integer (-32768 to 32767).'),
  ('4DB81F9F-8990-5952-BBEA-4E175B362CDA', 'DECIMAL_19_5', NULL, 3, NULL, 0, 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),
  ('72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'BOOL', 'bit', -7, 1, 0, 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', 'bool', 'boolean', 'bool', 'bool', 'BOOL', 'Boolean flag.'),
  ('EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', 'JSON_DOC', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', 'serde_json::Value', 'table', 'wchar_t*', 'std::wstring', 'LPWSTR', 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),
  ('BD61A7EA-38ED-57AC-949F-5C82A0C0173E', 'FLOAT32', 'real', 7, 4, 0, 'REAL', 'real', 'float', 'float', 'number', 'number', 'f32', 'number', 'float', 'float', 'FLOAT', '32-bit IEEE 754 floating point. Sensor data, approximate values.'),
  ('085132BC-DDEB-5591-ACB0-7348445DC92C', 'DECIMAL_28_12', NULL, 3, NULL, 0, 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'High-precision decimal (28,12). Staging tables, pre-quantization.'),
  ('2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', 'INT64_IDENTITY', NULL, -5, 8, 0, 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.'),
  ('8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', 'TEXT', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Unlimited-length Unicode text.'),
  ('1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'INT32', 'int', 4, 4, 0, 'INT', 'integer', 'int', 'int', 'number', 'integer', 'i32', 'number', 'int32_t', 'int32_t', 'LONG', '32-bit signed integer.'),
  ('53434CAA-A382-5B45-BAD2-AC3F655ED3A0', 'DECIMAL_38_18', NULL, 3, NULL, 0, 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.'),
  ('8579BB4B-746B-5E4B-867B-BFB182D52110', 'STRING', 'nvarchar', -9, NULL, 1, 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Variable-length Unicode string. Column-level pub_max_length required.'),
  ('B96336CD-D4A0-5B24-920E-C818BDC4AE7A', 'INT64', 'bigint', -5, 8, 0, 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', '64-bit signed integer.'),
  ('CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', 'DATE', 'date', 91, 3, 0, 'DATE', 'date', 'date', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Date without time component.'),
  ('DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'UUID', 'uniqueidentifier', -11, 16, 0, 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', 'uuid::Uuid', 'string', 'uint8_t[16]', 'std::array<uint8_t,16>', 'GUID', '128-bit UUID / GUID.'),
  ('F4CF3C0D-908E-5682-8FE7-F9973B90C56A', 'VECTOR', 'vector', -10, NULL, 1, 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', 'Vec<f32>', '{number}', 'float*', 'std::vector<float>', 'FLOAT*', 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.');
GO
-- =====================================================================
-- Kernel schema (etg + dbo): foundational self-referencing section
-- ---------------------------------------------------------------------
-- Reserved package identity (deterministic UUID5, DECAFBAD namespace):
--   namespace   = DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB
--   seed scheme = '{table_name}:{pub_name}'   (colon-joined, no schema prefix)
--   kernel = UUID5(ns, 'service_packages_manifest:kernel') = 7E203E54-5538-5C0F-B6E5-D276DCD04C36
--   core   = UUID5(ns, 'service_packages_manifest:core')   = F1954052-001D-5818-90DC-1953ADA7ABA1
-- The REPL must derive these from the same seed strings.
--
-- NOTE: Every ref_package_guid resolves to a manifest key_guid.
-- Manifest is the one table with no ref_package_guid (the root can't
-- belong to a package).
-- =====================================================================

-- =====================================================================
-- Kernel section 1 (etg schema): Contracts tables
-- =====================================================================
CREATE TABLE [etg].[contracts_db_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_exclude_element] BIT DEFAULT (0) NOT NULL
);
CREATE TABLE [etg].[contracts_db_constraint_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_constraint_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_column_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_constraints] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_table_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_expression] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_delete_disposition] TINYINT NULL
);
CREATE TABLE [etg].[contracts_db_index_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_index_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_descending] BIT DEFAULT (0) NOT NULL,
  [pub_is_included] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_indexes] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_is_unique] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_operations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_op] NVARCHAR(128) NOT NULL,
  [pub_query_mssql] NVARCHAR(MAX) NULL,
  [pub_query_postgres] NVARCHAR(MAX) NULL,
  [pub_query_mysql] NVARCHAR(MAX) NULL,
  [pub_bootstrap_element] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [ref_input_model_guid] UNIQUEIDENTIFIER NULL,
  [ref_output_model_guid] UNIQUEIDENTIFIER NULL
);
CREATE TABLE [etg].[contracts_db_operations_models] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_operations_models_fields] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_exclude_element] BIT DEFAULT (0) NOT NULL
);
CREATE TABLE [etg].[contracts_db_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_schema] NVARCHAR(64) DEFAULT ('dbo') NOT NULL,
  [pub_alias] NVARCHAR(128) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_seed_element] TINYINT DEFAULT (0) NOT NULL
);
-- =====================================================================
-- Kernel section 2 (etg schema): Enums, engines and primitives
-- =====================================================================
CREATE TABLE [etg].[contracts_primitives_enum_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_enums] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_enum_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_engines_cloudhost] -- Azure, AWS, GCP, etc.
(
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_engines_database] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_ddl_enums_mapping] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_engine_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_ddl_token] NVARCHAR(128) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_ddl_types_mapping] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_engine_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_ddl_token] NVARCHAR(128) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
-- =====================================================================
-- Core section (dbo schema): packages manifest and system configuration
-- =====================================================================
CREATE TABLE [dbo].[service_packages_manifest] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_version] NVARCHAR(64) NOT NULL,
  [pub_last_version] NVARCHAR(64) NULL,
  [pub_is_sealed] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_system_configuration] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_key] NVARCHAR(256) NOT NULL,
  [pub_value] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO
-- =====================================================================
-- Kernel package seed (must exist before any ref_package_guid resolves).
-- The REPL introspects the schema above and populates contracts_db_tables
-- / contracts_db_columns with deterministic UUID5s pointing here.
-- =====================================================================
INSERT INTO [dbo].[service_packages_manifest]
  (key_guid, pub_name, pub_version, pub_last_version, pub_is_sealed)
VALUES
  ('7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'kernel', '1.0.0', NULL, 1);
GO

-- contracts_primitives_enum_types seed
INSERT INTO [etg].[contracts_primitives_enum_types]
  (key_guid, ref_package_guid, pub_name, pub_notes)
VALUES
  ('4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_kind', 'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'schema_source', 'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).'),
  ('89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_disposition', 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT. Engine-specific DDL tokens live in contracts_ddl_enums_mapping.');

-- contracts_primitives_enums seed
INSERT INTO [etg].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, ref_package_guid, pub_name, pub_value, pub_notes)
VALUES
  ('57F37618-1A3E-5D30-88CB-095E1DC91492', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_ACTION', 0, 'Engine default. No clause emitted.'),
  ('E3C5DACB-6027-515A-8FED-489D71869C86', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY', 0, 'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('3426C194-B912-5F71-802F-566E2FF1E8FF', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('59C1933F-C216-5F32-A7C9-70A883287B8D', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CASCADE', 1, 'Delete or update of parent triggers same operation on children.'),
  ('BA9F914F-A591-512D-B2DF-B5C84D64C474', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_DEFAULT', 3, 'Child FK columns set to their column DEFAULT on parent delete/update.'),
  ('4D75333D-E472-5813-A03B-C0162671A00D', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('36DD290B-4606-5810-843E-CF324B66F504', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_NULL', 2, 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.'),
  ('92400F11-FCFD-5285-B9E2-D682B2496A88', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.'),
  ('B6ABA725-1FDB-5454-B164-DDBE11079598', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'GENERATED', 1, 'Declared schema generated from contracts_db_* rows.');

-- Indexes
CREATE INDEX [IX_cdic_index_guid] ON [etg].[contracts_db_index_columns] ([ref_index_guid]);
CREATE INDEX [IX_cdcc_constraint_guid] ON [etg].[contracts_db_constraint_columns] ([ref_constraint_guid]);
CREATE INDEX [IX_cddtm_engine_guid] ON [etg].[contracts_ddl_types_mapping] ([ref_engine_guid]);
CREATE INDEX [IX_cddtm_type_guid] ON [etg].[contracts_ddl_types_mapping] ([ref_type_guid]);
CREATE INDEX [IX_cddem_engine_guid] ON [etg].[contracts_ddl_enums_mapping] ([ref_engine_guid]);
CREATE INDEX [IX_cddem_enum_guid] ON [etg].[contracts_ddl_enums_mapping] ([ref_enum_guid]);
CREATE INDEX [IX_cdcn_kind] ON [etg].[contracts_db_constraints] ([ref_kind_enum_guid]);
CREATE INDEX [IX_cdcn_table_guid] ON [etg].[contracts_db_constraints] ([ref_table_guid]);
CREATE INDEX [IX_cdc_table_guid] ON [etg].[contracts_db_columns] ([ref_table_guid]);
CREATE INDEX [IX_cdc_type_guid] ON [etg].[contracts_db_columns] ([ref_type_guid]);
CREATE INDEX [IX_cdi_table_guid] ON [etg].[contracts_db_indexes] ([ref_table_guid]);
CREATE INDEX [IX_cdomf_model_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_model_guid]);
CREATE INDEX [IX_cdomf_type_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_type_guid]);

-- Constraints (PK, UNIQUE, CHECK)
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [PK_service_packages_manifest] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [UQ_spm_name] UNIQUE ([pub_name]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [PK_contracts_db_index_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [UQ_cdic_index_column] UNIQUE ([ref_index_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [PK_contracts_engines_cloudhost] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_name] UNIQUE ([pub_name]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_value] UNIQUE ([pub_value]);
ALTER TABLE [etg].[contracts_engines_database] ADD CONSTRAINT [PK_contracts_engines_database] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_engines_database] ADD CONSTRAINT [UQ_ced_name] UNIQUE ([pub_name]);
ALTER TABLE [etg].[contracts_engines_database] ADD CONSTRAINT [UQ_ced_value] UNIQUE ([pub_value]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [PK_contracts_db_tables] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_alias] UNIQUE ([pub_alias]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_schema_name] UNIQUE ([pub_schema], [pub_name]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [PK_contracts_db_constraint_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_column] UNIQUE ([ref_constraint_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_ordinal] UNIQUE ([ref_constraint_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [PK_contracts_db_operations_models] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [UQ_cdom_name] UNIQUE ([pub_name]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE ([pub_name]);
ALTER TABLE [etg].[contracts_ddl_types_mapping] ADD CONSTRAINT [PK_contracts_ddl_types_mapping] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_types_mapping] ADD CONSTRAINT [UQ_cddtm_type_engine] UNIQUE ([ref_type_guid], [ref_engine_guid]);
ALTER TABLE [etg].[contracts_ddl_enums_mapping] ADD CONSTRAINT [PK_contracts_ddl_enums_mapping] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_enums_mapping] ADD CONSTRAINT [UQ_cddem_enum_engine] UNIQUE ([ref_enum_guid], [ref_engine_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdcn_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_ordinal] UNIQUE ([ref_table_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [PK_contracts_db_operations_models_fields] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_name] UNIQUE ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_ordinal] UNIQUE ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_op] UNIQUE ([pub_op]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [PK_system_configuration] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [UQ_sc_key] UNIQUE ([pub_key]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [etg].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [FK_cec_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_engines_database] ADD CONSTRAINT [FK_ced_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [etg].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_ddl_types_mapping] ADD CONSTRAINT [FK_cddtm_engine] FOREIGN KEY ([ref_engine_guid]) REFERENCES [etg].[contracts_engines_database] ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_types_mapping] ADD CONSTRAINT [FK_cddtm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_ddl_types_mapping] ADD CONSTRAINT [FK_cddtm_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_enums_mapping] ADD CONSTRAINT [FK_cddem_engine] FOREIGN KEY ([ref_engine_guid]) REFERENCES [etg].[contracts_engines_database] ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_enums_mapping] ADD CONSTRAINT [FK_cddem_enum] FOREIGN KEY ([ref_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_ddl_enums_mapping] ADD CONSTRAINT [FK_cddem_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type] FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [etg].[contracts_primitives_enum_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;