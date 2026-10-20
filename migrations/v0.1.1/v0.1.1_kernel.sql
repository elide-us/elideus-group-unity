-- v0.1.1_kernel.sql: the 0.1.0 -> 0.1.1 gap. Idempotent: every statement is guarded, procedures use CREATE OR ALTER.
-- Adds: the workflow engine tables, number sequences with their issuing procedures, the stored-procedure kind in the ETG,
-- three kernel enum types, the workflow_batch sequence, and moves the database version to 0.1.1.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Tables
-- =====================================================================
IF OBJECT_ID(N'[etg].[contracts_db_procedures]', N'U') IS NULL
CREATE TABLE [etg].[contracts_db_procedures] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_schema] NVARCHAR(128) NOT NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_body_mssql] NVARCHAR(MAX) NOT NULL,
  [pub_body_postgres] NVARCHAR(MAX) NULL,
  [pub_body_mysql] NVARCHAR(MAX) NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[service_workflow_definitions]', N'U') IS NULL
CREATE TABLE [dbo].[service_workflow_definitions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_steps] NVARCHAR(MAX) NOT NULL,
  [pub_can_retry] BIT DEFAULT (1) NOT NULL,
  [pub_max_attempts] TINYINT DEFAULT (3) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_workflow_queue]', N'U') IS NULL
CREATE TABLE [dbo].[system_workflow_queue] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_batch_number] BIGINT NOT NULL,
  [pub_steps] NVARCHAR(MAX) NOT NULL,
  [pub_can_retry] BIT DEFAULT (1) NOT NULL,
  [pub_max_attempts] TINYINT DEFAULT (3) NOT NULL,
  [pub_attempts] TINYINT DEFAULT (0) NOT NULL,
  [pub_started_on] DATETIMEOFFSET(7) NULL,
  [pub_finished_on] DATETIMEOFFSET(7) NULL,
  [pub_error] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[service_sequences]', N'U') IS NULL
CREATE TABLE [dbo].[service_sequences] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_last_number] BIGINT DEFAULT (0) NOT NULL,
  [pub_allocation_size] INT DEFAULT (1) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_sequence_allocations]', N'U') IS NULL
