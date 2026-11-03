#!/usr/bin/env python3
"""Apply the ORA-multiple-SP-layout DDL + packages to an Oracle schema.

Prompts for the schema name (required — this is the schema objects land
in) and for connection details. The password is read with getpass: never
echoed, never logged, never stored, never taken from env or arguments.
Uses oracledb thin mode (no Oracle client needed):
    pip install oracledb

Apply order (dependency order — do not reorder):
  ddl/00_create_types.sql, ddl/01_create_reference_objects.sql,
  ddl/02_create_cs_tables.sql, ddl/03_create_aux_tables.sql,
  ddl/04_create_ttf_wrk_tables.sql, packages/pkg_common_spec.sql,
  packages/pkg_common_body.sql, then per workflow in run order
  (TRS_ONGOING, TRS_TOA, ECI, FSS, WIC, TTF, CRE): spec then body.

Statements are split on lines that are exactly "/". A chunk that fails
with ORA-00911 (trailing semicolon rejected) is retried once with the
trailing semicolon stripped. DDL auto-commits; a COMMIT is issued after
each file anyway (harmless).

Prerequisites (warned, not failed — they may live in another schema via
synonyms; package bodies compile INVALID if a referenced table is missing
and must be recompiled once staging exists):
- `CRE_SRC_MRG`
- `C_B_PTY_HMRG`
- `C_B_PTY_RLE_REL_XREF`
- `C_B_PTY_XREF`
- `STG_CRE_D_CARE_CASE_MAINT`
- `STG_CRE_D_CARE_CLIENTS`
- `STG_CRE_SN_CARE_CLIENTS`
- `STG_ECI_D_CHILD`
- `STG_ECI_D_FAMILY`
- `STG_ECI_D_FAMILY_ADDRESS`
- `STG_ECI_D_FAMILY_PHONE`
- `STG_ECI_D_MEDICAID`
- `STG_ECI_H_FAMILY_ADDRESS`
- `STG_ECI_H_FAMILY_PHONE`
- `STG_ECI_H_MEDICAID`
- `STG_ECI_PTY_INACTIVE_LOG`
- `STG_ECI_PTY_INACTIVE_STS`
- `STG_ECI_SN_CASE`
- `STG_ECI_SN_CHILD`
- `STG_FSS_PTY_INACTIVE_LOG`
- `STG_FSS_PTY_INACTIVE_STS`
- `STG_TRS_CD_REF`
- `STG_TRS_CV_ED_MCI_EDG_INDV`
- `STG_TRS_DC_CASES`
- `STG_TRS_DC_CASE_INDV`
- `STG_TRS_DC_PRIMARY_PAYEE`
- `STG_TRS_DEACTIVATED_RELATIONSHIPS`
- `STG_TRS_DEACTIVED_MEMBERS`
- `STG_TRS_D_CV_DC_MCI_ALIAS`
- `STG_TRS_D_CV_DC_MCI_INDV`
- `STG_TRS_D_CV_ED_MCI_EDG_INDV`
- `STG_TRS_D_DC_ALIAS`
- `STG_TRS_D_DC_CASES`
- `STG_TRS_D_DC_INDV`
- `STG_TRS_D_DC_PRIMARY_PAYEE`
- `STG_TRS_D_DC_RELATIONSHIPS_A`
- `STG_TRS_D_INDV_ADDR`
- `STG_TRS_D_LU_TOA`
- `STG_TRS_D_UNQ_ADDR`
- `STG_TRS_VALID_MEMBERS`
- `STG_TTF_PTY_INACTIVE_LOG`
- `STG_TTF_PTY_INACTIVE_STS`
- `STG_WIC_PTY_INACTIVE_LOG`
- `STG_WIC_PTY_INACTIVE_STS`
- `V_ECI_ETL_LU_DUP_CASES`
- `V_ECI_ETL_LU_FAMILY_VALIDATION`
- `V_ECI_ETL_LU_REACTIVATED_ID`
- `V_ECI_ETL_SRC_FAMILY_ADDRESS`
- `V_ECI_ETL_SRC_FAMILY_PHONE`
- `V_FSS_ETL_SRC`
- `V_FSS_ETL_SRC_RELATIONS`
- `V_TTF_ETL_SRC`
- `V_WIC_ETL_SRC`
Plus a schema/user literally named RDM (checked unless --skip-rdm-check).
"""
import argparse
import getpass
import os
import re
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ORDER = [
    ('ddl/00_create_types.sql', 'schema-level OBJECT/nested-table types'),
    ('ddl/01_create_reference_objects.sql', '7 reference placeholders'),
    ('ddl/02_create_cs_tables.sql', 'C_S_* landing tables'),
    ('ddl/03_create_aux_tables.sql', 'EXC + DQM tables'),
    ('ddl/04_create_ttf_wrk_tables.sql', 'TTF snapshot tables'),
    ('packages/pkg_common_spec.sql', 'PKG_COMMON spec'),
    ('packages/pkg_common_body.sql', 'PKG_COMMON body'),
    ('packages/pkg_trs_ongoing_spec.sql', 'PKG_TRS_ONGOING spec'),
    ('packages/pkg_trs_ongoing_body.sql', 'PKG_TRS_ONGOING body'),
    ('packages/pkg_trs_toa_spec.sql', 'PKG_TRS_TOA spec'),
    ('packages/pkg_trs_toa_body.sql', 'PKG_TRS_TOA body'),
    ('packages/pkg_eci_spec.sql', 'PKG_ECI spec'),
    ('packages/pkg_eci_body.sql', 'PKG_ECI body'),
    ('packages/pkg_fss_spec.sql', 'PKG_FSS spec'),
    ('packages/pkg_fss_body.sql', 'PKG_FSS body'),
    ('packages/pkg_wic_spec.sql', 'PKG_WIC spec'),
    ('packages/pkg_wic_body.sql', 'PKG_WIC body'),
    ('packages/pkg_ttf_spec.sql', 'PKG_TTF spec'),
    ('packages/pkg_ttf_body.sql', 'PKG_TTF body'),
    ('packages/pkg_cre_spec.sql', 'PKG_CRE spec'),
    ('packages/pkg_cre_body.sql', 'PKG_CRE body'),
]
PREREQ_TABLES = ['CRE_SRC_MRG', 'C_B_PTY_HMRG', 'C_B_PTY_RLE_REL_XREF', 'C_B_PTY_XREF', 'STG_CRE_D_CARE_CASE_MAINT', 'STG_CRE_D_CARE_CLIENTS', 'STG_CRE_SN_CARE_CLIENTS', 'STG_ECI_D_CHILD', 'STG_ECI_D_FAMILY', 'STG_ECI_D_FAMILY_ADDRESS', 'STG_ECI_D_FAMILY_PHONE', 'STG_ECI_D_MEDICAID', 'STG_ECI_H_FAMILY_ADDRESS', 'STG_ECI_H_FAMILY_PHONE', 'STG_ECI_H_MEDICAID', 'STG_ECI_PTY_INACTIVE_LOG', 'STG_ECI_PTY_INACTIVE_STS', 'STG_ECI_SN_CASE', 'STG_ECI_SN_CHILD', 'STG_FSS_PTY_INACTIVE_LOG', 'STG_FSS_PTY_INACTIVE_STS', 'STG_TRS_CD_REF', 'STG_TRS_CV_ED_MCI_EDG_INDV', 'STG_TRS_DC_CASES', 'STG_TRS_DC_CASE_INDV', 'STG_TRS_DC_PRIMARY_PAYEE', 'STG_TRS_DEACTIVATED_RELATIONSHIPS', 'STG_TRS_DEACTIVED_MEMBERS', 'STG_TRS_D_CV_DC_MCI_ALIAS', 'STG_TRS_D_CV_DC_MCI_INDV', 'STG_TRS_D_CV_ED_MCI_EDG_INDV', 'STG_TRS_D_DC_ALIAS', 'STG_TRS_D_DC_CASES', 'STG_TRS_D_DC_INDV', 'STG_TRS_D_DC_PRIMARY_PAYEE', 'STG_TRS_D_DC_RELATIONSHIPS_A', 'STG_TRS_D_INDV_ADDR', 'STG_TRS_D_LU_TOA', 'STG_TRS_D_UNQ_ADDR', 'STG_TRS_VALID_MEMBERS', 'STG_TTF_PTY_INACTIVE_LOG', 'STG_TTF_PTY_INACTIVE_STS', 'STG_WIC_PTY_INACTIVE_LOG', 'STG_WIC_PTY_INACTIVE_STS', 'V_ECI_ETL_LU_DUP_CASES', 'V_ECI_ETL_LU_FAMILY_VALIDATION', 'V_ECI_ETL_LU_REACTIVATED_ID', 'V_ECI_ETL_SRC_FAMILY_ADDRESS', 'V_ECI_ETL_SRC_FAMILY_PHONE', 'V_FSS_ETL_SRC', 'V_FSS_ETL_SRC_RELATIONS', 'V_TTF_ETL_SRC', 'V_WIC_ETL_SRC']
IDENT_RE = re.compile(r'^[A-Za-z][A-Za-z0-9_$#]*$')


