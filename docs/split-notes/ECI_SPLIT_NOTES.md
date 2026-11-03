# ECI split notes — v1 single-SP Oracle procedures → discrete single-purpose procedures

Scope: workflow `wf_ECI_Stage_Load` only — 9 mappings, split from the already-translated,
verified v1 Oracle mirror in `~/workspace/v1_oracle_mirror/wf_ECI_Stage_Load/` (read-only;
nothing there was modified). The Snowflake originals were used only to cross-check INSERT
targets and to verify the translation-gap fixes in §5. Output: 25 discrete procedures in
`wf_ECI_Stage_Load/`, plus the chain script `wf_ECI_Stage_Load/run_wf_ECI_Stage_Load.sql`
and the chain fragment `ECI_CHAIN_FRAGMENT.md` (25 rows, one per discrete proc).

Naming: `<orig_function_name>_<step_slug>`, e.g.
`sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep`. Every discrete proc is an Oracle
FUNCTION, `AUTHID CURRENT_USER`, returning a `VARCHAR2` status line. Common helpers
(`fn_snow_helperNN_common`) are CALLED, never copied into discrete procs. No file under
`common/` was touched.

## 1. Why a prep proc + WRK table exists per multi-target mapping

Six of the nine mappings are a single `INSERT ALL` over one shared CTE chain: the CTEs
compute enrichment, routing groups (`grp_*`) and uniqueness flags (`uq_*`), and each
branch writes a different target. A later branch cannot re-run the earlier branch's CTEs —
they are not tables — so the split materialises the shared CTE output once, in a work
table, and every writer reads only that table:

- the prep proc runs the original query unchanged (except the §5 fixes), wrapped as
  `INSERT INTO <WRK> (<cols>) SELECT <cols> FROM (<original query>)`;
- each writer is the original branch (or branch group) as `INSERT ... SELECT ... FROM <WRK>`
  (multi-branch writers keep their original `INSERT ALL` shape);
- the WRK column list is exactly the identifiers the writers' VALUES lists and predicates
  reference — nothing more. It therefore excludes intermediates consumed inside prep only
  (e.g. Validation `hub_state_ind`, `omit_id`, `fam_inactive_yn`, `name_missing`, and the
  flattened `std_*` columns are kept while the raw OBJECT columns `nm`/`gd`/`rc`/`em`/`av`
  are dropped, because writers never reference the OBJECT columns).
- WRK column types: `run_ts` → TIMESTAMP; `a_latitude`/`a_longitude` → NUMBER(38,6);
  flags (`uq_*`, `grp_*`), `version_seq`, `hub_state_ind`, `name_missing`, `is_email`,
  `birth_wght_grms`, `a_result_pct`, IDs (`ID`, `ID_CHILD`, `ID_FAMILY`,
  `ID_FAMILY_ADDRESS`, `ID_FAMILY_PHONE`, `ID_CASE`), `BIRTH_WT_LB`/`BIRTH_WT_OZ`,
  `GESTATION_AGE` → NUMBER; date-named columns (`DATE_CREATED`, `DATE_MODIFIED`, `DOB`,
  `LOAD_DATE`, `PERIOD_START_DATE`, `LAST_UPDATE_DATE`, `CANCEL_DATE`, `ELIG_DATE`,
  `END_DATE`, `src_last_upd_dt`, `BIRTH_DATE`) → DATE; everything else → VARCHAR2(4000).
  VARCHAR2 is the safe default (writer INSERTs into VARCHAR2 targets; numeric strings
  convert implicitly); NUMBER is used only where the value is provably numeric, so no new
  failure mode is introduced versus the original.

The three Reactivation mappings each contain a single INSERT, so they need no split: the
discrete proc IS the original body, renamed (`_load`).

## 2. Per-mapping INSERT-target → discrete-proc mapping

