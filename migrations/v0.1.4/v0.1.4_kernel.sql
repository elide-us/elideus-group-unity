-- v0.1.4_kernel.sql: the 0.1.3 -> 0.1.4 gap. Idempotent: every statement is guarded, every row by key.
-- Adds (core-owned): the IoGateway Discord channel's configuration rows; the workflow history table dbo.system_workflow_history
-- with its record operation, model and fields; four more columns on the claim's return (disposition, started_on, package, and
-- the definition's name); the Discord guild registry dbo.system_discord_guilds with its upsert / read_all / mark_left operations,
-- models and fields, and the elideus group guild row (always carried: the root debugging output server); the discord_guild_sync
-- workflow definition; and moves the database version to 0.1.4.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Tables
-- =====================================================================
IF OBJECT_ID(N'[dbo].[system_workflow_history]', N'U') IS NULL
CREATE TABLE [dbo].[system_workflow_history] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_instance_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_host_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_user_guid] UNIQUEIDENTIFIER NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_batch_number] BIGINT NOT NULL,
  [pub_attempts] TINYINT NOT NULL,
  [pub_started_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_finished_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_duration_ms] INT NOT NULL,
  [pub_error] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

IF OBJECT_ID(N'[dbo].[system_discord_guilds]', N'U') IS NULL
CREATE TABLE [dbo].[system_discord_guilds] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_guild_id] BIGINT NOT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_owner_id] BIGINT NULL,
  [pub_region] NVARCHAR(128) NULL,
  [pub_member_count] INT NULL,
  [pub_credits] INT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(MAX) NULL,
  [pub_joined_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_left_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_swh_definition_finished' AND object_id = OBJECT_ID(N'[dbo].[system_workflow_history]'))
CREATE NONCLUSTERED INDEX [IX_swh_definition_finished] ON [dbo].[system_workflow_history] ([ref_definition_guid], [pub_finished_on]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_swh_host' AND object_id = OBJECT_ID(N'[dbo].[system_workflow_history]'))
CREATE NONCLUSTERED INDEX [IX_swh_host] ON [dbo].[system_workflow_history] ([ref_host_guid]);
GO

-- Constraints (PK, UNIQUE)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_workflow_history' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [PK_system_workflow_history] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_discord_guilds' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [PK_system_discord_guilds] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_sdg_guild_id' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [UQ_sdg_guild_id] UNIQUE NONCLUSTERED ([pub_guild_id]);
GO

-- Constraints (FOREIGN KEY)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swh_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swh_definition' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_definition] FOREIGN KEY ([ref_definition_guid]) REFERENCES [dbo].[service_workflow_definitions] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swh_host' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swh_status' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_swh_disposition' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_sdg_package' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
GO

-- =====================================================================
-- System configuration (core-owned; key by formula 'service_system_configuration:<pub_key>')
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '6BD169ED-9F6D-5B32-A1C2-2B1CD0042708')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('6BD169ED-9F6D-5B32-A1C2-2B1CD0042708', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_system_channel_id', '1333131669409890334');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '4A619ECB-9B3E-5D0B-938D-1CE7318229ED')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('4A619ECB-9B3E-5D0B-938D-1CE7318229ED', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_bot_name', 'TheOracleRPC-Dev');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = 'CCC2A543-3722-5CFD-A66C-3DD4171B730D')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('CCC2A543-3722-5CFD-A66C-3DD4171B730D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_command_prefix', '!');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '504B52B9-583F-5595-AB8A-60A121151DED')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('504B52B9-583F-5595-AB8A-60A121151DED', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_send_interval_seconds', '1');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = 'A47FF247-1A9D-566F-A944-339D5E1E71E6')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('A47FF247-1A9D-566F-A944-339D5E1E71E6', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_rate_limit_delay_seconds', '5');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_system_configuration] WHERE [key_guid] = '228A573B-8A50-567B-9AF6-DA654A8B708B')
INSERT INTO [dbo].[service_system_configuration] ([key_guid], [ref_package_guid], [pub_key], [pub_value]) VALUES ('228A573B-8A50-567B-9AF6-DA654A8B708B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_message_max_length', '1900');
GO

