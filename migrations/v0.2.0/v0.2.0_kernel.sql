-- v0.2.0_kernel.sql: the 0.1.9 -> 0.2.0 gap. Idempotent: every statement is guarded, every row by key.
-- The URN registry (Aaron 2026-10-27/28/29): a URN string can exist only as a chain of rows. Four schema layers in etg:
-- contracts_urn_namespaces (db, urn today; api, mcp and others later) -> _domains -> _subdomains -> _functions (+ version).
-- Three security catalogues in dbo, one per gated layer: service_security_namespaces (NEW, the shape of roles),
-- service_security_roles, service_security_entitlements. Three mapping tables bind each layer to its catalogue, many-to-many:
-- contracts_urn_namespace_namespaces, contracts_urn_domain_roles, contracts_urn_subdomain_entitlements. No rows on a layer =
-- no gate at that layer (every layer of the db namespace today). The chain's FKs are NO ACTION like every other etg child
-- table (the package FK is the one CASCADE, as elsewhere; a CASCADE chain would be a second cascade path from the package).
-- SUPERSEDED THE SAME DAY by v0.2.1 (Aaron: domains, subdomains and namespaces are unique on name; this chain shape seeded
-- three duplicate domain rows). This file stays as applied; v0.2.1_kernel.sql carries the correction.
-- etg.contracts_db_operations is REBUILT (_MIGRATION copy, Aaron 2026-10-13): pub_op is DROPPED (the URN is derived from the
-- chain, one representation per concept), ref_function_guid NOT NULL UNIQUE -> contracts_urn_functions is ADDED (one query
-- serves one function; the function knows no SQL), and the two model columns appended in 0.1.x move into declared order.
-- The 54 operation rows keep their keys: uuid5(NS, 'contracts_db_operations:' + urn) is unchanged.
-- Seed: 2 schema namespaces (kernel-owned; db dispatched by DatabaseOperationsModule) and 2 security namespaces
-- (core-owned, no mapping rows yet: both namespaces open at that layer); the db chain decomposed from the 54 ops (6 domains,
-- 11 subdomains, 54 functions, each row owned by its op's package); the urn namespace's 10 domains (the production v2 RPC
-- domain vocabulary + public) with one role each in contracts_urn_domain_roles. No urn subdomain or function yet: the RPC
-- modules are a later slice.
-- The kernel lookup (DatabaseOperationsModule) composes the URN from the chain in its two bootstrap queries; lookup stays by
-- name (Aaron 2026-10-25). The Python code shipped in this release carries DATABASE_VERSION 0.2.0.
-- APPLY WITH THE APPLICATION STOPPED. After applying, boot, then populate: it reflects the eight new tables and the rebuilt
-- operations table (its new column and constraints) and MERGEs the declaration rows this script inserts. Populate never
-- deletes, so this script removes the pub_op column declaration and the UQ_cdo_op constraint declaration itself.
-- The version tail runs only when the eight tables exist, every operation row has a function, pub_op is gone, the copy is
-- gone, and the database is at 0.1.9 (or already 0.2.0), so a re-run against a later version never moves the version
-- backwards.
-- Moves the database version to 0.2.0.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Tables: the security namespace catalogue (the shape of service_security_roles), then the URN registry
-- =====================================================================
IF OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NULL
CREATE TABLE [dbo].[service_security_namespaces] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_namespaces]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_namespaces] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(16) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_namespace_namespaces]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_namespace_namespaces] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_namespace_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_security_namespace_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_domains]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_domains] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_namespace_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_domain_roles]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_domain_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_domain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_role_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_subdomains]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_subdomains] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_domain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_subdomain_entitlements]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_subdomain_entitlements] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_subdomain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_entitlement_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
IF OBJECT_ID(N'[etg].[contracts_urn_functions]', N'U') IS NULL
CREATE TABLE [etg].[contracts_urn_functions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_subdomain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_function_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_version] TINYINT DEFAULT (1) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
GO

