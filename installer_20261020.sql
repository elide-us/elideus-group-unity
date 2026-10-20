SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Static prelude: types table
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
  ('F35FF7B4-489C-5279-8ACE-1DEE162431D1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'JSON_DOC', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', 'serde_json::Value', 'table', 'wchar_t*', 'std::wstring', 'LPWSTR', 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),
  ('045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64', 'bigint', -5, 8, 0, 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', '64-bit signed integer.'),
  ('788ECED9-E612-53C9-935D-375394E7B26D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATE', 'date', 91, 3, 0, 'DATE', 'date', 'date', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Date without time component.'),
  ('7D036485-4EDC-5000-99AB-45A74CF605F0', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_38_18', NULL, 3, NULL, 0, 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.'),
  ('00E12F64-89DC-5C43-95B3-4AB7F00C9D88', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT16', 'smallint', 5, 2, 0, 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 'i16', 'number', 'int16_t', 'int16_t', 'SHORT', '16-bit signed integer (-32768 to 32767).'),
  ('C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'STRING', 'nvarchar', -9, NULL, 1, 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Variable-length Unicode string. Column-level pub_max_length required.'),
  ('D83C6FAB-1954-5E03-A84C-5255F1D20B60', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT64', 'float', 6, 8, 0, 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),
  ('7EDB34B7-836E-516E-9561-57AC66F00DD2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'VECTOR', 'vector', -10, NULL, 1, 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', 'Vec<f32>', '{number}', 'float*', 'std::vector<float>', 'FLOAT*', 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.'),
  ('AE75F369-2305-54B7-A76E-5E13DEB3B43B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT32', 'real', 7, 4, 0, 'REAL', 'real', 'float', 'float', 'number', 'number', 'f32', 'number', 'float', 'float', 'FLOAT', '32-bit IEEE 754 floating point. Sensor data, approximate values.'),
  ('CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT8', 'tinyint', -6, 1, 0, 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', 'u8', 'number', 'uint8_t', 'uint8_t', 'BYTE', '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),
  ('CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT32', 'int', 4, 4, 0, 'INT', 'integer', 'int', 'int', 'number', 'integer', 'i32', 'number', 'int32_t', 'int32_t', 'LONG', '32-bit signed integer.'),
  ('5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'UUID', 'uniqueidentifier', -11, 16, 0, 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', 'uuid::Uuid', 'string', 'uint8_t[16]', 'std::array<uint8_t,16>', 'GUID', '128-bit UUID / GUID.'),
  ('892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BOOL', 'bit', -7, 1, 0, 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', 'bool', 'boolean', 'bool', 'bool', 'BOOL', 'Boolean flag.'),
  ('160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATETIME_TZ', 'datetimeoffset', -155, NULL, 0, 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Timestamp with timezone offset. Platform standard for all timestamps.'),
  ('AB8B8138-B783-5A8B-9D26-CE8973E5E887', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_19_5', NULL, 3, NULL, 0, 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),
  ('69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'TEXT', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Unlimited-length Unicode text.'),
  ('77A989D6-BF01-5D0E-895A-D667C3C8A7CB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_28_12', NULL, 3, NULL, 0, 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'High-precision decimal (28,12). Staging tables, pre-quantization.'),
  ('7B75DC97-1DF5-5DC2-869F-F2931DC0C15B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BINARY', NULL, -4, NULL, 0, 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', 'Vec<u8>', 'buffer', 'uint8_t*', 'std::vector<uint8_t>', 'LPBYTE', 'Variable-length binary data.'),
  ('45FE541B-B4AA-518B-B707-FF5B673622FA', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64_IDENTITY', NULL, -5, 8, 0, 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.');
GO

-- =====================================================================
-- Generative section
-- =====================================================================
-- Tables
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
CREATE TABLE [dbo].[service_security_entitlements] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_security_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
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
CREATE TABLE [etg].[contracts_engines_cloudhost] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
GO
INSERT INTO [dbo].[service_packages_manifest]
  (key_guid, ref_package_guid, pub_name, pub_version, pub_last_version, pub_is_sealed)
VALUES
  ('F1954052-001D-5818-90DC-1953ADA7ABA1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'core', '0.1.0', NULL, 1),
  ('3051B31E-E885-52A0-A68A-2643EF82A8EC', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'setup', '0.1.0', NULL, 0),
  ('7E203E54-5538-5C0F-B6E5-D276DCD04C36', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'kernel', '0.1.0', NULL, 1);
GO

INSERT INTO [dbo].[service_system_configuration]
  (key_guid, ref_package_guid, pub_key, pub_value)
VALUES
  ('518CD840-0D12-5601-84EF-87FA6FA0E67F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'database_version', '0.1.0');
GO

-- service_security_entitlements seed
INSERT INTO [dbo].[service_security_entitlements]
  (key_guid, ref_package_guid, pub_name, pub_display, pub_notes)
VALUES
  ('42155909-38A2-594C-9885-2F237504A443', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTITLEMENT_OPENAI_IMAGE', 'OpenAI Image Generation', NULL),
  ('3790CD1E-0B2F-56CD-A22B-A680C44AD70B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTITLEMENT_OPENAI_TTS', 'OpenAI Text to Speech', NULL),
  ('7089BDB3-DC61-53B5-A9F7-F1EF19512C07', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTITLEMENT_OPENAI_TEXT', 'OpenAI Text Generation', NULL),
  ('E3E1F6BB-A6D8-5C39-9ED0-F2D5D35E508E', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTITLEMENT_LUMAAI', 'LumaAI Generation', NULL);

-- service_security_roles seed
INSERT INTO [dbo].[service_security_roles]
  (key_guid, ref_package_guid, pub_name, pub_display, pub_notes)
VALUES
  ('66A58CFD-8786-5D78-B874-1016E50471E5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_ADMIN', 'Finance Admin', NULL),
  ('E96BDA1F-8876-5D4E-B697-1926ECD628CE', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SERVICE_ADMIN', 'Service Admin', NULL),
  ('5C607B13-539B-5586-AD39-31124298D0AF', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_DISCORD_ADMIN', 'Discord Admin', NULL),
  ('B5533CBF-596D-58FE-9B88-379A2D608E53', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SUPPORT', 'Support', NULL),
  ('29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_SYSTEM_ADMIN', 'System Admin', NULL),
  ('755D78AC-3CF7-574A-9BCB-4B3BBD4EDD38', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_ANONYMOUS', 'Anonymous', NULL),
  ('89C75A3C-F893-5658-8CA4-6AB27D728BC1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_MODERATOR', 'Moderator', NULL),
  ('F3762DBF-5F50-524B-838F-70A957E92DF2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_ACCOUNT_ADMIN', 'Account Admin', NULL),
  ('D9ECA799-8D60-5436-9D59-817AB3E8CD62', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_REGISTERED', 'Registered User', NULL),
  ('6F9583DD-2CEB-5F78-96FD-84A2B567B6D0', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_AI_GENERATION', 'AI Generation', NULL),
  ('2DEAD089-E1E7-5F26-99C6-8E6CCE217C5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_ACCT', 'Accountant', NULL),
  ('8697410A-F3F9-5A58-84BA-A2215EA54F60', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_STORAGE', 'Storage Enabled', NULL),
  ('4798B5AD-8A49-5FBA-B392-BC50420657A7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_FINANCE_APPR', 'Accounting Manager', NULL),
  ('CC0F8FEF-2786-5A93-97F1-C81AB2CC781F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_DISCORD_BOT', 'Discord Bot', NULL),
  ('9B548691-7D52-545A-A697-E0D789A64A94', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ROLE_MCP_ACCESS', 'MCP Agent Access', NULL);

-- contracts_db_operations_models seed
INSERT INTO [etg].[contracts_db_operations_models]
  (key_guid, ref_package_guid, pub_name, pub_notes)
VALUES
  ('8E519B15-C659-511E-983D-007B243EF505', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_physical_tables_output', NULL),
  ('A17D0129-73D9-5CDF-AF30-00B1257B8A26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'check_physical_table_exists_output', NULL),
  ('359138B1-2CE7-50BF-BC99-042D92DF0E09', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_package_ext_columns_input', NULL),
  ('E598D705-DB31-553A-AB1B-0AB32C1EC96F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_seed_column_projection_input', NULL),
  ('824C72C5-6DB4-5836-9B08-15D96824391D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_tables_output', NULL),
  ('AFEA32E7-6E93-512E-8137-1887A96AC9E0', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_indexes_on_column_output', NULL),
  ('843D2319-E230-5714-8F6C-1C1CC7EBCD50', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'delete_manifest_row_input', NULL),
  ('AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'set_manifest_sealed_input', NULL),
  ('BF39BDE4-4185-565B-89B0-35A50701C1E0', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_manifest_rows_output', NULL),
  ('907D816F-63E6-5FCE-A40A-3DB38349317D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_package_owned_tables_input', NULL),
  ('7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_constraints_output', NULL),
  ('D52527ED-7530-5A0E-91AA-5D6552FDB662', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'check_physical_table_exists_input', NULL),
  ('1587F1D3-C8F7-5337-922A-6B2A117B28A2', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_indexes_on_column_input', NULL),
  ('5A3956C2-B48B-5712-948A-7AB479F56009', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_constraint_columns_output', NULL),
  ('804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_index_columns_output', NULL),
  ('B3A5C093-4FCF-5641-A3FE-7F8E887537E2', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_package_owned_tables_output', NULL),
  ('39623119-64BB-56CD-A769-8C4202B917B4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_entitlements_read_all_output', NULL),
  ('0389AD92-4AA9-57AD-8069-9EFBE5568D65', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_indexes_output', NULL),
  ('1E4753FE-ED6F-5097-B061-A2F7C85CAB0F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_fks_on_column_output', NULL),
  ('0D9086F0-1B38-502D-9607-A580D21B9A24', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_physical_tables_with_package_column_output', NULL),
  ('9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_columns_output', NULL),
  ('7E57F8F0-B322-58E3-B199-B40932016ADF', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_fks_on_column_input', NULL),
  ('87912659-527B-5173-B74A-C43EF898A113', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'check_table_has_package_column_input', NULL),
  ('EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'check_table_has_package_column_output', NULL),
  ('BA1E762E-8437-586F-9264-D1A05697559E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'list_package_ext_columns_output', NULL),
  ('A25D2D37-B0E6-5E60-8FC8-D8CB7F9DEDF7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_roles_read_all_output', NULL),
  ('09A5C28E-AAA9-505D-8A06-EE489F336B69', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_seed_table_list_output', NULL),
  ('FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'read_seed_column_projection_output', NULL);

-- contracts_primitives_enum_types seed
INSERT INTO [etg].[contracts_primitives_enum_types]
  (key_guid, ref_package_guid, pub_name, pub_notes)
VALUES
  ('4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_kind', 'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'schema_source', 'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).'),
  ('89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_disposition', 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT.');

-- contracts_db_operations seed
INSERT INTO [etg].[contracts_db_operations]
  (key_guid, ref_package_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql, pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
VALUES
  ('6BC72AED-3A33-5BD6-8433-0301334995E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_physical_tables_with_package_column:1', 'SELECT [ss].[name] AS [ss_name], [st].[name] AS [st_name] FROM [sys].[tables] AS [st] JOIN [sys].[schemas] AS [ss] ON [st].[schema_id] = [ss].[schema_id] JOIN [sys].[columns] AS [sc] ON [sc].[object_id] = [st].[object_id] WHERE [sc].[name] = ''ref_package_guid'' ORDER BY [ss].[name], [st].[name] FOR JSON PATH', NULL, NULL, 1, 'List physical tables that have a ref_package_guid column. Used by list_packages and uninstall scan.', NULL, '0D9086F0-1B38-502D-9607-A580D21B9A24'),
  ('8E9CFF6A-2193-566C-941E-0A3894F3BC8D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:update_statistics:1', 'EXEC [sys].[sp_updatestats]', NULL, NULL, 1, 'Refresh statistics on all user tables. MSSQL-specific. Used by uninstall maintenance pass.', NULL, NULL),
  ('DBE765C1-2A7F-5E01-B586-1AB86F4264BA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_seed_column_projection:1', 'SELECT [cdc].[pub_name] FROM [etg].[contracts_db_columns] AS [cdc] WHERE [cdc].[ref_table_guid] = ? AND [cdc].[pub_exclude_element] = 0 ORDER BY [cdc].[pub_ordinal] FOR JSON PATH', NULL, NULL, 1, 'Projected column names for a seed table, excluding pub_exclude_element=1 columns. Used by generate_seed.', 'E598D705-DB31-553A-AB1B-0AB32C1EC96F', 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37'),
  ('50519800-AAE3-5918-A735-2DD80CF2D781', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_tables:1', 'SELECT [cdt].[key_guid], [cdt].[pub_name], [cdt].[pub_schema], [cdt].[pub_alias] FROM [etg].[contracts_db_tables] AS [cdt] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH', NULL, NULL, 1, 'Read all rows from contracts_db_tables. Used by dump and materialize.', NULL, '824C72C5-6DB4-5836-9B08-15D96824391D'),
  ('564A31D5-E231-5F15-BB8B-2DDD09C2121C', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_constraint_columns:1', 'SELECT [cdcc].[ref_constraint_guid], [cdcc].[pub_ordinal], [cdc].[pub_name], (SELECT [cdc].[pub_name] FROM [etg].[contracts_db_columns] AS [cdc] WHERE [cdc].[key_guid] = [cdcc].[ref_referenced_column_guid]) AS [cdc_referenced_name] FROM [etg].[contracts_db_constraint_columns] AS [cdcc] JOIN [etg].[contracts_db_columns] AS [cdc] ON [cdcc].[ref_column_guid] = [cdc].[key_guid] ORDER BY [cdcc].[ref_constraint_guid], [cdcc].[pub_ordinal] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read constraint column membership. FK rows include cdc_referenced_name; PK/UQ/CHECK rows have NULL. Used by dump and materialize.', NULL, '5A3956C2-B48B-5712-948A-7AB479F56009'),
  ('13140348-71BE-5A4B-9209-36F84FFA6E00', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:delete_manifest_row:1', 'DELETE [spm] FROM [dbo].[service_packages_manifest] AS [spm] WHERE [spm].[key_guid] = ?', NULL, NULL, 1, 'Delete a manifest row. Cascade-on-delete walks the FK graph and removes every package-owned row across the kernel tables. Used by uninstall step 3.', '843D2319-E230-5714-8F6C-1C1CC7EBCD50', NULL),
  ('2E7334B9-78F2-5697-96D4-37485E257786', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_package_ext_columns:1', 'SELECT [cdc].[key_guid], [cdc].[pub_name], [cdc].[ref_table_guid], [cdt].[pub_schema], [cdt].[pub_name] AS [cdt_name] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdc].[ref_table_guid] = [cdt].[key_guid] WHERE [cdc].[ref_package_guid] = ? FOR JSON PATH', NULL, NULL, 1, 'List columns owned by a package, joined to their parent table info. Caller filters for ext columns where parent table is not also owned by the package.', '359138B1-2CE7-50BF-BC99-042D92DF0E09', 'BA1E762E-8437-586F-9264-D1A05697559E'),
  ('7F4083AE-E0FE-5283-B23E-396BBB7E9181', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:security:roles:read_all:1', 'SELECT [ssr].[key_guid], [ssr].[pub_name], [ssr].[pub_display] FROM [dbo].[service_security_roles] AS [ssr] ORDER BY [ssr].[pub_name] FOR JSON PATH', NULL, NULL, 0, 'Every security role: key, name, display. Loaded by the security module at startup.', NULL, 'A25D2D37-B0E6-5E60-8FC8-D8CB7F9DEDF7'),
  ('6AE5285C-A13B-5A9B-8682-4CC9C1EBED5A', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_indexes:1', 'SELECT [cdi].[key_guid], [cdi].[ref_table_guid], [cdi].[pub_name], [cdi].[pub_is_unique] FROM [etg].[contracts_db_indexes] AS [cdi] ORDER BY [cdi].[ref_table_guid], [cdi].[pub_name] FOR JSON PATH', NULL, NULL, 1, 'Read all rows from contracts_db_indexes. Used by dump and materialize.', NULL, '0389AD92-4AA9-57AD-8069-9EFBE5568D65'),
  ('7446EA9B-882F-5CF1-958B-6469CABAB55F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_package_owned_tables:1', 'SELECT [cdt].[key_guid], [cdt].[pub_schema], [cdt].[pub_name] FROM [etg].[contracts_db_tables] AS [cdt] WHERE [cdt].[ref_package_guid] = ? FOR JSON PATH', NULL, NULL, 1, 'List tables owned by a package. Used by uninstall scan to determine which physical tables to drop.', '907D816F-63E6-5FCE-A40A-3DB38349317D', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2'),
  ('BB558858-5E01-558B-A5DE-87CD1E6EA520', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:security:entitlements:read_all:1', 'SELECT [sse].[key_guid], [sse].[pub_name], [sse].[pub_display] FROM [dbo].[service_security_entitlements] AS [sse] ORDER BY [sse].[pub_name] FOR JSON PATH', NULL, NULL, 0, 'Every security entitlement: key, name, display. Loaded by the security module at startup.', NULL, '39623119-64BB-56CD-A769-8C4202B917B4'),
  ('3535C42A-BB38-5A2E-94B3-916171211704', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_seed_table_list:1', 'SELECT [cdt].[key_guid], [cdt].[pub_name], [cdt].[pub_seed_element] FROM [etg].[contracts_db_tables] AS [cdt] WHERE [cdt].[pub_seed_element] > 0 ORDER BY [cdt].[pub_seed_element] FOR JSON PATH', NULL, NULL, 1, 'List seed-flagged tables in install order. Used by generate_seed.', NULL, '09A5C28E-AAA9-505D-8A06-EE489F336B69'),
  ('673FC7B9-094E-5CCA-AD01-96B5E29550F7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_index_columns:1', 'SELECT [cdic].[ref_index_guid], [cdic].[pub_ordinal], [cdc].[pub_name] FROM [etg].[contracts_db_index_columns] AS [cdic] JOIN [etg].[contracts_db_columns] AS [cdc] ON [cdic].[ref_column_guid] = [cdc].[key_guid] ORDER BY [cdic].[ref_index_guid], [cdic].[pub_ordinal] FOR JSON PATH', NULL, NULL, 1, 'Read index column membership joined to column names. Used by dump and materialize.', NULL, '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F'),
  ('8F1C8960-1B1D-59F9-A2CB-96DFE5CA82F3', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_manifest_rows:1', 'SELECT [spm].[key_guid], [spm].[pub_name], [spm].[pub_version], [spm].[pub_is_sealed] FROM [dbo].[service_packages_manifest] AS [spm] ORDER BY [spm].[pub_name] FOR JSON PATH', NULL, NULL, 1, 'List all packages from [dbo].[service_packages_manifest]. Used by list_packages.', NULL, 'BF39BDE4-4185-565B-89B0-35A50701C1E0'),
  ('5B88C303-2248-5C95-8676-9A42CF66126A', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_physical_tables:1', 'SELECT [ss].[name] AS [ss_name], [st].[name] AS [st_name] FROM [sys].[tables] AS [st] JOIN [sys].[schemas] AS [ss] ON [st].[schema_id] = [ss].[schema_id] FOR JSON PATH', NULL, NULL, 1, 'List physical tables in the engine catalog. MSSQL: sys.tables joined to sys.schemas. Used by materialize for declared-vs-physical diff.', NULL, '8E519B15-C659-511E-983D-007B243EF505'),
  ('45B42B2C-0E39-56FC-ACE2-A095AA8029DF', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:check_table_has_package_column:1', 'SELECT 1 AS [sc_ok] FROM [sys].[columns] AS [sc] JOIN [sys].[tables] AS [st] ON [sc].[object_id] = [st].[object_id] WHERE [st].[name] = ? AND [sc].[name] = ''ref_package_guid'' FOR JSON PATH', NULL, NULL, 1, 'Returns one row {sc_ok:1} if the named table physically has a ref_package_guid column, else empty. Used by install pipeline auto-injection.', '87912659-527B-5173-B74A-C43EF898A113', 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8'),
  ('D6E53F59-FD67-5945-B938-A6C214236843', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:free_proc_cache:1', 'DBCC FREEPROCCACHE', NULL, NULL, 1, 'Flush the procedure cache. MSSQL-specific. Used by uninstall maintenance pass.', NULL, NULL),
  ('1CD9D4AC-3596-5E06-B221-D2F0FD85C433', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_indexes_on_column:1', 'SELECT [si].[name] FROM [sys].[indexes] AS [si] JOIN [sys].[index_columns] AS [sic] ON [si].[object_id] = [sic].[object_id] AND [si].[index_id] = [sic].[index_id] JOIN [sys].[columns] AS [sc] ON [sic].[object_id] = [sc].[object_id] AND [sic].[column_id] = [sc].[column_id] JOIN [sys].[tables] AS [st] ON [sc].[object_id] = [st].[object_id] JOIN [sys].[schemas] AS [ss] ON [st].[schema_id] = [ss].[schema_id] WHERE [ss].[name] = ? AND [st].[name] = ? AND [sc].[name] = ? AND [si].[is_primary_key] = 0 AND [si].[is_unique_constraint] = 0 FOR JSON PATH', NULL, NULL, 1, 'List non-PK/non-UQ indexes that include the named column. Used by uninstall ext-column drop to remove indexes blocking the column drop.', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'AFEA32E7-6E93-512E-8137-1887A96AC9E0'),
  ('0C7A41A5-2B9A-52C4-975B-D5777CB41203', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_columns:1', 'SELECT [cdc].[key_guid], [cdc].[ref_table_guid], [cdc].[pub_name], [cdc].[pub_ordinal], [cdc].[pub_is_nullable], [cdc].[pub_default_value], [cdc].[pub_max_length], [cpt].[pub_mssql_type], [cpt].[pub_default_length], [cpt].[pub_name] AS [cpt_name], [cpt].[pub_emits_length] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_primitives_types] AS [cpt] ON [cdc].[ref_type_guid] = [cpt].[key_guid] ORDER BY [cdc].[ref_table_guid], [cdc].[pub_ordinal] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read all rows from contracts_db_columns joined to contracts_primitives_types. Used by dump and materialize for DDL emission.', NULL, '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B'),
  ('C5E7CD2F-9649-5F94-8200-E4ECC7454ADB', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:check_physical_table_exists:1', 'SELECT 1 AS [st_ok] FROM [sys].[tables] AS [st] JOIN [sys].[schemas] AS [ss] ON [st].[schema_id] = [ss].[schema_id] WHERE [ss].[name] = ? AND [st].[name] = ? FOR JSON PATH', NULL, NULL, 1, 'Returns one row {st_ok:1} if the named (schema, table) physically exists, else empty. Used by uninstall scan.', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', 'A17D0129-73D9-5CDF-AF30-00B1257B8A26'),
  ('01FD0C2B-3963-5776-A6E2-F04DC0AEC567', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:list_fks_on_column:1', 'SELECT [sfk].[name] FROM [sys].[foreign_keys] AS [sfk] JOIN [sys].[foreign_key_columns] AS [sfkc] ON [sfkc].[constraint_object_id] = [sfk].[object_id] JOIN [sys].[columns] AS [sc] ON [sfkc].[parent_object_id] = [sc].[object_id] AND [sfkc].[parent_column_id] = [sc].[column_id] JOIN [sys].[tables] AS [st] ON [sfk].[parent_object_id] = [st].[object_id] JOIN [sys].[schemas] AS [ss] ON [st].[schema_id] = [ss].[schema_id] WHERE [ss].[name] = ? AND [st].[name] = ? AND [sc].[name] = ? FOR JSON PATH', NULL, NULL, 1, 'List foreign keys whose referencing (parent) column is the named column. Used by uninstall ext-column drop to remove FKs blocking the column drop.', '7E57F8F0-B322-58E3-B199-B40932016ADF', '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F'),
  ('296651AD-F4D5-5D89-86A4-F7027B2838F8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:set_manifest_sealed:1', 'UPDATE [spm] SET [spm].[pub_is_sealed] = 1 FROM [dbo].[service_packages_manifest] AS [spm] WHERE [spm].[key_guid] = ?', NULL, NULL, 1, 'Mark a manifest row as sealed. Used by install Phase 5.', 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', NULL),
  ('8466098A-0485-540A-B54F-FF05D40B56A6', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:db:read_constraints:1', 'SELECT [cdco].[key_guid], [cdco].[ref_table_guid], [cdco].[ref_referenced_table_guid], [cdco].[pub_name], [cdco].[pub_expression], [cdco].[pub_delete_disposition], [cpe].[pub_name] AS [cpe_name] FROM [etg].[contracts_db_constraints] AS [cdco] JOIN [etg].[contracts_primitives_enums] AS [cpe] ON [cdco].[ref_kind_enum_guid] = [cpe].[key_guid] ORDER BY [cdco].[ref_table_guid], [cpe].[pub_value], [cdco].[pub_name] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read constraints joined to constraint_kind enum for cpe_name resolution. Used by dump and materialize.', NULL, '7BF9E37A-C65E-583E-AD71-5B55E584DE2C');

-- contracts_db_operations_models_fields seed
INSERT INTO [etg].[contracts_db_operations_models_fields]
  (key_guid, ref_model_guid, ref_type_guid, ref_package_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length, pub_exclude_element)
VALUES
  ('30E6B306-4C51-5830-9FF7-02ADD31AEDD8', '843D2319-E230-5714-8F6C-1C1CC7EBCD50', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('8AAC0DDB-D8DE-582A-8B95-02FD4F78467D', '824C72C5-6DB4-5836-9B08-15D96824391D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 2, 0, NULL, 128, 0),
  ('C4FC2CB8-BBB2-5F68-9538-07A6BB898E1C', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 2, 0, NULL, 64, 0),
  ('E495E08E-5FA4-5AC8-9A7B-0A7C0B62766F', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 2, 0, NULL, NULL, 0),
  ('F5818E7E-0987-5B1E-80B6-0B66515EF180', 'BA1E762E-8437-586F-9264-D1A05697559E', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cdt_name', 5, 0, NULL, 128, 0),
  ('9C8D93AC-C394-5005-A2F3-0EEC69459A83', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_table_name', 2, 0, NULL, 128, 0),
  ('A966110F-2A12-5F9F-A189-1638E15A1748', '5A3956C2-B48B-5712-948A-7AB479F56009', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_ordinal', 2, 0, NULL, NULL, 0),
  ('2C663A97-495F-59EE-B659-19F2A37C4D3A', '39623119-64BB-56CD-A769-8C4202B917B4', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 2, 0, NULL, 64, 0),
  ('6EE4EF2D-D858-565C-A74A-21131C0BA210', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 2, 0, NULL, NULL, 0),
  ('D5EC3D3C-B05C-5B5B-BCD0-21BBBC0A9175', '359138B1-2CE7-50BF-BC99-042D92DF0E09', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 1, 0, NULL, NULL, 0),
  ('7E2198CD-6F74-540A-B9BA-22D7868D7F98', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cpt_name', 10, 0, NULL, 64, 0),
  ('09FA65FB-7960-5E09-9CDA-2A1AC496C948', 'E598D705-DB31-553A-AB1B-0AB32C1EC96F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 1, 0, NULL, NULL, 0),
  ('B85A567D-E540-5020-99A9-2A1F074CA19A', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_max_length', 7, 1, NULL, NULL, 0),
  ('1A93A1C6-4580-51D8-8C3B-33D34A08F379', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('E96A6707-45A8-5177-B2BF-36673239F43A', '7E57F8F0-B322-58E3-B199-B40932016ADF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_column_name', 3, 0, NULL, 128, 0),
  ('6A349796-E031-5AA5-B388-3B8ED40B3D58', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 2, 0, NULL, NULL, 0),
  ('B6B88B8A-B829-5624-A938-3D76F1CD45B2', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('1073DB51-C923-54BA-9F12-42920CF1715B', 'BA1E762E-8437-586F-9264-D1A05697559E', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 4, 0, NULL, 64, 0),
  ('1F3809C6-22F4-5870-BF55-45600515DD22', 'A25D2D37-B0E6-5E60-8FC8-D8CB7F9DEDF7', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 2, 0, NULL, 64, 0),
  ('2FD5F5B1-2BBC-5536-86F9-45C5CF54FC33', '907D816F-63E6-5FCE-A40A-3DB38349317D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 1, 0, NULL, NULL, 0),
  ('BDA6CB59-7068-56A5-BEF8-48F5AAD49003', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 3, 0, NULL, 128, 0),
  ('B7000A29-FACD-5E20-9D0B-4A2296BD2DBB', '5A3956C2-B48B-5712-948A-7AB479F56009', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_constraint_guid', 1, 0, NULL, NULL, 0),
  ('5AF8A97B-A853-553C-B7DE-53304E1FD1A7', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_ordinal', 2, 0, NULL, NULL, 0),
  ('A3FE69F6-E3DD-5BE8-96CC-5B35A1CAAFBF', 'BA1E762E-8437-586F-9264-D1A05697559E', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 3, 0, NULL, NULL, 0),
  ('20FA75AF-240B-571C-8A47-5D20B70B51BB', 'BA1E762E-8437-586F-9264-D1A05697559E', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 2, 0, NULL, 128, 0),
  ('01B8E37E-84B1-557F-A7D3-6112BC0563DA', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_referenced_table_guid', 3, 1, NULL, NULL, 0),
  ('8BCF44A9-9E34-5716-A388-62A51231C974', '7E57F8F0-B322-58E3-B199-B40932016ADF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 1, 0, NULL, 64, 0),
  ('04468668-F212-5069-8643-65342F22B1FB', '824C72C5-6DB4-5836-9B08-15D96824391D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('0F994B1C-298F-5AC6-9A84-6589B538D0B8', 'A17D0129-73D9-5CDF-AF30-00B1257B8A26', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'st_ok', 1, 0, NULL, NULL, 0),
  ('E15B3FE0-B6F9-51CD-A09E-73468C964355', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_is_nullable', 5, 0, NULL, NULL, 0),
  ('DEF26816-D04C-5618-9C71-76503D0BEE58', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_column_name', 3, 0, NULL, 128, 0),
  ('B764150D-6367-51A1-8CB6-7C0BAE983598', 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 1, 0, NULL, 128, 0),
  ('76D34D10-D391-5137-A1D3-81172A4BE83A', '8E519B15-C659-511E-983D-007B243EF505', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ss_name', 1, 0, NULL, 64, 0),
  ('EF3DFD78-0954-5E85-AD8B-81183F143117', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_index_guid', 1, 0, NULL, NULL, 0),
  ('53E6F233-A84C-5B7F-BB62-839B68852E00', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('EECF3C1C-E7FB-58DC-BC5D-8CA8518CCEDB', 'A25D2D37-B0E6-5E60-8FC8-D8CB7F9DEDF7', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0),
  ('AD77E785-DF9B-5F5E-889F-8EE663D700F7', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_is_unique', 4, 0, NULL, NULL, 0),
  ('1D30CD4A-51AD-53DB-9AC2-93A6900B1063', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('CA4EBB80-B6BC-50AE-AB4C-9623D6D6FA4B', '39623119-64BB-56CD-A769-8C4202B917B4', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0),
  ('B056B552-5919-5351-940C-96CA6D8A94FB', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_expression', 5, 1, NULL, NULL, 0),
  ('390ABBF2-1A84-571F-B77E-9840759F074B', 'A25D2D37-B0E6-5E60-8FC8-D8CB7F9DEDF7', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 3, 0, NULL, 128, 0),
  ('6FBD9D37-70A9-59D3-B677-9A1CC3B6BB4C', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_version', 3, 0, NULL, 64, 0),
  ('CA187572-1558-5F02-B6FC-A3D771A1F6D9', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cpe_name', 7, 0, NULL, 128, 0),
  ('BFC96BB7-7867-5C27-B061-A54187C90B31', '5A3956C2-B48B-5712-948A-7AB479F56009', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cdc_referenced_name', 4, 1, NULL, 128, 0),
  ('1B0FFB95-566F-51F1-AA5E-AB44906CF5E6', '7E57F8F0-B322-58E3-B199-B40932016ADF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_table_name', 2, 0, NULL, 128, 0),
  ('EA8E786A-57BF-5DA4-B579-AB52020C2975', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 2, 0, NULL, 256, 0),
  ('DCF1E853-FB81-52B0-91B2-B0C93D4FA8CD', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_mssql_type', 8, 0, NULL, 128, 0),
  ('99553ADD-8979-58D9-90BC-B587A4FB5681', 'BA1E762E-8437-586F-9264-D1A05697559E', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('35F4D370-08B4-5267-A365-C1631FBCD36A', '0D9086F0-1B38-502D-9607-A580D21B9A24', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'st_name', 2, 0, NULL, 128, 0),
  ('9FB4A6C6-F393-5ED6-923C-C3DCCA74BB53', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('D664491A-53A3-5E53-9A2E-C4EC2B4FD4B1', 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'sc_ok', 1, 0, NULL, NULL, 0),
  ('6E06BE45-7416-5C0F-B113-C6443850765B', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_is_sealed', 4, 0, NULL, NULL, 0),
  ('2D82E362-46C4-5C53-8334-C965FA9F830F', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_delete_disposition', 6, 1, NULL, NULL, 0),
  ('724CC2BA-A2E8-5FE1-AD2A-CA16E0588614', '824C72C5-6DB4-5836-9B08-15D96824391D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 3, 0, NULL, 64, 0),
  ('FD03B85C-3318-57A0-87BE-CC4C16853B23', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_table_name', 2, 0, NULL, 128, 0),
  ('446E13F4-BE4E-582F-AB7E-CC9F0025EF5F', '09A5C28E-AAA9-505D-8A06-EE489F336B69', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('F9920886-9D6A-5D45-9F9F-CEAB45F278D9', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 1, 0, NULL, 64, 0),
  ('8AF35F6E-E65F-5654-8227-CEEBB3CF9FCE', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 3, 0, NULL, 256, 0),
  ('38F37E79-F117-5C00-ABBB-D16EAD4611D4', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_default_length', 9, 1, NULL, NULL, 0),
  ('4B8E7BAF-A641-5BF2-8F9C-D29017FAF036', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_default_value', 6, 1, NULL, 512, 0),
  ('16292E77-D9D5-53D4-AFDA-D371ACF8E20A', '39623119-64BB-56CD-A769-8C4202B917B4', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 3, 0, NULL, 128, 0),
  ('80C587A2-4DA0-5760-98AB-D549C86E4D15', '0D9086F0-1B38-502D-9607-A580D21B9A24', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ss_name', 1, 0, NULL, 64, 0),
  ('286D534A-8D03-512E-9CC2-D5A054B9E52D', 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0),
  ('5D6174D4-FECD-5DFB-90D3-DA2CA0DE8B4E', '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'name', 1, 0, NULL, 256, 0),
  ('4F6BEBBC-9F39-58C7-B8CE-DF5984697B67', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 3, 0, NULL, 128, 0),
  ('8D36F179-4216-5703-AF19-E1B61BCFB525', '824C72C5-6DB4-5836-9B08-15D96824391D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_alias', 4, 0, NULL, 128, 0),
  ('4BF0861C-BE0F-5DA2-903B-E65B93DEACB4', 'AFEA32E7-6E93-512E-8137-1887A96AC9E0', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'name', 1, 0, NULL, 256, 0),
  ('7FE04F71-9FCC-5EA8-91B6-E843467ED7D1', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 4, 0, NULL, 256, 0),
  ('919BED66-6D7A-5460-AD62-E92EDFFEC2B9', '87912659-527B-5173-B74A-C43EF898A113', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_table_name', 1, 0, NULL, 128, 0),
  ('9ED06D9C-0FBF-5C3B-A11F-E9C6CC145574', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_emits_length', 11, 0, NULL, NULL, 0),
  ('15BB6EE7-227D-5045-AE3F-ED2233AE5286', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_ordinal', 4, 0, NULL, NULL, 0),
  ('4514CF79-4B17-51CA-89E4-F156B57F290C', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 1, 0, NULL, 64, 0),
  ('28ED9F4A-86EB-59AF-A9E8-F42C741A78FD', '09A5C28E-AAA9-505D-8A06-EE489F336B69', 'CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_seed_element', 3, 0, NULL, NULL, 0),
  ('B2788AB6-031F-59E2-8253-F8A255D0028C', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 3, 0, NULL, 128, 0),
  ('97319818-7856-5045-923D-FB70AEF1402B', '8E519B15-C659-511E-983D-007B243EF505', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'st_name', 2, 0, NULL, 128, 0),
  ('CC92F882-A81A-5626-BEAF-FD98B071855F', '5A3956C2-B48B-5712-948A-7AB479F56009', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 3, 0, NULL, 128, 0),
  ('27B8BF59-CD37-563F-9641-FDBEF05122ED', '09A5C28E-AAA9-505D-8A06-EE489F336B69', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 2, 0, NULL, 128, 0);

-- contracts_primitives_enums seed
INSERT INTO [etg].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, ref_package_guid, pub_name, pub_value, pub_notes)
VALUES
  ('57F37618-1A3E-5D30-88CB-095E1DC91492', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_ACTION', 0, 'Engine default. No clause emitted.'),
  ('E3C5DACB-6027-515A-8FED-489D71869C86', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY', 0, 'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('C1002C88-406F-546E-B3EF-69D75C4906FF', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.'),
  ('59C1933F-C216-5F32-A7C9-70A883287B8D', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CASCADE', 1, 'Delete or update of parent triggers same operation on children.'),
  ('BA9F914F-A591-512D-B2DF-B5C84D64C474', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_DEFAULT', 3, 'Child FK columns set to their column DEFAULT on parent delete/update.'),
  ('F688BD8B-9BF5-57C6-8483-B6AE49C0E826', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('36DD290B-4606-5810-843E-CF324B66F504', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_NULL', 2, 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.'),
  ('0AD96EE8-08F2-59B9-8FEC-D51DA0010517', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('773A1E54-BDC0-58E3-B3A2-D8296F00E9ED', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'GENERATED', 1, 'Declared schema generated from contracts_db_* rows.');

-- Indexes
CREATE NONCLUSTERED INDEX [IX_cdi_table_guid] ON [etg].[contracts_db_indexes] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdc_table_guid] ON [etg].[contracts_db_columns] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdc_type_guid] ON [etg].[contracts_db_columns] ([ref_type_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_model_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_model_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_type_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_type_guid]);
CREATE NONCLUSTERED INDEX [IX_cdic_index_guid] ON [etg].[contracts_db_index_columns] ([ref_index_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_kind] ON [etg].[contracts_db_constraints] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_table_guid] ON [etg].[contracts_db_constraints] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdcc_constraint_guid] ON [etg].[contracts_db_constraint_columns] ([ref_constraint_guid]);

-- Constraints (PK, UNIQUE, CHECK)
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [PK_contracts_db_operations_models] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [UQ_cdom_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_ordinal] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [PK_contracts_db_operations_models_fields] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_name] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_ordinal] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [PK_contracts_db_tables] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_alias] UNIQUE NONCLUSTERED ([pub_alias]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_schema_name] UNIQUE NONCLUSTERED ([pub_schema], [pub_name]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [PK_contracts_db_index_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [UQ_cdic_index_column] UNIQUE NONCLUSTERED ([ref_index_guid], [ref_column_guid]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [PK_service_security_roles] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [UQ_ssr_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_op] UNIQUE NONCLUSTERED ([pub_op]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdco_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [PK_service_packages_manifest] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [UQ_spm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [PK_service_security_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [UQ_sse_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [PK_contracts_db_constraint_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_column] UNIQUE NONCLUSTERED ([ref_constraint_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_ordinal] UNIQUE NONCLUSTERED ([ref_constraint_guid], [pub_ordinal]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [PK_system_configuration] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [UQ_sc_key] UNIQUE NONCLUSTERED ([pub_key]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [PK_contracts_engines_cloudhost] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [UQ_cec_value] UNIQUE NONCLUSTERED ([pub_value]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type] FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [etg].[contracts_primitives_enum_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [etg].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [FK_ssr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [FK_cpt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [FK_spm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [FK_sse_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [etg].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_engines_cloudhost] ADD CONSTRAINT [FK_cec_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;