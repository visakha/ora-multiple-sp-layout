# TTF split notes — REBUILT AT ASSEMBLY

> The original split-notes file for this workflow was lost when the shared
> staging directory was clobbered between worker completion and assembly
> (see ORA_MULTIPLE_SP_CHAIN.md, Assembly notes). This file was rebuilt at
> assembly from the verified generator output, the chain script, and the
> worker's delivery report. Target maps and WRK tables below were derived
> mechanically from the procedure code; the split rationale and quirks are
> the worker's own words, condensed.
>

## Per-mapping target map (each target written by exactly one discrete proc)

- Validation (4): stage -> WRK_TTF_VAL_ROUTED (21 cols); exc ->
  EXC_STG_BAD_REC_MEMB; log -> STG_TTF_PTY_INACTIVE_LOG; sts ->
  STG_TTF_PTY_INACTIVE_STS.
- Pty (4): stage -> WRK_TTF_PTY_ROUTED (56 cols); pty -> C_S_TTF_PTY; rle ->
  C_S_TTF_PTY_RLE; exc -> EXC_STG_BAD_REC_MEMB.
- Alt_Id (1): alt_id -> C_S_TTF_PTY_RLE_ALT_ID (whole mapping, already
  single-purpose, renamed only).
- Phn (3): stage -> WRK_TTF_PHN_ROUTED (20 cols); phn -> C_S_TTF_PTY_RLE_PHN;
  exc -> EXC_STG_BAD_REC_MEMB.

## Design

Each original multi-target mapping was one INSERT ALL over a shared CTE
pipeline. Each pipeline now runs once in a stage proc and lands in a work
table; writers are plain INSERT ... SELECT ... WHERE reads. No pipeline
logic is duplicated. Stage procs DELETE + INSERT their work table each run
(the tables are pre-existing install DDL — see ddl/04 — not created by the
procs); writers never write work tables. Only the Pty stage takes
parameters (the two BO-class params; the chain passes ('Indv', 'Member'),
the original defaults). Common helpers are called, never copied. No
address, email, or relationship mapping was invented for TTF.

## Split-induced normalizations (semantics-preserving)

- `uq_pty` (Pty) and `uq_phn` (Phn) were bare boolean expressions in the
  originals (Oracle 23ai BOOLEAN); a work-table column needs a concrete
  type, so the stage wraps each as `CASE WHEN (...) THEN 1 ELSE 0 END`.
  The condition is TRUE/FALSE only, never NULL, so downstream `= 1` tests
  behave exactly like the original INSERT ALL ... WHEN conditions. All
  other flags were already `CASE 1/0` and are verbatim.
- Each stage stamps `WRK.run_ts` from its own SYSTIMESTAMP (as each original
  stamped its own `l_run_ts`); writers use `WRK.run_ts` for row values, so
  all rows of one mapping still share one timestamp.

## Preserved quirks (not fixed)

No DD_DELETE of inactive STS, insert-only loads, the never-fed
phone-extension and language/suffix branches still generate nothing.

## Verification (worker, static only)

All 9 (mapping, target) pairs from the originals — cross-checked against
the Snowflake originals too, targets match exactly — are each written by
exactly one discrete proc. No Snowflake constructs in comment-stripped
code. Parenthesis balance clean (mask-aware scan) in every file. Stage
column counts match their SELECT item counts (21/21, 56/56, 20/20). Every
writer-referenced column exists in its work table's DDL. Chain script
order == fragment order (12 calls), all 12 files present.
