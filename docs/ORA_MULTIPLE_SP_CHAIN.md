# ORA-multiple-SP-layout — IICS chain document

This is the build order for the discrete-procedure layout. Follow it as-is:
one IICS mapping task or stored-procedure step per table row, in
`(seq1, seq2)` order, within each workflow. Do not reorder rows inside a
workflow, and do not run a row until the previous row has succeeded (the
chain scripts enforce this with `WHENEVER SQLERROR EXIT FAILURE`).

## How to read a row

- `seq1` = order of mappings within the workflow, 1-based, in original
  run-script order. It restarts at 1 for each workflow.
- `seq2` = discrete-procedure order within its mapping, 1-based. The first
  procedure of a mapping is its materializer (see below); the rest are writers.
- `spName` = the packaged procedure to call, always `PKG_<WORKFLOW>.<proc>`.
  The packages are: `PKG_TRS_ONGOING`, `PKG_TRS_TOA`, `PKG_ECI`, `PKG_FSS`,
  `PKG_WIC`, `PKG_TTF`, `PKG_CRE`, plus `PKG_COMMON` for the shared helpers
  (helpers are never chain steps — procedures call them internally).
- `work table created` = the single table this procedure writes. Landing
  `C_S_*` tables are listed here, not hidden: a writer's created table IS its
  target.
