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
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
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
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [PK_contracts_primitives_types] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [UQ_cpt_name] UNIQUE NONCLUSTERED ([pub_name]);
INSERT INTO [etg].[contracts_primitives_types]
  (key_guid, ref_package_guid, pub_name, pub_mssql_sys_type, pub_odbc_type_code, pub_default_length, pub_emits_length, pub_mssql_type, pub_postgresql_type, pub_mysql_type, pub_python_type, pub_typescript_type, pub_json_type, pub_rust_type, pub_lua_type, pub_c_type, pub_cpp_stl_type, pub_cpp_win32_type, pub_notes)
VALUES
  ('CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT8', 'tinyint', -6, 1, 0, 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', 'u8', 'number', 'uint8_t', 'uint8_t', 'BYTE', '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),
  ('160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATETIME_TZ', 'datetimeoffset', -155, NULL, 0, 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Timestamp with timezone offset. Platform standard for all timestamps.'),
  ('7B75DC97-1DF5-5DC2-869F-F2931DC0C15B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BINARY', NULL, -4, NULL, 0, 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', 'Vec<u8>', 'buffer', 'uint8_t*', 'std::vector<uint8_t>', 'LPBYTE', 'Variable-length binary data.'),
  ('D83C6FAB-1954-5E03-A84C-5255F1D20B60', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT64', 'float', 6, 8, 0, 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),
  ('00E12F64-89DC-5C43-95B3-4AB7F00C9D88', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT16', 'smallint', 5, 2, 0, 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 'i16', 'number', 'int16_t', 'int16_t', 'SHORT', '16-bit signed integer (-32768 to 32767).'),
  ('AB8B8138-B783-5A8B-9D26-CE8973E5E887', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_19_5', NULL, 3, NULL, 0, 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),
  ('892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BOOL', 'bit', -7, 1, 0, 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', 'bool', 'boolean', 'bool', 'bool', 'BOOL', 'Boolean flag.'),
  ('F35FF7B4-489C-5279-8ACE-1DEE162431D1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'JSON_DOC', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', 'serde_json::Value', 'table', 'wchar_t*', 'std::wstring', 'LPWSTR', 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),
  ('AE75F369-2305-54B7-A76E-5E13DEB3B43B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT32', 'real', 7, 4, 0, 'REAL', 'real', 'float', 'float', 'number', 'number', 'f32', 'number', 'float', 'float', 'FLOAT', '32-bit IEEE 754 floating point. Sensor data, approximate values.'),
  ('77A989D6-BF01-5D0E-895A-D667C3C8A7CB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_28_12', NULL, 3, NULL, 0, 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'High-precision decimal (28,12). Staging tables, pre-quantization.'),
  ('45FE541B-B4AA-518B-B707-FF5B673622FA', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64_IDENTITY', NULL, -5, 8, 0, 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.'),
  ('69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'TEXT', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Unlimited-length Unicode text.'),
  ('CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT32', 'int', 4, 4, 0, 'INT', 'integer', 'int', 'int', 'number', 'integer', 'i32', 'number', 'int32_t', 'int32_t', 'LONG', '32-bit signed integer.'),
  ('7D036485-4EDC-5000-99AB-45A74CF605F0', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_38_18', NULL, 3, NULL, 0, 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.'),
  ('C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'STRING', 'nvarchar', -9, NULL, 1, 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Variable-length Unicode string. Column-level pub_max_length required.'),
  ('045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64', 'bigint', -5, 8, 0, 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', '64-bit signed integer.'),
  ('788ECED9-E612-53C9-935D-375394E7B26D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATE', 'date', 91, 3, 0, 'DATE', 'date', 'date', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Date without time component.'),
  ('5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'UUID', 'uniqueidentifier', -11, 16, 0, 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', 'uuid::Uuid', 'string', 'uint8_t[16]', 'std::array<uint8_t,16>', 'GUID', '128-bit UUID / GUID.'),
  ('7EDB34B7-836E-516E-9561-57AC66F00DD2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'VECTOR', 'vector', -10, NULL, 1, 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', 'Vec<f32>', '{number}', 'float*', 'std::vector<float>', 'FLOAT*', 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.');
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
-- NOTE: Every ref_package_guid resolves to a manifest key_guid, the
-- manifest's own included: a package owns its manifest row (self
-- reference, NO ACTION - SQL Server forbids a cascading self reference).
-- =====================================================================
CREATE TABLE [dbo].[service_packages_manifest] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
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
-- Security roles: a role grants access to a top-level domain (a major
-- module: Administration, Finance, Content, Generation, Prism, ...).
-- Functions and users FK-link to roles; the domain lives on the RPC
-- domains table, not here. Keyed by formula: 'service_security_roles:<pub_name>'.
CREATE TABLE [dbo].[service_security_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
  [pub_is_clustered] BIT DEFAULT (0) NOT NULL,
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
  [pub_is_clustered] BIT DEFAULT (0) NOT NULL,
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
-- =====================================================================
-- Core section (dbo schema): packages manifest and system configuration
-- =====================================================================

GO
-- =====================================================================
-- Kernel package seed (must exist before any ref_package_guid resolves).
-- The REPL introspects the schema above and populates contracts_db_tables
-- / contracts_db_columns with deterministic UUID5s pointing here.
-- =====================================================================
INSERT INTO [dbo].[service_packages_manifest]
  (key_guid, ref_package_guid, pub_name, pub_version, pub_last_version, pub_is_sealed)
VALUES
  ('7E203E54-5538-5C0F-B6E5-D276DCD04C36', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'kernel', '0.1.0', NULL, 1),
  ('F1954052-001D-5818-90DC-1953ADA7ABA1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'core', '0.1.0', NULL, 0),
  ('3051B31E-E885-52A0-A68A-2643EF82A8EC', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'setup', '0.1.0', NULL, 0);
GO

-- Database schema version. The kernel reads this at startup and compares it
-- with the version it was built for; in setup mode a mismatch triggers the
-- upgrade workflow. Keyed by formula: 'service_system_configuration:database_version'.
INSERT INTO [dbo].[service_system_configuration]
  (key_guid, ref_package_guid, pub_key, pub_value)
VALUES
  ('518CD840-0D12-5601-84EF-87FA6FA0E67F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'database_version', '0.1.0');
GO

-- Security roles: the production role names, keyed by formula
-- 'service_security_roles:<pub_name>'. Owned by core. No masks: the
-- key is the lookup.
INSERT INTO [dbo].[service_security_roles]
  (key_guid, ref_package_guid, pub_name, pub_display, pub_notes)
VALUES
  ('29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SYSTEM_ADMIN', 'System Admin', NULL),
  ('2DEAD089-E1E7-5F26-99C6-8E6CCE217C5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_ACCT', 'Accountant', NULL),
  ('4798B5AD-8A49-5FBA-B392-BC50420657A7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_APPR', 'Accounting Manager', NULL),
  ('5C607B13-539B-5586-AD39-31124298D0AF', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_DISCORD_ADMIN', 'Discord Admin', NULL),
  ('66A58CFD-8786-5D78-B874-1016E50471E5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_ADMIN', 'Finance Admin', NULL),
  ('8697410A-F3F9-5A58-84BA-A2215EA54F60', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_STORAGE', 'Storage Enabled', NULL),
  ('89C75A3C-F893-5658-8CA4-6AB27D728BC1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_MODERATOR', 'Moderator', NULL),
  ('8C2B5285-2D47-52D4-8623-B177DB56B014', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_LUMAAI_API', 'LumaAI Generation', NULL),
  ('9B548691-7D52-545A-A697-E0D789A64A94', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_MCP_ACCESS', 'MCP Agent Access', NULL),
  ('B5533CBF-596D-58FE-9B88-379A2D608E53', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SUPPORT', 'Support', NULL),
  ('CC0F8FEF-2786-5A93-97F1-C81AB2CC781F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_DISCORD_BOT', 'Discord Bot', NULL),
  ('D9ECA799-8D60-5436-9D59-817AB3E8CD62', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_REGISTERED', 'Registered User', NULL),
  ('E96BDA1F-8876-5D4E-B697-1926ECD628CE', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SERVICE_ADMIN', 'Service Admin', NULL),
  ('ECD11AE1-7A20-53B3-A5E4-52EC20FFE8B5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_OPENAI_API', 'OpenAI Generation', NULL),
  ('F3762DBF-5F50-524B-838F-70A957E92DF2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_ACCOUNT_ADMIN', 'Account Admin', NULL);
GO

-- contracts_primitives_enum_types seed
INSERT INTO [etg].[contracts_primitives_enum_types]
  (key_guid, ref_package_guid, pub_name, pub_notes)
VALUES
  ('4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_kind', 'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'schema_source', 'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).'),
  ('89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_disposition', 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT.');

-- contracts_primitives_enums seed
INSERT INTO [etg].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, ref_package_guid, pub_name, pub_value, pub_notes)
VALUES
  ('57F37618-1A3E-5D30-88CB-095E1DC91492', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_ACTION', 0, 'Engine default. No clause emitted.'),
  ('E3C5DACB-6027-515A-8FED-489D71869C86', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY', 0, 'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('F688BD8B-9BF5-57C6-8483-B6AE49C0E826', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('59C1933F-C216-5F32-A7C9-70A883287B8D', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CASCADE', 1, 'Delete or update of parent triggers same operation on children.'),
  ('BA9F914F-A591-512D-B2DF-B5C84D64C474', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_DEFAULT', 3, 'Child FK columns set to their column DEFAULT on parent delete/update.'),
  ('773A1E54-BDC0-58E3-B3A2-D8296F00E9ED', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('36DD290B-4606-5810-843E-CF324B66F504', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_NULL', 2, 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.'),
  ('C1002C88-406F-546E-B3EF-69D75C4906FF', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.'),
  ('0AD96EE8-08F2-59B9-8FEC-D51DA0010517', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'GENERATED', 1, 'Declared schema generated from contracts_db_* rows.');

-- Indexes
CREATE NONCLUSTERED INDEX [IX_cdic_index_guid] ON [etg].[contracts_db_index_columns] ([ref_index_guid]);
CREATE NONCLUSTERED INDEX [IX_cdcc_constraint_guid] ON [etg].[contracts_db_constraint_columns] ([ref_constraint_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_kind] ON [etg].[contracts_db_constraints] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_table_guid] ON [etg].[contracts_db_constraints] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdc_table_guid] ON [etg].[contracts_db_columns] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdc_type_guid] ON [etg].[contracts_db_columns] ([ref_type_guid]);
CREATE NONCLUSTERED INDEX [IX_cdi_table_guid] ON [etg].[contracts_db_indexes] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_model_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_model_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_type_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_type_guid]);

-- Constraints (PK, UNIQUE, CHECK)
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [PK_service_packages_manifest] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [UQ_spm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [PK_contracts_db_index_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [UQ_cdic_index_column] UNIQUE NONCLUSTERED ([ref_index_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [PK_contracts_engines_cloudhost] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_value] UNIQUE NONCLUSTERED ([pub_value]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [PK_contracts_db_tables] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_alias] UNIQUE NONCLUSTERED ([pub_alias]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_schema_name] UNIQUE NONCLUSTERED ([pub_schema], [pub_name]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [PK_contracts_db_constraint_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_column] UNIQUE NONCLUSTERED ([ref_constraint_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_ordinal] UNIQUE NONCLUSTERED ([ref_constraint_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [PK_contracts_db_operations_models] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [UQ_cdom_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdco_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_ordinal] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [PK_contracts_db_operations_models_fields] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_name] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_ordinal] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_op] UNIQUE NONCLUSTERED ([pub_op]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [PK_system_configuration] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [UQ_sc_key] UNIQUE NONCLUSTERED ([pub_key]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [PK_service_security_roles] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [UQ_ssr_name] UNIQUE NONCLUSTERED ([pub_name]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [etg].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [FK_cec_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [etg].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type] FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [etg].[contracts_primitives_enum_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [FK_cpt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [FK_ssr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [FK_spm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]);