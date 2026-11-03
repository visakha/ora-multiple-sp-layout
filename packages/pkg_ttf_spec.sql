-- TTF discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_TTF AUTHID CURRENT_USER AS
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_stage() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_log() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_sts() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_stage(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_pty() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_rle() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_exc() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_stage() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_phn() RETURN VARCHAR2;
    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_exc() RETURN VARCHAR2;
END PKG_TTF;
/
