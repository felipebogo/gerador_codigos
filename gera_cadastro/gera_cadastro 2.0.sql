DECLARE 
  FUNCTION fGeraCadastro( ivTabela   VARCHAR2
                      , ivPackage  VARCHAR2
                      , ivSchema   VARCHAR2
                      , ivSchmaTab VARCHAR2 DEFAULT NULL
                      , ivTitulo   VARCHAR2 
                      , ivId       VARCHAR2 DEFAULT NULL
                      ) RETURN CLOB IS
  -- 1.0 - nascimento
  -- 2.0 - Alterado pShowResultadoLista para usar pljson
  --     - Alterado inputs para usar htf.
  --     - removido teste login do pMetodo
  --     - Adicionados campos chosen de domínio
  --     - adicionados campos no cadastro conforme tipo de dado
  --     - formatada as máscaras dos campos no cadastro e resultado
  --     - tratamento campos clob
  --     - correções menores
    cnApplicationError CONSTANT     INTEGER := -20050;
    eApplicationError               EXCEPTION;
    PRAGMA EXCEPTION_INIT(eApplicationError,-20050);
    cSaida CLOB;
    
    TYPE rec_ret IS RECORD 
    ( texto1 CLOB
    , texto2 CLOB
    );
    
    vTitulo   VARCHAR2(100);
    vTabela   VARCHAR2(100);
    vPackage  VARCHAR2(100);
    vSchema   VARCHAR2(100);
    vSchmaTab VARCHAR2(100);
    vId       VARCHAR2(32000);
    
    vPk       VARCHAR2(100);    
    
    CURSOR cColunas IS
      SELECT col.column_name
           , col.data_type
           , col.data_length
           , MAX(LENGTH(column_name)) over () maior
           , COUNT(1) over () total
           , NVL((SELECT 'S'
                    FROM dba_constraints c
                       , dba_cons_columns cc
                   WHERE c.table_name = col.table_name
                     AND cc.constraint_name = c.constraint_name
                     AND cc.column_name = col.column_name
                     AND c.constraint_type = 'P'),'N') pk
           , CASE NULLABLE WHEN 'Y' THEN 'N' ELSE 'S' END obrigatorio
           , virtual_column
        FROM dba_tab_cols col
       WHERE col.TABLE_NAME = UPPER(vTabela)
         AND (col.owner = vSchmaTab OR vSchmaTab IS NULL);
    
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
      RETURN CASE WHEN vSchmaTab IS NOT NULL THEN LOWER(vSchmaTab)||'.' END || vTabela;
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
    
    FUNCTION fContaCampos RETURN NUMBER IS 
      nTotal NUMBER;
    BEGIN
       SELECT COUNT(1)
        INTO nTotal
        FROM dba_tab_cols col
       WHERE col.TABLE_NAME = UPPER(vTabela)
         AND (col.owner = vSchmaTab OR vSchmaTab IS NULL)
         AND NOT EXISTS (SELECT 1
                           FROM dba_constraints c
                              , dba_cons_columns cc
                          WHERE c.table_name = col.table_name
                            AND cc.constraint_name = c.constraint_name
                            AND cc.column_name = col.column_name
                            AND c.constraint_type = 'P');
      RETURN nTotal;
    END fContaCampos;
    
    FUNCTION fGetDominio (ivDominio VARCHAR2) RETURN VARCHAR2 IS
      vDom VARCHAR2(200);
    BEGIN
      IF UPPER(ivDominio) LIKE 'FL\_%' ESCAPE '\' THEN
        vDom := 'SIM_NAO';
      ELSE
        BEGIN
          SELECT UPPER(ivDominio)
            INTO vDom
            FROM cg_ref_codes cg
           WHERE cg.rv_domain = UPPER(ivDominio)
             AND ROWNUM = 1;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              vDom := NULL;
          END;
      END IF;
      RETURN vDom;
    END fGetDominio;
    
    FUNCTION fMontaParam(ivColumnName VARCHAR2
                        ,ivDataType   VARCHAR2
                        ) RETURN VARCHAR2 IS
    BEGIN
      RETURN 'i'||fGetTipoParam(ivDataType)||fCapitalize(ivColumnName);
    END fMontaParam;
    
    FUNCTION fGetParamPk ( ivDeclare VARCHAR2 DEFAULT 'N'
                         , ivNull    VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS
    BEGIN
      RETURN 'in'||fCapitalize(vPk) ||
             CASE ivDeclare WHEN 'S' THEN ' NUMBER' END ||
             CASE ivNull WHEN 'S' THEN ' DEFAULT NULL' END;
    END fGetParamPk;
    
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
    
    FUNCTION fGetColSelect(inRecuo NUMBER DEFAULT 0) RETURN VARCHAR2 IS
      vParams VARCHAR2(4000);
      vCol    VARCHAR2(4000);
    BEGIN
      FOR r IN cColunas LOOP
        IF r.data_type = 'CLOB' THEN
          vCol := 'DBMS_LOB.SUBSTR('||LOWER(r.column_name)||',1,4000) '||LOWER(r.column_name);
        ELSE
          vCol := LOWER(r.column_name);
        END IF;
        vParams := vParams|| CASE WHEN vParams IS NOT NULL THEN CHR(10)||LPAD(', ',inRecuo,' ')END||
                   vCol;
      END LOOP;
      RETURN vParams;
    END fGetColSelect;
    
    FUNCTION fGetParamsDatatable RETURN CLOB IS
      vParams   CLOB;
      nTam      NUMBER;
      vDominio  VARCHAR2(32000);
      vRender   VARCHAR2(32000);
      vAlign    VARCHAR2(32000);
    BEGIN
      FOR r IN cColunas LOOP
        nTam    := r.maior;
        vRender := NULL;
        vAlign  := NULL;
        IF r.pk <> 'S' THEN
          -- Render
          vDominio := fGetDominio(r.column_name);
          IF vDominio IS NOT NULL THEN
            vRender := '$.fn.dataTable.render.domain("'||vDominio||'")';
          ELSE
            IF r.data_type = 'DATE' THEN
              vRender := '';
            ELSIF r.data_type = 'NUMBER' THEN
              IF upper(r.column_name) LIKE 'VL\_%' ESCAPE '\' THEN
                vRender := '$.fn.dataTable.render.vlr()';
              END IF;
            END IF;
          END IF;
          IF vRender IS NOT NULL THEN
            vRender := ', render: '||vRender;
          END IF;
          -- Alinhamento
          IF r.data_type IN ('DATE','NUMBER') THEN
            vAlign := ', className: "dt-body-right"';
          END IF;
          vParams := vParams|| '          ,{ "data": '||RPAD('"'||LOWER(r.column_name)||'"',nTam+2,' ')||',title: '||RPAD('"'||LOWER(r.column_name)||'"',nTam+2,' ')||''||vAlign||vRender||'} '||CHR(10);
        END IF;
      END LOOP;
      vParams :=' { "data": ""'||LPAD(' ',nTam,' ')||',title: "", orderable: false, className: "select-checkbox all", "defaultContent": ""}'||CHR(10)||
                vParams||
                '          ,{ "data": ""'||LPAD(' ',nTam,' ')||',title: "Acções", className:"dt-icons tdAct", orderable:false, searchable:false, render: $.fn.dataTable.render.globalAct("data_act")}';
      RETURN vParams;
    END fGetParamsDatatable;
  
    FUNCTION fGetListaJson RETURN rec_ret IS 
      vSelect    VARCHAR2(32000);
      vRespostas VARCHAR2(32000);
      vTam       NUMBER;
      rRet       rec_ret;
      vDominio   VARCHAR2(100);
      vSimNao    VARCHAR2(1) := 'N';
      vCampo     VARCHAR2(500);
    BEGIN
      FOR r IN cColunas LOOP
        vTam := r.maior;
        vSelect := vSelect ||CASE WHEN vSelect IS NOT NULL THEN 
                             CHR(10) ||  '                       , '
                             END||
                             CASE WHEN r.data_type = 'CLOB' AND 1=2 THEN 
                               'DBMS_LOB.SUBSTR('||LOWER(r.column_name)||',1,4000) ' || LOWER(r.column_name)
                             ELSE
                               LOWER(r.column_name)
                             END;
        vCampo := 'cReg.'||LOWER(r.column_name);
        IF r.pk <> 'S' THEN
          IF r.data_type = 'DATE' THEN
            vCampo := 'TO_CHAR('||vCampo||',''DD/MM/RRRR HH24:MI:SS'')';
          END IF;
          
          vRespostas := vRespostas|| '      oObj.put('||RPAD(''''||LOWER(r.column_name)||'''',vTam+2,' ')||', '||vCampo||');'||chr(10);
          vDominio := fGetDominio(r.column_name);
          IF vDominio = 'SIM_NAO' AND vSimNao = 'N' THEN
            vSimNao := 'S';
          ELSIF vDominio = 'SIM_NAO' THEN
            vDominio := NULL;
          END IF;
          IF vDominio IS NOT NULL THEN
            rRet.texto2 := rRet.texto2 || CASE WHEN rRet.texto2 IS NOT NULL THEN ',' END ||vDominio;
          END IF;
        END IF;
      END LOOP;
      IF rRet.texto2 IS NOT NULL THEN
        rRet.texto2 := '    oObj.put(''domain'', PLJSON(PKG_JSON.getDominioJSON('''||rRet.texto2||''')).get(''domain''));'||CHR(10);
      END IF;
      rRet.texto1 := 'FOR cReg IN ( SELECT '||vSelect||'
                    FROM '||CASE WHEN vSchmaTab IS NOT NULL THEN vSchmaTab||'.' END||vTabela ||'
                   WHERE ROWNUM < 100 -- REMOVER
                ) 
    LOOP
      oObj := NEW PLJSON;
      oObj.put('||RPAD('''cd''',vTam+2,' ')||', cReg.'||LOWER(vPk)||');
  
'||vRespostas||'    
      oObj.put('||RPAD('''data_act''',vTam+2,' ')||', vIco);
      oLst.append(oObj.to_json_value);
    END LOOP;';
      RETURN rRet;
    END fGetListaJson;
  
    FUNCTION fGetCampoCadastro ( ivColumnName  VARCHAR2 
                               , ivDataType    VARCHAR2 
                               , inDataLength NUMBER
                               , ivObrigatorio VARCHAR2
                               ) RETURN rec_ret IS
      rRet rec_ret;
      
    BEGIN
      DECLARE
        vDominio     VARCHAR2(100) := UPPER(ivColumnName);
        vCol         VARCHAR2(100);
        vObrigatorio VARCHAR2(100);
        nTam         NUMBER;
      BEGIN
        vDominio := fGetDominio(vDominio);
        vCol := fMontaParam(ivColumnName,ivDataType);
        vObrigatorio := CASE ivObrigatorio WHEN 'S' THEN 'obrigatorio' END;
        nTam := LEAST(GREATEST(NVL(inDataLength+3,30),5),80);
        IF vDominio IS NOT NULL THEN
          rRet.texto1 := 'htp.tableData(htf.formSelectOpen('''||vCol||''', cAttributes=>''id="'||vCol||'" class="box '||vObrigatorio||'" data-ivDominio="'||vDominio||'" data-defVal="''||vRow.'||LOWER(ivColumnName)||'||''"'')||
                          htf.formSelectClose);';
        ELSE
          IF ivDataType = 'DATE' THEN
            rRet.texto1 := 'htp.tableData(htf.formText('''||vCol||''', '||nTam||', '||NVL(inDataLength,30)||', TO_CHAR(vRow.'||LOWER(ivColumnName)||',''DD/MM/RRRR''), ''id="'||vCol||'" class="box datepicker '||vObrigatorio||'" ''));';
          ELSIF ivDataType = 'NUMBER' THEN
            IF upper(ivColumnName) LIKE 'VL\_%' ESCAPE '\' THEN
              rRet.texto1 := 'htp.tableData(htf.formText('''||vCol||''', '||nTam||', '||NVL(inDataLength,30)||', TO_CHAR(vRow.'||LOWER(ivColumnName)||',cvFmt), ''id="'||vCol||'" class="box box_monetario numberDec '||vObrigatorio||'" ''));';
            ELSE
              rRet.texto1 := 'htp.tableData(htf.formText('''||vCol||''', '||nTam||', '||NVL(inDataLength,30)||', vRow.'||LOWER(ivColumnName)||', ''id="'||vCol||'" class="box numero '||vObrigatorio||'" onKeyPress="OnlyNumbers(this, true);" ''));';
            END IF;
          ELSE
            rRet.texto1 := 'htp.tableData(htf.formText('''||vCol||''', '||nTam||', '||NVL(inDataLength,30)||', vRow.'||LOWER(ivColumnName)||', ''id="'||vCol||'" class="box '||vObrigatorio||'" ''));';
          END IF;
        END IF;
      END;
      RETURN rRet;
    END fGetCampoCadastro;
  
    FUNCTION fGetCamposCadastro RETURN rec_ret IS
      rRet      rec_ret;
      rRetCampo rec_ret;
    BEGIN
      FOR r IN cColunas LOOP
        IF r.pk = 'N' and r.virtual_column = 'NO' THEN
          rRetCampo := fGetCampoCadastro ( ivColumnName  => r.column_name
                                         , ivDataType    => r.data_type
                                         , inDataLength  => r.data_length
                                         , ivObrigatorio => r.obrigatorio
                                         );
          IF rRetCampo.texto2 IS NOT NULL THEN
            rRet.texto2 := rRet.texto2 || CASE WHEN rRet.texto2 IS NOT NULL THEN CHR(10) END ||'      '||rRetCampo.texto2;
          END IF;
          rRet.texto1 := rRet.texto1 || '          htp.tableRowOpen;
            htp.tableData(''<label for="'||fMontaParam(r.column_name,r.data_type)||'">'||INITCAP(r.column_name)||':'||CASE r.obrigatorio WHEN 'S' THEN '''||cvObrig||''' END||'</label>'',cnowrap => 1);
            '||rRetCampo.texto1||'
          htp.tableRowClose;'||CHR(10)||CHR(10);
        END if;
      END LOOP;
      RETURN rRet;
    END fGetCamposCadastro;
   
    FUNCTION fGetCamposMetodo RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      vInds   VARCHAR2(32000);
      nTam    NUMBER;
    BEGIN
      FOR r IN cColunas LOOP
        nTam := r.maior;
        IF r.pk = 'N' AND r.virtual_column = 'NO' THEN
          vCampos := vCampos|| '    vRow.'||RPAD(LOWER(r.column_name),nTam,' ')||':= '||fMontaParam(r.column_name,r.data_type)||';'||CHR(10);
          vInds   := vInds  || '    vInd.'||RPAD(LOWER(r.column_name),nTam,' ')||':= TRUE;'||CHR(10);
        END if;
      END LOOP;
      
      vCampos := '    vRow.'||RPAD(LOWER(vPk),nTam,' ')||':= '||fGetParamPk||';'||CHR(10)||vCampos;
      vInds   := '    vInd.'||RPAD(LOWER(vPk),nTam,' ')||':= FALSE;'||CHR(10)||vInds;
      
      RETURN vCampos ||CHR(10)|| vInds;
    END fGetCamposMetodo;
  
    FUNCTION fMontaMetodo RETURN VARCHAR2 IS
      vCampos VARCHAR2(32000);
      nRecuo  NUMBER;
    BEGIN
      nRecuo := 12;
      FOR r IN cColunas LOOP
        vCampos := vCampos|| LPAD(' ',nRecuo,' ')||                 
                   ', '||RPAD(fMontaParam(r.column_name,r.data_type),r.maior+3,' ')||
                   ' => '||fMontaParam(r.column_name,r.data_type)||CHR(10);
      END LOOP;
      RETURN '    pMetodo ('||SUBSTR(vCampos,nRecuo+2)||LPAD(' ',nRecuo,' ')||');';
    END fMontaMetodo;
  BEGIN
    vTabela   := LOWER(ivTabela);
    vPackage  := UPPER(ivPackage);
    vSchema   := UPPER(ivSchema);
    vSchmaTab := UPPER(ivSchmaTab);
    vTitulo   := ivTitulo;
    vId       := ivId;
  
    DECLARE
      rRet rec_ret;
    BEGIN
      BEGIN
        SELECT cc.column_name
          INTO vPk
          FROM dba_constraints c
             , dba_cons_columns cc
         WHERE c.table_name = UPPER(vTabela)
           AND (c.owner = vSchmaTab OR vSchmaTab IS NULL)
           AND cc.constraint_name = c.constraint_name
           AND c.constraint_type = 'P';
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(cnApplicationError,SQLERRM);
      END;
  
      -- pks
      pPrint('CREATE OR REPLACE PACKAGE '||lower(vSchema)||'.'||lower(vPackage)||' IS');
        pPrint('  cnApplicationError CONSTANT     INTEGER := -20050;');
        pPrint('  eApplicationError               EXCEPTION;');
        pPrint('  PRAGMA EXCEPTION_INIT(eApplicationError,-20050);'||CHR(10));  
      
        pPrint('  PROCEDURE pShowResultado;'||CHR(10));  
      
        pPrint('  PROCEDURE pShowResultadoLista;'||CHR(10));  
      
        pPrint('  PROCEDURE pCadastro('||fGetParamPk('S','S')||');'||CHR(10));  
      
        pPrint('  PROCEDURE pMetodo'||fGetParametros(19)||';'||CHR(10));  
      
        pPrint('  PROCEDURE pMetodoJson'||fGetParametros(23)||';'||CHR(10));  
      
        pPrint('  PROCEDURE pMetodoExcluir('||fGetParamPk('S')||');'||CHR(10)); 
       
        pPrint('  PROCEDURE pMetodoExcluirJson(il'||fCapitalize(vPk)||' IN OWA_UTIL.IDENT_ARR);'||CHR(10));  
      
      pPrint('END;'||CHR(10)||'/'||CHR(10));
    
      -- pkb
      pPrint('CREATE OR REPLACE PACKAGE BODY '||LOWER(vSchema)||'.'||LOWER(vPackage)||' IS');
        pPrint('  cvPackage CONSTANT VARCHAR2(30)  := '''||LOWER(vPackage)||'.'';');  
        pPrint('  cvMetodo  CONSTANT VARCHAR2(5)   := ''POST'';');  
        pPrint('  cvTitulo  CONSTANT VARCHAR2(50)  := '''||vTitulo||''';');  
        pPrint('  cvObrig   CONSTANT VARCHAR2(100) := ''<span class="obrigatorio">''||CHR(38)||''nbsp;*</span>'';'||CHR(10));  
        pPrint('  cvFmt     CONSTANT VARCHAR2(100) := ''FM999G999G999G999G999G999G999G999G990D00'';'||CHR(10));  
        
      
        pPrint('  PROCEDURE pShowResultado IS');
        pPrint('    vAttrLink VARCHAR2(4000);
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;

    P_MENU_PRINC(ivTitle=>cvTitulo||'' - Consultar'');

    htp.formOpen(cvPackage||''pShowResultado'', cvMetodo, NULL, NULL, '' role="form" name="formConsulta'||INITCAP(vID)||'" id="formConsulta'||INITCAP(vID)||'" '');
      htp.p(''<div style="width: 100%;">'');
        htp.p(''<fieldset><legend class="titulo2"><b>''||cvTitulo||'' - Consultar</b></legend>'');
          htp.tableOpen(''id="'||vTabela||'" class="display compact cell-border textos"'');
          htp.tableClose;
        htp.p(''</fieldset>'');
      htp.p(''</div>'');
    htp.formClose;');
    
        pPrint('    htp.script(''
    function showCad'||INITCAP(vID)||'(cd, tab){
      var carregou = false;
      jDialog.open({ name       : "dlgCad'||INITCAP(vID)||'"
                   , title      : "''||cvTitulo||'' - "+(!cd ? "Cadastrar" : "Alterar")
                   , url        : "''||cvPackage||''pCadastro?'||fGetParamPk||'="+cd
                   , resizable  : false
                   , width      : 750
                   , height     : '||TO_CHAR((100+40*fContaCampos))||'
                   , cancelBtn  : true
                   , cancelText : "Voltar"
                   , confirmBtn : true
                   , confirmText: "Confirmar"
                   , onConfirm  : function(){ return confirmaCad'||INITCAP(vID)||'(tab);}
                   , onLoad     : function(){ setTimeout(initDlg'||INITCAP(vID)||', 100); }
                  });
    }

    function reload'||INITCAP(vID)||'(){
      $("#'||vTabela||'").DataTable().refresh("''||cvPackage||''pShowResultadoLista?"+$("#formConsulta'||INITCAP(vID)||'").serialize());
    }

    $(document).ready(function() {
      //$(".cp-res").on("change", reload'||INITCAP(vID)||');

      var tab = $("#'||vTabela||'").DataTable({
          ajax: {"url": "''||cvPackage||''pShowResultadoLista''||vAttrLink||''"}
        , actDel: {url: "''||cvPackage||''pMetodoExcluirJson", ukName: "il'||fCapitalize(vPk)||'"}
        , addUrl: function(){ showCad'||INITCAP(vID)||'("", tab); }
        , columns: '||CHR(91)||'
          '||fGetParamsDatatable||'           
          '||CHR(93)||'
        , order: '||CHR(91)||CHR(93)||'
        , scrollY: "400px"
      });
      $("#'||vTabela||' tbody").on("click", "tr td.tdAct .mdi'||CHR(91)||'name'||CHR(93)||':not(.disabled)", function(){
        var el = $(this);
        var rw = tab.row(el.closest("tr"))
        var dt = rw.data();
        switch(el.attr("name")) {
          case "edt": showCad'||INITCAP(vID)||'(dt.cd, tab); break;
        }
      });
    });
    '');');
        pPrint('  END pShowResultado;'||CHR(10));  
    
        rRet := fGetListaJson;
      
        pPrint('  PROCEDURE pShowResultadoLista IS');
        pPrint(
'    oObj   PLJSON;
    oLst   PLJSON_LIST := NEW PLJSON_LIST;
    vIco   VARCHAR2(4000);
    
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;

    vIco := PKG_ICONS.fIcon(''edit'', ivAtrib=>''name="edt"'', ivLabel=>''Editar o registo'');

    '||rRet.texto1||'
    
    oObj := NEW PLJSON;
    oObj.put(''data'', oLst);
    oObj.put(''data_act'', vIco);
    '||CASE WHEN rRet.texto2 IS NOT NULL THEN CHR(10)||rRet.texto2 END||'
    oObj.htp;
  EXCEPTION
    WHEN OTHERS THEN
      PKG_JSON.printMetodoJSON(''Ocorreu um erro ao buscar dados: ''||SQLERRM, TRUE);');
      pPrint('  END pShowResultadoLista;'||CHR(10));  
    
      pPrint('  PROCEDURE pCadastro('||fGetParamPk('S','S')||') IS '||CHR(10));  
      pPrint(
'    vRow '||fTabela||'%ROWTYPE;
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;
    
    BEGIN
      SELECT *'||NULL/*fGetColSelect(13)*/||'
        INTO vRow
        FROM '||fTabela||' tab
       WHERE tab.'||lower(vPk)||' = '||fGetParamPk||';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;'||CHR(10));

        rRet := fGetCamposCadastro;
    
        pPrint('    htp.formOpen(NULL, cAttributes=>''name="frmCad'||INITCAP(vID)||'" id ="frmCad'||INITCAP(vID)||'" onSubmit="return false;"'');
      htp.formHidden('''||fGetParamPk||''','||fGetParamPk||');
      htp.p(''<fieldset><legend class="titulo2"><b>''||cvTitulo||'' - ''||CASE WHEN '||fGetParamPk||' IS NULL THEN ''Cadastrar'' ELSE ''Alterar'' END||''</b></legend>'');
        htp.tableOpen(''width="100%" border="0" class="textos" cellspacing="4" cellpadding="2"'');
          htp.tableRowOpen;
            htp.tableData(cAttributes => ''width="100px"'');
            htp.tableData;
          htp.tableRowClose;
          
'||rRet.texto1||'
        htp.tableClose;
      htp.p(''</fieldset>'');
    htp.formClose;
    
    htp.script(''
    function initDlg'||INITCAP(vID)||'(){
      //$(".jDialogInner_dlgCad'||INITCAP(vID)||'").css("overflow-y","hidden");
      $(".jDialogInner_dlgCad'||INITCAP(vID)||'").css("overflow-y","auto");
      
      $("#frmCad'||INITCAP(vID)||' select'||CHR(91)||'data-ivDominio'||CHR(93)||'").buscaDomain();
      $("#frmCad'||INITCAP(vID)||' .datepicker").datepicker();
      SIGFE.timepicker();
      $("#frmCad'||INITCAP(vID)||' .numberDec").keypress(function(e){return SIGFE.validateNumber(e);} );
      '||chr(10)||
      rRet.texto2||'
    }

    function confirmaCad'||INITCAP(vID)||'(tab){
      var f=$("#frmCad'||INITCAP(vID)||'");
      if (!f.valObrigatorio()){
        return false
      }

      jSpinner.ativaSpinner(".jDialog_dlgCad'||INITCAP(vID)||'");
      $.getJSON("''||cvPackage||''pMetodoJson",f.serialize(), function (data) {
        if (!data.erro){
          jDialog.close("dlgCad'||INITCAP(vID)||'");
          tab.refresh();
        }else{
          if (data.msg){
            alert(data.msg);
          }
        }
      }).fail(function(xhr) {
        if (xhr.getAllResponseHeaders()){
          alert("Ocorreu um erro ao salvar registo!");
        }
      }).always(function(){
        jSpinner.desativaSpinner(".jDialog_dlgCad'||INITCAP(vID)||'");
      });

      return false;
    }
    $(document).ready(function(){
    });
    '');');  
        pPrint('  END pCadastro;'||CHR(10));  
    
        pPrint('  PROCEDURE pMetodo'||fGetParametros(19)||' IS '||CHR(10));  
        pPrint(
'    vRow cg$'||LOWER(vTabela)||'.cg$row_type;
    vInd cg$'||LOWER(vTabela)||'.cg$ind_type;
    vErro VARCHAR2(4000);
  BEGIN
    vRow.the_rowid := NULL;

'||fGetCamposMetodo||'
    PKG_MFN_UTIL.setDsMotivo(cvTitulo);
    IF vRow.'||LOWER(vPk)||' IS NULL  THEN
      cg$'||LOWER(vTabela)||'.ins(vRow, vInd);
    ELSE
      cg$'||LOWER(vTabela)||'.upd(vRow, vInd);
    END IF;');  
        pPrint('  END pMetodo;'||CHR(10));
    
        pPrint('  PROCEDURE pMetodoJson'||fGetParametros(23)||' IS '||CHR(10)); 
        pPrint(
'    vErro    VARCHAR2(4000);
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;

'||fMontaMetodo||'
    PKG_JSON.printMetodoJSON(''Registo salvo com sucesso.'');
  EXCEPTION
    WHEN eApplicationError THEN
      ROLLBACK;
      vErro := REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''');
      PKG_JSON.printMetodoJSON(vErro, TRUE);
    WHEN OTHERS THEN
      PKG_JSON.printMetodoJSON(''Ocorreu um erro ao salvar registo: ''||SQLERRM, TRUE);
      ROLLBACK;'); 
        pPrint('  END pMetodoJson;'||CHR(10)); 
    
        pPrint('  PROCEDURE pMetodoExcluir('||fGetParamPk('S')||') IS '||CHR(10));   
        pPrint(
'    vRow  cg$'||lower(vTabela)||'.CG$PK_TYPE;
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;
    
    vRow.the_rowid  := NULL;  
    
    vRow.'||LOWER(vPk)||' := '||fGetParamPk||';

    cg$'||LOWER(vTabela)||'.DEL(vRow);');   
        pPrint('  END pMetodoExcluir;'||CHR(10)); 
    
        pPrint('  PROCEDURE pMetodoExcluirJson(il'||fCapitalize(vPk)||' IN OWA_UTIL.IDENT_ARR) IS '||CHR(10));  
        pPrint(
'    vErro VARCHAR2(4000);
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;
    
    FOR rIdx IN 1..il'||fCapitalize(vPk)||'.COUNT LOOP
      pMetodoExcluir(il'||fCapitalize(vPk)||'(rIdx));
    END LOOP;
    PKG_JSON.printMetodoJSON(null);
  EXCEPTION
    WHEN eApplicationError THEN
      ROLLBACK;
      vErro := REPLACE(SQLERRM,''ORA''||cnApplicationError||'': '','''');
      PKG_JSON.printMetodoJSON(vErro, TRUE);
    WHEN OTHERS THEN
      PKG_JSON.printMetodoJSON(''Ocorreu um erro ao excluir registo: ''||SQLERRM, TRUE);
      ROLLBACK;'); 
      pPrint('  END pMetodoExcluirJson;'||CHR(10)); 
  
      pPrint('END;'||CHR(10)||'/'||CHR(10));
  
      pPrint('GRANT EXECUTE ON '||LOWER(vSchema)||'.'||LOWER(vPackage)||' TO PUBLIC'||CHR(10)||'/');
  
      pPrint('CREATE OR REPLACE PUBLIC SYNONYM '||LOWER(vPackage)||' FOR '||LOWER(vSchema)||'.'||LOWER(vPackage)||''||CHR(10)||'/');
    END;
    RETURN cSaida;
  END fGeraCadastro;
BEGIN
  DECLARE
    cResult clob;
    nTam  PLS_INTEGER;
    nPos  PLS_INTEGER;
  BEGIN
    cResult := fGeraCadastro( ivTabela   => '&tabela'
                            , ivPackage  => '&package'
                            , ivSchema   => '&schema'
                            , ivSchmaTab => '&schemaTab'
                            , ivTitulo   => '&titulo'
                            , ivId       => '&id'
                            );
    nTam := 30000;
    nPos := 1;

    WHILE nPos < dbms_lob.getlength ( cResult ) LOOP
      dbms_output.put_line ( dbms_lob.substr ( cResult, nTam, nPos ) );
      nPos := nPos + nTam;
    END LOOP;
  END;
END;
