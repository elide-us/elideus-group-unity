from __future__ import annotations
import os, json, uuid, re
from datetime import datetime, timezone

import dotenv

dotenv.load_dotenv()


# =============================================================================
# Connection
# =============================================================================

async def connect(dbname: str | None = None):
  try:
    import aioodbc  # type: ignore
  except Exception as e:
    raise ImportError('aioodbc is required for database operations') from e
  dsn = os.getenv('AZURE_SQL_CONNECTION_STRING')
  if not dsn:
    raise RuntimeError('AZURE_SQL_CONNECTION_STRING not set')
  if dbname:
    parts = []
    replaced = False
    for part in dsn.split(';'):
      if part.upper().startswith('DATABASE=') or part.upper().startswith('INITIAL CATALOG='):
        parts.append('DATABASE=%s' % dbname)
        replaced = True
      else:
        parts.append(part)
    if not replaced:
      parts.append('DATABASE=%s' % dbname)
    dsn = ';'.join(parts)
  conn = await aioodbc.connect(dsn=dsn, autocommit=True)
  print('Connected to database %s' % (dbname or '<from DSN>'))
  return conn


# =============================================================================
# Internal helpers
# =============================================================================

NS_HASH = uuid.UUID(os.getenv('NS_HASH', 'DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB'))


def _guid(entity_type: str, natural_key: str) -> str:
  return str(uuid.uuid5(NS_HASH, '%s:%s' % (entity_type, natural_key))).upper()


# Known MSSQL builtin functions that may appear in default-value expressions.
# Uppercased in dump output to match SQL convention; introspection returns
# them lowercase from sys.* catalog views.
_KNOWN_SQL_FUNCTIONS = (
  'sysdatetimeoffset', 'sysdatetime', 'sysutcdatetime',
  'getdate', 'getutcdate', 'current_timestamp',
  'newid', 'newsequentialid',
  'object_definition',
)


def _upper_sql_functions(expr: str | None) -> str | None:
  """Uppercase known MSSQL function names in a default-value expression so
  emitted DDL matches conventional uppercase style."""
  if not expr:
    return expr
  result = expr
  for fn in _KNOWN_SQL_FUNCTIONS:
    result = re.sub(r'\b' + fn + r'\b', fn.upper(), result, flags=re.IGNORECASE)
  return result


async def _fetch_json(cur):
  parts: list[str] = []
  while True:
    row = await cur.fetchone()
    if not row:
      break
    parts.append(row[0])
  return json.loads(''.join(parts)) if parts else []


async def _query_json(conn, sql: str, params: tuple = ()) -> list:
  async with conn.cursor() as cur:
    await cur.execute(sql, params)
    return await _fetch_json(cur)


async def _execute(conn, sql: str, params: tuple = ()) -> int:
  async with conn.cursor() as cur:
    await cur.execute(sql, params)
    return cur.rowcount


async def _merge(conn, table: str, key_column: str, values: dict) -> None:
  cols = list(values.keys())
  placeholders = ', '.join('?' for _ in cols)
  col_list = ', '.join('[%s]' % c for c in cols)
  update_set = ', '.join('T.[%s] = S.[%s]' % (c, c) for c in cols if c != key_column)
  sql = (
    'MERGE INTO [%(table)s] AS T '
    'USING (SELECT %(placeholders)s) AS S (%(col_list)s) '
    'ON T.[%(key)s] = S.[%(key)s] '
    'WHEN MATCHED THEN UPDATE SET %(update_set)s '
    'WHEN NOT MATCHED THEN INSERT (%(col_list)s) VALUES (%(values_list)s);'
  ) % {
    'table': table,
    'placeholders': placeholders,
    'col_list': col_list,
    'key': key_column,
    'update_set': update_set if update_set else 'T.[%s] = S.[%s]' % (key_column, key_column),
    'values_list': ', '.join('S.[%s]' % c for c in cols),
  }
  params = tuple(values[c] for c in cols)
  async with conn.cursor() as cur:
    await cur.execute(sql, params)


