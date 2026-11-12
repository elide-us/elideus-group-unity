-- v0.2.1_kernel.sql: the 0.2.0 -> 0.2.1 gap. Idempotent: every statement is guarded, every row by key.
-- Aaron 2026-10-29: "Domains, Subdomains and Namespaces should be unique constrained" and "It is the SAME SECURITY". The
-- 0.2.0 chain keyed a domain per namespace and a subdomain per domain, which seeded three duplicate domain rows (discord,
-- service, system: one under db, one under urn) and put the role gate on only one of each pair. This version makes the three
-- vocabularies UNIQUE on name and moves the composition onto the function row: contracts_urn_functions names its namespace,
-- domain and subdomain by key plus its own name and version, unique on the five together; that row IS the URN.
-- Method (Aaron 2026-10-13, declared column order = physical order): the three tables are REBUILT through _MIGRATION copies.
-- Batch 1 (while contracts_urn_domains still has ref_namespace_guid): drop the inbound FKs from the surviving tables, copy
-- domains, subdomains and functions to _MIGRATION, drop them, create the new shapes. Batch 2 (while the copies exist):
-- constraints, the 13 domain and 11 subdomain rows under their new keys ('contracts_urn_domains:<domain>',
-- 'contracts_urn_subdomains:<subdomain>'), the 54 function rows copied back with namespace, domain and subdomain resolved
-- BY NAME through the copies (function keys unchanged, so contracts_db_operations needs nothing), the 10 domain-role rows
-- re-keyed onto the merged domains, the inbound FKs back, the copies dropped. The ownership of a shared term is kernel if
-- any kernel op uses it, else core. A failure rolls its batch back and a re-run resumes; the version tail refuses while a
-- copy exists or a count is short.
-- Aaron 2026-10-29, later the same morning: the NAMESPACE layer has no security; its whole job is to answer whether the op
-- string's namespace term is registered. So dbo.service_security_namespaces and etg.contracts_urn_namespace_namespaces
-- (created by 0.2.0) are DROPPED here, with their declaration and export rows.
-- Declarations populate may have written on 0.2.0 for the dropped tables, columns and constraints are removed (populate
-- never deletes); the new columns and constraints are populate's to declare on 0.2.1.
-- Grants (Aaron 2026-10-29, under FAILURE IS THE DEFAULT: a term with no grant authorizes nobody): the catalogue row
-- ROLE_SERVICE_AUTOMATION (the workflow runner's role); contracts, workflow and security, the three domains only db ops use, carry
-- ROLE_SYSTEM_ADMIN and ROLE_SERVICE_AUTOMATION (any-of); ownership by the rule (contracts kernel, workflow and security core); the other 10 domains already carry their
-- role; one entitlement per subdomain, ENTITLEMENT_<TERM>, added to the catalogue and mapped. Nothing evaluates any of
-- this until the security slice.
-- The Python code shipped in this release carries DATABASE_VERSION 0.2.1; the kernel lookup already composes the URN from
-- the function row's three keys. APPLY WITH THE APPLICATION STOPPED, then boot, then populate.
-- Aaron 2026-11-01, the security context (page https://claude.ai/artifact/1yD5ufV8WZpyB2Vx6eg9kY, the 2026-10-30 rulings):
-- batches 5 to 9 add the enums (account_kind, security_channel, security_layer, denial_reason, audit_kind), the seven tables
-- (system_users, system_user_roles, system_user_entitlements, system_security_contexts, system_security_denials,
-- service_audit_tables, system_audit_transactions), the context columns on the workflow and sequence tables, the three
-- accounts and the setup context by formula, ROLE_SYSTEM_AUTOMATION and ROLE_GLOBAL_ADMIN (the group of every role), the
-- audit db domain and seven subdomains with their grants, and the 19 operations with their models. The columns added to
-- existing tables are NULL until the ops and callers carry them (tracked); ref_actor_guid on the definitions is NOT NULL.
-- Needs one registered host (boot once before the batches run). After applying: boot, populate, make installer, make
-- package kernel / core / setup. The version tail now THROWS naming the first guard that failed instead of skipping.
-- Batch 10 (Aaron 2026-11-01, after batch 8 was applied): users, user_roles and user_entitlements are the ACCOUNT domain,
-- not security; the eight functions, their models and operations move by re-key. Batch 8 stays as applied.
-- Batch 11 (Aaron 2026-11-01): pub_email NVARCHAR(256) NULL appended to system_users; the two account:users operations and
-- their models carry it.
-- Moves the database version to 0.2.1.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Batch 1: copies, drop, new shapes
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_urn_domains]', N'ref_namespace_guid') IS NOT NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cdo_function')
      ALTER TABLE [etg].[contracts_db_operations] DROP CONSTRAINT [FK_cdo_function];
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuse_subdomain')
      ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] DROP CONSTRAINT [FK_cuse_subdomain];
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cudr_domain')
      ALTER TABLE [etg].[contracts_urn_domain_roles] DROP CONSTRAINT [FK_cudr_domain];
    IF OBJECT_ID(N'[etg].[contracts_urn_functions_MIGRATION]', N'U') IS NOT NULL DROP TABLE [etg].[contracts_urn_functions_MIGRATION];
    IF OBJECT_ID(N'[etg].[contracts_urn_subdomains_MIGRATION]', N'U') IS NOT NULL DROP TABLE [etg].[contracts_urn_subdomains_MIGRATION];
    IF OBJECT_ID(N'[etg].[contracts_urn_domains_MIGRATION]', N'U') IS NOT NULL DROP TABLE [etg].[contracts_urn_domains_MIGRATION];
    SELECT [cuf].* INTO [etg].[contracts_urn_functions_MIGRATION] FROM [etg].[contracts_urn_functions] AS [cuf];
    SELECT [cus].* INTO [etg].[contracts_urn_subdomains_MIGRATION] FROM [etg].[contracts_urn_subdomains] AS [cus];
    SELECT [cud].* INTO [etg].[contracts_urn_domains_MIGRATION] FROM [etg].[contracts_urn_domains] AS [cud];
    DROP TABLE [etg].[contracts_urn_functions];
    DROP TABLE [etg].[contracts_urn_subdomains];
    DROP TABLE [etg].[contracts_urn_domains];
    CREATE TABLE [etg].[contracts_urn_domains] (
      [key_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_module_guid] UNIQUEIDENTIFIER NULL,
      [ref_package_guid] UNIQUEIDENTIFIER NULL,
      [pub_name] NVARCHAR(64) NOT NULL,
      [pub_notes] NVARCHAR(512) NULL,
      [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
      [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
    );
    CREATE TABLE [etg].[contracts_urn_subdomains] (
      [key_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_module_guid] UNIQUEIDENTIFIER NULL,
      [ref_package_guid] UNIQUEIDENTIFIER NULL,
      [pub_name] NVARCHAR(64) NOT NULL,
      [pub_notes] NVARCHAR(512) NULL,
      [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
      [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
    );
    CREATE TABLE [etg].[contracts_urn_functions] (
      [key_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_namespace_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_domain_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_subdomain_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_module_function_guid] UNIQUEIDENTIFIER NULL,
      [ref_package_guid] UNIQUEIDENTIFIER NULL,
      [pub_name] NVARCHAR(128) NOT NULL,
      [pub_version] TINYINT DEFAULT (1) NOT NULL,
      [pub_notes] NVARCHAR(512) NULL,
      [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
      [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
    );
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Batch 2: constraints, vocabularies under their new keys, functions copied back, domain roles re-keyed, inbound FKs back
-- =====================================================================
IF OBJECT_ID(N'[etg].[contracts_urn_domains_MIGRATION]', N'U') IS NOT NULL
   AND COL_LENGTH(N'[etg].[contracts_urn_functions]', N'ref_namespace_guid') IS NOT NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [PK_contracts_urn_domains] PRIMARY KEY CLUSTERED ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [UQ_cud_name] UNIQUE NONCLUSTERED ([pub_name]);
    ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
    ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [PK_contracts_urn_subdomains] PRIMARY KEY CLUSTERED ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [UQ_cus_name] UNIQUE NONCLUSTERED ([pub_name]);
    ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [PK_contracts_urn_functions] PRIMARY KEY CLUSTERED ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [UQ_cuf_urn] UNIQUE NONCLUSTERED ([ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [pub_name], [pub_version]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_namespace] FOREIGN KEY ([ref_namespace_guid]) REFERENCES [etg].[contracts_urn_namespaces] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_module_function] FOREIGN KEY ([ref_module_function_guid]) REFERENCES [etg].[contracts_modules_functions] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
    -- the 13 domains
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B7675207-B214-5CC2-A1FB-0AC91A645BDA', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'contracts', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('91990891-D593-5A1E-9CD4-EFDFB03A319F', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'discord', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'security', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('2F752B35-1D0E-5F9B-9641-CC1159D5D619', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'service', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('511A28BB-3798-5B18-8AFF-F7916DEBB554', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'system', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('FE0E8FF5-47AD-529D-9E3A-5AFABA9A24AC', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'workflow', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('FF8225B7-74EA-59D8-9132-E3963296C238', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'public', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('4725EB69-AD48-5A62-AEDB-577DDE4705B9', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'users', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A1511BDB-CA1E-5DF8-9C48-3BF44997ADE4', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'storage', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5CD3724A-2FC4-5EC7-A012-269674FCB922', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'support', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D6664FBF-B802-5AC0-A885-FB8542FDF9FE', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'moderation', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'account', NULL);
    INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('0F448F57-BAD6-57FB-AA85-05C2A74077C0', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'finance', NULL);
    -- the 11 subdomains
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('F80CDB9A-D9D2-5970-9241-1302D49192E4', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'db', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('4ADD14BF-9FCF-5DC8-B978-D8763DCD00F5', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'modules', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('2D546528-7D1F-5E2B-A0D0-D5238B9AA66F', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'guilds', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('51B6D7C0-9086-53EC-B390-E73840052342', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'entitlements', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('59939B07-C0B5-5E39-9215-AA2F2CE16DE8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'role_groups', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('092F357E-8753-5AE3-87EA-9DF892121CFF', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'roles', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('91EC949A-17B8-5A87-81A0-42752E8527FB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'host', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('BBF9CEAF-1C22-548D-B83D-4796715ABDC2', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'sequence', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('81253A84-62C3-5ABE-B4FB-5575214FD743', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'definitions', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B0563073-9564-54D6-AB15-BF9407152B3E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'history', NULL);
    INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('67C75D33-4960-5D10-8BB4-720CFDE9071E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'queue', NULL);
    -- the functions, keys unchanged, namespace / domain / subdomain resolved by name through the 0.2.0 chain copies
    INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes], [priv_created_on], [priv_modified_on])
      SELECT [mf].[key_guid], [md].[ref_namespace_guid], [cud].[key_guid], [cus].[key_guid], [mf].[ref_module_function_guid], [mf].[ref_package_guid], [mf].[pub_name], [mf].[pub_version], [mf].[pub_notes], [mf].[priv_created_on], SYSDATETIMEOFFSET()
      FROM [etg].[contracts_urn_functions_MIGRATION] AS [mf]
      JOIN [etg].[contracts_urn_subdomains_MIGRATION] AS [ms] ON [ms].[key_guid] = [mf].[ref_subdomain_guid]
      JOIN [etg].[contracts_urn_domains_MIGRATION] AS [md] ON [md].[key_guid] = [ms].[ref_domain_guid]
      JOIN [etg].[contracts_urn_domains] AS [cud] ON [cud].[pub_name] = [md].[pub_name]
      JOIN [etg].[contracts_urn_subdomains] AS [cus] ON [cus].[pub_name] = [ms].[pub_name];
    IF (SELECT COUNT(*) FROM [etg].[contracts_urn_functions]) <> (SELECT COUNT(*) FROM [etg].[contracts_urn_functions_MIGRATION])
      THROW 50000, 'v0.2.1: a function row did not resolve to a merged domain or subdomain; the copies are in the _MIGRATION tables', 1;
    -- the domain roles: re-keyed from 'contracts_urn_domain_roles:urn:<domain>.<ROLE>' onto the merged domain
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '13AFA797-D5AA-557F-8566-7CE30251D44B', [ref_domain_guid] = 'FF8225B7-74EA-59D8-9132-E3963296C238', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '367A5156-7212-5981-A041-0E7854BC2693';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = 'D30F5781-F45B-5744-950F-591FF072FD8A', [ref_domain_guid] = '4725EB69-AD48-5A62-AEDB-577DDE4705B9', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E9826379-38B5-5FFB-B8C3-D026DB239BDF';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '51237CE0-9053-5486-AF1D-C01224F2EABD', [ref_domain_guid] = 'A1511BDB-CA1E-5DF8-9C48-3BF44997ADE4', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CEB06FE4-94C8-50ED-866F-B2C4869721BC';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '97891CC0-B447-5088-B13A-8E6DBC3A7EAC', [ref_domain_guid] = '5CD3724A-2FC4-5EC7-A012-269674FCB922', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '5227694F-29DB-5AB0-B078-CFF17EAAC656';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = 'FBC19B7C-A7C8-5558-972A-F97535824223', [ref_domain_guid] = 'D6664FBF-B802-5AC0-A885-FB8542FDF9FE', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6541C00B-2B80-548B-B45A-C85C8BF71DAF';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = 'ABDC8937-BF66-53B1-B6E8-AC181CCDEA99', [ref_domain_guid] = 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '37EAA200-D03F-5B96-94FF-F7BC362A504C';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = 'F0D91C29-C935-5CAF-8DF4-7623E5EAC4C1', [ref_domain_guid] = '511A28BB-3798-5B18-8AFF-F7916DEBB554', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'AAF72AAF-A4C3-559D-BC05-358E0C54B5F4';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '39945EC2-BC26-5B46-A264-58200854BF32', [ref_domain_guid] = '2F752B35-1D0E-5F9B-9641-CC1159D5D619', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '0BB604F5-B255-5BFF-A40C-705D129FC0D5';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '80E4219E-2FB2-5164-AA3A-8A02F8F2F05F', [ref_domain_guid] = '91990891-D593-5A1E-9CD4-EFDFB03A319F', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'DCDA70AB-1ADB-562B-B81A-AB62DCF37B83';
    UPDATE [etg].[contracts_urn_domain_roles] SET [key_guid] = '870CC0F3-D6B0-5408-A774-762197088A7D', [ref_domain_guid] = '0F448F57-BAD6-57FB-AA85-05C2A74077C0', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '496A6D4B-36E2-5504-92A9-596E4A8CE4A7';
    IF EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] AS [cudr] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] AS [cud] WHERE [cud].[key_guid] = [cudr].[ref_domain_guid]))
      THROW 50000, 'v0.2.1: a domain-role row points at no merged domain; the copies are in the _MIGRATION tables', 1;
    ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
    ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_function] FOREIGN KEY ([ref_function_guid]) REFERENCES [etg].[contracts_urn_functions] ([key_guid]);
    DROP TABLE [etg].[contracts_urn_functions_MIGRATION];
    DROP TABLE [etg].[contracts_urn_subdomains_MIGRATION];
    DROP TABLE [etg].[contracts_urn_domains_MIGRATION];
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Batch 3: grants. Keys 'service_security_roles:<NAME>', 'service_security_entitlements:<NAME>',
-- 'contracts_urn_domain_roles:<domain>.<ROLE>', 'contracts_urn_subdomain_entitlements:<subdomain>.<ENTITLEMENT>'; all
-- core-owned like the catalogues they bind.
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_urn_domains]', N'ref_namespace_guid') IS NULL
   AND OBJECT_ID(N'[etg].[contracts_urn_domains_MIGRATION]', N'U') IS NULL
BEGIN
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '64CDFFD3-70D2-5405-ACE9-C1572F4823E3')
  INSERT INTO [dbo].[service_security_roles] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ROLE_SERVICE_AUTOMATION', N'Service Automation', N'The service-tier automation that runs workflows. Held by the workflow runner account, never by a person.');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'C04A1FB2-5D6B-5DAD-9900-F7BF9E55CBD4')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('C04A1FB2-5D6B-5DAD-9900-F7BF9E55CBD4', 'B7675207-B214-5CC2-A1FB-0AC91A645BDA', '29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'D6483A0E-AF7A-56DD-9ABB-E7C63728D19E')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('D6483A0E-AF7A-56DD-9ABB-E7C63728D19E', 'FE0E8FF5-47AD-529D-9E3A-5AFABA9A24AC', '29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '8042738D-AE55-5C56-8164-DD1F96D0B71C')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('8042738D-AE55-5C56-8164-DD1F96D0B71C', 'B7675207-B214-5CC2-A1FB-0AC91A645BDA', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '281B0D44-4931-58FA-B590-4A53FDD9F6A9')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('281B0D44-4931-58FA-B590-4A53FDD9F6A9', 'FE0E8FF5-47AD-529D-9E3A-5AFABA9A24AC', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '8F2C1042-CC7C-50A0-A1A6-056D4473CBCE')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('8F2C1042-CC7C-50A0-A1A6-056D4473CBCE', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '1F9333B1-A72B-5754-86C7-1709C01BBC01')
  INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('1F9333B1-A72B-5754-86C7-1709C01BBC01', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '6D401DEE-C50E-54E8-B972-E8D19C0165FB')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('6D401DEE-C50E-54E8-B972-E8D19C0165FB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_DB', N'Database', N'Grants the db subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'FF4A7F04-274C-5BCB-BF81-3E3D37EB1738')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('FF4A7F04-274C-5BCB-BF81-3E3D37EB1738', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_MODULES', N'Modules', N'Grants the modules subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '74DF34AF-6CBC-5D5F-BFF4-292B6B01390A')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('74DF34AF-6CBC-5D5F-BFF4-292B6B01390A', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_GUILDS', N'Guilds', N'Grants the guilds subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '05E32FFB-0495-5FFF-A2EB-8822DE2ED3A7')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('05E32FFB-0495-5FFF-A2EB-8822DE2ED3A7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_ENTITLEMENTS', N'Entitlements', N'Grants the entitlements subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'A68CBD6F-33CA-5ED5-A57E-F634FB9A4464')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('A68CBD6F-33CA-5ED5-A57E-F634FB9A4464', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_ROLE_GROUPS', N'Role groups', N'Grants the role_groups subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '48A76EB1-D6C5-5830-818E-D6EC2F2762B4')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('48A76EB1-D6C5-5830-818E-D6EC2F2762B4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_ROLES', N'Roles', N'Grants the roles subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '35AF32ED-C080-5234-AC30-3FDF54658427')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('35AF32ED-C080-5234-AC30-3FDF54658427', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_HOST', N'Host', N'Grants the host subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'FFC4C81E-C602-544B-92B6-7FA00B239742')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('FFC4C81E-C602-544B-92B6-7FA00B239742', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_SEQUENCE', N'Sequence', N'Grants the sequence subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '57F94A66-8BC8-591C-9D9F-6653E07134F1')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('57F94A66-8BC8-591C-9D9F-6653E07134F1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_DEFINITIONS', N'Definitions', N'Grants the definitions subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '5AFFC00D-5186-5D8E-86DE-F8B733A88C0D')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('5AFFC00D-5186-5D8E-86DE-F8B733A88C0D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_HISTORY', N'History', N'Grants the history subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '80B8D0D9-028F-5E54-8EBB-2BF365FA8B80')
  INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('80B8D0D9-028F-5E54-8EBB-2BF365FA8B80', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_QUEUE', N'Queue', N'Grants the queue subdomain.');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '117DC5AD-5C7B-5643-BA3C-A67BC029FFE5')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('117DC5AD-5C7B-5643-BA3C-A67BC029FFE5', 'F80CDB9A-D9D2-5970-9241-1302D49192E4', '6D401DEE-C50E-54E8-B972-E8D19C0165FB', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '9482DAE9-52DE-5AF4-8A1D-D7139E1C6C05')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('9482DAE9-52DE-5AF4-8A1D-D7139E1C6C05', '4ADD14BF-9FCF-5DC8-B978-D8763DCD00F5', 'FF4A7F04-274C-5BCB-BF81-3E3D37EB1738', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'D83702A2-0A4B-5B01-86D6-8B0C6E4E886F')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('D83702A2-0A4B-5B01-86D6-8B0C6E4E886F', '2D546528-7D1F-5E2B-A0D0-D5238B9AA66F', '74DF34AF-6CBC-5D5F-BFF4-292B6B01390A', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '9188103A-0AC7-5117-9BDE-E04DAD4A440B')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('9188103A-0AC7-5117-9BDE-E04DAD4A440B', '51B6D7C0-9086-53EC-B390-E73840052342', '05E32FFB-0495-5FFF-A2EB-8822DE2ED3A7', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'A63A2E1F-4275-59D2-9963-656F6AC2F11A')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('A63A2E1F-4275-59D2-9963-656F6AC2F11A', '59939B07-C0B5-5E39-9215-AA2F2CE16DE8', 'A68CBD6F-33CA-5ED5-A57E-F634FB9A4464', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '00338FDA-8F3B-5165-8742-C4E4C4628388')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('00338FDA-8F3B-5165-8742-C4E4C4628388', '092F357E-8753-5AE3-87EA-9DF892121CFF', '48A76EB1-D6C5-5830-818E-D6EC2F2762B4', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'F0B307FC-98B0-5301-A53B-E2AE4691BB37')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('F0B307FC-98B0-5301-A53B-E2AE4691BB37', '91EC949A-17B8-5A87-81A0-42752E8527FB', '35AF32ED-C080-5234-AC30-3FDF54658427', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '2273FD50-426E-5BE9-A49C-7ED2634F0526')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('2273FD50-426E-5BE9-A49C-7ED2634F0526', 'BBF9CEAF-1C22-548D-B83D-4796715ABDC2', 'FFC4C81E-C602-544B-92B6-7FA00B239742', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'D840C279-0275-5749-8A38-1FEE799084B1')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('D840C279-0275-5749-8A38-1FEE799084B1', '81253A84-62C3-5ABE-B4FB-5575214FD743', '57F94A66-8BC8-591C-9D9F-6653E07134F1', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '2904C31B-5B0E-5012-88DF-D0AECA1D9969')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('2904C31B-5B0E-5012-88DF-D0AECA1D9969', 'B0563073-9564-54D6-AB15-BF9407152B3E', '5AFFC00D-5186-5D8E-86DE-F8B733A88C0D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
  IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '65EC448E-66DA-51E4-8D7A-E7B4F0CC9413')
  INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('65EC448E-66DA-51E4-8D7A-E7B4F0CC9413', '67C75D33-4960-5D10-8BB4-720CFDE9071E', '80B8D0D9-028F-5E54-8EBB-2BF365FA8B80', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
END
GO

-- =====================================================================
-- Batch 4: the namespace layer has no security. Drop the mapping table, then the catalogue, and their declaration and export rows.
-- =====================================================================
IF OBJECT_ID(N'[etg].[contracts_urn_namespace_namespaces]', N'U') IS NOT NULL
  DROP TABLE [etg].[contracts_urn_namespace_namespaces];
IF OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NOT NULL
  DROP TABLE [dbo].[service_security_namespaces];
GO

-- =====================================================================
-- Declarations: the two dropped tables (whatever populate wrote for them on 0.2.0, plus the rows 0.2.0 inserted itself) and
-- the dropped columns and constraints of the rebuilt tables. Populate never deletes. FK-safe order throughout.
-- Keys by populate's natural keys '<schema>.<table>[.<name>]'.
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_urn_domains]', N'ref_namespace_guid') IS NULL
   AND OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    -- the two dropped tables: every declaration row that is theirs or points at them (populate's keys), then the export rows and the table rows
    DELETE FROM [etg].[contracts_db_constraint_columns]
      WHERE [ref_constraint_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B') OR [ref_referenced_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'))
         OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'))
         OR [ref_referenced_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'));
    DELETE FROM [etg].[contracts_db_index_columns]
      WHERE [ref_index_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'))
         OR [ref_column_guid] IN (SELECT [key_guid] FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'));
    DELETE FROM [etg].[contracts_db_constraints] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B') OR [ref_referenced_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B');
    DELETE FROM [etg].[contracts_db_indexes] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B');
    DELETE FROM [etg].[contracts_db_columns] WHERE [ref_table_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B');
    DELETE FROM [dbo].[service_package_tables] WHERE [key_guid] IN ('8A5C7AFF-C67C-5AEA-8C89-78FE8345AD04', '74D232B0-7E25-5BE3-B7E3-DF58730DFB65');
    DELETE FROM [etg].[contracts_db_tables] WHERE [key_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B');
    -- the dropped columns and constraints of the rebuilt tables
    DELETE FROM [etg].[contracts_db_constraint_columns] WHERE [ref_constraint_guid] IN ('1D86BE09-BCFB-50A1-88D5-0264F0E70568', '9AC9C8EF-EF6E-5F0F-91A6-BBAEDC5CF42C', '5F325F9B-384B-5A02-A8DC-7BD0677F0327', 'B2F8F122-5069-5445-B624-92170FD311C2', '886C467D-657A-559D-B813-EB2804645402') OR [ref_column_guid] IN ('79BFA344-8DEA-5C78-8C38-E91929B1685A', '43471047-B335-5BC8-B605-EE0A6F926FA0') OR [ref_referenced_column_guid] IN ('79BFA344-8DEA-5C78-8C38-E91929B1685A', '43471047-B335-5BC8-B605-EE0A6F926FA0');
    DELETE FROM [etg].[contracts_db_constraints] WHERE [key_guid] IN ('1D86BE09-BCFB-50A1-88D5-0264F0E70568', '9AC9C8EF-EF6E-5F0F-91A6-BBAEDC5CF42C', '5F325F9B-384B-5A02-A8DC-7BD0677F0327', 'B2F8F122-5069-5445-B624-92170FD311C2', '886C467D-657A-559D-B813-EB2804645402');
    DELETE FROM [etg].[contracts_db_columns] WHERE [key_guid] IN ('79BFA344-8DEA-5C78-8C38-E91929B1685A', '43471047-B335-5BC8-B605-EE0A6F926FA0');
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Batch 5: the security context (Aaron 2026-11-01: "address these defects ... extend the existing 0.2.1 script").
-- Enums, the seven tables, their constraints and indexes, the columns added to the workflow and sequence tables.
-- Tables by the key_/ref_/pub_/priv_ convention in declared order; every FK NO ACTION except the package CASCADE.
-- Nothing optional on the new tables: actor, principal, channel, host, instance and seal are NOT NULL; the parent is
-- NULL only at the root. The columns ADDED to existing tables are NULL in this script: their ops and callers do not
-- carry them yet; the slice that does makes them NOT NULL (a tracked defect until then). ref_actor_guid on the
-- definitions is the exception: it is set here per definition and made NOT NULL.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '44EAB4BA-5937-5F90-8143-213C306AB08E')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'account_kind', N'What an account row is: INTERACTIVE (a person, first-seen by Auth), SYSTEM (application automation, sealed), SERVICE (infrastructure automation, unsealed), ANONYMOUS (the public grant: an account row, never a NULL).');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'C12C3474-7CC8-537F-8BD8-94F86B636D6A')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('C12C3474-7CC8-537F-8BD8-94F86B636D6A', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'INTERACTIVE', 1, N'A person; the only kind Auth will log in.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '66CAABF3-BA45-5417-BB15-BA59D16054FE')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('66CAABF3-BA45-5417-BB15-BA59D16054FE', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SYSTEM', 2, N'The system automation account: application work under seal.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '46BF744F-5E16-5A8A-B16A-7C7F8F9C7253')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('46BF744F-5E16-5A8A-B16A-7C7F8F9C7253', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SERVICE', 3, N'The service automation account: infrastructure work, unsealed.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ANONYMOUS', 4, N'The anonymous account: what a request with no identity runs as.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_channel', N'Where a unit of work entered the application: the channel provider that admitted it.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'B4D703DC-27CB-503E-A9B5-BD64FD3D67DB')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('B4D703DC-27CB-503E-A9B5-BD64FD3D67DB', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RPC', 1, N'The RPC gateway.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'AC70897E-0052-51E6-9581-C658E91E6E1D')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('AC70897E-0052-51E6-9581-C658E91E6E1D', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'MCP', 2, N'The MCP gateway.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '30C42C94-D7CA-5A8B-9231-97E28C4B4065')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('30C42C94-D7CA-5A8B-9231-97E28C4B4065', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DISCORD', 3, N'The Discord gateway.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '1423E34D-C5EF-5E09-9303-8C6EEE569D5D')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('1423E34D-C5EF-5E09-9303-8C6EEE569D5D', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'WORKFLOW', 4, N'A workflow run.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'C45DA709-B053-54A9-8933-6EE2504C5747')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('C45DA709-B053-54A9-8933-6EE2504C5747', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SCHEDULER', 5, N'A scheduled task.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SETUP', 6, N'Setup mode or an installer script.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'CCDA2282-BDC2-5A3C-8378-D0403FB9F05A')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('CCDA2282-BDC2-5A3C-8378-D0403FB9F05A', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'KERNEL', 7, N'The kernel bootstrap before core is up.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '718550F0-C6E9-5D96-B2B6-EC03C753E627')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_layer', N'Which of the three proofs a denial refused: IDENTITY (the claim), AUTHORIZATION (the operation), ACCESS (the transaction).');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'BE46F5F2-C245-56F8-AB6B-BC263D0DBAA6')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('BE46F5F2-C245-56F8-AB6B-BC263D0DBAA6', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'IDENTITY', 1, N'The gateway refused the claim.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'E0BB0DF2-D1F4-52FE-ACF1-F9C884252E64')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('E0BB0DF2-D1F4-52FE-ACF1-F9C884252E64', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'AUTHORIZATION', 2, N'RPC dispatch refused the operation.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '310E2BCC-4890-5FDD-B1E7-558E5372BF20')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('310E2BCC-4890-5FDD-B1E7-558E5372BF20', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ACCESS', 3, N'The data layer refused the transaction.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '19F0846A-4C48-5430-8449-2FAE34791294')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'denial_reason', N'Why a layer refused. One row per refusal in system_security_denials.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'B6E34B8A-DE76-5E18-9A8E-AB65A159C5B4')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('B6E34B8A-DE76-5E18-9A8E-AB65A159C5B4', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_IDENTITY', 1, N'No usable bearer: malformed, expired or unsigned.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'C69BDFCB-6AD5-568B-815C-BC06DB43B19B')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('C69BDFCB-6AD5-568B-815C-BC06DB43B19B', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNKNOWN_TERM', 2, N'A namespace, domain, subdomain or function term is not registered.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'DB9904DD-A011-5FD5-A6BC-E8518750B09A')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('DB9904DD-A011-5FD5-A6BC-E8518750B09A', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_GRANT', 3, N'The decoration holds no role or entitlement the term requires.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'E4F78513-0BF7-545F-A5E5-42BFB845893E')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('E4F78513-0BF7-545F-A5E5-42BFB845893E', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_CONTEXT', 4, N'A data request arrived with no security context.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '5F6E0F13-4804-594B-9F2C-F662F0BD68E3')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('5F6E0F13-4804-594B-9F2C-F662F0BD68E3', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'MALFORMED_OP', 5, N'The op string does not parse as a URN.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '9A534DC0-3083-55DF-A5A0-727EDEEAC090')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('9A534DC0-3083-55DF-A5A0-727EDEEAC090', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'REVOKED', 6, N'The grant or session was revoked.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'CA80FA79-BB9D-5FE9-A599-EE4617363A62')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('CA80FA79-BB9D-5FE9-A599-EE4617363A62', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DISABLED_ACCOUNT', 7, N'The account is disabled.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] = '064879DE-A840-5EF8-8939-E86A2CF8D69B')
INSERT INTO [etg].[contracts_primitives_enum_types] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_kind', N'Which change an audit tracking row records on a logged table.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'DCDC215E-188B-5C3D-BD66-6E3C8CE9BC4F')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('DCDC215E-188B-5C3D-BD66-6E3C8CE9BC4F', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'INSERT', 1, N'A record was created.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = '600C3293-DEA9-56B9-9D36-6C25E81510FC')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('600C3293-DEA9-56B9-9D36-6C25E81510FC', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UPDATE', 2, N'A record was changed.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_primitives_enums] WHERE [key_guid] = 'A8EC52A6-F222-519B-894C-843AAB11C909')
INSERT INTO [etg].[contracts_primitives_enums] ([key_guid], [ref_enum_type_guid], [ref_package_guid], [pub_name], [pub_value], [pub_notes]) VALUES ('A8EC52A6-F222-519B-894C-843AAB11C909', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DELETE', 3, N'A record was removed.');
GO

IF OBJECT_ID(N'[dbo].[system_users]', N'U') IS NULL
CREATE TABLE [dbo].[system_users] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_is_enabled] BIT DEFAULT (1) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_user_roles]', N'U') IS NULL
CREATE TABLE [dbo].[system_user_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_user_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_role_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_granted_context_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_revoked_context_guid] UNIQUEIDENTIFIER NULL,
  [pub_granted_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_revoked_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_user_entitlements]', N'U') IS NULL
CREATE TABLE [dbo].[system_user_entitlements] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_user_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_entitlement_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_granted_context_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_revoked_context_guid] UNIQUEIDENTIFIER NULL,
  [pub_granted_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_revoked_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_security_contexts]', N'U') IS NULL
CREATE TABLE [dbo].[system_security_contexts] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_actor_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_principal_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_parent_context_guid] UNIQUEIDENTIFIER NULL,
  [ref_channel_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_host_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_instance_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_sealed] BIT NOT NULL,
  [pub_issued_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_security_denials]', N'U') IS NULL
