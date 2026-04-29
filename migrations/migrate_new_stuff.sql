-- migrate_new_stuff.sql
-- One-shot: rename pub_bootstrap -> pub_bootstrap_element and add
-- pub_seed_element to contracts_db_tables (backfilled to 1 for every
-- existing row, since the current table set IS the kernel seed).
-- Run once against the live database, then delete this file.

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ---------------------------------------------------------------------
-- 1. Rename contracts_db_operations.pub_bootstrap -> pub_bootstrap_element.
-- ---------------------------------------------------------------------
EXEC sp_rename 'dbo.contracts_db_operations.pub_bootstrap',
               'pub_bootstrap_element', 'COLUMN';
GO

-- ---------------------------------------------------------------------
-- 2. Add pub_seed_element to contracts_db_tables.
--    Marks rows whose tables belong to the kernel install bundle.
-- ---------------------------------------------------------------------
ALTER TABLE [dbo].[contracts_db_tables]
  ADD [pub_seed_element] BIT DEFAULT (0) NOT NULL;
GO

-- 2a. Backfill: every table currently in the database is part of the
--     kernel seed, so flag them all.
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] = 1;
GO

PRINT 'Migration complete. Run REPL: populate, dump, nuke, seed to verify cycle.';
GO
-- migrate_new_stuff.sql
-- One-shot: decompose contracts_primitives_enums into header (enum_types) + lines.
-- Adds the FK column in-place rather than recreating the table; populate's
-- full-clear-and-rebuild handles any sys.columns ordinal gap on the next cycle.
-- Run once against the live database, then delete this file.

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ---------------------------------------------------------------------
-- 1. Create the new header table.
-- ---------------------------------------------------------------------
CREATE TABLE [dbo].[contracts_primitives_enum_types] (
  [key_guid]            UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid]    UNIQUEIDENTIFIER NULL,
  [pub_name]            NVARCHAR(128)    NOT NULL,
  [pub_notes]           NVARCHAR(512)    NULL,
  [priv_created_on]     DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on]    DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY ([key_guid]);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE ([pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_modules_manifest] ([key_guid]);
GO

-- ---------------------------------------------------------------------
-- 2. Seed header rows. Deterministic GUIDs from
--    uuid5(DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB, "contracts_primitives_enum_types:<name>").
-- ---------------------------------------------------------------------
INSERT INTO [dbo].[contracts_primitives_enum_types]
  (key_guid, pub_name, pub_notes)
VALUES
  ('4BE7C586-9847-5925-90A3-5071D8228F26', 'constraint_kind',
   'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', 'schema_source',
   'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).');
GO

-- ---------------------------------------------------------------------
-- 3. Add ref_enum_type_guid to contracts_primitives_enums and backfill.
-- ---------------------------------------------------------------------

-- 3a. Add the new column as nullable so backfill can populate it.
ALTER TABLE [dbo].[contracts_primitives_enums]
  ADD [ref_enum_type_guid] UNIQUEIDENTIFIER NULL;
GO

-- 3b. Backfill from the existing pub_enum_type text column via the header table.
UPDATE e
SET    e.ref_enum_type_guid = et.key_guid
FROM   [dbo].[contracts_primitives_enums] e
JOIN   [dbo].[contracts_primitives_enum_types] et
  ON   et.pub_name = e.pub_enum_type;
GO

-- Sanity check: every row should now have a ref_enum_type_guid.
IF EXISTS (SELECT 1 FROM [dbo].[contracts_primitives_enums] WHERE [ref_enum_type_guid] IS NULL)
  THROW 51000, 'contracts_primitives_enums has rows whose pub_enum_type does not match any enum_types.pub_name; aborting.', 1;
GO

-- 3c. Promote the column to NOT NULL now that it is fully populated.
ALTER TABLE [dbo].[contracts_primitives_enums]
  ALTER COLUMN [ref_enum_type_guid] UNIQUEIDENTIFIER NOT NULL;
GO

-- 3d. Drop the old unique constraints (they reference pub_enum_type).
ALTER TABLE [dbo].[contracts_primitives_enums] DROP CONSTRAINT [UQ_cpe_type_name];
ALTER TABLE [dbo].[contracts_primitives_enums] DROP CONSTRAINT [UQ_cpe_type_value];
GO

-- 3e. Drop the now-unused pub_enum_type text column.
ALTER TABLE [dbo].[contracts_primitives_enums]
  DROP COLUMN [pub_enum_type];
GO

-- 3f. Add the new unique constraints (keyed on ref_enum_type_guid) and the FK.
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name]
  UNIQUE ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value]
  UNIQUE ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [dbo].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type]
  FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [dbo].[contracts_primitives_enum_types] ([key_guid]);
