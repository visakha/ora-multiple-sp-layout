-- Shared lookup helpers (v1 mirror common/01 + common/02), packaged.
-- Package body: implementations moved verbatim from the discrete
-- single-procedure files; only PKG_COMMON. qualification differs.
CREATE OR REPLACE PACKAGE BODY PKG_COMMON AS

    FUNCTION fn_snow_helper01_common(p_value IN VARCHAR2) RETURN NUMBER(1) IS

BEGIN
    RETURN CASE WHEN p_value IS NULL THEN NULL
         WHEN REGEXP_LIKE(p_value,
                  '[[:space:]]*[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?[[:space:]]*') THEN 1
         ELSE 0 END;
    END fn_snow_helper01_common;


    FUNCTION fn_snow_helper02_common(p_hub_state_ind IN NUMBER) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_hub_state_ind IS NULL THEN 'H'
         WHEN p_hub_state_ind = -1    THEN 'D'
         ELSE 'P' END;
    END fn_snow_helper02_common;


    FUNCTION fn_snow_helper03_common(p_value IN VARCHAR2) RETURN NUMBER(1) IS

BEGIN
    RETURN CASE WHEN p_value IS NULL OR LENGTH(RTRIM(p_value)) = 0 THEN 1 WHEN NOT (p_value IS NULL OR LENGTH(RTRIM(p_value)) = 0) THEN 0 END;
    END fn_snow_helper03_common;


    FUNCTION fn_snow_helper04_common(p_value IN VARCHAR2,
    p_scale IN NUMBER) RETURN NUMBER(38, 10) IS

