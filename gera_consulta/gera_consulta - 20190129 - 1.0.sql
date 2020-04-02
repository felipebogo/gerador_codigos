-- 1.0 - nascimento - 29/01/2019
DECLARE
  PROCEDURE pGeraConsulta (ivSql     VARCHAR2
                          ,ivSchema  VARCHAR2
                          ,ivPackage VARCHAR2
                          ,ivTitulo  VARCHAR2
                          ,ivId      VARCHAR2 DEFAULT NULL
                          ) IS
    gvColunasTab   VARCHAR2(32767);
    gvColunasLista VARCHAR2(32767);
    gvCd           VARCHAR2(32767);
    vSql           VARCHAR2(32767);
    nNrColunas     NUMBER;
    tColunas       dbms_sql.desc_tab3;
    nCursor        NUMBER;
    vVarchar2      VARCHAR2(4000);
    nNumber        NUMBER;
    dDate          DATE;
    nStatus        NUMBER;
    PROCEDURE pColunasTab(ivColuna VARCHAR2) IS
      vPad VARCHAR2(32767) := LPAD(' ',29,' ');
    BEGIN
      IF gvColunasTab IS NOT NULL THEN
        gvColunasTab := gvColunasTab || ',';
      END IF; 
      gvColunasTab := gvColunasTab||vPad||' { "data": "'||LOWER(ivColuna)||'",title: "'||INITCAP(ivColuna)||'"}'||CHR(10);
    END pColunasTab;
    
    PROCEDURE pColunasLista(ivColuna VARCHAR2) IS
      vPad VARCHAR2(32767) := LPAD(' ',6,' ');
    BEGIN
      gvColunasLista := gvColunasLista||vPad||'oObj.put('''||LOWER(ivColuna)||''', rCur.'||LOWER(ivColuna)||');'||CHR(10);
    END pColunasLista;
    
    FUNCTION fFormataSql RETURN VARCHAR2 IS
      vPad VARCHAR2(32767) := LPAD(' ',6,' ');
    BEGIN
      RETURN vPad||REPLACE(vSql,CHR(10),CHR(10)||vPad);
    END fFormataSql;
    
    PROCEDURE pDefineCursor IS 
    BEGIN
      vSql := ivSql;--'select 1 coluninha_1, ''b'' coluninha_2 from dual';
      nCursor := dbms_sql.open_cursor;
      
      dbms_sql.parse(nCursor
                    ,vSql
                    ,dbms_sql.native);
      dbms_sql.describe_columns3(nCursor
                                ,nNrColunas
                                ,tColunas);
      
      FOR i IN 1 .. nNrColunas LOOP
        CASE
          WHEN tColunas(i).col_type IN (dbms_sql.Varchar2_Type
                                       ,dbms_sql.Char_Type
                                       ) THEN
            -- varchar2
            dbms_sql.define_column(nCursor
                                  ,i
                                  ,vVarchar2
                                  ,4000);
          WHEN tColunas(i).col_type = dbms_sql.Number_Type THEN
            -- number
            dbms_sql.define_column(nCursor
                                  ,i
                                  ,nNumber);
          WHEN tColunas(i).col_type = dbms_sql.Date_Type THEN
            -- date
            dbms_sql.define_column(nCursor
                                  ,i
                                  ,dDate);
        END CASE;
      END LOOP;
    END pDefineCursor;
    
    PROCEDURE pExecutaCursor IS
    BEGIN
      nStatus := dbms_sql.execute(nCursor);
      IF dbms_sql.fetch_rows(nCursor) > 0 THEN
          --bNoDataFound := FALSE;
          FOR i IN 1 .. nNrColunas LOOP
            /*dbms_output.put_line(tColunas(i).col_type           );
            dbms_output.put_line(tColunas(i).col_max_len        );
            dbms_output.put_line(tColunas(i).col_name           );
            dbms_output.put_line(tColunas(i).col_name_len       );
            dbms_output.put_line(tColunas(i).col_schema_name    );
            dbms_output.put_line(tColunas(i).col_schema_name_len);
            dbms_output.put_line(tColunas(i).col_precision      );
            dbms_output.put_line(tColunas(i).col_scale          );
            dbms_output.put_line(tColunas(i).col_charsetid      );
            dbms_output.put_line(tColunas(i).col_charsetform    );
            --dbms_output.put_line(tColunas(i).col_null_ok        );
            dbms_output.put_line(tColunas(i).col_type_name      );
            dbms_output.put_line(tColunas(i).col_type_name_len  );*/
            /*CASE
              WHEN tColunas(i).col_type IN (dbms_sql.Varchar2_Type
                                           ,dbms_sql.Char_Type) THEN
                -- varchar2
                dbms_sql.column_value(nCursor
                                     ,i
                                     ,vVarchar2);
              WHEN tColunas(i).col_type = dbms_sql.Number_Type THEN
                -- number
                dbms_sql.column_value(nCursor
                                     ,i
                                     ,nNumber);
              WHEN tColunas(i).col_type = dbms_sql.Date_Type THEN
                -- date
                dbms_sql.column_value(nCursor
                                     ,i
                                     ,dDate);
            END CASE;*/
            IF tColunas(i).col_type = dbms_sql.Number_Type AND gvCd IS NULL THEN
              gvCd := LOWER(tColunas(i).col_name);
            END IF;
            pColunasTab(tColunas(i).col_name);
            pColunasLista(tColunas(i).col_name);
          END LOOP;
        END IF;
        dbms_sql.close_cursor(nCursor);
    END pExecutaCursor;
    PROCEDURE pGeraCodigo IS
      cCodigo clob := empty_clob;
      vTabCon        VARCHAR2(1000);
      vPackage       VARCHAR2(1000);
      vFormCon       VARCHAR2(1000);
      vFunCon        VARCHAR2(1000);
      vFunWinDet     VARCHAR2(1000);
      vFunDlgDet     VARCHAR2(1000);
      vFunInitDlgDet VARCHAR2(1000);
    BEGIN
      vPackage := ivSchema||'.'||ivPackage;
      vFormCon := 'formConsulta'||INITCAP(ivId);
      vTabCon := 'tab_consulta'||CASE WHEN ivID IS NOT NULL THEN '_'||ivID END;
      vFunWinDet := 'showDlgDetalhes'||CASE WHEN ivID IS NOT NULL THEN INITCAP(ivID) END;
      vFunDlgDet := 'dlgDetalhes'||CASE WHEN ivID IS NOT NULL THEN INITCAP(ivID) END;
      vFunInitDlgDet := 'initDlgDetalhes'||CASE WHEN ivID IS NOT NULL THEN INITCAP(ivID) END;
      -- funçoes js
      vFunCon := 'reloadConsulta'||INITCAP(ivID);
      
      cCodigo := cCodigo || 'CREATE OR REPLACE PACKAGE '||vPackage||' IS'||chr(10);
      cCodigo := cCodigo || '  PROCEDURE pShowResultado;'||chr(10)||CHR(10);
      cCodigo := cCodigo || '  PROCEDURE pShowResultadoLista;'||chr(10)||chr(10);
      cCodigo := cCodigo || '  PROCEDURE pShowDetalhes (inCd IN NUMBER);'||chr(10);
      cCodigo := cCodigo || 'END;'||chr(10);
      cCodigo := cCodigo || '/'||chr(10)||chr(10);
      cCodigo := cCodigo || 'CREATE OR REPLACE PACKAGE BODY '||vPackage||' IS'||chr(10);
      cCodigo := cCodigo || '  cvPackage CONSTANT VARCHAR2(30)  := '''||ivPackage||'.'';'||chr(10);
      cCodigo := cCodigo || '  cvMetodo  CONSTANT VARCHAR2(5)   := ''POST'';'||chr(10);
      cCodigo := cCodigo || '  cvTitulo  CONSTANT VARCHAR2(50)  := '''||ivTitulo||''';'||chr(10);
      cCodigo := cCodigo || '  PROCEDURE pShowResultado IS'||chr(10);
      cCodigo := cCodigo || '  BEGIN'||chr(10);
      cCodigo := cCodigo || '    IF NOT WWSEC_APP_PRIV.CHECK_IF_LOGGED_ON THEN'||chr(10);
      cCodigo := cCodigo || '      RETURN;'||chr(10);
      cCodigo := cCodigo || '    END IF;'||chr(10)||chr(10);
      cCodigo := cCodigo || '    P_MENU_PRINC(ivTitle=>cvTitulo);'||chr(10);
      cCodigo := cCodigo || '    htp.formOpen(cvPackage||''pShowResultado'', cvMetodo, NULL, NULL, '' role="form" name="'||vFormCon||'" id="'||vFormCon||'" '');'||chr(10);
      cCodigo := cCodigo || '      htp.p(''<div style="width: 100%;">'');'||chr(10);
      cCodigo := cCodigo || '        htp.p(''<fieldset><legend class="titulo2"><b>''||cvTitulo||''</b></legend>'');'||chr(10);
      cCodigo := cCodigo || '          htp.tableOpen(''id="'||vTabCon||'" class="display compact cell-border textos"'');'||chr(10);
      cCodigo := cCodigo || '          htp.tableClose;'||chr(10);
      cCodigo := cCodigo || '        htp.p(''</fieldset>'');'||chr(10);
      cCodigo := cCodigo || '      htp.p(''</div>'');'||chr(10);
      cCodigo := cCodigo || '    htp.formClose;'||chr(10);
      cCodigo := cCodigo || '    htp.script('''||chr(10);
      cCodigo := cCodigo || '      function '||vFunCon||'(){'||chr(10);
      cCodigo := cCodigo || '        $("#'||vTabCon||'").DataTable().refresh("''||cvPackage||''pShowResultadoLista?"+$("#'||vFormCon||'").serialize());'||chr(10);
      cCodigo := cCodigo || '      }'||chr(10)||chr(10);
      cCodigo := cCodigo || '      function '||vFunWinDet||'(cd, tab){'||chr(10);
      cCodigo := cCodigo || '        jDialog.open({ name       : "'||vFunDlgDet||'"'||chr(10);
      cCodigo := cCodigo || '                     , title      : "''||cvTitulo||''"'||chr(10);
      cCodigo := cCodigo || '                     , url        : "''||cvPackage||''pShowDetalhes?inCd="+cd'||chr(10);
      cCodigo := cCodigo || '                     , resizable  : false'||chr(10);
      cCodigo := cCodigo || '                     , width      : 900'||chr(10);
      cCodigo := cCodigo || '                     , height     : 500'||chr(10);
      cCodigo := cCodigo || '                     , cancelBtn  : true'||chr(10);
      cCodigo := cCodigo || '                     , cancelText : "Voltar"'||chr(10);
      cCodigo := cCodigo || '                     , confirmBtn : false'||chr(10);
      cCodigo := cCodigo || '                     , onLoad     : function(){ setTimeout('||vFunInitDlgDet||', 100); }'||chr(10);
      cCodigo := cCodigo || '                    });'||chr(10);
      cCodigo := cCodigo || '      }'||chr(10)||chr(10);
      cCodigo := cCodigo || '      $(document).ready(function() {'||chr(10);
      cCodigo := cCodigo || '        //$(".cp-res").on("change", '||vFunCon||');'||chr(10)||chr(10);
      cCodigo := cCodigo || '        var tab = $("#'||vTabCon||'").DataTable({'||chr(10);
      cCodigo := cCodigo || '            ajax: {"url": "''||cvPackage||''pShowResultadoLista"}'||chr(10);
      cCodigo := cCodigo || '                  , columns: '||chr(91)||''||chr(10);
      cCodigo := cCodigo ||                                gvColunasTab;
      cCodigo := cCodigo || '                             ,{ "data": "",title: "Acções", className:"dt-icons tdAct", orderable:false, searchable:false, render: $.fn.dataTable.render.globalAct("data_act")}'||chr(10);
      cCodigo := cCodigo || '                             '||chr(93)||''||chr(10);
      cCodigo := cCodigo || '                  , order: '||chr(91)||''||chr(93)||''||chr(10);
      cCodigo := cCodigo || '                  , scrollY: "400px"'||chr(10);
      cCodigo := cCodigo || '                  });'||chr(10);
      cCodigo := cCodigo || '        $("#'||vTabCon||' tbody").on("click", "tr td.tdAct .mdi'||chr(91)||'name'||chr(93)||':not(.disabled)", function(){'||chr(10);
      cCodigo := cCodigo || '          var el = $(this);'||chr(10);
      cCodigo := cCodigo || '          var rw = tab.row(el.closest("tr"))'||chr(10);
      cCodigo := cCodigo || '          var dt = rw.data();'||chr(10);
      cCodigo := cCodigo || '          switch(el.attr("name")) {'||chr(10);
      cCodigo := cCodigo || '            case "detalhes": '||vFunWinDet||'(dt.'||nvl(gvCd,'cd')||', tab); break;'||chr(10);
      cCodigo := cCodigo || '          }'||chr(10);
      cCodigo := cCodigo || '        });'||chr(10);
      cCodigo := cCodigo || '      });'||chr(10);
      cCodigo := cCodigo || '    '');'||chr(10);
      cCodigo := cCodigo || '  END pShowResultado;'||chr(10)||chr(10);
      cCodigo := cCodigo || '  PROCEDURE pShowResultadoLista IS'||chr(10);
      cCodigo := cCodigo || '    oObj   PLJSON;'||chr(10);
      cCodigo := cCodigo || '    oLst   PLJSON_LIST := NEW PLJSON_LIST;'||chr(10);
      cCodigo := cCodigo || '    vIco   VARCHAR2(4000);'||chr(10);
      cCodigo := cCodigo || '    CURSOR cCur IS '||chr(10);
      cCodigo := cCodigo ||        fFormataSql||';'||chr(10);
      cCodigo := cCodigo || '  BEGIN'||chr(10);
      cCodigo := cCodigo || '    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN'||chr(10);
      cCodigo := cCodigo || '      RETURN;'||chr(10);
      cCodigo := cCodigo || '    END IF;'||chr(10)||chr(10);
      cCodigo := cCodigo || '    vIco := PKG_ICONS.fIcon(''visibility'', ivAtrib=>''name="detalhes"'', ivLabel=>''Detalhes do Registo'');'||chr(10)||chr(10);
      cCodigo := cCodigo || '    FOR rCur IN cCur LOOP'||chr(10);
      cCodigo := cCodigo || '      oObj := NEW PLJSON;'||chr(10);
      cCodigo := cCodigo ||        gvColunasLista;
      cCodigo := cCodigo || '      oObj.put(''data_act'', vIco);'||chr(10);
      cCodigo := cCodigo || '      oLst.append(oObj.to_json_value);'||chr(10);
      cCodigo := cCodigo || '    END LOOP;'||chr(10);
      cCodigo := cCodigo || '    oObj := NEW PLJSON;'||chr(10);
      cCodigo := cCodigo || '    oObj.put(''data'', oLst);'||chr(10);
      cCodigo := cCodigo || '    oObj.put(''data_act'', vIco);'||chr(10);
      cCodigo := cCodigo || '    oObj.htp;'||chr(10);
      cCodigo := cCodigo || '  EXCEPTION'||chr(10);
      cCodigo := cCodigo || '    WHEN OTHERS THEN'||chr(10);
      cCodigo := cCodigo || '      PKG_JSON.printMetodoJSON(''Ocorreu um erro ao buscar dados: ''||pkg_erro.fGetMsgErroSql(ivBacktrace => ''S''), TRUE);'||chr(10);
      cCodigo := cCodigo || '  END pShowResultadoLista;'||chr(10)||chr(10);
      cCodigo := cCodigo || '  PROCEDURE pShowDetalhes (inCd IN NUMBER) IS'||chr(10);
      cCodigo := cCodigo || '  BEGIN'||chr(10);
      cCodigo := cCodigo || '    IF NOT WWSEC_APP_PRIV.check_if_logged_on THEN'||chr(10);
      cCodigo := cCodigo || '      RETURN;'||chr(10);
      cCodigo := cCodigo || '    END IF;'||chr(10)||chr(10);
      cCodigo := cCodigo || '    htp.script('''||chr(10);
      cCodigo := cCodigo || '      function '||vFunInitDlgDet||'(){'||chr(10);
      cCodigo := cCodigo || '        $(".jDialogInner_'||vFunDlgDet||'").css("overflow-y","hidden");'||chr(10);
      cCodigo := cCodigo || '      }'||chr(10);
      cCodigo := cCodigo || '    '');'||chr(10)||chr(10);
      cCodigo := cCodigo || '    htp.p(''<fieldset><legend class="titulo2"><b>''||cvTitulo||''</b></legend>'');'||chr(10);
      cCodigo := cCodigo || '    htp.p(''</fieldset>'');'||chr(10);
      cCodigo := cCodigo || '  END pShowDetalhes;'||chr(10);
      cCodigo := cCodigo || 'END;'||chr(10);
      cCodigo := cCodigo || '/'||chr(10)||chr(10);
      cCodigo := cCodigo || 'GRANT EXECUTE ON '||vPackage||' TO PUBLIC;'||chr(10)||chr(10); 
      cCodigo := cCodigo || 'CREATE OR REPLACE PUBLIC SYNONYM '||ivPackage||' FOR '||vPackage||';'||chr(10)||chr(10);
      cCodigo := cCodigo || ''||chr(10);
      
      DBMS_OUTPUT.PUT_line(cCodigo);
    END pGeraCodigo;
  BEGIN
    pDefineCursor;
    pExecutaCursor;
    pGeraCodigo;
  END pGeraConsulta;
BEGIN
  pGeraConsulta(ivSql     => &<name="Sql"     type="string" required="yes" lines="5" hint="ex: SELECT * FROM Dual" >
               ,ivSchema  => &<name="Schema"  type="string" required="yes"           hint="ex: MINFIN_APP">
               ,ivPackage => &<name="Package" type="string" required="yes"           hint="ex: PKG_CONSULTA_XYZ">
               ,ivTitulo  => &<name="Titulo"  type="string" required="yes"           hint="ex: Consulta de XYZ">
               ,ivId      => &<name="Id"      type="string"                          hint="Id usado para criar elementos unicos ex: XYZ">
               );
  /*pGeraConsulta(ivSql     => 'select cd_pat_rev from tb_pat_rev where rownum < 500'
               ,ivSchema  => 'patrimonio_app'
               ,ivPackage => 'pkg_teste_consulta'
               ,ivTitulo  => 'pograma teste'
               ,ivId      => 'con'
               );*/
END;
/