# =============================================================================
# Alias generation
# =============================================================================
#
# For a snake_case table name, produce a short alias derived from segment
# initials. On collision with already-assigned aliases, extend by adding
# letters to segments in right-to-left cycles: each cycle adds one letter
# to every segment in reverse order before any segment grows again.
#
# Example for system_schema_failures with prior collisions:
#   ssf  -> ssfa  -> sscfa  -> syscfa  -> syscfai  -> syscefai  -> sysscefai
#
# Segment letter counts cap at the segment's own length; segments at their
# cap are skipped in subsequent cycles.
# =============================================================================

def _generate_alias(name: str, taken: set[str]) -> str:
  segments = name.split('_')
  n = len(segments)
  rounds = [1] * n

  def build() -> str:
    return ''.join(seg[:rounds[i]] for i, seg in enumerate(segments)).lower()

  candidate = build()
  cycle_pos = 0
  max_cycles = sum(len(s) for s in segments)
  while candidate in taken:
    if cycle_pos >= max_cycles:
      raise ValueError('cannot generate unique alias for %s' % name)
    seg_idx = n - 1 - (cycle_pos % n)
    cycle_pos += 1
    if rounds[seg_idx] >= len(segments[seg_idx]):
      continue  # this segment is maxed out; skip
    rounds[seg_idx] += 1
    candidate = build()
  return candidate


# =============================================================================
# populate
# =============================================================================
#
# Reads the live database via INFORMATION_SCHEMA and sys.*, populates the
# contracts_db_* cluster with rows describing every table in the database.
#
# Pass-based:
#   1. Tables       -> contracts_db_tables
#   2. Columns      -> contracts_db_columns
#   3. Indexes      -> contracts_db_indexes
#   4. Index cols   -> contracts_db_index_columns
#   5. Constraints  -> contracts_db_constraints
#   6. Constr cols  -> contracts_db_constraint_columns
#
# Idempotent via MERGE on deterministic key_guid.
# =============================================================================

# MSSQL system type name -> contracts_primitives_types.pub_name
_TYPE_MAP = {
  'bit': 'BOOL',
  'tinyint': 'INT8',
  'smallint': 'INT16',
  'int': 'INT32',
  'bigint': 'INT64',
  'real': 'FLOAT32',
  'float': 'FLOAT64',
  'decimal': 'DECIMAL_19_5',
  'numeric': 'DECIMAL_19_5',
  'nvarchar': 'STRING',
  'varchar': 'STRING',
  'nchar': 'STRING',
  'char': 'STRING',
  'uniqueidentifier': 'UUID',
  'date': 'DATE',
  'datetimeoffset': 'DATETIME_TZ',
  'datetime2': 'DATETIME_TZ',
  'datetime': 'DATETIME_TZ',
  'varbinary': 'BINARY',
  'binary': 'BINARY',
  'vector': 'VECTOR',
}


def _resolve_type_name(sys_type: str, max_length: int | None, precision: int | None, scale: int | None, is_identity: bool) -> str:
  st = sys_type.lower()
  if st == 'bigint' and is_identity:
    return 'INT64_IDENTITY'
  if st in ('decimal', 'numeric'):
    if precision == 19 and scale == 5:
      return 'DECIMAL_19_5'
    if precision == 28 and scale == 12:
      return 'DECIMAL_28_12'
    if precision == 38 and scale == 18:
      return 'DECIMAL_38_18'
    raise ValueError('unsupported decimal precision/scale: (%s,%s)' % (precision, scale))
  if st == 'nvarchar' and max_length == -1:
    return 'TEXT'
  if st in _TYPE_MAP:
    return _TYPE_MAP[st]
  raise ValueError('unmapped sys_type: %s' % sys_type)


async def _load_type_guids(conn) -> dict[str, str]:
  rows = await _query_json(
    conn,
    "SELECT pub_name, key_guid FROM contracts_primitives_types FOR JSON PATH"
  )
  return {r['pub_name']: r['key_guid'] for r in rows}


