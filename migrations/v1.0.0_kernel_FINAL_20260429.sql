-- Generated 2026-04-29 21:08:05 UTC
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Static prelude: types table
-- =====================================================================
CREATE TABLE [dbo].[contracts_primitives_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_mssql_type] NVARCHAR(128) NOT NULL,
  [pub_postgresql_type] NVARCHAR(128) NULL,
  [pub_mysql_type] NVARCHAR(128) NULL,
  [pub_python_type] NVARCHAR(64) NOT NULL,
  [pub_typescript_type] NVARCHAR(64) NOT NULL,
  [pub_json_type] NVARCHAR(64) NOT NULL,
  [pub_odbc_type_code] SMALLINT NOT NULL,
  [pub_default_length] INT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_mssql_sys_type] NVARCHAR(64) NULL,
  [pub_emits_length] BIT DEFAULT (0) NOT NULL
);
ALTER TABLE [dbo].[contracts_primitives_types] ADD CONSTRAINT [PK_contracts_primitives_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_types] ADD CONSTRAINT [FK_cpt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_types] ADD CONSTRAINT [UQ_cpt_name] UNIQUE ([pub_name]);
INSERT INTO [dbo].[contracts_primitives_types]
  (key_guid, pub_name, pub_mssql_type, pub_postgresql_type, pub_mysql_type, pub_python_type, pub_typescript_type, pub_json_type, pub_odbc_type_code, pub_default_length, pub_notes, pub_mssql_sys_type, pub_emits_length)