GO

-- ---------------------------------------------------------------------
-- 4. Seed schema_source enum members. Deterministic GUIDs from
--    uuid5(NS_HASH, "contracts_primitives_enums:schema_source.<name>").
-- ---------------------------------------------------------------------
INSERT INTO [dbo].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)
VALUES
  ('E3C5DACB-6027-515A-8FED-489D71869C86',
   'F5539B3E-417C-5A95-BF9B-592B97369B40',
   'PRIMARY', 0,
   'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07',
   'F5539B3E-417C-5A95-BF9B-592B97369B40',
   'GENERATED', 1,
   'Declared schema generated from contracts_db_* rows.');
GO

PRINT 'Migration complete. Run REPL: populate, dump, nuke, seed to verify cycle.';
GO





EXEC sp_rename 'dbo.contracts_db_operations.pub_bootstrap', 'pub_bootstrap_element', 'COLUMN';
GO

ALTER TABLE [dbo].[contracts_db_tables] ADD [pub_seed_element] BIT DEFAULT (0) NOT NULL;
GO

UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] = 1;
GO





-- Convert pub_seed_element from BIT to TINYINT and assign install ordinals.
-- Zero = not a seed table. Nonzero = seed with that load order.

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Drop the BIT default so the column type can be altered.
DECLARE @default_name NVARCHAR(256) = (
  SELECT dc.name
  FROM sys.default_constraints dc
  JOIN sys.columns c ON c.default_object_id = dc.object_id
  JOIN sys.tables t ON t.object_id = c.object_id
  WHERE t.name = 'contracts_db_tables' AND c.name = 'pub_seed_element'
);
IF @default_name IS NOT NULL
  EXEC ('ALTER TABLE [dbo].[contracts_db_tables] DROP CONSTRAINT [' + @default_name + ']');
GO

-- Widen BIT -> TINYINT.
ALTER TABLE [dbo].[contracts_db_tables]
  ALTER COLUMN [pub_seed_element] TINYINT NOT NULL;
GO

-- Restore default 0 with a deterministic constraint name.
ALTER TABLE [dbo].[contracts_db_tables]
  ADD CONSTRAINT [DF_cdt_pub_seed_element] DEFAULT (0) FOR [pub_seed_element];
GO

-- Assign install ordinals to the kernel seed tables.
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  1 WHERE [pub_name] = 'contracts_primitives_types';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  2 WHERE [pub_name] = 'contracts_primitives_enum_types';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  3 WHERE [pub_name] = 'contracts_primitives_enums';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  4 WHERE [pub_name] = 'contracts_db_tables';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  5 WHERE [pub_name] = 'contracts_db_columns';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  6 WHERE [pub_name] = 'contracts_db_indexes';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  7 WHERE [pub_name] = 'contracts_db_index_columns';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  8 WHERE [pub_name] = 'contracts_db_constraints';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] =  9 WHERE [pub_name] = 'contracts_db_constraint_columns';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] = 10 WHERE [pub_name] = 'contracts_db_operations';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] = 11 WHERE [pub_name] = 'service_system_configuration';
UPDATE [dbo].[contracts_db_tables] SET [pub_seed_element] = 12 WHERE [pub_name] = 'service_modules_manifest';
GO

-- Verify.
SELECT [pub_name], [pub_seed_element]
FROM [dbo].[contracts_db_tables]
ORDER BY [pub_seed_element], [pub_name];
GO









SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER TABLE [dbo].[contracts_db_columns]
  ADD [pub_exclude_element] BIT NOT NULL CONSTRAINT [DF_cdc_pub_exclude_element] DEFAULT (0);
GO

UPDATE [dbo].[contracts_db_columns]
SET    [pub_exclude_element] = 1
WHERE  [pub_name] IN ('ref_package_guid', 'priv_created_on', 'priv_modified_on');
GO

