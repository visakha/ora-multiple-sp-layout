-- Discrete chain for workflow wf_WIC_Stage_Load (v1 multi-SP layout).
-- Install order: common/ helpers first, then these files. WRK_* tables are created
-- at run time by the routed/scored procs (DROP + CTAS); no pre-DDL is needed.
-- Params use the original defaults; pass explicit values on the routed/scored calls
-- to override. Recovery: resume a failed mapping from its routed/scored proc,
-- never by re-running a single writer (writers are not idempotent: uq_* flags in
-- the WRK snapshot were computed pre-insert).
--
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_routed() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_exc() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_log() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_sts() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_routed() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_pty() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_rle() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_exc() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_scored() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_dqm() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_addr() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_exc() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_routed() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_phn() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_exc() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_eaddr() FROM DUAL;
SELECT PKG_WIC.sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id_alt() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