CREATE TABLE [dbo].[system_security_denials] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_context_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_layer_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_reason_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_host_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_subject] NVARCHAR(256) NOT NULL,
  [pub_occurred_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[service_audit_tables]', N'U') IS NULL
CREATE TABLE [dbo].[service_audit_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_log_insert] BIT DEFAULT (0) NOT NULL,
  [pub_log_update] BIT DEFAULT (0) NOT NULL,
  [pub_log_delete] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[dbo].[system_audit_transactions]', N'U') IS NULL
CREATE TABLE [dbo].[system_audit_transactions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_context_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_record_number] BIGINT NOT NULL,
  [pub_logged_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [pub_metadata] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF COL_LENGTH(N'[dbo].[service_workflow_definitions]', N'ref_actor_guid') IS NULL
ALTER TABLE [dbo].[service_workflow_definitions] ADD [ref_actor_guid] UNIQUEIDENTIFIER NULL;
IF COL_LENGTH(N'[dbo].[system_workflow_queue]', N'ref_principal_guid') IS NULL
ALTER TABLE [dbo].[system_workflow_queue] ADD [ref_principal_guid] UNIQUEIDENTIFIER NULL, [ref_context_guid] UNIQUEIDENTIFIER NULL;
IF COL_LENGTH(N'[dbo].[system_workflow_history]', N'ref_user_guid') IS NOT NULL AND COL_LENGTH(N'[dbo].[system_workflow_history]', N'ref_principal_guid') IS NULL
EXEC sp_rename N'[dbo].[system_workflow_history].[ref_user_guid]', N'ref_principal_guid', N'COLUMN';
IF COL_LENGTH(N'[dbo].[system_workflow_history]', N'ref_actor_guid') IS NULL
ALTER TABLE [dbo].[system_workflow_history] ADD [ref_actor_guid] UNIQUEIDENTIFIER NULL, [ref_context_guid] UNIQUEIDENTIFIER NULL;
IF COL_LENGTH(N'[dbo].[system_sequence_allocations]', N'ref_context_guid') IS NULL
ALTER TABLE [dbo].[system_sequence_allocations] ADD [ref_context_guid] UNIQUEIDENTIFIER NULL;
GO

-- =====================================================================
-- Batch 6: constraints and indexes on the seven tables and the added columns
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_users' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [PK_system_users] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_user_roles' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [PK_system_user_roles] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_user_entitlements' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [PK_system_user_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_security_contexts' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [PK_system_security_contexts] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_security_denials' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [PK_system_security_denials] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_audit_tables' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [PK_service_audit_tables] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_system_audit_transactions' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [PK_system_audit_transactions] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_sat_table' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [UQ_sat_table] UNIQUE NONCLUSTERED ([ref_table_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_su_package')
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [FK_su_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_su_kind')
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [FK_su_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sur_package')
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sur_user')
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sur_role')
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_role] FOREIGN KEY ([ref_role_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sur_granted_context')
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_granted_context] FOREIGN KEY ([ref_granted_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sur_revoked_context')
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_revoked_context] FOREIGN KEY ([ref_revoked_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sur_user_revoked' AND object_id = OBJECT_ID(N'[dbo].[system_user_roles]'))
CREATE NONCLUSTERED INDEX [IX_sur_user_revoked] ON [dbo].[system_user_roles] ([ref_user_guid], [pub_revoked_on]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sue_package')
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sue_user')
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sue_entitlement')
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_entitlement] FOREIGN KEY ([ref_entitlement_guid]) REFERENCES [dbo].[service_security_entitlements] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sue_granted_context')
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_granted_context] FOREIGN KEY ([ref_granted_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sue_revoked_context')
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_revoked_context] FOREIGN KEY ([ref_revoked_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sue_user_revoked' AND object_id = OBJECT_ID(N'[dbo].[system_user_entitlements]'))
CREATE NONCLUSTERED INDEX [IX_sue_user_revoked] ON [dbo].[system_user_entitlements] ([ref_user_guid], [pub_revoked_on]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_package')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_actor')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_principal')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_parent')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_parent] FOREIGN KEY ([ref_parent_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_channel')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_channel] FOREIGN KEY ([ref_channel_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssco_host')
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssco_actor_issued' AND object_id = OBJECT_ID(N'[dbo].[system_security_contexts]'))
CREATE NONCLUSTERED INDEX [IX_ssco_actor_issued] ON [dbo].[system_security_contexts] ([ref_actor_guid], [pub_issued_on]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssco_principal_issued' AND object_id = OBJECT_ID(N'[dbo].[system_security_contexts]'))
CREATE NONCLUSTERED INDEX [IX_ssco_principal_issued] ON [dbo].[system_security_contexts] ([ref_principal_guid], [pub_issued_on]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssco_parent_guid' AND object_id = OBJECT_ID(N'[dbo].[system_security_contexts]'))
CREATE NONCLUSTERED INDEX [IX_ssco_parent_guid] ON [dbo].[system_security_contexts] ([ref_parent_context_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssd_package')
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssd_context')
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssd_layer')
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_layer] FOREIGN KEY ([ref_layer_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssd_reason')
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_reason] FOREIGN KEY ([ref_reason_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssd_host')
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssd_context_guid' AND object_id = OBJECT_ID(N'[dbo].[system_security_denials]'))
CREATE NONCLUSTERED INDEX [IX_ssd_context_guid] ON [dbo].[system_security_denials] ([ref_context_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ssd_occurred' AND object_id = OBJECT_ID(N'[dbo].[system_security_denials]'))
CREATE NONCLUSTERED INDEX [IX_ssd_occurred] ON [dbo].[system_security_denials] ([pub_occurred_on]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sat_package')
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [FK_sat_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_sat_table')
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [FK_sat_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_satr_package')
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_satr_context')
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_satr_table')
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_satr_kind')
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_satr_table_record' AND object_id = OBJECT_ID(N'[dbo].[system_audit_transactions]'))
CREATE NONCLUSTERED INDEX [IX_satr_table_record] ON [dbo].[system_audit_transactions] ([ref_table_guid], [pub_record_number]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_satr_context_guid' AND object_id = OBJECT_ID(N'[dbo].[system_audit_transactions]'))
CREATE NONCLUSTERED INDEX [IX_satr_context_guid] ON [dbo].[system_audit_transactions] ([ref_context_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swq_principal')
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swq_context')
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swh_principal')
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swh_actor')
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swh_context')
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssa_context')
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
GO

-- =====================================================================
-- Batch 7: seed. The three accounts by formula (system_users:<name>), the two roles, ROLE_GLOBAL_ADMIN as the group
-- that contains every role, the SETUP context (system_security_contexts:setup; actor = principal = service; host = the
-- first registered host; instance by formula service_host_instances:setup) that grants the accounts their roles, the
-- definitions' actors. Automation is global (Aaron 2026-10-30): both automation accounts are members of global admin.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_hosts])
  THROW 50000, 'v0.2.1: no row in dbo.service_hosts; boot the application once before applying the security-context batches', 1;
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '24AEF840-A87E-5B32-81D9-26E8BFC1F482')
INSERT INTO [dbo].[service_security_roles] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('24AEF840-A87E-5B32-81D9-26E8BFC1F482', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ROLE_SYSTEM_AUTOMATION', N'System Automation', N'The application-tier automation: period close, guild sync, the Discord bot. Held by the system account, never by a person.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '0CC79EA9-C590-5A1E-9038-75D264F5BEDC')
INSERT INTO [dbo].[service_security_roles] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ROLE_GLOBAL_ADMIN', N'Global Admin', N'The group that contains every role. Held by both automation accounts: automation clears gates by membership, never by exemption. Bounded by the organization tenant.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '9FA3C02D-9E70-5C59-856E-9BC728AE0BFB')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('9FA3C02D-9E70-5C59-856E-9BC728AE0BFB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '66A58CFD-8786-5D78-B874-1016E50471E5');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'D4DC0603-9792-5F66-8E89-F3084E9006B4')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('D4DC0603-9792-5F66-8E89-F3084E9006B4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'E96BDA1F-8876-5D4E-B697-1926ECD628CE');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '5C9EC9C5-D291-52E8-A4BF-AD0BABDECF0C')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('5C9EC9C5-D291-52E8-A4BF-AD0BABDECF0C', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '5C607B13-539B-5586-AD39-31124298D0AF');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '74DAC815-ACEE-519A-A307-3414B499F7B4')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('74DAC815-ACEE-519A-A307-3414B499F7B4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'B5533CBF-596D-58FE-9B88-379A2D608E53');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '3A0CF896-F0E7-53D2-AD39-D7DBEC9D9CA0')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('3A0CF896-F0E7-53D2-AD39-D7DBEC9D9CA0', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '29B18BB9-998C-57B1-9A22-48B315CC266D');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'AF337479-1BBA-5030-A96C-C0D08B348F48')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('AF337479-1BBA-5030-A96C-C0D08B348F48', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '755D78AC-3CF7-574A-9BCB-4B3BBD4EDD38');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '95ADA811-5C7A-51B2-91CC-B62BF01773A4')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('95ADA811-5C7A-51B2-91CC-B62BF01773A4', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '89C75A3C-F893-5658-8CA4-6AB27D728BC1');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '5CF8D377-08B5-526F-AF9D-656BA6224EF2')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('5CF8D377-08B5-526F-AF9D-656BA6224EF2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'F3762DBF-5F50-524B-838F-70A957E92DF2');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '15E81E7F-CA55-5A46-8F96-0E8E92CBD25B')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('15E81E7F-CA55-5A46-8F96-0E8E92CBD25B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'D9ECA799-8D60-5436-9D59-817AB3E8CD62');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '94F1F81E-B134-58B1-A6B0-EBA5C3802D4F')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('94F1F81E-B134-58B1-A6B0-EBA5C3802D4F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '6F9583DD-2CEB-5F78-96FD-84A2B567B6D0');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '38A4C61C-2B8F-55DD-BEF2-28DBF05C86DA')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('38A4C61C-2B8F-55DD-BEF2-28DBF05C86DA', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '2DEAD089-E1E7-5F26-99C6-8E6CCE217C5B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '6B5F4C7B-DBCC-5A2F-8A7A-AF73A03E7957')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('6B5F4C7B-DBCC-5A2F-8A7A-AF73A03E7957', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '8697410A-F3F9-5A58-84BA-A2215EA54F60');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'E23D4C05-C692-5DC2-898E-A4AC08D19292')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('E23D4C05-C692-5DC2-898E-A4AC08D19292', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '4798B5AD-8A49-5FBA-B392-BC50420657A7');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'D66F613C-ADEA-5E4D-9F6E-D30FD403A845')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('D66F613C-ADEA-5E4D-9F6E-D30FD403A845', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'C43AB8E1-0130-543E-A53F-C380FF739426')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('C43AB8E1-0130-543E-A53F-C380FF739426', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'CC0F8FEF-2786-5A93-97F1-C81AB2CC781F');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = '90FD0B54-EE7D-52E5-A03D-447E39CD0759')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('90FD0B54-EE7D-52E5-A03D-447E39CD0759', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '9B548691-7D52-545A-A697-E0D789A64A94');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_role_groups] WHERE [key_guid] = 'BDE75BDD-27D3-5F2F-9F1E-B1785F844C31')
INSERT INTO [dbo].[service_security_role_groups] ([key_guid], [ref_package_guid], [ref_group_guid], [ref_member_guid]) VALUES ('BDE75BDD-27D3-5F2F-9F1E-B1785F844C31', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', '24AEF840-A87E-5B32-81D9-26E8BFC1F482');
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_users] WHERE [key_guid] = '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273')
INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled]) VALUES ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', '46BF744F-5E16-5A8A-B16A-7C7F8F9C7253', N'Service Automation', 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_users] WHERE [key_guid] = 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD')
INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled]) VALUES ('D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', '66CAABF3-BA45-5417-BB15-BA59D16054FE', N'System Automation', 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_users] WHERE [key_guid] = 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207')
INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled]) VALUES ('F9A4F9EA-743E-5E17-95F0-E0280D6DA207', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD', N'Anonymous', 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_security_contexts] WHERE [key_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59')
INSERT INTO [dbo].[system_security_contexts] ([key_guid], [ref_package_guid], [ref_actor_guid], [ref_principal_guid], [ref_parent_context_guid], [ref_channel_enum_guid], [ref_host_guid], [ref_instance_guid], [pub_sealed], [pub_issued_on], [pub_notes])
  SELECT TOP (1) 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', NULL, 'FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC', [sh].[key_guid], '61627C3F-5DBF-5245-AFD2-3424ED6C4018', 0, SYSDATETIMEOFFSET(), N'The setup context: the root under which the installer and the migrations grant. Actor and principal are the service account; the host is the first registered host.' FROM [dbo].[service_hosts] AS [sh] ORDER BY [sh].[priv_created_on];
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_user_roles] WHERE [key_guid] = '4ED16D35-1CB4-5F7C-B6E5-ADF4B7D00489')
INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES ('4ED16D35-1CB4-5F7C-B6E5-ADF4B7D00489', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_user_roles] WHERE [key_guid] = '87F1B9B6-F156-5CF4-BF4E-F61F5118D863')
INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES ('87F1B9B6-F156-5CF4-BF4E-F61F5118D863', 'F1954052-001D-5818-90DC-1953ADA7ABA1', '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_user_roles] WHERE [key_guid] = '8D3BF164-2352-5B62-B8DF-00ABA864E03E')
INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES ('8D3BF164-2352-5B62-B8DF-00ABA864E03E', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', '24AEF840-A87E-5B32-81D9-26E8BFC1F482', 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_user_roles] WHERE [key_guid] = 'C0224CE4-758B-53C1-BD4A-C1269A68F8DC')
INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES ('C0224CE4-758B-53C1-BD4A-C1269A68F8DC', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', '0CC79EA9-C590-5A1E-9038-75D264F5BEDC', 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', SYSDATETIMEOFFSET());
IF NOT EXISTS (SELECT 1 FROM [dbo].[system_user_roles] WHERE [key_guid] = '3D60B72F-DA89-5E92-88F8-691D6CBC1E04')
INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES ('3D60B72F-DA89-5E92-88F8-691D6CBC1E04', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207', '755D78AC-3CF7-574A-9BCB-4B3BBD4EDD38', 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59', SYSDATETIMEOFFSET());
UPDATE [dbo].[service_workflow_definitions] SET [ref_actor_guid] = '3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'CDA4B4A8-0A9F-55CC-B94A-E25E2F5298C6' AND [ref_actor_guid] IS NULL;
UPDATE [dbo].[service_workflow_definitions] SET [ref_actor_guid] = 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'E9D5A665-EFA4-5457-B897-F6D2F343467D' AND [ref_actor_guid] IS NULL;
IF EXISTS (SELECT 1 FROM [dbo].[service_workflow_definitions] WHERE [ref_actor_guid] IS NULL)
  THROW 50000, 'v0.2.1: a workflow definition has no actor; a definition with no actor cannot be declared', 1;
IF COLUMNPROPERTY(OBJECT_ID(N'[dbo].[service_workflow_definitions]'), N'ref_actor_guid', N'AllowsNull') = 1
ALTER TABLE [dbo].[service_workflow_definitions] ALTER COLUMN [ref_actor_guid] UNIQUEIDENTIFIER NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_swd_actor')
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
GO

-- =====================================================================
-- Batch 8: the URN rows and grants. One new db domain, audit (kernel-owned: its ops are the executor's), held by
-- ROLE_SERVICE_AUTOMATION and ROLE_SYSTEM_ADMIN (audit controls belong to service automation, Aaron 2026-10-30; the
-- system admin reads). Seven subdomains, one entitlement each. Then the functions, their models and the operations:
-- read functions exist as rows because an unnamed read is unreadable; no update or delete exists for contexts,
-- denials or audit transactions except the retention delete, which the audit domain gates.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'audit', N'The audit log: which tables are logged and the tracking rows. A control, held by service automation.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'ED0294D9-2710-5522-BA4A-CC70CE246803')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('ED0294D9-2710-5522-BA4A-CC70CE246803', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', '64CDFFD3-70D2-5405-ACE9-C1572F4823E3', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '65EB9286-E7D5-56A6-AE05-7B489BC60EBF')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('65EB9286-E7D5-56A6-AE05-7B489BC60EBF', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', '29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '53B61350-019B-57D7-8694-403E0F31623E')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('53B61350-019B-57D7-8694-403E0F31623E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'users', N'The account rows: who can act.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '191135F4-0921-5DC7-AAF6-2F86F9F10F2F')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('191135F4-0921-5DC7-AAF6-2F86F9F10F2F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_USERS', N'Users', N'Grants the users subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '2A55030B-72C0-596D-B692-B20BBFFEE764')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('2A55030B-72C0-596D-B692-B20BBFFEE764', '53B61350-019B-57D7-8694-403E0F31623E', '191135F4-0921-5DC7-AAF6-2F86F9F10F2F', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'user_roles', N'Temporal role grants: granted and revoked, never deleted.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'B740A6BD-A760-569A-8B01-2F8D3BF5AACD')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('B740A6BD-A760-569A-8B01-2F8D3BF5AACD', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_USER_ROLES', N'User roles', N'Grants the user_roles subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'F24B565A-4396-5466-963D-4F68CCADD8E4')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('F24B565A-4396-5466-963D-4F68CCADD8E4', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', 'B740A6BD-A760-569A-8B01-2F8D3BF5AACD', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'user_entitlements', N'Temporal entitlement grants: granted and revoked, never deleted.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'E71895C4-5DA9-516C-8093-B5B730E24A08')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('E71895C4-5DA9-516C-8093-B5B730E24A08', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_USER_ENTITLEMENTS', N'User entitlements', N'Grants the user_entitlements subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'E96EB3DF-7238-5259-B022-5CE58D5873D1')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('E96EB3DF-7238-5259-B022-5CE58D5873D1', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', 'E71895C4-5DA9-516C-8093-B5B730E24A08', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '8FE1005B-E985-59DD-B05E-CE4674533471')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('8FE1005B-E985-59DD-B05E-CE4674533471', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'contexts', N'The security context rows: one per unit of work, the recursive chain.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'F4A3F194-B8DF-56D8-8767-CAD74BEB8C32')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('F4A3F194-B8DF-56D8-8767-CAD74BEB8C32', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_CONTEXTS', N'Contexts', N'Grants the contexts subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = 'BFD3D2A9-EF7B-5BB2-B251-4F36250AB531')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('BFD3D2A9-EF7B-5BB2-B251-4F36250AB531', '8FE1005B-E985-59DD-B05E-CE4674533471', 'F4A3F194-B8DF-56D8-8767-CAD74BEB8C32', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '6883E979-EDC7-506A-9791-AD4A2C171DBB')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6883E979-EDC7-506A-9791-AD4A2C171DBB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'denials', N'One row per refusal, written by the layer that refused before it raised.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = 'AA108324-CAF7-5C99-873D-B969E6333E7B')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('AA108324-CAF7-5C99-873D-B969E6333E7B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_DENIALS', N'Denials', N'Grants the denials subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '6A1BBF05-806D-5359-A131-3E8643B93C33')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('6A1BBF05-806D-5359-A131-3E8643B93C33', '6883E979-EDC7-506A-9791-AD4A2C171DBB', 'AA108324-CAF7-5C99-873D-B969E6333E7B', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '5855ADF8-7C70-5784-96E4-D5CA800B2268')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5855ADF8-7C70-5784-96E4-D5CA800B2268', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'tables', N'Which sequence-bearing tables are logged, per change kind.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '1F6803FD-6E85-5F85-88D6-445F5E6DD076')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('1F6803FD-6E85-5F85-88D6-445F5E6DD076', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_TABLES', N'Tables', N'Grants the tables subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '6FF4FCCA-F393-54B5-AAA6-C9A426A0CA62')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('6FF4FCCA-F393-54B5-AAA6-C9A426A0CA62', '5855ADF8-7C70-5784-96E4-D5CA800B2268', '1F6803FD-6E85-5F85-88D6-445F5E6DD076', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'transactions', N'One tracking row per logged change: who made it and when, never the change.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_entitlements] WHERE [key_guid] = '12493754-C3BA-5507-939A-34BD04C8464A')
INSERT INTO [dbo].[service_security_entitlements] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('12493754-C3BA-5507-939A-34BD04C8464A', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'ENTITLEMENT_TRANSACTIONS', N'Transactions', N'Grants the transactions subdomain.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] WHERE [key_guid] = '9CC04E77-C5C5-5E5D-827B-42A3E1D7B7C6')
INSERT INTO [etg].[contracts_urn_subdomain_entitlements] ([key_guid], [ref_subdomain_guid], [ref_entitlement_guid], [ref_package_guid]) VALUES ('9CC04E77-C5C5-5E5D-827B-42A3E1D7B7C6', 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', '12493754-C3BA-5507-939A-34BD04C8464A', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'AADDD6B6-01B9-5BAB-8B28-2171DD992D08')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('AADDD6B6-01B9-5BAB-8B28-2171DD992D08', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '53B61350-019B-57D7-8694-403E0F31623E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'D37CD09D-5513-5539-8936-C734CE043733')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D37CD09D-5513-5539-8936-C734CE043733', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_users_read_all_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '9A341A79-EE53-5D4A-99D8-329F7493B85C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9A341A79-EE53-5D4A-99D8-329F7493B85C', 'D37CD09D-5513-5539-8936-C734CE043733', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '112E68A4-0AE7-5C99-A545-2A82AD228A5E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('112E68A4-0AE7-5C99-A545-2A82AD228A5E', 'D37CD09D-5513-5539-8936-C734CE043733', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '128D3370-A6F6-5AED-B0B0-77DDC29BAA95')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('128D3370-A6F6-5AED-B0B0-77DDC29BAA95', 'D37CD09D-5513-5539-8936-C734CE043733', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 3, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '23EDEE31-5C56-5A0C-9C12-ACF5795D30F7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('23EDEE31-5C56-5A0C-9C12-ACF5795D30F7', 'D37CD09D-5513-5539-8936-C734CE043733', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_enabled', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'B07BD6F5-AA3C-59A7-B084-AC6AC8D34264')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('B07BD6F5-AA3C-59A7-B084-AC6AC8D34264', 'AADDD6B6-01B9-5BAB-8B28-2171DD992D08', NULL, 'D37CD09D-5513-5539-8936-C734CE043733', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [su].[key_guid], [su].[ref_kind_enum_guid], [su].[pub_display], [su].[pub_is_enabled] FROM [dbo].[system_users] AS [su] ORDER BY [su].[pub_display] FOR JSON PATH', NULL, NULL, 1, N'Every account row: the three automation accounts and every person. The kernel reads it to name its own actor; Auth reads it to resolve a first-seen user.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '716BABC5-F63B-58EE-BD9A-FEA6430E2F31')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '53B61350-019B-57D7-8694-403E0F31623E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '363F12D1-C984-5A4D-B66B-BA102A3F1F93')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('363F12D1-C984-5A4D-B66B-BA102A3F1F93', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_users_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8753B4E9-E52F-5027-AAAE-C0CE4EAB2227')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8753B4E9-E52F-5027-AAAE-C0CE4EAB2227', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'FE127E60-ED00-5528-887C-7795C8A3F936')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FE127E60-ED00-5528-887C-7795C8A3F936', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D6C04077-4DEA-5892-932B-36872CE0B00E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D6C04077-4DEA-5892-932B-36872CE0B00E', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4A72C153-C1D1-5B7F-BD86-C16D1C8D7148')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4A72C153-C1D1-5B7F-BD86-C16D1C8D7148', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 4, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'FCB18EFA-3F41-556A-ABF4-DCD14AF6EDAF')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FCB18EFA-3F41-556A-ABF4-DCD14AF6EDAF', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_enabled', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'FEC4359D-4B9F-52FE-A055-54023F4185F5')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('FEC4359D-4B9F-52FE-A055-54023F4185F5', '716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled]) VALUES (?, ?, ?, ?, ?)', NULL, NULL, 0, N'Create one account row. Interactive accounts are minted by Users at first-seen (NEWID); the automation accounts are seeded by formula and never created here.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '55796AF7-347D-574E-886A-0278B09C6541')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('55796AF7-347D-574E-886A-0278B09C6541', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_active', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '49E5078D-5279-5D09-BD6C-5B86629416B6')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('49E5078D-5279-5D09-BD6C-5B86629416B6', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_roles_read_active_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'CED1EAF0-3C13-517F-88D5-8746F30CB995')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('CED1EAF0-3C13-517F-88D5-8746F30CB995', '49E5078D-5279-5D09-BD6C-5B86629416B6', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_roles_read_active_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EC02CC04-A338-506E-9142-8AE3E8CA0B69')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EC02CC04-A338-506E-9142-8AE3E8CA0B69', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B2AD8D6C-B7A2-557A-9ABC-5AEA6BF5915C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B2AD8D6C-B7A2-557A-9ABC-5AEA6BF5915C', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_role_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5119267C-8299-5B16-969C-BCDFB2C0A27F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5119267C-8299-5B16-969C-BCDFB2C0A27F', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_granted_on', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'D031F61F-7E34-5C7A-9A8A-D326C28BFE65')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('D031F61F-7E34-5C7A-9A8A-D326C28BFE65', '55796AF7-347D-574E-886A-0278B09C6541', '49E5078D-5279-5D09-BD6C-5B86629416B6', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [sur].[key_guid], [sur].[ref_role_guid], [sur].[pub_granted_on] FROM [dbo].[system_user_roles] AS [sur] WHERE [sur].[ref_user_guid] = ? AND [sur].[pub_revoked_on] IS NULL FOR JSON PATH', NULL, NULL, 1, N'The roles one account holds right now: the rows not yet revoked. The decoration of a unit of work is resolved from this once, at its start.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '4CE0362E-F0B2-5A3A-B548-F4A61B58654C')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('4CE0362E-F0B2-5A3A-B548-F4A61B58654C', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'grant', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'DD8743C8-7C95-522D-AEB7-D04D1A347D76')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('DD8743C8-7C95-522D-AEB7-D04D1A347D76', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_roles_grant_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0B418BA5-03DC-576D-9051-17DB90544B60')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0B418BA5-03DC-576D-9051-17DB90544B60', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8AC749A7-090E-5F36-AE77-3A93690DF9BB')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8AC749A7-090E-5F36-AE77-3A93690DF9BB', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7DA5F23F-1503-5793-BB45-57333352580F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7DA5F23F-1503-5793-BB45-57333352580F', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '07F2E473-F96F-564C-9B85-D8E0A42AA898')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('07F2E473-F96F-564C-9B85-D8E0A42AA898', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_role_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '28A02B96-5403-5938-84C9-05C8C65E128C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('28A02B96-5403-5938-84C9-05C8C65E128C', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_granted_context_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'C1C20E91-C646-5F77-93EA-E91088D2F597')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('C1C20E91-C646-5F77-93EA-E91088D2F597', '4CE0362E-F0B2-5A3A-B548-F4A61B58654C', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES (?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 0, N'Grant one role to one account, naming the context that granted it. A grant is itself an audited act.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'E461D260-D882-5222-9D22-95D25B8BF2EE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('E461D260-D882-5222-9D22-95D25B8BF2EE', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'revoke', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'B59B5585-0D36-5B24-830D-68210E788C05')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B59B5585-0D36-5B24-830D-68210E788C05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_roles_revoke_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E23349BF-4BD3-5C64-B3AD-22EC1190BCA3')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E23349BF-4BD3-5C64-B3AD-22EC1190BCA3', 'B59B5585-0D36-5B24-830D-68210E788C05', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_revoked_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'CA6DC866-5B17-5BF3-86AC-1A80B9C94678')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('CA6DC866-5B17-5BF3-86AC-1A80B9C94678', 'B59B5585-0D36-5B24-830D-68210E788C05', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '5BB26CA7-5ED6-5172-A90D-B160FD39326D')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('5BB26CA7-5ED6-5172-A90D-B160FD39326D', 'E461D260-D882-5222-9D22-95D25B8BF2EE', 'B59B5585-0D36-5B24-830D-68210E788C05', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sur] SET [sur].[pub_revoked_on] = SYSDATETIMEOFFSET(), [sur].[ref_revoked_context_guid] = ?, [sur].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_user_roles] AS [sur] WHERE [sur].[key_guid] = ? AND [sur].[pub_revoked_on] IS NULL', NULL, NULL, 0, N'Revoke one grant by key, naming the context that revoked it. The row stays: an auditor can still ask what the account held at a time.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_active', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '3FF5D601-D9EB-5795-9D67-E55322587056')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('3FF5D601-D9EB-5795-9D67-E55322587056', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_entitlements_read_active_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '9B380995-A321-5DD3-9F9A-783A7C5145FE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9B380995-A321-5DD3-9F9A-783A7C5145FE', '3FF5D601-D9EB-5795-9D67-E55322587056', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '09495779-0AC1-54B3-9CA0-1885E5C7A9EB')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('09495779-0AC1-54B3-9CA0-1885E5C7A9EB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_entitlements_read_active_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E160346A-A7BB-5B8F-B7CA-E78A835BA9D0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E160346A-A7BB-5B8F-B7CA-E78A835BA9D0', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D3DDF832-677A-546E-AB73-B054FF639C2C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D3DDF832-677A-546E-AB73-B054FF639C2C', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_entitlement_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '83841C21-1D00-5067-9B78-D6D7121CBDF7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('83841C21-1D00-5067-9B78-D6D7121CBDF7', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_granted_on', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '80267E20-8BC9-5B4B-814A-990D69BCEC8E')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('80267E20-8BC9-5B4B-814A-990D69BCEC8E', '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '3FF5D601-D9EB-5795-9D67-E55322587056', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [sue].[key_guid], [sue].[ref_entitlement_guid], [sue].[pub_granted_on] FROM [dbo].[system_user_entitlements] AS [sue] WHERE [sue].[ref_user_guid] = ? AND [sue].[pub_revoked_on] IS NULL FOR JSON PATH', NULL, NULL, 1, N'The entitlements one account holds right now: the rows not yet revoked.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '7C38CD25-80C9-507B-A290-CAFC5818DD23')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('7C38CD25-80C9-507B-A290-CAFC5818DD23', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'grant', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '9637B408-A388-5D8B-A1CA-B26F03C0FD58')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('9637B408-A388-5D8B-A1CA-B26F03C0FD58', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_entitlements_grant_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7C664BC9-85F0-5B97-A867-B6CF207A1386')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7C664BC9-85F0-5B97-A867-B6CF207A1386', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A30BA6D1-98FA-5931-BFCC-D7EB7BE87F8F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A30BA6D1-98FA-5931-BFCC-D7EB7BE87F8F', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F02918E6-2C8A-5DCD-8537-B8AA0E41FC0A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F02918E6-2C8A-5DCD-8537-B8AA0E41FC0A', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D33E4E3F-0D26-5AD0-909D-E9978BF86DC0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D33E4E3F-0D26-5AD0-909D-E9978BF86DC0', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_entitlement_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5AB2DCFF-3459-5368-B333-502EB894DDAF')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5AB2DCFF-3459-5368-B333-502EB894DDAF', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_granted_context_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'CCDD95C2-F059-507E-ABF5-E7FB9F678580')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('CCDD95C2-F059-507E-ABF5-E7FB9F678580', '7C38CD25-80C9-507B-A290-CAFC5818DD23', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_user_entitlements] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_entitlement_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES (?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 0, N'Grant one entitlement to one account, naming the context that granted it.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '91F687BF-14D1-5101-9986-A324015C2B46')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('91F687BF-14D1-5101-9986-A324015C2B46', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'revoke', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('FBE2B690-894F-58DE-A594-3C4B2BBD8CF8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'security_user_entitlements_revoke_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1778962D-03AB-517B-BD8D-F4B503A6B19C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1778962D-03AB-517B-BD8D-F4B503A6B19C', 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_revoked_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '3FEAFD05-6330-52DE-91D7-F7B25F61FB0E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('3FEAFD05-6330-52DE-91D7-F7B25F61FB0E', 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'A7B1A6E8-C59F-5B18-970C-D2902556998F')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('A7B1A6E8-C59F-5B18-970C-D2902556998F', '91F687BF-14D1-5101-9986-A324015C2B46', 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sue] SET [sue].[pub_revoked_on] = SYSDATETIMEOFFSET(), [sue].[ref_revoked_context_guid] = ?, [sue].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_user_entitlements] AS [sue] WHERE [sue].[key_guid] = ? AND [sue].[pub_revoked_on] IS NULL', NULL, NULL, 0, N'Revoke one entitlement grant by key, naming the context that revoked it. The row stays.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'B4FA5B80-4135-5DB0-BF3A-CEF4CA084E21')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('B4FA5B80-4135-5DB0-BF3A-CEF4CA084E21', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '8FE1005B-E985-59DD-B05E-CE4674533471', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_contexts_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '52C6976E-88E5-5394-9673-4BBA2CDC16BA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('52C6976E-88E5-5394-9673-4BBA2CDC16BA', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '2ED0EF43-898B-5BDF-A51D-B49F086F396C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('2ED0EF43-898B-5BDF-A51D-B49F086F396C', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '695403F1-9B16-51B7-98D0-BAD887F8C6F9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('695403F1-9B16-51B7-98D0-BAD887F8C6F9', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_actor_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '3D55D3A2-9F19-5775-A726-34B17D603905')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('3D55D3A2-9F19-5775-A726-34B17D603905', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_principal_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4610AD99-1736-5F18-8E39-C4E98A040CE8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4610AD99-1736-5F18-8E39-C4E98A040CE8', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_parent_context_guid', 5, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F5BC4202-F314-5CFC-B1FD-C962552CB805')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F5BC4202-F314-5CFC-B1FD-C962552CB805', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_channel_enum_guid', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C214831E-3632-5407-AC98-C9D13BD8396B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C214831E-3632-5407-AC98-C9D13BD8396B', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_host_guid', 7, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C13502CD-2F81-5D3F-956C-C47CFD2C9604')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C13502CD-2F81-5D3F-956C-C47CFD2C9604', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_instance_guid', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '583056E0-8A58-51B0-85FF-897D85C9ABF1')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('583056E0-8A58-51B0-85FF-897D85C9ABF1', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_sealed', 9, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'CD2C8843-71B8-59FA-8319-19E8731657FB')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('CD2C8843-71B8-59FA-8319-19E8731657FB', 'B4FA5B80-4135-5DB0-BF3A-CEF4CA084E21', '6681F3A6-B942-5AF4-93B1-3FBE02ABBEE5', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'INSERT INTO [dbo].[system_security_contexts] ([key_guid], [ref_package_guid], [ref_actor_guid], [ref_principal_guid], [ref_parent_context_guid], [ref_channel_enum_guid], [ref_host_guid], [ref_instance_guid], [pub_sealed], [pub_issued_on]) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 1, N'Write one context row: the token of one unit of work. Every context is a row, always, because a denial and an audit row must point at one. No update or delete function exists.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '48436E24-D9E8-55D3-91EE-D7BA4BA5CB0A')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('48436E24-D9E8-55D3-91EE-D7BA4BA5CB0A', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '8FE1005B-E985-59DD-B05E-CE4674533471', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_chain', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'C4D435D8-0213-55D4-ACA4-A9F3E18BC1A8')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('C4D435D8-0213-55D4-ACA4-A9F3E18BC1A8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_contexts_read_chain_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B1DF9233-5F9E-57AE-AE48-ACDD68F3B0B0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B1DF9233-5F9E-57AE-AE48-ACDD68F3B0B0', 'C4D435D8-0213-55D4-ACA4-A9F3E18BC1A8', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_contexts_read_chain_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '999D3999-0BF9-5A7B-9C1F-06D5C7A71524')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('999D3999-0BF9-5A7B-9C1F-06D5C7A71524', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B5D16D01-B8DD-5A00-8E67-7CC108BFDDC8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B5D16D01-B8DD-5A00-8E67-7CC108BFDDC8', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_actor_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '95BE3188-9063-5CA3-8C98-4F000681AF41')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('95BE3188-9063-5CA3-8C98-4F000681AF41', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_principal_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '54302CCE-5185-5DC6-BF86-AAD2D362B8DA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('54302CCE-5185-5DC6-BF86-AAD2D362B8DA', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_parent_context_guid', 4, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6C019670-BD42-538F-8405-714F83BF64C8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6C019670-BD42-538F-8405-714F83BF64C8', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_channel_enum_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '68C66E4B-67DE-5EBE-8B2B-D429B82CDF40')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('68C66E4B-67DE-5EBE-8B2B-D429B82CDF40', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_host_guid', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '34127FFF-EB82-5BD8-B951-EFAAF315167F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('34127FFF-EB82-5BD8-B951-EFAAF315167F', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_instance_guid', 7, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5291FCDA-8E9D-5002-A023-EA36A67B9792')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5291FCDA-8E9D-5002-A023-EA36A67B9792', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_sealed', 8, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '73B9142D-C21A-5558-8785-650172D607FF')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('73B9142D-C21A-5558-8785-650172D607FF', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_issued_on', 9, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1FF8BB04-7062-5A31-BFF4-00517FB2F3E5')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1FF8BB04-7062-5A31-BFF4-00517FB2F3E5', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', 'CF49017D-35D4-5F60-B25A-7688BC4B4517', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_depth', 10, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '7C1523D4-99B9-5AE9-9935-D3309EEF8322')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('7C1523D4-99B9-5AE9-9935-D3309EEF8322', '48436E24-D9E8-55D3-91EE-D7BA4BA5CB0A', 'C4D435D8-0213-55D4-ACA4-A9F3E18BC1A8', '1E12AA0B-2341-5F1E-9EF9-0571C1439A2F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'WITH [chain] AS (SELECT [ssco].[key_guid], [ssco].[ref_actor_guid], [ssco].[ref_principal_guid], [ssco].[ref_parent_context_guid], [ssco].[ref_channel_enum_guid], [ssco].[ref_host_guid], [ssco].[ref_instance_guid], [ssco].[pub_sealed], [ssco].[pub_issued_on], 0 AS [pub_depth] FROM [dbo].[system_security_contexts] AS [ssco] WHERE [ssco].[key_guid] = ? UNION ALL SELECT [p].[key_guid], [p].[ref_actor_guid], [p].[ref_principal_guid], [p].[ref_parent_context_guid], [p].[ref_channel_enum_guid], [p].[ref_host_guid], [p].[ref_instance_guid], [p].[pub_sealed], [p].[pub_issued_on], [c].[pub_depth] + 1 FROM [dbo].[system_security_contexts] AS [p] JOIN [chain] AS [c] ON [c].[ref_parent_context_guid] = [p].[key_guid]) SELECT [c].[key_guid], [c].[ref_actor_guid], [c].[ref_principal_guid], [c].[ref_parent_context_guid], [c].[ref_channel_enum_guid], [c].[ref_host_guid], [c].[ref_instance_guid], [c].[pub_sealed], [c].[pub_issued_on], [c].[pub_depth] FROM [chain] AS [c] ORDER BY [c].[pub_depth] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, N'One context and every parent up to the root, depth 0 first: the chain an auditor reads from a tracking row.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'F6C1E0B7-1ABD-53B5-BAB0-68C39072E224')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('F6C1E0B7-1ABD-53B5-BAB0-68C39072E224', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '6883E979-EDC7-506A-9791-AD4A2C171DBB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '3334CAD6-45C3-5D69-B84E-6466E52800FA')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('3334CAD6-45C3-5D69-B84E-6466E52800FA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_denials_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '52C9678C-7EFB-541B-8943-E26FF970D0FD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('52C9678C-7EFB-541B-8943-E26FF970D0FD', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6681E62B-0693-50F7-8F45-FF87C095AC9A')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6681E62B-0693-50F7-8F45-FF87C095AC9A', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4717F172-73A2-5196-8207-3368AACD350F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4717F172-73A2-5196-8207-3368AACD350F', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_context_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0A6D8760-B4CC-5523-8F35-D141547FF68F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0A6D8760-B4CC-5523-8F35-D141547FF68F', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_layer_enum_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F52698D2-F4AC-5918-BB9A-2AFB53B35C5F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F52698D2-F4AC-5918-BB9A-2AFB53B35C5F', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_reason_enum_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DB925CB5-5CC9-5A02-BB64-580B611A9CA9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DB925CB5-5CC9-5A02-BB64-580B611A9CA9', '3334CAD6-45C3-5D69-B84E-6466E52800FA', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_host_guid', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8A3676EA-4802-54E7-B7CA-3E559C722D95')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8A3676EA-4802-54E7-B7CA-3E559C722D95', '3334CAD6-45C3-5D69-B84E-6466E52800FA', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_subject', 7, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'F9171872-AAD1-530F-A1D5-C8848BB4563E')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('F9171872-AAD1-530F-A1D5-C8848BB4563E', 'F6C1E0B7-1ABD-53B5-BAB0-68C39072E224', '3334CAD6-45C3-5D69-B84E-6466E52800FA', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'INSERT INTO [dbo].[system_security_denials] ([key_guid], [ref_package_guid], [ref_context_guid], [ref_layer_enum_guid], [ref_reason_enum_guid], [ref_host_guid], [pub_subject], [pub_occurred_on]) VALUES (?, ?, ?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 1, N'Record one refusal: the context refused (the identity context when authorization or access refused), the layer, the reason, the subject (the URN, or schema.table for access). Written before the raise. No update or delete function exists.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '39027A44-5201-5F2F-8C66-D89C796EFE0A')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('39027A44-5201-5F2F-8C66-D89C796EFE0A', '6BF728D6-134F-5CFE-8259-8C979828765D', 'D372D512-3A8F-5745-9E25-DA2E8ACEBBFC', '6883E979-EDC7-506A-9791-AD4A2C171DBB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_by_context', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '3AACCD78-339C-575B-80EA-DE54527D4B61')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('3AACCD78-339C-575B-80EA-DE54527D4B61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_denials_read_by_context_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '99F257B3-D19E-51AE-B236-97955ABD001B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('99F257B3-D19E-51AE-B236-97955ABD001B', '3AACCD78-339C-575B-80EA-DE54527D4B61', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_denials_read_by_context_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'BA5C8D77-2C0A-5488-B50B-47280AA372B8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('BA5C8D77-2C0A-5488-B50B-47280AA372B8', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C9006F12-6A1B-5E48-868D-69D373C10435')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C9006F12-6A1B-5E48-868D-69D373C10435', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_layer_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E62C2AAE-92C6-512F-BC8B-23F9BA60C012')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E62C2AAE-92C6-512F-BC8B-23F9BA60C012', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_reason_enum_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F3AE2B5B-A982-5244-A314-4F308B1BB23C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F3AE2B5B-A982-5244-A314-4F308B1BB23C', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_host_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B6CA3647-FE98-56B1-B4DE-097074FAD25E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B6CA3647-FE98-56B1-B4DE-097074FAD25E', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_subject', 5, 0, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A6C19D0E-87E8-5F5A-95C3-72F1ECE2FBB4')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A6C19D0E-87E8-5F5A-95C3-72F1ECE2FBB4', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_occurred_on', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '593EF327-BD19-5689-99F1-0FC7862C41D8')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('593EF327-BD19-5689-99F1-0FC7862C41D8', '39027A44-5201-5F2F-8C66-D89C796EFE0A', '3AACCD78-339C-575B-80EA-DE54527D4B61', 'A3378C0D-C70D-5E0F-8A32-1BEF8F95806D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'SELECT [ssd].[key_guid], [ssd].[ref_layer_enum_guid], [ssd].[ref_reason_enum_guid], [ssd].[ref_host_guid], [ssd].[pub_subject], [ssd].[pub_occurred_on] FROM [dbo].[system_security_denials] AS [ssd] WHERE [ssd].[ref_context_guid] = ? ORDER BY [ssd].[pub_occurred_on] FOR JSON PATH', NULL, NULL, 0, N'Every refusal recorded against one context.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '24FFE66B-38B4-55C4-88BF-D6E603F8F2F1')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('24FFE66B-38B4-55C4-88BF-D6E603F8F2F1', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', '5855ADF8-7C70-5784-96E4-D5CA800B2268', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_tables_read_all_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E889334E-D621-5D3F-9606-5CA2C91FBD5F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E889334E-D621-5D3F-9606-5CA2C91FBD5F', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'AC519774-B862-5F8C-90B3-C98E5175A851')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('AC519774-B862-5F8C-90B3-C98E5175A851', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '17C00DFD-1CCA-56DA-94DA-AA613B48F3A8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('17C00DFD-1CCA-56DA-94DA-AA613B48F3A8', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_schema', 3, 0, NULL, 64, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '07935B8F-0F97-5A06-A884-27D12AC59195')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('07935B8F-0F97-5A06-A884-27D12AC59195', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_name', 4, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'FC0CFDEC-F73A-5127-B8C7-905D553AA3A6')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FC0CFDEC-F73A-5127-B8C7-905D553AA3A6', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_insert', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '735A9C7E-928A-5E8C-9C5A-44ABFFF82BCA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('735A9C7E-928A-5E8C-9C5A-44ABFFF82BCA', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_update', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '25875628-F9B1-5C44-B80A-3517E8E58E4B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('25875628-F9B1-5C44-B80A-3517E8E58E4B', '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_delete', 7, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '93FE4AFD-C147-565A-883F-7CA9FD5F1BA8')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('93FE4AFD-C147-565A-883F-7CA9FD5F1BA8', '24FFE66B-38B4-55C4-88BF-D6E603F8F2F1', NULL, '42D06ADA-A79F-5BD1-8E5D-A89FC6BF3413', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'SELECT [sat].[key_guid], [sat].[ref_table_guid], [cdt].[pub_schema], [cdt].[pub_name], [sat].[pub_log_insert], [sat].[pub_log_update], [sat].[pub_log_delete] FROM [dbo].[service_audit_tables] AS [sat] JOIN [etg].[contracts_db_tables] AS [cdt] ON [cdt].[key_guid] = [sat].[ref_table_guid] ORDER BY [cdt].[pub_schema], [cdt].[pub_name] FOR JSON PATH', NULL, NULL, 1, N'The audit setup: which tables are logged and for which change kinds. The executor holds this in memory and consults it before every write.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'A2982E38-5BBD-5DDB-9226-2B0B2315530B')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('A2982E38-5BBD-5DDB-9226-2B0B2315530B', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', '5855ADF8-7C70-5784-96E4-D5CA800B2268', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '68177FB7-53FD-540B-9716-CEDACD86D3C1')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('68177FB7-53FD-540B-9716-CEDACD86D3C1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_tables_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F02583D9-EF89-50A9-9B9A-2199B4D4DE12')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F02583D9-EF89-50A9-9B9A-2199B4D4DE12', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F160564B-686E-544C-9EDE-25E32CC91828')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F160564B-686E-544C-9EDE-25E32CC91828', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '3308C336-FD4B-5F5D-9144-AE234B541FF7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('3308C336-FD4B-5F5D-9144-AE234B541FF7', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '2CEBAB83-8CFB-5E1F-A22A-9298C4565090')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('2CEBAB83-8CFB-5E1F-A22A-9298C4565090', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_insert', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EAC596B2-C797-5BAC-ACC7-D32A31E66A02')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EAC596B2-C797-5BAC-ACC7-D32A31E66A02', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_update', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '51C1AD1B-2A5A-5F3C-A5E4-91C96A460140')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('51C1AD1B-2A5A-5F3C-A5E4-91C96A460140', '68177FB7-53FD-540B-9716-CEDACD86D3C1', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_delete', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C6C62A8C-6BB3-5EA3-93FC-735524CF07F8')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C6C62A8C-6BB3-5EA3-93FC-735524CF07F8', '68177FB7-53FD-540B-9716-CEDACD86D3C1', 'C7B88F80-0464-58D7-8310-4BB1902B7450', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_notes', 7, 1, NULL, 512, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '0A5D7C07-4496-5092-BBFD-6EBD8AE85599')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('0A5D7C07-4496-5092-BBFD-6EBD8AE85599', 'A2982E38-5BBD-5DDB-9226-2B0B2315530B', '68177FB7-53FD-540B-9716-CEDACD86D3C1', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'INSERT INTO [dbo].[service_audit_tables] ([key_guid], [ref_package_guid], [ref_table_guid], [pub_log_insert], [pub_log_update], [pub_log_delete], [pub_notes]) VALUES (?, ?, ?, ?, ?, ?, ?)', NULL, NULL, 0, N'Put one table under audit. The setup surface offers only tables whose records carry a number sequence; a table with no sequence has no record number to log.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'FC585D9E-6BD2-5FF4-816E-311CBF46CB51')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('FC585D9E-6BD2-5FF4-816E-311CBF46CB51', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', '5855ADF8-7C70-5784-96E4-D5CA800B2268', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'update', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'B01E9349-8B08-5537-A4CC-280767C40FE0')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B01E9349-8B08-5537-A4CC-280767C40FE0', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_tables_update_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '450545B4-CCD0-5BA3-85D1-863AB6E4514D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('450545B4-CCD0-5BA3-85D1-863AB6E4514D', 'B01E9349-8B08-5537-A4CC-280767C40FE0', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_insert', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0DF3D463-0D53-5060-8478-8902739B42BE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0DF3D463-0D53-5060-8478-8902739B42BE', 'B01E9349-8B08-5537-A4CC-280767C40FE0', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_update', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7E118BC8-6491-55F1-A80E-837C04CF36B9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7E118BC8-6491-55F1-A80E-837C04CF36B9', 'B01E9349-8B08-5537-A4CC-280767C40FE0', '892A2D24-1D12-5305-A7BD-9684FAE59667', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_log_delete', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4CDA76CA-947F-51B4-98E1-8A0C48FB767E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4CDA76CA-947F-51B4-98E1-8A0C48FB767E', 'B01E9349-8B08-5537-A4CC-280767C40FE0', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '217FA76E-8693-5ACB-AAD7-5D5DC642BD3B')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('217FA76E-8693-5ACB-AAD7-5D5DC642BD3B', 'FC585D9E-6BD2-5FF4-816E-311CBF46CB51', 'B01E9349-8B08-5537-A4CC-280767C40FE0', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'UPDATE [sat] SET [sat].[pub_log_insert] = ?, [sat].[pub_log_update] = ?, [sat].[pub_log_delete] = ?, [sat].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[service_audit_tables] AS [sat] WHERE [sat].[ref_table_guid] = ?', NULL, NULL, 0, N'Change which kinds are logged for one table. All three off is the way to stop logging; the row stays so the history of the setting is not lost.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '7DD1DD26-67D0-5FF6-A32C-F32DAB43BD60')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('7DD1DD26-67D0-5FF6-A32C-F32DAB43BD60', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'E804CF96-95A5-528F-94D7-CCDD0D493B36')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('E804CF96-95A5-528F-94D7-CCDD0D493B36', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '2D63C7AA-7A86-5EF7-A9C8-38F3515E8CF0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('2D63C7AA-7A86-5EF7-A9C8-38F3515E8CF0', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1143B573-516B-522C-BFB1-E84FFD05D7C7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1143B573-516B-522C-BFB1-E84FFD05D7C7', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '370633E3-50D5-5643-8FB2-9DC91EE8B928')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('370633E3-50D5-5643-8FB2-9DC91EE8B928', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_context_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F9250B06-1B50-5FD2-AD8A-544AC9757146')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F9250B06-1B50-5FD2-AD8A-544AC9757146', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C3C7164B-A363-5073-AE2D-A25F3A44C29E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C3C7164B-A363-5073-AE2D-A25F3A44C29E', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_kind_enum_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '859CAEA4-FE47-51DC-8BCB-033F2629C7FE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('859CAEA4-FE47-51DC-8BCB-033F2629C7FE', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '045872FB-30A5-5DF0-8A76-363093C66D05', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_record_number', 6, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'FE7127BB-2FD9-5054-8D39-3E76D8F3BBFD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('FE7127BB-2FD9-5054-8D39-3E76D8F3BBFD', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_metadata', 7, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '1C2F0CA1-EEDC-5667-AF11-BF0DC31A11C4')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('1C2F0CA1-EEDC-5667-AF11-BF0DC31A11C4', '7DD1DD26-67D0-5FF6-A32C-F32DAB43BD60', 'E804CF96-95A5-528F-94D7-CCDD0D493B36', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'INSERT INTO [dbo].[system_audit_transactions] ([key_guid], [ref_package_guid], [ref_context_guid], [ref_table_guid], [ref_kind_enum_guid], [pub_record_number], [pub_logged_on], [pub_metadata]) VALUES (?, ?, ?, ?, ?, ?, SYSDATETIMEOFFSET(), ?)', NULL, NULL, 1, N'The tracking row the executor writes in the same transaction as the record: who made it (the context) and when, the table, the record number, the change kind, metadata. Never the change itself. No update function exists.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8E43D3F5-AAEE-5991-BC65-26C207297173')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8E43D3F5-AAEE-5991-BC65-26C207297173', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_by_record', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '36518584-490B-57B4-A860-A97D4B0D4CDD')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('36518584-490B-57B4-A860-A97D4B0D4CDD', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_read_by_record_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B0805973-9734-5873-AAA2-F303E3DC79B0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B0805973-9734-5873-AAA2-F303E3DC79B0', '36518584-490B-57B4-A860-A97D4B0D4CDD', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E7199C07-58DF-5F4E-B7AD-C29E096505C0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E7199C07-58DF-5F4E-B7AD-C29E096505C0', '36518584-490B-57B4-A860-A97D4B0D4CDD', '045872FB-30A5-5DF0-8A76-363093C66D05', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_record_number', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_read_by_record_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C438E415-DB31-575F-B873-3536187D5842')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C438E415-DB31-575F-B873-3536187D5842', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '24D824F3-2C4F-50B8-ADCF-AA23C0BB2D27')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('24D824F3-2C4F-50B8-ADCF-AA23C0BB2D27', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_context_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EEEB1857-A967-5F7D-85BC-DB72A3BE9777')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EEEB1857-A967-5F7D-85BC-DB72A3BE9777', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_kind_enum_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '460F48AD-9F75-5CCA-9501-680B1D4838AC')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('460F48AD-9F75-5CCA-9501-680B1D4838AC', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_logged_on', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B4C003EB-CF91-52BA-ACDB-E25225B829AC')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B4C003EB-CF91-52BA-ACDB-E25225B829AC', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_metadata', 5, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '2FDA95F5-9A50-5DC2-B26E-BF7441469B9B')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('2FDA95F5-9A50-5DC2-B26E-BF7441469B9B', '8E43D3F5-AAEE-5991-BC65-26C207297173', '36518584-490B-57B4-A860-A97D4B0D4CDD', 'DFAB4FFD-7C3F-569F-86E3-814E4BB4D2C9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'SELECT [satr].[key_guid], [satr].[ref_context_guid], [satr].[ref_kind_enum_guid], [satr].[pub_logged_on], [satr].[pub_metadata] FROM [dbo].[system_audit_transactions] AS [satr] WHERE [satr].[ref_table_guid] = ? AND [satr].[pub_record_number] = ? ORDER BY [satr].[pub_logged_on] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, N'The history of one record: every logged change to it, oldest first. The auditors question, answered by table and record number.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'D29B5D41-CC4F-5349-BF03-97FDF9579920')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('D29B5D41-CC4F-5349-BF03-97FDF9579920', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_by_context', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'B4242561-57E9-533F-8660-C64396E8D8CB')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B4242561-57E9-533F-8660-C64396E8D8CB', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_read_by_context_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'BC336C5C-49CB-51DA-899B-94863120C79F')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('BC336C5C-49CB-51DA-899B-94863120C79F', 'B4242561-57E9-533F-8660-C64396E8D8CB', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'C74614EC-50C7-530D-BDFE-9E88581F45AE')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('C74614EC-50C7-530D-BDFE-9E88581F45AE', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_read_by_context_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '68B7C9A2-9B08-5E4B-A879-D47D1FF88221')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('68B7C9A2-9B08-5E4B-A879-D47D1FF88221', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '3DA7B8F3-1175-516C-875D-C21BE16E8F4E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('3DA7B8F3-1175-516C-875D-C21BE16E8F4E', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_table_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'A9C7BF4A-CA51-52E5-B9D1-16E613C14650')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('A9C7BF4A-CA51-52E5-B9D1-16E613C14650', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '5024F830-E80E-5271-BBF3-86CBD4815676', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ref_kind_enum_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B3D87132-5AD1-5972-BA1A-763F9B5AC7B3')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B3D87132-5AD1-5972-BA1A-763F9B5AC7B3', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '045872FB-30A5-5DF0-8A76-363093C66D05', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_record_number', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7BC8E4C5-8296-5B97-A853-A1178A62161D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7BC8E4C5-8296-5B97-A853-A1178A62161D', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_logged_on', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '5DD436CF-5769-514F-83B9-509D02B8AE56')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('5DD436CF-5769-514F-83B9-509D02B8AE56', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_metadata', 6, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'FDB49AA8-F8F7-5865-8B08-26B581F38DF4')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('FDB49AA8-F8F7-5865-8B08-26B581F38DF4', 'D29B5D41-CC4F-5349-BF03-97FDF9579920', 'B4242561-57E9-533F-8660-C64396E8D8CB', 'C74614EC-50C7-530D-BDFE-9E88581F45AE', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'SELECT [satr].[key_guid], [satr].[ref_table_guid], [satr].[ref_kind_enum_guid], [satr].[pub_record_number], [satr].[pub_logged_on], [satr].[pub_metadata] FROM [dbo].[system_audit_transactions] AS [satr] WHERE [satr].[ref_context_guid] = ? ORDER BY [satr].[pub_logged_on] FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 0, N'Every logged change one unit of work made.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '5D3F1349-DE9D-5EC7-9015-B7A25815C812')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('5D3F1349-DE9D-5EC7-9015-B7A25815C812', '6BF728D6-134F-5CFE-8259-8C979828765D', 'C8F4BCEF-3542-5A19-920F-4C6C5A8B1769', 'B5058F3F-2D4A-51ED-BEDC-F7671A0302C7', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'delete_before', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '0275A470-9B6F-5630-8B62-A8F086A931BD')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('0275A470-9B6F-5630-8B62-A8F086A931BD', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_transactions_delete_before_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '0D48BABC-A5EA-5E2E-B6EA-8D23C5A647A9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('0D48BABC-A5EA-5E2E-B6EA-8D23C5A647A9', '0275A470-9B6F-5630-8B62-A8F086A931BD', '160A9552-FB97-57D0-8C33-9FFE044F3A25', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'pub_logged_on', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'D37EF716-DB95-5712-8DE8-32A9129365AE')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('D37EF716-DB95-5712-8DE8-32A9129365AE', '5D3F1349-DE9D-5EC7-9015-B7A25815C812', '0275A470-9B6F-5630-8B62-A8F086A931BD', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'DELETE FROM [dbo].[system_audit_transactions] WHERE [pub_logged_on] < ?', NULL, NULL, 0, N'Retention: the one set-based delete on the audit log, plural by nature. The audit domain is held by service automation; nothing else can reach this.');
GO

-- =====================================================================
-- Batch 9: the renamed history column follows through the data that names it: the record op's SQL and its input
-- model field (re-keyed, since the field key is model.field), and the column declaration populate wrote for the old
-- name (populate never deletes; it declares the new one). Then the declaration and export rows for the seven tables.
-- =====================================================================
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = REPLACE([pub_query_mssql], N'[ref_user_guid]', N'[ref_principal_guid]'), [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '6C0E598D-F5D1-54AF-9A55-9728A3EEA342' AND [pub_query_mssql] LIKE N'%[[]ref_user_guid]%';
IF EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '286E9231-143E-5F68-B8B7-76FC5B064D7E')
UPDATE [etg].[contracts_db_operations_models_fields] SET [key_guid] = 'D9CC5360-E3F4-57E1-A271-85A1B5E1C51E', [pub_name] = 'ref_principal_guid', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '286E9231-143E-5F68-B8B7-76FC5B064D7E';
DELETE FROM [etg].[contracts_db_constraint_columns] WHERE [ref_column_guid] = '80F2D7D8-AFEF-52EB-A1A6-166CC9DF8C98' OR [ref_referenced_column_guid] = '80F2D7D8-AFEF-52EB-A1A6-166CC9DF8C98';
DELETE FROM [etg].[contracts_db_index_columns] WHERE [ref_column_guid] = '80F2D7D8-AFEF-52EB-A1A6-166CC9DF8C98';
DELETE FROM [etg].[contracts_db_columns] WHERE [key_guid] = '80F2D7D8-AFEF-52EB-A1A6-166CC9DF8C98';
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'D0690BAF-27E0-5CB6-B00D-BE44E6E4EA26')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('D0690BAF-27E0-5CB6-B00D-BE44E6E4EA26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_users', 'dbo', 'su', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '4B381486-E6D6-598C-A185-DF08548533CD')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('4B381486-E6D6-598C-A185-DF08548533CD', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_user_roles', 'dbo', 'sur', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '90731EB9-6011-5161-BFDE-CEEF48283E52')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('90731EB9-6011-5161-BFDE-CEEF48283E52', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_user_entitlements', 'dbo', 'sue', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '59AC1F9A-FC80-5A3C-AC4F-DEE0BB547196')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('59AC1F9A-FC80-5A3C-AC4F-DEE0BB547196', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_security_contexts', 'dbo', 'ssco', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'D8BA2056-AF11-59ED-A2D1-EF2117559366')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('D8BA2056-AF11-59ED-A2D1-EF2117559366', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_security_denials', 'dbo', 'ssd', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '108ABD08-77C4-54F3-9F7B-4910A6F57E84')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('108ABD08-77C4-54F3-9F7B-4910A6F57E84', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'service_audit_tables', 'dbo', 'sat', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '75BC1705-0AE3-5216-B37B-9A0CD969E62E')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('75BC1705-0AE3-5216-B37B-9A0CD969E62E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'system_audit_transactions', 'dbo', 'satr', 0);
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B3EE0A27-FEB0-5BD3-B95E-913B1633EAB8')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B3EE0A27-FEB0-5BD3-B95E-913B1633EAB8', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'D0690BAF-27E0-5CB6-B00D-BE44E6E4EA26');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '9EF3589F-801B-5ADD-A4A9-1CFF1610DCBA')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('9EF3589F-801B-5ADD-A4A9-1CFF1610DCBA', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '4B381486-E6D6-598C-A185-DF08548533CD');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '3E4D714E-BFF4-5127-8739-C6FCC36E82B5')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('3E4D714E-BFF4-5127-8739-C6FCC36E82B5', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '90731EB9-6011-5161-BFDE-CEEF48283E52');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B0AE7286-5CF7-5D04-99E7-2C86F9DB7F28')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B0AE7286-5CF7-5D04-99E7-2C86F9DB7F28', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '59AC1F9A-FC80-5A3C-AC4F-DEE0BB547196');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'DF5EF525-8581-50C8-88EB-B97A3E4393D7')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('DF5EF525-8581-50C8-88EB-B97A3E4393D7', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '108ABD08-77C4-54F3-9F7B-4910A6F57E84');
GO


