-- TRS Ongoing discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_TRS_ONGOING AS

    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_build(P_PTY_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DC_INDV_TBL_SRC        VARCHAR DEFAULT 'DC_INDV',
    P_MCI_TBL_SRC            VARCHAR DEFAULT 'MCI') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_PTYONGOING_BOTH';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_PTYONGOING_BOTH AS SELECT *
      FROM (
        WITH
        lkp_cv   AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())),
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_STG_TRS_D_DC_INDV (custom SQL, query mode SEMI; $MCI_TBL_SRC / $DC_INDV_TBL_SRC substituted)
        new_valid_indvs AS (
            SELECT DISTINCT indv_id FROM STG_TRS_D_CV_MCI_EDG_INDV_TOA WHERE conversion_ind = ''C''
            UNION
            SELECT DISTINCT indv_id FROM STG_TRS_D_DC_INDV
             WHERE FILE_CLEARANCE_SW = ''Y'' AND Inactive_ind = ''N'' AND delete_sw = ''N''
            UNION
            SELECT DISTINCT indv_id FROM STG_TRS_D_CV_DC_MCI_INDV WHERE Inactive_ind = ''N''
            UNION
            SELECT DISTINCT indv_id FROM STG_TRS_VALID_MEMBERS
            MINUS                              -- remove any records that will be inactivated today
            SELECT DISTINCT indv_id FROM STG_TRS_D_DC_INDV WHERE Inactive_ind = ''Y'' OR delete_sw = ''Y''
            MINUS
            SELECT DISTINCT indv_id FROM STG_TRS_D_CV_DC_MCI_INDV WHERE Inactive_ind = ''Y''
            MINUS                              -- re-runs and re-activations
            SELECT indv_id FROM STG_TRS_DEACTIVED_MEMBERS
        ),
        all_indv AS (
            SELECT INDV_ID, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME, PREFIX_NAME, GENDER_CD, RACE_CD, ETHNICITY_CD,
                   NULL AS SSA_VAL_SW, NULL AS FILE_CL_SW, DOB_DT, NULL AS DEATH_DT, CREATE_DT,
                   :1 AS SRC_TBL
              FROM STG_TRS_D_CV_DC_MCI_INDV
            UNION ALL
            SELECT INDV_ID, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME, PREFIX_NAME, GENDER_CD, RACE_CD, ETHNICITY_CD,
                   SSA_VALIDATION_SW, FILE_CLEARANCE_SW, DOB_DT, DEATH_DT, CREATE_DT, :2
              FROM STG_TRS_D_DC_INDV
        ),
        src AS (
            SELECT DISTINCT a.INDV_ID, RTRIM(LTRIM(a.FIRST_NAME)) AS FIRST_NAME, RTRIM(LTRIM(a.MID_NAME)) AS MID_NAME,
                   RTRIM(LTRIM(a.LAST_NAME)) AS LAST_NAME, RTRIM(a.SUFX_NAME) AS SUFX_NAME,
                   RTRIM(a.PREFIX_NAME) AS PREFIX_NAME, a.GENDER_CD, a.RACE_CD, a.ETHNICITY_CD, a.SSA_VAL_SW,
                   a.FILE_CL_SW, a.DOB_DT, a.CREATE_DT, a.SRC_TBL, a.DEATH_DT
              FROM all_indv a
             INNER JOIN new_valid_indvs f ON f.indv_id = a.indv_id
        ),
        -- exp_Tiers_Data_Load + exp_interface + mapplets (step 1: lookups and rule functions) + exp_Validate_Death_Dt
        dq AS (
            SELECT s.*,
                   CASE WHEN s.SRC_TBL = :2 THEN TO_CHAR(s.INDV_ID) || ''|'' || :2 ELSE TO_CHAR(s.INDV_ID) END                                                     AS pkey_src_object,
                   TRIM(NVL(s.FIRST_NAME, '''') || CASE WHEN s.MID_NAME IS NOT NULL THEN '' '' || TRIM(s.MID_NAME) ELSE '''' END
                        || '' '' || NVL(LTRIM(s.LAST_NAME), ''''))                                    AS src_full_name,
                   PKG_COMMON.fn_snow_helper15_common(s.FIRST_NAME, s.MID_NAME, s.LAST_NAME,
                       TRIM(NVL(s.FIRST_NAME, '''') || CASE WHEN s.MID_NAME IS NOT NULL THEN '' '' || TRIM(s.MID_NAME) ELSE '''' END
                            || '' '' || NVL(LTRIM(s.LAST_NAME), '''')),
                       s.PREFIX_NAME, s.SUFX_NAME, pfx.MSTR_CODE_VALUE, sfx.MSTR_CODE_VALUE,
                       jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)                                  AS nm,
                   PKG_COMMON.fn_snow_helper17_common(s.GENDER_CD, ''Indv'', ''TRS'')                            AS gd,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper16_common(s.DOB_DT, ''Indv'', ''TRS'', :3)  AS birth_exception_code,
                   rc.MSTR_CODE_VALUE                                                             AS race_mstr,
                   et.MSTR_CODE_VALUE                                                             AS ethnicity_mstr,
                   /* VALIDATION */ CASE WHEN s.DEATH_DT > :3 THEN ''Invalid_Death_Date'' ELSE NULL END      AS death_exception_code
              FROM src s
              LEFT JOIN lkp_cv pfx ON pfx.CODE_TYPE = ''PREFIX'' AND pfx.SRC_SYS = ''TRS'' AND pfx.SRC_CODE_VALUE = s.PREFIX_NAME
              LEFT JOIN lkp_cv sfx ON sfx.CODE_TYPE = ''SUFFIX'' AND sfx.SRC_SYS = ''TRS'' AND sfx.SRC_CODE_VALUE = s.SUFX_NAME
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(s.FIRST_NAME)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(s.LAST_NAME)) AND (jl.IS_LAST_JUNK = 1)
              LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = ''RACE'' AND rc.SRC_SYS = ''TRS'' AND rc.SRC_CODE_VALUE = s.RACE_CD
              LEFT JOIN lkp_cv et ON et.CODE_TYPE = ''ETHNICITY'' AND et.SRC_SYS = ''TRS'' AND et.SRC_CODE_VALUE = s.ETHNICITY_CD
        ),
        -- mapplets, step 2: the exception catalogue; lkp_Exc_Death_Dt
        base AS (
            SELECT d.*,
                   TRIM(d.pkey_src_object)               AS pkey_trim,
                   CAST(d.nm.first_name AS VARCHAR2(4000))              AS std_first_name,
                   CAST(d.nm.middle_name AS VARCHAR2(4000))             AS std_mdl_name,
                   CAST(d.nm.last_name AS VARCHAR2(4000))               AS std_lst_name,
                   CAST(d.nm.full_name AS VARCHAR2(4000))               AS std_full_name,
                   CAST(d.nm.prfx_name AS VARCHAR2(4000))               AS std_prfx_name,
                   CAST(d.nm.sfx_name AS VARCHAR2(4000))                AS std_sfx_name,
                   CAST(d.gd.mdm_gender_code AS VARCHAR2(4000))         AS mdm_gender_code,
                   CAST(d.gd.exception_code AS VARCHAR2(4000))          AS gender_exception_code,
                   xg.EXCEPTION_DESC                     AS gender_exception_description,
                   xg.EXCEPTION_TYPE                     AS gender_exception_type,
                   /* BAD DATA */ CASE WHEN d.birth_exception_code IS NULL THEN d.DOB_DT ELSE NULL END AS std_birth_date,
                   xb.EXCEPTION_DESC                     AS birth_exception_description,
                   xb.EXCEPTION_TYPE                     AS birth_exception_type,
                   xr.EXCEPTION_CODE                     AS race_exception_code,
                   xr.EXCEPTION_DESC                     AS race_exception_desc,
                   xr.EXCEPTION_TYPE                     AS race_exception_type,
                   xe.EXCEPTION_CODE                     AS ethnicity_exception_code,
                   xe.EXCEPTION_DESC                     AS ethnicity_exception_desc,
                   xe.EXCEPTION_TYPE                     AS ethnicity_exception_type,
                   xd.EXCEPTION_CODE                     AS death_exception_lkp_code,
                   xd.EXCEPTION_DESC                     AS death_exception_desc,
                   xd.EXCEPTION_TYPE                     AS death_exception_type,
                   /* VALIDATION */ (PKG_COMMON.fn_snow_helper03_common(CAST(d.nm.first_name AS VARCHAR2(4000)))
                                     OR (PKG_COMMON.fn_snow_helper03_common(CAST(d.nm.last_name AS VARCHAR2(4000))) = 1)) AS name_missing
              FROM dq d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.race_mstr, ''Invalid_Race'')
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, ''Invalid_Ethnicity'')
              LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = d.death_exception_code
        ),
        -- rtr_Invalid_Party (router rows) + exp_Invalid_Party_Name
        router AS (
            SELECT b.*,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_first_name) = 1) THEN ''Missing_First_Name''
                        WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_lst_name) = 1) THEN ''Missing_Last_Name'' END  AS name_exception_code,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_first_name) = 1) THEN ''First Name''
                        WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_lst_name) = 1) THEN ''Last Name'' END          AS name_attribute_name,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_first_name) = 1) THEN b.std_first_name
                        WHEN (PKG_COMMON.fn_snow_helper03_common(b.std_lst_name) = 1) THEN b.std_lst_name END       AS name_attribute_value
              FROM base b
        ),
        router_flagged AS (
            SELECT r.*,
                   xn.EXCEPTION_TYPE AS name_exception_type,
                   xn.EXCEPTION_DESC AS name_exception_desc,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.pkey_src_object, xn.EXCEPTION_TYPE,
                                                   r.name_exception_code ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.pkey_src_object, xn.EXCEPTION_TYPE,
                                                   r.name_exception_code ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_name,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.gender_exception_description IS NOT NULL THEN 1 WHEN NOT (r.gender_exception_description IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.gender_exception_type, r.gender_exception_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.gender_exception_description IS NOT NULL THEN 1 WHEN NOT (r.gender_exception_description IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.gender_exception_type, r.gender_exception_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_gender,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.death_exception_desc IS NOT NULL THEN 1 WHEN NOT (r.death_exception_desc IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.death_exception_type, r.death_exception_lkp_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.death_exception_desc IS NOT NULL THEN 1 WHEN NOT (r.death_exception_desc IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.death_exception_type, r.death_exception_lkp_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_death,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (r.birth_exception_code IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.birth_exception_type, r.birth_exception_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.birth_exception_code IS NOT NULL THEN 1 WHEN NOT (r.birth_exception_code IS NOT NULL) THEN 0 END , r.pkey_src_object,
                                                   r.birth_exception_type, r.birth_exception_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_birth
              FROM router r
              LEFT JOIN lkp_exc xn ON xn.EXCEPTION_CODE = r.name_exception_code
        ),
        -- srtr_Dedup_Rec (distinct over the ports that reach the C_S / valid-member / race / ethnicity targets)
        dedup AS (
            SELECT DISTINCT pkey_trim, CREATE_DT, INDV_ID, SRC_TBL, mdm_gender_code, std_sfx_name, std_first_name,
                   std_prfx_name, std_lst_name, std_mdl_name, std_birth_date, std_full_name, DEATH_DT, src_full_name,
                   RACE_CD, race_mstr, race_exception_code, race_exception_desc, race_exception_type, ETHNICITY_CD,
                   ethnicity_mstr, ethnicity_exception_code, ethnicity_exception_desc, ethnicity_exception_type
              FROM base
             -- rtr_Invalid_Party.Valid_Party: LENGTH(RTRIM(first)) != 0 OR LENGTH(RTRIM(last)) != 0
             --                                OR NOT ISNULL(first) OR NOT ISNULL(last)
             WHERE std_first_name IS NOT NULL OR std_lst_name IS NOT NULL
        ),
        dedup_ranked AS (
            SELECT x.*,
                   -- Aggregator1 / Aggregator / agg_Valid_Members: last row per key in srtr_Dedup_Rec order (NULL high)
                   ROW_NUMBER() OVER (PARTITION BY x.pkey_trim
                                      ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID DESC NULLS FIRST,
                                               x.SRC_TBL DESC NULLS FIRST, x.mdm_gender_code DESC NULLS FIRST,
                                               x.std_sfx_name DESC NULLS FIRST, x.std_first_name DESC NULLS FIRST,
                                               x.std_prfx_name DESC NULLS FIRST, x.std_lst_name DESC NULLS FIRST,
                                               x.std_mdl_name DESC NULLS FIRST, x.std_birth_date DESC NULLS FIRST,
                                               x.std_full_name DESC NULLS FIRST)               AS rn_pty,CASE WHEN -- lkp_Stg_TRS_Valid_Members + fltr_New_Valid_Members: ISNULL(PTY_PK_EXISTS)
                   vm.PTY_PK IS NOT NULL THEN 1 WHEN NOT (-- lkp_Stg_TRS_Valid_Members + fltr_New_Valid_Members: ISNULL(PTY_PK_EXISTS)
                   vm.PTY_PK IS NOT NULL) THEN 0 END AS is_valid_member,CASE WHEN xp.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xp.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_pty,CASE WHEN xr2.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xr2.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY CASE WHEN x.race_exception_code IS NOT NULL THEN 1 WHEN NOT (x.race_exception_code IS NOT NULL) THEN 0 END , x.pkey_trim,
                                                   x.race_exception_type, x.race_exception_code
                                          ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY CASE WHEN x.race_exception_code IS NOT NULL THEN 1 WHEN NOT (x.race_exception_code IS NOT NULL) THEN 0 END , x.pkey_trim,
                                                   x.race_exception_type, x.race_exception_code
                                          ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1) THEN 0 END AS uq_exc_race,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN x.ethnicity_exception_code IS NOT NULL THEN 1 WHEN NOT (x.ethnicity_exception_code IS NOT NULL) THEN 0 END , x.pkey_trim,
                                                   x.ethnicity_exception_type, x.ethnicity_exception_code
                                          ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN x.ethnicity_exception_code IS NOT NULL THEN 1 WHEN NOT (x.ethnicity_exception_code IS NOT NULL) THEN 0 END , x.pkey_trim,
                                                   x.ethnicity_exception_type, x.ethnicity_exception_code
                                          ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1) THEN 0 END AS uq_exc_ethnicity
              FROM dedup x
              LEFT JOIN (SELECT DISTINCT PTY_PK FROM STG_TRS_VALID_MEMBERS) vm ON vm.PTY_PK = x.pkey_trim
              /* BAD DATA: unique keys Snowflake does not enforce (key not yet in the table) */
              LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY WHERE VERSION_SEQ = 1) xp
                     ON xp.PKEY_SRC_OBJECT = x.pkey_trim
              LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE WHERE VERSION_SEQ = 1) xr2
                     ON xr2.PKEY_SRC_OBJECT = x.pkey_trim || ''|'' || :4
        ),
        -- one statement, two row kinds: the router rows (exceptions) and the de-duplicated valid rows
        both_kinds AS (
            SELECT ''ROUTER'' AS row_kind, b.pkey_src_object, b.pkey_trim, b.INDV_ID, b.SRC_TBL, b.CREATE_DT,
                   b.DEATH_DT, b.DOB_DT, b.GENDER_CD, b.RACE_CD, b.ETHNICITY_CD, b.src_full_name, b.std_first_name,
                   b.std_mdl_name, b.std_lst_name, b.std_full_name, b.std_prfx_name, b.std_sfx_name,
                   b.mdm_gender_code, b.gender_exception_code, b.gender_exception_description,
                   b.gender_exception_type, b.std_birth_date, b.birth_exception_code, b.birth_exception_description,
                   b.birth_exception_type, b.race_mstr, b.race_exception_code, b.race_exception_desc,
                   b.race_exception_type, b.ethnicity_mstr, b.ethnicity_exception_code, b.ethnicity_exception_desc,
                   b.ethnicity_exception_type, b.death_exception_lkp_code, b.death_exception_desc,
                   b.death_exception_type, b.name_missing, b.name_exception_code, b.name_exception_type,
                   b.name_exception_desc, b.name_attribute_name, b.name_attribute_value,
                   b.uq_exc_name, b.uq_exc_gender, b.uq_exc_death, b.uq_exc_birth,
                   CAST(NULL AS NUMBER) AS rn_pty, CAST(NULL AS NUMBER(1)) AS is_valid_member, CAST(NULL AS NUMBER(1)) AS uq_pty,
                   CAST(NULL AS NUMBER(1)) AS uq_rle, CAST(NULL AS NUMBER(1)) AS uq_exc_race, CAST(NULL AS NUMBER(1)) AS uq_exc_ethnicity
              FROM router_flagged b
            UNION ALL
            SELECT ''DEDUP'', NULL, r.pkey_trim, r.INDV_ID, r.SRC_TBL, r.CREATE_DT, r.DEATH_DT, NULL, NULL, r.RACE_CD,
                   r.ETHNICITY_CD, r.src_full_name, r.std_first_name, r.std_mdl_name, r.std_lst_name,
                   r.std_full_name, r.std_prfx_name, r.std_sfx_name, r.mdm_gender_code, NULL, NULL, NULL,
                   r.std_birth_date, NULL, NULL, NULL, r.race_mstr, r.race_exception_code, r.race_exception_desc,
                   r.race_exception_type, r.ethnicity_mstr, r.ethnicity_exception_code, r.ethnicity_exception_desc,
                   r.ethnicity_exception_type, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                   NULL, NULL, NULL, NULL,
                   r.rn_pty, r.is_valid_member, r.uq_pty, r.uq_rle, r.uq_exc_race, r.uq_exc_ethnicity
              FROM dedup_ranked r
        )
        SELECT k.*,
               k.pkey_trim || ''|'' || :4          AS rle_pkey,
               1 /* TIMELINE: VERSION_SEQ_NUM hard-coded */             AS version_seq,
               ''TRS''                                                     AS src_sys,
               :3                                                 AS run_ts,
               :5                                                AS mapping_name,
               :6                                 AS pty_bo_class_cd,
               :4                                 AS rle_bo_class_cd,
               TO_CHAR(k.DEATH_DT, ''MM/DD/YYYY HH24:MI:SS'')           AS death_text,   -- IDQ default date-to-string
               TO_CHAR(k.DOB_DT, ''MM/DD/YYYY'')                        AS dob_text,
               ''Gender''                                                  AS attr_gender,
               ''Death Date''                                              AS attr_death,
               ''Birth Date''                                              AS attr_birth,
               ''Race_Cd''                                                 AS attr_race,
               ''Ethnicity_Cd''                                            AS attr_ethnicity
          FROM both_kinds k
      )' USING P_MCI_TBL_SRC, P_DC_INDV_TBL_SRC, l_run_ts, P_RLE_BO_CLASS_CD_MEMBER, c_mapping, P_PTY_BO_CLASS_CD_MEMBER;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_PTYONGOING_BOTH;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_PTYONGOING_BOTH', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, GNDR_CD, SFX_NM, PTY_BO_CLASS_CD, FRST_NM, PRFX_NM, LST_NM, MDL_NM, FULL_NM, BIRTH_DT, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, HUB_STATE_IND, FLAG_SRC, DEATH_DT, SRC_FULL_NM, PERIOD_START_DATE, PERIOD_END_DATE, SRC_LAST_UPD_DT, SRC_ROWID, RACE_CD, ETHNCTY, SRC_ETHNCTY, SRC_RACE_CD)
    SELECT pkey_trim, NULL, NULL, NULL, NULL, mdm_gender_code, std_sfx_name, pty_bo_class_cd, std_first_name, std_prfx_name, std_lst_name, std_mdl_name, std_full_name, std_birth_date, version_seq, NULL, NULL, run_ts, NULL, NULL, NULL, NULL, NULL, DEATH_DT, src_full_name, CREATE_DT, NULL, CREATE_DT, pkey_trim, race_mstr, ethnicity_mstr, ETHNICITY_CD, RACE_CD FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'DEDUP' AND rn_pty = 1 AND (uq_pty = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE (PTY_FK, PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, RLE_BO_CLASS_CD, VERSION_SEQ, PERIOD_END_DATE, PERIOD_START_DATE, TIMELINE_ACTION, PERIOD_REFERENCE_TIME, UPDATED_BY, CREATE_DATE, CREATOR, SRC_LAST_UPD_DT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE)
    SELECT pkey_trim, rle_pkey, NULL, NULL, NULL, NULL, rle_bo_class_cd, version_seq, NULL, CREATE_DT, NULL, NULL, NULL, NULL, NULL, CREATE_DT, NULL, rle_pkey, run_ts FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'DEDUP' AND rn_pty = 1 AND (uq_rle = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_pty_rle;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TRS_VALID_MEMBERS (SRC_TBL, PTY_PK, INDV_ID, CREATE_DATE)
    SELECT SRC_TBL, pkey_trim, INDV_ID, run_ts FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'DEDUP' AND rn_pty = 1 AND NOT (is_valid_member = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TRS_VALID_MEMBERS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_valid_members;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (PERIOD_START_DATE, SRC_SYS, DEATH_DT, MAPPING_NAME, MIDDLE_NAME, LAST_NAME, FIRST_NAME, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, RUN_DATE, EXCEPTION_CODE, SRC_SYS_ID_1, EXCEPTION_TYPE, EXCEPTION_DESC, GENDER, PREFIX, SUFFIX, BIRTH_DATE)
    SELECT CREATE_DT, src_sys, DEATH_DT, mapping_name, std_mdl_name, std_lst_name, std_first_name, name_attribute_name, name_attribute_value, run_ts, name_exception_code, pkey_src_object, name_exception_type, name_exception_desc, NULL, NULL, NULL, NULL FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'ROUTER' AND (name_missing = 1) AND (uq_exc_name = 1)
    UNION ALL
    SELECT CREATE_DT, src_sys, DEATH_DT, mapping_name, std_mdl_name, std_lst_name, std_first_name, attr_gender, GENDER_CD, run_ts, gender_exception_code, pkey_src_object, gender_exception_type, gender_exception_description, GENDER_CD, std_prfx_name, std_sfx_name, std_birth_date FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'ROUTER' AND gender_exception_description IS NOT NULL AND (uq_exc_gender = 1)
    UNION ALL
    SELECT CREATE_DT, src_sys, DEATH_DT, NULL, std_mdl_name, std_lst_name, std_first_name, attr_death, death_text, run_ts, death_exception_lkp_code, pkey_src_object, death_exception_type, death_exception_desc, GENDER_CD, std_prfx_name, std_sfx_name, std_birth_date FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'ROUTER' AND death_exception_desc IS NOT NULL AND (uq_exc_death = 1)
    UNION ALL
    SELECT CREATE_DT, src_sys, DEATH_DT, mapping_name, std_mdl_name, std_lst_name, std_first_name, attr_birth, dob_text, run_ts, birth_exception_code, pkey_src_object, birth_exception_type, birth_exception_description, GENDER_CD, std_prfx_name, std_sfx_name, std_birth_date FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'ROUTER' AND birth_exception_code IS NOT NULL AND (uq_exc_birth = 1)
    UNION ALL
    SELECT CREATE_DT, src_sys, DEATH_DT, mapping_name, std_mdl_name, std_lst_name, std_first_name, attr_race, race_mstr, run_ts, race_exception_code, pkey_trim, race_exception_type, race_exception_desc, mdm_gender_code, std_prfx_name, std_sfx_name, std_birth_date FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'DEDUP' AND race_exception_code IS NOT NULL AND (uq_exc_race = 1)
    UNION ALL
    SELECT CREATE_DT, src_sys, DEATH_DT, mapping_name, std_mdl_name, std_lst_name, std_first_name, attr_ethnicity, ethnicity_mstr, run_ts, ethnicity_exception_code, pkey_trim, ethnicity_exception_type, ethnicity_exception_desc, mdm_gender_code, std_prfx_name, std_sfx_name, NULL FROM WRK_TRS_PTYONGOING_BOTH WHERE row_kind = 'DEDUP' AND ethnicity_exception_code IS NOT NULL AND (uq_exc_ethnicity = 1)
    ;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Deactivation_1';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TRS_DEACTIVED_MEMBERS
           (INDV_ID, PTY_PK, SRC_TBL, CREATE_DATE, SRC_DEACTIVATION_DATE, LOAD_DATE, INACTIVE_IND, DELETE_SW,
            PROCESSED_YN)
    WITH deactv AS (
        SELECT indv_id, inactive_ind, delete_sw, create_dt
          FROM STG_TRS_D_DC_INDV
         WHERE inactive_ind = 'Y' OR delete_sw = 'Y'
        UNION ALL
        SELECT indv_id, inactive_ind, NULL, create_dt
          FROM STG_TRS_D_CV_DC_MCI_INDV
         WHERE inactive_ind = 'Y'
    ), deactv_id AS (
        SELECT indv_id, MAX(inactive_ind) inactive_ind, MAX(delete_sw) delete_sw, MIN(create_dt) src_deactivation_date
          FROM deactv
         GROUP BY indv_id
    )
    SELECT INDV_ID, PTY_PK, SRC_TBL, CREATE_DATE, src_deactivation_date, __col5, inactive_ind, delete_sw, __col8 FROM (SELECT vm.INDV_ID, vm.PTY_PK, vm.SRC_TBL, vm.CREATE_DATE, d.src_deactivation_date, l_run_ts AS __col5, d.inactive_ind, d.delete_sw, 'N'
       AS __col8, ROW_NUMBER() OVER (PARTITION BY vm.INDV_ID ORDER BY vm.CREATE_DATE, vm.PTY_PK) AS __qual_rn FROM STG_TRS_VALID_MEMBERS vm
      JOIN deactv_id d ON d.indv_id = vm.indv_id
      -- Lookup_STG_TRS_DEACTIVED_MEMBERS + Filt_New_Only: ISNULL(PTY_PK1)
      LEFT JOIN (SELECT DISTINCT PTY_PK FROM STG_TRS_DEACTIVED_MEMBERS WHERE PTY_PK IS NOT NULL) dm
             ON dm.PTY_PK = vm.PTY_PK
      /* BAD DATA: primary key INDV_ID not yet in the table */
      LEFT JOIN (SELECT DISTINCT INDV_ID FROM STG_TRS_DEACTIVED_MEMBERS) di ON di.INDV_ID = vm.INDV_ID
     WHERE dm.PTY_PK IS NULL
       AND di.INDV_ID IS NULL
    /* BAD DATA: first row per INDV_ID in this run */
    ) WHERE __qual_rn = 1;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TRS_DEACTIVED_MEMBERS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1_deactived;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_build() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_TOA';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_TOA_KEYED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_TOA_KEYED AS SELECT *
      FROM (
        WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- read_Staging_Delta_Tables (custom SQL, query mode SEMI)
        toa_src AS (
            SELECT TO_CHAR(toa.INDV_ID) AS INDV_ID, toa.TYPE_OF_ASSISTANCE_CD, toa.ELIG_EFF_BEGIN_DT AS BEGIN_DT,
                   toa.ELIG_EFF_END_DT AS END_DT, ''MCI_EDG_INDV'' AS SRC_TBL,
                   /* TIMELINE */
                   ROW_NUMBER() OVER (PARTITION BY TO_CHAR(toa.INDV_ID) || ''|'' || NVL(TO_CHAR(toa.EDG_NUM), '''')
                                                   || ''|'' || NVL(TO_CHAR(toa.PROGRAM_CD), '''') || ''|''
                                                   || NVL(TO_CHAR(toa.MCI_CREATE_SEQ), '''')
                                      ORDER BY toa.CREATE_DT DESC) AS VERSION_SEQ,
                   TO_CHAR(toa.INDV_ID) AS PTY_PK, toa.EDG_NUM, toa.CASE_NUM, toa.MCI_CREATE_SEQ, toa.PROGRAM_CD,
                   toa.PART_STATUS_CD, toa.SYSTEM_CD, toa.CONVERT_DT, toa.CREATE_DT
              FROM STG_TRS_D_CV_MCI_EDG_INDV_TOA toa
              JOIN STG_TRS_VALID_MEMBERS vm ON TO_CHAR(toa.INDV_ID) = vm.PTY_PK
             WHERE toa.TYPE_OF_ASSISTANCE_CD IS NOT NULL
               AND (toa.CONVERSION_IND IS NULL OR toa.CONVERSION_IND = ''C'')
        ),
        src AS (
            SELECT * FROM toa_src WHERE VERSION_SEQ = 1
        ),
        -- lkp_LOOKUP_CODE_VALUE + exp_Stage_Source_Attributes + exp_Setup_PKey
        keyed AS (
            SELECT s.*,
                   lk.MSTR_REF_CODE                                                          AS toa_cd,
                   DECODE(s.SRC_TBL, ''LTSS_ELIG_PER'', ''DADS'', ''MCI_EDG_INDV'', ''TIERS'')      AS toa_source,
                   NVL(TO_CHAR(s.EDG_NUM), '''') || ''|'' || NVL(TO_CHAR(s.PROGRAM_CD), '''') || ''|''
                   || NVL(TO_CHAR(s.MCI_CREATE_SEQ), '''')                                  AS sgmnt_key,
                   s.INDV_ID || ''|Member''                                                    AS pty_rle_fk,
                   s.INDV_ID || ''|Member|'' || NVL(lk.MSTR_REF_CODE, '''') || ''|''
                   || NVL(DECODE(s.SRC_TBL, ''LTSS_ELIG_PER'', ''DADS'', ''MCI_EDG_INDV'', ''TIERS''), '''') || ''|''
                   || NVL(TO_CHAR(s.EDG_NUM), '''') || ''|'' || NVL(TO_CHAR(s.PROGRAM_CD), '''') || ''|''
                   || NVL(TO_CHAR(s.MCI_CREATE_SEQ), '''')                                  AS pkey_src_object,CASE WHEN /* VALIDATION */ lk.MSTR_REF_CODE IS NULL THEN 1 WHEN NOT (/* VALIDATION */ lk.MSTR_REF_CODE IS NULL) THEN 0 END AS grp_bad_value,
                   /* VALIDATION */ NVL(s.BEGIN_DT > s.END_DT, 0)                        AS grp_dates
              FROM src s
              LEFT JOIN (SELECT SRC_CODE_VALUE, MSTR_REF_CODE FROM (SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE, ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.MSTR_REF_CODE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
                          WHERE l.CODE_TYPE = ''TOA'' AND l.SRC_SYS = ''TRS''
                        ) WHERE __qual_rn = 1) lk
                     ON lk.SRC_CODE_VALUE = s.TYPE_OF_ASSISTANCE_CD
        )
        SELECT k.*,
               ''TRS''                                         AS src_sys,
               :1                                     AS run_ts,
               :2                                    AS mapping_name,
               ''Type of Assistance''                          AS attr_toa,
               ''Effective Date''                              AS attr_dates,
               xt.EXCEPTION_CODE                             AS toa_exc_code,
               xt.EXCEPTION_DESC                             AS toa_exc_desc,
               xt.EXCEPTION_TYPE                             AS toa_exc_type,
               ''Period_Start_Date_>_Period_End_Date''         AS date_exc_code,
               xd.EXCEPTION_DESC                             AS date_exc_desc,
               xd.EXCEPTION_TYPE                             AS date_exc_type,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY CASE WHEN k.grp_bad_value OR (k.grp_dates = 1) THEN 1 WHEN NOT (k.grp_bad_value OR (k.grp_dates = 1)) THEN 0 END , k.pkey_src_object
                                       ORDER BY k.CREATE_DT DESC) = 1
                AND xa.PKEY_SRC_OBJECT IS NULL)              AS uq_toa,CASE WHEN ROW_NUMBER() OVER (PARTITION BY k.grp_bad_value, k.INDV_ID, k.EDG_NUM, k.MCI_CREATE_SEQ
                                      ORDER BY k.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY k.grp_bad_value, k.INDV_ID, k.EDG_NUM, k.MCI_CREATE_SEQ
                                      ORDER BY k.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_toa,CASE WHEN ROW_NUMBER() OVER (PARTITION BY k.grp_dates, k.pkey_src_object, k.pty_rle_fk
                                      ORDER BY k.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY k.grp_dates, k.pkey_src_object, k.pty_rle_fk
                                      ORDER BY k.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_dates
          FROM keyed k
          LEFT JOIN lkp_exc xt ON xt.EXCEPTION_CODE = ''Invalid_TOA''
          LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = ''Period_Start_Date_>_Period_End_Date''
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_TOA WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = k.pkey_src_object
      )' USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_TOA_KEYED;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_TOA_KEYED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_TOA';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_TOA (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, TOA_SOURCE, TOA_FK, EFF_STRT_DT, EFF_END_DT, PTY_RLE_FK, EDG_NUM, CASE_NUM, SGMNT_KEY, CNVRT_DT, CNVRT_SYS_CD, INDV_ID, PRTCPNT_STS_CD, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, BEGIN_DT, END_DT, VERSION_SEQ, NULL, run_ts, NULL, CREATE_DT, NULL, pkey_src_object, NULL, toa_source, toa_cd, BEGIN_DT, END_DT, pty_rle_fk, EDG_NUM, CASE_NUM, sgmnt_key, CONVERT_DT, SYSTEM_CD, PTY_PK, PART_STATUS_CD, CREATE_DT FROM WRK_TRS_TOA_KEYED WHERE NOT (grp_bad_value = 1) AND NOT (grp_dates = 1) AND (uq_toa = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_TOA', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_toa;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_TOA';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, RUN_DATE, ATTRIBUTE_NAME, MAPPING_NAME, PERIOD_START_DATE, PERIOD_END_DATE, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, ATTRIBUTE_VALUE, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
    SELECT src_sys, run_ts, attr_toa, mapping_name, BEGIN_DT, END_DT, toa_exc_code, toa_exc_desc, toa_exc_type, TYPE_OF_ASSISTANCE_CD, INDV_ID, TO_CHAR(EDG_NUM), MCI_CREATE_SEQ FROM WRK_TRS_TOA_KEYED WHERE (grp_bad_value = 1) AND (uq_exc_toa = 1)
    UNION ALL
    SELECT src_sys, run_ts, attr_dates, mapping_name, BEGIN_DT, END_DT, date_exc_code, date_exc_desc, date_exc_type, NULL, pkey_src_object, pty_rle_fk, NULL FROM WRK_TRS_TOA_KEYED WHERE (grp_dates = 1) AND (uq_exc_dates = 1)
    ;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_build(P_INDV_ID_ALT_ID_TP IN VARCHAR2 DEFAULT '007') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_REL1_BOTH';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_REL1_BOTH AS SELECT *
      FROM (
        WITH
        lkp_cv  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_dst AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper47_common())),
        -- Read_STG_TRS_D_DC_RELATIONSHIPS (custom SQL, query mode SEMI)
        min_pk AS (
            SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
        ),
        src AS (
            SELECT rel.indv_id AS INDV_ID, rel.ref_indv_id AS REF_INDV_ID, rel.eff_begin_dt AS EFF_BEGIN_DT,
                   rel.eff_end_dt AS EFF_END_DT, rel.hist_nav_ind AS HIST_NAV_IND,
                   rel.relationship_type_cd AS RELATIONSHIP_TYPE_CD, pk1.pty_pk AS PTY_PKEY, pk2.pty_pk AS REF_PTY_PKEY,
                   :1 AS PTY_ALT_ID_TP, rel.create_dt AS CREATE_DT, rel.update_dt AS UPDATE_DT
              FROM STG_TRS_D_DC_RELATIONSHIPS rel
              JOIN min_pk pk1 ON rel.indv_id = pk1.indv_id
              JOIN min_pk pk2 ON rel.ref_indv_id = pk2.indv_id
        ),
        -- Lookup_V_LOOKUP_CODE_VALUE + exp_Build_FK
        keyed AS (
            SELECT s.*,
                   pt.MSTR_CODE_VALUE                                                       AS rel_type_code,
                   CASE WHEN s.PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.PTY_PKEY) || ''|Member'' END             AS pty_rle_fk_1,
                   CASE WHEN s.REF_PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.REF_PTY_PKEY) || ''|Member'' END     AS pty_rle_fk_2
              FROM src s
              LEFT JOIN lkp_cv pt ON pt.CODE_TYPE = ''PTY_REL'' AND pt.SRC_SYS = ''TRS''
                                 AND pt.SRC_CODE_VALUE = s.RELATIONSHIP_TYPE_CD
        ),
        routed AS (
            SELECT k.*,
                   NVL(k.pty_rle_fk_1, '''') || ''|'' || NVL(k.pty_rle_fk_2, '''') || ''|'' || NVL(k.rel_type_code, '''')
                                                                                            AS pkey_src_object,
                   /* VALIDATION */ NVL(k.EFF_BEGIN_DT > k.EFF_END_DT, 0)              AS dates_reversed
              FROM keyed k
        ),
        -- MPLT_Member_PTY_RLE_REL_Consolidation: Filter (type present), Sorter (distinct), Aggregator (one row per
        -- key + end + start; other ports from the last row)
        consolidated AS (
            SELECT * FROM (SELECT r.*, ROW_NUMBER() OVER (PARTITION BY r.pkey_src_object, r.EFF_END_DT, r.EFF_BEGIN_DT
                                          ORDER BY r.CREATE_DT DESC NULLS FIRST, r.UPDATE_DT DESC NULLS FIRST) AS __qual_rn FROM routed r
             WHERE r.pty_rle_fk_1 IS NOT NULL AND r.pty_rle_fk_2 IS NOT NULL AND r.rel_type_code IS NOT NULL
               AND NOT (r.dates_reversed = 1)
           ) WHERE __qual_rn = 1
        ),
        -- Exp_safe_C_S_TRS_PTY_RLE_REL (SRC_LAST_UPDATE_DATE = later of create / update) + mplt_DST_Correction
        prepared AS (
            SELECT c.*,
                   CASE WHEN c.CREATE_DT IS NOT NULL ANDCASE WHEN c.UPDATE_DT IS NOT NULL THEN GREATEST(c.CREATE_DT, c.UPDATE_DT) ELSE NVL(c.CREATE_DT, c.UPDATE_DT) END THEN 1 WHEN NOT (c.UPDATE_DT IS NOT NULL THEN GREATEST(c.CREATE_DT, c.UPDATE_DT) ELSE NVL(c.CREATE_DT, c.UPDATE_DT) END) THEN 0 END AS src_last_upd_dt,
                   /* TIMELINE */ PKG_COMMON.fn_snow_helper35_common(c.EFF_BEGIN_DT, c.EFF_END_DT, d.DST IS NOT NULL) AS dst_end_date
              FROM consolidated c
              LEFT JOIN lkp_dst d ON d.DST = ((c.EFF_END_DT) + (2)/24)
        ),
        -- rtr_Active_Records + union_All_Records (TIMELINE)
        versions AS (
            SELECT p.*, p.dst_end_date AS tl_period_end_date FROM prepared p                -- Active / End_Dated_Records
            UNION ALL
            SELECT p.*, CAST(NULL AS TIMESTAMP) FROM prepared p WHERE p.dst_end_date IS NOT NULL -- New_Active_Records
        ),
        -- SRT_PKEY_FOR_RANK + exp_RANK (TIMELINE)
        ranked AS (
            SELECT v.*,
                   ROW_NUMBER() OVER (PARTITION BY v.pkey_src_object
                                      ORDER BY v.EFF_BEGIN_DT ASC NULLS LAST,
                                               v.tl_period_end_date DESC NULLS FIRST)       AS tl_version_seq
              FROM versions v
        ),
        timeline AS (
            SELECT k.*,
                   CASE WHEN k.tl_period_end_date IS NOT NULL THEN 2 ELSE NULL END                          AS tl_timeline_action,
                   CASE WHEN k.tl_period_end_date IS NULL ANDCASE WHEN k.tl_version_seq = 1 THEN 1 ELSE NULL END THEN 1 WHEN NOT (k.tl_version_seq = 1 THEN 1 ELSE NULL END) THEN 0 END AS tl_hub_state_ind,CASE WHEN /* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
                   xr.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (/* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
                   xr.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rel
              FROM ranked k
              LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_REL) xr
                     ON xr.PKEY_SRC_OBJECT = k.pkey_src_object AND xr.VERSION_SEQ = k.tl_version_seq
        ),
        router AS (
            SELECT r.*,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.pty_rle_fk_1 IS NULL THEN 1 WHEN NOT (r.pty_rle_fk_1 IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.pty_rle_fk_1 IS NULL THEN 1 WHEN NOT (r.pty_rle_fk_1 IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_member,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.pty_rle_fk_2 IS NULL THEN 1 WHEN NOT (r.pty_rle_fk_2 IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.pty_rle_fk_2 IS NULL THEN 1 WHEN NOT (r.pty_rle_fk_2 IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_ref,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.rel_type_code IS NULL THEN 1 WHEN NOT (r.rel_type_code IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID,
                                                   r.RELATIONSHIP_TYPE_CD ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN r.rel_type_code IS NULL THEN 1 WHEN NOT (r.rel_type_code IS NULL) THEN 0 END , r.INDV_ID, r.REF_INDV_ID,
                                                   r.RELATIONSHIP_TYPE_CD ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_type,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.dates_reversed, r.INDV_ID, r.REF_INDV_ID, r.RELATIONSHIP_TYPE_CD
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.dates_reversed, r.INDV_ID, r.REF_INDV_ID, r.RELATIONSHIP_TYPE_CD
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_dates
              FROM routed r
        ),
        both_kinds AS (
            SELECT ''ROUTER'' AS row_kind, r.INDV_ID, r.REF_INDV_ID, r.EFF_BEGIN_DT, r.EFF_END_DT,
                   r.RELATIONSHIP_TYPE_CD, r.CREATE_DT, r.rel_type_code, r.pty_rle_fk_1, r.pty_rle_fk_2,
                   r.pkey_src_object, r.dates_reversed, CAST(NULL AS TIMESTAMP) AS src_last_upd_dt,
                   CAST(NULL AS TIMESTAMP) AS tl_period_end_date, CAST(NULL AS NUMBER) AS tl_version_seq,
                   CAST(NULL AS NUMBER) AS tl_timeline_action, CAST(NULL AS NUMBER) AS tl_hub_state_ind, CAST(NULL AS NUMBER(1)) AS uq_rel,
                   r.uq_exc_member, r.uq_exc_ref, r.uq_exc_type, r.uq_exc_dates
              FROM router r
            UNION ALL
            SELECT ''TIMELINE'', t.INDV_ID, t.REF_INDV_ID, t.EFF_BEGIN_DT, t.EFF_END_DT, t.RELATIONSHIP_TYPE_CD,
                   t.CREATE_DT, t.rel_type_code, t.pty_rle_fk_1, t.pty_rle_fk_2, t.pkey_src_object, t.dates_reversed,
                   t.src_last_upd_dt, t.tl_period_end_date, t.tl_version_seq, t.tl_timeline_action,
                   t.tl_hub_state_ind, t.uq_rel, NULL, NULL, NULL, NULL
              FROM timeline t
        )
        SELECT b.*,
               ''TRS''                                         AS src_sys,
               :2                                     AS run_ts,
               :3                                    AS mapping_name,
               ''Member Relationship''                         AS rel_type_code_label,
               ''Member''                                      AS hierarchy_code,
               ''Relationship Type''                           AS attr_rel_type,
               ''Effective Date''                              AS attr_dates,
               ''Invalid_Member''                              AS exc_member_code,
               xm.EXCEPTION_DESC                             AS exc_member_desc,
               xm.EXCEPTION_TYPE                             AS exc_member_type,
               ''Invalid_Ref_Member''                          AS exc_ref_code,
               xf.EXCEPTION_DESC                             AS exc_ref_desc,
               xf.EXCEPTION_TYPE                             AS exc_ref_type,
               xt.EXCEPTION_CODE                             AS exc_type_lkp_code,
               xt.EXCEPTION_DESC                             AS exc_type_desc,
               xt.EXCEPTION_TYPE                             AS exc_type_type,
               ''Period_Start_Date_>_Period_End_Date''         AS exc_dates_code,
               xd.EXCEPTION_DESC                             AS exc_dates_desc,
               xd.EXCEPTION_TYPE                             AS exc_dates_type
          FROM both_kinds b
          LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = ''Invalid_Member''
          LEFT JOIN lkp_exc xf ON xf.EXCEPTION_CODE = ''Invalid_Ref_Member''
          LEFT JOIN lkp_exc xt ON xt.EXCEPTION_CODE = ''Invalid_Rel_Type''
          LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = ''Period_Start_Date_>_Period_End_Date''
      )' USING P_INDV_ID_ALT_ID_TP, l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_REL1_BOTH;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_REL1_BOTH', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_REL (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, EFF_BEGIN_DT, tl_period_end_date, tl_version_seq, tl_period_end_date, tl_timeline_action, run_ts, NULL, CREATE_DT, NULL, pkey_src_object, tl_hub_state_ind, pty_rle_fk_1, pty_rle_fk_2, rel_type_code_label, hierarchy_code, rel_type_code, src_last_upd_dt FROM WRK_TRS_REL1_BOTH WHERE row_kind = 'TIMELINE' AND (uq_rel = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_REL', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_rel;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, RUN_DATE, MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, PERIOD_START_DATE, PERIOD_END_DATE, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME)
    SELECT src_sys, run_ts, mapping_name, INDV_ID, REF_INDV_ID, rel_type_code, EFF_BEGIN_DT, EFF_END_DT, exc_member_desc, exc_member_type, exc_member_code, NULL, NULL FROM WRK_TRS_REL1_BOTH WHERE row_kind = 'ROUTER' AND pty_rle_fk_1 IS NULL AND (uq_exc_member = 1)
    UNION ALL
    SELECT src_sys, run_ts, mapping_name, INDV_ID, REF_INDV_ID, rel_type_code, EFF_BEGIN_DT, EFF_END_DT, exc_ref_desc, exc_ref_type, exc_ref_code, NULL, NULL FROM WRK_TRS_REL1_BOTH WHERE row_kind = 'ROUTER' AND pty_rle_fk_2 IS NULL AND (uq_exc_ref = 1)
    UNION ALL
    SELECT src_sys, run_ts, mapping_name, INDV_ID, REF_INDV_ID, RELATIONSHIP_TYPE_CD, EFF_BEGIN_DT, EFF_END_DT, exc_type_desc, exc_type_type, exc_type_lkp_code, RELATIONSHIP_TYPE_CD, attr_rel_type FROM WRK_TRS_REL1_BOTH WHERE row_kind = 'ROUTER' AND rel_type_code IS NULL AND (uq_exc_type = 1)
    UNION ALL
    SELECT src_sys, run_ts, mapping_name, INDV_ID, REF_INDV_ID, RELATIONSHIP_TYPE_CD, EFF_BEGIN_DT, EFF_END_DT, exc_dates_desc, exc_dates_type, exc_dates_code, NULL, attr_dates FROM WRK_TRS_REL1_BOTH WHERE row_kind = 'ROUTER' AND (dates_reversed = 1) AND (uq_exc_dates = 1)
    ;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- sysdate of LOAD_DATE
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TRS_DEACTIVATED_RELATIONSHIPS
           (INDV_ID, REF_INDV_ID, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, SRC_PKEY_CT, LOAD_DATE, PKEY_SRC_OBJECT,
            ROWID_OBJECT, MASTER_RECORD_YN, MERGED_YN, ROWID_SYSTEM, ROWID_XREF)
    WITH
    lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.PKG_COMMON.fn_snow_helper41_common())),
    -- Read_STG_TRS_D_DC_RELATIONSHIPS_A (custom SQL, query mode SEMI)
    min_pk AS (
        SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
    ),
    src AS (
        SELECT rel.indv_id AS INDV_ID, rel.ref_indv_id AS REF_INDV_ID, rel.eff_begin_dt AS EFF_BEGIN_DT,
               rel.eff_end_dt AS EFF_END_DT, rel.relationship_type_cd AS RELATIONSHIP_TYPE_CD, pk1.pty_pk AS PTY_PKEY,
               pk2.pty_pk AS REF_PTY_PKEY, 'TRS' AS SRC_SYS
          FROM STG_TRS_D_DC_RELATIONSHIPS_A rel
          JOIN min_pk pk1 ON rel.indv_id = pk1.indv_id
          JOIN min_pk pk2 ON rel.ref_indv_id = pk2.indv_id
    ),
    -- Lookup_V_LOOKUP_CODE_VALUE + Exp_Gen_PKEY
    keyed AS (
        SELECT s.*,
               CASE WHEN s.PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.PTY_PKEY) || '|Member' END               AS pty_rle_fk_1,
               CASE WHEN s.REF_PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.REF_PTY_PKEY) || '|Member' END       AS pty_rle_fk_2,
               NVL(CASE WHEN s.PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.PTY_PKEY) || '|Member' END, '') || '|'
               || NVL(CASE WHEN s.REF_PTY_PKEY IS NULL THEN NULL ELSE TRIM(s.REF_PTY_PKEY) || '|Member' END, '') || '|'
               || NVL(pt.MSTR_CODE_VALUE, '')                                             AS pkey_src_object
          FROM src s
          LEFT JOIN lkp_cv pt ON pt.CODE_TYPE = 'PTY_REL' AND pt.SRC_SYS = s.SRC_SYS
                             AND pt.SRC_CODE_VALUE = s.RELATIONSHIP_TYPE_CD
    ),
    -- Lkp_C_B_PTY_RLE_REL_XREF (custom lookup SQL; the per-object window counts written as grouped joins)
    xref_obj AS (
        SELECT ROWID_OBJECT, COUNT(DISTINCT PKEY_SRC_OBJECT) AS SRC_PKEY_CT, MAX(HUB_STATE_IND) AS MAX_HUB_STATE_IND
          FROM C_B_PTY_RLE_REL_XREF
         GROUP BY ROWID_OBJECT
    ),
    xref_key AS (
        SELECT PKEY_SRC_OBJECT, MIN(ROWID_XREF) AS MIN_ROWID_XREF
          FROM C_B_PTY_RLE_REL_XREF
         GROUP BY PKEY_SRC_OBJECT
    ),
    xref AS (
        SELECT DISTINCT t.ROWID_OBJECT, t.PKEY_SRC_OBJECT, t.ROWID_SYSTEM, o.SRC_PKEY_CT,
               CASE WHEN o.SRC_PKEY_CT > 1 THEN 'Y' ELSE 'N' END                          AS MERGE_YN,
               CASE WHEN t.ROWID_OBJECT = t.ORIG_ROWID_OBJECT THEN 'Y' ELSE 'N' END        AS MASTER_RECORD_YN,
               CASE WHEN o.MAX_HUB_STATE_IND = -1 THEN 'Y' ELSE 'N' END                    AS SOFT_DELETE_YN,
               k.MIN_ROWID_XREF
          FROM C_B_PTY_RLE_REL_XREF t
          JOIN xref_obj o ON o.ROWID_OBJECT = t.ROWID_OBJECT
          JOIN xref_key k ON k.PKEY_SRC_OBJECT = t.PKEY_SRC_OBJECT
    ),
    xref_one AS (   -- lookup "return any row" per PKEY_SRC_OBJECT
        SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY PKEY_SRC_OBJECT ORDER BY ROWID_OBJECT) AS __qual_rn FROM xref
        ) WHERE __qual_rn = 1
    )
    SELECT k.INDV_ID, k.REF_INDV_ID, k.pty_rle_fk_1, k.pty_rle_fk_2, k.RELATIONSHIP_TYPE_CD, x.SRC_PKEY_CT, l_run_ts,
           k.pkey_src_object, x.ROWID_OBJECT, x.MASTER_RECORD_YN, TRIM(x.MERGE_YN), k.SRC_SYS, x.MIN_ROWID_XREF
      FROM keyed k
      LEFT JOIN xref_one x ON x.PKEY_SRC_OBJECT = k.pkey_src_object
      -- Lookup_STG_TRS_DEACTIVATED_RELATIONSHIPS (PROCESSED_YN = 'N') + Fil_New_Deactivations
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM STG_TRS_DEACTIVATED_RELATIONSHIPS
                  WHERE PROCESSED_YN = 'N' AND PKEY_SRC_OBJECT IS NOT NULL) d
             ON d.PKEY_SRC_OBJECT = k.pkey_src_object
     WHERE d.PKEY_SRC_OBJECT IS NULL
       AND x.MIN_ROWID_XREF IS NOT NULL;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TRS_DEACTIVATED_RELATIONSHIPS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1_deactivated;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_build(P_PCP_REL_TP IN VARCHAR2 DEFAULT '100') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_REL2_BOTH';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_REL2_BOTH AS SELECT *
      FROM (
        WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_dst AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper47_common())),
        -- Read_STG_TRS_D_IN_MANAGED_CARE (custom SQL, query mode SEMI) + Filt_Numeric_Prov
        min_pk AS (
            SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
        ),
        src AS (
            SELECT mc.indv_id AS INDV_ID, mc.history_seq AS HISTORY_SEQ, mc.mc_prog_code AS MC_PROG_CODE,
                   mc.begin_dt AS BEGIN_DT, mc.create_dt AS CREATE_DT, mc.provider_num AS PROVIDER_NUM,
                   mc.end_dt AS END_DT, vm.pty_pk AS PTY_PK
              FROM STG_TRS_D_IN_MANAGED_CARE mc
              JOIN min_pk vm ON mc.indv_id = vm.indv_id
             WHERE mc.provider_num IS NOT NULL
               AND fn_snow_helper01_common(mc.provider_num) = 1                              -- Filt_Numeric_Prov
        ),
        -- Lookup_C_B_PTY_RLE_ALT_ID (custom lookup SQL)
        tpi_src_key AS (
            SELECT alt_id_val, pkey_src_object FROM (SELECT bo.alt_id_val, xr.pkey_src_object, ROW_NUMBER() OVER (PARTITION BY bo.alt_id_val ORDER BY xr.src_last_upd_dt DESC) AS __qual_rn FROM C_B_PTY_RLE_ALT_ID bo
             INNER JOIN C_B_PTY_RLE_ALT_ID_XREF xr ON bo.rowid_object = xr.rowid_object
             WHERE bo.alt_id_tp = ''006'' AND TRIM(xr.rowid_system) = ''C21'' AND xr.hub_state_ind = 1
           ) WHERE __qual_rn = 1
        ),
        -- Exp_Build_FK
        keyed AS (
            SELECT s.*,
                   CASE WHEN s.PTY_PK IS NULL THEN NULL ELSE TRIM(s.PTY_PK) || ''|Member'' END                        AS pty_rle_fk_1,
                   SUBSTR(TRIM(t.pkey_src_object), 1, REGEXP_INSTR(TRIM(t.pkey_src_object), ''[|]'', 1, 2) - 1)
                                                                                                  AS pty_rle_fk_2,
                   CASE WHEN INSTR(TRIM(t.pkey_src_object), ''|HCO'') > 0 THEN ''Member PCO'' ELSE ''Member PCP'' END     AS rel_type_code
              FROM src s
              LEFT JOIN tpi_src_key t ON t.alt_id_val = s.PROVIDER_NUM
        ),
        routed AS (
            SELECT k.*,
                   NVL(k.pty_rle_fk_1, '''') || ''|'' || NVL(k.pty_rle_fk_2, '''') || ''|'' || :1 AS pkey_src_object,
                   /* VALIDATION */ NVL(k.BEGIN_DT > k.END_DT, 0)                              AS dates_reversed,
                   /* VALIDATION */ (k.pty_rle_fk_1 IS NOT NULL AND k.pty_rle_fk_2 IS NOT NULL
                                     AND NVL(k.BEGIN_DT <= k.END_DT OR k.END_DT IS NULL, 0))   AS is_valid
              FROM keyed k
        ),
        -- MPLT_Member_PTY_RLE_REL_Consolidation (type always present here; UPDATE_DT not fed)
        consolidated AS (
            SELECT * FROM (SELECT r.*, ROW_NUMBER() OVER (PARTITION BY r.pkey_src_object, r.END_DT, r.BEGIN_DT
                                          ORDER BY r.CREATE_DT DESC NULLS FIRST) AS __qual_rn FROM routed r
             WHERE (r.is_valid = 1) AND r.rel_type_code IS NOT NULL
           ) WHERE __qual_rn = 1
        ),
        -- mplt_DST_Correction (TIMELINE)
        prepared AS (
            SELECT c.*,
                   /* TIMELINE */ PKG_COMMON.fn_snow_helper35_common(c.BEGIN_DT, c.END_DT, d.DST IS NOT NULL)  AS dst_end_date
              FROM consolidated c
              LEFT JOIN lkp_dst d ON d.DST = ((c.END_DT) + (2)/24)
        ),
        -- rtr_Active_Records + union_All_Records (TIMELINE)
        versions AS (
            SELECT p.*, p.dst_end_date AS tl_period_end_date FROM prepared p
            UNION ALL
            SELECT p.*, CAST(NULL AS TIMESTAMP) FROM prepared p WHERE p.dst_end_date IS NOT NULL
        ),
        -- SRT_PKEY_FOR_RANK + exp_RANK + exp_Stage_Output_Attributes (TIMELINE)
        timeline AS (
            SELECT v.*,
                   ROW_NUMBER() OVER (PARTITION BY v.pkey_src_object
                                      ORDER BY v.BEGIN_DT ASC NULLS LAST, v.tl_period_end_date DESC NULLS FIRST) AS tl_version_seq
              FROM versions v
        ),
        timeline_flagged AS (
            SELECT t.*,
                   CASE WHEN t.tl_period_end_date IS NOT NULL THEN 2 ELSE NULL END                          AS tl_timeline_action,
                   CASE WHEN t.tl_period_end_date IS NULL ANDCASE WHEN t.tl_version_seq = 1 THEN 1 ELSE NULL END THEN 1 WHEN NOT (t.tl_version_seq = 1 THEN 1 ELSE NULL END) THEN 0 END AS tl_hub_state_ind,CASE WHEN /* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
                   xr.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (/* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
                   xr.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rel
              FROM timeline t
              LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_REL_PROV) xr
                     ON xr.PKEY_SRC_OBJECT = t.pkey_src_object AND xr.VERSION_SEQ = t.tl_version_seq
        ),
        router AS (
            SELECT r.*,
                   CASE WHEN r.pty_rle_fk_1 IS NULL THEN ''Invalid_Member''
                        WHEN r.pty_rle_fk_2 IS NULL THEN ''Invalid_PCP'' END                 AS exc_default_code
              FROM routed r
        ),
        router_flagged AS (
            SELECT r.*,CASE WHEN /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY r.dates_reversed, r.INDV_ID, r.PROVIDER_NUM, r.pty_rle_fk_2
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
                   ROW_NUMBER() OVER (PARTITION BY r.dates_reversed, r.INDV_ID, r.PROVIDER_NUM, r.pty_rle_fk_2
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_dates,CASE WHEN ROW_NUMBER() OVER (PARTITION BY CASE WHEN NOT (r.is_valid = 1) AND NOT (r.dates_reversed = 1) THEN 1 WHEN NOT (NOT (r.is_valid = 1) AND NOT (r.dates_reversed = 1)) THEN 0 END , r.INDV_ID,
                                                   r.PROVIDER_NUM, r.exc_default_code
                                          ORDER BY r.CREATE_DT DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY CASE WHEN NOT (r.is_valid = 1) AND NOT (r.dates_reversed = 1) THEN 1 WHEN NOT (NOT (r.is_valid = 1) AND NOT (r.dates_reversed = 1)) THEN 0 END , r.INDV_ID,
                                                   r.PROVIDER_NUM, r.exc_default_code
                                          ORDER BY r.CREATE_DT DESC) = 1) THEN 0 END AS uq_exc_default
              FROM router r
        ),
        both_kinds AS (
            SELECT ''ROUTER'' AS row_kind, r.INDV_ID, r.PROVIDER_NUM, r.BEGIN_DT, r.END_DT, r.CREATE_DT,
                   r.pty_rle_fk_1, r.pty_rle_fk_2, r.rel_type_code, r.pkey_src_object, r.is_valid, r.dates_reversed,
                   r.exc_default_code, CAST(NULL AS TIMESTAMP) AS tl_period_end_date, CAST(NULL AS NUMBER) AS tl_version_seq,
                   CAST(NULL AS NUMBER) AS tl_timeline_action, CAST(NULL AS NUMBER) AS tl_hub_state_ind, CAST(NULL AS NUMBER(1)) AS uq_rel,
                   r.uq_exc_dates, r.uq_exc_default
              FROM router_flagged r
            UNION ALL
            SELECT ''TIMELINE'', t.INDV_ID, t.PROVIDER_NUM, t.BEGIN_DT, t.END_DT, t.CREATE_DT, t.pty_rle_fk_1,
                   t.pty_rle_fk_2, t.rel_type_code, t.pkey_src_object, t.is_valid, t.dates_reversed, NULL,
                   t.tl_period_end_date, t.tl_version_seq, t.tl_timeline_action, t.tl_hub_state_ind, t.uq_rel,
                   NULL, NULL
              FROM timeline_flagged t
        )
        SELECT b.*,
               ''TRS''                                         AS src_sys,
               :2                                     AS run_ts,
               :3                                    AS mapping_name,
               ''Member''                                      AS hierarchy_code,
               :1                                 AS rel_tp,
               ''Effective Date''                              AS attr_dates,
               ''Provider''                                    AS attr_provider,
               ''Period_Start_Date_>_Period_End_Date''         AS exc_dates_code,
               xd.EXCEPTION_DESC                             AS exc_dates_desc,
               xd.EXCEPTION_TYPE                             AS exc_dates_type,
               xx.EXCEPTION_DESC                             AS exc_default_desc,
               xx.EXCEPTION_TYPE                             AS exc_default_type
          FROM both_kinds b
          LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = ''Period_Start_Date_>_Period_End_Date''
          LEFT JOIN lkp_exc xx ON xx.EXCEPTION_CODE = b.exc_default_code
      )' USING P_PCP_REL_TP, l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_REL2_BOTH;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_REL2_BOTH', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_REL_PROV (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, UPDATED_BY, CREATOR)
    SELECT pkey_src_object, BEGIN_DT, tl_period_end_date, tl_version_seq, run_ts, NULL, pkey_src_object, tl_hub_state_ind, pty_rle_fk_1, pty_rle_fk_2, rel_type_code, hierarchy_code, rel_tp, CREATE_DT, tl_period_end_date, tl_timeline_action, NULL, NULL, NULL, NULL, NULL, NULL FROM WRK_TRS_REL2_BOTH WHERE row_kind = 'TIMELINE' AND (uq_rel = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_REL_PROV', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_rel_prov;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, PERIOD_START_DATE, PERIOD_END_DATE, SRC_SYS_ID_3, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, ATTRIBUTE_VALUE)
    SELECT src_sys, INDV_ID, PROVIDER_NUM, mapping_name, run_ts, attr_dates, BEGIN_DT, END_DT, pty_rle_fk_2, exc_dates_code, exc_dates_desc, exc_dates_type, NULL FROM WRK_TRS_REL2_BOTH WHERE row_kind = 'ROUTER' AND (dates_reversed = 1) AND (uq_exc_dates = 1)
    UNION ALL
    SELECT src_sys, INDV_ID, PROVIDER_NUM, mapping_name, run_ts, attr_provider, BEGIN_DT, END_DT, NULL, exc_default_code, exc_default_desc, exc_default_type, PROVIDER_NUM FROM WRK_TRS_REL2_BOTH WHERE row_kind = 'ROUTER' AND NOT (is_valid = 1) AND NOT (dates_reversed = 1) AND (uq_exc_default = 1)
    ;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_build() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_PHN_ALL';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_PHN_ALL AS SELECT *
      FROM (
        WITH
        lkp_exc  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())),
        lkp_lcv  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper45_common())),
        -- read_Staging_Delta_Tables (custom SQL, query mode SEMI) + fltr_Hold (TRUE)
        src AS (
            SELECT DISTINCT I.INDV_ID, C.CASE_NUM, C.CREATE_DT, C.WORK_PH_NUM, C.OTHER_PH_NUM, C.EMAIL, C.PH_NUM,
                   C.OFFICE_NUM, C.WORK_PH_NUM_EXT, TO_CHAR(I.INDV_ID) AS PTY_PK
              FROM STG_TRS_D_DC_CASES C
              JOIN STG_TRS_DC_CASE_INDV I ON C.CASE_NUM = I.CASE_NUM
              JOIN STG_TRS_VALID_MEMBERS VM ON TO_CHAR(I.INDV_ID) = VM.PTY_PK
        ),
        -- mplt_Phone_Normalization: Normalizer (helper UDTF) ...
        slots AS (
            SELECT n.*
              FROM src s,
                   TABLE(fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr(
                         s.CREATE_DT, s.PTY_PK, ''TRS'', TO_CHAR(s.CASE_NUM),
                         ''001'', ''Telephone'', s.PH_NUM,
                         ''002'', ''Telephone'', CASE WHEN s.WORK_PH_NUM IS NULL THEN NULL ELSE RTRIM(s.WORK_PH_NUM || '' '' || NVL(s.WORK_PH_NUM_EXT, '''')) END,
                         ''003'', ''Telephone'', s.OTHER_PH_NUM)) n
        ),
        -- ... rule_Phone_Primary / _Secondary / _Tertiary (only Phone is linked: SRC_SYS and USG_TP are NULL)
        phones_checked AS (
            SELECT sl.*,
                   PKG_COMMON.fn_snow_helper23_common(sl.PHN_NUM_IN)                                          AS phn_num,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper24_common(PKG_COMMON.fn_snow_helper23_common(sl.PHN_NUM_IN), NULL, NULL,
                                                            ar.NPA_ID, ar.SERVICE)                 AS dq_exception_code
              FROM slots sl
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(PKG_COMMON.fn_snow_helper23_common(sl.PHN_NUM_IN), 1, 3)
        ),
        -- ... Filter_Null_Phone_Nums + Lookup_LOOKUP_CODE_VALUE (PHN_USG_TP) + Exp_NEWOUTPUT
        phones AS (
            SELECT p.PERIOD_START_DATE AS period_start_date, p.PTY_FK AS pty_fk, p.PREF_LVL AS pref_lvl,
                   p.USG_TP AS usg_tp, p.PHN_TP AS phn_tp, p.phn_num, p.SRC_SYS AS src_sys_in,
                   p.CASE_NUMBER AS case_number, p.dq_exception_code, xp.EXCEPTION_DESC AS dq_exception,
                   NVL(p.PTY_FK, '''') || ''|Member''                                                 AS pty_rle_fk,
                   NVL(p.PTY_FK, '''') || ''|Member|'' || NVL(p.PHN_TP, '''') || ''|'' || NVL(u.MSTR_REF_CODE, '''') || ''|''
                   || p.phn_num                                                                   AS pkey_src_object
              FROM phones_checked p
              LEFT JOIN lkp_lcv u ON u.CODE_TYPE = ''PHN_USG_TP'' AND u.MSTR_REF_CODE = p.USG_TP AND u.SRC_SYS = p.SRC_SYS
              LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = p.dq_exception_code
             WHERE p.phn_num IS NOT NULL
        ),
        -- mplt_Phone_Consolidation (fltr_Null_Phone, srtr_Pkey_Src_Object distinct, exp_Rank) on Valid_Records
        phn_versions AS (
            SELECT d.*,
                   /* TIMELINE */ COUNT(*) OVER (PARTITION BY d.pkey_src_object)                    AS version_seq,
                   ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object
                                      ORDER BY d.period_start_date DESC NULLS FIRST, d.pty_rle_fk DESC, d.usg_tp DESC,
                                               d.phn_tp DESC, d.phn_num DESC, d.pref_lvl DESC)      AS rn
              FROM (SELECT DISTINCT p.period_start_date, p.pkey_src_object, p.pty_rle_fk, p.usg_tp, p.phn_tp,
                           p.phn_num, p.pref_lvl
                      FROM phones p
                     WHERE p.dq_exception_code IS NULL) d
        ),
        -- fltr_Null_Emails: not isnull(rtrim(ltrim(ELEC_ADDR))) + rule_email_validation_v01
        emails AS (
            SELECT s.*,
                   PKG_COMMON.fn_snow_helper22_common(s.EMAIL)                                AS em
              FROM src s
             WHERE TRIM(s.EMAIL) IS NOT NULL
        ),
        emails_checked AS (
            SELECT e.*,
                   CAST(e.em.email_address AS VARCHAR2(4000))                                     AS std_email,
                   xe.EXCEPTION_CODE AS em_exc_code, xe.EXCEPTION_DESC AS em_exc_desc, xe.EXCEPTION_TYPE AS em_exc_type
              FROM emails e
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = CAST(e.em.exception_code AS VARCHAR2(4000))
        ),
        -- mplt_EAddr_Consolidation (fltr_Null_Email, srtr_Pkey_Src_Object distinct, exp_Version_Seq) on Valid_Records
        eaddr_versions AS (
            SELECT d.*,
                   /* TIMELINE */ COUNT(*) OVER (PARTITION BY d.pkey_src_object)                    AS version_seq,
                   ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object
                                      ORDER BY d.period_start_date DESC NULLS FIRST, d.pty_rle_fk DESC,
                                               d.elec_addr DESC)                                    AS rn
              FROM (SELECT DISTINCT e.CREATE_DT AS period_start_date,
                           TO_CHAR(e.INDV_ID) || ''|Member|001|'' || NVL(e.EMAIL, '''') AS pkey_src_object,
                           e.PTY_PK || ''|Member'' AS pty_rle_fk, e.std_email AS elec_addr
                      FROM emails_checked e
                     WHERE e.em_exc_code IS NULL
                       AND e.std_email IS NOT NULL) d
        ),
        all_kinds AS (
            SELECT ''PHN'' AS row_kind, v.pkey_src_object, v.period_start_date, v.version_seq, v.rn, v.pty_rle_fk,
                   v.usg_tp, v.phn_tp, v.phn_num, v.pref_lvl, CAST(NULL AS VARCHAR2(4000)) AS elec_addr, CAST(NULL AS VARCHAR2(4000)) AS pty_fk,
                   CAST(NULL AS VARCHAR2(4000)) AS case_number, CAST(NULL AS VARCHAR2(4000)) AS exc_code, CAST(NULL AS VARCHAR2(4000)) AS exc_desc,
                   CAST(NULL AS VARCHAR2(4000)) AS exc_type
              FROM phn_versions v
            UNION ALL
            SELECT ''PHN_EXC'', p.pkey_src_object, p.period_start_date, NULL, NULL, p.pty_rle_fk, p.usg_tp, p.phn_tp,
                   p.phn_num, p.pref_lvl, NULL, p.pty_fk, p.case_number, p.dq_exception_code, p.dq_exception,
                   ''Bad Value''
              FROM phones p
             WHERE p.dq_exception_code IS NOT NULL
            UNION ALL
            SELECT ''EADDR'', v.pkey_src_object, v.period_start_date, v.version_seq, v.rn, v.pty_rle_fk, NULL, NULL,
                   NULL, NULL, v.elec_addr, NULL, NULL, NULL, NULL, NULL
              FROM eaddr_versions v
            UNION ALL
            SELECT ''EADDR_EXC'', NULL, e.CREATE_DT, NULL, NULL, NULL, NULL, NULL, NULL, NULL, e.EMAIL,
                   TO_CHAR(e.INDV_ID), TO_CHAR(e.CASE_NUM), e.em_exc_code, e.em_exc_desc, e.em_exc_type
              FROM emails_checked e
             WHERE e.em_exc_code IS NOT NULL
        )
        SELECT a.*,
               ''TRS''                                                 AS src_sys,
               :1                                             AS run_ts,
               :2                                            AS mapping_name,
               ''001''                                                 AS eaddr_addr_tp,
               ''Active''                                              AS eaddr_sts_cd,
               ''Y''                                                   AS eaddr_is_vld,
               CASE WHEN a.pref_lvl = ''Primary'' THEN a.phn_num ELSE NULL END          AS exc_primary_phone,
               CASE WHEN a.usg_tp = ''Work'' THEN a.phn_num ELSE NULL END               AS exc_work_phone,
               CASE WHEN a.pref_lvl = ''Secondary'' THEN a.phn_num ELSE NULL END        AS exc_secondary_phone,
               CASE WHEN a.row_kind = ''EADDR_EXC'' THEN ''Email'' ELSE DECODE(a.usg_tp, ''001'', ''Main Phone'', ''002'', ''Work Phone'', ''003'', ''Other Phone'') END AS exc_attribute,
               /* BAD DATA: unique keys Snowflake does not enforce */
               xph.PKEY_SRC_OBJECT IS NULL ANDCASE WHEN xea.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xea.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_tgt,CASE WHEN ROW_NUMBER() OVER (PARTITION BY a.row_kind, a.pty_fk, a.case_number, a.usg_tp, a.exc_type, a.exc_code
                                      ORDER BY a.period_start_date DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY a.row_kind, a.pty_fk, a.case_number, a.usg_tp, a.exc_type, a.exc_code
                                      ORDER BY a.period_start_date DESC) = 1) THEN 0 END AS uq_exc
          FROM all_kinds a
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_PHN) xph
                 ON a.row_kind = ''PHN'' AND xph.PKEY_SRC_OBJECT = a.pkey_src_object AND xph.VERSION_SEQ = a.version_seq
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_EADDR) xea
                 ON a.row_kind = ''EADDR'' AND xea.PKEY_SRC_OBJECT = a.pkey_src_object AND xea.VERSION_SEQ = a.version_seq
      )' USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_PHN_ALL;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_PHN_ALL', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_PHN (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK, USG_TP, PHN_TP, PHN_NUM, PREF_LVL, PERIOD_END_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, period_start_date, version_seq, NULL, NULL, run_ts, NULL, period_start_date, NULL, pkey_src_object, NULL, pty_rle_fk, usg_tp, phn_tp, phn_num, pref_lvl, NULL, period_start_date FROM WRK_TRS_PHN_ALL WHERE row_kind = 'PHN' AND rn = 1 AND (uq_tgt = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_PHN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_phn;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_EADDR (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK, ELEC_ADDR, USG_TP, ADDR_TP, STS_CD, IS_VLD, PERIOD_END_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, period_start_date, version_seq, NULL, NULL, run_ts, NULL, period_start_date, NULL, pkey_src_object, NULL, pty_rle_fk, elec_addr, NULL, eaddr_addr_tp, eaddr_sts_cd, eaddr_is_vld, NULL, period_start_date FROM WRK_TRS_PHN_ALL WHERE row_kind = 'EADDR' AND rn = 1 AND (uq_tgt = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_EADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_eaddr;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE, MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE, SRC_SYS_ID_2, ATTRIBUTE_NAME, EMAIL)
    SELECT src_sys, exc_code, exc_desc, run_ts, exc_primary_phone, exc_work_phone, exc_secondary_phone, mapping_name, pty_fk, exc_type, usg_tp, period_start_date, phn_num, case_number, exc_attribute, NULL FROM WRK_TRS_PHN_ALL WHERE row_kind = 'PHN_EXC' AND (uq_exc = 1)
    UNION ALL
    SELECT src_sys, exc_code, exc_desc, run_ts, NULL, NULL, NULL, mapping_name, pty_fk, exc_type, NULL, period_start_date, elec_addr, case_number, exc_attribute, elec_addr FROM WRK_TRS_PHN_ALL WHERE row_kind = 'EADDR_EXC' AND (uq_exc = 1)
    ;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Mng_Attr_Sw';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- SYSTIMESTAMP() / SESSSTARTTIME
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            MNG_ATTR_TP, MNG_ATTR_VAL, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE,
            SRC_ROWID, CREATOR, LAST_UPDATE_DATE, SRC_LAST_UPD_DT, PTY_FK, HUB_STATE_IND)
    WITH
    -- Read_Stg_TRS_D_DC_Indv (custom SQL, query mode SEMI)
    daily_indv AS (
        SELECT dc.indv_id AS INDV_ID, dc.FILE_CLEARANCE_SW, dc.SSA_VALIDATION_SW, dc.CREATE_DT AS EFF_BEGIN_DT,
               NULL AS TW_CONVERT_IND, NULL AS LTC_CONVERT_IND, TO_CHAR(dc.INDV_ID) || '|DC_INDV' AS PTY_PK,
               dc.create_dt AS CREATE_DT, 'DC_INDV' AS SRC_TBL,
               ROW_NUMBER() OVER (PARTITION BY dc.INDV_ID ORDER BY dc.CREATE_DT DESC) AS KEY_RN
          FROM STG_TRS_D_DC_INDV dc
        UNION
        SELECT cv.indv_id, NULL, NULL, cv.create_dt, cv.TW_CONVERT_IND, cv.LTC_CONVERT_IND, TO_CHAR(cv.INDV_ID),
               cv.create_dt, 'MCI', ROW_NUMBER() OVER (PARTITION BY cv.INDV_ID ORDER BY cv.CREATE_DT DESC)
          FROM STG_TRS_D_CV_DC_MCI_INDV cv
    ),
    src AS (
        SELECT dly.INDV_ID, dly.FILE_CLEARANCE_SW, dly.SSA_VALIDATION_SW, dly.EFF_BEGIN_DT, dly.TW_CONVERT_IND,
               dly.LTC_CONVERT_IND, dly.PTY_PK, dly.CREATE_DT, dly.SRC_TBL
          FROM daily_indv dly
          JOIN STG_TRS_VALID_MEMBERS IM ON dly.INDV_ID = IM.INDV_ID AND dly.SRC_TBL = IM.SRC_TBL
         WHERE dly.KEY_RN = 1
    ),
    -- exp_Attr_Type + nrm_Attribute_Types (5 occurrences)
    normalized AS (
        SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT AS SRC_LAST_UPD_DT, 'File_Clearance_SW' AS ATTR_TYPE,
               TO_CHAR(s.FILE_CLEARANCE_SW) AS ATTR_VALUE FROM src s
        UNION ALL
        SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'SSA_Validation_SW', TO_CHAR(s.SSA_VALIDATION_SW) FROM src s
        UNION ALL
        SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'TW_Convert_Ind', TO_CHAR(s.TW_CONVERT_IND) FROM src s
        UNION ALL
        SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'LTC_Convert_Ind', TO_CHAR(s.LTC_CONVERT_IND) FROM src s
        UNION ALL
        SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'Source_Table', TO_CHAR(s.SRC_TBL) FROM src s
    ),
    -- fltr_Null_Values + exp_Pkey_Src_Object + srtr_Pkey (distinct)
    attrs AS (
        SELECT DISTINCT NVL(a.PTY_PK, '') || '|' || a.ATTR_TYPE AS pkey_src_object, a.EFF_BEGIN_DT, a.PTY_PK,
               a.ATTR_TYPE, a.ATTR_VALUE, a.SRC_LAST_UPD_DT
          FROM normalized a
         WHERE NOT (PKG_COMMON.PKG_COMMON.fn_snow_helper03_common(a.ATTR_VALUE) = 1)                 /* BAD DATA: NULL / blank values dropped */
    )
    -- exp_Version_Seq_No
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, __col5, __col6, ATTR_TYPE, ATTR_VALUE, __col9, __col10, __col11, NULL, __col13, pkey_src_object, NULL, __col16, SRC_LAST_UPD_DT, PTY_PK, NULL FROM (SELECT t.pkey_src_object, NULL, NULL, NULL, NULL, t.EFF_BEGIN_DT /* TIMELINE */ AS __col5, NULL /* TIMELINE: unfed */ AS __col6, t.ATTR_TYPE, t.ATTR_VALUE, 1 /* TIMELINE: VERSION_SEQ_NUM hard-coded */ AS __col9, NULL /* TIMELINE: unfed */ AS __col10, NULL /* TIMELINE: unfed */ AS __col11, NULL, l_run_ts AS __col13, t.pkey_src_object, NULL, l_run_ts AS __col16, t.SRC_LAST_UPD_DT, t.PTY_PK, NULL, ROW_NUMBER() OVER (PARTITION BY t.pkey_src_object ORDER BY t.EFF_BEGIN_DT DESC NULLS LAST) AS __qual_rn FROM attrs t
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_MNG_ATTR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = t.pkey_src_object
     /* BAD DATA: unique key not yet in the table, first row per key in this run */
     WHERE xa.PKEY_SRC_OBJECT IS NULL
    ) WHERE __qual_rn = 1;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_MNG_ATTR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw_mng_attr;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr(P_ATTR_TP_AUTH_REP IN VARCHAR2 DEFAULT 'Auth_Rep_Flag') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (CREATE_DATE, LAST_UPDATE_DATE, MNG_ATTR_TP, PTY_FK, PERIOD_END_DATE, PERIOD_START_DATE, VERSION_SEQ,
            SRC_ROWID, PKEY_SRC_OBJECT, SRC_LAST_UPD_DT, MNG_ATTR_VAL)
    WITH
    -- Read_STG_TRS_D_DC_Primary_Payee (custom SQL, query mode SEMI)
    a AS (
        SELECT ed.indv_id, 'Y' AS AR_FLAG, ed.elig_eff_begin_dt AS eff_begin_dt, ed.elig_eff_end_dt AS eff_end_dt,
               p.create_dt AS create_dt                                                                  -- In1
          FROM STG_TRS_D_DC_PRIMARY_PAYEE p
          JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
          JOIN STG_TRS_DC_CASES c ON p.case_num = c.case_num
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ed.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt                    -- In2
          FROM STG_TRS_D_DC_CASES c
          JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
          JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ed.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt                    -- In3
          FROM STG_TRS_DC_CASES c
          JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
          JOIN STG_TRS_D_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, NVL(p.create_dt, ed.create_dt) -- Out1
          FROM STG_TRS_D_CV_ED_MCI_EDG_INDV ed
          LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
            ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt                    -- Inner
          FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
          JOIN STG_TRS_D_DC_PRIMARY_PAYEE p
            ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, NVL(p.create_dt, ed.create_dt) -- Out3
          FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
          LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
            ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_D_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    ),
    src AS (
        SELECT DISTINCT a.indv_id AS INDV_ID, a.AR_FLAG, a.eff_begin_dt AS EFF_BEGIN_DT, a.eff_end_dt AS EFF_END_DT,
               a.create_dt AS CREATE_DT
          FROM a
          JOIN STG_TRS_VALID_MEMBERS IM ON TO_CHAR(a.INDV_ID) = IM.PTY_PK
    ),
    -- srtr_Indv_Id -> exp_Rank -> srtr_Rank (TIMELINE: distinct re-sort) -> exp_Pkey_Generation
    keyed AS (
        SELECT DISTINCT s.INDV_ID, s.AR_FLAG, s.EFF_BEGIN_DT, s.EFF_END_DT, s.CREATE_DT,
               TO_CHAR(s.INDV_ID) || '|' || P_ATTR_TP_AUTH_REP  AS pkey_src_object,
               TO_CHAR(s.INDV_ID)                                AS pty_pk
          FROM src s
    ),
    -- agg_Dedup_TRS_Pty_Mng_Attr: group by PKEY_SRC_OBJECT, MAX(EFF_END_DT), last row for the other ports
    agg AS (
        SELECT k.*,
               MAX(k.EFF_END_DT) OVER (PARTITION BY k.pkey_src_object)                               AS max_eff_end_dt,
               ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object
                                  ORDER BY k.EFF_BEGIN_DT DESC NULLS FIRST, k.EFF_END_DT DESC NULLS FIRST,
                                           k.CREATE_DT DESC NULLS FIRST)                             AS rn
          FROM keyed k
    )
    SELECT g.CREATE_DT, l_run_ts, P_ATTR_TP_AUTH_REP, g.pty_pk, g.max_eff_end_dt /* TIMELINE */,
           g.EFF_BEGIN_DT /* TIMELINE */, 1 /* TIMELINE: exp_Rank.VERSION_SEQ_NUM hard-coded */, g.pkey_src_object,
           g.pkey_src_object, g.CREATE_DT, g.AR_FLAG
      FROM agg g
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_MNG_ATTR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = g.pkey_src_object
     WHERE g.rn = 1
       /* BAD DATA: unique key not yet in the table */
       AND xa.PKEY_SRC_OBJECT IS NULL;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_MNG_ATTR (Auth_Rep_Flag)', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing_mng_attr;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm(P_MEMBER_NAME_TYPE_CODE IN VARCHAR2 DEFAULT '002') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Nm';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);  -- $sys.MappingRunStartTime
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_NM
           (PTY_FK, SFX_NM, FRST_NM, PFX_NM, LST_NM, MDL_NM, FULL_NM, VERSION_SEQ, LAST_UPDATE_DATE, NM_TP, SRC_ROWID,
            ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_END_DATE, PERIOD_REFERENCE_TIME, UPDATED_BY,
            CREATE_DATE, CREATOR, HUB_STATE_IND, SRC_FULL_NM, SRC_LAST_UPD_DT, PKEY_SRC_OBJECT, PERIOD_START_DATE)
    WITH
    lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.PKG_COMMON.fn_snow_helper43_common())),
    -- Read_STG_TRS_D_CV_DC_MCI_Alias (custom SQL, query mode SEMI)
    src AS (
        SELECT DISTINCT DC_ALIAS.INDV_ID AS INDV_ID, DC_ALIAS.PKEY_PTY AS PKEY_PTY,
               RTRIM(LTRIM(DC_ALIAS.FIRST_NAME)) AS FIRST_NAME, RTRIM(LTRIM(DC_ALIAS.MID_NAME)) AS MID_NAME,
               RTRIM(LTRIM(DC_ALIAS.LAST_NAME)) AS LAST_NAME, RTRIM(DC_ALIAS.SUFX_NAME) AS SUFX_NAME,
               RTRIM(DC_ALIAS.PREFIX_NAME) AS PREFIX_NAME, DC_ALIAS.CREATE_DT AS CREATE_DT,
               DC_ALIAS.SEQUENCE_NUM AS SEQUENCE_NUM
          FROM (SELECT INDV_ID, TO_CHAR(INDV_ID) AS PKEY_PTY, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME,
                       PREFIX_NAME, CREATE_DT, SEQUENCE_NUM
                  FROM STG_TRS_D_CV_DC_MCI_ALIAS MCI_ALIAS
                UNION ALL
                SELECT INDV_ID, TO_CHAR(INDV_ID) || '|DC_INDV' AS PKEY_PTY, FIRST_NAME, MID_NAME, LAST_NAME,
                       SUFX_NAME, PREFIX_NAME, CREATE_DT, SEQ_NUM
                  FROM STG_TRS_D_DC_ALIAS DC_ALIAS) DC_ALIAS
          JOIN STG_TRS_VALID_MEMBERS VM ON DC_ALIAS.PKEY_PTY = VM.PTY_PK
    ),
    named AS (
        SELECT s.*,
               TRIM(NVL(s.FIRST_NAME, '') || CASE WHEN s.MID_NAME IS NOT NULL THEN ' ' || TRIM(s.MID_NAME) ELSE '' END
                    || ' ' || NVL(LTRIM(s.LAST_NAME), ''))                                   AS src_full_name,
               PKG_COMMON.PKG_COMMON.fn_snow_helper14_common(s.FIRST_NAME, s.MID_NAME, s.LAST_NAME, NULL)          AS tn
          FROM src s
         WHERE s.FIRST_NAME IS NOT NULL AND s.LAST_NAME IS NOT NULL                         -- fltr_Null_Fn_Ln
    ),
    std AS (
        SELECT n.*,
               -- source system not linked: the prefix / suffix lookups cannot match (NULL standardized values)
               PKG_COMMON.PKG_COMMON.fn_snow_helper15_common(CAST(n.tn.first_name AS VARCHAR2(4000)), CAST(n.tn.middle_name AS VARCHAR2(4000)), CAST(n.tn.last_name AS VARCHAR2(4000)),
                                       n.src_full_name, n.PREFIX_NAME, n.SUFX_NAME, NULL, NULL,
                                       jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)            AS nm
          FROM named n
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(CAST(n.tn.first_name AS VARCHAR2(4000)))) AND (jf.IS_FIRST_JUNK = 1)
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(CAST(n.tn.last_name AS VARCHAR2(4000)))) AND (jl.IS_LAST_JUNK = 1)
    ),
    -- srtr_Pkey (distinct) / srtr_TRS_Pty_Nm (distinct); GNDR_CD is an unfed port (NULL) and is left out
    dedup AS (
        SELECT DISTINCT s.PKEY_PTY, s.CREATE_DT, CAST(s.nm.sfx_name AS VARCHAR2(4000)) AS sfx_nm,
               CAST(s.nm.first_name AS VARCHAR2(4000)) AS frst_nm, CAST(s.nm.prfx_name AS VARCHAR2(4000)) AS prfx_nm,
               CAST(s.nm.last_name AS VARCHAR2(4000)) AS lst_nm, CAST(s.nm.middle_name AS VARCHAR2(4000)) AS mdl_nm,
               CAST(s.nm.full_name AS VARCHAR2(4000)) AS full_nm, s.src_full_name, s.SEQUENCE_NUM,
               NVL(s.PKEY_PTY, '') || '|' || P_MEMBER_NAME_TYPE_CODE || '|' || NVL(TO_CHAR(s.SEQUENCE_NUM), '')
                                                                                            AS pkey_src_object
          FROM std s
    )
    -- exp_Party_Consolidation + exp_Pkey
    SELECT PKEY_PTY, sfx_nm, frst_nm, prfx_nm, lst_nm, mdl_nm, full_nm, __col7, __col8, __col9, pkey_src_object, NULL, NULL, NULL, NULL, __col15, __col16, NULL, CREATE_DT, NULL, NULL, src_full_name, CREATE_DT, pkey_src_object, __col24 FROM (SELECT d.PKEY_PTY, d.sfx_nm, d.frst_nm, d.prfx_nm, d.lst_nm, d.mdl_nm, d.full_nm, 1 /* TIMELINE: VERSION_SEQ_NUM hard-coded */ AS __col7, l_run_ts AS __col8, P_MEMBER_NAME_TYPE_CODE AS __col9, d.pkey_src_object, NULL, NULL, NULL, NULL, NULL /* TIMELINE: unfed */ AS __col15, NULL /* TIMELINE: unfed */ AS __col16, NULL, d.CREATE_DT, NULL, NULL, d.src_full_name, d.CREATE_DT, d.pkey_src_object, d.CREATE_DT /* TIMELINE: PERIOD_START_DATE_OUT, see header */
       AS __col24, ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object ORDER BY d.CREATE_DT DESC NULLS LAST, d.full_nm) AS __qual_rn FROM dedup d
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_NM WHERE VERSION_SEQ = 1) xn
             ON xn.PKEY_SRC_OBJECT = d.pkey_src_object
     /* BAD DATA: unique key not yet in the table, first row per key in this run */
     WHERE xn.PKEY_SRC_OBJECT IS NULL
    ) WHERE __qual_rn = 1;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_NM', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm_pty_nm;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_build() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Alt_Id';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_ALTID_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_ALTID_ROUTED AS SELECT *
      FROM (
        WITH
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        lkp_lcv AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper45_common())),
        -- Read_STG_TRS_D_DC_INDV (custom SQL, query mode SEMI)
        all_indv AS (
            SELECT DISTINCT TO_CHAR(mci_indv.indv_id) AS pty_pkey, mci_indv.indv_id AS member_id,
                   mci_indv.create_dt, mci_indv.ssn, ''1'' AS cv_ind
              FROM STG_TRS_D_CV_DC_MCI_INDV mci_indv
            UNION ALL
            SELECT DISTINCT TO_CHAR(indv.indv_id) || ''|DC_INDV'', indv.indv_id, indv.create_dt, indv.ssn, NULL
              FROM STG_TRS_D_DC_INDV indv
            UNION ALL
            SELECT DISTINCT TO_CHAR(mrg.old_indv_id), mrg.indv_id, mrg.create_dt, NULL, NULL
              FROM STG_TRS_D_CV_DC_MRG_SPRT_INDV mrg
             WHERE mrg.type_cd = ''ME''
        ),
        de_dup_indv AS (
            SELECT a.pty_pkey, TO_CHAR(a.member_id) AS member_id, a.create_dt AS start_dt, a.ssn, a.cv_ind,
                   ROW_NUMBER() OVER (PARTITION BY a.pty_pkey
                                      ORDER BY LENGTH(TO_CHAR(a.ssn)) DESC NULLS LAST, a.create_dt DESC) AS key_rn
              FROM all_indv a
              JOIN STG_TRS_VALID_MEMBERS vm ON a.pty_pkey = vm.pty_pk
        ),
        src AS (
            SELECT pty_pkey AS PTY_PKEY, member_id AS MEMBER_ID, start_dt AS START_DT, ssn AS SSN, cv_ind AS CV_IND
              FROM de_dup_indv
             WHERE key_rn = 1
        ),
        -- exp_TRS_Pty_Rle_Alt_Id + lkp_Valid_SSN (custom lookup SQL: SSA-validated, positive SSNs)
        with_ssn AS (
            SELECT *, valid_ssn FROM (SELECT s.*, v.SSN AS valid_ssn, ROW_NUMBER() OVER (PARTITION BY s.PTY_PKEY ORDER BY v.SSN) AS __qual_rn FROM src s
              LEFT JOIN (SELECT DISTINCT INDV_ID, SSN FROM STG_TRS_H_DC_INDV
                          WHERE SSA_VALIDATION_SW = ''Y'' AND SSN > 0) v
                     ON v.INDV_ID = PKG_COMMON.fn_snow_helper04_common(s.MEMBER_ID, 0) AND v.SSN = s.SSN
            ) WHERE __qual_rn = 1
        ),
        -- mplt_TRS_Pty_Rle_Alt_Id_Normalization: rules + NRM_ALT_ID (helper UDTF)
        normalized AS (
            SELECT n.*
              FROM with_ssn w,
                   TABLE(fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id(w.PTY_PKEY, w.START_DT, ''TRS'', w.MEMBER_ID,
                                                                       w.valid_ssn, w.MEMBER_ID, NULL, w.CV_IND)) n
        ),
        -- LKP_ALT_ID_LBL + FLTR_Remove_Null_Alt_IDs + RTR_Invalid_Alt_Ids + EXP_safe_tgt
        routed AS (
            SELECT n.PKEY_SRC_OBJECT_PTY AS pkey_src_object_pty, n.PERIOD_START_DATE AS period_start_date,
                   n.ALT_ID_VAL AS alt_id_val, lb.MSTR_REF_CODE AS alt_id_typ, lb.MSTR_REF_LABEL AS alt_id_label,
                   n.DQ_EXCP_CD AS dq_excp_cd, xd.EXCEPTION_DESC AS dq_excp, n.SRC_SYS AS src_sys, n.CV_IND AS cv_ind,
                   NVL(n.PKEY_SRC_OBJECT_PTY, '''') || ''|Member|'' || NVL(lb.MSTR_REF_CODE, '''') || ''|'' || n.ALT_ID_VAL
                                                                                         AS pkey_src_object_alt_id,
                   NVL(n.PKEY_SRC_OBJECT_PTY, '''') || ''|Member''                           AS pty_rle_fk,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper03_common(n.DQ_EXCP_CD)                AS is_valid
              FROM normalized n
              LEFT JOIN lkp_lcv lb ON lb.CODE_TYPE = ''ALT_ID_TP'' AND lb.MSTR_REF_CODE = n.ALT_ID_TYP
                                  AND lb.SRC_SYS = n.SRC_SYS
              LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = n.DQ_EXCP_CD
             /* BAD DATA: FLTR_Remove_Null_Alt_IDs: NOT ISNULL(ALT_ID_VAL) AND RTRIM(ALT_ID_VAL) <> '''' */
             WHERE n.ALT_ID_VAL IS NOT NULL AND RTRIM(n.ALT_ID_VAL) <> ''''
        )
        SELECT r.*,
               1 /* TIMELINE: exp_Rank.VERSION_SEQ hard-coded */                  AS version_seq,
               ''Issued''                                                            AS sts_cd,
               ''Bad Value''                                                         AS exc_type,
               :1                                                           AS run_ts,
               :2                                                          AS mapping_name,
               /* BAD DATA: unique keys Snowflake does not enforce */
               (ROW_NUMBER() OVER (PARTITION BY r.is_valid, r.pkey_src_object_alt_id
                                       ORDER BY r.alt_id_typ NULLS LAST, r.period_start_date DESC) = 1
                AND xa.PKEY_SRC_OBJECT IS NULL)                                    AS uq_alt_id,CASE WHEN ROW_NUMBER() OVER (PARTITION BY r.is_valid, r.pkey_src_object_pty, r.dq_excp_cd
                                      ORDER BY r.alt_id_typ NULLS LAST) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY r.is_valid, r.pkey_src_object_pty, r.dq_excp_cd
                                      ORDER BY r.alt_id_typ NULLS LAST) = 1) THEN 0 END AS uq_exc
          FROM routed r
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = r.pkey_src_object_alt_id
      )' USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_ALTID_ROUTED;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_ALTID_ROUTED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Alt_Id';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_ALT_ID (PKEY_SRC_OBJECT, SRC_ROWID, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, ALT_ID_TP, ALT_ID_VAL, STS_CD, ALT_ID_TP_FLTR, CV_IND, PTY_RLE_FK, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_END_DATE, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE, CREATOR, HUB_STATE_IND, SRC_LAST_UPD_DT)
    SELECT pkey_src_object_alt_id, pkey_src_object_alt_id, period_start_date, version_seq, run_ts, alt_id_typ, alt_id_val, sts_cd, alt_id_typ, cv_ind, pty_rle_fk, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, period_start_date, NULL, NULL, period_start_date FROM WRK_TRS_ALTID_ROUTED WHERE (is_valid = 1) AND (uq_alt_id = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_ALT_ID', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_alt_id;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Alt_Id';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (MAPPING_NAME, SRC_SYS, RUN_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, EXCEPTION_DESC, EXCEPTION_CODE, EXCEPTION_TYPE, SRC_SYS_ID_1)
    SELECT mapping_name, src_sys, run_ts, alt_id_val, alt_id_label, dq_excp, dq_excp_cd, exc_type, pkey_src_object_pty FROM WRK_TRS_ALTID_ROUTED WHERE NOT (is_valid = 1) AND (uq_exc = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_build() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Pln';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_PLN_PLANNED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_PLN_PLANNED AS SELECT *
      FROM (
        WITH
        lkp_cv  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- Read_Stg_TRS_D_IN_Managed_Care (custom SQL, query mode SEMI)
        src AS (
            SELECT DISTINCT M.INDV_ID AS INDV_ID, M.BEGIN_DT, M.MC_PLAN, M.HISTORY_SEQ, M.END_DT, M.CREATE_DT
              FROM STG_TRS_D_IN_MANAGED_CARE M
              JOIN STG_TRS_VALID_MEMBERS VM ON M.INDV_ID = VM.INDV_ID AND VM.SRC_TBL = ''MCI''
             WHERE M.MC_PLAN IS NOT NULL
               AND (M.BEGIN_DT < M.END_DT OR M.END_DT IS NULL)
        ),
        -- lkp_Plan_Cd + exp_Pty_Rle_Fk + exp_Pty_Rle_Plan
        planned AS (
            SELECT s.*,
                   lk.MSTR_CODE_VALUE                                                   AS pln_mstr_cd,
                   TO_CHAR(s.INDV_ID) || ''|Member''                                   AS pty_rle_fk,
                   TO_CHAR(s.INDV_ID) || ''|Member|'' || NVL(lk.MSTR_CODE_VALUE, '''')   AS pkey_prty_rl_plan
              FROM src s
              LEFT JOIN lkp_cv lk ON lk.CODE_TYPE = ''PLAN_CD'' AND lk.SRC_SYS = ''MAX'' AND lk.SRC_CODE_VALUE = s.MC_PLAN
        )
        SELECT p.*,
               -- agg_Dedup_Rec: last row per key in srtr_Pkey order (NULL high)
               ROW_NUMBER() OVER (PARTITION BY p.pkey_prty_rl_plan
                                  ORDER BY p.BEGIN_DT DESC NULLS FIRST, p.END_DT DESC NULLS FIRST,
                                           p.pty_rle_fk DESC NULLS FIRST, p.CREATE_DT DESC NULLS FIRST)   AS rn_key,
               -- exp_Rank + fltr_Rank on the invalid rows: first row per INDV_ID in source order
               ROW_NUMBER() OVER (PARTITION BY p.INDV_ID,CASE WHEN p.pln_mstr_cd IS NULL THEN 1 WHEN NOT (p.pln_mstr_cd IS NULL) THEN 0 END ORDER BY p.MC_PLAN, p.BEGIN_DT, p.END_DT)                               AS rn_invalid,CASE WHEN /* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
               xp.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (/* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
               xp.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_pln,
               1 /* TIMELINE: VERSION_SEQ hard-coded */                                                   AS version_seq,
               ''TRS''                                                    AS src_sys,
               :1                                                AS run_ts,
               :2                                               AS mapping_name,
               ''Plan''                                                   AS attr_plan,
               ''Invalid_Plan''                                           AS exc_code,
               ex.EXCEPTION_DESC                                        AS exc_desc,
               ex.EXCEPTION_TYPE                                        AS exc_type,
               TO_CHAR(p.BEGIN_DT, ''YYYY-MM-DD'')                     AS begin_dt_text
          FROM planned p
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = ''Invalid_Plan''
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_PLN WHERE VERSION_SEQ = 1) xp
                 ON xp.PKEY_SRC_OBJECT = p.pkey_prty_rl_plan
      )' USING l_run_ts, c_mapping;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_PLN_PLANNED;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_PLN_PLANNED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Pln';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_PLN (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, PTY_RLE_FK, PLN_FK, UPDATED_BY, CREATOR, HUB_STATE_IND, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, SRC_ROWID, CREATE_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_prty_rl_plan, BEGIN_DT, END_DT, version_seq, run_ts, pty_rle_fk, pln_mstr_cd, NULL, NULL, NULL, NULL, NULL, NULL, NULL, pkey_prty_rl_plan, run_ts, CREATE_DT FROM WRK_TRS_PLN_PLANNED WHERE pln_mstr_cd IS NOT NULL AND rn_key = 1 AND (uq_pln = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_PLN', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_pln;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Pty_Rle_Pln';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, MAPPING_NAME, RUN_DATE, PERIOD_START_DATE, SRC_SYS_ID_2)
    SELECT src_sys, INDV_ID, exc_type, exc_desc, exc_code, MC_PLAN, attr_plan, mapping_name, run_ts, BEGIN_DT, begin_dt_text FROM WRK_TRS_PLN_PLANNED WHERE pln_mstr_cd IS NULL AND rn_invalid = 1;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln_exc;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Addr_1';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO STG_TRS_D_UNQ_ADDR
           (ADDR_ID, ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT, LATTD,
            LNGTD, VLDTN_MSG, VLDTN_DESC, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, BLDG_NMBR, SUB_BLDG_NM,
            SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ADDRDR_RSLT_PCT, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
            SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT,
            ORG_DEPT)
    WITH
    lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.PKG_COMMON.fn_snow_helper41_common())),
    lkp_mc AS (SELECT * FROM TABLE(PKG_COMMON.PKG_COMMON.fn_snow_helper46_common())),
    -- read_Staging_Delta_Tables (custom SQL, query mode SEMI, distinct)
    src AS (
        SELECT DISTINCT
               NVL(TO_CHAR(a.addr_st_num), '') || '|' || NVL(a.addr_st_num_frac, '') || '|' || NVL(a.addr_st_nm, '')
               || '|' || NVL(a.addr_st_dir_cd, '') || '|' || NVL(a.addr_st_type_cd, '') || '|'
               || NVL(a.addr_dwelling_type_cd, '') || '|' || NVL(a.addr_apt_num, '') || '|' || NVL(a.addr_line, '')
               || '|' || NVL(a.addr_city, '') || '|' || NVL(a.addr_state_cd, '') || '|' || NVL(TO_CHAR(a.addr_zip5), '')
               || '|' || NVL(TO_CHAR(a.addr_zip4), '')                                   AS ADDR_ID,
               a.addr_st_num AS ADDR_ST_NUM, a.addr_st_num_frac AS ADDR_ST_NUM_FRAC, a.addr_st_nm AS ADDR_ST_NM,
               a.addr_apt_num AS ADDR_APT_NUM, a.addr_line AS ADDR_LINE, a.addr_city AS ADDR_CITY,
               a.addr_state_cd AS ADDR_STATE_CD, a.addr_zip5 AS ADDR_ZIP5, a.addr_zip4 AS ADDR_ZIP4,
               a.addr_dwelling_type_cd AS ADDR_DWELLING_TYPE_CD, a.addr_st_type_cd AS ADDR_ST_TYPE_CD,
               a.addr_st_dir_cd AS ADDR_ST_DIR_CD
          FROM STG_TRS_D_INDV_ADDR a
    ),
    -- lkp_Addr_Street_Type (any row) + exp_TRS_Addr_Derivation
    derived AS (
        SELECT s.*,
               TRIM(NVL(TO_CHAR(s.ADDR_ST_NUM), '') || ' ' || NVL(s.ADDR_ST_NUM_FRAC, '') || ' '
                    || NVL(CASE WHEN UPPER(s.ADDR_ST_DIR_CD) IN ('EA', 'NO', 'SO', 'WE') THEN SUBSTR(s.ADDR_ST_DIR_CD, 1, 1) ELSE s.ADDR_ST_DIR_CD END, '')
                    || ' ' || NVL(s.ADDR_ST_NM, '') || ' ' || NVL(st.DESCRIPTION, ''))                AS addr_line_1,
               TRIM(NVL(s.ADDR_DWELLING_TYPE_CD, '') || ' ' || NVL(s.ADDR_APT_NUM, '') || ' '
                    || NVL(s.ADDR_LINE, ''))                                                         AS addr_line_2
          FROM src s
          LEFT JOIN (SELECT CODE, DESCRIPTION FROM (SELECT r.CODE, r.DESCRIPTION, ROW_NUMBER() OVER (PARTITION BY r.CODE ORDER BY r.DESCRIPTION) AS __qual_rn FROM STG_TRS_CD_REF r
                     ) WHERE __qual_rn = 1) st
                 ON st.CODE = s.ADDR_ST_TYPE_CD
    ),
    -- mplt_Global_Addr_Validation (lkp_State_Cd: V_LOOKUP_CODE_VALUE STATE, 'TRS')
    validated AS (
        SELECT d.*,
               PKG_COMMON.PKG_COMMON.fn_snow_helper34_common(d.addr_line_1, d.addr_line_2, d.ADDR_CITY, d.ADDR_STATE_CD,
                                       NVL(TO_CHAR(d.ADDR_ZIP5), '') || '-' || NVL(TO_CHAR(d.ADDR_ZIP4), ''),
                                       'US', stc.MSTR_CODE_VALUE) AS av
          FROM derived d
          LEFT JOIN lkp_cv stc ON stc.CODE_TYPE = 'STATE' AND stc.SRC_SYS = 'TRS'
                              AND stc.SRC_CODE_VALUE = UPPER(TRIM(d.ADDR_STATE_CD))
    )
    -- Expression
    SELECT ADDR_ID, __col1, __col2, __col3, __col4, __col5, __col6, __col7, __col8, __col9, __col10, __col11, __col12, __col13, DESCRIPTION, __col15, __col16, __col17, __col18, __col19, __col20, __col21, __col22, __col23, __col24, __col25, __col26, __col27, addr_line_1, addr_line_2, ADDR_CITY, __col31, ADDR_STATE_CD, __col33, ADDR_ZIP5, ADDR_ZIP4, __col36 FROM (SELECT v.ADDR_ID, CAST(v.av.delivery_address_line1 AS VARCHAR2(4000)) AS __col1, CAST(v.av.delivery_address_line2 AS VARCHAR2(4000)) AS __col2, CAST(v.av.building_name AS VARCHAR2(4000)) AS __col3, CAST(v.av.sub_building_number AS VARCHAR2(4000)) AS __col4, CAST(v.av.city AS VARCHAR2(4000)) AS __col5, CAST(v.av.county_fips_cd AS VARCHAR2(4000)) AS __col6, CAST(v.av.state_fips_cd AS VARCHAR2(4000)) AS __col7, CAST(v.av.country_iso2_char AS VARCHAR2(4000)) AS __col8, CAST(v.av.zip_cd_5 AS VARCHAR2(4000)) AS __col9, CAST(v.av.zip_cd_4_extn AS VARCHAR2(4000)) AS __col10, CAST(v.av.geocoding_latitude AS NUMBER(38, 6)) AS __col11, CAST(v.av.geocoding_longitude AS NUMBER(38, 6)) AS __col12, CAST(v.av.match_code AS VARCHAR2(4000)) AS __col13, mc.DESCRIPTION, CAST(v.av.mailability_score AS VARCHAR2(4000)) AS __col15, CAST(v.av.address_type AS VARCHAR2(4000)) AS __col16, CAST(v.av.organization_descriptor AS VARCHAR2(4000)) AS __col17, CAST(v.av.organization_name AS VARCHAR2(4000)) AS __col18, CAST(v.av.building_number AS VARCHAR2(4000)) AS __col19, CAST(v.av.sub_building_complete AS VARCHAR2(4000)) AS __col20, CAST(v.av.sub_building_descriptor AS VARCHAR2(4000)) AS __col21, CAST(v.av.geocoding_status AS VARCHAR2(4000)) AS __col22, CAST(v.av.residential_delivery_indicator AS VARCHAR2(4000)) AS __col23, CAST(v.av.status_info_result_percentage AS VARCHAR2(4000)) AS __col24, CAST(v.av.early_warning_system_return_cd AS VARCHAR2(4000)) AS __col25, CAST(v.av.cass_error_code AS VARCHAR2(4000)) AS __col26, CAST(v.av.dpv_confirmation AS VARCHAR2(4000)) AS __col27, v.addr_line_1, v.addr_line_2, v.ADDR_CITY, NULL /* SRC_COUNTY unfed */ AS __col31, v.ADDR_STATE_CD, 'US' AS __col33, v.ADDR_ZIP5, v.ADDR_ZIP4, CAST(v.av.organization_department AS VARCHAR2(4000))
       AS __col36, ROW_NUMBER() OVER (PARTITION BY v.ADDR_ID ORDER BY v.addr_line_1) AS __qual_rn FROM validated v
      LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = CAST(v.av.status_info_match_code AS VARCHAR2(4000))
      /* BAD DATA: primary key ADDR_ID not yet in the table */
      LEFT JOIN (SELECT DISTINCT ADDR_ID FROM STG_TRS_D_UNQ_ADDR) xu ON xu.ADDR_ID = v.ADDR_ID
     WHERE xu.ADDR_ID IS NULL
    ) WHERE __qual_rn = 1;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert STG_TRS_D_UNQ_ADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Addr_1_unq_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_build(P_MEMBER_ROLE_TYPE IN VARCHAR2 DEFAULT 'Member',
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr') RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Addr_2';
    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_TRS_ADDR2_SCORED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE 'CREATE TABLE WRK_TRS_ADDR2_SCORED AS SELECT *
      FROM (
        WITH
        lkp_cv  AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())),
        lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())),
        -- read_Staging_Delta_Tables (custom SQL, query mode SEMI)
        addr_de_dup AS (
            SELECT a.indv_id, a.case_num, a.edg_num, a.addr_type_cd,
                   NVL(TO_CHAR(a.addr_st_num), '''') || ''|'' || NVL(a.addr_st_num_frac, '''') || ''|''
                   || NVL(a.addr_st_nm, '''') || ''|'' || NVL(a.addr_st_dir_cd, '''') || ''|'' || NVL(a.addr_st_type_cd, '''')
                   || ''|'' || NVL(a.addr_dwelling_type_cd, '''') || ''|'' || NVL(a.addr_apt_num, '''') || ''|''
                   || NVL(a.addr_line, '''') || ''|'' || NVL(a.addr_city, '''') || ''|'' || NVL(a.addr_state_cd, '''') || ''|''
                   || NVL(TO_CHAR(a.addr_zip5), '''') || ''|'' || NVL(TO_CHAR(a.addr_zip4), '''') AS addr_id,
                   GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) AS create_dt, a.eff_begin_dt, a.eff_end_dt,
                   ROW_NUMBER() OVER (PARTITION BY a.indv_id, a.addr_type_cd, a.case_num, a.edg_num
                                      ORDER BY GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) DESC,
                                               a.eff_begin_dt DESC) AS key_rn
              FROM STG_TRS_D_INDV_ADDR a
        ),
        src AS (
            SELECT a.indv_id AS INDV_ID, a.case_num AS CASE_NUM, a.edg_num AS EDG_NUM, vm.pty_pk AS PTY_PK,
                   a.addr_type_cd AS ADDR_TYPE_CD, a.create_dt AS CREATE_DT, a.eff_begin_dt AS EFF_BEGIN_DT,
                   a.eff_end_dt AS EFF_END_DT, u.addr_id AS ADDR_ID, u.addr_ln_1 AS ADDR_LN_1, u.addr_ln_2 AS ADDR_LN_2,
                   u.bldng_nm AS BLDNG_NM, u.flr_num AS FLR_NUM, u.city AS CITY, u.county AS COUNTY, u.state AS STATE,
                   u.cntry_cd AS CNTRY_CD, u.pstl_cd AS PSTL_CD, u.pstl_cd_ext AS PSTL_CD_EXT, u.lattd AS LATTD,
                   u.lngtd AS LNGTD, u.vldtn_msg AS VLDTN_MSG, u.vldtn_desc AS VLDTN_DESC, u.mlblty_scr AS MLBLTY_SCR,
                   u.addr_tp_cd AS ADDR_TP_CD, u.org_desc AS ORG_DESC, u.org_dept AS ORG_DEPT, u.org_nm AS ORG_NM,
                   u.bldg_nmbr AS BLDG_NMBR, u.sub_bldg_nm AS SUB_BLDG_NM, u.sub_bldg_desc AS SUB_BLDG_DESC,
                   u.geocd_sts_cd AS GEOCD_STS_CD, u.rsdntl_dlvry_ind AS RSDNTL_DLVRY_IND,
                   u.addrdr_rslt_pct AS ADDRDR_RSLT_PCT, u.erly_wrng_cd AS ERLY_WRNG_CD, u.cass_err_cd AS CASS_ERR_CD,
                   u.dlvry_pnt_vldn AS DLVRY_PNT_VLDN, u.src_addr_ln_1 AS SRC_ADDR_LN_1,
                   u.src_addr_ln_2 AS SRC_ADDR_LN_2, u.src_city AS SRC_CITY, u.src_county AS SRC_COUNTY,
                   u.src_state AS SRC_STATE, u.src_cntry AS SRC_CNTRY, u.src_pstl_cd AS SRC_PSTL_CD,
                   u.src_pstl_cd_ext AS SRC_PSTL_CD_EXT
              FROM addr_de_dup a
              JOIN STG_TRS_D_UNQ_ADDR u ON a.addr_id = u.addr_id
              JOIN STG_TRS_VALID_MEMBERS vm ON a.indv_id = vm.indv_id
             WHERE a.key_rn = 1
        ),
        -- lkp_Address_Type + Exp_src_defaults + exp_Address_Hold.PKEY_PTY_RLE_ADDR + mplt_Date_Greater_Than_Fifty_Years
        keyed AS (
            SELECT s.*,
                   at.MSTR_CODE_VALUE                                                                    AS mstr_addr_tp,
                   NVL(s.PSTL_CD, '''') || CASE WHEN s.PSTL_CD_EXT IS NOT NULL THEN ''-'' || s.PSTL_CD_EXT ELSE '''' END         AS rslt_pstl_cd,
                   NVL(s.PTY_PK, '''') || ''|'' || :1 || ''|'' || NVL(at.MSTR_CODE_VALUE, '''') || ''|''
                   || NVL(TO_CHAR(s.CASE_NUM), '''') || ''|'' || NVL(TO_CHAR(s.EDG_NUM), '''') || ''|''
                   || NVL(TO_CHAR(s.EFF_BEGIN_DT, ''YYYYMMDD''), '''')                                    AS pkey_pty_rle_addr,
                   /* TIMELINE */ PKG_COMMON.fn_snow_helper21_common(s.EFF_END_DT, :2)                         AS end_date_50y
              FROM src s
              LEFT JOIN lkp_cv at ON at.CODE_TYPE = ''ADDR_TP'' AND at.SRC_SYS = ''TRS'' AND at.SRC_CODE_VALUE = s.ADDR_TYPE_CD
        ),
        -- exp_Score_and_Exception_details + srt_Party_Role_Addr_By_PKey_Beg_Date + exp_Party_Role_Address_Attribute_Hold
        scored AS (
            SELECT k.*,
                   /* VALIDATION */ PKG_COMMON.fn_snow_helper05_common(k.mstr_addr_tp, k.MLBLTY_SCR, k.VLDTN_MSG)     AS score,
                   PKG_COMMON.fn_snow_helper06_common(k.mstr_addr_tp, k.MLBLTY_SCR, k.VLDTN_MSG)                     AS addr_issue_desc,
                   /* TIMELINE */
                   ROW_NUMBER() OVER (PARTITION BY k.pkey_pty_rle_addr
                                      ORDER BY k.CREATE_DT DESC NULLS FIRST, k.EFF_END_DT DESC NULLS FIRST,
                                               k.EFF_BEGIN_DT DESC NULLS FIRST)                          AS version_seq
              FROM keyed k
        )
        SELECT c.*,
               ''TRS''                                                                AS src_sys,
               :2                                                            AS run_ts,
               :3                                                           AS mapping_name,
               :4                                             AS hierarchy_code,
               :5                                               AS hm_rel_tp_cd,
               ''Primary''                                                            AS pref_lvl,
               /* TIMELINE */ CASE WHEN c.EFF_END_DT IS NOT NULL THEN :2 ELSE NULL END        AS period_reference_time,
               /* TIMELINE */ c.pkey_pty_rle_addr || ''|'' || TO_CHAR(c.version_seq) AS src_rowid,
               NVL(TO_CHAR(TRUNC(c.CASE_NUM)), '''') || ''|'' || NVL(TO_CHAR(TRUNC(c.EDG_NUM)), '''') AS loc_idn,
               NVL(c.PTY_PK, '''') || ''|'' || :1                      AS pty_rle_fk,
               PKG_COMMON.fn_snow_helper07_common(c.ADDR_LN_1, c.ADDR_LN_2)                    AS hold_line1,
               PKG_COMMON.fn_snow_helper08_common(c.ADDR_LN_1, c.ADDR_LN_2)                    AS hold_line2,
               NVL(c.ADDR_LN_1, '''') || ''|'' || NVL(c.ADDR_LN_2, '''') || ''|'' || NVL(c.CITY, '''') || ''|'' || c.rslt_pstl_cd
               || ''|'' || NVL(c.STATE, '''') || ''|'' || NVL(c.CNTRY_CD, '''')             AS dqm_addr_src_key,
               NVL(c.SRC_PSTL_CD, '''') || CASE WHEN c.SRC_PSTL_CD_EXT IS NOT NULL THEN ''-'' || c.SRC_PSTL_CD_EXT ELSE '''' END AS dqm_src_pstl_cd,
               CASE WHEN c.addr_issue_desc IS NOT NULL THEN ''Address'' ELSE NULL END                  AS exc_attribute_name,
               CASE WHEN c.addr_issue_desc IS NOT NULL THEN NVL(c.SRC_ADDR_LN_1, '''') || '' '' || NVL(c.SRC_ADDR_LN_2, '''') || '' '' || NVL(c.SRC_CITY, '''') || '' ''
                   || NVL(c.SRC_STATE, '''') || '' '' || NVL(TO_CHAR(c.SRC_PSTL_CD), '''') || '' ''
                   || NVL(TO_CHAR(c.SRC_PSTL_CD_EXT), '''') || '' '' || NVL(c.SRC_CNTRY, '''') ELSE NULL END AS exc_attribute_value,
               ex.EXCEPTION_CODE                                                    AS exc_code,
               ex.EXCEPTION_DESC                                                    AS exc_desc,
               ex.EXCEPTION_TYPE                                                    AS exc_type,CASE WHEN /* BAD DATA: unique keys Snowflake does not enforce */
               xa.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (/* BAD DATA: unique keys Snowflake does not enforce */
               xa.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_addr,CASE WHEN ROW_NUMBER() OVER (PARTITION BY c.score, c.INDV_ID, c.CASE_NUM, c.EDG_NUM
                                      ORDER BY c.CREATE_DT DESC, c.ADDR_TYPE_CD) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY c.score, c.INDV_ID, c.CASE_NUM, c.EDG_NUM
                                      ORDER BY c.CREATE_DT DESC, c.ADDR_TYPE_CD) = 1) THEN 0 END AS uq_addr_exc
          FROM scored c
          LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = ''Invalid_Address''
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_ADDR) xa
                 ON xa.PKEY_SRC_OBJECT = c.pkey_pty_rle_addr AND xa.VERSION_SEQ = c.version_seq
      )' USING P_MEMBER_ROLE_TYPE, l_run_ts, c_mapping, P_MEMBER_HIERARCHY_CODE, P_MEMBER_HM_REL_TP_CD;
    SELECT COUNT(*) INTO l_rows FROM WRK_TRS_ADDR2_SCORED;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'build WRK_TRS_ADDR2_SCORED', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Addr_2_build;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Addr_2';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO DQM_ADDRESS (ADDR_SRC_KEY, SRC_SYSTEM, PTY_SRC_KEY, LOAD_DT, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_CNTRY, RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_STATE, RSLT_CNTRY, COUNTY_FIPS, STATE_FIPS, LATTD, LNGTD, RSLT_PSTL_CD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_DESC, BLDG, SUB_BLDG, MLBLTY_SCR, ADDRDR_MTCH_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, RSLT_COUNTY, ORG_DEPT, ORG_NM, SRC_COUNTY, SRC_STATE, SRC_PSTL_CD, MDM_ADDR_TP)
    SELECT dqm_addr_src_key, src_sys, PTY_PK, run_ts, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_CNTRY, ADDR_LN_1, ADDR_LN_2, CITY, STATE, CNTRY_CD, COUNTY, STATE, LATTD, LNGTD, rslt_pstl_cd, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_DESC, BLDG_NMBR, SUB_BLDG_NM, MLBLTY_SCR, VLDTN_MSG, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN, ADDRDR_RSLT_PCT, ADDR_TP_CD, COUNTY, ORG_DEPT, ORG_NM, SRC_COUNTY, SRC_STATE, dqm_src_pstl_cd, ADDR_TYPE_CD FROM WRK_TRS_ADDR2_SCORED;
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert DQM_ADDRESS', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Addr_2_dqm;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Addr_2';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO C_S_TRS_PTY_RLE_ADDR (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, HIERARCHY_CODE, HM_REL_TP_CD, LAST_UPDATE_DATE, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, UPDATED_BY, SRC_ROWID, HUB_STATE_IND, PREF_LVL, LOC_IDN, ADDR_TP, PTY_RLE_FK, USG_TP, ADDR_LN_1, ADDR_LN_2, CITY, PSTL_CD, PSTL_CD_EXT, CNTRY_CD, CRDNT_SYS, LATTD, LNGTD, PSTL_BRCD, FLR_NUM, BLDNG_NM, COUNTY, STATE, LCTN_CRDNT_DESC, VLDTN_MSG, RGN_CD, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, GEOCD_STS_CD, SUB_BLDG_NM, BLDG_NMBR, SUB_BLDG_DESC, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, SRC_LAST_UPD_DT, CREATOR, CREATE_DATE, EFF_STRT_DT, PERIOD_END_DATE, EFF_END_DT)
    SELECT pkey_pty_rle_addr, EFF_BEGIN_DT, version_seq, period_reference_time, hierarchy_code, hm_rel_tp_cd, run_ts, NULL, NULL, NULL, NULL, NULL, src_rowid, NULL, pref_lvl, loc_idn, mstr_addr_tp, pty_rle_fk, NULL, hold_line1, hold_line2, CITY, PSTL_CD, PSTL_CD_EXT, CNTRY_CD, NULL, LATTD, LNGTD, NULL, FLR_NUM, BLDNG_NM, COUNTY, STATE, NULL, VLDTN_MSG, NULL, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, GEOCD_STS_CD, SUB_BLDG_NM, BLDG_NMBR, SUB_BLDG_DESC, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, CREATE_DT, NULL, NULL, EFF_BEGIN_DT, end_date_50y, end_date_50y FROM WRK_TRS_ADDR2_SCORED WHERE score = '100' AND (uq_addr = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert C_S_TRS_PTY_RLE_ADDR', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Addr_2_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc() RETURN VARCHAR2 IS

    c_mapping VARCHAR2(4000) := 'm_Tgt_C_S_TRS_Addr_2';
    l_rows NUMBER := 0;
    l_line VARCHAR2(4000);
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE, RUN_DATE, ADDRESS_LINE_1, ADDRESS_LINE_2, ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, VLDTN_MSG, VLDTN_DESC, MLBLTY_SCR, exc_attribute_name, exc_attribute_value, mapping_name, ADDR_TYPE_CD, EFF_BEGIN_DT, EFF_END_DT, run_ts, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_PSTL_CD, SRC_PSTL_CD_EXT, SRC_CNTRY, INDV_ID, CASE_NUM, EDG_NUM, exc_code, exc_desc, exc_type FROM WRK_TRS_ADDR2_SCORED WHERE score = '40' AND (uq_addr_exc = 1);
    l_rows := SQL%ROWCOUNT;
    SELECT PKG_COMMON.PKG_COMMON.fn_snow_helper36_common(c_mapping, 'insert EXC_STG_BAD_REC_MEMB', l_rows) INTO l_line FROM DUAL;
    COMMIT;
    RETURN l_line;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_TRS_Addr_2_exc;


    FUNCTION fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id(p_pkey_src_object_pty IN VARCHAR2,
    p_period_start_date IN TIMESTAMP,
    p_src_sys IN VARCHAR2,
    p_alt_id_val_member_id IN VARCHAR2,
    p_alt_id_val_ssn_num IN NUMBER,
    p_alt_id_val_medicaid_id IN VARCHAR2,
    p_alt_id_val_ns_client_id IN VARCHAR2,
    p_cv_ind IN VARCHAR2) RETURN T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID IS

    l_tab T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID(PKEY_SRC_OBJECT_PTY => __w0, PERIOD_START_DATE => __w1, ALT_ID_VAL => __w2, ALT_ID_TYP => __w3, DQ_EXCP_CD => __w4, SRC_SYS => __w5, CV_IND => __w6, ORIGINAL_SSN => __w7) FROM (
SELECT p_pkey_src_object_pty AS __w0, p_period_start_date AS __w1, p_alt_id_val_medicaid_id AS __w2, '002' AS __w3, CAST(PKG_COMMON.PKG_COMMON.fn_snow_helper27_common(p_alt_id_val_medicaid_id).exception_code AS VARCHAR2(4000)) AS __w4, p_src_sys AS __w5, p_cv_ind AS __w6, LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0') AS __w7
)
UNION ALL
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID(PKEY_SRC_OBJECT_PTY => __w0, PERIOD_START_DATE => __w1, ALT_ID_VAL => __w2, ALT_ID_TYP => __w3, DQ_EXCP_CD => __w4, SRC_SYS => __w5, CV_IND => __w6, ORIGINAL_SSN => __w7) FROM (
SELECT p_pkey_src_object_pty AS __w0, p_period_start_date AS __w1, CASE WHEN CAST(PKG_COMMON.PKG_COMMON.fn_snow_helper26_common(LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0')).ssn_status AS VARCHAR2(4000)) = 'Invalid' THEN NULL ELSE LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0') END AS __w2, '004' AS __w3, CASE WHEN CAST(PKG_COMMON.PKG_COMMON.fn_snow_helper26_common(LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0')).ssn_status AS VARCHAR2(4000)) = 'Invalid' THEN 'Invalid_SSN' ELSE NULL END AS __w4, p_src_sys AS __w5, p_cv_ind AS __w6, LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0') AS __w7
)
UNION ALL
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID(PKEY_SRC_OBJECT_PTY => __w0, PERIOD_START_DATE => __w1, ALT_ID_VAL => __w2, ALT_ID_TYP => __w3, DQ_EXCP_CD => __w4, SRC_SYS => __w5, CV_IND => __w6, ORIGINAL_SSN => __w7) FROM (
SELECT p_pkey_src_object_pty AS __w0, p_period_start_date AS __w1, p_alt_id_val_member_id AS __w2, '007' AS __w3, CAST(PKG_COMMON.PKG_COMMON.fn_snow_helper28_common(p_alt_id_val_member_id).exception_code AS VARCHAR2(4000)) AS __w4, p_src_sys AS __w5, p_cv_ind AS __w6, LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0') AS __w7
)
UNION ALL
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_ALT_ID(PKEY_SRC_OBJECT_PTY => __w0, PERIOD_START_DATE => __w1, ALT_ID_VAL => __w2, ALT_ID_TYP => __w3, DQ_EXCP_CD => __w4, SRC_SYS => __w5, CV_IND => __w6, ORIGINAL_SSN => __w7) FROM (
SELECT p_pkey_src_object_pty AS __w0, p_period_start_date AS __w1, p_alt_id_val_ns_client_id AS __w2, '009' AS __w3, NULL AS __w4, p_src_sys AS __w5, p_cv_ind AS __w6, LPAD(TO_CHAR(p_alt_id_val_ssn_num), 9, '0') AS __w7
)
);
    RETURN l_tab;
    END fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id;


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
    p_phn_num_tertiary IN VARCHAR2) RETURN T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR IS

    l_tab T_TAB_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR(PERIOD_START_DATE => __w0, PTY_FK => __w1, PREF_LVL => __w2, USG_TP => __w3, PHN_TP => __w4, PHN_NUM_IN => __w5, SRC_SYS => __w6, CASE_NUMBER => __w7) FROM (
SELECT p_period_start_date AS __w0, p_pty_fk AS __w1, 'Primary' AS __w2, p_usg_tp_primary AS __w3, p_phn_tp_primary AS __w4, p_phn_num_primary AS __w5, p_src_sys AS __w6, p_case_number AS __w7
)
UNION ALL
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR(PERIOD_START_DATE => __w0, PTY_FK => __w1, PREF_LVL => __w2, USG_TP => __w3, PHN_TP => __w4, PHN_NUM_IN => __w5, SRC_SYS => __w6, CASE_NUMBER => __w7) FROM (
SELECT p_period_start_date AS __w0, p_pty_fk AS __w1, 'Secondary' AS __w2, p_usg_tp_secondary AS __w3, p_phn_tp_secondary AS __w4, p_phn_num_secondary AS __w5, p_src_sys AS __w6, p_case_number AS __w7
)
UNION ALL
SELECT T_OBJ_FN_SNOW_HELPER01_M_TGT_C_S_TRS_PTY_RLE_PHN_AND_EADDR(PERIOD_START_DATE => __w0, PTY_FK => __w1, PREF_LVL => __w2, USG_TP => __w3, PHN_TP => __w4, PHN_NUM_IN => __w5, SRC_SYS => __w6, CASE_NUMBER => __w7) FROM (
SELECT p_period_start_date AS __w0, p_pty_fk AS __w1, 'Tertiary' AS __w2, p_usg_tp_tertiary AS __w3, p_phn_tp_tertiary AS __w4, p_phn_num_tertiary AS __w5, p_src_sys AS __w6, p_case_number AS __w7
)
);
    RETURN l_tab;
    END fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr;

END PKG_TRS_ONGOING;
/