CREATE TABLE [dbo].[system_sequence_allocations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_sequence_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_consumer_guid] UNIQUEIDENTIFIER NULL,
  [pub_number_from] BIGINT NOT NULL,
  [pub_number_to] BIGINT NOT NULL,
  [pub_issued_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_swq_status_created' AND object_id = OBJECT_ID(N'[dbo].[system_workflow_queue]'))
CREATE NONCLUSTERED INDEX [IX_swq_status_created] ON [dbo].[system_workflow_queue] ([ref_status_enum_guid], [priv_created_on]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssa_sequence_issued' AND object_id = OBJECT_ID(N'[dbo].[system_sequence_allocations]'))
CREATE NONCLUSTERED INDEX [IX_ssa_sequence_issued] ON [dbo].[system_sequence_allocations] ([ref_sequence_guid], [pub_issued_on]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssa_consumer_guid' AND object_id = OBJECT_ID(N'[dbo].[system_sequence_allocations]'))
CREATE NONCLUSTERED INDEX [IX_ssa_consumer_guid] ON [dbo].[system_sequence_allocations] ([ref_consumer_guid]);
GO

-- Constraints (PK, UNIQUE)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_db_procedures' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [PK_contracts_db_procedures] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cdp_schema_name' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [UQ_cdp_schema_name] UNIQUE NONCLUSTERED ([pub_schema], [pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_workflow_definitions' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [PK_service_workflow_definitions] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_swd_name' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [UQ_swd_name] UNIQUE NONCLUSTERED ([pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_workflow_queue' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [PK_system_workflow_queue] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_sequences' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_sequences] ADD CONSTRAINT [PK_service_sequences] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_ss_name' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_sequences] ADD CONSTRAINT [UQ_ss_name] UNIQUE NONCLUSTERED ([pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_sequence_allocations' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [PK_system_sequence_allocations] PRIMARY KEY CLUSTERED ([key_guid]);
GO

-- Constraints (FOREIGN KEY)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_cdp_package' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [FK_cdp_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swd_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swd_disposition' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swq_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swq_definition' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_definition] FOREIGN KEY ([ref_definition_guid]) REFERENCES [dbo].[service_workflow_definitions] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swq_status' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swq_disposition' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_ss_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_sequences] ADD CONSTRAINT [FK_ss_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_ss_kind' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_sequences] ADD CONSTRAINT [FK_ss_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_ssa_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_ssa_sequence' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_sequence] FOREIGN KEY ([ref_sequence_guid]) REFERENCES [dbo].[service_sequences] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_ssa_module' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
GO

-- =====================================================================
-- Enums (kernel-owned; keys by formula, members keyed 'type.NAME')
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '23AD5199-726E-5DCC-8CEC-33B699A987CC')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'task_status', 'Workflow instance lifecycle: PENDING, RUNNING, COMPLETE, FAILED, CANCELLING.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = 'E171D014-E371-5B40-B757-2FB33D6A7C61')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'task_disposition', 'Undo semantics of a workflow instance: REVERSIBLE, IRREVERSIBLE, TRANSIENT, CANCELLABLE. Orthogonal to retry.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = 'F3A8534E-EBEA-5F52-804C-0BBEA2B03A41')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'sequence_kind', 'How a number sequence issues: STRICT (one number per call, gapless) or CACHED (pre-allocated block, unused remainder lost on restart).');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '543313DE-AF0F-581B-8DC5-99EB9892C865')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('543313DE-AF0F-581B-8DC5-99EB9892C865', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PENDING', 0, 'Declared, awaiting claim by the workflow worker.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'A2310AD9-FD9E-5276-ABAF-5FDE20DDC7EC')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('A2310AD9-FD9E-5276-ABAF-5FDE20DDC7EC', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RUNNING', 1, 'Claimed and executing. Stale-claim recovery returns an abandoned RUNNING row to PENDING and counts the attempt.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '3FF26BAD-8734-50D7-A839-D8E987A36671')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('3FF26BAD-8734-50D7-A839-D8E987A36671', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'COMPLETE', 2, 'Executed successfully. Terminal.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '4291EA63-A8B4-59E2-B724-7B506A8D6A09')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('4291EA63-A8B4-59E2-B724-7B506A8D6A09', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FAILED', 3, 'Execution failed; pub_error holds the detail. Re-declaration flips it back to PENDING when attempts remain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '9A8EB79B-B824-58F9-8404-CE2248734DF3')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('9A8EB79B-B824-58F9-8404-CE2248734DF3', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CANCELLING', 4, 'Cancellation requested. The worker aborts and transitions to FAILED or COMPLETE.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '933FF84A-8A6B-5AF3-9861-6319434F504B')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('933FF84A-8A6B-5AF3-9861-6319434F504B', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'REVERSIBLE', 0, 'Effect can be undone by a separately declared compensating task.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'F0497A46-374D-59C9-9CB2-45CBB99B9D1C')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('F0497A46-374D-59C9-9CB2-45CBB99B9D1C', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'IRREVERSIBLE', 1, 'Effect cannot be undone through the system; external recovery only.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'C761A53C-DCED-5FF6-94E0-39D926B02E16')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('C761A53C-DCED-5FF6-94E0-39D926B02E16', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'TRANSIENT', 2, 'No persistent effect; safe to discard mid-execution.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '843555AB-F2BD-5CCA-AEBF-08C3519D6685')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('843555AB-F2BD-5CCA-AEBF-08C3519D6685', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CANCELLABLE', 3, 'May be cancelled before or during execution without a compensating task.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'EA0EAF92-84DE-56F3-9D6A-70973BF6B26D')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('EA0EAF92-84DE-56F3-9D6A-70973BF6B26D', 'F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STRICT', 0, 'One number per call, issued and audited in one transaction; no gaps at issue.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '47D47931-B3DA-5C42-99DA-D11342315A00')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('47D47931-B3DA-5C42-99DA-D11342315A00', 'F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CACHED', 1, 'A block of pub_allocation_size numbers per call, served from the process cache; what is not used before a restart is lost.');
GO

-- The sequence the workflow queue draws its batch number from (core-owned package data; CACHED).
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_sequences] WHERE [key_guid] = '9F920430-687B-5368-87AC-0320CF496414')
INSERT INTO [dbo].[service_sequences] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_name], [pub_last_number], [pub_allocation_size], [pub_notes]) VALUES ('9F920430-687B-5368-87AC-0320CF496414', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '47D47931-B3DA-5C42-99DA-D11342315A00', 'workflow_batch', 0, 10, 'Traceable batch number stamped on every system_workflow_queue row at declaration.');
GO

-- =====================================================================
-- Procedures: issuing numbers. @module_guid = the requesting module's contracts_modules key;
-- @consumer_guid = the record the number is for, when known at issue. One ACID transaction each:
-- the sequence row is advanced and the audit row written under one commit; once returned, the number is burned.
-- Return shape (one model, from = to for STRICT): {"pub_number_from": n, "pub_number_to": m}.
-- =====================================================================
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
      FROM [dbo].[service_sequences] AS [ss] WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
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
      FROM [dbo].[service_sequences] AS [ss] WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
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
-- Version: the database is now at kernel 0.1.1
-- =====================================================================
UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
GO
