-- WIC discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_WIC AS

    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_routed() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Validation';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_WIC_VAL_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_WIC_VAL_ROUTED AS SELECT *
      FROM (
        WITH
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        sts AS (    -- Lookup_STG_WIC_PTY_INACTIVE_STS (any row)
            SELECT SRC_KEY, DEACTIVATION_STS FROM (SELECT i.SRC_KEY, i.DEACTIVATION_STS, ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) AS __qual_rn FROM STG_WIC_PTY_INACTIVE_STS i
             WHERE i.ROWID_SYSTEM = 'WIC'
           ) WHERE __qual_rn = 1
        ),
        xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'WIC')
            SELECT PKEY_SRC_OBJECT, HUB_STATE_IND FROM (SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND, ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) AS __qual_rn FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'WIC'
           ) WHERE __qual_rn = 1
        ),
        enriched AS (
            SELECT v.SOURCE_TABLE, v.ID, v.FIRST_NAME, v.LAST_NAME, v.MIDDLE_NAME, v.DOB, v.DATEKEY, v.LOAD_DATE,
                   v.PTY_SRC_KEY,
                   sts.DEACTIVATION_STS AS deactivation_sts,
                   xref.HUB_STATE_IND   AS hub_state_ind,
                   PKG_COMMON.fn_snow_helper15_common(v.FIRST_NAME, v.MIDDLE_NAME, v.LAST_NAME,
                       TRIM(NVL(v.FIRST_NAME, '') || CASE WHEN v.MIDDLE_NAME IS NOT NULL THEN ' ' || TRIM(v.MIDDLE_NAME) ELSE '' END
                            || ' ' || NVL(LTRIM(v.LAST_NAME), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
              FROM V_WIC_ETL_SRC v
              LEFT JOIN sts  ON sts.SRC_KEY = v.PTY_SRC_KEY
              LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = v.PTY_SRC_KEY
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRST_NAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LAST_NAME)) AND (jl.IS_LAST_JUNK = 1)
        ),
        named AS (
            SELECT n.*,
                   CAST(n.nm.first_name AS VARCHAR2(4000))  AS std_first_name,
                   CAST(n.nm.middle_name AS VARCHAR2(4000)) AS std_mdl_name,
                   CAST(n.nm.last_name AS VARCHAR2(4000))   AS std_lst_name,
                   /* VALIDATION */ (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.first_name AS VARCHAR2(4000)))
                                     OR (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.last_name AS VARCHAR2(4000))) = 1)) AS name_missing
              FROM enriched n
        ),
        -- Rtr_Valid_Party + Exp_Invalid_PTY_NM
        routed AS (
            SELECT r.*,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'Missing_First_Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Missing_Last_Name' END  AS exc_code_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'First Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Last Name' END          AS exc_attribute_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN r.std_first_name
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN r.std_lst_name END       AS exc_attribute_value,
                   PKG_COMMON.fn_snow_helper02_common(r.hub_state_ind)                                        AS new_deactivation_sts
              FROM named r
        )
        SELECT r.*,
               ex.EXCEPTION_DESC     AS exc_desc_name,
               ex.EXCEPTION_TYPE     AS exc_type_name,
               'WIC'                 AS src_sys,
               :b1             AS run_ts,
               :b2            AS mapping_name,
               'Deactivation'        AS action_deactivation,
               'Reactivation'        AS action_reactivation,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE, r.exc_code_name
                                      ORDER BY r.DATEKEY DESC, r.ID) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE, r.exc_code_name
                                      ORDER BY r.DATEKEY DESC, r.ID) = 1) THEN 0 END AS uq_exc_name
          FROM routed r
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name
      )]'
        USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_WIC_VAL_ROUTED;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_WIC_VAL_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_routed;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (PERIOD_START_DATE, MAPPING_NAME, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, FIRST_NAME, MIDDLE_NAME,
                  LAST_NAME, RUN_DATE, SRC_SYS, SRC_SYS_ID_1, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE,
                  BIRTH_DATE)
        SELECT DATEKEY, mapping_name, exc_attribute_name, exc_attribute_value, std_first_name, std_mdl_name,
                    std_lst_name, run_ts, src_sys, PTY_SRC_KEY, exc_desc_name, exc_type_name, exc_code_name, DOB FROM WRK_WIC_VAL_ROUTED
         WHERE (name_missing = 1) AND (uq_exc_name = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_log() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (name_missing = 1) THEN
            INTO STG_WIC_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
            VALUES (PTY_SRC_KEY, src_sys, action_deactivation, run_ts)
        WHEN deactivation_sts IS NOT NULL AND NOT (name_missing = 1) THEN
            INTO STG_WIC_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
            VALUES (PTY_SRC_KEY, src_sys, action_reactivation, run_ts)
    SELECT * FROM WRK_WIC_VAL_ROUTED;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_WIC_PTY_INACTIVE_LOG', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_log;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_sts() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_WIC_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
        SELECT PTY_SRC_KEY, src_sys, new_deactivation_sts, run_ts FROM WRK_WIC_VAL_ROUTED
         WHERE (name_missing = 1) AND deactivation_sts IS NULL;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_WIC_PTY_INACTIVE_STS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation_inactive_sts;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_routed(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_WIC_PTY_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_WIC_PTY_ROUTED AS SELECT *
      FROM (
        WITH
        lkp_cv   AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_V_WIC_ETL_SRC + Lookup_STG_WIC_PTY_INACTIVE_STS + Flt_Remove_Inactive
        active AS (
            SELECT v.SOURCE_TABLE, v.DATEKEY, v.LOAD_DATE, v.ID, v.PTY_SRC_KEY, v.FIRST_NAME, v.LAST_NAME,
                   v.MIDDLE_NAME, v.DOB, v.GENDER, v.BIRTH_WT_LB, v.BIRTH_WT_OZ, v.LANGUAGE_CD, v.ETHNICITY,
                   v.RACE_WHITE_IND, v.RACE_AA_IND, v.RACE_ASIAN_IND, v.RACE_PI_IND, v.RACE_AN_IND
              FROM V_WIC_ETL_SRC v
             WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        dq AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper15_common(a.FIRST_NAME, a.MIDDLE_NAME, a.LAST_NAME,
                       TRIM(NVL(a.FIRST_NAME, '') || CASE WHEN a.MIDDLE_NAME IS NOT NULL THEN ' ' || TRIM(a.MIDDLE_NAME) ELSE '' END
                            || ' ' || NVL(LTRIM(a.LAST_NAME), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)        AS nm,
                   PKG_COMMON.fn_snow_helper17_common(a.GENDER, 'Indv', 'WIC')                            AS gd,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper16_common(a.DOB, 'Indv', 'WIC', :b1)  AS birth_exception_code,
                   et.MSTR_CODE_VALUE                                                          AS ethnicity_mstr,
                   PKG_COMMON.fn_snow_helper19_common(a.RACE_WHITE_IND, a.RACE_AA_IND, a.RACE_ASIAN_IND, a.RACE_PI_IND,
                                           a.RACE_AN_IND)                                      AS rc,
                   lg.MSTR_CODE_VALUE                                                          AS language_mstr
              FROM active a
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRST_NAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LAST_NAME)) AND (jl.IS_LAST_JUNK = 1)
              LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'WIC' AND et.SRC_CODE_VALUE = a.ETHNICITY
              LEFT JOIN lkp_cv lg ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = 'WIC' AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD
        ),
        dq2 AS (
            SELECT d.*,
                   CAST(d.nm.first_name AS VARCHAR2(4000))          AS std_first_name,
                   CAST(d.nm.middle_name AS VARCHAR2(4000))         AS std_mdl_name,
                   CAST(d.nm.last_name AS VARCHAR2(4000))           AS std_lst_name,
                   CAST(d.nm.full_name AS VARCHAR2(4000))           AS std_full_name,
                   CAST(d.nm.src_full_name AS VARCHAR2(4000))       AS std_src_full_name,
                   CAST(d.nm.prfx_name AS VARCHAR2(4000))           AS std_prfx_name,
                   CAST(d.gd.mdm_gender_code AS VARCHAR2(4000))     AS mdm_gender_code,
                   CAST(d.gd.exception_code AS VARCHAR2(4000))      AS gender_exception_code,
                   xg.EXCEPTION_DESC                 AS gender_exception_description,
                   xg.EXCEPTION_TYPE                 AS gender_exception_type,
                   /* BAD DATA */ CASE WHEN d.birth_exception_code IS NULL THEN d.DOB ELSE NULL END AS std_birth_date,
                   xb.EXCEPTION_DESC                 AS birth_exception_description,
                   xb.EXCEPTION_TYPE                 AS birth_exception_type,
                   xe.EXCEPTION_CODE                 AS ethnicity_exception_code,
                   xe.EXCEPTION_DESC                 AS ethnicity_exception_desc,
                   xe.EXCEPTION_TYPE                 AS ethnicity_exception_type,
                   CAST(d.rc.mdm_race_cd AS VARCHAR2(4000))         AS mdm_race_cd,
                   CAST(d.rc.src_race_ind_list AS VARCHAR2(4000))   AS src_race_ind_list,
                   xr.EXCEPTION_CODE                 AS race_exception_cd,
                   xr.EXCEPTION_DESC                 AS race_exception_desc,
                   xr.EXCEPTION_TYPE                 AS race_exception_type,
                   xl.EXCEPTION_CODE                 AS language_exception_code,
                   xl.EXCEPTION_DESC                 AS language_exception_desc,
                   xl.EXCEPTION_TYPE                 AS language_exception_type
              FROM dq d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = CAST(d.rc.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.language_mstr, 'Invalid_Language')
        ),
        routed AS (
            SELECT d.*,
                   TRIM(d.PTY_SRC_KEY)                                                    AS pkey_trim,
                   TRIM(d.PTY_SRC_KEY) || '|' || :b2                 AS rle_pkey,CASE WHEN d.gender_exception_description IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT' THEN 1 WHEN NOT (d.gender_exception_description IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT') THEN 0 END AS grp_gender,CASE WHEN d.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (d.birth_exception_code IS NOT NULL) THEN 0 END AS grp_birth,CASE WHEN d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT' THEN 1 WHEN NOT (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT') THEN 0 END AS grp_ethnicity,CASE WHEN d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT' THEN 1 WHEN NOT (d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT') THEN 0 END AS grp_race,CASE WHEN d.language_exception_code IS NOT NULL THEN 1 WHEN NOT (d.language_exception_code IS NOT NULL) THEN 0 END AS grp_language
              FROM dq2 d
        )
        SELECT r.*,
               1 /* TIMELINE: VERSION_SEQ hard-coded */         AS version_seq,
               1                                                 AS hub_state_ind,
               'WIC'                                             AS src_sys,
               :b3                                         AS run_ts,
               :b4                                        AS mapping_name,
               :b5                         AS pty_bo_class_cd,
               :b6                         AS rle_bo_class_cd,
               r.BIRTH_WT_OZ * 28.35                             AS birth_wght_grms,
               TO_CHAR(r.DOB, 'MM/DD/YYYY')                   AS dob_text,
               'Gender'                                          AS attr_gender,
               'Birth Date'                                      AS attr_birth,
               'Ethnicity_Cd'                                    AS attr_ethnicity,
               'Race_Cd'                                         AS attr_race,
               'Language_Cd'                                     AS attr_language,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DATEKEY DESC, r.ID) = 1
                AND xp.PKEY_SRC_OBJECT IS NULL)                  AS uq_pty,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATEKEY DESC, r.ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATEKEY DESC, r.ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_gender,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_birth,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID, r.ethnicity_exception_type,
                                               r.ethnicity_exception_code ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID, r.ethnicity_exception_type,
                                               r.ethnicity_exception_code ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_ethnicity,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_race,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID, r.language_exception_type,
                                               r.language_exception_code ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID, r.language_exception_type,
                                               r.language_exception_code ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_language
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY WHERE VERSION_SEQ = 1) xp
                 ON xp.PKEY_SRC_OBJECT = r.pkey_trim
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE WHERE VERSION_SEQ = 1) xr2
                 ON xr2.PKEY_SRC_OBJECT = r.rle_pkey
      )]'
        USING l_run_ts, P_RLE_BO_CLASS_CD_MEMBER, l_run_ts, c_mapping, P_PTY_BO_CLASS_CD_MEMBER, P_RLE_BO_CLASS_CD_MEMBER;
    SELECT COUNT(*) INTO l_rows FROM WRK_WIC_PTY_ROUTED;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_WIC_PTY_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_routed;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_pty() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_WIC_PTY (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND, PTY_BO_CLASS_CD,
                  BIRTH_WGHT_GRMS, PERIOD_START_DATE, CREATE_DATE, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD,
                  BIRTH_DT, SRC_RACE_CD, RACE_CD, ETHNCTY, SRC_ETHNCTY, PRFRD_LANG_CD, SRC_LAST_UPD_DT,
                  SRC_PRFRD_LANG_CD, SRC_FULL_NM)
        SELECT pkey_trim, version_seq, run_ts, pkey_trim, hub_state_ind, pty_bo_class_cd, birth_wght_grms,
                    DATEKEY, DATEKEY, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name,
                    mdm_gender_code, DOB, src_race_ind_list, mdm_race_cd, ethnicity_mstr, ETHNICITY, language_mstr,
                    DATEKEY, LANGUAGE_CD, std_src_full_name FROM WRK_WIC_PTY_ROUTED
         WHERE (uq_pty = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_pty;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_rle() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE (PKEY_SRC_OBJECT, SRC_ROWID, RLE_BO_CLASS_CD, PTY_FK, VERSION_SEQ, LAST_UPDATE_DATE, HUB_STATE_IND,
                  CREATE_DATE, PERIOD_START_DATE, SRC_LAST_UPD_DT)
        SELECT rle_pkey, rle_pkey, rle_bo_class_cd, pkey_trim, version_seq, run_ts, hub_state_ind, DATEKEY,
                    DATEKEY, DATEKEY FROM WRK_WIC_PTY_ROUTED
         WHERE (uq_rle = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY_RLE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_rle;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (grp_gender = 1) AND (uq_gender = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE, FIRST_NAME, MIDDLE_NAME,
                  LAST_NAME)
            VALUES (src_sys, gender_exception_type, gender_exception_code, gender_exception_description, attr_gender,
                    GENDER, mapping_name, PTY_SRC_KEY, ID, GENDER, DOB, run_ts, FIRST_NAME, MIDDLE_NAME, LAST_NAME)
        WHEN (grp_birth = 1) AND (uq_birth = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
                  GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
                  BIRTH_DATE)
            VALUES (src_sys, PTY_SRC_KEY, birth_exception_code, birth_exception_description, birth_exception_type,
                    run_ts, mapping_name, GENDER, attr_birth, ID, std_prfx_name, FIRST_NAME, LAST_NAME, MIDDLE_NAME,
                    dob_text, DOB)
        WHEN (grp_ethnicity = 1) AND (uq_ethnicity = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
                  SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
                  SRC_SYS_ID_2, ATTRIBUTE_VALUE)
            VALUES (run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
                    attr_ethnicity, GENDER, PTY_SRC_KEY, src_sys, FIRST_NAME, std_lst_name, std_mdl_name,
                    mapping_name, DOB, DATEKEY, ID, ETHNICITY)
        WHEN (grp_race = 1) AND (uq_race = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
                  MAPPING_NAME, ATTRIBUTE_VALUE)
            VALUES (ID, PTY_SRC_KEY, src_sys, race_exception_cd, race_exception_desc, race_exception_type, run_ts,
                    FIRST_NAME, std_mdl_name, std_lst_name, GENDER, DOB, attr_race, std_prfx_name, DATEKEY,
                    mapping_name, src_race_ind_list)
        WHEN (grp_language = 1) AND (uq_language = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, PERIOD_START_DATE)
            VALUES (src_sys, PTY_SRC_KEY, ID, language_exception_type, language_exception_code,
                    language_exception_desc, run_ts, FIRST_NAME, std_mdl_name, std_lst_name, std_birth_date,
                    GENDER, attr_language, LANGUAGE_CD, mapping_name, DATEKEY)
    SELECT * FROM WRK_WIC_PTY_ROUTED;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_scored(P_MEMBER_HIERARCHY_CODE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Addr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_WIC_ADDR_SCORED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_WIC_ADDR_SCORED AS SELECT *
      FROM (
        WITH
        lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_mc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper46_common())),
        -- Read_V_WIC_ETL_SRC + Exp_src + Exp_Build_Src_key + Lookup_STG_WIC_PTY_INACTIVE_STS + Fil_Inactive_recs
        active AS (
            SELECT v.SOURCE_TABLE, v.ID, v.FID, v.DATE_ADDRESS_VALID_FROM, v.ADDRESS1, v.ADDRESS2, v.CITY, v.COUNTY,
                   v.ZIP_CODE, v.PTY_SRC_KEY,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|002|' || NVL(LPAD(TO_CHAR(v.FID), 12, '0'), '') || '|'
                   || NVL(TRIM(UPPER(v.ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(v.ADDRESS2)), '') || '|'
                   || NVL(UPPER(v.CITY), '') || '||' || NVL(v.ZIP_CODE, '')                      AS pkey_src_object
              FROM V_WIC_ETL_SRC v
             WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- Exp_all_active + mplt_Global_Addr_Validation (state 'TX' passed in; lkp_State_Cd on 'TX')
        validated AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper34_common(a.ADDRESS1, a.ADDRESS2, a.CITY, 'TX', a.ZIP_CODE, 'US', st.MSTR_CODE_VALUE) AS av
              FROM active a
              LEFT JOIN lkp_cv st ON st.CODE_TYPE = 'STATE' AND st.SRC_SYS = 'WIC' AND st.SRC_CODE_VALUE = 'TX'
        ),
        flat AS (
            SELECT v.*,
                   CAST(v.av.delivery_address_line1 AS VARCHAR2(4000))          AS a_line1,
                   CAST(v.av.delivery_address_line2 AS VARCHAR2(4000))          AS a_line2,
                   CAST(v.av.city AS VARCHAR2(4000))                            AS a_city,
                   CAST(v.av.postcode_complete AS VARCHAR2(4000))               AS a_postcode_complete,
                   CAST(v.av.zip_cd_5 AS VARCHAR2(4000))                        AS a_zip_cd_5,
                   CAST(v.av.zip_cd_4_extn AS VARCHAR2(4000))                   AS a_zip_cd_4_extn,
                   CAST(v.av.country_iso2_char AS VARCHAR2(4000))               AS a_country,
                   CAST(v.av.mailability_score AS VARCHAR2(4000))               AS a_mailability_score,
                   CAST(v.av.match_code AS VARCHAR2(4000))                      AS a_match_code,
                   mc.DESCRIPTION                                AS a_match_code_description,
                   PKG_COMMON.fn_snow_helper04_common(CAST(v.av.status_info_result_percentage AS VARCHAR2(4000)), 2) AS a_result_pct,
                   CAST(v.av.address_type AS VARCHAR2(4000))                    AS a_address_type,
                   CAST(v.av.county_fips_cd AS VARCHAR2(4000))                  AS a_county_fips,
                   CAST(v.av.state_fips_cd AS VARCHAR2(4000))                   AS a_state_fips,
                   CAST(v.av.geocoding_latitude AS NUMBER(38, 6))        AS a_latitude,
                   CAST(v.av.geocoding_longitude AS NUMBER(38, 6))       AS a_longitude,
                   CAST(v.av.geocoding_status AS VARCHAR2(4000))                AS a_geocoding_status,
                   CAST(v.av.residential_delivery_indicator AS VARCHAR2(4000))  AS a_residential,
                   CAST(v.av.organization_name AS VARCHAR2(4000))               AS a_org_name,
                   CAST(v.av.organization_descriptor AS VARCHAR2(4000))         AS a_org_descriptor,
                   CAST(v.av.organization_department AS VARCHAR2(4000))         AS a_org_department,
                   CAST(v.av.building_complete AS VARCHAR2(4000))               AS a_building_complete,
                   CAST(v.av.building_name AS VARCHAR2(4000))                   AS a_building_name,
                   CAST(v.av.building_number AS VARCHAR2(4000))                 AS a_building_number,
                   CAST(v.av.sub_building_complete AS VARCHAR2(4000))           AS a_sub_building_complete,
                   CAST(v.av.sub_building_descriptor AS VARCHAR2(4000))         AS a_sub_building_descriptor,
                   CAST(v.av.early_warning_system_return_cd AS VARCHAR2(4000))  AS a_early_warning,
                   CAST(v.av.cass_error_code AS VARCHAR2(4000))                 AS a_cass_error,
                   CAST(v.av.dpv_confirmation AS VARCHAR2(4000))                AS a_dpv
              FROM validated v
              LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = CAST(v.av.status_info_match_code AS VARCHAR2(4000))
        ),
        -- exp_Score_and_Exception_details + exp_Address_Hold
        scored AS (
            SELECT f.*,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper05_common('002', f.a_mailability_score, f.a_match_code) AS score,
                   PKG_COMMON.fn_snow_helper06_common('002', f.a_mailability_score, f.a_match_code)   AS addr_issue_desc,
                   PKG_COMMON.fn_snow_helper07_common(f.a_line1, f.a_line2)                          AS hold_line1,
                   PKG_COMMON.fn_snow_helper08_common(f.a_line1, f.a_line2)                          AS hold_line2
              FROM flat f
        )
        SELECT s.*,
               '002'                                                         AS addr_tp,
               'US'                                                          AS src_cntry,
               'WIC'                                                         AS src_sys,
               :b1                                                     AS run_ts,
               :b2                                                    AS mapping_name,
               1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
               1                                                             AS hub_state_ind,
               NVL(s.PTY_SRC_KEY, '') || '|Member'                           AS pty_rle_fk,
               LPAD(TO_CHAR(s.ID), 10, '0')                               AS dqm_pty_src_key,
               'Primary'                                                     AS pref_lvl,
               NVL(TO_CHAR(s.ID), '') || '|' || NVL(TO_CHAR(s.FID), '') AS loc_idn,
               :b3                                      AS hierarchy_code,
               :b4                                        AS hm_rel_tp_cd,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN 'Address' ELSE NULL END           AS exc_attribute_name,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN NVL(s.ADDRESS1, '') || ' ' || NVL(s.ADDRESS2, '') || ' ' || NVL(s.CITY, '') || '  '
                   || NVL(s.ZIP_CODE, '') || '  US' ELSE NULL END                   AS exc_attribute_value,
               'Invalid_Address'                                             AS exc_code,
               'Invalid Address per Address Doctor'                          AS exc_desc,
               'Bad Value'                                                   AS exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object
                                       ORDER BY s.DATE_ADDRESS_VALID_FROM DESC, s.FID) = 1
                AND xa.PKEY_SRC_OBJECT IS NULL)                              AS uq_addr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.FID, s.SOURCE_TABLE
                                      ORDER BY s.DATE_ADDRESS_VALID_FROM DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.FID, s.SOURCE_TABLE
                                      ORDER BY s.DATE_ADDRESS_VALID_FROM DESC) = 1) THEN 0 END AS uq_addr_exc
          FROM scored s
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = s.pkey_src_object
      )]'
        USING l_run_ts, c_mapping, P_MEMBER_HIERARCHY_CODE, P_MEMBER_HM_REL_TP_CD;
    SELECT COUNT(*) INTO l_rows FROM WRK_WIC_ADDR_SCORED;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_WIC_ADDR_SCORED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_scored;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_dqm() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO DQM_ADDRESS (MLBLTY_SCR, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_STATE, SRC_PSTL_CD, SRC_CNTRY, SRC_COUNTY,
                  RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_PSTL_CD, RSLT_CNTRY, RSLT_COUNTY, COUNTY_FIPS, STATE_FIPS,
                  LATTD, LNGTD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_NM, ORG_DESC, ORG_DEPT, BLDG, SUB_BLDG,
                  ADDRDR_MTCH_CD, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
                  MDM_ADDR_TP, SRC_SYSTEM, ADDR_SRC_KEY, LOAD_DT, PTY_SRC_KEY, RSLT_STATE)
        SELECT a_mailability_score, ADDRESS1, ADDRESS2, CITY, NULL, ZIP_CODE, src_cntry, COUNTY,
                    a_line1, a_line2, a_city, a_postcode_complete, a_country, a_county_fips, a_county_fips,
                    a_state_fips, a_latitude, a_longitude, a_geocoding_status, a_residential, a_org_name,
                    a_org_descriptor, a_org_department, a_building_complete, a_sub_building_complete, a_match_code,
                    a_result_pct, a_address_type, a_early_warning, a_cass_error, a_dpv, addr_tp, src_sys,
                    pkey_src_object, run_ts, dqm_pty_src_key, a_state_fips FROM WRK_WIC_ADDR_SCORED;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert DQM_ADDRESS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_dqm;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_addr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_ADDR (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
                  VERSION_SEQ, UPDATED_BY, LAST_UPDATE_DATE, PREF_LVL, LOC_IDN, HM_REL_TP_CD, HUB_STATE_IND,
                  SRC_ROWID, USG_TP, HIERARCHY_CODE, ADDR_LN_1, ADDR_LN_2, SRC_LAST_UPD_DT, FLR_NUM, LCTN_CRDNT_DESC,
                  PSTL_BRCD, RGN_CD, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY,
                  SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT, EFF_END_DT, ADDR_TP, PTY_RLE_FK, CREATE_DATE, CREATOR,
                  PERIOD_REFERENCE_TIME, CITY, PSTL_CD, CNTRY_CD, VLDTN_MSG, LATTD, LNGTD, COUNTY, MLBLTY_SCR, STATE,
                  RSDNTL_DLVRY_IND, ORG_DESC, ADDR_TP_CD, ORG_NM, BLDNG_NM, GEOCD_STS_CD, SUB_BLDG_NM,
                  SUB_BLDG_DESC, BLDG_NMBR, PSTL_CD_EXT)
        SELECT pkey_src_object, NULL, NULL, NULL, NULL, DATE_ADDRESS_VALID_FROM, version_seq, mapping_name,
                    run_ts, pref_lvl, loc_idn, hm_rel_tp_cd, hub_state_ind, pkey_src_object, NULL, hierarchy_code,
                    hold_line1, hold_line2, DATE_ADDRESS_VALID_FROM, NULL, NULL, NULL, NULL, ADDRESS1, ADDRESS2, CITY,
                    COUNTY, NULL, src_cntry, ZIP_CODE, NULL, DATE_ADDRESS_VALID_FROM, NULL, addr_tp, pty_rle_fk,
                    DATE_ADDRESS_VALID_FROM, NULL, NULL, a_city, a_zip_cd_5, a_country, a_match_code, a_latitude,
                    a_longitude, a_county_fips, a_mailability_score, a_state_fips, a_residential, a_org_descriptor,
                    a_address_type, a_org_name, a_building_name, a_geocoding_status, a_sub_building_complete,
                    a_sub_building_descriptor, a_building_number, a_zip_cd_4_extn FROM WRK_WIC_ADDR_SCORED
         WHERE score = '100' AND (uq_addr = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY_RLE_ADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE,
                  ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE,
                  EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EXCEPTION_TYPE, ADDRESS_LINE_1, ADDRESS_LINE_2,
                  ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY,
                  SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
        SELECT src_sys, a_match_code, a_match_code_description, a_mailability_score, exc_attribute_name,
                    exc_attribute_value, mapping_name, addr_tp, DATE_ADDRESS_VALID_FROM, NULL, exc_code, exc_desc,
                    run_ts, exc_type, ADDRESS1, ADDRESS2, CITY, COUNTY, NULL, ZIP_CODE, NULL, src_cntry, ID, FID,
                    SOURCE_TABLE FROM WRK_WIC_ADDR_SCORED
         WHERE score = '40' AND (uq_addr_exc = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_routed() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_WIC_PHN_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_WIC_PHN_ROUTED AS SELECT *
      FROM (
        WITH
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())),
        -- Read_V_WIC_ETL_SRC + exp_Stage_Source_Attributes + exp_Phone_Email_Keys + fil_deactivated_status
        src AS (
            SELECT v.SOURCE_TABLE, v.ID, v.PTY_SRC_KEY, v.DATEKEY, v.FID, v.PHONE, v.EMAIL,
                   NVL(v.PTY_SRC_KEY, '') || '|Member'                                            AS pty_rle_fk,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|' || NVL(TO_CHAR(v.FID), '') || '|'
                   || NVL(TRIM(v.PHONE), '')                                                      AS phn_pkey,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|001|' || NVL(TO_CHAR(v.FID), '') || '|' || NVL(v.EMAIL, '')
                                                                                                  AS eaddr_pkey,
                   PKG_COMMON.fn_snow_helper23_common(v.PHONE)                                               AS std_phone,
                   CASE WHEN v.EMAIL IS NOT NULL THEN PKG_COMMON.fn_snow_helper22_common(v.EMAIL) ELSE NULL END               AS em
              FROM V_WIC_ETL_SRC v
             WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        checked AS (
            SELECT s.*,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper24_common(s.std_phone, 'WIC', '001', ar.NPA_ID, ar.SERVICE) AS phone_exception_code,
                   CAST(s.em.email_address AS VARCHAR2(4000))                                                   AS std_email
              FROM src s
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(s.std_phone, 1, 3)
        ),
        routed AS (
            SELECT c.*,
                   xp.EXCEPTION_DESC AS phone_exception_desc,
                   xe.EXCEPTION_CODE AS email_exception_code,
                   xe.EXCEPTION_DESC AS email_exception_desc,
                   xe.EXCEPTION_TYPE AS email_exception_type,CASE WHEN c.phone_exception_code IS NULL OR c.phone_exception_code = 'Missing_AreaCode' THEN 1 WHEN NOT (c.phone_exception_code IS NULL OR c.phone_exception_code = 'Missing_AreaCode') THEN 0 END AS grp_phone_good,CASE WHEN c.phone_exception_code IS NOT NULL THEN 1 WHEN NOT (c.phone_exception_code IS NOT NULL) THEN 0 END AS grp_phone_bad,CASE WHEN c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL THEN 1 WHEN NOT (c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL) THEN 0 END AS grp_email_good,CASE WHEN c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL THEN 1 WHEN NOT (c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL) THEN 0 END AS grp_email_bad
              FROM checked c
              LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = CAST(c.em.exception_code AS VARCHAR2(4000))
        )
        SELECT r.*,
               '1' /* TIMELINE: VERSION_SEQ */                          AS version_seq,
               1                                                         AS hub_state_ind,
               'WIC'                                                     AS src_sys,
               :b1                                                 AS run_ts,
               :b2                                                AS mapping_name,
               'Telephone'                                               AS phn_tp,
               '001'                                                     AS usg_tp,
               'Primary'                                                 AS pref_lvl,
               'Bad Value'                                               AS exc_type_bad_value,
               'Main Phone'                                              AS attr_phone,
               'Email'                                                   AS attr_email,
               '001'                                                     AS eaddr_addr_tp,
               'Active'                                                  AS eaddr_sts_cd,
               'Y'                                                       AS eaddr_is_vld,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.phn_pkey ORDER BY r.DATEKEY DESC, r.FID) = 1
                AND xph.PKEY_SRC_OBJECT IS NULL)                         AS uq_phn,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.eaddr_pkey ORDER BY r.DATEKEY DESC, r.FID) = 1
                AND xea.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.eaddr_pkey ORDER BY r.DATEKEY DESC, r.FID) = 1
                AND xea.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_eaddr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.FID, r.phone_exception_code
                                      ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.FID, r.phone_exception_code
                                      ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_phone_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.FID, r.email_exception_type,
                                               r.email_exception_code ORDER BY r.DATEKEY DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.FID, r.email_exception_type,
                                               r.email_exception_code ORDER BY r.DATEKEY DESC) = 1) THEN 0 END AS uq_email_exc
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
                 ON xph.PKEY_SRC_OBJECT = r.phn_pkey
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
                 ON xea.PKEY_SRC_OBJECT = r.eaddr_pkey
      )]'
        USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_WIC_PHN_ROUTED;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_WIC_PHN_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_routed;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_PHN (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, PTY_RLE_FK, PHN_TP,
                  USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, HUB_STATE_IND)
        SELECT phn_pkey, DATEKEY, version_seq, run_ts, phn_pkey, pty_rle_fk, phn_tp, usg_tp, std_phone, pref_lvl,
                    DATEKEY, hub_state_ind FROM WRK_WIC_PHN_ROUTED
         WHERE (grp_phone_good = 1) AND (uq_phn = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY_RLE_PHN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_phn;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (grp_phone_bad = 1) AND (uq_phone_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
                  MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE,
                  ATTRIBUTE_NAME, SRC_SYS_ID_2)
            VALUES (src_sys, phone_exception_code, phone_exception_desc, run_ts, std_phone, NULL, NULL, mapping_name,
                    PTY_SRC_KEY, exc_type_bad_value, usg_tp, DATEKEY, std_phone, attr_phone, FID)
        WHEN (grp_email_bad = 1) AND (uq_email_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME, EXCEPTION_TYPE,
                  PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2)
            VALUES (src_sys, email_exception_code, email_exception_desc, run_ts, EMAIL, mapping_name,
                    email_exception_type, DATEKEY, EMAIL, attr_email, PTY_SRC_KEY, FID)
    SELECT * FROM WRK_WIC_PHN_ROUTED;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_EADDR (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  HUB_STATE_IND, PTY_RLE_FK, ELEC_ADDR, USG_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, ADDR_TP)
        SELECT eaddr_pkey, DATEKEY, version_seq, run_ts, run_ts, eaddr_pkey, hub_state_ind, pty_rle_fk,
                    std_email, NULL, eaddr_sts_cd, eaddr_is_vld, DATEKEY, eaddr_addr_tp FROM WRK_WIC_PHN_ROUTED
         WHERE (grp_email_good = 1) AND (uq_eaddr = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY_RLE_EADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr_eaddr;


    FUNCTION sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id_alt() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_WIC_Pty_Rle_Alt_Id';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
-- transaction start removed: Oracle transactions are implicit
    -- Not performed: IDQ "truncate target table" of C_S_WIC_PTY_RLE_ALT_ID. This code base never deletes, truncates or drops (rows are only inserted).

    INSERT INTO C_S_WIC_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, SRC_ROWID, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE,
            ALT_ID_TP_FLTR, SRC_LAST_UPD_DT, STS_CD, PERIOD_START_DATE)
    SELECT pkey_src_object, __col1, __col2, pty_rle_fk, alt_id_tp, __col5, DATEKEY, __col7, alt_id_tp, __col9, __col10, __col11 FROM (SELECT x.pkey_src_object, NVL(TO_CHAR(x.ID), '') || '|' || x.alt_id_tp AS __col1, 1 /* TIMELINE: VERSION_SEQ */ AS __col2, x.pty_rle_fk, x.alt_id_tp, LPAD(TO_CHAR(x.ID), 12, '0') AS __col5, x.DATEKEY, l_run_ts AS __col7, x.alt_id_tp, x.DATEKEY /* IIF(IsNull(DATEKEY), DATEKEY, DATEKEY) */ AS __col9, 'Issued' AS __col10, x.DATEKEY /* TIMELINE */
       AS __col11, ROW_NUMBER() OVER (PARTITION BY x.pkey_src_object ORDER BY x.DATEKEY DESC NULLS LAST) AS __qual_rn FROM (SELECT v.ID, v.PTY_SRC_KEY, v.DATEKEY, v.SOURCE_TABLE,
                   NVL(v.PTY_SRC_KEY, '') || '|Member'                                    AS pty_rle_fk,
                   CASE WHEN v.SOURCE_TABLE = 'CLIENT' THEN '020' ELSE '021' END                           AS alt_id_tp,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|' || CASE WHEN v.SOURCE_TABLE = 'CLIENT' THEN '020' ELSE '021' END || '|'
                   || NVL(LPAD(TO_CHAR(v.ID), 12, '0'), '')                             AS pkey_src_object
              FROM V_WIC_ETL_SRC v) x
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = x.pkey_src_object
     -- Lookup_STG_WIC_PTY_INACTIVE_STS + Filter
     WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = x.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                          AND i.DEACTIVATION_STS IS NOT NULL)
       /* BAD DATA: unique key not yet in the table, first row per key in this run */
       AND xa.PKEY_SRC_OBJECT IS NULL
    ) WHERE __qual_rn = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_WIC_PTY_RLE_ALT_ID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id_alt;

END PKG_WIC;
/
