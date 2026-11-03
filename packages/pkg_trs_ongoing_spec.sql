-- TRS Ongoing discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_TRS_ONGOING AUTHID CURRENT_USER AS
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_build(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DC_INDV_TBL_SRC        VARCHAR DEFAULT 'DC_INDV',
    P_MCI_TBL_SRC            VARCHAR DEFAULT 'MCI') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_build() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_build(P_INDV_ID_ALT_ID_TP IN VARCHAR2 DEFAULT '007') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_build(P_PCP_REL_TP IN VARCHAR2 DEFAULT '100') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_build() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr(P_ATTR_TP_AUTH_REP IN VARCHAR2 DEFAULT 'Auth_Rep_Flag') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm(P_MEMBER_NAME_TYPE_CODE IN VARCHAR2 DEFAULT '002') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_build() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_build() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_build(P_MEMBER_ROLE_TYPE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc() RETURN VARCHAR2;
    FUNCTION fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id(p_pkey_src_object_pty IN VARCHAR2,
    p_period_start_date IN TIMESTAMP,
    p_src_sys IN VARCHAR2,
    p_alt_id_val_member_id IN VARCHAR2,
    p_alt_id_val_ssn_num IN NUMBER,
    p_alt_id_val_medicaid_id IN VARCHAR2,
    p_alt_id_val_ns_client_id IN VARCHAR2,
    p_cv_ind IN VARCHAR2) RETURN T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID;
    FUNCTION fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr(p_period_start_date IN TIMESTAMP,
    p_pty_fk IN VARCHAR2,
    p_src_sys IN VARCHAR2,
    p_case_number IN VARCHAR2,
    p_usg_tp_primary IN VARCHAR2,
    p_phn_tp_primary IN VARCHAR2,
    p_phn_num_primary IN VARCHAR2,
    p_usg_tp_secondary IN VARCHAR2,
    p_phn_tp_secondary IN VARCHAR2,
    p_phn_num_secondary IN VARCHAR2,
    p_usg_tp_tertiary IN VARCHAR2,
    p_phn_tp_tertiary IN VARCHAR2,
    p_phn_num_tertiary IN VARCHAR2) RETURN T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR;
END PKG_TRS_ONGOING;
/
