-- Truncate data from reflection tables
DELETE FROM etg.contracts_db_constraint_columns;
DELETE FROM etg.contracts_db_constraints;
DELETE FROM etg.contracts_db_index_columns;
DELETE FROM etg.contracts_db_indexes;
DELETE FROM etg.contracts_db_columns;
DELETE FROM etg.contracts_db_tables;
DELETE FROM etg.contracts_db_procedures;
GO

-- Drop all foreign keys
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'ALTER TABLE [' + s.name + '].[' + t.name + '] DROP CONSTRAINT [' + fk.name + '];' + CHAR(13)
FROM sys.foreign_keys fk
JOIN sys.tables t ON fk.parent_object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id;
EXEC sp_executesql @sql;
GO

-- Drop all tables
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'DROP TABLE [' + s.name + '].[' + t.name + '];' + CHAR(13)
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id;
EXEC sp_executesql @sql;
GO

-- Drop all stored procedures
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'DROP PROCEDURE [' + s.name + '].[' + p.name + '];' + CHAR(13)
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id;
EXEC sp_executesql @sql;
GO