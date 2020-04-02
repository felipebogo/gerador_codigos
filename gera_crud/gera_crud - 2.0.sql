-- release notes
-- 1.0 - Felipe Bogo - 28/11/2018 - nascimento
-- 1.1 - Felipe Bogo - 30/11/2018 - inclusão exemplo de lista json
-- 1.2 - Felipe Bogo - 03/12/2018 - Correção na quebra do dbms_output.put_line('');
-- 2.0 - Felipe Bogo - 19/12/2018 - Alterada a maneira de passar os CURSOR no lst
DECLARE 
  FUNCTION fCrudGenerator( ivTabela   VARCHAR2
                         , ivSchema   VARCHAR2
                         ) RETURN CLOB IS
    cnApplicationError CONSTANT     INTEGER := -20050;
    eApplicationError               EXCEPTION;
    PRAGMA EXCEPTION_INIT(eApplicationError,-20050);
    cSaida CLOB;
    
    vTabela   VARCHAR2(100);
    vPackage  VARCHAR2(100);
    vSchema   VARCHAR2(100);
    vSchemaTab VARCHAR2(100);
    vPk       VARCHAR2(100); 
    
    CURSOR cColunas(ivPk VARCHAR2 DEFAULT NULL) IS
      SELECT col.column_name
           , col.data_type
           , col.data_length
           , MAX(LENGTH(column_name)) over () maiorU
           , MAX(LENGTH(DECODE(data_type,'DATE',column_name,''))) over () maiorDU
           , MAX(LENGTH(REPLACe(column_name,'_',''))) over () maior
           , COUNT(1) over () total
           , NVL((SELECT 'S'
                    FROM dba_constraints c
                       , dba_cons_columns cc
                   WHERE c.table_name = col.table_name
                     AND cc.constraint_name = c.constraint_name
                     AND cc.column_name = col.column_name
                     AND cc.table_name = col.table_name
                     AND cc.owner = col.owner
                     AND cc.owner = c.owner                      
                     AND c.constraint_type = 'P'),'N') pk
           , CASE NULLABLE WHEN 'Y' THEN 'N' ELSE 'S' END obrigatorio
           , virtual_column
        FROM dba_tab_cols col
       WHERE col.table_name = vTabela
         AND (ivPk = col.column_name OR ivPk IS NULL)
         AND col.owner = vSchemaTab
         AND col.virtual_column = 'NO'
    ORDER BY COLUMN_ID;
    
    PROCEDURE pPrint( ivTexto     VARCHAR2
                    , ivTipoPrint VARCHAR2 DEFAULT 'VAR'
                    ) IS
    BEGIN
      -- Se quiser um comportamento diferente tem q implementar
      IF ivTipoPrint = 'DBMS' THEN
        DBMS_OUTPUT.PUT_LINE(ivTexto);
      ELSIF ivTipoPrint = 'VAR' THEN
        cSaida := cSaida || ivTexto||CHR(10);
      END IF;
    END pPrint;
    
    FUNCTION fGetTipoParam (ivTipo VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE ivTipo WHEN 'VARCHAR2' THEN 'v'
                         WHEN 'NUMBER' THEN   'n'
                         WHEN 'DATE' THEN     'd'
                         WHEN 'CLOB' THEN     'c' END;
    END fGetTipoParam;
    
    FUNCTION fTabela RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE WHEN vSchemaTab IS NOT NULL THEN LOWER(vSchemaTab)||'.' END || vTabela;
    END fTabela;
    
    FUNCTION fCapitalize(ivValor VARCHAR2) RETURN VARCHAR2 IS
      vString VARCHAR2(100);
    BEGIN
      FOR r IN (SELECT regexp_substr(sq.valColumn, CHR(91)||'^'||sq.valPipe||CHR(93)||'+', 1, level) colResult
                  FROM   ( SELECT LOWER(ivValor) valColumn
                                , '_'      valPipe
                             FROM   dual
                         ) sq
            CONNECT BY regexp_substr(sq.valColumn, CHR(91)||'^'||sq.valPipe||CHR(93)||'+', 1, level) is not null) LOOP
        vString := vString || INITCAP(r.colResult);
      END LOOP;
      RETURN vString;
    END fCapitalize;
    
    FUNCTION fMontaParam(ivColumnName VARCHAR2
                        ,ivDataType   VARCHAR2
                        ,ivOut        VARCHAR2 DEFAULT 'N'
                        ) RETURN VARCHAR2 IS
    BEGIN
      RETURN 'i'||CASE ivOut WHEN 'S' THEN 'o' END||fGetTipoParam(ivDataType)||fCapitalize(ivColumnName);
    END fMontaParam;
    
    FUNCTION fGetParamPk( ivDeclare VARCHAR2 DEFAULT 'N'
                        , ivNull    VARCHAR2 DEFAULT 'N'
                        , ivOut     VARCHAR2 DEFAULT 'N'
                        ) RETURN VARCHAR2 IS
      vParams   VARCHAR2(32000);
      vTpParam VARCHAR2(32000);
    BEGIN
      IF ivOut = 'S' THEN
        vTpParam := 'io';
      ELSE
        vTpParam := 'i';
      END IF;
      FOR r IN cColunas(vPk) LOOP
        vParams := vTpParam||fGetTipoParam(r.data_type)||
                   fCapitalize(r.column_name)||
                   CASE ivDeclare WHEN 'S' THEN 
                     ' IN '||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE'
                   END ||
                   CASE ivNull WHEN 'S' THEN ' DEFAULT NULL' END;
      END LOOP;
      RETURN vParams;
    END fGetParamPk;
    
    FUNCTION fGetParametrosLst(inRecuo NUMBER DEFAULT 0) RETURN VARCHAR2 IS
      vParams VARCHAR2(32000);
      vRecuo  VARCHAR2(32000);
      nMaior  NUMBER;
    BEGIN
      vRecuo := LPAD(' ',inRecuo,' ');
      FOR r IN cColunas LOOP
        vParams := vParams|| vRecuo||                 
                   ', '||RPAD('i'||fGetTipoParam(r.data_type)||
                   fCapitalize(r.column_name),r.maior+3,' ')||
                   ' IN '||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE DEFAULT NULL' ||CHR(10);
        nMaior := r.maior;
      END LOOP;
        nMaior := nMaior + 3;
        vParams := vParams || vRecuo || ', '||RPAD('ivOrder',nMaior)||' IN VARCHAR2'||CHR(10)||
                              vRecuo || ', '||RPAD('inPagNum',nMaior)||' IN NUMBER'||CHR(10)||
                              vRecuo || ', '||RPAD('inPagTam',nMaior)||' IN NUMBER'||CHR(10);
      RETURN '('||SUBSTR(vParams,inRecuo+2)||vRecuo||')';
    END fGetParametrosLst;
    
    FUNCTION fGetParametrosType(inRecuo NUMBER DEFAULT 0) RETURN VARCHAR2 IS
      vParams VARCHAR2(32000);
      vRecuo  VARCHAR2(32000);
      nMaior  NUMBER;
    BEGIN
      vRecuo := LPAD(' ',inRecuo,' ');
      FOR r IN cColunas LOOP
        vParams := vParams|| vRecuo||
                   ', '||RPAD(lower(r.column_name),r.maiorU+1,' ');
        IF r.data_type IN ('DATE') THEN
          vParams := vParams|| 'VARCHAR2(100) '||CHR(10);
        ELSE
          vParams := vParams|| lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE ' ||CHR(10);
        END IF;
        nMaior := r.maiorU;
      END LOOP;
        nMaior := nMaior;
        vParams := vParams || vRecuo || ', '||RPAD('total_registros',nMaior)||' NUMBER'||CHR(10)||
                              vRecuo || ', '||RPAD('nro_linha',nMaior)||' NUMBER'||CHR(10);
      RETURN '('||SUBSTR(vParams,inRecuo+2)||vRecuo||')';
    END fGetParametrosType;
    
    FUNCTION fGetParametrosInsUpd(inRecuo NUMBER DEFAULT 0,ivOperacao VARCHAR2 DEFAULT 'I') RETURN VARCHAR2 IS
      vParams VARCHAR2(32000);
      vTpParam VARCHAR2(32000);
      vIn      VARCHAR2(32000);
    BEGIN
      FOR r IN cColunas LOOP
        IF ivOperacao = 'IA' THEN
          IF r.column_name = vPk THEN
            vIn := 'io';
            vTpParam := ' IN OUT ';
          ELSE
            vIn := 'i';
            vTpParam := ' IN ';
          END IF;
          vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                     ', '||RPAD(vIn||fGetTipoParam(r.data_type)||
                     fCapitalize(r.column_name),r.maior+3,' ')||
                     RPAD(vTpParam,8,' ')||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE'||
                     CASE WHEN r.column_name <> vPk THEN ' DEFAULT NULL' end||CHR(10);
          IF r.column_name <> vPk THEN
            vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                       ', '||RPAD('i'||'b'||
                       fCapitalize(r.column_name),r.maior+3,' ')||
                       ' IN     NUMBER DEFAULT 0'||CHR(10);
          END IF;
        ELSIF ivOperacao = 'U' THEN
          vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                     --', '||RPAD('i'||fGetTipoParam(r.data_type)||
                     --fCapitalize(r.column_name),r.maior+3,' ')||
                     ', '||RPAD(fMontaParam(r.column_name,r.data_type),r.maior+3,' ')||
                     ' IN '||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE'||
                     ' DEFAULT NULL'||CHR(10);
          IF r.column_name <> vPk THEN
            vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                       ', '||RPAD('i'||'b'||
                       fCapitalize(r.column_name),r.maior+3,' ')||
                       ' IN NUMBER DEFAULT 0'||CHR(10);
          END IF;
        ELSIF (r.column_name <> vPk AND ivOperacao = 'I') THEN
          vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                     --', '||RPAD('i'||fGetTipoParam(r.data_type)||
                     --fCapitalize(r.column_name),r.maior+3,' ')||
                     ', '||RPAD(fMontaParam(r.column_name,r.data_type),r.maior+3,' ')||
                     ' IN '||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE'||
                     CASE NVL(r.obrigatorio,'N') WHEN 'N' THEN ' DEFAULT NULL' END||CHR(10);
        END IF;
      END LOOP;
      RETURN '('||SUBSTR(vParams,inRecuo+2)||LPAD(' ',inRecuo,' ')||')';
    END fGetParametrosInsUpd;
    
    FUNCTION fGetParametros(inRecuo NUMBER DEFAULT 0) RETURN VARCHAR2 IS
      vParams VARCHAR2(4000);
    BEGIN
      FOR r IN cColunas LOOP
        vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                   ', '||RPAD('i'||fGetTipoParam(r.data_type)||
                   fCapitalize(r.column_name),r.maior+3,' ')||
                   ' IN '||r.data_type||
                   CASE r.pk WHEN 'S' THEN ' DEFAULT NULL' END||CHR(10);
      END LOOP;
      RETURN '('||SUBSTR(vParams,inRecuo+2)||LPAD(' ',inRecuo,' ')||')';
    END fGetParametros;
   
    FUNCTION fGetCamposMetodo RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      vInds   VARCHAR2(32000);
      nTam    NUMBER;
    BEGIN
      FOR r IN cColunas LOOP
        nTam := r.maiorU;
        IF r.pk = 'N' AND r.virtual_column = 'NO' THEN
          vCampos := vCampos|| '    rRow.'||RPAD(LOWER(r.column_name),nTam,' ')||':= '||fMontaParam(r.column_name,r.data_type)||';'||CHR(10);
          vInds   := vInds  || '    rInd.'||RPAD(LOWER(r.column_name),nTam,' ')||':= NVL(nInsert,ib'||fCapitalize(r.column_name)||') = 1;'||CHR(10);
        END if;
      END LOOP;
      
      vCampos := '    rRow.'||RPAD(LOWER(vPk),nTam,' ')||':= '||fGetParamPk(ivOut=>'S')||';'||CHR(10)||vCampos;
      vInds   := '    rInd.'||RPAD(LOWER(vPk),nTam,' ')||':= nInsert = 1;'||CHR(10)||vInds;
      
      RETURN vCampos ||CHR(10)|| vInds;
    END fGetCamposMetodo;
  
    FUNCTION fMontaMetodo(inRecuo NUMBER,ivOperacao VARCHAR2 DEFAULT 'I') RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      nRecuo  NUMBER;
      vFlPk   VARCHAR2(10);
    BEGIN
      nRecuo := inRecuo+10;
      FOR r IN cColunas LOOP
        vFlPk := NULL;
        IF r.column_name = vPk THEN 
          vFlPk := 'S';
        END IF;
        vCampos := vCampos|| LPAD(' ',nRecuo,' ')||                 
                   ', '||RPAD(fMontaParam(r.column_name,r.data_type,vFlPk),r.maior+3,' ')||
                   ' => ';
        IF r.column_name = vPk THEN
          IF ivOperacao = 'I' THEN
            vCampos := vCampos || 'nPk'||CHR(10);
          ELSE
            vCampos := vCampos || 'rRow.'||lower(vPk)||CHR(10);
          END IF;
        ELSE
          vCampos := vCampos || fMontaParam(r.column_name,r.data_type)||CHR(10);
          IF ivOperacao = 'U' THEN
            vCampos := vCampos|| LPAD(' ',nRecuo,' ')||                 
                       ', '||RPAD('ib'||fCapitalize(r.column_name),r.maior+3,' ')||
                       ' => '||'ib'||fCapitalize(r.column_name)||CHR(10);
          END IF;
        END IF;
      END LOOP;
      RETURN 'pIns'||fCapitalize(vTabela)||'('||SUBSTR(vCampos,nRecuo+2)||LPAD(' ',nRecuo,' ')||');';
    END fMontaMetodo;
    
    FUNCTION fGetFiltro( ivCol VARCHAR2 
                         , ivTipo VARCHAR2
                         ) RETURN VARCHAR2 IS
      vFiltro VARCHAR2(32000);
      vParam VARCHAR2(32000);
      vBinds VARCHAR2(32000);
    BEGIN
      vParam := fMontaParam(ivCol,ivTipo);
      vBinds := '        tBinds(tBinds.COUNT + 1).nome := '''||vParam||''';
';
      IF UPPER(ivTipo) = 'NUMBER' THEN
        vBinds := vBinds ||
'        tBinds(tBinds.COUNT).n := '||vParam||';
        tBinds(tBinds.COUNT).tipo := ''N'';';
      ELSIF UPPER(ivTipo) IN ('VARCHAR2','CLOB') THEN
        vBinds := vBinds ||
'        tBinds(tBinds.COUNT).v := '||vParam||';
        tBinds(tBinds.COUNT).tipo := ''V'';';
      ELSIF UPPER(ivTipo) = 'DATE' THEN
        vBinds := vBinds ||
'        tBinds(tBinds.COUNT).d := '||vParam||';
        tBinds(tBinds.COUNT).tipo := ''D'';';
      END IF;
      IF ivTipo IN ('NUMBER','DATE') THEN
        vFiltro := ' AND '||lower(ivCol);
        vFiltro := vFiltro||' = :'||vParam;
      ELSIF ivTipo IN ('VARCHAR2','CLOB') THEN
        IF SUBSTR(ivCol,1,2) IN ('DS','NO') THEN
          vFiltro := ' AND UPPER('||lower(ivCol)||')';
          vFiltro := vFiltro||' LIKE ''''%''''|| UPPER(:'||vParam||') || ''''%'''' ';
        ELSE
          vFiltro := ' AND '||lower(ivCol);
          vFiltro := vFiltro||' = :'||vParam;
        END IF;
      END IF;
      vFiltro := 
'      IF '||vParam||' IS NOT NULL THEN
        vSql := vSql ||'''||vFiltro||' ''; '||chr(10)||chr(10)||
        vBinds||' 
      END IF;
';
      RETURN vFiltro;
    END fGetFiltro;
    
    FUNCTION fGetBinds RETURN VARCHAR2 IS
      vBinds   VARCHAR2(32000);
      nRecuo   NUMBER;
    BEGIN
      nRecuo := 29;
      FOR r IN cColunas LOOP
        vBinds := vBinds || chr(10)||rpad(' ',nRecuo,' ')|| ', '||fMontaParam(r.column_name,r.data_type);
      END LOOP;
      vBinds := SUBSTR(vBinds,nRecuo+4);
      RETURN vBinds;
    END fGetBinds;
    
    FUNCTION fGetListaJsonExemplo RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'        -- exemplo
        oLstAux := new pljson_list;
        FOR r IN (SELECT ''campo ''||level c1
                       , ''campo ''||(level * 10) c2
                    FROM dual
              CONNECT BY LEVEL <= 5
                    )
        LOOP
          oObjAux := new pljson;
          oObjAux.put(''ivC1'',r.c1);
          oObjAux.put(''ivC2'',r.c2);
          oLstAux.append(oObjAux.to_json_value);
        END LOOP endereco;
        oObj.put(''ilExemplo'',oLstAux);
';
      RETURN vRet;
    END fGetListaJsonExemplo;
    
    FUNCTION fGetCamposJson RETURN VARCHAR2 IS
      vCampos   VARCHAR2(32000);
    BEGIN
      FOR r IN cColunas LOOP
        vCampos := vCampos || '        oObj.put('||RPAD(''''||fMontaParam(r.column_name,r.data_type)||'''',r.maior+4,' ')||', rReg.'||lower(r.column_name)||'); '||chr(10);
      END LOOP;
      RETURN vCampos;
    END fGetCamposJson;
    
    FUNCTION fGetQuery RETURN VARCHAR2 IS
      vSelect  VARCHAR2(32000);
      vFiltros VARCHAR2(32000);
      nRecuo   NUMBER;
    BEGIN
      nRecuo := 20;
      FOR r IN cColunas LOOP
        vSelect := vSelect || chr(10)||rpad(' ',nRecuo,' ')||', ';
        IF r.data_type = 'DATE' THEN
          vSelect := vSelect || RPAD('TO_CHAR('||lower(r.column_name)||',''''DD/MM/RRRR'''')',GREATEST(r.maiorDU+25,r.maiorU),' ');
        ELSE
          vSelect := vSelect || RPAD(lower(r.column_name),GREATEST(r.maiorDU+25,r.maiorU+1),' ');
        END IF;
        vSelect := vSelect || fMontaParam(r.column_name,r.data_type);
        vFiltros := vFiltros || fGetFiltro(r.column_name,r.data_type);
      END LOOP;
      --vSelect := vSelect || chr(10)||rpad(' ',nRecuo,' ')||', count(1) over() qtdeTotal';
      vSelect := SUBSTR(vSelect,nRecuo+4);
      
      vSelect := 
'      vSql := ''SELECT '||vSelect||'
                 FROM '||lower(vSchemaTab)||'.'||lower(vTabela)||' 
                WHERE 1 = 1 '';
'||vFiltros;
      
      RETURN vSelect;
    END fGetQuery;
    
    FUNCTION fInsUpdPl RETURN VARCHAR2 IS
      vRet  VARCHAR2(32000);
      nTam  NUMBER;   
    BEGIN
      nTam := length(fCapitalize(vTabela));
      vRet := 
'  PROCEDURE pIns'||fCapitalize(vTabela)||fGetParametrosInsUpd(nTam+16,'IA')||' IS 
    rRow cg$'||LOWER(vTabela)||'.cg$row_type;
    rInd cg$'||LOWER(vTabela)||'.cg$ind_type;      
    nInsert NUMBER;
  BEGIN
    nInsert := CASE WHEN '||fGetParamPk(ivOut=>'S')||' IS NULL THEN 1 END;
    
'||fGetCamposMetodo||'
    IF nInsert = 1  THEN
      cg$'||LOWER(vTabela)||'.ins(rRow, rInd);
    ELSE
      cg$'||LOWER(vTabela)||'.upd(rRow, rInd);
    END IF;
    
    '||fGetParamPk(ivOut=>'S')||' := rRow.'||lower(vPk)||';
  END pIns'||fCapitalize(vTabela)||';
';
      RETURN vRet;
    END fInsUpdPl;
    
    FUNCTION fDelPl RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet :=
'  PROCEDURE pDel'||fCapitalize(vTabela)||'('||fGetParamPk('S')||') IS 
    rPk  cg$'||LOWER(vTabela)||'.cg$pk_type;
  BEGIN
    rPk.'||lower(vPk)||' := '||fGetParamPk||';
    cg$'||LOWER(vTabela)||'.del(rPk);
  END pDel'||fCapitalize(vTabela)||';
';
      RETURN vRet;
    END fDelPl;
    
    FUNCTION fLst RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION lst'||fGetParametrosLst(14)||' RETURN CLOB IS
    tBinds   pljson_sql.t_binds;
    vSql     VARCHAR2(32000);
    cRet     CLOB;
    oRet     PLJSON;
    oObj     PLJSON;
    oObjAux  PLJSON;
    oLst     PLJSON_LIST := NEW PLJSON_LIST;
    oLstAux  PLJSON_LIST;
    oData    PLJSON;
    cCur     SYS_REFCURSOR;
    
    TYPE rec_reg IS RECORD
    '||fGetParametrosType(4)||';
    rReg rec_reg;
    
  BEGIN
    BEGIN      
'||fGetQuery||'   
      
      cCur := pljson_sql.getCursorFromSql(ivSql          => vSql
                                         ,itBinds        => tBinds
                                         ,inOffset       => inPagNum
                                         ,inFetchFirst   => inPagTam
                                         ,ivOrderByRn    => NVL(ivOrder,'' 1 DESC '')
                                         );                   
      LOOP
      FETCH cCur INTO rReg;
      EXIT WHEN ccur%NOTFOUND;
        oObj := NEW PLJSON;
'||fGetCamposJson||CHR(10)||fGetListaJsonExemplo||'
        oLst.append(oObj.to_json_value);
      END LOOP vistos;
      oData := NEW PLJSON;
      oRet  := NEW PLJSON;
      oData.put(''lista'',oLst);
      oData.put(''totalRegistros'', nvl(rReg.total_registros,0));
      oRet.put(''data'',oData);
      CLOSE cCur;
      oRet.to_clob(cRet,spaces => true);
      
    EXCEPTION
      WHEN eApplicationError THEN
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''')
                                            );
      WHEN OTHERS THEN
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace
                                            );
    END;

    RETURN cRet;
  END lst;
';
      RETURN vRet;
    END fLst;
    
    FUNCTION fIns RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
      nTam  NUMBER;   
    BEGIN
      nTam := length(fCapitalize(vTabela));
      vRet := 
'  FUNCTION ins'||fGetParametrosInsUpd(14,'I')||' RETURN CLOB IS
    cRet CLOB;
    nPk  NUMBER;
  BEGIN
    BEGIN
      '||fMontaMetodo(nTam,'I')||'
      COMMIT;

      cRet := pkg_sisp_util_json.getStatus(ivStatus => ''ok''
                                          ,ivMsg    => ''Registo incluído com sucesso.''
                                          ,inId     => nPk
                                          );
    EXCEPTION
      WHEN eApplicationError THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''')
                                            );
      WHEN OTHERS THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace
                                            );
    END;

    RETURN cRet;
  END ins;
