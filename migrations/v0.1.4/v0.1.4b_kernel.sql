-- v0.1.4b_kernel.sql: a follow-up to v0.1.4_kernel.sql in the same version. Idempotent: every row is guarded by key.
-- Adds (kernel-owned): the module listing operation db:contracts:modules:read_all:1 with its output model and fields. It is a
-- bootstrap element (cached before seal), so the kernel module manager can read [etg].[contracts_modules] right after the kernel's
-- own modules start: a module loads only if it is listed there.
-- Does NOT move the database version: the database stays at 0.1.4.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Operations (kernel-owned; keys by formula)
-- =====================================================================
-- Operation models
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_modules_read_all_output', NULL);
GO

-- Operation model fields
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6BB94CAC-D04E-5D06-90D2-26A6D133F834')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6BB94CAC-D04E-5D06-90D2-26A6D133F834', '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '924C2CEA-0CCF-5519-A4FA-ED961CC88A31')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('924C2CEA-0CCF-5519-A4FA-ED961CC88A31', '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_role_enum_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B61FA2DD-A222-5B6C-BA4A-020CCA3A2D6F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B61FA2DD-A222-5B6C-BA4A-020CCA3A2D6F', '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 3, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '363AFE0A-2C9D-5F51-B550-98CEC50DA9F6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('363AFE0A-2C9D-5F51-B550-98CEC50DA9F6', '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 4, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A4E17432-0C4F-5F1C-89C5-1C3F4F3B9D37')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A4E17432-0C4F-5F1C-89C5-1C3F4F3B9D37', '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_is_abstract', 5, 0, NULL, NULL, 0);
GO

-- Operations
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'E4D47334-225F-55F0-A9D0-54237D432442')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_package_guid], [pub_op], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [ref_input_model_guid], [ref_output_model_guid]) VALUES ('E4D47334-225F-55F0-A9D0-54237D432442', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'db:contracts:modules:read_all:1', 'SELECT [cm].[key_guid], [cm].[ref_role_enum_guid], [cm].[ref_package_guid], [cm].[pub_name], [cm].[pub_is_abstract] FROM [etg].[contracts_modules] AS [cm] FOR JSON PATH', NULL, NULL, 1, 'Every module row in [etg].[contracts_modules]: the listing the kernel module manager loads from. A module that is not listed never loads; role, abstract and package are filtered by the manager.', NULL, '5EF16CDA-B4E4-55ED-84CF-E919380B6E3A');
GO
