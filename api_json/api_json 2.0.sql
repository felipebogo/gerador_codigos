-- release notes
-- 1.0 - tratamento de parametros data,char e NUMBER. não trata types
-- 2.0 - tratamento de types
--     - adicionado parametro de-para do json com a assinatura
DECLARE
  
  cnApplicationError CONSTANT     INTEGER := -20050;
  eApplicationError               EXCEPTION;
  PRAGMA EXCEPTION_INIT(eApplicationError,-20050);
  vErro VARCHAR2(4000);
  
  TYPE tab_varchar2 IS TABLE OF VARCHAR2(200) INDEX BY VARCHAR2(200);

  TYPE tab_cols IS TABLE OF all_arguments%rowtype INDEX BY VARCHAR2(50);
  lCols tab_cols;
  
  TYPE rec_parametro IS RECORD
  ( parametro      VARCHAR2(32000)
  , dependencias   CLOB
  , declaracoes    VARCHAR2(32000)
  , erros          CLOB
  );
  
  TYPE tab_parametro IS TABLE OF rec_parametro INDEX BY pls_integer;
  
  
  -- parametros informados
  lDePara tab_varchar2;  
  vPackage   VARCHAR2(32);
  vProcedure VARCHAR2(32);
  vJson      CLOB;
  
  
  FUNCTION fGetDePara (ivKey VARCHAR2) RETURN VARCHAR2 IS
    vRet VARCHAR2(50);
  BEGIN
    vRet := ivKey;
    IF lDePara.EXISTS(upper(vRet)) THEN
      vRet := lDePara(upper(vRet));
    END IF;
    RETURN vRet;
  END fGetDePara;
  
  FUNCTION fGetParametro (ivKey  VARCHAR2
                         ,ilCols tab_cols
                         ,ioObj  pljson ) RETURN rec_parametro IS
    rParam rec_parametro;
    vKeyCols   VARCHAR2(50);
    oValor     pljson_value;
    oObjList   pljson_list;
    oObj       pljson;
    vRecName   VARCHAR2(100);
    vTabName   VARCHAR2(100);
    lCols      tab_cols;
    lKeys      pljson_list;
    vKey       VARCHAR2(50);
    lparametros tab_parametro;
    vParams     VARCHAR2(32000);
    vDeclare    VARCHAR2(32000);
    vIdx        VARCHAR2(200);
    nIdx        number;
  BEGIN
    vKeyCols := UPPER(fGetDePara(ivKey));
    oValor := pljson_ext.get_json_value(ioObj,ivKey);     
    IF ilCols.EXISTS(vKeyCols) THEN
      rParam.parametro := ilCols(vKeyCols).argument_name||' => ';
      IF oValor IS NOT NULL THEN
        CASE oValor.get_type 
        WHEN 'number' THEN
          rParam.parametro := rParam.parametro || REPLACE(pljson_ext.get_number(ioObj,ivKey),',','.');
        WHEN 'string' THEN
          IF ilCols(vKeyCols).data_type = 'DATE' THEN
            DECLARE
                  vAux VARCHAR2(200);
                  vSep VARCHAR2(1);
            BEGIN
              vAux := pljson_ext.get_string(ioObj,ivKey);
              IF INSTR(vAux,'-') > 0 THEN
                vSep := '-';
              ELSIF INSTR(vAux,'.') > 0 THEN
                vSep := '.';
              ELSE
                vSep := '/';
              END IF;
              -- Valida se tem hora na mascara
              IF LENGTH(vAux) > 10 THEN
                vAux := ' TO_DATE('''||vAux||''',''DD'||vSep||'MM'||vSep||'RRRR HH24:MI:SS'') ';
              ELSE
                vAux := ' TO_DATE('''||vAux||''',''DD'||vSep||'MM'||vSep||'RRRR'') ';
              END IF;
              rParam.parametro := rParam.parametro || vAux;
            END;
          ELSE
            rParam.parametro := rParam.parametro ||''''||pljson_ext.get_string(ioObj,ivKey)||'''';
          END IF;
        WHEN 'array' THEN
          IF ilCols(vKeyCols).data_type = 'TABLE' THEN
            vTabName := ilCols(vKeyCols).type_name;
            -- Recupera vetor do objeto:
            -- exemplo: {"ilAnexo":{"anexo":1},{"anexo":2},{"anexo":3}]
            oObjList := pljson_ext.get_json_list(obj  => ioObj
                                                ,path => ivKey
                                                );
            IF oObjList IS NOT NULL THEN
              -- ilAnexo tab_anexo := tab_anexo()
              rParam.declaracoes := vKeyCols||' '||vTabName||' := '||vTabName||'();';
              -- monta types para declarar objetos
              -- Busca record
              SELECT elem_type_name
                INTO vRecName
                FROM all_coll_types
               WHERE type_name = vTabName;
              -- busca atributos do record.
              -- Busca colunas na type a partir do itpo passado
              FOR rCur IN ( SELECT REPLACE(at.ATTR_NAME,'_','') idx
                                 , at.ATTR_NAME Argument_Name
                                 , CASE 
                                   WHEN
                                     at.ATTR_TYPE_NAME IN ('NUMBER','VARCHAR2','DATE') THEN
                                     at.ATTR_TYPE_NAME
                                   ELSE
                                     (SELECT 'TABLE'
                                        FROM all_coll_types
                                       WHERE type_name = at.ATTR_TYPE_NAME)
                                   END data_TYPE
                                 , at.length data_length
                                 , CASE 
                                   WHEN
                                     at.ATTR_TYPE_NAME NOT IN ('NUMBER','VARCHAR2','DATE') THEN
                                     at.ATTR_TYPE_NAME
                                   END TYPE_NAME
                             FROM all_type_attrs at
                            WHERE type_name = vRecName
                        )
              LOOP
                lCols(rCur.idx).argument_name  := rCur.argument_name;
                lCols(rCur.idx).data_type      := rCur.data_type;
                lCols(rCur.idx).data_length    := rCur.data_length;
                lCols(rCur.idx).type_name      := rCur.type_name;
              END LOOP;
              
              -- Percorre objetos da lista de parâmetros
              -- Exemplo:
              -- percorre objetos do [{"anexo":1},{"anexo":2},{"anexo":3}]
              FOR i IN 1..oObjList.COUNT LOOP
                -- Monta lista de parâmetro a partir dos valores do json 
                oObj := pljson(oObjList.get(i));
                lKeys := oObj.get_keys;
                
                -- Percorre parâmetros do objeto
                lParametros.DELETE;
                vIdx := lCols.FIRST;
                -- Faz um de-para entre o nome da coluna na type pra coluna no json
                WHILE vIdx IS NOT NULL LOOP
                  FOR I IN 1..lkeys.count LOOP
                    nIdx := i;
                    vKey := replace(lKeys.get(i).to_char,'"','');
                    IF UPPER(vKey) = vIdx THEN
                      EXIT;
                    ELSE
                      vKey := null;
                    END IF;
                  END loop;
                  IF vKey IS NULL THEN
                    vKey := vIdx;
                  ELSE
                    lkeys.remove(nIdx);
                  END IF;
                  lParametros(lParametros.count+1)  := fGetParametro(vKey,lCols,oObj);
                  vIdx := lCols.NEXT(vIdx);
                END LOOP;
                IF lkeys.count > 0 THEN
                  
                  rParam.erros := rParam.erros || chr(10) || 'Parametros informados no json que não existem na type '||vTabName||': '||lkeys.count;
                  FOR I IN 1..lKeys.count LOOP
                    rParam.erros := rParam.erros || chr(10) || ' - '||lkeys.get(i).to_char;
                  END LOOP;
                END IF;
                
                vParams  := null;
                vDeclare := null;
                -- remove primeira virgula
                FOR j IN 1..lparametros.count LOOP
                  IF lparametros(j).declaracoes IS NOT NULL THEN
                    vDeclare := vDeclare || CASE WHEN j > 1 THEN CHR(10) END || lparametros(j).declaracoes;
                  END IF;
                  vParams := vParams || CASE WHEN j > 1 THEN ', ' END || lparametros(j).parametro||CHR(10);
                  IF lparametros(j).erros IS NOT NULL THEN
                     rParam.erros := rParam.erros ||CHR(10) ||lparametros(j).erros;
                  END IF;
                END LOOP;
                IF vParams IS NOT NULL THEN
                  vParams := '('||vParams||');';
                END IF;
                IF vDeclare IS NOT NULL THEN
                  rParam.declaracoes := rParam.declaracoes||CASE WHEN rParam.DECLAracoes IS NOT NULL THEN CHR(10) END ||vDeclare;
                END IF;
                rParam.dependencias := rParam.dependencias || vKeyCols||'.extend;'||CHR(10);
                rParam.dependencias := rParam.dependencias || vKeyCols||'('||i||') := '||vRecName||vParams||CHR(10);
                
                /*dbms_output.put_line('----------------------DEC INTERNO---------------------------');
                dbms_output.put_line(vDeclare);
                dbms_output.put_line('----------------------DEP INTERNO---------------------------');
                dbms_output.put_line(rParam.dependencias);
                dbms_output.put_line('----------------------PARAM INTERNO---------------------------');
                dbms_output.put_line(vParams);
                dbms_output.put_line('------------------------------------------------------------');*/
              END LOOP;
              --dbms_output.put_line(rParam.declaracoes);
              --dbms_output.put_line('--------------------------------------------------------------------------');
              rParam.parametro := rParam.parametro ||vKeyCols;
            END IF;
          END IF;
        WHEN 'null' THEN
          --dbms_output.put_line('null');
          rParam.parametro := rParam.parametro || 'null';
        ELSE
          dbms_output.put_line(ivKey||' - TIPO: '||oValor.get_type||' ainda não tratado');
        END CASE;
      ELSE
        rParam.parametro := rParam.parametro || 'null';
      END IF;
    ELSE
      rParam.parametro := vKeyCols||'=> null';
      rParam.erros := 'parâmetro '||vKeyCols||' não encontrado.';
    END IF;
    RETURN rParam;
  END fGetParametro;
  
  
  PROCEDURE pPrint IS
    oObj        pljson;
    lKeys       pljson_list;
    vKey        VARCHAR2(50);
    
    cPrint         CLOB;
    vParams        VARCHAR2(32000);
    vDeclare       VARCHAR2(32000);
    vDependencias  VARCHAR2(32000);
    vDePara        VARCHAR2(32000);
    lparametros    tab_parametro;
    vVars          VARCHAR2(32000);
    cErros         CLOB;
    vFDeclare      VARCHAR2(32000);
    vTypeProc      VARCHAR2(32000);
    vOwner         VARCHAR2(32000);
  BEGIN
    vPackage   := UPPER(vPackage);
    vProcedure := UPPER(vProcedure);
    BEGIN
      SELECT 'vRet '||
             CASE 
             WHEN args.data_type IN ('OBJECT','TABLE') THEN
               args.type_name
             WHEN args.data_type IN ('VARCHAR2') THEN
               args.data_type||('('||NVL(args.DATA_LENGTH,32000)||')')
             ELSE
               args.data_type
             END ||';'||CHR(10)
           , args.data_type
        INTO vFDeclare
           , vTypeProc
       FROM all_arguments args
      WHERE args.package_name = vPackage
        AND args.object_name = vProcedure
        AND args.position = 0;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        vFDeclare := NULL;
    END;
    FOR rCur IN ( SELECT args.argument_name
                       , args.data_type
                       , args.data_length
                       , args.type_name
                       , args.owner
                    FROM all_arguments args
                   WHERE args.package_name = vPackage
                     AND args.object_name = vProcedure
                     AND args.argument_name IS NOT NULL
                )
    LOOP
      vOwner := rCur.owner;
      lCols(rCur.Argument_Name).argument_name  := rCur.argument_name;
      lCols(rCur.Argument_Name).data_type      := rCur.data_type;
      lCols(rCur.Argument_Name).data_length    := rCur.data_length;
      lCols(rCur.Argument_Name).type_name      := rCur.type_name;
    END LOOP;
    
    IF lcols.count = 0 THEN
      RAISE_APPLICATION_ERROR(cnApplicationError,'Nenhum argumento encontrado para o procedimento '||vPackage||'.'||vProcedure||'.');
    END IF;
    
    -- Monta lista de parâmetro a partir dos valores do json 
    oObj := pljson(vJson);
    lKeys := oObj.get_keys;
    dbms_output.put_line('-------------------------- JSON -------------------------');
    oObj.print;
    dbms_output.put_line('---------------------------------------------------------');
    dbms_output.put_line(';');
    FOR i IN 1..lKeys.COUNT LOOP
      vKey := replace(lKeys.get(i).to_char,'"','');
      lParametros(lParametros.count+1)  := fGetParametro(vKey,lCols,oObj);
    END LOOP;
    -- remove primeira virgula
    FOR i IN 1..lparametros.count LOOP
      IF lparametros(i).declaracoes IS NOT NULL THEN
        vDeclare := vDeclare || CASE WHEN i > 1 THEN CHR(10) END || lparametros(i).declaracoes;
      END IF;
      IF lparametros(i).dependencias IS NOT NULL THEN
        vDependencias := vDependencias || CASE WHEN i > 1 THEN CHR(10) END || lparametros(i).dependencias;
      END IF;
      vParams := vParams || CASE WHEN i > 1 THEN ', ' END || lparametros(i).parametro||CHR(10);
      IF lparametros(i).ERROS IS NOT NULL THEN
       cErros := cErros ||CHR(10) ||lparametros(i).erros;
      END IF;
    END LOOP;
    vParams := '('||vParams||');';
    cPrint := vOwner||'.'||vPackage||'.'||vProcedure|| vParams;
    IF vFDeclare IS NOT NULL THEN
      cPrint := 'vRet := '||cPrint;
    END IF;
    dbms_output.put_line('DECLARE');
    dbms_output.put_line(vDeclare||vFDeclare);
    dbms_output.put_line('BEGIN');
    dbms_output.put_line(vDependencias||CASE WHEN vDependencias IS NOT NULL THEN CHR(10) END);
    dbms_output.put_line(cPrint||CASE WHEN cPrint IS NOT NULL THEN CHR(10) END);
    IF vTypeProc NOT IN ('TABLE','OBJECT') THEN
      DBMS_OUTPUT.PUT_LINE('DBMS_OUTPUT.PUT_LINE(vRet);');
    END IF;
    dbms_output.put_line('END;'||CHR(10)||'/');
    IF cErros IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('------------ ERROS ----------------');
      DBMS_OUTPUT.PUT_LINE(cErros);
    END IF;
    
  EXCEPTION
    WHEN eApplicationError THEN
      vErro := REPLACE(SQLERRM,'ORA'||cnApplicationError||': ','');
      dbms_output.put_line(vErro);
    WHEN OTHERS THEN
      dbms_output.put_line('Ops! Ocorreu um erro: '||dbms_utility.format_error_stack || dbms_utility.format_error_backtrace);
  END pPrint;
  
BEGIN
  -- parametros que estão diferente no json da função/type
  lDePara('ITENSPORPAGINA') := 'INPAGTAM';
  lDePara('ORDENACAO') := 'IVORDER';
  lDePara('PAGINAATUAL') := 'INPAGNUM';
  ------------------------------------------------
  vPackage   := UPPER('');
  vProcedure := UPPER('');
  vJson      := '';
  pPrint;
END;
/