- `work table consumed` = every table this procedure reads that an earlier
  chain step wrote (plain), plus reads of prior-run state marked
  `(prior run)`. Pure staging inputs (`STG_*_D_*` delta tables, `_H_`
  history tables, hub tables) and pre-write target-state self-checks
  (`uq_*` / `NOT EXISTS` against the procedure's own target) are NOT listed
  here — they are inputs to the workflow, not handoffs between steps.
  A `(prior run)` entry means the table must already hold rows from a
  previous run; this chain does not create it before this row runs.
- `handoff mechanism` = what the NEXT row gets from this row (output-side):
  `TABLE:<table>` = a later row reads the table this row wrote;
  `CONTROL:success-only` = no later row reads this row's output — the next
  row only requires this row to have succeeded;
  `NONE` = last row of the workflow, nothing follows.
  `PARAM:<param>` is part of the vocabulary for chains where one procedure's
  output feeds the next procedure's argument. No row in this release uses it:
  every procedure takes its parameters from the chain script's defaults,
  never from a predecessor procedure. (The per-workflow notes below list the
  parameters that matter.)
- `notes` = what the procedure does, its branch predicate where the worker
  recorded it, and any quirk that survives into this layout.

## Materializers

Every multi-target mapping starts with a materializer: one procedure that
runs the mapping's shared driving query ONCE and lands it in a `WRK_*`
snapshot table. Writers then read only that table and never re-evaluate the
source — this preserves the original statement-level snapshot semantics
(source anti-joins against the mapping's own targets must see pre-insert
state). Materializer step names vary by source (`*_build`, `*_prep`,
`*_src`, `*_routed` / `*_scored`, `*_stage`) but the role is identical.
Single-INSERT mappings have no materializer: the one procedure IS the
original statement, renamed.

## Commit and recovery (all workflows)

- TRS, ECI, FSS, WIC, TTF: each discrete procedure COMMITs its own work.
  A failed procedure stops the chain but does NOT roll back earlier writers.
- CRE: target writes stay uncommitted until the chain script's single COMMIT
  at the end. Stage DROP + CTAS commits only the scratch WRK tables (Oracle
  DDL implicit commit), never target data.
- Recovery rule (all workflows): resume a failed mapping from its
  materializer procedure, never by re-running a single writer. `uq_*` flags
  were computed at materialization time against pre-write targets.
- NEVER re-execute a succeeded DQM step: `DQM_ADDRESS` appends on every run
  (the same no-fix stance as the v1 DQM-RERUN decision).
- Re-runs duplicate unguarded EXC / LOG rows exactly as the originals would
  (no NOT EXISTS guard existed there either). `uq_*`-guarded writers skip
  already-written rows on re-run.
- WRK tables persist after a run and are rebuilt by the next run's
  materializer. They are scratch, never target data.

## Prior-run reads (why some rows read tables nobody wrote yet)

- TRS Ongoing `seq1=1` build reads prior-run `STG_TRS_VALID_MEMBERS` and
  `STG_TRS_DEACTIVED_MEMBERS`: the original run script also runs Pty_OnGoing
  before Pty_Deactivation_1. Preserved, not reordered.
- Each workflow's Validation materializer reads the pre-run inactive-status
  snapshot (`STG_*_PTY_INACTIVE_STS`); later mappings read the state that
  Validation wrote in this chain.
- ECI reactivation loads self-filter against their own delta tables
  (`NOT EXISTS` / `LEFT JOIN` on prior-run rows): address not already in the
  delta table is what gets inserted.
- TRS Addr_1 self-filters `STG_TRS_D_UNQ_ADDR` against prior-run rows.

## Install before chaining

Install order (or run `apply_ddl.py`, which prompts for the schema and
applies in this order): `ddl/00_create_types.sql` (schema-level OBJECT /
nested-table types — Oracle forbids OBJECT types inside a package spec),
`ddl/01_create_reference_objects.sql` (EMPTY placeholders — replace with
real definitions before any real run; DBA must create schema `RDM` first),
`ddl/02_create_cs_tables.sql`, `ddl/03_create_aux_tables.sql`,
`ddl/04_create_ttf_wrk_tables.sql`, then `packages/pkg_common_spec.sql` +
`pkg_common_body.sql`, then each workflow's spec + body. The chain scripts
in `chains/` call the packaged procedures in row order.


## TRS Ongoing

Chain script: `chains/run_wf_TRS_Stage_Load_1_Ongoing.sql` (34 calls, original run-script order). Package: `PKG_TRS_ONGOING`. The two `fn_snow_helper01_*` functions are in the same package; they are called by the Alt_Id and Phn build procedures and are NOT chain steps.

Parameters: build procedures take the original mapping parameters; the chain script calls everything with `()` and relies on the original defaults. The one parameter handoff to know about: the first build (`seq1=1`) reads prior-run `STG_TRS_VALID_MEMBERS` and `STG_TRS_DEACTIVED_MEMBERS` — the original run script also runs Pty_OnGoing before Pty_Deactivation_1, so this ordering quirk is preserved, not reordered.

Commit: each discrete procedure COMMITs its own work (as the original mains did). A failed procedure stops the chain (`WHENEVER SQLERROR EXIT FAILURE`) but does NOT roll back earlier writers.

Recovery: resume a failed mapping from its `*_build` procedure, never by re-running a single writer. `uq_*` flags were computed at build time against pre-write targets, so writer re-runs skip already-written rows; EXC rows would duplicate on re-run exactly as in v1 (no NOT EXISTS guard).

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_build | WRK_TRS_PTYONGOING_BOTH | STG_TRS_DEACTIVED_MEMBERS (prior run), STG_TRS_VALID_MEMBERS (prior run) | TABLE:WRK_TRS_PTYONGOING_BOTH | Build step: materializes the driving query into WRK_TRS_PTYONGOING_BOTH. |
| 1 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty | C_S_TRS_PTY | WRK_TRS_PTYONGOING_BOTH | CONTROL:success-only | Writes C_S_TRS_PTY (branch WHEN row_kind = 'DEDUP' AND rn_pty = 1 AND (uq_pty = 1)). |
| 1 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle | C_S_TRS_PTY_RLE | WRK_TRS_PTYONGOING_BOTH | CONTROL:success-only | Writes C_S_TRS_PTY_RLE (branch WHEN row_kind = 'DEDUP' AND rn_pty = 1 AND (uq_rle = 1)). |
| 1 | 4 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members | STG_TRS_VALID_MEMBERS | WRK_TRS_PTYONGOING_BOTH | TABLE:STG_TRS_VALID_MEMBERS | Writes STG_TRS_VALID_MEMBERS (branch WHEN row_kind = 'DEDUP' AND rn_pty = 1 AND NOT (is_valid_member = 1)). |
| 1 | 5 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_PTYONGOING_BOTH | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB: UNION ALL of 6 EXC branches over superset columns. |
| 2 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived | STG_TRS_DEACTIVED_MEMBERS | STG_TRS_VALID_MEMBERS | CONTROL:success-only | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1. |
| 3 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_build | WRK_TRS_TOA_KEYED | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_TOA_KEYED | Build step: materializes the driving query into WRK_TRS_TOA_KEYED. |
| 3 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa | C_S_TRS_PTY_RLE_TOA | WRK_TRS_TOA_KEYED | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_TOA (branch WHEN NOT (grp_bad_value = 1) AND NOT (grp_dates = 1) AND (uq_toa = 1)). |
| 3 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_TOA_KEYED | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB: UNION ALL of 2 EXC branches over superset columns. |
| 4 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_build | WRK_TRS_REL1_BOTH | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_REL1_BOTH | Build step: materializes the driving query into WRK_TRS_REL1_BOTH. |
| 4 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel | C_S_TRS_PTY_RLE_REL | WRK_TRS_REL1_BOTH | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_REL (branch WHEN row_kind = 'TIMELINE' AND (uq_rel = 1)). |
| 4 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_REL1_BOTH | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB: UNION ALL of 4 EXC branches over superset columns. |
| 5 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated | STG_TRS_DEACTIVATED_RELATIONSHIPS | STG_TRS_VALID_MEMBERS | CONTROL:success-only | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1. |
| 6 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_build | WRK_TRS_REL2_BOTH | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_REL2_BOTH | Build step: materializes the driving query into WRK_TRS_REL2_BOTH. |
| 6 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov | C_S_TRS_PTY_RLE_REL_PROV | WRK_TRS_REL2_BOTH | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_REL_PROV (branch WHEN row_kind = 'TIMELINE' AND (uq_rel = 1)). |
| 6 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_REL2_BOTH | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB: UNION ALL of 2 EXC branches over superset columns. |
| 7 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_build | WRK_TRS_PHN_ALL | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_PHN_ALL | Build step: materializes the driving query into WRK_TRS_PHN_ALL. |
| 7 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn | C_S_TRS_PTY_RLE_PHN | WRK_TRS_PHN_ALL | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_PHN (branch WHEN row_kind = 'PHN' AND rn = 1 AND (uq_tgt = 1)). |
| 7 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr | C_S_TRS_PTY_RLE_EADDR | WRK_TRS_PHN_ALL | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_EADDR (branch WHEN row_kind = 'EADDR' AND rn = 1 AND (uq_tgt = 1)). |
| 7 | 4 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_PHN_ALL | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB: UNION ALL of 2 EXC branches over superset columns. |
| 8 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr | C_S_TRS_PTY_MNG_ATTR | STG_TRS_VALID_MEMBERS | CONTROL:success-only | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw. |
| 9 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr | C_S_TRS_PTY_MNG_ATTR | STG_TRS_VALID_MEMBERS | CONTROL:success-only | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing. |
| 10 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm | C_S_TRS_PTY_NM | STG_TRS_VALID_MEMBERS | CONTROL:success-only | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm. |
| 11 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_build | WRK_TRS_ALTID_ROUTED | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_ALTID_ROUTED | Build step: materializes the driving query into WRK_TRS_ALTID_ROUTED. |
| 11 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id | C_S_TRS_PTY_RLE_ALT_ID | WRK_TRS_ALTID_ROUTED | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_ALT_ID (branch WHEN (is_valid = 1) AND (uq_alt_id = 1)). |
| 11 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_ALTID_ROUTED | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB (branch WHEN NOT (is_valid = 1) AND (uq_exc = 1)). |
| 12 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_build | WRK_TRS_PLN_PLANNED | STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_PLN_PLANNED | Build step: materializes the driving query into WRK_TRS_PLN_PLANNED. |
| 12 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln | C_S_TRS_PTY_RLE_PLN | WRK_TRS_PLN_PLANNED | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_PLN (branch WHEN pln_mstr_cd IS NOT NULL AND rn_key = 1 AND (uq_pln = 1)). |
| 12 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_PLN_PLANNED | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB (branch WHEN pln_mstr_cd IS NULL AND rn_invalid = 1). |
| 13 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr | STG_TRS_D_UNQ_ADDR | STG_TRS_D_UNQ_ADDR (prior run) | TABLE:STG_TRS_D_UNQ_ADDR | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Addr_1. |
| 14 | 1 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_build | WRK_TRS_ADDR2_SCORED | STG_TRS_D_UNQ_ADDR, STG_TRS_VALID_MEMBERS | TABLE:WRK_TRS_ADDR2_SCORED | Build step: materializes the driving query into WRK_TRS_ADDR2_SCORED. |
| 14 | 2 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm | DQM_ADDRESS | WRK_TRS_ADDR2_SCORED | CONTROL:success-only | Writes DQM_ADDRESS (branch WHEN 1). |
| 14 | 3 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr | C_S_TRS_PTY_RLE_ADDR | WRK_TRS_ADDR2_SCORED | CONTROL:success-only | Writes C_S_TRS_PTY_RLE_ADDR (branch WHEN score = '100' AND (uq_addr = 1)). |
| 14 | 4 | PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc | EXC_STG_BAD_REC_MEMB | WRK_TRS_ADDR2_SCORED | NONE | Writes EXC_STG_BAD_REC_MEMB (branch WHEN score = '40' AND (uq_addr_exc = 1)). |

## TRS TOA

Chain script: `chains/run_wf_TRS_Stage_Load_TOA.sql` (1 call). Package: `PKG_TRS_TOA`. Single-INSERT mapping, statement verbatim; writes `C_S_LU_TOA` with literal VERSION_SEQ = 1, as in v1.

Commit: the single procedure COMMITs its own work.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_TRS_TOA.sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa | C_S_LU_TOA | — | NONE | Single-INSERT mapping; statement verbatim from sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA. |

## ECI

Chain script: `chains/run_wf_ECI_Stage_Load.sql` (25 calls). Package: `PKG_ECI`. Materializer step names: `*_prep` (the first step of a mapping; it materializes the shared CTE output into a WRK table with an explicit column list and a static INSERT — no dynamic-SQL binds).

Parameters: only preps take the original mapping parameters; writers take none. Medicaid reactivation writes nothing unless `P_TEST_LOOKUP_RESULT = 'Y'` (an IDQ defect preserved from v1, not fixed here).

Commit: each discrete procedure COMMITs its own work. A failed procedure stops the chain but does NOT roll back earlier writers.

Recovery: resume a failed mapping from its `*_prep` procedure, never by re-running a single writer. DQM_ADDRESS appends on re-run (same no-fix stance as the v1 DQM-RERUN decision); never re-execute a succeeded `_dqm` step. Re-running a failed mapping is safe for `uq_*`-guarded writers (prep re-computes anti-joins against pre-run targets).

ECI boolean note: this split applies 17 boolean-translation fixes that the single-SP mirror does NOT have (see Known live-compile items). The most serious: Validation `fam_inactive_yn` — the mirror glues `ANDCASE` and wraps a 'N'/'Y' CASE in a 1/0 CASE while downstream code compares `= 'N'` / `= 'Y'`; the split uses the Snowflake original's 'N'/'Y' CASE. Backporting these fixes to ora-single-sp-layout is a separate decision; the two trees differ here until then.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep | WRK_ECI_VALIDATION_ROUTED | STG_ECI_PTY_INACTIVE_STS (prior run) | TABLE:WRK_ECI_VALIDATION_ROUTED | Builds the routed dataset; writers below read only this table. Reads the pre-run INACTIVE_STS snapshot (previous run), not this chain. |
| 1 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_VALIDATION_ROUTED | CONTROL:success-only | Writes Invalid_Party_Name rows to the exception queue. |
| 1 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_log | STG_ECI_PTY_INACTIVE_LOG | WRK_ECI_VALIDATION_ROUTED | CONTROL:success-only | Writes Deactivation and Reactivation rows to the inactive log. |
| 1 | 4 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_sts | STG_ECI_PTY_INACTIVE_STS | WRK_ECI_VALIDATION_ROUTED | TABLE:STG_ECI_PTY_INACTIVE_STS | Live inactive list; every later mapping filters on it. |
| 2 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_prep | WRK_ECI_PTY_ROUTED | STG_ECI_PTY_INACTIVE_STS | TABLE:WRK_ECI_PTY_ROUTED | Builds the routed dataset; writers below read only this table. Reads INACTIVE_STS written by Validation _inactive_sts earlier in this chain. |
| 2 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_pty | C_S_ECI_PTY | WRK_ECI_PTY_ROUTED | CONTROL:success-only | Writes valid parties to C_S_ECI_PTY. |
| 2 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_pty_rle | C_S_ECI_PTY_RLE | WRK_ECI_PTY_ROUTED | CONTROL:success-only | Writes party roles to C_S_ECI_PTY_RLE. |
| 2 | 4 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_ROUTED | CONTROL:success-only | Writes gender, birth-date, ethnicity, race and language exception rows to the exception queue. |
| 3 | 1 | PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr_load | STG_ECI_D_FAMILY_ADDRESS | STG_ECI_D_FAMILY_ADDRESS (prior run) | CONTROL:success-only | Reactivation delta; read by the downstream mapping(s) in this workflow. |
| 4 | 1 | PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn_load | STG_ECI_D_FAMILY_PHONE | STG_ECI_D_FAMILY_PHONE (prior run) | CONTROL:success-only | Reactivation delta; read by the downstream mapping(s) in this workflow. |
| 5 | 1 | PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid_load | STG_ECI_D_MEDICAID | STG_ECI_D_MEDICAID (prior run) | TABLE:STG_ECI_D_MEDICAID | Reactivation delta; read by the downstream mapping(s) in this workflow. |
| 6 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_prep | WRK_ECI_ALT_ID_ROUTED | STG_ECI_D_MEDICAID, STG_ECI_PTY_INACTIVE_STS | TABLE:WRK_ECI_ALT_ID_ROUTED | Builds the routed dataset; writers below read only this table. Reads INACTIVE_STS written by Validation _inactive_sts earlier in this chain. |
| 6 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_alt_id | C_S_ECI_PTY_RLE_ALT_ID | WRK_ECI_ALT_ID_ROUTED | CONTROL:success-only | Writes valid alternate ids to C_S_ECI_PTY_RLE_ALT_ID. |
| 6 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_ALT_ID_ROUTED | CONTROL:success-only | Writes invalid-SSN and invalid-Medicaid-id rows to the exception queue. |
| 7 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_prep | WRK_ECI_PHN_ROUTED | STG_ECI_PTY_INACTIVE_STS | TABLE:WRK_ECI_PHN_ROUTED | Builds the routed dataset; writers below read only this table. Reads INACTIVE_STS written by Validation _inactive_sts earlier in this chain. |
| 7 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_phn | C_S_ECI_PTY_RLE_PHN | WRK_ECI_PHN_ROUTED | CONTROL:success-only | Writes good phone records to C_S_ECI_PTY_RLE_PHN. |
| 7 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_eaddr | C_S_ECI_PTY_RLE_EADDR | WRK_ECI_PHN_ROUTED | CONTROL:success-only | Writes valid email records to C_S_ECI_PTY_RLE_EADDR. |
| 7 | 4 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_PHN_ROUTED | CONTROL:success-only | Writes bad-phone and bad-email rows to the exception queue. |
| 8 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_prep | WRK_ECI_ADDR_SCORED | STG_ECI_PTY_INACTIVE_STS | TABLE:WRK_ECI_ADDR_SCORED | Builds the routed dataset; writers below read only this table. Reads INACTIVE_STS written by Validation _inactive_sts earlier in this chain. |
| 8 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_dqm | DQM_ADDRESS | WRK_ECI_ADDR_SCORED | CONTROL:success-only | Writes every active address to DQM_ADDRESS (appends; no uq guard, as in the original). |
| 8 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_addr | C_S_ECI_PTY_RLE_ADDR | WRK_ECI_ADDR_SCORED | CONTROL:success-only | Writes score-100 addresses to C_S_ECI_PTY_RLE_ADDR. |
| 8 | 4 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_ADDR_SCORED | CONTROL:success-only | Writes score-40 addresses to the exception queue. |
| 9 | 1 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_prep | WRK_ECI_REL_BUILT | STG_ECI_PTY_INACTIVE_STS | TABLE:WRK_ECI_REL_BUILT | Builds the routed dataset; writers below read only this table. Reads INACTIVE_STS written by Validation _inactive_sts earlier in this chain. |
| 9 | 2 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_rel | C_S_ECI_PTY_RLE_REL | WRK_ECI_REL_BUILT | CONTROL:success-only | Writes valid relationships to C_S_ECI_PTY_RLE_REL. |
| 9 | 3 | PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_exc | EXC_STG_BAD_REC_MEMB | WRK_ECI_REL_BUILT | NONE | Writes untranslated-relationship rows to the exception queue. Chain terminus: nothing follows in this workflow. |

## FSS

Chain script: `chains/run_wf_FSS_Stage_Load.sql` (20 calls). Package: `PKG_FSS`. Materializer step names: `*_src` (DROP-if-exists + CTAS via q-quoted dynamic SQL with `:bN` binds for `l_run_ts`, `c_mapping` and the original parameters).

Parameters: materializers take the original mapping parameters with original defaults (Pty: `P_PTY_BO_CLASS_CD_MEMBER = 'Indv'`, `P_RLE_BO_CLASS_CD_MEMBER = 'Member'`; Addr: `P_MEMBER_HIERARCHY_CODE = 'Member'`, `P_MEMBER_HM_REL_TP_CD = 'Member Addr'`); the chain script calls them zero-arg. Consumers take none.

Commit: each discrete procedure COMMITs its own work (materializer DDL also auto-commits). A failed procedure stops the chain but does NOT roll back earlier writers.

Recovery: resume a failed mapping from its `*_src` procedure, never by re-running a single writer. DQM_ADDRESS appends — never re-execute a succeeded `_dqm` step. LOG/EXC branches are NOT idempotent (`uq_*` guards are within-run only): reconcile or clean failed-attempt LOG/EXC rows before re-running.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_src | WRK_FSS_VAL_SRC | STG_FSS_PTY_INACTIVE_STS (prior run) | TABLE:WRK_FSS_VAL_SRC | DROP-if-exists + CTAS of the original source SELECT; binds carry l_run_ts, c_mapping and the original params. Must run before this mapping's consumers: consumers must never re-evaluate the source (target anti-joins would see partial inserts). |
| 1 | 2 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_exc | EXC_STG_BAD_REC_MEMB | WRK_FSS_VAL_SRC | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB from the WRK_FSS_VAL_SRC snapshot. |
| 1 | 3 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_log | STG_FSS_PTY_INACTIVE_LOG | WRK_FSS_VAL_SRC | CONTROL:success-only | Writes STG_FSS_PTY_INACTIVE_LOG from the WRK_FSS_VAL_SRC snapshot. |
| 1 | 4 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_sts | STG_FSS_PTY_INACTIVE_STS | WRK_FSS_VAL_SRC | TABLE:STG_FSS_PTY_INACTIVE_STS | Writes STG_FSS_PTY_INACTIVE_STS from the WRK_FSS_VAL_SRC snapshot. |
| 2 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_src | WRK_FSS_PTY_SRC | STG_FSS_PTY_INACTIVE_STS | TABLE:WRK_FSS_PTY_SRC | DROP-if-exists + CTAS of the original source SELECT; binds carry l_run_ts, c_mapping and the original params. Must run before this mapping's consumers: consumers must never re-evaluate the source (target anti-joins would see partial inserts). |
| 2 | 2 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_pty | C_S_FSS_PTY | WRK_FSS_PTY_SRC | CONTROL:success-only | Writes C_S_FSS_PTY from the WRK_FSS_PTY_SRC snapshot. |
| 2 | 3 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_rle | C_S_FSS_PTY_RLE | WRK_FSS_PTY_SRC | CONTROL:success-only | Writes C_S_FSS_PTY_RLE from the WRK_FSS_PTY_SRC snapshot. |
| 2 | 4 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_exc | EXC_STG_BAD_REC_MEMB | WRK_FSS_PTY_SRC | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB from the WRK_FSS_PTY_SRC snapshot. |
| 3 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_src | WRK_FSS_ADDR_SRC | STG_FSS_PTY_INACTIVE_STS | TABLE:WRK_FSS_ADDR_SRC | DROP-if-exists + CTAS of the original source SELECT; binds carry l_run_ts, c_mapping and the original params. Must run before this mapping's consumers: consumers must never re-evaluate the source (target anti-joins would see partial inserts). |
| 3 | 2 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_dqm | DQM_ADDRESS | WRK_FSS_ADDR_SRC | CONTROL:success-only | Writes DQM_ADDRESS from the WRK_FSS_ADDR_SRC snapshot. |
| 3 | 3 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_addr | C_S_FSS_PTY_RLE_ADDR | WRK_FSS_ADDR_SRC | CONTROL:success-only | Writes C_S_FSS_PTY_RLE_ADDR from the WRK_FSS_ADDR_SRC snapshot. |
| 3 | 4 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_exc | EXC_STG_BAD_REC_MEMB | WRK_FSS_ADDR_SRC | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB from the WRK_FSS_ADDR_SRC snapshot. |
| 4 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id_alt | C_S_FSS_PTY_RLE_ALT_ID | STG_FSS_PTY_INACTIVE_STS | CONTROL:success-only | Single INSERT carried verbatim; no WRK table needed (source used once). |
| 5 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_src | WRK_FSS_PHN_SRC | STG_FSS_PTY_INACTIVE_STS | TABLE:WRK_FSS_PHN_SRC | DROP-if-exists + CTAS of the original source SELECT; binds carry l_run_ts, c_mapping and the original params. Must run before this mapping's consumers: consumers must never re-evaluate the source (target anti-joins would see partial inserts). |
| 5 | 2 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_eaddr | C_S_FSS_PTY_RLE_EADDR | WRK_FSS_PHN_SRC | CONTROL:success-only | Writes C_S_FSS_PTY_RLE_EADDR from the WRK_FSS_PHN_SRC snapshot. |
| 5 | 3 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_phn | C_S_FSS_PTY_RLE_PHN | WRK_FSS_PHN_SRC | CONTROL:success-only | Writes C_S_FSS_PTY_RLE_PHN from the WRK_FSS_PHN_SRC snapshot. |
| 5 | 4 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_exc | EXC_STG_BAD_REC_MEMB | WRK_FSS_PHN_SRC | CONTROL:success-only | Writes EXC_STG_BAD_REC_MEMB from the WRK_FSS_PHN_SRC snapshot. |
| 6 | 1 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_src | WRK_FSS_REL_SRC | STG_FSS_PTY_INACTIVE_STS | TABLE:WRK_FSS_REL_SRC | DROP-if-exists + CTAS of the original source SELECT; binds carry l_run_ts, c_mapping and the original params. Must run before this mapping's consumers: consumers must never re-evaluate the source (target anti-joins would see partial inserts). |
| 6 | 2 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_rel | C_S_FSS_PTY_RLE_REL | WRK_FSS_REL_SRC | CONTROL:success-only | Writes C_S_FSS_PTY_RLE_REL from the WRK_FSS_REL_SRC snapshot. |
| 6 | 3 | PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_exc | EXC_STG_BAD_REC_MEMB | WRK_FSS_REL_SRC | NONE | Writes EXC_STG_BAD_REC_MEMB from the WRK_FSS_REL_SRC snapshot. |

## WIC

Chain script: `chains/run_wf_WIC_Stage_Load.sql` (17 calls). Package: `PKG_WIC`. Materializer step names: `*_routed` / `*_scored` (DROP-if-exists + CTAS via dynamic SQL with `:bN` binds; the CTAS query restores byte-identical to the original when binds are replaced).

Parameters: only routed/scored procedures take the original mapping parameters with original defaults; writers take none. All parameters come from the chain script's defaults, never from a predecessor procedure.

Commit: materializer DDL auto-commits; writers COMMIT their own work. A failed procedure stops the chain but does NOT roll back earlier writers.

Recovery: resume a failed mapping from its routed/scored procedure, never by re-running a single writer. Writers are not idempotent (`uq_*` flags were computed pre-insert); full-chain re-runs duplicate EXC_STG_BAD_REC_MEMB / STG_WIC_PTY_INACTIVE_LOG rows, as in v1. DQM_ADDRESS appends — never re-execute a succeeded `_dqm` step.

WIC boolean note: two inherited boolean issues are preserved UNFIXED here (see Known live-compile items): Validation `name_missing` and Pty `uq_pty` are invalid in Oracle SQL and will fail their CTAS at live-compile time. Fix shape (when approved, applied identically in both trees): `CASE WHEN <cond> THEN 1 ELSE 0 END`.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_routed | WRK_WIC_VAL_ROUTED | STG_WIC_PTY_INACTIVE_STS (prior run) | TABLE:WRK_WIC_VAL_ROUTED | DROP + CTAS (DDL commits); snapshot semantics preserved: uq_* flags computed against pre-insert targets once. |
| 1 | 2 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_exc | EXC_STG_BAD_REC_MEMB | WRK_WIC_VAL_ROUTED | CONTROL:success-only | 1 branch: WHEN (name_missing = 1) AND (uq_exc_name = 1). |
| 1 | 3 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_log | STG_WIC_PTY_INACTIVE_LOG | WRK_WIC_VAL_ROUTED | CONTROL:success-only | 2 branches: WHEN (name_missing = 1); WHEN deactivation_sts IS NOT NULL AND NOT (name_missing = 1). |
| 1 | 4 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_sts | STG_WIC_PTY_INACTIVE_STS | WRK_WIC_VAL_ROUTED | TABLE:STG_WIC_PTY_INACTIVE_STS | 1 branch: WHEN (name_missing = 1) AND deactivation_sts IS NULL. |
| 2 | 1 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_routed | WRK_WIC_PTY_ROUTED | STG_WIC_PTY_INACTIVE_STS | TABLE:WRK_WIC_PTY_ROUTED | DROP + CTAS (DDL commits); snapshot semantics preserved: uq_* flags computed against pre-insert targets once. |
| 2 | 2 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_pty | C_S_WIC_PTY | WRK_WIC_PTY_ROUTED | CONTROL:success-only | 1 branch: WHEN (uq_pty = 1). |
| 2 | 3 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_rle | C_S_WIC_PTY_RLE | WRK_WIC_PTY_ROUTED | CONTROL:success-only | 1 branch: WHEN (uq_rle = 1). |
| 2 | 4 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_exc | EXC_STG_BAD_REC_MEMB | WRK_WIC_PTY_ROUTED | CONTROL:success-only | 5 branches: WHEN (grp_gender = 1) AND (uq_gender = 1); WHEN (grp_birth = 1) AND (uq_birth = 1); WHEN (grp_ethnicity = 1) AND (uq_ethnicity = 1); WHEN (grp_race = 1) AND (uq_race = 1); WHEN (grp_language = 1) AND (uq_language = 1). |
| 3 | 1 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_scored | WRK_WIC_ADDR_SCORED | STG_WIC_PTY_INACTIVE_STS | TABLE:WRK_WIC_ADDR_SCORED | DROP + CTAS (DDL commits); snapshot semantics preserved: uq_* flags computed against pre-insert targets once. |
| 3 | 2 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_dqm | DQM_ADDRESS | WRK_WIC_ADDR_SCORED | CONTROL:success-only | 1 branch: WHEN 1. |
| 3 | 3 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_addr | C_S_WIC_PTY_RLE_ADDR | WRK_WIC_ADDR_SCORED | CONTROL:success-only | 1 branch: WHEN score = '100' AND (uq_addr = 1). |
| 3 | 4 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_exc | EXC_STG_BAD_REC_MEMB | WRK_WIC_ADDR_SCORED | CONTROL:success-only | 1 branch: WHEN score = '40' AND (uq_addr_exc = 1). |
| 4 | 1 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_routed | WRK_WIC_PHN_ROUTED | STG_WIC_PTY_INACTIVE_STS | TABLE:WRK_WIC_PHN_ROUTED | DROP + CTAS (DDL commits); snapshot semantics preserved: uq_* flags computed against pre-insert targets once. |
| 4 | 2 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_phn | C_S_WIC_PTY_RLE_PHN | WRK_WIC_PHN_ROUTED | CONTROL:success-only | 1 branch: WHEN (grp_phone_good = 1) AND (uq_phn = 1). |
| 4 | 3 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_exc | EXC_STG_BAD_REC_MEMB | WRK_WIC_PHN_ROUTED | CONTROL:success-only | 2 branches: WHEN (grp_phone_bad = 1) AND (uq_phone_exc = 1); WHEN (grp_email_bad = 1) AND (uq_email_exc = 1). |
| 4 | 4 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_eaddr | C_S_WIC_PTY_RLE_EADDR | WRK_WIC_PHN_ROUTED | CONTROL:success-only | 1 branch: WHEN (grp_email_good = 1) AND (uq_eaddr = 1). |
| 5 | 1 | PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id_alt | C_S_WIC_PTY_RLE_ALT_ID | STG_WIC_PTY_INACTIVE_STS | NONE | Single INSERT; anti-join against own target (VERSION_SEQ = 1) and inactive-status filter preserved. No WRK table needed. Last proc in chain. |

## TTF

Chain script: `chains/run_wf_TTF_Stage_Load.sql` (12 calls). Package: `PKG_TTF`. Materializer step names: `*_stage` (DELETE + INSERT into a pre-existing WRK table — install `ddl/04_create_ttf_wrk_tables.sql` first; the stage stamps `run_ts` from its own SYSTIMESTAMP and writers reuse it, so all rows of one mapping still share one timestamp).

Parameters: only the Pty stage takes parameters, `('Indv', 'Member')` (the two BO-class params, original defaults); everything else is zero-arg.

Commit: each discrete procedure COMMITs its own work. A failed procedure stops the chain but does NOT roll back earlier writers.

Recovery: resume a failed mapping from its `*_stage` procedure, never by re-running a single writer. TTF has no address, email, or relationship mapping — none was invented. Preserved quirks (not fixed): no DD_DELETE of inactive STS, insert-only loads, the never-fed phone-extension and language/suffix branches still generate nothing.

TTF boolean note: `uq_pty` (Pty) and `uq_phn` (Phn) were bare booleans in the originals and are wrapped here as `CASE WHEN (...) THEN 1 ELSE 0 END`; the conditions are TRUE/FALSE only, never NULL, so downstream `= 1` tests behave exactly like the original WHEN conditions.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_stage | WRK_TTF_VAL_ROUTED | STG_TTF_PTY_INACTIVE_STS (prior run) | TABLE:WRK_TTF_VAL_ROUTED | Stage: DELETE + INSERT WRK_TTF_VAL_ROUTED (21 cols) from the original INSERT ALL pipeline. Reads the pre-run STG_TTF_PTY_INACTIVE_STS snapshot (previous run), not this chain. Stamps run_ts for its mapping. |
| 1 | 2 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_exc | EXC_STG_BAD_REC_MEMB | WRK_TTF_VAL_ROUTED | CONTROL:success-only | Writes invalid-party-name rows to EXC_STG_BAD_REC_MEMB from WRK_TTF_VAL_ROUTED. |
| 1 | 3 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_log | STG_TTF_PTY_INACTIVE_LOG | WRK_TTF_VAL_ROUTED | CONTROL:success-only | Writes deactivation/reactivation rows to STG_TTF_PTY_INACTIVE_LOG from WRK_TTF_VAL_ROUTED. |
| 1 | 4 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_sts | STG_TTF_PTY_INACTIVE_STS | WRK_TTF_VAL_ROUTED | TABLE:STG_TTF_PTY_INACTIVE_STS | Writes the live inactive list to STG_TTF_PTY_INACTIVE_STS from WRK_TTF_VAL_ROUTED. |
| 2 | 1 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_stage | WRK_TTF_PTY_ROUTED | STG_TTF_PTY_INACTIVE_STS | TABLE:WRK_TTF_PTY_ROUTED | Stage: DELETE + INSERT WRK_TTF_PTY_ROUTED (56 cols) from the original pipeline. Takes ('Indv', 'Member') (the two BO-class params, original defaults). uq_pty was a bare boolean in the original and is wrapped here as CASE WHEN (...) THEN 1 ELSE 0 END; downstream = 1 tests behave exactly as the original WHEN conditions. |
| 2 | 2 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_pty | C_S_TTF_PTY | WRK_TTF_PTY_ROUTED | CONTROL:success-only | Writes valid parties to C_S_TTF_PTY from WRK_TTF_PTY_ROUTED. |
| 2 | 3 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_rle | C_S_TTF_PTY_RLE | WRK_TTF_PTY_ROUTED | CONTROL:success-only | Writes party roles to C_S_TTF_PTY_RLE from WRK_TTF_PTY_ROUTED. |
| 2 | 4 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_exc | EXC_STG_BAD_REC_MEMB | WRK_TTF_PTY_ROUTED | CONTROL:success-only | Writes party exception rows to EXC_STG_BAD_REC_MEMB from WRK_TTF_PTY_ROUTED. |
| 3 | 1 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id_alt_id | C_S_TTF_PTY_RLE_ALT_ID | STG_TTF_PTY_INACTIVE_STS | CONTROL:success-only | Single-INSERT mapping, renamed only; writes C_S_TTF_PTY_RLE_ALT_ID. No WRK table needed. |
| 4 | 1 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_stage | WRK_TTF_PHN_ROUTED | STG_TTF_PTY_INACTIVE_STS | TABLE:WRK_TTF_PHN_ROUTED | Stage: DELETE + INSERT WRK_TTF_PHN_ROUTED (20 cols) from the original pipeline. uq_phn was a bare boolean in the original and is wrapped here as CASE WHEN (...) THEN 1 ELSE 0 END. |
| 4 | 2 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_phn | C_S_TTF_PTY_RLE_PHN | WRK_TTF_PHN_ROUTED | CONTROL:success-only | Writes good phone records to C_S_TTF_PTY_RLE_PHN from WRK_TTF_PHN_ROUTED. |
| 4 | 3 | PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_exc | EXC_STG_BAD_REC_MEMB | WRK_TTF_PHN_ROUTED | NONE | Writes bad-phone rows to EXC_STG_BAD_REC_MEMB from WRK_TTF_PHN_ROUTED. |

## CRE

Chain script: `chains/run_wf_CRE_Stage_Load_Ongoing.sql` (26 calls). Package: `PKG_CRE`. Step names: 8 pipeline stages (`routed` → `named` → `members` → `ranked` → `dq` → `dq2` → `flat` → `keyed`, each writing exactly one WRK table via DROP-if-exists + CTAS) followed by 18 writers in original INSERT ALL branch order, each reading only `WRK_CRE_KEYED`.

Parameters: only `flat` (2 params: `Member`, `99`) and `keyed` (5 params: `002`, `48`, `996`, `998`, `Member`) take parameters; the chain script passes the original defaults and a caller may override by calling stages directly. All other procedures take none.

Commit: DIFFERENT from the other workflows — target writes stay uncommitted until the chain script's single COMMIT at the end (a write failure rolls its step back). Stage DROP + CTAS commits only the scratch WRK tables (Oracle DDL implicit commit), never target data.

Recovery: re-run the chain from the start after a failure (each stage rebuilds its work table). Gated branches insert nothing new on re-run (gates computed in `keyed` against pre-run target state); unguarded exception branches (gender, suffix, ethnicity, race, address, phone) duplicate on re-run, exactly as re-running the original would. The chain is not idempotent for those branches.

Lookup CTEs (helper40–47 table functions) and the alt-id type lookup are folded into their consuming stages (pure lookups, no writes). The original's helper36 summary line is not reproduced — each write procedure returns its own rowcount instead.

| seq1 | seq2 | spName | work table created | work table consumed | handoff mechanism | notes |
|---|---|---|---|---|---|---|
| 1 | 1 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_routed | WRK_CRE_ROUTED | — | TABLE:WRK_CRE_ROUTED | Stage 1: snapshot union of the CARE source plus XREF/HMRG merge-history resolution. Stamps run_ts once for the whole chain; every later stage carries it as a column. |
| 1 | 2 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_named | WRK_CRE_NAMED | WRK_CRE_ROUTED | TABLE:WRK_CRE_NAMED | Stage 2: helper15 name standardization. |
| 1 | 3 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_members | WRK_CRE_MEMBERS | WRK_CRE_NAMED | TABLE:WRK_CRE_MEMBERS | Stage 3: member validity plus the end-dated flag. |
| 1 | 4 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_ranked | WRK_CRE_RANKED | WRK_CRE_MEMBERS | TABLE:WRK_CRE_RANKED | Stage 4: REC_TYPE pick — VERSION_SEQ rank per CARE id, merge-care id, SSN output. |
| 1 | 5 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq | WRK_CRE_DQ | WRK_CRE_RANKED | TABLE:WRK_CRE_DQ | Stage 5: gender / ethnicity / race / phone / alt-id enrichment. |
| 1 | 6 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq2 | WRK_CRE_DQ2 | WRK_CRE_DQ | TABLE:WRK_CRE_DQ2 | Stage 6: helper34 address validation plus phone code. |
| 1 | 7 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_flat | WRK_CRE_FLAT | WRK_CRE_DQ2 | TABLE:WRK_CRE_FLAT | Stage 7: timeline, validated address fields, exception lookups, alt-id types. Takes (Member, 99) (original defaults). |
| 1 | 8 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_keyed | WRK_CRE_KEYED | WRK_CRE_FLAT | TABLE:WRK_CRE_KEYED | Stage 8: keys, router flags, constants, 30-char rowids, all dedup gates. 197 columns; every writer below reads only this table. Takes (002, 48, 996, 998, Member) (original defaults). |
| 1 | 9 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_mrg | CRE_SRC_MRG | WRK_CRE_KEYED | CONTROL:success-only | Writes merge-history rows to CRE_SRC_MRG (not a C_S_* table; staging-owned). |
| 1 | 10 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_fname | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes first-name exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 11 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_lname | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes last-name exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 12 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_pty | C_S_CRE_PTY | WRK_CRE_KEYED | CONTROL:success-only | Writes C_S_CRE_PTY from WRK_CRE_KEYED with its original branch predicate. |
| 1 | 13 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_rle | C_S_CRE_PTY_RLE | WRK_CRE_KEYED | CONTROL:success-only | Writes C_S_CRE_PTY_RLE from WRK_CRE_KEYED with its original branch predicate. |
| 1 | 14 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_gender | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes gender exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 15 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_suffix | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes suffix exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 16 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ethnicity | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes ethnicity exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 17 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_race | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes race exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 18 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_addr | C_S_CRE_PTY_RLE_ADDR | WRK_CRE_KEYED | CONTROL:success-only | Writes C_S_CRE_PTY_RLE_ADDR from WRK_CRE_KEYED with its original branch predicate. |
| 1 | 19 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_addr | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes address exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 20 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_phn | C_S_CRE_PTY_RLE_PHN | WRK_CRE_KEYED | CONTROL:success-only | Writes C_S_CRE_PTY_RLE_PHN from WRK_CRE_KEYED with its original branch predicate. |
| 1 | 21 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_phone | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes phone exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 22 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_care | C_S_CRE_PTY_RLE_ALT_ID | WRK_CRE_KEYED | CONTROL:success-only | Writes CARE alternate ids to C_S_CRE_PTY_RLE_ALT_ID. |
| 1 | 23 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_medicaid | C_S_CRE_PTY_RLE_ALT_ID | WRK_CRE_KEYED | CONTROL:success-only | Writes Medicaid alternate ids to C_S_CRE_PTY_RLE_ALT_ID. |
| 1 | 24 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_medicaid | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | CONTROL:success-only | Writes Medicaid exception rows to EXC_STG_BAD_REC_MEMB. |
| 1 | 25 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_ssn | C_S_CRE_PTY_RLE_ALT_ID | WRK_CRE_KEYED | CONTROL:success-only | Writes SSN alternate ids to C_S_CRE_PTY_RLE_ALT_ID. |
| 1 | 26 | PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ssn | EXC_STG_BAD_REC_MEMB | WRK_CRE_KEYED | NONE | Writes SSN exception rows to EXC_STG_BAD_REC_MEMB. |

## Known live-compile / live-run items (static verification only)

Nothing in this tree has been compiled or executed against a live Oracle
database. The split inherits every open live-DB item from the v1 mirror, and
adds the CTAS-bind mechanism (unexercised on a real instance):

- `func().attribute` in SQL (biggest risk): helper object results are
  dereferenced with dot notation (e.g. `PKG_COMMON.fn_snow_helper15_common
  (...).std_first_name`). Fallback if a live compile rejects it:
  scalar-subquery / CTE wrapping.
- Table-function form: row OBJECT + nested-table + BULK COLLECT shape is
  translated, not proven.
- `VARCHAR2(4000)` assumption for every string column / parameter / variable.
- `''` vs NULL gaps carried from the translator.
- No row-count parity vs the v1 mirror or vs IDQ has been run.
- WRK tables carrying object-typed columns (`nm`, `gd`, `rc`, `em`, …) need
  the schema-level object types installed first — the installer order
  (`00_create_types.sql` before the packages) guarantees this.

Per-source boolean status (Oracle SQL has no boolean type, so bare booleans
are compile errors, not style):

- ECI: 17 boolean-translation fixes applied IN THIS SPLIT ONLY. The
  single-SP repo still carries those gaps (full list with evidence:
  `docs/split-notes/ECI_SPLIT_NOTES.md` §5). Most serious first: Validation
  `fam_inactive_yn` — the mirror glues `ANDCASE` and wraps a `'N'/'Y'` CASE
  in a 1/0 CASE while downstream code compares `= 'N'` / `= 'Y'` (a SEMANTIC
  break, not just a compile error); the split uses the Snowflake original's
  `'N'/'Y'` CASE. Others: Validation `name_missing` boolean-OR fix + routed
  `= 1` comparisons; Validation+Pty helper15 junk args (booleans passed to
  NUMBER(1) params); Alt_Id `ssn_exception_code` ANDCASE fix; bare-boolean
  SELECT values → `CASE WHEN … THEN 1 ELSE 0 END` (Pty `uq_pty`, Alt_Id
  `uq_alt_id`, Phn `uq_phn`, Addr `uq_addr`, Rel `uq_rel`); Phn `is_email`
  NVL-boolean fix + `NOT …is_email` comparisons; Rel `FROM VALUES` →
  `UNION ALL … FROM DUAL`. Backporting these to ora-single-sp-layout is a
  separate decision — until then the two trees differ here.
- TTF: 2 bare booleans wrapped in CASE (`uq_pty`, `uq_phn`); the conditions
  are TRUE/FALSE only, never NULL, so downstream `= 1` tests are unchanged.
- WIC: 2 inherited boolean issues preserved UNFIXED (Validation
  `name_missing`, Pty `uq_pty`) — they will fail their CTAS at live-compile
  time. Fix shape (to be applied identically in both trees if ever fixed):
  `CASE WHEN <cond> THEN 1 ELSE 0 END`.
- TRS, FSS, CRE: translator output preserved as-is; no boolean fixes were
  needed or applied there beyond what the v1 mirror already carried.


## Assembly notes (how this document was put together)

- One table per workflow, 135 rows total (TRS Ongoing 34, TRS TOA 1, ECI 25,
  FSS 20, WIC 17, TTF 12, CRE 26), assembled from the six chain fragments.
- `spName` values are the packaged names; the fragments used unqualified
  names. The packaged procedure set is identical to the fragment set — no
  procedure was added, removed, or renamed, only qualified with its package.
- Handoff values were normalized to the output-side rule defined above.
  In the workers' fragments the column mixed two readings (input-side in
  TRS/FSS, output-side in ECI/WIC). Recomputed mechanically: `TABLE:<created>`
  iff a later row plain-consumes that table, else `CONTROL:success-only`,
  except the workflow-final row which is `NONE`. `PARAM:` rows in the TRS
  fragment (build procedures take mapping parameters) became `TABLE:<WRK>`
  because their WRK tables are consumed by their writers; the parameter
  facts moved to the per-workflow notes above.