-- =====================================================================
-- Batch 10: users are the ACCOUNT domain (Aaron 2026-11-01: "system_users is not the correct domain, users is account
-- domain, and technically the mapping to security is also an account domain consideration"). Batch 8 stays as applied;
-- this batch moves the users, user_roles and user_entitlements functions from db:security to db:account: the eight
-- operations, their ten models and the fields are deleted under the security keys and inserted under the account keys
-- (a key is uuid5 of the URN or the model name, so a move is a re-key). The subdomain rows and their entitlements are
-- unchanged: a subdomain names no domain since 0.2.1. The account domain already carries ROLE_ACCOUNT_ADMIN.
-- Table names are not domains (Aaron 2026-10-22): system_users and system_user_* stay.
-- =====================================================================
IF EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('AADDD6B6-01B9-5BAB-8B28-2171DD992D08', '716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '55796AF7-347D-574E-886A-0278B09C6541', '4CE0362E-F0B2-5A3A-B548-F4A61B58654C', 'E461D260-D882-5222-9D22-95D25B8BF2EE', '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '7C38CD25-80C9-507B-A290-CAFC5818DD23', '91F687BF-14D1-5101-9986-A324015C2B46'))
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    DELETE FROM [etg].[contracts_db_operations] WHERE [key_guid] IN ('B07BD6F5-AA3C-59A7-B084-AC6AC8D34264', 'FEC4359D-4B9F-52FE-A055-54023F4185F5', 'D031F61F-7E34-5C7A-9A8A-D326C28BFE65', 'C1C20E91-C646-5F77-93EA-E91088D2F597', '5BB26CA7-5ED6-5172-A90D-B160FD39326D', '80267E20-8BC9-5B4B-814A-990D69BCEC8E', 'CCDD95C2-F059-507E-ABF5-E7FB9F678580', 'A7B1A6E8-C59F-5B18-970C-D2902556998F');
    DELETE FROM [etg].[contracts_db_operations_models_fields] WHERE [ref_model_guid] IN ('D37CD09D-5513-5539-8936-C734CE043733', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '49E5078D-5279-5D09-BD6C-5B86629416B6', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', 'B59B5585-0D36-5B24-830D-68210E788C05', '3FF5D601-D9EB-5795-9D67-E55322587056', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8');
    DELETE FROM [etg].[contracts_db_operations_models] WHERE [key_guid] IN ('D37CD09D-5513-5539-8936-C734CE043733', '363F12D1-C984-5A4D-B66B-BA102A3F1F93', '49E5078D-5279-5D09-BD6C-5B86629416B6', '6DA6FF3C-29A2-5D1C-ADD7-D0D5C4DD8526', 'DD8743C8-7C95-522D-AEB7-D04D1A347D76', 'B59B5585-0D36-5B24-830D-68210E788C05', '3FF5D601-D9EB-5795-9D67-E55322587056', '09495779-0AC1-54B3-9CA0-1885E5C7A9EB', '9637B408-A388-5D8B-A1CA-B26F03C0FD58', 'FBE2B690-894F-58DE-A594-3C4B2BBD8CF8');
    DELETE FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('AADDD6B6-01B9-5BAB-8B28-2171DD992D08', '716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '55796AF7-347D-574E-886A-0278B09C6541', '4CE0362E-F0B2-5A3A-B548-F4A61B58654C', 'E461D260-D882-5222-9D22-95D25B8BF2EE', '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '7C38CD25-80C9-507B-A290-CAFC5818DD23', '91F687BF-14D1-5101-9986-A324015C2B46');
  COMMIT TRANSACTION;
