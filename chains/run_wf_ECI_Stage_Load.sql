-- ECI multiple-SP chain script: discrete single-purpose procedures, in chain order.
-- Each mapping runs prep first, then its writers. A failed step stops the script
-- (WHENEVER SQLERROR EXIT FAILURE): later steps run only if all earlier ones succeeded.
-- Source of order: run_wf_ECI_Stage_Load.sql (v1 mirror) for mappings, branch order within mappings.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_exc() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_log() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_sts() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_pty() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_pty_rle() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_exc() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr_load() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn_load() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid_load() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_alt_id() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_exc() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_phn() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_eaddr() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_exc() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_dqm() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_addr() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_exc() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_prep() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_rel() FROM DUAL;
SELECT PKG_ECI.sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_exc() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