';
      RETURN vRet;
    END fIns;
    
    FUNCTION fUpd RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
      nTam  NUMBER;   
    BEGIN
      nTam := length(fCapitalize(vTabela));
      vRet := 
'  FUNCTION upd'||fGetParametrosInsUpd(14,'U')||' RETURN CLOB IS
    cRet CLOB;
    rRow cg$'||LOWER(vTabela)||'.cg$row_type;
  BEGIN
    BEGIN
      rRow.'||lower(vPk)||' := '||fGetParamPk||';
      '||fMontaMetodo(nTam,'U')||'
      COMMIT;

      cRet := pkg_sisp_util_json.getStatus(ivStatus => ''ok''
                                          ,ivMsg    => ''Registo alterado com sucesso.''
                                          ,inId     => '||fGetParamPk||'
                                          );
    EXCEPTION
      WHEN eApplicationError THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''')
                                            ,inId     => '||fGetParamPk||'
                                            );
      WHEN OTHERS THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus(ivStatus => ''error''
                                            ,ivMsg    => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace
                                            ,inId     => '||fGetParamPk||'
                                            );
    END;

    RETURN cRet;
  END upd;
';
      RETURN vRet;
    END fUpd;
    
    FUNCTION fDel RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION del('||fGetParamPk(ivDeclare=>'S')||') RETURN CLOB IS
    cRet CLOB;
  BEGIN
    BEGIN
      pDel'||fCapitalize(vTabela)||'('||fGetParamPk||');

      COMMIT;

      cRet := pkg_sisp_util_json.getStatus(ivStatus => ''ok''
                                          ,ivMsg    => ''Registo apagado com sucesso.''
                                          );
    EXCEPTION
      WHEN eApplicationError THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus( ivStatus => ''error''
                                            , ivMsg    => REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''')
                                            , inId     => '||fGetParamPk||'
                                            );
      WHEN OTHERS THEN
        ROLLBACK;
        cRet := pkg_sisp_util_json.getStatus( ivStatus => ''error''
                                            , ivMsg    => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace
                                            , inId     => '||fGetParamPk||'
                                            );
    END;
    RETURN cRet;
  END del;';
      RETURN vRet;
    END fDel;
    
  BEGIN
    vTabela   := UPPER(ivTabela);
    vSchemaTab := UPPER(ivSchema);
    vSchema   := vSchemaTab||'_APP';
    vPackage  := 'PKG_'||REPLACE(vTabela,'TB_','');
  
    BEGIN
      BEGIN
        SELECT cc.column_name
          INTO vPk
          FROM dba_constraints c
             , dba_cons_columns cc
         WHERE c.table_name = vTabela
           AND c.owner = vSchemaTab
           AND cc.constraint_name = c.constraint_name
		       AND cc.table_name = c.table_name
           AND cc.owner = c.owner
           AND c.constraint_type = 'P';
      EXCEPTION
        WHEN TOO_MANY_ROWS THEN
		  RAISE_APPLICATION_ERROR(cnApplicationError,'A tabela '||vTabela||' existe em mais de um schema. favor especificar o schema.');
		WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(cnApplicationError,SQLERRM);
      END;
  
      -- pks
      pPrint('CREATE OR REPLACE PACKAGE '||lower(vSchema)||'.'||lower(vPackage)||' IS');
        pPrint('  cnApplicationError CONSTANT     INTEGER := -20050;');
        pPrint('  eApplicationError               EXCEPTION;');
        pPrint('  PRAGMA EXCEPTION_INIT(eApplicationError,-20050);'||CHR(10));  
      
        pPrint('  FUNCTION lst'||fGetParametrosLst(14)||' RETURN CLOB;'||CHR(10));  
      
        pPrint('  FUNCTION ins'||fGetParametrosInsUpd(14)||' RETURN CLOB;'||CHR(10));  
      
        pPrint('  FUNCTION upd'||fGetParametrosInsUpd(14,'U')||' RETURN CLOB;'||CHR(10));  
        
        pPrint('  FUNCTION del('||fGetParamPk(ivDeclare=>'S')||') RETURN CLOB;'||CHR(10));  
      
      pPrint('END;'||CHR(10)||'/'||CHR(10));
    
      -- pkb
      pPrint('CREATE OR REPLACE PACKAGE BODY '||LOWER(vSchema)||'.'||LOWER(vPackage)||' IS
  ');
      
        -- PROCEDURE pInsUpd
        pPrint(fInsUpdPl);
        
        -- PROCEDURE pDelPl
        pPrint(fDelPl);
      
        -- FUNCTION lst
        pPrint(fLst);
        
        -- FUNCTION ins
        pPrint(fIns);
        
        -- FUNCTION upd
        pPrint(fUpd);
        
        -- FUNCTION del
        pPrint(fDel);
     
      pPrint('END;'||CHR(10)||'/'||CHR(10));
  
      pPrint('GRANT EXECUTE ON '||LOWER(vSchema)||'.'||LOWER(vPackage)||' TO PUBLIC'||CHR(10)||'/');
  
      pPrint('CREATE OR REPLACE PUBLIC SYNONYM '||LOWER(vPackage)||' FOR '||LOWER(vSchema)||'.'||LOWER(vPackage)||''||CHR(10)||'/');
    END;
    RETURN cSaida;
  END fCrudGenerator;
BEGIN
  DECLARE
    nTam    PLS_INTEGER;
    nTamMin PLS_INTEGER;
    nPos    PLS_INTEGER;
    nPosQ   PLS_INTEGER;
    nTamQ   PLS_INTEGER;
    cResult CLOB;
  BEGIN
    cResult := fCrudGenerator( ivTabela   => upper('&tabela')
                              , ivSchema   => upper('&schema')
                              );
    /*cResult := fCrudGenerator( ivTabela   => upper('tb_aipex_proposta')
                              , ivSchema   => upper('aipex')
                              );*/
    nTamMin := 30000;
    nTam := 32000;
    nPos := 1;

    WHILE nPos < dbms_lob.getlength ( cResult ) LOOP
      nPosQ := dbms_lob.instr(lob_loc => cResult,
                              pattern => chr(10),
                              offset  => nPos+nTamMin-1,
                              nth     => 1);
      nTamQ := nPosQ - nPos;
      IF dbms_lob.getlength ( cResult ) - nPos > nTam AND nPosQ > 0 AND nTamQ <= nTam THEN
        dbms_output.put_line ( dbms_lob.substr ( cResult, nTamQ, nPos ) );
        nPos := nPos + nTamQ+1;
      ELSE
        dbms_output.put_line ( dbms_lob.substr ( cResult, nTam, nPos ) );
        nPos := nPos + nTam;
      END IF;
    END LOOP;
  END;
END;
/
