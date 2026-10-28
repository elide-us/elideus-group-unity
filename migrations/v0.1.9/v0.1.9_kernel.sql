-- v0.1.9_kernel.sql: the 0.1.8 -> 0.1.9 gap. Idempotent: every statement is guarded, every row by key.
-- Adds the fifth module_role member, SERVICE (Aaron 2026-10-27): the role of the two kernel services that exist before
-- and around the modules, LifecycleManager (the status of the application) and ModuleManager (loading and unloading
-- modules). Registers both as contracts_modules rows with that role in the kernel package, so the listing gate can require
-- them by name on the first boot after this script; populate reflects their functions and models by its existing rules.
-- SERVICE rows are listed and mapped, never loaded as modules: the loader still instantiates MANAGER and EXECUTOR rows only.
-- Removes the 13 stale contracts_modules_* rows the v0.1.8 loop left behind (populate MERGEs and never prunes): the
-- BaseModule.module_manager function row (the alias property removed 2026-10-28) and 12 dependency rows the tree no
-- longer has (11 INHERITS edges straight to BaseProvider / BaseWorker from classes whose direct base is an abstract
-- provider or worker, and the WorkflowManagementModule -> HostExecutionModule edge carried over by the 0.1.8 rename).
-- Nothing references a function or dependency row by foreign key, so the deletes need no child handling.
-- APPLY WITH THE APPLICATION STOPPED, once the code of this release carries DATABASE_VERSION 0.1.9.
-- The version tail runs only when the SERVICE member and both service rows exist, the 13 stale rows are gone, and the
-- database is at 0.1.8 (or already 0.1.9), so a re-run against a later version never moves the version backwards.
-- Moves the database version to 0.1.9.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- module_role: SERVICE (value 4), kernel-owned, key by formula like the four existing members
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '7FA001CC-D978-5589-869D-8D957D1F31A9')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('7FA001CC-D978-5589-869D-8D957D1F31A9', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SERVICE', 4, 'Service slot: a kernel service that exists before and around the modules (LifecycleManager, ModuleManager). Listed and mapped, never loaded as a module.');
UPDATE [etg].[contracts_primitives_enum_types] SET [pub_notes] = 'MEP slot of a module: MANAGER (Operations, Maintenance, Interface), EXECUTOR (Execution, Management), PROVIDER, WORKER, SERVICE (the kernel services around the modules). NULL on BaseModule, the base of every slot.', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5E1DE2D2-E1F3-5B20-A126-7CFF92741146' AND [pub_notes] NOT LIKE '%SERVICE%';
GO

-- =====================================================================
-- The two kernel services, listed with role SERVICE so the listing gate can require them by name
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = '2B7F4853-C1EE-5C1B-ADA8-F69F1FD768A4')
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('2B7F4853-C1EE-5C1B-ADA8-F69F1FD768A4', '7FA001CC-D978-5589-869D-8D957D1F31A9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'LifecycleManager', 0, 'server/lifecycle_manager.py');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = 'FA69B9AC-4B40-5C04-B1A2-87E395BB8027')
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('FA69B9AC-4B40-5C04-B1A2-87E395BB8027', '7FA001CC-D978-5589-869D-8D957D1F31A9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ModuleManager', 0, 'server/module_manager.py');
GO

-- =====================================================================
-- Stale module rows left by the v0.1.8 loop: 1 function row, 12 dependency rows (verified 2026-10-28 against the exports)
-- =====================================================================
DELETE FROM [etg].[contracts_modules_functions] WHERE [key_guid] = '2875A5C3-77F0-576F-9F26-E755F96FBF68';
DELETE FROM [etg].[contracts_modules_dependencies] WHERE [key_guid] IN ('50241E67-269E-570F-A37B-C1DC21A08DED', '46EAC8EF-FEDC-5CCE-9CE7-EBE7B6C0BBEE', 'ECB4AF3A-26AD-5DA4-8BF1-EFAB6C0D4007', 'CD5E2281-1BFD-5A83-B766-69DA7EA045FD', '4E0A41ED-2DEE-5AC2-9EF6-F821C1AA5EEA', 'B7653AF6-1DE0-5088-A9B0-E6731505984D', 'AFB5F3C5-DF07-5680-ACE1-F4F7E8CEF154', 'EDAFD5E1-CABD-53AA-B35A-23666D6A5508', 'A7B5A230-5A72-5015-8373-7F04C21641DD', '9E3949EA-FAE9-5195-803F-C804E21C4528', '7344A090-1097-564C-B0E7-22BAD8327111', 'DBE14E04-6841-5B9D-96D0-828EC84E9B2E');
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.9
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '7FA001CC-D978-5589-869D-8D957D1F31A9')
   AND (SELECT COUNT(*) FROM [etg].[contracts_modules] WHERE [key_guid] IN ('2B7F4853-C1EE-5C1B-ADA8-F69F1FD768A4', 'FA69B9AC-4B40-5C04-B1A2-87E395BB8027')) = 2
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules_functions] WHERE [key_guid] = '2875A5C3-77F0-576F-9F26-E755F96FBF68')
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules_dependencies] WHERE [key_guid] IN ('50241E67-269E-570F-A37B-C1DC21A08DED', '46EAC8EF-FEDC-5CCE-9CE7-EBE7B6C0BBEE', 'ECB4AF3A-26AD-5DA4-8BF1-EFAB6C0D4007', 'CD5E2281-1BFD-5A83-B766-69DA7EA045FD', '4E0A41ED-2DEE-5AC2-9EF6-F821C1AA5EEA', 'B7653AF6-1DE0-5088-A9B0-E6731505984D', 'AFB5F3C5-DF07-5680-ACE1-F4F7E8CEF154', 'EDAFD5E1-CABD-53AA-B35A-23666D6A5508', 'A7B5A230-5A72-5015-8373-7F04C21641DD', '9E3949EA-FAE9-5195-803F-C804E21C4528', '7344A090-1097-564C-B0E7-22BAD8327111', 'DBE14E04-6841-5B9D-96D0-828EC84E9B2E'))
   AND (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.1.8', '0.1.9')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.9', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.9', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
