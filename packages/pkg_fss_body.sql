-- FSS discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_FSS AS

    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_src() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Validation';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime / SYSTIMESTAMP()
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_sql CLOB;
BEGIN
    -- Drop any previous run's snapshot (Oracle DDL auto-commits).
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_FSS_VAL_SRC';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    -- Snapshot the shared source SELECT verbatim. PL/SQL variables
    -- are passed as binds (:bN) because dynamic SQL cannot see them.
    l_sql := q'[CREATE TABLE WRK_FSS_VAL_SRC AS SELECT *
      FROM (
        WITH
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_V_FSS_ETL_SRC (source filter; the commented-out testing filters are not applied)
        src AS (
            SELECT v.ID_CLIENT, v.PTY_SRC_KEY, v.SOURCE_TYPE, v.NM_FIRST, v.NM_LAST, v.NM_MIDDLE, v.DT_DOB,
                   v.DT_LAST_UPDATE, v.CLIENT_DTL__CAPXACTION, v.STG_UPDATE_DATE, v.LAST_INACTV_CLIENT_YN
              FROM V_FSS_ETL_SRC v
             WHERE (v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y' OR v.LAST_INACTV_CLIENT_YN = 'Y')
        ),
        sts AS (    -- Lookup_STG_FSS_PTY_INACTIVE_STS (any row)
            SELECT SRC_KEY, DEACTIVATION_STS FROM (SELECT i.SRC_KEY, i.DEACTIVATION_STS, ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) AS __qual_rn FROM STG_FSS_PTY_INACTIVE_STS i
             WHERE i.ROWID_SYSTEM = 'FSS'
           ) WHERE __qual_rn = 1
        ),
        xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'FSS'; blank-padded MDM column trimmed)
            SELECT PKEY_SRC_OBJECT, HUB_STATE_IND FROM (SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND, ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) AS __qual_rn FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'FSS'
           ) WHERE __qual_rn = 1
        ),
        -- Exp_ECI_Data_Load (sic) + lookups + mplt_Name_Standardization_Indv_Member
        enriched AS (
            SELECT s.*,
                   sts.DEACTIVATION_STS AS deactivation_sts,
                   xref.HUB_STATE_IND   AS hub_state_ind,
                   PKG_COMMON.fn_snow_helper15_common(s.NM_FIRST, s.NM_MIDDLE, s.NM_LAST,
                       TRIM(NVL(s.NM_FIRST, '') || CASE WHEN s.NM_MIDDLE IS NOT NULL THEN ' ' || TRIM(s.NM_MIDDLE) ELSE '' END
                            || ' ' || NVL(LTRIM(s.NM_LAST), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
              FROM src s
              LEFT JOIN sts  ON sts.SRC_KEY = s.PTY_SRC_KEY
              LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = s.PTY_SRC_KEY
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(s.NM_FIRST)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(s.NM_LAST)) AND (jl.IS_LAST_JUNK = 1)
        ),
        named AS (
            SELECT n.*,
                   CAST(n.nm.first_name AS VARCHAR2(4000))    AS std_first_name,
                   CAST(n.nm.middle_name AS VARCHAR2(4000))   AS std_mdl_name,
                   CAST(n.nm.last_name AS VARCHAR2(4000))     AS std_lst_name,
                   CAST(n.nm.src_full_name AS VARCHAR2(4000)) AS std_src_full_name,
                   /* VALIDATION */ (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.first_name AS VARCHAR2(4000)))
                                     OR (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.last_name AS VARCHAR2(4000))) = 1)) AS name_missing
              FROM enriched n
        ),
        -- Rtr_Valid_Party + Exp_Invalid_PTY_NM
        routed AS (
            SELECT r.*,
                   r.name_missing                                                          AS grp_invalid_party_name,CASE WHEN r.name_missing OR r.CLIENT_DTL__CAPXACTION = 'D' OR r.LAST_INACTV_CLIENT_YN = 'Y' THEN 1 WHEN NOT (r.name_missing OR r.CLIENT_DTL__CAPXACTION = 'D' OR r.LAST_INACTV_CLIENT_YN = 'Y') THEN 0 END AS grp_deactivation,
                   NVL(r.deactivation_sts IS NOT NULL AND NOT (r.name_missing = 1)
                       AND r.CLIENT_DTL__CAPXACTION <> 'D' AND r.LAST_INACTV_CLIENT_YN <> 'Y', 0) AS grp_reactivation,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'Missing_First_Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Missing_Last_Name' END    AS exc_code_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'First Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Last Name' END            AS exc_attribute_name,
                   PKG_COMMON.fn_snow_helper02_common(r.hub_state_ind)                                          AS new_deactivation_sts
              FROM named r
        )
        SELECT r.*,
               ex.EXCEPTION_DESC     AS exc_desc_name,
               ex.EXCEPTION_TYPE     AS exc_type_name,
               'FSS'                 AS src_sys,
               :b1             AS run_ts,
               :b2            AS mapping_name,
               'Deactivation'        AS action_deactivation,
               'Reactivation'        AS action_reactivation,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE,
                                               r.exc_code_name ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE,
                                               r.exc_code_name ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1) THEN 0 END AS uq_exc_name
          FROM routed r
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name
      )]';
    EXECUTE IMMEDIATE l_sql USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_FSS_VAL_SRC;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'materialize WRK_FSS_VAL_SRC', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_src;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (PERIOD_START_DATE, MAPPING_NAME, ATTRIBUTE_NAME, FIRST_NAME, MIDDLE_NAME, LAST_NAME, RUN_DATE,
                  SRC_SYS, SRC_SYS_ID_1, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE, BIRTH_DATE, ATTRIBUTE_VALUE) SELECT DT_LAST_UPDATE, mapping_name, exc_attribute_name, std_first_name, std_mdl_name, std_lst_name,
                    run_ts, src_sys, PTY_SRC_KEY, exc_desc_name, exc_type_name, exc_code_name, DT_DOB,
                    std_src_full_name FROM WRK_FSS_VAL_SRC WHERE (grp_invalid_party_name = 1) AND (uq_exc_name = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_log() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_FSS_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT) SELECT PTY_SRC_KEY, src_sys, action_deactivation, run_ts FROM WRK_FSS_VAL_SRC WHERE (grp_deactivation = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_FSS_PTY_INACTIVE_LOG', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_log;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_sts() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (grp_deactivation = 1) AND deactivation_sts IS NULL THEN
            INTO STG_FSS_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT) VALUES (PTY_SRC_KEY, src_sys, new_deactivation_sts, run_ts)
        WHEN (grp_reactivation = 1) THEN
            INTO STG_FSS_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT) VALUES (PTY_SRC_KEY, src_sys, action_reactivation, run_ts)
    SELECT * FROM WRK_FSS_VAL_SRC;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_FSS_PTY_INACTIVE_STS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation_sts;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_src(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime / SYSDATE
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_sql CLOB;
BEGIN
    -- Drop any previous run's snapshot (Oracle DDL auto-commits).
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_FSS_PTY_SRC';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    -- Snapshot the shared source SELECT verbatim. PL/SQL variables
    -- are passed as binds (:bN) because dynamic SQL cannot see them.
    l_sql := q'[CREATE TABLE WRK_FSS_PTY_SRC AS SELECT *
      FROM (
        WITH
        lkp_cv    AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_cv_any AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper42_common())),
        lkp_junk  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc   AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_V_FSS_ETL_SRC (source filter; the commented-out testing filter is not applied)
        src AS (
            SELECT v.SOURCE_TYPE, v.DT_LAST_UPDATE, v.PTY_SRC_KEY, v.ID_CLIENT, v.NM_FIRST, v.NM_LAST, v.NM_MIDDLE,
                   v.DT_DOB, v.CD_GENDER, v.LANGUAGE_CD, v.CD_HISPANIC, v.RACE_AN, v.RACE_ASIAN, v.RACE_AA,
                   v.RACE_WHITE, v.RACE_PI, v.CD_SUFFIX
              FROM V_FSS_ETL_SRC v
             WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y'
        ),
        -- Lookup_STG_FSS_PTY_INACTIVE_STS + Flt_Remove_Inactive
        active AS (
            SELECT s.*
              FROM src s
             WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = s.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- mapplets, step 1: lookups and rule functions
        dq AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper15_common(a.NM_FIRST, a.NM_MIDDLE, a.NM_LAST,
                       TRIM(NVL(a.NM_FIRST, '') || CASE WHEN a.NM_MIDDLE IS NOT NULL THEN ' ' || TRIM(a.NM_MIDDLE) ELSE '' END
                            || ' ' || NVL(LTRIM(a.NM_LAST), '')),
                       NULL, a.CD_SUFFIX, NULL, nsx.MSTR_CODE_VALUE,
                       jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)                                    AS nm,
                   PKG_COMMON.fn_snow_helper17_common(a.CD_GENDER, 'Indv', 'FSS')                              AS gd,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper16_common(a.DT_DOB, 'Indv', 'FSS', :b1)     AS birth_exception_code,
                   et.MSTR_CODE_VALUE                                                               AS ethnicity_mstr,
                   PKG_COMMON.fn_snow_helper19_common(a.RACE_WHITE, a.RACE_AA, a.RACE_ASIAN, a.RACE_PI, a.RACE_AN) AS rc,
                   lg.MSTR_CODE_VALUE                                                               AS language_mstr,
                   sx.MSTR_CODE_VALUE                                                               AS std_suffix,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper20_common(a.CD_SUFFIX, sx.MSTR_CODE_VALUE)       AS suffix_exception_code
              FROM active a
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.NM_FIRST)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.NM_LAST)) AND (jl.IS_LAST_JUNK = 1)
              -- lkp_V_Lookup_Sfx_Code_Value inside the name mapplet (CODE_TYPE 'SUFFIX')
              LEFT JOIN lkp_cv nsx ON nsx.CODE_TYPE = 'SUFFIX' AND nsx.SRC_SYS = 'FSS' AND nsx.SRC_CODE_VALUE = a.CD_SUFFIX
              LEFT JOIN lkp_cv et  ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'FSS' AND et.SRC_CODE_VALUE = a.CD_HISPANIC
              LEFT JOIN lkp_cv lg  ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = 'FSS' AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD
              -- rule_Suffix_Std's lkp_V_LOOKUP_CODE_VALUE (no code-type filter)
              LEFT JOIN lkp_cv_any sx ON sx.SRC_SYS = 'FSS' AND sx.SRC_CODE_VALUE = a.CD_SUFFIX
        ),
        -- mapplets, step 2: exception catalogue
        dq2 AS (
            SELECT d.*,
                   CAST(d.nm.first_name AS VARCHAR2(4000))                       AS std_first_name,
                   CAST(d.nm.middle_name AS VARCHAR2(4000))                      AS std_mdl_name,
                   CAST(d.nm.last_name AS VARCHAR2(4000))                        AS std_lst_name,
                   CAST(d.nm.full_name AS VARCHAR2(4000))                        AS std_full_name,
                   CAST(d.nm.src_full_name AS VARCHAR2(4000))                    AS std_src_full_name,
                   CAST(d.nm.prfx_name AS VARCHAR2(4000))                        AS std_prfx_name,
                   CAST(d.gd.mdm_gender_code AS VARCHAR2(4000))                  AS mdm_gender_code,
                   CAST(d.gd.exception_code AS VARCHAR2(4000))                   AS gender_exception_code,
                   xg.EXCEPTION_DESC                              AS gender_exception_description,
                   xg.EXCEPTION_TYPE                              AS gender_exception_type,
                   /* BAD DATA */ CASE WHEN d.birth_exception_code IS NULL THEN d.DT_DOB ELSE NULL END AS std_birth_date,
                   xb.EXCEPTION_DESC                              AS birth_exception_description,
                   xb.EXCEPTION_TYPE                              AS birth_exception_type,
                   xe.EXCEPTION_CODE                              AS ethnicity_exception_code,
                   xe.EXCEPTION_DESC                              AS ethnicity_exception_desc,
                   xe.EXCEPTION_TYPE                              AS ethnicity_exception_type,
                   CAST(d.rc.mdm_race_cd AS VARCHAR2(4000))                      AS mdm_race_cd,
                   CAST(d.rc.src_race_ind_list AS VARCHAR2(4000))                AS src_race_ind_list,
                   xr.EXCEPTION_CODE                              AS race_exception_cd,
                   xr.EXCEPTION_DESC                              AS race_exception_desc,
                   xr.EXCEPTION_TYPE                              AS race_exception_type,
                   xl.EXCEPTION_CODE                              AS language_exception_code,
                   xl.EXCEPTION_DESC                              AS language_exception_desc,
                   xl.EXCEPTION_TYPE                              AS language_exception_type,
                   xs.EXCEPTION_DESC                              AS suffix_exception_desc,
                   xs.EXCEPTION_TYPE                              AS suffix_exception_type
              FROM dq d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = CAST(d.rc.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.language_mstr, 'Invalid_Language')
              LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.suffix_exception_code
        ),
        routed AS (
            SELECT d.*,
                   TRIM(d.PTY_SRC_KEY)                                                   AS pkey_trim,
                   TRIM(d.PTY_SRC_KEY) || '|' || :b2                AS rle_pkey,CASE WHEN d.gender_exception_description IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT' THEN 1 WHEN NOT (d.gender_exception_description IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT') THEN 0 END AS grp_gender,CASE WHEN d.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (d.birth_exception_code IS NOT NULL) THEN 0 END AS grp_birth,CASE WHEN d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT' THEN 1 WHEN NOT (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT') THEN 0 END AS grp_ethnicity,CASE WHEN d.race_exception_desc IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT' THEN 1 WHEN NOT (d.race_exception_desc IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT') THEN 0 END AS grp_race,CASE WHEN d.language_exception_code IS NOT NULL THEN 1 WHEN NOT (d.language_exception_code IS NOT NULL) THEN 0 END AS grp_language,CASE WHEN d.suffix_exception_code IS NOT NULL THEN 1 WHEN NOT (d.suffix_exception_code IS NOT NULL) THEN 0 END AS grp_suffix
              FROM dq2 d
        )
        SELECT r.*,
               1 /* TIMELINE: VERSION_SEQ hard-coded */                  AS version_seq,
               1                                                          AS hub_state_ind,
               'FSS'                                                      AS src_sys,
               :b3                                                  AS run_ts,
               :b4                                                 AS mapping_name,
               :b5                                  AS pty_bo_class_cd,
               :b6                                  AS rle_bo_class_cd,
               TO_CHAR(r.DT_DOB, 'MM/DD/YYYY')                         AS dob_text,
               'Gender'                                                   AS attr_gender,
               'Birth Date'                                               AS attr_birth,
               'Ethnicity_Cd'                                             AS attr_ethnicity,
               'Race_Cd'                                                  AS attr_race,
               'Language_Cd'                                              AS attr_language,
               'Name Suffix'                                              AS attr_suffix,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1
                AND xp.PKEY_SRC_OBJECT IS NULL)                           AS uq_pty,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID_CLIENT, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID_CLIENT, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_gender,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID_CLIENT, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID_CLIENT, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_birth,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID_CLIENT,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID_CLIENT,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_ethnicity,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID_CLIENT, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID_CLIENT, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_race,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID_CLIENT,
                                               r.language_exception_type, r.language_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID_CLIENT,
                                               r.language_exception_type, r.language_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_language,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_suffix, r.PTY_SRC_KEY, r.ID_CLIENT, r.suffix_exception_type,
                                               r.suffix_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_suffix, r.PTY_SRC_KEY, r.ID_CLIENT, r.suffix_exception_type,
                                               r.suffix_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_suffix
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY WHERE VERSION_SEQ = 1) xp
                 ON xp.PKEY_SRC_OBJECT = r.pkey_trim
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE WHERE VERSION_SEQ = 1) xr2
                 ON xr2.PKEY_SRC_OBJECT = r.rle_pkey
      )]';
    EXECUTE IMMEDIATE l_sql USING l_run_ts, P_RLE_BO_CLASS_CD_MEMBER, l_run_ts, c_mapping, P_PTY_BO_CLASS_CD_MEMBER, P_RLE_BO_CLASS_CD_MEMBER;
    SELECT COUNT(*) INTO l_rows FROM WRK_FSS_PTY_SRC;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'materialize WRK_FSS_PTY_SRC', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_src;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_pty() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  HUB_STATE_IND, PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, BIRTH_DT,
                  SRC_FULL_NM, ETHNCTY, SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM) SELECT pkey_trim, DT_LAST_UPDATE, version_seq, run_ts, DT_LAST_UPDATE, pkey_trim, hub_state_ind,
                    pty_bo_class_cd, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name,
                    mdm_gender_code, DT_DOB, std_src_full_name, ethnicity_mstr, CD_HISPANIC, mdm_race_cd,
                    src_race_ind_list, DT_LAST_UPDATE, language_mstr, std_suffix FROM WRK_FSS_PTY_SRC WHERE (uq_pty = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_pty;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_rle() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  HUB_STATE_IND, PTY_FK, RLE_BO_CLASS_CD, SRC_LAST_UPD_DT) SELECT rle_pkey, DT_LAST_UPDATE, version_seq, run_ts, DT_LAST_UPDATE, rle_pkey, hub_state_ind, pkey_trim,
                    rle_bo_class_cd, DT_LAST_UPDATE FROM WRK_FSS_PTY_SRC WHERE (uq_rle = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_rle;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (grp_gender = 1) AND (uq_gender = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE, FIRST_NAME, MIDDLE_NAME,
                  LAST_NAME) VALUES (src_sys, gender_exception_type, gender_exception_code, gender_exception_description, attr_gender,
                    CD_GENDER, mapping_name, PTY_SRC_KEY, ID_CLIENT, CD_GENDER, DT_DOB, run_ts, NM_FIRST, NM_MIDDLE,
                    NM_LAST)
        WHEN (grp_birth = 1) AND (uq_birth = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
                  GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
                  BIRTH_DATE) VALUES (src_sys, PTY_SRC_KEY, birth_exception_code, birth_exception_description, birth_exception_type,
                    run_ts, mapping_name, CD_GENDER, attr_birth, ID_CLIENT, std_prfx_name, NM_FIRST, NM_LAST,
                    NM_MIDDLE, dob_text, DT_DOB)
        WHEN (grp_ethnicity = 1) AND (uq_ethnicity = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
                  SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
                  SRC_SYS_ID_2, ATTRIBUTE_VALUE) VALUES (run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
                    attr_ethnicity, CD_GENDER, PTY_SRC_KEY, src_sys, NM_FIRST, std_lst_name, std_mdl_name,
                    mapping_name, DT_DOB, DT_LAST_UPDATE, ID_CLIENT, CD_HISPANIC)
        WHEN (grp_race = 1) AND (uq_race = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
                  MAPPING_NAME, ATTRIBUTE_VALUE) VALUES (ID_CLIENT, PTY_SRC_KEY, src_sys, race_exception_cd, race_exception_desc, race_exception_type,
                    run_ts, NM_FIRST, std_mdl_name, std_lst_name, CD_GENDER, DT_DOB, attr_race, std_prfx_name,
                    DT_LAST_UPDATE, mapping_name, src_race_ind_list)
        WHEN (grp_language = 1) AND (uq_language = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, PERIOD_START_DATE) VALUES (src_sys, PTY_SRC_KEY, ID_CLIENT, language_exception_type, language_exception_code,
                    language_exception_desc, run_ts, NM_FIRST, std_mdl_name, std_lst_name, std_birth_date,
                    CD_GENDER, attr_language, LANGUAGE_CD, mapping_name, DT_LAST_UPDATE)
        WHEN (grp_suffix = 1) AND (uq_suffix = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, SUFFIX, ALIAS_SUFFIX, BIRTH_DATE, ATTRIBUTE_NAME,
                  ATTRIBUTE_VALUE, MAPPING_NAME) VALUES (src_sys, PTY_SRC_KEY, ID_CLIENT, suffix_exception_type, suffix_exception_code,
                    suffix_exception_desc, run_ts, NM_FIRST, NM_MIDDLE, NM_LAST, CD_SUFFIX, std_suffix, DT_DOB,
                    attr_suffix, CD_SUFFIX, mapping_name)
    SELECT * FROM WRK_FSS_PTY_SRC;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_src(P_MEMBER_HIERARCHY_CODE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Addr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_sql CLOB;
BEGIN
    -- Drop any previous run's snapshot (Oracle DDL auto-commits).
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_FSS_ADDR_SRC';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    -- Snapshot the shared source SELECT verbatim. PL/SQL variables
    -- are passed as binds (:bN) because dynamic SQL cannot see them.
    l_sql := q'[CREATE TABLE WRK_FSS_ADDR_SRC AS SELECT *
      FROM (
        WITH
        lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_mc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper46_common())),
        -- Read_V_FSS_ETL_SRC (source filter DTL__CAPXACTION <> 'D') + Exp_src + Exp_Build_Src_key
        src AS (
            SELECT v.SOURCE_TYPE, v.ID_CLIENT, v.ADDR_LINE1, v.ADDR_LINE2, v.ADDR_CITY, v.CD_CNTY, v.ADDR_ZIP,
                   v.ADDR_STATE, v.PTY_SRC_KEY, v.ID_REGISTRATION_CLIENT, v.DT_LAST_UPDATE, v.DT_CREATED,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|002|' || NVL(LPAD(TO_CHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '')
                   || '|' || NVL(TRIM(UPPER(v.ADDR_LINE1)), '') || '|' || NVL(TRIM(UPPER(v.ADDR_LINE2)), '') || '|'
                   || NVL(UPPER(v.ADDR_CITY), '') || '|' || NVL(UPPER(v.ADDR_STATE), '') || '|' || NVL(v.ADDR_ZIP, '')
                                                                                                   AS pkey_src_object,
                   -- exp_Score_and_Exception_details.PTY_SRC_KEY (DQM_ADDRESS only)
                   LPAD(TO_CHAR(v.ID_CLIENT), 10, '0') || CASE WHEN v.SOURCE_TYPE = 'FSS_FAMILY' THEN 'F' ELSE '' END AS dqm_pty_src_key
              FROM V_FSS_ETL_SRC v
             WHERE v.DTL__CAPXACTION <> 'D'
        ),
        -- Lookup_STG_FSS_PTY_INACTIVE_STS + Fil_Inactive_recs
        active AS (
            SELECT s.*
              FROM src s
             WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = s.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- Exp_all_active (FULL_PSTL_CD: the extension port is unfed, so the zip alone) + mplt_Global_Addr_Validation
        validated AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper34_common(a.ADDR_LINE1, a.ADDR_LINE2, a.ADDR_CITY, a.ADDR_STATE, a.ADDR_ZIP, 'US',
                                           st.MSTR_CODE_VALUE) AS av
              FROM active a
              LEFT JOIN lkp_cv st ON st.CODE_TYPE = 'STATE' AND st.SRC_SYS = 'FSS'
                                 AND st.SRC_CODE_VALUE = UPPER(TRIM(a.ADDR_STATE))
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
               'FSS'                                                         AS src_sys,
               :b1                                                     AS run_ts,
               :b2                                                    AS mapping_name,
               1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
               1                                                             AS hub_state_ind,
               NVL(s.PTY_SRC_KEY, '') || '|Member'                           AS pty_rle_fk,
               'Primary'                                                     AS pref_lvl,
               NVL(TO_CHAR(s.ID_CLIENT), '') || '|' || NVL(TO_CHAR(s.ID_REGISTRATION_CLIENT), '') AS loc_idn,
               :b3                                      AS hierarchy_code,
               :b4                                        AS hm_rel_tp_cd,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN 'Address' ELSE NULL END           AS exc_attribute_name,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN NVL(s.ADDR_LINE1, '') || ' ' || NVL(s.ADDR_LINE2, '') || ' ' || NVL(s.ADDR_CITY, '') || ' '
                   || NVL(s.ADDR_STATE, '') || ' ' || NVL(s.ADDR_ZIP, '') || '  US' ELSE NULL END AS exc_attribute_value,
               'Invalid_Address'                                             AS exc_code,
               'Invalid Address per Address Doctor'                          AS exc_desc,
               'Bad Value'                                                   AS exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object
                                       ORDER BY s.DT_LAST_UPDATE DESC, s.ID_REGISTRATION_CLIENT) = 1
                AND xa.PKEY_SRC_OBJECT IS NULL)                              AS uq_addr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY s.score, s.ID_CLIENT, s.ID_REGISTRATION_CLIENT, s.SOURCE_TYPE
                                      ORDER BY s.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY s.score, s.ID_CLIENT, s.ID_REGISTRATION_CLIENT, s.SOURCE_TYPE
                                      ORDER BY s.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_addr_exc
          FROM scored s
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = s.pkey_src_object
      )]';
    EXECUTE IMMEDIATE l_sql USING l_run_ts, c_mapping, P_MEMBER_HIERARCHY_CODE, P_MEMBER_HM_REL_TP_CD;
    SELECT COUNT(*) INTO l_rows FROM WRK_FSS_ADDR_SRC;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'materialize WRK_FSS_ADDR_SRC', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_src;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_dqm() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO DQM_ADDRESS (MLBLTY_SCR, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_STATE, SRC_PSTL_CD, SRC_CNTRY, SRC_COUNTY,
                  RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_PSTL_CD, RSLT_CNTRY, RSLT_COUNTY, COUNTY_FIPS, STATE_FIPS,
                  LATTD, LNGTD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_NM, ORG_DESC, ORG_DEPT, BLDG, SUB_BLDG,
                  ADDRDR_MTCH_CD, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
                  MDM_ADDR_TP, SRC_SYSTEM, ADDR_SRC_KEY, LOAD_DT, PTY_SRC_KEY, RSLT_STATE) SELECT a_mailability_score, ADDR_LINE1, ADDR_LINE2, ADDR_CITY, ADDR_STATE, ADDR_ZIP, src_cntry, CD_CNTY,
                    a_line1, a_line2, a_city, a_postcode_complete, a_country, a_county_fips, a_county_fips,
                    a_state_fips, a_latitude, a_longitude, a_geocoding_status, a_residential, a_org_name,
                    a_org_descriptor, a_org_department, a_building_complete, a_sub_building_complete, a_match_code,
                    a_result_pct, a_address_type, a_early_warning, a_cass_error, a_dpv, addr_tp, src_sys,
                    pkey_src_object, run_ts, dqm_pty_src_key, a_state_fips FROM WRK_FSS_ADDR_SRC;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert DQM_ADDRESS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_dqm;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_addr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE_ADDR (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, VERSION_SEQ,
                  PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND,
                  PTY_RLE_FK, ADDR_TP, USG_TP, PREF_LVL, HIERARCHY_CODE, HM_REL_TP_CD, LOC_IDN, SRC_LAST_UPD_DT,
                  ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT,
                  LCTN_CRDNT_DESC, LATTD, LNGTD, PSTL_BRCD, VLDTN_MSG, RGN_CD, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC,
                  ORG_NM, BLDG_NMBR, SUB_BLDG_NM, SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1,
                  SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT,
                  EFF_END_DT, PERIOD_START_DATE) SELECT pkey_src_object, NULL, NULL, NULL, NULL, version_seq, NULL, run_ts, mapping_name, DT_LAST_UPDATE,
                    NULL, pkey_src_object, hub_state_ind, pty_rle_fk, addr_tp, NULL, pref_lvl, hierarchy_code,
                    hm_rel_tp_cd, loc_idn, DT_LAST_UPDATE, hold_line1, hold_line2, a_building_name, NULL, a_city,
                    a_county_fips, a_state_fips, a_country, a_zip_cd_5, a_zip_cd_4_extn, NULL, a_latitude,
                    a_longitude, NULL, a_match_code, NULL, a_mailability_score, a_address_type, a_org_descriptor,
                    a_org_name, a_building_number, a_sub_building_complete, a_sub_building_descriptor,
                    a_geocoding_status, a_residential, ADDR_LINE1, ADDR_LINE2, ADDR_CITY, CD_CNTY, ADDR_STATE,
                    src_cntry, ADDR_ZIP, NULL, DT_LAST_UPDATE, NULL, DT_CREATED FROM WRK_FSS_ADDR_SRC WHERE score = '100' AND (uq_addr = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE_ADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE,
                  ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE,
                  EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EXCEPTION_TYPE, ADDRESS_LINE_1, ADDRESS_LINE_2,
                  ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY,
                  SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3) SELECT src_sys, a_match_code, a_match_code_description, a_mailability_score, exc_attribute_name,
                    exc_attribute_value, mapping_name, addr_tp, DT_LAST_UPDATE, NULL, exc_code, exc_desc, run_ts,
                    exc_type, ADDR_LINE1, ADDR_LINE2, ADDR_CITY, CD_CNTY, ADDR_STATE, ADDR_ZIP, NULL, src_cntry,
                    ID_CLIENT, ID_REGISTRATION_CLIENT, SOURCE_TYPE FROM WRK_FSS_ADDR_SRC WHERE score = '40' AND (uq_addr_exc = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id_alt() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Alt_Id';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, SRC_LAST_UPD_DT, HUB_STATE_IND, STS_CD, SRC_ROWID,
            LAST_UPDATE_DATE, VERSION_SEQ, ALT_ID_TP_FLTR, CREATE_DATE, PERIOD_START_DATE)
    SELECT pkey_src_object, pty_rle_fk, alt_id_tp, __col3, __col4, __col5, __col6, __col7, __col8, __col9, alt_id_tp, DT_CREATED, __col12 FROM (SELECT x.pkey_src_object, x.pty_rle_fk, x.alt_id_tp, LPAD(TO_CHAR(x.ID_CLIENT), 10, '0') AS __col3, l_run_ts AS __col4, 1 AS __col5, 'Issued' AS __col6, NVL(TO_CHAR(x.ID_CLIENT), '') || '|' || x.alt_id_tp AS __col7, l_run_ts AS __col8, 1 /* TIMELINE: VERSION_SEQ */ AS __col9, x.alt_id_tp, x.DT_CREATED, x.DT_CREATED /* TIMELINE */
       AS __col12, ROW_NUMBER() OVER (PARTITION BY x.pkey_src_object ORDER BY x.DT_LAST_UPDATE DESC NULLS LAST) AS __qual_rn FROM (SELECT v.SOURCE_TYPE, v.DT_CREATED, v.DT_LAST_UPDATE, v.PTY_SRC_KEY, v.ID_CLIENT,
                   NVL(v.PTY_SRC_KEY, '') || '|Member'                                      AS pty_rle_fk,
                   CASE WHEN v.SOURCE_TYPE = 'CLIENT' THEN '022' ELSE '023' END                              AS alt_id_tp,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|' || CASE WHEN v.SOURCE_TYPE = 'CLIENT' THEN '022' ELSE '023' END || '|'
                   || NVL(LPAD(TO_CHAR(v.ID_CLIENT), 10, '0'), '')                        AS pkey_src_object
              FROM V_FSS_ETL_SRC v
             -- source filter (the commented-out testing filter is not applied)
             WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y') x
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = x.pkey_src_object
     -- Lkp_STG_FSS_PTY_INACTIVE_STS + Filter: IsNull(DEACTIVATION_STS)
     WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = x.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
       /* BAD DATA: unique key not yet in the table */
       AND xa.PKEY_SRC_OBJECT IS NULL
    /* BAD DATA: first row per key in this run */
    ) WHERE __qual_rn = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE_ALT_ID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id_alt;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_src() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime / SYSTIMESTAMP()
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_sql CLOB;
BEGIN
    -- Drop any previous run's snapshot (Oracle DDL auto-commits).
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_FSS_PHN_SRC';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    -- Snapshot the shared source SELECT verbatim. PL/SQL variables
    -- are passed as binds (:bN) because dynamic SQL cannot see them.
    l_sql := q'[CREATE TABLE WRK_FSS_PHN_SRC AS SELECT *
      FROM (
        WITH
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())),
        -- Read_V_FSS_ETL_SRC (source filter; the commented-out testing filter is not applied) + fil_deactivated_status
        src AS (
            SELECT v.PTY_SRC_KEY, v.ADDR_EMAIL, v.NBR_PHONE, v.NBR_PHONE_EXT, v.SOURCE_TYPE, v.ID_REGISTRATION_CLIENT,
                   v.DT_LAST_UPDATE,
                   NVL(v.PTY_SRC_KEY, '') || '|Member'                                             AS pty_rle_fk,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|001|' || NVL(LPAD(TO_CHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '')
                   || '|' || NVL(TRIM(v.ADDR_EMAIL), '')                                           AS eaddr_pkey,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|'
                   || NVL(LPAD(TO_CHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '') || '|' || NVL(TRIM(v.NBR_PHONE), '')
                                                                                                   AS phn_pkey
              FROM V_FSS_ETL_SRC v
             WHERE v.DTL__CAPXACTION <> 'D'
               AND NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        dq AS (
            SELECT s.*,
                   CASE WHEN s.ADDR_EMAIL IS NOT NULL THEN PKG_COMMON.fn_snow_helper22_common(s.ADDR_EMAIL) ELSE NULL END    AS em,
                   CASE WHEN s.NBR_PHONE IS NOT NULL THEN PKG_COMMON.fn_snow_helper23_common(s.NBR_PHONE) ELSE NULL END      AS std_phone,
                   CASE WHEN s.NBR_PHONE IS NOT NULL THEN PKG_COMMON.fn_snow_helper25_common(s.NBR_PHONE_EXT) ELSE NULL END  AS px
              FROM src s
        ),
        checked AS (
            SELECT d.*,
                   CAST(d.em.email_address AS VARCHAR2(4000))                                                   AS std_email,
                   /* VALIDATION */
                   CASE WHEN d.NBR_PHONE IS NOT NULL THEN PKG_COMMON.fn_snow_helper24_common(d.std_phone, 'FSS', '001', ar.NPA_ID, ar.SERVICE) ELSE NULL END AS phone_exception_code,
                   CAST(d.px.phone_nbr_ext AS VARCHAR2(4000))                                                   AS std_ext,
                   CAST(d.px.exception_code AS VARCHAR2(4000))                                                  AS ext_exception_code
              FROM dq d
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(d.std_phone, 1, 3)
        ),
        routed AS (
            SELECT c.*,
                   xe.EXCEPTION_CODE  AS email_exception_code,
                   xe.EXCEPTION_DESC  AS email_exception_desc,
                   xe.EXCEPTION_TYPE  AS email_exception_type,
                   xp.EXCEPTION_DESC  AS phone_exception_desc,
                   xx.EXCEPTION_DESC  AS ext_exception_desc,CASE WHEN c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL THEN 1 WHEN NOT (c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL) THEN 0 END AS grp_email_good,CASE WHEN c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL THEN 1 WHEN NOT (c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL) THEN 0 END AS grp_email_bad,CASE WHEN c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NULL THEN 1 WHEN NOT (c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NULL) THEN 0 END AS grp_phone_good,CASE WHEN c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NOT NULL THEN 1 WHEN NOT (c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NOT NULL) THEN 0 END AS grp_phone_bad,CASE WHEN c.NBR_PHONE IS NOT NULL AND c.ext_exception_code IS NOT NULL THEN 1 WHEN NOT (c.NBR_PHONE IS NOT NULL AND c.ext_exception_code IS NOT NULL) THEN 0 END AS grp_ext_bad
              FROM checked c
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = CAST(c.em.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
              LEFT JOIN lkp_exc xx ON xx.EXCEPTION_CODE = c.ext_exception_code
        )
        SELECT r.*,
               '1' /* TIMELINE: VERSION_SEQ */                          AS version_seq,
               1                                                         AS hub_state_ind,
               'FSS'                                                     AS src_sys,
               :b1                                                 AS run_ts,
               :b2                                                AS mapping_name,
               '001'                                                     AS eaddr_addr_tp,
               'Active'                                                  AS eaddr_sts_cd,
               'Y'                                                       AS eaddr_is_vld,
               'Telephone'                                               AS phn_tp,
               '001'                                                     AS usg_tp,
               'Primary'                                                 AS pref_lvl,
               /* BAD DATA: an invalid extension is blanked on the loaded phone */
               CASE WHEN r.ext_exception_code IS NULL THEN r.std_ext ELSE NULL END        AS phn_num_ext,
               'Email'                                                   AS attr_email,
               'Main Phone'                                              AS attr_phone,
               'Main Phone Ext'                                          AS attr_phone_ext,
               'Rejected Record'                                         AS exc_type_rejected,
               'Bad Value'                                               AS exc_type_bad_value,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.eaddr_pkey
                                       ORDER BY r.DT_LAST_UPDATE DESC, r.ID_REGISTRATION_CLIENT) = 1
                AND xea.PKEY_SRC_OBJECT IS NULL)                         AS uq_eaddr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.phn_pkey
                                       ORDER BY r.DT_LAST_UPDATE DESC, r.ID_REGISTRATION_CLIENT) = 1
                AND xph.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.phn_pkey
                                       ORDER BY r.DT_LAST_UPDATE DESC, r.ID_REGISTRATION_CLIENT) = 1
                AND xph.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_phn,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.email_exception_type, r.email_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.email_exception_type, r.email_exception_code
                                      ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_email_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.phone_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.phone_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_phone_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ext_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.ext_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ext_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                               r.ext_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_ext_exc
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
                 ON xea.PKEY_SRC_OBJECT = r.eaddr_pkey
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
                 ON xph.PKEY_SRC_OBJECT = r.phn_pkey
      )]';
    EXECUTE IMMEDIATE l_sql USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_FSS_PHN_SRC;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'materialize WRK_FSS_PHN_SRC', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_src;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE_EADDR (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  HUB_STATE_IND, PTY_RLE_FK, ADDR_TP, USG_TP, ELEC_ADDR, STS_CD, IS_VLD, SRC_LAST_UPD_DT) SELECT eaddr_pkey, DT_LAST_UPDATE, version_seq, run_ts, run_ts, eaddr_pkey, hub_state_ind, pty_rle_fk,
                    eaddr_addr_tp, NULL, std_email, eaddr_sts_cd, eaddr_is_vld, DT_LAST_UPDATE FROM WRK_FSS_PHN_SRC WHERE (grp_email_good = 1) AND (uq_eaddr = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE_EADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_eaddr;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE_PHN (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND,
                  PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT) SELECT phn_pkey, DT_LAST_UPDATE, version_seq, run_ts, phn_pkey, hub_state_ind, pty_rle_fk, phn_tp,
                    usg_tp, std_phone, pref_lvl, DT_LAST_UPDATE, phn_num_ext FROM WRK_FSS_PHN_SRC WHERE (grp_phone_good = 1) AND (uq_phn = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE_PHN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_phn;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        WHEN (grp_email_bad = 1) AND (uq_email_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME, EXCEPTION_TYPE,
                  PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2) VALUES (src_sys, email_exception_code, email_exception_desc, run_ts, ADDR_EMAIL, mapping_name,
                    email_exception_type, DT_LAST_UPDATE, ADDR_EMAIL, attr_email, PTY_SRC_KEY, ID_REGISTRATION_CLIENT)
        WHEN (grp_phone_bad = 1) AND (uq_phone_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
                  MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME,
                  SRC_SYS_ID_2) VALUES (src_sys, phone_exception_code, phone_exception_desc, run_ts, NBR_PHONE, NULL, NULL,
                    mapping_name, PTY_SRC_KEY, exc_type_rejected, DT_LAST_UPDATE, NBR_PHONE, attr_phone,
                    ID_REGISTRATION_CLIENT)
        WHEN (grp_ext_bad = 1) AND (uq_ext_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
                  PRIMARY_PHONE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, PERIOD_START_DATE, MAPPING_NAME) VALUES (src_sys, PTY_SRC_KEY, ID_REGISTRATION_CLIENT, exc_type_bad_value, ext_exception_code,
                    ext_exception_desc, run_ts, NBR_PHONE_EXT, NBR_PHONE_EXT, attr_phone_ext, DT_LAST_UPDATE,
                    mapping_name)
    SELECT * FROM WRK_FSS_PHN_SRC;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_src() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Rel';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_sql CLOB;
BEGIN
    -- Drop any previous run's snapshot (Oracle DDL auto-commits).
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_FSS_REL_SRC';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    -- Snapshot the shared source SELECT verbatim. PL/SQL variables
    -- are passed as binds (:bN) because dynamic SQL cannot see them.
    l_sql := q'[CREATE TABLE WRK_FSS_REL_SRC AS SELECT *
      FROM (
        WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_V_FSS_ETL_SRC_RELATIONS + Lkp_*_STG_FSS_PTY_INACTIVE_STS + Filter_Fam_Child_Valid
        src AS (
            SELECT r.RELATION_DIRECTION, r.RELN_DT_LAST_UPDATE, r.RELN_DT_CREATED, r.ID_CLIENT, r.CD_RELTSHP_TO_TC,
                   r.PTY_SRC_KEY, r.RELN_PTY_SRC_KEY, r.RELN_CD_GENDER, r.CD_GENDER, r.RELN_ID_CLIENT,
                   r.ID_REGISTRATION
              FROM V_FSS_ETL_SRC_RELATIONS r
             WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = r.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
               AND NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = r.RELN_PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- Exp_Map_Code_Val_and_Gender (IIF(x = 'UNK','UNK',x) is the identity and is kept implicit)
        coded AS (
            SELECT s.*,
                   NVL(s.CD_RELTSHP_TO_TC, 'CAREGIVER') || '|'
                   || NVL(CASE WHEN s.RELATION_DIRECTION = 'To Child' THEN s.RELN_CD_GENDER ELSE s.CD_GENDER END, '') AS relation_cd,
                   CASE WHEN s.RELATION_DIRECTION = 'To Child' THEN 'REL_TP' ELSE 'INVERSE_REL' END                    AS code_type,
                   CASE WHEN s.RELATION_DIRECTION = 'To Child' THEN s.RELN_CD_GENDER ELSE s.CD_GENDER END              AS out_gender_cd,
                   NVL(CASE WHEN s.RELATION_DIRECTION = 'To Child' THEN s.RELN_PTY_SRC_KEY ELSE s.PTY_SRC_KEY END, '') || '|Member'
                                                                                                      AS rel_fk_1,
                   NVL(CASE WHEN s.RELATION_DIRECTION = 'To Child' THEN s.PTY_SRC_KEY ELSE s.RELN_PTY_SRC_KEY END, '') || '|Member'
                                                                                                      AS rel_fk_2
              FROM src s
        ),
        -- Lkp_Rel_Tp_Code_Value (lookup filter CODE_TYPE IN ('REL_TP','INVERSE_REL') plus the code-type condition)
        typed AS (
            SELECT c.*, lk.MSTR_REF_CODE AS mstr_ref_code
              FROM coded c
              LEFT JOIN (SELECT CODE_TYPE, SRC_CODE_VALUE, MSTR_REF_CODE FROM (SELECT l.CODE_TYPE, l.SRC_CODE_VALUE, l.MSTR_REF_CODE, ROW_NUMBER() OVER (PARTITION BY l.CODE_TYPE, l.SRC_CODE_VALUE
                                                       ORDER BY l.MSTR_REF_CODE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
                          WHERE l.CODE_TYPE IN ('REL_TP', 'INVERSE_REL') AND l.SRC_SYS = 'FSS'
                        ) WHERE __qual_rn = 1) lk
                     ON lk.SRC_CODE_VALUE = c.relation_cd AND lk.CODE_TYPE = c.code_type
        )
        SELECT t.*,
               t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '')  AS rel_pkey,
               1 /* TIMELINE: VERSION_SEQ */                                       AS version_seq,
               1                                                                    AS hub_state_ind,
               'Member Relationship'                                                AS rel_type_code,
               'Member'                                                             AS hierarchy_code,
               'batchload'                                                          AS batch_user,
               'FSS'                                                                AS src_sys,
               :b1                                                            AS run_ts,
               :b2                                                           AS mapping_name,
               'Relationship|Sex'                                                   AS attr_relationship,
               ex.EXCEPTION_CODE                                                    AS exc_code,
               ex.EXCEPTION_DESC                                                    AS exc_desc,
               ex.EXCEPTION_TYPE                                                    AS exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY CASE WHEN t.mstr_ref_code IS NULL THEN 1 WHEN NOT (t.mstr_ref_code IS NULL) THEN 0 END ,
                                                t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '')
                                       ORDER BY t.RELN_DT_LAST_UPDATE DESC, t.ID_REGISTRATION) = 1
                AND xr.PKEY_SRC_OBJECT IS NULL)                                     AS uq_rel,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN t.mstr_ref_code IS NULL THEN 1 WHEN NOT (t.mstr_ref_code IS NULL) THEN 0 END , t.RELN_ID_CLIENT, t.ID_CLIENT,
                                               t.ID_REGISTRATION ORDER BY t.RELN_DT_LAST_UPDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN t.mstr_ref_code IS NULL THEN 1 WHEN NOT (t.mstr_ref_code IS NULL) THEN 0 END , t.RELN_ID_CLIENT, t.ID_CLIENT,
                                               t.ID_REGISTRATION ORDER BY t.RELN_DT_LAST_UPDATE DESC) = 1) THEN 0 END AS uq_rel_exc
          FROM typed t
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = 'Invalid_Relationship'
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_REL WHERE VERSION_SEQ = 1) xr
                 ON xr.PKEY_SRC_OBJECT = t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '')
      )]';
    EXECUTE IMMEDIATE l_sql USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_FSS_REL_SRC;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'materialize WRK_FSS_REL_SRC', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_src;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_rel() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Rel';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_FSS_PTY_RLE_REL (REL_TP, VERSION_SEQ, HUB_STATE_IND, REL_TYPE_CODE, HIERARCHY_CODE, UPDATED_BY, LAST_UPDATE_DATE,
                  PERIOD_START_DATE, PKEY_SRC_OBJECT, PTY_RLE_FK_1, PTY_RLE_FK_2, SRC_LAST_UPD_DT, CREATOR, SRC_ROWID,
                  CREATE_DATE) SELECT mstr_ref_code, version_seq, hub_state_ind, rel_type_code, hierarchy_code, batch_user, run_ts,
                    RELN_DT_CREATED, rel_pkey, rel_fk_1, rel_fk_2, RELN_DT_LAST_UPDATE, batch_user, rel_pkey,
                    RELN_DT_LAST_UPDATE FROM WRK_FSS_REL_SRC WHERE mstr_ref_code IS NOT NULL AND (uq_rel = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_FSS_PTY_RLE_REL', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_rel;


    FUNCTION sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_FSS_Pty_Rle_Rel';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, RUN_DATE, MAPPING_NAME, ATTRIBUTE_NAME, PERIOD_START_DATE,
                  EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_VALUE, SRC_SYS_ID_3, GENDER) SELECT src_sys, RELN_ID_CLIENT, ID_CLIENT, run_ts, mapping_name, attr_relationship, RELN_DT_CREATED,
                    exc_type, exc_code, exc_desc, relation_cd, ID_REGISTRATION, out_gender_cd FROM WRK_FSS_REL_SRC WHERE mstr_ref_code IS NULL AND (uq_rel_exc = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel_exc;

END PKG_FSS;
/