END
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '74AF9DA8-0836-59E8-97DF-5DD5BD391747')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('74AF9DA8-0836-59E8-97DF-5DD5BD391747', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '53B61350-019B-57D7-8694-403E0F31623E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '530B06E0-6258-5261-8573-1A207971CD4B')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('530B06E0-6258-5261-8573-1A207971CD4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_users_read_all_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DAA06917-2BFA-5005-B658-0A64CB4C9706')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DAA06917-2BFA-5005-B658-0A64CB4C9706', '530B06E0-6258-5261-8573-1A207971CD4B', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'B67278DB-1FD2-5F65-A8B5-C3BC565C77C5')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('B67278DB-1FD2-5F65-A8B5-C3BC565C77C5', '530B06E0-6258-5261-8573-1A207971CD4B', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '8A94D93A-1437-5F9F-B1E2-4DFEC1AB6C70')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('8A94D93A-1437-5F9F-B1E2-4DFEC1AB6C70', '530B06E0-6258-5261-8573-1A207971CD4B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 3, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D1C56C8D-A16B-54C4-ADDF-F203F78B470B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D1C56C8D-A16B-54C4-ADDF-F203F78B470B', '530B06E0-6258-5261-8573-1A207971CD4B', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_enabled', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'F3EE6C56-24BE-5D50-974A-2FDAEC306731')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('F3EE6C56-24BE-5D50-974A-2FDAEC306731', '74AF9DA8-0836-59E8-97DF-5DD5BD391747', NULL, '530B06E0-6258-5261-8573-1A207971CD4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [su].[key_guid], [su].[ref_kind_enum_guid], [su].[pub_display], [su].[pub_is_enabled] FROM [dbo].[system_users] AS [su] ORDER BY [su].[pub_display] FOR JSON PATH', NULL, NULL, 1, N'Every account row: the three automation accounts and every person. The kernel reads it to name its own actor; Auth reads it to resolve a first-seen user.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '9C5A2173-ED08-57A8-AA91-DE7DEA3D9260')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('9C5A2173-ED08-57A8-AA91-DE7DEA3D9260', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '53B61350-019B-57D7-8694-403E0F31623E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'D962613C-4F39-54B4-A6DC-B76BD580E11E')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D962613C-4F39-54B4-A6DC-B76BD580E11E', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_users_create_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D1961A13-D399-5653-B588-5C28B1C7C8B9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D1961A13-D399-5653-B588-5C28B1C7C8B9', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'CE68293A-47AC-52C3-99A6-D3D745309441')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('CE68293A-47AC-52C3-99A6-D3D745309441', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DAAC4B6E-E6DA-51B6-8507-27DF7A014F4C')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DAAC4B6E-E6DA-51B6-8507-27DF7A014F4C', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_kind_enum_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'EE1A710F-FF61-592C-9CCF-8A18E400353B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('EE1A710F-FF61-592C-9CCF-8A18E400353B', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_display', 4, 0, NULL, 128, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '24B44442-1405-5794-89DF-36426A30FD5D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('24B44442-1405-5794-89DF-36426A30FD5D', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', '892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_is_enabled', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'EDA82594-EBF7-596B-8CA7-CC069CEEA4FB')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('EDA82594-EBF7-596B-8CA7-CC069CEEA4FB', '9C5A2173-ED08-57A8-AA91-DE7DEA3D9260', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled]) VALUES (?, ?, ?, ?, ?)', NULL, NULL, 0, N'Create one account row. Interactive accounts are minted by Users at first-seen (NEWID); the automation accounts are seeded by formula and never created here.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_active', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '1A9B65B2-D774-53A2-994B-42BBF04EB24F')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('1A9B65B2-D774-53A2-994B-42BBF04EB24F', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_roles_read_active_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F9ADB181-30C8-5AA3-B983-C5A2969CB3D9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F9ADB181-30C8-5AA3-B983-C5A2969CB3D9', '1A9B65B2-D774-53A2-994B-42BBF04EB24F', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'ED5666EA-6F66-5E36-9C5B-A591DBFA0682')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('ED5666EA-6F66-5E36-9C5B-A591DBFA0682', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_roles_read_active_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'F6DA5117-9750-5583-967F-4753674A1AE2')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('F6DA5117-9750-5583-967F-4753674A1AE2', 'ED5666EA-6F66-5E36-9C5B-A591DBFA0682', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '4A5E5D50-E376-579A-97D1-404CED9C9E9B')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('4A5E5D50-E376-579A-97D1-404CED9C9E9B', 'ED5666EA-6F66-5E36-9C5B-A591DBFA0682', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_role_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6082E91D-8283-5CB1-9D07-744F1155F4AA')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6082E91D-8283-5CB1-9D07-744F1155F4AA', 'ED5666EA-6F66-5E36-9C5B-A591DBFA0682', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_granted_on', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'E6CA7B6D-2A40-5B57-9FFE-DCF66F56126B')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('E6CA7B6D-2A40-5B57-9FFE-DCF66F56126B', 'CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB', '1A9B65B2-D774-53A2-994B-42BBF04EB24F', 'ED5666EA-6F66-5E36-9C5B-A591DBFA0682', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [sur].[key_guid], [sur].[ref_role_guid], [sur].[pub_granted_on] FROM [dbo].[system_user_roles] AS [sur] WHERE [sur].[ref_user_guid] = ? AND [sur].[pub_revoked_on] IS NULL FOR JSON PATH', NULL, NULL, 1, N'The roles one account holds right now: the rows not yet revoked. The decoration of a unit of work is resolved from this once, at its start.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8C8FBDFE-8F51-508F-B25D-538B914B1BA6')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8C8FBDFE-8F51-508F-B25D-538B914B1BA6', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'grant', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B3885E0B-C5BF-5B6D-924F-B1EC571C7078', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_roles_grant_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6A35CC91-E121-5F7D-9970-4E0F3FA52A90')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6A35CC91-E121-5F7D-9970-4E0F3FA52A90', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DE3DFCDE-86F3-5EF8-A9CD-44CFC51516E1')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DE3DFCDE-86F3-5EF8-A9CD-44CFC51516E1', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'DB33B73E-73C7-53FE-8A95-3C4F9BF1EC55')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('DB33B73E-73C7-53FE-8A95-3C4F9BF1EC55', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '2A5EFCA5-3A3A-5956-BB02-4B916F7D2DAB')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('2A5EFCA5-3A3A-5956-BB02-4B916F7D2DAB', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_role_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '1D916D02-8660-5AA2-A122-E9CF6A6671B7')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('1D916D02-8660-5AA2-A122-E9CF6A6671B7', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_granted_context_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '78F2BD7C-4500-5046-9455-B26232FE9979')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('78F2BD7C-4500-5046-9455-B26232FE9979', '8C8FBDFE-8F51-508F-B25D-538B914B1BA6', 'B3885E0B-C5BF-5B6D-924F-B1EC571C7078', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_user_roles] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_role_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES (?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 0, N'Grant one role to one account, naming the context that granted it. A grant is itself an audited act.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'FF048465-6B16-5768-B4B7-6D1915C136B0')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('FF048465-6B16-5768-B4B7-6D1915C136B0', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', 'EB7A40D7-8FC3-59C6-B332-75E04E28EFA7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'revoke', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '59FA9B7D-8CE9-5AD4-B65E-D6F6DD17FEC5')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('59FA9B7D-8CE9-5AD4-B65E-D6F6DD17FEC5', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_roles_revoke_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'E3769FA9-BE0A-5E48-8B9B-1E58081E1ABD')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('E3769FA9-BE0A-5E48-8B9B-1E58081E1ABD', '59FA9B7D-8CE9-5AD4-B65E-D6F6DD17FEC5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_revoked_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '44E82875-21C9-5423-9C8A-FC75B6A49062')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('44E82875-21C9-5423-9C8A-FC75B6A49062', '59FA9B7D-8CE9-5AD4-B65E-D6F6DD17FEC5', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '943E7270-27DF-53BF-B26C-AC03A49A01C3')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('943E7270-27DF-53BF-B26C-AC03A49A01C3', 'FF048465-6B16-5768-B4B7-6D1915C136B0', '59FA9B7D-8CE9-5AD4-B65E-D6F6DD17FEC5', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sur] SET [sur].[pub_revoked_on] = SYSDATETIMEOFFSET(), [sur].[ref_revoked_context_guid] = ?, [sur].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_user_roles] AS [sur] WHERE [sur].[key_guid] = ? AND [sur].[pub_revoked_on] IS NULL', NULL, NULL, 0, N'Revoke one grant by key, naming the context that revoked it. The row stays: an auditor can still ask what the account held at a time.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'C747AAEA-A706-5180-AB43-51F1C55EB6B5')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('C747AAEA-A706-5180-AB43-51F1C55EB6B5', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_active', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '34E64235-B657-50B6-86FD-F2C182B9E4B9')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('34E64235-B657-50B6-86FD-F2C182B9E4B9', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_entitlements_read_active_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '68BBFF80-E55C-5810-A5D1-6ABBC1D4FD46')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('68BBFF80-E55C-5810-A5D1-6ABBC1D4FD46', '34E64235-B657-50B6-86FD-F2C182B9E4B9', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'CFE5313F-179F-53A9-980B-E2C1EB2A487B')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('CFE5313F-179F-53A9-980B-E2C1EB2A487B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_entitlements_read_active_output', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '99F0DC3B-D86C-5E67-9C2F-A33E03BB1667')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('99F0DC3B-D86C-5E67-9C2F-A33E03BB1667', 'CFE5313F-179F-53A9-980B-E2C1EB2A487B', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'D2CEAE3E-37E7-52D7-B191-9EF836CB19CE')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('D2CEAE3E-37E7-52D7-B191-9EF836CB19CE', 'CFE5313F-179F-53A9-980B-E2C1EB2A487B', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_entitlement_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7445EA9D-B939-53F9-8804-0B39D33ABDA9')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7445EA9D-B939-53F9-8804-0B39D33ABDA9', 'CFE5313F-179F-53A9-980B-E2C1EB2A487B', '160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_granted_on', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '62857988-AE20-5DDB-B087-2DA9A388497B')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('62857988-AE20-5DDB-B087-2DA9A388497B', 'C747AAEA-A706-5180-AB43-51F1C55EB6B5', '34E64235-B657-50B6-86FD-F2C182B9E4B9', 'CFE5313F-179F-53A9-980B-E2C1EB2A487B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'SELECT [sue].[key_guid], [sue].[ref_entitlement_guid], [sue].[pub_granted_on] FROM [dbo].[system_user_entitlements] AS [sue] WHERE [sue].[ref_user_guid] = ? AND [sue].[pub_revoked_on] IS NULL FOR JSON PATH', NULL, NULL, 1, N'The entitlements one account holds right now: the rows not yet revoked.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8CBE612B-6964-5CDC-90C3-E45B74223C02')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8CBE612B-6964-5CDC-90C3-E45B74223C02', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'grant', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = '5E1D1FFB-348A-5428-8781-197C8D4A0377')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5E1D1FFB-348A-5428-8781-197C8D4A0377', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_entitlements_grant_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'C9D8CC6F-7C98-57AF-B4C0-12E57F9ED934')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('C9D8CC6F-7C98-57AF-B4C0-12E57F9ED934', '5E1D1FFB-348A-5428-8781-197C8D4A0377', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7984CDF7-2BF1-5E5F-B758-2ECDBE4D471D')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7984CDF7-2BF1-5E5F-B758-2ECDBE4D471D', '5E1D1FFB-348A-5428-8781-197C8D4A0377', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_package_guid', 2, 1, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '6A95B640-8C0D-55DA-889D-0354D3AE8F27')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('6A95B640-8C0D-55DA-889D-0354D3AE8F27', '5E1D1FFB-348A-5428-8781-197C8D4A0377', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_user_guid', 3, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '71C26F02-8436-5CF2-8458-2E632CAE70C0')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('71C26F02-8436-5CF2-8458-2E632CAE70C0', '5E1D1FFB-348A-5428-8781-197C8D4A0377', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_entitlement_guid', 4, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '67025A2B-5C87-5A8F-9DAD-BB084609E871')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('67025A2B-5C87-5A8F-9DAD-BB084609E871', '5E1D1FFB-348A-5428-8781-197C8D4A0377', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_granted_context_guid', 5, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = 'A581E4CD-7553-5002-8C41-399441DDFDE0')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('A581E4CD-7553-5002-8C41-399441DDFDE0', '8CBE612B-6964-5CDC-90C3-E45B74223C02', '5E1D1FFB-348A-5428-8781-197C8D4A0377', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'INSERT INTO [dbo].[system_user_entitlements] ([key_guid], [ref_package_guid], [ref_user_guid], [ref_entitlement_guid], [ref_granted_context_guid], [pub_granted_on]) VALUES (?, ?, ?, ?, ?, SYSDATETIMEOFFSET())', NULL, NULL, 0, N'Grant one entitlement to one account, naming the context that granted it.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '6093E97A-99F1-5571-9FCA-A8BEBB5E3FDE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('6093E97A-99F1-5571-9FCA-A8BEBB5E3FDE', '6BF728D6-134F-5CFE-8259-8C979828765D', 'BDC50DB9-A78E-50B3-A3CD-CAC6F30AE53E', '5EA27403-9BA8-553A-9F0D-CC9E4D3132C8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'revoke', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models] WHERE [key_guid] = 'BE7B9943-5023-571E-AB7E-BCAA8D6F55A7')
INSERT INTO [etg].[contracts_db_operations_models] ([key_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('BE7B9943-5023-571E-AB7E-BCAA8D6F55A7', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'account_user_entitlements_revoke_input', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '97D138CC-E9BF-5ABD-8B53-7ED40FAF2F85')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('97D138CC-E9BF-5ABD-8B53-7ED40FAF2F85', 'BE7B9943-5023-571E-AB7E-BCAA8D6F55A7', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ref_revoked_context_guid', 1, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = 'AEE07A49-23AE-5909-93E0-288C5F271D25')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('AEE07A49-23AE-5909-93E0-288C5F271D25', 'BE7B9943-5023-571E-AB7E-BCAA8D6F55A7', '5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'key_guid', 2, 0, NULL, NULL, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] = '9D218C8F-7E54-5DBD-ADC1-2B66E10C9F24')
INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes]) VALUES ('9D218C8F-7E54-5DBD-ADC1-2B66E10C9F24', '6093E97A-99F1-5571-9FCA-A8BEBB5E3FDE', 'BE7B9943-5023-571E-AB7E-BCAA8D6F55A7', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'UPDATE [sue] SET [sue].[pub_revoked_on] = SYSDATETIMEOFFSET(), [sue].[ref_revoked_context_guid] = ?, [sue].[priv_modified_on] = SYSDATETIMEOFFSET() FROM [dbo].[system_user_entitlements] AS [sue] WHERE [sue].[key_guid] = ? AND [sue].[pub_revoked_on] IS NULL', NULL, NULL, 0, N'Revoke one entitlement grant by key, naming the context that revoked it. The row stays.');
GO