| seq1 | Original procedure | Original INSERT target | Discrete proc that writes it |
|---|---|---|---|
| 1 | sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation | EXC_STG_BAD_REC_MEMB | …_Validation_exc |
| 1 | | STG_ECI_PTY_INACTIVE_LOG | …_Validation_inactive_log |
| 1 | | STG_ECI_PTY_INACTIVE_STS | …_Validation_inactive_sts |
| 2 | sp_snow_main_m_Tgt_C_S_ECI_Pty | C_S_ECI_PTY | …_Pty_pty |
| 2 | | C_S_ECI_PTY_RLE | …_Pty_pty_rle |
| 2 | | EXC_STG_BAD_REC_MEMB | …_Pty_exc |
| 3 | sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr | STG_ECI_D_FAMILY_ADDRESS | …_Reactivation_D_Family_Addr_load |
| 4 | sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn | STG_ECI_D_FAMILY_PHONE | …_Reactivation_D_Family_Phn_load |
| 5 | sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid | STG_ECI_D_MEDICAID | …_Reactivation_D_Medicaid_load |
| 6 | sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id | C_S_ECI_PTY_RLE_ALT_ID | …_Pty_Rle_Alt_Id_alt_id |
| 6 | | EXC_STG_BAD_REC_MEMB | …_Pty_Rle_Alt_Id_exc |
| 7 | sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr | C_S_ECI_PTY_RLE_PHN | …_Pty_Rle_Phn_And_EAddr_phn |
| 7 | | C_S_ECI_PTY_RLE_EADDR | …_Pty_Rle_Phn_And_EAddr_eaddr |
| 7 | | EXC_STG_BAD_REC_MEMB | …_Pty_Rle_Phn_And_EAddr_exc |
| 8 | sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr | DQM_ADDRESS | …_Pty_Addr_dqm |
| 8 | | C_S_ECI_PTY_RLE_ADDR | …_Pty_Addr_addr |
| 8 | | EXC_STG_BAD_REC_MEMB | …_Pty_Addr_exc |
| 9 | sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel | C_S_ECI_PTY_RLE_REL | …_Pty_Rle_Rel_rel |
| 9 | | EXC_STG_BAD_REC_MEMB | …_Pty_Rle_Rel_exc |

Every INSERT target in every original file is written by exactly one discrete proc
(verified mechanically — see §6). Multi-branch writers that write the same table from
several original branches stay one proc: Pty `_exc` (5 branches: gender, birth, ethnicity,
race, language), Alt_Id `_exc` (2: SSN, Medicaid), Phn `_exc` (2: phone-bad, email-bad),
Validation `_inactive_log` (2: Deactivation, Reactivation). Branch order inside each
writer is the original branch order. Original branch comment lines are preserved in the
writer files (above the WHEN in multi-branch writers, above the INSERT in single-branch
writers).

Discrete-proc counts per mapping: Validation 4, Pty 4, Reactivation Addr 1, Reactivation
Phn 1, Reactivation Medicaid 1, Alt_Id 3, Phn_And_EAddr 4, Addr 4, Rel 3 — **25 total**.

## 3. Every new WRK table introduced, and why

| WRK table | Written by | Read by | Why |
|---|---|---|---|
| WRK_ECI_VALIDATION_ROUTED (22 cols) | …_Validation_prep | …_Validation_exc, …_inactive_log, …_inactive_sts | Shared CTE output (standardisation, routing groups, uq flags) for the 3 Validation targets. |
| WRK_ECI_PTY_ROUTED (68 cols) | …_Pty_prep | …_Pty_pty, …_pty_rle, …_exc | Shared CTE output for the 3 Pty targets. |
| WRK_ECI_ALT_ID_ROUTED (27 cols) | …_Alt_Id_prep | …_Alt_Id_alt_id, …_exc | Shared CTE output for the 2 Alt_Id targets. |
| WRK_ECI_PHN_ROUTED (40 cols) | …_Phn_And_EAddr_prep | …_phn, …_eaddr, …_exc | Shared CTE output for the 3 Phn/EAddr targets. |
| WRK_ECI_ADDR_SCORED (65 cols) | …_Pty_Addr_prep | …_dqm, …_addr, …_exc | Shared CTE output (validation score, hold lines, uq flags) for the 3 Addr targets. |
| WRK_ECI_REL_BUILT (22 cols) | …_Pty_Rle_Rel_prep | …_rel, …_exc | Shared CTE output (keys, code translation, uq flags) for the 2 Rel targets. |

