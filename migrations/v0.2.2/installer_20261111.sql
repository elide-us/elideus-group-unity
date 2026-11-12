SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =====================================================================
-- Static prelude: types table
-- =====================================================================
CREATE TABLE [etg].[contracts_primitives_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_mssql_sys_type] NVARCHAR(64) NULL,
  [pub_odbc_type_code] SMALLINT NOT NULL,
  [pub_default_length] INT NULL,
  [pub_emits_length] BIT DEFAULT (0) NOT NULL,
  [pub_mssql_type] NVARCHAR(128) NOT NULL,
  [pub_postgresql_type] NVARCHAR(128) NULL,
  [pub_mysql_type] NVARCHAR(128) NULL,
  [pub_python_type] NVARCHAR(64) NOT NULL,
  [pub_typescript_type] NVARCHAR(64) NOT NULL,
  [pub_json_type] NVARCHAR(64) NOT NULL,
  [pub_rust_type] NVARCHAR(64) NOT NULL,
  [pub_lua_type] NVARCHAR(64) NOT NULL,
  [pub_c_type] NVARCHAR(64) NOT NULL,
  [pub_cpp_stl_type] NVARCHAR(64) NOT NULL,
  [pub_cpp_win32_type] NVARCHAR(64) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [PK_contracts_primitives_types] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [UQ_cpt_name] UNIQUE NONCLUSTERED ([pub_name]);
GO

-- =====================================================================
-- Generative section
-- =====================================================================
-- Tables
CREATE TABLE [dbo].[service_audit_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_log_insert] BIT DEFAULT (0) NOT NULL,
  [pub_log_read] BIT DEFAULT (0) NOT NULL,
  [pub_log_update] BIT DEFAULT (0) NOT NULL,
  [pub_log_delete] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_hosts] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_entrypoint_guid] UNIQUEIDENTIFIER NULL,
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
CREATE TABLE [dbo].[service_package_dependencies] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_dependency_guid] UNIQUEIDENTIFIER NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_package_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_packages_manifest] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_version] NVARCHAR(64) NOT NULL,
  [pub_last_version] NVARCHAR(64) NULL,
  [pub_is_sealed] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_security_entitlements] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_security_role_groups] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_group_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_member_guid] UNIQUEIDENTIFIER NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_security_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_system_configuration] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_key] NVARCHAR(256) NOT NULL,
  [pub_value] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[service_workflow_definitions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_actor_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_steps] NVARCHAR(MAX) NOT NULL,
  [pub_can_retry] BIT DEFAULT (1) NOT NULL,
  [pub_max_attempts] TINYINT DEFAULT (3) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
CREATE TABLE [dbo].[system_discord_guilds] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_organization_guid] UNIQUEIDENTIFIER NULL,
  [ref_owner_user_guid] UNIQUEIDENTIFIER NULL,
  [pub_guild_id] BIGINT NOT NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_owner_id] BIGINT NULL,
  [pub_region] NVARCHAR(128) NULL,
  [pub_member_count] INT NULL,
  [pub_notes] NVARCHAR(MAX) NULL,
  [pub_joined_on] DATETIMEOFFSET(7) NOT NULL,
  [pub_left_on] DATETIMEOFFSET(7) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
CREATE TABLE [dbo].[system_sequence_allocations] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_sequence_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_consumer_guid] UNIQUEIDENTIFIER NULL,
  [ref_context_guid] UNIQUEIDENTIFIER NULL,
  [pub_number_from] BIGINT NOT NULL,
  [pub_number_to] BIGINT NOT NULL,
  [pub_issued_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[system_sequences] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_name] NVARCHAR(64) NOT NULL,
  [pub_last_number] BIGINT DEFAULT (0) NOT NULL,
  [pub_allocation_size] INT DEFAULT (1) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
CREATE TABLE [dbo].[system_users] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [pub_email] NVARCHAR(256) NULL,
  [pub_display] NVARCHAR(128) NOT NULL,
  [pub_is_enabled] BIT DEFAULT (1) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [dbo].[system_workflow_history] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_instance_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_host_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_principal_guid] UNIQUEIDENTIFIER NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_actor_guid] UNIQUEIDENTIFIER NULL,
  [ref_context_guid] UNIQUEIDENTIFIER NULL,
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
CREATE TABLE [dbo].[system_workflow_queue] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [ref_definition_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_status_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_disposition_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_principal_guid] UNIQUEIDENTIFIER NULL,
  [ref_context_guid] UNIQUEIDENTIFIER NULL,
  [pub_batch_number] BIGINT NOT NULL,
  [pub_steps] NVARCHAR(MAX) NOT NULL,
  [pub_can_retry] BIT DEFAULT (1) NOT NULL,
  [pub_max_attempts] TINYINT DEFAULT (3) NOT NULL,
  [pub_attempts] TINYINT DEFAULT (0) NOT NULL,
  [pub_started_on] DATETIMEOFFSET(7) NULL,
  [pub_finished_on] DATETIMEOFFSET(7) NULL,
  [pub_error] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_components] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_components_dependencies] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_component_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_dependency_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [pub_exclude_element] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_constraint_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_constraint_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_column_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_constraints] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_referenced_table_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_expression] NVARCHAR(MAX) NULL,
  [pub_is_clustered] BIT DEFAULT (0) NOT NULL,
  [pub_delete_disposition] TINYINT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_index_columns] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_index_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_column_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_descending] BIT DEFAULT (0) NOT NULL,
  [pub_is_included] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_indexes] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_table_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_is_unique] BIT DEFAULT (0) NOT NULL,
  [pub_is_clustered] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
