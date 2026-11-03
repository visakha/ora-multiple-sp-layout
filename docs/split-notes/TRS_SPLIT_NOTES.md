# TRS split notes — v1 single-SP procedures split into discrete procedures

Source: `~/workspace/v1_oracle_mirror/wf_TRS_Stage_Load_1_Ongoing/` and `wf_TRS_Stage_Load_TOA/` (already-translated Oracle versions of the bulky v1 procedures). Nothing was re-translated from Snowflake; the split preserves all logic, predicates, and order.

The 2 `fn_snow_helper01` files (`fn_snow_helper01_alt_id`, `fn_snow_helper01_phn`) are already single-purpose table functions. They are carried over unchanged into `wf_TRS_Stage_Load_1_Ongoing/` and are NOT chain steps, so they have no chain rows. Common helpers (`fn_snow_helperNN_common`) are called, never copied.

## Split rules applied

- One discrete procedure writes exactly one table (one C_S_* target, one work table, or the exception table `EXC_STG_BAD_REC_MEMB`).
- A build procedure (`*_build`) materializes the original driving query into a work table `WRK_<mapping>_<step>` (DROP-if-exists + CTAS through `EXECUTE IMMEDIATE` with bind variables). Target procedures then read only that work table. No logic is duplicated across procedures.
- A block that writes nothing is folded into the consuming procedure (no such block needed a separate procedure in TRS; all driving-query CTEs live in the build procedure).
- Naming: `<orig_function_name>_<step_slug>`, step slug lowercase and short. All discrete procedures are Oracle FUNCTIONS, `AUTHID CURRENT_USER`, `RETURN VARCHAR2` status, taking only the parameters their block needs (build procedures take the original mapping parameters; target procedures take none — every value they need is in the work table).
- Every discrete procedure logs through `fn_snow_helper36_common` and COMMITs on success, exactly as the original mains did. The build procedure counts its rows with `COUNT(*)` after the CTAS (SQL%ROWCOUNT is not meaningful after DDL).
- The build procedure stamps `l_run_ts` once and stores it in the work table, so all target procedures of one mapping share the original single-timestamp semantics.
- Re-run semantics are UNCHANGED from v1 (not improved): `uq_*` flags are computed at build time against pre-write target state, so a re-run skips already-written target rows; EXC branches carry only run-internal `ROW_NUMBER` uniqueness, so EXC rows would duplicate on re-run exactly as in v1 (v1 EXC has no NOT EXISTS guard). This is preserved deliberately, not fixed silently.

## sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing (seq1=1, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_OnGoing`. Kind: multi.
- New work table: `WRK_TRS_PTYONGOING_BOTH` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty`
  - `C_S_TRS_PTY_RLE` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle`
  - `STG_TRS_VALID_MEMBERS` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1 (seq1=2, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Deactivation_1`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `STG_TRS_DEACTIVED_MEMBERS` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA (seq1=3, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_TOA`. Kind: multi.
- New work table: `WRK_TRS_TOA_KEYED` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_TOA` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem (seq1=4, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem`. Kind: multi.
- New work table: `WRK_TRS_REL1_BOTH` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_REL` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 (seq1=5, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `STG_TRS_DEACTIVATED_RELATIONSHIPS` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP (seq1=6, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP`. Kind: multi.
- New work table: `WRK_TRS_REL2_BOTH` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_REL_PROV` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr (seq1=7, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr`. Kind: multi.
- New work table: `WRK_TRS_PHN_ALL` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_PHN` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn`
  - `C_S_TRS_PTY_RLE_EADDR` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw (seq1=8, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_MNG_ATTR` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing (seq1=9, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_MNG_ATTR` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm (seq1=10, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Nm`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_NM` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id (seq1=11, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Alt_Id`. Kind: multi.
- New work table: `WRK_TRS_ALTID_ROUTED` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_ALT_ID` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln (seq1=12, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Pty_Rle_Pln`. Kind: multi.
- New work table: `WRK_TRS_PLN_PLANNED` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `C_S_TRS_PTY_RLE_PLN` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Addr_1 (seq1=13, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Addr_1`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `STG_TRS_D_UNQ_ADDR` → `sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr`

## sp_snow_main_m_Tgt_C_S_TRS_Addr_2 (seq1=14, wf_TRS_Stage_Load_1_Ongoing)

- Mapping: `m_Tgt_C_S_TRS_Addr_2`. Kind: multi.
- New work table: `WRK_TRS_ADDR2_SCORED` — holds the driving query output (all CTE stages plus the final SELECT with computed columns) so the target procedures can each read one table instead of duplicating the query.
- Original INSERT targets → discrete procedure:
  - `DQM_ADDRESS` → `sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm`
  - `C_S_TRS_PTY_RLE_ADDR` → `sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr`
  - `EXC_STG_BAD_REC_MEMB` → `sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc`

## sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA (seq1=1, wf_TRS_Stage_Load_TOA)

- Mapping: `m_Tgt_C_S_TRS_Stg_TOA`. Kind: single.
- No new work table: single INSERT, statement verbatim.
- Original INSERT targets → discrete procedure:
  - `C_S_LU_TOA` → `sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa`

## Things that could not be split cleanly

- EXC branches combined into one procedure per mapping: the original `INSERT ALL` wrote `EXC_STG_BAD_REC_MEMB` from several branches with different column lists. The discrete EXC procedure unions them over the superset column list (first-appearance order), padding missing columns with NULL. Splitting one EXC procedure per branch would have produced several writers of the same table and hidden the mapping-level exception picture; the union keeps the rule "one procedure writes one table" while preserving every branch predicate and value.
- TOA EXC union type harmonization: branch 1 (Bad_Value) puts `EDG_NUM` (NUMBER) into `SRC_SYS_ID_2` while branch 2 (dates-reversed) puts `pty_rle_fk` (VARCHAR2, e.g. `123|Member`, not number-convertible). The union therefore wraps branch 1 as `TO_CHAR(EDG_NUM)`. All other EXC unions were checked column-by-column and needed no conversion.
- Build procedures use `EXECUTE IMMEDIATE` with a literal CTAS statement (the only dynamic SQL in the package). This is required because Oracle has no other way to materialize a query into a new table from inside a procedure without DDL; the statement text is fixed at generation time, not built from inputs, and all PL/SQL values enter as bind variables.
- Chain order note: `Pty_OnGoing` (seq1=1) runs before `Pty_Deactivation_1` (seq1=2), exactly as in the original run script, so the ongoing loader's deactivation filter reads the prior run's `STG_TRS_DEACTIVED_MEMBERS`. This ordering quirk is preserved, not reordered.