Prep owns its WRK table: it DROPs it (errors swallowed — first run has nothing to drop),
CREATEs it with an explicit column list, then INSERTs statically, so the PL/SQL variables
(`l_run_ts`, `c_mapping`, mapping parameters) stay visible without dynamic-SQL bind
subtleties. WRK tables are NOT dropped by the writers; the next run's prep drops them
(run-start bookend, matching the clean-ETL constitution's "work tables dropped at the next
run's start" — the drop lives in prep, not in a separate step).

## 4. Things that could not be split cleanly, and behaviour changes to know

- **Transaction granularity changes by necessity.** The original mapping was one statement
  (one implicit transaction per INSERT ALL). The split is one COMMIT per discrete proc.
  The chain script uses `WHENEVER SQLERROR EXIT FAILURE`, so a failed proc stops the chain
  (success-only sequencing), but it does NOT roll back earlier writers of the same mapping
  or earlier mappings. A re-run after a mid-mapping failure re-runs prep (which drops and
  rebuilds the WRK table) and then re-runs the writers; writer anti-joins (`uq_*`) are
  computed in prep against pre-run targets, so a re-run's prep sees the first attempt's
  already-written rows and marks them `uq_* = 0` — the writers then write nothing new for
  those keys. Re-running a failed mapping is therefore safe for the `uq_*`-guarded
  writers, but it is NOT the same as the original single-statement atomicity.
- **Anti-join snapshot semantics are preserved by chain order.** Prep runs before its
  writers, so the `uq_*` anti-joins against target tables (e.g. `C_S_ECI_PTY`,
  `EXC_STG_BAD_REC_MEMB` NULL-RUN_DATE rows for SSN) read pre-run targets, exactly as the
  original single-statement snapshot did. Writers must never run before their prep, and
  preps must never be re-run between writers of the same mapping.
- **`run_ts` single-timestamp semantics are preserved.** Prep writes its `l_run_ts` into
  WRK rows; writers read `run_ts` from WRK instead of computing their own SYSTIMESTAMP,
  so EXC/LOG/STS rows of one mapping share one timestamp exactly as in the original.
- **DQM append behaviour is preserved, not fixed.** Addr `_dqm` has no uniqueness
  predicate (original branch predicate is `WHEN 1`), so re-runs append to DQM_ADDRESS —
  the same known limitation as the v1 mirror and the v3 line (DQM-RERUN: no fix wanted).
- **Medicaid IDQ defect is preserved.** The Reactivation Medicaid filter tests the source
  port `ID_MEDICAID` (never NULL) instead of the lookup result `lkp_ID_MEDICAID`, so with
  the default `P_TEST_LOOKUP_RESULT = 'N'` the load writes no rows; `'Y'` keeps records
  not yet in `STG_ECI_D_MEDICAID`. The parameter is unchanged; the chain script calls the
  load zero-arg, i.e. default behaviour, exactly as the original run script did.
- **SSN NULL-RUN_DATE quirk is preserved.** Alt_Id SSN exception rows have NULL RUN_DATE,
  so their uniqueness key repeats run to run and the prep-computed `uq_ssn_exc` anti-join
  against existing NULL-RUN_DATE rows means an invalid SSN is logged only once, ever.
- **Missing_AreaCode overlap is preserved.** In Phn_And_EAddr, a phone row with a bad area
  code is both loaded (`_phn`) and logged (`_exc`), because the two writers read the same
  WRK rows independently — IDQ router semantics, not a split artefact.
- **Return value narrows.** Each discrete proc returns its own `fn_snow_helper36_common`
  log line; the original returned one accumulated mapping log. The chain script discards
  return values (`SELECT ... FROM DUAL`), so this changes nothing downstream.
- **Parameters:** only preps take the original mapping's parameters (Pty prep:
  `P_PTY_BO_CLASS_CD_MEMBER`, `P_RLE_BO_CLASS_CD_MEMBER`; Addr prep:
  `P_MEMBER_HIERARCHY_CODE`, `P_MEMBER_HM_REL_TP_CD`; Medicaid load:
  `P_TEST_LOOKUP_RESULT`). Writers take no parameters — every value comes from WRK rows
  (including `pty_bo_class_cd`/`rle_bo_class_cd`, which are WRK columns, not params).
  The chain script calls all preps zero-arg, relying on the original defaults, exactly as
  the original run script called the bulky procs zero-arg.
