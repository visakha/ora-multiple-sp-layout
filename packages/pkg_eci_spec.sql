-- ECI discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_ECI AUTHID CURRENT_USER AS
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_log() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_sts() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_prep(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_pty() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_pty_rle() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr_load() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn_load() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid_load(P_TEST_LOOKUP_RESULT IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_prep() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_prep() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_prep(P_MEMBER_HIERARCHY_CODE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_dqm() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_addr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_prep() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_rel() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_exc() RETURN VARCHAR2;
END PKG_ECI;
/
