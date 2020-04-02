DECLARE
  cnApplicationError CONSTANT     INTEGER := -20050;
  eApplicationError               EXCEPTION;
  PRAGMA EXCEPTION_INIT(eApplicationError,-20050);
  
  vTitulo   VARCHAR2(100);
  vTabela   VARCHAR2(100);
  vPackage  VARCHAR2(100);
  vSchema   VARCHAR2(100);
  vSchmaTab VARCHAR2(100);
  vTexto    VARCHAR2(32000);
  vId       VARCHAR2(32000);
  
  vPk       VARCHAR2(100);
  
  vTipoPrint VARCHAR2(100) := 'DBMS';
  
  CURSOR cColunas IS
    SELECT col.column_name
         , col.data_type
         , MAX(LENGTH(column_name)) over () maior
         , COUNT(1) over () total
         , NVL((SELECT 'S'
                  FROM dba_constraints c
                     , dba_cons_columns cc
                 WHERE c.table_name = col.table_name
                   AND cc.constraint_name = c.constraint_name
                   AND cc.column_name = col.column_name
                   AND c.constraint_type = 'P'),'N') pk
         ,CASE NULLABLE WHEN 'Y' THEN 'N' ELSE 'S' END obrigatorio
      FROM dba_tab_cols col
     WHERE col.TABLE_NAME = UPPER(vTabela)
       AND (col.owner = vSchmaTab OR vSchmaTab IS NULL);
  
  PROCEDURE pPrint(ivTexto VARCHAR2) IS
  BEGIN
    -- Se quiser um comportamento diferente tem q implementar
    IF vTipoPrint = 'DBMS' THEN
      DBMS_OUTPUT.PUT_LINE(ivTexto);
    END IF;
  END pPrint;
  
  FUNCTION fGetTipoParam (ivTipo VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE ivTipo WHEN 'VARCHAR2' THEN 'v'
                       WHEN 'NUMBER' THEN   'n'
                       WHEN 'DATE' THEN     'd'
                       WHEN 'BOOLEAN' THEN  'b' END;
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
                 fCapitalize(r.column_name),r.maior,' ')||
                 ' IN '||r.data_type||
                 CASE r.pk WHEN 'S' THEN ' DEFAULT NULL' END||CHR(10);
    END LOOP;
    RETURN '('||SUBSTR(vParams,inRecuo+2)||LPAD(' ',inRecuo,' ')||')';
  END fGetParametros;
  
  FUNCTION fGetParamsDatatable RETURN VARCHAR2 IS
    vParams VARCHAR2(32000);
    nTam    NUMBER;
  BEGIN
    FOR r IN cColunas LOOP
      nTam := r.maior;
      IF r.pk <> 'S' THEN
        vParams := vParams|| '          ,{ "data": '||RPAD('"'||LOWER(r.column_name)||'"',nTam+2,' ')||',title: "'||LOWER(r.column_name)||'"} '||CHR(10);
      END IF;
    END LOOP;
    vParams :=' { "data": ""'||LPAD(' ',nTam,' ')||',title: "", orderable: false, className: "select-checkbox all", "defaultContent": ""}'||CHR(10)||
              vParams||
              '          ,{ "data": ""'||LPAD(' ',nTam,' ')||',title: "Acções", className:"dt-icons tdAct", orderable:false, searchable:false, render: $.fn.dataTable.render.globalAct("data_act")}';
    RETURN vParams;
  END fGetParamsDatatable;
  
  FUNCTION fGetListaJson RETURN VARCHAR2 IS 
    vTexto     VARCHAR2(32000);
    vSelect    VARCHAR2(32000);
    vRespostas VARCHAR2(32000);
    vTam       NUMBER;
  BEGIN
    FOR r IN cColunas LOOP
      vTam := r.maior;
      vSelect := vSelect ||CASE WHEN vSelect IS NOT NULL THEN '                         ,'END||' '||LOWER(r.column_name)||CHR(10);
      IF r.pk <> 'S' THEN
      
        vRespostas := vRespostas|| '      PKG_JSON.addAtributoColecaoLinhaAtrib(nData, PKG_JSON.addAtributo('||RPAD(''''||LOWER(r.column_name)||'''',vTam+2,' ')||', i'||fGetTipoParam(r.data_type)||'Valor => cReg.'||LOWER(r.column_name)||'));'||chr(10);
      END IF;
      
    END LOOP;
    vSelect := SUBSTR(vSelect,1,LENGTH(vSelect)-1);
    vTexto := '  FOR cReg IN ( SELECT'||vSelect||'
                      FROM '||CASE WHEN vSchmaTab IS NOT NULL THEN vSchmaTab||'.' END||vTabela ||'
                  ORDER BY 1
                ) 
      LOOP
      PKG_JSON.addAtributoColecaoLinha(nData);
      PKG_JSON.addAtributoColecaoLinhaAtrib(nData, PKG_JSON.addAtributo('||RPAD('''cd''',vTam+2,' ')||', inValor => cReg.'||LOWER(vPk)||'));
      
'||vRespostas||'    
    END LOOP;';
    RETURN vTexto;
  END fGetListaJson;
  
  FUNCTION fGetCamposCadastro RETURN VARCHAR2 IS
    vCampos VARCHAR2(32000);
  BEGIN
    FOR r IN cColunas LOOP
      IF r.pk = 'N' THEN
        vCampos := vCampos || '          htp.tableRowOpen;
            htp.tableData(''<label for="'||fMontaParam(r.column_name,r.data_type)||'">'||INITCAP(r.column_name)||':'||CASE r.obrigatorio WHEN 'S' THEN '''||cvObrig||''' END||'</label>'',cnowrap => 1);
            htp.tableData(''<input TYPE="text" class="box '||CASE r.obrigatorio WHEN 'S' THEN 'obrigatorio' END||'" name="'||fMontaParam(r.column_name,r.data_type)||'" id="'||fMontaParam(r.column_name,r.data_type)||'" VALUE="''||vRow.'||LOWER(r.column_name)||'||''" size="100" maxlength="400" >'');
          htp.tableRowClose;'||CHR(10)||CHR(10);
      END if;
    END LOOP;
    RETURN vCampos;
  END fGetCamposCadastro;
   
  FUNCTION fGetCamposMetodo RETURN VARCHAR2 IS
    vCampos VARCHAR2(32000);
    vInds   VARCHAR2(32000);
    nTam    NUMBER;
  BEGIN
    FOR r IN cColunas LOOP
      nTam := r.maior;
      IF r.pk = 'N' THEN
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
                 ', '||RPAD(fMontaParam(r.column_name,r.data_type),r.maior,' ')||
                 ' => '||fMontaParam(r.column_name,r.data_type)||CHR(10);
    END LOOP;
    RETURN '    pMetodo ('||SUBSTR(vCampos,nRecuo+2)||LPAD(' ',nRecuo,' ')||');';
  END fMontaMetodo;
  
BEGIN
  vTabela := LOWER('&tabela');
  vPackage := UPPER('&package');
  vSchema := UPPER('&schema');
  vSchmaTab := UPPER('&schemaTab');
  vTitulo := '&titulo';
  vId     := '&id';
  
/*  vTabela   := LOWER('tb_aipex_processo');
  vPackage  := UPPER('pkg_aipex_cad_processo');
  vSchema   := UPPER('AIPEX_APP');
  vSchmaTab := UPPER('AIPEX');
  vTitulo   := 'Processos';*/

  
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
    pPrint('  cvObrig   CONSTANT VARCHAR2(100) := ''<span class="obrigatorio">'||CHR(38)||'nbsp;*</span>'';'||CHR(10));  
    
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
    
    pPrint('  PROCEDURE pShowResultadoLista IS');
    pPrint(
'    vJSON  VARCHAR2(15) := ''json'';
    nData  PLS_INTEGER;
    vIco   VARCHAR2(4000);
  BEGIN
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;

    PKG_JSON.iniciaJSON(vJSON);

    vIco := PKG_ICONS.fIcon(''edit'',         ivAtrib=>''name="edt"'', ivLabel=>''Editar o registo'');

    PKG_JSON.addAtributoRaiz(vJSON, PKG_JSON.addAtributo(''data_act'', ivValor => vIco));

    nData := PKG_JSON.addAtributo(''data'');
    PKG_JSON.addAtributoRaiz(vJSON, nData);
    PKG_JSON.initAtributoColecao(nData);
    '||fGetListaJson||'
    --PKG_JSON.makeDominioJSON(''SIM_NAO'', vJSON, inInicia=>0);
    
    PKG_JSON.getJSON(vJSON);
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
      SELECT *
        INTO vRow
        FROM '||fTabela||' tab
       WHERE tab.'||lower(vPk)||' = '||fGetParamPk||';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;

    htp.formOpen(NULL, cAttributes=>''name="frmCad'||INITCAP(vID)||'" id ="frmCad'||INITCAP(vID)||'" onSubmit="return false;"'');
      htp.formHidden('''||fGetParamPk||''','||fGetParamPk||');
      htp.p(''<fieldset><legend class="titulo2"><b>''||cvTitulo||'' - ''||CASE WHEN '||fGetParamPk||' IS NULL THEN ''Cadastrar'' ELSE ''Alterar'' END||''</b></legend>'');
        htp.tableOpen(''width="100%" border="0" class="textos" cellspacing="4" cellpadding="2"'');
          htp.tableRowOpen;
            htp.tableData(cAttributes => ''width="100px"'');
            htp.tableData;
          htp.tableRowClose;
          
'||fGetCamposCadastro||'
        htp.tableClose;
      htp.p(''</fieldset>'');
    htp.formClose;
    
    htp.script(''
    function initDlg'||INITCAP(vID)||'(){
      $(".jDialogInner_dlgCad'||INITCAP(vID)||'").css("overflow-y","hidden");
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
    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN
      RETURN;
    END IF;

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
  
  pPrint('CREATE PUBLIC SYNONYM '||LOWER(vPackage)||' FOR '||LOWER(vSchema)||'.'||LOWER(vPackage)||''||CHR(10)||'/');

END;
