"""
Generate v1.0.0_kernel_seed.json by hand-encoding the canonical kernel schema.

Mirrors populate's GUID scheme. If v1.0.0_kernel.sql changes, edit KERNEL_TABLES
below and regenerate.

Usage:
  python scripts/gen_kernel_seed.py > migrations/v1.0.0_kernel_seed.json
"""

import json
import sys
import uuid

NS = uuid.UUID('DECAFBAD-CAFE-FADE-BABE-C0FFEE420DAB')

def g(entity_type, natural_key):
    return str(uuid.uuid5(NS, '%s:%s' % (entity_type, natural_key))).upper()


# --- type GUIDs from kernel canon (verbatim) ---
TYPE = {
    'BINARY':         '4B286A51-7A0B-5BA2-8391-264E572C8375',
    'BOOL':           '72AD4685-D3E2-5A3F-941E-4EA9B0D3F9CC',
    'DATE':           'CA4D0D68-BA56-5852-9CDA-DC88F8D120FB',
    'DATETIME_TZ':    '0A301083-D3E1-5119-9ADB-09B47A1E00FA',
    'DECIMAL_19_5':   '4DB81F9F-8990-5952-BBEA-4E175B362CDA',
    'DECIMAL_28_12':  '085132BC-DDEB-5591-ACB0-7348445DC92C',
    'DECIMAL_38_18':  '53434CAA-A382-5B45-BAD2-AC3F655ED3A0',
    'FLOAT32':        'BD61A7EA-38ED-57AC-949F-5C82A0C0173E',
    'FLOAT64':        '421D6C05-ACBA-58E7-9FE3-27F500497011',
    'INT16':          '18667606-C633-5A82-9A3B-2CD27916FC95',
    'INT32':          '1F2E7AE3-B435-5C98-A73D-ABF84F6A5E50',
    'INT64':          'B96336CD-D4A0-5B24-920E-C818BDC4AE7A',
    'INT64_IDENTITY': '2C0073EA-0BF3-53BF-8C5A-95C1D62F9A23',
    'INT8':           '0D331097-4AB4-5AA2-A481-07AB66A29BBD',
    'JSON_DOC':       'EBCFAA50-8CF7-58CB-A90E-5BBBD92DEA9C',
    'STRING':         '8579BB4B-746B-5E4B-867B-BFB182D52110',
    'TEXT':           '8529FAA0-77FA-5C6E-B8D5-A3F886C973F6',
    'UUID':           'DF427A75-F5DE-5797-988A-F2FF40BD7FA5',
    'VECTOR':         'F4CF3C0D-908E-5682-8FE7-F9973B90C56A',
}

CK = {
    'PRIMARY_KEY': '3426C194-B912-5F71-802F-566E2FF1E8FF',
    'FOREIGN_KEY': 'B6ABA725-1FDB-5454-B164-DDBE11079598',
    'UNIQUE':      '4D75333D-E472-5813-A03B-C0162671A00D',
    'CHECK':       '92400F11-FCFD-5285-B9E2-D682B2496A88',
}


def _generate_alias(name, taken):
    segments = name.split('_')
    n = len(segments)
    rounds = [1] * n
    def build():
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
            continue
        rounds[seg_idx] += 1
        candidate = build()
    return candidate


# ref_package_guid present on every kernel table except service_modules_manifest.
PKG_COL = ('ref_package_guid', 'UUID', True, None, None)

PRIV_AUDIT_COLS = [
    ('priv_created_on',  'DATETIME_TZ', False, 'SYSDATETIMEOFFSET()', None),
    ('priv_modified_on', 'DATETIME_TZ', False, 'SYSDATETIMEOFFSET()', None),
]

