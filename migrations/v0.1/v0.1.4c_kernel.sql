-- v0.1.4c_kernel.sql: a follow-up to v0.1.4_kernel.sql and v0.1.4b_kernel.sql in the same version. Idempotent: every statement is
-- guarded and the procedures use CREATE OR ALTER, so a re-run is a no-op.
-- Renames dbo.service_sequences -> dbo.system_sequences (Aaron 2026-10-21: number sequences number the application's own records,
-- vouchers and batches, so they are system_ data, beside their allocation log dbo.system_sequence_allocations). With it: the
-- primary key name, the workflow_batch row's formula key (entity type = table name), the two core procedures that read the
-- table, and the ETG declaration rows of the old table name.
-- Does NOT move the database version: the database stays at 0.1.4.
-- Apply with the application STOPPED, and start it again only on the code that keys the batch sequence as
-- 'system_sequences:workflow_batch' (server/core/workflow_management_module.py): a running 0.1.4 process still asks for the old key.
-- After applying, run populate: it reflects dbo.system_sequences into the contracts_db_* declarations and re-reads the two
-- procedure bodies. Populate never deletes, so this script removes the old table's declaration rows itself (last batch).
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Table: rename, and the constraint whose name carries the table name
-- =====================================================================
-- The alias stays ss (the allocation log is ssa): UQ_ss_name, FK_ss_package and FK_ss_kind keep their names.
-- FK_ssa_sequence on [dbo].[system_sequence_allocations] needs nothing: a foreign key binds to the referenced table's object_id,
-- which sp_rename keeps. Renaming the PK constraint renames its index with it.
IF OBJECT_ID(N'[dbo].[service_sequences]', N'U') IS NOT NULL AND OBJECT_ID(N'[dbo].[system_sequences]', N'U') IS NULL
EXEC sp_rename N'dbo.service_sequences', N'system_sequences';
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_sequences' AND schema_id = SCHEMA_ID(N'dbo'))
  AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_sequences' AND schema_id = SCHEMA_ID(N'dbo'))
EXEC sp_rename N'dbo.PK_service_sequences', N'PK_system_sequences', N'OBJECT';
GO

