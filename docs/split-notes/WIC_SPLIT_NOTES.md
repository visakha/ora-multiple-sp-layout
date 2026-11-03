# WIC split notes — REBUILT AT ASSEMBLY

> The original split-notes file for this workflow was lost when the shared
> staging directory was clobbered between worker completion and assembly
> (see ORA_MULTIPLE_SP_CHAIN.md, Assembly notes). This file was rebuilt at
> assembly from the verified generator output, the chain script, and the
> worker's delivery report. Target maps and WRK tables below were derived
> mechanically from the procedure code; the split rationale and quirks are
> the worker's own words, condensed.
>

## Per-mapping target map (each target written by exactly one proc)

- Validation (4): routed -> WRK_WIC_VAL_ROUTED; exc -> EXC_STG_BAD_REC_MEMB
  (name_missing=1 AND uq_exc_name=1); inactive_log ->
  STG_WIC_PTY_INACTIVE_LOG (deactivation + reactivation branches);
  inactive_sts -> STG_WIC_PTY_INACTIVE_STS.
- Pty (4): routed -> WRK_WIC_PTY_ROUTED; pty -> C_S_WIC_PTY; rle ->
  C_S_WIC_PTY_RLE; exc -> EXC_STG_BAD_REC_MEMB (5 branches: gender, birth,
  ethnicity, race, language).
- Addr (4): scored -> WRK_WIC_ADDR_SCORED; dqm -> DQM_ADDRESS (every active
  address); addr -> C_S_WIC_PTY_RLE_ADDR; exc -> EXC_STG_BAD_REC_MEMB.
- Phn/EAddr (4): routed -> WRK_WIC_PHN_ROUTED; phn -> C_S_WIC_PTY_RLE_PHN;
  exc -> EXC_STG_BAD_REC_MEMB (bad-phone + bad-email branches); eaddr ->
  C_S_WIC_PTY_RLE_EADDR.
- Alt_Id (1): already atomic, renamed only, body byte-identical ->
  C_S_WIC_PTY_RLE_ALT_ID.

## Design

Each bulky mapping was a single INSERT ALL whose branches shared one
computed query: one routed/scored proc computes the query once into a
snapshot table (DROP swallowing only ORA-00942 + CTAS, PL/SQL variables
replaced by numbered bind placeholders `:b1`, `:b2`, … each used exactly
once), then one writer proc per target table reads it. This preserves the
original's snapshot semantics (all branches see pre-run state, including
the `uq_*` anti-joins against targets). Writers are single-INSERT...SELECT
for single-branch targets, or INSERT ALL with the original branches
verbatim for multi-branch targets (Validation log, Pty exc, Phn exc).

## Not split cleanly / preserved quirks

- Inherited latent boolean issues, NOT fixed, carried over unchanged
  (fixing them here would diverge the split from its source): Validation
  `name_missing` is a `(NUMBER OR condition)` expression and Pty `uq_pty`
  is a bare boolean SELECT-list column — both invalid in Oracle SQL and
  both will fail the affected CTAS at live-compile time. Fix shape for the
  live-compile pass, mirroring the already-CASE-wrapped siblings:
  `CASE WHEN <cond> THEN 1 ELSE 0 END`. Apply identically in the v1 mirror
  and here or the trees diverge.
- INSERT ALL atomicity is gone: writers are separate transactions. Recovery
  rule: resume a failed mapping from its routed/scored proc, never by
  re-running a single writer.
- Writers are not idempotent (`uq_*` flags were computed pre-insert), and
  full-chain reruns duplicate EXC_STG_BAD_REC_MEMB /
  STG_WIC_PTY_INACTIVE_LOG rows — a preserved original quirk (no NOT EXISTS
  guard existed), as is DQM_ADDRESS appending on rerun.
- Logging is now per-proc (17 helper36 lines instead of 5 combined
  per-mapping lines); WRK DDL commits; WRK tables persist after a run and
  are recreated by the next run's routed proc; WRK tables carry object-typed
  columns (`nm`, `gd`, `rc`, `em`), so the schema-level object types must be
  installed first.
- Verification (worker, static only, 250 checks, 0 failures): every original
  INSERT target written by exactly one discrete proc per mapping; every
  writer writes exactly one table; every WRK CTAS query restores
  byte-identical to the original query when bind placeholders are replaced;
  no unbound variables; no q-quote delimiter collision; every writer branch
  matches the original after whitespace normalisation; no Snowflake
  constructs in code (remaining mentions are inside preserved source
  comments only); parenthesis balance clean; function name matches
  filename; chain script order matches the fragment (17 calls).
