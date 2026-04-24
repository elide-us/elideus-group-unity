-- =============================================================================
-- elideus-group-unity :: Contracts Layer — Seed Data
-- =============================================================================
-- v1.0.1_contracts_seed.sql
--
-- Seeds:
--   1. VoidModel                           (permanent empty-model row)
--   2. EnvKey / EnvLookupResult models     (env_get signature)
--   3. env_get function                    (kernel environment lookup)
--
-- All GUIDs are deterministic UUID5 from:
--   namespace:  DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB
--   models:     uuid5(NS_HASH, "contracts_api_models:{pub_name}")
--   fields:     uuid5(NS_HASH, "contracts_api_model_fields:{model}.{field}")
--   functions:  uuid5(NS_HASH, "contracts_api_functions:{pub_name}")
--
-- Type GUIDs referenced from v1.0.0_seed.sql (service_types).
-- =============================================================================

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- =============================================================================
-- 1. VoidModel — permanent empty-model row
-- =============================================================================
-- Functions with no meaningful input or output reference this model rather
-- than nulling their refs. Keeps the function signature invariant uniform.
-- VoidModel has zero field rows.
-- =============================================================================

INSERT INTO [dbo].[contracts_api_models]
  ([key_guid], [pub_name], [pub_notes])
VALUES
  -- GUID computed: uuid5(NS_HASH, "contracts_api_models:VoidModel")
  -- Replace with actual UUID5 result when seeding.
  ('00000000-0000-0000-0000-000000000000', 'VoidModel',
   'Permanent empty-model row. Referenced by functions with no meaningful input or output. Zero fields.');
GO

-- =============================================================================
-- 2. Models for env_get
-- =============================================================================
-- env_get: EnvKey -> EnvLookupResult
--
-- EnvKey is a single-field model wrapping the variable name. Wrapping a
-- scalar in a named model is deliberate — the contract layer does not
-- expose raw primitives as function inputs, because doing so loses the
-- semantic identity of the parameter. "EnvKey" means something; "STRING"
-- does not.
--
-- EnvLookupResult is a single-field nullable model. The nullability is
-- part of the contract — callers must handle the absence case.
-- =============================================================================

INSERT INTO [dbo].[contracts_api_models]
  ([key_guid], [pub_name], [pub_notes])
VALUES
  ('00000000-0000-0000-0000-000000000000', 'EnvKey',
   'Environment variable lookup key. Single-field input model for env_get.'),

  ('00000000-0000-0000-0000-000000000000', 'EnvLookupResult',
   'Environment variable lookup result. Nullable value; absence indicates the variable is not loaded or not set.');
GO

-- =============================================================================
-- 3. Fields for EnvKey and EnvLookupResult
-- =============================================================================

INSERT INTO [dbo].[contracts_api_model_fields]
  ([key_guid], [ref_model_guid], [ref_type_guid],
   [pub_name], [pub_ordinal], [pub_is_nullable], [pub_max_length], [pub_notes])
VALUES
  -- EnvKey.name : STRING(256)
  ('00000000-0000-0000-0000-000000000000',
   '00000000-0000-0000-0000-000000000000',  -- EnvKey model
   '8579BB4B-746B-5E4B-867B-BFB182D52110',  -- STRING
   'name', 1, 0, 256,
   'Environment variable name as declared in the host environment (e.g., SQL_PROVIDER, NS_HASH).'),

  -- EnvLookupResult.value : STRING(MAX), nullable
  ('00000000-0000-0000-0000-000000000000',
   '00000000-0000-0000-0000-000000000000',  -- EnvLookupResult model
   '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',  -- TEXT
   'value', 1, 1, NULL,
   'Variable value, or NULL if the variable is not loaded or not set in the host environment.');
GO

-- =============================================================================
-- 4. Function row: env_get
-- =============================================================================
-- env_get is the kernel's environment-variable lookup function.
-- Signature: EnvKey -> EnvLookupResult
--
-- This is the first populated function in the contract graph. It is the
-- canonical example of the pattern: a named reduction from one model to
-- another, with the Python implementation (EnvironmentVariablesModule.get)
-- being a materialization of this contract, not the definition of it.
-- =============================================================================

INSERT INTO [dbo].[contracts_api_functions]
  ([key_guid], [ref_input_model_guid], [ref_output_model_guid],
   [pub_name], [pub_notes])
VALUES
  ('00000000-0000-0000-0000-000000000000',
   '00000000-0000-0000-0000-000000000000',  -- EnvKey
   '00000000-0000-0000-0000-000000000000',  -- EnvLookupResult
   'env_get',
   'Kernel environment variable lookup. Returns the value of the named variable, or null if the variable is not loaded or not set. Implemented by EnvironmentVariablesModule.get.');
GO
