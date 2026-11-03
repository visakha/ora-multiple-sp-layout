-- Discrete-proc chain for wf_FSS_Stage_Load (split of the v1 single-SP Oracle mirror).
-- One discrete proc writes exactly one table. Each proc COMMITs its own work;
-- WHENEVER SQLERROR EXIT FAILURE stops the chain at the first failure.
-- Recovery: re-run from a mapping's *_src proc (it drops + recreates its WRK
-- snapshot), or resume from any consumer (its WRK snapshot persists).
-- Materializers are called with zero arguments: the original defaults apply.
-- To override a materializer parameter, pass it at that proc's call only.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_src() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_exc() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_log() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_sts() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_src() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_pty() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_rle() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_exc() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_src() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_dqm() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_addr() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_exc() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id_alt() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_src() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_eaddr() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_phn() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_exc() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_src() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_rel() FROM DUAL;
SELECT PKG_FSS.sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_exc() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
