-- Chain script for wf_TRS_Stage_Load_1_Ongoing: discrete single-purpose procedures in chain order.
-- Mirrors the original run script order; each mapping expands into its discrete procs.
-- Each proc commits on success; the script stops on the first failure.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_build() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr() FROM DUAL;
SELECT PKG_TRS_ONGOING.sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