-- Operation models
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '5011BDE8-802B-5063-B470-6BB14F45C354')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5011BDE8-802B-5063-B470-6BB14F45C354', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'workflow_history_record_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '5A22942B-1F75-5B89-B7DA-55E40B826EFF')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5A22942B-1F75-5B89-B7DA-55E40B826EFF', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_guilds_upsert_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'CED91567-DA0C-5751-9D9B-5D6E430539EF')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('CED91567-DA0C-5751-9D9B-5D6E430539EF', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_guilds_read_all_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'E87A44EB-31CD-5943-A4B4-36B79390FAC7')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('E87A44EB-31CD-5943-A4B4-36B79390FAC7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_guilds_mark_left_input', NULL);
GO

-- Operation model fields
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'AD90170A-42F6-52A9-90D7-C0E7F03CB1DA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('AD90170A-42F6-52A9-90D7-C0E7F03CB1DA', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '75243608-DEA1-57D0-A916-EE7F684ACCBA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('75243608-DEA1-57D0-A916-EE7F684ACCBA', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '04C80E9A-4370-5DB2-8A01-02C59BE38DE6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('04C80E9A-4370-5DB2-8A01-02C59BE38DE6', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_definition_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '3C9F661B-7635-5448-89FF-111264DA9193')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('3C9F661B-7635-5448-89FF-111264DA9193', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_instance_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '85403BB6-C0FC-5EB3-B760-BFB20E449091')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('85403BB6-C0FC-5EB3-B760-BFB20E449091', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_host_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '286E9231-143E-5F68-B8B7-76FC5B064D7E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('286E9231-143E-5F68-B8B7-76FC5B064D7E', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 6, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4EC64B9E-DA69-54AA-ABA8-6DECFD8ED65F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4EC64B9E-DA69-54AA-ABA8-6DECFD8ED65F', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_status_enum_guid', 7, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5710F7CB-A1C6-5940-9255-C481C4C0B4FF')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5710F7CB-A1C6-5940-9255-C481C4C0B4FF', '5011BDE8-802B-5063-B470-6BB14F45C354', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_disposition_enum_guid', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E562FCF6-308C-5189-919C-E2E8C36A7B44')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E562FCF6-308C-5189-919C-E2E8C36A7B44', '5011BDE8-802B-5063-B470-6BB14F45C354', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 9, 0, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '83A719E0-71FA-52DD-890B-123C18E3F436')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('83A719E0-71FA-52DD-890B-123C18E3F436', '5011BDE8-802B-5063-B470-6BB14F45C354', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_batch_number', 10, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B8B83213-9A98-57BF-B395-274998E49512')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B8B83213-9A98-57BF-B395-274998E49512', '5011BDE8-802B-5063-B470-6BB14F45C354', 'CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_attempts', 11, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8A42BCFF-ADE8-510F-97F9-F26EACCFA7C5')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8A42BCFF-ADE8-510F-97F9-F26EACCFA7C5', '5011BDE8-802B-5063-B470-6BB14F45C354', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_started_on', 12, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '85C14E8C-1EF0-5B5A-BD13-BF9D4DB5D65D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('85C14E8C-1EF0-5B5A-BD13-BF9D4DB5D65D', '5011BDE8-802B-5063-B470-6BB14F45C354', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_finished_on', 13, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7F182D55-0938-59FB-9DDA-F9558977D929')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7F182D55-0938-59FB-9DDA-F9558977D929', '5011BDE8-802B-5063-B470-6BB14F45C354', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_duration_ms', 14, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '258C5F01-647F-5850-8EF1-A353BAEBCB8D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('258C5F01-647F-5850-8EF1-A353BAEBCB8D', '5011BDE8-802B-5063-B470-6BB14F45C354', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_error', 15, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C44B45FB-C94C-5F5A-9C64-3A577994A24C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C44B45FB-C94C-5F5A-9C64-3A577994A24C', '80D2901A-88E2-5B2B-98BB-3867AC2EA2C4', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_disposition_enum_guid', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E2F7AE72-45CD-58EA-BC79-66198BE0A0BD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E2F7AE72-45CD-58EA-BC79-66198BE0A0BD', '80D2901A-88E2-5B2B-98BB-3867AC2EA2C4', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_started_on', 9, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8CF23C5A-6E96-528F-95BD-F2038DCB39F7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8CF23C5A-6E96-528F-95BD-F2038DCB39F7', '80D2901A-88E2-5B2B-98BB-3867AC2EA2C4', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 10, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A9711300-DAA3-5BD7-B916-3AC3D665F11B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A9711300-DAA3-5BD7-B916-3AC3D665F11B', '80D2901A-88E2-5B2B-98BB-3867AC2EA2C4', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 11, 0, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A1B75E97-CEC4-5D8B-9C43-2BEF29F174DE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A1B75E97-CEC4-5D8B-9C43-2BEF29F174DE', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '54D21E32-5715-59BE-82EC-9CE7DF02BCE4')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('54D21E32-5715-59BE-82EC-9CE7DF02BCE4', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '941A9CB3-4C97-566C-A1BA-14296FF66A3D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('941A9CB3-4C97-566C-A1BA-14296FF66A3D', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_guild_id', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '576408C2-B979-5D88-87BC-11634AC5773A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('576408C2-B979-5D88-87BC-11634AC5773A', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 4, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6949B01E-6BD2-5017-9EB4-B39E33936C30')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6949B01E-6BD2-5017-9EB4-B39E33936C30', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_owner_id', 5, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '09595833-D837-5B43-9C0B-65B5D343898B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('09595833-D837-5B43-9C0B-65B5D343898B', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_region', 6, 1, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A5E1A2D6-1B87-5EFD-B072-B0004356C5C0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A5E1A2D6-1B87-5EFD-B072-B0004356C5C0', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_member_count', 7, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7668D74B-9D2C-52E0-83FF-473A1A9647BD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7668D74B-9D2C-52E0-83FF-473A1A9647BD', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '19DBDC78-58DC-50D7-B7E1-9B4739DA112B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('19DBDC78-58DC-50D7-B7E1-9B4739DA112B', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '98E592B6-85AA-588D-909F-EF59C0EE26D6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('98E592B6-85AA-588D-909F-EF59C0EE26D6', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_guild_id', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F59C9A32-8FBF-5F38-ABB6-FB9DAC226524')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F59C9A32-8FBF-5F38-ABB6-FB9DAC226524', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 4, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1E62FBB7-33D0-5841-9357-0FB75F439144')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1E62FBB7-33D0-5841-9357-0FB75F439144', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_owner_id', 5, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '9A215FCD-519C-5617-B043-8375A18FBA4C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9A215FCD-519C-5617-B043-8375A18FBA4C', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_region', 6, 1, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E25ECE40-58EE-5566-98E9-4E8AFDA3E8E3')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E25ECE40-58EE-5566-98E9-4E8AFDA3E8E3', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_member_count', 7, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'CF454546-FB48-53E4-94B4-036251DAF504')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('CF454546-FB48-53E4-94B4-036251DAF504', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_credits', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '447E8CF4-6F14-5C14-8FEF-11322187F486')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('447E8CF4-6F14-5C14-8FEF-11322187F486', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_notes', 9, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '162490FA-05F9-500A-A722-B8E7A6A2D04D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('162490FA-05F9-500A-A722-B8E7A6A2D04D', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_joined_on', 10, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DFABEA01-D466-5523-B70A-913623A0216F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DFABEA01-D466-5523-B70A-913623A0216F', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_left_on', 11, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8DEEA3AC-E1A1-5B69-92D6-EBE9CF064590')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8DEEA3AC-E1A1-5B69-92D6-EBE9CF064590', 'E87A44EB-31CD-5943-A4B4-36B79390FAC7', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_guild_id', 1, 0, NULL, NULL, 0);
GO

-- Operations
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '6C0E598D-F5D1-54AF-9A55-9728A3EEA342')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('6C0E598D-F5D1-54AF-9A55-9728A3EEA342', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:workflow:history:record:1', 'INSERT INTO [dbo].[system_workflow_history] ([key_guid], [ref_package_guid], [ref_definition_guid], [ref_instance_guid], [ref_host_guid], [ref_user_guid], [ref_status_enum_guid], [ref_disposition_enum_guid], [pub_name], [pub_batch_number], [pub_attempts], [pub_started_on], [pub_finished_on], [pub_duration_ms], [pub_error]) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', NULL, NULL, 0, 'Record one terminal workflow outcome (COMPLETE or FAILED): the name it ran as, disposition, batch, attempts, started and finished, run time, the host that ran it, the error.', '5011BDE8-802B-5063-B470-6BB14F45C354', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'CFCDB2DE-B109-5103-9E97-E7B7F66E7769')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('CFCDB2DE-B109-5103-9E97-E7B7F66E7769', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:discord:guilds:upsert:1', 'MERGE [dbo].[system_discord_guilds] WITH (HOLDLOCK) AS [sdg] USING (SELECT CAST(? AS UNIQUEIDENTIFIER) AS [key_guid], CAST(? AS UNIQUEIDENTIFIER) AS [ref_package_guid], CAST(? AS BIGINT) AS [pub_guild_id], CAST(? AS NVARCHAR(256)) AS [pub_name], CAST(? AS BIGINT) AS [pub_owner_id], CAST(? AS NVARCHAR(128)) AS [pub_region], CAST(? AS INT) AS [pub_member_count]) AS [src] ON [sdg].[pub_guild_id] = [src].[pub_guild_id] WHEN MATCHED THEN UPDATE SET [sdg].[pub_name] = [src].[pub_name], [sdg].[pub_owner_id] = [src].[pub_owner_id], [sdg].[pub_region] = COALESCE([src].[pub_region], [sdg].[pub_region]), [sdg].[pub_member_count] = [src].[pub_member_count], [sdg].[pub_left_on] = NULL, [sdg].[priv_modified_on] = SYSDATETIMEOFFSET() WHEN NOT MATCHED THEN INSERT ([key_guid], [ref_package_guid], [pub_guild_id], [pub_name], [pub_owner_id], [pub_region], [pub_member_count], [pub_joined_on]) VALUES ([src].[key_guid], [src].[ref_package_guid], [src].[pub_guild_id], [src].[pub_name], [src].[pub_owner_id], [src].[pub_region], [src].[pub_member_count], SYSDATETIMEOFFSET());', NULL, NULL, 0, 'Upsert one Discord guild the bot is in, by guild id: an existing row takes the reported name, owner and member count, and the region only when one is reported (the client reports none, so a seeded region stands), and is no longer left; a new row is inserted under its formula key with joined_on now. Credits and notes are never touched.', '5A22942B-1F75-5B89-B7DA-55E40B826EFF', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '150489BB-9266-5690-8E36-F68FAC029CFC')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('150489BB-9266-5690-8E36-F68FAC029CFC', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:discord:guilds:read_all:1', 'SELECT [sdg].[key_guid], [sdg].[ref_package_guid], [sdg].[pub_guild_id], [sdg].[pub_name], [sdg].[pub_owner_id], [sdg].[pub_region], [sdg].[pub_member_count], [sdg].[pub_credits], [sdg].[pub_notes], [sdg].[pub_joined_on], [sdg].[pub_left_on] FROM [dbo].[system_discord_guilds] AS [sdg] ORDER BY [sdg].[pub_guild_id] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, 'Every Discord guild row, joined or left: the registry the guild sync compares the client against.', NULL, 'CED91567-DA0C-5751-9D9B-5D6E430539EF');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '30FBB31C-063E-5435-8670-416461E6379E')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('30FBB31C-063E-5435-8670-416461E6379E', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'db:discord:guilds:mark_left:1', 'UPDATE [sdg] SET [sdg].[pub_left_on] = SYSDATETIMEOFFSET(), [sdg].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_discord_guilds] AS [sdg] WHERE [sdg].[pub_guild_id] = ? AND [sdg].[pub_left_on] IS NULL', NULL, NULL, 0, 'Stamp left_on on one guild row the bot is no longer in (by guild id, only while it is not already left).', 'E87A44EB-31CD-5943-A4B4-36B79390FAC7', NULL);
GO

