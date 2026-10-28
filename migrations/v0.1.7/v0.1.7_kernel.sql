-- v0.1.7_kernel.sql: the 0.1.6 -> 0.1.7 gap. Idempotent: every statement is guarded, every row by key.
-- Renames the 9 database-operation aliases that lacked a domain segment (db:host:*, db:sequence:*) to the five-segment form
-- db:<domain>:<subdomain>:<function>:<version>. Every other alias already has five segments and is left as it is.
-- Each row is updated in place in etg.contracts_db_operations: pub_op moves to the new op string and key_guid moves to the
-- key the formula derives from it (uuid5 of 'contracts_db_operations:' + pub_op). Only key_guid, pub_op and priv_modified_on
-- change; query text, models, package, notes and bootstrap flags are untouched. Each update runs only while the old key exists and the
-- new key does not, so a re-run is a no-op.
-- APPLY WITH THE APPLICATION STOPPED. The Python code shipped in this release carries DATABASE_VERSION 0.1.7 and names the
-- new op strings, so a boot against a database that has not run this script is refused at the version gate.
-- 7 of the 9 rows are kernel-package rows (host) and 2 are core-package rows (sequence). After applying, the v0.1.6
-- kernel.json.gz, core.json.gz, installer and bacpac are stale: run the loop (populate, make installer, make package
-- kernel / core / setup) so no package carrying the old keys is ever installed over this database.
-- Also removes the stale module registration rows: the two left by the kernel host provider/worker class rename and
-- the eight left by folding the security roles / entitlements MEPs into the provider-less security and entitlements modules.
-- Registers the two entitlements modules that replace them, so the first boot after this script can load them.
-- The version tail runs only when all 9 new keys exist, none of the 9 old keys remain, the stale module rows are gone, and the database is at 0.1.6
-- (or already 0.1.7), so a re-run against a later version never moves the version backwards.
-- Moves the database version to 0.1.7.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- host (domain service)
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '98B8B36C-443F-5378-BF6A-E196AF88501E') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '1BC3B206-421B-53D7-83FB-9D6E1D44E1AC')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = '1BC3B206-421B-53D7-83FB-9D6E1D44E1AC', [pub_op] = 'db:service:host:register:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '98B8B36C-443F-5378-BF6A-E196AF88501E';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '52FDA689-1D3D-521D-94BF-14BECD106FA7') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '667DD044-B6D0-5570-9DFA-EDDBDFD9F251')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = '667DD044-B6D0-5570-9DFA-EDDBDFD9F251', [pub_op] = 'db:service:host:seal:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '52FDA689-1D3D-521D-94BF-14BECD106FA7';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'C9A3C8BF-EB22-528C-8415-95629EACABF4') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'E3C92243-BAF0-5E19-9561-A0AA78B1E1FC')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = 'E3C92243-BAF0-5E19-9561-A0AA78B1E1FC', [pub_op] = 'db:service:host:set_status:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C9A3C8BF-EB22-528C-8415-95629EACABF4';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '2B49858D-892D-5D09-9615-EF07E454FEB3') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'B02D6F83-3F72-51F0-81FB-22CF9A3CBF0D')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = 'B02D6F83-3F72-51F0-81FB-22CF9A3CBF0D', [pub_op] = 'db:service:host:heartbeat:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2B49858D-892D-5D09-9615-EF07E454FEB3';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '257C0536-1A88-51E3-8F7F-22A8D2754870') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '3D5805BE-C4AB-5DA3-86CF-EF11E4007F35')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = '3D5805BE-C4AB-5DA3-86CF-EF11E4007F35', [pub_op] = 'db:service:host:read:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '257C0536-1A88-51E3-8F7F-22A8D2754870';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '0D63E471-5C33-5F96-8787-D52E0C47D31B') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '014F5267-B2C6-5E60-8B47-D92E1E8C635D')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = '014F5267-B2C6-5E60-8B47-D92E1E8C635D', [pub_op] = 'db:service:host:release_stale:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0D63E471-5C33-5F96-8787-D52E0C47D31B';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '174A087F-58FA-5D12-9DA5-29573ABD6406') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'B9B1AFC0-9CFD-5DBF-9A94-421A2E5E1E8C')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = 'B9B1AFC0-9CFD-5DBF-9A94-421A2E5E1E8C', [pub_op] = 'db:service:host:reload:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '174A087F-58FA-5D12-9DA5-29573ABD6406';
GO

-- =====================================================================
-- sequence (domain system)
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '7063D5D1-267B-5435-8D14-01196E3EB785') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'C2E2FCC6-0712-5F5A-BC50-D77EFB7FD418')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = 'C2E2FCC6-0712-5F5A-BC50-D77EFB7FD418', [pub_op] = 'db:system:sequence:allocate:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7063D5D1-267B-5435-8D14-01196E3EB785';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '4F6A8C67-468C-5353-BF21-2C13DB9DBAD9') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'A403BA68-8CFB-5691-BCDE-8EC3D9616030')
UPDATE [etg].[contracts_db_operations] SET [key_guid] = 'A403BA68-8CFB-5691-BCDE-8EC3D9616030', [pub_op] = 'db:system:sequence:next:1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4F6A8C67-468C-5353-BF21-2C13DB9DBAD9';
GO

