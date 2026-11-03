-- ECI discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_ECI AS


    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Validation';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP() of RUN_DATE / ACTION_DT
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_log VARCHAR2(4000) := '';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_VALIDATION_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_VALIDATION_ROUTED (
    DATE_CREATED DATE,
    DOB DATE,
    action_deactivation VARCHAR2(4000),
    action_reactivation VARCHAR2(4000),
    deactivation_sts VARCHAR2(4000),
    exc_attribute_name VARCHAR2(4000),
    exc_attribute_value VARCHAR2(4000),
    exc_code_name VARCHAR2(4000),
    exc_desc_name VARCHAR2(4000),
    exc_type_name VARCHAR2(4000),
    grp_deactivation NUMBER,
    grp_invalid_party_name NUMBER,
    grp_reactivation NUMBER,
    mapping_name VARCHAR2(4000),
    new_deactivation_sts VARCHAR2(4000),
    pkey_src_object VARCHAR2(4000),
    run_ts TIMESTAMP,
    src_system VARCHAR2(4000),
    std_first_name VARCHAR2(4000),
    std_lst_name VARCHAR2(4000),
    std_mdl_name VARCHAR2(4000),
    uq_exc_name NUMBER
)';
    INSERT INTO WRK_ECI_VALIDATION_ROUTED (DATE_CREATED, DOB, action_deactivation, action_reactivation, deactivation_sts, exc_attribute_name, exc_attribute_value, exc_code_name, exc_desc_name, exc_type_name, grp_deactivation, grp_invalid_party_name, grp_reactivation, mapping_name, new_deactivation_sts, pkey_src_object, run_ts, src_system, std_first_name, std_lst_name, std_mdl_name, uq_exc_name)
    SELECT DATE_CREATED, DOB, action_deactivation, action_reactivation, deactivation_sts, exc_attribute_name, exc_attribute_value, exc_code_name, exc_desc_name, exc_type_name, grp_deactivation, grp_invalid_party_name, grp_reactivation, mapping_name, new_deactivation_sts, pkey_src_object, run_ts, src_system, std_first_name, std_lst_name, std_mdl_name, uq_exc_name FROM (
    WITH
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_STG_ECI_D_CHILD_and_FAMILY (custom SQL, query mode SEMI)
        src AS (
            SELECT 'ECI_CHILD' AS SOURCE_TABLE, c.ID_CHILD AS ID, c.FIRST_NAME, c.LAST_NAME, c.MIDDLE_INITIAL,
                   c.DOB, c.DATE_CREATED, c.DATE_MODIFIED, c.MODIFIED_BY, c.CREATED_BY, c.LOAD_DATE
              FROM STG_ECI_D_CHILD c
            UNION ALL
            SELECT 'ECI_FAMILY' AS SOURCE_TABLE, fam.ID_FAMILY AS ID, fam.FIRST_NAME, fam.LAST_NAME,
                   fam.MIDDLE_INITIAL, fam.DOB, fam.DATE_CREATED, fam.DATE_MODIFIED, fam.MODIFIED_BY,
                   fam.CREATED_BY, fam.LOAD_DATE
              FROM STG_ECI_D_FAMILY fam
        ),
        -- Exp_ECI_Data_Load
        exp_load AS (
            SELECT s.*,
                   LPAD(TO_CHAR(s.ID), 10, '0') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END   AS pkey_src_object,
                   'ECI'                                                                           AS src_system,
                   SUBSTR(TRIM(NVL(s.FIRST_NAME, '')
                               || CASE WHEN s.MIDDLE_INITIAL IS NOT NULL THEN ' ' || TRIM(s.MIDDLE_INITIAL) ELSE '' END
                               || ' ' || NVL(LTRIM(s.LAST_NAME), '')), 1, 10)                       AS full_name
              FROM src s
        ),
        -- lookups of the mapping
        sts AS (    -- Lookup_STG_ECI_PTY_INACTIVE_STS (any row)
            SELECT SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS FROM (SELECT i.SRC_KEY, i.ROWID_SYSTEM, i.DEACTIVATION_STS, ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY, i.ROWID_SYSTEM
                                          ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) AS __qual_rn FROM STG_ECI_PTY_INACTIVE_STS i
           ) WHERE __qual_rn = 1
        ),
        xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'ECI')
            SELECT PKEY_SRC_OBJECT, HUB_STATE_IND FROM (SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND, ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) AS __qual_rn FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'ECI'
           ) WHERE __qual_rn = 1
        ),
        dup AS (    -- Lookup_V_ECI_ETL_LU_DUP_CASES
            SELECT DISTINCT d.SOURCE_TABLE, d.ID FROM V_ECI_ETL_LU_DUP_CASES d
        ),
        fam AS (    -- Lookup_V_ECI_ETL_LU_FAMILY_VALIDATION
            SELECT SOURCE_TABLE, ID_FAMILY, FAM_NAME_STATUS, FAM_PHONE_AND_ADDRESS_STS, FAM_INACTIVE_STS FROM (SELECT f.SOURCE_TABLE, f.ID_FAMILY, f.FAM_NAME_STATUS, f.FAM_PHONE_AND_ADDRESS_STS, f.FAM_INACTIVE_STS, ROW_NUMBER() OVER (PARTITION BY f.SOURCE_TABLE, f.ID_FAMILY ORDER BY f.ID_FAMILY) AS __qual_rn FROM V_ECI_ETL_LU_FAMILY_VALIDATION f
           ) WHERE __qual_rn = 1
        ),
        -- lookups + mplt_Name_Standardization_Indv_Member
        enriched AS (
            SELECT e.*,
                   sts.DEACTIVATION_STS                                                    AS deactivation_sts,
                   xref.HUB_STATE_IND                                                      AS hub_state_ind,
                   dup.ID                                                                  AS omit_id,
                   CASE WHEN fam.FAM_NAME_STATUS IS NULL AND fam.FAM_PHONE_AND_ADDRESS_STS IS NULL AND fam.FAM_INACTIVE_STS IS NULL THEN 'N' ELSE 'Y' END AS fam_inactive_yn,
                   -- no prefix / suffix is passed, so their lookups cannot match
                   PKG_COMMON.fn_snow_helper15_common(e.FIRST_NAME, e.MIDDLE_INITIAL, e.LAST_NAME, e.full_name, NULL, NULL,
                                           NULL, NULL, CASE WHEN jf.NAME IS NOT NULL THEN 1 ELSE 0 END, CASE WHEN jl.NAME IS NOT NULL THEN 1 ELSE 0 END) AS nm
              FROM exp_load e
              LEFT JOIN sts  ON sts.SRC_KEY = e.pkey_src_object AND sts.ROWID_SYSTEM = e.src_system
              LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = e.pkey_src_object
              LEFT JOIN dup  ON dup.SOURCE_TABLE = e.SOURCE_TABLE AND dup.ID = e.ID
              LEFT JOIN fam  ON fam.SOURCE_TABLE = e.SOURCE_TABLE AND fam.ID_FAMILY = e.ID
              -- junk-name lookups inside mplt_Name_Standardization_Indv_Member
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(e.FIRST_NAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(e.LAST_NAME)) AND (jl.IS_LAST_JUNK = 1)
        ),
        -- Exp_Consolidate_Exceptions + Rtr_Valid_Party conditions + Exp_Invalid_PTY_NM
        named AS (
            SELECT n.*,
                   CAST(n.nm.first_name AS VARCHAR2(4000))  AS std_first_name,
                   CAST(n.nm.middle_name AS VARCHAR2(4000)) AS std_mdl_name,
                   CAST(n.nm.last_name AS VARCHAR2(4000))   AS std_lst_name,
                   /* VALIDATION */ CASE WHEN PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.first_name AS VARCHAR2(4000))) = 1 OR PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.last_name AS VARCHAR2(4000))) = 1 THEN 1 ELSE 0 END AS name_missing
              FROM enriched n
        ),
        routed AS (
            SELECT r.*,CASE WHEN r.name_missing = 1 AND r.fam_inactive_yn = 'N' THEN 1 WHEN NOT (r.name_missing = 1 AND r.fam_inactive_yn = 'N') THEN 0 END AS grp_invalid_party_name,CASE WHEN r.name_missing = 1 OR r.omit_id IS NOT NULL OR r.fam_inactive_yn = 'Y' THEN 1 WHEN NOT (r.name_missing = 1 OR r.omit_id IS NOT NULL OR r.fam_inactive_yn = 'Y') THEN 0 END AS grp_deactivation,CASE WHEN r.deactivation_sts IS NOT NULL AND NOT (r.name_missing = 1) AND r.omit_id IS NULL
                    AND r.fam_inactive_yn = 'N' THEN 1 WHEN NOT (r.deactivation_sts IS NOT NULL AND NOT (r.name_missing = 1) AND r.omit_id IS NULL
                    AND r.fam_inactive_yn = 'N') THEN 0 END AS grp_reactivation,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'Missing_First_Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Missing_Last_Name' END AS exc_code_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN 'First Name'
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN 'Last Name' END        AS exc_attribute_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_first_name) = 1) THEN r.std_first_name
                        WHEN (PKG_COMMON.fn_snow_helper03_common(r.std_lst_name) = 1) THEN r.std_lst_name END     AS exc_attribute_value,
                   PKG_COMMON.fn_snow_helper02_common(r.hub_state_ind)                                      AS new_deactivation_sts
              FROM named r
        )
        SELECT r.*,
               ex.EXCEPTION_DESC     AS exc_desc_name,
               ex.EXCEPTION_TYPE     AS exc_type_name,
               l_run_ts             AS run_ts,
               c_mapping            AS mapping_name,
               'Deactivation'        AS action_deactivation,
               'Reactivation'        AS action_reactivation,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.src_system, r.pkey_src_object,
                                               ex.EXCEPTION_TYPE, r.exc_code_name
                                      ORDER BY r.ID) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.src_system, r.pkey_src_object,
                                               ex.EXCEPTION_TYPE, r.exc_code_name
                                      ORDER BY r.ID) = 1) THEN 0 END AS uq_exc_name
          FROM routed r
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_VALIDATION_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Write_Invalid_Party_Name (Exp_Invalid_PTY_NM + Lkp_EXC_LOOKUP_CODE_VALUE_Name)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME,
                  PERIOD_START_DATE)
    SELECT src_system, pkey_src_object, exc_code_name, exc_desc_name, exc_type_name, run_ts,
                    std_first_name, std_mdl_name, std_lst_name, DOB, exc_attribute_name, exc_attribute_value,
                    mapping_name, DATE_CREATED
      FROM WRK_ECI_VALIDATION_ROUTED
     WHERE (grp_invalid_party_name = 1) AND (uq_exc_name = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_exc;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_log() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        -- Write_Deactv_STG_ECI_PTY_INACTIVE_LOG (Exp_Log_Deactv)
        WHEN (grp_deactivation = 1) THEN
            INTO STG_ECI_PTY_INACTIVE_LOG
                 (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
            VALUES (pkey_src_object, src_system, action_deactivation, run_ts)
        -- Write_STG_ECI_PTY_INACTIVE_LOG (Exp_Log_Reactv)
        WHEN (grp_reactivation = 1) THEN
            INTO STG_ECI_PTY_INACTIVE_LOG
                 (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
            VALUES (pkey_src_object, src_system, action_reactivation, run_ts)
    SELECT * FROM WRK_ECI_VALIDATION_ROUTED;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_ECI_PTY_INACTIVE_LOG', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_log;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_sts() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Validation';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Filt_new_deactivations: IsNull(DEACTIVATION_STS) -> Write_new_STG_ECI_PTY_INACTIVE_STS (Exp_New_Deactvn_Sts)
    INSERT INTO STG_ECI_PTY_INACTIVE_STS
           (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    SELECT pkey_src_object, src_system, new_deactivation_sts, run_ts
      FROM WRK_ECI_VALIDATION_ROUTED
     WHERE (grp_deactivation = 1) AND deactivation_sts IS NULL;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_ECI_PTY_INACTIVE_STS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation_inactive_sts;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_prep(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty';
    c_exc_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_OnGoing';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP() / SYSDATE
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
    l_log VARCHAR2(4000) := '';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_PTY_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_PTY_ROUTED (
    CREATED_BY VARCHAR2(4000),
    DATE_CREATED DATE,
    DATE_MODIFIED DATE,
    DOB DATE,
    ETHNICITY VARCHAR2(4000),
    FIRST_NAME VARCHAR2(4000),
    GENDER VARCHAR2(4000),
    ID NUMBER,
    LANGUAGE_CD VARCHAR2(4000),
    LAST_NAME VARCHAR2(4000),
    MIDDLE_INITIAL VARCHAR2(4000),
    MODIFIED_BY VARCHAR2(4000),
    attr_birth VARCHAR2(4000),
    attr_ethnicity VARCHAR2(4000),
    attr_gender VARCHAR2(4000),
    attr_language VARCHAR2(4000),
    attr_race VARCHAR2(4000),
    birth_exception_code VARCHAR2(4000),
    birth_exception_description VARCHAR2(4000),
    birth_exception_type VARCHAR2(4000),
    birth_wght_grms NUMBER,
    dob_text VARCHAR2(4000),
    ethnicity_exception_code VARCHAR2(4000),
    ethnicity_exception_desc VARCHAR2(4000),
    ethnicity_exception_type VARCHAR2(4000),
    ethnicity_mstr VARCHAR2(4000),
    exc_mapping VARCHAR2(4000),
    gender_exception_code VARCHAR2(4000),
    gender_exception_description VARCHAR2(4000),
    gender_exception_type VARCHAR2(4000),
    grp_birth NUMBER,
    grp_ethnicity NUMBER,
    grp_gender NUMBER,
    grp_language NUMBER,
    grp_race NUMBER,
    hub_state_ind NUMBER,
    language_exception_code VARCHAR2(4000),
    language_exception_desc VARCHAR2(4000),
    language_exception_type VARCHAR2(4000),
    language_mstr VARCHAR2(4000),
    mdm_gender_code VARCHAR2(4000),
    mdm_race_cd VARCHAR2(4000),
    pkey_src_object VARCHAR2(4000),
    pkey_trim VARCHAR2(4000),
    pty_bo_class_cd VARCHAR2(4000),
    race_exception_cd VARCHAR2(4000),
    race_exception_desc VARCHAR2(4000),
    race_exception_type VARCHAR2(4000),
    rle_bo_class_cd VARCHAR2(4000),
    rle_pkey VARCHAR2(4000),
    run_ts TIMESTAMP,
    src_race_ind_list VARCHAR2(4000),
    src_system VARCHAR2(4000),
    std_birth_date VARCHAR2(4000),
    std_first_name VARCHAR2(4000),
    std_full_name VARCHAR2(4000),
    std_lst_name VARCHAR2(4000),
    std_mdl_name VARCHAR2(4000),
    std_prfx_name VARCHAR2(4000),
    std_src_full_name VARCHAR2(4000),
    uq_birth NUMBER,
    uq_ethnicity NUMBER,
    uq_gender NUMBER,
    uq_language NUMBER,
    uq_pty NUMBER,
    uq_race NUMBER,
    uq_rle NUMBER,
    version_seq NUMBER
)';
    INSERT INTO WRK_ECI_PTY_ROUTED (CREATED_BY, DATE_CREATED, DATE_MODIFIED, DOB, ETHNICITY, FIRST_NAME, GENDER, ID, LANGUAGE_CD, LAST_NAME, MIDDLE_INITIAL, MODIFIED_BY, attr_birth, attr_ethnicity, attr_gender, attr_language, attr_race, birth_exception_code, birth_exception_description, birth_exception_type, birth_wght_grms, dob_text, ethnicity_exception_code, ethnicity_exception_desc, ethnicity_exception_type, ethnicity_mstr, exc_mapping, gender_exception_code, gender_exception_description, gender_exception_type, grp_birth, grp_ethnicity, grp_gender, grp_language, grp_race, hub_state_ind, language_exception_code, language_exception_desc, language_exception_type, language_mstr, mdm_gender_code, mdm_race_cd, pkey_src_object, pkey_trim, pty_bo_class_cd, race_exception_cd, race_exception_desc, race_exception_type, rle_bo_class_cd, rle_pkey, run_ts, src_race_ind_list, src_system, std_birth_date, std_first_name, std_full_name, std_lst_name, std_mdl_name, std_prfx_name, std_src_full_name, uq_birth, uq_ethnicity, uq_gender, uq_language, uq_pty, uq_race, uq_rle, version_seq)
    SELECT CREATED_BY, DATE_CREATED, DATE_MODIFIED, DOB, ETHNICITY, FIRST_NAME, GENDER, ID, LANGUAGE_CD, LAST_NAME, MIDDLE_INITIAL, MODIFIED_BY, attr_birth, attr_ethnicity, attr_gender, attr_language, attr_race, birth_exception_code, birth_exception_description, birth_exception_type, birth_wght_grms, dob_text, ethnicity_exception_code, ethnicity_exception_desc, ethnicity_exception_type, ethnicity_mstr, exc_mapping, gender_exception_code, gender_exception_description, gender_exception_type, grp_birth, grp_ethnicity, grp_gender, grp_language, grp_race, hub_state_ind, language_exception_code, language_exception_desc, language_exception_type, language_mstr, mdm_gender_code, mdm_race_cd, pkey_src_object, pkey_trim, pty_bo_class_cd, race_exception_cd, race_exception_desc, race_exception_type, rle_bo_class_cd, rle_pkey, run_ts, src_race_ind_list, src_system, std_birth_date, std_first_name, std_full_name, std_lst_name, std_mdl_name, std_prfx_name, std_src_full_name, uq_birth, uq_ethnicity, uq_gender, uq_language, uq_pty, uq_race, uq_rle, version_seq FROM (
    WITH
        lkp_cv   AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_STG_ECI_D_CHILD_AND_FAMILY (custom SQL, query mode SEMI)
        src AS (
            SELECT 'ECI_CHILD' AS SOURCE_TABLE, child.ID_CHILD AS ID, child.CHILD_SSN, child.FIRST_NAME,
                   child.LAST_NAME, child.MIDDLE_INITIAL, child.DOB, child.GESTATION_AGE, child.GENDER,
                   child.BIRTH_WT_LB, child.BIRTH_WT_OZ, child.INTERPRET_IND, child.LANGUAGE_CD, child.RACE_CD,
                   child.DATE_CREATED, COALESCE(child.DATE_MODIFIED, child.DATE_CREATED) AS DATE_MODIFIED,
                   child.MODIFIED_BY, child.CREATED_BY, child.ETHNICITY, child.RACE_WHITE, child.RACE_AA,
                   child.RACE_ASIAN, child.RACE_PI, child.RACE_AN, child.LOAD_DATE
              FROM STG_ECI_D_CHILD child
            UNION ALL
            SELECT 'ECI_FAMILY', fam.ID_FAMILY, NULL, fam.FIRST_NAME, fam.LAST_NAME, fam.MIDDLE_INITIAL, fam.DOB,
                   NULL, fam.GENDER, NULL, NULL, NULL, NULL, NULL, fam.DATE_CREATED,
                   COALESCE(fam.DATE_MODIFIED, fam.DATE_CREATED), fam.MODIFIED_BY, fam.CREATED_BY, NULL, NULL,
                   NULL, NULL, NULL, NULL, fam.LOAD_DATE
              FROM STG_ECI_D_FAMILY fam
        ),
        -- Exp_ECI_Data_Load
        exp_load AS (
            SELECT s.*,
                   LPAD(TO_CHAR(s.ID), 10, '0') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END  AS pkey_src_object,
                   'Indv' AS party_type,
                   'ECI'  AS src_system,
                   TRIM(NVL(s.FIRST_NAME, '')
                        || CASE WHEN s.MIDDLE_INITIAL IS NOT NULL THEN ' ' || TRIM(s.MIDDLE_INITIAL) ELSE '' END
                        || ' ' || NVL(LTRIM(s.LAST_NAME), ''))                                      AS src_full_name
              FROM src s
        ),
        -- Lkp_STG_ECI_PTY_INACTIVE_STS + Flt_Remove_Inactive
        active AS (
            SELECT e.*
              FROM exp_load e
             WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = e.pkey_src_object AND i.ROWID_SYSTEM = e.src_system
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- mapplets, step 1: lookups and the rule functions
        dq AS (
            SELECT a.*,
                   PKG_COMMON.fn_snow_helper15_common(a.FIRST_NAME, a.MIDDLE_INITIAL, a.LAST_NAME, a.src_full_name, NULL, NULL,
                                           NULL, NULL, CASE WHEN jf.NAME IS NOT NULL THEN 1 ELSE 0 END, CASE WHEN jl.NAME IS NOT NULL THEN 1 ELSE 0 END)       AS nm,
                   PKG_COMMON.fn_snow_helper17_common(a.GENDER, a.party_type, a.src_system)                       AS gd,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper16_common(a.DOB, a.party_type, a.src_system, l_run_ts) AS birth_exception_code,
                   et.MSTR_CODE_VALUE                                                                  AS ethnicity_mstr,
                   PKG_COMMON.fn_snow_helper19_common(a.RACE_WHITE, a.RACE_AA, a.RACE_ASIAN, a.RACE_PI, a.RACE_AN) AS rc,
                   lg.MSTR_CODE_VALUE                                                                  AS language_mstr
              FROM active a
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRST_NAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LAST_NAME)) AND (jl.IS_LAST_JUNK = 1)
              LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = a.src_system
                                 AND et.SRC_CODE_VALUE = a.ETHNICITY
              LEFT JOIN lkp_cv lg ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = a.src_system
                                 AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD
        ),
        -- mapplets, step 2: the exception catalogue (EXC_LOOKUP_CODE_VALUE) of every rule
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
                   /* BAD DATA */ CASE WHEN d.birth_exception_code IS NULL THEN d.DOB ELSE NULL END AS std_birth_date,
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
                   xl.EXCEPTION_TYPE                              AS language_exception_type
              FROM dq d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = CAST(d.rc.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.language_mstr, 'Invalid_Language')
        ),
        -- Exp_Consolidate_Exceptions / exp_Party_Consolidation + Rtr_Exception groups
        routed AS (
            SELECT d.*,
                   TRIM(d.pkey_src_object)                                   AS pkey_trim,   -- o_PKEY_SRC_OBJECT
                   TRIM(d.pkey_src_object) || '|' || P_RLE_BO_CLASS_CD_MEMBER AS rle_pkey,CASE WHEN d.gender_exception_description IS NOT NULL THEN 1 WHEN NOT (d.gender_exception_description IS NOT NULL) THEN 0 END AS grp_gender,CASE WHEN d.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (d.birth_exception_code IS NOT NULL) THEN 0 END AS grp_birth,CASE WHEN d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD' THEN 1 WHEN NOT (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD') THEN 0 END AS grp_ethnicity,CASE WHEN d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD' THEN 1 WHEN NOT (d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD') THEN 0 END AS grp_race,CASE WHEN d.language_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD' THEN 1 WHEN NOT (d.language_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD') THEN 0 END AS grp_language
              FROM dq2 d
        )
        SELECT r.*,
               1 /* TIMELINE: VERSION_SEQ hard-coded */                AS version_seq,
               1                                                        AS hub_state_ind,
               l_run_ts                                                AS run_ts,
               c_exc_mapping                                           AS exc_mapping,
               P_PTY_BO_CLASS_CD_MEMBER                                AS pty_bo_class_cd,
               P_RLE_BO_CLASS_CD_MEMBER                                AS rle_bo_class_cd,
               r.BIRTH_WT_LB * 453.6 + r.BIRTH_WT_OZ * 28.35            AS birth_wght_grms,
               TO_CHAR(r.DOB, 'MM/DD/YYYY')                          AS dob_text,
               'Gender'                                                 AS attr_gender,
               'Birth Date'                                             AS attr_birth,
               'Ethnicity_Cd'                                           AS attr_ethnicity,
               'Race_Cd'                                                AS attr_race,
               'Language_Cd'                                            AS attr_language,
               /* BAD DATA: unique keys Snowflake does not enforce (first row per key; key not yet in the table) */
               CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1 AND xp.PKEY_SRC_OBJECT IS NULL THEN 1 ELSE 0 END                         AS uq_pty,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1
                AND xr2.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.pkey_src_object, r.ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.pkey_src_object, r.ID, r.gender_exception_type,
                                               r.gender_exception_code ORDER BY r.ID) = 1) THEN 0 END AS uq_gender,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.pkey_src_object, r.ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.pkey_src_object, r.ID, r.birth_exception_type,
                                               r.birth_exception_code ORDER BY r.ID) = 1) THEN 0 END AS uq_birth,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.pkey_src_object, r.ID,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.pkey_src_object, r.ID,
                                               r.ethnicity_exception_type, r.ethnicity_exception_code
                                      ORDER BY r.ID) = 1) THEN 0 END AS uq_ethnicity,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.pkey_src_object, r.ID, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.pkey_src_object, r.ID, r.race_exception_type,
                                               r.race_exception_cd ORDER BY r.ID) = 1) THEN 0 END AS uq_race,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.pkey_src_object, r.ID,
                                               r.language_exception_type, r.language_exception_code
                                      ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.pkey_src_object, r.ID,
                                               r.language_exception_type, r.language_exception_code
                                      ORDER BY r.ID) = 1) THEN 0 END AS uq_language
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY WHERE VERSION_SEQ = 1) xp
                 ON xp.PKEY_SRC_OBJECT = r.pkey_trim
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE WHERE VERSION_SEQ = 1) xr2
                 ON xr2.PKEY_SRC_OBJECT = r.rle_pkey
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_PTY_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_pty() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Rtr_Exception.Valid_Party (TRUE) -> exp_Party_Consolidation -> Write_C_S_ECI_PTY
    INSERT INTO C_S_ECI_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
                  PTY_BO_CLASS_CD, PRFX_NM, FULL_NM, LST_NM, MDL_NM, FRST_NM, GNDR_CD, BIRTH_DT, SRC_FULL_NM,
                  SRC_LAST_UPD_DT, BIRTH_WGHT_GRMS, HUB_STATE_IND, SRC_ETHNCTY, ETHNCTY, RACE_CD, PRFRD_LANG_CD,
                  SRC_PRFRD_LANG_CD, SRC_RACE_CD, PERIOD_START_DATE)
    SELECT pkey_trim, version_seq, run_ts, MODIFIED_BY, DATE_CREATED, CREATED_BY, pkey_trim,
                    pty_bo_class_cd, std_prfx_name, std_full_name, std_lst_name, std_mdl_name, std_first_name,
                    mdm_gender_code, std_birth_date, std_src_full_name, DATE_MODIFIED, birth_wght_grms,
                    hub_state_ind, ETHNICITY, ethnicity_mstr, mdm_race_cd, language_mstr, LANGUAGE_CD,
                    src_race_ind_list, DATE_MODIFIED
      FROM WRK_ECI_PTY_ROUTED
     WHERE (uq_pty = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_pty;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_pty_rle() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Rtr_Exception.Valid_Party -> Write_C_S_ECI_PTY_RLE
    INSERT INTO C_S_ECI_PTY_RLE
           (PKEY_SRC_OBJECT, LAST_UPDATE_DATE, CREATOR, CREATE_DATE, VERSION_SEQ, PTY_FK, SRC_LAST_UPD_DT,
                  RLE_BO_CLASS_CD, PERIOD_START_DATE, HUB_STATE_IND, SRC_ROWID)
    SELECT rle_pkey, run_ts, CREATED_BY, DATE_CREATED, version_seq, pkey_trim, DATE_MODIFIED,
                    rle_bo_class_cd, DATE_CREATED, hub_state_ind, rle_pkey
      FROM WRK_ECI_PTY_ROUTED
     WHERE (uq_rle = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_pty_rle;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        -- Rtr_Exception.Invalid_Gender_Code -> Exp_Invalid_Gender -> Write_Invalid_Party_Gender
        WHEN (grp_gender = 1) AND (uq_gender = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE)
            VALUES (src_system, gender_exception_type, gender_exception_code, gender_exception_description,
                    attr_gender, GENDER, exc_mapping, pkey_src_object, ID, GENDER, DOB, run_ts)
        -- Rtr_Exception.Invalid_Birth_Date -> Exp_Invalid_DOB -> Write_Invalid_Party_DOB
        WHEN (grp_birth = 1) AND (uq_birth = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
                  GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
                  BIRTH_DATE)
            VALUES (src_system, pkey_src_object, birth_exception_code, birth_exception_description,
                    birth_exception_type, run_ts, exc_mapping, GENDER, attr_birth, ID, std_prfx_name,
                    FIRST_NAME, LAST_NAME, MIDDLE_INITIAL, dob_text, DOB)
        -- Rtr_Exception.Invalid_Ethnicity -> Exp_Load_Ethnicity_Exceptions -> Write_Invalid_Party_Ethnicity
        WHEN (grp_ethnicity = 1) AND (uq_ethnicity = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
                  SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
                  SRC_SYS_ID_2, ATTRIBUTE_VALUE)
            VALUES (run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
                    attr_ethnicity, GENDER, pkey_src_object, src_system, FIRST_NAME, std_lst_name, std_mdl_name,
                    exc_mapping, DOB, DATE_CREATED, ID, ETHNICITY)
        -- Rtr_Exception.Invalid_Race -> Exp_Load_Race_Exceptions -> Write_Invalid_Party_Race
        WHEN (grp_race = 1) AND (uq_race = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
                  MAPPING_NAME, ATTRIBUTE_VALUE)
            VALUES (ID, pkey_src_object, src_system, race_exception_cd, race_exception_desc, race_exception_type,
                    run_ts, FIRST_NAME, std_mdl_name, std_lst_name, GENDER, DOB, attr_race, std_prfx_name,
                    DATE_CREATED, exc_mapping, src_race_ind_list)
        -- Rtr_Exception.Invalid_Language -> Exp_Load_Language_Exceptions -> Write_Invalid_Party_Language
        WHEN (grp_language = 1) AND (uq_language = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
                  FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
                  MAPPING_NAME, PERIOD_START_DATE)
            VALUES (src_system, pkey_src_object, ID, language_exception_type, language_exception_code,
                    language_exception_desc, run_ts, FIRST_NAME, std_mdl_name, std_lst_name, std_birth_date,
                    GENDER, attr_language, LANGUAGE_CD, exc_mapping, DATE_CREATED)
    SELECT * FROM WRK_ECI_PTY_ROUTED;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_exc;


    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr_load() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
-- transaction start removed: Oracle transactions are implicit
    INSERT INTO STG_ECI_D_FAMILY_ADDRESS
           (ID_FAMILY_ADDRESS, ID_FAMILY, ID_CASE, ADDRESS_CD, ADDRESS1, ADDRESS2, ID_ST_CITY_CNTY_ZIP, CITY_NAME,
            COUNTY_NAME, ZIP_CODE, ZIP_SFX, STATE_ABBREV, CANCEL_DATE, DATE_CREATED, DATE_MODIFIED, MODIFIED_BY,
            CREATED_BY, LOAD_DATE)
    SELECT h.ID_FAMILY_ADDRESS, h.ID_FAMILY, h.ID_CASE, h.ADDRESS_CD, h.ADDRESS1, h.ADDRESS2, h.ID_ST_CITY_CNTY_ZIP,
           h.CITY_NAME, h.COUNTY_NAME, h.ZIP_CODE, h.ZIP_SFX, h.STATE_ABBREV, h.CANCEL_DATE, h.DATE_CREATED,
           h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.LOAD_DATE
      FROM STG_ECI_H_FAMILY_ADDRESS h
     -- Read_STG_ECI_H_FAMILY_ADDRESS source filter: (ID_FAMILY_ADDRESS, LOAD_DATE) IN (latest per address)
     INNER JOIN (SELECT ID_FAMILY_ADDRESS, MAX(LOAD_DATE) AS MAX_LOAD_DATE
                   FROM STG_ECI_H_FAMILY_ADDRESS
                  WHERE ID_FAMILY IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_FAMILY')
                  GROUP BY ID_FAMILY_ADDRESS) m
             ON m.ID_FAMILY_ADDRESS = h.ID_FAMILY_ADDRESS AND m.MAX_LOAD_DATE = h.LOAD_DATE
     -- Lookup_STG_ECI_D_FAMILY_ADDRESS + Filt_Keep_New_Addr: IsNull(LKP_ID_FAMILY_ADDRESS)
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_D_FAMILY_ADDRESS d
                        WHERE d.ID_FAMILY_ADDRESS = h.ID_FAMILY_ADDRESS);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_ECI_D_FAMILY_ADDRESS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr_load;


    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn_load() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
-- transaction start removed: Oracle transactions are implicit
    INSERT INTO STG_ECI_D_FAMILY_PHONE
           (ID_FAMILY_PHONE, ID_FAMILY, ID_CASE, HOME_AC, HOME_NBR, WORK_AC, WORK_NBR, WORK_EXT, CELL_AC, CELL_NBR,
            FAX_AC, FAX_NBR, PAGER_AC, PAGER_NBR, OTHER_AC, OTHER_NBR, EMAIL_ADDRESS, DATE_CREATED, DATE_MODIFIED,
            MODIFIED_BY, CREATED_BY, CHILD_RESIDES_IND, INACTIVE_IND, PRIMARY_CONTACT_IND, LOAD_DATE)
    SELECT h.ID_FAMILY_PHONE, h.ID_FAMILY, h.ID_CASE, h.HOME_AC, h.HOME_NBR, h.WORK_AC, h.WORK_NBR, h.WORK_EXT,
           h.CELL_AC, h.CELL_NBR, h.FAX_AC, h.FAX_NBR, h.PAGER_AC, h.PAGER_NBR, h.OTHER_AC, h.OTHER_NBR,
           h.EMAIL_ADDRESS, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CHILD_RESIDES_IND,
           h.INACTIVE_IND, h.PRIMARY_CONTACT_IND, h.LOAD_DATE
      FROM STG_ECI_H_FAMILY_PHONE h
     -- Read_STG_ECI_H_FAMILY_PHONE source filter: (ID_FAMILY_PHONE, LOAD_DATE) IN (latest per phone record)
     INNER JOIN (SELECT ID_FAMILY_PHONE, MAX(LOAD_DATE) AS MAX_LOAD_DATE
                   FROM STG_ECI_H_FAMILY_PHONE
                  WHERE ID_FAMILY IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_FAMILY')
                  GROUP BY ID_FAMILY_PHONE) m
             ON m.ID_FAMILY_PHONE = h.ID_FAMILY_PHONE AND m.MAX_LOAD_DATE = h.LOAD_DATE
     -- Lookup_STG_ECI_D_FAMILY_PHONE + Filt_Keep_New_Phone: IsNull(lkp_ID_FAMILY_PHONE)
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_D_FAMILY_PHONE d
                        WHERE d.ID_FAMILY_PHONE = h.ID_FAMILY_PHONE);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_ECI_D_FAMILY_PHONE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn_load;


    FUNCTION sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid_load(P_TEST_LOOKUP_RESULT IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
-- transaction start removed: Oracle transactions are implicit
    INSERT INTO STG_ECI_D_MEDICAID
           (ID_MEDICAID, ID_CASE, MEDICAID_NBR, ELIG_DATE, END_DATE, CURRENT_IND, CANCEL_DATE, HMO_DESC,
            DATE_CREATED, DATE_MODIFIED, MODIFIED_BY, CREATED_BY, CONSENT_TO_BILL, LOAD_DATE)
    SELECT ID_MEDICAID, ID_CASE, MEDICAID_NBR, ELIG_DATE, END_DATE, CURRENT_IND, CANCEL_DATE, HMO_DESC, DATE_CREATED, DATE_MODIFIED, MODIFIED_BY, CREATED_BY, CONSENT_TO_BILL, LOAD_DATE FROM (SELECT h.ID_MEDICAID, h.ID_CASE, h.MEDICAID_NBR, h.ELIG_DATE, h.END_DATE, h.CURRENT_IND, h.CANCEL_DATE, h.HMO_DESC, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CONSENT_TO_BILL, h.LOAD_DATE, ROW_NUMBER() OVER (PARTITION BY h.ID_MEDICAID ORDER BY h.DATE_MODIFIED DESC NULLS LAST) AS __qual_rn FROM STG_ECI_H_MEDICAID h
     -- Read_STG_ECI_H_MEDICAID source filter: (ID_MEDICAID, LOAD_DATE) IN (latest per Medicaid record)
     INNER JOIN (SELECT m.ID_MEDICAID, MAX(m.LOAD_DATE) AS MAX_LOAD_DATE
                   FROM STG_ECI_H_MEDICAID m
                  INNER JOIN STG_ECI_SN_CASE c ON m.ID_CASE = c.ID_CASE
                  WHERE c.ID_CHILD IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_CHILD')
                  GROUP BY m.ID_MEDICAID) mx
             ON mx.ID_MEDICAID = h.ID_MEDICAID AND mx.MAX_LOAD_DATE = h.LOAD_DATE
     -- Lookup_STG_ECI_D_MEDICAID
      LEFT JOIN (SELECT DISTINCT ID_MEDICAID FROM STG_ECI_D_MEDICAID) d ON d.ID_MEDICAID = h.ID_MEDICAID
     -- Filt_Keep_New_Medicaid: 'Y' tests lkp_ID_MEDICAID; IDQ tests IsNull(ID_MEDICAID) on the source port
     WHERE CASE WHEN P_TEST_LOOKUP_RESULT = 'Y' THEN CASE WHEN d.ID_MEDICAID IS NULL THEN 1 WHEN NOT (d.ID_MEDICAID IS NULL) THEN 0 END ELSE CASE WHEN h.ID_MEDICAID IS NULL THEN 1 WHEN NOT (h.ID_MEDICAID IS NULL) THEN 0 END END = 1
    /* BAD DATA: primary key ID_MEDICAID, first row per id in this run */
    ) WHERE __qual_rn = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_ECI_D_MEDICAID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid_load;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_prep() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Alt_Id';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP()
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_ALT_ID_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_ALT_ID_ROUTED (
    ALT_ID_TP VARCHAR2(4000),
    ALT_ID_VAL VARCHAR2(4000),
    DATE_CREATED DATE,
    PKEY_SRC_OBJECT VARCHAR2(4000),
    PTY_REL_FK VARCHAR2(4000),
    attr_medicaid VARCHAR2(4000),
    attr_ssn VARCHAR2(4000),
    grp_mcd_exc NUMBER,
    grp_ssn_exc NUMBER,
    grp_valid NUMBER,
    hub_state_ind NUMBER,
    mapping_name VARCHAR2(4000),
    medicaid_exception_code VARCHAR2(4000),
    medicaid_exception_desc VARCHAR2(4000),
    medicaid_exception_type VARCHAR2(4000),
    run_ts TIMESTAMP,
    src_last_upd_dt DATE,
    src_rowid VARCHAR2(4000),
    src_sys VARCHAR2(4000),
    ssn_lkp_code VARCHAR2(4000),
    ssn_lkp_desc VARCHAR2(4000),
    ssn_lkp_type VARCHAR2(4000),
    sts_cd VARCHAR2(4000),
    uq_alt_id NUMBER,
    uq_mcd_exc NUMBER,
    uq_ssn_exc NUMBER,
    version_seq NUMBER
)';
    INSERT INTO WRK_ECI_ALT_ID_ROUTED (ALT_ID_TP, ALT_ID_VAL, DATE_CREATED, PKEY_SRC_OBJECT, PTY_REL_FK, attr_medicaid, attr_ssn, grp_mcd_exc, grp_ssn_exc, grp_valid, hub_state_ind, mapping_name, medicaid_exception_code, medicaid_exception_desc, medicaid_exception_type, run_ts, src_last_upd_dt, src_rowid, src_sys, ssn_lkp_code, ssn_lkp_desc, ssn_lkp_type, sts_cd, uq_alt_id, uq_mcd_exc, uq_ssn_exc, version_seq)
    SELECT ALT_ID_TP, ALT_ID_VAL, DATE_CREATED, PKEY_SRC_OBJECT, PTY_REL_FK, attr_medicaid, attr_ssn, grp_mcd_exc, grp_ssn_exc, grp_valid, hub_state_ind, mapping_name, medicaid_exception_code, medicaid_exception_desc, medicaid_exception_type, run_ts, src_last_upd_dt, src_rowid, src_sys, ssn_lkp_code, ssn_lkp_desc, ssn_lkp_type, sts_cd, uq_alt_id, uq_mcd_exc, uq_ssn_exc, version_seq FROM (
    WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_STG_ECI_D_CHILD (custom SQL, query mode SEMI; port ID_CHILD = column ID)
        src AS (
            SELECT ID_CHILD AS ID, LPAD(TO_CHAR(ID_CHILD), 10, '0') || '|Member' AS PTY_REL_FK,
                   LPAD(TO_CHAR(ID_CHILD), 10, '0') AS SRC_KEY_SFX, '018' AS ALT_ID_TP,
                   LPAD(TO_CHAR(ID_CHILD), 10, '0') AS ALT_ID_VAL, DATE_CREATED, DATE_MODIFIED,
                   LPAD(TO_CHAR(ID_CHILD), 10, '0') || '|Member' || '|018' || '|'
                   || LPAD(TO_CHAR(ID_CHILD), 10, '0') AS PKEY_SRC_OBJECT
              FROM STG_ECI_D_CHILD
            UNION ALL
            SELECT ID_CHILD, LPAD(TO_CHAR(ID_CHILD), 10, '0') || '|Member', LPAD(TO_CHAR(ID_CHILD), 10, '0'),
                   '004', CHILD_SSN, DATE_CREATED, DATE_MODIFIED,
                   LPAD(TO_CHAR(ID_CHILD), 10, '0') || '|Member' || '|004' || '|' || LPAD(TO_CHAR(ID_CHILD), 10, '0')
              FROM STG_ECI_D_CHILD
             WHERE CHILD_SSN IS NOT NULL
            UNION ALL
            SELECT C.ID_CHILD, LPAD(TO_CHAR(C.ID_CHILD), 10, '0') || '|Member', LPAD(TO_CHAR(M.ID_MEDICAID), 9, '0'),
                   '002', M.MEDICAID_NBR, M.DATE_CREATED, M.DATE_MODIFIED,
                   LPAD(TO_CHAR(C.ID_CHILD), 10, '0') || '|Member' || '|002' || '|' || LPAD(TO_CHAR(M.ID_MEDICAID), 10, '0')
              FROM STG_ECI_D_MEDICAID M
             INNER JOIN STG_ECI_SN_CASE C ON M.ID_CASE = C.ID_CASE
            UNION ALL
            SELECT ID_FAMILY, LPAD(TO_CHAR(ID_FAMILY), 10, '0') || 'F|Member', LPAD(TO_CHAR(ID_FAMILY), 10, '0'),
                   '019', LPAD(TO_CHAR(ID_FAMILY), 10, '0'), DATE_CREATED, DATE_MODIFIED,
                   LPAD(TO_CHAR(ID_FAMILY), 10, '0') || 'F|Member' || '|019' || '|' || LPAD(TO_CHAR(ID_FAMILY), 10, '0')
              FROM STG_ECI_D_FAMILY
        ),
        -- exp_ECI_Pty_Rle_Alt_Id + Lkp_STG_ECI_PTY_INACTIVE_STS + Filter
        active AS (
            SELECT s.*
              FROM src s
             WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = RTRIM(SUBSTR(s.PTY_REL_FK, 1, 11), '|') AND i.ROWID_SYSTEM = 'ECI'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- rule_USA_SSN_Validation_post_June2011 (004 rows) + exp_validate_ssn; rule_MEDICAID_ID_Std (002 rows)
        dq AS (
            SELECT a.*,
                   /* VALIDATION */
                   CASE WHEN a.ALT_ID_TP = '004' AND CAST(PKG_COMMON.fn_snow_helper26_common(a.ALT_ID_VAL).ssn_status AS VARCHAR2(4000)) = 'Invalid' THEN 'Invalid_SSN' ELSE NULL END AS ssn_exception_code,
                   CASE WHEN a.ALT_ID_TP = '002' THEN CAST(PKG_COMMON.fn_snow_helper27_common(a.ALT_ID_VAL).exception_code AS VARCHAR2(4000)) ELSE NULL END
                                                                                               AS medicaid_exception_code
              FROM active a
        ),
        routed AS (
            SELECT d.*,
                   xs.EXCEPTION_CODE AS ssn_lkp_code, xs.EXCEPTION_DESC AS ssn_lkp_desc, xs.EXCEPTION_TYPE AS ssn_lkp_type,
                   xm.EXCEPTION_TYPE AS medicaid_exception_type, xm.EXCEPTION_DESC AS medicaid_exception_desc,CASE WHEN (d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NULL)
                    OR d.ALT_ID_TP IN ('018', '019')
                    OR (d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NULL) THEN 1 WHEN NOT ((d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NULL)
                    OR d.ALT_ID_TP IN ('018', '019')
                    OR (d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NULL)) THEN 0 END AS grp_valid,CASE WHEN d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NOT NULL THEN 1 WHEN NOT (d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NOT NULL) THEN 0 END AS grp_ssn_exc,CASE WHEN d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NOT NULL THEN 1 WHEN NOT (d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NOT NULL) THEN 0 END AS grp_mcd_exc
              FROM dq d
              LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.ssn_exception_code
              LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = d.medicaid_exception_code
        )
        SELECT r.*,
               TO_CHAR(r.ID) || '|' || r.ALT_ID_TP                    AS src_rowid,
               1 /* TIMELINE: VERSION_SEQ */                             AS version_seq,
               'Issued'                                                  AS sts_cd,
               1                                                         AS hub_state_ind,
               NVL(r.DATE_MODIFIED, r.DATE_CREATED)                      AS src_last_upd_dt,
               'ECI'                                                     AS src_sys,
               l_run_ts                                                 AS run_ts,
               c_mapping                                                AS mapping_name,
               'ALT_ID_Type_SSN'                                         AS attr_ssn,
               'ALT_ID_TP_MedicaidId'                                    AS attr_medicaid,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_valid, r.PKEY_SRC_OBJECT ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1 AND xa.PKEY_SRC_OBJECT IS NULL THEN 1 ELSE 0 END                          AS uq_alt_id,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_ssn_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK, r.ssn_lkp_type,
                                                r.ssn_lkp_code ORDER BY r.ID) = 1
                AND xe.SRC_SYS_ID_1 IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_ssn_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK, r.ssn_lkp_type,
                                                r.ssn_lkp_code ORDER BY r.ID) = 1
                AND xe.SRC_SYS_ID_1 IS NULL) THEN 0 END AS uq_ssn_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_mcd_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK,
                                               r.medicaid_exception_type, r.medicaid_exception_code
                                      ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_mcd_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK,
                                               r.medicaid_exception_type, r.medicaid_exception_code
                                      ORDER BY r.ID) = 1) THEN 0 END AS uq_mcd_exc
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = r.PKEY_SRC_OBJECT
          -- SSN exception rows of earlier runs (RUN_DATE NULL, same key): Oracle's unique constraint rejects a repeat
          LEFT JOIN (SELECT DISTINCT SRC_SYS_ID_1, SRC_SYS_ID_2, NVL(EXCEPTION_TYPE, '~') AS EXC_TYPE,
                            NVL(EXCEPTION_CODE, '~') AS EXC_CODE
                       FROM EXC_STG_BAD_REC_MEMB
                      WHERE SRC_SYS = 'ECI' AND RUN_DATE IS NULL AND SRC_SYS_ID_3 IS NULL) xe
                 ON (r.grp_ssn_exc = 1) AND xe.SRC_SYS_ID_1 = r.PKEY_SRC_OBJECT AND xe.SRC_SYS_ID_2 = r.PTY_REL_FK
                AND xe.EXC_TYPE = NVL(r.ssn_lkp_type, '~') AND xe.EXC_CODE = NVL(r.ssn_lkp_code, '~')
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_ALT_ID_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Alt_Id';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Union_Valid_ALT_ID_Type (SSN valid, ECI ids, Medicaid valid) -> Exp_STG_ALT_ID_Type_Load -> target
    INSERT INTO C_S_ECI_PTY_RLE_ALT_ID
           (PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE, PKEY_SRC_OBJECT, SRC_ROWID,
                  VERSION_SEQ, STS_CD, HUB_STATE_IND, SRC_LAST_UPD_DT, ALT_ID_TP_FLTR, PERIOD_START_DATE)
    SELECT PTY_REL_FK, ALT_ID_TP, ALT_ID_VAL, DATE_CREATED, run_ts, PKEY_SRC_OBJECT, src_rowid,
                    version_seq, sts_cd, hub_state_ind, src_last_upd_dt, ALT_ID_TP, DATE_CREATED
      FROM WRK_ECI_ALT_ID_ROUTED
     WHERE (grp_valid = 1) AND (uq_alt_id = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE_ALT_ID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_alt_id;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Alt_Id';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        -- RTR_Valid_SSN.Invalid_CHILD_SSN -> Exp_SSN_Exceptions -> Write_EXC_STG_BAD_REC_MEMB_SSN (RUN_DATE unlinked)
        WHEN (grp_ssn_exc = 1) AND (uq_ssn_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, SRC_SYS, ATTRIBUTE_NAME, MAPPING_NAME,
                  ATTRIBUTE_VALUE, SRC_SYS_ID_1, SRC_SYS_ID_2)
            VALUES (ssn_lkp_code, ssn_lkp_desc, ssn_lkp_type, src_sys, attr_ssn, mapping_name, ALT_ID_VAL,
                    PKEY_SRC_OBJECT, PTY_REL_FK)
        -- RTR_Valid_Medicaid_ID.INVALID_Medicaid_Id -> Exp_Invalid_MedicaidId -> Write_EXC_STG_BAD_REC_MEMB_MedicaidId
        WHEN (grp_mcd_exc = 1) AND (uq_mcd_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, RUN_DATE, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, MAPPING_NAME, ATTRIBUTE_VALUE,
                  ATTRIBUTE_NAME, SRC_SYS_ID_2, SRC_SYS_ID_1)
            VALUES (src_sys, run_ts, medicaid_exception_type, medicaid_exception_code, medicaid_exception_desc,
                    mapping_name, ALT_ID_VAL, attr_medicaid, PTY_REL_FK, PKEY_SRC_OBJECT)
    SELECT * FROM WRK_ECI_ALT_ID_ROUTED;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id_exc;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_prep() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP()
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_PHN_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_PHN_ROUTED (
    ID_CASE NUMBER,
    ID_FAMILY_PHONE NUMBER,
    PERIOD_START_DATE DATE,
    PHONE_EMAIL VARCHAR2(4000),
    PHONE_TP VARCHAR2(4000),
    PREF_LVL VARCHAR2(4000),
    USG_TP VARCHAR2(4000),
    WORK_EXT VARCHAR2(4000),
    eaddr_addr_tp VARCHAR2(4000),
    eaddr_is_vld VARCHAR2(4000),
    eaddr_sts_cd VARCHAR2(4000),
    email_exception_code VARCHAR2(4000),
    email_exception_desc VARCHAR2(4000),
    email_exception_type VARCHAR2(4000),
    exc_email_attribute VARCHAR2(4000),
    exc_phone_attribute VARCHAR2(4000),
    exc_primary_phone VARCHAR2(4000),
    exc_secondary_phone VARCHAR2(4000),
    exc_type_bad_value VARCHAR2(4000),
    exc_work_phone VARCHAR2(4000),
    grp_email_bad NUMBER,
    grp_email_good NUMBER,
    grp_phone_bad NUMBER,
    grp_phone_good NUMBER,
    hub_state_ind NUMBER,
    mapping_name VARCHAR2(4000),
    phone_exception_code VARCHAR2(4000),
    phone_exception_desc VARCHAR2(4000),
    pkey_src_object VARCHAR2(4000),
    pty_rle_fk VARCHAR2(4000),
    run_ts TIMESTAMP,
    src_rowid VARCHAR2(4000),
    src_sys VARCHAR2(4000),
    std_email VARCHAR2(4000),
    std_phone VARCHAR2(4000),
    uq_eaddr NUMBER,
    uq_email_exc NUMBER,
    uq_phn NUMBER,
    uq_phone_exc NUMBER,
    version_seq NUMBER
)';
    INSERT INTO WRK_ECI_PHN_ROUTED (ID_CASE, ID_FAMILY_PHONE, PERIOD_START_DATE, PHONE_EMAIL, PHONE_TP, PREF_LVL, USG_TP, WORK_EXT, eaddr_addr_tp, eaddr_is_vld, eaddr_sts_cd, email_exception_code, email_exception_desc, email_exception_type, exc_email_attribute, exc_phone_attribute, exc_primary_phone, exc_secondary_phone, exc_type_bad_value, exc_work_phone, grp_email_bad, grp_email_good, grp_phone_bad, grp_phone_good, hub_state_ind, mapping_name, phone_exception_code, phone_exception_desc, pkey_src_object, pty_rle_fk, run_ts, src_rowid, src_sys, std_email, std_phone, uq_eaddr, uq_email_exc, uq_phn, uq_phone_exc, version_seq)
    SELECT ID_CASE, ID_FAMILY_PHONE, PERIOD_START_DATE, PHONE_EMAIL, PHONE_TP, PREF_LVL, USG_TP, WORK_EXT, eaddr_addr_tp, eaddr_is_vld, eaddr_sts_cd, email_exception_code, email_exception_desc, email_exception_type, exc_email_attribute, exc_phone_attribute, exc_primary_phone, exc_secondary_phone, exc_type_bad_value, exc_work_phone, grp_email_bad, grp_email_good, grp_phone_bad, grp_phone_good, hub_state_ind, mapping_name, phone_exception_code, phone_exception_desc, pkey_src_object, pty_rle_fk, run_ts, src_rowid, src_sys, std_email, std_phone, uq_eaddr, uq_email_exc, uq_phn, uq_phone_exc, version_seq FROM (
    WITH
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())),
        -- Read_V_ECI_ETL_SRC_FAMILY_PHONE + exp_Stage_Source_Attributes
        src AS (
            SELECT s.SOURCE_TABLE, s.WORK_EXT, s.PHONE_TP, s.USG_TP, s.PREF_LVL, s.PERIOD_START_DATE,
                   s.PHONE_EMAIL_TYPE, s.PHONE_EMAIL, s.ID_CASE, s.ID, s.ID_FAMILY_PHONE,
                   CASE WHEN s.PHONE_EMAIL_TYPE = 'EADDRESS' THEN 1 ELSE 0 END                                    AS is_email,
                   NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END      AS pty_src_key,
                   NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member' AS pty_rle_fk,
                   CASE WHEN (CASE WHEN s.PHONE_EMAIL_TYPE = 'EADDRESS' THEN 1 ELSE 0 END = 1) THEN CASE WHEN NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|001|'
                       || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(TRIM(s.PHONE_EMAIL), '') THEN 1 WHEN NOT (NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|001|'
                       || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(TRIM(s.PHONE_EMAIL), '')) THEN 0 END ELSE CASE WHEN NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(TRIM(s.PHONE_EMAIL), '') THEN 1 WHEN NOT (NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(TRIM(s.PHONE_EMAIL), '')) THEN 0 END END                                     AS pkey_src_object,
                   -- o_SRC_ROWID: same as the key but WITHOUT trimming the phone / e-mail
                   CASE WHEN (CASE WHEN s.PHONE_EMAIL_TYPE = 'EADDRESS' THEN 1 ELSE 0 END = 1) THEN CASE WHEN NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|001|'
                       || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(s.PHONE_EMAIL, '') THEN 1 WHEN NOT (NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|001|'
                       || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(s.PHONE_EMAIL, '')) THEN 0 END ELSE CASE WHEN NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(s.PHONE_EMAIL, '') THEN 1 WHEN NOT (NVL(TO_CHAR(s.ID), '') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_CHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(s.PHONE_EMAIL, '')) THEN 0 END END                                           AS src_rowid
              FROM V_ECI_ETL_SRC_FAMILY_PHONE s
        ),
        -- Lkp_STG_ECI_PTY_INACTIVE_STS + fil_deactivated_status
        active AS (
            SELECT s.*
              FROM src s
             WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = s.pty_src_key AND i.ROWID_SYSTEM = 'ECI'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- rule_Phone_Std step 1 (phone rows; Expression.PHONE_EMAIL1 prefixes '000' to 7-digit numbers) and
        -- rule_email_validation_v01 (e-mail rows)
        dq AS (
            SELECT a.*,
                   CASE WHEN a.is_email = 0 THEN PKG_COMMON.fn_snow_helper23_common(CASE WHEN LENGTH(a.PHONE_EMAIL) = 7 THEN '000' || a.PHONE_EMAIL ELSE a.PHONE_EMAIL END) ELSE NULL END                                                          AS std_phone,
                   CASE WHEN (a.is_email = 1) THEN PKG_COMMON.fn_snow_helper22_common(a.PHONE_EMAIL) ELSE NULL END       AS em
              FROM active a
        ),
        -- rule_Phone_Std step 2 (Lookup_REF_PHN_AREA_CD, exp_validate_Phone) and the exception lookups
        checked AS (
            SELECT d.*,
                   /* VALIDATION */
                   CASE WHEN d.is_email = 0 THEN PKG_COMMON.fn_snow_helper24_common(d.std_phone, 'ECI', d.USG_TP, ar.NPA_ID, ar.SERVICE) ELSE NULL END AS phone_exception_code,
                   CAST(d.em.email_address AS VARCHAR2(4000))                                        AS std_email
              FROM dq d
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(d.std_phone, 1, 3)
        ),
        routed AS (
            SELECT c.*,
                   xp.EXCEPTION_DESC                                                  AS phone_exception_desc,
                   xe.EXCEPTION_CODE                                                  AS email_exception_code,
                   xe.EXCEPTION_DESC                                                  AS email_exception_desc,
                   xe.EXCEPTION_TYPE                                                  AS email_exception_type,CASE WHEN c.is_email = 0 AND (c.phone_exception_code IS NULL
                                        OR c.phone_exception_code = 'Missing_AreaCode') THEN 1 WHEN NOT (c.is_email = 0 AND (c.phone_exception_code IS NULL
                                        OR c.phone_exception_code = 'Missing_AreaCode')) THEN 0 END AS grp_phone_good,CASE WHEN c.is_email = 0 AND c.phone_exception_code IS NOT NULL THEN 1 WHEN NOT (c.is_email = 0 AND c.phone_exception_code IS NOT NULL) THEN 0 END AS grp_phone_bad,CASE WHEN c.is_email = 1 AND xe.EXCEPTION_CODE IS NULL THEN 1 WHEN NOT (c.is_email = 1 AND xe.EXCEPTION_CODE IS NULL) THEN 0 END AS grp_email_good,CASE WHEN c.is_email = 1 AND xe.EXCEPTION_CODE IS NOT NULL THEN 1 WHEN NOT (c.is_email = 1 AND xe.EXCEPTION_CODE IS NOT NULL) THEN 0 END AS grp_email_bad
              FROM checked c
              LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = CAST(c.em.exception_code AS VARCHAR2(4000))
        )
        SELECT r.*,
               '1' /* TIMELINE: VERSION_SEQ */                                     AS version_seq,
               1                                                                    AS hub_state_ind,
               'ECI'                                                                AS src_sys,
               l_run_ts                                                            AS run_ts,
               c_mapping                                                           AS mapping_name,
               'Bad Value'                                                          AS exc_type_bad_value,
               CASE WHEN r.PREF_LVL = 'Primary' THEN r.std_phone ELSE NULL END                       AS exc_primary_phone,
               CASE WHEN r.USG_TP = 'Work' THEN r.std_phone ELSE NULL END                            AS exc_work_phone,
               CASE WHEN r.PREF_LVL = 'Secondary' THEN r.std_phone ELSE NULL END                     AS exc_secondary_phone,
               DECODE(r.USG_TP, '001', 'Main Phone', '002', 'Work Phone', '003', 'Other Phone') AS exc_phone_attribute,
               'Email'                                                              AS exc_email_attribute,
               '001'                                                                AS eaddr_addr_tp,
               'Active'                                                             AS eaddr_sts_cd,
               'Y'                                                                  AS eaddr_is_vld,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.pkey_src_object ORDER BY r.PERIOD_START_DATE DESC, r.ID_FAMILY_PHONE) = 1 AND xph.PKEY_SRC_OBJECT IS NULL THEN 1 ELSE 0 END                                    AS uq_phn,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.pkey_src_object
                                       ORDER BY r.PERIOD_START_DATE DESC, r.ID_FAMILY_PHONE) = 1
                AND xea.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.pkey_src_object
                                       ORDER BY r.PERIOD_START_DATE DESC, r.ID_FAMILY_PHONE) = 1
                AND xea.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_eaddr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.ID_CASE, r.USG_TP, r.phone_exception_code
                                      ORDER BY r.ID_FAMILY_PHONE) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.ID_CASE, r.USG_TP, r.phone_exception_code
                                      ORDER BY r.ID_FAMILY_PHONE) = 1) THEN 0 END AS uq_phone_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.ID_FAMILY_PHONE, r.email_exception_type,
                                               r.email_exception_code ORDER BY r.ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.ID_FAMILY_PHONE, r.email_exception_type,
                                               r.email_exception_code ORDER BY r.ID) = 1) THEN 0 END AS uq_email_exc
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
                 ON xph.PKEY_SRC_OBJECT = r.pkey_src_object
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
                 ON xea.PKEY_SRC_OBJECT = r.pkey_src_object
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_PHN_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Default -> RTR_Valid_PhoneNumbers.Good_Records -> exp_Stage_Target_PhoneNumbers -> Write_C_S_ECI_PTY_RLE_PHN
    INSERT INTO C_S_ECI_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT, HUB_STATE_IND)
    SELECT pkey_src_object, PERIOD_START_DATE, version_seq, run_ts, run_ts, src_rowid, pty_rle_fk, PHONE_TP,
                    USG_TP, std_phone, PREF_LVL, PERIOD_START_DATE, WORK_EXT, hub_state_ind
      FROM WRK_ECI_PHN_ROUTED
     WHERE (grp_phone_good = 1) AND (uq_phn = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE_PHN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_phn;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Email_Group -> rtr_Valid_EAddr_Records.Valid_Records -> exp_Stage_Target_EAddr_Attributes
    INSERT INTO C_S_ECI_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
                  PTY_RLE_FK, ELEC_ADDR, USG_TP, ADDR_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, VERSION_SEQ, HUB_STATE_IND)
    SELECT pkey_src_object, PERIOD_START_DATE, NULL, run_ts, run_ts, pkey_src_object, pty_rle_fk,
                    std_email, NULL, eaddr_addr_tp, eaddr_sts_cd, eaddr_is_vld, PERIOD_START_DATE, version_seq,
                    hub_state_ind
      FROM WRK_ECI_PHN_ROUTED
     WHERE (grp_email_good = 1) AND (uq_eaddr = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE_EADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_eaddr;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT ALL
        -- Default -> RTR_Valid_PhoneNumbers.Bad_Phone_Records -> exp_Stage_Phone_Exceptions
        WHEN (grp_phone_bad = 1) AND (uq_phone_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
                  MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE,
                  SRC_SYS_ID_2, ATTRIBUTE_NAME)
            VALUES (src_sys, phone_exception_code, phone_exception_desc, run_ts, exc_primary_phone, exc_work_phone,
                    exc_secondary_phone, mapping_name, NULL, exc_type_bad_value, USG_TP, PERIOD_START_DATE,
                    std_phone, ID_CASE, exc_phone_attribute)
        -- Email_Group -> rtr_Valid_EAddr_Records.Bad_Records -> exp_Stage_Email_Exceptions
        WHEN (grp_email_bad = 1) AND (uq_email_exc = 1) THEN
            INTO EXC_STG_BAD_REC_MEMB
                 (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME,
                  EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME)
            VALUES (src_sys, ID_FAMILY_PHONE, email_exception_code, email_exception_desc, run_ts, PHONE_EMAIL,
                    mapping_name, email_exception_type, PERIOD_START_DATE, PHONE_EMAIL, exc_email_attribute)
    SELECT * FROM WRK_ECI_PHN_ROUTED;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr_exc;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_prep(P_MEMBER_HIERARCHY_CODE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Addr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP() / $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_ADDR_SCORED';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_ADDR_SCORED (
    ADDRESS1 VARCHAR2(4000),
    ADDRESS2 VARCHAR2(4000),
    ADDRESS_CD VARCHAR2(4000),
    CITY_NAME VARCHAR2(4000),
    COUNTY_NAME VARCHAR2(4000),
    ID NUMBER,
    ID_FAMILY_ADDRESS NUMBER,
    LAST_UPDATE_DATE DATE,
    SOURCE_TABLE VARCHAR2(4000),
    STATE_ABBREV VARCHAR2(4000),
    ZIP_CODE VARCHAR2(4000),
    ZIP_SFX VARCHAR2(4000),
    a_address_type VARCHAR2(4000),
    a_building_complete VARCHAR2(4000),
    a_building_name VARCHAR2(4000),
    a_building_number VARCHAR2(4000),
    a_cass_error VARCHAR2(4000),
    a_city VARCHAR2(4000),
    a_country VARCHAR2(4000),
    a_county_fips VARCHAR2(4000),
    a_dpv VARCHAR2(4000),
    a_early_warning VARCHAR2(4000),
    a_geocoding_status VARCHAR2(4000),
    a_latitude NUMBER(38,6),
    a_line1 VARCHAR2(4000),
    a_line2 VARCHAR2(4000),
    a_longitude NUMBER(38,6),
    a_mailability_score VARCHAR2(4000),
    a_match_code VARCHAR2(4000),
    a_match_code_description VARCHAR2(4000),
    a_org_department VARCHAR2(4000),
    a_org_descriptor VARCHAR2(4000),
    a_org_name VARCHAR2(4000),
    a_postcode_complete VARCHAR2(4000),
    a_residential VARCHAR2(4000),
    a_result_pct NUMBER,
    a_state_fips VARCHAR2(4000),
    a_sub_building_complete VARCHAR2(4000),
    a_sub_building_descriptor VARCHAR2(4000),
    a_zip_cd_4_extn VARCHAR2(4000),
    a_zip_cd_5 VARCHAR2(4000),
    exc_attribute_name VARCHAR2(4000),
    exc_attribute_value VARCHAR2(4000),
    exc_code VARCHAR2(4000),
    exc_desc VARCHAR2(4000),
    exc_type VARCHAR2(4000),
    hierarchy_code VARCHAR2(4000),
    hm_rel_tp_cd VARCHAR2(4000),
    hold_line1 VARCHAR2(4000),
    hold_line2 VARCHAR2(4000),
    hub_state_ind NUMBER,
    loc_idn VARCHAR2(4000),
    mapping_name VARCHAR2(4000),
    mstr_addr_tp VARCHAR2(4000),
    pkey_src_object VARCHAR2(4000),
    pref_lvl VARCHAR2(4000),
    pty_rle_fk VARCHAR2(4000),
    pty_src_key VARCHAR2(4000),
    run_ts TIMESTAMP,
    score VARCHAR2(4000),
    src_cntry VARCHAR2(4000),
    src_sys VARCHAR2(4000),
    uq_addr NUMBER,
    uq_addr_exc NUMBER,
    version_seq NUMBER
)';
    INSERT INTO WRK_ECI_ADDR_SCORED (ADDRESS1, ADDRESS2, ADDRESS_CD, CITY_NAME, COUNTY_NAME, ID, ID_FAMILY_ADDRESS, LAST_UPDATE_DATE, SOURCE_TABLE, STATE_ABBREV, ZIP_CODE, ZIP_SFX, a_address_type, a_building_complete, a_building_name, a_building_number, a_cass_error, a_city, a_country, a_county_fips, a_dpv, a_early_warning, a_geocoding_status, a_latitude, a_line1, a_line2, a_longitude, a_mailability_score, a_match_code, a_match_code_description, a_org_department, a_org_descriptor, a_org_name, a_postcode_complete, a_residential, a_result_pct, a_state_fips, a_sub_building_complete, a_sub_building_descriptor, a_zip_cd_4_extn, a_zip_cd_5, exc_attribute_name, exc_attribute_value, exc_code, exc_desc, exc_type, hierarchy_code, hm_rel_tp_cd, hold_line1, hold_line2, hub_state_ind, loc_idn, mapping_name, mstr_addr_tp, pkey_src_object, pref_lvl, pty_rle_fk, pty_src_key, run_ts, score, src_cntry, src_sys, uq_addr, uq_addr_exc, version_seq)
    SELECT ADDRESS1, ADDRESS2, ADDRESS_CD, CITY_NAME, COUNTY_NAME, ID, ID_FAMILY_ADDRESS, LAST_UPDATE_DATE, SOURCE_TABLE, STATE_ABBREV, ZIP_CODE, ZIP_SFX, a_address_type, a_building_complete, a_building_name, a_building_number, a_cass_error, a_city, a_country, a_county_fips, a_dpv, a_early_warning, a_geocoding_status, a_latitude, a_line1, a_line2, a_longitude, a_mailability_score, a_match_code, a_match_code_description, a_org_department, a_org_descriptor, a_org_name, a_postcode_complete, a_residential, a_result_pct, a_state_fips, a_sub_building_complete, a_sub_building_descriptor, a_zip_cd_4_extn, a_zip_cd_5, exc_attribute_name, exc_attribute_value, exc_code, exc_desc, exc_type, hierarchy_code, hm_rel_tp_cd, hold_line1, hold_line2, hub_state_ind, loc_idn, mapping_name, mstr_addr_tp, pkey_src_object, pref_lvl, pty_rle_fk, pty_src_key, run_ts, score, src_cntry, src_sys, uq_addr, uq_addr_exc, version_seq FROM (
    WITH
        lkp_cv  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_mc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper46_common())),
        -- Read_V_ECI_ETL_SRC_FAMILY_ADDRESS + Exp_src + lkp_Address_Type + Exp_Build_Src_key
        src AS (
            SELECT s.SOURCE_TABLE, s.ID, s.ID_FAMILY_ADDRESS, s.ADDRESS1, s.ADDRESS2, s.ADDRESS_CD, s.CITY_NAME,
                   s.COUNTY_NAME, s.STATE_ABBREV, s.ZIP_CODE, s.ZIP_SFX, s.LAST_UPDATE_DATE,
                   LPAD(TO_CHAR(s.ID), 10, '0') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END   AS pty_src_key,
                   LPAD(TO_CHAR(s.ID), 10, '0') || CASE WHEN s.SOURCE_TABLE = 'ECI_FAMILY' THEN 'F' ELSE '' END || '|Member'
                                                                                                   AS pty_rle_fk,
                   at.MSTR_CODE_VALUE                                                              AS mstr_addr_tp
              FROM V_ECI_ETL_SRC_FAMILY_ADDRESS s
              LEFT JOIN lkp_cv at ON at.CODE_TYPE = 'ADDR_TP' AND at.SRC_SYS = 'ECI'
                                 AND at.SRC_CODE_VALUE = s.ADDRESS_CD
        ),
        keyed AS (
            SELECT s.*,
                   s.pty_rle_fk || '|' || NVL(s.mstr_addr_tp, '') || '|'
                   || NVL(LPAD(TO_CHAR(s.ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
                   || NVL(TRIM(UPPER(s.ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(s.ADDRESS2)), '') || '|'
                   || NVL(UPPER(s.CITY_NAME), '') || '|' || NVL(UPPER(s.STATE_ABBREV), '') || '|'
                   || NVL(s.ZIP_CODE, '') || '|' || NVL(s.ZIP_SFX, '')                             AS pkey_src_object
              FROM src s
             -- Lkp_STG_ECI_PTY_INACTIVE_STS + Fil_Inactive_recs: IsNull(DEACTIVATION_STS)
             WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = s.pty_src_key AND i.ROWID_SYSTEM = 'ECI'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- Exp_all_active + mplt_Global_Addr_Validation (lkp_State_Cd: V_LOOKUP_CODE_VALUE STATE)
        validated AS (
            SELECT k.*,
                   PKG_COMMON.fn_snow_helper34_common(k.ADDRESS1, k.ADDRESS2, k.CITY_NAME, k.STATE_ABBREV,
                                           NVL(k.ZIP_CODE, '') || CASE WHEN k.ZIP_SFX IS NOT NULL THEN '-' || k.ZIP_SFX ELSE '' END,
                                           'US', st.MSTR_CODE_VALUE) AS av
              FROM keyed k
              LEFT JOIN lkp_cv st ON st.CODE_TYPE = 'STATE' AND st.SRC_SYS = 'ECI'
                                 AND st.SRC_CODE_VALUE = UPPER(TRIM(k.STATE_ABBREV))
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
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper05_common(f.mstr_addr_tp, f.a_mailability_score, f.a_match_code) AS score,
                   PKG_COMMON.fn_snow_helper06_common(f.mstr_addr_tp, f.a_mailability_score, f.a_match_code)   AS addr_issue_desc,
                   PKG_COMMON.fn_snow_helper07_common(f.a_line1, f.a_line2)                                   AS hold_line1,
                   PKG_COMMON.fn_snow_helper08_common(f.a_line1, f.a_line2)                                   AS hold_line2
              FROM flat f
        )
        SELECT s.*,
               'US'                                                          AS src_cntry,
               'ECI'                                                         AS src_sys,
               l_run_ts                                                     AS run_ts,
               c_mapping                                                    AS mapping_name,
               1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
               1                                                             AS hub_state_ind,
               'Primary'                                                     AS pref_lvl,
               TO_CHAR(TRUNC(s.ID)) || '|' || TO_CHAR(TRUNC(s.ID_FAMILY_ADDRESS)) AS loc_idn,
               P_MEMBER_HIERARCHY_CODE                                      AS hierarchy_code,
               P_MEMBER_HM_REL_TP_CD                                        AS hm_rel_tp_cd,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN 'Address' ELSE NULL END           AS exc_attribute_name,
               CASE WHEN s.addr_issue_desc IS NOT NULL THEN NVL(s.ADDRESS1, '') || ' ' || NVL(s.ADDRESS2, '') || ' ' || NVL(s.CITY_NAME, '') || ' '
                   || NVL(s.STATE_ABBREV, '') || ' ' || NVL(s.ZIP_CODE, '') || ' ' || NVL(s.ZIP_SFX, '') || ' US' ELSE NULL END                                                     AS exc_attribute_value,
               'Invalid_Address'                                             AS exc_code,
               'Invalid Address per Address Doctor'                          AS exc_desc,
               'Bad Value'                                                   AS exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object ORDER BY s.LAST_UPDATE_DATE DESC, s.ID_FAMILY_ADDRESS) = 1 AND xa.PKEY_SRC_OBJECT IS NULL THEN 1 ELSE 0 END                              AS uq_addr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.ID_FAMILY_ADDRESS, s.SOURCE_TABLE
                                      ORDER BY s.LAST_UPDATE_DATE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.ID_FAMILY_ADDRESS, s.SOURCE_TABLE
                                      ORDER BY s.LAST_UPDATE_DATE DESC) = 1) THEN 0 END AS uq_addr_exc
          FROM scored s
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = s.pkey_src_object
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_ADDR_SCORED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_dqm() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Write_DQM_ADDRESS (all rows that pass Fil_Inactive_recs)
    INSERT INTO DQM_ADDRESS
           (MLBLTY_SCR, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_STATE, SRC_PSTL_CD, SRC_CNTRY, SRC_COUNTY,
                  RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_PSTL_CD, RSLT_CNTRY, RSLT_COUNTY, COUNTY_FIPS, STATE_FIPS,
                  LATTD, LNGTD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_NM, ORG_DESC, ORG_DEPT, BLDG, SUB_BLDG,
                  ADDRDR_MTCH_CD, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
                  MDM_ADDR_TP, SRC_SYSTEM, ADDR_SRC_KEY, LOAD_DT, PTY_SRC_KEY, RSLT_STATE)
    SELECT a_mailability_score, ADDRESS1, ADDRESS2, CITY_NAME, STATE_ABBREV, ZIP_CODE, src_cntry, COUNTY_NAME,
                    a_line1, a_line2, a_city, a_postcode_complete, a_country, a_county_fips, a_county_fips,
                    a_state_fips, a_latitude, a_longitude, a_geocoding_status, a_residential, a_org_name,
                    a_org_descriptor, a_org_department, a_building_complete, a_sub_building_complete, a_match_code,
                    a_result_pct, a_address_type, a_early_warning, a_cass_error, a_dpv, mstr_addr_tp, src_sys,
                    pkey_src_object, run_ts, pty_src_key, a_state_fips
      FROM WRK_ECI_ADDR_SCORED;
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert DQM_ADDRESS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_dqm;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_addr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- rtr_Good_vs_Exception_Pty_Records.Good -> exp_Address_Hold -> Write_C_S_ECI_PTY_RLE_ADDR
    INSERT INTO C_S_ECI_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
                  VERSION_SEQ, UPDATED_BY, CREATE_DATE, CREATOR, ADDR_TP, LAST_UPDATE_DATE, PREF_LVL, LOC_IDN,
                  SRC_ROWID, HUB_STATE_IND, HIERARCHY_CODE, HM_REL_TP_CD, PERIOD_REFERENCE_TIME, ADDR_LN_1,
                  ADDR_LN_2, CITY, PSTL_CD, CNTRY_CD, VLDTN_MSG, LATTD, LNGTD, PSTL_BRCD, RGN_CD, COUNTY,
                  LCTN_CRDNT_DESC, MLBLTY_SCR, STATE, RSDNTL_DLVRY_IND, ORG_DESC, ADDR_TP_CD, ORG_NM, FLR_NUM,
                  BLDNG_NM, GEOCD_STS_CD, SUB_BLDG_NM, SUB_BLDG_DESC, BLDG_NMBR, SRC_ADDR_LN_1, SRC_ADDR_LN_2,
                  SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT, EFF_END_DT,
                  PTY_RLE_FK, SRC_LAST_UPD_DT, PSTL_CD_EXT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, LAST_UPDATE_DATE, version_seq, mapping_name,
                    LAST_UPDATE_DATE, NULL, mstr_addr_tp, run_ts, pref_lvl, loc_idn, pkey_src_object, hub_state_ind,
                    hierarchy_code, hm_rel_tp_cd, NULL, hold_line1, hold_line2, a_city, a_zip_cd_5, a_country,
                    a_match_code, a_latitude, a_longitude, NULL, NULL, a_county_fips, NULL, a_mailability_score,
                    a_state_fips, a_residential, a_org_descriptor, a_address_type, a_org_name, NULL,
                    a_building_name, a_geocoding_status, a_sub_building_complete, a_sub_building_descriptor,
                    a_building_number, ADDRESS1, ADDRESS2, CITY_NAME, COUNTY_NAME, STATE_ABBREV, src_cntry, ZIP_CODE,
                    ZIP_SFX, LAST_UPDATE_DATE, NULL, pty_rle_fk, LAST_UPDATE_DATE, a_zip_cd_4_extn
      FROM WRK_ECI_ADDR_SCORED
     WHERE score = '100' AND (uq_addr = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE_ADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_addr;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Addr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- rtr_Good_vs_Exception_Pty_Records.Exception -> exp_ECI_US_Addr_Exc_Rec -> write_ECI_Exc_Member_Rec
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE,
                  ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE,
                  EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EXCEPTION_TYPE, ADDRESS_LINE_1, ADDRESS_LINE_2,
                  ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY,
                  SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
    SELECT src_sys, a_match_code, a_match_code_description, a_mailability_score, exc_attribute_name,
                    exc_attribute_value, mapping_name, ADDRESS_CD, LAST_UPDATE_DATE, NULL, exc_code, exc_desc,
                    run_ts, exc_type, ADDRESS1, ADDRESS2, CITY_NAME, COUNTY_NAME, STATE_ABBREV, ZIP_CODE, ZIP_SFX,
                    src_cntry, ID, ID_FAMILY_ADDRESS, SOURCE_TABLE
      FROM WRK_ECI_ADDR_SCORED
     WHERE score = '40' AND (uq_addr_exc = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr_exc;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_prep() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Rel';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP()
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_ECI_REL_BUILT';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_ECI_REL_BUILT (
    DATE_CREATED DATE,
    DATE_MODIFIED DATE,
    ID_CHILD NUMBER,
    ID_FAMILY NUMBER,
    attr_family_cd VARCHAR2(4000),
    exc_code VARCHAR2(4000),
    exc_desc VARCHAR2(4000),
    exc_type VARCHAR2(4000),
    hierarchy_code VARCHAR2(4000),
    hub_state_ind NUMBER,
    mapping_name VARCHAR2(4000),
    mstr_ref_code VARCHAR2(4000),
    rel_family_cd VARCHAR2(4000),
    rel_fk_1 VARCHAR2(4000),
    rel_fk_2 VARCHAR2(4000),
    rel_src_key VARCHAR2(4000),
    rel_type_code VARCHAR2(4000),
    run_ts TIMESTAMP,
    src_sys VARCHAR2(4000),
    uq_rel NUMBER,
    uq_rel_exc NUMBER,
    version_seq NUMBER
)';
    INSERT INTO WRK_ECI_REL_BUILT (DATE_CREATED, DATE_MODIFIED, ID_CHILD, ID_FAMILY, attr_family_cd, exc_code, exc_desc, exc_type, hierarchy_code, hub_state_ind, mapping_name, mstr_ref_code, rel_family_cd, rel_fk_1, rel_fk_2, rel_src_key, rel_type_code, run_ts, src_sys, uq_rel, uq_rel_exc, version_seq)
    SELECT DATE_CREATED, DATE_MODIFIED, ID_CHILD, ID_FAMILY, attr_family_cd, exc_code, exc_desc, exc_type, hierarchy_code, hub_state_ind, mapping_name, mstr_ref_code, rel_family_cd, rel_fk_1, rel_fk_2, rel_src_key, rel_type_code, run_ts, src_sys, uq_rel, uq_rel_exc, version_seq FROM (
    WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_STG_ECI_D_FAMILY (custom SQL: two rows per family row)
        src AS (
            SELECT d.RELATION_DIRECTION, f.ID_FAMILY, f.GENDER AS FAMILY_GENDER, f.ID_CHILD, f.FAMILY_CD,
                   COALESCE(f.DATE_MODIFIED, f.DATE_CREATED) AS DATE_MODIFIED, f.DATE_CREATED
              FROM STG_ECI_D_FAMILY f
             CROSS JOIN (SELECT 'From Child' AS RELATION_DIRECTION FROM DUAL UNION ALL SELECT 'To Child' FROM DUAL) d
        ),
        -- Exp_Build_Keys + Filter_Fam_Child_Valid
        keyed AS (
            SELECT s.*,
                   LPAD(TO_CHAR(s.ID_CHILD), 10, '0')          AS child_pty_src_key,
                   LPAD(TO_CHAR(s.ID_FAMILY), 10, '0') || 'F'  AS family_pty_src_key
              FROM src s
             WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = LPAD(TO_CHAR(s.ID_CHILD), 10, '0') AND i.ROWID_SYSTEM = 'ECI'
                                  AND i.DEACTIVATION_STS IS NOT NULL)
               AND NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                                WHERE i.SRC_KEY = LPAD(TO_CHAR(s.ID_FAMILY), 10, '0') || 'F'
                                  AND i.ROWID_SYSTEM = 'ECI' AND i.DEACTIVATION_STS IS NOT NULL)
        ),
        -- Lkp_STG_ECI_SN_CHILD + Exp_Prep_Family_cd
        coded AS (
            SELECT k.*,
                   CASE WHEN k.RELATION_DIRECTION = 'To Child' THEN TO_CHAR(k.FAMILY_CD) ELSE NVL(TO_CHAR(k.FAMILY_CD), '') || '|' || NVL(ch.GENDER, '') END     AS rel_family_cd
              FROM keyed k
              LEFT JOIN (SELECT ID_CHILD, GENDER FROM (SELECT c.ID_CHILD, c.GENDER, ROW_NUMBER() OVER (PARTITION BY c.ID_CHILD ORDER BY c.GENDER) AS __qual_rn FROM STG_ECI_SN_CHILD c
                         ) WHERE __qual_rn = 1) ch
                     ON ch.ID_CHILD = k.ID_CHILD
        ),
        -- Lkp_Rel_Tp_Code_Value (LOOKUP_CODE_VALUE by source code, any row)
        typed AS (
            SELECT c.*, lk.MSTR_REF_CODE AS mstr_ref_code
              FROM coded c
              LEFT JOIN (SELECT SRC_CODE_VALUE, MSTR_REF_CODE FROM (SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE, ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.CODE_TYPE DESC,
                                                   l.MSTR_REF_CODE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
                          WHERE l.CODE_TYPE IN ('REL_TP', 'INVERSE_REL') AND l.SRC_SYS = 'ECI'
                        ) WHERE __qual_rn = 1) lk
                     ON lk.SRC_CODE_VALUE = c.rel_family_cd
        ),
        -- Exp_Build_Reln / Exp_Build_Exception
        built AS (
            SELECT t.*,
                   CASE WHEN t.RELATION_DIRECTION = 'To Child' THEN t.family_pty_src_key ELSE t.child_pty_src_key END || '|Member'
                                                                                              AS rel_fk_1,
                   CASE WHEN t.RELATION_DIRECTION = 'To Child' THEN t.child_pty_src_key ELSE t.family_pty_src_key END || '|Member'
                                                                                              AS rel_fk_2,
                   CASE WHEN t.RELATION_DIRECTION = 'To Child' THEN t.family_pty_src_key ELSE t.child_pty_src_key END || '|Member|'
                   || CASE WHEN t.RELATION_DIRECTION = 'To Child' THEN t.child_pty_src_key ELSE t.family_pty_src_key END || '|Member|'
                   || NVL(t.mstr_ref_code, '')                                               AS rel_src_key
              FROM typed t
        )
        SELECT b.*,
               1 /* TIMELINE: VERSION_SEQ */                  AS version_seq,
               1                                              AS hub_state_ind,
               'Member Relationship'                          AS rel_type_code,
               'Member'                                       AS hierarchy_code,
               'ECI'                                          AS src_sys,
               l_run_ts                                      AS run_ts,
               c_mapping                                     AS mapping_name,
               'FAMILY_CD'                                    AS attr_family_cd,
               ex.EXCEPTION_CODE                              AS exc_code,
               ex.EXCEPTION_DESC                              AS exc_desc,
               ex.EXCEPTION_TYPE                              AS exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN b.mstr_ref_code IS NULL THEN 1 WHEN NOT (b.mstr_ref_code IS NULL) THEN 0 END, b.rel_src_key ORDER BY b.DATE_MODIFIED DESC, b.ID_FAMILY) = 1 AND xr.PKEY_SRC_OBJECT IS NULL THEN 1 ELSE 0 END               AS uq_rel,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN b.mstr_ref_code IS NULL THEN 1 WHEN NOT (b.mstr_ref_code IS NULL) THEN 0 END , b.ID_FAMILY, b.ID_CHILD, b.rel_src_key
                                      ORDER BY b.DATE_MODIFIED DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN b.mstr_ref_code IS NULL THEN 1 WHEN NOT (b.mstr_ref_code IS NULL) THEN 0 END , b.ID_FAMILY, b.ID_CHILD, b.rel_src_key
                                      ORDER BY b.DATE_MODIFIED DESC) = 1) THEN 0 END AS uq_rel_exc
          FROM built b
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = 'Invalid_Relationship'
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_REL WHERE VERSION_SEQ = 1) xr
                 ON xr.PKEY_SRC_OBJECT = b.rel_src_key
    );
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'prep WRK_ECI_REL_BUILT', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_prep;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_rel() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Rel';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Route_Good_vs_Exceptions.Valid_Relations -> Exp_Build_Reln -> Write_C_S_ECI_PTY_RLE_REL
    INSERT INTO C_S_ECI_PTY_RLE_REL
           (PTY_RLE_FK_1, PTY_RLE_FK_2, PKEY_SRC_OBJECT, VERSION_SEQ, SRC_ROWID, HUB_STATE_IND, REL_TYPE_CODE,
                  HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR,
                  PERIOD_START_DATE)
    SELECT rel_fk_1, rel_fk_2, rel_src_key, version_seq, rel_src_key, hub_state_ind, rel_type_code,
                    hierarchy_code, mstr_ref_code, DATE_MODIFIED, run_ts, mapping_name, DATE_MODIFIED, mapping_name,
                    DATE_CREATED
      FROM WRK_ECI_REL_BUILT
     WHERE mstr_ref_code IS NOT NULL AND (uq_rel = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_ECI_PTY_RLE_REL', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_rel;



    FUNCTION sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_ECI_Pty_Rle_Rel';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    -- Route_Good_vs_Exceptions.Relation_Exceptions -> Exp_Build_Exception -> Write_EXC_STG_BAD_REC_MEMB
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, RUN_DATE, MAPPING_NAME, ATTRIBUTE_NAME,
                  PERIOD_START_DATE, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_VALUE)
    SELECT src_sys, ID_FAMILY, ID_CHILD, rel_src_key, run_ts, mapping_name, attr_family_cd, DATE_CREATED,
                    exc_type, exc_code, exc_desc, rel_family_cd
      FROM WRK_ECI_REL_BUILT
     WHERE mstr_ref_code IS NULL AND (uq_rel_exc = 1);
    l_rows := SQL%%ROWCOUNT;
    SELECT PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel_exc;

END PKG_ECI;
/
