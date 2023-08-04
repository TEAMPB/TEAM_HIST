# TEAM_HIST

Listings:

## Listing 1: Erstellen einer Demo-Tabelle

```sql
CREATE SEQUENCE hd_customers_seq;

CREATE TABLE hd_customers (
    hd_customer_id NUMBER DEFAULT ON NULL
                   hd_customers_seq.NEXTVAL 
                   CONSTRAINT hd_customers_id_pk PRIMARY KEY,
    customer_name VARCHAR2(100 CHAR),
    contact_number VARCHAR2(15 CHAR),
    created DATE NOT NULL,
    created_by VARCHAR2(255 CHAR) NOT NULL,
    updated DATE NOT NULL,
    updated_by VARCHAR2(255 CHAR) NOT NULL
);

CREATE OR REPLACE TRIGGER hd_customers_biu
BEFORE INSERT OR UPDATE ON hd_customers
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :new.created := SYSDATE;
        :new.created_by := 
              COALESCE(SYS_CONTEXT('APEX$SESSION','APP_USER')
                       ,USER);
    END IF;
    :new.updated := SYSDATE;
    :new.updated_by := 
              COALESCE(SYS_CONTEXT('APEX$SESSION','APP_USER')
                       ,USER);
END hd_customers_biu;
/
```

## Listing 2: Erstellen einer Tabelle für die Historisierung mit Gültigkeitszeitraum

```sql
CREATE TABLE hd_customers_hist (
    hd_customer_id NUMBER,
    customer_name VARCHAR2(100 CHAR),
    contact_number VARCHAR2(15 CHAR),
    created DATE,
    created_by VARCHAR2(255 CHAR),
    updated DATE,
    updated_by VARCHAR2(255 CHAR),
    hist_trans VARCHAR2(1 CHAR),
    valid_from TIMESTAMP,
    valid_until TIMESTAMP,
    invalidated_by VARCHAR2(255 CHAR),
    invalidation_trans VARCHAR2(255 CHAR)
);

```

## Listing 3: Erstellen eines Triggers für eine Historisierungstabelle mit Gültigkeitszeitraum

```sql
CREATE OR REPLACE TRIGGER HD_CUSTOMERS_BUD_HIST
BEFORE UPDATE OR DELETE ON HD_CUSTOMERS
FOR EACH ROW
DECLARE
   v_hist_trans VARCHAR2(1);
BEGIN
   IF UPDATING THEN
      v_hist_trans := 'U';
   END IF;

   IF DELETING THEN
      v_hist_trans := 'D';
   END IF;

   INSERT INTO HD_CUSTOMERS_HIST
      (hd_customer_id, customer_name, contact_number, created, 
       created_by, updated, updated_by, hist_trans, valid_from, 
       valid_until, invalidated_by, invalidation_trans)
   VALUES
      (:old.hd_Customer_ID, :old.Customer_Name, :old.Contact_Number,
       :old.created, :old.created_by, :old.updated, :old.updated_by,
       v_hist_trans,
       NVL(:old.updated, :old.created),
       SYSDATE,
       NVL(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER),
       v('APP_PAGE_ID') || ' (' || v('APP_PAGE_ALIAS') || ')');
END;
/
```

## Listing 4: Erstellen eines Package-Headers zum setzen und Lesen eines Gültigkeitsdatums

```sql
CREATE OR REPLACE PACKAGE TEAM_HIST AS
  PROCEDURE SET_HIST_DATE(p_date IN TIMESTAMP);
  FUNCTION GET_HIST_DATE RETURN TIMESTAMP;
END TEAM_HIST;
/
```

## Listing 5: Erstellen eines Package-Bodies zum setzen und Lesen eines Gültigkeitsdatums

```sql
CREATE OR REPLACE PACKAGE BODY TEAM_HIST AS
  g_hist_date TIMESTAMP;

  PROCEDURE SET_HIST_DATE(p_date IN TIMESTAMP) IS
  BEGIN
    g_hist_date := p_date;
  END SET_HIST_DATE;

  FUNCTION GET_HIST_DATE RETURN TIMESTAMP IS
  BEGIN
    RETURN coalesce(g_hist_date,sysdate+1);
  END GET_HIST_DATE;

END TEAM_HIST;
/
```

## Listing 6: Erstellen eines Views um historische Daten anzuzeigen

