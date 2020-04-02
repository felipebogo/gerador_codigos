-- release notes
-- 1.0 - Felipe Bogo - 28/11/2018 - nascimento
-- 2.0 - Jonathan Cubillos - 14/01/2019 - Ajustes para a API (WSO2)
DECLARE 
  FUNCTION fCrudGenerator( ivTabela   VARCHAR2
                         , ivSchema   VARCHAR2
                         , ivServico  VARCHAR2
                         ) RETURN CLOB IS
    cnApplicationError CONSTANT     INTEGER := -20050;
    eApplicationError               EXCEPTION;
    PRAGMA EXCEPTION_INIT(eApplicationError,-20050);
    cSaida CLOB;
    
    vTabela   VARCHAR2(100);
    vPackage  VARCHAR2(100);
    vSchema   VARCHAR2(100);
    vSchemaTab VARCHAR2(100);
    vServico  VARCHAR2(100);
    vPk       VARCHAR2(100); 
    
    CURSOR cColunas(ivPk VARCHAR2 DEFAULT NULL) IS
      SELECT col.column_name
           , col.data_type
           , col.data_length
           , MAX(LENGTH(column_name)) over () maiorU
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
      RETURN CASE ivTipo WHEN 'VARCHAR2'    THEN 'v'
                         WHEN 'NUMBER'      THEN 'n'
                         WHEN 'DATE'        THEN 'd'
                         WHEN 'BOOLEAN'     THEN 'b'
                         WHEN 'CLOB'        THEN 'c' END;
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
    
    FUNCTION fCapitalizeConversao(ivValor VARCHAR2) RETURN VARCHAR2 IS
        vString VARCHAR2(100);
    BEGIN
      vString := fCapitalize(ivValor);
      RETURN LOWER(substr(vString, 1, 1)) || substr(vString, 2, LENGTH(vString));
    END fCapitalizeConversao;
    
    FUNCTION fMontaParam(ivColumnName VARCHAR2
                        ,ivDataType   VARCHAR2
                        ,ivOut        VARCHAR2 DEFAULT 'N'
                        ) RETURN VARCHAR2 IS
    BEGIN
      RETURN 'i'||CASE ivOut WHEN 'S' THEN 'o' END||fGetTipoParam(ivDataType)||fCapitalize(ivColumnName);
    END fMontaParam;
    
    FUNCTION fMontaConversao(ivColumnName  VARCHAR2
                            ,ivDataType    VARCHAR2
                            ,inMaior       NUMBER
                            ,inSize        VARCHAR2 DEFAULT '100'
                            ) RETURN VARCHAR2 IS
    BEGIN
      RETURN RPAD(('i'||fGetTipoParam(ivDataType)||fCapitalize(ivColumnName)), inMaior + 3)||' := pkg_types_util.get'||INITCAP(ivDataType)||'(ivParam => '||fCapitalizeConversao(ivColumnName)||CASE WHEN ivDataType = 'VARCHAR2' THEN ', inSize => ' || inSize END|| ');' || CHR(10);
    END fMontaConversao;
    
    FUNCTION fGetParamPk( ivDeclare         VARCHAR2 DEFAULT 'N'
                        , ivDeclareInterno  VARCHAR2 DEFAULT 'N'
                        , ivConversao       VARCHAR2 DEFAULT 'N'
                        , ivNull            VARCHAR2 DEFAULT 'N'
                        , ivOut             VARCHAR2 DEFAULT 'N'
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
        vParams := CASE WHEN ivConversao = 'N' THEN vTpParam||fGetTipoParam(r.data_type) END ||
                   CASE ivConversao WHEN 'S' THEN fCapitalizeConversao(r.column_name) ELSE fCapitalize(r.column_name) END||
                   CASE ivDeclare WHEN 'S' THEN 
                     ' IN '||lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE'
                   END ||
                   CASE ivNull WHEN 'S' THEN ' DEFAULT NULL' END;
      END LOOP;
      RETURN vParams;
    END fGetParamPk;
    
    FUNCTION fGetParametrosLst(inRecuo NUMBER DEFAULT 0) RETURN VARCHAR2 IS
      vParams VARCHAR2(32000);
      vBloco  VARCHAR2(32000);
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
        vParams := vParams || vRecuo || ', '||RPAD('ivOrdem',nMaior)||' IN VARCHAR2'||CHR(10)||
                              vRecuo || ', '||RPAD('inPagNum',nMaior)||' IN NUMBER'||CHR(10)||
                              vRecuo || ', '||RPAD('inPagTam',nMaior)||' IN NUMBER'||CHR(10);
      
      vBloco := SUBSTR(vParams, 1, LENGTH(vParams) - 1);
      
      RETURN '('||SUBSTR(vBloco,inRecuo+2)||' )';
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
      vParams  VARCHAR2(32000);
      vBloco   VARCHAR2(32000);
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
      
      vBloco := SUBSTR(vParams, 1, LENGTH(vParams) - 1);
      
      RETURN '('||SUBSTR(vBloco,inRecuo+2)||' )';
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
    
    FUNCTION fGetParametrosConversao(inRecuo NUMBER DEFAULT 0, ivOperacao VARCHAR2 DEFAULT 'I') RETURN VARCHAR2 IS
      vParams VARCHAR2(32000);
      vBloco  VARCHAR2(32000);
      nMaior  NUMBER;
    BEGIN
      IF ivOperacao IN ('D','R') THEN
        FOR r IN cColunas(vPk) LOOP
            vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                       ', '||RPAD(fCapitalizeConversao(r.column_name),r.maior+3,' ')||
                       ' IN VARCHAR2'||CHR(10);
        END LOOP;
      ELSIF ivOperacao IN ('I','U','L') THEN
          FOR r IN cColunas LOOP
            IF NOT (ivOperacao = 'I' AND r.pk = 'S') THEN
                vParams := vParams|| LPAD(' ',inRecuo,' ')||                 
                           ', '||RPAD(fCapitalizeConversao(r.column_name),r.maior+3,' ')||
                           ' IN VARCHAR2'||
                           CASE WHEN r.obrigatorio = 'N' OR ivOperacao = 'L' THEN ' DEFAULT NULL' END||CHR(10);
                nMaior := r.maior;
            END IF;
          END LOOP;
          
          IF ivOperacao = 'L' THEN
              nMaior := nMaior + 3;
              vParams := vParams || LPAD(' ',inRecuo,' ') || ', '||RPAD('orderBy',nMaior)||' IN VARCHAR2'||CHR(10)||
                                    LPAD(' ',inRecuo,' ') || ', '||RPAD('pagIni',nMaior)||' IN VARCHAR2'||CHR(10)||
                                    LPAD(' ',inRecuo,' ') || ', '||RPAD('pagTam',nMaior)||' IN VARCHAR2'||CHR(10);
          END IF;
      END IF;
      
      vParams := SUBSTR(vParams, 1, LENGTH(vParams) - 1);
      vBloco := '('||SUBSTR(vParams,inRecuo+2)||' )';
      
      RETURN vBloco;
    END fGetParametrosConversao;
    
    FUNCTION fGetParametrosInternoConversao(inRecuo NUMBER DEFAULT 0, ivOperacao VARCHAR2 DEFAULT 'I') RETURN VARCHAR2 IS
      vParams VARCHAR2(4000);
      nMaior  NUMBER;
    BEGIN
      IF ivOperacao IN ('D','R') THEN
        FOR r IN cColunas(vPk) LOOP
            nMaior := r.maior + 3;
            vParams := vParams || LPAD(' ',inRecuo,' ') ||
                       'i'||fGetTipoParam(r.data_type)||
                       RPAD(fCapitalize(r.column_name), nMaior)||
                       lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE;'||
                       CHR(10);
        END LOOP;
      ELSIF ivOperacao IN ('I','U','L') THEN
          FOR r IN cColunas LOOP
            IF NOT (ivOperacao = 'I' AND r.pk = 'S') THEN
                nMaior := r.maior + 3;
                vParams := vParams || LPAD(' ',inRecuo,' ') ||
                           'i'||fGetTipoParam(r.data_type)||
                           RPAD(fCapitalize(r.column_name), nMaior)||
                           lower(vSchemaTab)||'.'||lower(vTabela)||'.'||lower(r.column_name)||'%TYPE;'||
                           CHR(10);
            END IF;
          END LOOP;
          
          IF ivOperacao = 'L' THEN
            nMaior := nMaior + 1;
            vParams := vParams || LPAD(' ',inRecuo,' ') || RPAD('ivOrdem',nMaior)||' VARCHAR2(100);'||CHR(10)||
                                  LPAD(' ',inRecuo,' ') || RPAD('inPagNum',nMaior)||' NUMBER;'||CHR(10)||
                                  LPAD(' ',inRecuo,' ') || RPAD('inPagTam',nMaior)||' NUMBER;'||CHR(10);
          END IF;
      END IF;
      
      vParams := SUBSTR(vParams, 1, LENGTH(vParams) - 1);
      
      RETURN vParams;
    END fGetParametrosInternoConversao;
   
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
      vBloco  VARCHAR2(32000);
      nRecuo  NUMBER;
      vFlPk   VARCHAR2(10);
    BEGIN
      nRecuo := inRecuo+13;
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
      
      vBloco := SUBSTR(vCampos, 1, LENGTH(vCampos) - 1);
      
      RETURN 'pManter'||fCapitalize(vTabela)||'('||SUBSTR(vBloco,nRecuo+2)||' );';
    END fMontaMetodo;
    
    FUNCTION fMontaMetodoConversao(inRecuo NUMBER,ivOperacao VARCHAR2 DEFAULT 'I') RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      vBloco  VARCHAR2(32000);
      nRecuo  NUMBER;
      nMaior  NUMBER;
      vFlPk   VARCHAR2(10);
    BEGIN
      nRecuo := inRecuo;
      
      IF ivOperacao IN ('D','R') THEN
          FOR coluna IN cColunas(vPk) LOOP
            vBloco := vBloco || LPAD(' ',nRecuo,' ') || fMontaConversao(ivColumnName => coluna.column_name, ivDataType => coluna.data_type, inMaior => LENGTH(coluna.column_name), inSize => coluna.data_length );
          END LOOP;
      END IF;
      
      IF ivOperacao IN ('I','L','U') THEN
          FOR coluna IN cColunas LOOP
            nMaior := coluna.maior;
            IF NOT (ivOperacao = 'I' AND coluna.pk = 'S') THEN
                vBloco := vBloco || LPAD(' ',nRecuo,' ') || fMontaConversao(ivColumnName => coluna.column_name, ivDataType => coluna.data_type, inMaior => nMaior, inSize => coluna.data_length );
            END IF;
          END LOOP;
          
          IF ivOperacao = 'L' THEN
            vBloco := vBloco || LPAD(' ',nRecuo,' ') || fMontaConversao(ivColumnName => 'orderBy', inMaior => nMaior, ivDataType => 'VARCHAR2' );
            vBloco := vBloco || LPAD(' ',nRecuo,' ') || fMontaConversao(ivColumnName => 'pag_num', inMaior => nMaior, ivDataType => 'NUMBER' );
            vBloco := vBloco || LPAD(' ',nRecuo,' ') || fMontaConversao(ivColumnName => 'pag_tam', inMaior => nMaior, ivDataType => 'NUMBER' );
          END IF;
      END IF;
      
      vBloco := SUBSTR(vBloco, 1, LENGTH(vBloco) - 1);
      
      RETURN vBloco;
    END fMontaMetodoConversao;
    
    FUNCTION fMontaChamadaMetodoConversao(inRecuo NUMBER,ivOperacao VARCHAR2 DEFAULT 'I', ivFronteira VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      vBloco  VARCHAR2(32000);
      nMaior  NUMBER;
      nRecuo  NUMBER;
      vRecuo  VARCHAR2(32000);
      vFlPk   VARCHAR2(10);
    BEGIN
      nRecuo := inRecuo;
      vRecuo := LPAD(' ',nRecuo);
      
      IF ivOperacao IN ('D','R') THEN
          FOR coluna IN cColunas(vPk) LOOP
            nMaior := coluna.maior + 3;
            vBloco := vBloco||vRecuo||', '||
                      RPAD((CASE ivFronteira WHEN 'N' THEN 'i'||fGetTipoParam(coluna.data_type)END||CASE ivFronteira WHEN 'S' THEN fCapitalizeConversao(coluna.column_name) ELSE fCapitalize(coluna.column_name) END), nMaior)||
                      ' => '||
                      CASE ivFronteira WHEN 'N' THEN 'i'||fGetTipoParam(coluna.data_type)END||CASE ivFronteira WHEN 'S' THEN fCapitalizeConversao(coluna.column_name) ELSE fCapitalize(coluna.column_name) END||CHR(10);
          END LOOP;
      END IF;
      
      IF ivOperacao IN ('I','L','U') THEN
          FOR coluna IN cColunas LOOP
            IF NOT (ivOperacao = 'I' AND coluna.pk = 'S') THEN
                nMaior := coluna.maior + 3;
                vBloco := vBloco||vRecuo||', '||
                          RPAD((CASE ivFronteira WHEN 'N' THEN 'i'||fGetTipoParam(coluna.data_type)END||CASE ivFronteira WHEN 'S' THEN fCapitalizeConversao(coluna.column_name) ELSE fCapitalize(coluna.column_name) END), nMaior)||
                          ' => '||
                          CASE ivFronteira WHEN 'N' THEN 'i'||fGetTipoParam(coluna.data_type)END||CASE ivFronteira WHEN 'S' THEN fCapitalizeConversao(coluna.column_name) ELSE fCapitalize(coluna.column_name) END||CHR(10);
                          
                IF ivOperacao = 'U' AND coluna.pk = 'N' AND ivFronteira = 'N' THEN
                    vBloco := vBloco||vRecuo||', '||
                          RPAD(('ib'||fCapitalize(coluna.column_name)), nMaior)||
                          ' => 1'||CHR(10);
                END IF;
            END IF;
          END LOOP;
          
          IF ivOperacao = 'L' THEN
            vBloco := vBloco||vRecuo||', '||RPAD(CASE ivFronteira WHEN 'S' THEN 'orderBy' ELSE 'ivOrdem' END, nMaior)||' => '||CASE ivFronteira WHEN 'S' THEN 'orderBy' ELSE 'ivOrdem' END||CHR(10);
            vBloco := vBloco||vRecuo||', '||RPAD(CASE ivFronteira WHEN 'S' THEN 'pagIni' ELSE 'inPagNum' END, nMaior)||' => '||CASE ivFronteira WHEN 'S' THEN 'pagIni' ELSE 'inPagNum' END||CHR(10);
            vBloco := vBloco||vRecuo||', '||RPAD(CASE ivFronteira WHEN 'S' THEN 'pagTam' ELSE 'inPagTam' END, nMaior)||' => '||CASE ivFronteira WHEN 'S' THEN 'pagTam' ELSE 'inPagTam' END||CHR(10);
          END IF;
      END IF;
      
      vBloco := SUBSTR(vBloco, 1, LENGTH(vBloco) - 1);
      
      RETURN SUBSTR(vBloco,inRecuo+3);
    END fMontaChamadaMetodoConversao;
    
    FUNCTION fGetFiltro( ivCol VARCHAR2 
                         , ivTipo VARCHAR2
                         ) RETURN VARCHAR2 IS
      vFiltro VARCHAR2(32000);
      vFiltroBind VARCHAR2(32000);
      vParam VARCHAR2(32000);
    BEGIN
      vParam := fMontaParam(ivCol,ivTipo);
      IF ivTipo IN ('NUMBER','DATE') THEN
        vFiltro := ' AND '||lower(ivCol);
        vFiltro := vFiltro||' = :'||vParam;
        vFiltroBind := vParam;
      ELSIF ivTipo IN ('VARCHAR2','CLOB') THEN
        IF SUBSTR(ivCol,1,2) IN ('DS','NO') THEN
          vFiltro := ' AND UPPER('||lower(ivCol)||')';
          vFiltro := vFiltro||' LIKE ''''%''''|| UPPER(:'||vParam||') || ''''%'''' ';
          vFiltroBind := ' ''%'' || UPPER('||vParam||') || ''%'' ';
        ELSE
          vFiltro := ' AND '||lower(ivCol);
          vFiltro := vFiltro||' = :'||vParam;
          vFiltroBind := vParam;
        END IF;
      END IF;
      vFiltro := 
'      
      IF '||vParam||' IS NOT NULL THEN
        vSql := vSql ||'''||vFiltro||' '';
        
        tBinds(tBinds.COUNT + 1).nome := '''||vParam||''';
        tBinds(tBinds.COUNT).tipo := '''|| UPPER(fGetTipoParam(ivTipo)) ||''';
        tBinds(tBinds.COUNT).'||fGetTipoParam(ivTipo)||' := '||vFiltroBind||';
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
      vBinds   VARCHAR2(32000);
      nRecuo   NUMBER;
    BEGIN
      nRecuo := 20;
      FOR r IN cColunas LOOP
        vSelect := vSelect || chr(10)||rpad(' ',nRecuo,' ')||', ';
        IF r.data_type = 'DATE' THEN
          vSelect := vSelect || 'TO_CHAR('||lower(r.column_name)||',''''RRRR-MM-DD'''') '||lower(r.column_name);
        ELSE
          vSelect := vSelect || lower(r.column_name);
        END IF;
        vFiltros := vFiltros || fGetFiltro(r.column_name,r.data_type);
        vBinds := vBinds || ', '||fMontaParam(r.column_name,r.data_type)||chr(10);
      END LOOP;
      vSelect := SUBSTR(vSelect,nRecuo+4);
      vBinds := SUBSTR(vBinds,3);
      
      vSelect := 
'      vSql := ''SELECT '||vSelect||'
                 FROM '||lower(vSchemaTab)||'.'||lower(vTabela)||' 
                WHERE 1 = 1 '';
'||vFiltros||'';
      
      RETURN vSelect;
    END fGetQuery;
    
    FUNCTION fInsUpdPl RETURN VARCHAR2 IS
      vRet  VARCHAR2(32000);
      nTam  NUMBER;   
    BEGIN
      nTam := length(fCapitalize(vTabela));
      vRet := 
'  PROCEDURE pManter'||fCapitalize(vTabela)||fGetParametrosInsUpd(nTam+19,'IA')||' IS 
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
  END pManter'||fCapitalize(vTabela)||';
';
      RETURN vRet;
    END fInsUpdPl;
    
    FUNCTION fDelPl RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet :=
'  PROCEDURE pDel'||fCapitalize(vTabela)||'( '||fGetParamPk('S')||' ) IS 
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
    jReturn         PLJSON;
    jData           PLJSON;
    cReturn         CLOB;
    
    vSql            CLOB;
    tBinds          UTILS.pljson_sql.t_binds;
    nPagNum         NUMBER;
  BEGIN
    BEGIN
      tBinds.delete;
      nPagNum := ((inPagNum + 1) - 1) * inPagTam + 1;
      
'||fGetQuery||'
      vSql := vSql || '' ORDER BY '' || NVL(ivOrdem, '' 1 '');
   
      jData := utils.pljson_sql.getFromSql( ivSql          => vSql
                                          , itBinds        => tBinds
                                          , inOffset       => nPagNum
                                          , inFetchFirst   => inPagTam
                                          , ivOrderByRn    => ivOrdem
                                          , ivLinesAttr    => ''lista''
                                          , ivNumLinesAttr => ''totalRegistros'');
        
      jReturn := pkg_msg.getMsgOk(ivDsMensagem=> ''Registo encontrato.'');
      jReturn.put(pkg_msg.vMSG_BODY_ATTR_NAME, jData);        
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            jReturn := pkg_msg.getMsgNotFound(ivDsMensagem => ''Registo não encontrado.'');
        WHEN OTHERS THEN
            jReturn := pkg_msg.getMsgInternalServerError(ivDsMensagem => ''Erro ao executar: '' || dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
    END;
    
    jReturn.to_clob(cReturn);
    RETURN cReturn;
    
  END lst;
';
      RETURN vRet;
    END fLst;
    
    FUNCTION fDtl RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION dtl( '||fGetParamPk(ivDeclare=>'S')||' ) RETURN CLOB IS
    jReturn         PLJSON;
    jData           PLJSON;
    cReturn         CLOB;
    
    jList           PLJSON;
    cList           CLOB;
  BEGIN
    BEGIN
      cList := lst( '||fGetParamPk||' => '||fGetParamPk||'
                  , ivOrdem => ''1''                                        
                  , inPagNum => 0
                  , inPagTam => ''1'' );
                  
      jList := NEW pljson(cList);
        
      IF jList.get(''code'').get_number = 404 THEN
          RAISE NO_DATA_FOUND;
      END IF;
      
      jData := new pljson (pljson_ext.get_json_value(jList, ''body.lista'||chr(91)||'1'||chr(93)||'''));
      
      jReturn := pkg_msg.getMsgOk(ivDsMensagem=> ''Registo encontrato.'');
      jReturn.put(pkg_msg.vMSG_BODY_ATTR_NAME, jData);
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            jReturn := pkg_msg.getMsgNotFound(ivDsMensagem => ''Registo não encontrado.'');
        WHEN OTHERS THEN
            jReturn := pkg_msg.getMsgInternalServerError(ivDsMensagem => ''Erro ao executar: '' || dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
    END;
    
    jReturn.to_clob(cReturn);
    RETURN cReturn;    
    
  END dtl;
';
      RETURN vRet;
    END fDtl;
    
    FUNCTION fIns RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
      nTam  NUMBER;   
    BEGIN
      nTam := length(fCapitalize(vTabela));
      vRet := 
'  FUNCTION ins'||fGetParametrosInsUpd(14,'I')||' RETURN CLOB IS
    jReturn PLJSON;
    cReturn CLOB;
    
    nPk         NUMBER;
  BEGIN
    BEGIN
      '||fMontaMetodo(nTam,'I')||'
      COMMIT;

      jReturn := pkg_msg.getMsgOk( inPK => nPk
                                 , ivDsMensagem=> ''Registo incluído com sucesso!'' );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            jReturn := pkg_msg.getMsgInternalServerError(ivDsMensagem => ''Erro ao executar: '' || dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
    END;

    jReturn.to_clob(cReturn);
    RETURN cReturn;
    
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
    jReturn PLJSON;
    cReturn CLOB;
    
    rRow cg$'||LOWER(vTabela)||'.cg$row_type;
  BEGIN
    BEGIN
      rRow.'||lower(vPk)||' := '||fGetParamPk||';
      '||fMontaMetodo(nTam,'U')||'
      COMMIT;

      jReturn := pkg_msg.getMsgOk( inPK => rRow.'||lower(vPk)||'
                                 , ivDsMensagem => ''Registo alterado com sucesso!'' );
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            jReturn := pkg_msg.getMsgInternalServerError(ivDsMensagem => ''Erro ao executar: '' || dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
    END;

    jReturn.to_clob(cReturn);
    RETURN cReturn;
    
  END upd;
';
      RETURN vRet;
    END fUpd;
    
    FUNCTION fDel RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION del( '||fGetParamPk(ivDeclare=>'S')||' ) RETURN CLOB IS
    jReturn PLJSON;
    cReturn CLOB;
  BEGIN
    BEGIN
    
      pDel'||fCapitalize(vTabela)||'('||fGetParamPk||');
      COMMIT;

      jReturn := pkg_msg.getMsgOk(ivDsMensagem=> ''Registo apagado com sucesso!'');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            jReturn := pkg_msg.getMsgInternalServerError(ivDsMensagem => ''Erro ao executar: '' || dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
    END;

    jReturn.to_clob(cReturn);
    RETURN cReturn;
    
  END del;
  ';
      RETURN vRet;
    END fDel;
    
    FUNCTION fDetalhar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION detalhar'||fGetParametrosConversao(inRecuo=>17, ivOperacao=>'D')||' RETURN CLOB IS
    cReturn     CLOB;
    jReturn     PLJSON;
    
'||fGetParametrosInternoConversao(inRecuo=>4, ivOperacao=>'D')||'
  BEGIN
    BEGIN
    
'||fMontaMetodoConversao(inRecuo=>6, ivOperacao=>'D')||'
      cReturn := dtl( '||fMontaChamadaMetodoConversao(inRecuo=>20, ivOperacao=>'D')||' );

    EXCEPTION
       WHEN OTHERS THEN
           jReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
           jReturn.to_clob(cReturn);
    END;
    
    RETURN cReturn;
    
  END detalhar;
  ';
      RETURN vRet;
    END fDetalhar;
    
    FUNCTION fListar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION listar'||fGetParametrosConversao(inRecuo=>17, ivOperacao=>'L')||' RETURN CLOB IS
    cReturn     CLOB;
    jReturn     PLJSON;
    
'||fGetParametrosInternoConversao(inRecuo=>4, ivOperacao=>'L')||'
  BEGIN
    BEGIN
    
'||fMontaMetodoConversao(inRecuo=>6, ivOperacao=>'L')||'

      cReturn := lst( '||fMontaChamadaMetodoConversao(inRecuo=>20, ivOperacao=>'L')||' );

    EXCEPTION
       WHEN OTHERS THEN
           jReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
           jReturn.to_clob(cReturn);
    END;
    
    RETURN cReturn;
    
  END listar;
  ';
      RETURN vRet;
    END fListar;
    
    FUNCTION fRegistar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION registar'||fGetParametrosConversao(inRecuo=>19, ivOperacao=>'I')||' RETURN CLOB IS
    cReturn     CLOB;
    jReturn     PLJSON;
    
'||fGetParametrosInternoConversao(inRecuo=>4, ivOperacao=>'I')||'
  BEGIN
    BEGIN
    
'||fMontaMetodoConversao(inRecuo=>6, ivOperacao=>'I')||'

      cReturn := ins( '||fMontaChamadaMetodoConversao(inRecuo=>20, ivOperacao=>'I')||' );

    EXCEPTION
       WHEN OTHERS THEN
           jReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
           jReturn.to_clob(cReturn);
    END;
    
    RETURN cReturn;
    
  END registar;
  ';
      RETURN vRet;
  END fRegistar;
  
  FUNCTION fActualizar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION actualizar'||fGetParametrosConversao(inRecuo=>21, ivOperacao=>'U')||' RETURN CLOB IS
    cReturn     CLOB;
    jReturn     PLJSON;
    
'||fGetParametrosInternoConversao(inRecuo=>4, ivOperacao=>'U')||'
  BEGIN
    BEGIN
    
'||fMontaMetodoConversao(inRecuo=>6, ivOperacao=>'U')||'

      cReturn := upd( '||fMontaChamadaMetodoConversao(inRecuo=>20, ivOperacao=>'U')||' );

    EXCEPTION
       WHEN OTHERS THEN
           jReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
           jReturn.to_clob(cReturn);
    END;
    
    RETURN cReturn;
    
  END actualizar;
  ';
      RETURN vRet;
  END fActualizar;
  
  FUNCTION fRemover RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION remover'||fGetParametrosConversao(inRecuo=>18, ivOperacao=>'R')||' RETURN CLOB IS
    cReturn     CLOB;
    jReturn     PLJSON;
    
'||fGetParametrosInternoConversao(inRecuo=>4, ivOperacao=>'R')||'
  BEGIN
    BEGIN
    
'||fMontaMetodoConversao(inRecuo=>6, ivOperacao=>'R')||'
      cReturn := del( '||fMontaChamadaMetodoConversao(inRecuo=>20, ivOperacao=>'R')||' );

    EXCEPTION
       WHEN OTHERS THEN
           jReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
           jReturn.to_clob(cReturn);
    END;
    
    RETURN cReturn;
    
  END remover;
  ';
      RETURN vRet;
  END fRemover;
  
  FUNCTION fGetListar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
'  FUNCTION '||LOWER(vServico)||'s_get'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+16, ivOperacao=>'L')||' RETURN CLOB IS
  BEGIN
    RETURN '||LOWER(vSchema)||'.'||LOWER(vPackage)||'.lst( '||fMontaChamadaMetodoConversao(inRecuo=>LENGTH(vPackage) + 16 + length(vSchema), ivOperacao=>'L', ivFronteira=>'S')||' );                                           
  END '||LOWER(vServico)||'s_get;
  ';
      RETURN vRet;
  END fGetListar;
  
  FUNCTION fGetDetalhar RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
' 
  FUNCTION '||LOWER(vServico)||'_get'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+15, ivOperacao=>'D')||' RETURN CLOB IS
  BEGIN
    RETURN '||LOWER(vSchema)||'.'||LOWER(vPackage)||'.getByPk( '||fMontaChamadaMetodoConversao(inRecuo=>LENGTH(vPackage) + 20, ivOperacao=>'D', ivFronteira=>'S')||' );                                           
  END '||LOWER(vServico)||'_get;
  ';
      RETURN vRet;
  END fGetDetalhar;
  
  FUNCTION fPost RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
' 
  FUNCTION '||LOWER(vServico)||'_post'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+16, ivOperacao=>'I')||' RETURN CLOB IS
  BEGIN
    RETURN '||LOWER(vSchema)||'.'||LOWER(vPackage)||'.ins( '||fMontaChamadaMetodoConversao(inRecuo=>LENGTH(vPackage) + 16 + length(vSchema), ivOperacao=>'I', ivFronteira=>'S')||' );                                           
  END '||LOWER(vServico)||'_post;
  ';
      RETURN vRet;
  END fPost;
  
  FUNCTION fPut RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
' 
  FUNCTION '||LOWER(vServico)||'_put'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+15, ivOperacao=>'U')||' RETURN CLOB IS
  BEGIN
    RETURN '||LOWER(vSchema)||'.'||LOWER(vPackage)||'.upd( '||fMontaChamadaMetodoConversao(inRecuo=>LENGTH(vPackage) + 16 + length(vSchema), ivOperacao=>'U', ivFronteira=>'S')||' );                                           
  END '||LOWER(vServico)||'_put;
  ';
      RETURN vRet;
  END fPut;
  
  FUNCTION fDelete RETURN VARCHAR2 IS
      vRet VARCHAR2(32000);
    BEGIN
      vRet := 
' 
  FUNCTION '||LOWER(vServico)||'_delete'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+18, ivOperacao=>'R')||' RETURN CLOB IS
  BEGIN
    RETURN '||LOWER(vSchema)||'.'||LOWER(vPackage)||'.del( '||fMontaChamadaMetodoConversao(inRecuo=>LENGTH(vPackage) + 19, ivOperacao=>'R', ivFronteira=>'S')||' );                                           
  END '||LOWER(vServico)||'_delete;
  ';
      RETURN vRet;
  END fDelete;
    
  BEGIN
    vTabela   := UPPER(ivTabela);
    vSchemaTab := UPPER(ivSchema);
    vSchema   := vSchemaTab||'_APP';
    vPackage  := 'PKG_API_'||REPLACE(vTabela,'TB_','');
    vServico  := LOWER(ivServico);
  
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
  
      /*-- pks
      pPrint('CREATE OR REPLACE PACKAGE '||lower(vSchema)||'.'||lower(vPackage)||' IS ' ||CHR(10) );
        
        pPrint('  FUNCTION detalhar'||fGetParametrosConversao(inRecuo=>19, ivOperacao=>'D')||' RETURN CLOB;'||CHR(10));  
        
        pPrint('  FUNCTION listar'||fGetParametrosConversao(inRecuo=>17, ivOperacao=>'L')||' RETURN CLOB;'||CHR(10));  
      
        pPrint('  FUNCTION registar'||fGetParametrosConversao(inRecuo=>19, ivOperacao=>'I')||' RETURN CLOB;'||CHR(10));  
      
        pPrint('  FUNCTION actualizar'||fGetParametrosConversao(inRecuo=>21, ivOperacao=>'U')||' RETURN CLOB;'||CHR(10));  
        
        pPrint('  FUNCTION remover'||fGetParametrosConversao(inRecuo=>18, ivOperacao=>'R')||' RETURN CLOB;'||CHR(10));  
      
      pPrint('END;'||CHR(10)||'/'||CHR(10));
    
      -- pkb
      pPrint('CREATE OR REPLACE PACKAGE BODY '||LOWER(vSchema)||'.'||LOWER(vPackage)||' IS '||CHR(10));
      
        -- PROCEDURE pManter
        pPrint(fInsUpdPl);
        
        -- PROCEDURE pDelPl
        pPrint(fDelPl);
      
        -- FUNCTION lst
        pPrint(fLst);
        
        -- FUNCTION dtl
        pPrint(fDtl);
        
        -- FUNCTION ins
        pPrint(fIns);
        
        -- FUNCTION upd
        pPrint(fUpd);
        
        -- FUNCTION del
        pPrint(fDel);
        
        -- FUNCTION detalhar
        pPrint(fDetalhar);
        
        -- FUNCTION listar
        pPrint(fListar);
        
        -- FUNCTION registar
        pPrint(fRegistar);
        
        -- FUNCTION actualizar
        pPrint(fActualizar);
        
        -- FUNCTION remover
        pPrint(fRemover);
     
      pPrint('END;'||CHR(10)||'/'||CHR(10));
  
      pPrint('GRANT EXECUTE ON '||LOWER(vSchema)||'.'||LOWER(vPackage)||' TO executor_au'||CHR(10)||'/');
  
      pPrint('CREATE OR REPLACE SYNONYM executor_au.'||LOWER(vPackage)||' FOR '||LOWER(vSchema)||'.'||LOWER(vPackage)||''||CHR(10)||'/');
      
      pPrint(CHR(10)||CHR(10));*/
      
      -- pks Package de Fronteira
      pPrint('CREATE OR REPLACE PACKAGE executor_au.<Nome da API> IS '||CHR(10));
        
        pPrint('  FUNCTION '||LOWER(vServico)||'s_get'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+16, ivOperacao=>'L')||' RETURN CLOB;'||CHR(10));
        
        pPrint('  FUNCTION '||LOWER(vServico)||'_get'||fGetParametrosConversao(inRecuo=>LENGTH(vServico), ivOperacao=>'D')||' RETURN CLOB;'||CHR(10));
      
        pPrint('  FUNCTION '||LOWER(vServico)||'_post'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+16, ivOperacao=>'I')||' RETURN CLOB;'||CHR(10));
      
        pPrint('  FUNCTION '||LOWER(vServico)||'_put'||fGetParametrosConversao(inRecuo=>LENGTH(vServico)+15, ivOperacao=>'U')||' RETURN CLOB;'||CHR(10));
        
        pPrint('  FUNCTION '||LOWER(vServico)||'_delete'||fGetParametrosConversao(inRecuo=>LENGTH(vServico), ivOperacao=>'R')||' RETURN CLOB;'||CHR(10));
      
      pPrint('END;'||CHR(10)||'/'||CHR(10));
      
      -- pkb Package de Fronteira
      pPrint('CREATE OR REPLACE PACKAGE BODY executor_au.<Nome da API> IS '||CHR(10));
      
        -- FUNCTION listar
        pPrint(fGetListar);
        
        -- FUNCTION detalhar
        pPrint(fGetDetalhar);
        
        -- FUNCTION registar
        pPrint(fPost);
        
        -- FUNCTION actualizar
        pPrint(fPut);
        
        -- FUNCTION remover
        pPrint(fDelete);
     
      pPrint('END;'||CHR(10)||'/');
      
    END;
    RETURN cSaida;
  END fCrudGenerator;
BEGIN
  DECLARE
    cResult clob;
    nTam  PLS_INTEGER;
    nPos  PLS_INTEGER;
  BEGIN
    nTam := 30000;
    nPos := 1;
    dbms_output.enable(1000000);
    
    cResult := fCrudGenerator( ivTabela   => upper('&tabela')
                             , ivSchema   => upper('&schema')
                             , ivServico  => upper('&servico')
                              );
    /*cResult := fCrudGenerator( ivTabela   => upper('tb_ffhab_servico')
                             , ivSchema   => upper('FFHAB')
                             , ivServico  => upper('servico')*/
                              );
    gravalogclob(cResult, 'GeradorPL');

    WHILE nPos < dbms_lob.getlength ( cResult ) LOOP
      dbms_output.put_line ( dbms_lob.substr ( cResult, nTam, nPos ) );
      nPos := nPos + nTam;
    END LOOP;
  END;
END;
/