-- The claim (a 0.1.2 row) also returns the claimed row's disposition, started_on and package, and its definition's name (a join
-- on service_workflow_definitions), which the history row records:
-- its text moves by key, guarded on the text so a re-apply changes nothing.
DECLARE @claim NVARCHAR(MAX) = 'SET NOCOUNT ON; DECLARE @claimed TABLE ([key_guid] UNIQUEIDENTIFIER NOT NULL, [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL, [pub_batch_number] BIGINT NOT NULL, [pub_steps] NVARCHAR(MAX) NOT NULL, [pub_can_retry] BIT NOT NULL, [pub_max_attempts] TINYINT NOT NULL, [pub_attempts] TINYINT NOT NULL, [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL, [pub_started_on] DATETIMEOFFSET(7) NOT NULL, [ref_package_guid] UNIQUEIDENTIFIER NULL); WITH [next] AS (SELECT TOP (1) [swq].[key_guid] FROM [dbo].[system_workflow_queue] AS [swq] WITH (UPDLOCK, READPAST, ROWLOCK) WHERE [swq].[ref_status_enum_guid] = ? ORDER BY [swq].[priv_created_on]) UPDATE [swq] SET [swq].[ref_status_enum_guid] = ?, [swq].[pub_attempts] = [swq].[pub_attempts] + 1, [swq].[pub_started_on] = SYSDATETIMEOFFSET(), [swq].[priv_modified_on] = SYSDATETIMEOFFSET() OUTPUT [inserted].[key_guid], [inserted].[ref_definition_guid], [inserted].[pub_batch_number], [inserted].[pub_steps], [inserted].[pub_can_retry], [inserted].[pub_max_attempts], [inserted].[pub_attempts], [inserted].[ref_disposition_enum_guid], [inserted].[pub_started_on], [inserted].[ref_package_guid] INTO @claimed FROM [dbo].[system_workflow_queue] AS [swq] JOIN [next] ON [next].[key_guid] = [swq].[key_guid]; SELECT [c].[key_guid], [c].[ref_definition_guid], [c].[pub_batch_number], [c].[pub_steps], [c].[pub_can_retry], [c].[pub_max_attempts], [c].[pub_attempts], [c].[ref_disposition_enum_guid], [c].[pub_started_on], [c].[ref_package_guid], [swd].[pub_name] FROM @claimed AS [c] JOIN [dbo].[service_workflow_definitions] AS [swd] ON [swd].[key_guid] = [c].[ref_definition_guid] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = @claim, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FFE1A2B9-32EA-5754-9617-FFF3CB587E37' AND [pub_query_mssql] <> @claim;
GO

