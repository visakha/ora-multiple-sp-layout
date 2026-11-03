-- Chain script for the TTF multiple-SP layout (wf_TTF_Stage_Load).
-- Calls the discrete procedures in chain order (seq1 = mapping order = original
-- run-script order; seq2 = discrete proc order within the mapping).
-- Each procedure is one transaction; WHENEVER SQLERROR EXIT FAILURE stops the
-- chain at the first failure, so every later step runs success-only.
-- The CLI reads the SELECT lines below: keep one "SELECT <fn>() FROM DUAL;" per line.
WHENEVER SQLERROR EXIT FAILURE;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_stage() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_exc() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_log() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation_sts() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_stage('Indv', 'Member') FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_pty() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_rle() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_exc() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id_alt_id() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_stage() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_phn() FROM DUAL;
SELECT PKG_TTF.sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn_exc() FROM DUAL;
WHENEVER SQLERROR CONTINUE;