-- =====================================================================
-- Batch 11: pub_email on system_users (Aaron 2026-11-01: v2 account_users.element_email translates to pub_email; "Yes, add
-- it"). Appended by ALTER, since batch 5 is applied (the installer then carries it last, as pub_exclude_element and
-- pub_seed_element are). NULL for people whose provider gives none; the three automation accounts carry
-- contact@elideusgroup.com for now (Aaron 2026-11-01: a managed identity comes with organizations and Entra tenants). The
-- two account:users operations and
-- their models follow: read_all returns it, create takes it as its sixth parameter. Guarded on the column text so a
-- re-run changes nothing.
-- =====================================================================
IF COL_LENGTH(N'[dbo].[system_users]', N'pub_email') IS NULL
ALTER TABLE [dbo].[system_users] ADD [pub_email] NVARCHAR(256) NULL;
GO
UPDATE [dbo].[system_users] SET [pub_email] = N'contact@elideusgroup.com', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] IN ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207') AND [pub_email] IS NULL;
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'SELECT [su].[key_guid], [su].[ref_kind_enum_guid], [su].[pub_display], [su].[pub_is_enabled], [su].[pub_email] FROM [dbo].[system_users] AS [su] ORDER BY [su].[pub_display] FOR JSON PATH, INCLUDE_NULL_VALUES', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'F3EE6C56-24BE-5D50-974A-2FDAEC306731' AND [pub_query_mssql] NOT LIKE N'%pub_email%';
UPDATE [etg].[contracts_db_operations] SET [pub_query_mssql] = N'INSERT INTO [dbo].[system_users] ([key_guid], [ref_package_guid], [ref_kind_enum_guid], [pub_display], [pub_is_enabled], [pub_email]) VALUES (?, ?, ?, ?, ?, ?)', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = 'EDA82594-EBF7-596B-8CA7-CC069CEEA4FB' AND [pub_query_mssql] NOT LIKE N'%pub_email%';
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '7AA9DB95-CBA7-5453-84E2-77DDE27211F3')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('7AA9DB95-CBA7-5453-84E2-77DDE27211F3', '530B06E0-6258-5261-8573-1A207971CD4B', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_email', 5, 1, NULL, 256, 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations_models_fields] WHERE [key_guid] = '9EC6FA4B-09DE-546D-8078-BEA15280589E')
INSERT INTO [etg].[contracts_db_operations_models_fields] ([key_guid], [ref_model_guid], [ref_type_guid], [ref_package_guid], [pub_name], [pub_ordinal], [pub_is_nullable], [pub_default_value], [pub_max_length], [pub_exclude_element]) VALUES ('9EC6FA4B-09DE-546D-8078-BEA15280589E', 'D962613C-4F39-54B4-A6DC-B76BD580E11E', 'C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'pub_email', 6, 1, NULL, 256, 0);
GO


-- =====================================================================
-- Version: the database is now at kernel 0.2.1
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_urn_domains]', N'ref_namespace_guid') IS NULL
   AND COL_LENGTH(N'[etg].[contracts_urn_subdomains]', N'ref_domain_guid') IS NULL
   AND COL_LENGTH(N'[etg].[contracts_urn_functions]', N'ref_domain_guid') IS NOT NULL
   AND OBJECT_ID(N'[etg].[contracts_urn_domains_MIGRATION]', N'U') IS NULL
   AND OBJECT_ID(N'[etg].[contracts_urn_subdomains_MIGRATION]', N'U') IS NULL
   AND OBJECT_ID(N'[etg].[contracts_urn_functions_MIGRATION]', N'U') IS NULL
   AND EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cdo_function')
   AND OBJECT_ID(N'[etg].[contracts_urn_namespace_namespaces]', N'U') IS NULL
   AND OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NULL
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'))
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_domains]) = 14
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_subdomains]) = 18
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_functions]) >= 73
   AND EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '64CDFFD3-70D2-5405-ACE9-C1572F4823E3')
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_domain_roles]) = 18
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_subdomain_entitlements]) = 18
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] AS [cud] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] AS [cudr] WHERE [cudr].[ref_domain_guid] = [cud].[key_guid]))
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] AS [cus] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] AS [cuse] WHERE [cuse].[ref_subdomain_guid] = [cus].[key_guid]))
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] AS [cdo] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] AS [cuf] WHERE [cuf].[key_guid] = [cdo].[ref_function_guid]))
   AND OBJECT_ID(N'[dbo].[system_users]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[system_user_roles]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[system_user_entitlements]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[system_security_contexts]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[system_security_denials]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[service_audit_tables]', N'U') IS NOT NULL
   AND OBJECT_ID(N'[dbo].[system_audit_transactions]', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '0CC79EA9-C590-5A1E-9038-75D264F5BEDC')
   AND EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '24AEF840-A87E-5B32-81D9-26E8BFC1F482')
   AND (SELECT COUNT(*) FROM [dbo].[service_security_role_groups] WHERE [ref_group_guid] = '0CC79EA9-C590-5A1E-9038-75D264F5BEDC') = 17
   AND (SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207')) = 3
   AND EXISTS (SELECT 1 FROM [dbo].[system_security_contexts] WHERE [key_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59')
   AND (SELECT COUNT(*) FROM [dbo].[system_user_roles] WHERE [ref_granted_context_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59') = 5
   AND COLUMNPROPERTY(OBJECT_ID(N'[dbo].[service_workflow_definitions]'), N'ref_actor_guid', N'AllowsNull') = 0
   AND COL_LENGTH(N'[dbo].[system_workflow_history]', N'ref_user_guid') IS NULL
   AND (SELECT COUNT(*) FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] IN ('44EAB4BA-5937-5F90-8143-213C306AB08E', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '19F0846A-4C48-5430-8449-2FAE34791294', '064879DE-A840-5EF8-8939-E86A2CF8D69B')) = 5
   AND (SELECT COUNT(*) FROM [etg].[contracts_primitives_enums] WHERE [key_guid] IN ('C12C3474-7CC8-537F-8BD8-94F86B636D6A', '66CAABF3-BA45-5417-BB15-BA59D16054FE', '46BF744F-5E16-5A8A-B16A-7C7F8F9C7253', 'F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD', 'B4D703DC-27CB-503E-A9B5-BD64FD3D67DB', 'AC70897E-0052-51E6-9581-C658E91E6E1D', '30C42C94-D7CA-5A8B-9231-97E28C4B4065', '1423E34D-C5EF-5E09-9303-8C6EEE569D5D', 'C45DA709-B053-54A9-8933-6EE2504C5747', 'FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC', 'CCDA2282-BDC2-5A3C-8378-D0403FB9F05A', 'BE46F5F2-C245-56F8-AB6B-BC263D0DBAA6', 'E0BB0DF2-D1F4-52FE-ACF1-F9C884252E64', '310E2BCC-4890-5FDD-B1E7-558E5372BF20', 'B6E34B8A-DE76-5E18-9A8E-AB65A159C5B4', 'C69BDFCB-6AD5-568B-815C-BC06DB43B19B', 'DB9904DD-A011-5FD5-A6BC-E8518750B09A', 'E4F78513-0BF7-545F-A5E5-42BFB845893E', '5F6E0F13-4804-594B-9F2C-F662F0BD68E3', '9A534DC0-3083-55DF-A5A0-727EDEEAC090', 'CA80FA79-BB9D-5FE9-A599-EE4617363A62', 'DCDC215E-188B-5C3D-BD66-6E3C8CE9BC4F', '600C3293-DEA9-56B9-9D36-6C25E81510FC', 'A8EC52A6-F222-519B-894C-843AAB11C909')) = 24
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('AADDD6B6-01B9-5BAB-8B28-2171DD992D08', '716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '55796AF7-347D-574E-886A-0278B09C6541', '4CE0362E-F0B2-5A3A-B548-F4A61B58654C', 'E461D260-D882-5222-9D22-95D25B8BF2EE', '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '7C38CD25-80C9-507B-A290-CAFC5818DD23', '91F687BF-14D1-5101-9986-A324015C2B46'))
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('74AF9DA8-0836-59E8-97DF-5DD5BD391747', '9C5A2173-ED08-57A8-AA91-DE7DEA3D9260', 'CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB', '8C8FBDFE-8F51-508F-B25D-538B914B1BA6', 'FF048465-6B16-5768-B4B7-6D1915C136B0', 'C747AAEA-A706-5180-AB43-51F1C55EB6B5', '8CBE612B-6964-5CDC-90C3-E45B74223C02', '6093E97A-99F1-5571-9FCA-A8BEBB5E3FDE')) = 8
   AND COL_LENGTH(N'[dbo].[system_users]', N'pub_email') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] IN ('F3EE6C56-24BE-5D50-974A-2FDAEC306731', 'EDA82594-EBF7-596B-8CA7-CC069CEEA4FB') AND [pub_query_mssql] NOT LIKE N'%pub_email%')
   AND (SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207') AND [pub_email] IS NOT NULL) = 3
   AND (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.2.0', '0.2.1')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.2.1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.2.1', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
ELSE
BEGIN
  DECLARE @failed NVARCHAR(400) = NULL;
  IF @failed IS NULL AND NOT (COL_LENGTH(N'[etg].[contracts_urn_domains]', N'ref_namespace_guid') IS NULL) SET @failed = N'guard 1: COL_LENGTH(N''[etg].[contracts_urn_domains]'', N''ref_namespace_guid'') IS NULL';
  IF @failed IS NULL AND NOT (COL_LENGTH(N'[etg].[contracts_urn_subdomains]', N'ref_domain_guid') IS NULL) SET @failed = N'guard 2: COL_LENGTH(N''[etg].[contracts_urn_subdomains]'', N''ref_domain_guid'') IS NULL';
  IF @failed IS NULL AND NOT (COL_LENGTH(N'[etg].[contracts_urn_functions]', N'ref_domain_guid') IS NOT NULL) SET @failed = N'guard 3: COL_LENGTH(N''[etg].[contracts_urn_functions]'', N''ref_domain_guid'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[etg].[contracts_urn_domains_MIGRATION]', N'U') IS NULL) SET @failed = N'guard 4: OBJECT_ID(N''[etg].[contracts_urn_domains_MIGRATION]'', N''U'') IS NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[etg].[contracts_urn_subdomains_MIGRATION]', N'U') IS NULL) SET @failed = N'guard 5: OBJECT_ID(N''[etg].[contracts_urn_subdomains_MIGRATION]'', N''U'') IS NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[etg].[contracts_urn_functions_MIGRATION]', N'U') IS NULL) SET @failed = N'guard 6: OBJECT_ID(N''[etg].[contracts_urn_functions_MIGRATION]'', N''U'') IS NULL';
  IF @failed IS NULL AND NOT (EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cdo_function')) SET @failed = N'guard 7: EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N''FK_cdo_function'')';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[etg].[contracts_urn_namespace_namespaces]', N'U') IS NULL) SET @failed = N'guard 8: OBJECT_ID(N''[etg].[contracts_urn_namespace_namespaces]'', N''U'') IS NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NULL) SET @failed = N'guard 9: OBJECT_ID(N''[dbo].[service_security_namespaces]'', N''U'') IS NULL';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] IN ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B'))) SET @failed = N'guard 10: NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] IN (''A2A7F203-CB71-5C3E-801A-6B8BB01C691D'', ''AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B''))';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_domains]) = 14) SET @failed = N'guard 11: (SELECT COUNT(*) FROM [etg].[contracts_urn_domains]) = 14';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_subdomains]) = 18) SET @failed = N'guard 12: (SELECT COUNT(*) FROM [etg].[contracts_urn_subdomains]) = 18';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_functions]) >= 73) SET @failed = N'guard 13: (SELECT COUNT(*) FROM [etg].[contracts_urn_functions]) >= 73';
  IF @failed IS NULL AND NOT (EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '64CDFFD3-70D2-5405-ACE9-C1572F4823E3')) SET @failed = N'guard 14: EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = ''64CDFFD3-70D2-5405-ACE9-C1572F4823E3'')';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_domain_roles]) = 18) SET @failed = N'guard 15: (SELECT COUNT(*) FROM [etg].[contracts_urn_domain_roles]) = 18';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_subdomain_entitlements]) = 18) SET @failed = N'guard 16: (SELECT COUNT(*) FROM [etg].[contracts_urn_subdomain_entitlements]) = 18';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] AS [cud] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] AS [cudr] WHERE [cudr].[ref_domain_guid] = [cud].[key_guid]))) SET @failed = N'guard 17: NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] AS [cud] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] AS [cudr] WHERE [cudr].[ref_domain_guid] = [cud].[key_guid]))';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] AS [cus] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] AS [cuse] WHERE [cuse].[ref_subdomain_guid] = [cus].[key_guid]))) SET @failed = N'guard 18: NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] AS [cus] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomain_entitlements] AS [cuse] WHERE [cuse].[ref_subdomain_guid] = [cus].[key_guid]))';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] AS [cdo] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] AS [cuf] WHERE [cuf].[key_guid] = [cdo].[ref_function_guid]))) SET @failed = N'guard 19: NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] AS [cdo] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] AS [cuf] WHERE [cuf].[key_guid] = [cdo].[ref_function_guid]))';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_users]', N'U') IS NOT NULL) SET @failed = N'guard 20: OBJECT_ID(N''[dbo].[system_users]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_user_roles]', N'U') IS NOT NULL) SET @failed = N'guard 21: OBJECT_ID(N''[dbo].[system_user_roles]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_user_entitlements]', N'U') IS NOT NULL) SET @failed = N'guard 22: OBJECT_ID(N''[dbo].[system_user_entitlements]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_security_contexts]', N'U') IS NOT NULL) SET @failed = N'guard 23: OBJECT_ID(N''[dbo].[system_security_contexts]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_security_denials]', N'U') IS NOT NULL) SET @failed = N'guard 24: OBJECT_ID(N''[dbo].[system_security_denials]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[service_audit_tables]', N'U') IS NOT NULL) SET @failed = N'guard 25: OBJECT_ID(N''[dbo].[service_audit_tables]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (OBJECT_ID(N'[dbo].[system_audit_transactions]', N'U') IS NOT NULL) SET @failed = N'guard 26: OBJECT_ID(N''[dbo].[system_audit_transactions]'', N''U'') IS NOT NULL';
  IF @failed IS NULL AND NOT (EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '0CC79EA9-C590-5A1E-9038-75D264F5BEDC')) SET @failed = N'guard 27: EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = ''0CC79EA9-C590-5A1E-9038-75D264F5BEDC'')';
  IF @failed IS NULL AND NOT (EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = '24AEF840-A87E-5B32-81D9-26E8BFC1F482')) SET @failed = N'guard 28: EXISTS (SELECT 1 FROM [dbo].[service_security_roles] WHERE [key_guid] = ''24AEF840-A87E-5B32-81D9-26E8BFC1F482'')';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [dbo].[service_security_role_groups] WHERE [ref_group_guid] = '0CC79EA9-C590-5A1E-9038-75D264F5BEDC') = 17) SET @failed = N'guard 29: (SELECT COUNT(*) FROM [dbo].[service_security_role_groups] WHERE [ref_group_guid] = ''0CC79EA9-C590-5A1E-9038-75D264F5BEDC'') = 17';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207')) = 3) SET @failed = N'guard 30: (SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN (''3A96CDC2-F5C4-5AC5-AD6C-065C1936F273'', ''D7E1862B-25CD-50A1-8A9F-FF7911C26EAD'', ''F9A4F9EA-743E-5E17-95F0-E0280D6DA207'')) = 3';
  IF @failed IS NULL AND NOT (EXISTS (SELECT 1 FROM [dbo].[system_security_contexts] WHERE [key_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59')) SET @failed = N'guard 31: EXISTS (SELECT 1 FROM [dbo].[system_security_contexts] WHERE [key_guid] = ''F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59'')';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [dbo].[system_user_roles] WHERE [ref_granted_context_guid] = 'F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59') = 5) SET @failed = N'guard 32: (SELECT COUNT(*) FROM [dbo].[system_user_roles] WHERE [ref_granted_context_guid] = ''F271C2CE-CBB4-5A7F-B006-48FFFA2F3D59'') = 5';
  IF @failed IS NULL AND NOT (COLUMNPROPERTY(OBJECT_ID(N'[dbo].[service_workflow_definitions]'), N'ref_actor_guid', N'AllowsNull') = 0) SET @failed = N'guard 33: COLUMNPROPERTY(OBJECT_ID(N''[dbo].[service_workflow_definitions]''), N''ref_actor_guid'', N''AllowsNull'') = 0';
  IF @failed IS NULL AND NOT (COL_LENGTH(N'[dbo].[system_workflow_history]', N'ref_user_guid') IS NULL) SET @failed = N'guard 34: COL_LENGTH(N''[dbo].[system_workflow_history]'', N''ref_user_guid'') IS NULL';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] IN ('44EAB4BA-5937-5F90-8143-213C306AB08E', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '19F0846A-4C48-5430-8449-2FAE34791294', '064879DE-A840-5EF8-8939-E86A2CF8D69B')) = 5) SET @failed = N'guard 35: (SELECT COUNT(*) FROM [etg].[contracts_primitives_enum_types] WHERE [key_guid] IN (''44EAB4BA-5937-5F90-8143-213C306AB08E'', ''75CDADC0-7A2F-582D-9580-E67CB5B4CCA1'', ''718550F0-C6E9-5D96-B2B6-EC03C753E627'', ''19F0846A-4C48-5430-8449-2FAE34791294'', ''064879DE-A840-5EF8-8939-E86A2CF8D69B'')) = 5';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_primitives_enums] WHERE [key_guid] IN ('C12C3474-7CC8-537F-8BD8-94F86B636D6A', '66CAABF3-BA45-5417-BB15-BA59D16054FE', '46BF744F-5E16-5A8A-B16A-7C7F8F9C7253', 'F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD', 'B4D703DC-27CB-503E-A9B5-BD64FD3D67DB', 'AC70897E-0052-51E6-9581-C658E91E6E1D', '30C42C94-D7CA-5A8B-9231-97E28C4B4065', '1423E34D-C5EF-5E09-9303-8C6EEE569D5D', 'C45DA709-B053-54A9-8933-6EE2504C5747', 'FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC', 'CCDA2282-BDC2-5A3C-8378-D0403FB9F05A', 'BE46F5F2-C245-56F8-AB6B-BC263D0DBAA6', 'E0BB0DF2-D1F4-52FE-ACF1-F9C884252E64', '310E2BCC-4890-5FDD-B1E7-558E5372BF20', 'B6E34B8A-DE76-5E18-9A8E-AB65A159C5B4', 'C69BDFCB-6AD5-568B-815C-BC06DB43B19B', 'DB9904DD-A011-5FD5-A6BC-E8518750B09A', 'E4F78513-0BF7-545F-A5E5-42BFB845893E', '5F6E0F13-4804-594B-9F2C-F662F0BD68E3', '9A534DC0-3083-55DF-A5A0-727EDEEAC090', 'CA80FA79-BB9D-5FE9-A599-EE4617363A62', 'DCDC215E-188B-5C3D-BD66-6E3C8CE9BC4F', '600C3293-DEA9-56B9-9D36-6C25E81510FC', 'A8EC52A6-F222-519B-894C-843AAB11C909')) = 24) SET @failed = N'guard 36: (SELECT COUNT(*) FROM [etg].[contracts_primitives_enums] WHERE [key_guid] IN (''C12C3474-7CC8-537F-8BD8-94F86B636D6A'', ''66CAABF3-BA45-5417-BB15-BA59D16054FE'', ''46BF744F-5E16-5A8A-B16A-7C7F8F9C7253'', ''F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD'', ''B4D703DC-27CB-503E-A9B5-BD64FD3D67DB'', ''AC70897E-0';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('AADDD6B6-01B9-5BAB-8B28-2171DD992D08', '716BABC5-F63B-58EE-BD9A-FEA6430E2F31', '55796AF7-347D-574E-886A-0278B09C6541', '4CE0362E-F0B2-5A3A-B548-F4A61B58654C', 'E461D260-D882-5222-9D22-95D25B8BF2EE', '345BC92E-FF7F-59CF-80AF-2B7EB93D0D9A', '7C38CD25-80C9-507B-A290-CAFC5818DD23', '91F687BF-14D1-5101-9986-A324015C2B46'))) SET @failed = N'guard: NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN (''AADDD6B6-01B9-5BAB-8B28-2171DD992D08'', ''716BABC5-F63B-58EE-BD9A-FEA6430E2F31'', ''55796AF7-347D-574E-886A-0278B09C6541'', ''4CE0362E-F0B2-5A3A-B548-F4A61B58654C'', ''E461D260-D882-5222-9D22-95D25B8BF2EE'', ''345BC92E-';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN ('74AF9DA8-0836-59E8-97DF-5DD5BD391747', '9C5A2173-ED08-57A8-AA91-DE7DEA3D9260', 'CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB', '8C8FBDFE-8F51-508F-B25D-538B914B1BA6', 'FF048465-6B16-5768-B4B7-6D1915C136B0', 'C747AAEA-A706-5180-AB43-51F1C55EB6B5', '8CBE612B-6964-5CDC-90C3-E45B74223C02', '6093E97A-99F1-5571-9FCA-A8BEBB5E3FDE')) = 8) SET @failed = N'guard: (SELECT COUNT(*) FROM [etg].[contracts_urn_functions] WHERE [key_guid] IN (''74AF9DA8-0836-59E8-97DF-5DD5BD391747'', ''9C5A2173-ED08-57A8-AA91-DE7DEA3D9260'', ''CAE35DA0-2B4E-59BA-AAB5-0C1F4C5524EB'', ''8C8FBDFE-8F51-508F-B25D-538B914B1BA6'', ''FF048465-6B16-5768-B4B7-6D1915C136B0'', ''C747AAEA-A706';
  IF @failed IS NULL AND NOT (COL_LENGTH(N'[dbo].[system_users]', N'pub_email') IS NOT NULL) SET @failed = N'guard: COL_LENGTH(N''[dbo].[system_users]'', N''pub_email'') IS NOT NULL';
  IF @failed IS NULL AND NOT (NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] IN ('F3EE6C56-24BE-5D50-974A-2FDAEC306731', 'EDA82594-EBF7-596B-8CA7-CC069CEEA4FB') AND [pub_query_mssql] NOT LIKE N'%pub_email%')) SET @failed = N'guard: NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] WHERE [key_guid] IN (''F3EE6C56-24BE-5D50-974A-2FDAEC306731'', ''EDA82594-EBF7-596B-8CA7-CC069CEEA4FB'') AND [pub_query_mssql] NOT LIKE N''%pub_email%'')';
  IF @failed IS NULL AND NOT ((SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN ('3A96CDC2-F5C4-5AC5-AD6C-065C1936F273', 'D7E1862B-25CD-50A1-8A9F-FF7911C26EAD', 'F9A4F9EA-743E-5E17-95F0-E0280D6DA207') AND [pub_email] IS NOT NULL) = 3) SET @failed = N'guard: (SELECT COUNT(*) FROM [dbo].[system_users] WHERE [key_guid] IN (''3A96CDC2-F5C4-5AC5-AD6C-065C1936F273'', ''D7E1862B-25CD-50A1-8A9F-FF7911C26EAD'', ''F9A4F9EA-743E-5E17-95F0-E0280D6DA207'') AND [pub_email] IS NOT NULL) = 3';
  IF @failed IS NULL AND NOT ((SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.2.0', '0.2.1')) SET @failed = N'guard 37: (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = ''518CD840-0D12-5601-84EF-87FA6FA0E67F'') IN (''0.2.0'', ''0.2.1'')';
  IF @failed IS NULL SET @failed = N'unknown';
  DECLARE @msg NVARCHAR(500) = N'v0.2.1: the version tail did not run; ' + @failed;
  THROW 50000, @msg, 1;
END
GO
