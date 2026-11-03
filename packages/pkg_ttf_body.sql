-- TTF discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_TTF AS

    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_stage() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Validation';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    DELETE FROM WRK_TTF_VAL_ROUTED;
    INSERT INTO WRK_TTF_VAL_ROUTED (pkey_src_object, createddate, dob, std_first_name, std_mdl_name, std_lst_name, std_src_full_name, grp_invalid_party_name, grp_deactivation, grp_reactivation, exc_code_name, new_deactivation_sts, deactivation_sts, exc_desc_name, exc_type_name, src_sys, run_ts, mapping_name, action_deactivation, action_reactivation, uq_exc_name)
        WITH
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        sts AS (    -- Lookup_STG_TTF_PTY_INACTIVE_STS (any row)
            SELECT SRC_KEY, DEACTIVATION_STS FROM (SELECT i.SRC_KEY, i.DEACTIVATION_STS, ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) AS __qual_rn FROM STG_TTF_PTY_INACTIVE_STS i
             WHERE i.ROWID_SYSTEM = 'TTF'
           ) WHERE __qual_rn = 1
        ),
        xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter TRIM(ROWID_SYSTEM) = 'TTF')
            SELECT PKEY_SRC_OBJECT, HUB_STATE_IND FROM (SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND, ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) AS __qual_rn FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'TTF'
           ) WHERE __qual_rn = 1
        ),
        enriched AS (
            SELECT v.CLIENTS_ID, v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME, v.DOB, v.CREATEDDATE, v.SUBMITDATE,
                   v.CLIENT_EXISTS_FLAG,
                   LPAD(TO_CHAR(v.CLIENTS_ID), 10, '0')  AS pkey_src_object,
                   sts.DEACTIVATION_STS                     AS deactivation_sts,
                   xref.HUB_STATE_IND                       AS hub_state_ind,
                   PKG_COMMON.fn_snow_helper15_common(v.FIRSTNAME, v.MIDDLENAME, v.LASTNAME,
                       TRIM(NVL(v.FIRSTNAME, '') || CASE WHEN v.MIDDLENAME IS NOT NULL THEN ' ' || TRIM(v.MIDDLENAME) ELSE '' END
                            || ' ' || NVL(LTRIM(v.LASTNAME), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
              FROM V_TTF_ETL_SRC v
              LEFT JOIN sts  ON sts.SRC_KEY = LPAD(TO_CHAR(v.CLIENTS_ID), 10, '0')
              LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = LPAD(TO_CHAR(v.CLIENTS_ID), 10, '0')
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRSTNAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LASTNAME)) AND (jl.IS_LAST_JUNK = 1)
        ),
        named AS (
            SELECT n.*,
                   CAST(n.nm.first_name AS VARCHAR2(4000))    AS std_first_name,
                   CAST(n.nm.middle_name AS VARCHAR2(4000))   AS std_mdl_name,
                   CAST(n.nm.last_name AS VARCHAR2(4000))     AS std_lst_name,
                   CAST(n.nm.src_full_name AS VARCHAR2(4000)) AS std_src_full_name,
                   /* VALIDATION */
                   (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.first_name AS VARCHAR2(4000)))
                    OR (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.last_name AS VARCHAR2(4000))) = 1))                          AS name_missing,
                   NVL(UPPER(CAST(n.nm.last_name AS VARCHAR2(4000))) = 'DECLINED'
                       OR UPPER(CAST(n.nm.first_name AS VARCHAR2(4000))) = 'DECLINED', 0)                    AS name_declined,
                   NVL(UPPER(CAST(n.nm.last_name AS VARCHAR2(4000))) = 'DO_NOT_DISCLOSE'
                       OR UPPER(CAST(n.nm.first_name AS VARCHAR2(4000))) = 'DO_NOT_DISCLOSE', 0)             AS name_undisclosed
              FROM enriched n
        ),
        -- Rtr_Valid_Party + Exp_Invalid_PTY_NM
        routed AS (
            SELECT r.*,CASE WHEN r.name_missing OR r.name_declined OR r.name_undisclosed THEN 1 WHEN NOT (r.name_missing OR r.name_declined OR r.name_undisclosed) THEN 0 END AS grp_invalid_party_name,CASE WHEN r.name_missing OR r.name_declined OR NVL(r.CLIENT_EXISTS_FLAG = 'N', 0) THEN 1 WHEN NOT (r.name_missing OR r.name_declined OR NVL(r.CLIENT_EXISTS_FLAG = 'N', 0)) THEN 0 END AS grp_deactivation,
                   NVL(r.deactivation_sts IS NOT NULL AND NOT (r.name_missing = 1)
                       AND NOT (UPPER(r.std_lst_name) = 'DECLINED') AND NOT (UPPER(r.std_first_name) = 'DECLINED')
                       AND r.CLIENT_EXISTS_FLAG = 'Y', 0)                                      AS grp_reactivation,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'Missing_First_Name'
                        WHEN UPPER(TRIM(r.std_first_name)) IN ('DECLINED', 'DO_NOT_DISCLOSE') THEN 'Invalid_First_Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Missing_Last_Name'
                        WHEN UPPER(TRIM(r.std_lst_name)) IN ('DECLINED', 'DO_NOT_DISCLOSE') THEN 'Invalid_Last_Name'
                        ELSE 'Valid' END                                                           AS exc_code_name,
                   PKG_COMMON.fn_snow_helper02_common(r.hub_state_ind)                                        AS new_deactivation_sts
              FROM named r
        )
        SELECT r.pkey_src_object, r.CREATEDDATE, r.DOB, r.std_first_name, r.std_mdl_name, r.std_lst_name, r.std_src_full_name, r.grp_invalid_party_name, r.grp_deactivation, r.grp_reactivation, r.exc_code_name, r.new_deactivation_sts, r.deactivation_sts,
               ex.EXCEPTION_DESC     AS exc_desc_name,
               ex.EXCEPTION_TYPE     AS exc_type_name,
               'TTF'                 AS src_sys,
               l_run_ts             AS run_ts,
               c_mapping            AS mapping_name,
               'Deactivation'        AS action_deactivation,
               'Reactivation'        AS action_reactivation,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.pkey_src_object, ex.EXCEPTION_TYPE,
                                               r.exc_code_name ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.pkey_src_object, ex.EXCEPTION_TYPE,
                                               r.exc_code_name ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1) THEN 0 END AS uq_exc_name
          FROM routed r
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'stage WRK_TTF_VAL_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_stage;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (PERIOD_START_DATE, MAPPING_NAME, ATTRIBUTE_NAME, FIRST_NAME, MIDDLE_NAME, LAST_NAME, RUN_DATE,
            SRC_SYS, SRC_SYS_ID_1, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE, BIRTH_DATE, ATTRIBUTE_VALUE)
    SELECT createddate, mapping_name, exc_code_name, std_first_name, std_mdl_name, std_lst_name, run_ts,
           src_sys, pkey_src_object, exc_desc_name, exc_type_name, exc_code_name, dob, std_src_full_name
      FROM WRK_TTF_VAL_ROUTED
     WHERE grp_invalid_party_name = 1 AND uq_exc_name = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB (validation)', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_log() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TTF_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    SELECT pkey_src_object, src_sys, action_deactivation, run_ts
      FROM WRK_TTF_VAL_ROUTED
     WHERE grp_deactivation = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    INSERT INTO STG_TTF_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    SELECT pkey_src_object, src_sys, action_reactivation, run_ts
      FROM WRK_TTF_VAL_ROUTED
     WHERE grp_reactivation = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TTF_PTY_INACTIVE_LOG', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_log;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_sts() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TTF_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    SELECT pkey_src_object, src_sys, new_deactivation_sts, run_ts
      FROM WRK_TTF_VAL_ROUTED
     WHERE grp_deactivation = 1 AND deactivation_sts IS NULL;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TTF_PTY_INACTIVE_STS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_sts;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_stage(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    DELETE FROM WRK_TTF_PTY_ROUTED;
    INSERT INTO WRK_TTF_PTY_ROUTED (pkey_trim, rle_pkey, submitdate, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name, mdm_gender_code, std_src_full_name, ethnicity_mstr, ethnicity, race_mstr, raceethnicityid, std_birth_date, pty_src_key, clients_id, firstname, middlename, lastname, gender, dob, gender_exception_code, gender_exception_description, gender_exception_type, birth_exception_code, birth_exception_description, birth_exception_type, ethnicity_exception_code, ethnicity_exception_desc, ethnicity_exception_type, race_exception_code, race_exception_desc, race_exception_type, grp_gender, grp_birth, grp_ethnicity, grp_race, version_seq, hub_state_ind, src_sys, run_ts, mapping_name, pty_bo_class_cd, rle_bo_class_cd, dob_text, attr_gender, attr_birth, attr_ethnicity, attr_race, uq_pty, uq_rle, uq_gender, uq_birth, uq_ethnicity, uq_race)
        WITH
        lkp_cv   AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_V_TTF_ETL_SRC + Expression + Lookup_STG_TTF_PTY_INACTIVE_STS + Flt_Remove_Inactive
        active AS (
            SELECT v.CLIENTS_ID, v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME, v.DOB, v.SUBMITDATE, v.SEXID,
                   v.RACEETHNICITYID, v.PTY_SRC_KEY, v.LOAD_DATE,
                   DECODE(v.SEXID, '33', 'F', '34', 'M', 'U')            AS gender,
                   CASE WHEN v.RACEETHNICITYID = '55' THEN '55' ELSE NULL END             AS ethnicity
              FROM V_TTF_ETL_SRC v
             WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        dq AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper15_common(a.FIRSTNAME, a.MIDDLENAME, a.LASTNAME,
                       TRIM(NVL(a.FIRSTNAME, '') || CASE WHEN a.MIDDLENAME IS NOT NULL THEN ' ' || TRIM(a.MIDDLENAME) ELSE '' END
                            || ' ' || NVL(LTRIM(a.LASTNAME), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)        AS nm,
                   PKG_COMMON.fn_snow_helper17_common(a.gender, 'Indv', 'TTF')                            AS gd,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper16_common(a.DOB, 'Indv', 'TTF', l_run_ts)  AS birth_exception_code,
                   et.MSTR_CODE_VALUE                                                          AS ethnicity_mstr,
                   rc.MSTR_CODE_VALUE                                                          AS race_mstr
              FROM active a
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRSTNAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LASTNAME)) AND (jl.IS_LAST_JUNK = 1)
              LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'TTF' AND et.SRC_CODE_VALUE = a.ethnicity
              LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = 'RACE' AND rc.SRC_SYS = 'TTF' AND rc.SRC_CODE_VALUE = a.RACEETHNICITYID
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
                   xr.EXCEPTION_CODE                 AS race_exception_code,
                   xr.EXCEPTION_DESC                 AS race_exception_desc,
                   xr.EXCEPTION_TYPE                 AS race_exception_type
              FROM dq d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.race_mstr, 'Invalid_Race')
        ),
        routed AS (
            SELECT d.*,
                   TRIM(d.PTY_SRC_KEY)                                        AS pkey_trim,
                   TRIM(d.PTY_SRC_KEY) || '|' || P_RLE_BO_CLASS_CD_MEMBER     AS rle_pkey,CASE WHEN d.gender_exception_description IS NOT NULL THEN 1 WHEN NOT (d.gender_exception_description IS NOT NULL) THEN 0 END AS grp_gender,CASE WHEN d.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (d.birth_exception_code IS NOT NULL) THEN 0 END AS grp_birth,CASE WHEN d.ethnicity_exception_code IS NOT NULL THEN 1 WHEN NOT (d.ethnicity_exception_code IS NOT NULL) THEN 0 END AS grp_ethnicity,CASE WHEN d.race_exception_desc IS NOT NULL THEN 1 WHEN NOT (d.race_exception_desc IS NOT NULL) THEN 0 END AS grp_race
              FROM dq2 d
        )
        SELECT r.pkey_trim, r.rle_pkey, r.SUBMITDATE, r.std_prfx_name, r.std_first_name, r.std_mdl_name, r.std_lst_name, r.std_full_name, r.mdm_gender_code, r.std_src_full_name, r.ethnicity_mstr, r.ethnicity, r.race_mstr, r.RACEETHNICITYID, r.std_birth_date, r.PTY_SRC_KEY, r.CLIENTS_ID, r.FIRSTNAME, r.MIDDLENAME, r.LASTNAME, r.gender, r.DOB, r.gender_exception_code, r.gender_exception_description, r.gender_exception_type, r.birth_exception_code, r.birth_exception_description, r.birth_exception_type, r.ethnicity_exception_code, r.ethnicity_exception_desc, r.ethnicity_exception_type, r.race_exception_code, r.race_exception_desc, r.race_exception_type, r.grp_gender, r.grp_birth, r.grp_ethnicity, r.grp_race,
               1 /* TIMELINE: VERSION_SEQ hard-coded */         AS version_seq,
               1                                                 AS hub_state_ind,
               'TTF'                                             AS src_sys,
               l_run_ts                                         AS run_ts,
               c_mapping                                        AS mapping_name,
               P_PTY_BO_CLASS_CD_MEMBER                         AS pty_bo_class_cd,
               P_RLE_BO_CLASS_CD_MEMBER                         AS rle_bo_class_cd,
               TO_CHAR(r.DOB, 'MM/DD/YYYY')                   AS dob_text,
               'Gender'                                          AS attr_gender,
               'Birth Date'                                      AS attr_birth,
               'Ethnicity_Cd'                                    AS attr_ethnicity,
               'Race_Cd'                                         AS attr_race,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1
                AND xp.PKEY_SRC_OBJECT IS NULL) THEN 1 ELSE 0 END AS uq_pty,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.CLIENTS_ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.SUBMITDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.CLIENTS_ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.SUBMITDATE DESC) = 1) THEN 0 END AS uq_gender,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.CLIENTS_ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.SUBMITDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.CLIENTS_ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.SUBMITDATE DESC) = 1) THEN 0 END AS uq_birth,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.CLIENTS_ID,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.SUBMITDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.CLIENTS_ID,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.SUBMITDATE DESC) = 1) THEN 0 END AS uq_ethnicity,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.CLIENTS_ID, r.race_exception_type,
                                               r.race_exception_code ORDER BY r.SUBMITDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.CLIENTS_ID, r.race_exception_type,
                                               r.race_exception_code ORDER BY r.SUBMITDATE DESC) = 1) THEN 0 END AS uq_race
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY WHERE VERSION_SEQ = 1) xp
                 ON xp.PKEY_SRC_OBJECT = r.pkey_trim
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE WHERE VERSION_SEQ = 1) xr2
                 ON xr2.PKEY_SRC_OBJECT = r.rle_pkey;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'stage WRK_TTF_PTY_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_stage;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_pty() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TTF_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, SRC_FULL_NM, ETHNCTY,
            SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM, PERIOD_START_DATE,
            BIRTH_DT)
    SELECT pkey_trim, version_seq, run_ts, submitdate, pkey_trim, hub_state_ind, pty_bo_class_cd,
           std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name, mdm_gender_code,
           std_src_full_name, ethnicity_mstr, ethnicity, race_mstr, raceethnicityid, submitdate, NULL, NULL,
           run_ts, std_birth_date
      FROM WRK_TTF_PTY_ROUTED
     WHERE uq_pty = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TTF_PTY', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_pty;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_rle() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TTF_PTY_RLE
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_FK, RLE_BO_CLASS_CD, SRC_LAST_UPD_DT)
    SELECT rle_pkey, submitdate, version_seq, run_ts, submitdate, rle_pkey, hub_state_ind, pkey_trim,
           rle_bo_class_cd, submitdate
      FROM WRK_TTF_PTY_ROUTED
     WHERE uq_rle = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TTF_PTY_RLE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_rle;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
            MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE, FIRST_NAME, MIDDLE_NAME,
            LAST_NAME)
    SELECT src_sys, gender_exception_type, gender_exception_code, gender_exception_description, attr_gender,
           gender, mapping_name, pty_src_key, clients_id, gender, dob, run_ts, firstname, middlename,
           lastname
      FROM WRK_TTF_PTY_ROUTED
     WHERE grp_gender = 1 AND uq_gender = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
            GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
            BIRTH_DATE)
    SELECT src_sys, pty_src_key, birth_exception_code, birth_exception_description, birth_exception_type,
           run_ts, mapping_name, gender, attr_birth, clients_id, std_prfx_name, firstname, lastname,
           middlename, dob_text, dob
      FROM WRK_TTF_PTY_ROUTED
     WHERE grp_birth = 1 AND uq_birth = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
            SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
            SRC_SYS_ID_2, ATTRIBUTE_VALUE)
    SELECT run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
           attr_ethnicity, gender, pty_src_key, src_sys, firstname, std_lst_name, std_mdl_name,
           mapping_name, dob, submitdate, clients_id, ethnicity
      FROM WRK_TTF_PTY_ROUTED
     WHERE grp_ethnicity = 1 AND uq_ethnicity = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
            FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
            MAPPING_NAME, ATTRIBUTE_VALUE)
    SELECT clients_id, pty_src_key, src_sys, race_exception_code, race_exception_desc, race_exception_type,
           run_ts, firstname, std_mdl_name, std_lst_name, gender, dob, attr_race, std_prfx_name, submitdate,
           mapping_name, raceethnicityid
      FROM WRK_TTF_PTY_ROUTED
     WHERE grp_race = 1 AND uq_race = 1;
    l_rows := l_rows + SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB (party)', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Rle_Alt_Id';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
