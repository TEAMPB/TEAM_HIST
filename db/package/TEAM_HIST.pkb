create or replace PACKAGE BODY TEAM_HIST AS
  g_hist_date TIMESTAMP;
  g_hist_transaction_num number;
  g_transaction_id varchar2(255);
  g_transaction_num number;

  PROCEDURE SET_HIST_DATE(p_date IN TIMESTAMP) IS
  BEGIN
    g_hist_date := p_date;
    g_hist_transaction_num := null;
  END SET_HIST_DATE;
  
  PROCEDURE SET_HIST_TRANSACTION(p_tsansaction_num IN number) is
  begin
     g_hist_date := null;
     g_hist_transaction_num := p_tsansaction_num;
  end;
  
  FUNCTION GET_HIST_TRANSACTION_NUM RETURN NUMBER is
  begin
    return g_hist_transaction_num;
  end;

  FUNCTION GET_HIST_DATE RETURN TIMESTAMP IS
  BEGIN
    RETURN coalesce(g_hist_date,sysdate+1);
  END GET_HIST_DATE;

procedure GENERATE_HIST_TABLE(p_table_name in varchar2)
is
begin
   begin
          execute immediate 'alter table '||p_table_name||' add transaction_num number'; 
   exception
      when others then null;
   end; 

    execute immediate 'create table '||p_table_name||'_hist as
       select t.*,
              CAST(null AS VARCHAR2(1))   as hist_trans,
              CAST(null as timestamp)     as valid_from,
              CAST(null as timestamp)     as valid_until,
              CAST(null AS VARCHAR2(255)) as invalidated_by,
              CAST(null AS VARCHAR2(255)) as invalidation_trans,
              CAST(null as number)        as until_transaction_num
         from '||p_table_name||' t
        where 1=0'; 
    
    
end;

procedure GENERATE_HIST_TRIGGER(p_table_name in varchar2)
is 
  v_cols varchar2(32767 byte);
  v_old_cols varchar2(32767 byte);
  v_sql varchar2(32767 byte);
begin
  select listagg(column_name,', ') within group (order by column_id),
         listagg(':old.'||column_name,', ') within group (order by column_id)
    into v_cols,
         v_old_cols
    from user_tab_columns 
   where table_name = p_table_name;    

   v_sql := q'~
CREATE OR REPLACE TRIGGER ~'||p_table_name||q'~_BIUD_HIST
BEFORE INSERT or UPDATE OR DELETE ON ~'||p_table_name||q'~
FOR EACH ROW
DECLARE
   v_hist_trans VARCHAR2(1);
BEGIN
   
   IF INSERTING or UPDATING THEN
      :NEW.transaction_num := team_hist.GET_TRANSACTION_NUM;
   END IF;   
   
   IF UPDATING THEN
      v_hist_trans := 'U';
   END IF;

   IF DELETING THEN
      v_hist_trans := 'D';
   END IF;

   IF not INSERTING THEN
       INSERT INTO ~'||p_table_name||q'~_hist
          (~'||v_cols||q'~
           ,hist_trans, valid_from, valid_until, invalidated_by, invalidation_trans,
           until_transaction_num)
       VALUES
          (~'||v_old_cols||q'~,
           v_hist_trans,
           NVL(:old.updated, :old.created),
           SYSDATE,
           NVL(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER),
           v('APP_PAGE_ID') || ' (' || v('APP_PAGE_ALIAS') || ')',
           team_hist.GET_TRANSACTION_NUM);
   END IF;           
END;
~';
   execute immediate v_sql;
end;

procedure GENERATE_HIST_VIEW(p_table_name in varchar2)
is begin
    execute immediate q'~
    CREATE OR REPLACE VIEW V_~'||p_table_name||q'~_HIST AS    
    SELECT *
    FROM (
      SELECT t.*,
        'A' AS hist_trans,
        NVL(t.updated, t.created) AS valid_from,
        to_date('01.01.4000','dd.mm.yyyy') AS valid_until,
        NULL AS invalidated_by,
        NULL AS invalidation_trans,
        1.0E125 as until_transaction_num
      FROM ~'||p_table_name||q'~ t
      UNION ALL
      SELECT *
      FROM ~'||p_table_name||q'~_HIST
    )
    WHERE (     TEAM_HIST.GET_HIST_TRANSACTION_NUM is null
            and TEAM_HIST.GET_HIST_DATE >= valid_from
            and TEAM_HIST.GET_HIST_DATE < valid_until)
       or  (    TEAM_HIST.GET_HIST_TRANSACTION_NUM is not null
            and TEAM_HIST.GET_HIST_TRANSACTION_NUM >= transaction_num
            and TEAM_HIST.GET_HIST_TRANSACTION_NUM < until_transaction_num)        
    ~';

end;




function GET_TRANSACTION_NUM return number
is 
begin
  if DBMS_TRANSACTION.local_transaction_id is null or
     nvl(g_transaction_id,'#*') !=  DBMS_TRANSACTION.local_transaction_id
  then
  
      g_transaction_id := DBMS_TRANSACTION.local_transaction_id;
      insert into hd_transaction (transaction_num,transaction_trans)
             values (hd_transaction_seq.nextval,v('APP_PAGE_ID') || ' (' || v('APP_PAGE_ALIAS') || ')'||' - '||DBMS_TRANSACTION.local_transaction_id)
             return transaction_num into g_transaction_num;
  end if;
  return g_transaction_num;  
end;    

procedure update_hist_struct
is
begin
  for i in c_hist_tabs.FIRST .. c_hist_tabs.LAST
  loop
     dbms_output.put_line(c_hist_tabs(i));
     begin
       GENERATE_HIST_TABLE(c_hist_tabs(i));
       dbms_output.put_line(' Tabelle erstellt.');
     exception
       when others then 
         dbms_output.put_line(' Tabelle wurde nicht erstellt!');
     end;
     GENERATE_HIST_TRIGGER(c_hist_tabs(i));
     dbms_output.put_line(' Trigger erstellt.');
     GENERATE_HIST_VIEW(c_hist_tabs(i));     
     dbms_output.put_line(' View erstellt.');  
  end loop;
end;  
END TEAM_HIST;