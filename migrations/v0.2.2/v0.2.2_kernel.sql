-- v0.2.2_kernel.sql: the 0.2.1 -> 0.2.2 gap. One script, one migration, one version: applied once to a database at 0.2.1.
-- Aaron 2026-11-01: "the packages should probably roll with the database minor version at least, so we're currently now
-- working on the 0.2 series, it makes sense the core and kernel match." From this version the script moves EVERY package
-- manifest row (kernel, core, setup) with the database version, not only the kernel's; 0.2.1 left core and setup at 0.1.0.
-- This version carries the security-context CODE slice (DBRequest carries the context; the execution module requires the
-- token and sets SESSION_CONTEXT; the gateway and RPC translation mint contexts; declare, run and the sequence procedures
-- stamp them). The schema change that closes the slice, the five context columns on system_workflow_queue,
-- system_workflow_history and system_sequence_allocations going NOT NULL, is added above the version block when that
-- code lands.
-- The Python code shipped in this release carries DATABASE_VERSION 0.2.2. APPLY WITH THE APPLICATION STOPPED, then boot,
-- then populate, then make installer, then make package kernel / core / setup.
-- Aaron 2026-11-02: batch 1 declares the column ORDINALS of nine tables whose columns were appended by ALTER plus
-- contracts_db_tables (pub_schema before pub_name): the ordinal is the query ordering, never the current layout. Batch 2
-- indexes system_users on pub_email and pub_display. Batch 3 rewrites six op bodies and the two account:users models to
-- the declared order. populate (corrected the same day) keeps declared ordinals; make installer emits them; the full
-- wipe and reinstall that follows lays the tables out physically in that order.
-- Batch 4 re-lists GatewayOperationsModule, WorkflowOperationsModule and WorkflowExecutionModule (renamed 2026-11-02) and
-- retires the three rows they replace.
-- Batch 5 adds module_role.PRIMITIVE (Aaron 2026-11-03).
-- Batch 6 adds READ logging: pub_log_read on service_audit_tables, audit_kind.READ, the three audit ops and models (Aaron 2026-11-03).
-- Batch 7 adds the entry point record: enum cloudhost_engine, contracts_entrypoints (3 rows), service_hosts.ref_entrypoint_guid,
-- drops contracts_engines_cloudhost (Aaron 2026-11-03).
-- Batch 8 adds the component model: EXTENDS, contracts_components (17 rows), contracts_components_dependencies (30 rows),
-- service_package_dependencies (2 rows), contracts_modules rebuilt with ref_component_guid second (Aaron 2026-11-03).
-- Batch 9 adds the organization primitive and membership (system_organizations, system_organization_members, 7 account ops),
-- the Discord and Organizations components' module rows, system_discord_guilds.ref_organization_guid and ref_owner_user_guid
-- (assign_owner op), and drops system_discord_guilds.pub_credits: no financial data on a guild row (Aaron 2026-11-03).
-- Batch 10 adds Discord channel management: system_discord_channels (guild-or-user owned, owner snowflake) and four
-- db:discord:channels ops (Aaron 2026-11-03).
-- Moves the database version to 0.2.2.
-- The last addendum attaches every row to a package for the clean install: the export set gains the four new design
-- tables and service_hosts, no component is unowned, the security domain row is kernel's, and the setup context points
-- at the static setup host (Aaron 2026-11-11).
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Batch 1: declared column ordinals (Aaron 2026-11-02: the ordinal is the QUERY ORDERING, never the current layout;
-- priv_ last). Nine tables carried columns appended by ALTER; contracts_db_tables was laid out (pub_name, pub_schema)
-- against its four readers. Each table's rows are parked (negated) first so UQ (table, ordinal) cannot collide, then
-- every column is set by key. populate keeps declared ordinals; make installer emits them; the wipe and reinstall
-- makes the physical layout match.
-- =====================================================================
-- dbo.service_workflow_definitions
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '94148736-392D-5424-B5CE-2840D0ED2A0B' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '55E61665-D642-5A5E-85AB-D673B9D31BC7';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E2E22E60-72B4-524D-878B-A645A687FBA2';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'AFD39659-0863-5703-A121-6840A456FEEF';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F2D93FFC-4EDA-5747-A3A1-B9EAFC43DC2E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'AF5E43BE-81E7-5FBC-9DB2-D69F91FCC85F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5584E5D6-B3BF-590F-82B9-3FF909261775';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '3D856B4A-B1AB-5661-9505-D6FE18EE8616';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7DFF2BD1-845D-5ECF-AED9-776EC928C89B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F1FDFD88-A45A-5EEE-81A3-41BCDD769959';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '674669E9-82B0-5136-8505-D85CE8A81C3F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5087C4FB-BF4E-5E30-B6E0-5ADFF5C24462';
-- dbo.system_workflow_queue
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '0E85FEEF-2D21-5F9D-AA78-33D19BD4E566' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9A77062D-7A7C-5154-AF19-6937CB175726';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C23BB197-D6D4-553F-A563-D6DC427729E4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '663B5BA5-1B5A-5667-8927-5376BFB04B59';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '37FA8E2A-CE53-5EE1-A66B-9B9A6254EFC7';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BA194173-0200-52A1-B256-F0D1DC2E50E0';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '82A8CE44-F09D-5B1B-8669-2BC7254696A0';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'AAD48DDB-F158-5428-8202-DFF9C319B3A0';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '57186AEC-1B6B-5E48-91A8-46B93910C955';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EC7B31F0-720A-5454-91D3-7E8479FA938D';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DBCED107-54E6-5E27-B3CC-F9E7F81DD850';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '3B201A83-47F5-5944-B89A-8B0F077AD910';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EA0718DF-5F30-5EE3-9793-103DD90C5E70';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 13, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F3691FDB-F72D-5DE2-A747-0EB05985A2DA';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 14, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1A9E1F28-17DC-5F91-977F-1506870A48F6';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 15, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '15F9A562-59EF-53CD-A263-61E29FC89311';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 16, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F5969951-0447-5B6E-A4FF-29371C0DCAA4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 17, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '74926DDB-ACF7-5FAB-BAAF-1E9F65D10A75';
-- dbo.system_workflow_history
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '9733ECB5-95AF-52D9-9C5C-FE77DBA1EC66' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2E0121B1-3102-5A7F-985A-1ABCE70EF97B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '24FF8AF4-88AC-5727-97C1-FAE15827B993';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9A7D7098-52A8-5777-A24C-C9388B1A8F27';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '3CD254FA-7ED5-51E7-A6FA-C494D8A9FF4E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DDBA5BA0-9F8B-5348-9A95-1336E436F421';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0C63CF73-1382-54C6-8193-945F161C478F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0490541B-F5B3-5794-A2B6-77BBF0B5F9A2';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4FEED4A1-D6CB-562B-A260-E4A0B569E674';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '20C9E70A-9634-5B03-9B27-5A06260DE695';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6084004C-2A74-56D7-A0E6-9ADCF2D6732C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5E75729F-9293-5FD4-A4D4-0C1D4EB72417';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '89744BB6-2928-5DF2-BCC1-721FAD69EAC6';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 13, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '223CDD08-67E9-5904-BC6E-4BBC9B8C2818';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 14, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FD0258AD-6F1B-5F8A-B030-865A8C4A804E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 15, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A194F395-2054-51DC-A56E-ABA2DE22FAA1';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 16, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7FACFE51-0081-57DA-860B-D387DFF2A1BC';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 17, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D47360CF-7F21-54CD-9252-9CAEA12989F3';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 18, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2899EBCB-8D14-5DF4-8C98-BF99EB2C16F9';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 19, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DF1A9788-85F3-53E1-9590-755F19A4AF55';
-- dbo.system_sequence_allocations
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = 'CF7B7278-F0D8-5217-97E1-3E399C152872' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5A058F70-C36E-5FB5-8782-01F1B82043B3';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '26D36A1C-433C-5215-AFBC-D6E62C8E0D0D';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0FFC1195-4C3C-54EF-94DF-6A970E43EC1A';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CA6B8822-D50C-5F93-A08A-A4D74C545BF9';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'B0A635CF-2A4E-51B3-BAC5-C3598F9D700C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4BF1974D-3756-5443-A787-A2D4768C4AA5';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FC1D146E-1871-5789-8A6C-86592DF26110';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F442B0B2-E00E-56DC-958D-8A270E240861';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4A22DDF9-1C2C-50A4-95B2-E15DFAF7C089';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4F1B7A1D-506C-5E58-9D2E-7DD0DE9D0ECE';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E0F1B748-FFF0-5711-BFAE-D43F8CECE141';
-- dbo.system_users
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = 'D0690BAF-27E0-5CB6-B00D-BE44E6E4EA26' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E16ACE76-DBA7-51E4-A57D-D0BBBED7E016';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C7F61BE9-52F8-59CF-9A46-749F0AB79FE7';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '8CA9A64B-33F7-5A7A-A6FD-ABA096190644';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C942C245-1936-5E19-A5E7-2925A5A244B4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CA156830-7AD7-5D50-8116-D1571DBE3174';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FFA76C7B-B69D-5825-B488-8836D4F8207C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D18D854E-2294-5320-8A7E-02ED4B5C090F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '73EC434B-5057-5C15-81E3-4CE43393B4C6';
-- etg.contracts_db_tables
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = 'CAD055F6-8D16-54A3-80EC-674953D98AAB' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F74E5051-7BBC-55DF-8788-AEB4B094E540';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '61D9800C-3200-5106-8097-2B32DC58E9E4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9A588F85-C683-52DB-BA37-C2F358DF63FC';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '786E7F5E-93B0-5CD0-BE4D-BAEE5BB685FD';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A315A97D-2C89-58B3-92AD-EDA976B1AC86';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A0476BC1-0F3F-5462-85FC-7D907F4DFE2B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C044AAF5-DB3F-56E4-AFE5-369C7569852B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4703A693-0F79-52A6-A3FF-4B50C6A32575';
-- etg.contracts_db_columns
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '5ED7D3AA-3C6E-5671-85B1-41104F5EBDEE' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1BAE3F71-2CB0-5610-A344-B9848470211B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '37033C5C-E1B2-550E-85F9-F94FB8938EA0';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5CFD11ED-2715-5F16-99D8-04573001E14A';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '77BBD1CF-D95C-5398-9213-597C7D8C9CD6';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0EED8704-4495-580C-A7A4-530DF4D83985';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5BA711D1-9F50-5AA1-9FD5-00C0C6CE74DE';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CD767D10-49E2-595B-A41F-4F8B28682B8C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '99CCAD38-8A03-521B-867A-DF4BDE7B000C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '07598494-0F3B-5F15-81E7-085CC8D1B788';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7137DF60-C720-5D4F-9996-68CCD45BC8FB';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FE034144-1F63-59BB-A0D9-0B77A541C204';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A4CB0957-B794-5E33-9DE4-49866A78D5FC';
-- etg.contracts_db_constraints
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '3AAAC83C-13F2-5992-AE2B-8CD07D00F97A' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '754CBFB3-23FB-5584-BDA8-61A04184C107';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EA3483AB-34F2-5F78-8300-9488D07F8AA2';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A960911D-2595-531B-A35F-11703CC7945F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F68500EA-E723-5750-B8F2-9262831511AA';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A6997773-14CF-5EB9-B674-D065C15A4A69';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BC1C0C7B-9463-50C2-A4DA-03B5170DDFCE';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5D2D18E2-72D5-5E4F-94A2-1AF832727A20';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1DF302CF-D82F-5ECD-8290-9795AE65E564';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C7A714AA-823B-537B-B73C-FE6B876980FC';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '590693F7-B59F-5CEE-B1BE-93A78B49F17B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D252B3E3-A9CA-5DAA-A427-FF9A930597CB';
-- etg.contracts_db_operations_models_fields
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '68B0EABF-3BB4-569B-B860-52E053EA5B63' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F42810B6-1E6F-5F55-95C5-9C8F1C32012E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '72EFCAFB-3280-5412-8EA3-47C0FDFE8798';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EA136435-566E-5F87-9F78-E9EBCB292BD7';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '05915499-3A2C-5CFA-B282-1DB6B411271A';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0482626D-768B-5B7E-BA93-4E279597471C';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CC6604B6-8339-5F46-A95B-73E10952AAFE';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '81A21FC7-C129-5D32-A490-A9E75084CA14';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '51655CAB-13BB-5692-A68C-D12FF924E0A5';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A9BF48A8-FA08-59B7-B43B-85A1323368E8';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '943E8B76-5016-58D4-AC92-87E34693A8C8';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '00BC84B0-79A3-5FFA-97E4-BD7B36BE9B42';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A3FF7D5B-A9C8-53BF-A84E-851971A758A6';
GO

