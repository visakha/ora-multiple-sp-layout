-- TRS TOA discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_TRS_TOA AS

    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Stg_TOA';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_LU_TOA
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            HUB_STATE_IND, TOA_CD, TOA_LBL, TOA_DESC, MBR_PRG_CD, EFF_STRT_DT, EFF_END_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, NULL, NULL,
           1, NULL, l_run_ts, SUBSTR(UPDATE_USER_ID, 1, 50), CREATE_DT, 'admin', SUBSTR(pkey_src_object, 1, 30),
           1, pkey_src_object, SUBSTR(toa_lbl, 1, 100), SUBSTR(TOA_DESC, 1, 250), mbr_prg_cd, EFF_BEGIN_DT, EFF_END_DT
      FROM (
        WITH
        -- Lkp_LOOKUP_CODE_VALUE_TOA / Lkp_LOOKUP_CODE_VALUE_MBR_PGM (SQL override by code type; any row per label)
        lkp_toa AS (
            SELECT MSTR_REF_LABEL, MSTR_REF_CODE FROM (SELECT l.MSTR_REF_LABEL, l.MSTR_REF_CODE, ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
             WHERE l.CODE_TYPE = 'TOA'
            ) WHERE __qual_rn = 1
        ),
        lkp_pgm AS (
            SELECT MSTR_REF_LABEL, MSTR_REF_CODE FROM (SELECT l.MSTR_REF_LABEL, l.MSTR_REF_CODE, ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
             WHERE l.CODE_TYPE = 'MEMBER_PRG'
            ) WHERE __qual_rn = 1
        ),
        -- Read_STG_TRS_D_LU_TOA -> Exp_Src_TRS_Input -> lookups -> Exp_TOA_Load
        keyed AS (
            SELECT s.*,
                   SUBSTR(lt.MSTR_REF_CODE, 1, 10) AS pkey_src_object,   -- string(10) port
                   lt.MSTR_REF_LABEL               AS toa_lbl,
                   SUBSTR(lp.MSTR_REF_CODE, 1, 9)  AS mbr_prg_cd         -- string(9) port
              FROM STG_TRS_D_LU_TOA s
              LEFT JOIN lkp_toa lt ON lt.MSTR_REF_LABEL = s.TOA_CODE
              LEFT JOIN lkp_pgm lp ON lp.MSTR_REF_LABEL = s.PROGRAM_CODE
        )
        SELECT * FROM (SELECT k.*, ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object
                                       ORDER BY k.UPDATE_DT DESC NULLS LAST, k.UNIQUE_TRANS_ID DESC NULLS LAST) AS __qual_rn FROM keyed k
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_LU_TOA WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = k.pkey_src_object
         /* BAD DATA: Oracle rejects a NULL key */
         WHERE k.pkey_src_object IS NOT NULL
           /* BAD DATA: unique keys Snowflake does not enforce */
           AND xa.PKEY_SRC_OBJECT IS NULL
        ) WHERE __qual_rn = 1
      );
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert (C_S_LU_TOA)', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA_lu_toa;

END PKG_TRS_TOA;
/
