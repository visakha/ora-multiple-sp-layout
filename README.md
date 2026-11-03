# ORA-multiple-SP-layout

Discrete-procedure Oracle layout of the v1 Snowflake drop-in ETL: the same
logic as `ora-single-sp-layout` (one bulky procedure per mapping),
repackaged so **each stored procedure does one thing and one thing only**.
The purpose is IICS mapping construction: chain the procedures in the
order given by `docs/ORA_MULTIPLE_SP_CHAIN.md` — that document is the build
order and is meant to be followed as-is.

## Contrast with ora-single-sp-layout

| | single-SP layout | multiple-SP layout (this repo) |
|---|---|---|
| Unit | 1 bulky function per mapping (40 mains) | 137 discrete functions: 1 materializer + 1 writer per target per mapping |
| Chain | call the mapping function | call the rows of the chain doc in (seq1, seq2) order |
| Logic | — | identical by construction: split, not re-translated |
| Packages | standalone functions | 8 packages (see below) |
| DDL | reference placeholders only | + C_S_* tables, aux tables, TTF WRK tables, drop-only file, installer |

## Layout

- `packages/` — 8 packages, spec + body each:
  `PKG_COMMON` (45 shared lookup helpers), `PKG_TRS_ONGOING` (34 discrete
  procs + 2 TRS helper01 table functions, which are called by the Alt_Id
  and Phn builds and are NOT chain steps), `PKG_TRS_TOA` (1),
  `PKG_ECI` (25), `PKG_FSS` (20), `PKG_WIC` (17), `PKG_TTF` (12),
  `PKG_CRE` (26). Total 182 routines.
- `ddl/` — install DDL, in apply order:
  `00_create_types.sql` (schema-level OBJECT / nested-table types —
  Oracle does not allow OBJECT types inside a package spec, so these stay
  at schema level with their original names; the packaged functions return
  them unchanged),
  `01_create_reference_objects.sql` (7 EMPTY placeholder tables),
  `02_create_cs_tables.sql` (C_S_* landing tables, v1-faithful shape:
  v3 flag + DIAG columns omitted, union superset otherwise, all columns
  nullable, no constraints),
  `03_create_aux_tables.sql` (EXC_STG_BAD_REC_MEMB, DQM_ADDRESS),
  `04_create_ttf_wrk_tables.sql` (TTF snapshot tables — required because
  TTF stages DELETE + INSERT pre-existing tables instead of creating
  them; all other workflows' WRK tables are created at run time by their
  materializers and need no DDL),
  `drop_all.sql` (DROPs ONLY — teardown/reinstall, never run against a
  schema holding data you want).
- `chains/` — one chain script per workflow; calls the packaged procedures
  in chain-doc order with `WHENEVER SQLERROR EXIT FAILURE` (CRE ends with
  a single COMMIT).
- `docs/ORA_MULTIPLE_SP_CHAIN.md` — the chain document (seq1, seq2,
  spName, work table created/consumed, handoff mechanism, notes).
- `docs/split-notes/` — per-workflow split notes (TRS/ECI copied from the
  workers; FSS/WIC/TTF/CRE rebuilt at assembly — see their headers).
- `apply_ddl.py` — installer: prompts for the schema name (and connection
  details), sets it as the session's current schema, applies everything in
  dependency order, reports per file, stops on first error by default.

## The DDL-vs-DROP rule (strict, per the brief)

- No file that contains a CREATE statement contains a top-level DROP
  statement. All DROPs live in `ddl/drop_all.sql` only.
- The exception that is NOT an exception: discrete procedures rebuild
  their own scratch WRK tables at run time (DROP-if-exists + CTAS, or
  DELETE + INSERT for TTF). That DROP happens inside a procedure body when
  the chain runs — it is not install-time DDL, it touches only scratch
  tables that the same chain rebuilds, and it never touches target data.
  The README states this explicitly so the rule is not misread.

## Install

```
python3 apply_ddl.py            # prompts for schema + connection
python3 apply_ddl.py --dry-run  # print apply order, do nothing
```

Prerequisites (must already exist; the installer warns but does not fail
on these — they may live in another schema via synonyms; note that package
bodies will compile INVALID if a referenced table is missing and must be
recompiled with `ALTER PACKAGE <pkg> COMPILE BODY` once staging exists):

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

Plus: a schema/user literally named `RDM` (for `RDM.REF_PHN_AREA_CD`; the
installer checks and aborts if it is missing, unless `--skip-rdm-check`).

## Packaged-name rule

Chain steps are always called as `PKG_<WORKFLOW>.<proc>` (see the chain
doc). Inside a package body, shared helpers are called as
`PKG_COMMON.<helper>`; TRS helper01 functions are called unqualified
inside `PKG_TRS_ONGOING` (same package). The single-SP standalone names no
longer exist once this layout is installed — do not mix the two layouts
in one schema.

## Verification status (static only)

- Every discrete proc from the six splits appears in exactly one package
  body, declared in its spec with a matching signature (182 routines).
- Chain scripts call every fragment row exactly once, in order; chain-doc
  spNames match package spec entries (135 rows, 7 workflows).
- C_S_* column coverage: every column written by any discrete proc into a
  C_S_* table exists in `02_create_cs_tables.sql`.
- Mask-aware scans: no Snowflake constructs in emitted code; parenthesis
  balance clean; no top-level DROP outside `drop_all.sql`; no SQL*Plus
  commands in DDL files; no secrets anywhere.
- NOT verified (needs a live Oracle DB): compilation, execution, row-count
  parity vs the v1 mirror or IDQ. See the chain doc's "Known live-compile /
  live-run items" section, including the per-source boolean status (ECI
  fixed in this split only; WIC has 2 known live-compile failures carried
  over unfixed; TTF has 2 CASE-wrapped normalizations).
