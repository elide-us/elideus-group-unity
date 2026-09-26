-- ============================================================================
-- migrate_002_ddl_ops_models.sql
--
-- Schema additions to support DDL operations as data:
--   1. New table contracts_db_operations_models
--   2. New table contracts_db_operations_models_fields
--   3. Two new columns on contracts_db_operations
--      (ref_input_model_guid, ref_output_model_guid)
--
-- Self-describing rows are MERGE'd into contracts_db_* so the next REPL dump
-- regenerates v1.0.0_kernel.sql / v1.0.0_kernel_seed.json with everything in
-- place. Idempotent — safe to re-run.
--
-- Throwaway script. Do not check in to long-term migrations history.
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- Phase 1: physical DDL
-- ----------------------------------------------------------------------------

CREATE TABLE [dbo].[contracts_db_operations_models] (
  [key_guid]         UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name]         NVARCHAR(128) NOT NULL,
  [pub_notes]        NVARCHAR(512) NULL,
  [priv_created_on]  DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_db_operations_models]
  ADD CONSTRAINT [PK_contracts_db_operations_models] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations_models]
  ADD CONSTRAINT [UQ_cdom_name] UNIQUE ([pub_name]);
ALTER TABLE [dbo].[contracts_db_operations_models]
  ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid]);

CREATE TABLE [dbo].[contracts_db_operations_models_fields] (
  [key_guid]            UNIQUEIDENTIFIER NOT NULL,
  [ref_model_guid]      UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid]       UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid]    UNIQUEIDENTIFIER NULL,
  [pub_name]            NVARCHAR(128) NOT NULL,
  [pub_ordinal]         INT NOT NULL,
  [pub_is_nullable]     BIT DEFAULT (0) NOT NULL,
  [pub_default_value]   NVARCHAR(512) NULL,
  [pub_max_length]      INT NULL,
  [priv_created_on]     DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on]    DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_exclude_element] BIT DEFAULT (0) NOT NULL
);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [PK_contracts_db_operations_models_fields] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [UQ_cdomf_model_name] UNIQUE ([ref_model_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [UQ_cdomf_model_ordinal] UNIQUE ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [FK_cdomf_model] FOREIGN KEY ([ref_model_guid])
  REFERENCES [dbo].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [FK_cdomf_type] FOREIGN KEY ([ref_type_guid])
  REFERENCES [dbo].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
CREATE INDEX [IX_cdomf_model_guid]
  ON [dbo].[contracts_db_operations_models_fields] ([ref_model_guid]);
CREATE INDEX [IX_cdomf_type_guid]
  ON [dbo].[contracts_db_operations_models_fields] ([ref_type_guid]);

ALTER TABLE [dbo].[contracts_db_operations]
  ADD [ref_input_model_guid]  UNIQUEIDENTIFIER NULL,
      [ref_output_model_guid] UNIQUEIDENTIFIER NULL;
GO
ALTER TABLE [dbo].[contracts_db_operations]
  ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid])
  REFERENCES [dbo].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [dbo].[contracts_db_operations]
  ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid])
  REFERENCES [dbo].[contracts_db_operations_models] ([key_guid]);
GO

-- ----------------------------------------------------------------------------
-- Phase 2: self-describing rows in contracts_db_*
-- ----------------------------------------------------------------------------

-- Bump seed ordinals on existing tables to make room (11=models, 12=fields)
UPDATE contracts_db_tables SET pub_seed_element = 13
  WHERE key_guid = 'AA6A6163-FA21-5936-9499-EA4C366F6FE9';  -- service_system_configuration: 11 -> 13
UPDATE contracts_db_tables SET pub_seed_element = 14
  WHERE key_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54';  -- service_modules_manifest:     12 -> 14

-- contracts_db_tables: new rows for the two new tables
MERGE INTO [contracts_db_tables] AS T
USING (SELECT '5C245081-513A-5AC6-84CE-7746C2B43A0D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'contracts_db_operations_models',
  pub_schema = 'dbo',
  pub_alias = 'cdom',
  pub_seed_element = 11
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_schema, pub_alias, pub_seed_element)
  VALUES ('5C245081-513A-5AC6-84CE-7746C2B43A0D', 'contracts_db_operations_models', 'dbo', 'cdom', 11);

MERGE INTO [contracts_db_tables] AS T
USING (SELECT '70607B20-5E4D-5109-9B71-E3BCC68D5261' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'contracts_db_operations_models_fields',
  pub_schema = 'dbo',
  pub_alias = 'cdomf',
  pub_seed_element = 12
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_schema, pub_alias, pub_seed_element)
  VALUES ('70607B20-5E4D-5109-9B71-E3BCC68D5261', 'contracts_db_operations_models_fields', 'dbo', 'cdomf', 12);

