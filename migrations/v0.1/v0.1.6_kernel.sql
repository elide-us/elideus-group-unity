-- v0.1.6_kernel.sql: the 0.1.5 -> 0.1.6 gap. Idempotent: every statement is guarded, every row by key.
-- Splits the two facts etg.contracts_db_tables.pub_seed_element carried (Aaron 2026-10-21) into two homes:
-- 1. Installer seed membership and order stays in pub_seed_element, now AUTHORED: nonzero only on the four tables whose
--    rows the bootstrap DDL carries, the value their emission order (contracts_primitives_types 1, service_packages_manifest 2,
--    contracts_primitives_enum_types 3, contracts_primitives_enums 4); every other table 0. populate no longer writes it.
-- 2. Package-export membership moves to dbo.service_package_tables (setup-owned, so the list ships in setup.json.gz and
--    lists itself): one row per table whose rows are package data. make package orders the set by FK depth read from the
--    live sys.foreign_keys at make time, so no order is stored. Runtime data is deliberately absent.
-- PRECONDITION: apply AFTER the v0.1.5 loop has run populate on 0.1.5. The export rows of the five
-- etg.contracts_primitives_libraries* tables reference declaration rows only populate creates. Without them the export
-- batch THROWs before inserting a row, and the version tail runs only when all 33 export rows exist, so the database stays
-- at 0.1.5 instead of reaching 0.1.6 with a partial export set; run populate, then re-run this script. This script inserts
-- the declaration row of dbo.service_package_tables itself, so the table can list itself before populate sees it;
-- populate later MERGEs the same values.
-- Moves the database version to 0.1.6.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Tables
-- =====================================================================
IF OBJECT_ID(N'[dbo].[service_package_tables]', N'U') IS NULL
CREATE TABLE [dbo].[service_package_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

-- Constraints (PK, UNIQUE, CHECK)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_package_tables' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [PK_service_package_tables] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_spt_table' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [UQ_spt_table] UNIQUE NONCLUSTERED ([ref_table_guid]);
GO

-- Constraints (FOREIGN KEY)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_spt_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [FK_spt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_spt_table' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [FK_spt_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
GO

-- =====================================================================
-- Declaration row (kernel-owned, as populate stamps every declaration)
-- =====================================================================
-- The export table lists itself below, and FK_spt_table needs its declaration row before populate ever runs on 0.1.6.
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '8B62701E-A88C-5C1E-A0FA-0B879FC47214')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('8B62701E-A88C-5C1E-A0FA-0B879FC47214', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'service_package_tables', 'dbo', 'spt', 0);
GO

-- =====================================================================
-- Installer seed set (authored): pub_seed_element = emission order on the four bootstrap tables, 0 on every other
-- =====================================================================
UPDATE [etg].[contracts_db_tables] SET [pub_seed_element] = 0, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_seed_element] <> 0 AND [key_guid] NOT IN ('499F548D-73A0-5A49-9423-8683867B5190', '91EEE511-5EB6-5E95-8AB0-9B088E36206D', '6045697D-9AAC-5937-9007-41583D2D2A36', '8F1265F6-5429-5990-950E-374782CAACA5');
-- 1: etg.contracts_primitives_types
UPDATE [etg].[contracts_db_tables] SET [pub_seed_element] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '499F548D-73A0-5A49-9423-8683867B5190' AND [pub_seed_element] <> 1;
-- 2: dbo.service_packages_manifest
UPDATE [etg].[contracts_db_tables] SET [pub_seed_element] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '91EEE511-5EB6-5E95-8AB0-9B088E36206D' AND [pub_seed_element] <> 2;
-- 3: etg.contracts_primitives_enum_types
UPDATE [etg].[contracts_db_tables] SET [pub_seed_element] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6045697D-9AAC-5937-9007-41583D2D2A36' AND [pub_seed_element] <> 3;
-- 4: etg.contracts_primitives_enums
UPDATE [etg].[contracts_db_tables] SET [pub_seed_element] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '8F1265F6-5429-5990-950E-374782CAACA5' AND [pub_seed_element] <> 4;
GO