CREATE TABLE [etg].[contracts_db_operations_models] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_operations_models_fields] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [pub_exclude_element] BIT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_procedures] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_schema] NVARCHAR(128) NOT NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_body_mssql] NVARCHAR(MAX) NOT NULL,
  [pub_body_postgres] NVARCHAR(MAX) NULL,
  [pub_body_mysql] NVARCHAR(MAX) NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_db_tables] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_schema] NVARCHAR(64) DEFAULT ('dbo') NOT NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_alias] NVARCHAR(128) NOT NULL,
  [pub_seed_element] TINYINT DEFAULT (0) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
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
CREATE TABLE [etg].[contracts_modules_dependencies] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_dependency_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_kind_enum_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_modules_functions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_input_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_output_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_is_async] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_modules_models] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_modules_models_fields] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NULL,
  [ref_type_model_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_is_collection] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_enum_types] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_enums] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_enum_type_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_value] TINYINT NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_libraries] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_version] NVARCHAR(32) NOT NULL,
  [pub_is_dev_library] BIT DEFAULT (0) NOT NULL,
  [pub_project_url] NVARCHAR(512) NULL,
  [pub_advisory_ref] NVARCHAR(256) NULL,
  [pub_notes] NVARCHAR(MAX) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_libraries_functions] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_library_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_input_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_output_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(256) NOT NULL,
  [pub_is_async] BIT DEFAULT (0) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_libraries_hashes] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_library_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_artifact] NVARCHAR(256) NOT NULL,
  [pub_algorithm] NVARCHAR(16) NOT NULL,
  [pub_hash] NVARCHAR(128) NOT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_libraries_models] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_primitives_libraries_models_fields] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_model_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_type_guid] UNIQUEIDENTIFIER NULL,
  [ref_type_model_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(128) NOT NULL,
  [pub_ordinal] INT NOT NULL,
  [pub_is_nullable] BIT DEFAULT (0) NOT NULL,
  [pub_is_collection] BIT DEFAULT (0) NOT NULL,
  [pub_default_value] NVARCHAR(512) NULL,
  [pub_max_length] INT NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_urn_domain_roles] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_domain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_role_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_urn_domains] (
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
CREATE TABLE [etg].[contracts_urn_namespaces] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_module_guid] UNIQUEIDENTIFIER NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
  [pub_name] NVARCHAR(16) NOT NULL,
  [pub_notes] NVARCHAR(512) NULL,
  [priv_created_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
  [priv_modified_on] DATETIMEOFFSET(7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL
);
CREATE TABLE [etg].[contracts_urn_subdomain_entitlements] (
  [key_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_subdomain_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_entitlement_guid] UNIQUEIDENTIFIER NOT NULL,
  [ref_package_guid] UNIQUEIDENTIFIER NULL,
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
GO

-- contracts_primitives_types seed
INSERT INTO [etg].[contracts_primitives_types]
  (key_guid, ref_package_guid, pub_name, pub_mssql_sys_type, pub_odbc_type_code, pub_default_length, pub_emits_length, pub_mssql_type, pub_postgresql_type, pub_mysql_type, pub_python_type, pub_typescript_type, pub_json_type, pub_rust_type, pub_lua_type, pub_c_type, pub_cpp_stl_type, pub_cpp_win32_type, pub_notes)
VALUES
  ('F35FF7B4-489C-5279-8ACE-1DEE162431D1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'JSON_DOC', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'jsonb', 'json', 'dict', 'object', 'object', 'serde_json::Value', 'table', 'wchar_t*', 'std::wstring', 'LPWSTR', 'JSON document. MSSQL stores as NVARCHAR(MAX); Postgres uses native jsonb.'),
  ('045872FB-30A5-5DF0-8A76-363093C66D05', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64', 'bigint', -5, 8, 0, 'BIGINT', 'bigint', 'bigint', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', '64-bit signed integer.'),
  ('788ECED9-E612-53C9-935D-375394E7B26D', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATE', 'date', 91, 3, 0, 'DATE', 'date', 'date', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Date without time component.'),
  ('7D036485-4EDC-5000-99AB-45A74CF605F0', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_38_18', NULL, 3, NULL, 0, 'DECIMAL(38,18)', 'numeric(38,18)', 'decimal(38,18)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Maximum-precision decimal (38,18). Scientific computation, full-precision intermediates.'),
  ('00E12F64-89DC-5C43-95B3-4AB7F00C9D88', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT16', 'smallint', 5, 2, 0, 'SMALLINT', 'smallint', 'smallint', 'int', 'number', 'integer', 'i16', 'number', 'int16_t', 'int16_t', 'SHORT', '16-bit signed integer (-32768 to 32767).'),
  ('C7B88F80-0464-58D7-8310-4BB1902B7450', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'STRING', 'nvarchar', -9, NULL, 1, 'NVARCHAR', 'varchar', 'varchar', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Variable-length Unicode string. Column-level pub_max_length required.'),
  ('D83C6FAB-1954-5E03-A84C-5255F1D20B60', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT64', 'float', 6, 8, 0, 'FLOAT', 'double precision', 'double', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', '64-bit IEEE 754 floating point. Scientific computation, high-range approximation.'),
  ('7EDB34B7-836E-516E-9561-57AC66F00DD2', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'VECTOR', 'vector', -10, NULL, 1, 'VECTOR', 'vector', 'vector', 'list[float]', 'number[]', 'array', 'Vec<f32>', '{number}', 'float*', 'std::vector<float>', 'FLOAT*', 'Vector embedding. Dimension count via pub_max_length. MSSQL/Azure SQL native; Postgres via pgvector; MySQL 9.0+ native.'),
  ('AE75F369-2305-54B7-A76E-5E13DEB3B43B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'FLOAT32', 'real', 7, 4, 0, 'REAL', 'real', 'float', 'float', 'number', 'number', 'f32', 'number', 'float', 'float', 'FLOAT', '32-bit IEEE 754 floating point. Sensor data, approximate values.'),
  ('CD3AD4B6-BCF9-5EF1-A383-752FB7F87310', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT8', 'tinyint', -6, 1, 0, 'TINYINT', 'smallint', 'tinyint unsigned', 'int', 'number', 'integer', 'u8', 'number', 'uint8_t', 'uint8_t', 'BYTE', '8-bit unsigned integer (0-255). Postgres lacks unsigned tinyint; uses smallint.'),
  ('CF49017D-35D4-5F60-B25A-7688BC4B4517', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT32', 'int', 4, 4, 0, 'INT', 'integer', 'int', 'int', 'number', 'integer', 'i32', 'number', 'int32_t', 'int32_t', 'LONG', '32-bit signed integer.'),
  ('5024F830-E80E-5271-BBF3-86CBD4815676', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'UUID', 'uniqueidentifier', -11, 16, 0, 'UNIQUEIDENTIFIER', 'uuid', 'char(36)', 'str', 'string', 'string', 'uuid::Uuid', 'string', 'uint8_t[16]', 'std::array<uint8_t,16>', 'GUID', '128-bit UUID / GUID.'),
  ('892A2D24-1D12-5305-A7BD-9684FAE59667', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BOOL', 'bit', -7, 1, 0, 'BIT', 'boolean', 'tinyint(1)', 'bool', 'boolean', 'boolean', 'bool', 'boolean', 'bool', 'bool', 'BOOL', 'Boolean flag.'),
  ('160A9552-FB97-57D0-8C33-9FFE044F3A25', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DATETIME_TZ', 'datetimeoffset', -155, NULL, 0, 'DATETIMEOFFSET(7)', 'timestamptz', 'datetime(6)', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Timestamp with timezone offset. Platform standard for all timestamps.'),
  ('AB8B8138-B783-5A8B-9D26-CE8973E5E887', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_19_5', NULL, 3, NULL, 0, 'DECIMAL(19,5)', 'decimal(19,5)', 'decimal(19,5)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'Fixed-precision decimal (19,5). Financial: currency amounts, rates, unit prices.'),
  ('69721FA2-EC1D-5F49-BBE5-CFD0F2C3FDD8', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'TEXT', NULL, -10, NULL, 0, 'NVARCHAR(MAX)', 'text', 'longtext', 'str', 'string', 'string', 'String', 'string', 'wchar_t*', 'std::wstring', 'LPWSTR', 'Unlimited-length Unicode text.'),
  ('77A989D6-BF01-5D0E-895A-D667C3C8A7CB', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DECIMAL_28_12', NULL, 3, NULL, 0, 'DECIMAL(28,12)', 'numeric(28,12)', 'decimal(28,12)', 'float', 'number', 'number', 'f64', 'number', 'double', 'double', 'DOUBLE', 'High-precision decimal (28,12). Staging tables, pre-quantization.'),
  ('7B75DC97-1DF5-5DC2-869F-F2931DC0C15B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'BINARY', NULL, -4, NULL, 0, 'VARBINARY(MAX)', 'bytea', 'longblob', 'bytes', 'Uint8Array', 'string', 'Vec<u8>', 'buffer', 'uint8_t*', 'std::vector<uint8_t>', 'LPBYTE', 'Variable-length binary data.'),
  ('45FE541B-B4AA-518B-B707-FF5B673622FA', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'INT64_IDENTITY', NULL, -5, 8, 0, 'BIGINT IDENTITY(1,1)', 'bigserial', 'bigint auto_increment', 'int', 'number', 'integer', 'i64', 'number', 'int64_t', 'int64_t', 'LONGLONG', 'Auto-incrementing 64-bit integer. Identity is intrinsic to the type.');

-- service_packages_manifest seed
INSERT INTO [dbo].[service_packages_manifest]
  (key_guid, ref_package_guid, pub_name, pub_version, pub_last_version, pub_is_sealed)
VALUES
  ('F1954052-001D-5818-90DC-1953ADA7ABA1', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'core', '0.2.2', NULL, 1),
  ('3051B31E-E885-52A0-A68A-2643EF82A8EC', '3051B31E-E885-52A0-A68A-2643EF82A8EC', 'setup', '0.2.2', NULL, 1),
  ('7E203E54-5538-5C0F-B6E5-D276DCD04C36', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'kernel', '0.2.2', '0.1.1', 1);

-- contracts_primitives_enum_types seed
INSERT INTO [etg].[contracts_primitives_enum_types]
  (key_guid, ref_package_guid, pub_name, pub_notes)
VALUES
  ('F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'sequence_kind', 'How a number sequence issues: STRICT (one number per call, gapless) or CACHED (pre-allocated block, unused remainder lost on restart).'),
  ('44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'account_kind', 'What an account row is: INTERACTIVE (a person, first-seen by Auth), SYSTEM (application automation, sealed), SERVICE (infrastructure automation, unsealed), ANONYMOUS (the public grant: an account row, never a NULL).'),
  ('19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'denial_reason', 'Why a layer refused. One row per refusal in system_security_denials.'),
  ('E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'task_disposition', 'Undo semantics of a workflow instance: REVERSIBLE, IRREVERSIBLE, TRANSIENT, CANCELLABLE. Orthogonal to retry.'),
  ('23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'task_status', 'Workflow instance lifecycle: PENDING, RUNNING, COMPLETE, FAILED, CANCELLING.'),
  ('4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_kind', 'Database constraint kinds: PRIMARY_KEY, FOREIGN_KEY, UNIQUE, CHECK.'),
  ('F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'schema_source', 'Origin of a generated schema view: PRIMARY (live introspection) or GENERATED (from contracts_db_* rows).'),
  ('4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'cloudhost_engine', 'The platform an entry point launches the process on.'),
  ('1CDD672E-B1CE-5C8D-A386-7C4A26ACAB8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'module_dependency_kind', 'Kind of a module dependency edge: REQUIRES (get_module / constructor), INHERITS (base class).'),
  ('5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'module_role', 'MEP slot of a module: MANAGER (Operations, Maintenance), EXECUTOR (Execution, Management), PROVIDER, WORKER, SERVICE (the kernel services around the modules), PRIMITIVE (a standalone module with no executor). NULL on BaseModule, the base of every slot.'),
  ('89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'constraint_disposition', 'Referential action for FK constraints: NO_ACTION (engine default), CASCADE, SET_NULL, SET_DEFAULT.'),
  ('A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'host_status', 'Running-instance lifecycle of a service_hosts row: STARTING, SEALED, DRAINING, RELOADING, STOPPED.'),
  ('02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'organization_kind', 'What an organization row is: the external thing it maps.'),
  ('75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_channel', 'Where a unit of work entered the application: the channel provider that admitted it.'),
  ('064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'audit_kind', 'Which change an audit tracking row records on a logged table.'),
  ('718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'security_layer', 'Which of the three proofs a denial refused: IDENTITY (the claim), AUTHORIZATION (the operation), ACCESS (the transaction).');

-- contracts_primitives_enums seed
INSERT INTO [etg].[contracts_primitives_enums]
  (key_guid, ref_enum_type_guid, ref_package_guid, pub_name, pub_value, pub_notes)
VALUES
  ('843555AB-F2BD-5CCA-AEBF-08C3519D6685', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CANCELLABLE', 3, 'May be cancelled before or during execution without a compensating task.'),
  ('B0D3359F-7388-55ED-810C-09033F4C276D', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STARTING', 0, 'Registered at kernel startup; the application is not yet sealed.'),
  ('57F37618-1A3E-5D30-88CB-095E1DC91492', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_ACTION', 0, 'Engine default. No clause emitted.'),
  ('4A3BEA0A-490B-5C4E-8B61-0C06FC48D9D6', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ACA', 3, 'Azure Container Apps.'),
  ('1C1EF0D5-C3AE-57C0-B1B5-0E1E5D9E820F', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'ENTRA_TENANT', 2, 'A Microsoft Entra tenant.'),
  ('FACAE3A1-DE97-5D4C-9EC8-0F209B1E58FC', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SETUP', 6, 'Setup mode or an installer script.'),
  ('0FEBB2D7-F55C-592C-88F5-179772136B4F', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'AKS', 4, 'Azure Kubernetes Service.'),
  ('DABC9F21-2FE3-5948-B5D0-187CE3E5DC35', '1CDD672E-B1CE-5C8D-A386-7C4A26ACAB8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'INHERITS', 1, 'The module is a subclass of the dependency and implements its declared functions.'),
  ('916C02CA-6389-5145-9FD9-2DC9B2C4FE5B', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'EXECUTOR', 1, 'Executor slot: dispatch behind a manager (Execution, Management).'),
  ('4C4ADD75-0A5B-53D1-AB0E-2EEBBC143B0E', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMITIVE', 5, 'Primitive slot: a standalone module with no executor that serves system or service data (configuration, enumerations, environment, logging); with MANAGER, the only role RPC may dispatch to.'),
  ('C761A53C-DCED-5FF6-94E0-39D926B02E16', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'TRANSIENT', 2, 'No persistent effect; safe to discard mid-execution.'),
  ('6231C597-4771-5888-8470-3EEF7308E966', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'DISCORD_GUILD', 1, 'A Discord server.'),
  ('E4F78513-0BF7-545F-A5E5-42BFB845893E', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_CONTEXT', 4, 'A data request arrived with no security context.'),
  ('F0497A46-374D-59C9-9CB2-45CBB99B9D1C', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'IRREVERSIBLE', 1, 'Effect cannot be undone through the system; external recovery only.'),
  ('E3C5DACB-6027-515A-8FED-489D71869C86', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY', 0, 'Live database schema introspected via the engine catalog (sys.* / INFORMATION_SCHEMA).'),
  ('29765458-8EDF-56AC-B149-4B84231776DB', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'READ', 4, 'A record was read.'),
  ('310E2BCC-4890-5FDD-B1E7-558E5372BF20', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ACCESS', 3, 'The data layer refused the transaction.'),
  ('1157DAB1-7D35-505F-B877-59543829C4E7', '1CDD672E-B1CE-5C8D-A386-7C4A26ACAB8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'REQUIRES', 0, 'The module resolves the dependency at startup (get_module) or takes it in its constructor.'),
  ('A2310AD9-FD9E-5276-ABAF-5FDE20DDC7EC', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RUNNING', 1, 'Claimed and executing. Stale-claim recovery returns an abandoned RUNNING row to PENDING and counts the attempt.'),
  ('933FF84A-8A6B-5AF3-9861-6319434F504B', 'E171D014-E371-5B40-B757-2FB33D6A7C61', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'REVERSIBLE', 0, 'Effect can be undone by a separately declared compensating task.'),
  ('C1002C88-406F-546E-B3EF-69D75C4906FF', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CHECK', 3, 'Check constraint. pub_expression on the constraint row holds the predicate.'),
  ('600C3293-DEA9-56B9-9D36-6C25E81510FC', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UPDATE', 2, 'A record was changed.'),
  ('C00FD6DB-1191-509A-A1B1-6E123D822E50', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'WORKER', 3, 'Worker slot: runs on its own cadence (start / stop), owned by a provider.'),
  ('DCDC215E-188B-5C3D-BD66-6E3C8CE9BC4F', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'INSERT', 1, 'A record was created.'),
  ('C45DA709-B053-54A9-8933-6EE2504C5747', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SCHEDULER', 5, 'A scheduled task.'),
  ('EA0EAF92-84DE-56F3-9D6A-70973BF6B26D', 'F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STRICT', 0, 'One number per call, issued and audited in one transaction; no gaps at issue.'),
  ('59C1933F-C216-5F32-A7C9-70A883287B8D', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CASCADE', 1, 'Delete or update of parent triggers same operation on children.'),
  ('9A534DC0-3083-55DF-A5A0-727EDEEAC090', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'REVOKED', 6, 'The grant or session was revoked.'),
  ('4291EA63-A8B4-59E2-B724-7B506A8D6A09', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FAILED', 3, 'Execution failed; pub_error holds the detail. Re-declaration flips it back to PENDING when attempts remain.'),
  ('46BF744F-5E16-5A8A-B16A-7C7F8F9C7253', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SERVICE', 3, 'The service automation account: infrastructure work, unsealed.'),
  ('38358AA0-B911-5794-8E61-7D7A6E8E5582', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RELOADING', 3, 'Written by the workflow side onto a sealed host; the host observes it, drains and exits, and the host runtime restarts it.'),
  ('A8EC52A6-F222-519B-894C-843AAB11C909', '064879DE-A840-5EF8-8939-E86A2CF8D69B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DELETE', 3, 'A record was removed.'),
  ('1423E34D-C5EF-5E09-9303-8C6EEE569D5D', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'WORKFLOW', 4, 'A workflow run.'),
  ('7FA001CC-D978-5589-869D-8D957D1F31A9', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SERVICE', 4, 'Service slot: a kernel service that exists before and around the modules (LifecycleManager, ModuleManager). Listed and mapped, never loaded as a module.'),
  ('C12C3474-7CC8-537F-8BD8-94F86B636D6A', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'INTERACTIVE', 1, 'A person; the only kind Auth will log in.'),
  ('30C42C94-D7CA-5A8B-9231-97E28C4B4065', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DISCORD', 3, 'The Discord gateway.'),
  ('543313DE-AF0F-581B-8DC5-99EB9892C865', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PENDING', 0, 'Declared, awaiting claim by the workflow worker.'),
  ('945EABDF-DE88-59FA-B034-9D9382D48051', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SEALED', 1, 'Every module has sealed; the host is live. The only state reload() moves to RELOADING.'),
  ('824195E5-DF9A-5475-AB7E-A3C543E2C23D', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'MANAGER', 0, 'Manager slot: the public contract the application calls (Operations, Maintenance, Interface).'),
  ('839D8F97-2D6E-5135-81CD-A76E135E4A97', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'LOCAL', 1, 'A developer machine: dev.sh / dev.cmd, uvicorn with reload on localhost.'),
  ('B6E34B8A-DE76-5E18-9A8E-AB65A159C5B4', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_IDENTITY', 1, 'No usable bearer: malformed, expired or unsigned.'),
  ('838A88E7-41D2-595B-9EEE-B411AC91B897', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'STOPPED', 4, 'The kernel stopped, or the stale sweep found the heartbeat older than the grace period. Terminal.'),
  ('BA9F914F-A591-512D-B2DF-B5C84D64C474', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_DEFAULT', 3, 'Child FK columns set to their column DEFAULT on parent delete/update.'),
  ('F688BD8B-9BF5-57C6-8483-B6AE49C0E826', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PRIMARY_KEY', 0, 'Primary key constraint. One per table. Columns via constraint_columns junction.'),
  ('AC26B0F1-48C4-5133-BBB4-B7539D7BA7F3', '4F18B834-5FBA-5BBB-91EB-6A06770E5337', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CONTAINER', 2, 'The image: startup.sh, uvicorn on 0.0.0.0:8000, wherever the container runs.'),
  ('66CAABF3-BA45-5417-BB15-BA59D16054FE', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SYSTEM', 2, 'The system automation account: application work under seal.'),
  ('C69BDFCB-6AD5-568B-815C-BC06DB43B19B', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNKNOWN_TERM', 2, 'A namespace, domain, subdomain or function term is not registered.'),
  ('BE46F5F2-C245-56F8-AB6B-BC263D0DBAA6', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'IDENTITY', 1, 'The gateway refused the claim.'),
  ('B4D703DC-27CB-503E-A9B5-BD64FD3D67DB', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'RPC', 1, 'The RPC gateway.'),
  ('D24B3B8C-EC6E-5D52-A0A2-BD9DF03CFD67', '02B7BD50-AF73-5DB3-98B0-B1FC187E9B4B', 'F1954052-001D-5818-90DC-1953ADA7ABA1', 'GAME_GUILD', 3, 'An in-game guild.'),
  ('AC70897E-0052-51E6-9581-C658E91E6E1D', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'MCP', 2, 'The MCP gateway.'),
  ('F72FED1F-2655-5898-8DE9-C9C8576582A5', '5E1DE2D2-E1F3-5B20-A126-7CFF92741146', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'PROVIDER', 2, 'Provider slot: the function interface to a primitive service, owned by an executor.'),
  ('F78A44FC-D5DD-54ED-BFF1-CAFA7AA875CD', '44EAB4BA-5937-5F90-8143-213C306AB08E', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'ANONYMOUS', 4, 'The anonymous account: what a request with no identity runs as.'),
  ('9A8EB79B-B824-58F9-8404-CE2248734DF3', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CANCELLING', 4, 'Cancellation requested. The worker aborts and transitions to FAILED or COMPLETE.'),
  ('36DD290B-4606-5810-843E-CF324B66F504', '89BF8DE1-413E-582E-8D15-9629A883F6DA', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'SET_NULL', 2, 'Child FK columns set to NULL on parent delete/update. Child column must be nullable.'),
  ('CCDA2282-BDC2-5A3C-8378-D0403FB9F05A', '75CDADC0-7A2F-582D-9580-E67CB5B4CCA1', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'KERNEL', 7, 'The kernel bootstrap before core is up.'),
  ('47D47931-B3DA-5C42-99DA-D11342315A00', 'F3A8534E-EBEA-5F52-804C-0BBEA2B03A41', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'CACHED', 1, 'A block of pub_allocation_size numbers per call, served from the process cache; what is not used before a restart is lost.'),
  ('0AD96EE8-08F2-59B9-8FEC-D51DA0010517', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'FOREIGN_KEY', 1, 'Foreign key constraint. Source and target columns via constraint_columns junction.'),
  ('773A1E54-BDC0-58E3-B3A2-D8296F00E9ED', '4BE7C586-9847-5925-90A3-5071D8228F26', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'UNIQUE', 2, 'Unique constraint. Columns via constraint_columns junction.'),
  ('3FF26BAD-8734-50D7-A839-D8E987A36671', '23AD5199-726E-5DCC-8CEC-33B699A987CC', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'COMPLETE', 2, 'Executed successfully. Terminal.'),
  ('6816DA40-9AD2-519E-8A31-DA5C610C6B4F', 'A3F43D12-E26A-5B69-9CE3-AD2192C7DD64', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DRAINING', 2, 'The kernel is draining: modules stop accepting work ahead of shutdown.'),
  ('DB9904DD-A011-5FD5-A6BC-E8518750B09A', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'NO_GRANT', 3, 'The decoration holds no role or entitlement the term requires.'),
  ('CA80FA79-BB9D-5FE9-A599-EE4617363A62', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'DISABLED_ACCOUNT', 7, 'The account is disabled.'),
  ('5F6E0F13-4804-594B-9F2C-F662F0BD68E3', '19F0846A-4C48-5430-8449-2FAE34791294', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'MALFORMED_OP', 5, 'The op string does not parse as a URN.'),
  ('04B28DA7-E20C-5AEE-8E2A-F8FE79ADCF07', 'F5539B3E-417C-5A95-BF9B-592B97369B40', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'GENERATED', 1, 'Declared schema generated from contracts_db_* rows.'),
  ('E0BB0DF2-D1F4-52FE-ACF1-F9C884252E64', '718550F0-C6E9-5D96-B2B6-EC03C753E627', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'AUTHORIZATION', 2, 'RPC dispatch refused the operation.'),
  ('0BACC23E-8865-5C11-808B-FA068A226844', '1CDD672E-B1CE-5C8D-A386-7C4A26ACAB8B', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'EXTENDS', 2, 'The privileged composition: the module is an extension over its concrete pair of the same role in the component it extends; the one dependency whose target need not be a Manager.');

GO

INSERT INTO [dbo].[service_system_configuration]
  (key_guid, ref_package_guid, pub_key, pub_value)
VALUES
  ('518CD840-0D12-5601-84EF-87FA6FA0E67F', '7E203E54-5538-5C0F-B6E5-D276DCD04C36', 'database_version', '0.2.2');
GO

-- Indexes
CREATE NONCLUSTERED INDEX [IX_so_kind] ON [dbo].[system_organizations] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cplmf_model_guid] ON [etg].[contracts_primitives_libraries_models_fields] ([ref_model_guid]);
CREATE NONCLUSTERED INDEX [IX_cmd_kind] ON [etg].[contracts_modules_dependencies] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cmd_module_guid] ON [etg].[contracts_modules_dependencies] ([ref_module_guid]);
CREATE NONCLUSTERED INDEX [IX_sdc_guild] ON [dbo].[system_discord_channels] ([ref_guild_guid]);
CREATE NONCLUSTERED INDEX [IX_sdc_user] ON [dbo].[system_discord_channels] ([ref_user_guid]);
CREATE NONCLUSTERED INDEX [IX_cplh_library_guid] ON [etg].[contracts_primitives_libraries_hashes] ([ref_library_guid]);
CREATE NONCLUSTERED INDEX [IX_ssrg_member_guid] ON [dbo].[service_security_role_groups] ([ref_member_guid]);
CREATE NONCLUSTERED INDEX [IX_cdi_table_guid] ON [etg].[contracts_db_indexes] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_swq_status_created] ON [dbo].[system_workflow_queue] ([ref_status_enum_guid], [priv_created_on]);
CREATE NONCLUSTERED INDEX [IX_ssa_consumer_guid] ON [dbo].[system_sequence_allocations] ([ref_consumer_guid]);
CREATE NONCLUSTERED INDEX [IX_ssa_sequence_issued] ON [dbo].[system_sequence_allocations] ([ref_sequence_guid], [pub_issued_on]);
CREATE NONCLUSTERED INDEX [IX_cdc_table_guid] ON [etg].[contracts_db_columns] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_cdc_type_guid] ON [etg].[contracts_db_columns] ([ref_type_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_model_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_model_guid]);
CREATE NONCLUSTERED INDEX [IX_cdomf_type_guid] ON [etg].[contracts_db_operations_models_fields] ([ref_type_guid]);
CREATE NONCLUSTERED INDEX [IX_sdg_owner_user] ON [dbo].[system_discord_guilds] ([ref_owner_user_guid]);
CREATE NONCLUSTERED INDEX [IX_cdic_index_guid] ON [etg].[contracts_db_index_columns] ([ref_index_guid]);
CREATE NONCLUSTERED INDEX [IX_cmf_module_guid] ON [etg].[contracts_modules_functions] ([ref_module_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_kind] ON [etg].[contracts_db_constraints] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cdco_table_guid] ON [etg].[contracts_db_constraints] ([ref_table_guid]);
CREATE NONCLUSTERED INDEX [IX_som_organization_left] ON [dbo].[system_organization_members] ([ref_organization_guid], [pub_left_on]);
CREATE NONCLUSTERED INDEX [IX_som_user] ON [dbo].[system_organization_members] ([ref_user_guid]);
CREATE NONCLUSTERED INDEX [IX_sh_status_heartbeat] ON [dbo].[service_hosts] ([ref_status_enum_guid], [pub_heartbeat_on]);
CREATE NONCLUSTERED INDEX [IX_satr_context_guid] ON [dbo].[system_audit_transactions] ([ref_context_guid]);
CREATE NONCLUSTERED INDEX [IX_satr_table_record] ON [dbo].[system_audit_transactions] ([ref_table_guid], [pub_record_number]);
CREATE NONCLUSTERED INDEX [IX_ccd_component] ON [etg].[contracts_components_dependencies] ([ref_component_guid]);
CREATE NONCLUSTERED INDEX [IX_ccd_kind] ON [etg].[contracts_components_dependencies] ([ref_kind_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_cm_component] ON [etg].[contracts_modules] ([ref_component_guid]);
CREATE NONCLUSTERED INDEX [IX_cm_role] ON [etg].[contracts_modules] ([ref_role_enum_guid]);
CREATE NONCLUSTERED INDEX [IX_ce_module] ON [etg].[contracts_entrypoints] ([ref_module_guid]);
CREATE NONCLUSTERED INDEX [IX_su_display] ON [dbo].[system_users] ([pub_display]);
CREATE NONCLUSTERED INDEX [IX_su_email] ON [dbo].[system_users] ([pub_email]);
CREATE NONCLUSTERED INDEX [IX_sue_user_revoked] ON [dbo].[system_user_entitlements] ([ref_user_guid], [pub_revoked_on]);
CREATE NONCLUSTERED INDEX [IX_cmmf_model_guid] ON [etg].[contracts_modules_models_fields] ([ref_model_guid]);
CREATE NONCLUSTERED INDEX [IX_ssco_actor_issued] ON [dbo].[system_security_contexts] ([ref_actor_guid], [pub_issued_on]);
CREATE NONCLUSTERED INDEX [IX_ssco_parent_guid] ON [dbo].[system_security_contexts] ([ref_parent_context_guid]);
CREATE NONCLUSTERED INDEX [IX_ssco_principal_issued] ON [dbo].[system_security_contexts] ([ref_principal_guid], [pub_issued_on]);
CREATE NONCLUSTERED INDEX [IX_sur_user_revoked] ON [dbo].[system_user_roles] ([ref_user_guid], [pub_revoked_on]);
CREATE NONCLUSTERED INDEX [IX_cdcc_constraint_guid] ON [etg].[contracts_db_constraint_columns] ([ref_constraint_guid]);
CREATE NONCLUSTERED INDEX [IX_cplf_library_guid] ON [etg].[contracts_primitives_libraries_functions] ([ref_library_guid]);
CREATE NONCLUSTERED INDEX [IX_ssd_context_guid] ON [dbo].[system_security_denials] ([ref_context_guid]);
CREATE NONCLUSTERED INDEX [IX_ssd_occurred] ON [dbo].[system_security_denials] ([pub_occurred_on]);
CREATE NONCLUSTERED INDEX [IX_swh_definition_finished] ON [dbo].[system_workflow_history] ([ref_definition_guid], [pub_finished_on]);
CREATE NONCLUSTERED INDEX [IX_swh_host] ON [dbo].[system_workflow_history] ([ref_host_guid]);

-- Constraints (PK, UNIQUE, CHECK)
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [PK_contracts_db_operations_models] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [UQ_cdom_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [PK_system_organizations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [UQ_so_kind_external] UNIQUE NONCLUSTERED ([ref_kind_enum_guid], [pub_external_id]);
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [PK_service_package_tables] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [UQ_spt_table] UNIQUE NONCLUSTERED ([ref_table_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models] ADD CONSTRAINT [PK_contracts_primitives_libraries_models] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models] ADD CONSTRAINT [UQ_cplm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [PK_contracts_primitives_libraries_models_fields] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [UQ_cplmf_model_name] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [UQ_cplmf_model_ordinal] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [CK_cplmf_typed] CHECK (([ref_type_guid] IS NOT NULL AND [ref_type_model_guid] IS NULL OR [ref_type_guid] IS NULL AND [ref_type_model_guid] IS NOT NULL));
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [PK_contracts_modules_dependencies] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [UQ_cmd_module_dependency] UNIQUE NONCLUSTERED ([ref_module_guid], [ref_dependency_guid]);
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [PK_contracts_urn_namespaces] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [UQ_cun_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [PK_contracts_components] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [UQ_cc_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [PK_system_discord_channels] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [UQ_sdc_channel_id] UNIQUE NONCLUSTERED ([pub_channel_id]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [CK_sdc_owner] CHECK (([ref_guild_guid] IS NOT NULL AND [ref_user_guid] IS NULL OR [ref_guild_guid] IS NULL AND [ref_user_guid] IS NOT NULL));
ALTER TABLE [etg].[contracts_primitives_libraries_hashes] ADD CONSTRAINT [PK_contracts_primitives_libraries_hashes] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_hashes] ADD CONSTRAINT [UQ_cplh_artifact] UNIQUE NONCLUSTERED ([pub_artifact]);
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [PK_service_workflow_definitions] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [UQ_swd_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[service_security_role_groups] ADD CONSTRAINT [PK_service_security_role_groups] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_role_groups] ADD CONSTRAINT [UQ_ssrg_group_member] UNIQUE NONCLUSTERED ([ref_group_guid], [ref_member_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [PK_contracts_db_indexes] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [UQ_cdi_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_modules_models] ADD CONSTRAINT [PK_contracts_modules_models] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models] ADD CONSTRAINT [UQ_cmm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [PK_system_workflow_queue] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [PK_contracts_primitives_enums] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_name] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_name]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [UQ_cpe_type_value] UNIQUE NONCLUSTERED ([ref_enum_type_guid], [pub_value]);
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [PK_system_sequence_allocations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [PK_contracts_db_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [UQ_cdc_table_ordinal] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [PK_contracts_primitives_enum_types] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [UQ_cpet_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [PK_service_audit_tables] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [UQ_sat_table] UNIQUE NONCLUSTERED ([ref_table_guid]);
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [PK_contracts_db_procedures] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [UQ_cdp_schema_name] UNIQUE NONCLUSTERED ([pub_schema], [pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [PK_contracts_db_operations_models_fields] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_name] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [UQ_cdomf_model_ordinal] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [PK_service_package_dependencies] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [UQ_spd_package_dependency] UNIQUE NONCLUSTERED ([ref_package_guid], [ref_dependency_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [PK_contracts_db_tables] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_alias] UNIQUE NONCLUSTERED ([pub_alias]);
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [UQ_cdt_schema_name] UNIQUE NONCLUSTERED ([pub_schema], [pub_name]);
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [PK_system_discord_guilds] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [UQ_sdg_guild_id] UNIQUE NONCLUSTERED ([pub_guild_id]);
ALTER TABLE [etg].[contracts_primitives_libraries] ADD CONSTRAINT [PK_contracts_primitives_libraries] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries] ADD CONSTRAINT [UQ_cpl_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [PK_contracts_db_index_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [UQ_cdic_index_column] UNIQUE NONCLUSTERED ([ref_index_guid], [ref_column_guid]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [PK_service_security_roles] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [UQ_ssr_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [PK_contracts_urn_domain_roles] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [UQ_cudr_domain_role] UNIQUE NONCLUSTERED ([ref_domain_guid], [ref_role_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [PK_contracts_db_operations] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [UQ_cdo_function] UNIQUE NONCLUSTERED ([ref_function_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [PK_contracts_modules_functions] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [UQ_cmf_module_name] UNIQUE NONCLUSTERED ([ref_module_guid], [pub_name]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [PK_contracts_db_constraints] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [UQ_cdco_table_name] UNIQUE NONCLUSTERED ([ref_table_guid], [pub_name]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [PK_system_organization_members] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [UQ_som_organization_user] UNIQUE NONCLUSTERED ([ref_organization_guid], [ref_user_guid]);
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [PK_service_hosts] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [PK_system_audit_transactions] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [PK_service_packages_manifest] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [UQ_spm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [PK_contracts_components_dependencies] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [UQ_ccd_component_dependency] UNIQUE NONCLUSTERED ([ref_component_guid], [ref_dependency_guid]);
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [PK_contracts_urn_subdomains] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [UQ_cus_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [PK_contracts_modules] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [UQ_cm_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [PK_service_security_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [UQ_sse_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [PK_contracts_urn_domains] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [UQ_cud_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [PK_contracts_entrypoints] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [UQ_ce_engine_name] UNIQUE NONCLUSTERED ([ref_engine_enum_guid], [pub_name]);
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [PK_system_users] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [PK_system_user_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [PK_contracts_modules_models_fields] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [UQ_cmmf_model_name] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_name]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [UQ_cmmf_model_ordinal] UNIQUE NONCLUSTERED ([ref_model_guid], [pub_ordinal]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [CK_cmmf_typed] CHECK (([ref_type_guid] IS NOT NULL AND [ref_type_model_guid] IS NULL OR [ref_type_guid] IS NULL AND [ref_type_model_guid] IS NOT NULL));
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [PK_contracts_urn_subdomain_entitlements] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [UQ_cuse_subdomain_entitlement] UNIQUE NONCLUSTERED ([ref_subdomain_guid], [ref_entitlement_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [PK_system_security_contexts] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [PK_system_user_roles] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [PK_contracts_db_constraint_columns] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_column] UNIQUE NONCLUSTERED ([ref_constraint_guid], [ref_column_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [UQ_cdcc_constraint_ordinal] UNIQUE NONCLUSTERED ([ref_constraint_guid], [pub_ordinal]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [PK_system_configuration] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [UQ_sc_key] UNIQUE NONCLUSTERED ([pub_key]);
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [PK_contracts_primitives_libraries_functions] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [UQ_cplf_library_name] UNIQUE NONCLUSTERED ([ref_library_guid], [pub_name]);
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [PK_system_security_denials] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [PK_contracts_urn_functions] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [UQ_cuf_urn] UNIQUE NONCLUSTERED ([ref_namespace_guid], [ref_domain_guid], [ref_subdomain_guid], [pub_name], [pub_version]);
ALTER TABLE [dbo].[system_sequences] ADD CONSTRAINT [PK_system_sequences] PRIMARY KEY CLUSTERED ([key_guid]);
ALTER TABLE [dbo].[system_sequences] ADD CONSTRAINT [UQ_ss_name] UNIQUE NONCLUSTERED ([pub_name]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [PK_system_workflow_history] PRIMARY KEY CLUSTERED ([key_guid]);

-- Constraints (FOREIGN KEY)
ALTER TABLE [etg].[contracts_db_operations_models] ADD CONSTRAINT [FK_cdom_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [FK_so_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_organizations] ADD CONSTRAINT [FK_so_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [FK_spt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_package_tables] ADD CONSTRAINT [FK_spt_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models] ADD CONSTRAINT [FK_cplm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [FK_cplmf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_primitives_libraries_models] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [FK_cplmf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [FK_cplmf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_models_fields] ADD CONSTRAINT [FK_cplmf_type_model] FOREIGN KEY ([ref_type_model_guid]) REFERENCES [etg].[contracts_primitives_libraries_models] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_dependencies] ADD CONSTRAINT [FK_cmd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [FK_cun_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_namespaces] ADD CONSTRAINT [FK_cun_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_components] ADD CONSTRAINT [FK_cc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_guild] FOREIGN KEY ([ref_guild_guid]) REFERENCES [dbo].[system_discord_guilds] ([key_guid]);
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_discord_channels] ADD CONSTRAINT [FK_sdc_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_hashes] ADD CONSTRAINT [FK_cplh_library] FOREIGN KEY ([ref_library_guid]) REFERENCES [etg].[contracts_primitives_libraries] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_hashes] ADD CONSTRAINT [FK_cplh_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[service_workflow_definitions] ADD CONSTRAINT [FK_swd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_security_role_groups] ADD CONSTRAINT [FK_ssrg_group] FOREIGN KEY ([ref_group_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
ALTER TABLE [dbo].[service_security_role_groups] ADD CONSTRAINT [FK_ssrg_member] FOREIGN KEY ([ref_member_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
ALTER TABLE [dbo].[service_security_role_groups] ADD CONSTRAINT [FK_ssrg_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_indexes] ADD CONSTRAINT [FK_cdi_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models] ADD CONSTRAINT [FK_cmm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_definition] FOREIGN KEY ([ref_definition_guid]) REFERENCES [dbo].[service_workflow_definitions] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_queue] ADD CONSTRAINT [FK_swq_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_enum_type] FOREIGN KEY ([ref_enum_type_guid]) REFERENCES [etg].[contracts_primitives_enum_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enums] ADD CONSTRAINT [FK_cpe_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_sequence_allocations] ADD CONSTRAINT [FK_ssa_sequence] FOREIGN KEY ([ref_sequence_guid]) REFERENCES [dbo].[system_sequences] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_columns] ADD CONSTRAINT [FK_cdc_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_enum_types] ADD CONSTRAINT [FK_cpet_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [FK_sat_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_audit_tables] ADD CONSTRAINT [FK_sat_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_procedures] ADD CONSTRAINT [FK_cdp_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_operations_models_fields] ADD CONSTRAINT [FK_cdomf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [FK_spd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]);
ALTER TABLE [dbo].[service_package_dependencies] ADD CONSTRAINT [FK_spd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_tables] ADD CONSTRAINT [FK_cdt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_organization] FOREIGN KEY ([ref_organization_guid]) REFERENCES [dbo].[system_organizations] ([key_guid]);
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_owner_user] FOREIGN KEY ([ref_owner_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_discord_guilds] ADD CONSTRAINT [FK_sdg_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_libraries] ADD CONSTRAINT [FK_cpl_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_index] FOREIGN KEY ([ref_index_guid]) REFERENCES [etg].[contracts_db_indexes] ([key_guid]);
ALTER TABLE [etg].[contracts_db_index_columns] ADD CONSTRAINT [FK_cdic_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_security_roles] ADD CONSTRAINT [FK_ssr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_domain_roles] ADD CONSTRAINT [FK_cudr_role] FOREIGN KEY ([ref_role_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_function] FOREIGN KEY ([ref_function_guid]) REFERENCES [etg].[contracts_urn_functions] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_db_operations_models] ([key_guid]);
ALTER TABLE [etg].[contracts_db_operations] ADD CONSTRAINT [FK_cdo_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_types] ADD CONSTRAINT [FK_cpt_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [FK_cmf_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_modules_models] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [FK_cmf_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [FK_cmf_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_modules_models] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_functions] ADD CONSTRAINT [FK_cmf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_ref_table] FOREIGN KEY ([ref_referenced_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraints] ADD CONSTRAINT [FK_cdco_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_organization] FOREIGN KEY ([ref_organization_guid]) REFERENCES [dbo].[system_organizations] ([key_guid]);
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_organization_members] ADD CONSTRAINT [FK_som_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_entrypoint] FOREIGN KEY ([ref_entrypoint_guid]) REFERENCES [etg].[contracts_entrypoints] ([key_guid]);
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[service_hosts] ADD CONSTRAINT [FK_sh_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_audit_transactions] ADD CONSTRAINT [FK_satr_table] FOREIGN KEY ([ref_table_guid]) REFERENCES [etg].[contracts_db_tables] ([key_guid]);
ALTER TABLE [dbo].[service_packages_manifest] ADD CONSTRAINT [FK_spm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_component] FOREIGN KEY ([ref_component_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_dependency] FOREIGN KEY ([ref_dependency_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_components_dependencies] ADD CONSTRAINT [FK_ccd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomains] ADD CONSTRAINT [FK_cus_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_component] FOREIGN KEY ([ref_component_guid]) REFERENCES [etg].[contracts_components] ([key_guid]);
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_modules] ADD CONSTRAINT [FK_cm_role] FOREIGN KEY ([ref_role_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[service_security_entitlements] ADD CONSTRAINT [FK_sse_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_domains] ADD CONSTRAINT [FK_cud_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_engine] FOREIGN KEY ([ref_engine_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_module] FOREIGN KEY ([ref_module_guid]) REFERENCES [etg].[contracts_modules] ([key_guid]);
ALTER TABLE [etg].[contracts_entrypoints] ADD CONSTRAINT [FK_ce_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [FK_su_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_users] ADD CONSTRAINT [FK_su_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_entitlement] FOREIGN KEY ([ref_entitlement_guid]) REFERENCES [dbo].[service_security_entitlements] ([key_guid]);
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_granted_context] FOREIGN KEY ([ref_granted_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_revoked_context] FOREIGN KEY ([ref_revoked_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_user_entitlements] ADD CONSTRAINT [FK_sue_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [FK_cmmf_model] FOREIGN KEY ([ref_model_guid]) REFERENCES [etg].[contracts_modules_models] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [FK_cmmf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [FK_cmmf_type] FOREIGN KEY ([ref_type_guid]) REFERENCES [etg].[contracts_primitives_types] ([key_guid]);
ALTER TABLE [etg].[contracts_modules_models_fields] ADD CONSTRAINT [FK_cmmf_type_model] FOREIGN KEY ([ref_type_model_guid]) REFERENCES [etg].[contracts_modules_models] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_entitlement] FOREIGN KEY ([ref_entitlement_guid]) REFERENCES [dbo].[service_security_entitlements] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_subdomain_entitlements] ADD CONSTRAINT [FK_cuse_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_channel] FOREIGN KEY ([ref_channel_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_parent] FOREIGN KEY ([ref_parent_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_security_contexts] ADD CONSTRAINT [FK_ssco_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_granted_context] FOREIGN KEY ([ref_granted_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_revoked_context] FOREIGN KEY ([ref_revoked_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_role] FOREIGN KEY ([ref_role_guid]) REFERENCES [dbo].[service_security_roles] ([key_guid]);
ALTER TABLE [dbo].[system_user_roles] ADD CONSTRAINT [FK_sur_user] FOREIGN KEY ([ref_user_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_column] FOREIGN KEY ([ref_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_constraint] FOREIGN KEY ([ref_constraint_guid]) REFERENCES [etg].[contracts_db_constraints] ([key_guid]);
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_db_constraint_columns] ADD CONSTRAINT [FK_cdcc_ref_column] FOREIGN KEY ([ref_referenced_column_guid]) REFERENCES [etg].[contracts_db_columns] ([key_guid]);
ALTER TABLE [dbo].[service_system_configuration] ADD CONSTRAINT [FK_ssc_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [FK_cplf_input_model] FOREIGN KEY ([ref_input_model_guid]) REFERENCES [etg].[contracts_primitives_libraries_models] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [FK_cplf_library] FOREIGN KEY ([ref_library_guid]) REFERENCES [etg].[contracts_primitives_libraries] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [FK_cplf_output_model] FOREIGN KEY ([ref_output_model_guid]) REFERENCES [etg].[contracts_primitives_libraries_models] ([key_guid]);
ALTER TABLE [etg].[contracts_primitives_libraries_functions] ADD CONSTRAINT [FK_cplf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_layer] FOREIGN KEY ([ref_layer_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_security_denials] ADD CONSTRAINT [FK_ssd_reason] FOREIGN KEY ([ref_reason_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_domain] FOREIGN KEY ([ref_domain_guid]) REFERENCES [etg].[contracts_urn_domains] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_module_function] FOREIGN KEY ([ref_module_function_guid]) REFERENCES [etg].[contracts_modules_functions] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_namespace] FOREIGN KEY ([ref_namespace_guid]) REFERENCES [etg].[contracts_urn_namespaces] ([key_guid]);
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [etg].[contracts_urn_functions] ADD CONSTRAINT [FK_cuf_subdomain] FOREIGN KEY ([ref_subdomain_guid]) REFERENCES [etg].[contracts_urn_subdomains] ([key_guid]);
ALTER TABLE [dbo].[system_sequences] ADD CONSTRAINT [FK_ss_kind] FOREIGN KEY ([ref_kind_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_sequences] ADD CONSTRAINT [FK_ss_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_actor] FOREIGN KEY ([ref_actor_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_context] FOREIGN KEY ([ref_context_guid]) REFERENCES [dbo].[system_security_contexts] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_definition] FOREIGN KEY ([ref_definition_guid]) REFERENCES [dbo].[service_workflow_definitions] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_disposition] FOREIGN KEY ([ref_disposition_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_host] FOREIGN KEY ([ref_host_guid]) REFERENCES [dbo].[service_hosts] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_package] FOREIGN KEY ([ref_package_guid]) REFERENCES [dbo].[service_packages_manifest] ([key_guid]) ON DELETE CASCADE;
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_principal] FOREIGN KEY ([ref_principal_guid]) REFERENCES [dbo].[system_users] ([key_guid]);
ALTER TABLE [dbo].[system_workflow_history] ADD CONSTRAINT [FK_swh_status] FOREIGN KEY ([ref_status_enum_guid]) REFERENCES [etg].[contracts_primitives_enums] ([key_guid]);

-- Procedures
GO