-- =====================================================================
-- Batch 2: system_users is searched by email before display name (Aaron 2026-11-02); both indexed.
-- =====================================================================
CREATE NONCLUSTERED INDEX [IX_su_email] ON [dbo].[system_users] ([pub_email]);
CREATE NONCLUSTERED INDEX [IX_su_display] ON [dbo].[system_users] ([pub_display]);
GO

-- =====================================================================
-- Batch 3: queries rewritten to the declared order (Aaron 2026-11-02: queries are updated to align). Each row is
-- matched on its exact current text. The two account:users models move pub_email beside pub_display; the create
-- input binds positionally and has no caller yet.
-- =====================================================================
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [cdt].[key_guid], [cdt].[pub_schema], [cdt].[pub_name], [cdt].[pub_alias] FROM [etg].[contracts_db_tables] AS [cdt] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [cdt].[key_guid], [cdt].[pub_name], [cdt].[pub_schema], [cdt].[pub_alias] FROM [etg].[contracts_db_tables] AS [cdt] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [cdc].[key_guid], [cdc].[ref_table_guid], [cdc].[pub_name], [cdt].[pub_schema], [cdt].[pub_name] AS [cdt_name] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdc].[ref_table_guid] = [cdt].[key_guid] WHERE [cdc].[ref_package_guid] = ? FOR JSON PATH', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [cdc].[key_guid], [cdc].[pub_name], [cdc].[ref_table_guid], [cdt].[pub_schema], [cdt].[pub_name] AS [cdt_name] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdc].[ref_table_guid] = [cdt].[key_guid] WHERE [cdc].[ref_package_guid] = ? FOR JSON PATH';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [cdc].[key_guid], [cdc].[ref_table_guid], [cdc].[pub_name], [cdc].[pub_ordinal], [cdc].[pub_is_nullable], [cdc].[pub_default_value], [cdc].[pub_max_length], [cpt].[pub_name] AS [cpt_name], [cpt].[pub_default_length], [cpt].[pub_emits_length], [cpt].[pub_mssql_type] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_primitives_types] AS [cpt] ON [cdc].[ref_type_guid] = [cpt].[key_guid] ORDER BY [cdc].[ref_table_guid], [cdc].[pub_ordinal] FOR JSON PATH, INCLUDE_NULL_VALUES', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [cdc].[key_guid], [cdc].[ref_table_guid], [cdc].[pub_name], [cdc].[pub_ordinal], [cdc].[pub_is_nullable], [cdc].[pub_default_value], [cdc].[pub_max_length], [cpt].[pub_mssql_type], [cpt].[pub_default_length], [cpt].[pub_name] AS [cpt_name], [cpt].[pub_emits_length] FROM [etg].[contracts_db_columns] AS [cdc] JOIN [etg].[contracts_primitives_types] AS [cpt] ON [cdc].[ref_type_guid] = [cpt].[key_guid] ORDER BY [cdc].[ref_table_guid], [cdc].[pub_ordinal] FOR JSON PATH, INCLUDE_NULL_VALUES';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_email], [pub_display], [pub_is_enabled]) VALUES (?, ?, ?, ?, ?, ?)', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled], [pub_email]) VALUES (?, ?, ?, ?, ?, ?)';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [su].[key_guid], [su].[ref_kind_enum_guid], [su].[pub_email], [su].[pub_display], [su].[pub_is_enabled] FROM [dbo].[system_users] AS [su] ORDER BY [su].[pub_display] FOR JSON PATH, INCLUDE_NULL_VALUES', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [su].[key_guid], [su].[ref_kind_enum_guid], [su].[pub_display], [su].[pub_is_enabled], [su].[pub_email] FROM [dbo].[system_users] AS [su] ORDER BY [su].[pub_display] FOR JSON PATH, INCLUDE_NULL_VALUES';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SET NOCOUNT ON; DECLARE @claimed TABLE ([key_guid] UNIQUEIDENTIFIER NOT NULL, [ref_package_guid] UNIQUEIDENTIFIER NULL, [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL, [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL, [pub_batch_number] BIGINT NOT NULL, [pub_steps] NVARCHAR(MAX) NOT NULL, [pub_can_retry] BIT NOT NULL, [pub_max_attempts] TINYINT NOT NULL, [pub_attempts] TINYINT NOT NULL, [pub_started_on] DATETIMEOFFSET(7) NOT NULL); WITH [next] AS (SELECT TOP (1) [swq].[key_guid] FROM [dbo].[system_workflow_queue] AS [swq] WITH (UPDLOCK, READPAST, ROWLOCK) WHERE [swq].[ref_status_enum_guid] = ? ORDER BY [swq].[priv_created_on]) UPDATE [swq] SET [swq].[ref_status_enum_guid] = ?, [swq].[pub_attempts] = [swq].[pub_attempts] + 1, [swq].[pub_started_on] = SYSDATETIMEOFFSET(), [swq].[priv_modified_on] = SYSDATETIMEOFFSET() OUTPUT [inserted].[key_guid], [inserted].[ref_package_guid], [inserted].[ref_definition_guid], [inserted].[ref_disposition_enum_guid], [inserted].[pub_batch_number], [inserted].[pub_steps], [inserted].[pub_can_retry], [inserted].[pub_max_attempts], [inserted].[pub_attempts], [inserted].[pub_started_on] INTO @claimed FROM [dbo].[system_workflow_queue] AS [swq] JOIN [next] ON [next].[key_guid] = [swq].[key_guid]; SELECT [c].[key_guid], [c].[ref_package_guid], [c].[ref_definition_guid], [c].[ref_disposition_enum_guid], [c].[pub_batch_number], [c].[pub_steps], [c].[pub_can_retry], [c].[pub_max_attempts], [c].[pub_attempts], [c].[pub_started_on], [swd].[pub_name] FROM @claimed AS [c] JOIN [dbo].[service_workflow_definitions] AS [swd] ON [swd].[key_guid] = [c].[ref_definition_guid] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SET NOCOUNT ON; DECLARE @claimed TABLE ([key_guid] UNIQUEIDENTIFIER NOT NULL, [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL, [pub_batch_number] BIGINT NOT NULL, [pub_steps] NVARCHAR(MAX) NOT NULL, [pub_can_retry] BIT NOT NULL, [pub_max_attempts] TINYINT NOT NULL, [pub_attempts] TINYINT NOT NULL, [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL, [pub_started_on] DATETIMEOFFSET(7) NOT NULL, [ref_package_guid] UNIQUEIDENTIFIER NULL); WITH [next] AS (SELECT TOP (1) [swq].[key_guid] FROM [dbo].[system_workflow_queue] AS [swq] WITH (UPDLOCK, READPAST, ROWLOCK) WHERE [swq].[ref_status_enum_guid] = ? ORDER BY [swq].[priv_created_on]) UPDATE [swq] SET [swq].[ref_status_enum_guid] = ?, [swq].[pub_attempts] = [swq].[pub_attempts] + 1, [swq].[pub_started_on] = SYSDATETIMEOFFSET(), [swq].[priv_modified_on] = SYSDATETIMEOFFSET() OUTPUT [inserted].[key_guid], [inserted].[ref_definition_guid], [inserted].[pub_batch_number], [inserted].[pub_steps], [inserted].[pub_can_retry], [inserted].[pub_max_attempts], [inserted].[pub_attempts], [inserted].[ref_disposition_enum_guid], [inserted].[pub_started_on], [inserted].[ref_package_guid] INTO @claimed FROM [dbo].[system_workflow_queue] AS [swq] JOIN [next] ON [next].[key_guid] = [swq].[key_guid]; SELECT [c].[key_guid], [c].[ref_definition_guid], [c].[pub_batch_number], [c].[pub_steps], [c].[pub_can_retry], [c].[pub_max_attempts], [c].[pub_attempts], [c].[ref_disposition_enum_guid], [c].[pub_started_on], [c].[ref_package_guid], [swd].[pub_name] FROM @claimed AS [c] JOIN [dbo].[service_workflow_definitions] AS [swd] ON [swd].[key_guid] = [c].[ref_definition_guid] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER';
-- account:users create input model (D962613C) and read_all output model (530B06E0): pub_email before pub_display.
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = 'D962613C-4F39-54B4-A6DC-B76BD580E11E' AND [pub_name] IN ('pub_email', 'pub_display', 'pub_is_enabled') AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = 'D962613C-4F39-54B4-A6DC-B76BD580E11E' AND [pub_name] = 'pub_email';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = 'D962613C-4F39-54B4-A6DC-B76BD580E11E' AND [pub_name] = 'pub_display';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = 'D962613C-4F39-54B4-A6DC-B76BD580E11E' AND [pub_name] = 'pub_is_enabled';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = '530B06E0-6258-5261-8573-1A207971CD4B' AND [pub_name] IN ('pub_email', 'pub_display', 'pub_is_enabled') AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = '530B06E0-6258-5261-8573-1A207971CD4B' AND [pub_name] = 'pub_email';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = '530B06E0-6258-5261-8573-1A207971CD4B' AND [pub_name] = 'pub_display';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_model_guid] = '530B06E0-6258-5261-8573-1A207971CD4B' AND [pub_name] = 'pub_is_enabled';
GO

-- =====================================================================
-- Batch 4: the core Workflow and Gateway modules re-listed under the Operations / Execution pattern (Aaron 2026-11-02:
-- "Correct the fucking pattern"; the 2026-10-27 ruling). GatewayInterfaceModule -> GatewayOperationsModule,
-- WorkflowMaintenanceModule -> WorkflowOperationsModule, WorkflowManagementModule -> WorkflowExecutionModule. The new rows
-- are listed before the first boot (the loader refuses an unlisted class); the sequence allocation log is re-keyed to the
-- renamed executor so the statutory trace survives; the old rows, their function rows and every edge on either side go in
-- FK-safe order; populate re-registers the functions and edges under the new names. The workflow task provider and
-- worker are renamed the same day to the kind-first pattern of the database providers (workflow_task_* ->
-- async_transaction_*, AsyncTransactionProvider / AsyncTransactionWorker); their two rows and edges retire here too and
-- populate lists the new ones (PROVIDER / WORKER rows are not loader-gated).
-- The definitions reader (WorkflowManagementProvider and its base, one op) is gone: the executor dispatches
-- db:workflow:definitions:read_all:1 through the Database Manager itself (Aaron 2026-11-02: the ME layer, not P); its
-- two rows, the read_all function row and their edges retire here.
-- =====================================================================
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('E6B40C06-6F58-5B5B-AA98-68120522E2B4', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'GatewayOperationsModule', 0, 'server/core/gateway_operations_module.py');
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('53E01805-C6DE-55E9-A99C-E99DD6B20005', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'WorkflowOperationsModule', 0, 'server/core/workflow_operations_module.py');
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('9AAA2FB1-D199-58C7-AFA8-A3B8DEE5C904', '916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'WorkflowExecutionModule', 0, 'server/core/workflow_execution_module.py');
UPDATE [dbo].[system_sequence_allocations] SET [ref_module_guid] = '9AAA2FB1-D199-58C7-AFA8-A3B8DEE5C904', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_module_guid] = '05249B65-D92F-5DB4-A6F6-E19EFE07B16C';
UPDATE [dbo].[system_sequence_allocations] SET [ref_module_guid] = '53E01805-C6DE-55E9-A99C-E99DD6B20005', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_module_guid] = '7989CDC0-A354-5897-B455-11CE517457D7';
UPDATE [dbo].[system_sequence_allocations] SET [ref_module_guid] = 'E6B40C06-6F58-5B5B-AA98-68120522E2B4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [ref_module_guid] = '60FC86E2-C274-5B52-ACA1-354EE7185BC0';
-- the discord_guild_sync step names the Manager by class: the rename follows into the definition row
UPDATE [dbo].[service_workflow_definitions] SET [pub_steps] = N'{"steps": [{"contract": "GatewayOperationsModule.sync_guilds", "model": "void", "params": {}}]}', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E9D5A665-EFA4-5457-B897-F6D2F343467D' AND [pub_steps] = N'{"steps": [{"contract": "GatewayInterfaceModule.sync_guilds", "model": "void", "params": {}}]}';
DELETE FROM [etg].[contracts_modules_functions] WHERE [ref_module_guid] IN ('60FC86E2-C274-5B52-ACA1-354EE7185BC0', '7989CDC0-A354-5897-B455-11CE517457D7', '05249B65-D92F-5DB4-A6F6-E19EFE07B16C', 'E2A5E8C7-74D3-56A8-A28F-CB8A825E8DB9', 'F12C79F9-B321-5F23-9F20-3B5BE724922B', '3EE28568-E3EB-52CD-B67B-DEADE072055E', '75BAD353-BC40-56DA-BDD6-46CE63F9A124');
DELETE FROM [etg].[contracts_modules_dependencies] WHERE [ref_module_guid] IN ('60FC86E2-C274-5B52-ACA1-354EE7185BC0', '7989CDC0-A354-5897-B455-11CE517457D7', '05249B65-D92F-5DB4-A6F6-E19EFE07B16C', 'E2A5E8C7-74D3-56A8-A28F-CB8A825E8DB9', 'F12C79F9-B321-5F23-9F20-3B5BE724922B', '3EE28568-E3EB-52CD-B67B-DEADE072055E', '75BAD353-BC40-56DA-BDD6-46CE63F9A124') OR [ref_dependency_guid] IN ('60FC86E2-C274-5B52-ACA1-354EE7185BC0', '7989CDC0-A354-5897-B455-11CE517457D7', '05249B65-D92F-5DB4-A6F6-E19EFE07B16C', 'E2A5E8C7-74D3-56A8-A28F-CB8A825E8DB9', 'F12C79F9-B321-5F23-9F20-3B5BE724922B', '3EE28568-E3EB-52CD-B67B-DEADE072055E', '75BAD353-BC40-56DA-BDD6-46CE63F9A124');
DELETE FROM [etg].[contracts_modules] WHERE [key_guid] IN ('60FC86E2-C274-5B52-ACA1-354EE7185BC0', '7989CDC0-A354-5897-B455-11CE517457D7', '05249B65-D92F-5DB4-A6F6-E19EFE07B16C', 'E2A5E8C7-74D3-56A8-A28F-CB8A825E8DB9', 'F12C79F9-B321-5F23-9F20-3B5BE724922B', '3EE28568-E3EB-52CD-B67B-DEADE072055E', '75BAD353-BC40-56DA-BDD6-46CE63F9A124');
GO

-- =====================================================================
-- Batch 5: module_role gains PRIMITIVE (Aaron 2026-11-03: a role names the interface ABC a class implements; the standalone
-- system/service modules with no executor carry it; RPC may call MANAGER and PRIMITIVE rows only). Which modules carry it
-- is the component map's classification; populate follows that, not a name rule.
-- =====================================================================
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('4C4ADD75-0A5B-53D1-AB0E-2EEBBC143B0E', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMITIVE', 5, N'Primitive slot: a standalone module with no executor that serves system or service data (configuration, enumerations, environment, logging); with MANAGER, the only role RPC may dispatch to.');
UPDATE [etg].[contracts_primitives_enum_types] SET [pub_notes] = N'MEP slot of a module: MANAGER (Operations, Maintenance), EXECUTOR (Execution, Management), PROVIDER, WORKER, SERVICE (the kernel services around the modules), PRIMITIVE (a standalone module with no executor). NULL on BaseModule, the base of every slot.', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5E1DE2D2-E1F3-5B20-A126-7CFF92741146';
GO

-- =====================================================================
-- Batch 6: READ logging (Aaron 2026-11-03: audit is CRUD, said twice; the agent set up insert/update/delete only).
-- dbo.service_audit_tables gains pub_log_read, declared at ordinal 5 (CRUD order: insert, read, update, delete);
-- audit_kind gains READ = 4; the three audit-table ops and their models carry the flag.
-- =====================================================================
ALTER TABLE [dbo].[service_audit_tables] ADD [pub_log_read] BIT DEFAULT (0) NOT NULL;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '108ABD08-77C4-54F3-9F7B-4910A6F57E84' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2C5A63D6-71A3-5D41-9804-C71545AA8D07';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A0409913-28F6-5B60-A6DB-47D152CD0D69';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '23EB9D12-6347-5B25-BC70-1F83AEBFACD1';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A3FB176A-050D-5221-95A9-DA0B1FB7E629';
INSERT INTO [etg].[contracts_db_columns] ([key_guid], [ref_table_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('31B0531C-8C7C-55AB-8379-536E0DB6AA7F', '108ABD08-77C4-54F3-9F7B-4910A6F57E84', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_read', 5, 0, '0', NULL, 0);
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7EA41427-4B43-5096-A553-CCFA317FD563';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '3D664C0A-3BA1-518E-A1C0-F009745559C4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2973155A-DB2F-5AC1-A816-604AFE4ACAEF';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0B6BB8EB-0444-57F9-96FF-20123BA12E0B';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '8A19ED49-256A-580C-8BB7-E985B20B4C5F';
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('29765458-8EDF-56AC-B149-4B84231776DB', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'READ', 4, N'A record was read.');
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413' AND [pub_name] IN ('pub_log_insert', 'pub_log_update', 'pub_log_delete') AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FC0CFDEC-F73A-5127-B8C7-905D553AA3A6';
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('810484A1-DC4C-577C-84AB-C439832682C8', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_read', 6, 0, NULL, NULL, 0);
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '735A9C7E-928A-5E8C-9C5A-44ABFFF82BCA';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '25875628-F9B1-5C44-B80A-3517E8E58E4B';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = '68177FB7-53FD-540B-9716-CEDACD86D3C1' AND [pub_name] IN ('pub_log_insert', 'pub_log_update', 'pub_log_delete', 'pub_notes') AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2CEBAB83-8CFB-5E1F-A22A-9298C4565090';
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F48942A5-8D34-5970-AEFB-7ACC74BC4E67', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_read', 5, 0, NULL, NULL, 0);
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EAC596B2-C797-5BAC-ACC7-D32A31E66A02';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '51C1AD1B-2A5A-5F3C-A5E4-91C96A460140';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C6C62A8C-6BB3-5EA3-93FC-735524CF07F8';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = 'B01E9349-8B08-5537-A4CC-280767C40FE0' AND [pub_name] IN ('pub_log_insert', 'pub_log_update', 'pub_log_delete', 'ref_table_guid') AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '450545B4-CCD0-5BA3-85D1-863AB6E4514D';
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FD425696-1E05-54FE-AD4C-4118C457871C', 'B01E9349-8B08-5537-A4CC-280767C40FE0', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_read', 2, 0, NULL, NULL, 0);
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0DF3D463-0D53-5060-8478-8902739B42BE';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E118BC8-6491-55F1-A80E-837C04CF36B9';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4CDA76CA-947F-51B4-98E1-8A0C48FB767E';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'INSERT INTO [dbo].[service_audit_tables] ([key_guid], [ref_package_guid], [ref_table_guid], [pub_log_insert], [pub_log_read], [pub_log_update], [pub_log_delete], [pub_notes]) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'INSERT INTO [dbo].[service_audit_tables] ([key_guid], [ref_package_guid], [ref_table_guid], [pub_log_insert], [pub_log_update], [pub_log_delete], [pub_notes]) VALUES (?, ?, ?, ?, ?, ?, ?)';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'UPDATE [sat] SET [sat].[pub_log_insert] = ?, [sat].[pub_log_read] = ?, [sat].[pub_log_update] = ?, [sat].[pub_log_delete] = ?, [sat].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_audit_tables] AS [sat] WHERE [sat].[ref_table_guid] = ?', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'UPDATE [sat] SET [sat].[pub_log_insert] = ?, [sat].[pub_log_update] = ?, [sat].[pub_log_delete] = ?, [sat].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_audit_tables] AS [sat] WHERE [sat].[ref_table_guid] = ?';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [sat].[key_guid], [sat].[ref_table_guid], [cdt].[pub_schema], [cdt].[pub_name], [sat].[pub_log_insert], [sat].[pub_log_read], [sat].[pub_log_update], [sat].[pub_log_delete] FROM [dbo].[service_audit_tables] AS [sat] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdt].[key_guid] = [sat].[ref_table_guid] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [sat].[key_guid], [sat].[ref_table_guid], [cdt].[pub_schema], [cdt].[pub_name], [sat].[pub_log_insert], [sat].[pub_log_update], [sat].[pub_log_delete] FROM [dbo].[service_audit_tables] AS [sat] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdt].[key_guid] = [sat].[ref_table_guid] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH';
GO

-- =====================================================================
-- Batch 7: the entry point record (Aaron 2026-11-03, Option A of the entry-gap proposal). The platform list becomes the
-- enum cloudhost_engine; contracts_entrypoints says what launches the process (platform, command, the module entered);
-- the scaling concern stays with the Host module. Three kernel rows: startup.sh (deployed, CONTAINER) and the local
-- twins dev.sh / dev.cmd (not deployed, LOCAL), tracked so the Dockerfile cleanup can one day be rendered from data.
-- The Main module row is listed here because the entry rows reference it before the first populate. service_hosts gains
-- ref_entrypoint_guid (declared after ref_status_enum_guid), NULL until the host register op passes it (tracked, as the
-- context columns were); the host read op projects it now. contracts_engines_cloudhost is dropped with its declarations.
-- =====================================================================
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cloudhost_engine', N'The platform an entry point launches the process on.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('839D8F97-2D6E-5135-81CD-A76E135E4A97', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'LOCAL', 1, N'A developer machine: dev.sh / dev.cmd, uvicorn with reload on localhost.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('AC26B0F1-48C4-5133-BBB4-B7539D7BA7F3', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CONTAINER', 2, N'The image: startup.sh, uvicorn on 0.0.0.0:8000, wherever the container runs.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('4A3BEA0A-490B-5C4E-8B61-0C06FC48D9D6', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ACA', 3, N'Azure Container Apps.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('0FEBB2D7-F55C-592C-88F5-179772136B4F', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'AKS', 4, N'Azure Kubernetes Service.');
CREATE TABLE [etg].[contracts_entrypoints] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_engine_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_app] NVARCHAR(128) NOT NULL,
  [pub_command] NVARCHAR(512) NOT NULL,
  [pub_host] NVARCHAR(256) NOT NULL,
  [pub_port] INT NOT NULL,
  [pub_is_deployed] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [PK_contracts_entrypoints] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [UQ_ce_engine_name] UNIQUE NONCLUSTERED ([ref_engine_enum_guid], [pub_name]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_engine] FOREIGN KEY ([ref_engine_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
CREATE NONCLUSTERED INDEX [IX_ce_module] ON [etg].[contracts_entrypoints] ([ref_module_guid]);
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('D94DC643-22B6-5D8C-953A-5BE9B8EAD9A6', '7FA001CC-D978-5589-869D-8D957D1F31A9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'Main', 0, 'main.py');
INSERT INTO [etg].[contracts_entrypoints] ([key_guid], [ref_engine_enum_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_app], [pub_command], [pub_host], [pub_port], [pub_is_deployed], [pub_notes]) VALUES ('BBDE50E7-CF47-5DBB-AB73-25CB9C61CA80', 'AC26B0F1-48C4-5133-BBB4-B7539D7BA7F3', 'D94DC643-22B6-5D8C-953A-5BE9B8EAD9A6', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'startup.sh', 'main:app', N'python -m uvicorn main:app --host 0.0.0.0 --port 8000', '0.0.0.0', 8000, 1, N'The image entry: Dockerfile CMD runs it.');
INSERT INTO [etg].[contracts_entrypoints] ([key_guid], [ref_engine_enum_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_app], [pub_command], [pub_host], [pub_port], [pub_is_deployed], [pub_notes]) VALUES ('B50D47BB-E321-5BC8-8266-D28B291DAE93', '839D8F97-2D6E-5135-81CD-A76E135E4A97', 'D94DC643-22B6-5D8C-953A-5BE9B8EAD9A6', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'dev.sh', 'main:app', N'python3 -m uvicorn main:app --reload --host localhost', 'localhost', 8000, 0, N'Local test launch (macOS/Linux); removed from the image.');
INSERT INTO [etg].[contracts_entrypoints] ([key_guid], [ref_engine_enum_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_app], [pub_command], [pub_host], [pub_port], [pub_is_deployed], [pub_notes]) VALUES ('F16BDB67-A34B-5816-B10C-6716011AC9BE', '839D8F97-2D6E-5135-81CD-A76E135E4A97', 'D94DC643-22B6-5D8C-953A-5BE9B8EAD9A6', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'dev.cmd', 'main:app', N'python -m uvicorn main:app --reload --host localhost', 'localhost', 8000, 0, N'Local test launch (Windows); removed from the image.');
ALTER TABLE [dbo].[service_hosts] ADD [ref_entrypoint_guid] UNIQUEIDENTIFIER NULL;
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_entrypoint] FOREIGN KEY ([ref_entrypoint_guid]) REFERENCES [etg].[contracts_entrypoints] ([key_guid]);
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '4E76CA07-D493-5E99-BFF9-9379567B1D50' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1FEBC18E-331B-5DF1-A842-CE008EC53EBA';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BFDE8EA6-5FF2-5CAA-986D-379083C74E1D';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '96E3B1DE-3699-5424-9E1C-D9B9B6489C91';
INSERT INTO [etg].[contracts_db_columns] ([key_guid], [ref_table_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('35DA1F0D-8165-5EBF-A61F-2523A470629B', '4E76CA07-D493-5E99-BFF9-9379567B1D50', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_entrypoint_guid', 4, 1, NULL, NULL, 0);
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '411F7D3B-A5CB-5AC4-8439-F8B18529137E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A7286708-4203-5BD4-BC8A-F637A134FE06';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A245C526-A869-5064-9020-04CCA46C27CA';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7CF33AD6-71C9-5411-9EAA-204436871010';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DDFEFD32-92D8-53F4-9599-F33D1DA55081';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0FFEF4F2-C133-59BB-85C3-9BE3F96C6941';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F6B2AD95-B9AD-5152-A88F-035ABE59D4FA';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0D7255D4-7D3A-50C1-B902-CB3C52570489';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 13, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E23E342C-17CF-523D-A2F7-95F0F85740E4';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 14, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D3F0184F-0EF8-51CB-A6C5-25D9C31DE624';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [sh].[key_guid], [sh].[ref_status_enum_guid], [sh].[ref_entrypoint_guid], [sh].[pub_host_name], [sh].[pub_pid], [sh].[pub_kernel_version], [sh].[pub_core_version], [sh].[pub_connections], [sh].[pub_started_on], [sh].[pub_heartbeat_on], [sh].[pub_lease_until] FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ? FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [sh].[key_guid], [sh].[ref_status_enum_guid], [sh].[pub_host_name], [sh].[pub_pid], [sh].[pub_kernel_version], [sh].[pub_core_version], [sh].[pub_connections], [sh].[pub_started_on], [sh].[pub_heartbeat_on], [sh].[pub_lease_until] FROM [dbo].[service_hosts] AS [sh] WHERE [sh].[key_guid] = ? FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES';
DROP TABLE [etg].[contracts_engines_cloudhost];
DELETE FROM [etg].[contracts_db_constraint_columns] WHERE [ref_constraint_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D' OR [ref_referenced_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D') OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D') OR [ref_referenced_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D');
DELETE FROM [etg].[contracts_db_index_columns] WHERE [ref_index_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D') OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D');
DELETE FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D' OR [ref_referenced_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D';
DELETE FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D';
DELETE FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D';
DELETE FROM [dbo].[service_package_tables] WHERE [ref_table_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D';
DELETE FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'D2D19619-42A6-51F9-BC13-EFD855AEAA0D';
GO

-- =====================================================================
-- Batch 8: the component model (Aaron 2026-11-02 direction; rulings 2026-11-03). A component is a hand-authored row
-- attached to its package; every module row names its component; dependencies are recorded at BOTH levels, the
-- module edges populate reflects and the component edges declared here (the accepted risk edge: populate derives the
-- component edges from the module edges and reports every difference). EXTENDS is the third module dependency kind:
-- a module of <X>Maintenance over its concrete pair in <X>. Single-module components and Server are the server tier
-- and carry no package of their own here; the 2026-11-11 addendum attaches each to its modules' package. Packages extend
-- packages in service_package_dependencies (core over kernel, setup over core). contracts_modules is REBUILT through
-- a copy so ref_component_guid sits second, then declared.
-- =====================================================================
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('0BACC23E-8865-5C11-808B-FA068A226844', '1CDD672E-B1CE-5C8D-A386-7C4A26ACAB8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'EXTENDS', 2, N'The privileged composition: the module is an extension over its concrete pair of the same role in the component it extends; the one dependency whose target need not be a Manager.');
CREATE TABLE [etg].[contracts_components] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [PK_contracts_components] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [UQ_cc_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [FK_cc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
CREATE TABLE [etg].[contracts_components_dependencies] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_component_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_dependency_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [PK_contracts_components_dependencies] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [UQ_ccd_component_dependency] UNIQUE NONCLUSTERED ([ref_component_guid], [ref_dependency_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_component] FOREIGN KEY ([ref_component_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
CREATE NONCLUSTERED INDEX [IX_ccd_component] ON [etg].[contracts_components_dependencies] ([ref_component_guid]);
CREATE NONCLUSTERED INDEX [IX_ccd_kind] ON [etg].[contracts_components_dependencies] ([ref_kind_enum_guid]);
CREATE TABLE [dbo].[service_package_dependencies] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_dependency_guid] UNIQUEIDENTIFIER NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [PK_service_package_dependencies] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [UQ_spd_package_dependency] UNIQUE NONCLUSTERED ([ref_package_guid], [ref_dependency_guid]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [FK_spd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [FK_spd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]);
INSERT INTO [dbo].[service_package_dependencies] ([key_guid], [ref_package_guid], [ref_dependency_guid]) VALUES ('1A2170FE-F8A3-537B-8CD0-207BC83DB6E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [dbo].[service_package_dependencies] ([key_guid], [ref_package_guid], [ref_dependency_guid]) VALUES ('676BAF9F-F2C2-51C3-A1DA-8327075A709E', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('F822D033-FC2C-55BA-8E61-022CD2920B53', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Auth', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('2A3731A6-4226-5336-BC2B-E2DA49C5D8CC', NULL, 'CoreConfiguration', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('565F8BD3-013D-5435-AD45-7E7E307A038B', NULL, 'CoreLogging', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('FE33702D-56D0-59C9-ACDC-356016C654AF', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'Database', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('99B79E0F-5870-5785-8A9F-400CC5AED74F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DatabaseMaintenance', N'The privileged composition over Database: Maintenance over Operations, Management over Execution, the management provider and worker over the transaction provider.');
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('8B989CE7-909E-5DF8-BBEA-1A635AEC525F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Discord', N'Discord system data: the guild registry and the guild as an organization. The bot connection is a Gateway channel.');
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('129125D1-6F86-506C-AF33-6763948ADD51', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Entitlements', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', NULL, 'EnvironmentVariables', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('61801503-76D3-5804-B897-EC8B89634BE4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Gateway', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('2CA990FC-07EB-57ED-BED4-03ED72A8D542', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'Host', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('3392526D-7E72-539C-9F08-71AE7CF1E793', NULL, 'KernelConfiguration', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B7E21FBA-58D3-584B-BF10-364C6D9489F1', NULL, 'KernelEnum', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('331B196C-6A32-5F81-A76F-0F75981AA4F5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Organizations', N'The organization primitive and its user membership: one shape for a Discord guild, an Entra tenant, an in-game guild.');
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Security', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('39B84C02-2743-5428-AC6F-5760E3703D21', NULL, 'Server', N'The tier beside the packages: the process entry, the lifespan, the kernel services, the helpers and the root bases.');
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('68EF211E-E7B2-5EA3-B1F1-952CC9D45912', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Users', NULL);
INSERT INTO [etg].[contracts_components] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'Workflow', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('22271EE4-AAA8-54FA-A01D-C315A692EF27', 'F822D033-FC2C-55BA-8E61-022CD2920B53', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('E2EF7DAC-7F13-53A9-8768-77950A191AF3', '2A3731A6-4226-5336-BC2B-E2DA49C5D8CC', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('D27A0092-2BB4-55F9-B978-D9EA6D7A9233', '565F8BD3-013D-5435-AD45-7E7E307A038B', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('0B5CBCDE-138C-5BE8-985A-1305C3233DCA', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('34CCBBDB-2213-5FA2-90E1-75C994ED70B9', '99B79E0F-5870-5785-8A9F-400CC5AED74F', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '0BACC23E-8865-5C11-808B-FA068A226844', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('A26D2E2A-0673-5B8F-A2C0-3A2604156BFA', '99B79E0F-5870-5785-8A9F-400CC5AED74F', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('8576C9EF-34D1-5BCA-A56C-BD2C846CFDD1', '8B989CE7-909E-5DF8-BBEA-1A635AEC525F', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('056D2763-EE91-55F8-AA49-EC84C2370E1F', '8B989CE7-909E-5DF8-BBEA-1A635AEC525F', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('2B77CCFC-398D-5D49-82BD-F5D8E2657C2A', '129125D1-6F86-506C-AF33-6763948ADD51', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('D5D7E81A-FFE1-5628-8402-5C16A517D409', '129125D1-6F86-506C-AF33-6763948ADD51', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('9A258AE7-DD8A-57C3-93BC-9A3718C5B282', '61801503-76D3-5804-B897-EC8B89634BE4', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('4EC7EB70-1543-5B55-ADE1-C69E0CBAF471', '61801503-76D3-5804-B897-EC8B89634BE4', '8B989CE7-909E-5DF8-BBEA-1A635AEC525F', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('FE5C5AD3-8867-5C6D-9738-E64A1E02C22C', '61801503-76D3-5804-B897-EC8B89634BE4', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('EE97BC4A-F601-530A-806C-E483D3BB644A', '61801503-76D3-5804-B897-EC8B89634BE4', '3392526D-7E72-539C-9F08-71AE7CF1E793', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('63CA7D20-6132-542B-93E1-F247596757DC', '61801503-76D3-5804-B897-EC8B89634BE4', '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('1C9EA934-32DE-564D-94AA-A579E1D1EA20', '2CA990FC-07EB-57ED-BED4-03ED72A8D542', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('06289A66-58A7-5448-B793-1BF1AECCBC39', '2CA990FC-07EB-57ED-BED4-03ED72A8D542', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('60DBDD03-84F2-5267-9B60-4E313176AA9C', '2CA990FC-07EB-57ED-BED4-03ED72A8D542', '3392526D-7E72-539C-9F08-71AE7CF1E793', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('3E889354-C216-5421-9117-7C50452CF3CA', '2CA990FC-07EB-57ED-BED4-03ED72A8D542', 'B7E21FBA-58D3-584B-BF10-364C6D9489F1', '1157DAB1-7D35-505F-B877-59543829C4E7', '7E203E54-5538-5C0F-B6E5-D276DCD04C36');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('1B4390A7-B4CB-5246-A080-E54246FF026D', '3392526D-7E72-539C-9F08-71AE7CF1E793', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('0E6A4B99-CB8E-52C3-B9AD-63F466495A44', '3392526D-7E72-539C-9F08-71AE7CF1E793', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('8B230560-35BC-5751-8590-BDB0DC88FA1C', 'B7E21FBA-58D3-584B-BF10-364C6D9489F1', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', NULL);
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('71271CC1-DF95-5979-97ED-D0C943AF4FF3', '331B196C-6A32-5F81-A76F-0F75981AA4F5', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('B38C2FDE-AFB0-5B60-B7AF-C2DFA0E6CB26', 'F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('752E8C1A-FFF1-5D79-8A50-BF2DF6459855', 'F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', '129125D1-6F86-506C-AF33-6763948ADD51', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('EACE24F1-13E8-546F-A16F-EFDF3C168837', 'F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('3CE63772-CBCB-523B-A987-6F6046D90341', '68EF211E-E7B2-5EA3-B1F1-952CC9D45912', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('0A16792B-A608-5A48-80CD-DAAA80CE7EB9', '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', 'FE33702D-56D0-59C9-ACDC-356016C654AF', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('1BA4EBE3-AB76-573B-A57C-F24BF30854D0', '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_components_dependencies] ([key_guid], [ref_component_guid], [ref_dependency_guid], [ref_kind_enum_guid], [ref_package_guid]) VALUES ('75C00309-4CF0-59CA-AB20-7B5D23637FA6', '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', '3392526D-7E72-539C-9F08-71AE7CF1E793', '1157DAB1-7D35-505F-B877-59543829C4E7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
ALTER TABLE [etg].[contracts_modules_dependencies] DROP CONSTRAINT [FK_cmd_dependency];
ALTER TABLE [etg].[contracts_modules_dependencies] DROP CONSTRAINT [FK_cmd_module];
ALTER TABLE [etg].[contracts_modules_functions] DROP CONSTRAINT [FK_cmf_module];
ALTER TABLE [etg].[contracts_urn_namespaces] DROP CONSTRAINT [FK_cun_module];
ALTER TABLE [etg].[contracts_urn_subdomains] DROP CONSTRAINT [FK_cus_module];
ALTER TABLE [etg].[contracts_urn_domains] DROP CONSTRAINT [FK_cud_module];
ALTER TABLE [dbo].[system_sequence_allocations] DROP CONSTRAINT [FK_ssa_module];
ALTER TABLE [etg].[contracts_entrypoints] DROP CONSTRAINT [FK_ce_module];
SELECT * INTO [etg].[contracts_modules_MIGRATION] FROM [etg].[contracts_modules];
DROP TABLE [etg].[contracts_modules];
CREATE TABLE [etg].[contracts_modules] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_component_guid] UNIQUEIDENTIFIER NULL,
  [ref_role_enum_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_is_abstract] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes], [priv_created_on], [priv_modified_on]) SELECT [key_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes], [priv_created_on], [priv_modified_on] FROM [etg].[contracts_modules_MIGRATION];
DROP TABLE [etg].[contracts_modules_MIGRATION];
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [PK_contracts_modules] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [UQ_cm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_component] FOREIGN KEY ([ref_component_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_role] FOREIGN KEY ([ref_role_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
CREATE NONCLUSTERED INDEX [IX_cm_component] ON [etg].[contracts_modules] ([ref_component_guid]);
CREATE NONCLUSTERED INDEX [IX_cm_role] ON [etg].[contracts_modules] ([ref_role_enum_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [FK_cmf_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [FK_cun_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
GO
-- Batch 8, second half: a batch is compiled whole before it runs, and contracts_modules existed without ref_component_guid
-- when the first half was compiled (Msg 207 on 2026-11-11). The rebuilt table is referenced only from here on.
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2A9E80DD-7D97-5C59-AD8D-80FEFF86182B';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FF08788B-36D2-5074-8A31-F980C99476C1';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '61339F4F-AE1C-562A-893D-ECAFEA8E7726';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '32935867-BFE8-580E-B7DB-64A93717A556';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FA05E950-BE2F-509E-98CE-A9ADA5656819';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6B5F25AE-73A0-51C5-B160-5FF657F56F97';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4EC4C00B-1DAE-5898-A08E-64D29949E54F';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '14E372B6-5635-5A12-B34E-CF167FCC8E1E';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BE82CA88-9888-5285-8746-396B09327054';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '70631F5E-1579-57B1-ADC9-A2319A24AFDB';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '01443E07-9CC8-5D53-964F-663B7F80313B';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'FE33702D-56D0-59C9-ACDC-356016C654AF', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CAC75654-CB0E-5BDE-9CF7-2A1098113245';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9DE3DFE1-E8F8-5CAD-855D-62CAE0BD753E';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A3A5BA4D-629C-5B43-A921-B2A656DA8BF9';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4D211225-E5DF-53A7-A5E1-278531946921';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7FEFFF59-6A6C-51DA-B59E-B6F51B299436';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F9523B1A-445F-58CD-B019-DCB53AE0B271';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D7E8E2D4-11F9-506D-A58B-07D27EC5FC7F';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2F35EA14-E97D-5C35-8AEE-630A343E6FFB';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EC2F7297-3FED-5BAC-8A0F-1DD8A6CB48C4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D24AE07D-EE60-55B9-9DB6-5049566AAB2A';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '798C9742-1D8C-5A2F-AE6B-1F268B9D7640';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2A3731A6-4226-5336-BC2B-E2DA49C5D8CC', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '19AD58B3-77F4-5771-A853-A7011B34AD13';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '565F8BD3-013D-5435-AD45-7E7E307A038B', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '52E3192F-939B-560B-AD4F-06B789C607E9';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'FE33702D-56D0-59C9-ACDC-356016C654AF', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CC04A818-DF08-58A3-A57B-3251CA484E35';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6ECB6FBC-6548-5C9F-B34E-7CDCC5699162';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '75347360-7F78-5909-BB54-D1850CF9187E';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FC73809E-D1BA-5360-9EC9-506800775E87';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'FE33702D-56D0-59C9-ACDC-356016C654AF', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'C17B5152-F788-58C6-A441-E116F651F906';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '4B5FE211-D4ED-5230-AB59-13595098CF96';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A0546DEA-C46A-5F8C-9327-827CCD5780E4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '117C4B8F-E95D-578A-AAF9-4726A2C969D4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '129125D1-6F86-506C-AF33-6763948ADD51', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E065E280-B32F-586B-A860-370A1F23BC8C';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '129125D1-6F86-506C-AF33-6763948ADD51', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FD8366ED-1ED1-5C86-B6EC-B75A4A8856C7';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '8FEAB21F-BBEF-58F2-8C99-205FF3BEAAD4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BAE8F208-F668-55D8-A89A-83834DFD4FCE';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '887B1E1A-A4A3-572D-A283-47BB06FF31F4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E6B40C06-6F58-5B5B-AA98-68120522E2B4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2A6E745D-A10F-53A0-AAC8-8D832C715ADA';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7F4DED3E-1074-5C82-85E6-A5DC22551A39';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '530456B5-093F-572E-BEBD-D96B1462FDC2';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '2CA990FC-07EB-57ED-BED4-03ED72A8D542', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '82391782-21D3-5E01-B9A1-89D4BA659C71';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'B247E595-E3DA-59A0-86FC-651A24FA12D1';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '3392526D-7E72-539C-9F08-71AE7CF1E793', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1748A94C-0D3D-5A7B-BF79-8060933F33C0';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'B7E21FBA-58D3-584B-BF10-364C6D9489F1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5809E9D5-77FC-5C94-8308-45CE3583F3ED';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2B7F4853-C1EE-5C1B-ADA8-F69F1FD768A4';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '826ABD6B-8F76-5A50-AF4A-8A7460DB25CD';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D94DC643-22B6-5D8C-953A-5BE9B8EAD9A6';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CC81EE8E-CEB8-52AD-951F-1F6546E82CE3';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F822D033-FC2C-55BA-8E61-022CD2920B53', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '90077989-6146-5D9A-8E2F-DF39E7B860DD';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '39B84C02-2743-5428-AC6F-5760E3703D21', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'FA69B9AC-4B40-5C04-B1A2-87E395BB8027';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'AF60CD45-D5BE-5BB4-9B55-4E097002D470';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '99B79E0F-5870-5785-8A9F-400CC5AED74F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '2DBED964-06FC-5493-8727-D501A37BAE1D';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'FE33702D-56D0-59C9-ACDC-356016C654AF', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9C45F6F3-1934-5F9E-BC16-04F6C1740ED5';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '61801503-76D3-5804-B897-EC8B89634BE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'BD43FD1F-3D5F-5A35-B9C7-B3690665A64F';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'A005E24C-B051-5947-9B0D-858EEE771C96';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = 'F185B5A2-67F3-5A73-A20A-F91A0CBE6F35', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7B1AB7CE-999C-526D-B36D-4F67610AB819';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '68EF211E-E7B2-5EA3-B1F1-952CC9D45912', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1B6825E7-5140-598B-BF73-74E9591EB061';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '68EF211E-E7B2-5EA3-B1F1-952CC9D45912', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '54919DCC-5787-592A-9E16-4D22D778EF22';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9AAA2FB1-D199-58C7-AFA8-A3B8DEE5C904';
UPDATE [etg].[contracts_modules] SET [ref_component_guid] = '09F7D108-9EA6-5240-85AF-A9C5B1DDCB44', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '53E01805-C6DE-55E9-A99C-E99DD6B20005';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = 'D495E25E-146A-5916-9B8A-A8FCD8A7B127' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F5F17213-C0B1-5CB5-A31A-CD7946A7BFA4';
INSERT INTO [etg].[contracts_db_columns] ([key_guid], [ref_table_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1BBA052E-6ED0-5B79-820C-6D2CB05C3803', 'D495E25E-146A-5916-9B8A-A8FCD8A7B127', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_component_guid', 2, 1, NULL, NULL, 0);
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 3, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7A8037CF-F419-5958-82C9-AD957361312A';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 4, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DE47C285-A159-5F50-9CA3-0011A595AAC8';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '42E5CC59-AE7F-528D-A1EE-D5F5C757D697';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '17534D35-AEB5-57ED-BE8D-1B12779207CC';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '37B1238A-A9C5-5ECE-BF92-04FC5C010376';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '923D5548-E461-563E-B830-61AA275E2E4F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6BA561B1-B2BC-5DAB-A7FA-803D808EEC8A';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [cm].[key_guid], [cm].[ref_component_guid], [cm].[ref_role_enum_guid], [cm].[ref_package_guid], [cm].[pub_name], [cm].[pub_is_abstract] FROM [etg].[contracts_modules] AS [cm] FOR JSON PATH', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [cm].[key_guid], [cm].[ref_role_enum_guid], [cm].[ref_package_guid], [cm].[pub_name], [cm].[pub_is_abstract] FROM [etg].[contracts_modules] AS [cm] FOR JSON PATH';
GO

-- =====================================================================
-- Batch 9: the organization primitive and user membership, and the Discord component (Aaron 2026-11-03: Discord guild
-- data is system data owned by a Discord operations / execution pair; Organization -> User is a standard mapping for a
-- Discord guild, an Entra tenant and later an in-game guild; members are account users, the identity link comes with
-- OAuth). Tables: system_organizations (kind, external id, name), system_organization_members (organization, user,
-- joined/left). system_discord_guilds gains ref_organization_guid, declared after ref_package_guid, NULL until the Discord
-- executor maps a guild onto its organization (tracked), and ref_owner_user_guid: the one account user who owns the guild,
-- assigned and changed through db:discord:guilds:assign_owner (the Manager's assign_guild_owner). pub_credits leaves the
-- guild row: a guild carries no financial data; credits belong to a Finance package, not built, nothing depends on it.
-- Ops under db:account: organizations (create, read_all,
-- read_by_kind, update) and organization_members (create, read_active, mark_left), with their subdomains and
-- entitlements. The four new module rows are listed so the first boot loads them; the guild registry provider and its
-- contract retire: the Discord executor dispatches the guild ops itself (the ME layer, not a provider).
-- =====================================================================
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'organization_kind', N'What an organization row is: the external thing it maps.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('6231C597-4771-5888-8470-3EEF7308E966', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DISCORD_GUILD', 1, N'A Discord server.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('1C1EF0D5-C3AE-57C0-B1B5-0E1E5D9E820F', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTRA_TENANT', 2, N'A Microsoft Entra tenant.');
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('D24B3B8C-EC6E-5D52-A0A2-BD9DF03CFD67', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'GAME_GUILD', 3, N'An in-game guild.');
CREATE TABLE [dbo].[system_organizations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_external_id] NVARCHAR(256) NOT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [PK_system_organizations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [UQ_so_kind_external] UNIQUE NONCLUSTERED ([ref_kind_enum_guid], [pub_external_id]);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [FK_so_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [FK_so_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
CREATE NONCLUSTERED INDEX [IX_so_kind] ON [dbo].[system_organizations] ([ref_kind_enum_guid]);
CREATE TABLE [dbo].[system_organization_members] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_organization_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_user_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_joined_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_left_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [PK_system_organization_members] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [UQ_som_organization_user] UNIQUE NONCLUSTERED ([ref_organization_guid], [ref_user_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_organization] FOREIGN KEY ([ref_organization_guid]) REFERENCES [dbo].[system_organizations] ([key_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
CREATE NONCLUSTERED INDEX [IX_som_organization_left] ON [dbo].[system_organization_members] ([ref_organization_guid], [pub_left_on]);
CREATE NONCLUSTERED INDEX [IX_som_user] ON [dbo].[system_organization_members] ([ref_user_guid]);
ALTER TABLE [dbo].[system_discord_guilds] ADD [ref_organization_guid] UNIQUEIDENTIFIER NULL;
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_organization] FOREIGN KEY ([ref_organization_guid]) REFERENCES [dbo].[system_organizations] ([key_guid]);
ALTER TABLE [dbo].[system_discord_guilds] ADD [ref_owner_user_guid] UNIQUEIDENTIFIER NULL;
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_owner_user] FOREIGN KEY ([ref_owner_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
CREATE NONCLUSTERED INDEX [IX_sdg_owner_user] ON [dbo].[system_discord_guilds] ([ref_owner_user_guid]);
DECLARE @sdg_credits_default sysname = (SELECT [dc].[name] FROM [sys].[default_constraints] AS [dc] INNER JOIN [sys].[columns] AS [c] ON [c].[object_id] = [dc].[parent_object_id] AND [c].[column_id] = [dc].[parent_column_id] WHERE [dc].[parent_object_id] = OBJECT_ID(N'[dbo].[system_discord_guilds]') AND [c].[name] = N'pub_credits');
EXEC (N'ALTER TABLE [dbo].[system_discord_guilds] DROP CONSTRAINT [' + @sdg_credits_default + N']');
ALTER TABLE [dbo].[system_discord_guilds] DROP COLUMN [pub_credits];
DELETE FROM [etg].[contracts_db_columns] WHERE [key_guid] = '60E74FAC-91D5-57ED-A2B0-1EB8135BE9BC';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_table_guid] = '8FC03AB8-D609-5EFB-84FE-6D63CCC3833B' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E978311A-4A75-5CD6-8374-00BA35235958';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E83ABBCE-CEB0-5104-9FBC-2AE244EE9B80';
INSERT INTO [etg].[contracts_db_columns] ([key_guid], [ref_table_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('33DED0F1-CCC2-52CB-81A0-8265382DC2E4', '8FC03AB8-D609-5EFB-84FE-6D63CCC3833B', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_organization_guid', 3, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_columns] ([key_guid], [ref_table_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('65A3E38B-E008-5F40-B687-36523435DD5C', '8FC03AB8-D609-5EFB-84FE-6D63CCC3833B', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_owner_user_guid', 4, 1, NULL, NULL, 0);
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '87D660E9-8FAC-5411-A204-F3247182E096';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '630454D8-9A37-5169-BD96-B094EF0661F6';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6818C727-7BC2-5DEB-A9A1-09E57B342ED6';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0E1C6C5C-8F8C-5680-8E05-986D5137E5B0';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'B6667651-704E-5D17-B89B-09793E57FE8F';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '8EE0EA78-5FC9-55B6-85DE-799F6EF4C80E';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '85E69826-29DD-5669-963E-DE15DC6D6A40';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1B026AF1-5868-59E6-96FA-F50BAFD6785A';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 13, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D8E9313E-7851-565B-A564-5B6736AE4AF7';
UPDATE [etg].[contracts_db_columns] SET [pub_ordinal] = 14, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '77CF4EAB-5A23-53C1-949A-EE1DA8936041';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [sdg].[key_guid], [sdg].[ref_package_guid], [sdg].[ref_organization_guid], [sdg].[ref_owner_user_guid], [sdg].[pub_guild_id], [sdg].[pub_name], [sdg].[pub_owner_id], [sdg].[pub_region], [sdg].[pub_member_count], [sdg].[pub_notes], [sdg].[pub_joined_on], [sdg].[pub_left_on] FROM [dbo].[system_discord_guilds] AS [sdg] ORDER BY [sdg].[pub_guild_id] FOR JSON PATH, INCLUDE_NULL_VALUES', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [pub_query_mssql] = N'SELECT [sdg].[key_guid], [sdg].[ref_package_guid], [sdg].[pub_guild_id], [sdg].[pub_name], [sdg].[pub_owner_id], [sdg].[pub_region], [sdg].[pub_member_count], [sdg].[pub_credits], [sdg].[pub_notes], [sdg].[pub_joined_on], [sdg].[pub_left_on] FROM [dbo].[system_discord_guilds] AS [sdg] ORDER BY [sdg].[pub_guild_id] FOR JSON PATH, INCLUDE_NULL_VALUES';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = -[pub_ordinal] WHERE [ref_model_guid] = 'CED91567-DA0C-5751-9D9B-5D6E430539EF' AND [pub_ordinal] > 0;
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 1, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7668D74B-9D2C-52E0-83FF-473A1A9647BD';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 2, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '19DBDC78-58DC-50D7-B7E1-9B4739DA112B';
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9207DD65-BEA1-5555-918D-932E09948BF3', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_organization_guid', 3, 1, NULL, NULL, 0);
DELETE FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'CF454546-FB48-53E4-94B4-036251DAF504';
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DEAD96B7-E8C7-5FF3-92AB-EB8F43726289', 'CED91567-DA0C-5751-9D9B-5D6E430539EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_owner_user_guid', 4, 1, NULL, NULL, 0);
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 5, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '98E592B6-85AA-588D-909F-EF59C0EE26D6';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 6, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F59C9A32-8FBF-5F38-ABB6-FB9DAC226524';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 7, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '1E62FBB7-33D0-5841-9357-0FB75F439144';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 8, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '9A215FCD-519C-5617-B043-8375A18FBA4C';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 9, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E25ECE40-58EE-5566-98E9-4E8AFDA3E8E3';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 10, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '447E8CF4-6F14-5C14-8FEF-11322187F486';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 11, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '162490FA-05F9-500A-A722-B8E7A6A2D04D';
UPDATE [etg].[contracts_db_operations_models_fields] SET [pub_ordinal] = 12, [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DFABEA01-D466-5523-B70A-913623A0216F';
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('32D7F857-E7FD-5190-9CE8-EBCA11617582', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_guilds_assign_owner_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F642A134-3052-5A85-BF01-828EF3B4D559', '32D7F857-E7FD-5190-9CE8-EBCA11617582', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_owner_user_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4B3F527F-841A-5242-99B6-C34490E3A763', '32D7F857-E7FD-5190-9CE8-EBCA11617582', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_guild_id', 2, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('1B1C6F90-6C8F-573C-B44D-64A1A8B8EB03', '6BF728D6-134F-5CFE-8259-8C979828765D', '91990891-D593-5A1E-9CD4-EFDFB03A319F', '2D546528-7D1F-5E2B-A0D0-D5238B9AA66F', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'assign_owner', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('C9163589-0D69-553E-8D68-8ABF9A124E24', '1B1C6F90-6C8F-573C-B44D-64A1A8B8EB03', '32D7F857-E7FD-5190-9CE8-EBCA11617582', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sdg] SET [sdg].[ref_owner_user_guid] = ?, [sdg].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_discord_guilds] AS [sdg] WHERE [sdg].[pub_guild_id] = ?', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('76B36B58-6344-534D-97A1-03652F1E3088', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'organizations', NULL);
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('061CD668-5F12-5E24-9FE6-1A0599583E53', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_ORGANIZATIONS', N'Organizations', N'Grants the organizations subdomain.');
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('DC8BA2D2-7913-57F9-A233-043242C7E179', '76B36B58-6344-534D-97A1-03652F1E3088', '061CD668-5F12-5E24-9FE6-1A0599583E53', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('944C2A72-6441-5453-B48F-C0C55A25CC2B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'organization_members', NULL);
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('4A0887F4-0210-559C-A171-DFBDC2723BEE', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_ORGANIZATION_MEMBERS', N'Organization members', N'Grants the organization_members subdomain.');
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('35BA6004-5C3E-5CDC-92C2-556220AB1A83', '944C2A72-6441-5453-B48F-C0C55A25CC2B', '4A0887F4-0210-559C-A171-DFBDC2723BEE', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6CC59484-1B01-5A50-93DC-E584E0D9C266', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organizations_create_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E513B543-891E-54CB-A6C2-07E6F49A13D7', '6CC59484-1B01-5A50-93DC-E584E0D9C266', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D496713F-543D-53C7-83F9-A6B187383EEF', '6CC59484-1B01-5A50-93DC-E584E0D9C266', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9B2CD343-4951-5F36-9D5A-D1454DC6A4D9', '6CC59484-1B01-5A50-93DC-E584E0D9C266', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 3, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('CA97ACF0-0288-54FE-A5C3-F62627B955D9', '6CC59484-1B01-5A50-93DC-E584E0D9C266', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_external_id', 4, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E0DE9E0E-3423-5E31-9B00-6AE3464B0CF0', '6CC59484-1B01-5A50-93DC-E584E0D9C266', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 5, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D7A71773-79F5-5F8C-AA79-446241ABB782', '6CC59484-1B01-5A50-93DC-E584E0D9C266', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_notes', 6, 1, NULL, 512, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('2DE45BAD-05E5-5277-92E9-789A43A07C2A', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '76B36B58-6344-534D-97A1-03652F1E3088', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('1F2C2444-8FCD-5280-96FD-EF9E8CB2E855', '2DE45BAD-05E5-5277-92E9-789A43A07C2A', '6CC59484-1B01-5A50-93DC-E584E0D9C266', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_organizations] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_external_id], [pub_name], [pub_notes]) VALUES (?, ?, ?, ?, ?, ?)', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organizations_read_all_output', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('11C6B48E-9727-5830-B3A8-A3EBF5073323', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('592860D7-FDC4-5D34-A980-A094A48573B9', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 2, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0357DDB2-9E29-5EFD-BB18-8A016336EC38', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_external_id', 3, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8A086D73-3DCA-5026-9CE3-C66CADB184EE', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 4, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6EDBD3BD-039F-55B4-99B4-4C0F05B5FE87', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_notes', 5, 1, NULL, 512, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('44BA11E2-7F19-56EC-8AC8-1981210A490B', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '76B36B58-6344-534D-97A1-03652F1E3088', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('4B22453A-A084-5F68-98D3-93B074FB2B87', '44BA11E2-7F19-56EC-8AC8-1981210A490B', NULL, '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [so].[key_guid], [so].[ref_kind_enum_guid], [so].[pub_external_id], [so].[pub_name], [so].[pub_notes] FROM [dbo].[system_organizations] AS [so] ORDER BY [so].[pub_name] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5B8BD416-660C-5AF7-9AA2-ED955B27EE72', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organizations_read_by_kind_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0A75B26F-ADA6-5811-97C3-B1484E815D8D', '5B8BD416-660C-5AF7-9AA2-ED955B27EE72', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('E3882A48-88BC-55C5-B447-B831335D08A0', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '76B36B58-6344-534D-97A1-03652F1E3088', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_by_kind', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('7D1CC609-7A3E-5FD4-8330-917D770938DB', 'E3882A48-88BC-55C5-B447-B831335D08A0', '5B8BD416-660C-5AF7-9AA2-ED955B27EE72', '777D2E45-C0DA-51E5-A756-FFA9A3083B5D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [so].[key_guid], [so].[ref_kind_enum_guid], [so].[pub_external_id], [so].[pub_name], [so].[pub_notes] FROM [dbo].[system_organizations] AS [so] WHERE [so].[ref_kind_enum_guid] = ? ORDER BY [so].[pub_name] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('00E18CD0-75CA-5966-8501-877E6502321A', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organizations_update_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5994A26A-6806-5597-9370-B92527CD078A', '00E18CD0-75CA-5966-8501-877E6502321A', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 1, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6A4026F9-6A38-57C2-9920-57A7D2FF4881', '00E18CD0-75CA-5966-8501-877E6502321A', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_notes', 2, 1, NULL, 512, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6E027DB2-D048-5368-B019-821356EFDC7C', '00E18CD0-75CA-5966-8501-877E6502321A', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 3, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('762A3380-7133-5276-BE13-EF22ACAF709B', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '76B36B58-6344-534D-97A1-03652F1E3088', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'update', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('4E8AC19D-6D01-5F4B-B4CB-F939F4B27056', '762A3380-7133-5276-BE13-EF22ACAF709B', '00E18CD0-75CA-5966-8501-877E6502321A', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [so] SET [so].[pub_name] = ?, [so].[pub_notes] = ?, [so].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_organizations] AS [so] WHERE [so].[key_guid] = ?', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organization_members_create_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9A0C0138-697A-5364-A2C1-37C23474B56E', 'A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('72FEF65A-27B9-561A-A47E-F2165AB20CA5', 'A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7C9E0868-9DE2-5A36-8E39-1D3444980B74', 'A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_organization_guid', 3, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('BC3BAF74-25BC-5FE7-9132-57B4EA293110', 'A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 4, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('69CDE223-550F-5E9E-BA78-3CB1DC7F9CCA', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '944C2A72-6441-5453-B48F-C0C55A25CC2B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('87C62450-8CA7-526D-B9CA-46F45A068EC6', '69CDE223-550F-5E9E-BA78-3CB1DC7F9CCA', 'A5C8F668-6694-5FD8-BDEA-3CE0A30786D2', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_organization_members] ([key_guid], [ref_package_guid], [ref_organization_guid], [ref_user_guid], [pub_joined_on]) VALUES (?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('C9A0529E-A4A8-5470-94B3-787B2B090761', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organization_members_read_active_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('34FDD27B-7F28-57A8-B07F-5BD4E998787C', 'C9A0529E-A4A8-5470-94B3-787B2B090761', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_organization_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('FF4943B7-6E0C-5F2F-8B8D-5749E801F846', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organization_members_read_active_output', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7679074B-7830-50BE-8E5A-D23359D128D7', 'FF4943B7-6E0C-5F2F-8B8D-5749E801F846', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4A700E27-3BCC-55A6-ACA3-4E2299C255FA', 'FF4943B7-6E0C-5F2F-8B8D-5749E801F846', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 2, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4482C191-13BC-5FEF-9B52-253186E5F520', 'FF4943B7-6E0C-5F2F-8B8D-5749E801F846', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_joined_on', 3, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('F9F6F592-58BF-56EF-8604-D8F0C3BC9EA4', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '944C2A72-6441-5453-B48F-C0C55A25CC2B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_active', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('D77AA446-623D-55D1-AC2F-91250CDB624C', 'F9F6F592-58BF-56EF-8604-D8F0C3BC9EA4', 'C9A0529E-A4A8-5470-94B3-787B2B090761', 'FF4943B7-6E0C-5F2F-8B8D-5749E801F846', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [som].[key_guid], [som].[ref_user_guid], [som].[pub_joined_on] FROM [dbo].[system_organization_members] AS [som] WHERE [som].[ref_organization_guid] = ? AND [som].[pub_left_on] IS NULL FOR JSON PATH', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('66C487DA-2997-55EC-AA81-41881D278441', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_organization_members_mark_left_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('ECCE2BC2-0FC3-5E28-90C0-FBE586F86047', '66C487DA-2997-55EC-AA81-41881D278441', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_organization_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E762257A-C5E9-5855-A733-95007FB6C029', '66C487DA-2997-55EC-AA81-41881D278441', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 2, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('38D2D549-5F45-5BCC-915A-C60CD74B61AD', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '944C2A72-6441-5453-B48F-C0C55A25CC2B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'mark_left', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('69023C9C-E330-5052-A520-309D87554361', '38D2D549-5F45-5BCC-915A-C60CD74B61AD', '66C487DA-2997-55EC-AA81-41881D278441', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [som] SET [som].[pub_left_on] = SYSDATETIMEOFFSET(), [som].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_organization_members] AS [som] WHERE [som].[ref_organization_guid] = ? AND [som].[ref_user_guid] = ? AND [som].[pub_left_on] IS NULL', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_component_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('1CDB4F31-0115-5D3E-88AE-6E72B0DC9435', '8B989CE7-909E-5DF8-BBEA-1A635AEC525F', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DiscordOperationsModule', 0, 'server/core/discord_operations_module.py');
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_component_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('AE18BF98-63F7-54E3-A867-BB7B09C3974D', '8B989CE7-909E-5DF8-BBEA-1A635AEC525F', '916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DiscordExecutionModule', 0, 'server/core/discord_execution_module.py');
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_component_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('97BDF0F6-5672-5C2B-8596-293666985C78', '331B196C-6A32-5F81-A76F-0F75981AA4F5', '824195E5-DF9A-5475-AB7E-A3C543E2C23D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'OrganizationsOperationsModule', 0, 'server/core/organizations_operations_module.py');
INSERT INTO [etg].[contracts_modules] ([key_guid], [ref_component_guid], [ref_role_enum_guid], [ref_package_guid], [pub_name], [pub_is_abstract], [pub_notes]) VALUES ('22B34BE5-1A8D-545C-928B-AF596445B818', '331B196C-6A32-5F81-A76F-0F75981AA4F5', '916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'OrganizationsExecutionModule', 0, 'server/core/organizations_execution_module.py');
DELETE FROM [etg].[contracts_modules_functions] WHERE [ref_module_guid] IN ('59A2E2FF-3B0D-5BB5-B613-B8E9D1D88EA3', 'ABB88DBC-17E6-5538-B5BC-F29B7721B905');
DELETE FROM [etg].[contracts_modules_dependencies] WHERE [ref_module_guid] IN ('59A2E2FF-3B0D-5BB5-B613-B8E9D1D88EA3', 'ABB88DBC-17E6-5538-B5BC-F29B7721B905') OR [ref_dependency_guid] IN ('59A2E2FF-3B0D-5BB5-B613-B8E9D1D88EA3', 'ABB88DBC-17E6-5538-B5BC-F29B7721B905');
DELETE FROM [etg].[contracts_modules] WHERE [key_guid] IN ('59A2E2FF-3B0D-5BB5-B613-B8E9D1D88EA3', 'ABB88DBC-17E6-5538-B5BC-F29B7721B905');
-- The module models the code no longer has (populate refuses a model field it finds parked; Aaron's populate 2026-11-11):
-- discord_guild_row.pub_credits (the row model lost the column) and the two input models of the retired guild registry
-- provider's upsert and mark_left, fields first, then the models.
DELETE FROM [etg].[contracts_modules_models_fields] WHERE [key_guid] IN ('B01F3EE5-1801-5C38-B92F-B68A785FEAB4', 'AEE3D08C-7E4F-5365-9B11-6BF9C5FB97F5', '94C6B2A3-06C6-5C0E-844F-692FCDB5A383', '699A5966-2663-5B9F-B46E-A7988034BC77', 'C0BD268F-B10E-59CF-8212-4B3AB8178AB8');
DELETE FROM [etg].[contracts_modules_models] WHERE [key_guid] IN ('2EFD0A76-7477-5CB0-92D4-DD751AD1611D', '0E4FB112-F071-5624-8410-776B8B86C404');
GO

-- =====================================================================
-- Batch 10: Discord channel management (Aaron 2026-11-03: the Discord component manages Discord interactions; guilds and
-- channels are its two main items; it knows its own configuration). system_discord_channels: a channel belongs to
-- exactly one of a guild or an account user (ref_guild_guid / ref_user_guid, CK_sdc_owner), keeps the Discord owner's
-- snowflake (pub_owner_id, retained for billing), the channel snowflake, name, type, whether the application may send
-- to it and whether it monitors it for input, when it was seen and removed. The debug output channel stays in the
-- environment and does not conflict with these rows. Ops under db:discord:channels (upsert, read_all, mark_removed,
-- set_use) with the subdomain and its entitlement; the discord domain already carries ROLE_DISCORD_ADMIN. The last
-- change of 0.2.2.
-- =====================================================================
CREATE TABLE [dbo].[system_discord_channels] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_guild_guid] UNIQUEIDENTIFIER NULL,
  [ref_user_guid] UNIQUEIDENTIFIER NULL,
  [pub_channel_id] BIGINT NOT NULL,
  [pub_owner_id] BIGINT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_type] NVARCHAR(32) NOT NULL,
  [pub_is_send] BIT DEFAULT (0) NOT NULL,
  [pub_is_monitor] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [pub_seen_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_removed_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [PK_system_discord_channels] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [UQ_sdc_channel_id] UNIQUE NONCLUSTERED ([pub_channel_id]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_guild] FOREIGN KEY ([ref_guild_guid]) REFERENCES [dbo].[system_discord_guilds] ([key_guid]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [CK_sdc_owner] CHECK (([ref_guild_guid] IS NOT NULL AND [ref_user_guid] IS NULL) OR ([ref_guild_guid] IS NULL AND [ref_user_guid] IS NOT NULL));
CREATE NONCLUSTERED INDEX [IX_sdc_guild] ON [dbo].[system_discord_channels] ([ref_guild_guid]);
CREATE NONCLUSTERED INDEX [IX_sdc_user] ON [dbo].[system_discord_channels] ([ref_user_guid]);
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('582425D2-1CDA-5857-9C11-673BF50A5431', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'channels', NULL);
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('BC8C5104-51A2-5C1D-9B9E-ACF09DB78B6B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_CHANNELS', N'Channels', N'Grants the channels subdomain.');
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('BEFC8B0E-53E1-5080-8DB7-7E069267C32D', '582425D2-1CDA-5857-9C11-673BF50A5431', 'BC8C5104-51A2-5C1D-9B9E-ACF09DB78B6B', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_channels_upsert_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C696ADA7-71C9-5FAD-859C-CDB02EB41197', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('12744321-7675-5977-8F4C-BC6FABF5AAC6', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('62FB48B7-78A1-553E-8245-B95C04DF9A2D', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_guild_guid', 3, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5408BE7A-2ED7-5BFD-BBF7-DB92AF4E9FDB', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 4, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D6BD9018-A58C-5E31-9F49-2FA599460AFF', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_channel_id', 5, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EE37316D-A42B-5D8C-98B3-E00062F68918', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_owner_id', 6, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8612BAB7-5CFB-5AA3-A332-A60CDA306C25', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 7, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('05FD9251-9CD7-5CDC-A858-201DF9E21E73', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_type', 8, 0, NULL, 32, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('FD78B481-703C-50D8-835D-3F4D680DD820', '6BF728D6-134F-5CFE-8259-8C979828765D', '91990891-D593-5A1E-9CD4-EFDFB03A319F', '582425D2-1CDA-5857-9C11-673BF50A5431', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'upsert', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('3E2F3541-68BD-58E6-B43A-9BA7C0A5F44E', 'FD78B481-703C-50D8-835D-3F4D680DD820', '689FA2F0-CC01-5240-8B2E-91C7B2EF98EF', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'MERGE [dbo].[system_discord_channels] WITH (HOLDLOCK) AS [sdc] USING (SELECT CAST(? AS UNIQUEIDENTIFIER) AS [key_guid], CAST(? AS UNIQUEIDENTIFIER) AS [ref_package_guid], CAST(? AS UNIQUEIDENTIFIER) AS [ref_guild_guid], CAST(? AS UNIQUEIDENTIFIER) AS [ref_user_guid], CAST(? AS BIGINT) AS [pub_channel_id], CAST(? AS BIGINT) AS [pub_owner_id], CAST(? AS NVARCHAR(256)) AS [pub_name], CAST(? AS NVARCHAR(32)) AS [pub_type]) AS [src] ON [sdc].[pub_channel_id] = [src].[pub_channel_id] WHEN MATCHED THEN UPDATE SET [sdc].[ref_guild_guid] = [src].[ref_guild_guid], [sdc].[ref_user_guid] = [src].[ref_user_guid], [sdc].[pub_owner_id] = [src].[pub_owner_id], [sdc].[pub_name] = [src].[pub_name], [sdc].[pub_type] = [src].[pub_type], [sdc].[pub_seen_on] = SYSDATETIMEOFFSET(), [sdc].[pub_removed_on] = NULL, [sdc].[priv_modified_on] = SYSDATETIMEOFFSET() WHEN NOT MATCHED THEN INSERT ([key_guid], [ref_package_guid], [ref_guild_guid], [ref_user_guid], [pub_channel_id], [pub_owner_id], [pub_name], [pub_type], [pub_seen_on]) VALUES ([src].[key_guid], [src].[ref_package_guid], [src].[ref_guild_guid], [src].[ref_user_guid], [src].[pub_channel_id], [src].[pub_owner_id], [src].[pub_name], [src].[pub_type], SYSDATETIMEOFFSET());', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_channels_read_all_output', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5F587561-7553-5473-A8BE-061F4DD2A6FE', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0BE27770-7CED-5485-9918-930C5D3D0F93', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5D2DAA9D-D283-5E58-90C8-12AF3A119014', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_guild_guid', 3, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0F731A89-32BB-5B44-82E6-A2F93527EE71', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 4, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('AE41E624-3B6E-538F-8C94-669A27EE9DAF', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_channel_id', 5, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FEAA8D18-FEB2-5EDB-AE85-E7E527CA28CA', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_owner_id', 6, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A7FB5FF1-ACAA-5DFE-A185-5D0C33B12A54', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_name', 7, 0, NULL, 256, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8BF350FA-FCAA-50F2-AE1F-A32E4977B767', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_type', 8, 0, NULL, 32, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D7379C17-C4E0-5913-88E4-89738EF1360E', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_send', 9, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('666F64E1-C939-5A4E-8749-087CA0342D32', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_monitor', 10, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E2650F3F-CC92-508E-B5A6-3E2EEAFFB258', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_notes', 11, 1, NULL, 512, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('846EABB9-C8A8-5299-81E3-5B720E40DF4C', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_seen_on', 12, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4085D696-647C-5980-93CD-2A0AD09D4279', '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_removed_on', 13, 1, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('EA56AFD7-8D30-5701-9303-495C1833D7EE', '6BF728D6-134F-5CFE-8259-8C979828765D', '91990891-D593-5A1E-9CD4-EFDFB03A319F', '582425D2-1CDA-5857-9C11-673BF50A5431', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('F68139FE-13CC-5C6C-B4A8-B344A1E2B2F5', 'EA56AFD7-8D30-5701-9303-495C1833D7EE', NULL, '986E37FE-3421-5065-ACC5-FFCE3AD8D7D5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [sdc].[key_guid], [sdc].[ref_package_guid], [sdc].[ref_guild_guid], [sdc].[ref_user_guid], [sdc].[pub_channel_id], [sdc].[pub_owner_id], [sdc].[pub_name], [sdc].[pub_type], [sdc].[pub_is_send], [sdc].[pub_is_monitor], [sdc].[pub_notes], [sdc].[pub_seen_on], [sdc].[pub_removed_on] FROM [dbo].[system_discord_channels] AS [sdc] ORDER BY [sdc].[ref_guild_guid], [sdc].[ref_user_guid], [sdc].[pub_channel_id] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('9B65D11D-F98D-5F9E-BAF0-DF6E53E04D64', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_channels_mark_removed_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E7C56DD9-51E7-5132-B74E-14B89C0AC357', '9B65D11D-F98D-5F9E-BAF0-DF6E53E04D64', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_channel_id', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('662797E5-4A3D-5E35-AD11-FBC5951EF390', '6BF728D6-134F-5CFE-8259-8C979828765D', '91990891-D593-5A1E-9CD4-EFDFB03A319F', '582425D2-1CDA-5857-9C11-673BF50A5431', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'mark_removed', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('D34322A5-CF5E-5070-9B2B-A5DEEC017177', '662797E5-4A3D-5E35-AD11-FBC5951EF390', '9B65D11D-F98D-5F9E-BAF0-DF6E53E04D64', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sdc] SET [sdc].[pub_removed_on] = SYSDATETIMEOFFSET(), [sdc].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_discord_channels] AS [sdc] WHERE [sdc].[pub_channel_id] = ? AND [sdc].[pub_removed_on] IS NULL', NULL, NULL, 0, NULL);
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('669BAEB9-0C84-514F-AFB3-F9E160B57F48', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'discord_channels_set_use_input', NULL);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9584C0B4-EBA8-5BEF-B692-16F242C908BA', '669BAEB9-0C84-514F-AFB3-F9E160B57F48', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_send', 1, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9D965786-3E2E-5A95-99A9-14F89B3F3F26', '669BAEB9-0C84-514F-AFB3-F9E160B57F48', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_monitor', 2, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5C2BD09A-B86F-5D24-9789-EE87A2C696B2', '669BAEB9-0C84-514F-AFB3-F9E160B57F48', '045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_channel_id', 3, 0, NULL, NULL, 0);
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('6222FF05-25DF-542B-8591-420904205650', '6BF728D6-134F-5CFE-8259-8C979828765D', '91990891-D593-5A1E-9CD4-EFDFB03A319F', '582425D2-1CDA-5857-9C11-673BF50A5431', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'set_use', 1, NULL);
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('735A9A62-04E3-5182-85E4-8C2977C3F387', '6222FF05-25DF-542B-8591-420904205650', '669BAEB9-0C84-514F-AFB3-F9E160B57F48', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sdc] SET [sdc].[pub_is_send] = ?, [sdc].[pub_is_monitor] = ?, [sdc].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_discord_channels] AS [sdc] WHERE [sdc].[pub_channel_id] = ?', NULL, NULL, 0, NULL);
GO

-- =====================================================================
-- Version: the database is now at kernel 0.2.2; the three package manifest rows roll with it
-- =====================================================================
UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.2.2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.2.2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.2.2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F1954052-001D-5818-90DC-1953ADA7ABA1';
UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.2.2', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '3051B31E-E885-52A0-A68A-2643EF82A8EC';
GO

-- =====================================================================
-- Addendum: extra values that failed populate
-- =====================================================================
DELETE FROM [etg].[contracts_modules_models_fields] WHERE [key_guid] IN ('B01F3EE5-1801-5C38-B92F-B68A785FEAB4', 'AEE3D08C-7E4F-5365-9B11-6BF9C5FB97F5', '94C6B2A3-06C6-5C0E-844F-692FCDB5A383', '699A5966-2663-5B9F-B46E-A7988034BC77', 'C0BD268F-B10E-59CF-8212-4B3AB8178AB8');
DELETE FROM [etg].[contracts_modules_models] WHERE [key_guid] IN ('2EFD0A76-7477-5CB0-92D4-DD751AD1611D', '0E4FB112-F071-5624-8410-776B8B86C404');
GO

-- =====================================================================
-- Addendum: package attachment that failed the clean install (Aaron 2026-11-11: "obviously attach them. kernel and
-- core"). A row ships only in the package that owns it, and only from a table in the export set. The first wipe and
-- reinstall since 0.2.1 refused the kernel package on FK_cm_component, with FK_cuf_domain and FK_ssco_host behind it.
--   Export set: the four design tables this version creates, and service_hosts, join dbo.service_package_tables.
--   Components: the six that carried no package take the package their modules live in (four kernel, two core); a
--   component dependency row takes its component's package.
--   Security: validation is kernel (contexts, denials), management is core (roles, role groups, entitlements). The
--   one domain row both sit under is a shared vocabulary word; kernel installs first, so kernel owns it. Nothing moves.
--   Setup context: its host was "the first registered host", which no fresh database has. It now points at a static
--   host row keyed service_hosts:setup, kernel-owned, STOPPED so the stale sweep never touches it. Running hosts
--   register without a package and never export.
-- Every statement is safe to run again.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '7A967E40-00F3-5FAC-8BE6-215A6EC82EF6')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('7A967E40-00F3-5FAC-8BE6-215A6EC82EF6', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_components', 'etg', 'cc', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'A669200B-9FFD-5C5D-AA45-A250F858BD5F')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('A669200B-9FFD-5C5D-AA45-A250F858BD5F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_components_dependencies', 'etg', 'ccd', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '92233D29-27F6-5726-80A4-B2917A6E2A8B')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('92233D29-27F6-5726-80A4-B2917A6E2A8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_entrypoints', 'etg', 'ce', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'F844AF83-F3B8-5418-ABE9-635E912D0011')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('F844AF83-F3B8-5418-ABE9-635E912D0011', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'service_package_dependencies', 'dbo', 'spd', 0);
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '336CE50F-FA7D-5C8B-9852-86BE87C4B357')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('336CE50F-FA7D-5C8B-9852-86BE87C4B357', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '7A967E40-00F3-5FAC-8BE6-215A6EC82EF6');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '507F53EB-97BF-52AC-BAE4-8A5EB792DE5A')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('507F53EB-97BF-52AC-BAE4-8A5EB792DE5A', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'A669200B-9FFD-5C5D-AA45-A250F858BD5F');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '5300D989-6797-5146-865E-3E3F6441D359')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('5300D989-6797-5146-865E-3E3F6441D359', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '92233D29-27F6-5726-80A4-B2917A6E2A8B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '0850AD46-9AEB-5D23-900F-38F89B6AC598')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('0850AD46-9AEB-5D23-900F-38F89B6AC598', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'F844AF83-F3B8-5418-ABE9-635E912D0011');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '587B669C-7881-5BAF-8CD6-3AEE45CC8298')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('587B669C-7881-5BAF-8CD6-3AEE45CC8298', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '4E76CA07-D493-5E99-BFF9-9379567B1D50');
UPDATE [etg].[contracts_components] SET [ref_package_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] IN ('8FF9790D-C07C-53DF-8E6F-899A2B47BAD7', '3392526D-7E72-539C-9F08-71AE7CF1E793', 'B7E21FBA-58D3-584B-BF10-364C6D9489F1', '39B84C02-2743-5428-AC6F-5760E3703D21');
UPDATE [etg].[contracts_components] SET [ref_package_guid] = 'F1954052-001D-5818-90DC-1953ADA7ABA1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] IN ('2A3731A6-4226-5336-BC2B-E2DA49C5D8CC', '565F8BD3-013D-5435-AD45-7E7E307A038B');
UPDATE [ccd] SET [ccd].[ref_package_guid] = [cc].[ref_package_guid], [ccd].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [etg].[contracts_components_dependencies] AS [ccd] INNER JOIN [etg].[contracts_components] AS [cc] ON [cc].[key_guid] = [ccd].[ref_component_guid] WHERE [ccd].[ref_package_guid] IS NULL;
UPDATE [etg].[contracts_urn_domains] SET [ref_package_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC';
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_hosts] WHERE [key_guid] = '2D6B3590-107C-5D7D-B117-CDEA49298DA2')
INSERT INTO [dbo].[service_hosts] ([key_guid], [ref_package_guid], [ref_status_enum_guid], [pub_host_name], [pub_pid], [pub_kernel_version]) VALUES ('2D6B3590-107C-5D7D-B117-CDEA49298DA2', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', '838A88E7-41D2-595B-9EEE-B411AC91B897', 'setup', 0, '0.2.2');
UPDATE [dbo].[system_security_contexts] SET [ref_host_guid] = '2D6B3590-107C-5D7D-B117-CDEA49298DA2', [pub_notes] = N'The setup context: the root under which the installer and the migrations grant. Actor and principal are the service account; the host is the setup host row (service_hosts:setup), not a running process.', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59';