-- =====================================================================
-- Package export set (setup-owned; keys by formula)
-- =====================================================================
-- Absent by design, runtime data no package carries: dbo.service_hosts, dbo.system_workflow_queue,
-- dbo.system_workflow_history, dbo.system_sequence_allocations.
-- Precondition: populate on 0.1.5 created the five library declaration rows the export rows reference.
IF (SELECT COUNT(*) FROM [etg].[contracts_db_tables] WHERE [key_guid] IN ('FCEA3BAA-7EE6-5234-830B-6D7742D2862A', '31C0B435-DFAB-5ECE-AE78-254299FB1F07', '60C74B82-0CC4-571C-B177-0F00AF917B40', '766E4CD8-8221-550C-9627-13A7B68D5EA5', '941DCB16-E66C-5683-92AB-EDC3E8BEF90B')) < 5
  THROW 50000, 'v0.1.6: run populate on 0.1.5 first, then re-run this script', 1;
-- etg
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '994645B3-8A3C-5944-A86C-C82E5BD4DA9C')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('994645B3-8A3C-5944-A86C-C82E5BD4DA9C', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '499F548D-73A0-5A49-9423-8683867B5190');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '8AAE616A-2FB9-5BF0-B2BA-F879B2AA58EC')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('8AAE616A-2FB9-5BF0-B2BA-F879B2AA58EC', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '6045697D-9AAC-5937-9007-41583D2D2A36');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '45D39EC9-993F-5FAB-A12D-952CE73F733F')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('45D39EC9-993F-5FAB-A12D-952CE73F733F', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '8F1265F6-5429-5990-950E-374782CAACA5');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'F5E60CFD-E9A3-5C68-BEC6-13365C5826C6')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('F5E60CFD-E9A3-5C68-BEC6-13365C5826C6', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'CAD055F6-8D16-54A3-80EC-674953D98AAB');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '85728892-BE8F-562C-B0D7-4E2D018D34C3')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('85728892-BE8F-562C-B0D7-4E2D018D34C3', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '5ED7D3AA-3C6E-5671-85B1-41104F5EBDEE');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '85950C7D-D201-5111-9F91-FBF76F2E7506')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('85950C7D-D201-5111-9F91-FBF76F2E7506', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '3898C97B-90C4-56CA-83EA-2F82D5F15A5B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '888D881E-C5C4-57AA-A2E8-D6256B208AB1')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('888D881E-C5C4-57AA-A2E8-D6256B208AB1', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '5645CCCC-1EC8-57D5-B63A-7716A06846DB');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'F189FF9A-6D51-5AAB-B649-2B3AA36775CC')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('F189FF9A-6D51-5AAB-B649-2B3AA36775CC', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '3AAAC83C-13F2-5992-AE2B-8CD07D00F97A');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'CB83C153-B19E-5A31-8295-3C1702E6CF86')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('CB83C153-B19E-5A31-8295-3C1702E6CF86', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '9475ABC3-1853-5023-B150-E325A11E2F92');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '12172AEA-B8B8-5408-9AAC-564655B0EDC5')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('12172AEA-B8B8-5408-9AAC-564655B0EDC5', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '70C033AA-835C-5271-8C5E-8346156516EE');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '2ACA608C-8429-577A-A572-CD7A93274030')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('2ACA608C-8429-577A-A572-CD7A93274030', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '76CFF2AF-F36D-51FD-8FD7-02AC01BBC429');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '401A6098-45A7-5335-8736-04A6EA91D836')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('401A6098-45A7-5335-8736-04A6EA91D836', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '68B0EABF-3BB4-569B-B860-52E053EA5B63');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B93855E0-F186-52D9-ABB0-C61576AB6A14')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B93855E0-F186-52D9-ABB0-C61576AB6A14', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '78E49B7C-E765-5B5C-8696-4FF21DDB821C');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '7C3348F1-8588-5C6F-BE4B-419A11BA7129')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('7C3348F1-8588-5C6F-BE4B-419A11BA7129', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '075B357F-2A55-5277-9F6E-AC80045AE7CE')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('075B357F-2A55-5277-9F6E-AC80045AE7CE', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'D495E25E-146A-5916-9B8A-A8FCD8A7B127');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '574BA5EF-3D9E-5156-ABE3-7B2985F1B03A')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('574BA5EF-3D9E-5156-ABE3-7B2985F1B03A', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'D9569D01-628B-5D30-B5BF-32E01482A390');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'BE8B058C-99B9-5F5E-86CC-2B055A483851')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('BE8B058C-99B9-5F5E-86CC-2B055A483851', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '0F1A46F1-99DB-5AF8-BA34-D071DCA3408B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B4B76057-88BC-54D4-ABBC-E3341E371D80')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B4B76057-88BC-54D4-ABBC-E3341E371D80', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'A1895638-F8C6-599D-91D9-87143AC4A3A7');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '79E840AD-9B17-57D4-A7E2-299A144A63B6')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('79E840AD-9B17-57D4-A7E2-299A144A63B6', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'AD2DA31E-605E-5F41-A954-1567C2796F71');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '4B8A4FB3-FE38-519F-AF92-6CBAEF397F6D')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('4B8A4FB3-FE38-519F-AF92-6CBAEF397F6D', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'FCEA3BAA-7EE6-5234-830B-6D7742D2862A');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '86B18490-6E4D-5762-95EF-0CBC22BDD5BD')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('86B18490-6E4D-5762-95EF-0CBC22BDD5BD', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '31C0B435-DFAB-5ECE-AE78-254299FB1F07');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '090F06A0-8043-5425-A536-B9087F988B2A')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('090F06A0-8043-5425-A536-B9087F988B2A', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '60C74B82-0CC4-571C-B177-0F00AF917B40');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B2332809-B4DE-56E1-87FD-68DF9376E1C7')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B2332809-B4DE-56E1-87FD-68DF9376E1C7', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '766E4CD8-8221-550C-9627-13A7B68D5EA5');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '83EE54A2-C821-5CAA-AE87-10057277C787')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('83EE54A2-C821-5CAA-AE87-10057277C787', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '941DCB16-E66C-5683-92AB-EDC3E8BEF90B');
-- dbo
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'EC044062-15C7-5A63-BFD5-9FEEB16CEF50')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('EC044062-15C7-5A63-BFD5-9FEEB16CEF50', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '91EEE511-5EB6-5E95-8AB0-9B088E36206D');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'BFC1BBF6-EE97-54D4-B266-F15D2A9AC2D5')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('BFC1BBF6-EE97-54D4-B266-F15D2A9AC2D5', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'AA6A6163-FA21-5936-9499-EA4C366F6FE9');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '4C52A69E-13AA-5D0D-A2E5-D2315335E6E1')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('4C52A69E-13AA-5D0D-A2E5-D2315335E6E1', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'A46113D1-AB26-5773-AFB6-7BDC20E03C60');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '0F4CC355-81FF-52D8-9438-D727E5A007F0')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('0F4CC355-81FF-52D8-9438-D727E5A007F0', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '583E0E80-3648-5653-972A-B1090BDB1362');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '0DA9835A-C926-5ED4-86CC-8FE0947D92DB')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('0DA9835A-C926-5ED4-86CC-8FE0947D92DB', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '120AFCE1-97D6-57AE-B786-2F040262E60E');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '7C3E58AA-20E0-510B-AA4F-C4FEDD5146F5')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('7C3E58AA-20E0-510B-AA4F-C4FEDD5146F5', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '94148736-392D-5424-B5CE-2840D0ED2A0B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '59A16953-6961-5B29-A25C-4D8A291E5CD8')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('59A16953-6961-5B29-A25C-4D8A291E5CD8', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'C02E322E-2B03-5AE5-A3D9-F7FCFB340D08');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'D6D7D147-29E4-5786-BAF7-E36C93400050')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('D6D7D147-29E4-5786-BAF7-E36C93400050', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '8FC03AB8-D609-5EFB-84FE-6D63CCC3833B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B52621CD-FD4E-5FAE-A13E-34159F7E73AA')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B52621CD-FD4E-5FAE-A13E-34159F7E73AA', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '8B62701E-A88C-5C1E-A0FA-0B879FC47214');
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.6
-- =====================================================================
-- Only with the full export set: a THROW above ends its batch, not the script, so this batch still runs.
IF (SELECT COUNT(*) FROM [dbo].[service_package_tables]) = 33
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.6', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.6', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
