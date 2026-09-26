-- ============================================================================
-- migrate_005_bootstrap_operations.sql
--
-- Migrates the bootstrap DDL/management queries from scriptlib.py into
-- contracts_db_operations as data rows. Twenty-one operations covering:
--
--   Cluster C (8 ops): pure reads of contracts_db_* and seed metadata
--     - read_tables, read_columns, read_indexes, read_index_columns,
--       read_constraints, read_constraint_columns, read_seed_table_list,
--       read_seed_column_projection
--
--   Cluster E (5 ops): package management against the manifest
--     - list_manifest_rows, list_package_owned_tables, list_package_ext_columns,
--       set_manifest_sealed, delete_manifest_row
--     (resolve_package was migrated previously and isn't re-asserted here.)
--
--   Engine introspection (6 ops): MSSQL sys.* reads
--     - list_physical_tables, check_table_has_package_column,
--       list_physical_tables_with_package_column, check_physical_table_exists,
--       list_indexes_on_column, list_fks_on_column
--
--   Maintenance (2 ops): MSSQL-specific
--     - update_statistics, free_proc_cache
--
-- All operations are URN-named under db:contracts:db:<op>:1.
-- pub_query_mssql holds the literal query body. pub_query_postgres and
-- pub_query_mysql are NULL; engine-specific bodies for those engines are
-- separate authoring work.
--
-- pub_bootstrap_element = 1 on every row: these are all called by the
-- install/uninstall pipeline itself.
--
-- Output models follow the convention <op>_output. Input models follow
-- <op>_input. Operations with no parameters have ref_input_model_guid = NULL.
-- Operations dispatched via .execute() (UPDATE/DELETE/EXEC/DDL) have
-- ref_output_model_guid = NULL; the database execution provider's two
-- API surfaces (.query() and .execute()) handle the row-vs-rowcount
-- distinction at the dispatch layer.
--
-- This migration is mechanical. Stepping stone for the kernel database
-- module to read these rows and dispatch them. Throwaway. MERGE-based,
-- idempotent.
-- ============================================================================
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_tables:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '824C72C5-6DB4-5836-9B08-15D96824391D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_tables_output',
  pub_notes = 'Output model for db:contracts:db:read_tables:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('824C72C5-6DB4-5836-9B08-15D96824391D', 'read_tables_output', 'Output model for db:contracts:db:read_tables:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '04468668-F212-5069-8643-65342F22B1FB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '824C72C5-6DB4-5836-9B08-15D96824391D',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('04468668-F212-5069-8643-65342F22B1FB', '824C72C5-6DB4-5836-9B08-15D96824391D', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '8AAC0DDB-D8DE-582A-8B95-02FD4F78467D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '824C72C5-6DB4-5836-9B08-15D96824391D',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8AAC0DDB-D8DE-582A-8B95-02FD4F78467D', '824C72C5-6DB4-5836-9B08-15D96824391D', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '724CC2BA-A2E8-5FE1-AD2A-CA16E0588614' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '824C72C5-6DB4-5836-9B08-15D96824391D',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('724CC2BA-A2E8-5FE1-AD2A-CA16E0588614', '824C72C5-6DB4-5836-9B08-15D96824391D', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 3, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '8D36F179-4216-5703-AF19-E1B61BCFB525' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '824C72C5-6DB4-5836-9B08-15D96824391D',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_alias',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8D36F179-4216-5703-AF19-E1B61BCFB525', '824C72C5-6DB4-5836-9B08-15D96824391D', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_alias', 4, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '50519800-AAE3-5918-A735-2DD80CF2D781' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_tables:1',
  pub_query_mssql = 'SELECT key_guid, pub_name, pub_schema, pub_alias FROM contracts_db_tables ORDER BY pub_schema, pub_name FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read all rows from contracts_db_tables. Used by dump and materialize.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '824C72C5-6DB4-5836-9B08-15D96824391D'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('50519800-AAE3-5918-A735-2DD80CF2D781', 'db:contracts:db:read_tables:1', 'SELECT key_guid, pub_name, pub_schema, pub_alias FROM contracts_db_tables ORDER BY pub_schema, pub_name FOR JSON PATH', NULL, NULL, 1, 'Read all rows from contracts_db_tables. Used by dump and materialize.', NULL, '824C72C5-6DB4-5836-9B08-15D96824391D');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_columns:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_columns_output',
  pub_notes = 'Output model for db:contracts:db:read_columns:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'read_columns_output', 'Output model for db:contracts:db:read_columns:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '53E6F233-A84C-5B7F-BB62-839B68852E00' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('53E6F233-A84C-5B7F-BB62-839B68852E00', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'E495E08E-5FA4-5AC8-9A7B-0A7C0B62766F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_table_guid',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E495E08E-5FA4-5AC8-9A7B-0A7C0B62766F', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_table_guid', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '4F6BEBBC-9F39-58C7-B8CE-DF5984697B67' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('4F6BEBBC-9F39-58C7-B8CE-DF5984697B67', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '15BB6EE7-227D-5045-AE3F-ED2233AE5286' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_ordinal',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('15BB6EE7-227D-5045-AE3F-ED2233AE5286', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_ordinal', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'E15B3FE0-B6F9-51CD-A09E-73468C964355' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_is_nullable',
  pub_ordinal = 5,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E15B3FE0-B6F9-51CD-A09E-73468C964355', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_is_nullable', 5, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '4B8E7BAF-A641-5BF2-8F9C-D29017FAF036' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_default_value',
  pub_ordinal = 6,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 512
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('4B8E7BAF-A641-5BF2-8F9C-D29017FAF036', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_default_value', 6, 1, NULL, 512);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B85A567D-E540-5020-99A9-2A1F074CA19A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_max_length',
  pub_ordinal = 7,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B85A567D-E540-5020-99A9-2A1F074CA19A', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_max_length', 7, 1, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'DCF1E853-FB81-52B0-91B2-B0C93D4FA8CD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_mssql_type',
  pub_ordinal = 8,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('DCF1E853-FB81-52B0-91B2-B0C93D4FA8CD', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_mssql_type', 8, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '38F37E79-F117-5C00-ABBB-D16EAD4611D4' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_default_length',
  pub_ordinal = 9,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('38F37E79-F117-5C00-ABBB-D16EAD4611D4', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_default_length', 9, 1, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'CE84DBE7-F97B-56FB-8602-98EE62C9DFEB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'type_name',
  pub_ordinal = 10,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('CE84DBE7-F97B-56FB-8602-98EE62C9DFEB', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'type_name', 10, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '9ED06D9C-0FBF-5C3B-A11F-E9C6CC145574' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_emits_length',
  pub_ordinal = 11,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('9ED06D9C-0FBF-5C3B-A11F-E9C6CC145574', '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_emits_length', 11, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '0C7A41A5-2B9A-52C4-975B-D5777CB41203' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_columns:1',
  pub_query_mssql = 'SELECT c.key_guid, c.ref_table_guid, c.pub_name, c.pub_ordinal, c.pub_is_nullable, c.pub_default_value, c.pub_max_length, t.pub_mssql_type, t.pub_default_length, t.pub_name AS type_name, t.pub_emits_length FROM contracts_db_columns c JOIN contracts_primitives_types t ON c.ref_type_guid = t.key_guid ORDER BY c.ref_table_guid, c.pub_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read all rows from contracts_db_columns joined to contracts_primitives_types. Used by dump and materialize for DDL emission.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('0C7A41A5-2B9A-52C4-975B-D5777CB41203', 'db:contracts:db:read_columns:1', 'SELECT c.key_guid, c.ref_table_guid, c.pub_name, c.pub_ordinal, c.pub_is_nullable, c.pub_default_value, c.pub_max_length, t.pub_mssql_type, t.pub_default_length, t.pub_name AS type_name, t.pub_emits_length FROM contracts_db_columns c JOIN contracts_primitives_types t ON c.ref_type_guid = t.key_guid ORDER BY c.ref_table_guid, c.pub_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read all rows from contracts_db_columns joined to contracts_primitives_types. Used by dump and materialize for DDL emission.', NULL, '9D7F7E7B-1562-5788-9FF3-A89E9F280B5B');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_indexes:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '0389AD92-4AA9-57AD-8069-9EFBE5568D65' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_indexes_output',
  pub_notes = 'Output model for db:contracts:db:read_indexes:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('0389AD92-4AA9-57AD-8069-9EFBE5568D65', 'read_indexes_output', 'Output model for db:contracts:db:read_indexes:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '1A93A1C6-4580-51D8-8C3B-33D34A08F379' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0389AD92-4AA9-57AD-8069-9EFBE5568D65',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('1A93A1C6-4580-51D8-8C3B-33D34A08F379', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '6A349796-E031-5AA5-B388-3B8ED40B3D58' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0389AD92-4AA9-57AD-8069-9EFBE5568D65',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_table_guid',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6A349796-E031-5AA5-B388-3B8ED40B3D58', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_table_guid', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '8AF35F6E-E65F-5654-8227-CEEBB3CF9FCE' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0389AD92-4AA9-57AD-8069-9EFBE5568D65',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8AF35F6E-E65F-5654-8227-CEEBB3CF9FCE', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 3, 0, NULL, 256);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'AD77E785-DF9B-5F5E-889F-8EE663D700F7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0389AD92-4AA9-57AD-8069-9EFBE5568D65',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_is_unique',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('AD77E785-DF9B-5F5E-889F-8EE663D700F7', '0389AD92-4AA9-57AD-8069-9EFBE5568D65', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_is_unique', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '6AE5285C-A13B-5A9B-8682-4CC9C1EBED5A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_indexes:1',
  pub_query_mssql = 'SELECT key_guid, ref_table_guid, pub_name, pub_is_unique FROM contracts_db_indexes ORDER BY ref_table_guid, pub_name FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read all rows from contracts_db_indexes. Used by dump and materialize.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '0389AD92-4AA9-57AD-8069-9EFBE5568D65'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('6AE5285C-A13B-5A9B-8682-4CC9C1EBED5A', 'db:contracts:db:read_indexes:1', 'SELECT key_guid, ref_table_guid, pub_name, pub_is_unique FROM contracts_db_indexes ORDER BY ref_table_guid, pub_name FOR JSON PATH', NULL, NULL, 1, 'Read all rows from contracts_db_indexes. Used by dump and materialize.', NULL, '0389AD92-4AA9-57AD-8069-9EFBE5568D65');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_index_columns:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_index_columns_output',
  pub_notes = 'Output model for db:contracts:db:read_index_columns:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', 'read_index_columns_output', 'Output model for db:contracts:db:read_index_columns:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'EF3DFD78-0954-5E85-AD8B-81183F143117' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_index_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('EF3DFD78-0954-5E85-AD8B-81183F143117', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_index_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '5AF8A97B-A853-553C-B7DE-53304E1FD1A7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_ordinal',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('5AF8A97B-A853-553C-B7DE-53304E1FD1A7', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_ordinal', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '05EA1749-4AA2-5E03-BE5E-9F73548C5316' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'column_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('05EA1749-4AA2-5E03-BE5E-9F73548C5316', '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'column_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '673FC7B9-094E-5CCA-AD01-96B5E29550F7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_index_columns:1',
  pub_query_mssql = 'SELECT ic.ref_index_guid, ic.pub_ordinal, c.pub_name AS column_name FROM contracts_db_index_columns ic JOIN contracts_db_columns c ON ic.ref_column_guid = c.key_guid ORDER BY ic.ref_index_guid, ic.pub_ordinal FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read index column membership joined to column names. Used by dump and materialize.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('673FC7B9-094E-5CCA-AD01-96B5E29550F7', 'db:contracts:db:read_index_columns:1', 'SELECT ic.ref_index_guid, ic.pub_ordinal, c.pub_name AS column_name FROM contracts_db_index_columns ic JOIN contracts_db_columns c ON ic.ref_column_guid = c.key_guid ORDER BY ic.ref_index_guid, ic.pub_ordinal FOR JSON PATH', NULL, NULL, 1, 'Read index column membership joined to column names. Used by dump and materialize.', NULL, '804CE79C-9FC9-5B03-9B51-7D1C7E881B8F');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_constraints:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '7BF9E37A-C65E-583E-AD71-5B55E584DE2C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_constraints_output',
  pub_notes = 'Output model for db:contracts:db:read_constraints:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'read_constraints_output', 'Output model for db:contracts:db:read_constraints:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B6B88B8A-B829-5624-A938-3D76F1CD45B2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B6B88B8A-B829-5624-A938-3D76F1CD45B2', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '6EE4EF2D-D858-565C-A74A-21131C0BA210' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_table_guid',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6EE4EF2D-D858-565C-A74A-21131C0BA210', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_table_guid', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '01B8E37E-84B1-557F-A7D3-6112BC0563DA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_referenced_table_guid',
  pub_ordinal = 3,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('01B8E37E-84B1-557F-A7D3-6112BC0563DA', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_referenced_table_guid', 3, 1, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '7FE04F71-9FCC-5EA8-91B6-E843467ED7D1' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('7FE04F71-9FCC-5EA8-91B6-E843467ED7D1', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 4, 0, NULL, 256);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B056B552-5919-5351-940C-96CA6D8A94FB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',
  pub_name = 'pub_expression',
  pub_ordinal = 5,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B056B552-5919-5351-940C-96CA6D8A94FB', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6', 'pub_expression', 5, 1, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '2D82E362-46C4-5C53-8334-C965FA9F830F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  pub_name = 'pub_delete_disposition',
  pub_ordinal = 6,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('2D82E362-46C4-5C53-8334-C965FA9F830F', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'pub_delete_disposition', 6, 1, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '336538E5-6189-525F-9565-52B9E04DE493' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'kind_name',
  pub_ordinal = 7,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('336538E5-6189-525F-9565-52B9E04DE493', '7BF9E37A-C65E-583E-AD71-5B55E584DE2C', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'kind_name', 7, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '8466098A-0485-540A-B54F-FF05D40B56A6' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_constraints:1',
  pub_query_mssql = 'SELECT cn.key_guid, cn.ref_table_guid, cn.ref_referenced_table_guid, cn.pub_name, cn.pub_expression, cn.pub_delete_disposition, e.pub_name AS kind_name FROM contracts_db_constraints cn JOIN contracts_primitives_enums e ON cn.ref_kind_enum_guid = e.key_guid ORDER BY cn.ref_table_guid, e.pub_value, cn.pub_name FOR JSON PATH, INCLUDE_NULL_VALUES',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read constraints joined to constraint_kind enum for kind_name resolution. Used by dump and materialize.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '7BF9E37A-C65E-583E-AD71-5B55E584DE2C'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('8466098A-0485-540A-B54F-FF05D40B56A6', 'db:contracts:db:read_constraints:1', 'SELECT cn.key_guid, cn.ref_table_guid, cn.ref_referenced_table_guid, cn.pub_name, cn.pub_expression, cn.pub_delete_disposition, e.pub_name AS kind_name FROM contracts_db_constraints cn JOIN contracts_primitives_enums e ON cn.ref_kind_enum_guid = e.key_guid ORDER BY cn.ref_table_guid, e.pub_value, cn.pub_name FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read constraints joined to constraint_kind enum for kind_name resolution. Used by dump and materialize.', NULL, '7BF9E37A-C65E-583E-AD71-5B55E584DE2C');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_constraint_columns:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '5A3956C2-B48B-5712-948A-7AB479F56009' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_constraint_columns_output',
  pub_notes = 'Output model for db:contracts:db:read_constraint_columns:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('5A3956C2-B48B-5712-948A-7AB479F56009', 'read_constraint_columns_output', 'Output model for db:contracts:db:read_constraint_columns:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B7000A29-FACD-5E20-9D0B-4A2296BD2DBB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5A3956C2-B48B-5712-948A-7AB479F56009',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_constraint_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B7000A29-FACD-5E20-9D0B-4A2296BD2DBB', '5A3956C2-B48B-5712-948A-7AB479F56009', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_constraint_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'A966110F-2A12-5F9F-A189-1638E15A1748' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5A3956C2-B48B-5712-948A-7AB479F56009',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'pub_ordinal',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A966110F-2A12-5F9F-A189-1638E15A1748', '5A3956C2-B48B-5712-948A-7AB479F56009', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'pub_ordinal', 2, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '92B53374-C77D-5F83-90FE-9CA0DC1B6A09' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5A3956C2-B48B-5712-948A-7AB479F56009',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'column_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('92B53374-C77D-5F83-90FE-9CA0DC1B6A09', '5A3956C2-B48B-5712-948A-7AB479F56009', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'column_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '8B1160A4-10B0-5CD0-BB24-A51562D75945' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '5A3956C2-B48B-5712-948A-7AB479F56009',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'ref_column_name',
  pub_ordinal = 4,
  pub_is_nullable = 1,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8B1160A4-10B0-5CD0-BB24-A51562D75945', '5A3956C2-B48B-5712-948A-7AB479F56009', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'ref_column_name', 4, 1, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '564A31D5-E231-5F15-BB8B-2DDD09C2121C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_constraint_columns:1',
  pub_query_mssql = 'SELECT cc.ref_constraint_guid, cc.pub_ordinal, c.pub_name AS column_name, rc.pub_name AS ref_column_name FROM contracts_db_constraint_columns cc JOIN contracts_db_columns c ON cc.ref_column_guid = c.key_guid LEFT JOIN contracts_db_columns rc ON cc.ref_referenced_column_guid = rc.key_guid ORDER BY cc.ref_constraint_guid, cc.pub_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Read constraint column membership. FK rows include ref_column_name; PK/UQ/CHECK rows have NULL. Used by dump and materialize.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '5A3956C2-B48B-5712-948A-7AB479F56009'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('564A31D5-E231-5F15-BB8B-2DDD09C2121C', 'db:contracts:db:read_constraint_columns:1', 'SELECT cc.ref_constraint_guid, cc.pub_ordinal, c.pub_name AS column_name, rc.pub_name AS ref_column_name FROM contracts_db_constraint_columns cc JOIN contracts_db_columns c ON cc.ref_column_guid = c.key_guid LEFT JOIN contracts_db_columns rc ON cc.ref_referenced_column_guid = rc.key_guid ORDER BY cc.ref_constraint_guid, cc.pub_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES', NULL, NULL, 1, 'Read constraint column membership. FK rows include ref_column_name; PK/UQ/CHECK rows have NULL. Used by dump and materialize.', NULL, '5A3956C2-B48B-5712-948A-7AB479F56009');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_seed_table_list:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '09A5C28E-AAA9-505D-8A06-EE489F336B69' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_seed_table_list_output',
  pub_notes = 'Output model for db:contracts:db:read_seed_table_list:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('09A5C28E-AAA9-505D-8A06-EE489F336B69', 'read_seed_table_list_output', 'Output model for db:contracts:db:read_seed_table_list:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '446E13F4-BE4E-582F-AB7E-CC9F0025EF5F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '09A5C28E-AAA9-505D-8A06-EE489F336B69',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('446E13F4-BE4E-582F-AB7E-CC9F0025EF5F', '09A5C28E-AAA9-505D-8A06-EE489F336B69', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '27B8BF59-CD37-563F-9641-FDBEF05122ED' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '09A5C28E-AAA9-505D-8A06-EE489F336B69',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('27B8BF59-CD37-563F-9641-FDBEF05122ED', '09A5C28E-AAA9-505D-8A06-EE489F336B69', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '28ED9F4A-86EB-59AF-A9E8-F42C741A78FD' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '09A5C28E-AAA9-505D-8A06-EE489F336B69',
  ref_type_guid = '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
  pub_name = 'pub_seed_element',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('28ED9F4A-86EB-59AF-A9E8-F42C741A78FD', '09A5C28E-AAA9-505D-8A06-EE489F336B69', '0D331097-4AB4-5AA2-A481-07AB66A29BBD', 'pub_seed_element', 3, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '3535C42A-BB38-5A2E-94B3-916171211704' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_seed_table_list:1',
  pub_query_mssql = 'SELECT key_guid, pub_name, pub_seed_element FROM contracts_db_tables WHERE pub_seed_element > 0 ORDER BY pub_seed_element FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List seed-flagged tables in install order. Used by generate_seed.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '09A5C28E-AAA9-505D-8A06-EE489F336B69'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('3535C42A-BB38-5A2E-94B3-916171211704', 'db:contracts:db:read_seed_table_list:1', 'SELECT key_guid, pub_name, pub_seed_element FROM contracts_db_tables WHERE pub_seed_element > 0 ORDER BY pub_seed_element FOR JSON PATH', NULL, NULL, 1, 'List seed-flagged tables in install order. Used by generate_seed.', NULL, '09A5C28E-AAA9-505D-8A06-EE489F336B69');

-- ----------------------------------------------------------------------------
-- db:contracts:db:read_seed_column_projection:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'E598D705-DB31-553A-AB1B-0AB32C1EC96F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_seed_column_projection_input',
  pub_notes = 'Input model for db:contracts:db:read_seed_column_projection:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('E598D705-DB31-553A-AB1B-0AB32C1EC96F', 'read_seed_column_projection_input', 'Input model for db:contracts:db:read_seed_column_projection:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '09FA65FB-7960-5E09-9CDA-2A1AC496C948' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'E598D705-DB31-553A-AB1B-0AB32C1EC96F',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_table_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('09FA65FB-7960-5E09-9CDA-2A1AC496C948', 'E598D705-DB31-553A-AB1B-0AB32C1EC96F', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_table_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'read_seed_column_projection_output',
  pub_notes = 'Output model for db:contracts:db:read_seed_column_projection:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37', 'read_seed_column_projection_output', 'Output model for db:contracts:db:read_seed_column_projection:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B764150D-6367-51A1-8CB6-7C0BAE983598' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B764150D-6367-51A1-8CB6-7C0BAE983598', 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 1, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT 'DBE765C1-2A7F-5E01-B586-1AB86F4264BA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:read_seed_column_projection:1',
  pub_query_mssql = 'SELECT pub_name FROM contracts_db_columns WHERE ref_table_guid = ? AND pub_exclude_element = 0 ORDER BY pub_ordinal FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Projected column names for a seed table, excluding pub_exclude_element=1 columns. Used by generate_seed.',
  ref_input_model_guid = 'E598D705-DB31-553A-AB1B-0AB32C1EC96F',
  ref_output_model_guid = 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('DBE765C1-2A7F-5E01-B586-1AB86F4264BA', 'db:contracts:db:read_seed_column_projection:1', 'SELECT pub_name FROM contracts_db_columns WHERE ref_table_guid = ? AND pub_exclude_element = 0 ORDER BY pub_ordinal FOR JSON PATH', NULL, NULL, 1, 'Projected column names for a seed table, excluding pub_exclude_element=1 columns. Used by generate_seed.', 'E598D705-DB31-553A-AB1B-0AB32C1EC96F', 'FD8F4C8E-3B02-5928-A5C2-FBED5EB5AD37');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_manifest_rows:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'BF39BDE4-4185-565B-89B0-35A50701C1E0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_manifest_rows_output',
  pub_notes = 'Output model for db:contracts:db:list_manifest_rows:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('BF39BDE4-4185-565B-89B0-35A50701C1E0', 'list_manifest_rows_output', 'Output model for db:contracts:db:list_manifest_rows:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '9FB4A6C6-F393-5ED6-923C-C3DCCA74BB53' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BF39BDE4-4185-565B-89B0-35A50701C1E0',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('9FB4A6C6-F393-5ED6-923C-C3DCCA74BB53', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'EA8E786A-57BF-5DA4-B579-AB52020C2975' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BF39BDE4-4185-565B-89B0-35A50701C1E0',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('EA8E786A-57BF-5DA4-B579-AB52020C2975', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 2, 0, NULL, 256);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '6FBD9D37-70A9-59D3-B677-9A1CC3B6BB4C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BF39BDE4-4185-565B-89B0-35A50701C1E0',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_version',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6FBD9D37-70A9-59D3-B677-9A1CC3B6BB4C', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_version', 3, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '6E06BE45-7416-5C0F-B113-C6443850765B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BF39BDE4-4185-565B-89B0-35A50701C1E0',
  ref_type_guid = '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
  pub_name = 'pub_is_sealed',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6E06BE45-7416-5C0F-B113-C6443850765B', 'BF39BDE4-4185-565B-89B0-35A50701C1E0', '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC', 'pub_is_sealed', 4, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '8F1C8960-1B1D-59F9-A2CB-96DFE5CA82F3' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_manifest_rows:1',
  pub_query_mssql = 'SELECT key_guid, pub_name, pub_version, pub_is_sealed FROM service_modules_manifest ORDER BY pub_name FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List all packages from service_modules_manifest. Used by list_packages.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = 'BF39BDE4-4185-565B-89B0-35A50701C1E0'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('8F1C8960-1B1D-59F9-A2CB-96DFE5CA82F3', 'db:contracts:db:list_manifest_rows:1', 'SELECT key_guid, pub_name, pub_version, pub_is_sealed FROM service_modules_manifest ORDER BY pub_name FOR JSON PATH', NULL, NULL, 1, 'List all packages from service_modules_manifest. Used by list_packages.', NULL, 'BF39BDE4-4185-565B-89B0-35A50701C1E0');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_package_owned_tables:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '907D816F-63E6-5FCE-A40A-3DB38349317D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_package_owned_tables_input',
  pub_notes = 'Input model for db:contracts:db:list_package_owned_tables:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('907D816F-63E6-5FCE-A40A-3DB38349317D', 'list_package_owned_tables_input', 'Input model for db:contracts:db:list_package_owned_tables:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '2FD5F5B1-2BBC-5536-86F9-45C5CF54FC33' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '907D816F-63E6-5FCE-A40A-3DB38349317D',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('2FD5F5B1-2BBC-5536-86F9-45C5CF54FC33', '907D816F-63E6-5FCE-A40A-3DB38349317D', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_package_owned_tables_output',
  pub_notes = 'Output model for db:contracts:db:list_package_owned_tables:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('B3A5C093-4FCF-5641-A3FE-7F8E887537E2', 'list_package_owned_tables_output', 'Output model for db:contracts:db:list_package_owned_tables:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '1D30CD4A-51AD-53DB-9AC2-93A6900B1063' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('1D30CD4A-51AD-53DB-9AC2-93A6900B1063', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'C4FC2CB8-BBB2-5F68-9538-07A6BB898E1C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('C4FC2CB8-BBB2-5F68-9538-07A6BB898E1C', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 2, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B2788AB6-031F-59E2-8253-F8A255D0028C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B2788AB6-031F-59E2-8253-F8A255D0028C', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '7446EA9B-882F-5CF1-958B-6469CABAB55F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_package_owned_tables:1',
  pub_query_mssql = 'SELECT key_guid, pub_schema, pub_name FROM contracts_db_tables WHERE ref_package_guid = ? FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List tables owned by a package. Used by uninstall scan to determine which physical tables to drop.',
  ref_input_model_guid = '907D816F-63E6-5FCE-A40A-3DB38349317D',
  ref_output_model_guid = 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('7446EA9B-882F-5CF1-958B-6469CABAB55F', 'db:contracts:db:list_package_owned_tables:1', 'SELECT key_guid, pub_schema, pub_name FROM contracts_db_tables WHERE ref_package_guid = ? FOR JSON PATH', NULL, NULL, 1, 'List tables owned by a package. Used by uninstall scan to determine which physical tables to drop.', '907D816F-63E6-5FCE-A40A-3DB38349317D', 'B3A5C093-4FCF-5641-A3FE-7F8E887537E2');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_package_ext_columns:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '359138B1-2CE7-50BF-BC99-042D92DF0E09' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_package_ext_columns_input',
  pub_notes = 'Input model for db:contracts:db:list_package_ext_columns:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('359138B1-2CE7-50BF-BC99-042D92DF0E09', 'list_package_ext_columns_input', 'Input model for db:contracts:db:list_package_ext_columns:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'D5EC3D3C-B05C-5B5B-BCD0-21BBBC0A9175' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '359138B1-2CE7-50BF-BC99-042D92DF0E09',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_package_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('D5EC3D3C-B05C-5B5B-BCD0-21BBBC0A9175', '359138B1-2CE7-50BF-BC99-042D92DF0E09', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_package_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'BA1E762E-8437-586F-9264-D1A05697559E' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_package_ext_columns_output',
  pub_notes = 'Output model for db:contracts:db:list_package_ext_columns:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('BA1E762E-8437-586F-9264-D1A05697559E', 'list_package_ext_columns_output', 'Output model for db:contracts:db:list_package_ext_columns:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '99553ADD-8979-58D9-90BC-B587A4FB5681' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('99553ADD-8979-58D9-90BC-B587A4FB5681', 'BA1E762E-8437-586F-9264-D1A05697559E', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '86727B04-D355-5778-A8A8-97081BDB64CF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'column_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('86727B04-D355-5778-A8A8-97081BDB64CF', 'BA1E762E-8437-586F-9264-D1A05697559E', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'column_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'A3FE69F6-E3DD-5BE8-96CC-5B35A1CAAFBF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'ref_table_guid',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A3FE69F6-E3DD-5BE8-96CC-5B35A1CAAFBF', 'BA1E762E-8437-586F-9264-D1A05697559E', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'ref_table_guid', 3, 0, NULL, NULL);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '1073DB51-C923-54BA-9F12-42920CF1715B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 4,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('1073DB51-C923-54BA-9F12-42920CF1715B', 'BA1E762E-8437-586F-9264-D1A05697559E', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 4, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'A7389ACB-5D8E-5EB3-93AD-875704377B64' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'table_name',
  pub_ordinal = 5,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('A7389ACB-5D8E-5EB3-93AD-875704377B64', 'BA1E762E-8437-586F-9264-D1A05697559E', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'table_name', 5, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '2E7334B9-78F2-5697-96D4-37485E257786' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_package_ext_columns:1',
  pub_query_mssql = 'SELECT c.key_guid, c.pub_name AS column_name, c.ref_table_guid, t.pub_schema, t.pub_name AS table_name FROM contracts_db_columns c JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid WHERE c.ref_package_guid = ? FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List columns owned by a package, joined to their parent table info. Caller filters for ext columns where parent table is not also owned by the package.',
  ref_input_model_guid = '359138B1-2CE7-50BF-BC99-042D92DF0E09',
  ref_output_model_guid = 'BA1E762E-8437-586F-9264-D1A05697559E'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('2E7334B9-78F2-5697-96D4-37485E257786', 'db:contracts:db:list_package_ext_columns:1', 'SELECT c.key_guid, c.pub_name AS column_name, c.ref_table_guid, t.pub_schema, t.pub_name AS table_name FROM contracts_db_columns c JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid WHERE c.ref_package_guid = ? FOR JSON PATH', NULL, NULL, 1, 'List columns owned by a package, joined to their parent table info. Caller filters for ext columns where parent table is not also owned by the package.', '359138B1-2CE7-50BF-BC99-042D92DF0E09', 'BA1E762E-8437-586F-9264-D1A05697559E');

-- ----------------------------------------------------------------------------
-- db:contracts:db:set_manifest_sealed:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'set_manifest_sealed_input',
  pub_notes = 'Input model for db:contracts:db:set_manifest_sealed:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', 'set_manifest_sealed_input', 'Input model for db:contracts:db:set_manifest_sealed:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '286D534A-8D03-512E-9CC2-D5A054B9E52D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('286D534A-8D03-512E-9CC2-D5A054B9E52D', 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '296651AD-F4D5-5D89-86A4-F7027B2838F8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:set_manifest_sealed:1',
  pub_query_mssql = 'UPDATE service_modules_manifest SET pub_is_sealed = 1 WHERE key_guid = ?',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Mark a manifest row as sealed. Used by install Phase 5.',
  ref_input_model_guid = 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9',
  ref_output_model_guid = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('296651AD-F4D5-5D89-86A4-F7027B2838F8', 'db:contracts:db:set_manifest_sealed:1', 'UPDATE service_modules_manifest SET pub_is_sealed = 1 WHERE key_guid = ?', NULL, NULL, 1, 'Mark a manifest row as sealed. Used by install Phase 5.', 'AFECF3D6-2D9F-507D-9EE7-2314ADECE8F9', NULL);

-- ----------------------------------------------------------------------------
-- db:contracts:db:delete_manifest_row:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '843D2319-E230-5714-8F6C-1C1CC7EBCD50' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'delete_manifest_row_input',
  pub_notes = 'Input model for db:contracts:db:delete_manifest_row:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('843D2319-E230-5714-8F6C-1C1CC7EBCD50', 'delete_manifest_row_input', 'Input model for db:contracts:db:delete_manifest_row:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '30E6B306-4C51-5830-9FF7-02ADD31AEDD8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '843D2319-E230-5714-8F6C-1C1CC7EBCD50',
  ref_type_guid = 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
  pub_name = 'key_guid',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('30E6B306-4C51-5830-9FF7-02ADD31AEDD8', '843D2319-E230-5714-8F6C-1C1CC7EBCD50', 'DF427A75-F5DE-5797-988A-F2FF40BD7FA5', 'key_guid', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '13140348-71BE-5A4B-9209-36F84FFA6E00' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:delete_manifest_row:1',
  pub_query_mssql = 'DELETE FROM service_modules_manifest WHERE key_guid = ?',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Delete a manifest row. Cascade-on-delete walks the FK graph and removes every package-owned row across the kernel tables. Used by uninstall step 3.',
  ref_input_model_guid = '843D2319-E230-5714-8F6C-1C1CC7EBCD50',
  ref_output_model_guid = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('13140348-71BE-5A4B-9209-36F84FFA6E00', 'db:contracts:db:delete_manifest_row:1', 'DELETE FROM service_modules_manifest WHERE key_guid = ?', NULL, NULL, 1, 'Delete a manifest row. Cascade-on-delete walks the FK graph and removes every package-owned row across the kernel tables. Used by uninstall step 3.', '843D2319-E230-5714-8F6C-1C1CC7EBCD50', NULL);

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_physical_tables:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '8E519B15-C659-511E-983D-007B243EF505' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_physical_tables_output',
  pub_notes = 'Output model for db:contracts:db:list_physical_tables:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('8E519B15-C659-511E-983D-007B243EF505', 'list_physical_tables_output', 'Output model for db:contracts:db:list_physical_tables:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '6CEDF159-9CFD-5339-AB6D-BC00C2E4D067' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '8E519B15-C659-511E-983D-007B243EF505',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('6CEDF159-9CFD-5339-AB6D-BC00C2E4D067', '8E519B15-C659-511E-983D-007B243EF505', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 1, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '9A86A7AD-632A-54D7-A62D-01FFD8BAE244' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '8E519B15-C659-511E-983D-007B243EF505',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('9A86A7AD-632A-54D7-A62D-01FFD8BAE244', '8E519B15-C659-511E-983D-007B243EF505', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '5B88C303-2248-5C95-8676-9A42CF66126A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_physical_tables:1',
  pub_query_mssql = 'SELECT s.name AS pub_schema, t.name AS pub_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List physical tables in the engine catalog. MSSQL: sys.tables. Used by materialize for declared-vs-physical diff.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '8E519B15-C659-511E-983D-007B243EF505'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('5B88C303-2248-5C95-8676-9A42CF66126A', 'db:contracts:db:list_physical_tables:1', 'SELECT s.name AS pub_schema, t.name AS pub_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id FOR JSON PATH', NULL, NULL, 1, 'List physical tables in the engine catalog. MSSQL: sys.tables. Used by materialize for declared-vs-physical diff.', NULL, '8E519B15-C659-511E-983D-007B243EF505');

-- ----------------------------------------------------------------------------
-- db:contracts:db:check_table_has_package_column:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '87912659-527B-5173-B74A-C43EF898A113' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'check_table_has_package_column_input',
  pub_notes = 'Input model for db:contracts:db:check_table_has_package_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('87912659-527B-5173-B74A-C43EF898A113', 'check_table_has_package_column_input', 'Input model for db:contracts:db:check_table_has_package_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '919BED66-6D7A-5460-AD62-E92EDFFEC2B9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '87912659-527B-5173-B74A-C43EF898A113',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_table_name',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('919BED66-6D7A-5460-AD62-E92EDFFEC2B9', '87912659-527B-5173-B74A-C43EF898A113', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_table_name', 1, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'check_table_has_package_column_output',
  pub_notes = 'Output model for db:contracts:db:check_table_has_package_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8', 'check_table_has_package_column_output', 'Output model for db:contracts:db:check_table_has_package_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'E0DE7F8F-A662-5FDA-996A-73B9E184A805' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'ok',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E0DE7F8F-A662-5FDA-996A-73B9E184A805', 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'ok', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '45B42B2C-0E39-56FC-ACE2-A095AA8029DF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:check_table_has_package_column:1',
  pub_query_mssql = 'SELECT 1 AS ok FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id WHERE t.name = ? AND c.name = ''ref_package_guid'' FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Returns one row {ok:1} if the named table physically has a ref_package_guid column, else empty. Used by install pipeline auto-injection.',
  ref_input_model_guid = '87912659-527B-5173-B74A-C43EF898A113',
  ref_output_model_guid = 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('45B42B2C-0E39-56FC-ACE2-A095AA8029DF', 'db:contracts:db:check_table_has_package_column:1', 'SELECT 1 AS ok FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id WHERE t.name = ? AND c.name = ''ref_package_guid'' FOR JSON PATH', NULL, NULL, 1, 'Returns one row {ok:1} if the named table physically has a ref_package_guid column, else empty. Used by install pipeline auto-injection.', '87912659-527B-5173-B74A-C43EF898A113', 'EAB1D8A5-D7D7-58F0-85A9-C72BBB7505D8');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_physical_tables_with_package_column:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '0D9086F0-1B38-502D-9607-A580D21B9A24' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_physical_tables_with_package_column_output',
  pub_notes = 'Output model for db:contracts:db:list_physical_tables_with_package_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('0D9086F0-1B38-502D-9607-A580D21B9A24', 'list_physical_tables_with_package_column_output', 'Output model for db:contracts:db:list_physical_tables_with_package_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '092D1244-29E3-5B05-A9B3-2E5510BA572B' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0D9086F0-1B38-502D-9607-A580D21B9A24',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('092D1244-29E3-5B05-A9B3-2E5510BA572B', '0D9086F0-1B38-502D-9607-A580D21B9A24', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 1, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'B4C35685-7235-5AC3-A9CA-35529B5FF1CE' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '0D9086F0-1B38-502D-9607-A580D21B9A24',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('B4C35685-7235-5AC3-A9CA-35529B5FF1CE', '0D9086F0-1B38-502D-9607-A580D21B9A24', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '6BC72AED-3A33-5BD6-8433-0301334995E7' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_physical_tables_with_package_column:1',
  pub_query_mssql = 'SELECT s.name AS pub_schema, t.name AS pub_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id JOIN sys.columns c ON c.object_id = t.object_id WHERE c.name = ''ref_package_guid'' ORDER BY s.name, t.name FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List physical tables that have a ref_package_guid column. Used by list_packages and uninstall scan.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = '0D9086F0-1B38-502D-9607-A580D21B9A24'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('6BC72AED-3A33-5BD6-8433-0301334995E7', 'db:contracts:db:list_physical_tables_with_package_column:1', 'SELECT s.name AS pub_schema, t.name AS pub_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id JOIN sys.columns c ON c.object_id = t.object_id WHERE c.name = ''ref_package_guid'' ORDER BY s.name, t.name FOR JSON PATH', NULL, NULL, 1, 'List physical tables that have a ref_package_guid column. Used by list_packages and uninstall scan.', NULL, '0D9086F0-1B38-502D-9607-A580D21B9A24');

-- ----------------------------------------------------------------------------
-- db:contracts:db:check_physical_table_exists:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'D52527ED-7530-5A0E-91AA-5D6552FDB662' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'check_physical_table_exists_input',
  pub_notes = 'Input model for db:contracts:db:check_physical_table_exists:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('D52527ED-7530-5A0E-91AA-5D6552FDB662', 'check_physical_table_exists_input', 'Input model for db:contracts:db:check_physical_table_exists:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'F9920886-9D6A-5D45-9F9F-CEAB45F278D9' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'D52527ED-7530-5A0E-91AA-5D6552FDB662',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('F9920886-9D6A-5D45-9F9F-CEAB45F278D9', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 1, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '9C8D93AC-C394-5005-A2F3-0EEC69459A83' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'D52527ED-7530-5A0E-91AA-5D6552FDB662',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_table_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('9C8D93AC-C394-5005-A2F3-0EEC69459A83', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_table_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'A17D0129-73D9-5CDF-AF30-00B1257B8A26' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'check_physical_table_exists_output',
  pub_notes = 'Output model for db:contracts:db:check_physical_table_exists:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('A17D0129-73D9-5CDF-AF30-00B1257B8A26', 'check_physical_table_exists_output', 'Output model for db:contracts:db:check_physical_table_exists:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'E9EF2E2B-A512-5B11-927F-0F84461A461C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'A17D0129-73D9-5CDF-AF30-00B1257B8A26',
  ref_type_guid = '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
  pub_name = 'ok',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = NULL
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E9EF2E2B-A512-5B11-927F-0F84461A461C', 'A17D0129-73D9-5CDF-AF30-00B1257B8A26', '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50', 'ok', 1, 0, NULL, NULL);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT 'C5E7CD2F-9649-5F94-8200-E4ECC7454ADB' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:check_physical_table_exists:1',
  pub_query_mssql = 'SELECT 1 AS ok FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Returns one row {ok:1} if the named (schema, table) physically exists, else empty. Used by uninstall scan.',
  ref_input_model_guid = 'D52527ED-7530-5A0E-91AA-5D6552FDB662',
  ref_output_model_guid = 'A17D0129-73D9-5CDF-AF30-00B1257B8A26'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('C5E7CD2F-9649-5F94-8200-E4ECC7454ADB', 'db:contracts:db:check_physical_table_exists:1', 'SELECT 1 AS ok FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? FOR JSON PATH', NULL, NULL, 1, 'Returns one row {ok:1} if the named (schema, table) physically exists, else empty. Used by uninstall scan.', 'D52527ED-7530-5A0E-91AA-5D6552FDB662', 'A17D0129-73D9-5CDF-AF30-00B1257B8A26');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_indexes_on_column:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '1587F1D3-C8F7-5337-922A-6B2A117B28A2' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_indexes_on_column_input',
  pub_notes = 'Input model for db:contracts:db:list_indexes_on_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'list_indexes_on_column_input', 'Input model for db:contracts:db:list_indexes_on_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '4514CF79-4B17-51CA-89E4-F156B57F290C' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '1587F1D3-C8F7-5337-922A-6B2A117B28A2',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('4514CF79-4B17-51CA-89E4-F156B57F290C', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 1, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'FD03B85C-3318-57A0-87BE-CC4C16853B23' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '1587F1D3-C8F7-5337-922A-6B2A117B28A2',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_table_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('FD03B85C-3318-57A0-87BE-CC4C16853B23', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_table_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'DEF26816-D04C-5618-9C71-76503D0BEE58' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '1587F1D3-C8F7-5337-922A-6B2A117B28A2',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_column_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('DEF26816-D04C-5618-9C71-76503D0BEE58', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_column_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT 'AFEA32E7-6E93-512E-8137-1887A96AC9E0' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_indexes_on_column_output',
  pub_notes = 'Output model for db:contracts:db:list_indexes_on_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('AFEA32E7-6E93-512E-8137-1887A96AC9E0', 'list_indexes_on_column_output', 'Output model for db:contracts:db:list_indexes_on_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'C3FFBDEA-B6B8-52ED-A522-88819DFE6399' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = 'AFEA32E7-6E93-512E-8137-1887A96AC9E0',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'index_name',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('C3FFBDEA-B6B8-52ED-A522-88819DFE6399', 'AFEA32E7-6E93-512E-8137-1887A96AC9E0', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'index_name', 1, 0, NULL, 256);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '1CD9D4AC-3596-5E06-B221-D2F0FD85C433' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_indexes_on_column:1',
  pub_query_mssql = 'SELECT i.name AS index_name FROM sys.indexes i JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id JOIN sys.tables t ON c.object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? AND c.name = ? AND i.is_primary_key = 0 AND i.is_unique_constraint = 0 FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List non-PK/non-UQ indexes that include the named column. Used by uninstall ext-column drop to remove indexes blocking the column drop.',
  ref_input_model_guid = '1587F1D3-C8F7-5337-922A-6B2A117B28A2',
  ref_output_model_guid = 'AFEA32E7-6E93-512E-8137-1887A96AC9E0'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('1CD9D4AC-3596-5E06-B221-D2F0FD85C433', 'db:contracts:db:list_indexes_on_column:1', 'SELECT i.name AS index_name FROM sys.indexes i JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id JOIN sys.tables t ON c.object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? AND c.name = ? AND i.is_primary_key = 0 AND i.is_unique_constraint = 0 FOR JSON PATH', NULL, NULL, 1, 'List non-PK/non-UQ indexes that include the named column. Used by uninstall ext-column drop to remove indexes blocking the column drop.', '1587F1D3-C8F7-5337-922A-6B2A117B28A2', 'AFEA32E7-6E93-512E-8137-1887A96AC9E0');

-- ----------------------------------------------------------------------------
-- db:contracts:db:list_fks_on_column:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '7E57F8F0-B322-58E3-B199-B40932016ADF' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_fks_on_column_input',
  pub_notes = 'Input model for db:contracts:db:list_fks_on_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('7E57F8F0-B322-58E3-B199-B40932016ADF', 'list_fks_on_column_input', 'Input model for db:contracts:db:list_fks_on_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '8BCF44A9-9E34-5716-A388-62A51231C974' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7E57F8F0-B322-58E3-B199-B40932016ADF',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_schema',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 64
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('8BCF44A9-9E34-5716-A388-62A51231C974', '7E57F8F0-B322-58E3-B199-B40932016ADF', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_schema', 1, 0, NULL, 64);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '1B0FFB95-566F-51F1-AA5E-AB44906CF5E6' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7E57F8F0-B322-58E3-B199-B40932016ADF',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_table_name',
  pub_ordinal = 2,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('1B0FFB95-566F-51F1-AA5E-AB44906CF5E6', '7E57F8F0-B322-58E3-B199-B40932016ADF', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_table_name', 2, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT 'E96A6707-45A8-5177-B2BF-36673239F43A' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '7E57F8F0-B322-58E3-B199-B40932016ADF',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'pub_column_name',
  pub_ordinal = 3,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 128
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('E96A6707-45A8-5177-B2BF-36673239F43A', '7E57F8F0-B322-58E3-B199-B40932016ADF', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'pub_column_name', 3, 0, NULL, 128);

MERGE INTO [contracts_db_operations_models] AS T
USING (SELECT '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_name = 'list_fks_on_column_output',
  pub_notes = 'Output model for db:contracts:db:list_fks_on_column:1.'
WHEN NOT MATCHED THEN INSERT (key_guid, pub_name, pub_notes)
  VALUES ('1E4753FE-ED6F-5097-B061-A2F7C85CAB0F', 'list_fks_on_column_output', 'Output model for db:contracts:db:list_fks_on_column:1.');

MERGE INTO [contracts_db_operations_models_fields] AS T
USING (SELECT '371C2BEC-F4C9-50B0-9375-0610795C6EFA' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  ref_model_guid = '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F',
  ref_type_guid = '8579BB4B-746B-5E4B-867B-BFB182D52110',
  pub_name = 'fk_name',
  pub_ordinal = 1,
  pub_is_nullable = 0,
  pub_default_value = NULL,
  pub_max_length = 256
WHEN NOT MATCHED THEN INSERT (key_guid, ref_model_guid, ref_type_guid, pub_name, pub_ordinal, pub_is_nullable, pub_default_value, pub_max_length)
  VALUES ('371C2BEC-F4C9-50B0-9375-0610795C6EFA', '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F', '8579BB4B-746B-5E4B-867B-BFB182D52110', 'fk_name', 1, 0, NULL, 256);

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '01FD0C2B-3963-5776-A6E2-F04DC0AEC567' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:list_fks_on_column:1',
  pub_query_mssql = 'SELECT fk.name AS fk_name FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id JOIN sys.tables t ON fk.parent_object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? AND c.name = ? FOR JSON PATH',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'List foreign keys that reference the named column. Used by uninstall ext-column drop to remove FKs blocking the column drop.',
  ref_input_model_guid = '7E57F8F0-B322-58E3-B199-B40932016ADF',
  ref_output_model_guid = '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F'
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('01FD0C2B-3963-5776-A6E2-F04DC0AEC567', 'db:contracts:db:list_fks_on_column:1', 'SELECT fk.name AS fk_name FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id JOIN sys.tables t ON fk.parent_object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = ? AND t.name = ? AND c.name = ? FOR JSON PATH', NULL, NULL, 1, 'List foreign keys that reference the named column. Used by uninstall ext-column drop to remove FKs blocking the column drop.', '7E57F8F0-B322-58E3-B199-B40932016ADF', '1E4753FE-ED6F-5097-B061-A2F7C85CAB0F');

-- ----------------------------------------------------------------------------
-- db:contracts:db:update_statistics:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations] AS T
USING (SELECT '8E9CFF6A-2193-566C-941E-0A3894F3BC8D' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:update_statistics:1',
  pub_query_mssql = 'EXEC sp_updatestats',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Refresh statistics on all user tables. MSSQL-specific. Used by uninstall maintenance pass.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('8E9CFF6A-2193-566C-941E-0A3894F3BC8D', 'db:contracts:db:update_statistics:1', 'EXEC sp_updatestats', NULL, NULL, 1, 'Refresh statistics on all user tables. MSSQL-specific. Used by uninstall maintenance pass.', NULL, NULL);

-- ----------------------------------------------------------------------------
-- db:contracts:db:free_proc_cache:1
-- ----------------------------------------------------------------------------

MERGE INTO [contracts_db_operations] AS T
USING (SELECT 'D6E53F59-FD67-5945-B938-A6C214236843' AS key_guid) AS S ON T.key_guid = S.key_guid
WHEN MATCHED THEN UPDATE SET
  pub_op = 'db:contracts:db:free_proc_cache:1',
  pub_query_mssql = 'DBCC FREEPROCCACHE',
  pub_query_postgres = NULL,
  pub_query_mysql = NULL,
  pub_bootstrap_element = 1,
  pub_notes = 'Flush the procedure cache. MSSQL-specific. Used by uninstall maintenance pass.',
  ref_input_model_guid = NULL,
  ref_output_model_guid = NULL
WHEN NOT MATCHED THEN INSERT
  (key_guid, pub_op, pub_query_mssql, pub_query_postgres, pub_query_mysql,
   pub_bootstrap_element, pub_notes, ref_input_model_guid, ref_output_model_guid)
  VALUES ('D6E53F59-FD67-5945-B938-A6C214236843', 'db:contracts:db:free_proc_cache:1', 'DBCC FREEPROCCACHE', NULL, NULL, 1, 'Flush the procedure cache. MSSQL-specific. Used by uninstall maintenance pass.', NULL, NULL);

-- ============================================================================
-- Done. After run, inspect with:
--
--   SELECT pub_op, ref_input_model_guid IS NOT NULL AS has_input,
--          ref_output_model_guid IS NOT NULL AS has_output
--     FROM contracts_db_operations
--    WHERE pub_op LIKE 'db:contracts:db:%'
--    ORDER BY pub_op;
--
--   SELECT m.pub_name AS model, COUNT(*) AS field_count
--     FROM contracts_db_operations_models m
--     LEFT JOIN contracts_db_operations_models_fields f ON f.ref_model_guid = m.key_guid
--    GROUP BY m.pub_name
--    ORDER BY m.pub_name;
-- ============================================================================