-- =====================================================================
-- Re-key the workflow_batch row: uuid5(NS, 'service_sequences:workflow_batch') -> uuid5(NS, 'system_sequences:workflow_batch')
-- =====================================================================
-- One transaction: copy the row under the new key (every column, pub_last_number included, so no number is issued twice), move the
-- allocation log onto it, delete the old row. UQ_ss_name holds pub_name unique, so the old row's name is parked on its own key
-- before the copy goes in.
IF OBJECT_ID(N'[dbo].[system_sequences]', N'U') IS NOT NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  IF EXISTS (SELECT 1 FROM [dbo].[system_sequences] WITH (UPDLOCK, HOLDLOCK) WHERE [key_guid] = '9F920430-687B-5368-87AC-0320CF496414')
    AND NOT EXISTS (SELECT 1 FROM [dbo].[system_sequences] WITH (UPDLOCK, HOLDLOCK) WHERE [key_guid] = '35D184E5-72A5-5C8E-A45D-7EBD15E64D9B')
  BEGIN
    DECLARE @old TABLE (
      [ref_package_guid] UNIQUEIDENTIFIER NULL,
      [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
      [pub_name] NVARCHAR(64) NOT NULL,
      [pub_last_number] BIGINT NOT NULL,
      [pub_allocation_size] INT NOT NULL,
      [pub_notes] NVARCHAR(512) NULL,
      [priv_created_on] DATETIMEOFFSET(7) NOT NULL,
      [priv_modified_on] DATETIMEOFFSET(7) NOT NULL
    );
    INSERT INTO @old ([ref_package_guid], [ref_kind_enum_guid], [pub_name], [pub_last_number], [pub_allocation_size], [pub_notes], [priv_created_on], [priv_modified_on])
      SELECT [ss].[ref_package_guid], [ss].[ref_kind_enum_guid], [ss].[pub_name], [ss].[pub_last_number], [ss].[pub_allocation_size], [ss].[pub_notes], [ss].[priv_created_on], [ss].[priv_modified_on]
      FROM [dbo].[system_sequences] AS [ss]
      WHERE [ss].[key_guid] = '9F920430-687B-5368-87AC-0320CF496414';
    UPDATE [dbo].[system_sequences] SET [pub_name] = N'9F920430-687B-5368-87AC-0320CF496414' WHERE [key_guid] = '9F920430-687B-5368-87AC-0320CF496414';
    INSERT INTO [dbo].[system_sequences] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_name], [pub_last_number], [pub_allocation_size], [pub_notes], [priv_created_on], [priv_modified_on])
      SELECT '35D184E5-72A5-5C8E-A45D-7EBD15E64D9B', [o].[ref_package_guid], [o].[ref_kind_enum_guid], [o].[pub_name], [o].[pub_last_number], [o].[pub_allocation_size], [o].[pub_notes], [o].[priv_created_on], [o].[priv_modified_on]
      FROM @old AS [o];
    UPDATE [dbo].[system_sequence_allocations] SET [ref_sequence_guid] = '35D184E5-72A5-5C8E-A45D-7EBD15E64D9B', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_sequence_guid] = '9F920430-687B-5368-87AC-0320CF496414';
    DELETE FROM [dbo].[system_sequences] WHERE [key_guid] = '9F920430-687B-5368-87AC-0320CF496414';
  END
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Procedures (core-owned; keys by formula over schema.name): the stored definition rows, then the procedures themselves
-- =====================================================================
UPDATE [etg].[contracts_db_procedures] SET [pub_body_mssql] = REPLACE([pub_body_mssql], N'[dbo].[service_sequences]', N'[dbo].[system_sequences]'), [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7ED9F193-4413-55D0-8845-DEFF75BD3908' AND [pub_body_mssql] LIKE N'%service_sequences%';
UPDATE [etg].[contracts_db_procedures] SET [pub_body_mssql] = REPLACE([pub_body_mssql], N'[dbo].[service_sequences]', N'[dbo].[system_sequences]'), [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F69DDD00-C00D-5523-B875-CEAA3930355B' AND [pub_body_mssql] LIKE N'%service_sequences%';
GO
CREATE OR ALTER PROCEDURE [dbo].[sequence_next]
  @sequence_guid UNIQUEIDENTIFIER,
  @module_guid UNIQUEIDENTIFIER,
  @consumer_guid UNIQUEIDENTIFIER = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  DECLARE @issued TABLE ([pub_number_from] BIGINT NOT NULL, [pub_number_to] BIGINT NOT NULL);
  BEGIN TRANSACTION;
    UPDATE [ss]
      SET [ss].[pub_last_number] = [ss].[pub_last_number] + 1,
          [ss].[priv_modified_on] = SYSDATETIMEOFFSET()
      OUTPUT [inserted].[pub_last_number], [inserted].[pub_last_number] INTO @issued ([pub_number_from], [pub_number_to])
      FROM [dbo].[system_sequences] AS [ss] WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
      JOIN [etg].[contracts_primitives_enums] AS [cpe] ON [cpe].[key_guid] = [ss].[ref_kind_enum_guid]
      WHERE [ss].[key_guid] = @sequence_guid
        AND [cpe].[pub_name] = 'STRICT';
    IF @@ROWCOUNT <> 1
      THROW 50001, 'sequence_next: no STRICT sequence with that key', 1;
    INSERT INTO [dbo].[system_sequence_allocations]
      ([key_guid], [ref_package_guid], [ref_sequence_guid], [ref_module_guid], [ref_consumer_guid], [pub_number_from], [pub_number_to])
      SELECT NEWID(), [cm].[ref_package_guid], @sequence_guid, [cm].[key_guid], @consumer_guid, [i].[pub_number_from], [i].[pub_number_to]
      FROM @issued AS [i]
      JOIN [etg].[contracts_modules] AS [cm] ON [cm].[key_guid] = @module_guid;
    IF @@ROWCOUNT <> 1
      THROW 50003, 'sequence: requesting module is not a contract row', 1;
  COMMIT TRANSACTION;
  SELECT [i].[pub_number_from], [i].[pub_number_to]
  FROM @issued AS [i]
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
END
GO
CREATE OR ALTER PROCEDURE [dbo].[sequence_allocate]
  @sequence_guid UNIQUEIDENTIFIER,
  @module_guid UNIQUEIDENTIFIER,
  @consumer_guid UNIQUEIDENTIFIER = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  DECLARE @issued TABLE ([pub_number_from] BIGINT NOT NULL, [pub_number_to] BIGINT NOT NULL);
  BEGIN TRANSACTION;
    UPDATE [ss]
      SET [ss].[pub_last_number] = [ss].[pub_last_number] + [ss].[pub_allocation_size],
          [ss].[priv_modified_on] = SYSDATETIMEOFFSET()
      OUTPUT [deleted].[pub_last_number] + 1, [inserted].[pub_last_number] INTO @issued ([pub_number_from], [pub_number_to])
      FROM [dbo].[system_sequences] AS [ss] WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
      JOIN [etg].[contracts_primitives_enums] AS [cpe] ON [cpe].[key_guid] = [ss].[ref_kind_enum_guid]
      WHERE [ss].[key_guid] = @sequence_guid
        AND [cpe].[pub_name] = 'CACHED';
    IF @@ROWCOUNT <> 1
      THROW 50002, 'sequence_allocate: no CACHED sequence with that key', 1;
    INSERT INTO [dbo].[system_sequence_allocations]
      ([key_guid], [ref_package_guid], [ref_sequence_guid], [ref_module_guid], [ref_consumer_guid], [pub_number_from], [pub_number_to])
      SELECT NEWID(), [cm].[ref_package_guid], @sequence_guid, [cm].[key_guid], @consumer_guid, [i].[pub_number_from], [i].[pub_number_to]
      FROM @issued AS [i]
      JOIN [etg].[contracts_modules] AS [cm] ON [cm].[key_guid] = @module_guid;
    IF @@ROWCOUNT <> 1
      THROW 50003, 'sequence: requesting module is not a contract row', 1;
  COMMIT TRANSACTION;
  SELECT [i].[pub_number_from], [i].[pub_number_to]
  FROM @issued AS [i]
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
END
GO

-- =====================================================================
-- ETG declarations of the old table name (populate re-reflects the table as dbo.system_sequences and never deletes)
-- =====================================================================
-- Old table key: uuid5(NS, 'contracts_db_tables:dbo.service_sequences'). FK-safe order: constraint columns, index columns,
-- constraints, indexes, columns, the table row. FK_ssa_sequence's declaration (on dbo.system_sequence_allocations) points at the old
-- table and its key_guid column, so it goes too; populate writes it back under the same key, pointing at dbo.system_sequences.
IF OBJECT_ID(N'[dbo].[service_sequences]', N'U') IS NULL
  AND EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD')
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    DELETE FROM [etg].[contracts_db_constraint_columns]
      WHERE [ref_constraint_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD' OR [ref_referenced_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD')
        OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD')
        OR [ref_referenced_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD');
    DELETE FROM [etg].[contracts_db_index_columns]
      WHERE [ref_index_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD')
        OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD');
    DELETE FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD' OR [ref_referenced_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD';
    DELETE FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD';
    DELETE FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD';
    DELETE FROM [etg].[contracts_db_tables] WHERE [key_guid] = '472AEAA3-94FC-5DDD-BC89-473DEF0583CD';
  COMMIT TRANSACTION;
END
GO
