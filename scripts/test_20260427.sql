-- Generated 2026-04-27 21:14:16 UTC
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Static prelude: types table
-- =====================================================================
CREATE TABLE [dbo].[contracts_primitives_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
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
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_primitives_types] ADD CONSTRAINT [PK_contracts_primitives_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_types] ADD CONSTRAINT [UQ_cpt_name] UNIQUE ([pub_name]);
INSERT INTO [dbo].[contracts_primitives_types]
  (key_guid, pub_name, pub_mssql_type, pub_postgresql_type, pub_mysql_type,
   pub_python_type, pub_typescript_type, pub_json_type,
   pub_odbc_type_code, pub_default_length, pub_notes)
VALUES
  ('4B286A51-7A0B-5BA2-8391-264E572C8375', 'BINARY', 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', -4, NULL, 'Variable-length binary data.'),
  ('72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'BOOL', 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', -7, 1, 'Boolean flag.'),
  ('CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', 'DATE', 'DATE', 'date', 'date', 'str', 'string', 'string', 91, 3, 'Date without time component.'),
  ('0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'DATETIME_TZ', 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', -155, NULL, 'Timestamp with timezone offset. Platform standard for all timestamps.'),
  ('4DB81F9F-8990-5952-BBEA-4E175B362CDA', 'DECIMAL_19_5', 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 3, NULL, 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),
  ('085132BC-DDEB-5591-ACB0-7348445DC92C', 'DECIMAL_28_12', 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 3, NULL, 'High-precision decimal (28,12). Staging tables, pre-quantization.'),
  ('53434CAA-A382-5B45-BAD2-AC3F655ED3A0', 'DECIMAL_38_18', 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 3, NULL, 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.'),
  ('BD61A7EA-38ED-57AC-949F-5C82A0C0173E', 'FLOAT32', 'REAL', 'real', 'float', 'float', 'number', 'number', 7, 4, '32-bit IEEE 754 floating point. Sensor data, approximate values.'),
  ('421D6C05-ACBA-58E7-9FE3-27F500497011', 'FLOAT64', 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 6, 8, '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),
  ('18667606-C633-5A82-9A3B-2CD27916FC95', 'INT16', 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 5, 2, '16-bit signed integer (-32768 to 32767).'),
  ('1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'INT32', 'INT', 'integer', 'int', 'int', 'number', 'integer', 4, 4, '32-bit signed integer.'),
  ('B96336CD-D4A0-5B24-920E-C818BDC4AE7A', 'INT64', 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', -5, 8, '64-bit signed integer.'),
  ('2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', 'INT64_IDENTITY', 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', -5, 8, 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.'),
  ('0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'INT8', 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', -6, 1, '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),
  ('EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', 'JSON_DOC', 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', -10, NULL, 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),
  ('8579BB4B-746B-5E4B-867B-BFB182D52110', 'STRING', 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', -9, NULL, 'Variable-length Unicode string. Column-level pub_max_length required.'),
  ('8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', 'TEXT', 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', -10, NULL, 'Unlimited-length Unicode text.'),
  ('DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'UUID', 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', -11, 16, '128-bit UUID / GUID.'),
  ('F4CF3C0D-908E-5682-8FE7-F9973B90C56A', 'VECTOR', 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', -10, NULL, 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.');
GO

-- =====================================================================
-- Generative section
-- =====================================================================
-- Tables
CREATE TABLE [dbo].[contracts_db_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_constraint_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_constraint_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_column_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_constraints] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_table_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_expression] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_index_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_index_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_indexes] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_is_unique] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_operations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_op] NVARCHAR(128) NOT NULL,
  [pub_query_mssql] NVARCHAR(MAX) NULL,
  [pub_query_postgres] NVARCHAR(MAX) NULL,
  [pub_query_mysql] NVARCHAR(MAX) NULL,
  [pub_bootstrap] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_db_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_schema] NVARCHAR(64) DEFAULT ('dbo') NOT NULL,
  [pub_alias] NVARCHAR(128) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[contracts_primitives_enums] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_enum_type] NVARCHAR(128) NOT NULL,
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
  [priv_installed_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);

-- contracts_primitives_enums seed
INSERT INTO [dbo].[contracts_primitives_enums]
  (key_guid, pub_enum_type, pub_name, pub_value, pub_notes)
VALUES
  ('3426C194-B912-5F71-802F-566E2FF1E8FF', 'constraint_kind', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('B6ABA725-1FDB-5454-B164-DDBE11079598', 'constraint_kind', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('4D75333D-E472-5813-A03B-C0162671A00D', 'constraint_kind', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('92400F11-FCFD-5285-B9E2-D682B2496A88', 'constraint_kind', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.');

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
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdcn_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE ([pub_enum_type], [pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE ([pub_enum_type], [pub_value]);
ALTER TABLE [dbo].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_op] UNIQUE ([pub_op]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [dbo].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [dbo].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [dbo].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [dbo].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_constraints] ADD CONSTRAINT [FK_cdcn_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [dbo].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [dbo].[contracts_db_tables] ([key_guid]);