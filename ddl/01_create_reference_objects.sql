-- 01_create_reference_objects.sql -- placeholder definitions for the
-- 7 reference objects read by the lookup helpers (PKG_COMMON
-- fn_snow_helper40..47). These tables are EMPTY placeholders so the
-- helpers compile. REPLACE them with the real definitions (and data)
-- before any real ETL run. DBA PRE-ACTION: create a schema/user
-- literally named RDM first (helper44 references RDM.REF_PHN_AREA_CD
-- qualified). V_LOOKUP_CODE_VALUE is a TABLE here; in Oracle it is a
-- VIEW — replacing it later needs the table removed first.
-- NO DROP STATEMENTS IN THIS FILE. Teardown lives in drop_all.sql only.
-- Placeholder definitions for the 7 reference objects read by the lookup helpers
-- (common/02_snow_common_lookups.sql, fn_snow_helper40..47_common).
-- These objects have NO real definitions in this estate: the tables below are EMPTY
-- placeholders so the translated functions compile. Replace them with the real
-- definitions (and data) before any real ETL run. Column shapes are inferred from
-- how the lookup functions use them; see V1_MIRROR_REPORT.md.
--
-- DBA PRE-ACTION: create a schema/user literally named RDM first. Helper44
-- references RDM.REF_PHN_AREA_CD qualified; without schema RDM the function fails
-- at compile time with ORA-01918 / ORA-00942.
--
-- V_LOOKUP_CODE_VALUE is a TABLE here. In Oracle it is a VIEW; replacing it later
-- needs the table removed first, then CREATE VIEW.
--
-- Run once. Re-running requires removing the tables first (see drop_all.sql).

CREATE TABLE EXC_LOOKUP_CODE_VALUE (
    EXCEPTION_CODE VARCHAR2(4000),
    EXCEPTION_DESC VARCHAR2(4000),
    EXCEPTION_TYPE VARCHAR2(4000)
);

CREATE TABLE V_LOOKUP_CODE_VALUE (
    CODE_TYPE VARCHAR2(4000),
    SRC_SYS VARCHAR2(4000),
    SRC_CODE_VALUE VARCHAR2(4000),
    MSTR_CODE_VALUE VARCHAR2(4000)
);

CREATE TABLE REF_JUNK_NAME_LIST (
    NAME VARCHAR2(4000),
    EDIT_LIMITATION VARCHAR2(4000)
);

CREATE TABLE REF_MATCHCODE_DESC (
    MATCH_CODE VARCHAR2(4000),
    DESCRIPTION VARCHAR2(4000)
);

CREATE TABLE RDM.REF_PHN_AREA_CD (
    NPA_ID VARCHAR2(4000),
    SERVICE VARCHAR2(4000),
    IN_SERVICE VARCHAR2(4000),
    IN_SERVICE_DT DATE,
    COUNTRY VARCHAR2(4000)
);

CREATE TABLE LOOKUP_CODE_VALUE (
    CODE_TYPE VARCHAR2(4000),
    SRC_SYS VARCHAR2(4000),
    MSTR_REF_CODE VARCHAR2(4000),
    MSTR_REF_LABEL VARCHAR2(4000)
);

CREATE TABLE REF_DYLGHT_SVNGS_TM (
    DST TIMESTAMP
);
