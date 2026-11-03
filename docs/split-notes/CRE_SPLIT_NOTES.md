# CRE split notes — REBUILT AT ASSEMBLY

> The original split-notes file for this workflow was lost when the shared
> staging directory was clobbered between worker completion and assembly
> (see ORA_MULTIPLE_SP_CHAIN.md, Assembly notes). This file was rebuilt at
> assembly from the verified generator output, the chain script, and the
> worker's delivery report. Target maps and WRK tables below were derived
> mechanically from the procedure code; the split rationale and quirks are
> the worker's own words, condensed.
>

## Source and method

Source (read-only): the verified v1 Oracle mirror file
`sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients.sql` — 562 lines, one INSERT ALL
fanning out from a 13-stage WITH chain. The split was done mechanically by
a generator script: stage query bodies and INSERT ALL branches were
extracted verbatim from that file, not re-translated or hand-transcribed.
Cross-checked against the Snowflake original: the Snowflake original has
the same 18 INSERT ALL branches, in the same order, to the same targets.

## The 26 procedures

8 pipeline stages (each writes exactly one work table): `routed` (snapshot
union + XREF/HMRG merge-history resolution, sets run_ts once) -> `named`
(helper15 name standardization) -> `members` (validity + end-dated flag) ->
`ranked` (REC_TYPE pick: VERSION_SEQ rank per CARE id, merge-care id, SSN
output) -> `dq` (gender/ethnicity/race/phone/alt-id enrichment) -> `dq2`
(helper34 address validation + phone code) -> `flat` (timeline, validated
address fields, exception lookups, alt-id types) -> `keyed` (keys, router
flags, constants, 30-char rowids, all dedup gates; 197 columns). Each stage
rebuilds its table via DROP-if-exists + CREATE TABLE AS inside q-quoted
dynamic SQL, so a chain re-run from the start is safe.

18 write procedures (one per original INSERT ALL branch, in original branch
order): `mrg` -> CRE_SRC_MRG; `pty` -> C_S_CRE_PTY; `rle` ->
C_S_CRE_PTY_RLE; `addr` -> C_S_CRE_PTY_RLE_ADDR; `phn` ->
C_S_CRE_PTY_RLE_PHN; `alt_care`, `alt_medicaid`, `alt_ssn` ->
C_S_CRE_PTY_RLE_ALT_ID; and 10 exception procedures (`exc_fname`,
`exc_lname`, `exc_gender`, `exc_suffix`, `exc_ethnicity`, `exc_race`,
`exc_addr`, `exc_phone`, `exc_medicaid`, `exc_ssn`) ->
EXC_STG_BAD_REC_MEMB. Each writes exactly one table, reading only
WRK_CRE_KEYED with its original predicate.

Note on the counting rule: "exactly one procedure" holds per original
branch, not per target table — EXC and ALT_ID branches are distinct checks /
id types, so they are separate procedures by design; no procedure writes
more than one table and no branch is left without one.

## Parameters, run timestamp, atomicity, re-runs

- Only `flat` (2 params) and `keyed` (5 params) take parameters; all other
  procedures take none. The chain script passes original defaults
  (`flat`: Member, 99; `keyed`: 002, 48, 996, 998, Member); callers may
  override by calling stages directly.
- Run timestamp: set once by `routed` from SYSTIMESTAMP and carried as a
  column through every work table — no per-procedure drift, matching the
  original's single `l_run_ts`. End-dated `last_update` (run ts - 1h) is
  computed downstream from that column.
- Folded, not split: lookup CTEs (helper40-47 table functions) and the
  alt-id type lookup are folded into their consuming stages (pure lookups,
  no writes). The original's helper36 summary line is not reproduced — each
  write procedure returns its own rowcount instead.
- Atomicity: target writes stay uncommitted until the chain's single
  COMMIT; a write failure rolls its step back. Pipeline DROP + CREATE TABLE
  AS commits work tables only (Oracle DDL implicit commit) — scratch
  tables, rebuilt every run, never target data.
- Re-runs: gated branches insert nothing new on re-run (gates computed in
  `keyed` against pre-run target state); unguarded exception branches
  (gender, suffix, ethnicity, race, address, phone) duplicate on re-run,
  exactly as re-running the original would. The chain is not idempotent for
  those branches.

## Live-DB items (unproven, same class as the v1 mirror)

CREATE TABLE AS must infer helper result-object column types (`nm`, `gd`,
`ci`, `md`, `sn`, `av`) — fallback is scalar extraction in the producing
stage; plus the inherited v1 caveats (`func().attribute`, VARCHAR2(4000)
assumption, `''` vs NULL gaps, translator booleanization artifacts copied
verbatim).

## Verification (worker, static only)

Branch coverage: 18 branches extracted, 18 write procedures, targets
asserted in order against the branch list. No Snowflake constructs in
procedure code (after stripping strings/comments). Parenthesis balance
clean in all 27 files (wrapper and q-quoted query text checked separately).
Work-table wiring: each stage consumes exactly the previous stage's table;
`routed` consumes staging/hub tables only; all 18 writes consume only
WRK_CRE_KEYED. Column-set check: star-expansion through the original CTE
chain resolves WRK_CRE_KEYED to 197 columns with nothing unresolved, and
every column referenced by all 18 write procedures (select lists and
predicates) resolves to one of them.
