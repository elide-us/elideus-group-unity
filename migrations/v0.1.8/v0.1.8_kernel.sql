-- v0.1.8_kernel.sql: the 0.1.7 -> 0.1.8 gap. Idempotent: every statement is guarded, every row by key.
-- STARTED 2026-10-28, NOT COMPLETE. Content to be authored: the host_status enum keys become a database lookup for the
-- kernel (the enum module exposes member row keys) instead of a formula derived in code; whatever rows or columns that
-- needs land here, each as its own guarded batch above the version tail.
-- APPLY WITH THE APPLICATION STOPPED, only once the content above the tail is authored and the code of this release is
-- deployed. The version tail runs only when the database is at 0.1.7 (or already 0.1.8).
-- Moves the database version to 0.1.8.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- (content to be authored)
-- =====================================================================
GO

-- =====================================================================
-- Version: the database is now at kernel 0.1.8
-- =====================================================================
IF (SELECT [pub_value] FROM [dbo].[service_system_configuration] WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F') IN ('0.1.7', '0.1.8')
BEGIN
  UPDATE [dbo].[service_system_configuration] SET [pub_value] = '0.1.8', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '518CD840-0D12-5601-84EF-87FA6FA0E67F';
  UPDATE [dbo].[service_packages_manifest] SET [pub_version] = '0.1.8', [priv_modified_on] = SYSDATETIMEOFFSET() WHERE [key_guid] = '7E203E54-5538-5C0F-B6E5-D276DCD04C36';
END
GO