-- =====================================================================
-- Constraints (PRIMARY KEY, UNIQUE)
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_service_security_namespaces' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_security_namespaces] ADD CONSTRAINT [PK_service_security_namespaces] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_ssn_name' AND schema_id = SCHEMA_ID(N'dbo'))
ALTER TABLE [dbo].[service_security_namespaces] ADD CONSTRAINT [UQ_ssn_name] UNIQUE NONCLUSTERED ([pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_namespaces' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [PK_contracts_urn_namespaces] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cun_name' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [UQ_cun_name] UNIQUE NONCLUSTERED ([pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_namespace_namespaces' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_namespace_namespaces] ADD CONSTRAINT [PK_contracts_urn_namespace_namespaces] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cunn_namespace_security_namespace' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_namespace_namespaces] ADD CONSTRAINT [UQ_cunn_namespace_security_namespace] UNIQUE NONCLUSTERED ([ref_namespace_guid], [ref_security_namespace_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_domains' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [PK_contracts_urn_domains] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cud_namespace_name' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [UQ_cud_namespace_name] UNIQUE NONCLUSTERED ([ref_namespace_guid], [pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_domain_roles' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [PK_contracts_urn_domain_roles] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cudr_domain_role' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [UQ_cudr_domain_role] UNIQUE NONCLUSTERED ([ref_domain_guid], [ref_role_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_subdomains' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [PK_contracts_urn_subdomains] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cus_domain_name' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [UQ_cus_domain_name] UNIQUE NONCLUSTERED ([ref_domain_guid], [pub_name]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_subdomain_entitlements' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [PK_contracts_urn_subdomain_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cuse_subdomain_entitlement' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [UQ_cuse_subdomain_entitlement] UNIQUE NONCLUSTERED ([ref_subdomain_guid], [ref_entitlement_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_contracts_urn_functions' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [PK_contracts_urn_functions] PRIMARY KEY CLUSTERED ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_cuf_subdomain_name_version' AND schema_id = SCHEMA_ID(N'etg'))
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [UQ_cuf_subdomain_name_version] UNIQUE NONCLUSTERED ([ref_subdomain_guid], [pub_name], [pub_version]);
GO

-- =====================================================================
-- Constraints (FOREIGN KEY): package CASCADE as everywhere; the chain and the links into modules and security NO ACTION
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ssn_package')
ALTER TABLE [dbo].[service_security_namespaces] ADD CONSTRAINT [FK_ssn_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cun_module')
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [FK_cun_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cun_package')
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [FK_cun_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cunn_namespace')
ALTER TABLE [etg].[contracts_urn_namespace_namespaces] ADD CONSTRAINT [FK_cunn_namespace] FOREIGN KEY ([ref_namespace_guid]) REFERENCES [etg].[contracts_urn_namespaces] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cunn_security_namespace')
ALTER TABLE [etg].[contracts_urn_namespace_namespaces] ADD CONSTRAINT [FK_cunn_security_namespace] FOREIGN KEY ([ref_security_namespace_guid]) REFERENCES [dbo].[service_security_namespaces] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cunn_package')
ALTER TABLE [etg].[contracts_urn_namespace_namespaces] ADD CONSTRAINT [FK_cunn_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cud_namespace')
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_namespace] FOREIGN KEY ([ref_namespace_guid]) REFERENCES [etg].[contracts_urn_namespaces] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cud_module')
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cud_package')
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cudr_domain')
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cudr_role')
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_role] FOREIGN KEY ([ref_role_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cudr_package')
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cus_domain')
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cus_module')
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cus_package')
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuse_subdomain')
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuse_entitlement')
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_entitlement] FOREIGN KEY ([ref_entitlement_guid]) REFERENCES [dbo].[service_security_entitlements] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuse_package')
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuf_subdomain')
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuf_module_function')
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_module_function] FOREIGN KEY ([ref_module_function_guid]) REFERENCES [etg].[contracts_modules_functions] ([key_guid]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_cuf_package')
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
GO

-- =====================================================================
-- Seed: the security namespace catalogue (core-owned, like roles and entitlements). Keys 'service_security_namespaces:<NAME>'
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_namespaces] WHERE [key_guid] = 'ADBE9128-22E8-5528-83D5-8D8AC8383B95')
INSERT INTO [dbo].[service_security_namespaces] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('ADBE9128-22E8-5528-83D5-8D8AC8383B95', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'NAMESPACE_DB', N'Database operations', N'Grants the db: namespace. Internal; no account holds it today.');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_security_namespaces] WHERE [key_guid] = 'DA985EFA-E67A-5293-BF45-14254E3D82E8')
INSERT INTO [dbo].[service_security_namespaces] ([key_guid], [ref_package_guid], [pub_name], [pub_display], [pub_notes]) VALUES ('DA985EFA-E67A-5293-BF45-14254E3D82E8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'NAMESPACE_URN', N'RPC', N'Grants the urn: namespace, the public RPC surface.');
GO

-- =====================================================================
-- Seed: schema namespaces (kernel-owned; db is dispatched by DatabaseOperationsModule, urn's dispatcher is a later slice).
-- No contracts_urn_namespace_namespaces rows: both namespaces are open at this layer until a grant is ruled.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_namespaces] WHERE [key_guid] = '6BF728D6-134F-5CFE-8259-8C979828765D')
INSERT INTO [etg].[contracts_urn_namespaces] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6BF728D6-134F-5CFE-8259-8C979828765D', 'C17B5152-F788-58C6-A441-E116F651F906', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'db', N'db:<domain>:<subdomain>:<function>:<version>. The database operation namespace, dispatched by DatabaseOperationsModule; organised by the database''s abstract purpose.');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_namespaces] WHERE [key_guid] = 'A906033F-FF02-5050-9DF3-512D08DBE069')
INSERT INTO [etg].[contracts_urn_namespaces] ([key_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A906033F-FF02-5050-9DF3-512D08DBE069', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'urn', N'urn:<domain>:<subdomain>:<function>:<version>. The RPC namespace, the one public entry point; organised by functional area: domain grants by role, subdomain grants by entitlement.');
GO

-- =====================================================================
-- Seed: domains. db: the 6 domains the 54 ops decompose into, each owned by its ops' package. urn: the 10 RPC domains
-- (production v2 vocabulary + public), core-owned; no dispatch module yet
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '6537D05F-BE38-51E0-8B18-CE6BE1384BFB')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6537D05F-BE38-51E0-8B18-CE6BE1384BFB', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'contracts', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '11178C25-0CE0-5A5C-B014-B2DD5C37DD8E')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('11178C25-0CE0-5A5C-B014-B2DD5C37DD8E', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'discord', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'EF889036-47BD-5318-BEAD-DABA35237A71')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('EF889036-47BD-5318-BEAD-DABA35237A71', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'security', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '15BDB521-E006-5AC0-9F5D-993548BF7833')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('15BDB521-E006-5AC0-9F5D-993548BF7833', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'service', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '61A766FC-99BC-53BA-9C9A-F747D6F3EFCA')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('61A766FC-99BC-53BA-9C9A-F747D6F3EFCA', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'system', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '86AEC36D-F43C-5165-B4BB-D556DD4CE4D3')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('86AEC36D-F43C-5165-B4BB-D556DD4CE4D3', '6BF728D6-134F-5CFE-8259-8C979828765D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'workflow', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '5A2DF8DA-36DF-5EAE-8095-15DE9FD2D2D9')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5A2DF8DA-36DF-5EAE-8095-15DE9FD2D2D9', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'public', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '24BB4072-7799-5753-88D6-DB8D9F37F501')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('24BB4072-7799-5753-88D6-DB8D9F37F501', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'users', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'D9D2C4A2-C980-5F0E-8E2F-DA5B350A6A1F')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D9D2C4A2-C980-5F0E-8E2F-DA5B350A6A1F', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'storage', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '1A73030B-6B88-5B5F-BC48-CDB67EB27D0A')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('1A73030B-6B88-5B5F-BC48-CDB67EB27D0A', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'support', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '4B12A747-69F2-55C2-A697-905119FD9286')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('4B12A747-69F2-55C2-A697-905119FD9286', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'moderation', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '5CD6B3B5-F2D0-5F1F-BBFA-A1E5BCF88D25')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('5CD6B3B5-F2D0-5F1F-BBFA-A1E5BCF88D25', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'account', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'A31F99B3-8428-5E58-8192-076BD99BEB1A')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A31F99B3-8428-5E58-8192-076BD99BEB1A', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'system', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'B44F5278-2E43-59AF-9AB5-C94089770820')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('B44F5278-2E43-59AF-9AB5-C94089770820', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'service', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = '4F09A4F0-E71C-54FA-92F1-79F72DCD011A')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('4F09A4F0-E71C-54FA-92F1-79F72DCD011A', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'discord', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domains] WHERE [key_guid] = 'C1763C35-BA39-502D-AF99-986D21BE5F15')
INSERT INTO [etg].[contracts_urn_domains] ([key_guid], [ref_namespace_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('C1763C35-BA39-502D-AF99-986D21BE5F15', 'A906033F-FF02-5050-9DF3-512D08DBE069', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'finance', NULL);
GO

-- =====================================================================
-- Seed: domain roles. urn domains only: one role per domain (the v2 role -> rpc_domain link made a row). db domains carry
-- no role rows: no role gate at that layer. Keys 'contracts_urn_domain_roles:<ns>:<domain>.<ROLE_NAME>'
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '367A5156-7212-5981-A041-0E7854BC2693')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('367A5156-7212-5981-A041-0E7854BC2693', '5A2DF8DA-36DF-5EAE-8095-15DE9FD2D2D9', '755D78AC-3CF7-574A-9BCB-4B3BBD4EDD38', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'E9826379-38B5-5FFB-B8C3-D026DB239BDF')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('E9826379-38B5-5FFB-B8C3-D026DB239BDF', '24BB4072-7799-5753-88D6-DB8D9F37F501', 'D9ECA799-8D60-5436-9D59-817AB3E8CD62', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'CEB06FE4-94C8-50ED-866F-B2C4869721BC')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('CEB06FE4-94C8-50ED-866F-B2C4869721BC', 'D9D2C4A2-C980-5F0E-8E2F-DA5B350A6A1F', '8697410A-F3F9-5A58-84BA-A2215EA54F60', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '5227694F-29DB-5AB0-B078-CFF17EAAC656')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('5227694F-29DB-5AB0-B078-CFF17EAAC656', '1A73030B-6B88-5B5F-BC48-CDB67EB27D0A', 'B5533CBF-596D-58FE-9B88-379A2D608E53', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '6541C00B-2B80-548B-B45A-C85C8BF71DAF')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('6541C00B-2B80-548B-B45A-C85C8BF71DAF', '4B12A747-69F2-55C2-A697-905119FD9286', '89C75A3C-F893-5658-8CA4-6AB27D728BC1', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '37EAA200-D03F-5B96-94FF-F7BC362A504C')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('37EAA200-D03F-5B96-94FF-F7BC362A504C', '5CD6B3B5-F2D0-5F1F-BBFA-A1E5BCF88D25', 'F3762DBF-5F50-524B-838F-70A957E92DF2', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'AAF72AAF-A4C3-559D-BC05-358E0C54B5F4')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('AAF72AAF-A4C3-559D-BC05-358E0C54B5F4', 'A31F99B3-8428-5E58-8192-076BD99BEB1A', '29B18BB9-998C-57B1-9A22-48B315CC266D', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '0BB604F5-B255-5BFF-A40C-705D129FC0D5')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('0BB604F5-B255-5BFF-A40C-705D129FC0D5', 'B44F5278-2E43-59AF-9AB5-C94089770820', 'E96BDA1F-8876-5D4E-B697-1926ECD628CE', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = 'DCDA70AB-1ADB-562B-B81A-AB62DCF37B83')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('DCDA70AB-1ADB-562B-B81A-AB62DCF37B83', '4F09A4F0-E71C-54FA-92F1-79F72DCD011A', '5C607B13-539B-5586-AD39-31124298D0AF', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_domain_roles] WHERE [key_guid] = '496A6D4B-36E2-5504-92A9-596E4A8CE4A7')
INSERT INTO [etg].[contracts_urn_domain_roles] ([key_guid], [ref_domain_guid], [ref_role_guid], [ref_package_guid]) VALUES ('496A6D4B-36E2-5504-92A9-596E4A8CE4A7', 'C1763C35-BA39-502D-AF99-986D21BE5F15', '66A58CFD-8786-5D78-B874-1016E50471E5', 'F1954052-001D-5818-90DC-1953ADA7ABA1');
GO

-- =====================================================================
-- Seed: subdomains (db only; no processing module yet; no entitlement rows: every db subdomain is open at that layer)
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '180FCE45-A435-5B67-8979-3BDEB0853863')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('180FCE45-A435-5B67-8979-3BDEB0853863', '6537D05F-BE38-51E0-8B18-CE6BE1384BFB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'db', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'DB991268-B942-5620-879E-980CCA90BADA')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('DB991268-B942-5620-879E-980CCA90BADA', '6537D05F-BE38-51E0-8B18-CE6BE1384BFB', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'modules', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '20FFC9F9-63A9-5624-A9D2-4AD5211E7F00')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('20FFC9F9-63A9-5624-A9D2-4AD5211E7F00', '11178C25-0CE0-5A5C-B014-B2DD5C37DD8E', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'guilds', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '6EE8955F-65F5-5C58-9632-77CE0D34833C')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('6EE8955F-65F5-5C58-9632-77CE0D34833C', 'EF889036-47BD-5318-BEAD-DABA35237A71', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'entitlements', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'EDF738D1-5763-5211-8100-B74D0EF5FC6D')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('EDF738D1-5763-5211-8100-B74D0EF5FC6D', 'EF889036-47BD-5318-BEAD-DABA35237A71', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'role_groups', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'F3DB84F2-BE0C-5B81-9751-67F66A3514CA')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('F3DB84F2-BE0C-5B81-9751-67F66A3514CA', 'EF889036-47BD-5318-BEAD-DABA35237A71', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'roles', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '88178075-397F-58C8-AEA2-C972EE09A548')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('88178075-397F-58C8-AEA2-C972EE09A548', '15BDB521-E006-5AC0-9F5D-993548BF7833', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'host', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '1C9190AC-5C30-58EE-9271-A20B66768F5B')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('1C9190AC-5C30-58EE-9271-A20B66768F5B', '61A766FC-99BC-53BA-9C9A-F747D6F3EFCA', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'sequence', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'D1969D68-15D9-560E-AA83-B6D998B806B5')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('D1969D68-15D9-560E-AA83-B6D998B806B5', '86AEC36D-F43C-5165-B4BB-D556DD4CE4D3', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'definitions', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = 'A4E8DC50-D3CF-5FAA-8AE4-EA329A24EC02')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('A4E8DC50-D3CF-5FAA-8AE4-EA329A24EC02', '86AEC36D-F43C-5165-B4BB-D556DD4CE4D3', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'history', NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_subdomains] WHERE [key_guid] = '1E8A185E-59E2-5191-B6D8-45F64760D5B8')
INSERT INTO [etg].[contracts_urn_subdomains] ([key_guid], [ref_domain_guid], [ref_module_guid], [ref_package_guid], [pub_name], [pub_notes]) VALUES ('1E8A185E-59E2-5191-B6D8-45F64760D5B8', '86AEC36D-F43C-5165-B4BB-D556DD4CE4D3', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'queue', NULL);
GO

-- =====================================================================
-- Seed: functions, one per operation row (db functions have no module function: the query is the implementation)
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'A416ACE5-4A91-5E40-AD84-FBD93A60E62D')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('A416ACE5-4A91-5E40-AD84-FBD93A60E62D', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'check_physical_table_exists', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '44762E97-572F-5076-840E-2B0032449B32')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('44762E97-572F-5076-840E-2B0032449B32', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'check_table_has_package_column', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '63F78319-0561-5CF6-84F0-6840364FA9E0')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('63F78319-0561-5CF6-84F0-6840364FA9E0', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'delete_manifest_row', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '64E53DC2-C906-5934-9F42-A9EB44E83C7B')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('64E53DC2-C906-5934-9F42-A9EB44E83C7B', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'free_proc_cache', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8425F9A8-FEF4-5F7E-8712-97C999E48B0B')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8425F9A8-FEF4-5F7E-8712-97C999E48B0B', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_fks_on_column', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'EEE59114-D866-566B-90C2-2F4EC00268FA')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('EEE59114-D866-566B-90C2-2F4EC00268FA', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_indexes_on_column', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '90DD5D08-E905-52F9-B0FC-3BA0FB49144E')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('90DD5D08-E905-52F9-B0FC-3BA0FB49144E', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_manifest_rows', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '861A6671-02FE-5914-939B-42E6E0A07FCF')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('861A6671-02FE-5914-939B-42E6E0A07FCF', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_package_ext_columns', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'BF846684-E6AE-51F6-9A6A-2DEFE36B4A2B')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('BF846684-E6AE-51F6-9A6A-2DEFE36B4A2B', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_package_owned_tables', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'F1C7CFEC-8A08-53DA-AC3A-BB12AC5A2F14')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('F1C7CFEC-8A08-53DA-AC3A-BB12AC5A2F14', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_physical_tables', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'FC40F80A-8B81-5CC3-9DF5-9B7C246D2B53')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('FC40F80A-8B81-5CC3-9DF5-9B7C246D2B53', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'list_physical_tables_with_package_column', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '4FF85F00-9996-534D-89A2-FE21B41765EC')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('4FF85F00-9996-534D-89A2-FE21B41765EC', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_columns', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'D6220071-AB8D-57AA-9EBE-74B7E3B31EFD')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('D6220071-AB8D-57AA-9EBE-74B7E3B31EFD', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_constraint_columns', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '113D0C60-27C7-5D74-8824-5EF0F294159C')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('113D0C60-27C7-5D74-8824-5EF0F294159C', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_constraints', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'EFE4A4C7-4797-5A0A-B0AE-78EFECD058E8')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('EFE4A4C7-4797-5A0A-B0AE-78EFECD058E8', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_index_columns', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '573EDBA8-785F-5543-AC83-4E7A2B77F337')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('573EDBA8-785F-5543-AC83-4E7A2B77F337', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_indexes', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'DBC3CC85-4A8D-5376-8AC4-7DD6019D1FD6')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('DBC3CC85-4A8D-5376-8AC4-7DD6019D1FD6', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_seed_column_projection', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'A38769CF-DFD5-5A10-8781-8C44050FFF88')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('A38769CF-DFD5-5A10-8781-8C44050FFF88', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_seed_table_list', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'E71776EE-65EA-52E1-B769-B76BBB45F5EF')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('E71776EE-65EA-52E1-B769-B76BBB45F5EF', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_tables', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '47B2E532-9644-5507-8D02-4D547E844000')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('47B2E532-9644-5507-8D02-4D547E844000', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'set_manifest_sealed', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '10DC50BE-3C4C-57D2-97D1-AA46FEBE4AB3')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('10DC50BE-3C4C-57D2-97D1-AA46FEBE4AB3', '180FCE45-A435-5B67-8979-3BDEB0853863', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'update_statistics', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '189C5FBF-19FC-58F1-9478-E2FA4F206C32')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('189C5FBF-19FC-58F1-9478-E2FA4F206C32', 'DB991268-B942-5620-879E-980CCA90BADA', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8E7761B8-CF80-55FB-B9C2-D751C5DEEF51')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8E7761B8-CF80-55FB-B9C2-D751C5DEEF51', '20FFC9F9-63A9-5624-A9D2-4AD5211E7F00', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'mark_left', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '9C0A0A37-F66A-57A0-8148-F02D471A2B2C')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('9C0A0A37-F66A-57A0-8148-F02D471A2B2C', '20FFC9F9-63A9-5624-A9D2-4AD5211E7F00', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'C3AA335C-9378-549C-88F1-6F3118799221')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('C3AA335C-9378-549C-88F1-6F3118799221', '20FFC9F9-63A9-5624-A9D2-4AD5211E7F00', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'upsert', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'D637B526-C9C6-5D32-A90D-3FDFC3B1654E')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('D637B526-C9C6-5D32-A90D-3FDFC3B1654E', '6EE8955F-65F5-5C58-9632-77CE0D34833C', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'E2EFFAB2-575E-55A3-86B4-E8630CA51934')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('E2EFFAB2-575E-55A3-86B4-E8630CA51934', '6EE8955F-65F5-5C58-9632-77CE0D34833C', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'delete', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '09725874-1FBE-5647-9664-9C41144FA6FC')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('09725874-1FBE-5647-9664-9C41144FA6FC', '6EE8955F-65F5-5C58-9632-77CE0D34833C', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8C66A7BA-05A5-59AA-928B-1C93BAEBF5BE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8C66A7BA-05A5-59AA-928B-1C93BAEBF5BE', '6EE8955F-65F5-5C58-9632-77CE0D34833C', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'update', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'CF160872-2F22-58F6-964F-67D8ED27EAEE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('CF160872-2F22-58F6-964F-67D8ED27EAEE', 'EDF738D1-5763-5211-8100-B74D0EF5FC6D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'ED40BF1D-FEF5-5809-BC89-5818DB27E4EB')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('ED40BF1D-FEF5-5809-BC89-5818DB27E4EB', 'EDF738D1-5763-5211-8100-B74D0EF5FC6D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'delete', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '70337D2D-584F-50EB-B8EA-3681D7839A0D')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('70337D2D-584F-50EB-B8EA-3681D7839A0D', 'EDF738D1-5763-5211-8100-B74D0EF5FC6D', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '9A2B1290-BDEA-51A4-A280-E646A7ADBAB1')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('9A2B1290-BDEA-51A4-A280-E646A7ADBAB1', 'F3DB84F2-BE0C-5B81-9751-67F66A3514CA', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'create', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'AD73FD59-59EB-599E-B991-789E8CCCC640')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('AD73FD59-59EB-599E-B991-789E8CCCC640', 'F3DB84F2-BE0C-5B81-9751-67F66A3514CA', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'delete', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '86447BB8-A203-52D4-8F37-D9FA2FF2E619')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('86447BB8-A203-52D4-8F37-D9FA2FF2E619', 'F3DB84F2-BE0C-5B81-9751-67F66A3514CA', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '37AC2A9A-5113-5713-BA1D-49F5F18CEBEC')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('37AC2A9A-5113-5713-BA1D-49F5F18CEBEC', 'F3DB84F2-BE0C-5B81-9751-67F66A3514CA', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'update', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '899ACAAD-9208-5AAF-89F6-CC23B87217D8')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('899ACAAD-9208-5AAF-89F6-CC23B87217D8', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'heartbeat', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8692A612-4A15-5DA5-80B6-DEEADBE6852F')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8692A612-4A15-5DA5-80B6-DEEADBE6852F', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'read', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '25335289-3654-599C-B4EE-59F9908E0686')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('25335289-3654-599C-B4EE-59F9908E0686', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'register', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'BF135A36-FC56-547F-927F-101BB542FE32')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('BF135A36-FC56-547F-927F-101BB542FE32', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'release_stale', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '27F7B5FA-CCD4-535A-ADA5-222F5BC6AA16')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('27F7B5FA-CCD4-535A-ADA5-222F5BC6AA16', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'reload', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '91BE0C78-6A0D-513A-8F8A-42A29FCF3F47')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('91BE0C78-6A0D-513A-8F8A-42A29FCF3F47', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'seal', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'EAF34A93-753C-5913-8C83-1BF9699F06B9')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('EAF34A93-753C-5913-8C83-1BF9699F06B9', '88178075-397F-58C8-AEA2-C972EE09A548', NULL, '7E203E54-5538-5C0F-B6E5-D276DCD04C36', N'set_status', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '07A860DA-A7E9-5258-BE9E-F3D6533C8CAE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('07A860DA-A7E9-5258-BE9E-F3D6533C8CAE', '1C9190AC-5C30-58EE-9271-A20B66768F5B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'allocate', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'AD343C27-1BCC-5A18-8ECB-0A8EDBE597B6')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('AD343C27-1BCC-5A18-8ECB-0A8EDBE597B6', '1C9190AC-5C30-58EE-9271-A20B66768F5B', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'next', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '8607B1F2-CFC8-5428-A253-DC292E027E1A')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('8607B1F2-CFC8-5428-A253-DC292E027E1A', 'D1969D68-15D9-560E-AA83-B6D998B806B5', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read_all', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '59AEC9AE-9A78-59B2-8618-5A719F3788EE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('59AEC9AE-9A78-59B2-8618-5A719F3788EE', 'A4E8DC50-D3CF-5FAA-8AE4-EA329A24EC02', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'record', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'E0ED14F0-7B35-50AF-9E30-A457BC461A13')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('E0ED14F0-7B35-50AF-9E30-A457BC461A13', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'claim', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'B91357FD-B962-528C-89BC-1D1C313F97F4')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('B91357FD-B962-528C-89BC-1D1C313F97F4', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'complete', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '2AD0A936-06A4-5762-B02A-129C134E3DDE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('2AD0A936-06A4-5762-B02A-129C134E3DDE', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'declare', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '446BBF40-867F-5E22-A81A-30AC22B93BFE')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('446BBF40-867F-5E22-A81A-30AC22B93BFE', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'fail', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = 'BD92833D-5277-5405-823D-93A417742C99')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('BD92833D-5277-5405-823D-93A417742C99', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'read', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '2854092C-6DCE-53D6-9CA1-010EECF50CA0')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('2854092C-6DCE-53D6-9CA1-010EECF50CA0', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'release_stale', 1, NULL);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] WHERE [key_guid] = '7554BAC6-3C5F-5382-B2B4-38573B2458F2')
INSERT INTO [etg].[contracts_urn_functions] ([key_guid], [ref_subdomain_guid], [ref_module_function_guid], [ref_package_guid], [pub_name], [pub_version], [pub_notes]) VALUES ('7554BAC6-3C5F-5382-B2B4-38573B2458F2', '1E8A185E-59E2-5191-B6D8-45F64760D5B8', NULL, 'F1954052-001D-5818-90DC-1953ADA7ABA1', N'retry', 1, NULL);
GO

-- =====================================================================
-- Rebuild etg.contracts_db_operations (Aaron 2026-10-13: _MIGRATION copy, drop, recreate in declared column order, copy
-- back, recreate constraints). Two batches, because a batch is compiled against the table as it stands when the batch
-- starts: the copy-back names ref_function_guid, which exists only once the first batch has committed.
-- Batch 1 runs only while the old shape (pub_op) exists: copy every row to _MIGRATION, drop, create the new shape.
-- Batch 2 runs only while _MIGRATION exists: copy back with each row's function resolved from its pub_op, recreate the
-- constraints, drop the copy. A failure in either batch rolls that batch back (XACT_ABORT) and a re-run resumes where it
-- stopped; the version tail refuses while _MIGRATION exists or the table is short of its 54 rows.
-- FK_cdo_* are the only constraints on the table; nothing references it.
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_db_operations]', N'pub_op') IS NOT NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    IF OBJECT_ID(N'[etg].[contracts_db_operations_MIGRATION]', N'U') IS NOT NULL
      DROP TABLE [etg].[contracts_db_operations_MIGRATION];
    SELECT [cdo].* INTO [etg].[contracts_db_operations_MIGRATION] FROM [etg].[contracts_db_operations] AS [cdo];
    DROP TABLE [etg].[contracts_db_operations];
    CREATE TABLE [etg].[contracts_db_operations] (
      [key_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_function_guid] UNIQUEIDENTIFIER NOT NULL,
      [ref_input_model_guid] UNIQUEIDENTIFIER NULL,
      [ref_output_model_guid] UNIQUEIDENTIFIER NULL,
      [ref_package_guid] UNIQUEIDENTIFIER NULL,
      [pub_query_mssql] NVARCHAR(MAX) NULL,
      [pub_query_postgres] NVARCHAR(MAX) NULL,
      [pub_query_mysql] NVARCHAR(MAX) NULL,
      [pub_bootstrap_element] BIT DEFAULT (0) NOT NULL,
      [pub_notes] NVARCHAR(512) NULL,
      [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
      [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
    );
  COMMIT TRANSACTION;
END
GO

IF OBJECT_ID(N'[etg].[contracts_db_operations_MIGRATION]', N'U') IS NOT NULL
   AND COL_LENGTH(N'[etg].[contracts_db_operations]', N'ref_function_guid') IS NOT NULL
BEGIN
  SET XACT_ABORT ON;
  BEGIN TRANSACTION;
    -- Each row's function is the chain row whose composed URN equals the row's pub_op; a row no chain row names is a defect
    -- and stops the batch before the copy-back (the copy stays in _MIGRATION, the new table stays empty, the tail refuses).
    IF EXISTS (
      SELECT 1 FROM [etg].[contracts_db_operations_MIGRATION] AS [m]
      WHERE NOT EXISTS (
        SELECT 1
        FROM [etg].[contracts_urn_functions] AS [cuf]
        JOIN [etg].[contracts_urn_subdomains] AS [cus] ON [cus].[key_guid] = [cuf].[ref_subdomain_guid]
        JOIN [etg].[contracts_urn_domains] AS [cud] ON [cud].[key_guid] = [cus].[ref_domain_guid]
        JOIN [etg].[contracts_urn_namespaces] AS [cun] ON [cun].[key_guid] = [cud].[ref_namespace_guid]
        WHERE CONCAT([cun].[pub_name], N':', [cud].[pub_name], N':', [cus].[pub_name], N':', [cuf].[pub_name], N':', [cuf].[pub_version]) = [m].[pub_op]
      )
    ) THROW 50000, 'v0.2.0: an operation row has no contracts_urn_functions row for its pub_op; the copy is in contracts_db_operations_MIGRATION', 1;
    DELETE FROM [etg].[contracts_db_operations];
    INSERT INTO [etg].[contracts_db_operations] ([key_guid], [ref_function_guid], [ref_input_model_guid], [ref_output_model_guid], [ref_package_guid], [pub_query_mssql], [pub_query_postgres], [pub_query_mysql], [pub_bootstrap_element], [pub_notes], [priv_created_on], [priv_modified_on])
      SELECT [m].[key_guid], [u].[key_guid], [m].[ref_input_model_guid], [m].[ref_output_model_guid], [m].[ref_package_guid], [m].[pub_query_mssql], [m].[pub_query_postgres], [m].[pub_query_mysql], [m].[pub_bootstrap_element], [m].[pub_notes], [m].[priv_created_on], SYSDATETIMEOFFSET()
      FROM [etg].[contracts_db_operations_MIGRATION] AS [m]
      JOIN (
        SELECT [cuf].[key_guid], CONCAT([cun].[pub_name], N':', [cud].[pub_name], N':', [cus].[pub_name], N':', [cuf].[pub_name], N':', [cuf].[pub_version]) AS [pub_urn]
        FROM [etg].[contracts_urn_functions] AS [cuf]
        JOIN [etg].[contracts_urn_subdomains] AS [cus] ON [cus].[key_guid] = [cuf].[ref_subdomain_guid]
        JOIN [etg].[contracts_urn_domains] AS [cud] ON [cud].[key_guid] = [cus].[ref_domain_guid]
        JOIN [etg].[contracts_urn_namespaces] AS [cun] ON [cun].[key_guid] = [cud].[ref_namespace_guid]
      ) AS [u] ON [u].[pub_urn] = [m].[pub_op];
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY CLUSTERED ([key_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_function] UNIQUE NONCLUSTERED ([ref_function_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_function] FOREIGN KEY ([ref_function_guid]) REFERENCES [etg].[contracts_urn_functions] ([key_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
    ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
    DROP TABLE [etg].[contracts_db_operations_MIGRATION];
  COMMIT TRANSACTION;
END
GO

-- =====================================================================
-- Declaration rows for the eight tables (kernel-owned, as populate stamps every declaration) and the package export set (setup-owned).
-- The export rows need the declaration rows before populate ever runs on 0.2.0, so both are inserted here; populate later
-- MERGEs the same declaration values and adds columns, constraints and indexes.
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'service_security_namespaces', 'dbo', 'ssn', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'EE743EE8-84B8-55C8-B15C-169FAE2D545A')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('EE743EE8-84B8-55C8-B15C-169FAE2D545A', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_namespaces', 'etg', 'cun', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'A2A7F203-CB71-5C3E-801A-6B8BB01C691D')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('A2A7F203-CB71-5C3E-801A-6B8BB01C691D', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_namespace_namespaces', 'etg', 'cunn', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'AB6A4A3D-DAEE-5EE2-9511-B1DF474962DC')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('AB6A4A3D-DAEE-5EE2-9511-B1DF474962DC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_domains', 'etg', 'cud', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '5EBAD346-9619-59A1-8F2D-7DA0B8EC5313')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('5EBAD346-9619-59A1-8F2D-7DA0B8EC5313', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_domain_roles', 'etg', 'cudr', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = 'A320AB3F-F87F-582A-81A4-A37725DA175A')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('A320AB3F-F87F-582A-81A4-A37725DA175A', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_subdomains', 'etg', 'cus', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '82F41238-E105-59D3-A201-D2F8B46E5FE9')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('82F41238-E105-59D3-A201-D2F8B46E5FE9', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_subdomain_entitlements', 'etg', 'cuse', 0);
IF NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_tables] WHERE [key_guid] = '3B75AC0F-E1B5-596E-92BA-F33519C5288C')
INSERT INTO [etg].[contracts_db_tables] ([key_guid], [ref_package_guid], [pub_name], [pub_schema], [pub_alias], [pub_seed_element]) VALUES ('3B75AC0F-E1B5-596E-92BA-F33519C5288C', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'contracts_urn_functions', 'etg', 'cuf', 0);
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '74D232B0-7E25-5BE3-B7E3-DF58730DFB65')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('74D232B0-7E25-5BE3-B7E3-DF58730DFB65', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'AF6E2EB7-DADC-55F5-9BC2-81AA7450E41B');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'B36C206E-93E2-5E2A-BDAA-3E6DFCFB9E7E')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('B36C206E-93E2-5E2A-BDAA-3E6DFCFB9E7E', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'EE743EE8-84B8-55C8-B15C-169FAE2D545A');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '8A5C7AFF-C67C-5AEA-8C89-78FE8345AD04')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('8A5C7AFF-C67C-5AEA-8C89-78FE8345AD04', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'A2A7F203-CB71-5C3E-801A-6B8BB01C691D');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '24F4C68E-AB8F-5481-9354-9158C7B7BB56')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('24F4C68E-AB8F-5481-9354-9158C7B7BB56', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'AB6A4A3D-DAEE-5EE2-9511-B1DF474962DC');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '03EA4C01-5CC5-54AE-BAC5-931FFD83758A')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('03EA4C01-5CC5-54AE-BAC5-931FFD83758A', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '5EBAD346-9619-59A1-8F2D-7DA0B8EC5313');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '80162376-DA9C-5F72-8B59-B0027843FEE2')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('80162376-DA9C-5F72-8B59-B0027843FEE2', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'A320AB3F-F87F-582A-81A4-A37725DA175A');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = 'E9277DF9-DB4D-5FC2-B3B3-3A8313F5E211')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('E9277DF9-DB4D-5FC2-B3B3-3A8313F5E211', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '82F41238-E105-59D3-A201-D2F8B46E5FE9');
IF NOT EXISTS (SELECT 1 FROM [dbo].[service_package_tables] WHERE [key_guid] = '4A8CA2EB-7E0B-5CEA-AB4E-25D0BB230125')
INSERT INTO [dbo].[service_package_tables] ([key_guid], [ref_package_guid], [ref_table_guid]) VALUES ('4A8CA2EB-7E0B-5CEA-AB4E-25D0BB230125', '3051B31E-E885-52A0-A68A-2643EF82A8EC', '3B75AC0F-E1B5-596E-92BA-F33519C5288C');
GO

-- =====================================================================
-- Declarations of the dropped column and constraint (populate never deletes). FK-safe order: the constraint's column row,
-- the constraint row, the column row. The new column and constraints of the rebuilt table are populate's to declare.
-- =====================================================================
IF COL_LENGTH(N'[etg].[contracts_db_operations]', N'pub_op') IS NULL
BEGIN
  DELETE FROM [etg].[contracts_db_constraint_columns] WHERE [key_guid] = '62472E7E-F715-5719-AE6E-4B247FB05A1E';
  DELETE FROM [etg].[contracts_db_constraints] WHERE [key_guid] = '34314D53-E3F9-51B9-99A8-69F11836D52B';
  DELETE FROM [etg].[contracts_db_columns] WHERE [key_guid] = 'E9C3D55E-E7FE-5EA1-BE8F-B9F5F9E49855';
END
GO

-- =====================================================================
-- Version: the database is now at kernel 0.2.0
-- =====================================================================
IF (SELECT COUNT(*) FROM sys.tables AS [t] JOIN sys.schemas AS [s] ON [s].[schema_id] = [t].[schema_id] WHERE [s].[name] = N'etg' AND [t].[name] IN (N'contracts_urn_namespaces', N'contracts_urn_namespace_namespaces', N'contracts_urn_domains', N'contracts_urn_domain_roles', N'contracts_urn_subdomains', N'contracts_urn_subdomain_entitlements', N'contracts_urn_functions')) = 7
   AND OBJECT_ID(N'[dbo].[service_security_namespaces]', N'U') IS NOT NULL
   AND COL_LENGTH(N'[etg].[contracts_db_operations]', N'pub_op') IS NULL
   AND COL_LENGTH(N'[etg].[contracts_db_operations]', N'ref_function_guid') IS NOT NULL
   AND OBJECT_ID(N'[etg].[contracts_db_operations_MIGRATION]', N'U') IS NULL
   AND (SELECT COUNT(*) FROM [etg].[contracts_db_operations]) >= 54
   AND (SELECT COUNT(*) FROM [etg].[contracts_urn_functions]) >= 54
   AND NOT EXISTS (SELECT 1 FROM [etg].[contracts_db_operations] AS [cdo] WHERE NOT EXISTS (SELECT 1 FROM [etg].[contracts_urn_functions] AS [cuf] WHERE [cuf].[key_guid] = [cdo].[ref_function_guid]))
   AND (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.1.9', '0.2.0')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.2.0', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.2.0', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
