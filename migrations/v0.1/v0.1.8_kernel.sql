-- v0.1.8_kernel.sql: the 0.1.7 -> 0.1.8 gap. Idempotent: every statement is guarded, every row by key.
-- Renames the module registration of the kernel host executor to its new class name (KernelHostManagementModule ->
-- HostExecutionModule) and registers the new host manager (HostOperationsModule), so the listing gate of the loader passes
-- on the first boot after this script. Still to be authored in this version: the host_status enum keys as a database lookup;
-- the service_hosts parent table, the rename of the instance table to service_host_instances, the MERGE register and the
-- workflow history re-point.
-- APPLY WITH THE APPLICATION STOPPED. The Python code shipped in this release carries DATABASE_VERSION 0.1.8, so a boot
-- against a database that has not run this script is refused at the version gate.
-- The version tail runs only when the renamed row and the new row exist, the old row is gone, and the database is at 0.1.7
-- (or already 0.1.8), so a re-run against a later version never moves the version backwards.
-- Moves the database version to 0.1.8.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Module registration: KernelHostManagementModule is HostExecutionModule in the tree (server/kernel/host_execution_module.py,
-- role EXECUTOR unchanged, same three functions host_key / observe / reload, same three REQUIRES edges and INHERITS BaseModule).
-- contracts_modules keys on the class name, so the row is renamed by key: the new row is inserted, every row keyed on the old
-- module (its 3 function rows, its 4 outbound edges, the 1 inbound edge from WorkflowManagementModule, any sequence allocation)
-- moves to the new key under the key the formula derives from the new name, then the old row is deleted. The module key cannot
-- be updated in place: FK_cmf_module, FK_cmd_module, FK_cmd_dependency and FK_ssa_module reference it with no cascade.
-- The inbound WorkflowManagementModule edge is carried over as a rename only; the tree no longer has that dependency and
-- populate never prunes, so it is stale until removed.
-- HostOperationsModule (MANAGER, server/kernel/host_operations_module.py) is new and is registered here, because the loop
-- order is apply -> boot -> populate and the loader refuses a boot with a loaded module that has no row; populate later
-- MERGEs the same values and adds its function rows and edges.
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = '5083BB14-B9AA-554E-B88C-4818235921BC') AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2')
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('530456B5-093F-572E-BEBD-D96B1462FDC2', '916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'HostExecutionModule', 0, 'server/kernel/host_execution_module.py');
    UPDATE [etg].[contracts_modules_functions] SET [key_guid] = '296B5112-0B53-54EF-A549-54A6652DB227', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E7AEAD61-D1AA-58F7-8FD2-066FFED4CA78';
    UPDATE [etg].[contracts_modules_functions] SET [key_guid] = '75E7B2D0-D73E-5445-847D-86C2A74FD99D', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F0EDD597-C881-5A5C-9E8B-53CD3ADCA410';
    UPDATE [etg].[contracts_modules_functions] SET [key_guid] = '056507F5-CF99-5AD3-AA2C-C34207B34182', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DBCC27A0-1E2C-5E16-97AF-C44E821B9AFE';
    UPDATE [etg].[contracts_modules_dependencies] SET [key_guid] = 'A087F510-4C1F-582B-9F84-3BE95E28B41A', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '08C9FEBF-C952-5EBA-A81A-092470AD58CC';
    UPDATE [etg].[contracts_modules_dependencies] SET [key_guid] = '755AD8D3-7CB4-56A3-9095-1EF88F2386BC', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D693710B-5DB2-5FED-A33B-0A9F106BFBAF';
    UPDATE [etg].[contracts_modules_dependencies] SET [key_guid] = '23824378-53E8-54A1-B1E9-7B6686534E32', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CBC28B4D-D3A9-54EF-AE26-83CD106F4ECC';
    UPDATE [etg].[contracts_modules_dependencies] SET [key_guid] = '9666BB57-25D8-58D1-AA1E-F14919CCC0A8', [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E7522152-BD85-58DC-8272-D2BBE6B87EBB';
    UPDATE [etg].[contracts_modules_dependencies] SET [key_guid] = 'DBE14E04-6841-5B9D-96D0-828EC84E9B2E', [ref_dependency_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F24B6C63-5D78-5297-9428-948505E4CDF8';
    UPDATE [dbo].[system_sequence_allocations] SET [ref_module_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_module_guid] = '5083BB14-B9AA-554E-B88C-4818235921BC';
    DELETE FROM [etg].[contracts_modules] WHERE [key_guid] = '5083BB14-B9AA-554E-B88C-4818235921BC';
  COMMIT TRANSACTION;
END
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = '82391782-21D3-5E01-B9A1-89D4BA659C71')
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('82391782-21D3-5E01-B9A1-89D4BA659C71', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'HostOperationsModule', 0, 'server/kernel/host_operations_module.py');
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.8
-- =====================================================================
IF (SELECT COUNT(*) FROM [etg].[contracts_modules] WHERE [key_guid] IN ('530456B5-093F-572E-BEBD-D96B1462FDC2', '82391782-21D3-5E01-B9A1-89D4BA659C71')) = 2
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_modules] WHERE [key_guid] = '5083BB14-B9AA-554E-B88C-4818235921BC')
   AND (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.1.7', '0.1.8')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.8', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.8', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