async def _populate_tables(conn) -> dict[str, str]:
  # ORDER BY ensures alphabetical processing so alias assignment is
  # deterministic across runs against the same set of tables.
  rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_name
       FROM sys.tables t
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       ORDER BY s.name, t.name
       FOR JSON PATH"""
  )
  guids: dict[str, str] = {}
  taken_aliases: set[str] = set()
  for r in rows:
    natural = '%s.%s' % (r['pub_schema'], r['pub_name'])
    g = _guid('contracts_db_tables', natural)
    alias = _generate_alias(r['pub_name'], taken_aliases)
    taken_aliases.add(alias)
    await _merge(conn, 'contracts_db_tables', 'key_guid', {
      'key_guid': g,
      'pub_name': r['pub_name'],
      'pub_schema': r['pub_schema'],
      'pub_alias': alias,
    })
    guids[natural] = g
  print('  tables: %d' % len(guids))
  return guids


async def _populate_columns(conn, table_guids: dict[str, str], type_guids: dict[str, str]) -> dict[str, str]:
  rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         c.name AS pub_name,
         ty.name AS sys_type,
         c.max_length AS sys_max_length,
         c.precision AS sys_precision,
         c.scale AS sys_scale,
         c.is_nullable AS pub_is_nullable,
         c.is_identity AS sys_is_identity,
         c.column_id AS pub_ordinal,
         OBJECT_DEFINITION(c.default_object_id) AS pub_default_value
       FROM sys.columns c
       JOIN sys.tables t ON c.object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.types ty ON c.user_type_id = ty.user_type_id
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )
  guids: dict[str, str] = {}
  for r in rows:
    table_natural = '%s.%s' % (r['pub_schema'], r['pub_table'])
    table_guid = table_guids.get(table_natural)
    if not table_guid:
      continue
    type_name = _resolve_type_name(
      r['sys_type'], r['sys_max_length'], r['sys_precision'], r['sys_scale'], bool(r['sys_is_identity'])
    )
    type_guid = type_guids[type_name]
    max_length = None
    st = r['sys_type'].lower()
    if st in ('nvarchar', 'nchar') and r['sys_max_length'] != -1:
      max_length = r['sys_max_length'] // 2
    elif st in ('varchar', 'char', 'varbinary', 'binary') and r['sys_max_length'] != -1:
      max_length = r['sys_max_length']
    column_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_name'])
    g = _guid('contracts_db_columns', column_natural)
    default_value = r['pub_default_value']
    if default_value and default_value.startswith('(') and default_value.endswith(')'):
      default_value = default_value[1:-1]
      if default_value.startswith('(') and default_value.endswith(')'):
        default_value = default_value[1:-1]
    await _merge(conn, 'contracts_db_columns', 'key_guid', {
      'key_guid': g,
      'ref_table_guid': table_guid,
      'ref_type_guid': type_guid,
      'pub_name': r['pub_name'],
      'pub_ordinal': r['pub_ordinal'],
      'pub_is_nullable': int(bool(r['pub_is_nullable'])),
      'pub_default_value': default_value,
      'pub_max_length': max_length,
    })
    guids[column_natural] = g
  print('  columns: %d' % len(guids))
  return guids


async def _populate_indexes(conn, table_guids: dict[str, str]) -> dict[str, str]:
  rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         i.name AS pub_name,
         i.is_unique AS pub_is_unique
       FROM sys.indexes i
       JOIN sys.tables t ON i.object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       WHERE i.is_primary_key = 0
         AND i.is_unique_constraint = 0
         AND i.name IS NOT NULL
       FOR JSON PATH"""
  )
  guids: dict[str, str] = {}
  for r in rows:
    table_natural = '%s.%s' % (r['pub_schema'], r['pub_table'])
    table_guid = table_guids.get(table_natural)
    if not table_guid:
      continue
    natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_name'])
    g = _guid('contracts_db_indexes', natural)
    await _merge(conn, 'contracts_db_indexes', 'key_guid', {
      'key_guid': g,
      'ref_table_guid': table_guid,
      'pub_name': r['pub_name'],
      'pub_is_unique': int(bool(r['pub_is_unique'])),
    })
    guids[natural] = g
  print('  indexes: %d' % len(guids))
  return guids


