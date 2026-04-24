-- =============================================================================
-- elideus-group-unity :: Contracts Layer — DDL
-- =============================================================================
-- v1.0.1_contracts.sql
--
-- Introduces the API contract layer. These tables define the application as
-- a type graph: named functions joining named input/output models, where
-- every model field references the platform type catalog (service_types).
--
-- This is the application schema — distinct from the database schema
-- defined in objects_schema_*. Both layers share service_types as their
-- underlying type catalog but otherwise do not reference each other.
--
-- Naming cluster:
--   contracts_api_*   — application function catalog (this file)
--   contracts_db_*    — future: database query contracts
--   contracts_auth_*  — future: IDP provider / protocol contracts
--   contracts_io_*    — future: gateway / transport contracts
--
-- Tables in this migration:
--   1. contracts_api_models       (named input/output model catalog)
--   2. contracts_api_model_fields (model ↔ type junction, ordered)
--   3. contracts_api_functions    (named functions with input/output model refs)
--
-- Column prefix conventions follow foundation (key_*, pub_*, ref_*, priv_*).
--
-- Deterministic keys:
--   namespace: DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB  (env: NS_HASH)
--   models:    uuid5(NS_HASH, "contracts_api_models:{pub_name}")
--   fields:    uuid5(NS_HASH, "contracts_api_model_fields:{model_name}.{field_name}")
--   functions: uuid5(NS_HASH, "contracts_api_functions:{pub_name}")
-- =============================================================================

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- =============================================================================
-- 1. contracts_api_models
-- =============================================================================
-- Named model definitions. A model is a named, ordered composition of typed
-- fields — the structural equivalent of a C struct, a Pydantic model, or a
-- TypeScript interface.
--
-- Models are reusable across functions: the same model may appear as the
-- input of one function and the output of another. Substitutability is
-- structural — two functions with the same input/output model pair are
-- interchangeable at the type level.
--
-- The VoidModel row is seeded permanently. Functions with no meaningful
-- input or output reference VoidModel rather than nulling their refs.
--
-- Deterministic key: uuid5(NS_HASH, "contracts_api_models:{pub_name}")
-- =============================================================================

CREATE TABLE [dbo].[contracts_api_models] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(128)     NOT NULL,
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_contracts_api_models] PRIMARY KEY ([key_guid]),
  CONSTRAINT [UQ_cam_name] UNIQUE ([pub_name])
);
GO

-- =============================================================================
-- 2. contracts_api_model_fields
-- =============================================================================
-- One row per field in a model. Joins the owning model to the platform type
-- catalog. Structurally parallel to objects_schema_columns but rooted in a
-- model rather than a table.
--
-- pub_ordinal controls field ordering. Field order is part of the contract
-- — positional protocols (e.g., tuple serialization) depend on it, and
-- reordering fields changes the contract.
--
-- pub_max_length overrides the type's pub_default_length when present,
-- following the same convention as objects_schema_columns.
--
-- Deterministic key:
--   uuid5(NS_HASH, "contracts_api_model_fields:{model_name}.{field_name}")
-- =============================================================================

CREATE TABLE [dbo].[contracts_api_model_fields] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_model_guid]        UNIQUEIDENTIFIER  NOT NULL,
  [ref_type_guid]         UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(128)     NOT NULL,
  [pub_ordinal]           INT               NOT NULL,
  [pub_is_nullable]       BIT               NOT NULL DEFAULT (0),
  [pub_max_length]        INT               NULL,
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_contracts_api_model_fields] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_camf_model] FOREIGN KEY ([ref_model_guid])
    REFERENCES [dbo].[contracts_api_models] ([key_guid]),
  CONSTRAINT [FK_camf_type] FOREIGN KEY ([ref_type_guid])
    REFERENCES [dbo].[service_types] ([key_guid]),
  CONSTRAINT [UQ_camf_model_name] UNIQUE ([ref_model_guid], [pub_name]),
  CONSTRAINT [UQ_camf_model_ordinal] UNIQUE ([ref_model_guid], [pub_ordinal])
);
GO

CREATE INDEX [IX_camf_model_guid]
  ON [dbo].[contracts_api_model_fields] ([ref_model_guid]);
GO

CREATE INDEX [IX_camf_type_guid]
  ON [dbo].[contracts_api_model_fields] ([ref_type_guid]);
GO

-- =============================================================================
-- 3. contracts_api_functions
-- =============================================================================
-- One row per named function. A function is the edge in the type graph —
-- its existence is defined entirely by (input_model, output_model).
--
-- Two functions with the same input and output models are NOT the same
-- function. pub_name is the functional identity; models are the signature.
-- Multiple functions may share a signature while performing different
-- reductions (e.g., four auth providers all satisfying the same
-- ProviderToken → ResolvedIdentity signature).
--
-- Functions with no meaningful input or output reference the seeded
-- VoidModel row rather than nulling their refs. The graph stays uniform:
-- every function has a complete signature.
--
-- Deterministic key: uuid5(NS_HASH, "contracts_api_functions:{pub_name}")
-- =============================================================================

CREATE TABLE [dbo].[contracts_api_functions] (
  [key_guid]              UNIQUEIDENTIFIER  NOT NULL,
  [ref_input_model_guid]  UNIQUEIDENTIFIER  NOT NULL,
  [ref_output_model_guid] UNIQUEIDENTIFIER  NOT NULL,
  [pub_name]              NVARCHAR(256)     NOT NULL,
  [pub_notes]             NVARCHAR(512)     NULL,
  [priv_created_on]       DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  [priv_modified_on]      DATETIMEOFFSET(7) NOT NULL DEFAULT (SYSDATETIMEOFFSET()),
  CONSTRAINT [PK_contracts_api_functions] PRIMARY KEY ([key_guid]),
  CONSTRAINT [FK_caf_input_model] FOREIGN KEY ([ref_input_model_guid])
    REFERENCES [dbo].[contracts_api_models] ([key_guid]),
  CONSTRAINT [FK_caf_output_model] FOREIGN KEY ([ref_output_model_guid])
    REFERENCES [dbo].[contracts_api_models] ([key_guid]),
  CONSTRAINT [UQ_caf_name] UNIQUE ([pub_name])
);
GO

CREATE INDEX [IX_caf_input_model_guid]
  ON [dbo].[contracts_api_functions] ([ref_input_model_guid]);
GO

CREATE INDEX [IX_caf_output_model_guid]
  ON [dbo].[contracts_api_functions] ([ref_output_model_guid]);
GO
