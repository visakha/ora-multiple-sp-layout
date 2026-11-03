-- Shared lookup helpers (v1 mirror common/01 + common/02), packaged.
-- Package spec: one declaration per routine, in chain order.
CREATE OR REPLACE PACKAGE PKG_COMMON AUTHID CURRENT_USER AS
    FUNCTION fn_snow_helper01_common(p_value IN VARCHAR2) RETURN NUMBER(1);
    FUNCTION fn_snow_helper02_common(p_hub_state_ind IN NUMBER) RETURN VARCHAR2;
    FUNCTION fn_snow_helper03_common(p_value IN VARCHAR2) RETURN NUMBER(1);
    FUNCTION fn_snow_helper04_common(p_value IN VARCHAR2,
    p_scale IN NUMBER) RETURN NUMBER(38, 10);
    FUNCTION fn_snow_helper05_common(p_addr_tp_mstr IN VARCHAR2,
    p_mailability_score IN VARCHAR2,
    p_match_code IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper06_common(p_addr_tp_mstr IN VARCHAR2,
    p_mailability_score IN VARCHAR2,
    p_match_code IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper07_common(p_line_1 IN VARCHAR2,
    p_line_2 IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper08_common(p_line_1 IN VARCHAR2,
    p_line_2 IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper09_common(p_value IN VARCHAR2,
    p_chars IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper10_common(p_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper11_common(p_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper12_common(p_name IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper13_common(p_name IN VARCHAR2,
    p_keep IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper14_common(p_first_name IN VARCHAR2,
    p_middle_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_full_name IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER14_COMMON;
    FUNCTION fn_snow_helper15_common(p_first_name IN VARCHAR2,
    p_mdl_name IN VARCHAR2,
    p_lst_name IN VARCHAR2,
    p_full_name IN VARCHAR2,
    p_prfx_name IN VARCHAR2,
    p_sfx_name IN VARCHAR2,
    p_std_prefix IN VARCHAR2,
    p_std_suffix IN VARCHAR2,
    p_first_junk IN NUMBER(1),
    p_last_junk IN NUMBER(1)) RETURN T_OBJ_FN_SNOW_HELPER15_COMMON;
    FUNCTION fn_snow_helper16_common(p_birth_date IN TIMESTAMP,
    p_party_type IN VARCHAR2,
    p_src_sys IN VARCHAR2,
    p_run_ts IN TIMESTAMP) RETURN VARCHAR2;
    FUNCTION fn_snow_helper17_common(p_gender_code IN VARCHAR2,
    p_party_type IN VARCHAR2,
    p_src_sys IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER17_COMMON;
    FUNCTION fn_snow_helper18_common(p_mstr_code_value IN VARCHAR2,
    p_exception_code IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper19_common(p_white_ind IN NUMBER,
    p_black_ind IN NUMBER,
    p_asian_ind IN NUMBER,
    p_pacific_islander_ind IN NUMBER,
    p_native_american_ind IN NUMBER) RETURN T_OBJ_FN_SNOW_HELPER19_COMMON;
    FUNCTION fn_snow_helper20_common(p_suffix IN VARCHAR2,
    p_std_suffix IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper21_common(p_input_date IN TIMESTAMP,
    p_run_ts IN TIMESTAMP) RETURN TIMESTAMP;
    FUNCTION fn_snow_helper22_common(p_email IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER22_COMMON;
    FUNCTION fn_snow_helper23_common(p_phone IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper24_common(p_phone IN VARCHAR2,
    p_src_sys IN VARCHAR2,
    p_usg_tp IN VARCHAR2,
    p_npa_id IN VARCHAR2,
    p_area_service IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper25_common(p_phone_nbr_ext IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER25_COMMON;
    FUNCTION fn_snow_helper26_common(p_ssn IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER26_COMMON;
    FUNCTION fn_snow_helper27_common(p_medicaid_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER27_COMMON;
    FUNCTION fn_snow_helper28_common(p_member_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER28_COMMON;
    FUNCTION fn_snow_helper29_common(p_line IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper30_common(p_line IN VARCHAR2,
    p_second_line IN NUMBER(1)) RETURN VARCHAR2;
    FUNCTION fn_snow_helper31_common(p_line IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper32_common(p_ad_state_fips IN VARCHAR2,
    p_source_state_fips IN VARCHAR2,
    p_zip5 IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper33_common(p_ad_state_fips IN VARCHAR2,
    p_ad_county_fips IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION fn_snow_helper34_common(p_address_1 IN VARCHAR2,
    p_address_2 IN VARCHAR2,
    p_city IN VARCHAR2,
    p_state IN VARCHAR2,
    p_postal_code IN VARCHAR2,
    p_country IN VARCHAR2,
    p_source_state_fips IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER34_COMMON;
    FUNCTION fn_snow_helper35_common(p_period_start_date IN TIMESTAMP,
    p_period_end_date IN TIMESTAMP,
    p_dst_matched IN NUMBER(1)) RETURN TIMESTAMP;
    FUNCTION fn_snow_helper36_common(p_mapping_name IN VARCHAR2,
    p_step IN VARCHAR2,
    p_rows IN NUMBER) RETURN VARCHAR2;
    FUNCTION fn_snow_helper37_common(p_care_id IN VARCHAR2) RETURN T_OBJ_FN_SNOW_HELPER37_COMMON;
    FUNCTION fn_snow_helper40_common() RETURN T_TAB_FN_SNOW_HELPER40_COMMON;
    FUNCTION fn_snow_helper41_common() RETURN T_TAB_FN_SNOW_HELPER41_COMMON;
    FUNCTION fn_snow_helper42_common() RETURN T_TAB_FN_SNOW_HELPER42_COMMON;
    FUNCTION fn_snow_helper43_common() RETURN T_TAB_FN_SNOW_HELPER43_COMMON;
    FUNCTION fn_snow_helper44_common() RETURN T_TAB_FN_SNOW_HELPER44_COMMON;
    FUNCTION fn_snow_helper45_common() RETURN T_TAB_FN_SNOW_HELPER45_COMMON;
    FUNCTION fn_snow_helper46_common() RETURN T_TAB_FN_SNOW_HELPER46_COMMON;
    FUNCTION fn_snow_helper47_common() RETURN T_TAB_FN_SNOW_HELPER47_COMMON;
END PKG_COMMON;
/