- **No logic was duplicated across procs.** No block needed its CTE output in two places
  except through its WRK table. Pure-computation blocks (standardisation, scoring, routing)
  were folded into prep, not duplicated into writers.

## 5. Translation-gap fixes applied during the split (BACKPORT FLAG for ora-single-sp-layout)

Splitting forced a line-by-line read of the v1 mirror, which surfaced boolean-translation
gaps in the mirror itself. Oracle SQL has no boolean type, so Snowflake boolean
expressions/values carried into the mirror are compile errors, not style issues. Each fix
below was verified against the Snowflake original and the helper signature, and applied
in the split ONLY — the single-SP repo is untouched. **The parent should decide whether
to backport these to ora-single-sp-layout; the most serious is the first one (semantic,
not just compile).**

- **Validation `fam_inactive_yn` — SEMANTIC BREAK (fix first).** Mirror text glued
  `ANDCASE` and wrapped a `'N'/'Y'` CASE in a 1/0 CASE, while downstream code compares
  `fam_inactive_yn = 'N'` / `= 'Y'`. Snowflake original:
  `IFF(fam.FAM_NAME_STATUS IS NULL AND fam.FAM_PHONE_AND_ADDRESS_STS IS NULL AND
  fam.FAM_INACTIVE_STS IS NULL, 'N', 'Y')`. Split: `CASE WHEN ... IS NULL AND ... IS
  NULL AND ... IS NULL THEN 'N' ELSE 'Y' END`.
- **Validation `name_missing` — boolean OR of a NUMBER and a boolean.** Mirror:
  `(fn03(first) OR (fn03(last) = 1))`. Snowflake original: `(fn03(first) OR fn03(last))`
  with the boolean-returning Snowflake helper. Split: `CASE WHEN fn03(first) = 1 OR
  fn03(last) = 1 THEN 1 ELSE 0 END`; routed bare uses became `r.name_missing = 1 AND/OR
  ...` (2 AND, 2 OR occurrences; the existing `NOT (r.name_missing = 1)` was already
  valid).
- **Validation + Pty helper15 junk args — booleans passed to NUMBER(1) params.**
  `fn_snow_helper15_common` takes `p_first_junk`/`p_last_junk` as NUMBER(1); the mirror
  passed `jf.NAME IS NOT NULL, jl.NAME IS NOT NULL`. Split: `CASE WHEN jf.NAME IS NOT
  NULL THEN 1 ELSE 0 END, CASE WHEN jl.NAME IS NOT NULL THEN 1 ELSE 0 END` (both files).
- **Alt_Id `ssn_exception_code` — same ANDCASE mistranslation.** Snowflake original:
  `IFF(a.ALT_ID_TP = '004' AND fn26(...):ssn_status::VARCHAR = 'Invalid',
  'Invalid_SSN', NULL)`. Split: `CASE WHEN a.ALT_ID_TP = '004' AND
  CAST(fn26(...).ssn_status AS VARCHAR2(4000)) = 'Invalid' THEN 'Invalid_SSN' ELSE NULL
  END`.
- **Bare boolean as a SELECT-list value → `CASE WHEN ... THEN 1 ELSE 0 END`:** Pty
  `uq_pty`, Alt_Id `uq_alt_id`, Phn `uq_phn`, Addr `uq_addr`, Rel `uq_rel`. (Other
  `uq_*`/`grp_*` in these files were already CASE-wrapped with comparison conditions and
  are valid — each was verified during generation, not assumed.)
