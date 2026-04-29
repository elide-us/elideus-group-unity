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
    """SELECT e.pub_name, e.key_guid
       FROM contracts_primitives_enums e
       JOIN contracts_primitives_enum_types et ON e.ref_enum_type_guid = et.key_guid
       WHERE et.pub_name = 'constraint_kind'
       FOR JSON PATH"""
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


async def _read_enum_types(conn) -> list[dict]:
  return await _query_json(
    conn,
    """SELECT key_guid, pub_name, pub_notes
       FROM contracts_primitives_enum_types
       ORDER BY pub_name
       FOR JSON PATH, INCLUDE_NULL_VALUES"""
  )


async def _read_enums(conn) -> list[dict]:
  return await _query_json(
    conn,
    """SELECT e.key_guid, e.ref_enum_type_guid, et.pub_name AS enum_type_name,
              e.pub_name, e.pub_value, e.pub_notes
       FROM contracts_primitives_enums e
       JOIN contracts_primitives_enum_types et ON e.ref_enum_type_guid = et.key_guid
       ORDER BY et.pub_name, e.pub_value
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


def _build_enum_types_seed(enum_types: list[dict]) -> str:
  if not enum_types:
    return ''
  lines = ['INSERT INTO [dbo].[contracts_primitives_enum_types]',
           '  (key_guid, pub_name, pub_notes)',
           'VALUES']
  vals = []
  for et in enum_types:
    def q(v):
      if v is None:
        return 'NULL'
      if isinstance(v, int):
        return str(v)
      return "'%s'" % str(v).replace("'", "''")
    vals.append('  (%s)' % ', '.join([
      "'%s'" % et['key_guid'],
      q(et['pub_name']),
      q(et['pub_notes']),
    ]))
  return '\n'.join(lines) + '\n' + ',\n'.join(vals) + ';'


def _build_enums_seed(enums: list[dict]) -> str:
  if not enums:
    return ''
  lines = ['INSERT INTO [dbo].[contracts_primitives_enums]',
           '  (key_guid, ref_enum_type_guid, pub_name, pub_value, pub_notes)',
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
      "'%s'" % e['ref_enum_type_guid'],
      q(e['pub_name']),
      q(e['pub_value']),
      q(e['pub_notes']),
    ]))
  return '\n'.join(lines) + '\n' + ',\n'.join(vals) + ';'


async def dump(conn, prefix: str = 'schema') -> str:
  print('Reading schema...')
  types = await _read_types(conn)
  enum_types = await _read_enum_types(conn)
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
    sections.append('-- contracts_primitives_enum_types seed')
    sections.append(_build_enum_types_seed(enum_types))
    sections.append('')
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


# =============================================================================
# generate_seed
# =============================================================================
#
# Generates a kernel-package seed JSON file by reading the contracts_db_*
# cluster directly. Filters on ref_package_guid IS NULL — kernel-owned rows
# predate the manifest entries that would otherwise own them, so NULL is
# the kernel's package-ownership marker.
#
# Output is the same flat-rows shape consumed by install_seed:
#   {package, version, rows: [{table, data}, ...]}
#
# Row order matches install dependency order: tables, columns, indexes,
# index_columns, constraints, constraint_columns. Within each table, rows
# are sorted to make the output deterministic across runs.
#
# Currently scoped to the kernel package (ref_package_guid IS NULL). When
# make_package lands in DatabaseManagementModule, this logic moves there
# and accepts a package-name argument that resolves to a manifest GUID.
#
# Note: priv_* timestamps and ref_package_guid are deliberately omitted
# from the projection. install_seed expects neither — timestamps come from
# column defaults at MERGE time, and ref_package_guid for non-kernel
# packages is auto-injected by the install pipeline. Including them here
# would force specific values into every install, which is wrong.
# =============================================================================

# Tables emitted in dependency-safe install order, paired with the ORDER BY
# clause that produces deterministic output across runs.
_KERNEL_SEED_TABLES = [
  ('contracts_db_tables',             'pub_schema, pub_name'),
  ('contracts_db_columns',            'ref_table_guid, pub_ordinal'),
  ('contracts_db_indexes',            'ref_table_guid, pub_name'),
  ('contracts_db_index_columns',      'ref_index_guid, pub_ordinal'),
  ('contracts_db_constraints',        'ref_table_guid, pub_name'),
  ('contracts_db_constraint_columns', 'ref_constraint_guid, pub_ordinal'),
]

# Per-table column projections — exactly the columns install_seed writes
# into each row's data dict. Excludes priv_* timestamps and ref_package_guid.
_KERNEL_SEED_COLUMNS = {
  'contracts_db_tables': [
    'key_guid', 'pub_name', 'pub_schema', 'pub_alias',
  ],
  'contracts_db_columns': [
    'key_guid', 'ref_table_guid', 'ref_type_guid', 'pub_name',
    'pub_ordinal', 'pub_is_nullable', 'pub_default_value', 'pub_max_length',
  ],
  'contracts_db_indexes': [
    'key_guid', 'ref_table_guid', 'pub_name', 'pub_is_unique',
  ],
  'contracts_db_index_columns': [
    'key_guid', 'ref_index_guid', 'ref_column_guid', 'pub_ordinal',
  ],
  'contracts_db_constraints': [
    'key_guid', 'ref_table_guid', 'ref_kind_enum_guid',
    'ref_referenced_table_guid', 'pub_name', 'pub_expression',
  ],
  'contracts_db_constraint_columns': [
    'key_guid', 'ref_constraint_guid', 'ref_column_guid',
    'ref_referenced_column_guid', 'pub_ordinal',
  ],
}


async def generate_seed(conn, path: str,
                        package: str = 'kernel',
                        version: str = '1.0.0') -> None:
  """Read kernel-owned rows from contracts_db_*, emit as a seed JSON file."""
  rows: list[dict] = []
  counts: dict[str, int] = {}

  for table, order_by in _KERNEL_SEED_TABLES:
    columns = _KERNEL_SEED_COLUMNS[table]
    select_list = ', '.join(columns)
    sql = (
      'SELECT %s FROM [%s] WHERE ref_package_guid IS NULL ORDER BY %s '
      'FOR JSON PATH, INCLUDE_NULL_VALUES'
    ) % (select_list, table, order_by)
    table_rows = await _query_json(conn, sql)
    for row in table_rows:
      rows.append({'table': table, 'data': row})
    counts[table] = len(table_rows)

  package_doc = {
    'package': package,
    'version': version,
    'rows': rows,
  }

  with open(path, 'w') as f:
    json.dump(package_doc, f, indent=2)

  print('Generated seed: %s' % path)
  print('  package: %s v%s' % (package, version))
  for table, _ in _KERNEL_SEED_TABLES:
    print('  %-40s %d' % (table, counts[table]))
  print('  total: %d rows' % len(rows))


# =============================================================================
# install
# =============================================================================
#
# Full package install pipeline. A package JSON has the shape:
#
#   {
#     "package": "<name>",
#     "version": "<semver>",
#     "schema": [
#       {"table": "contracts_db_tables",            "data": {...}},
#       {"table": "contracts_db_columns",           "data": {...}},
#       {"table": "contracts_db_constraints",       "data": {...}},
#       {"table": "contracts_db_constraint_columns","data": {...}},
#       ...
#     ],
#     "data": [
#       {"table": "<arbitrary>", "data": {...}},
#       ...
#     ]
#   }
#
# Phases (register first, seal last):
#   1. register        — write service_modules_manifest row, pub_is_sealed=0
#   2. seed_schema     — MERGE rows from `schema` into contracts_db_*,
#                        auto-injecting ref_package_guid into every row
#                        whose target table has that column
#   3. materialize     — diff contracts_db_tables vs sys.tables; for each
#                        declared-but-missing table, generate and run DDL
#                        (CREATE TABLE + indexes + PK/UNIQUE/CHECK + FKs)
#   4. seed_data       — MERGE rows from `data` into target tables, with
#                        the same auto-injection as seed_schema
#   5. seal            — flip pub_is_sealed=1 on the manifest row
#
# Mid-install crashes leave pub_is_sealed=0 on the manifest row, so
# re-running detects unsealed packages and the pipeline can resume
# (every step is MERGE-idempotent).
#
# Failure handling: each phase is a try/except boundary. On error, prints
# which phase, which row (if applicable), and the full exception. The
# pipeline halts immediately. DDL in materialize is guarded against
# re-running by a left-anti-join on sys.tables, so re-runs only create
# what's still missing.
# =============================================================================

# Per-table cache of which tables physically have a ref_package_guid column.
# Populated lazily by _table_has_package_column() to avoid querying
# sys.columns for every row in a large package.
_PACKAGE_COL_CACHE: dict[str, bool] = {}


async def _table_has_package_column(conn, table: str) -> bool:
  if table in _PACKAGE_COL_CACHE:
    return _PACKAGE_COL_CACHE[table]
  rows = await _query_json(
    conn,
    """SELECT 1 AS ok
       FROM sys.columns c
       JOIN sys.tables t ON c.object_id = t.object_id
       WHERE t.name = ? AND c.name = 'ref_package_guid'
       FOR JSON PATH""",
    (table,)
  )
  has = bool(rows)
  _PACKAGE_COL_CACHE[table] = has
  return has


async def _existing_table_names(conn) -> set[str]:
  """Return {schema.table} for every table currently in sys.tables."""
  rows = await _query_json(
    conn,
    """SELECT s.name AS pub_schema, t.name AS pub_name
       FROM sys.tables t
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       FOR JSON PATH"""
  )
  return {'%s.%s' % (r['pub_schema'], r['pub_name']) for r in rows}


async def _materialize(conn) -> None:
  """Phase 2. Read contracts_db_*, find tables declared but not in sys.tables,
  generate and execute DDL for them. Reuses the same builders dump uses, so
  output is identical to what dump would emit for those tables."""
  schema = await _read_schema(conn)
  existing = await _existing_table_names(conn)

  # Filter to tables declared in contracts_db_tables that aren't physical yet
  missing = [
    t for t in schema['tables']
    if '%s.%s' % (t['pub_schema'], t['pub_name']) not in existing
  ]
  if not missing:
    print('  no tables to materialize')
    return

  missing_guids = {t['key_guid'] for t in missing}
  table_by_guid = {t['key_guid']: t for t in schema['tables']}

  print('  materializing %d table(s):' % len(missing))
  for t in missing:
    print('    %s.%s' % (t['pub_schema'], t['pub_name']))

  # CREATE TABLE for each missing table
  for table in missing:
    ddl = _build_create_table(table, schema['columns'])
    async with conn.cursor() as cur:
      await cur.execute(ddl)

  # Indexes on missing tables
  for idx in schema['indexes']:
    if idx['ref_table_guid'] not in missing_guids:
      continue
    table = table_by_guid.get(idx['ref_table_guid'])
    if not table:
      continue
    ddl = _build_create_index(idx, table, schema['index_columns'])
    async with conn.cursor() as cur:
      await cur.execute(ddl)

  # Constraints — two passes (PK/UQ/CHECK first, FK second)
  # Each constraint applies only if its owning table is missing AND, for FKs,
  # if the referenced table either already exists or was just created here.
  for con in schema['constraints']:
    if con['kind_name'] == 'FOREIGN_KEY':
      continue
    if con['ref_table_guid'] not in missing_guids:
      continue
    table = table_by_guid.get(con['ref_table_guid'])
    if not table:
      continue
    ref_table = table_by_guid.get(con['ref_referenced_table_guid']) if con.get('ref_referenced_table_guid') else None
    ddl = _build_constraint(con, table, ref_table, schema['constraint_columns'])
    async with conn.cursor() as cur:
      await cur.execute(ddl)

  for con in schema['constraints']:
    if con['kind_name'] != 'FOREIGN_KEY':
      continue
    if con['ref_table_guid'] not in missing_guids:
      continue
    table = table_by_guid.get(con['ref_table_guid'])
    if not table:
      continue
    ref_table = table_by_guid.get(con['ref_referenced_table_guid']) if con.get('ref_referenced_table_guid') else None
    if ref_table is None:
      raise ValueError('FK %s on %s.%s has no resolvable referenced table' % (
        con['pub_name'], table['pub_schema'], table['pub_name']))
    ddl = _build_constraint(con, table, ref_table, schema['constraint_columns'])
    async with conn.cursor() as cur:
      await cur.execute(ddl)


async def _merge_rows_phase(conn, rows: list, phase_name: str,
                            pkg_guid: str | None = None) -> dict[str, int]:
  """Generic MERGE-each-row helper used by both seed_schema and seed_data
  phases. If pkg_guid is supplied, auto-injects ref_package_guid into each
  row whose target table physically has that column (unless the row already
  sets it explicitly — author override stays intact). Returns count-by-table
  dict on success; raises on first error with row index and table name
  attached to the message."""
  counts: dict[str, int] = {}
  for i, row in enumerate(rows):
    if 'table' not in row or 'data' not in row:
      raise ValueError('%s row %d malformed: missing "table" or "data" key' % (phase_name, i))
    table = row['table']
    data = dict(row['data'])  # copy so injection doesn't mutate caller's dict
    if 'key_guid' not in data:
      raise ValueError('%s row %d (%s) missing key_guid' % (phase_name, i, table))
    if pkg_guid and 'ref_package_guid' not in data:
      if await _table_has_package_column(conn, table):
        data['ref_package_guid'] = pkg_guid
    try:
      await _merge(conn, table, 'key_guid', data)
    except Exception as e:
      raise RuntimeError('%s row %d (%s, key_guid=%s): %s' % (
        phase_name, i, table, data.get('key_guid'), e)) from e
    counts[table] = counts.get(table, 0) + 1
  return counts


def _print_counts(counts: dict[str, int]) -> None:
  for table in sorted(counts.keys()):
    print('    %-40s %d' % (table, counts[table]))


async def install(conn, path: str) -> None:
  # Read package
  try:
    with open(path, 'r') as f:
      package = json.load(f)
  except FileNotFoundError:
    print('Error: package file not found: %s' % path)
    return
  except json.JSONDecodeError as e:
    print('Error: package file is not valid JSON: %s' % e)
    return

  pkg_name = package.get('package')
  pkg_version = package.get('version')
  if not pkg_name or not pkg_version:
    print('Error: package file missing required "package" or "version" field')
    return

  schema_rows = package.get('schema', [])
  data_rows = package.get('data', [])

  print('Installing %s v%s' % (pkg_name, pkg_version))
  print('  schema rows: %d' % len(schema_rows))
  print('  data rows:   %d' % len(data_rows))

  manifest_guid = _guid('service_modules_manifest', pkg_name)

  # ---- Phase 1: register (manifest row, unsealed) ----
  print('Phase 1: register')
  try:
    await _merge(conn, 'service_modules_manifest', 'key_guid', {
      'key_guid': manifest_guid,
      'pub_name': pkg_name,
      'pub_version': pkg_version,
      'pub_last_version': pkg_version,
      'pub_is_sealed': 0,
    })
    print('    %s v%s registered (unsealed)' % (pkg_name, pkg_version))
  except Exception as e:
    print('  FAILED: %s' % e)
    return

  # ---- Phase 2: seed schema declarations ----
  print('Phase 2: seed_schema')
  try:
    counts = await _merge_rows_phase(conn, schema_rows, 'seed_schema', pkg_guid=manifest_guid)
    _print_counts(counts)
  except Exception as e:
    print('  FAILED: %s' % e)
    return

  # ---- Phase 3: materialize ----
  print('Phase 3: materialize')
  try:
    await _materialize(conn)
  except Exception as e:
    print('  FAILED: %s' % e)
    return

  # ---- Phase 4: seed data ----
  print('Phase 4: seed_data')
  try:
    counts = await _merge_rows_phase(conn, data_rows, 'seed_data', pkg_guid=manifest_guid)
    _print_counts(counts)
  except Exception as e:
    print('  FAILED: %s' % e)
    return

  # ---- Phase 5: seal ----
  print('Phase 5: seal')
  try:
    await _execute(
      conn,
      'UPDATE service_modules_manifest SET pub_is_sealed = 1 WHERE key_guid = ?',
      (manifest_guid,)
    )
    print('    %s v%s sealed' % (pkg_name, pkg_version))
  except Exception as e:
    print('  FAILED: %s' % e)
    return

  print('Install complete.')


# =============================================================================
# Package introspection helpers
# =============================================================================

async def _tables_with_package_ref(conn) -> list[str]:
  """Returns [schema.table] for every table that has a ref_package_guid
  column. Determined at runtime so the list isn't hardcoded."""
  rows = await _query_json(
    conn,
    """SELECT s.name AS pub_schema, t.name AS pub_name
       FROM sys.tables t
       JOIN sys.schemas s ON t.schema_id = s.schema_id
       JOIN sys.columns c ON c.object_id = t.object_id
       WHERE c.name = 'ref_package_guid'
       ORDER BY s.name, t.name
       FOR JSON PATH"""
  )
  return ['%s.%s' % (r['pub_schema'], r['pub_name']) for r in rows]


# =============================================================================
# list_packages
# =============================================================================

async def list_packages(conn) -> None:
  manifest = await _query_json(
    conn,
    """SELECT key_guid, pub_name, pub_version, pub_is_sealed
       FROM service_modules_manifest
       ORDER BY pub_name
       FOR JSON PATH"""
  )
  if not manifest:
    print('No packages installed.')
    return
  pkg_tables = await _tables_with_package_ref(conn)
  ownership: dict[str, dict[str, int]] = {}  # pkg_guid -> {table -> count}
  for tbl in pkg_tables:
    table_name = tbl.split('.', 1)[1]
    rows = await _query_json(
      conn,
      "SELECT ref_package_guid AS pkg, COUNT(*) AS n FROM [%s] WHERE ref_package_guid IS NOT NULL GROUP BY ref_package_guid FOR JSON PATH" % table_name
    )
    for r in rows:
      ownership.setdefault(r['pkg'].upper(), {})[tbl] = r['n']

  print('Installed packages:')
  for m in manifest:
    sealed = 'sealed' if m['pub_is_sealed'] else 'UNSEALED'
    counts = ownership.get(m['key_guid'].upper(), {})
    total = sum(counts.values())
    print('  %-30s v%-12s %-9s rows=%d' % (m['pub_name'], m['pub_version'], sealed, total))
    if counts:
      for tbl in sorted(counts.keys()):
        print('      %-40s %d' % (tbl, counts[tbl]))


# =============================================================================
# uninstall
# =============================================================================
#
# Reverses install. Removes:
#   1. Drop physical tables owned by the package (rows in contracts_db_tables
#      with matching pkg_guid). Their data rows go with the table.
#   2. ext_ columns: contracts_db_columns rows owned by pkg whose parent
#      table is NOT owned by the package — emit ALTER TABLE ... DROP COLUMN
#      after dropping any indexes/FKs that reference the column.
#   3. Delete owned rows from kernel pkg-aware tables in dependency-safe
#      order (constraint_columns before constraints, columns before tables,
#      etc.).
#   4. Maintenance pass: sp_updatestats + DBCC FREEPROCCACHE.
#   5. Delete the manifest row.
#
# Default: dry run. Prints the plan and changes nothing.
# Pass confirm=True to execute.
#
# Hard guard: refuses to uninstall the kernel package.
# =============================================================================

# Order matters. Tables with FKs to the manifest are listed in dependency-
# safe deletion order: child rows before parent rows.
_UNINSTALL_TABLE_ORDER = [
  'contracts_db_constraint_columns',
  'contracts_db_constraints',
  'contracts_db_index_columns',
  'contracts_db_indexes',
  'contracts_db_columns',
  'contracts_db_tables',
  'contracts_db_operations',
  'contracts_primitives_enums',
  'contracts_primitives_types',
  'service_system_configuration',
]


async def _resolve_package(conn, pkg_name: str) -> dict | None:
  rows = await _query_json(
    conn,
    "SELECT key_guid, pub_name, pub_version, pub_is_sealed FROM service_modules_manifest WHERE pub_name = ? FOR JSON PATH",
    (pkg_name,)
  )
  return rows[0] if rows else None


async def _scan_owned_rows(conn, pkg_guid: str) -> dict:
  """Inventory what the package owns. Returns:
     {
       'data_tables': [{'schema', 'name', 'guid', 'count', 'physical'}, ...],
       'ext_columns': [{'schema', 'table', 'column', 'column_guid'}, ...],
       'pkg_table_counts': {'contracts_db_columns': N, ...},
     }
  """
  result: dict = {'data_tables': [], 'ext_columns': [], 'pkg_table_counts': {}}

  # Tables owned by the package
  owned_tables = await _query_json(
    conn,
    "SELECT key_guid, pub_schema, pub_name FROM contracts_db_tables WHERE ref_package_guid = ? FOR JSON PATH",
    (pkg_guid,)
  )
  owned_table_guids = {t['key_guid'].upper() for t in owned_tables}

  for t in owned_tables:
    exists = await _query_json(
      conn,
      """SELECT 1 AS ok FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
         WHERE s.name = ? AND t.name = ? FOR JSON PATH""",
      (t['pub_schema'], t['pub_name'])
    )
    if exists:
      cnt = await _query_json(
        conn,
        "SELECT COUNT(*) AS n FROM [%s].[%s] FOR JSON PATH" % (t['pub_schema'], t['pub_name'])
      )
      n = cnt[0]['n'] if cnt else 0
    else:
      n = 0
    result['data_tables'].append({
      'schema': t['pub_schema'],
      'name': t['pub_name'],
      'guid': t['key_guid'],
      'count': n,
      'physical': bool(exists),
    })

  # ext_ columns: contracts_db_columns rows owned by pkg but parent table isn't owned
  ext_rows = await _query_json(
    conn,
    """SELECT c.key_guid, c.pub_name AS column_name, c.ref_table_guid,
              t.pub_schema, t.pub_name AS table_name
       FROM contracts_db_columns c
       JOIN contracts_db_tables t ON c.ref_table_guid = t.key_guid
       WHERE c.ref_package_guid = ?
       FOR JSON PATH""",
    (pkg_guid,)
  )
  for r in ext_rows:
    if r['ref_table_guid'].upper() not in owned_table_guids:
      result['ext_columns'].append({
        'schema': r['pub_schema'],
        'table': r['table_name'],
        'column': r['column_name'],
        'column_guid': r['key_guid'],
      })

  # Counts in each pkg-aware kernel table
  for tbl in _UNINSTALL_TABLE_ORDER:
    rows = await _query_json(
      conn,
      "SELECT COUNT(*) AS n FROM [%s] WHERE ref_package_guid = ? FOR JSON PATH" % tbl,
      (pkg_guid,)
    )
    n = rows[0]['n'] if rows else 0
    if n > 0:
      result['pkg_table_counts'][tbl] = n

  return result


def _print_uninstall_plan(pkg: dict, scan: dict) -> None:
  print('Uninstall plan for %s v%s:' % (pkg['pub_name'], pkg['pub_version']))
  if not pkg['pub_is_sealed']:
    print('  (package is UNSEALED — uninstall cleans up partial install)')

  if scan['data_tables']:
    print('  Drop %d table(s):' % len(scan['data_tables']))
    for t in scan['data_tables']:
      tag = '' if t['physical'] else ' (declared only, not physical)'
      print('    DROP TABLE [%s].[%s]  (%d row(s))%s' % (t['schema'], t['name'], t['count'], tag))

  if scan['ext_columns']:
    print('  Drop %d ext column(s) on foreign tables:' % len(scan['ext_columns']))
    for c in scan['ext_columns']:
      print('    ALTER TABLE [%s].[%s] DROP COLUMN [%s]' % (c['schema'], c['table'], c['column']))

  if scan['pkg_table_counts']:
    print('  Delete owned rows:')
    for tbl in _UNINSTALL_TABLE_ORDER:
      if tbl in scan['pkg_table_counts']:
        print('    %-40s %d' % (tbl, scan['pkg_table_counts'][tbl]))

  print('  Run maintenance pass (sp_updatestats, DBCC FREEPROCCACHE)')
  print('  Delete service_modules_manifest row')


async def _execute_uninstall(conn, pkg: dict, scan: dict) -> None:
  pkg_guid = pkg['key_guid']

  # Step 1: drop physical owned tables (rows go with them)
  for t in scan['data_tables']:
    if t['physical']:
      ddl = 'DROP TABLE [%s].[%s]' % (t['schema'], t['name'])
      print('    %s' % ddl)
      try:
        await _execute(conn, ddl)
      except Exception as e:
        raise RuntimeError('failed to drop %s.%s: %s' % (t['schema'], t['name'], e)) from e

  # Step 2: drop ext columns from foreign tables.
  # Indexes/FKs physically referencing the column must go first.
  for c in scan['ext_columns']:
    idx_rows = await _query_json(
      conn,
      """SELECT i.name AS index_name
         FROM sys.indexes i
         JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
         JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
         JOIN sys.tables t ON c.object_id = t.object_id
         JOIN sys.schemas s ON t.schema_id = s.schema_id
         WHERE s.name = ? AND t.name = ? AND c.name = ?
           AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
         FOR JSON PATH""",
      (c['schema'], c['table'], c['column'])
    )
    for ix in idx_rows:
      ddl = 'DROP INDEX [%s] ON [%s].[%s]' % (ix['index_name'], c['schema'], c['table'])
      print('    %s' % ddl)
      await _execute(conn, ddl)

    fk_rows = await _query_json(
      conn,
      """SELECT fk.name AS fk_name
         FROM sys.foreign_keys fk
         JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
         JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
         JOIN sys.tables t ON fk.parent_object_id = t.object_id
         JOIN sys.schemas s ON t.schema_id = s.schema_id
         WHERE s.name = ? AND t.name = ? AND c.name = ?
         FOR JSON PATH""",
      (c['schema'], c['table'], c['column'])
    )
    for fk in fk_rows:
      ddl = 'ALTER TABLE [%s].[%s] DROP CONSTRAINT [%s]' % (c['schema'], c['table'], fk['fk_name'])
      print('    %s' % ddl)
      await _execute(conn, ddl)

    ddl = 'ALTER TABLE [%s].[%s] DROP COLUMN [%s]' % (c['schema'], c['table'], c['column'])
    print('    %s' % ddl)
    try:
      await _execute(conn, ddl)
    except Exception as e:
      raise RuntimeError('failed to drop ext column %s.%s.%s: %s' % (
        c['schema'], c['table'], c['column'], e)) from e

  # Step 3: delete owned rows from kernel pkg-aware tables in dependency order
  for tbl in _UNINSTALL_TABLE_ORDER:
    if tbl not in scan['pkg_table_counts']:
      continue
    sql = 'DELETE FROM [%s] WHERE ref_package_guid = ?' % tbl
    n = await _execute(conn, sql, (pkg_guid,))
    print('    DELETE [%s]: %s row(s)' % (tbl, n))

  # Step 4: maintenance pass
  print('    EXEC sp_updatestats')
  try:
    await _execute(conn, 'EXEC sp_updatestats')
  except Exception as e:
    print('    (sp_updatestats failed: %s)' % e)
  print('    DBCC FREEPROCCACHE')
  try:
    await _execute(conn, 'DBCC FREEPROCCACHE')
  except Exception as e:
    print('    (DBCC FREEPROCCACHE failed: %s)' % e)

  # Step 5: delete the manifest row
  await _execute(conn, 'DELETE FROM service_modules_manifest WHERE key_guid = ?', (pkg_guid,))
  print('    DELETE service_modules_manifest: 1 row')


async def uninstall(conn, pkg_name: str, confirm: bool = False) -> None:
  if pkg_name == 'kernel':
    print('Refused: cannot uninstall the kernel package.')
    return

  pkg = await _resolve_package(conn, pkg_name)
  if not pkg:
    print('Package not found: %s' % pkg_name)
    return

  scan = await _scan_owned_rows(conn, pkg['key_guid'])
  _print_uninstall_plan(pkg, scan)

  if not confirm:
    print()
    print('This is a dry run. To execute, run: uninstall %s confirm' % pkg_name)
    return

  print()
  print('Executing uninstall...')
  try:
    await _execute_uninstall(conn, pkg, scan)
  except Exception as e:
    print('  FAILED: %s' % e)
    return
  print('Uninstall complete.')