-- =====================================================================
-- Data rows (core-owned)
-- =====================================================================
-- The elideus group guild: always carried, the root debugging output server for the whole ecosystem and platform.
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_discord_guilds] WHERE [key_guid] = 'D8DCFD8F-57D0-59E7-82BD-A0A65D21B659')
INSERT INTO [dbo].[system_discord_guilds] ([key_guid], [ref_package_guid], [pub_guild_id], [pub_name], [pub_owner_id], [pub_region], [pub_member_count], [pub_credits], [pub_notes], [pub_joined_on], [pub_left_on]) VALUES ('D8DCFD8F-57D0-59E7-82BD-A0A65D21B659', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 425055481766215680, 'elideus group', 177220160187400192, 'en-US', 12, 0, NULL, '2025-02-14 01:08:49.0000000 -08:00', NULL);
GO

-- The guild sync: one step, the gateway's sync_guilds contract (no parameters), declared by the gateway on seal and on guild join / remove.
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_workflow_definitions] WHERE [key_guid] = 'E9D5A665-EFA4-5457-B897-F6D2F343467D')
INSERT INTO [dbo].[service_workflow_definitions] ([key_guid], [ref_package_guid], [ref_disposition_enum_guid], [pub_name], [pub_steps], [pub_can_retry], [pub_max_attempts], [pub_notes]) VALUES ('E9D5A665-EFA4-5457-B897-F6D2F343467D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'C761A53C-DCED-5FF6-94E0-39D926B02E16', 'discord_guild_sync', '{"steps": [{"contract": "GatewayInterfaceModule.sync_guilds", "model": "void", "params": {}}]}', 1, 3, 'Sync the Discord guild registry with the guilds the bot is in: upsert each, stamp left_on on the rows it no longer sees. Declared by the gateway on seal and on guild join / remove.');
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.4
-- =====================================================================
UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
GO