- `work table created` was normalized to always name the table written:
  the WIC fragment's `—` for the final Alt_Id row became
  `C_S_WIC_PTY_RLE_ALT_ID`, and the FSS fragment's `—` entries became their
  target tables (from the generator's emitted data).
- Two fragment gaps were corrected from the procedure code itself: ECI
  Alt_Id prep also reads `STG_ECI_D_MEDICAID` (written by the Medicaid
  reactivation row), so it is listed in that row's consumed set; and the ECI
  reactivation Address/Phone rows do NOT hand off to any later row in this
  workflow (no later procedure reads `STG_ECI_D_FAMILY_ADDRESS` /
  `STG_ECI_D_FAMILY_PHONE` — their consumers are outside this chain), so
  their handoff is `CONTROL:success-only`, not `TABLE:` as the fragment
  claimed. The Medicaid reactivation row keeps `TABLE:STG_ECI_D_MEDICAID`
  because Alt_Id prep reads it.
- TTF and CRE fragments were rebuilt at assembly from the procedure bodies
  and chain scripts (their original fragment files were lost when the shared
  staging directory was clobbered mid-build — see below). Row order, created
  and consumed sets were derived mechanically from the code; notes come
  from the workers' delivery reports.
- Recovery note (please read before the next multi-worker round): the
  shared staging directory `v1_multi_oracle/` lost the FSS, WIC, TTF and CRE
  outputs between worker completion and assembly (one worker had run
  `rm -rf` on it during its own regeneration; another reported its folder
  vanishing across a compaction boundary). All four were regenerated from
  the workers' surviving `/tmp` generator scripts into a separate recovery
  directory and re-verified with the workers' own verifiers (FSS binds
  match, WIC 0 failures, CRE column resolution clean, TTF chain order
  exact) before packaging. The surviving ECI and TRS outputs were used
  as-is. In future rounds, give each worker its own staging directory.