BEGIN
    RETURN CASE WHEN p_value IS NULL THEN NULL
         WHEN fn_snow_helper01_common(p_value) = 0 THEN 0
         WHEN p_scale IS NULL THEN TO_NUMBER(TRIM(p_value) DEFAULT NULL ON CONVERSION ERROR)
         ELSE ROUND(TO_NUMBER(TRIM(p_value) DEFAULT NULL ON CONVERSION ERROR), p_scale) END;
    END fn_snow_helper04_common;


    FUNCTION fn_snow_helper05_common(p_addr_tp_mstr IN VARCHAR2,
    p_mailability_score IN VARCHAR2,
    p_match_code IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_addr_tp_mstr <> '002' AND p_mailability_score <= '3' THEN '40'
         WHEN p_addr_tp_mstr = '002' AND p_mailability_score < '3'
              AND SUBSTR(p_match_code, 1, 1) IN ('I', 'N') THEN '40'
         WHEN p_addr_tp_mstr IS NULL THEN '40'
         ELSE '100' END;
    END fn_snow_helper05_common;


    FUNCTION fn_snow_helper06_common(p_addr_tp_mstr IN VARCHAR2,
    p_mailability_score IN VARCHAR2,
    p_match_code IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_addr_tp_mstr <> '002' AND p_mailability_score <= '3' THEN 'Invalid Address'
         WHEN p_addr_tp_mstr = '002' AND p_mailability_score < '3'
              AND SUBSTR(p_match_code, 1, 1) IN ('I', 'N') THEN 'Invalid Address'
         WHEN p_addr_tp_mstr IS NULL THEN 'Invalid Address Type' END;
    END fn_snow_helper06_common;


    FUNCTION fn_snow_helper07_common(p_line_1 IN VARCHAR2,
    p_line_2 IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN (fn_snow_helper03_common(p_line_1) = 1) THEN p_line_2 ELSE p_line_1 END;
    END fn_snow_helper07_common;


    FUNCTION fn_snow_helper08_common(p_line_1 IN VARCHAR2,
    p_line_2 IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN fn_snow_helper07_common(p_line_1, p_line_2) = p_line_2 THEN NULL ELSE p_line_2 END;
    END fn_snow_helper08_common;


    FUNCTION fn_snow_helper09_common(p_value IN VARCHAR2,
    p_chars IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN REGEXP_REPLACE(TRIM(TRANSLATE(p_value, CHR(1) || p_chars, CHR(1))), ' {2,}', ' ');
    END fn_snow_helper09_common;


    FUNCTION fn_snow_helper10_common(p_value IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN NULLIF(REGEXP_REPLACE(TRIM(REGEXP_REPLACE(p_value, '[^[:alnum:] ]', '')), ' {2,}', ' '), '');
    END fn_snow_helper10_common;


    FUNCTION fn_snow_helper11_common(p_value IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN REGEXP_REPLACE(REGEXP_REPLACE(p_value, '[[:alpha:]]', 'X'), '[1-9]', '9');
    END fn_snow_helper11_common;


    FUNCTION fn_snow_helper12_common(p_name IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_name IS NULL THEN NULL
         WHEN (INSTR(fn_snow_helper11_common(p_name), 'X0X') > 0)
              AND NOT REGEXP_LIKE(TRIM(p_name), '.*[0-9]') THEN REPLACE(p_name, '0', 'o')
         ELSE p_name END;
    END fn_snow_helper12_common;


    FUNCTION fn_snow_helper13_common(p_name IN VARCHAR2,
    p_keep IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN TRIM(CASE WHEN p_name IS NULL THEN NULL
              WHEN NOT (LENGTH(TRIM(p_name)) >= 3
                        AND SUBSTR(fn_snow_helper11_common(TRIM(p_name)), LENGTH(TRIM(p_name)) - 2, 2) = '99')
                   AND SUBSTR(TRIM(p_name), -(1), 1) = '0' THEN p_keep
              WHEN REGEXP_INSTR(p_name, '[0-9]') > 0 THEN SUBSTR(p_name, 1, REGEXP_INSTR(p_name, '[0-9]') - 1)
              ELSE p_name END);
    END fn_snow_helper13_common;


    FUNCTION fn_snow_helper14_common(p_first_name IN VARCHAR2,
    p_middle_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_full_name IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER14_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER14_COMMON(first_name => fn_snow_helper13_common(fn_snow_helper12_common(p_first_name),
                                               fn_snow_helper12_common(p_first_name)), middle_name => fn_snow_helper13_common(fn_snow_helper12_common(p_middle_name),
                                               fn_snow_helper12_common(p_last_name)), last_name => fn_snow_helper13_common(fn_snow_helper12_common(p_last_name),
                                               fn_snow_helper12_common(p_last_name)), full_name => TRIM(NVL(fn_snow_helper13_common(fn_snow_helper12_common(p_first_name),
                                                        fn_snow_helper12_common(p_first_name)), '')
                            || CASE WHEN (fn_snow_helper03_common(fn_snow_helper13_common(
                                       fn_snow_helper12_common(p_middle_name), fn_snow_helper12_common(p_last_name))) = 1) THEN '' ELSE ' ' || TRIM(fn_snow_helper13_common(fn_snow_helper12_common(p_middle_name),
                                                                       fn_snow_helper12_common(p_last_name))) END
                            || ' '
                            || NVL(LTRIM(fn_snow_helper13_common(fn_snow_helper12_common(p_last_name),
                                                                 fn_snow_helper12_common(p_last_name))), '')));
    END fn_snow_helper14_common;


    FUNCTION fn_snow_helper15_common(p_first_name IN VARCHAR2,
    p_mdl_name IN VARCHAR2,
    p_lst_name IN VARCHAR2,
    p_full_name IN VARCHAR2,
    p_prfx_name IN VARCHAR2,
    p_sfx_name IN VARCHAR2,
    p_std_prefix IN VARCHAR2,
    p_std_suffix IN VARCHAR2,
    p_first_junk IN NUMBER(1),
    p_last_junk IN NUMBER(1)) RETURN T_OBJ_FN_SNOW_HELPER15_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER15_COMMON(first_name => fn_snow_helper14_common(
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_first_junk, 0) = 1) THEN NULL ELSE p_first_name END,
                                            '~!`@#$%^&*()_+=":;?/.>,<' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(p_mdl_name,
                                            '~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_last_junk, 0) = 1) THEN NULL ELSE p_lst_name END,
                                            '~`!@#$%^&*()_+=|\}{[]";:?>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(NVL(p_full_name, NVL(TRIM(p_first_name), '') || ' '
                                                             || NVL(TRIM(p_lst_name), '')),
                                            '~`!@#$%^*()_+=\|}]{[":;?/>.<,' || CHR(9)), ' ')).first_name, middle_name => fn_snow_helper14_common(
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_first_junk, 0) = 1) THEN NULL ELSE p_first_name END,
                                            '~!`@#$%^&*()_+=":;?/.>,<' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(p_mdl_name,
                                            '~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_last_junk, 0) = 1) THEN NULL ELSE p_lst_name END,
                                            '~`!@#$%^&*()_+=|\}{[]";:?>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(NVL(p_full_name, NVL(TRIM(p_first_name), '') || ' '
                                                             || NVL(TRIM(p_lst_name), '')),
                                            '~`!@#$%^*()_+=\|}]{[":;?/>.<,' || CHR(9)), ' ')).middle_name, last_name => fn_snow_helper14_common(
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_first_junk, 0) = 1) THEN NULL ELSE p_first_name END,
                                            '~!`@#$%^&*()_+=":;?/.>,<' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(p_mdl_name,
                                            '~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_last_junk, 0) = 1) THEN NULL ELSE p_lst_name END,
                                            '~`!@#$%^&*()_+=|\}{[]";:?>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(NVL(p_full_name, NVL(TRIM(p_first_name), '') || ' '
                                                             || NVL(TRIM(p_lst_name), '')),
                                            '~`!@#$%^*()_+=\|}]{[":;?/>.<,' || CHR(9)), ' ')).last_name, full_name => fn_snow_helper14_common(
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_first_junk, 0) = 1) THEN NULL ELSE p_first_name END,
                                            '~!`@#$%^&*()_+=":;?/.>,<' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(p_mdl_name,
                                            '~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(CASE WHEN (NVL(p_last_junk, 0) = 1) THEN NULL ELSE p_lst_name END,
                                            '~`!@#$%^&*()_+=|\}{[]";:?>.<,' || CHR(9)), ' '),
            INITCAP(fn_snow_helper09_common(NVL(p_full_name, NVL(TRIM(p_first_name), '') || ' '
                                                             || NVL(TRIM(p_lst_name), '')),
                                            '~`!@#$%^*()_+=\|}]{[":;?/>.<,' || CHR(9)), ' ')).full_name, src_full_name => NVL(p_full_name, NVL(TRIM(p_first_name), '') || ' ' || NVL(TRIM(p_lst_name), '')));
    END fn_snow_helper15_common;


    FUNCTION fn_snow_helper16_common(p_birth_date IN TIMESTAMP,
    p_party_type IN VARCHAR2,
    p_src_sys IN VARCHAR2,
    p_run_ts IN TIMESTAMP) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_src_sys IN ('P23', 'C21', 'P88', 'MAX', 'P84', 'PMR', 'TRS', 'CRE', 'ECI', 'WIC', 'FSS', 'TTF')
        AND p_party_type IN ('HCP', 'Indv', 'INDV', 'I')
        AND p_birth_date > p_run_ts THEN 'Invalid_Birth_Date' ELSE NULL END;
    END fn_snow_helper16_common;


    FUNCTION fn_snow_helper17_common(p_gender_code IN VARCHAR2,
    p_party_type IN VARCHAR2,
    p_src_sys IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER17_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER17_COMMON(gender_code => p_gender_code, mdm_gender_code => CASE WHEN p_party_type IN ('I', 'Indv', 'INDV', 'HCP') AND SUBSTR(p_gender_code, 1, 1) IN ('B', 'U') THEN NULL
                 WHEN p_party_type IN ('I', 'Indv', 'INDV', 'HCP') AND SUBSTR(p_gender_code, 1, 1) = 'M' THEN '1'
                 WHEN p_party_type IN ('I', 'Indv', 'INDV', 'HCP') AND SUBSTR(p_gender_code, 1, 1) = 'F' THEN '2'
                 ELSE NULL END, exception_code => CASE WHEN TRIM(p_src_sys) IN ('P23', 'C21', 'P88', 'MAX', 'P84', 'PMR', 'TRS', 'CRE', 'ECI', 'WIC', 'FSS', 'TTF')
                AND p_party_type IN ('HCP', 'Indv', 'INDV', 'I')
                AND (p_gender_code IS NULL
                     OR fn_snow_helper01_common(SUBSTR(p_gender_code, 1, 1)) = 1
                     OR SUBSTR(p_gender_code, 1, 1) NOT IN ('M', 'F', 'U', 'B')) THEN 'Invalid_Gender' ELSE NULL END);
    END fn_snow_helper17_common;


    FUNCTION fn_snow_helper18_common(p_mstr_code_value IN VARCHAR2,
    p_exception_code IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_mstr_code_value IS NULL THEN p_exception_code ELSE NULL END;
    END fn_snow_helper18_common;


    FUNCTION fn_snow_helper19_common(p_white_ind IN NUMBER,
    p_black_ind IN NUMBER,
    p_asian_ind IN NUMBER,
    p_pacific_islander_ind IN NUMBER,
    p_native_american_ind IN NUMBER) RETURN T_OBJ_FN_SNOW_HELPER19_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER19_COMMON(mdm_race_cd => CASE WHEN p_white_ind + p_black_ind + p_asian_ind + p_pacific_islander_ind + p_native_american_ind = 2
                     THEN '006'
                 WHEN p_white_ind + p_black_ind + p_asian_ind + p_pacific_islander_ind + p_native_american_ind > 2
                     THEN '007'
                 WHEN p_white_ind + p_black_ind + p_asian_ind + p_pacific_islander_ind + p_native_american_ind = 0
                     THEN NULL
                 WHEN p_white_ind + p_black_ind + p_asian_ind + p_pacific_islander_ind + p_native_american_ind = 1
                     THEN CASE WHEN p_white_ind = 1 THEN '001'
                               WHEN p_black_ind = 1 THEN '002'
                               WHEN p_native_american_ind = 1 THEN '003'
                               WHEN p_asian_ind = 1 THEN '004'
                               WHEN p_pacific_islander_ind = 1 THEN '005' END
                 ELSE NULL END, src_race_ind_list => 'WH' || NVL(TO_CHAR(p_white_ind), '') || 'AA' || NVL(TO_CHAR(p_black_ind), '')
            || 'AS' || NVL(TO_CHAR(p_asian_ind), '') || 'PI' || NVL(TO_CHAR(p_pacific_islander_ind), '')
            || 'NA' || NVL(TO_CHAR(p_native_american_ind), ''), exception_code => CASE WHEN NVL(p_white_ind + p_black_ind + p_asian_ind + p_pacific_islander_ind + p_native_american_ind, 0) = 0 THEN 'Invalid_Race' ELSE NULL END);
    END fn_snow_helper19_common;


    FUNCTION fn_snow_helper20_common(p_suffix IN VARCHAR2,
    p_std_suffix IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN NOT (fn_snow_helper03_common(p_suffix) = 1) AND p_std_suffix IS NULL THEN 'Invalid_Suffix' ELSE NULL END;
    END fn_snow_helper20_common;


    FUNCTION fn_snow_helper21_common(p_input_date IN TIMESTAMP,
    p_run_ts IN TIMESTAMP) RETURN TIMESTAMP IS

BEGIN
    RETURN CASE WHEN SUBSTR(TO_CHAR(CAST((MONTHS_BETWEEN(p_input_date, p_run_ts) / 12) AS BINARY_DOUBLE)), 1, 10) > '50' THEN NULL ELSE p_input_date END;
    END fn_snow_helper21_common;


    FUNCTION fn_snow_helper22_common(p_email IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER22_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER22_COMMON(email_address => LOWER(TRIM(p_email)), exception_code => CASE WHEN p_email IS NULL THEN 'Invalid_Email'
                 WHEN REGEXP_LIKE(TRIM(p_email), '.*[[:space:]].*') THEN 'Invalid_Email'
                 WHEN LOWER(TRIM(p_email)) = 'invalid' THEN 'Invalid_Email'
                 WHEN INSTR(p_email, '@') = 0 OR INSTR(p_email, '.', INSTR(p_email, '@')) = 0
                     THEN 'Invalid_Email'
                 WHEN NOT (
                        -- domain part = everything after the first '@', trimmed, lower case
                        NOT (INSTR(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                             '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), '_') > 1
                             OR (SUBSTR(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                             '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), 1, LENGTH('.')) = '.')
                             OR (SUBSTR(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                             '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), 1, LENGTH('-')) = '-')
                             OR (SUBSTR(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                           '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), -LENGTH('-'), LENGTH('-')) = '-'))
                        AND REGEXP_LIKE(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                          '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), '[a-z0-9.-]+')
                        AND INSTR(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                             '^(.*)[.][^.]*$', 1, 1,NULL, 1), ''), '..') <= 1
                        AND INSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))), '..') <= 1)
                     THEN 'Invalid_Email'
                 WHEN NOT (REGEXP_LIKE(NVL(REGEXP_SUBSTR(TRIM(LOWER(SUBSTR(p_email, INSTR(p_email, '@') + 1))),
                                                         '[.]([^.]*)$', 1, 1,NULL, 1), ''), '[a-z0-9]{2,11}'))
                     THEN 'Invalid_Email'
                 ELSE NULL END);
    END fn_snow_helper22_common;


    FUNCTION fn_snow_helper23_common(p_phone IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN SUBSTR(fn_snow_helper09_common(p_phone, '~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<, ' || CHR(9)), 1, 10);
    END fn_snow_helper23_common;


    FUNCTION fn_snow_helper24_common(p_phone IN VARCHAR2,
    p_src_sys IN VARCHAR2,
    p_usg_tp IN VARCHAR2,
    p_npa_id IN VARCHAR2,
    p_area_service IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN NVL(fn_snow_helper01_common(p_phone), 0) = 0 THEN 'Invalid_Phone_Number'
         WHEN LENGTH(p_phone) <> 10 OR p_phone = '0000000000' THEN 'Invalid_Phone_Number'
         WHEN SUBSTR(p_phone, 4, 1) IN ('0', '1') THEN 'Invalid_Phone_Number'
         WHEN p_src_sys = 'ECI' AND SUBSTR(p_phone, 1, 3) = '000' THEN 'Missing_AreaCode'
         WHEN p_npa_id IS NULL THEN 'Invalid_Phone_Number'
         WHEN SUBSTR(p_phone, 1, 1) IN ('0', '1') THEN 'Invalid_Phone_Number'
         WHEN p_src_sys IN ('TRS', 'CRE', 'ECI') AND p_usg_tp IN ('001', '003') AND p_area_service = 'Toll-Free'
             THEN 'Invalid_Phone_Number'
         ELSE NULL END;
    END fn_snow_helper24_common;


    FUNCTION fn_snow_helper25_common(p_phone_nbr_ext IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER25_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER25_COMMON(phone_nbr_ext => fn_snow_helper10_common(p_phone_nbr_ext), exception_code => CASE WHEN fn_snow_helper10_common(p_phone_nbr_ext) IS NOT NULL
                AND (LENGTH(fn_snow_helper10_common(p_phone_nbr_ext)) NOT BETWEEN 2 AND 6
                     OR fn_snow_helper01_common(fn_snow_helper10_common(p_phone_nbr_ext)) = 0) THEN 'Invalid_Phone_Number_Ext' ELSE NULL END);
    END fn_snow_helper25_common;


    FUNCTION fn_snow_helper26_common(p_ssn IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER26_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER26_COMMON(ssn_status => CASE WHEN REGEXP_LIKE(REPLACE(REPLACE(TRIM(p_ssn), '-', ''), ' ', ''), '[0-9]{9}')
                AND SUBSTR(REPLACE(REPLACE(TRIM(p_ssn), '-', ''), ' ', ''), 1, 3) NOT IN ('000', '666')
                AND SUBSTR(REPLACE(REPLACE(TRIM(p_ssn), '-', ''), ' ', ''), 1, 1) <> '9'
                AND SUBSTR(REPLACE(REPLACE(TRIM(p_ssn), '-', ''), ' ', ''), 4, 2) <> '00'
                AND SUBSTR(REPLACE(REPLACE(TRIM(p_ssn), '-', ''), ' ', ''), 6, 4) <> '0000' THEN 'Valid' ELSE 'Invalid' END, ssn_error_message => CASE WHEN NVL(LENGTH(TRIM(REGEXP_REPLACE(p_ssn, '[- Xx]', ''))), 0) <> 9 THEN 'Invalid SSN length'
                 WHEN SUBSTR(TRIM(REGEXP_REPLACE(p_ssn, '[- Xx]', '')), 1, 3) IN ('000', '666')
                      OR SUBSTR(TRIM(REGEXP_REPLACE(p_ssn, '[- Xx]', '')), 1, 3) > '899' THEN 'SSN area invalid'
                 WHEN SUBSTR(TRIM(REGEXP_REPLACE(p_ssn, '[- Xx]', '')), 4, 2) = '00' THEN 'SSN group invalid'
                 WHEN SUBSTR(TRIM(REGEXP_REPLACE(p_ssn, '[- Xx]', '')), 6, 4) = '0000' THEN 'SSN serial invalid'
                 ELSE 'No error' END);
    END fn_snow_helper26_common;


    FUNCTION fn_snow_helper27_common(p_medicaid_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER27_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER27_COMMON(id_value => SUBSTR(fn_snow_helper10_common(p_medicaid_id), 1, 10), exception_code => CASE WHEN LENGTH(SUBSTR(fn_snow_helper10_common(p_medicaid_id), 1, 10)) <> 9 THEN 'Invalid_Medicaid_Id' ELSE NULL END);
    END fn_snow_helper27_common;


    FUNCTION fn_snow_helper28_common(p_member_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER28_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER28_COMMON(id_value => SUBSTR(fn_snow_helper10_common(p_member_id), 1, 10), exception_code => CASE WHEN LENGTH(SUBSTR(fn_snow_helper10_common(p_member_id), 1, 10)) NOT IN (9, 10) THEN 'Invalid_Member_Id' ELSE NULL END);
    END fn_snow_helper28_common;


    FUNCTION fn_snow_helper29_common(p_line IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_line IS NULL THEN NULL
         WHEN (SUBSTR(UPPER(TRIM(p_line)), -LENGTH('STE #'), LENGTH('STE #')) = 'STE #') THEN SUBSTR(TRIM(p_line), 1, LENGTH(TRIM(p_line)) - 5)
         WHEN (SUBSTR(UPPER(TRIM(p_line)), -LENGTH('SUITE'), LENGTH('SUITE')) = 'SUITE') THEN SUBSTR(TRIM(p_line), 1, LENGTH(TRIM(p_line)) - 5)
         WHEN (SUBSTR(UPPER(TRIM(p_line)), -LENGTH('STE.'), LENGTH('STE.')) = 'STE.')  THEN SUBSTR(TRIM(p_line), 1, LENGTH(TRIM(p_line)) - 4)
         WHEN (SUBSTR(UPPER(TRIM(p_line)), -LENGTH('STE'), LENGTH('STE')) = 'STE')   THEN SUBSTR(TRIM(p_line), 1, LENGTH(TRIM(p_line)) - 3)
         ELSE p_line END;
    END fn_snow_helper29_common;


    FUNCTION fn_snow_helper30_common(p_line IN VARCHAR2,
    p_second_line IN NUMBER(1)) RETURN VARCHAR2 IS

BEGIN
    RETURN REPLACE(REGEXP_REPLACE(
                fn_snow_helper09_common(UPPER(p_line),
                                        CASE WHEN (p_second_line = 1) THEN '$)(@^!~*%+-={}[]|:;"''<>?&' ELSE '$)(@^!~*%+_={}[]|:;"''<>?&' END),
                '#{2,}', '#'),
            '\', '/');
    END fn_snow_helper30_common;


    FUNCTION fn_snow_helper31_common(p_line IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN TRIM(REGEXP_REPLACE(
             REPLACE(CASE WHEN SUBSTR(REGEXP_REPLACE(TRIM(p_line), ' {2,}', ' '), 1, LENGTH('C/O ')) = 'C/O ' THEN 'c/o ' || SUBSTR(REGEXP_REPLACE(TRIM(p_line), ' {2,}', ' '), 5) ELSE REGEXP_REPLACE(TRIM(p_line), ' {2,}', ' ') END,
                     ' C/O ', ' c/o '),
             '[[:space:]]+(#|APT|BLDG|DEPT|FL|HNGR|KEY|LOT|PIER|RM|SLIP|SPC|STOP|STE|TRLR|UNIT)$', '', 1, 0, 'i'));
    END fn_snow_helper31_common;


    FUNCTION fn_snow_helper32_common(p_ad_state_fips IN VARCHAR2,
    p_source_state_fips IN VARCHAR2,
    p_zip5 IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN NOT (fn_snow_helper03_common(p_ad_state_fips) = 1) THEN p_ad_state_fips
         WHEN NOT (fn_snow_helper03_common(p_source_state_fips) = 1) THEN p_source_state_fips
         WHEN p_zip5 = '73301'
              OR (p_zip5 BETWEEN '75001' AND '79999' AND p_zip5 <> '75502')
              OR p_zip5 BETWEEN '88510' AND '88589' THEN '48'
         ELSE NULL END;
    END fn_snow_helper32_common;


    FUNCTION fn_snow_helper33_common(p_ad_state_fips IN VARCHAR2,
    p_ad_county_fips IN VARCHAR2) RETURN VARCHAR2 IS

BEGIN
    RETURN CASE WHEN p_ad_state_fips = '48' THEN p_ad_county_fips
         WHEN p_ad_county_fips IS NULL THEN '999'
         ELSE '996' END;
    END fn_snow_helper33_common;


    FUNCTION fn_snow_helper34_common(p_address_1 IN VARCHAR2,
    p_address_2 IN VARCHAR2,
    p_city IN VARCHAR2,
    p_state IN VARCHAR2,
    p_postal_code IN VARCHAR2,
    p_country IN VARCHAR2,
    p_source_state_fips IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER34_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER34_COMMON(delivery_address_line1 => fn_snow_helper31_common(fn_snow_helper30_common(fn_snow_helper29_common(p_address_1), 0)), delivery_address_line2 => fn_snow_helper31_common(fn_snow_helper30_common(fn_snow_helper29_common(p_address_2), 1)), city => p_city, postcode_complete => TRIM(p_postal_code), zip_cd_5 => SUBSTR(TRIM(p_postal_code), 1, 5), zip_cd_4_extn => SUBSTR(TRIM(p_postal_code), 7, 4), country_iso2_char => p_country, province_iso3 => NULL, state_fips_cd => fn_snow_helper32_common(NULL, p_source_state_fips, SUBSTR(TRIM(p_postal_code), 1, 5)), county_fips_cd => fn_snow_helper33_common(NULL, NULL), geocoding_latitude => 0, geocoding_longitude => 0, geocoding_status => NULL, geocoding_complete => NULL, match_code => NULL, status_info_match_code => NULL, status_info_result_percentage => NULL, mailability_score => NULL, address_type => NULL, residential_delivery_indicator => NULL, organization_complete => NULL, organization_name => NULL, organization_descriptor => NULL, organization_department => NULL, building_name => NULL, building_number => NULL, building_complete => NULL, street_number_complete => NULL, sub_building_number => NULL, sub_building_complete => NULL, sub_building_descriptor => NULL, early_warning_system_return_cd => NULL, cass_error_code => NULL, dpv_confirmation => NULL);
    END fn_snow_helper34_common;


    FUNCTION fn_snow_helper35_common(p_period_start_date IN TIMESTAMP,
    p_period_end_date IN TIMESTAMP,
    p_dst_matched IN NUMBER(1)) RETURN TIMESTAMP IS

BEGIN
    RETURN CASE WHEN NVL(p_period_start_date = p_period_end_date, 0) OR NVL(p_dst_matched, 0) THEN ((p_period_end_date) + (1)/24) ELSE p_period_end_date END;
    END fn_snow_helper35_common;


    FUNCTION fn_snow_helper36_common(p_mapping_name IN VARCHAR2,
    p_step IN VARCHAR2,
    p_rows IN NUMBER) RETURN VARCHAR2 IS

BEGIN
    RETURN TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3') || ' ' || NVL(p_mapping_name, '') || ' '
    || NVL(p_step, '') || ': ' || NVL(TO_CHAR(p_rows), '0') || ' row(s)';
    END fn_snow_helper36_common;


    FUNCTION fn_snow_helper37_common(p_care_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER37_COMMON IS

BEGIN
    RETURN T_OBJ_FN_SNOW_HELPER37_COMMON(id_value => SUBSTR(fn_snow_helper10_common(p_care_id), 1, 10), exception_code => NULL);
    END fn_snow_helper37_common;


    FUNCTION fn_snow_helper40_common() RETURN T_TAB_FN_SNOW_HELPER40_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER40_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER40_COMMON(EXCEPTION_CODE => __w0, EXCEPTION_DESC => __w1, EXCEPTION_TYPE => __w2) FROM (
SELECT EXCEPTION_CODE AS __w0, EXCEPTION_DESC AS __w1, EXCEPTION_TYPE AS __w2FROM (SELECT e.EXCEPTION_CODE, e.EXCEPTION_DESC, e.EXCEPTION_TYPE, ROW_NUMBER() OVER (PARTITION BY e.EXCEPTION_CODE
                                  ORDER BY e.EXCEPTION_DESC NULLS LAST, e.EXCEPTION_TYPE NULLS LAST) AS __qual_rn FROM EXC_LOOKUP_CODE_VALUE e
     WHERE e.EXCEPTION_CODE IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper40_common;


    FUNCTION fn_snow_helper41_common() RETURN T_TAB_FN_SNOW_HELPER41_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER41_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER41_COMMON(CODE_TYPE => __w0, SRC_SYS => __w1, SRC_CODE_VALUE => __w2, MSTR_CODE_VALUE => __w3) FROM (
SELECT CODE_TYPE AS __w0, SRC_SYS AS __w1, SRC_CODE_VALUE AS __w2, MSTR_CODE_VALUE AS __w3FROM (SELECT v.CODE_TYPE, v.SRC_SYS, v.SRC_CODE_VALUE, v.MSTR_CODE_VALUE, ROW_NUMBER() OVER (PARTITION BY v.CODE_TYPE, v.SRC_SYS, v.SRC_CODE_VALUE
                                  ORDER BY v.MSTR_CODE_VALUE NULLS LAST) AS __qual_rn FROM V_LOOKUP_CODE_VALUE v
     WHERE v.CODE_TYPE IS NOT NULL AND v.SRC_SYS IS NOT NULL AND v.SRC_CODE_VALUE IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper41_common;


    FUNCTION fn_snow_helper42_common() RETURN T_TAB_FN_SNOW_HELPER42_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER42_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER42_COMMON(SRC_SYS => __w0, SRC_CODE_VALUE => __w1, MSTR_CODE_VALUE => __w2) FROM (
SELECT SRC_SYS AS __w0, SRC_CODE_VALUE AS __w1, MSTR_CODE_VALUE AS __w2FROM (SELECT v.SRC_SYS, v.SRC_CODE_VALUE, v.MSTR_CODE_VALUE, ROW_NUMBER() OVER (PARTITION BY v.SRC_SYS, v.SRC_CODE_VALUE
                                  ORDER BY v.MSTR_CODE_VALUE NULLS LAST, v.CODE_TYPE) AS __qual_rn FROM V_LOOKUP_CODE_VALUE v
     WHERE v.SRC_SYS IS NOT NULL AND v.SRC_CODE_VALUE IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper42_common;


    FUNCTION fn_snow_helper43_common() RETURN T_TAB_FN_SNOW_HELPER43_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER43_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER43_COMMON(NAME => __w0, IS_FIRST_JUNK => IS_FIRST_JUNK, IS_LAST_JUNK => IS_LAST_JUNK) FROM (
SELECT j.NAME AS __w0, MAX(CASE WHEN j.EDIT_LIMITATION IS NULL OR j.EDIT_LIMITATION = 'FIRST' THEN 1 WHEN NOT (j.EDIT_LIMITATION IS NULL OR j.EDIT_LIMITATION = 'FIRST') THEN 0 END) AS IS_FIRST_JUNK, MAX(CASE WHEN j.EDIT_LIMITATION IS NULL OR j.EDIT_LIMITATION = 'LAST' THEN 1 WHEN NOT (j.EDIT_LIMITATION IS NULL OR j.EDIT_LIMITATION = 'LAST') THEN 0 END)  AS IS_LAST_JUNKFROM REF_JUNK_NAME_LIST j
     WHERE j.NAME IS NOT NULL
     GROUP BY j.NAME
)
);
    RETURN l_tab;
    END fn_snow_helper43_common;


    FUNCTION fn_snow_helper44_common() RETURN T_TAB_FN_SNOW_HELPER44_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER44_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER44_COMMON(NPA_ID => __w0, SERVICE => __w1) FROM (
SELECT NPA_ID AS __w0, SERVICE AS __w1FROM (SELECT CAST(a.NPA_ID AS VARCHAR2(4000)) AS NPA_ID, a.SERVICE, ROW_NUMBER() OVER (PARTITION BY a.NPA_ID ORDER BY a.SERVICE NULLS FIRST) AS __qual_rn FROM RDM.REF_PHN_AREA_CD a
     WHERE (a.IN_SERVICE = 'Y' OR CURRENT_DATE >= a.IN_SERVICE_DT)
       AND (a.SERVICE IS NULL OR a.SERVICE = 'Toll-Free')
       AND (a.COUNTRY = 'US' OR a.COUNTRY IS NULL)   -- omit Canada and Caribbean countries
       AND a.NPA_ID IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper44_common;


    FUNCTION fn_snow_helper45_common() RETURN T_TAB_FN_SNOW_HELPER45_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER45_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER45_COMMON(CODE_TYPE => __w0, SRC_SYS => __w1, MSTR_REF_CODE => __w2, MSTR_REF_LABEL => __w3) FROM (
SELECT CODE_TYPE AS __w0, SRC_SYS AS __w1, MSTR_REF_CODE AS __w2, MSTR_REF_LABEL AS __w3FROM (SELECT l.CODE_TYPE, l.SRC_SYS, l.MSTR_REF_CODE, l.MSTR_REF_LABEL, ROW_NUMBER() OVER (PARTITION BY l.CODE_TYPE, l.SRC_SYS, l.MSTR_REF_CODE
                                  ORDER BY l.MSTR_REF_LABEL NULLS LAST) AS __qual_rn FROM LOOKUP_CODE_VALUE l
     WHERE l.CODE_TYPE IS NOT NULL AND l.SRC_SYS IS NOT NULL AND l.MSTR_REF_CODE IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper45_common;


    FUNCTION fn_snow_helper46_common() RETURN T_TAB_FN_SNOW_HELPER46_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER46_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER46_COMMON(MATCH_CODE => __w0, DESCRIPTION => __w1) FROM (
SELECT MATCH_CODE AS __w0, DESCRIPTION AS __w1FROM (SELECT r.MATCH_CODE, r.DESCRIPTION, ROW_NUMBER() OVER (PARTITION BY r.MATCH_CODE ORDER BY r.DESCRIPTION NULLS LAST) AS __qual_rn FROM REF_MATCHCODE_DESC r
     WHERE r.MATCH_CODE IS NOT NULL
   ) WHERE __qual_rn = 1
)
);
    RETURN l_tab;
    END fn_snow_helper46_common;


    FUNCTION fn_snow_helper47_common() RETURN T_TAB_FN_SNOW_HELPER47_COMMON IS

    l_tab T_TAB_FN_SNOW_HELPER47_COMMON;
BEGIN
    SELECT * BULK COLLECT INTO l_tab FROM (
SELECT T_OBJ_FN_SNOW_HELPER47_COMMON(DST => DST) FROM (
SELECT DISTINCT CAST(d.DST AS TIMESTAMP) AS DSTFROM REF_DYLGHT_SVNGS_TM d
     WHERE d.DST IS NOT NULL
)
);
    RETURN l_tab;
    END fn_snow_helper47_common;

END PKG_COMMON;
/
