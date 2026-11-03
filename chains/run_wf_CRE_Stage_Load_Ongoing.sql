-- Chain for wf_CRE_Stage_Load_Ongoing (v1 multiple-procedure layout).
-- Calls the discrete procedures in chain order, then commits once.
-- A failure in any step rolls that step back and stops the chain;
-- re-run the chain from the start (each stage rebuilds its work table).
-- Pipeline stages use the original defaults; flat/keyed take them as
-- arguments below so a caller can override them per call.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_routed() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_named() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_members() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_ranked() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_dq2() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_flat('Member', '99') FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_keyed('002', '48', '996', '998', 'Member') FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_mrg() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_fname() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_lname() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_pty() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_rle() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_gender() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_suffix() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ethnicity() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_race() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_addr() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_addr() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_phn() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_phone() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_care() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_medicaid() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_medicaid() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_alt_ssn() FROM DUAL;
SELECT PKG_CRE.sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients_exc_ssn() FROM DUAL;
COMMIT;
WHENEVER SQLERROR CONTINUE;