async def _populate_index_columns(conn, index_guids: dict[str, str], column_guids: dict[str, str]) -> int:
  rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         i.name AS pub_index,
         c.name AS pub_column,
         ic.key_ordinal AS pub_ordinal
       FROM sys.index_columns ic
       JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
       JOIN sys.tables t ON ic.object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
       WHERE i.is_primary_key = 0
         AND i.is_unique_constraint = 0
         AND i.name IS NOT NULL
       FOR JSON PATH"""
  )
  count = 0
  for r in rows:
    index_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_index'])
    column_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_column'])
    index_guid = index_guids.get(index_natural)
    column_guid = column_guids.get(column_natural)
    if not (index_guid and column_guid):
      continue
    g = _guid('contracts_db_index_columns', '%s.%s' % (index_natural, r['pub_column']))
    await _merge(conn, 'contracts_db_index_columns', 'key_guid', {
      'key_guid': g,
      'ref_index_guid': index_guid,
      'ref_column_guid': column_guid,
      'pub_ordinal': r['pub_ordinal'],
    })
    count += 1
  print('  index_columns: %d' % count)
  return count


async def _populate_constraints(conn, table_guids: dict[str, str]) -> dict[str, str]:
  enum_rows = await _query_json(
    conn,
    "SELECT pub_name, key_guid FROM contracts_primitives_enums WHERE pub_enum_type='constraint_kind' FOR JSON PATH"
  )
  kind_guids = {r['pub_name']: r['key_guid'] for r in enum_rows}
  rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         k.name AS pub_name,
         k.type_desc AS sys_kind,
         rs.name AS ref_schema,
         rt.name AS ref_table_name
       FROM (
         SELECT object_id, parent_object_id, name, 'PRIMARY_KEY' AS type_desc, NULL AS referenced_object_id FROM sys.key_constraints WHERE type='PK'
         UNION ALL
         SELECT object_id, parent_object_id, name, 'UNIQUE'      AS type_desc, NULL                       FROM sys.key_constraints WHERE type='UQ'
         UNION ALL
         SELECT object_id, parent_object_id, name, 'FOREIGN_KEY' AS type_desc, referenced_object_id       FROM sys.foreign_keys
         UNION ALL
         SELECT object_id, parent_object_id, name, 'CHECK'       AS type_desc, NULL                       FROM sys.check_constraints
       ) k
       JOIN sys.tables t ON k.parent_object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       LEFT JOIN sys.tables rt ON k.referenced_object_id = rt.object_id
       LEFT JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )
  guids: dict[str, str] = {}
  for r in rows:
    table_natural = '%s.%s' % (r['pub_schema'], r['pub_table'])
    table_guid = table_guids.get(table_natural)
    if not table_guid:
      continue
    kind_guid = kind_guids.get(r['sys_kind'])
    if not kind_guid:
      continue
    ref_table_guid = None
    if r.get('ref_table_name'):
      ref_natural = '%s.%s' % (r['ref_schema'], r['ref_table_name'])
      ref_table_guid = table_guids.get(ref_natural)
    natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_name'])
    g = _guid('contracts_db_constraints', natural)
    await _merge(conn, 'contracts_db_constraints', 'key_guid', {
      'key_guid': g,
      'ref_table_guid': table_guid,
      'ref_kind_enum_guid': kind_guid,
      'ref_referenced_table_guid': ref_table_guid,
      'pub_name': r['pub_name'],
      'pub_expression': None,
    })
    guids[natural] = g
  print('  constraints: %d' % len(guids))
  return guids


async def _populate_constraint_columns(conn, constraint_guids: dict[str, str], column_guids: dict[str, str]) -> int:
  pk_uq_rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         kc.name AS pub_constraint,
         c.name AS pub_column,
         ic.key_ordinal AS pub_ordinal
       FROM sys.key_constraints kc
       JOIN sys.tables t ON kc.parent_object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
       JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
       FOR JSON PATH"""
  )
  fk_rows = await _query_json(
    conn,
    """SELECT
         s.name AS pub_schema,
         t.name AS pub_table,
         fk.name AS pub_constraint,
         c.name AS pub_column,
         rs.name AS ref_schema,
         rt.name AS ref_table,
         rc.name AS ref_column,
         fkc.constraint_column_id AS pub_ordinal
       FROM sys.foreign_key_columns fkc
       JOIN sys.foreign_keys fk ON fkc.constraint_object_id = fk.object_id
       JOIN sys.tables t ON fk.parent_object_id = t.object_id
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
       JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
       JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
       JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
       FOR JSON PATH"""
  )
  count = 0
  for r in pk_uq_rows:
    constraint_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_constraint'])
    column_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_column'])
    constraint_guid = constraint_guids.get(constraint_natural)
    column_guid = column_guids.get(column_natural)
    if not (constraint_guid and column_guid):
      continue
    g = _guid('contracts_db_constraint_columns',
              '%s.%s' % (constraint_natural, r['pub_column']))
    await _merge(conn, 'contracts_db_constraint_columns', 'key_guid', {
      'key_guid': g,
      'ref_constraint_guid': constraint_guid,
      'ref_column_guid': column_guid,
      'ref_referenced_column_guid': None,
      'pub_ordinal': r['pub_ordinal'],
    })
    count += 1
  for r in fk_rows:
    constraint_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_constraint'])
    column_natural = '%s.%s.%s' % (r['pub_schema'], r['pub_table'], r['pub_column'])
    ref_column_natural = '%s.%s.%s' % (r['ref_schema'], r['ref_table'], r['ref_column'])
    constraint_guid = constraint_guids.get(constraint_natural)
    column_guid = column_guids.get(column_natural)
    ref_column_guid = column_guids.get(ref_column_natural)
    if not (constraint_guid and column_guid and ref_column_guid):
      continue
    g = _guid('contracts_db_constraint_columns',
              '%s.%s' % (constraint_natural, r['pub_column']))
    await _merge(conn, 'contracts_db_constraint_columns', 'key_guid', {
      'key_guid': g,
      'ref_constraint_guid': constraint_guid,
      'ref_column_guid': column_guid,
      'ref_referenced_column_guid': ref_column_guid,
      'pub_ordinal': r['pub_ordinal'],
    })
    count += 1
  print('  constraint_columns: %d' % count)
  return count


