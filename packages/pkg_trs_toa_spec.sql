-- TRS TOA discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_TRS_TOA AUTHID CURRENT_USER AS
    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa() RETURN VARCHAR2;
END PKG_TRS_TOA;
/