-- contracts_db_columns: rows describing contracts_db_operations_models
MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('AEE57CBE-3FC2-51D4-89C8-2C6F7A703413', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '336C25E7-0184-5B88-A96A-C02C4AC0DDEC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 2,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('336C25E7-0184-5B88-A96A-C02C4AC0DDEC', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 2, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'BA65ED8C-4E15-5E75-BC1A-5AA36B594E72' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('BA65ED8C-4E15-5E75-BC1A-5AA36B594E72', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '42E11BF0-9825-5194-A2EB-71256085BDF2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_notes',
  pub_ordinal = 4,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 512
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('42E11BF0-9825-5194-A2EB-71256085BDF2', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_notes', 4, 1, NULL, 512);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '8D35CFBB-9257-5C39-86DF-027B731C39DB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_created_on',
  pub_ordinal = 5,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8D35CFBB-9257-5C39-86DF-027B731C39DB', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_created_on', 5, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '6B1B7790-20B7-5960-8206-F0B6924CA15A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_modified_on',
  pub_ordinal = 6,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6B1B7790-20B7-5960-8206-F0B6924CA15A', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_modified_on', 6, 0, 'SYSDATETIMEOFFSET()', NULL);

-- contracts_db_columns: rows describing contracts_db_operations_models_fields
MERGE INTO [contracts_db_columns] AS T
USING (SELECT '7ED3AECB-5411-512A-8326-7CA751ACC20F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('7ED3AECB-5411-512A-8326-7CA751ACC20F', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '312E41D1-D99A-5336-BA86-D61E37562EA5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_model_guid',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('312E41D1-D99A-5336-BA86-D61E37562EA5', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_model_guid', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'A39D9CF1-AEBA-5776-81D2-3169685CA83B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_type_guid',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A39D9CF1-AEBA-5776-81D2-3169685CA83B', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_type_guid', 3, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '5AF81866-1BF7-500C-A7FE-43C32E077B70' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 4,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('5AF81866-1BF7-500C-A7FE-43C32E077B70', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 4, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '0B3BB6D9-D5D8-5A93-95D8-C847276655B1' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 5,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('0B3BB6D9-D5D8-5A93-95D8-C847276655B1', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 5, 0, NULL, 128);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '884CF9F8-1F4E-5E6F-A337-68E29F3F5D3C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_ordinal',
  pub_ordinal = 6,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('884CF9F8-1F4E-5E6F-A337-68E29F3F5D3C', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_ordinal', 6, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'D5D79AE6-A766-5087-818B-2656F54EE88A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_is_nullable',
  pub_ordinal = 7,
  pub_is_nullable = 0,
  pub_default_value = '0',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('D5D79AE6-A766-5087-818B-2656F54EE88A', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_is_nullable', 7, 0, '0', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '26545B8A-3EA3-59C3-9896-72B911CEF4A1' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_default_value',
  pub_ordinal = 8,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 512
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('26545B8A-3EA3-59C3-9896-72B911CEF4A1', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_default_value', 8, 1, NULL, 512);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '8C405C87-B923-59B7-AE4B-579B2D3EF396' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_max_length',
  pub_ordinal = 9,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8C405C87-B923-59B7-AE4B-579B2D3EF396', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_max_length', 9, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '6F2B83B4-3032-5612-BB5A-5CA716F264E2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_created_on',
  pub_ordinal = 10,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6F2B83B4-3032-5612-BB5A-5CA716F264E2', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_created_on', 10, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '275AAC06-AB1D-512D-8DEA-4C998CED0244' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_modified_on',
  pub_ordinal = 11,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('275AAC06-AB1D-512D-8DEA-4C998CED0244', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_modified_on', 11, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'A901C065-6F2E-5267-BA2B-7FC307F4B053' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_exclude_element',
  pub_ordinal = 12,
  pub_is_nullable = 0,
  pub_default_value = '0',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A901C065-6F2E-5267-BA2B-7FC307F4B053', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_exclude_element', 12, 0, '0', NULL);

-- contracts_db_columns: two new rows on contracts_db_operations
MERGE INTO [contracts_db_columns] AS T
USING (SELECT '8523EF33-A8BD-5AEA-BC60-D11C8C520A88' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '77B59E48-CE4F-5B1B-B3A5-E895F35317AE',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_input_model_guid',
  pub_ordinal = 11,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8523EF33-A8BD-5AEA-BC60-D11C8C520A88', '77B59E48-CE4F-5B1B-B3A5-E895F35317AE', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_input_model_guid', 11, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '4B7DCD53-33B1-53D6-8351-FFECE1C52CD6' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '77B59E48-CE4F-5B1B-B3A5-E895F35317AE',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_output_model_guid',
  pub_ordinal = 12,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('4B7DCD53-33B1-53D6-8351-FFECE1C52CD6', '77B59E48-CE4F-5B1B-B3A5-E895F35317AE', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_output_model_guid', 12, 1, NULL, NULL);

-- contracts_db_indexes: helper indexes on contracts_db_operations_models_fields
MERGE INTO [contracts_db_indexes] AS T
USING (SELECT '19325C54-62DA-5D81-8621-B95D771C84CF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  pub_name = 'IX_cdomf_model_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('19325C54-62DA-5D81-8621-B95D771C84CF', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'IX_cdomf_model_guid', 0);

MERGE INTO [contracts_db_indexes] AS T
USING (SELECT '00694546-4D6C-537E-A446-86BE77F865CB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  pub_name = 'IX_cdomf_type_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('00694546-4D6C-537E-A446-86BE77F865CB', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'IX_cdomf_type_guid', 0);

-- contracts_db_index_columns
MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT '2F4C79B4-E707-5C73-B021-174104438EC5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = '19325C54-62DA-5D81-8621-B95D771C84CF',
  ref_column_guid = '312E41D1-D99A-5336-BA86-D61E37562EA5',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('2F4C79B4-E707-5C73-B021-174104438EC5', '19325C54-62DA-5D81-8621-B95D771C84CF', '312E41D1-D99A-5336-BA86-D61E37562EA5', 1);

MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT 'A6AD52D6-4627-53CF-8615-0405BB6A0D6F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = '00694546-4D6C-537E-A446-86BE77F865CB',
  ref_column_guid = 'A39D9CF1-AEBA-5776-81D2-3169685CA83B',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('A6AD52D6-4627-53CF-8615-0405BB6A0D6F', '00694546-4D6C-537E-A446-86BE77F865CB', 'A39D9CF1-AEBA-5776-81D2-3169685CA83B', 1);

-- contracts_db_constraints: new rows
MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '4AF19039-5825-5FAA-84A0-7ADF9E573743' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_kind_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_referenced_table_guid = NULL,
  pub_name = 'PK_contracts_db_operations_models',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('4AF19039-5825-5FAA-84A0-7ADF9E573743', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '3426C194-B912-5F71-802F-566E2FF1E8FF', NULL, 'PK_contracts_db_operations_models', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '02C3FAC3-4703-5BAF-84D6-A0207B8D30F8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_cdom_name',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('02C3FAC3-4703-5BAF-84D6-A0207B8D30F8', '5C245081-513A-5AC6-84CE-7746C2B43A0D', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_cdom_name', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'A507F07C-4539-50D4-A5C5-E0C27D0BA7E0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54',
  pub_name = 'FK_cdom_package',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('A507F07C-4539-50D4-A5C5-E0C27D0BA7E0', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '855F0DA4-6700-5402-BE81-2ECC543BFB54', 'FK_cdom_package', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '6C7E3F97-7AA7-5DE6-9772-DA86BF4C9A0F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_referenced_table_guid = NULL,
  pub_name = 'PK_contracts_db_operations_models_fields',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('6C7E3F97-7AA7-5DE6-9772-DA86BF4C9A0F', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '3426C194-B912-5F71-802F-566E2FF1E8FF', NULL, 'PK_contracts_db_operations_models_fields', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'FCC055AF-F4D6-509E-A565-259178C3870A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_cdomf_model_name',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('FCC055AF-F4D6-509E-A565-259178C3870A', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_cdomf_model_name', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'BCFAD9C8-CEA5-5319-880A-F298A67ECB45' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_cdomf_model_ordinal',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('BCFAD9C8-CEA5-5319-880A-F298A67ECB45', '70607B20-5E4D-5109-9B71-E3BCC68D5261', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_cdomf_model_ordinal', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '4D75DC6B-6320-5062-BB15-6DDA49C0742C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  pub_name = 'FK_cdomf_model',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('4D75DC6B-6320-5062-BB15-6DDA49C0742C', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'FK_cdomf_model', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '4AF62A14-D8E9-5674-927F-366D6EEFFC29' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = 'B7213805-2910-5427-A2BB-6B12CA1C15DF',
  pub_name = 'FK_cdomf_type',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('4AF62A14-D8E9-5674-927F-366D6EEFFC29', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'B6ABA725-1FDB-5454-B164-DDBE11079598', 'B7213805-2910-5427-A2BB-6B12CA1C15DF', 'FK_cdomf_type', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'A23F4F13-A431-5F5F-8E96-AF02D9911E85' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '70607B20-5E4D-5109-9B71-E3BCC68D5261',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54',
  pub_name = 'FK_cdomf_package',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('A23F4F13-A431-5F5F-8E96-AF02D9911E85', '70607B20-5E4D-5109-9B71-E3BCC68D5261', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '855F0DA4-6700-5402-BE81-2ECC543BFB54', 'FK_cdomf_package', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'A0441D6F-FB8A-518A-82A8-BC6830449309' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '77B59E48-CE4F-5B1B-B3A5-E895F35317AE',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  pub_name = 'FK_cdo_input_model',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('A0441D6F-FB8A-518A-82A8-BC6830449309', '77B59E48-CE4F-5B1B-B3A5-E895F35317AE', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'FK_cdo_input_model', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '2F687BCA-0C16-54F6-801E-E3718E59E684' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '77B59E48-CE4F-5B1B-B3A5-E895F35317AE',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '5C245081-513A-5AC6-84CE-7746C2B43A0D',
  pub_name = 'FK_cdo_output_model',
  pub_expression = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression)
  VALUES ('2F687BCA-0C16-54F6-801E-E3718E59E684', '77B59E48-CE4F-5B1B-B3A5-E895F35317AE', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '5C245081-513A-5AC6-84CE-7746C2B43A0D', 'FK_cdo_output_model', NULL);

-- contracts_db_constraint_columns: column membership rows
MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '9AA00AD2-60CC-57BE-B7B9-5A73F23A0BC5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '4AF19039-5825-5FAA-84A0-7ADF9E573743',
  ref_column_guid = 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('9AA00AD2-60CC-57BE-B7B9-5A73F23A0BC5', '4AF19039-5825-5FAA-84A0-7ADF9E573743', 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '13E8E206-A640-5A84-8318-95995BA2F324' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '02C3FAC3-4703-5BAF-84D6-A0207B8D30F8',
  ref_column_guid = 'BA65ED8C-4E15-5E75-BC1A-5AA36B594E72',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('13E8E206-A640-5A84-8318-95995BA2F324', '02C3FAC3-4703-5BAF-84D6-A0207B8D30F8', 'BA65ED8C-4E15-5E75-BC1A-5AA36B594E72', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '80933E8C-6BF0-5C47-9992-D8D833FA2E94' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'A507F07C-4539-50D4-A5C5-E0C27D0BA7E0',
  ref_column_guid = '336C25E7-0184-5B88-A96A-C02C4AC0DDEC',
  ref_referenced_column_guid = '131404F3-E1C4-5F57-BCB5-8A62B90CED0F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('80933E8C-6BF0-5C47-9992-D8D833FA2E94', 'A507F07C-4539-50D4-A5C5-E0C27D0BA7E0', '336C25E7-0184-5B88-A96A-C02C4AC0DDEC', '131404F3-E1C4-5F57-BCB5-8A62B90CED0F', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '96E9E8BE-5765-5D42-BBE2-ACCF7B12F80D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '6C7E3F97-7AA7-5DE6-9772-DA86BF4C9A0F',
  ref_column_guid = '7ED3AECB-5411-512A-8326-7CA751ACC20F',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('96E9E8BE-5765-5D42-BBE2-ACCF7B12F80D', '6C7E3F97-7AA7-5DE6-9772-DA86BF4C9A0F', '7ED3AECB-5411-512A-8326-7CA751ACC20F', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '3C4DE436-0BBC-5E42-BC61-2B1450060694' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'FCC055AF-F4D6-509E-A565-259178C3870A',
  ref_column_guid = '312E41D1-D99A-5336-BA86-D61E37562EA5',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('3C4DE436-0BBC-5E42-BC61-2B1450060694', 'FCC055AF-F4D6-509E-A565-259178C3870A', '312E41D1-D99A-5336-BA86-D61E37562EA5', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '749D279E-BB3F-5829-8ED6-9CEEA028C2B3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'FCC055AF-F4D6-509E-A565-259178C3870A',
  ref_column_guid = '0B3BB6D9-D5D8-5A93-95D8-C847276655B1',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 2
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('749D279E-BB3F-5829-8ED6-9CEEA028C2B3', 'FCC055AF-F4D6-509E-A565-259178C3870A', '0B3BB6D9-D5D8-5A93-95D8-C847276655B1', NULL, 2);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'BB205953-F745-53FA-B5D9-703FA1AC3030' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'BCFAD9C8-CEA5-5319-880A-F298A67ECB45',
  ref_column_guid = '312E41D1-D99A-5336-BA86-D61E37562EA5',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('BB205953-F745-53FA-B5D9-703FA1AC3030', 'BCFAD9C8-CEA5-5319-880A-F298A67ECB45', '312E41D1-D99A-5336-BA86-D61E37562EA5', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'EE7409E0-BB10-595E-864F-6232D23A225A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'BCFAD9C8-CEA5-5319-880A-F298A67ECB45',
  ref_column_guid = '884CF9F8-1F4E-5E6F-A337-68E29F3F5D3C',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 2
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('EE7409E0-BB10-595E-864F-6232D23A225A', 'BCFAD9C8-CEA5-5319-880A-F298A67ECB45', '884CF9F8-1F4E-5E6F-A337-68E29F3F5D3C', NULL, 2);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'FD4A6D30-605E-5010-9F2E-D123E6661886' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '4D75DC6B-6320-5062-BB15-6DDA49C0742C',
  ref_column_guid = '312E41D1-D99A-5336-BA86-D61E37562EA5',
  ref_referenced_column_guid = 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('FD4A6D30-605E-5010-9F2E-D123E6661886', '4D75DC6B-6320-5062-BB15-6DDA49C0742C', '312E41D1-D99A-5336-BA86-D61E37562EA5', 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'C134E23D-B320-598F-A1B0-939ADDD773A6' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '4AF62A14-D8E9-5674-927F-366D6EEFFC29',
  ref_column_guid = 'A39D9CF1-AEBA-5776-81D2-3169685CA83B',
  ref_referenced_column_guid = '342331DE-3D99-5422-BBE5-09F22583AE8E',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('C134E23D-B320-598F-A1B0-939ADDD773A6', '4AF62A14-D8E9-5674-927F-366D6EEFFC29', 'A39D9CF1-AEBA-5776-81D2-3169685CA83B', '342331DE-3D99-5422-BBE5-09F22583AE8E', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'ED117813-2290-5183-9350-F87C6E1F9688' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'A23F4F13-A431-5F5F-8E96-AF02D9911E85',
  ref_column_guid = '5AF81866-1BF7-500C-A7FE-43C32E077B70',
  ref_referenced_column_guid = '131404F3-E1C4-5F57-BCB5-8A62B90CED0F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('ED117813-2290-5183-9350-F87C6E1F9688', 'A23F4F13-A431-5F5F-8E96-AF02D9911E85', '5AF81866-1BF7-500C-A7FE-43C32E077B70', '131404F3-E1C4-5F57-BCB5-8A62B90CED0F', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '3F5B4493-4E58-573E-B1BF-AF878A75A3AC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'A0441D6F-FB8A-518A-82A8-BC6830449309',
  ref_column_guid = '8523EF33-A8BD-5AEA-BC60-D11C8C520A88',
  ref_referenced_column_guid = 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('3F5B4493-4E58-573E-B1BF-AF878A75A3AC', 'A0441D6F-FB8A-518A-82A8-BC6830449309', '8523EF33-A8BD-5AEA-BC60-D11C8C520A88', 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '4D4F992E-9D4C-5283-9DD0-085DB4823D39' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '2F687BCA-0C16-54F6-801E-E3718E59E684',
  ref_column_guid = '4B7DCD53-33B1-53D6-8351-FFECE1C52CD6',
  ref_referenced_column_guid = 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('4D4F992E-9D4C-5283-9DD0-085DB4823D39', '2F687BCA-0C16-54F6-801E-E3718E59E684', '4B7DCD53-33B1-53D6-8351-FFECE1C52CD6', 'AEE57CBE-3FC2-51D4-89C8-2C6F7A703413', 1);

-- ============================================================================
-- Done. Run REPL dump next to regenerate v1.0.0_kernel.sql and seed.
-- ============================================================================









-- ============================================================================
-- migrate_003_resolve_package_op.sql
--
-- POC migration: move the first DDL/introspection query from scriptlib.py
-- into contracts_db_operations as data.
--
-- Source query: _resolve_package() in scripts/scriptlib.py
--   "SELECT key_guid, pub_name, pub_version, pub_is_sealed
--    FROM service_modules_manifest WHERE pub_name = ?
--    FOR JSON PATH"
--
-- This adds:
--   1. Two model rows in contracts_db_operations_models:
--        - resolve_package_input  (1 field: pub_name)
--        - resolve_package_output (4 fields: manifest projection)
--   2. Five field rows in contracts_db_operations_models_fields.
--   3. One operation row in contracts_db_operations with URN
--        db:contracts:db:resolve_package:1
--      and ref_input_model_guid / ref_output_model_guid wired up.
--
-- Throwaway script. MERGE-based, idempotent.
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- Models
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '2E612695-4565-55ED-B3C5-2300FFA66485' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'resolve_package_input',
  pub_notes = 'Input model for db:contracts:db:resolve_package:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES (
    '2E612695-4565-55ED-B3C5-2300FFA66485',
    'resolve_package_input',
    'Input model for db:contracts:db:resolve_package:1.'
  );

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '5E41725A-40CC-5CF0-8473-D19CC7EAE966' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'resolve_package_output',
  pub_notes = 'Output model for db:contracts:db:resolve_package:1. Projection of service_modules_manifest.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES (
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
    'resolve_package_output',
    'Output model for db:contracts:db:resolve_package:1. Projection of service_modules_manifest.'
  );

-- ----------------------------------------------------------------------------
-- Model fields
-- Type GUIDs (from kernel):
--   STRING       8579BB4B-746B-5E4B-867B-BFB182D52110  (pub_emits_length=1)
--   UUID         DF427A75-F5DE-5797-988A-F2FF40BD7FA5
--   BOOL         72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC
-- ----------------------------------------------------------------------------

-- resolve_package_input.pub_name : STRING(256)
MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B9C41171-9266-5284-992A-6B9E63171499' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '2E612695-4565-55ED-B3C5-2300FFA66485',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT
  (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES (
    'B9C41171-9266-5284-992A-6B9E63171499',
    '2E612695-4565-55ED-B3C5-2300FFA66485',
    '8579BB4B-746B-5E4B-867B-BFB182D52110',
    'pub_name', 1, 0, NULL, 256
  );

-- resolve_package_output.key_guid : UUID
MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '71C1651E-695E-5993-A763-8D2481520E6A' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES (
    '71C1651E-695E-5993-A763-8D2481520E6A',
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
    'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
    'key_guid', 1, 0, NULL, NULL
  );

-- resolve_package_output.pub_name : STRING(256)
MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'A9F8738B-7ED1-52BE-B24A-9F3606FDCD99' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT
  (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES (
    'A9F8738B-7ED1-52BE-B24A-9F3606FDCD99',
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
    '8579BB4B-746B-5E4B-867B-BFB182D52110',
    'pub_name', 2, 0, NULL, 256
  );

-- resolve_package_output.pub_version : STRING(64)
MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '5508897D-E8AF-5CFD-9D39-1A03C3E5E513' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_version',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT
  (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES (
    '5508897D-E8AF-5CFD-9D39-1A03C3E5E513',
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
    '8579BB4B-746B-5E4B-867B-BFB182D52110',
    'pub_version', 3, 0, NULL, 64
  );

-- resolve_package_output.pub_is_sealed : BOOL
MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '904A2296-E5C1-5775-8DD2-1B1649B3106D' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_is_sealed',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES (
    '904A2296-E5C1-5775-8DD2-1B1649B3106D',
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966',
    '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
    'pub_is_sealed', 4, 0, NULL, NULL
  );

-- ----------------------------------------------------------------------------
-- Operation row
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations] AS T
USING (SELECT 'A7B7D229-9832-5BF8-8A79-C0D317E3DC87' AS key_guid) AS S
  ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:resolve_package:1',
  pub_query_mssql = 'SELECT key_guid, pub_name, pub_version, pub_is_sealed FROM service_modules_manifest WHERE pub_name = ? FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Resolve a package by pub_name. Returns 0 or 1 row. Used by uninstall and other install-pipeline introspection.',
  ref_input_model_guid = '2E612695-4565-55ED-B3C5-2300FFA66485',
  ref_output_model_guid = '5E41725A-40CC-5CF0-8473-D19CC7EAE966'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES (
    'A7B7D229-9832-5BF8-8A79-C0D317E3DC87',
    'db:contracts:db:resolve_package:1',
    'SELECT key_guid, pub_name, pub_version, pub_is_sealed FROM service_modules_manifest WHERE pub_name = ? FOR JSON PATH',
    NULL,
    NULL,
    1,
    'Resolve a package by pub_name. Returns 0 or 1 row. Used by uninstall and other install-pipeline introspection.',
    '2E612695-4565-55ED-B3C5-2300FFA66485',
    '5E41725A-40CC-5CF0-8473-D19CC7EAE966'
  );

-- ============================================================================
-- Done. After run, the dump won't pick this up automatically — these are
-- data rows, not schema rows. Inspect with:
--
-- SELECT pub_op, pub_query_mssql FROM contracts_db_operations
--  WHERE pub_op = 'db:contracts:db:resolve_package:1';

-- SELECT m.pub_name AS model, f.pub_ordinal, f.pub_name, t.pub_name AS type, f.pub_max_length
--   FROM contracts_db_operations_models_fields f
--   JOIN contracts_db_operations_models m ON f.ref_model_guid = m.key_guid
--   JOIN contracts_primitives_types t ON f.ref_type_guid = t.key_guid
--   WHERE m.pub_name IN ('resolve_package_input', 'resolve_package_output')
--  ORDER BY m.pub_name, f.pub_ordinal;
-- ============================================================================








-- WORK FROM HERE ---



-- ============================================================================
-- migrate_004_engines_and_cascade.sql
--
-- Adds the cross-engine token mapping infrastructure (engines + two
-- mapping tables), introduces the constraint_disposition enum, adds
-- pub_delete_disposition on contracts_db_constraints, and switches the 10
-- FK_*_package constraints to ON DELETE CASCADE so uninstall can rely on
-- the database to walk the FK graph.
--
-- Three new tables:
--   contracts_db_engines           — entity table, one row per engine
--   contracts_types_ddl_mapping    — junction (type, engine) -> token
--   contracts_enums_ddl_mapping    — junction (enum, engine) -> token
--
-- Enum work:
--   New enum_type 'constraint_disposition' with NO_ACTION=0, CASCADE=1,
--   SET_NULL=2, SET_DEFAULT=3.
--
-- Cascade fix:
--   Adds pub_delete_disposition TINYINT NULL on contracts_db_constraints.
--   Marks the 10 FK_*_package constraint rows with value 1 (CASCADE).
--   Drops and re-adds those 10 FKs in the live database with ON DELETE
--   CASCADE, so uninstall reduces to a single DELETE on the manifest row.
--
-- Additive only: parallel engine columns on contracts_primitives_types
-- and contracts_db_operations remain untouched. The new mapping tables
-- duplicate the data; consumers can migrate at their own pace; the
-- redundant columns can be dropped in a future migration.
--
-- Throwaway script. MERGE-based, idempotent.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- Phase 1: physical DDL
-- ----------------------------------------------------------------------------

CREATE TABLE [dbo].[contracts_db_engines] (
  [key_guid]         UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name]         NVARCHAR(64)  NOT NULL,
  [pub_value]        TINYINT NOT NULL,
  [pub_notes]        NVARCHAR(512) NULL,
  [priv_created_on]  DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_db_engines]
  ADD CONSTRAINT [PK_contracts_db_engines] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_db_engines]
  ADD CONSTRAINT [UQ_cde_name] UNIQUE ([pub_name]);
ALTER TABLE [dbo].[contracts_db_engines]
  ADD CONSTRAINT [UQ_cde_value] UNIQUE ([pub_value]);
ALTER TABLE [dbo].[contracts_db_engines]
  ADD CONSTRAINT [FK_cde_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;

CREATE TABLE [dbo].[contracts_types_ddl_mapping] (
  [key_guid]         UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_type_guid]    UNIQUEIDENTIFIER NOT NULL,
  [ref_engine_guid]  UNIQUEIDENTIFIER NOT NULL,
  [pub_ddl_token]    NVARCHAR(128) NULL,
  [priv_created_on]  DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_types_ddl_mapping]
  ADD CONSTRAINT [PK_contracts_types_ddl_mapping] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_types_ddl_mapping]
  ADD CONSTRAINT [UQ_ctddm_type_engine] UNIQUE ([ref_type_guid], [ref_engine_guid]);
ALTER TABLE [dbo].[contracts_types_ddl_mapping]
  ADD CONSTRAINT [FK_ctddm_type] FOREIGN KEY ([ref_type_guid])
  REFERENCES [dbo].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [dbo].[contracts_types_ddl_mapping]
  ADD CONSTRAINT [FK_ctddm_engine] FOREIGN KEY ([ref_engine_guid])
  REFERENCES [dbo].[contracts_db_engines] ([key_guid]);
ALTER TABLE [dbo].[contracts_types_ddl_mapping]
  ADD CONSTRAINT [FK_ctddm_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
CREATE INDEX [IX_ctddm_type_guid]
  ON [dbo].[contracts_types_ddl_mapping] ([ref_type_guid]);
CREATE INDEX [IX_ctddm_engine_guid]
  ON [dbo].[contracts_types_ddl_mapping] ([ref_engine_guid]);

CREATE TABLE [dbo].[contracts_enums_ddl_mapping] (
  [key_guid]         UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_enum_guid]    UNIQUEIDENTIFIER NOT NULL,
  [ref_engine_guid]  UNIQUEIDENTIFIER NOT NULL,
  [pub_ddl_token]    NVARCHAR(128) NULL,
  [priv_created_on]  DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_enums_ddl_mapping]
  ADD CONSTRAINT [PK_contracts_enums_ddl_mapping] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_enums_ddl_mapping]
  ADD CONSTRAINT [UQ_ceddm_enum_engine] UNIQUE ([ref_enum_guid], [ref_engine_guid]);
ALTER TABLE [dbo].[contracts_enums_ddl_mapping]
  ADD CONSTRAINT [FK_ceddm_enum] FOREIGN KEY ([ref_enum_guid])
  REFERENCES [dbo].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[contracts_enums_ddl_mapping]
  ADD CONSTRAINT [FK_ceddm_engine] FOREIGN KEY ([ref_engine_guid])
  REFERENCES [dbo].[contracts_db_engines] ([key_guid]);
ALTER TABLE [dbo].[contracts_enums_ddl_mapping]
  ADD CONSTRAINT [FK_ceddm_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
CREATE INDEX [IX_ceddm_enum_guid]
  ON [dbo].[contracts_enums_ddl_mapping] ([ref_enum_guid]);
CREATE INDEX [IX_ceddm_engine_guid]
  ON [dbo].[contracts_enums_ddl_mapping] ([ref_engine_guid]);

-- New column on contracts_db_constraints
ALTER TABLE [dbo].[contracts_db_constraints]
  ADD [pub_delete_disposition] TINYINT NULL;
GO

-- ----------------------------------------------------------------------------
-- Phase 2: engine rows
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_engines] AS T
USING (SELECT '1479A929-D1BF-565D-97B6-FFF277967653' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'mssql',
  pub_value = 1,
  pub_notes = 'Microsoft SQL Server (incl. Azure SQL).'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_value, pub_notes)
  VALUES ('1479A929-D1BF-565D-97B6-FFF277967653', 'mssql', 1, 'Microsoft SQL Server (incl. Azure SQL).');

MERGE INTO [contracts_db_engines] AS T
USING (SELECT '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'postgres',
  pub_value = 2,
  pub_notes = 'PostgreSQL.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_value, pub_notes)
  VALUES ('0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'postgres', 2, 'PostgreSQL.');

MERGE INTO [contracts_db_engines] AS T
USING (SELECT '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'mysql',
  pub_value = 3,
  pub_notes = 'MySQL.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_value, pub_notes)
  VALUES ('55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'mysql', 3, 'MySQL.');

-- ----------------------------------------------------------------------------
-- Phase 3: contracts_types_ddl_mapping rows (backfilled from existing
-- parallel-engine columns on contracts_primitives_types)
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'FF76C077-47F7-5F59-AF3C-2DEBD33391DA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'TINYINT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('FF76C077-47F7-5F59-AF3C-2DEBD33391DA', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', '1479A929-D1BF-565D-97B6-FFF277967653', 'TINYINT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '747C81CE-3744-56C9-BA3A-88A6A4677D75' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'smallint'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('747C81CE-3744-56C9-BA3A-88A6A4677D75', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'smallint');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'FC9126A4-8FB2-5D9F-ABB5-5EDD05368DFD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'tinyint unsigned'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('FC9126A4-8FB2-5D9F-ABB5-5EDD05368DFD', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'tinyint unsigned');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '5294DD39-200D-5555-9D2B-EDA918F67BE9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'DATETIMEOFFSET(7)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('5294DD39-200D-5555-9D2B-EDA918F67BE9', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', '1479A929-D1BF-565D-97B6-FFF277967653', 'DATETIMEOFFSET(7)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'C3EC7EC1-1552-535C-95B9-C4713BFBE17F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'timestamptz'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('C3EC7EC1-1552-535C-95B9-C4713BFBE17F', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'timestamptz');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '37F6374D-DD86-5A76-A538-EF957E86F964' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'datetime(6)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('37F6374D-DD86-5A76-A538-EF957E86F964', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'datetime(6)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '2C3D1DE9-8121-5F03-B44A-BDC2920D6A40' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4B286A51-7A0B-5BA2-8391-264E572C8375',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'VARBINARY(MAX)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('2C3D1DE9-8121-5F03-B44A-BDC2920D6A40', '4B286A51-7A0B-5BA2-8391-264E572C8375', '1479A929-D1BF-565D-97B6-FFF277967653', 'VARBINARY(MAX)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'B54D4837-1D4B-5DC4-9562-69EAD8B06EF0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4B286A51-7A0B-5BA2-8391-264E572C8375',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'bytea'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('B54D4837-1D4B-5DC4-9562-69EAD8B06EF0', '4B286A51-7A0B-5BA2-8391-264E572C8375', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'bytea');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '7CB584AB-7389-5851-AA66-1BD72984FBEC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4B286A51-7A0B-5BA2-8391-264E572C8375',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'longblob'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('7CB584AB-7389-5851-AA66-1BD72984FBEC', '4B286A51-7A0B-5BA2-8391-264E572C8375', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'longblob');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'CF86CA37-8DD3-59CE-B0C6-2AEC20DCC370' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '421D6C05-ACBA-58E7-9FE3-27F500497011',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'FLOAT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('CF86CA37-8DD3-59CE-B0C6-2AEC20DCC370', '421D6C05-ACBA-58E7-9FE3-27F500497011', '1479A929-D1BF-565D-97B6-FFF277967653', 'FLOAT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'F772454A-1A5B-53A1-BFA2-D2C961790517' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '421D6C05-ACBA-58E7-9FE3-27F500497011',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'double precision'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('F772454A-1A5B-53A1-BFA2-D2C961790517', '421D6C05-ACBA-58E7-9FE3-27F500497011', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'double precision');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '2C03BD91-5F04-5996-A56E-004227289C2E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '421D6C05-ACBA-58E7-9FE3-27F500497011',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'double'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('2C03BD91-5F04-5996-A56E-004227289C2E', '421D6C05-ACBA-58E7-9FE3-27F500497011', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'double');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'A3265182-2494-5A0D-9D99-8C2E3A40EACC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '18667606-C633-5A82-9A3B-2CD27916FC95',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'SMALLINT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('A3265182-2494-5A0D-9D99-8C2E3A40EACC', '18667606-C633-5A82-9A3B-2CD27916FC95', '1479A929-D1BF-565D-97B6-FFF277967653', 'SMALLINT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'E686F5F1-7437-5AC3-AED2-3431899DA0DF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '18667606-C633-5A82-9A3B-2CD27916FC95',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'smallint'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('E686F5F1-7437-5AC3-AED2-3431899DA0DF', '18667606-C633-5A82-9A3B-2CD27916FC95', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'smallint');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'F50FA90E-087D-5FBC-8612-695FAB58EF16' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '18667606-C633-5A82-9A3B-2CD27916FC95',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'smallint'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('F50FA90E-087D-5FBC-8612-695FAB58EF16', '18667606-C633-5A82-9A3B-2CD27916FC95', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'smallint');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '581D6E11-0656-5EDF-A1C4-3DA401FB331D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4DB81F9F-8990-5952-BBEA-4E175B362CDA',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'DECIMAL(19,5)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('581D6E11-0656-5EDF-A1C4-3DA401FB331D', '4DB81F9F-8990-5952-BBEA-4E175B362CDA', '1479A929-D1BF-565D-97B6-FFF277967653', 'DECIMAL(19,5)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '3E0BDEBA-5D97-52AD-871A-3101ED5B603C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4DB81F9F-8990-5952-BBEA-4E175B362CDA',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'decimal(19,5)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('3E0BDEBA-5D97-52AD-871A-3101ED5B603C', '4DB81F9F-8990-5952-BBEA-4E175B362CDA', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'decimal(19,5)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '01D3C881-4242-5C3B-A193-F44D7168E157' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '4DB81F9F-8990-5952-BBEA-4E175B362CDA',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'decimal(19,5)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('01D3C881-4242-5C3B-A193-F44D7168E157', '4DB81F9F-8990-5952-BBEA-4E175B362CDA', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'decimal(19,5)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'E2D11C89-11AF-5E21-80D1-DF4F407A4275' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'BIT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('E2D11C89-11AF-5E21-80D1-DF4F407A4275', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', '1479A929-D1BF-565D-97B6-FFF277967653', 'BIT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '77D245C2-51A1-53C2-AB29-BFB771B4A7E4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'boolean'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('77D245C2-51A1-53C2-AB29-BFB771B4A7E4', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'boolean');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '2B14A48B-DA14-5DD3-8CA3-67FE5D6202D2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'tinyint(1)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('2B14A48B-DA14-5DD3-8CA3-67FE5D6202D2', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'tinyint(1)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'BFAEA0C5-EB36-5748-B45A-84BC3154BB13' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'NVARCHAR(MAX)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('BFAEA0C5-EB36-5748-B45A-84BC3154BB13', 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', '1479A929-D1BF-565D-97B6-FFF277967653', 'NVARCHAR(MAX)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '20DBC42C-2171-56CC-B1B1-C3A6FF77E852' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'jsonb'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('20DBC42C-2171-56CC-B1B1-C3A6FF77E852', 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'jsonb');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '14367A4F-C1CA-577C-A5A6-343E190A582F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'json'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('14367A4F-C1CA-577C-A5A6-343E190A582F', 'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'json');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'EB6AC7C2-91D5-5C2B-8734-42EFBECE3BF3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'REAL'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('EB6AC7C2-91D5-5C2B-8734-42EFBECE3BF3', 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E', '1479A929-D1BF-565D-97B6-FFF277967653', 'REAL');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '7A235D58-CED2-5BA3-BEA3-D71AF42CC280' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'real'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('7A235D58-CED2-5BA3-BEA3-D71AF42CC280', 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'real');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '6D9C2FA2-4E1A-5894-B0BE-9D9CF1772837' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'float'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('6D9C2FA2-4E1A-5894-B0BE-9D9CF1772837', 'BD61A7EA-38ED-57AC-949F-5C82A0C0173E', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'float');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '5F70B6F8-2534-5D12-91F9-B3C6CAC1C2CC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '085132BC-DDEB-5591-ACB0-7348445DC92C',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'DECIMAL(28,12)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('5F70B6F8-2534-5D12-91F9-B3C6CAC1C2CC', '085132BC-DDEB-5591-ACB0-7348445DC92C', '1479A929-D1BF-565D-97B6-FFF277967653', 'DECIMAL(28,12)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '94B90DDE-053C-522E-8E8C-53C2063AFB08' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '085132BC-DDEB-5591-ACB0-7348445DC92C',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'numeric(28,12)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('94B90DDE-053C-522E-8E8C-53C2063AFB08', '085132BC-DDEB-5591-ACB0-7348445DC92C', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'numeric(28,12)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '80D614CE-CF75-5015-A320-EF338B73FF16' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '085132BC-DDEB-5591-ACB0-7348445DC92C',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'decimal(28,12)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('80D614CE-CF75-5015-A320-EF338B73FF16', '085132BC-DDEB-5591-ACB0-7348445DC92C', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'decimal(28,12)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '7E663AEA-7E55-540D-BAEC-2704587179F1' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'BIGINT IDENTITY(1,1)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('7E663AEA-7E55-540D-BAEC-2704587179F1', '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', '1479A929-D1BF-565D-97B6-FFF277967653', 'BIGINT IDENTITY(1,1)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '24BBD7B1-E765-58F0-AD21-38B51C8D5FC0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'bigserial'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('24BBD7B1-E765-58F0-AD21-38B51C8D5FC0', '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'bigserial');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '799CE7F1-EC91-56EB-B9DB-41F46ED8E7CD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'bigint auto_increment'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('799CE7F1-EC91-56EB-B9DB-41F46ED8E7CD', '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'bigint auto_increment');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '4DD4680F-1319-531B-B06C-5CC92A4C480D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'NVARCHAR(MAX)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('4DD4680F-1319-531B-B06C-5CC92A4C480D', '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', '1479A929-D1BF-565D-97B6-FFF277967653', 'NVARCHAR(MAX)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '8044DA76-9D31-55E6-9F98-70DC999DB5A9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'text'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('8044DA76-9D31-55E6-9F98-70DC999DB5A9', '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'text');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'C6F60824-C24D-55B6-AD57-893FFEA525D8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'longtext'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('C6F60824-C24D-55B6-AD57-893FFEA525D8', '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'longtext');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '1FC776CC-BFE2-5E8B-9551-4A6056D27AA3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'INT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('1FC776CC-BFE2-5E8B-9551-4A6056D27AA3', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', '1479A929-D1BF-565D-97B6-FFF277967653', 'INT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '7103F115-AB5D-54BD-8C3F-81CDF2DE0292' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'integer'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('7103F115-AB5D-54BD-8C3F-81CDF2DE0292', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'integer');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'E2FC252A-0A3B-5AFC-BD74-8687BFBEA257' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'int'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('E2FC252A-0A3B-5AFC-BD74-8687BFBEA257', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'int');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'AFFC87D3-E355-5023-903F-C8D53E7BB624' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '53434CAA-A382-5B45-BAD2-AC3F655ED3A0',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'DECIMAL(38,18)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('AFFC87D3-E355-5023-903F-C8D53E7BB624', '53434CAA-A382-5B45-BAD2-AC3F655ED3A0', '1479A929-D1BF-565D-97B6-FFF277967653', 'DECIMAL(38,18)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '0556F54A-1256-5EA4-A83E-2C0809EF5958' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '53434CAA-A382-5B45-BAD2-AC3F655ED3A0',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'numeric(38,18)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('0556F54A-1256-5EA4-A83E-2C0809EF5958', '53434CAA-A382-5B45-BAD2-AC3F655ED3A0', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'numeric(38,18)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'A564B00A-B2D5-57A7-AB21-5DEAAA15D2E5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '53434CAA-A382-5B45-BAD2-AC3F655ED3A0',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'decimal(38,18)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('A564B00A-B2D5-57A7-AB21-5DEAAA15D2E5', '53434CAA-A382-5B45-BAD2-AC3F655ED3A0', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'decimal(38,18)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '4D248FB0-834C-5760-A80B-6C7B57E16A80' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'NVARCHAR'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('4D248FB0-834C-5760-A80B-6C7B57E16A80', '8579BB4B-746B-5E4B-867B-BFB182D52110', '1479A929-D1BF-565D-97B6-FFF277967653', 'NVARCHAR');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'AC24EDCF-9856-5AE6-B548-7BB57BD0909E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'varchar'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('AC24EDCF-9856-5AE6-B548-7BB57BD0909E', '8579BB4B-746B-5E4B-867B-BFB182D52110', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'varchar');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '40542E3F-A17A-54A2-B20E-389640ED5C1E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'varchar'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('40542E3F-A17A-54A2-B20E-389640ED5C1E', '8579BB4B-746B-5E4B-867B-BFB182D52110', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'varchar');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '19720837-F9F5-5BE8-8D1C-409B784EE69E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'BIGINT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('19720837-F9F5-5BE8-8D1C-409B784EE69E', 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A', '1479A929-D1BF-565D-97B6-FFF277967653', 'BIGINT');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '096E8AF6-1E48-56F7-A72E-14671F348790' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'bigint'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('096E8AF6-1E48-56F7-A72E-14671F348790', 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'bigint');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '400A2E7D-C36B-530F-AC68-BB3D49F9F37D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'bigint'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('400A2E7D-C36B-530F-AC68-BB3D49F9F37D', 'B96336CD-D4A0-5B24-920E-C818BDC4AE7A', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'bigint');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'FF5DD4A4-88DD-5D7B-B5E4-E7262BA05E99' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'DATE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('FF5DD4A4-88DD-5D7B-B5E4-E7262BA05E99', 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', '1479A929-D1BF-565D-97B6-FFF277967653', 'DATE');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '0EB4F475-6FCD-5B33-AE2D-F630B3E2ED24' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'date'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('0EB4F475-6FCD-5B33-AE2D-F630B3E2ED24', 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'date');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'DABA3725-5204-577A-AD33-65DDCF6638F5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'date'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('DABA3725-5204-577A-AD33-65DDCF6638F5', 'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'date');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '98BF8F83-16D1-5D90-96E5-E50E03462B8E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'UNIQUEIDENTIFIER'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('98BF8F83-16D1-5D90-96E5-E50E03462B8E', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', '1479A929-D1BF-565D-97B6-FFF277967653', 'UNIQUEIDENTIFIER');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT '1FE744A3-2448-55DC-A679-7129E6118C4E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'uuid'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('1FE744A3-2448-55DC-A679-7129E6118C4E', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'uuid');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'E6D08674-CC48-525F-AA40-A274E6B22495' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'char(36)'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('E6D08674-CC48-525F-AA40-A274E6B22495', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'char(36)');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'F5DF0021-6924-5AF5-BA81-66FA2010E8B5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'VECTOR'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('F5DF0021-6924-5AF5-BA81-66FA2010E8B5', 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A', '1479A929-D1BF-565D-97B6-FFF277967653', 'VECTOR');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'E9A88F7E-4C39-5D5F-B874-8E4EB78A20AD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'vector'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('E9A88F7E-4C39-5D5F-B874-8E4EB78A20AD', 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'vector');

MERGE INTO [contracts_types_ddl_mapping] AS T
USING (SELECT 'CCCFB3D6-5C95-59E6-8B8F-447486721F69' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_type_guid = 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'vector'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_type_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('CCCFB3D6-5C95-59E6-8B8F-447486721F69', 'F4CF3C0D-908E-5682-8FE7-F9973B90C56A', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'vector');

-- ----------------------------------------------------------------------------
-- Phase 4: contracts_enums_ddl_mapping rows for constraint_kind
-- All three engines emit the same DDL keywords here, but the rows make
-- that explicit rather than implicit.
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '48806798-8825-5ECF-95BA-B40258984675' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'PRIMARY KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('48806798-8825-5ECF-95BA-B40258984675', '3426C194-B912-5F71-802F-566E2FF1E8FF', '1479A929-D1BF-565D-97B6-FFF277967653', 'PRIMARY KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '81F0EE61-744C-559B-AEA7-961F04B74CA7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'PRIMARY KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('81F0EE61-744C-559B-AEA7-961F04B74CA7', '3426C194-B912-5F71-802F-566E2FF1E8FF', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'PRIMARY KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'F3D3CD08-B849-577D-B6F2-0322298723DB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'PRIMARY KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('F3D3CD08-B849-577D-B6F2-0322298723DB', '3426C194-B912-5F71-802F-566E2FF1E8FF', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'PRIMARY KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'D595F918-8123-5E2E-A606-C5BB857ED54D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'UNIQUE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('D595F918-8123-5E2E-A606-C5BB857ED54D', '4D75333D-E472-5813-A03B-C0162671A00D', '1479A929-D1BF-565D-97B6-FFF277967653', 'UNIQUE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '72968652-409D-5E10-8EF2-E8514108AA9F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'UNIQUE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('72968652-409D-5E10-8EF2-E8514108AA9F', '4D75333D-E472-5813-A03B-C0162671A00D', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'UNIQUE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'AE9B06B1-2E96-5404-9B92-6F8C16FA1065' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'UNIQUE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('AE9B06B1-2E96-5404-9B92-6F8C16FA1065', '4D75333D-E472-5813-A03B-C0162671A00D', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'UNIQUE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'FA923DDD-E9F4-53FD-BA64-D8C730DC14D5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'FOREIGN KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('FA923DDD-E9F4-53FD-BA64-D8C730DC14D5', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '1479A929-D1BF-565D-97B6-FFF277967653', 'FOREIGN KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '9DC5DF05-61FB-5EBB-8620-B4CEB7ECB43C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'FOREIGN KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('9DC5DF05-61FB-5EBB-8620-B4CEB7ECB43C', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'FOREIGN KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'ADE35BAE-9BBC-5530-9699-A117CE1CF187' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'FOREIGN KEY'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('ADE35BAE-9BBC-5530-9699-A117CE1CF187', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'FOREIGN KEY');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'C703823B-3894-5104-B868-E5DD5CC66ABE' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '92400F11-FCFD-5285-B9E2-D682B2496A88',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'CHECK'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('C703823B-3894-5104-B868-E5DD5CC66ABE', '92400F11-FCFD-5285-B9E2-D682B2496A88', '1479A929-D1BF-565D-97B6-FFF277967653', 'CHECK');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '49BAF326-30B3-52FC-B17B-2675A968BD71' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '92400F11-FCFD-5285-B9E2-D682B2496A88',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'CHECK'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('49BAF326-30B3-52FC-B17B-2675A968BD71', '92400F11-FCFD-5285-B9E2-D682B2496A88', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'CHECK');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '97734317-FDC7-5213-8C24-046D4BA5EBB3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '92400F11-FCFD-5285-B9E2-D682B2496A88',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'CHECK'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('97734317-FDC7-5213-8C24-046D4BA5EBB3', '92400F11-FCFD-5285-B9E2-D682B2496A88', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'CHECK');

-- ----------------------------------------------------------------------------
-- Phase 5: constraint_disposition enum_type + enum rows
-- Foundational primitive enum, sits alongside constraint_kind in the
-- kernel prelude on next dump.
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_primitives_enum_types] AS T
USING (SELECT '89BF8DE1-413E-582E-8D15-9629A883F6DA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'constraint_disposition',
  pub_notes = 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT. Engine-specific DDL tokens live in contracts_enums_ddl_mapping.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('89BF8DE1-413E-582E-8D15-9629A883F6DA', 'constraint_disposition', 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT. Engine-specific DDL tokens live in contracts_enums_ddl_mapping.');

MERGE INTO [contracts_primitives_enums] AS T
USING (SELECT '57F37618-1A3E-5D30-88CB-095E1DC91492' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_type_guid = '89BF8DE1-413E-582E-8D15-9629A883F6DA',
  pub_name = 'NO_ACTION',
  pub_value = 0,
  pub_notes = 'Engine default. No clause emitted.'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
  VALUES ('57F37618-1A3E-5D30-88CB-095E1DC91492', '89BF8DE1-413E-582E-8D15-9629A883F6DA', 'NO_ACTION', 0, 'Engine default. No clause emitted.');

MERGE INTO [contracts_primitives_enums] AS T
USING (SELECT '59C1933F-C216-5F32-A7C9-70A883287B8D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_type_guid = '89BF8DE1-413E-582E-8D15-9629A883F6DA',
  pub_name = 'CASCADE',
  pub_value = 1,
  pub_notes = 'Delete or update of parent triggers same operation on children.'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
  VALUES ('59C1933F-C216-5F32-A7C9-70A883287B8D', '89BF8DE1-413E-582E-8D15-9629A883F6DA', 'CASCADE', 1, 'Delete or update of parent triggers same operation on children.');

MERGE INTO [contracts_primitives_enums] AS T
USING (SELECT '36DD290B-4606-5810-843E-CF324B66F504' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_type_guid = '89BF8DE1-413E-582E-8D15-9629A883F6DA',
  pub_name = 'SET_NULL',
  pub_value = 2,
  pub_notes = 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
  VALUES ('36DD290B-4606-5810-843E-CF324B66F504', '89BF8DE1-413E-582E-8D15-9629A883F6DA', 'SET_NULL', 2, 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.');

MERGE INTO [contracts_primitives_enums] AS T
USING (SELECT 'BA9F914F-A591-512D-B2DF-B5C84D64C474' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_type_guid = '89BF8DE1-413E-582E-8D15-9629A883F6DA',
  pub_name = 'SET_DEFAULT',
  pub_value = 3,
  pub_notes = 'Child FK columns set to their column DEFAULT on parent delete/update.'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
  VALUES ('BA9F914F-A591-512D-B2DF-B5C84D64C474', '89BF8DE1-413E-582E-8D15-9629A883F6DA', 'SET_DEFAULT', 3, 'Child FK columns set to their column DEFAULT on parent delete/update.');

-- ----------------------------------------------------------------------------
-- Phase 6: contracts_enums_ddl_mapping rows for constraint_disposition
-- NO_ACTION's token is NULL across all engines (it emits no clause; the
-- engine default applies). The other three are identical SQL keywords
-- across all three target engines.
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'BF738132-EC1D-5397-9B91-33FE794B17FD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '57F37618-1A3E-5D30-88CB-095E1DC91492',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('BF738132-EC1D-5397-9B91-33FE794B17FD', '57F37618-1A3E-5D30-88CB-095E1DC91492', '1479A929-D1BF-565D-97B6-FFF277967653', NULL);

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '67C0B46F-D07C-52B3-B862-A5BD85C4DDF9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '57F37618-1A3E-5D30-88CB-095E1DC91492',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('67C0B46F-D07C-52B3-B862-A5BD85C4DDF9', '57F37618-1A3E-5D30-88CB-095E1DC91492', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', NULL);

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '56D58F30-7107-5DD9-ADE7-2BF4BFEA8A1D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '57F37618-1A3E-5D30-88CB-095E1DC91492',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('56D58F30-7107-5DD9-ADE7-2BF4BFEA8A1D', '57F37618-1A3E-5D30-88CB-095E1DC91492', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', NULL);

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '78478DD6-A1BD-58F5-81D8-46AAAF32EB18' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '59C1933F-C216-5F32-A7C9-70A883287B8D',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'CASCADE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('78478DD6-A1BD-58F5-81D8-46AAAF32EB18', '59C1933F-C216-5F32-A7C9-70A883287B8D', '1479A929-D1BF-565D-97B6-FFF277967653', 'CASCADE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '069F167D-9A9D-57A0-B7C1-82A01E45AFF4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '59C1933F-C216-5F32-A7C9-70A883287B8D',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'CASCADE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('069F167D-9A9D-57A0-B7C1-82A01E45AFF4', '59C1933F-C216-5F32-A7C9-70A883287B8D', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'CASCADE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'B20E403E-0CE7-5DE3-A5DA-FE376BA7B73E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '59C1933F-C216-5F32-A7C9-70A883287B8D',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'CASCADE'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('B20E403E-0CE7-5DE3-A5DA-FE376BA7B73E', '59C1933F-C216-5F32-A7C9-70A883287B8D', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'CASCADE');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '5F46376C-0B34-514C-95FF-4B6C5115700B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '36DD290B-4606-5810-843E-CF324B66F504',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'SET NULL'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('5F46376C-0B34-514C-95FF-4B6C5115700B', '36DD290B-4606-5810-843E-CF324B66F504', '1479A929-D1BF-565D-97B6-FFF277967653', 'SET NULL');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'F28AFAE6-6AD4-5FF9-AFD7-246D383F7D36' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '36DD290B-4606-5810-843E-CF324B66F504',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'SET NULL'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('F28AFAE6-6AD4-5FF9-AFD7-246D383F7D36', '36DD290B-4606-5810-843E-CF324B66F504', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'SET NULL');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '93C82DBB-BF25-59DC-AA58-6C4E6E58B256' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = '36DD290B-4606-5810-843E-CF324B66F504',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'SET NULL'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('93C82DBB-BF25-59DC-AA58-6C4E6E58B256', '36DD290B-4606-5810-843E-CF324B66F504', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'SET NULL');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '12805BA5-443E-5790-8FA0-AC1A08529335' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'BA9F914F-A591-512D-B2DF-B5C84D64C474',
  ref_engine_guid = '1479A929-D1BF-565D-97B6-FFF277967653',
  pub_ddl_token = 'SET DEFAULT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('12805BA5-443E-5790-8FA0-AC1A08529335', 'BA9F914F-A591-512D-B2DF-B5C84D64C474', '1479A929-D1BF-565D-97B6-FFF277967653', 'SET DEFAULT');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT '7AB84C0E-D889-51F2-9BB1-2851169A85FF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'BA9F914F-A591-512D-B2DF-B5C84D64C474',
  ref_engine_guid = '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0',
  pub_ddl_token = 'SET DEFAULT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('7AB84C0E-D889-51F2-9BB1-2851169A85FF', 'BA9F914F-A591-512D-B2DF-B5C84D64C474', '0F0D38AA-DCA1-5475-9FFD-CB00FD33D1F0', 'SET DEFAULT');

MERGE INTO [contracts_enums_ddl_mapping] AS T
USING (SELECT 'BBFCDAB6-F254-500A-919F-AD6045FF9211' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_enum_guid = 'BA9F914F-A591-512D-B2DF-B5C84D64C474',
  ref_engine_guid = '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74',
  pub_ddl_token = 'SET DEFAULT'
WHEN NOT MATCHED THEN INSERT (key_guid, ref_enum_guid, ref_engine_guid, pub_ddl_token)
  VALUES ('BBFCDAB6-F254-500A-919F-AD6045FF9211', 'BA9F914F-A591-512D-B2DF-B5C84D64C474', '55C34EBD-A4FE-54FD-B1CD-4E6CF9957C74', 'SET DEFAULT');

-- ----------------------------------------------------------------------------
-- Phase 7: mark the 10 FK_*_package rows with pub_delete_disposition = 1
-- ----------------------------------------------------------------------------

UPDATE contracts_db_constraints
   SET pub_delete_disposition = 1
 WHERE key_guid IN (
   'BBCE7E3B-323B-5050-BD2F-CAE060708C86',  -- contracts_db_tables.FK_cdt_package
   '32940E00-1D6E-5B3E-B77F-D6DC61565F22',  -- contracts_db_columns.FK_cdc_package
   'A22E8687-5DD7-5157-BBF1-46DF9A76F9B3',  -- contracts_db_indexes.FK_cdi_package
   'F6127708-12B2-503E-884D-DC4A4C060B7C',  -- contracts_db_index_columns.FK_cdic_package
   'FE164784-A1F0-5239-9C93-29A310EA849B',  -- contracts_db_constraints.FK_cdcn_package
   '747A39E9-53BC-56B5-B092-AE775DF62732',  -- contracts_db_constraint_columns.FK_cdcc_package
   '1DA448CB-C8BA-52DE-A172-659B30B3BBAF',  -- contracts_db_operations.FK_cdo_package
   'C4765E95-3E18-5EB8-A486-20D10839984C',  -- service_system_configuration.FK_ssc_package
   'A507F07C-4539-50D4-A5C5-E0C27D0BA7E0',  -- contracts_db_operations_models.FK_cdom_package
   'A23F4F13-A431-5F5F-8E96-AF02D9911E85'  -- contracts_db_operations_models_fields.FK_cdomf_package
 );

-- ----------------------------------------------------------------------------
-- Phase 8: drop and re-add the 10 FK_*_package constraints with
-- ON DELETE CASCADE
-- ----------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdt_package')
  ALTER TABLE [dbo].[contracts_db_tables] DROP CONSTRAINT [FK_cdt_package];
ALTER TABLE [dbo].[contracts_db_tables]
  ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdc_package')
  ALTER TABLE [dbo].[contracts_db_columns] DROP CONSTRAINT [FK_cdc_package];
ALTER TABLE [dbo].[contracts_db_columns]
  ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdi_package')
  ALTER TABLE [dbo].[contracts_db_indexes] DROP CONSTRAINT [FK_cdi_package];
ALTER TABLE [dbo].[contracts_db_indexes]
  ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdic_package')
  ALTER TABLE [dbo].[contracts_db_index_columns] DROP CONSTRAINT [FK_cdic_package];
ALTER TABLE [dbo].[contracts_db_index_columns]
  ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdcn_package')
  ALTER TABLE [dbo].[contracts_db_constraints] DROP CONSTRAINT [FK_cdcn_package];
ALTER TABLE [dbo].[contracts_db_constraints]
  ADD CONSTRAINT [FK_cdcn_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdcc_package')
  ALTER TABLE [dbo].[contracts_db_constraint_columns] DROP CONSTRAINT [FK_cdcc_package];
ALTER TABLE [dbo].[contracts_db_constraint_columns]
  ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdo_package')
  ALTER TABLE [dbo].[contracts_db_operations] DROP CONSTRAINT [FK_cdo_package];
ALTER TABLE [dbo].[contracts_db_operations]
  ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ssc_package')
  ALTER TABLE [dbo].[service_system_configuration] DROP CONSTRAINT [FK_ssc_package];
ALTER TABLE [dbo].[service_system_configuration]
  ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdom_package')
  ALTER TABLE [dbo].[contracts_db_operations_models] DROP CONSTRAINT [FK_cdom_package];
ALTER TABLE [dbo].[contracts_db_operations_models]
  ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cdomf_package')
  ALTER TABLE [dbo].[contracts_db_operations_models_fields] DROP CONSTRAINT [FK_cdomf_package];
ALTER TABLE [dbo].[contracts_db_operations_models_fields]
  ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid])
  REFERENCES [dbo].[service_modules_manifest] ([key_guid])
  ON DELETE CASCADE;
GO

-- ----------------------------------------------------------------------------
-- Phase 9: self-describing rows in contracts_db_*
-- Three new tables (engines + two mapping tables), all their columns,
-- indexes, constraints, constraint-columns, plus the new column on
-- contracts_db_constraints. Authored such that the next REPL dump
-- regenerates kernel.sql and seed.json with everything in place.
-- ----------------------------------------------------------------------------

-- contracts_db_engines (alias cde, seed=15)
MERGE INTO [contracts_db_tables] AS T
USING (SELECT 'E6DFFDB4-A2B3-5001-B2C1-447976648A83' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'contracts_db_engines',
  pub_schema = 'dbo',
  pub_alias = 'cde',
  pub_seed_element = 15
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_schema, pub_alias, pub_seed_element)
  VALUES ('E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'contracts_db_engines', 'dbo', 'cde', 15);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '5E2D173F-708F-54C5-B164-A8CE1C7D3353' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('5E2D173F-708F-54C5-B164-A8CE1C7D3353', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '5CC9E5CC-3EBE-5E82-9255-75D9EF68CF9E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 2,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('5CC9E5CC-3EBE-5E82-9255-75D9EF68CF9E', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 2, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'FD840E82-8DDA-5C28-911C-73762D3F4E16' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('FD840E82-8DDA-5C28-911C-73762D3F4E16', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 3, 0, NULL, 64);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '738F0E9A-E726-57CE-8535-976DBE098BB5' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  pub_name = 'pub_value',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('738F0E9A-E726-57CE-8535-976DBE098BB5', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'pub_value', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '09186BFC-F11E-58B1-B06B-AB136151D1F9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_notes',
  pub_ordinal = 5,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 512
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('09186BFC-F11E-58B1-B06B-AB136151D1F9', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_notes', 5, 1, NULL, 512);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '7D7ABB42-D820-5133-AA8F-44B0E3FC28A7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_created_on',
  pub_ordinal = 6,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('7D7ABB42-D820-5133-AA8F-44B0E3FC28A7', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_created_on', 6, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '161257C9-8590-5686-8040-706D197C9298' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_modified_on',
  pub_ordinal = 7,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('161257C9-8590-5686-8040-706D197C9298', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_modified_on', 7, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '40EF103D-1384-5BD3-BCD9-EE37629F7B4C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_kind_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_referenced_table_guid = NULL,
  pub_name = 'PK_contracts_db_engines',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('40EF103D-1384-5BD3-BCD9-EE37629F7B4C', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '3426C194-B912-5F71-802F-566E2FF1E8FF', NULL, 'PK_contracts_db_engines', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '66CA6209-5480-5645-A728-D22B68D97A24' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_cde_name',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('66CA6209-5480-5645-A728-D22B68D97A24', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_cde_name', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'BEA47AA4-53EA-5700-B6F7-F51610C2544F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_cde_value',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('BEA47AA4-53EA-5700-B6F7-F51610C2544F', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_cde_value', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '7F6D1F59-5A0F-51D9-AEC1-B92F630B2DF9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54',
  pub_name = 'FK_cde_package',
  pub_expression = NULL,
  pub_delete_disposition = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('7F6D1F59-5A0F-51D9-AEC1-B92F630B2DF9', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '855F0DA4-6700-5402-BE81-2ECC543BFB54', 'FK_cde_package', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '15CF1B53-75AD-50AD-B768-33F881F52AD4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '40EF103D-1384-5BD3-BCD9-EE37629F7B4C',
  ref_column_guid = '5E2D173F-708F-54C5-B164-A8CE1C7D3353',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('15CF1B53-75AD-50AD-B768-33F881F52AD4', '40EF103D-1384-5BD3-BCD9-EE37629F7B4C', '5E2D173F-708F-54C5-B164-A8CE1C7D3353', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'B10C2904-B478-597F-9271-37A857B2FB6C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '66CA6209-5480-5645-A728-D22B68D97A24',
  ref_column_guid = 'FD840E82-8DDA-5C28-911C-73762D3F4E16',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('B10C2904-B478-597F-9271-37A857B2FB6C', '66CA6209-5480-5645-A728-D22B68D97A24', 'FD840E82-8DDA-5C28-911C-73762D3F4E16', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'E1911201-556E-571B-BFA3-CEDBE90469CC' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'BEA47AA4-53EA-5700-B6F7-F51610C2544F',
  ref_column_guid = '738F0E9A-E726-57CE-8535-976DBE098BB5',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('E1911201-556E-571B-BFA3-CEDBE90469CC', 'BEA47AA4-53EA-5700-B6F7-F51610C2544F', '738F0E9A-E726-57CE-8535-976DBE098BB5', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '1764FE75-7F48-545C-8F26-329D4AD528CD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '7F6D1F59-5A0F-51D9-AEC1-B92F630B2DF9',
  ref_column_guid = '5CC9E5CC-3EBE-5E82-9255-75D9EF68CF9E',
  ref_referenced_column_guid = '131404F3-E1C4-5F57-BCB5-8A62B90CED0F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('1764FE75-7F48-545C-8F26-329D4AD528CD', '7F6D1F59-5A0F-51D9-AEC1-B92F630B2DF9', '5CC9E5CC-3EBE-5E82-9255-75D9EF68CF9E', '131404F3-E1C4-5F57-BCB5-8A62B90CED0F', 1);

-- contracts_types_ddl_mapping (alias ctddm, seed=16)
MERGE INTO [contracts_db_tables] AS T
USING (SELECT '55C97D42-210F-585F-A66C-93F3FA02CF34' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'contracts_types_ddl_mapping',
  pub_schema = 'dbo',
  pub_alias = 'ctddm',
  pub_seed_element = 16
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_schema, pub_alias, pub_seed_element)
  VALUES ('55C97D42-210F-585F-A66C-93F3FA02CF34', 'contracts_types_ddl_mapping', 'dbo', 'ctddm', 16);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'B304FF4D-895D-523F-9BDA-CE742D1230F6' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B304FF4D-895D-523F-9BDA-CE742D1230F6', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '7221E3DD-8FAC-598E-8B40-8D3C4B3AFDF8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 2,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('7221E3DD-8FAC-598E-8B40-8D3C4B3AFDF8', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 2, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '630ED8FE-E3B4-512F-8CA1-7D702D9279EE' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_type_guid',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('630ED8FE-E3B4-512F-8CA1-7D702D9279EE', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_type_guid', 3, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_engine_guid',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_engine_guid', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'D586A7B5-DB0A-58DE-820C-1B91B2788210' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_ddl_token',
  pub_ordinal = 5,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('D586A7B5-DB0A-58DE-820C-1B91B2788210', '55C97D42-210F-585F-A66C-93F3FA02CF34', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_ddl_token', 5, 1, NULL, 128);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '9B870D79-37F9-5BCE-B2ED-7205FC83D0D4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_created_on',
  pub_ordinal = 6,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('9B870D79-37F9-5BCE-B2ED-7205FC83D0D4', '55C97D42-210F-585F-A66C-93F3FA02CF34', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_created_on', 6, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'A8549ED1-6543-5BA9-A9DE-EDBD144373DE' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_modified_on',
  pub_ordinal = 7,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A8549ED1-6543-5BA9-A9DE-EDBD144373DE', '55C97D42-210F-585F-A66C-93F3FA02CF34', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_modified_on', 7, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_indexes] AS T
USING (SELECT '075808C6-BC7D-53EA-8AEB-885A4C4A7346' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  pub_name = 'IX_ctddm_type_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('075808C6-BC7D-53EA-8AEB-885A4C4A7346', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'IX_ctddm_type_guid', 0);

MERGE INTO [contracts_db_indexes] AS T
USING (SELECT 'C6BA8314-B98B-5A77-B762-4C419F2706C3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  pub_name = 'IX_ctddm_engine_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('C6BA8314-B98B-5A77-B762-4C419F2706C3', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'IX_ctddm_engine_guid', 0);

MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT 'A2AD2C05-1633-5812-BE74-5F859AC2F22E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = '075808C6-BC7D-53EA-8AEB-885A4C4A7346',
  ref_column_guid = '630ED8FE-E3B4-512F-8CA1-7D702D9279EE',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('A2AD2C05-1633-5812-BE74-5F859AC2F22E', '075808C6-BC7D-53EA-8AEB-885A4C4A7346', '630ED8FE-E3B4-512F-8CA1-7D702D9279EE', 1);

MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT 'B782359E-A396-575D-B1FD-0BEDE18F8B6E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = 'C6BA8314-B98B-5A77-B762-4C419F2706C3',
  ref_column_guid = 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('B782359E-A396-575D-B1FD-0BEDE18F8B6E', 'C6BA8314-B98B-5A77-B762-4C419F2706C3', 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2', 1);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'E8E4AF58-5AF2-5FC7-99B4-017438C2585F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_kind_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_referenced_table_guid = NULL,
  pub_name = 'PK_contracts_types_ddl_mapping',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('E8E4AF58-5AF2-5FC7-99B4-017438C2585F', '55C97D42-210F-585F-A66C-93F3FA02CF34', '3426C194-B912-5F71-802F-566E2FF1E8FF', NULL, 'PK_contracts_types_ddl_mapping', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'D922CA56-A422-5C48-B8EE-A80892C2DBDF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_ctddm_type_engine',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('D922CA56-A422-5C48-B8EE-A80892C2DBDF', '55C97D42-210F-585F-A66C-93F3FA02CF34', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_ctddm_type_engine', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'A2D91BC6-9FCC-54A5-93A4-3EA71A7CDB52' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = 'B7213805-2910-5427-A2BB-6B12CA1C15DF',
  pub_name = 'FK_ctddm_type',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('A2D91BC6-9FCC-54A5-93A4-3EA71A7CDB52', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'B6ABA725-1FDB-5454-B164-DDBE11079598', 'B7213805-2910-5427-A2BB-6B12CA1C15DF', 'FK_ctddm_type', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT 'C40F5697-A41B-5CF3-AEA4-9F4EE2109EA4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  pub_name = 'FK_ctddm_engine',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('C40F5697-A41B-5CF3-AEA4-9F4EE2109EA4', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'B6ABA725-1FDB-5454-B164-DDBE11079598', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'FK_ctddm_engine', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '95556179-E0A5-5F86-9C09-2637D38C3B67' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '55C97D42-210F-585F-A66C-93F3FA02CF34',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54',
  pub_name = 'FK_ctddm_package',
  pub_expression = NULL,
  pub_delete_disposition = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('95556179-E0A5-5F86-9C09-2637D38C3B67', '55C97D42-210F-585F-A66C-93F3FA02CF34', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '855F0DA4-6700-5402-BE81-2ECC543BFB54', 'FK_ctddm_package', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '6E87B6B8-0401-586E-8AC2-5BD7207EDCDD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'E8E4AF58-5AF2-5FC7-99B4-017438C2585F',
  ref_column_guid = 'B304FF4D-895D-523F-9BDA-CE742D1230F6',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('6E87B6B8-0401-586E-8AC2-5BD7207EDCDD', 'E8E4AF58-5AF2-5FC7-99B4-017438C2585F', 'B304FF4D-895D-523F-9BDA-CE742D1230F6', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '9A4D10C4-332C-5564-9D6D-410BC4CE97EA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'D922CA56-A422-5C48-B8EE-A80892C2DBDF',
  ref_column_guid = '630ED8FE-E3B4-512F-8CA1-7D702D9279EE',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('9A4D10C4-332C-5564-9D6D-410BC4CE97EA', 'D922CA56-A422-5C48-B8EE-A80892C2DBDF', '630ED8FE-E3B4-512F-8CA1-7D702D9279EE', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '255ED468-B4A6-54B7-8AF8-295F7EEF6D75' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'D922CA56-A422-5C48-B8EE-A80892C2DBDF',
  ref_column_guid = 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 2
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('255ED468-B4A6-54B7-8AF8-295F7EEF6D75', 'D922CA56-A422-5C48-B8EE-A80892C2DBDF', 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2', NULL, 2);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '336710F6-5F59-5AE3-90E4-62C17B685841' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'A2D91BC6-9FCC-54A5-93A4-3EA71A7CDB52',
  ref_column_guid = '630ED8FE-E3B4-512F-8CA1-7D702D9279EE',
  ref_referenced_column_guid = '342331DE-3D99-5422-BBE5-09F22583AE8E',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('336710F6-5F59-5AE3-90E4-62C17B685841', 'A2D91BC6-9FCC-54A5-93A4-3EA71A7CDB52', '630ED8FE-E3B4-512F-8CA1-7D702D9279EE', '342331DE-3D99-5422-BBE5-09F22583AE8E', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'CE354F59-76F4-55A8-B2A7-E586EDD2E306' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = 'C40F5697-A41B-5CF3-AEA4-9F4EE2109EA4',
  ref_column_guid = 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2',
  ref_referenced_column_guid = '5E2D173F-708F-54C5-B164-A8CE1C7D3353',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('CE354F59-76F4-55A8-B2A7-E586EDD2E306', 'C40F5697-A41B-5CF3-AEA4-9F4EE2109EA4', 'E5CC4E60-B1B5-5B97-B0D7-4DC1683BF2D2', '5E2D173F-708F-54C5-B164-A8CE1C7D3353', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT 'C9D161B9-CFFA-52AD-8995-6925CC355DDD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '95556179-E0A5-5F86-9C09-2637D38C3B67',
  ref_column_guid = '7221E3DD-8FAC-598E-8B40-8D3C4B3AFDF8',
  ref_referenced_column_guid = '131404F3-E1C4-5F57-BCB5-8A62B90CED0F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('C9D161B9-CFFA-52AD-8995-6925CC355DDD', '95556179-E0A5-5F86-9C09-2637D38C3B67', '7221E3DD-8FAC-598E-8B40-8D3C4B3AFDF8', '131404F3-E1C4-5F57-BCB5-8A62B90CED0F', 1);

-- contracts_enums_ddl_mapping (alias ceddm, seed=17)
MERGE INTO [contracts_db_tables] AS T
USING (SELECT '706200BA-EA7E-59EE-AC8A-A60B7892C6C4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'contracts_enums_ddl_mapping',
  pub_schema = 'dbo',
  pub_alias = 'ceddm',
  pub_seed_element = 17
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_schema, pub_alias, pub_seed_element)
  VALUES ('706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'contracts_enums_ddl_mapping', 'dbo', 'ceddm', 17);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'A44E5B7D-E11A-5427-806C-7AED4C0F9016' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A44E5B7D-E11A-5427-806C-7AED4C0F9016', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '3AA4F08A-4157-5624-8E7E-74103DBC257A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 2,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('3AA4F08A-4157-5624-8E7E-74103DBC257A', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 2, 1, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'A69748C2-0FA0-5BAE-8E60-DC83E415022F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_enum_guid',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A69748C2-0FA0-5BAE-8E60-DC83E415022F', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_enum_guid', 3, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_engine_guid',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('ED286F1F-FFA7-5857-B9FA-5ED45C9A0636', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_engine_guid', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'E5D50687-C344-53EB-9E20-F82BF18EAD39' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_ddl_token',
  pub_ordinal = 5,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E5D50687-C344-53EB-9E20-F82BF18EAD39', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_ddl_token', 5, 1, NULL, 128);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT 'BDD70EED-FE84-50F4-B42C-3BFFA833CF65' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_created_on',
  pub_ordinal = 6,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('BDD70EED-FE84-50F4-B42C-3BFFA833CF65', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_created_on', 6, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_columns] AS T
USING (SELECT '10E0401C-F38D-597C-B469-FB468C958A21' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_type_guid = '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
  pub_name = 'priv_modified_on',
  pub_ordinal = 7,
  pub_is_nullable = 0,
  pub_default_value = 'SYSDATETIMEOFFSET()',
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('10E0401C-F38D-597C-B469-FB468C958A21', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', '0A301083-D3E1-5119-9ADB-09B47A1E00FA', 'priv_modified_on', 7, 0, 'SYSDATETIMEOFFSET()', NULL);

MERGE INTO [contracts_db_indexes] AS T
USING (SELECT 'F8CE947D-1463-5A74-AEA9-BAA346CC240D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  pub_name = 'IX_ceddm_enum_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('F8CE947D-1463-5A74-AEA9-BAA346CC240D', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'IX_ceddm_enum_guid', 0);

MERGE INTO [contracts_db_indexes] AS T
USING (SELECT 'E3E1DA95-1939-57A6-A089-582514A1C2D8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  pub_name = 'IX_ceddm_engine_guid',
  pub_is_unique = 0
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, pub_name, pub_is_unique)
  VALUES ('E3E1DA95-1939-57A6-A089-582514A1C2D8', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'IX_ceddm_engine_guid', 0);

MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT 'A5E008C3-370D-579C-9828-954422E21AFF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = 'F8CE947D-1463-5A74-AEA9-BAA346CC240D',
  ref_column_guid = 'A69748C2-0FA0-5BAE-8E60-DC83E415022F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('A5E008C3-370D-579C-9828-954422E21AFF', 'F8CE947D-1463-5A74-AEA9-BAA346CC240D', 'A69748C2-0FA0-5BAE-8E60-DC83E415022F', 1);

MERGE INTO [contracts_db_index_columns] AS T
USING (SELECT '8133DA01-6A59-5833-AE99-C5593BD23AEF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_index_guid = 'E3E1DA95-1939-57A6-A089-582514A1C2D8',
  ref_column_guid = 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_index_guid, ref_column_guid, pub_ordinal)
  VALUES ('8133DA01-6A59-5833-AE99-C5593BD23AEF', 'E3E1DA95-1939-57A6-A089-582514A1C2D8', 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636', 1);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '0364DC64-2603-5037-B6E1-3C88DCDA1013' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_kind_enum_guid = '3426C194-B912-5F71-802F-566E2FF1E8FF',
  ref_referenced_table_guid = NULL,
  pub_name = 'PK_contracts_enums_ddl_mapping',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('0364DC64-2603-5037-B6E1-3C88DCDA1013', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', '3426C194-B912-5F71-802F-566E2FF1E8FF', NULL, 'PK_contracts_enums_ddl_mapping', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '3652E971-07C7-5A4A-8E01-B713A31202C4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_kind_enum_guid = '4D75333D-E472-5813-A03B-C0162671A00D',
  ref_referenced_table_guid = NULL,
  pub_name = 'UQ_ceddm_enum_engine',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('3652E971-07C7-5A4A-8E01-B713A31202C4', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', '4D75333D-E472-5813-A03B-C0162671A00D', NULL, 'UQ_ceddm_enum_engine', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '6027B5CC-0CBE-5F1D-97D8-B23ABA9CD01E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = 'DB8900D4-9FBC-5544-B774-DBFCD14793EC',
  pub_name = 'FK_ceddm_enum',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('6027B5CC-0CBE-5F1D-97D8-B23ABA9CD01E', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'B6ABA725-1FDB-5454-B164-DDBE11079598', 'DB8900D4-9FBC-5544-B774-DBFCD14793EC', 'FK_ceddm_enum', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '3C65C8A2-C4D9-568A-A923-B18CA4280CE2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = 'E6DFFDB4-A2B3-5001-B2C1-447976648A83',
  pub_name = 'FK_ceddm_engine',
  pub_expression = NULL,
  pub_delete_disposition = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('3C65C8A2-C4D9-568A-A923-B18CA4280CE2', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'B6ABA725-1FDB-5454-B164-DDBE11079598', 'E6DFFDB4-A2B3-5001-B2C1-447976648A83', 'FK_ceddm_engine', NULL, NULL);

MERGE INTO [contracts_db_constraints] AS T
USING (SELECT '0AB138D2-071C-56AE-9F0E-C99BED70408A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '706200BA-EA7E-59EE-AC8A-A60B7892C6C4',
  ref_kind_enum_guid = 'B6ABA725-1FDB-5454-B164-DDBE11079598',
  ref_referenced_table_guid = '855F0DA4-6700-5402-BE81-2ECC543BFB54',
  pub_name = 'FK_ceddm_package',
  pub_expression = NULL,
  pub_delete_disposition = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_kind_enum_guid, ref_referenced_table_guid, pub_name, pub_expression, pub_delete_disposition)
  VALUES ('0AB138D2-071C-56AE-9F0E-C99BED70408A', '706200BA-EA7E-59EE-AC8A-A60B7892C6C4', 'B6ABA725-1FDB-5454-B164-DDBE11079598', '855F0DA4-6700-5402-BE81-2ECC543BFB54', 'FK_ceddm_package', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '16614ED5-08DD-544E-B42A-6C9583FD5B67' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '0364DC64-2603-5037-B6E1-3C88DCDA1013',
  ref_column_guid = 'A44E5B7D-E11A-5427-806C-7AED4C0F9016',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('16614ED5-08DD-544E-B42A-6C9583FD5B67', '0364DC64-2603-5037-B6E1-3C88DCDA1013', 'A44E5B7D-E11A-5427-806C-7AED4C0F9016', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '1A8DF8F6-BCFC-55D2-8B4A-557211305B97' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '3652E971-07C7-5A4A-8E01-B713A31202C4',
  ref_column_guid = 'A69748C2-0FA0-5BAE-8E60-DC83E415022F',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('1A8DF8F6-BCFC-55D2-8B4A-557211305B97', '3652E971-07C7-5A4A-8E01-B713A31202C4', 'A69748C2-0FA0-5BAE-8E60-DC83E415022F', NULL, 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '16935391-CFA5-5B44-9711-F45D6C510E74' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '3652E971-07C7-5A4A-8E01-B713A31202C4',
  ref_column_guid = 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636',
  ref_referenced_column_guid = NULL,
  pub_ordinal = 2
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('16935391-CFA5-5B44-9711-F45D6C510E74', '3652E971-07C7-5A4A-8E01-B713A31202C4', 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636', NULL, 2);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '49799B0B-C82B-5360-AA5B-94C78452DD41' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '6027B5CC-0CBE-5F1D-97D8-B23ABA9CD01E',
  ref_column_guid = 'A69748C2-0FA0-5BAE-8E60-DC83E415022F',
  ref_referenced_column_guid = 'B96DA853-8D46-5150-908A-AD558171ECF5',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('49799B0B-C82B-5360-AA5B-94C78452DD41', '6027B5CC-0CBE-5F1D-97D8-B23ABA9CD01E', 'A69748C2-0FA0-5BAE-8E60-DC83E415022F', 'B96DA853-8D46-5150-908A-AD558171ECF5', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '9433CC5D-6111-5A72-8DD7-F09CD78112FD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '3C65C8A2-C4D9-568A-A923-B18CA4280CE2',
  ref_column_guid = 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636',
  ref_referenced_column_guid = '5E2D173F-708F-54C5-B164-A8CE1C7D3353',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('9433CC5D-6111-5A72-8DD7-F09CD78112FD', '3C65C8A2-C4D9-568A-A923-B18CA4280CE2', 'ED286F1F-FFA7-5857-B9FA-5ED45C9A0636', '5E2D173F-708F-54C5-B164-A8CE1C7D3353', 1);

MERGE INTO [contracts_db_constraint_columns] AS T
USING (SELECT '346C58CC-87AB-5BE7-BCAA-7655639B6199' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_constraint_guid = '0AB138D2-071C-56AE-9F0E-C99BED70408A',
  ref_column_guid = '3AA4F08A-4157-5624-8E7E-74103DBC257A',
  ref_referenced_column_guid = '131404F3-E1C4-5F57-BCB5-8A62B90CED0F',
  pub_ordinal = 1
WHEN NOT MATCHED THEN INSERT (key_guid, ref_constraint_guid, ref_column_guid, ref_referenced_column_guid, pub_ordinal)
  VALUES ('346C58CC-87AB-5BE7-BCAA-7655639B6199', '0AB138D2-071C-56AE-9F0E-C99BED70408A', '3AA4F08A-4157-5624-8E7E-74103DBC257A', '131404F3-E1C4-5F57-BCB5-8A62B90CED0F', 1);

-- New column row: contracts_db_constraints.pub_delete_disposition
-- Existing column count on this table is 9; new column at ordinal 10.
MERGE INTO [contracts_db_columns] AS T
USING (SELECT '078D6921-CEFE-59D4-986B-53EED369B3E7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_table_guid = '76EEA9D8-FB6A-5E18-BD94-AFA5A991A56D',
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  pub_name = 'pub_delete_disposition',
  pub_ordinal = 10,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_table_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('078D6921-CEFE-59D4-986B-53EED369B3E7', '76EEA9D8-FB6A-5E18-BD94-AFA5A991A56D', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'pub_delete_disposition', 10, 1, NULL, NULL);

-- ============================================================================
-- Done.
--
-- Run REPL dump to regenerate kernel.sql / kernel_seed.json:
--   - 3 new tables get their CREATE TABLE blocks
--   - constraint_disposition enum + its 4 enum rows go in the prelude
--   - 57 type mapping rows + 12 + 12 = 24 enum mapping rows in the seed
--   - 3 engine rows in the seed
--   - 10 FK_*_package rows now emit ON DELETE CASCADE clauses
--   - new pub_delete_disposition column on contracts_db_constraints
--
-- IMPORTANT: scriptlib's _build_constraint must be updated BEFORE the
-- next dump to emit ON DELETE clauses (the current scriptlib version
-- already reads pub_delete_disposition; verify it does an integer-keyed
-- lookup for the keyword rather than carrying a hardcoded mapping).
-- ============================================================================