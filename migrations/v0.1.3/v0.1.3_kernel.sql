-- v0.1.3_kernel.sql: the 0.1.2 -> 0.1.3 gap. Idempotent: every statement is guarded, every row by key.
-- Adds: running-instance tracking (H0) -- the kernel-owned host registry dbo.service_hosts, the host_status enum, the
-- kernel registry operations the host module dispatches with their models and fields, and moves the database version to 0.1.3.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Tables
-- =====================================================================
IF OBJECT_ID(N'[dbo].[service_hosts]', N'U') IS NULL
CREATE TABLE [dbo].[service_hosts] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_host_name] NVARCHAR(256) NOT NULL,
  [pub_pid] INT NOT NULL,
  [pub_kernel_version] NVARCHAR(64) NOT NULL,
  [pub_core_version] NVARCHAR(64) NULL,
  [pub_connections] INT DEFAULT (0) NOT NULL,
  [pub_started_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_heartbeat_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_lease_until] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sh_status_heartbeat' AND object_id = OBJECT_ID(N'[dbo].[service_hosts]'))
CREATE NONCLUSTERED INDEX [IX_sh_status_heartbeat] ON [dbo].[service_hosts] ([ref_status_enum_guid], [pub_heartbeat_on]);
GO

-- Constraints (PK, UNIQUE)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_hosts' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [PK_service_hosts] PRIMARY KEY CLUSTERED ([key_guid]);
GO

-- Constraints (FOREIGN KEY)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_sh_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_sh_status' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
GO

-- =====================================================================
-- System configuration (kernel-owned; key by formula 'service_system_configuration:<pub_key>')
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '2DA1AF68-9189-5D18-A086-AC8CD74EB98D')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('2DA1AF68-9189-5D18-A086-AC8CD74EB98D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_heartbeat_seconds', '15');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '76D2BDC2-CF45-5740-8664-666891659185')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('76D2BDC2-CF45-5740-8664-666891659185', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'stale_grace_seconds', '300');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '967960DA-668D-50B0-AA45-7EBE098349A0')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('967960DA-668D-50B0-AA45-7EBE098349A0', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'workflow_poll_seconds', '5');
GO