KERNEL_TABLES = [
    {
        'name': 'contracts_primitives_types',
        'columns': [
            ('key_guid',            'UUID',        False, None, None),
            PKG_COL,
            ('pub_name',            'STRING',      False, None, 64),
            ('pub_mssql_type',      'STRING',      False, None, 128),
            ('pub_postgresql_type', 'STRING',      True,  None, 128),
            ('pub_mysql_type',      'STRING',      True,  None, 128),
            ('pub_python_type',     'STRING',      False, None, 64),
            ('pub_typescript_type', 'STRING',      False, None, 64),
            ('pub_json_type',       'STRING',      False, None, 64),
            ('pub_odbc_type_code',  'INT16',       False, None, None),
            ('pub_default_length',  'INT32',       True,  None, None),
            ('pub_notes',           'STRING',      True,  None, 512),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_primitives_types', 'PRIMARY_KEY', ['key_guid'], None, None, None),
            ('UQ_cpt_name',                   'UNIQUE',      ['pub_name'], None, None, None),
            ('FK_cpt_package',                'FOREIGN_KEY', ['ref_package_guid'], 'service_modules_manifest', ['key_guid'], None),
        ],
        'indexes': [],
    },
    {
        'name': 'contracts_primitives_enums',
        'columns': [
            ('key_guid',      'UUID',   False, None, None),
            PKG_COL,
            ('pub_enum_type', 'STRING', False, None, 128),
            ('pub_name',      'STRING', False, None, 128),
            ('pub_value',     'INT8',   False, None, None),
            ('pub_notes',     'STRING', True,  None, 512),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_primitives_enums', 'PRIMARY_KEY', ['key_guid'],                     None, None, None),
            ('UQ_cpe_type_name',              'UNIQUE',      ['pub_enum_type', 'pub_name'],    None, None, None),
            ('UQ_cpe_type_value',             'UNIQUE',      ['pub_enum_type', 'pub_value'],   None, None, None),
            ('FK_cpe_package',                'FOREIGN_KEY', ['ref_package_guid'], 'service_modules_manifest', ['key_guid'], None),
        ],
        'indexes': [],
    },
    {
        'name': 'contracts_db_tables',
        'columns': [
            ('key_guid',   'UUID',   False, None,    None),
            PKG_COL,
            ('pub_name',   'STRING', False, None,    128),
            ('pub_schema', 'STRING', False, "'dbo'", 64),
            ('pub_alias',  'STRING', False, None,    128),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_tables', 'PRIMARY_KEY', ['key_guid'],                None, None, None),
            ('UQ_cdt_alias',           'UNIQUE',      ['pub_alias'],               None, None, None),
            ('UQ_cdt_schema_name',     'UNIQUE',      ['pub_schema', 'pub_name'],  None, None, None),
            ('FK_cdt_package',         'FOREIGN_KEY', ['ref_package_guid'], 'service_modules_manifest', ['key_guid'], None),
        ],
        'indexes': [],
    },
    {
        'name': 'contracts_db_columns',
        'columns': [
            ('key_guid',          'UUID',   False, None, None),
            ('ref_table_guid',    'UUID',   False, None, None),
            ('ref_type_guid',     'UUID',   False, None, None),
            PKG_COL,
            ('pub_name',          'STRING', False, None, 128),
            ('pub_ordinal',       'INT32',  False, None, None),
            ('pub_is_nullable',   'BOOL',   False, '0',  None),
            ('pub_default_value', 'STRING', True,  None, 512),
            ('pub_max_length',    'INT32',  True,  None, None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_columns', 'PRIMARY_KEY', ['key_guid'],                          None,                         None,         None),
            ('FK_cdc_table',            'FOREIGN_KEY', ['ref_table_guid'],                    'contracts_db_tables',        ['key_guid'], None),
            ('FK_cdc_type',             'FOREIGN_KEY', ['ref_type_guid'],                     'contracts_primitives_types', ['key_guid'], None),
            ('FK_cdc_package',          'FOREIGN_KEY', ['ref_package_guid'],                  'service_modules_manifest',   ['key_guid'], None),
            ('UQ_cdc_table_name',       'UNIQUE',      ['ref_table_guid', 'pub_name'],        None,                         None,         None),
            ('UQ_cdc_table_ordinal',    'UNIQUE',      ['ref_table_guid', 'pub_ordinal'],     None,                         None,         None),
        ],
        'indexes': [
            ('IX_cdc_table_guid', False, ['ref_table_guid']),
            ('IX_cdc_type_guid',  False, ['ref_type_guid']),
        ],
    },
    {
        'name': 'contracts_db_indexes',
        'columns': [
            ('key_guid',       'UUID',   False, None, None),
            ('ref_table_guid', 'UUID',   False, None, None),
            PKG_COL,
            ('pub_name',       'STRING', False, None, 256),
            ('pub_is_unique',  'BOOL',   False, '0',  None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_indexes', 'PRIMARY_KEY', ['key_guid'],                    None,                       None,         None),
            ('FK_cdi_table',            'FOREIGN_KEY', ['ref_table_guid'],              'contracts_db_tables',      ['key_guid'], None),
            ('FK_cdi_package',          'FOREIGN_KEY', ['ref_package_guid'],            'service_modules_manifest', ['key_guid'], None),
            ('UQ_cdi_table_name',       'UNIQUE',      ['ref_table_guid', 'pub_name'],  None,                       None,         None),
        ],
        'indexes': [
            ('IX_cdi_table_guid', False, ['ref_table_guid']),
        ],
    },
    {
        'name': 'contracts_db_index_columns',
        'columns': [
            ('key_guid',        'UUID',  False, None, None),
            ('ref_index_guid',  'UUID',  False, None, None),
            ('ref_column_guid', 'UUID',  False, None, None),
            PKG_COL,
            ('pub_ordinal',     'INT32', False, None, None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_index_columns', 'PRIMARY_KEY', ['key_guid'],                          None,                       None,         None),
            ('FK_cdic_index',                 'FOREIGN_KEY', ['ref_index_guid'],                    'contracts_db_indexes',     ['key_guid'], None),
            ('FK_cdic_column',                'FOREIGN_KEY', ['ref_column_guid'],                   'contracts_db_columns',     ['key_guid'], None),
            ('FK_cdic_package',               'FOREIGN_KEY', ['ref_package_guid'],                  'service_modules_manifest', ['key_guid'], None),
            ('UQ_cdic_index_column',          'UNIQUE',      ['ref_index_guid', 'ref_column_guid'], None,                       None,         None),
        ],
        'indexes': [
            ('IX_cdic_index_guid', False, ['ref_index_guid']),
        ],
    },
    {
        'name': 'contracts_db_constraints',
        'columns': [
            ('key_guid',                  'UUID',   False, None, None),
            ('ref_table_guid',            'UUID',   False, None, None),
            ('ref_kind_enum_guid',        'UUID',   False, None, None),
            ('ref_referenced_table_guid', 'UUID',   True,  None, None),
            PKG_COL,
            ('pub_name',                  'STRING', False, None, 256),
            ('pub_expression',            'TEXT',   True,  None, None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_constraints', 'PRIMARY_KEY', ['key_guid'],                    None,                         None,         None),
            ('FK_cdcn_table',               'FOREIGN_KEY', ['ref_table_guid'],              'contracts_db_tables',        ['key_guid'], None),
            ('FK_cdcn_kind',                'FOREIGN_KEY', ['ref_kind_enum_guid'],          'contracts_primitives_enums', ['key_guid'], None),
            ('FK_cdcn_ref_table',           'FOREIGN_KEY', ['ref_referenced_table_guid'],   'contracts_db_tables',        ['key_guid'], None),
            ('FK_cdcn_package',             'FOREIGN_KEY', ['ref_package_guid'],            'service_modules_manifest',   ['key_guid'], None),
            ('UQ_cdcn_table_name',          'UNIQUE',      ['ref_table_guid', 'pub_name'],  None,                         None,         None),
        ],
        'indexes': [
            ('IX_cdcn_table_guid', False, ['ref_table_guid']),
            ('IX_cdcn_kind',       False, ['ref_kind_enum_guid']),
        ],
    },
    {
        'name': 'contracts_db_constraint_columns',
        'columns': [
            ('key_guid',                   'UUID',  False, None, None),
            ('ref_constraint_guid',        'UUID',  False, None, None),
            ('ref_column_guid',            'UUID',  False, None, None),
            ('ref_referenced_column_guid', 'UUID',  True,  None, None),
            PKG_COL,
            ('pub_ordinal',                'INT32', False, None, None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_constraint_columns', 'PRIMARY_KEY', ['key_guid'],                                None,                       None,         None),
            ('FK_cdcc_constraint',                 'FOREIGN_KEY', ['ref_constraint_guid'],                     'contracts_db_constraints', ['key_guid'], None),
            ('FK_cdcc_column',                     'FOREIGN_KEY', ['ref_column_guid'],                         'contracts_db_columns',     ['key_guid'], None),
            ('FK_cdcc_ref_column',                 'FOREIGN_KEY', ['ref_referenced_column_guid'],              'contracts_db_columns',     ['key_guid'], None),
            ('FK_cdcc_package',                    'FOREIGN_KEY', ['ref_package_guid'],                        'service_modules_manifest', ['key_guid'], None),
            ('UQ_cdcc_constraint_column',          'UNIQUE',      ['ref_constraint_guid', 'ref_column_guid'],  None,                       None,         None),
            ('UQ_cdcc_constraint_ordinal',         'UNIQUE',      ['ref_constraint_guid', 'pub_ordinal'],      None,                       None,         None),
        ],
        'indexes': [
            ('IX_cdcc_constraint_guid', False, ['ref_constraint_guid']),
        ],
    },
    {
        'name': 'contracts_db_operations',
        'columns': [
            ('key_guid',           'UUID',   False, None, None),
            PKG_COL,
            ('pub_op',             'STRING', False, None, 128),
            ('pub_query_mssql',    'TEXT',   True,  None, None),
            ('pub_query_postgres', 'TEXT',   True,  None, None),
            ('pub_query_mysql',    'TEXT',   True,  None, None),
            ('pub_bootstrap',      'BOOL',   False, '0',  None),
            ('pub_notes',          'STRING', True,  None, 512),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_contracts_db_operations', 'PRIMARY_KEY', ['key_guid'], None, None, None),
            ('UQ_cdo_op',                  'UNIQUE',      ['pub_op'],   None, None, None),
            ('FK_cdo_package',             'FOREIGN_KEY', ['ref_package_guid'], 'service_modules_manifest', ['key_guid'], None),
        ],
        'indexes': [],
    },
    {
        'name': 'service_modules_manifest',
        # No ref_package_guid; this IS the package registry.
        'columns': [
            ('key_guid',          'UUID',        False, None,                   None),
            ('pub_name',          'STRING',      False, None,                   256),
            ('pub_version',       'STRING',      False, None,                   64),
            ('pub_last_version',  'STRING',      True,  None,                   64),
            ('pub_is_sealed',     'BOOL',        False, '0',                    None),
            ('priv_installed_on', 'DATETIME_TZ', False, 'SYSDATETIMEOFFSET()',  None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_service_modules_manifest', 'PRIMARY_KEY', ['key_guid'],  None, None, None),
            ('UQ_smm_name',                 'UNIQUE',      ['pub_name'],  None, None, None),
        ],
        'indexes': [],
    },
    {
        'name': 'service_system_configuration',
        'columns': [
            ('key_guid',  'UUID',   False, None, None),
            PKG_COL,
            ('pub_key',   'STRING', False, None, 256),
            ('pub_value', 'TEXT',   True,  None, None),
        ] + PRIV_AUDIT_COLS,
        'constraints': [
            ('PK_system_configuration', 'PRIMARY_KEY', ['key_guid'], None, None, None),
            ('UQ_sc_key',               'UNIQUE',      ['pub_key'],  None, None, None),
            ('FK_ssc_package',          'FOREIGN_KEY', ['ref_package_guid'], 'service_modules_manifest', ['key_guid'], None),
        ],
        'indexes': [],
    },
]


def main():
    rows = []

    table_guids = {}
    sorted_tables = sorted(KERNEL_TABLES, key=lambda t: t['name'])
    taken_aliases = set()
    for t in sorted_tables:
        natural = 'dbo.%s' % t['name']
        gid = g('contracts_db_tables', natural)
        alias = _generate_alias(t['name'], taken_aliases)
        taken_aliases.add(alias)
        table_guids[t['name']] = gid
        rows.append({
            'table': 'contracts_db_tables',
            'data': {
                'key_guid': gid,
                'pub_name': t['name'],
                'pub_schema': 'dbo',
                'pub_alias': alias,
            }
        })

    column_guids = {}
    for t in KERNEL_TABLES:
        for ordinal, (cname, ctype, nullable, default, max_length) in enumerate(t['columns'], start=1):
            natural = 'dbo.%s.%s' % (t['name'], cname)
            gid = g('contracts_db_columns', natural)
            column_guids[(t['name'], cname)] = gid
            rows.append({
                'table': 'contracts_db_columns',
                'data': {
                    'key_guid': gid,
                    'ref_table_guid': table_guids[t['name']],
                    'ref_type_guid': TYPE[ctype],
                    'pub_name': cname,
                    'pub_ordinal': ordinal,
                    'pub_is_nullable': 1 if nullable else 0,
                    'pub_default_value': default,
                    'pub_max_length': max_length,
                }
            })

    index_guids = {}
    for t in KERNEL_TABLES:
        for iname, unique, _cols in t['indexes']:
            natural = 'dbo.%s.%s' % (t['name'], iname)
            gid = g('contracts_db_indexes', natural)
            index_guids[(t['name'], iname)] = gid
            rows.append({
                'table': 'contracts_db_indexes',
                'data': {
                    'key_guid': gid,
                    'ref_table_guid': table_guids[t['name']],
                    'pub_name': iname,
                    'pub_is_unique': 1 if unique else 0,
                }
            })

    for t in KERNEL_TABLES:
        for iname, _unique, icols in t['indexes']:
            for ord_, cname in enumerate(icols, start=1):
                natural_idx = 'dbo.%s.%s' % (t['name'], iname)
                natural = '%s.%s' % (natural_idx, cname)
                gid = g('contracts_db_index_columns', natural)
                rows.append({
                    'table': 'contracts_db_index_columns',
                    'data': {
                        'key_guid': gid,
                        'ref_index_guid': index_guids[(t['name'], iname)],
                        'ref_column_guid': column_guids[(t['name'], cname)],
                        'pub_ordinal': ord_,
                    }
                })

    constraint_guids = {}
    for t in KERNEL_TABLES:
        for cname, kind, _cols, ref_table, _refcols, expr in t['constraints']:
            natural = 'dbo.%s.%s' % (t['name'], cname)
            gid = g('contracts_db_constraints', natural)
            constraint_guids[(t['name'], cname)] = gid
            rows.append({
                'table': 'contracts_db_constraints',
                'data': {
                    'key_guid': gid,
                    'ref_table_guid': table_guids[t['name']],
                    'ref_kind_enum_guid': CK[kind],
                    'ref_referenced_table_guid': table_guids[ref_table] if ref_table else None,
                    'pub_name': cname,
                    'pub_expression': expr,
                }
            })

    for t in KERNEL_TABLES:
        for cname, kind, cols, ref_table, refcols, _expr in t['constraints']:
            con_natural = 'dbo.%s.%s' % (t['name'], cname)
            for ord_, col in enumerate(cols, start=1):
                ref_col_guid = None
                if kind == 'FOREIGN_KEY':
                    ref_col_name = refcols[ord_ - 1]
                    ref_col_guid = column_guids[(ref_table, ref_col_name)]
                natural = '%s.%s' % (con_natural, col)
                gid = g('contracts_db_constraint_columns', natural)
                rows.append({
                    'table': 'contracts_db_constraint_columns',
                    'data': {
                        'key_guid': gid,
                        'ref_constraint_guid': constraint_guids[(t['name'], cname)],
                        'ref_column_guid': column_guids[(t['name'], col)],
                        'ref_referenced_column_guid': ref_col_guid,
                        'pub_ordinal': ord_,
                    }
                })

    package = {
        'package': 'kernel',
        'version': '1.0.0',
        'rows': rows,
    }
    print(json.dumps(package, indent=2))
    print('# row count: %d' % len(rows), file=sys.stderr)


if __name__ == '__main__':
    main()
