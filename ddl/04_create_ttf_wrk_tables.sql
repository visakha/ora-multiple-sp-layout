-- 04_create_ttf_wrk_tables.sql -- TTF snapshot tables.
-- Required at install time because the TTF stage procedures DELETE +
-- INSERT these pre-existing tables each run (they do not create them).
-- All other workflows' WRK tables are created at run time by their
-- materializer procedures (DROP-if-exists + CTAS) and need no DDL.
-- NO DROP STATEMENTS IN THIS FILE. Teardown lives in drop_all.sql only.
-- Work tables for the TTF multiple-SP layout (wf_TTF_Stage_Load).
-- Run once at install time. Re-running requires removing the tables first (see drop_all.sql).
-- Stage procedures DELETE + INSERT these tables each run (transactional);
-- writer procedures read them. They are never read by any other workflow.
-- Column types follow the v1 mirror conventions: VARCHAR2(4000) for strings,
-- TIMESTAMP for run/date stamps, NUMBER for 1/0 flags.

CREATE TABLE WRK_TTF_VAL_ROUTED (
    pkey_src_object VARCHAR2(4000),
    createddate TIMESTAMP,
    dob TIMESTAMP,
    std_first_name VARCHAR2(4000),
    std_mdl_name VARCHAR2(4000),
    std_lst_name VARCHAR2(4000),
    std_src_full_name VARCHAR2(4000),
    grp_invalid_party_name NUMBER,
    grp_deactivation NUMBER,
    grp_reactivation NUMBER,
    exc_code_name VARCHAR2(4000),
    new_deactivation_sts VARCHAR2(4000),
    deactivation_sts VARCHAR2(4000),
    exc_desc_name VARCHAR2(4000),
    exc_type_name VARCHAR2(4000),
    src_sys VARCHAR2(4000),
    run_ts TIMESTAMP,
    mapping_name VARCHAR2(4000),
    action_deactivation VARCHAR2(4000),
    action_reactivation VARCHAR2(4000),
    uq_exc_name NUMBER
);

CREATE TABLE WRK_TTF_PTY_ROUTED (
    pkey_trim VARCHAR2(4000),
    rle_pkey VARCHAR2(4000),
    submitdate TIMESTAMP,
    std_prfx_name VARCHAR2(4000),
    std_first_name VARCHAR2(4000),
    std_mdl_name VARCHAR2(4000),
    std_lst_name VARCHAR2(4000),
    std_full_name VARCHAR2(4000),
    mdm_gender_code VARCHAR2(4000),
    std_src_full_name VARCHAR2(4000),
    ethnicity_mstr VARCHAR2(4000),
    ethnicity VARCHAR2(4000),
    race_mstr VARCHAR2(4000),
    raceethnicityid VARCHAR2(4000),
    std_birth_date TIMESTAMP,
    pty_src_key VARCHAR2(4000),
    clients_id VARCHAR2(4000),
    firstname VARCHAR2(4000),
    middlename VARCHAR2(4000),
    lastname VARCHAR2(4000),
    gender VARCHAR2(4000),
    dob TIMESTAMP,
    gender_exception_code VARCHAR2(4000),
    gender_exception_description VARCHAR2(4000),
    gender_exception_type VARCHAR2(4000),
    birth_exception_code VARCHAR2(4000),
    birth_exception_description VARCHAR2(4000),
    birth_exception_type VARCHAR2(4000),
    ethnicity_exception_code VARCHAR2(4000),
    ethnicity_exception_desc VARCHAR2(4000),
    ethnicity_exception_type VARCHAR2(4000),
    race_exception_code VARCHAR2(4000),
    race_exception_desc VARCHAR2(4000),
    race_exception_type VARCHAR2(4000),
    grp_gender NUMBER,
    grp_birth NUMBER,
    grp_ethnicity NUMBER,
    grp_race NUMBER,
    version_seq VARCHAR2(4000),
    hub_state_ind NUMBER,
    src_sys VARCHAR2(4000),
    run_ts TIMESTAMP,
    mapping_name VARCHAR2(4000),
    pty_bo_class_cd VARCHAR2(4000),
    rle_bo_class_cd VARCHAR2(4000),
    dob_text VARCHAR2(4000),
    attr_gender VARCHAR2(4000),
    attr_birth VARCHAR2(4000),
    attr_ethnicity VARCHAR2(4000),
    attr_race VARCHAR2(4000),
    uq_pty NUMBER,
    uq_rle NUMBER,
    uq_gender NUMBER,
    uq_birth NUMBER,
    uq_ethnicity NUMBER,
    uq_race NUMBER
);

CREATE TABLE WRK_TTF_PHN_ROUTED (
    phn_pkey VARCHAR2(4000),
    submitdate TIMESTAMP,
    std_phone VARCHAR2(4000),
    phone VARCHAR2(4000),
    pty_src_key VARCHAR2(4000),
    phone_exception_code VARCHAR2(4000),
    phone_exception_desc VARCHAR2(4000),
    version_seq VARCHAR2(4000),
    hub_state_ind NUMBER,
    pty_rle_fk VARCHAR2(4000),
    phn_tp VARCHAR2(4000),
    usg_tp VARCHAR2(4000),
    pref_lvl VARCHAR2(4000),
    src_sys VARCHAR2(4000),
    run_ts TIMESTAMP,
    mapping_name VARCHAR2(4000),
    exc_type_rejected VARCHAR2(4000),
    attr_phone VARCHAR2(4000),
    uq_phn NUMBER,
    uq_phone_exc NUMBER
);