```sql
CREATE OR REPLACE VIEW V_HD_CUSTOMERS_HIST AS
SELECT *
FROM (
  SELECT t.*,
    'A' AS hist_trans,
    NVL(t.updated, t.created) AS valid_from,
    to_date('01.01.4000','dd.mm.yyyy') AS valid_until,
    NULL AS invalidated_by,
    NULL AS invalidation_trans
  FROM HD_CUSTOMERS t
  UNION ALL
  SELECT *
  FROM HD_CUSTOMERS_HIST
)
WHERE TEAM_HIST.GET_HIST_DATE >= valid_from
  AND TEAM_HIST.GET_HIST_DATE < valid_until;
```

## Listing 7: Beispieldaten

```sql
INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
VALUES ('Kunde A', '123456789');

INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
VALUES ('Kunde B', '987654321');

INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
VALUES ('Kunde C', '555555555');
```

## Listing 9: Ändern der Beispieldaten

```sql
UPDATE HD_CUSTOMERS
SET CONTACT_NUMBER = '111111111'
WHERE CUSTOMER_NAME = 'Kunde A';

```

## Listing 10: Ändern der Beispieldaten

```sql
DELETE FROM HD_CUSTOMERS
WHERE CUSTOMER_NAME = 'Kunde A';
```

## Listing 12: Ausgabe der Beispieldaten

```sql
exec team_hist.set_hist_date(to_date('<<hier das Passende Datum setzen>>','dd.mm.yyyy hh24:mi:ss'));

select * from V_HD_CUSTOMERS_HIST
```

## Listing 14: Erstellen einer Transaktions-Tabelle

```sql
CREATE SEQUENCE hd_transaction_seq;

CREATE TABLE hd_transaction (
    transaction_num    NUMBER,
    transaction_trans  VARCHAR2(255),
    created           DATE NOT NULL,
    created_by        VARCHAR2(255) NOT NULL,
    updated           DATE NOT NULL,
    updated_by        VARCHAR2(255) NOT NULL
);

CREATE OR REPLACE TRIGGER hd_transaction_biu
    BEFORE INSERT OR UPDATE 
    ON hd_transaction
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :new.created := sysdate;
        :new.created_by :=  
              COALESCE(sys_context('APEX$SESSION','APP_USER'),
                       user);
    END IF;
    :new.updated := sysdate;
    :new.updated_by := 
              COALESCE(sys_context('APEX$SESSION','APP_USER'),
                       user);
END;
```

## Listing 15: Erweitern der Tabellen um die Transaktion

```sql
ALTER TABLE HD_CUSTOMERS ADD transaction_num NUMBER;

TRUNCATE TABLE HD_CUSTOMERS;
DROP TABLE HD_CUSTOMERS_HIST;

CREATE TABLE HD_CUSTOMERS_HIST AS
SELECT t.*,
       CAST(NULL AS VARCHAR2(1))   AS hist_trans,
       CAST(NULL AS TIMESTAMP)     AS valid_from,
       CAST(NULL AS TIMESTAMP)     AS valid_until,
       CAST(NULL AS VARCHAR2(255)) AS invalidated_by,
       CAST(NULL AS VARCHAR2(255)) AS invalidation_trans,
       CAST(NULL AS NUMBER)        AS until_transaction_num
FROM HD_CUSTOMERS t
WHERE 1=0;
```

## Listing 16: Funktion um Ermitteln der Transaktionsnummer

```sql
/* Globale Variablen */
g_transaction_id VARCHAR2(255);
g_transaction_num NUMBER;

FUNCTION GET_TRANSACTION_NUM RETURN NUMBER IS
BEGIN
  IF DBMS_TRANSACTION.local_transaction_id IS NULL OR
     NVL(g_transaction_id,'#*') !=    
                        DBMS_TRANSACTION.local_transaction_id 
  THEN
        g_transaction_id := 
                        DBMS_TRANSACTION.local_transaction_id;
        INSERT INTO hd_transaction (transaction_num,
                                    transaction_trans)
        VALUES (hd_transaction_seq.NEXTVAL, 
                v('APP_PAGE_ID') 
                || ' (' || v('APP_PAGE_ALIAS') || ')')
        RETURNING transaction_num INTO g_transaction_num;
  END IF;
  RETURN g_transaction_num;
END;

```

## Listing 17: Trigger der Hist-Tabelle mit Transaktionsnummer