SELECT [pub_name], COUNT(*) AS n
FROM   [dbo].[contracts_db_columns]
WHERE  [pub_exclude_element] = 1
GROUP BY [pub_name]
ORDER BY [pub_name];
GO





SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER TABLE [dbo].[contracts_primitives_types]
  ADD [pub_mssql_sys_type] NVARCHAR(64) NULL;
GO

-- Direct sys.types matches: bare type names that resolve unambiguously.
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'bit'              WHERE [pub_name] = 'BOOL';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'tinyint'          WHERE [pub_name] = 'INT8';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'smallint'         WHERE [pub_name] = 'INT16';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'int'              WHERE [pub_name] = 'INT32';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'bigint'           WHERE [pub_name] = 'INT64';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'real'             WHERE [pub_name] = 'FLOAT32';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'float'            WHERE [pub_name] = 'FLOAT64';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'nvarchar'         WHERE [pub_name] = 'STRING';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'uniqueidentifier' WHERE [pub_name] = 'UUID';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'date'             WHERE [pub_name] = 'DATE';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'datetimeoffset'   WHERE [pub_name] = 'DATETIME_TZ';
UPDATE [dbo].[contracts_primitives_types] SET [pub_mssql_sys_type] = 'vector'           WHERE [pub_name] = 'VECTOR';

-- Ambiguous or parameterized variants stay NULL — only reached through
-- _resolve_type_name disambiguation rules.
-- TEXT: nvarchar + max_length=-1
-- JSON_DOC: nvarchar + max_length=-1 (collides with TEXT, can't be auto-resolved)
-- BINARY: varbinary + max_length=-1
-- INT64_IDENTITY: bigint + is_identity
-- DECIMAL_19_5/28_12/38_18: decimal + precision/scale
GO

SELECT pub_name, pub_mssql_type, pub_mssql_sys_type
FROM contracts_primitives_types
ORDER BY pub_name;
GO





SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

UPDATE c
  SET pub_exclude_element = 1
  FROM contracts_db_columns c
  WHERE c.pub_name IN ('ref_package_guid', 'priv_created_on', 'priv_modified_on', 'priv_installed_on')
    AND c.pub_exclude_element = 0;
GO

SELECT t.pub_name AS table_name, c.pub_name AS column_name, c.pub_exclude_element
  FROM contracts_db_columns c
  JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid
  WHERE c.pub_name IN ('ref_package_guid', 'priv_created_on', 'priv_modified_on', 'priv_installed_on')
  ORDER BY t.pub_name, c.pub_ordinal;
GO





SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER TABLE [dbo].[contracts_primitives_types]
  ADD [pub_emits_length] BIT NOT NULL CONSTRAINT [DF_cpt_pub_emits_length] DEFAULT (0);
GO

UPDATE [dbo].[contracts_primitives_types]
SET    [pub_emits_length] = 1
WHERE  [pub_name] IN ('STRING', 'VECTOR');
GO

SELECT [pub_name], [pub_mssql_type], [pub_emits_length]
FROM   [dbo].[contracts_primitives_types]
ORDER BY [pub_name];
GO



SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Drop the DEFAULT constraint first (named auto if added inline)
DECLARE @df_name NVARCHAR(256);
SELECT @df_name = dc.name
  FROM sys.default_constraints dc
  JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
  JOIN sys.tables t ON c.object_id = t.object_id
  WHERE t.name = 'service_modules_manifest' AND c.name = 'priv_installed_on';

IF @df_name IS NOT NULL
BEGIN
  EXEC('ALTER TABLE [dbo].[service_modules_manifest] DROP CONSTRAINT [' + @df_name + ']');
END;
GO

ALTER TABLE [dbo].[service_modules_manifest] DROP COLUMN [priv_installed_on];
GO

-- Verify
SELECT name FROM sys.columns
  WHERE object_id = OBJECT_ID('dbo.service_modules_manifest')
  ORDER BY column_id;
GO


DELETE c
  FROM contracts_db_columns c
  JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid
  WHERE t.pub_schema = 'dbo'
    AND t.pub_name = 'service_modules_manifest'
    AND c.pub_name = 'priv_installed_on';


    