-- transaction start removed: Oracle transactions are implicit
    -- Not performed: IDQ "truncate target table" of C_S_TTF_PTY_RLE_ALT_ID. This code base never deletes, truncates or drops (rows are only inserted).

    INSERT INTO C_S_TTF_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE, VERSION_SEQ, CREATE_DATE, PTY_RLE_FK,
            ALT_ID_TP, ALT_ID_VAL, ALT_ID_TP_FLTR, STS_CD, PERIOD_START_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, __col1, pkey_src_object, __col3, __col4, SUBMITDATE, __col6, __col7, PTY_SRC_KEY, __col9, __col10, __col11, SUBMITDATE FROM (SELECT k.pkey_src_object, 1 AS __col1, k.pkey_src_object, l_run_ts AS __col3, 1 /* TIMELINE: VERSION_SEQ */ AS __col4, k.SUBMITDATE, NVL(k.PTY_SRC_KEY, '') || '|Member' AS __col6, '024' AS __col7, k.PTY_SRC_KEY, '024' AS __col9, 'Issued' AS __col10, l_run_ts /* TIMELINE: $sys.MappingRunStartTime */ AS __col11, k.SUBMITDATE, ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object ORDER BY k.SUBMITDATE DESC NULLS LAST) AS __qual_rn FROM (SELECT v.PTY_SRC_KEY, v.SUBMITDATE,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|024|' || NVL(v.PTY_SRC_KEY, '') AS pkey_src_object
              FROM V_TTF_ETL_SRC v
             -- Lkp_STG_TTF_PTY_INACTIVE_STS + Filter
             WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                                  AND i.DEACTIVATION_STS IS NOT NULL)) k
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = k.pkey_src_object
     /* BAD DATA: unique key not yet in the table, first row per key in this run */
     WHERE xa.PKEY_SRC_OBJECT IS NULL
    ) WHERE __qual_rn = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TTF_PTY_RLE_ALT_ID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id_alt_id;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_stage() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Rle_Phn';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    DELETE FROM WRK_TTF_PHN_ROUTED;
    INSERT INTO WRK_TTF_PHN_ROUTED (phn_pkey, submitdate, std_phone, phone, pty_src_key, phone_exception_code, phone_exception_desc, version_seq, hub_state_ind, pty_rle_fk, phn_tp, usg_tp, pref_lvl, src_sys, run_ts, mapping_name, exc_type_rejected, attr_phone, uq_phn, uq_phone_exc)
        WITH
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())),
        src AS (
            SELECT v.PHONE, v.SUBMITDATE, v.PTY_SRC_KEY,
                   NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|' || v.PHONE AS phn_pkey,
                   PKG_COMMON.fn_snow_helper23_common(v.PHONE)                             AS std_phone
              FROM V_TTF_ETL_SRC v
             WHERE v.PHONE IS NOT NULL                                           -- Filt_null_phone
               AND NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i          -- fil_deactivated_status
                                WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        checked AS (
            SELECT s.*,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper24_common(s.std_phone, 'TTF', '001', ar.NPA_ID, ar.SERVICE) AS phone_exception_code
              FROM src s
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(s.std_phone, 1, 3)
        )
        SELECT c.phn_pkey, c.SUBMITDATE, c.std_phone, c.PHONE, c.PTY_SRC_KEY, c.phone_exception_code,
               xp.EXCEPTION_DESC                                    AS phone_exception_desc,
               '1' /* TIMELINE: VERSION_SEQ */                     AS version_seq,
               1                                                    AS hub_state_ind,
               NVL(c.PTY_SRC_KEY, '') || '|Member'                  AS pty_rle_fk,
               'Telephone'                                          AS phn_tp,
               '001'                                                AS usg_tp,
               'Primary'                                            AS pref_lvl,
               'TTF'                                                AS src_sys,
               l_run_ts                                            AS run_ts,
               c_mapping                                           AS mapping_name,
               'Rejected Record'                                    AS exc_type_rejected,
               'Main Phone'                                         AS attr_phone,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN (ROW_NUMBER() OVER (PARTITION BY CASE WHEN c.phone_exception_code IS NULL THEN 1 WHEN NOT (c.phone_exception_code IS NULL) THEN 0 END , c.phn_pkey
                                       ORDER BY c.SUBMITDATE DESC) = 1
                AND xph.PKEY_SRC_OBJECT IS NULL) THEN 1 ELSE 0 END AS uq_phn,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN c.phone_exception_code IS NULL THEN 1 WHEN NOT (c.phone_exception_code IS NULL) THEN 0 END , c.PTY_SRC_KEY, c.phone_exception_code
                                      ORDER BY c.SUBMITDATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN c.phone_exception_code IS NULL THEN 1 WHEN NOT (c.phone_exception_code IS NULL) THEN 0 END , c.PTY_SRC_KEY, c.phone_exception_code
                                      ORDER BY c.SUBMITDATE DESC) = 1) THEN 0 END AS uq_phone_exc
          FROM checked c
          LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
                 ON xph.PKEY_SRC_OBJECT = c.phn_pkey;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'stage WRK_TTF_PHN_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_stage;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_phn() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Rle_Phn';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TTF_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT)
    SELECT phn_pkey, submitdate, version_seq, run_ts, phn_pkey, hub_state_ind, pty_rle_fk, phn_tp, usg_tp,
           std_phone, pref_lvl, submitdate
      FROM WRK_TTF_PHN_ROUTED
     WHERE phone_exception_code IS NULL AND uq_phn = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TTF_PTY_RLE_PHN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_phn;


    FUNCTION sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TTF_Pty_Rle_Phn';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME,
            SRC_SYS_ID_2)
    SELECT src_sys, phone_exception_code, phone_exception_desc, run_ts, phone, NULL, NULL, mapping_name,
           pty_src_key, exc_type_rejected, submitdate, phone, attr_phone, NULL
      FROM WRK_TTF_PHN_ROUTED
     WHERE phone_exception_code IS NOT NULL AND uq_phone_exc = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB (phone)', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_exc;

END PKG_TTF;
/
