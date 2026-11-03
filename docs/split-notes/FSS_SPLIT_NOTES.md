# FSS split notes — REBUILT AT ASSEMBLY

> The original split-notes file for this workflow was lost when the shared
> staging directory was clobbered between worker completion and assembly
> (see ORA_MULTIPLE_SP_CHAIN.md, Assembly notes). This file was rebuilt at
> assembly from the verified generator output, the chain script, and the
> worker's delivery report. Target maps and WRK tables below were derived
> mechanically from the procedure code; the split rationale and quirks are
> the worker's own words, condensed.
>

## Per-mapping target map (each target written by exactly one discrete proc)

- Validation (4): `*_src` -> WRK_FSS_VAL_SRC; `_exc` -> EXC_STG_BAD_REC_MEMB
  (grp_invalid_party_name=1 AND uq_exc_name=1); `_log` ->
  STG_FSS_PTY_INACTIVE_LOG (grp_deactivation=1); `_sts` ->
  STG_FSS_PTY_INACTIVE_STS (2 branches: new deactivation + reactivation,
  kept as one INSERT ALL).
- Pty (4): `*_src` -> WRK_FSS_PTY_SRC (params P_PTY_BO_CLASS_CD_MEMBER='Indv',
  P_RLE_BO_CLASS_CD_MEMBER='Member'; chain calls zero-arg); `_pty` ->
  C_S_FSS_PTY (uq_pty=1); `_rle` -> C_S_FSS_PTY_RLE (uq_rle=1); `_exc` ->
  EXC_STG_BAD_REC_MEMB (6 branches: gender, birth, ethnicity, race,
  language, suffix).
- Addr (4): `*_src` -> WRK_FSS_ADDR_SRC (params
  P_MEMBER_HIERARCHY_CODE='Member', P_MEMBER_HM_REL_TP_CD='Member Addr');
  `_dqm` -> DQM_ADDRESS (every row, WHEN 1); `_addr` ->
  C_S_FSS_PTY_RLE_ADDR (score='100' AND uq_addr=1); `_exc` ->
  EXC_STG_BAD_REC_MEMB (score='40' AND uq_addr_exc=1).
- Alt_Id (1): `_alt` -> C_S_FSS_PTY_RLE_ALT_ID, single INSERT verbatim, no
  WRK table (source used once).
- Phn_And_EAddr (4): `*_src` -> WRK_FSS_PHN_SRC; `_eaddr` ->
  C_S_FSS_PTY_RLE_EADDR (grp_email_good=1 AND uq_eaddr=1); `_phn` ->
  C_S_FSS_PTY_RLE_PHN (grp_phone_good=1 AND uq_phn=1); `_exc` ->
  EXC_STG_BAD_REC_MEMB (3 branches: email, phone, phone-ext).
- Rel (3): `*_src` -> WRK_FSS_REL_SRC; `_rel` -> C_S_FSS_PTY_RLE_REL
  (mstr_ref_code IS NOT NULL AND uq_rel=1); `_exc` -> EXC_STG_BAD_REC_MEMB
  (mstr_ref_code IS NULL AND uq_rel_exc=1).

## Why snapshots

Each original is one INSERT ALL over one shared source SELECT. Each
mapping's `*_src` proc materializes that SELECT once (DROP-if-exists + CTAS
via q-quoted dynamic SQL with `:bN` binds for `l_run_ts`, `c_mapping` and
the original params). Consumers read the snapshot and never re-evaluate the
source — the source anti-joins against the mapping's own targets must see
pre-insert state. Same-table multi-branch consumers stay as INSERT ALL
inside one proc. No pure-computation folding was needed: all CTE work lives
inside the source SELECTs.

## Not split cleanly / preserved semantics

- Per-proc COMMIT replaces per-mapping atomicity: a mid-mapping failure
  leaves earlier procs committed.
- Re-runs are NOT idempotent for LOG/EXC branches (uq guards are within-run
  only): reconcile/clean failed-attempt LOG/EXC rows before re-running.
- DQM_ADDRESS is APPEND: never re-execute a succeeded DQM step.
- Materializers need CREATE/DROP TABLE privilege.
- CTAS output column names were hand-checked against CTE column lists (no
  collisions) but only a first live run proves derivation — a duplicate
  would fail loudly at CTAS, not corrupt silently.
- Verification (worker, static only): all 15 (mapping, target) pairs written
  by exactly one discrete proc; no Snowflake constructs in emitted code
  (one raw `IIF(` hit is a preserved source comment inside the Rel
  snapshot's dynamic SQL, comment-only); parenthesis balance clean in all 21
  files; all 22 original INSERT ALL branches, all 5 source SELECTs (binds
  reversed and compared) and the Alt_Id statement appear verbatim.