-- =====================================================================
-- Enums (kernel-owned; keys by formula, members keyed 'type.NAME')
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_status', 'Running-instance lifecycle of a service_hosts row: STARTING, SEALED, DRAINING, RELOADING, STOPPED.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'B0D3359F-7388-55ED-810C-09033F4C276D')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('B0D3359F-7388-55ED-810C-09033F4C276D', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STARTING', 0, 'Registered at kernel startup; the application is not yet sealed.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '945EABDF-DE88-59FA-B034-9D9382D48051')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('945EABDF-DE88-59FA-B034-9D9382D48051', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SEALED', 1, 'Every module has sealed; the host is live. The only state reload() moves to RELOADING.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '6816DA40-9AD2-519E-8A31-DA5C610C6B4F')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('6816DA40-9AD2-519E-8A31-DA5C610C6B4F', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DRAINING', 2, 'The kernel is draining: modules stop accepting work ahead of shutdown.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '38358AA0-B911-5794-8E61-7D7A6E8E5582')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('38358AA0-B911-5794-8E61-7D7A6E8E5582', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RELOADING', 3, 'Written by the workflow side onto a sealed host; the host observes it, drains and exits, and the host runtime restarts it.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '838A88E7-41D2-595B-9EEE-B411AC91B897')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('838A88E7-41D2-595B-9EEE-B411AC91B897', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STOPPED', 4, 'The kernel stopped, or the stale sweep found the heartbeat older than the grace period. Terminal.');
GO

-- Operation models
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '65BCA5FA-0709-5050-85A2-474683F3BF8C')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('65BCA5FA-0709-5050-85A2-474683F3BF8C', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_register_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'DD8F02BA-E154-5D14-8949-AA9DA801BE26')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('DD8F02BA-E154-5D14-8949-AA9DA801BE26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_seal_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'A9AD8B76-D58B-52AC-A141-D14D785CC93C')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A9AD8B76-D58B-52AC-A141-D14D785CC93C', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_status_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '7DCDE693-7466-5232-9E33-B3BA2DD44BAA')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('7DCDE693-7466-5232-9E33-B3BA2DD44BAA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_key_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '22998F41-1CD8-53DD-A4B6-1A78ACE78A17')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_read_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_release_stale_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '5BB140B5-2501-541F-A75B-B54A5B6DA5A2')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5BB140B5-2501-541F-A75B-B54A5B6DA5A2', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_reload_input', NULL);
GO

-- Operation model fields
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '42B693E2-231F-5B1C-980A-DAF78677053E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('42B693E2-231F-5B1C-980A-DAF78677053E', '65BCA5FA-0709-5050-85A2-474683F3BF8C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EBA27698-5F56-5E1F-B699-EE94BE410AFD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EBA27698-5F56-5E1F-B699-EE94BE410AFD', '65BCA5FA-0709-5050-85A2-474683F3BF8C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '04140D14-3869-56BA-8AAE-EB79B410C8E1')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('04140D14-3869-56BA-8AAE-EB79B410C8E1', '65BCA5FA-0709-5050-85A2-474683F3BF8C', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_host_name', 3, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '54E8D16B-1AE8-5D97-9C5D-BA5E09C9682D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('54E8D16B-1AE8-5D97-9C5D-BA5E09C9682D', '65BCA5FA-0709-5050-85A2-474683F3BF8C', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_pid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '22DB161F-25AC-5970-8A81-7A6B76B86556')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('22DB161F-25AC-5970-8A81-7A6B76B86556', '65BCA5FA-0709-5050-85A2-474683F3BF8C', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_kernel_version', 5, 0, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '559638A0-632F-5E2E-ADD9-BBFDD0018A54')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('559638A0-632F-5E2E-ADD9-BBFDD0018A54', 'DD8F02BA-E154-5D14-8949-AA9DA801BE26', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EAD6EB74-B9F5-5D87-B798-E1ECE85363DE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EAD6EB74-B9F5-5D87-B798-E1ECE85363DE', 'DD8F02BA-E154-5D14-8949-AA9DA801BE26', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_core_package_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5BF2FBF2-8C5A-582A-8855-777E04538A1B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5BF2FBF2-8C5A-582A-8855-777E04538A1B', 'DD8F02BA-E154-5D14-8949-AA9DA801BE26', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'BCD6E9DA-EE3A-58D2-8D49-DB118CC714AC')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('BCD6E9DA-EE3A-58D2-8D49-DB118CC714AC', 'A9AD8B76-D58B-52AC-A141-D14D785CC93C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F13A86B0-D53B-5E71-A903-F652A713FC9A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F13A86B0-D53B-5E71-A903-F652A713FC9A', 'A9AD8B76-D58B-52AC-A141-D14D785CC93C', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '558FAC49-E6D8-5B28-B909-1E25F66C07BE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('558FAC49-E6D8-5B28-B909-1E25F66C07BE', '7DCDE693-7466-5232-9E33-B3BA2DD44BAA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F383F50F-169D-53A8-8CB3-DF42989AC7B8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F383F50F-169D-53A8-8CB3-DF42989AC7B8', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0F0C3269-91D3-56EA-9B39-7E46C0F72EB2')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0F0C3269-91D3-56EA-9B39-7E46C0F72EB2', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '85B608E6-F7B7-52D4-B083-CBC3AE806D7A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('85B608E6-F7B7-52D4-B083-CBC3AE806D7A', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_host_name', 3, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1BF37F3E-5125-5E46-988E-F5AFD65926B6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1BF37F3E-5125-5E46-988E-F5AFD65926B6', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_pid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '2BE02D10-ED9F-53AC-9C82-84810AC8C356')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('2BE02D10-ED9F-53AC-9C82-84810AC8C356', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_kernel_version', 5, 0, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '45233C35-7AC1-50CA-9FB4-686C37A53FBD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('45233C35-7AC1-50CA-9FB4-686C37A53FBD', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_core_version', 6, 1, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5D90BA16-2177-5090-9E3A-B8511893C3A7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5D90BA16-2177-5090-9E3A-B8511893C3A7', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_connections', 7, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B695ED4A-9CC3-539B-934B-72A4361251E6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B695ED4A-9CC3-539B-934B-72A4361251E6', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_started_on', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0D6CD6CA-AD1C-5BCB-99F7-F8189E1FCAD0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0D6CD6CA-AD1C-5BCB-99F7-F8189E1FCAD0', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_heartbeat_on', 9, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '206F100C-EF1E-5870-835B-37A2FBAA6EEB')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('206F100C-EF1E-5870-835B-37A2FBAA6EEB', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_lease_until', 10, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8AA726B3-9859-5211-919C-0D858BD2AF2A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8AA726B3-9859-5211-919C-0D858BD2AF2A', 'A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '516E3980-EDA5-5DDD-A458-535F1F4EBAA9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('516E3980-EDA5-5DDD-A458-535F1F4EBAA9', 'A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_stopped_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'FB29AB7A-FE7E-56E8-88B0-C7180024CF74')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FB29AB7A-FE7E-56E8-88B0-C7180024CF74', 'A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_grace_seconds', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7CBC3A23-BA0C-55B4-A0DD-48E4841EBF2C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7CBC3A23-BA0C-55B4-A0DD-48E4841EBF2C', '5BB140B5-2501-541F-A75B-B54A5B6DA5A2', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_status_enum_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DDE9F5FC-521A-58EF-9793-93CA867BBAD1')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DDE9F5FC-521A-58EF-9793-93CA867BBAD1', '5BB140B5-2501-541F-A75B-B54A5B6DA5A2', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A72F7B9B-86B7-56BC-9FEE-85EF2E623A9D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A72F7B9B-86B7-56BC-9FEE-85EF2E623A9D', '5BB140B5-2501-541F-A75B-B54A5B6DA5A2', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_sealed_enum_guid', 3, 0, NULL, NULL, 0);
GO

-- Operations (kernel bootstrap elements: loaded with the registry at startup, before seal)
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '98B8B36C-443F-5378-BF6A-E196AF88501E')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('98B8B36C-443F-5378-BF6A-E196AF88501E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:register:1', 'INSERT INTO [dbo].[service_hosts] ([key_guid], [ref_status_enum_guid], [pub_host_name], [pub_pid], [pub_kernel_version]) VALUES (?, ?, ?, ?, ?)', NULL, NULL, 1, 'Register this process: its boot key, STARTING, host name and pid for display, the kernel version it runs; started and heartbeat stamped by default.', '65BCA5FA-0709-5050-85A2-474683F3BF8C', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '52FDA689-1D3D-521D-94BF-14BECD106FA7')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('52FDA689-1D3D-521D-94BF-14BECD106FA7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:seal:1', 'UPDATE [sh] SET [sh].[ref_status_enum_guid] = ?, [sh].[pub_core_version] = (SELECT [spm].[pub_version] FROM [dbo].[service_packages_manifest] AS [spm] WHERE [spm].[key_guid] = ?), [sh].[pub_heartbeat_on] = SYSDATETIMEOFFSET(), [sh].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ?', NULL, NULL, 1, 'Record the seal: status SEALED and the core manifest version read at seal, on one host by key.', 'DD8F02BA-E154-5D14-8949-AA9DA801BE26', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'C9A3C8BF-EB22-528C-8415-95629EACABF4')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('C9A3C8BF-EB22-528C-8415-95629EACABF4', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:set_status:1', 'UPDATE [sh] SET [sh].[ref_status_enum_guid] = ?, [sh].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ?', NULL, NULL, 1, 'Record a lifecycle transition (DRAINING, STOPPED) on one host by key.', 'A9AD8B76-D58B-52AC-A141-D14D785CC93C', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '2B49858D-892D-5D09-9615-EF07E454FEB3')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('2B49858D-892D-5D09-9615-EF07E454FEB3', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:heartbeat:1', 'UPDATE [sh] SET [sh].[pub_heartbeat_on] = SYSDATETIMEOFFSET(), [sh].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ?', NULL, NULL, 1, 'The heartbeat: stamp the beat time on one host by key.', '7DCDE693-7466-5232-9E33-B3BA2DD44BAA', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '257C0536-1A88-51E3-8F7F-22A8D2754870')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('257C0536-1A88-51E3-8F7F-22A8D2754870', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:read:1', 'SELECT [sh].[key_guid], [sh].[ref_status_enum_guid], [sh].[pub_host_name], [sh].[pub_pid], [sh].[pub_kernel_version], [sh].[pub_core_version], [sh].[pub_connections], [sh].[pub_started_on], [sh].[pub_heartbeat_on], [sh].[pub_lease_until] FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ? FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'One host by key, as it stands: what the observer reads its own status from.', '7DCDE693-7466-5232-9E33-B3BA2DD44BAA', '22998F41-1CD8-53DD-A4B6-1A78ACE78A17');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '0D63E471-5C33-5F96-8787-D52E0C47D31B')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('0D63E471-5C33-5F96-8787-D52E0C47D31B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:release_stale:1', 'UPDATE [sh] SET [sh].[ref_status_enum_guid] = ?, [sh].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[ref_status_enum_guid] <> ? AND [sh].[pub_heartbeat_on] < DATEADD(SECOND, 0 - ?, SYSDATETIMEOFFSET())', NULL, NULL, 1, 'Stale sweep: every host not STOPPED whose heartbeat is older than the grace period becomes STOPPED. Same grace as the workflow stale-claim sweep.', 'A8E7BF09-B2F2-5CE8-B698-29B8A8C071B1', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '174A087F-58FA-5D12-9DA5-29573ABD6406')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('174A087F-58FA-5D12-9DA5-29573ABD6406', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:host:reload:1', 'UPDATE [sh] SET [sh].[ref_status_enum_guid] = ?, [sh].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ? AND [sh].[ref_status_enum_guid] = ?', NULL, NULL, 1, 'Ask one host to reload: a SEALED host by key becomes RELOADING. The one write the workflow side makes to the registry.', '5BB140B5-2501-541F-A75B-B54A5B6DA5A2', NULL);
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.3
-- =====================================================================
UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.3', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.3', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
GO
