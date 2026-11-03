-- Chain script for wf_TRS_Stage_Load_TOA: discrete single-purpose procedures in chain order.
-- Mirrors the original run script order; each mapping expands into its discrete procs.
-- Each proc commits on success; the script stops on the first failure.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_TRS_TOA.sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