def ask(text, default=''):
    v = input('%s%s: ' % (text, ' [%s]' % default if default else '')).strip()
    return v or default


def split_statements(text):
    chunks, cur = [], []
    for line in text.splitlines():
        if line.strip() == '/':
            chunks.append('\n'.join(cur))
            cur = []
        else:
            cur.append(line)
    if cur:
        chunks.append('\n'.join(cur))
    out = []
    for c in chunks:
        body = '\n'.join(l for l in c.splitlines()
                          if not l.strip().startswith('--'))
        if body.strip():
            out.append(c)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dry-run', action='store_true',
                    help='print apply order, do nothing')
    ap.add_argument('--skip-rdm-check', action='store_true',
                    help='skip the RDM-schema existence check')
    ap.add_argument('--continue-on-error', action='store_true',
                    help='keep going after a failed file (default: stop)')
    args = ap.parse_args()
    if args.dry_run:
        print('Dry run — would apply in this order (schema is prompted '
              'only for a real run):')
        for f, desc in ORDER:
            print('  %s  (%s)' % (f, desc))
        return 0
    schema = ask('Schema name (objects will be created here, required)')
    if not schema or not IDENT_RE.match(schema):
        print('A valid Oracle schema name is required (letter followed by '
              'letters/digits/_/$/#).')
        return 2
    host = ask('DB host', os.environ.get('ORACLE_HOST', ''))
    port = ask('DB port', os.environ.get('ORACLE_PORT', '1521'))
    service = ask('Service name', os.environ.get('ORACLE_SERVICE', ''))
    user = ask('DB username', os.environ.get('ORACLE_USER', ''))
    password = getpass.getpass('DB password (never stored or logged): ')
    if not all([host, port, service, user, password]):
        print('Host, port, service, username and password are all required.')
        return 2
    try:
        import oracledb
    except ImportError:
        print('oracledb is not installed. Run: pip install oracledb')
        return 1
    print('Prerequisite warning: the following tables/views must already '
          'exist (or be reachable via synonyms) or package bodies will '
          'compile INVALID and need recompiling once staging exists:')
    for t in PREREQ_TABLES:
        print('  ' + t)
    print('Plus a schema/user literally named RDM (for RDM.REF_PHN_AREA_CD).')
    conn = oracledb.connect(user=user, password=password,
                            dsn=oracledb.makedsn(host, int(port),
                                                 service_name=service))
    cur = conn.cursor()
    if not args.skip_rdm_check:
        n = cur.execute("SELECT COUNT(*) FROM ALL_USERS WHERE USERNAME = 'RDM'").fetchone()[0]
        if n == 0:
            print('ABORT: schema/user RDM does not exist. Have the DBA create '
                  'it first, or re-run with --skip-rdm-check (the '
                  'RDM.REF_PHN_AREA_CD create will then fail).')
            return 3
    cur.execute('ALTER SESSION SET CURRENT_SCHEMA = %s' % schema)
    for fname, desc in ORDER:
        path = os.path.join(BASE, fname)
        try:
            text = open(path).read()
        except OSError as e:
            print('FAILED %s (%s): cannot read file: %s' % (fname, desc, e))
            if not args.continue_on_error:
                return 4
            continue
        stmts = split_statements(text)
        failed = None
        for st in stmts:
            try:
                cur.execute(st)
            except Exception as e:
                code = getattr(e, 'args', [None])
                err = str(e)
                if 'ORA-00911' in err and st.rstrip().endswith(';'):
                    try:
                        cur.execute(st.rstrip().rstrip(';'))
                        continue
                    except Exception as e2:
                        err = str(e2)
                failed = (st.splitlines()[0][:120] if st.splitlines() else '', err)
                break
        if failed:
            print('FAILED %s (%s) at chunk starting: %s\n  error: %s'
                  % (fname, desc, failed[0], failed[1]))
            if not args.continue_on_error:
                print('Stopped on first error. Fix and re-run; files already '
                      'applied stay applied (DDL auto-commits).')
                return 5
        else:
            conn.commit()
            print('OK %s (%s): %d statements' % (fname, desc, len(stmts)))
    print('Done. All files applied to schema %s.' % schema)
    return 0


if __name__ == '__main__':
    sys.exit(main())