VALUES
  ('0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'INT8', 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', -6, 1, '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.', 'tinyint', 0),
  ('0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'DATETIME_TZ', 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', -155, NULL, 'Timestamp with timezone offset. Platform standard for all timestamps.', 'datetimeoffset', 0),
  ('4B286A51-7A0B-5BA2-8391-264E572C8375', 'BINARY', 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', -4, NULL, 'Variable-length binary data.', NULL, 0),
  ('421D6C05-ACBA-58E7-9FE3-27F500497011', 'FLOAT64', 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 6, 8, '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.', 'float', 0),
  ('18667606-C633-5A82-9A3B-2CD27916FC95', 'INT16', 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 5, 2, '16-bit signed integer (-32768 to 32767).', 'smallint', 0),
  ('4DB81F9F-8990-5952-BBEA-4E175B362CDA', 'DECIMAL_19_5', 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 3, NULL, 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.', NULL, 0),
  ('72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'BOOL', 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', -7, 1, 'Boolean flag.', 'bit', 0),
  ('EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', 'JSON_DOC', 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', -10, NULL, 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.', NULL, 0),
  ('BD61A7EA-38ED-57AC-949F-5C82A0C0173E', 'FLOAT32', 'REAL', 'real', 'float', 'float', 'number', 'number', 7, 4, '32-bit IEEE 754 floating point. Sensor data, approximate values.', 'real', 0),
  ('085132BC-DDEB-5591-ACB0-7348445DC92C', 'DECIMAL_28_12', 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 3, NULL, 'High-precision decimal (28,12). Staging tables, pre-quantization.', NULL, 0),
  ('2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', 'INT64_IDENTITY', 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', -5, 8, 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.', NULL, 0),
  ('8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', 'TEXT', 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', -10, NULL, 'Unlimited-length Unicode text.', NULL, 0),
  ('1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'INT32', 'INT', 'integer', 'int', 'int', 'number', 'integer', 4, 4, '32-bit signed integer.', 'int', 0),
  ('53434CAA-A382-5B45-BAD2-AC3F655ED3A0', 'DECIMAL_38_18', 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 3, NULL, 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.', NULL, 0),
  ('8579BB4B-746B-5E4B-867B-BFB182D52110', 'STRING', 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', -9, NULL, 'Variable-length Unicode string. Column-level pub_max_length required.', 'nvarchar', 1),
  ('B96336CD-D4A0-5B24-920E-C818BDC4AE7A', 'INT64', 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', -5, 8, '64-bit signed integer.', 'bigint', 0),
  ('CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', 'DATE', 'DATE', 'date', 'date', 'str', 'string', 'string', 91, 3, 'Date without time component.', 'date', 0),
  ('DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'UUID', 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', -11, 16, '128-bit UUID / GUID.', 'uniqueidentifier', 0),
  ('F4CF3C0D-908E-5682-8FE7-F9973B90C56A', 'VECTOR', 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', -10, NULL, 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.', 'vector', 1);
GO

-- =====================================================================
-- Generative section
-- =====================================================================
-- Tables
CREATE TABLE [dbo].[contracts_db_columns] (
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
CREATE TABLE [dbo].[contracts_db_constraint_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_constraint_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_column_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_constraints] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_table_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_expression] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_index_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_index_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_indexes] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_is_unique] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_operations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_op] NVARCHAR(128) NOT NULL,
  [pub_query_mssql] NVARCHAR(MAX) NULL,
  [pub_query_postgres] NVARCHAR(MAX) NULL,
  [pub_query_mysql] NVARCHAR(MAX) NULL,
  [pub_bootstrap_element] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_schema] NVARCHAR(64) DEFAULT ('dbo') NOT NULL,
  [pub_alias] NVARCHAR(128) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_seed_element] TINYINT DEFAULT (0) NOT NULL
);
CREATE TABLE [dbo].[contracts_primitives_enum_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_primitives_enums] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_enum_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_modules_manifest] (
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

-- contracts_primitives_enum_types seed
INSERT INTO [dbo].[contracts_primitives_enum_types]
  (key_guid, pub_name, pub_notes)
VALUES
  ('4BE7C586-9847-5925-90A3-5071D8228F26', 'constraint_kind', 'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', 'schema_source', 'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).');

-- contracts_primitives_enums seed
INSERT INTO [dbo].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
VALUES
  ('E3C5DACB-6027-515A-8FED-489D71869C86', 'F5539B3E-417C-5A95-BF9B-592B97369B40', 'PRIMARY', 0, 'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('3426C194-B912-5F71-802F-566E2FF1E8FF', '4BE7C586-9847-5925-90A3-5071D8228F26', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('4D75333D-E472-5813-A03B-C0162671A00D', '4BE7C586-9847-5925-90A3-5071D8228F26', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('92400F11-FCFD-5285-B9E2-D682B2496A88', '4BE7C586-9847-5925-90A3-5071D8228F26', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.'),
  ('B6ABA725-1FDB-5454-B164-DDBE11079598', '4BE7C586-9847-5925-90A3-5071D8228F26', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07', 'F5539B3E-417C-5A95-BF9B-592B97369B40', 'GENERATED', 1, 'Declared schema generated from contracts_db_* rows.');

-- Indexes
CREATE INDEX [IX_cdic_index_guid] ON [dbo].[contracts_db_index_columns] ([ref_index_guid]);
CREATE INDEX [IX_cdcc_constraint_guid] ON [dbo].[contracts_db_constraint_columns] ([ref_constraint_guid]);
CREATE INDEX [IX_cdcn_kind] ON [dbo].[contracts_db_constraints] ([ref_kind_enum_guid]);
CREATE INDEX [IX_cdcn_table_guid] ON [dbo].[contracts_db_constraints] ([ref_table_guid]);
CREATE INDEX [IX_cdc_table_guid] ON [dbo].[contracts_db_columns] ([ref_table_guid]);
CREATE INDEX [IX_cdc_type_guid] ON [dbo].[contracts_db_columns] ([ref_type_guid]);
CREATE INDEX [IX_cdi_table_guid] ON [dbo].[contracts_db_indexes] ([ref_table_guid]);

-- Constraints (PK, UNIQUE, CHECK)
ALTER TABLE [dbo].[service_modules_manifest] ADD CONSTRAINT [PK_service_modules_manifest] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[service_modules_manifest] ADD CONSTRAINT [UQ_smm_name] UNIQUE ([pub_name]);
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [PK_contracts_db_index_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [UQ_cdic_index_column] UNIQUE ([ref_index_guid], [ref_column_guid]);
ALTER TABLE [dbo].[contracts_db_tables] ADD CONSTRAINT [PK_contracts_db_tables] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_alias] UNIQUE ([pub_alias]);
ALTER TABLE [dbo].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_schema_name] UNIQUE ([pub_schema], [pub_name]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [PK_contracts_db_constraint_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_column] UNIQUE ([ref_constraint_guid], [ref_column_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_ordinal] UNIQUE ([ref_constraint_guid], [pub_ordinal]);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE ([pub_name]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdcn_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_ordinal] UNIQUE ([ref_table_guid], [pub_ordinal]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [dbo].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_op] UNIQUE ([pub_op]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [PK_system_configuration] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [UQ_sc_key] UNIQUE ([pub_key]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [dbo].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_tables] ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [dbo].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [dbo].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type] FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [dbo].[contracts_primitives_enum_types] ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);

-- Authored overrides: pub_exclude_element on contracts_db_columns
UPDATE c
  SET pub_exclude_element = 1
  FROM contracts_db_columns c
  JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid
  WHERE (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_columns' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_columns' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_columns' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraint_columns' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraint_columns' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraint_columns' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraints' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraints' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_constraints' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_index_columns' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_index_columns' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_index_columns' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_indexes' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_indexes' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_indexes' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_operations' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_operations' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_operations' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_tables' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_tables' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_db_tables' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enum_types' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enum_types' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enum_types' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enums' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enums' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_enums' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_types' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_types' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'contracts_primitives_types' AND c.pub_name = 'ref_package_guid')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'service_modules_manifest' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'service_modules_manifest' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'service_system_configuration' AND c.pub_name = 'priv_created_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'service_system_configuration' AND c.pub_name = 'priv_modified_on')
     OR (t.pub_schema = 'dbo' AND t.pub_name = 'service_system_configuration' AND c.pub_name = 'ref_package_guid');