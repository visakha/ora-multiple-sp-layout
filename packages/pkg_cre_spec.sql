-- CRE discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_CRE AUTHID CURRENT_USER AS
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_routed() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_named() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_members() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_ranked() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq2() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_flat(P_RLE_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Member',
    P_DEFAULT_NONUS_STATE_CD IN VARCHAR2 DEFAULT '99') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_keyed(P_PHYSICAL_ADDR_TYPE_CD IN VARCHAR2 DEFAULT '002',
    P_DEFAULT_TX_STATE_CD IN VARCHAR2 DEFAULT '48',
    P_COUNTY_CD_NONTX IN VARCHAR2 DEFAULT '996',
    P_COUNTYCD_DEFAULTALL IN VARCHAR2 DEFAULT '998',
    P_RLE_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Member') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_mrg() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_fname() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_lname() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_pty() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_rle() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_gender() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_suffix() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ethnicity() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_race() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_addr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_addr() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_phn() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_phone() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_care() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_medicaid() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_medicaid() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_ssn() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ssn() RETURN VARCHAR2;
END PKG_CRE;
/