- **Phn `is_email` — boolean inside NVL.** Snowflake original:
  `NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE)`. Mirror: `NVL(s.PHONE_EMAIL_TYPE =
  'EADDRESS', 0)` — invalid. Split: `CASE WHEN s.PHONE_EMAIL_TYPE = 'EADDRESS' THEN 1
  ELSE 0 END` (3 occurrences, including 2 inside pkey/src_rowid computations, where it
  becomes `CASE ... END = 1`). Plus `NOT a.is_email` → `a.is_email = 0` (1×),
  `NOT d.is_email` → `d.is_email = 0` (1×), `NOT c.is_email AND` → `c.is_email = 0 AND`
  (4×), `c.is_email AND xe.EXCEPTION_CODE` → `c.is_email = 1 AND xe.EXCEPTION_CODE`
  (4×).
- **Rel `FROM VALUES` — invalid in Oracle.** Mirror: `CROSS JOIN (SELECT column1 AS
  RELATION_DIRECTION FROM VALUES ('From Child'), ('To Child')) d`. Split: `CROSS JOIN
  (SELECT 'From Child' AS RELATION_DIRECTION FROM DUAL UNION ALL SELECT 'To Child' FROM
  DUAL) d`.
- Reactivation Phn/Medicaid bodies were checked and are clean (single INSERT each,
  NOT EXISTS filters; Medicaid's `WHERE CASE ... END = 1` uses comparison conditions and
  is valid).

Fixes were applied with assertion-checked counts per file (17 fix rules, all matched).

## 6. Verification (all mechanical, all passing)

1. **INSERT-target mapping:** for each of the 9 original files, every INSERT target is
   written by exactly one discrete proc, and no discrete proc writes a target the original
   did not (see §2 table). Distinct targets across the workflow: 14 — C_S_ECI_PTY,
   C_S_ECI_PTY_RLE, C_S_ECI_PTY_RLE_ALT_ID, C_S_ECI_PTY_RLE_PHN, C_S_ECI_PTY_RLE_EADDR,
   C_S_ECI_PTY_RLE_ADDR, C_S_ECI_PTY_RLE_REL, EXC_STG_BAD_REC_MEMB, DQM_ADDRESS,
   STG_ECI_PTY_INACTIVE_LOG, STG_ECI_PTY_INACTIVE_STS, STG_ECI_D_FAMILY_ADDRESS,
   STG_ECI_D_FAMILY_PHONE, STG_ECI_D_MEDICAID.
2. **No Snowflake constructs in new files** (code-only scan, comments/strings stripped):
   zero hits for `$$`, `IFF(`, `DATEADD(`, `::`, `QUALIFY`, `EXECUTE AS CALLER`,
   `TIMESTAMP_NTZ`, `TO_VARCHAR`, `:P_` binds, `FROM VALUES`, `ANDCASE`/`ORCASE`,
   `EXECUTE IMMEDIATE ... TRUNCATE`.
3. **No helper code copied:** zero `CREATE OR REPLACE FUNCTION fn_snow_helper` in new
   files — helpers are only called.
4. **Parenthesis balance:** mask-aware (string- and comment-aware) scan clean in all 26
   files.
5. **WRK coverage:** every identifier in every writer's VALUES list and predicate exists
   in its prep's WRK column list.
6. **Prep column lists agree:** CREATE TABLE columns = INSERT column list = wrapping
   SELECT list, per prep (22 / 68 / 27 / 40 / 65 / 22 columns).
7. **Table discipline:** writers read only their WRK table (+ DUAL for the log call);
   preps never read their own WRK table.
8. **Counts:** 25 discrete procs + 1 chain script = 26 files; per-mapping counts in §2.

## 7. What is NOT verified (static work only)

No database connection was used. Not verified: compilation on a live Oracle database,
execution of any discrete proc, row-count parity against the v1 single-SP mirror or IDQ,
or the live-DB items already open on the v1 mirror (`func().attribute` in SQL statements,
table-function form, the VARCHAR2(4000) assumption, `''` vs NULL gaps) — the split
inherits those unchanged, because it reuses the mirror's expressions verbatim except for
§5. The chain script's `WHENEVER SQLERROR EXIT FAILURE` semantics assume SQL*Plus /
SQLcl-style execution, as in the v1 mirror's run scripts.