```sql
CREATE OR REPLACE TRIGGER HD_CUSTOMERS_BIUD_HIST
BEFORE INSERT OR UPDATE OR DELETE ON HD_CUSTOMERS
FOR EACH ROW
DECLARE
   v_hist_trans VARCHAR2(1);
BEGIN

   IF INSERTING OR UPDATING THEN
      :NEW.transaction_num := team_hist.GET_TRANSACTION_NUM;
   END IF;

   IF UPDATING THEN
      v_hist_trans := 'U';
   END IF;

   IF DELETING THEN
      v_hist_trans := 'D';
   END IF;

   IF NOT INSERTING THEN
       INSERT INTO HD_CUSTOMERS_hist
          (HD_CUSTOMER_ID, CUSTOMER_NAME, CONTACT_NUMBER, 
           CREATED, CREATED_BY, UPDATED, UPDATED_BY,
           TRANSACTION_NUM,
           hist_trans, valid_from, valid_until, 
           invalidated_by, invalidation_trans,
           until_transaction_num)
       VALUES
          (:old.HD_CUSTOMER_ID, :old.CUSTOMER_NAME, 
           :old.CONTACT_NUMBER, :old.CREATED, :old.CREATED_BY, 
           :old.UPDATED, :old.UPDATED_BY, 
           :old.TRANSACTION_NUM,
           v_hist_trans,
           NVL(:old.updated, :old.created),
           SYSDATE,
           NVL(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER),
           v('APP_PAGE_ID') || ' (' || v('APP_PAGE_ALIAS') 
           || ')',
           team_hist.GET_TRANSACTION_NUM);
   END IF;           
END;
```

## Listing 18: Hist-Package um Abfrage der Transaktion erweitern

```sql
/* Globale Variablen */
g_hist_transaction_num NUMBER;

PROCEDURE SET_HIST_DATE(p_date IN TIMESTAMP) IS
BEGIN
  g_hist_date := p_date;
  g_hist_transaction_num := NULL;
END SET_HIST_DATE;

PROCEDURE SET_HIST_TRANSACTION(p_transaction_num IN NUMBER) IS
BEGIN
   g_hist_date := NULL;
   g_hist_transaction_num := p_transaction_num;
END SET_HIST_TRANSACTION;

FUNCTION GET_HIST_TRANSACTION_NUM RETURN NUMBER IS
BEGIN
  RETURN g_hist_transaction_num;
END;
```

## Listing 19: View zum Abfragen historischer Werte mit Transaktionsnummer

```sql
CREATE OR REPLACE VIEW V_HD_CUSTOMERS_HIST AS 
SELECT *
  FROM (
    SELECT t.*,
      'A' AS hist_trans,
      NVL(t.updated, t.created) AS valid_from,
      TO_DATE('01.01.4000','dd.mm.yyyy') AS valid_until,
      NULL AS invalidated_by,
      NULL AS invalidation_trans,
      1.0E125 AS until_transaction_num
    FROM HD_CUSTOMERS t
  UNION ALL
    SELECT *
      FROM HD_CUSTOMERS_HIST)
     WHERE (    TEAM_HIST.GET_HIST_TRANSACTION_NUM IS NULL
            AND TEAM_HIST.GET_HIST_DATE >= valid_from
            AND TEAM_HIST.GET_HIST_DATE < valid_until)
       OR  (    TEAM_HIST.GET_HIST_TRANSACTION_NUM IS NOT NULL
            AND TEAM_HIST.GET_HIST_TRANSACTION_NUM >= 
                                            transaction_num
            AND TEAM_HIST.GET_HIST_TRANSACTION_NUM < 
                                        until_transaction_num)          
```

## Listing 20: Erstellung der Testdaten

```sql
BEGIN
  -- Transaktion 1
  INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
                    VALUES ('Kunde C', '555555555');
  COMMIT;
  DBMS_SESSION.SLEEP(5);

  -- Transaktion 2
  INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
                    VALUES ('Kunde A', '123456789');
  DBMS_SESSION.SLEEP(5);
  INSERT INTO HD_CUSTOMERS (CUSTOMER_NAME, CONTACT_NUMBER)
                    VALUES ('Kunde B', '987654321');
  COMMIT;
END;

```

## Listing 21: Abfragen der historischen Stände

```sql
select customer_name,contact_number,transaction_num, 
       to_char(valid_from,'dd.mm.yy hh24:mi:ss') valid_from
  from v_hd_customers_hist
  order by valid_from;

```

## Listing 23: Abfragen mit Transaktionsnummer

```sql
exec team_hist.set_hist_transaction(<hier die Transahtionsnummer eintragen>);
```