async def populate(conn) -> None:
  print('Populating contracts_db_*...')
  type_guids = await _load_type_guids(conn)
  table_guids = await _populate_tables(conn)
  column_guids = await _populate_columns(conn, table_guids, type_guids)
  index_guids = await _populate_indexes(conn, table_guids)
  await _populate_index_columns(conn, index_guids, column_guids)
  constraint_guids = await _populate_constraints(conn, table_guids)
  await _populate_constraint_columns(conn, constraint_guids, column_guids)
  print('Populate complete.')


# =============================================================================
# dump
# =============================================================================

async def _read_types(conn) -> list[dict]:
  return await _query_json(
    conn,
    """SELECT key_guid, pub_name, pub_mssql_type, pub_postgresql_type, pub_mysql_type,
              pub_python_type, pub_typescript_type, pub_json_type,
              pub_odbc_type_code, pub_default_length, pub_notes
       FROM contracts_primitives_types
       ORDER BY pub_name
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )


async def _read_enums(conn) -> list[dict]:
  return await _query_json(
    conn,
    """SELECT key_guid, pub_enum_type, pub_name, pub_value, pub_notes
       FROM contracts_primitives_enums
       ORDER BY pub_enum_type, pub_value
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )


async def _read_schema(conn) -> dict:
  tables = await _query_json(
    conn,
    """SELECT key_guid, pub_name, pub_schema, pub_alias
       FROM contracts_db_tables
       ORDER BY pub_schema, pub_name
       FOR JSON PATH"""
  )
  columns = await _query_json(
    conn,
    """SELECT c.key_guid, c.ref_table_guid, c.pub_name, c.pub_ordinal,
              c.pub_is_nullable, c.pub_default_value, c.pub_max_length,
              t.pub_mssql_type, t.pub_default_length, t.pub_name AS type_name
       FROM contracts_db_columns c
       JOIN contracts_primitives_types t ON c.ref_type_guid = t.key_guid
       ORDER BY c.ref_table_guid, c.pub_ordinal
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )
  indexes = await _query_json(
    conn,
    """SELECT key_guid, ref_table_guid, pub_name, pub_is_unique
       FROM contracts_db_indexes
       ORDER BY ref_table_guid, pub_name
       FOR JSON PATH"""
  )
  index_columns = await _query_json(
    conn,
    """SELECT ic.ref_index_guid, ic.pub_ordinal, c.pub_name AS column_name
       FROM contracts_db_index_columns ic
       JOIN contracts_db_columns c ON ic.ref_column_guid = c.key_guid
       ORDER BY ic.ref_index_guid, ic.pub_ordinal
       FOR JSON PATH"""
  )
  constraints = await _query_json(
    conn,
    """SELECT cn.key_guid, cn.ref_table_guid, cn.ref_referenced_table_guid,
              cn.pub_name, cn.pub_expression, e.pub_name AS kind_name
       FROM contracts_db_constraints cn
       JOIN contracts_primitives_enums e ON cn.ref_kind_enum_guid = e.key_guid
       ORDER BY cn.ref_table_guid, e.pub_value, cn.pub_name
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )
  constraint_columns = await _query_json(
    conn,
    """SELECT cc.ref_constraint_guid, cc.pub_ordinal,
              c.pub_name AS column_name,
              rc.pub_name AS ref_column_name
       FROM contracts_db_constraint_columns cc
       JOIN contracts_db_columns c ON cc.ref_column_guid = c.key_guid
       LEFT JOIN contracts_db_columns rc ON cc.ref_referenced_column_guid = rc.key_guid
       ORDER BY cc.ref_constraint_guid, cc.pub_ordinal
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )
  return {
    'tables': tables,
    'columns': columns,
    'indexes': indexes,
    'index_columns': index_columns,
    'constraints': constraints,
    'constraint_columns': constraint_columns,
  }


def _column_ddl(col: dict) -> str:
  ctype = col['pub_mssql_type']
  type_name = col['type_name']
  if type_name == 'STRING':
    length = col.get('pub_max_length') or col.get('pub_default_length')
    if length is None:
      raise ValueError('STRING column %s has no length' % col['pub_name'])
    ctype = '%s(%d)' % (ctype, length)
  parts = ['[%s]' % col['pub_name'], ctype]
  default_value = col.get('pub_default_value')
  if default_value:
    parts.append('DEFAULT (%s)' % _upper_sql_functions(default_value))
  if col.get('pub_is_nullable'):
    parts.append('NULL')
  else:
    parts.append('NOT NULL')
  return ' '.join(parts)


def _build_create_table(table: dict, columns: list[dict]) -> str:
  table_columns = [c for c in columns if c['ref_table_guid'] == table['key_guid']]
  table_columns.sort(key=lambda c: c['pub_ordinal'])
  col_lines = ['  %s' % _column_ddl(c) for c in table_columns]
  return 'CREATE TABLE [%s].[%s] (\n%s\n);' % (
    table['pub_schema'], table['pub_name'], ',\n'.join(col_lines)
  )


def _build_create_index(idx: dict, table: dict, idx_columns: list[dict]) -> str:
  unique = 'UNIQUE ' if idx.get('pub_is_unique') else ''
  cols = [c for c in idx_columns if c['ref_index_guid'] == idx['key_guid']]
  cols.sort(key=lambda c: c['pub_ordinal'])
  col_list = ', '.join('[%s]' % c['column_name'] for c in cols)
  return 'CREATE %sINDEX [%s] ON [%s].[%s] (%s);' % (
    unique, idx['pub_name'], table['pub_schema'], table['pub_name'], col_list
  )


def _build_constraint(con: dict, table: dict, ref_table: dict | None,
                      con_columns: list[dict]) -> str:
  cols = [c for c in con_columns if c['ref_constraint_guid'] == con['key_guid']]
  cols.sort(key=lambda c: c['pub_ordinal'])
  src_cols = ', '.join('[%s]' % c['column_name'] for c in cols)
  match con['kind_name']:
    case 'PRIMARY_KEY':
      body = 'PRIMARY KEY (%s)' % src_cols
    case 'UNIQUE':
      body = 'UNIQUE (%s)' % src_cols
    case 'FOREIGN_KEY':
      ref_cols = ', '.join('[%s]' % c['ref_column_name'] for c in cols)
      body = 'FOREIGN KEY (%s) REFERENCES [%s].[%s] (%s)' % (
        src_cols, ref_table['pub_schema'], ref_table['pub_name'], ref_cols
      )
    case 'CHECK':
      body = 'CHECK (%s)' % con['pub_expression']
    case _:
      raise ValueError('unknown constraint kind: %s' % con['kind_name'])
  return 'ALTER TABLE [%s].[%s] ADD CONSTRAINT [%s] %s;' % (
    table['pub_schema'], table['pub_name'], con['pub_name'], body
  )


def _build_types_seed(types: list[dict]) -> str:
  lines = ['INSERT INTO [dbo].[contracts_primitives_types]',
           '  (key_guid, pub_name, pub_mssql_type, pub_postgresql_type, pub_mysql_type,',
           '   pub_python_type, pub_typescript_type, pub_json_type,',
           '   pub_odbc_type_code, pub_default_length, pub_notes)',
           'VALUES']
  vals = []
  for t in types:
    def q(v):
      if v is None:
        return 'NULL'
      if isinstance(v, int):
        return str(v)
      return "'%s'" % str(v).replace("'", "''")
    vals.append('  (%s)' % ', '.join([
      "'%s'" % t['key_guid'],
      q(t['pub_name']),
      q(t['pub_mssql_type']),
      q(t['pub_postgresql_type']),
      q(t['pub_mysql_type']),
      q(t['pub_python_type']),
      q(t['pub_typescript_type']),
      q(t['pub_json_type']),
      q(t['pub_odbc_type_code']),
      q(t['pub_default_length']),
      q(t['pub_notes']),
    ]))
  return '\n'.join(lines) + '\n' + ',\n'.join(vals) + ';'


def _build_enums_seed(enums: list[dict]) -> str:
  if not enums:
    return ''
  lines = ['INSERT INTO [dbo].[contracts_primitives_enums]',
           '  (key_guid, pub_enum_type, pub_name, pub_value, pub_notes)',
           'VALUES']
  vals = []
  for e in enums:
    def q(v):
      if v is None:
        return 'NULL'
      if isinstance(v, int):
        return str(v)
      return "'%s'" % str(v).replace("'", "''")
    vals.append('  (%s)' % ', '.join([
      "'%s'" % e['key_guid'],
      q(e['pub_enum_type']),
      q(e['pub_name']),
      q(e['pub_value']),
      q(e['pub_notes']),
    ]))
  return '\n'.join(lines) + '\n' + ',\n'.join(vals) + ';'


async def dump(conn, prefix: str = 'schema') -> str:
  print('Reading schema...')
  types = await _read_types(conn)
  enums = await _read_enums(conn)
  schema = await _read_schema(conn)

  table_by_guid = {t['key_guid']: t for t in schema['tables']}

  types_table = next(
    (t for t in schema['tables'] if t['pub_name'] == 'contracts_primitives_types'),
    None,
  )

  sections: list[str] = []
  sections.append('-- Generated %s UTC' % datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S'))
  sections.append('SET ANSI_NULLS ON;\nGO\nSET QUOTED_IDENTIFIER ON;\nGO\n')

  sections.append('-- =====================================================================')
  sections.append('-- Static prelude: types table')
  sections.append('-- =====================================================================')
  if types_table:
    sections.append(_build_create_table(types_table, schema['columns']))
    types_constraints = [
      c for c in schema['constraints']
      if c['ref_table_guid'] == types_table['key_guid']
    ]
    for con in types_constraints:
      ref_table = table_by_guid.get(con['ref_referenced_table_guid']) if con.get('ref_referenced_table_guid') else None
      sections.append(_build_constraint(con, types_table, ref_table, schema['constraint_columns']))
  sections.append(_build_types_seed(types))
  sections.append('GO')
  sections.append('')

  sections.append('-- =====================================================================')
  sections.append('-- Generative section')
  sections.append('-- =====================================================================')
  sections.append('-- Tables')
  for table in schema['tables']:
    if types_table and table['key_guid'] == types_table['key_guid']:
      continue
    sections.append(_build_create_table(table, schema['columns']))
  sections.append('')

  if enums:
    sections.append('-- contracts_primitives_enums seed')
    sections.append(_build_enums_seed(enums))
    sections.append('')

  sections.append('-- Indexes')
  for idx in schema['indexes']:
    table = table_by_guid.get(idx['ref_table_guid'])
    if not table:
      continue
    sections.append(_build_create_index(idx, table, schema['index_columns']))
  sections.append('')

  # Constraints emitted in two passes: PKs / UNIQUEs / CHECKs first across
  # all tables, then FKs. FKs depend on the referenced table already having
  # its primary or candidate key in place; without splitting, constraints
  # interleave by table guid (non-deterministic) and FKs can land before
  # their target's PK exists.
  sections.append('-- Constraints (PK, UNIQUE, CHECK)')
  for con in schema['constraints']:
    if con['kind_name'] == 'FOREIGN_KEY':
      continue
    table = table_by_guid.get(con['ref_table_guid'])
    if not table:
      continue
    if types_table and con['ref_table_guid'] == types_table['key_guid']:
      continue
    ref_table = table_by_guid.get(con['ref_referenced_table_guid']) if con.get('ref_referenced_table_guid') else None
    sections.append(_build_constraint(con, table, ref_table, schema['constraint_columns']))
  sections.append('')

  sections.append('-- Constraints (FOREIGN KEY)')
  for con in schema['constraints']:
    if con['kind_name'] != 'FOREIGN_KEY':
      continue
    table = table_by_guid.get(con['ref_table_guid'])
    if not table:
      continue
    if types_table and con['ref_table_guid'] == types_table['key_guid']:
      continue
    ref_table = table_by_guid.get(con['ref_referenced_table_guid']) if con.get('ref_referenced_table_guid') else None
    sections.append(_build_constraint(con, table, ref_table, schema['constraint_columns']))

  ts = datetime.now(timezone.utc).strftime('%Y%m%d')
  filename = '%s_%s.sql' % (prefix, ts)
  with open(filename, 'w') as f:
    f.write('\n'.join(sections))
  print('Schema dumped to %s' % filename)
  return filename


# =============================================================================
# apply
# =============================================================================

async def apply(conn, path: str) -> None:
  with open(path, 'r') as f:
    sql = f.read()
  count = 0
  async with conn.cursor() as cur:
    for stmt in sql.split(';'):
      stmt = stmt.strip()
      if not stmt:
        continue
      await cur.execute(stmt)
      count += 1
  print('Applied %d statements from %s.' % (count, path))
  

# =============================================================================
# install_seed
# =============================================================================
#
# Reads a JSON package file and MERGEs each row into its declared target
# table by key_guid. Format:
#
#   {
#     "package": "<name>",
#     "version": "<semver>",
#     "rows": [
#       {"table": "<table_name>", "data": {"key_guid": "...", ...}},
#       ...
#     ]
#   }
#
# Each row is one MERGE on key_guid. Rows are processed in file order; the
# author is responsible for ordering when FK dependencies exist within a
# package (e.g. tables before columns before constraints). Idempotent:
# re-running over the same package with the same data is a no-op.
# =============================================================================

async def install_seed(conn, path: str) -> None:
  with open(path, 'r') as f:
    package = json.load(f)

  pkg_name = package.get('package', '<unnamed>')
  pkg_version = package.get('version', '<unversioned>')
  rows = package.get('rows', [])

  print('Installing seed: %s v%s (%d rows)' % (pkg_name, pkg_version, len(rows)))

  counts: dict[str, int] = {}
  for i, row in enumerate(rows):
    table = row['table']
    data = row['data']
    try:
      await _merge(conn, table, 'key_guid', data)
      counts[table] = counts.get(table, 0) + 1
    except Exception as e:
      print('  row %d (%s, key_guid=%s): %s' % (i, table, data.get('key_guid'), e))
      raise

  for table in sorted(counts.keys()):
    print('  %-40s %d' % (table, counts[table]))
  print('Seed install complete.')
