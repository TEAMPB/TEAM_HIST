CREATE SEQUENCE hd_transaction_seq;

CREATE TABLE "HD_TRANSACTION" (
    "TRANSACTION_NUM"   NUMBER,
    "TRANSACTION_TRANS" VARCHAR2(255 BYTE),
    "CREATED"           DATE
        NOT NULL ENABLE,
    "CREATED_BY"        VARCHAR2(255 BYTE) NOT NULL,
    "UPDATED"           DATE
        NOT NULL ENABLE,
    "UPDATED_BY"        VARCHAR2(255 BYTE) NOT NULL
);

CREATE OR REPLACE EDITIONABLE TRIGGER "HD_TRANSACTION_BIU" BEFORE
    INSERT OR UPDATE ON hd_transaction
    FOR EACH ROW
BEGIN
    IF inserting THEN
        :new.created := sysdate;
        :new.created_by := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    END IF;

    :new.updated := sysdate;
    :new.updated_by := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
END hd_customers_biu;
/

ALTER TRIGGER "DEMOS"."HD_TRANSACTION_BIU" ENABLE;