-- =====================================================================
-- Stale module registrations: KernelHostProvider and KernelHostWorker were renamed in the tree
-- (host_execution_providers/aca_transaction_*.py). contracts_modules keys on the class name, populate
-- MERGEs the new names and never prunes, so the old rows and their INHERITS edges are removed here in
-- FK-safe order. No function rows exist on either (their functions are declared on the abstract bases).
-- Guarded on no sequence allocation referencing them. populate rewrites the new rows under their own keys.
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20'))
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules_functions] WHERE [ref_module_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20'))
   AND NOT EXISTS (SELECT 1 FROM [dbo].[system_sequence_allocations] WHERE [ref_module_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20'))
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    DELETE FROM [etg].[contracts_modules_dependencies] WHERE [key_guid] IN ('1D427689-66B2-5D27-AD52-399CBB645069', 'FB4CB943-A538-544F-967E-C6BBBF43C862') OR [ref_module_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20') OR [ref_dependency_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20');
    DELETE FROM [etg].[contracts_modules] WHERE [key_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20');
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Retired module registrations: the security roles and security entitlements MEPs (manager, executor,
-- abstract provider, database provider x2) are folded into security_*_module.py and entitlements_*_module.py
-- with no provider layer (Aaron 2026-10-28). Their 8 contracts_modules rows, 41 function rows and every
-- dependency edge on either side are removed in FK-safe order; populate re-registers the four modules that
-- replace them. Without this the loader refuses the boot: a listed MANAGER/EXECUTOR row with no class on disk.
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00'))
   AND NOT EXISTS (SELECT 1 FROM [dbo].[system_sequence_allocations] WHERE [ref_module_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00'))
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    DELETE FROM [etg].[contracts_modules_functions] WHERE [ref_module_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00');
    DELETE FROM [etg].[contracts_modules_dependencies] WHERE [ref_module_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00') OR [ref_dependency_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00');
    DELETE FROM [etg].[contracts_modules] WHERE [key_guid] IN ('2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00');
  COMMIT TRANSACTION;
END
-- The two modules that replace them must be listed BEFORE the first boot: the loader instantiates only listed
-- MANAGER/EXECUTOR rows, and SecurityExecutionModule depends on EntitlementsOperationsModule at startup. The loop
-- order is apply -> boot -> populate, so the rows are inserted here; populate later MERGEs the same values.
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = 'FD8366ED-1ED1-5C86-B6EC-B75A4A8856C7')
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('FD8366ED-1ED1-5C86-B6EC-B75A4A8856C7', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'EntitlementsOperationsModule', 0, 'server/core/entitlements_operations_module.py');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = 'E065E280-B32F-586B-A860-370A1F23BC8C')
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('E065E280-B32F-586B-A860-370A1F23BC8C', '916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'EntitlementsExecutionModule', 0, 'server/core/entitlements_execution_module.py');
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.7
-- =====================================================================
IF (SELECT COUNT(*) FROM [etg].[contracts_db_operations] WHERE [key_guid] IN ('1BC3B206-421B-53D7-83FB-9D6E1D44E1AC', '667DD044-B6D0-5570-9DFA-EDDBDFD9F251', 'E3C92243-BAF0-5E19-9561-A0AA78B1E1FC', 'B02D6F83-3F72-51F0-81FB-22CF9A3CBF0D', '3D5805BE-C4AB-5DA3-86CF-EF11E4007F35', '014F5267-B2C6-5E60-8B47-D92E1E8C635D', 'B9B1AFC0-9CFD-5DBF-9A94-421A2E5E1E8C', 'C2E2FCC6-0712-5F5A-BC50-D77EFB7FD418', 'A403BA68-8CFB-5691-BCDE-8EC3D9616030')) = 9
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] IN ('98B8B36C-443F-5378-BF6A-E196AF88501E', '52FDA689-1D3D-521D-94BF-14BECD106FA7', 'C9A3C8BF-EB22-528C-8415-95629EACABF4', '2B49858D-892D-5D09-9615-EF07E454FEB3', '257C0536-1A88-51E3-8F7F-22A8D2754870', '0D63E471-5C33-5F96-8787-D52E0C47D31B', '174A087F-58FA-5D12-9DA5-29573ABD6406', '7063D5D1-267B-5435-8D14-01196E3EB785', '4F6A8C67-468C-5353-BF21-2C13DB9DBAD9'))
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] IN ('6F07D8F4-7F0B-5432-818B-56DB453D2DD6', '81C579B4-75D9-560E-943B-0485F7433A20', '2235E42C-8B4B-5A15-9996-8C2A019B1716', '7187A42D-9D4C-5FBA-8BDB-F7BB1299AA8A', '30A1C893-618E-5817-823E-EB857610A22B', '93480DBC-85B5-50EE-9DA6-0DBE01302D40', '859424B6-B503-50FB-BD62-CE04AE31CC06', 'E4E89A74-FF11-5F4D-8B30-9061E71D0831', '8AB6A7CB-26A6-5E4A-B6EB-A3E865B4838A', '490F7A28-3C38-5425-A290-0C0D36E70D00'))
   AND (SELECT COUNT(*) FROM [etg].[contracts_modules] WHERE [key_guid] IN ('FD8366ED-1ED1-5C86-B6EC-B75A4A8856C7', 'E065E280-B32F-586B-A860-370A1F23BC8C')) = 2
   AND (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.1.6', '0.1.7')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.7', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.7', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
