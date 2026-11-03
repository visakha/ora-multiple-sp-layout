-- CRE discrete procedures, packaged (ORA-multiple-SP-layout).
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_CRE AS

    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_routed() RETURN VARCHAR2 IS

    l_run_ts TIMESTAMP := CAST(SYSTIMESTAMP AS TIMESTAMP);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_ROUTED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_ROUTED AS WITH src AS (
            SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
                   CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
                   CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, CLIENTS.MAINT_FLAG, CLIENTS.SSN,
                   CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, CAST(NULL AS VARCHAR2(4000)) AS SOURCE_ID,
                   CAST(NULL AS VARCHAR2(4000)) AS TARGET_ID, CAST(NULL AS VARCHAR2(4000)) AS REC, 'I' AS REC_TYPE
              FROM STG_CRE_D_CARE_CLIENTS CLIENTS
             WHERE CLIENTS.MAINT_FLAG IS NULL
            UNION ALL
            SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
                   CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
                   CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, DELTAS.MAINT_FLAG, CLIENTS.SSN,
                   CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, MAINT.SOURCE_ID, MAINT.TARGET_ID, MAINT.REC,
                   DECODE(MAINT.REC, 'CASEMOV', 'B', 'D')
              FROM STG_CRE_D_CARE_CLIENTS DELTAS
              LEFT JOIN STG_CRE_SN_CARE_CLIENTS CLIENTS
                ON DELTAS.CARE_ID = CLIENTS.CARE_ID
              JOIN STG_CRE_D_CARE_CASE_MAINT MAINT
                ON CLIENTS.CARE_ID = MAINT.SOURCE_ID
               AND DELTAS.MAINT_FLAG = 'D'
               AND MAINT.REC IN ('CASEMOV', 'CASEDEL')
            UNION ALL
            SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
                   CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
                   CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, CLIENTS.MAINT_FLAG, CLIENTS.SSN,
                   CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, MAINT.SOURCE_ID, MAINT.TARGET_ID, MAINT.REC,
                   'A' AS REC_TYPE
              FROM STG_CRE_SN_CARE_CLIENTS CLIENTS
              JOIN STG_CRE_D_CARE_CASE_MAINT MAINT
                ON CLIENTS.CARE_ID = MAINT.TARGET_ID
               AND MAINT.REC = 'CASEMOV'
        ), xref AS (
            SELECT PKEY_SRC_OBJECT, ROWID_OBJECT, ORIG_ROWID_OBJECT FROM (SELECT x.PKEY_SRC_OBJECT, RTRIM(x.ROWID_OBJECT) AS ROWID_OBJECT, RTRIM(x.ORIG_ROWID_OBJECT) AS ORIG_ROWID_OBJECT, ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.ROWID_XREF) AS __qual_rn FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'CRE'
           ) WHERE __qual_rn = 1
        ), hmrg_src AS (SELECT DISTINCT RTRIM(SRC_ROWID_OBJECT) AS ROWID_OBJECT FROM C_B_PTY_HMRG
                      WHERE SRC_ROWID_OBJECT IS NOT NULL), hmrg_tgt AS (SELECT DISTINCT RTRIM(TGT_ROWID_OBJECT) AS ROWID_OBJECT FROM C_B_PTY_HMRG
                      WHERE TGT_ROWID_OBJECT IS NOT NULL) 
            SELECT s.*,
                   NVL(s.MAINT_FLAG IS NULL OR (s.MAINT_FLAG = 'D' AND s.REC = 'CASEDEL'), 0) AS grp_deletes,
                   xs.ROWID_OBJECT AS src_rowid_object,
                   xt.ROWID_OBJECT AS tgt_rowid_object,CASE WHEN h1.ROWID_OBJECT IS NULL AND h2.ROWID_OBJECT IS NULL AND h3.ROWID_OBJECT IS NULL
                    AND h4.ROWID_OBJECT IS NULL THEN 1 WHEN NOT (h1.ROWID_OBJECT IS NULL AND h2.ROWID_OBJECT IS NULL AND h3.ROWID_OBJECT IS NULL
                    AND h4.ROWID_OBJECT IS NULL) THEN 0 END AS no_merge_history
              , :1 AS run_ts FROM src s
              LEFT JOIN xref xs ON xs.PKEY_SRC_OBJECT = s.SOURCE_ID
              LEFT JOIN xref xt ON xt.PKEY_SRC_OBJECT = s.TARGET_ID
              LEFT JOIN hmrg_src h1 ON h1.ROWID_OBJECT = xs.ORIG_ROWID_OBJECT
              LEFT JOIN hmrg_tgt h2 ON h2.ROWID_OBJECT = xs.ORIG_ROWID_OBJECT
              LEFT JOIN hmrg_src h3 ON h3.ROWID_OBJECT = xt.ORIG_ROWID_OBJECT
              LEFT JOIN hmrg_tgt h4 ON h4.ROWID_OBJECT = xt.ORIG_ROWID_OBJECT
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_routed;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_named() RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_NAMED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_NAMED AS WITH lkp_junk AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper43_common())), lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())) 
            SELECT r.*,
                   CASE WHEN (r.grp_deletes = 1) THEN NULL ELSE CASE WHEN (r.no_merge_history = 1) THEN 'N' ELSE 'Y' END END            AS orig_rowid_object_desc,
                   PKG_COMMON.fn_snow_helper15_common(r.FIRSTNM, NULL, r.LASTNM, NULL, NULL, r.LAST_SUF, NULL,
                                           sf.MSTR_CODE_VALUE, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
              FROM WRK_CRE_ROUTED r
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(r.FIRSTNM)) AND (jf.IS_FIRST_JUNK = 1)
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(r.LASTNM)) AND (jl.IS_LAST_JUNK = 1)
              LEFT JOIN lkp_cv sf ON sf.CODE_TYPE = 'SUFFIX' AND sf.SRC_SYS = 'CRE' AND sf.SRC_CODE_VALUE = r.LAST_SUF
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_named;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_members() RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_MEMBERS';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_MEMBERS AS 
            SELECT n.*,
                   CAST(n.nm.first_name AS VARCHAR2(4000))                                                AS std_first_name,
                   CAST(n.nm.last_name AS VARCHAR2(4000))                                                 AS std_lst_name,
                   CAST(n.nm.full_name AS VARCHAR2(4000))                                                 AS std_full_name,
                   CAST(n.nm.src_full_name AS VARCHAR2(4000))                                             AS std_src_full_name,
                   CAST(n.nm.sfx_name AS VARCHAR2(4000))                                                  AS std_sfx_name,
                   CAST(n.nm.src_suffix AS VARCHAR2(4000))                                                AS src_suffix,
                   CAST(n.nm.suffix_exception_code AS VARCHAR2(4000))                                     AS suffix_exception_code,
                   /* VALIDATION */
                   NVL(LENGTH(TRIM(CAST(n.nm.first_name AS VARCHAR2(4000)))) > 0 AND LENGTH(TRIM(CAST(n.nm.last_name AS VARCHAR2(4000)))) > 0,
                       0)                                                              AS valid_member,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.first_name AS VARCHAR2(4000))) = 1) THEN 'Missing_First_Name' ELSE NULL END AS fn_missing_code,
                   CASE WHEN (PKG_COMMON.fn_snow_helper03_common(CAST(n.nm.last_name AS VARCHAR2(4000))) = 1) THEN 'Missing_Last_Name' ELSE NULL END   AS ln_missing_code,CASE WHEN n.REC_TYPE IN ('B', 'D') THEN 1 WHEN NOT (n.REC_TYPE IN ('B', 'D')) THEN 0 END AS end_dated
              FROM WRK_CRE_NAMED n
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_members;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_ranked() RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_RANKED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_RANKED AS WITH lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())), lkp_any AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper42_common())) 
            SELECT m.*,
                   /* TIMELINE: VERSION_SEQ_NUM per CARE id, REC_TYPE descending */
                   CASE WHEN (m.valid_member = 1) THEN ROW_NUMBER() OVER (PARTITION BY m.valid_member, m.CARE_ID ORDER BY m.REC_TYPE DESC) ELSE NULL END
                                                                                           AS version_seq_num,
                   xf.EXCEPTION_CODE AS fn_exception_code, xf.EXCEPTION_DESC AS fn_exception_desc,
                   xf.EXCEPTION_TYPE AS fn_exception_type,
                   xl.EXCEPTION_CODE AS ln_exception_code, xl.EXCEPTION_DESC AS ln_exception_desc,
                   xl.EXCEPTION_TYPE AS ln_exception_type,
                   CASE WHEN m.orig_rowid_object_desc = 'N' THEN m.TARGET_ID ELSE m.CARE_ID END             AS mrg_care_id,
                   /* BAD DATA: SSN_OUT suppresses the default values */
                   CASE WHEN m.SSN = 'U' ORCASE WHEN m.SSN = 'N' THEN NULL ELSE m.SSN END THEN 1 WHEN NOT (m.SSN = 'N' THEN NULL ELSE m.SSN END) THEN 0 END AS ssn_out,
                   st.MSTR_CODE_VALUE                                                      AS std_state_cd
              FROM WRK_CRE_MEMBERS m
              LEFT JOIN lkp_exc xf ON xf.EXCEPTION_CODE = m.fn_missing_code
              LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = m.ln_missing_code
              LEFT JOIN lkp_any st ON st.SRC_SYS = 'CRE' AND st.SRC_CODE_VALUE = m.STATE
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_ranked;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq() RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_DQ';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_DQ AS WITH lkp_cv AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper41_common())) 
            SELECT r.*,
                   NVL(r.version_seq_num = 1, 0)                                       AS is_member,
                   PKG_COMMON.fn_snow_helper17_common(r.SEX, 'Indv', 'CRE')                           AS gd,
                   et.MSTR_CODE_VALUE                                                      AS ethnicity_mstr,
                   rc.MSTR_CODE_VALUE                                                      AS race_mstr,
                   PKG_COMMON.fn_snow_helper23_common(r.PHONE)                                        AS phone_std,
                   PKG_COMMON.fn_snow_helper37_common(r.mrg_care_id)                                  AS ci,
                   PKG_COMMON.fn_snow_helper27_common(r.RECIP_NO)                                     AS md,
                   PKG_COMMON.fn_snow_helper26_common(r.ssn_out)                                      AS sn,CASE WHEN /* RTR_US_ADDRESSES.US_ADDRESSES: STD_STATE_CD <> '99' OR ISNULL(STD_STATE_CD) */
                   NVL(r.std_state_cd <> '99', 1) THEN 1 WHEN NOT (/* RTR_US_ADDRESSES.US_ADDRESSES: STD_STATE_CD <> '99' OR ISNULL(STD_STATE_CD) */
                   NVL(r.std_state_cd <> '99', 1)) THEN 0 END AS addr_us,
                   ss.MSTR_CODE_VALUE                                                      AS source_state_fips
              FROM WRK_CRE_RANKED r
              LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'CRE' AND et.SRC_CODE_VALUE = r.FEDETH
              LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = 'RACE' AND rc.SRC_SYS = 'CRE' AND rc.SRC_CODE_VALUE = r.RACE
              LEFT JOIN lkp_cv ss ON ss.CODE_TYPE = 'STATE' AND ss.SRC_SYS = 'CRE'
                                 AND ss.SRC_CODE_VALUE = UPPER(TRIM(r.STATE))
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq2() RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_DQ2';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_DQ2 AS WITH lkp_area AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper44_common())) 
            SELECT d.*,
                   CASE WHEN (d.addr_us = 1) THEN PKG_COMMON.fn_snow_helper34_common(d.STREET, NULL, d.CITY, d.STATE,
                                                          NVL(d.ZIP, '') || '-' || NVL(d.ZIPSUF, ''), 'US',
                                                          d.source_state_fips) ELSE NULL END AS av,
                   /* VALIDATION */
                   PKG_COMMON.fn_snow_helper24_common(d.phone_std, NULL, NULL, ar.NPA_ID, ar.SERVICE)  AS phone_code
              FROM WRK_CRE_DQ d
              LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(d.phone_std, 1, 3)
        ]';
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq2;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_flat(P_RLE_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Member',
    P_DEFAULT_NONUS_STATE_CD IN VARCHAR2 DEFAULT '99') RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_FLAT';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_FLAT AS WITH lkp_exc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper40_common())), lkp_mc AS (SELECT * FROM TABLE(PKG_COMMON.fn_snow_helper46_common())), alt_tp AS (
            SELECT SRC_CODE_VALUE, MSTR_REF_CODE, MSTR_REF_LABEL, SRC_SYS FROM (SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE, l.MSTR_REF_LABEL, l.SRC_SYS, ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.CODE_TYPE) AS __qual_rn FROM LOOKUP_CODE_VALUE l
             WHERE l.SRC_SYS = 'CRE' AND l.SRC_CODE_VALUE IN ('CARE ID', 'Medicaid ID', 'SSN')
           ) WHERE __qual_rn = 1
        ) 
            SELECT d.*,
                   d.CARE_ID                                                               AS pty_key,
                   NVL(d.CARE_ID, '') || '|' || :1                  AS rle_key,
                   NVL(d.CARE_ID, '') || '|Member'                                         AS member_rle_fk,
                   /* TIMELINE: EXP_VALID_MEMBERS, EXP_PTY_HOLD / EXP_PTY_RLE_HOLD */
                   CASE WHEN (d.end_dated = 1) THEN ((d.CARE_LASTUP_DT) + (-1)) ELSE d.CARE_LASTUP_DT END  AS period_start,
                   CASE WHEN (d.end_dated = 1) THEN d.CARE_LASTUP_DT ELSE NULL END                                AS period_end,
                   CASE WHEN (d.end_dated = 1) THEN 2 ELSE NULL END                                               AS timeline_action,
                   CASE WHEN (d.end_dated = 1) THEN ((d.CARE_LASTUP_DT) + (-1)) ELSE NULL END              AS period_reference_time,
                   CASE WHEN (d.end_dated = 1) THEN ((l_run_ts) + (-1)/24) ELSE l_run_ts END               AS last_update,
                   CASE WHEN (d.end_dated = 1) THEN ((((d.CARE_LASTUP_DT) + (-1))) + (1)) ELSE NULL END AS pty_period_end,
                   CASE WHEN (d.end_dated = 1) THEN ((d.CARE_LASTUP_DT) + (-1)) ELSE NULL END              AS pty_period_reference_time,
                   NVL(d.CARE_LASTUP_DT, d.INSERT_DATE)                                    AS src_last_update,
                   CAST(d.gd.mdm_gender_code AS VARCHAR2(4000))                                           AS mdm_gender_code,
                   CAST(d.gd.exception_code AS VARCHAR2(4000))                                            AS gender_exception_code,
                   xg.EXCEPTION_DESC                                                       AS gender_exception_description,
                   xg.EXCEPTION_TYPE                                                       AS gender_exception_type,
                   xs.EXCEPTION_DESC                                                       AS suffix_exception_desc,
                   xs.EXCEPTION_TYPE                                                       AS suffix_exception_type,
                   xe.EXCEPTION_CODE AS ethnicity_exception_code, xe.EXCEPTION_DESC AS ethnicity_exception_desc,
                   xe.EXCEPTION_TYPE AS ethnicity_exception_type,
                   xr.EXCEPTION_CODE AS race_exception_code, xr.EXCEPTION_DESC AS race_exception_desc,
                   xr.EXCEPTION_TYPE AS race_exception_type,
                   xp.EXCEPTION_CODE AS phone_exception_code, xp.EXCEPTION_DESC AS phone_exception_desc,
                   xp.EXCEPTION_TYPE AS phone_exception_type,
                   NVL(d.CARE_ID, '') || '|Member|Telephone|001|' || NVL(d.phone_std, '')  AS phn_key,
                   /* VALIDATION: RTR_VALID_ADDRESS / RTR_VALID_NON_US_ADDRESSES */
                   CASE WHEN (d.addr_us = 1) THEN NVL((TRUNC(TO_NUMBER(CAST(d.av.mailability_score AS VARCHAR2(4000)) DEFAULT NULL ON CONVERSION ERROR)) >= 3
                            OR SUBSTR(CAST(d.av.match_code AS VARCHAR2(4000)), 1, 1) NOT IN ('I', 'N'))
                           AND CAST(d.av.state_fips_cd AS VARCHAR2(4000)) IS NOT NULL, 0) ELSE CASE WHEN d.CITY IS NOT NULL ANDCASE WHEN d.STREET IS NOT NULL THEN 1 WHEN NOT (d.CITY IS NOT NULL AND d.STREET IS NOT NULL) THEN 0 END END THEN 1 WHEN NOT (d.STREET IS NOT NULL THEN 1 WHEN NOT (d.CITY IS NOT NULL AND d.STREET IS NOT NULL) THEN 0 END END) THEN 0 END AS addr_valid,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.delivery_address_line1 AS VARCHAR2(4000)) ELSE INITCAP(d.STREET) END AS a_line1,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.delivery_address_line2 AS VARCHAR2(4000)) ELSE NULL END             AS a_line2,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.city AS VARCHAR2(4000)) ELSE INITCAP(d.CITY) END                    AS a_city,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.state_fips_cd AS VARCHAR2(4000)) ELSE :2 END AS a_state,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.county_fips_cd AS VARCHAR2(4000)) ELSE d.CNTY END                   AS a_county_fips,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.country_iso2_char AS VARCHAR2(4000)) ELSE 'ZZ' END                  AS a_country,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.zip_cd_5 AS VARCHAR2(4000)) ELSE d.ZIP END                          AS a_postcode,
                   CASE WHEN (d.addr_us = 1) THEN CAST(d.av.zip_cd_4_extn AS VARCHAR2(4000)) ELSE d.ZIPSUF END                  AS a_postcode_ext,
                   CAST(d.av.geocoding_latitude AS NUMBER(38, 6))                                  AS a_latitude,
                   CAST(d.av.geocoding_longitude AS NUMBER(38, 6))                                 AS a_longitude,
                   CAST(d.av.mailability_score AS VARCHAR2(4000))                                         AS a_mailability_score,
                   CAST(d.av.match_code AS VARCHAR2(4000))                                                AS a_match_code,
                   CAST(d.av.address_type AS VARCHAR2(4000))                                              AS a_address_type,
                   CAST(d.av.sub_building_number AS VARCHAR2(4000))                                       AS a_sub_building_number,
                   CAST(d.av.sub_building_descriptor AS VARCHAR2(4000))                                   AS a_sub_building_descriptor,
                   CAST(d.av.sub_building_complete AS VARCHAR2(4000))                                     AS a_sub_building_complete,
                   CAST(d.av.building_number AS VARCHAR2(4000))                                           AS a_building_number,
                   CAST(d.av.building_name AS VARCHAR2(4000))                                             AS a_building_name,
                   CAST(d.av.residential_delivery_indicator AS VARCHAR2(4000))                            AS a_residential,
                   CAST(d.av.geocoding_status AS VARCHAR2(4000))                                          AS a_geocoding_status,
                   CAST(d.av.organization_name AS VARCHAR2(4000))                                         AS a_org_name,
                   CAST(d.av.organization_descriptor AS VARCHAR2(4000))                                   AS a_org_descriptor,
                   TO_NUMBER(CAST(d.av.mailability_score AS VARCHAR2(4000)) DEFAULT NULL ON CONVERSION ERROR)                          AS a_dr_mailability_score,
                   mc.DESCRIPTION                                                          AS a_dr_error_desc,
                   CAST(d.av.match_code AS VARCHAR2(4000))                                                AS a_dr_error_code,
                   NVL(d.STREET, '') || ' ' || '' || ' ' || NVL(d.CITY, '') || ' ' || NVL(d.STATE, '') || ' '
                   || NVL(d.ZIP, '')                                                       AS addr_attribute_value,
                   xa.EXCEPTION_CODE AS addr_exception_code, xa.EXCEPTION_DESC AS addr_exception_desc,
                   xa.EXCEPTION_TYPE AS addr_exception_type,
                   -- NRML_ALT_ID occurrences and lkp_ALT_ID_MSTR_REF_CODE
                   CAST(d.ci.id_value AS VARCHAR2(4000))                                                  AS care_alt_id,
                   t1.MSTR_REF_CODE                                                        AS care_tp_cd,
                   CAST(d.md.id_value AS VARCHAR2(4000))                                                  AS medicaid_alt_id,
                   CAST(d.md.exception_code AS VARCHAR2(4000))                                            AS medicaid_exception_code,
                   xm.EXCEPTION_DESC AS medicaid_exception_desc, xm.EXCEPTION_TYPE AS medicaid_exception_type,
                   t2.MSTR_REF_CODE AS medicaid_tp_cd, t2.MSTR_REF_LABEL AS medicaid_tp_lbl,
                   t2.SRC_SYS AS medicaid_tp_sys,
                   /* VALIDATION: exp_validate_ssn + Lkp_EXC_LOOKUP_CODE_VALUE_SSN (looked-up code) */
                   xn.EXCEPTION_CODE AS ssn_exception_code, xn.EXCEPTION_DESC AS ssn_exception_desc,
                   xn.EXCEPTION_TYPE AS ssn_exception_type,
                   t3.MSTR_REF_CODE AS ssn_tp_cd, t3.MSTR_REF_LABEL AS ssn_tp_lbl, t3.SRC_SYS AS ssn_tp_sys
              FROM WRK_CRE_DQ2 d
              LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = CAST(d.gd.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.suffix_exception_code
              LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
              LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = PKG_COMMON.fn_snow_helper18_common(d.race_mstr, 'Invalid_Race')
              LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = d.phone_code
              LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = CAST(d.md.exception_code AS VARCHAR2(4000))
              LEFT JOIN lkp_exc xn ON xn.EXCEPTION_CODE = CASE WHEN CAST(d.sn.ssn_status AS VARCHAR2(4000)) = 'Invalid'
                                                              AND d.ssn_out IS NOT NULL THEN 'Invalid_SSN' ELSE NULL END
              LEFT JOIN lkp_exc xa ON xa.EXCEPTION_CODE = 'Invalid_Address'
              LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = CAST(d.av.match_code AS VARCHAR2(4000))
              LEFT JOIN alt_tp t1 ON t1.SRC_CODE_VALUE = 'CARE ID'
              LEFT JOIN alt_tp t2 ON t2.SRC_CODE_VALUE = 'Medicaid ID'
              LEFT JOIN alt_tp t3 ON t3.SRC_CODE_VALUE = 'SSN'
        ]' USING P_RLE_BO_CLASS_CD_MEMBER, P_DEFAULT_NONUS_STATE_CD;
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_flat;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_keyed(P_PHYSICAL_ADDR_TYPE_CD IN VARCHAR2 DEFAULT '002',
    P_DEFAULT_TX_STATE_CD IN VARCHAR2 DEFAULT '48',
    P_COUNTY_CD_NONTX IN VARCHAR2 DEFAULT '996',
    P_COUNTYCD_DEFAULTALL IN VARCHAR2 DEFAULT '998',
    P_RLE_BO_CLASS_CD_MEMBER IN VARCHAR2 DEFAULT 'Member') RETURN VARCHAR2 IS

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE WRK_CRE_KEYED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
    END;
    EXECUTE IMMEDIATE q'[CREATE TABLE WRK_CRE_KEYED AS SELECT k.*,
               'CRE'                                             AS src_sys,
               l_run_ts                                         AS run_ts,
               c_mapping                                        AS mapping_name,
               'Indv'                                            AS pty_bo_class_cd,
               :5                         AS rle_bo_class_cd,
               :1                          AS addr_tp,
               'Payer'                                           AS hierarchy_code,
               'Primary'                                         AS pref_lvl,
               'Member Addr'                                     AS hm_rel_tp_cd,
               'US'                                              AS src_cntry,
               'Telephone'                                       AS phn_tp,
               '001'                                             AS usg_tp_phone,
               'Issued'                                          AS sts_cd,
               'First Name'                                      AS attr_first_name,
               'Last Name'                                       AS attr_last_name,
               'Gender'                                          AS attr_gender,
               'Name Suffix'                                     AS attr_suffix,
               'FEDETH'                                          AS attr_fedeth,
               'RACE'                                            AS attr_race,
               'Address'                                         AS attr_address,
               'Telephone'                                       AS attr_phone,
               CAST(NULL AS TIMESTAMP)                       AS null_timestamp,   -- TIMELINE: not linked
               CAST(NULL AS NUMBER)                              AS null_number,      -- TIMELINE: not linked
               /* BAD DATA: SRC_ROWID is 30 characters */
               SUBSTR(k.addr_key, 1, 30)                              AS addr_src_rowid,
               SUBSTR(k.phn_key, 1, 30)                               AS phn_src_rowid,
               SUBSTR(k.care_alt_key, 1, 30)                          AS care_alt_src_rowid,
               SUBSTR(k.medicaid_alt_key, 1, 30)                      AS medicaid_alt_src_rowid,
               SUBSTR(k.ssn_alt_key, 1, 30)                           AS ssn_alt_src_rowid,CASE WHEN /* BAD DATA: unique keys Snowflake does not enforce */
               ROW_NUMBER() OVER (PARTITION BY k.grp_first_name, k.CARE_ID, k.fn_exception_type, k.fn_exception_code
                                  ORDER BY k.REC_TYPE DESC) = 1 THEN 1 WHEN NOT (/* BAD DATA: unique keys Snowflake does not enforce */
               ROW_NUMBER() OVER (PARTITION BY k.grp_first_name, k.CARE_ID, k.fn_exception_type, k.fn_exception_code
                                  ORDER BY k.REC_TYPE DESC) = 1) THEN 0 END AS uq_first_name,CASE WHEN ROW_NUMBER() OVER (PARTITION BY k.grp_last_name, k.CARE_ID, k.ln_exception_type, k.ln_exception_code
                                  ORDER BY k.REC_TYPE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY k.grp_last_name, k.CARE_ID, k.ln_exception_type, k.ln_exception_code
                                  ORDER BY k.REC_TYPE DESC) = 1) THEN 0 END AS uq_last_name,CASE WHEN xpty.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xpty.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_pty,CASE WHEN xrle.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xrle.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_rle,CASE WHEN xadr.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xadr.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_addr,CASE WHEN xphn.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xphn.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_phone,CASE WHEN xca.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xca.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_care_alt,CASE WHEN xma.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xma.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_medicaid_alt,CASE WHEN xsa.PKEY_SRC_OBJECT IS NULL THEN 1 WHEN NOT (xsa.PKEY_SRC_OBJECT IS NULL) THEN 0 END AS uq_ssn_alt,CASE WHEN ROW_NUMBER() OVER (PARTITION BY k.grp_medicaid_exc, k.mrg_care_id, k.medicaid_exception_type,
                                               k.medicaid_exception_code ORDER BY k.REC_TYPE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY k.grp_medicaid_exc, k.mrg_care_id, k.medicaid_exception_type,
                                               k.medicaid_exception_code ORDER BY k.REC_TYPE DESC) = 1) THEN 0 END AS uq_medicaid_exc,CASE WHEN ROW_NUMBER() OVER (PARTITION BY k.grp_ssn_exc, k.mrg_care_id, k.ssn_exception_type,
                                               k.ssn_exception_code ORDER BY k.REC_TYPE DESC) = 1 THEN 1 WHEN NOT (ROW_NUMBER() OVER (PARTITION BY k.grp_ssn_exc, k.mrg_care_id, k.ssn_exception_type,
                                               k.ssn_exception_code ORDER BY k.REC_TYPE DESC) = 1) THEN 0 END AS uq_ssn_exc FROM (
            SELECT f.*,
                   /* EXP_PTY_RLE_ADDR_HOLD.out_COUNTY_CD */
                   CASE WHEN f.a_state <> :2 THEN :3
                        WHEN f.a_county_fips IS NULL THEN :4
                        ELSE f.a_county_fips END                                           AS a_county,
                   f.rle_key || '|' || :1                            AS addr_key,
                   CASE WHEN f.care_alt_id IN ('U', 'N') THEN NULL ELSE f.care_alt_id END                   AS care_alt_val,
                   CASE WHEN f.medicaid_alt_id IN ('U', 'N') THEN NULL ELSE f.medicaid_alt_id END           AS medicaid_alt_val,
                   f.rle_key || '|' || NVL(f.care_tp_cd, '') || '|' || NVL(f.care_alt_id, '')         AS care_alt_key,
                   f.rle_key || '|' || NVL(f.medicaid_tp_cd, '') || '|' || NVL(f.medicaid_alt_id, '') AS medicaid_alt_key,
                   f.rle_key || '|' || NVL(f.ssn_tp_cd, '') || '|' || NVL(f.ssn_out, '')              AS ssn_alt_key,
                   /* routes (every flag NVL'd: a NULL router condition does not route) */
                   NOT (f.grp_deletes = 1) AND NVL(f.orig_rowid_object_desc = 'N', 0)        AS grp_mrg,
                   NOT f.valid_member ANDCASE WHEN f.fn_exception_code IS NOT NULL OR f.fn_exception_desc IS NOT NULL
                                           OR f.fn_exception_type IS NOT NULL THEN 1 WHEN NOT (f.fn_exception_code IS NOT NULL OR f.fn_exception_desc IS NOT NULL
                                           OR f.fn_exception_type IS NOT NULL) THEN 0 END AS grp_first_name,
                   NOT f.valid_member ANDCASE WHEN f.ln_exception_code IS NOT NULL OR f.ln_exception_desc IS NOT NULL
                                           OR f.ln_exception_type IS NOT NULL THEN 1 WHEN NOT (f.ln_exception_code IS NOT NULL OR f.ln_exception_desc IS NOT NULL
                                           OR f.ln_exception_type IS NOT NULL) THEN 0 END AS grp_last_name,
                   f.is_member ANDCASE WHEN f.gender_exception_description IS NOT NULL THEN 1 WHEN NOT (f.gender_exception_description IS NOT NULL) THEN 0 END AS grp_gender,
                   f.is_member ANDCASE WHEN f.suffix_exception_code IS NOT NULL THEN 1 WHEN NOT (f.suffix_exception_code IS NOT NULL) THEN 0 END AS grp_suffix,
                   f.is_member ANDCASE WHEN f.ethnicity_exception_code IS NOT NULL THEN 1 WHEN NOT (f.ethnicity_exception_code IS NOT NULL) THEN 0 END AS grp_ethnicity,
                   f.is_member ANDCASE WHEN f.race_exception_code IS NOT NULL THEN 1 WHEN NOT (f.race_exception_code IS NOT NULL) THEN 0 END AS grp_race,
                   f.is_member ANDCASE WHEN f.addr_valid = 1 THEN 1 WHEN NOT (f.addr_valid = 1) THEN 0 END AS grp_addr,
                   f.is_member ANDCASE WHEN NOT (f.addr_valid = 1) THEN 1 WHEN NOT (NOT (f.addr_valid = 1)) THEN 0 END AS grp_addr_exc,
                   f.is_member AND f.PHONE IS NOT NULL ANDCASE WHEN f.phone_exception_code IS NULL THEN 1 WHEN NOT (f.phone_exception_code IS NULL) THEN 0 END AS grp_phone,
                   f.is_member AND f.PHONE IS NOT NULL ANDCASE WHEN f.phone_exception_code IS NOT NULL THEN 1 WHEN NOT (f.phone_exception_code IS NOT NULL) THEN 0 END AS grp_phone_exc,
                   f.is_member ANDCASE WHEN f.care_alt_id IS NOT NULL THEN 1 WHEN NOT (f.care_alt_id IS NOT NULL) THEN 0 END AS grp_care_alt,
                   f.is_member AND f.medicaid_alt_id IS NOT NULL ANDCASE WHEN f.medicaid_exception_code IS NULL THEN 1 WHEN NOT (f.medicaid_exception_code IS NULL) THEN 0 END AS grp_medicaid_alt,
                   f.is_member AND f.medicaid_alt_id IS NOT NULL ANDCASE WHEN f.medicaid_exception_code IS NOT NULL THEN 1 WHEN NOT (f.medicaid_exception_code IS NOT NULL) THEN 0 END AS grp_medicaid_exc,
                   f.is_member AND f.ssn_out IS NOT NULL ANDCASE WHEN f.ssn_exception_code IS NULL THEN 1 WHEN NOT (f.ssn_exception_code IS NULL) THEN 0 END AS grp_ssn_alt,
                   f.is_member AND f.ssn_out IS NOT NULL ANDCASE WHEN f.ssn_exception_code IS NOT NULL THEN 1 WHEN NOT (f.ssn_exception_code IS NOT NULL) THEN 0 END AS grp_ssn_exc
              FROM WRK_CRE_FLAT f
        ) k LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY WHERE VERSION_SEQ = 1) xpty
                 ON xpty.PKEY_SRC_OBJECT = k.pty_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE WHERE VERSION_SEQ = 1) xrle
                 ON xrle.PKEY_SRC_OBJECT = k.rle_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xadr
                 ON xadr.PKEY_SRC_OBJECT = k.addr_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xphn
                 ON xphn.PKEY_SRC_OBJECT = k.phn_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xca
                 ON xca.PKEY_SRC_OBJECT = k.care_alt_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xma
                 ON xma.PKEY_SRC_OBJECT = k.medicaid_alt_key
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xsa
                 ON xsa.PKEY_SRC_OBJECT = k.ssn_alt_key]' USING P_PHYSICAL_ADDR_TYPE_CD, P_DEFAULT_TX_STATE_CD, P_COUNTY_CD_NONTX, P_COUNTYCD_DEFAULTALL, P_RLE_BO_CLASS_CD_MEMBER;
    RETURN 'OK';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_keyed;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_mrg() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO CRE_SRC_MRG (SRC_ROWID_OBJECT, TGT_ROWID_OBJECT, RUN_DATE)
    SELECT src_rowid_object, tgt_rowid_object, run_ts
      FROM WRK_CRE_KEYED
     WHERE (grp_mrg = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into CRE_SRC_MRG';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_mrg;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_fname() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS_ID_1, RUN_DATE, MAPPING_NAME, FIRST_NAME, LAST_NAME, ATTRIBUTE_NAME, GENDER, BIRTH_DATE,
                  SUFFIX, SRC_SYS, ATTRIBUTE_VALUE, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE)
    SELECT CARE_ID, run_ts, mapping_name, std_first_name, std_lst_name, attr_first_name, SEX, BIRTH_DT,
                    std_sfx_name, src_sys, FIRSTNM, fn_exception_type, fn_exception_desc, fn_exception_code
      FROM WRK_CRE_KEYED
     WHERE (grp_first_name = 1) AND (uq_first_name = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_fname;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_lname() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, FIRST_NAME, MAPPING_NAME, BIRTH_DATE, GENDER, ADDRESS_LINE_1,
                  ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ATTRIBUTE_NAME, LAST_NAME,
                  SUFFIX, ATTRIBUTE_VALUE, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, CARE_ID, run_ts, std_first_name, mapping_name, BIRTH_DT, SEX, STREET, CITY, CNTY, STATE,
                    ZIP, ZIPSUF, attr_last_name, std_lst_name, std_sfx_name, LASTNM, ln_exception_code,
                    ln_exception_desc, ln_exception_type
      FROM WRK_CRE_KEYED
     WHERE (grp_last_name = 1) AND (uq_last_name = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_lname;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_pty() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME,
                  TIMELINE_ACTION, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, BIRTH_DT, FULL_NM, GNDR_CD, SFX_NM,
                  LST_NM, FRST_NM, PTY_BO_CLASS_CD, SRC_FULL_NM, SRC_LAST_UPD_DT, ETHNCTY, RACE_CD, SRC_ETHNCTY,
                  SRC_RACE_CD)
    SELECT pty_key, period_start, pty_period_end, version_seq_num, pty_period_reference_time,
                    timeline_action, last_update, last_update, pty_key, BIRTH_DT, std_full_name, mdm_gender_code,
                    std_sfx_name, std_lst_name, std_first_name, pty_bo_class_cd, std_src_full_name, src_last_update,
                    ethnicity_mstr, race_mstr, FEDETH, RACE
      FROM WRK_CRE_KEYED
     WHERE (is_member = 1) AND (uq_pty = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_pty;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_rle() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE (PTY_FK, PKEY_SRC_OBJECT, SRC_ROWID, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ,
                  LAST_UPDATE_DATE, RLE_BO_CLASS_CD, CREATE_DATE, SRC_LAST_UPD_DT, PERIOD_REFERENCE_TIME,
                  TIMELINE_ACTION)
    SELECT pty_key, rle_key, rle_key, period_start, pty_period_end, version_seq_num, run_ts,
                    rle_bo_class_cd, run_ts, src_last_update, null_timestamp, null_number
      FROM WRK_CRE_KEYED
     WHERE (is_member = 1) AND (uq_rle = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_rle;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_gender() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME,
                  EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC)
    SELECT src_sys, CARE_ID, run_ts, SEX, attr_gender, SEX, mapping_name, gender_exception_type,
                    gender_exception_code, gender_exception_description
      FROM WRK_CRE_KEYED
     WHERE (grp_gender = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_gender;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_suffix() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, ATTRIBUTE_NAME,
                  ATTRIBUTE_VALUE, MAPPING_NAME)
    SELECT src_sys, CARE_ID, suffix_exception_type, suffix_exception_code, suffix_exception_desc, run_ts,
                    attr_suffix, src_suffix, mapping_name
      FROM WRK_CRE_KEYED
     WHERE (grp_suffix = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_suffix;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ethnicity() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, EXCEPTION_CODE,
                  EXCEPTION_TYPE, EXCEPTION_DESC)
    SELECT src_sys, pty_key, run_ts, attr_fedeth, FEDETH, mapping_name, ethnicity_exception_code,
                    ethnicity_exception_type, ethnicity_exception_desc
      FROM WRK_CRE_KEYED
     WHERE (grp_ethnicity = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ethnicity;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_race() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, EXCEPTION_TYPE,
                  EXCEPTION_DESC, EXCEPTION_CODE)
    SELECT src_sys, pty_key, run_ts, attr_race, RACE, mapping_name, race_exception_type, race_exception_desc,
                    race_exception_code
      FROM WRK_CRE_KEYED
     WHERE (grp_race = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_race;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_addr() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ADDR (PKEY_SRC_OBJECT, SRC_ROWID, VERSION_SEQ, LAST_UPDATE_DATE, PERIOD_START_DATE, PERIOD_END_DATE,
                  PERIOD_REFERENCE_TIME, TIMELINE_ACTION, CREATE_DATE, HIERARCHY_CODE, PREF_LVL, ADDR_TP, HM_REL_TP_CD,
                  ADDR_LN_1, ADDR_LN_2, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT, LATTD, LNGTD, MLBLTY_SCR,
                  PTY_RLE_FK, USG_TP, SRC_ADDR_LN_1, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD,
                  SRC_PSTL_CD_EXT, SRC_LAST_UPD_DT, FLR_NUM, ADDR_TP_CD, SUB_BLDG_DESC, SUB_BLDG_NM, BLDG_NMBR,
                  BLDNG_NM, RSDNTL_DLVRY_IND, GEOCD_STS_CD, ORG_NM, ORG_DESC, VLDTN_MSG)
    SELECT addr_key, addr_src_rowid, version_seq_num, last_update, period_start, period_end,
                    period_reference_time, timeline_action, last_update, hierarchy_code, pref_lvl, addr_tp,
                    hm_rel_tp_cd, a_line1, a_line2, a_city, a_county, a_state, a_country, a_postcode, a_postcode_ext,
                    a_latitude, a_longitude, a_mailability_score, rle_key, addr_tp, STREET, CITY, CNTY, STATE,
                    src_cntry, ZIP, ZIPSUF, CARE_LASTUP_DT, a_sub_building_number, a_address_type,
                    a_sub_building_descriptor, a_sub_building_complete, a_building_number, a_building_name,
                    a_residential, a_geocoding_status, a_org_name, a_org_descriptor, a_match_code
      FROM WRK_CRE_KEYED
     WHERE (grp_addr = 1) AND (uq_addr = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE_ADDR';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_addr() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, RUN_DATE, MAPPING_NAME, ADDRESS_DR_MAILABILITY_SCORE, ADDRESS_DR_ERROR_DESC,
                  ADDRESS_DR_ERROR_CODE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, SRC_SYS_ID_1, ADDRESS_LINE_1, ADDRESS_CITY,
                  ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY, EXCEPTION_CODE,
                  EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, run_ts, mapping_name, a_dr_mailability_score, a_dr_error_desc, a_dr_error_code,
                    attr_address, addr_attribute_value, CARE_ID, STREET, CITY, CNTY, STATE, ZIP, ZIPSUF, src_cntry,
                    addr_exception_code, addr_exception_desc, addr_exception_type
      FROM WRK_CRE_KEYED
     WHERE (grp_addr_exc = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_addr;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_phn() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_PHN (PKEY_SRC_OBJECT, SRC_ROWID, PHN_NUM, VERSION_SEQ, LAST_UPDATE_DATE, PHN_TP, PTY_RLE_FK, USG_TP,
                  PREF_LVL, PERIOD_START_DATE, PERIOD_END_DATE, TIMELINE_ACTION, PERIOD_REFERENCE_TIME, CREATE_DATE,
                  SRC_LAST_UPD_DT)
    SELECT phn_key, phn_src_rowid, phone_std, version_seq_num, last_update, phn_tp, member_rle_fk,
                    usg_tp_phone, pref_lvl, period_start, period_end, timeline_action, period_reference_time,
                    last_update, CARE_LASTUP_DT
      FROM WRK_CRE_KEYED
     WHERE (grp_phone = 1) AND (uq_phone = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE_PHN';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_phn;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_phone() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (SRC_SYS, PRIMARY_PHONE, MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, SRC_SYS_ID_1,
                  EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC)
    SELECT src_sys, phone_std, mapping_name, run_ts, attr_phone, phone_std, CARE_ID, phone_exception_code,
                    phone_exception_type, phone_exception_desc
      FROM WRK_CRE_KEYED
     WHERE (grp_phone_exc = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_phone;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_care() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ALT_ID (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL,
                  ALT_ID_TP_FLTR, STS_CD, SRC_ROWID, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, PERIOD_REFERENCE_TIME,
                  TIMELINE_ACTION)
    SELECT care_alt_key, period_start, period_end, version_seq_num, rle_key, care_tp_cd, care_alt_val,
                    care_tp_cd, sts_cd, care_alt_src_rowid, CARE_LASTUP_DT, last_update, null_timestamp, null_number
      FROM WRK_CRE_KEYED
     WHERE (grp_care_alt = 1) AND (uq_care_alt = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE_ALT_ID';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_care;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_medicaid() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ALT_ID (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL,
                  ALT_ID_TP_FLTR, STS_CD, SRC_ROWID, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, PERIOD_REFERENCE_TIME,
                  TIMELINE_ACTION)
    SELECT medicaid_alt_key, period_start, period_end, version_seq_num, rle_key, medicaid_tp_cd,
                    medicaid_alt_val, medicaid_tp_cd, sts_cd, medicaid_alt_src_rowid, CARE_LASTUP_DT, last_update,
                    null_timestamp, null_number
      FROM WRK_CRE_KEYED
     WHERE (grp_medicaid_alt = 1) AND (uq_medicaid_alt = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE_ALT_ID';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_medicaid;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_medicaid() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE,
                  ATTRIBUTE_VALUE, SRC_SYS_ID_1)
    SELECT mapping_name, run_ts, medicaid_tp_lbl, medicaid_tp_sys, medicaid_exception_code,
                    medicaid_exception_desc, medicaid_exception_type, medicaid_alt_id, mrg_care_id
      FROM WRK_CRE_KEYED
     WHERE (grp_medicaid_exc = 1) AND (uq_medicaid_exc = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_medicaid;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_ssn() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ALT_ID (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL,
                  ALT_ID_TP_FLTR, STS_CD, SRC_ROWID, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, PERIOD_REFERENCE_TIME,
                  TIMELINE_ACTION)
    SELECT ssn_alt_key, period_start, period_end, version_seq_num, rle_key, ssn_tp_cd, ssn_out, ssn_tp_cd,
                    sts_cd, ssn_alt_src_rowid, CARE_LASTUP_DT, last_update, null_timestamp, null_number
      FROM WRK_CRE_KEYED
     WHERE (grp_ssn_alt = 1) AND (uq_ssn_alt = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into C_S_CRE_PTY_RLE_ALT_ID';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_ssn;


    FUNCTION sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ssn() RETURN VARCHAR2 IS

    l_rows NUMBER := 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB (MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE,
                  ATTRIBUTE_VALUE, SRC_SYS_ID_1)
    SELECT mapping_name, run_ts, ssn_tp_lbl, ssn_tp_sys, ssn_exception_code, ssn_exception_desc,
                    ssn_exception_type, ssn_out, mrg_care_id
      FROM WRK_CRE_KEYED
     WHERE (grp_ssn_exc = 1) AND (uq_ssn_exc = 1);
    l_rows := SQL%ROWCOUNT;
    RETURN 'OK: ' || l_rows || ' rows into EXC_STG_BAD_REC_MEMB';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ssn;

END PKG_CRE;
/
