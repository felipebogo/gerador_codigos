<#assign maiorTamanho = 0>
<#list table.columns as col>
  <#if col.columnName?length gt maiorTamanho>
    <#assign maiorTamanho = col.columnName?length>
  </#if>
</#list>
<#assign maiorTamanhoCamelCaseVarchar = 0>
<#list table.columns as col>
  <#if col.columnNameCamelCase?length gt maiorTamanhoCamelCaseVarchar>
    <#assign maiorTamanhoCamelCaseVarchar = col.columnNameCamelCase?length>
  </#if>
</#list>
<#assign maiorTamanhoPk = 0>
<#list table.columns as col>
  <#if col.pk == 'Y' && col.columnName?length gt maiorTamanhoPk>
    <#assign maiorTamanhoPk = col.columnName?length>
  </#if>
</#list>
<#assign v_rec = "rec_"+table.name?lower_case?replace("tb_", "")>
<#assign v_rec_det = "rec_"+table.name?lower_case?replace("tb_", "")+"_det">
<#assign v_tab = "tab_"+table.name?lower_case?replace("tb_", "")>
<#assign v_table = table.name?lower_case>
<#assign v_get_json = "fGet"+table.name?replace("TB_","")?replace("_"," ")?capitalize?replace(" ","")+"Json">
<#assign v_get_json_list = "fGet"+table.name?replace("TB_","")?replace("_"," ")?capitalize?replace(" ","")+"JsonList">
<#list table.columnsPk as col>
  <#assign v_p_pk = "i"+col.dataType[0]?lower_case+col.columnNameCamelCase?cap_first>  
</#list>
<#list table.columnsPk as col>
  <#assign v_po_pk = "io"+col.dataType[0]?lower_case+col.columnNameCamelCase?cap_first>  
</#list>
<#list table.columnsPk as col>
  <#assign v_pk = col.columnName?lower_case>  
</#list>
CREATE OR REPLACE PACKAGE BODY <#if table.schema?? && table.schema != "">${table.schema?lower_case}_app.</#if>pkg_api_${table.name?lower_case?replace("ev_", "")?replace("tb_", "")} IS

  FUNCTION fLst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL
               ,</#list>ivOrderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT NULL
               ,inPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
               ,inPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
               ) RETURN ${v_tab} IS
    vSql     VARCHAR2(32767);
    vWhere   VARCHAR2(32767);
    tBinds   PLJSON_sql.t_binds;
    lTab     ${v_tab};
    cCur     SYS_REFCURSOR;
  BEGIN
    vSql := '
      SELECT <#list table.columns as col>${col.columnName?lower_case}<#sep>
            ,</#sep></#list>
        FROM ${table.name?lower_case}';

<#assign idx = 0>
<#list table.columns as col>
    IF i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first} IS NOT NULL THEN
      tBinds(tBinds.COUNT + 1).nome := 'i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}';
      tBinds(tBinds.COUNT).tipo     := '${col.dataType[0]?upper_case}';
      tBinds(tBinds.COUNT).${col.dataType[0]?lower_case}        := <#if col.dataType[0] == "V">'%' || LOWER(i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}) || '%'<#else>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}</#if>;

<#if idx gt 0>
      IF vWhere IS NOT NULL THEN
        vWhere := vWhere || ' AND ';
      END IF;

</#if>      vWhere := <#if idx gt 0>vWhere || </#if><#if col.dataType[0] == "V">'LOWER(${col.columnName?lower_case}) LIKE :i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}'<#else>'${col.columnName?lower_case} = :i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}'</#if>;
    END IF;

<#assign idx ++></#list>
    IF vWhere IS NOT NULL THEN
      vSql := vSql || ' WHERE ' || vWhere;
    END IF;
   
    cCur := utils.pkg_util.getCursorFromSql(ivSql        => vSql
                                           ,itBinds      => tBinds
                                           ,inOffset     => inPagIni * inPagTam + 1
                                           ,inFetchFirst => inPagTam
                                           ,ivOrderByRn  => NVL(ivOrderBy, '1')
                                           );

    FETCH cCur BULK COLLECT INTO lTab LIMIT 10000;
    CLOSE cCur;
    
    IF lTab.COUNT = 10000 THEN
      pkg_erro.pRaiseErro('A quantidade de linhas retornadas é maior que o permitido (10000). É necessário refefinir os filtros para executar a consulta.');
    END IF;
    
    RETURN lTab; 
  END fLst;
  
  FUNCTION fGetByPk(${v_p_pk} IN ${table.name?lower_case}.${v_pk}%TYPE) RETURN ${v_rec_det} IS
    rRec ${v_rec_det};
  BEGIN
    rRec.rec := fLst(${v_p_pk} => NVL(${v_p_pk},0)
                    ,inPagIni => 0
                    ,inPagTam => 1)(1);
                          
    RETURN rRec;
  END fGetByPk;
  
  FUNCTION ${v_get_json}(irRec IN ${v_rec}) RETURN PLJSON IS
    oObj PLJSON;
  BEGIN
    oObj := NEW PLJSON;
    
    <#list table.columns as col>oObj.put('${col.columnNameCamelCase}'${""?right_pad(maiorTamanho-3-col.columnNameCamelCase?length)}, irRec.${col.columnName?lower_case});<#sep>
    ${""}</#sep></#list>  

    RETURN oObj;
  END ${v_get_json};
  
  FUNCTION ${v_get_json}(irRecDet IN ${v_rec_det}) RETURN pljson IS
  BEGIN
    RETURN ${v_get_json}(irRec => irRecDet.rec);
  END ${v_get_json};
  
  FUNCTION ${v_get_json_list}(ilTab IN ${v_tab}) RETURN PLJSON_LIST IS
    oList PLJSON_LIST;
  BEGIN
    oList := PLJSON_LIST;
    FOR rIdx IN 1 .. ilTab.COUNT LOOP
      oList.append(${v_get_json}(ilTab(rIdx)).to_json_value);
    END LOOP;
    RETURN oList;
  END ${v_get_json_list};
  
  PROCEDURE pManter(<#list table.columns as col>i<#if col.pk == "Y">o</#if>${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } <#if col.pk != "Y"> IN    <#else>IN OUT</#if> ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#if col.pk != "Y"> DEFAULT NULL</#if><#if col.pk != "Y">
                   ,ib${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) }  IN     NUMBER DEFAULT 0</#if><#sep>
                   ,</#sep></#list>
                   ) IS
    rRow    ${table.schema?lower_case}.cg$${table.name?lower_case}.cg$row_type;
    rInd    ${table.schema?lower_case}.cg$${table.name?lower_case}.cg$ind_type;
    nInsert NUMBER;
  BEGIN
    nInsert := CASE WHEN ${v_po_pk} IS NULL THEN 1 END;
      
    <#list table.columns as col>
    rRow.${col.columnName?lower_case}${""?right_pad ( maiorTamanho - col.columnName?length ) } := <#if col.pk != "Y">i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#else>${v_po_pk}</#if>;
    </#list>

    <#list table.columns as col>
    rInd.${col.columnName?lower_case}${""?right_pad ( maiorTamanho - col.columnName?length ) } := <#if col.pk != "Y">NVL(nInsert,ib${col.columnNameCamelCase?cap_first}) = 1<#else>nInsert = 1</#if>;
    </#list>

    IF nInsert = 1 THEN
      ${table.schema?lower_case}.cg$${table.name?lower_case}.ins(rRow, rInd);
      ${v_po_pk} := rRow.${v_pk};
    ELSE
      ${table.schema?lower_case}.cg$${table.name?lower_case}.upd(rRow, rInd);
    END IF;      
  END pManter;
  
  PROCEDURE pExcluir(${v_p_pk} IN ${v_table}.${v_pk}%TYPE) IS
    rPk ${table.schema?lower_case}.cg$${table.name?lower_case}.cg$pk_type;
  BEGIN
    rPk.the_rowid${""?right_pad ( maiorTamanhoPk - 9 ) } := NULL;
    rPk.${v_pk} := ${v_p_pk};

    ${table.schema?lower_case}.cg$${table.name?lower_case}.del(rPk);
  END pExcluir;
  
  FUNCTION getByPk(${v_p_pk} IN ${table.name?lower_case}.${v_pk}%TYPE) RETURN PLJSON IS
    oReturn PLJSON;
    oObj    PLJSON;
    rErro   pkg_erro.rec_erro;
  BEGIN
    IF ${v_p_pk} IS NULL THEN
      oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    ELSE
      BEGIN
        oObj := ${v_get_json}(fGetByPk(${v_p_pk}));
        oReturn := pkg_msg.getMsgOk;
        oReturn.put(pkg_msg.vMSG_BODY_ATTR_NAME, oObj);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          oReturn := pkg_msg.getMsgNotFound(ivCdMensagem => pkg_msg.vMSG_NO_DATA_FOUND);
        WHEN pkg_erro.eErroCodigo THEN
          rErro := pkg_erro.fGetErro;
          oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => rErro.msg, itSubstituicoes => rErro.substituicoes);
        WHEN pkg_erro.eErro THEN
          oReturn := pkg_msg.getMsgBadRequest(ivDsMensagem => pkg_erro.fGetMsgErroSql);
        WHEN OTHERS THEN
          oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
      END;
    END IF;
    RETURN oReturn;
  END getByPk;

  FUNCTION lst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL
              ,</#list>ivOrderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT NULL
              ,inPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
              ,inPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
              ) RETURN PLJSON IS
    oReturn  PLJSON;
    lTab     ${v_tab};
    oList    PLJSON_LIST;
    nLines   NUMBER;
    oBody    pljson;
    rErro    pkg_erro.rec_erro;
  BEGIN
    BEGIN
      lTab := fLst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } => i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#sep>
                  ,</#sep></#list>
                  ,ivOrderBy                => ivOrderBy
                  ,inPagIni                 => inPagIni
                  ,inPagTam                 => inPagTam
                  );
      
      oList := ${v_get_json_list}(lTab);
      nLines := 0;
      IF lTab.count > 0 THEN
        nLines := ltab(1).total_linhas;
      END IF;

      oReturn := pkg_msg.getMsgOK;

      oBody := PLJSON;
      oBody.put(pljson_sql.vLINES_ARRAY_ATTR_NAME, oList);
      oBody.put(pljson_sql.vLINES_COUNT_ATTR_NAME, nLines);

      oReturn.put(pkg_msg.vMSG_BODY_ATTR_NAME, oBody);
    EXCEPTION
      WHEN pkg_erro.eErroCodigo THEN
        rErro := pkg_erro.fGetErro;
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => rErro.msg, itSubstituicoes => rErro.substituicoes);
      WHEN pkg_erro.eErro THEN
        oReturn := pkg_msg.getMsgBadRequest(ivDsMensagem => pkg_erro.fGetMsgErroSql);
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
    END;
    RETURN oReturn;
  END lst;

  FUNCTION ins(<#list table.columns as col><#if col.pk != "Y">i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length )} IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL<#sep>
              ,</#sep></#if></#list>
              ) RETURN pljson IS
    oReturn pljson;
    rErro   pkg_erro.rec_erro;
    nCd     ${v_table}.${v_pk}%TYPE;
  BEGIN
    BEGIN      
      pManter(<#list table.columns as col><#if col.pk == "Y">io${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) }=> nCd<#else>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } => i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}</#if><#sep>
             ,</#sep></#list>
             );
      
      oReturn := utils.pkg_util.getJsonINS(inPk => nCd);

      IF oReturn IS NULL THEN
        raise_application_error(-20001
                               ,'PK não foi retornada corretamente.');
      END IF;

    EXCEPTION
      WHEN pkg_erro.eErroCodigo THEN
        rErro := pkg_erro.fGetErro;
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => rErro.msg, itSubstituicoes => rErro.substituicoes);
      WHEN pkg_erro.eErro THEN
        oReturn := pkg_msg.getMsgBadRequest(ivDsMensagem => pkg_erro.fGetMsgErroSql);
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
    END;

    RETURN oReturn;
  END ins;

  FUNCTION upd(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN  ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#if col.pk != "Y"> DEFAULT NULL</#if><#sep>
              ,</#sep></#list>
              ) RETURN pljson IS
    oReturn pljson;
    rErro   pkg_erro.rec_erro;
    nCd     ${v_table}.${v_pk}%TYPE;
  BEGIN
    BEGIN      
      nCd := ${v_p_pk};
      pManter(<#list table.columns as col><#if col.pk == "Y">io${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) }=> nCd<#else>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } => i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}</#if><#if col.pk != "Y">
             ,ib${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } => 1</#if><#sep>
             ,</#sep></#list>
             );
      
      oReturn := pkg_msg.getMsgOK(ivCdMensagem => pkg_msg.vMSG_SUCESS);
    EXCEPTION
      WHEN pkg_erro.eErroCodigo THEN
        rErro := pkg_erro.fGetErro;
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => rErro.msg, itSubstituicoes => rErro.substituicoes);
      WHEN pkg_erro.eErro THEN
        oReturn := pkg_msg.getMsgBadRequest(ivDsMensagem => pkg_erro.fGetMsgErroSql);
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
    END;

    RETURN oReturn;
  END upd;

  FUNCTION del(${v_p_pk} IN ${v_table}.${v_pk}%TYPE) RETURN PLJSON IS
    oReturn PLJSON;
  BEGIN
    BEGIN
      pExcluir(${v_p_pk} => ${v_p_pk});

      oReturn := pkg_msg.getMsgOK(ivCdMensagem => pkg_msg.vMSG_SUCESS);
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
    END;

    RETURN oReturn;
  END del;

  FUNCTION getByPk(<#list table.columnsPk as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN VARCHAR2<#sep>
                  ,</#sep></#list>) RETURN CLOB IS
    oReturn${""?right_pad ( maiorTamanhoPk - 6 ) } PLJSON;
    lReturn${""?right_pad ( maiorTamanhoPk - 6 ) } CLOB;
<#list table.columnsPk as col>
    ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } ${table.name?lower_case}.${col.columnName?lower_case}%TYPE;
</#list>
  BEGIN
    BEGIN
<#list table.columnsPk as col><#if col.dataType?lower_case == "varchar2" || col.dataType?lower_case == "number" || col.dataType?lower_case == "date">
      ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } := pkg_types_util.<#switch col.dataType?lower_case><#case "varchar2">getVarchar2<#break><#case "number">getNumber<#break><#case "date">getDate<#break></#switch><#if col.dataType?lower_case == "number"><#if col.dataPrecision?? && col.dataPrecision != "">(ivParam     => <#else>(ivParam => </#if><#else>(ivParam => </#if>${col.columnNameCamelCase}<#if col.dataType?lower_case == "varchar2">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inSize  => ${col.dataLength}</#if><#if col.dataType?lower_case == "number" && col.dataPrecision?? && col.dataPrecision != "">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inPrecision => ${col.dataPrecision}<#if col.dataScale?? && col.dataScale != "0">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inScale     => ${col.dataScale}</#if></#if>);

</#if></#list>
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    END;

    IF oReturn IS NULL THEN
      oReturn := getByPk(<#list table.columnsPk as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } => ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#sep>
                        ,</#sep></#list>);
    END IF;

    oReturn.to_clob(lReturn);
    RETURN lReturn;
  END getByPk;

  FUNCTION lst(<#list table.columns as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN VARCHAR2 DEFAULT NULL
              ,</#list>orderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT '1'
              ,pagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN VARCHAR2
              ,pagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN VARCHAR2) RETURN CLOB IS
    oReturn${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } PLJSON;
    lReturn${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } CLOB;
<#list table.columns as col>
    ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } ${table.name?lower_case}.${col.columnName?lower_case}%TYPE;
</#list>
    nPagIni NUMBER;
    nPagTam NUMBER;
  BEGIN
    BEGIN
<#list table.columns as col><#if col.dataType?lower_case == "varchar2" || col.dataType?lower_case == "number" || col.dataType?lower_case == "date">
      ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } := pkg_types_util.<#switch col.dataType?lower_case><#case "varchar2">getVarchar2<#break><#case "number">getNumber<#break><#case "date">getDate<#break></#switch><#if col.dataType?lower_case == "number"><#if col.dataPrecision?? && col.dataPrecision != "">(ivParam     => <#else>(ivParam => </#if><#else>(ivParam => </#if>${col.columnNameCamelCase}<#if col.dataType?lower_case == "varchar2">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inSize  => ${col.dataLength}</#if><#if col.dataType?lower_case == "number" && col.dataPrecision?? && col.dataPrecision != "">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inPrecision => ${col.dataPrecision}<#if col.dataScale?? && col.dataScale != "0">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inScale     => ${col.dataScale}</#if></#if>);
</#if></#list>
      nPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 5 ) }:= pkg_types_util.getNumber(ivParam => pagIni);
      nPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 5 ) }:= pkg_types_util.getNumber(ivParam => pagTam);
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    END;

    IF oReturn IS NULL THEN
      oReturn := lst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } => ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}
                    ,</#list>ivOrderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } => orderBy
                    ,inPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } => nPagIni
                    ,inPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } => nPagTam);
    END IF;
    
    oReturn.to_clob(lReturn);
    RETURN lReturn;
  END lst;

  FUNCTION ins(<#list table.columns as col><#if col.pk != "Y">${col.columnNameCamelCase}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN VARCHAR2 DEFAULT NULL<#sep>
              ,</#sep></#if></#list>) RETURN CLOB IS
    oReturn${""?right_pad ( maiorTamanho - 6 ) } PLJSON;
    lReturn${""?right_pad ( maiorTamanho - 6 ) } CLOB;
<#list table.columns as col><#if col.pk != "Y">
    ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } ${table.name?lower_case}.${col.columnName?lower_case}%TYPE;
</#if></#list>
  BEGIN
    BEGIN
<#list table.columns as col><#if col.pk != "Y"><#if col.dataType?lower_case == "varchar2" || col.dataType?lower_case == "number" || col.dataType?lower_case == "date">
      ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } := pkg_types_util.<#switch col.dataType?lower_case><#case "varchar2">getVarchar2<#break><#case "number">getNumber<#break><#case "date">getDate<#break></#switch><#if col.dataType?lower_case == "number"><#if col.dataPrecision?? && col.dataPrecision != "">(ivParam     => <#else>(ivParam => </#if><#else>(ivParam => </#if>${col.columnNameCamelCase}<#if col.dataType?lower_case == "varchar2">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inSize  => ${col.dataLength}</#if><#if col.dataType?lower_case == "number" && col.dataPrecision?? && col.dataPrecision != "">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inPrecision => ${col.dataPrecision}<#if col.dataScale?? && col.dataScale != "0">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inScale     => ${col.dataScale}</#if></#if>);
</#if></#if></#list>
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    END;

    IF oReturn IS NULL THEN
      BEGIN
        oReturn := ins(<#list table.columns as col><#if col.pk != "Y">i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } => ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#sep>
                      ,</#sep></#if></#list>);

        utils.pkg_util.checkTransaction(ioResult => oReturn);
      EXCEPTION
        WHEN OTHERS THEN
          utils.pkg_util.rollbackTransaction;
          oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
      END;
    END IF;

    oReturn.to_clob(lReturn);

    RETURN lReturn;
  END ins;

  FUNCTION upd(<#list table.columns as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN VARCHAR2<#if col.pk != "Y"> DEFAULT NULL</#if><#sep>
              ,</#sep></#list>) RETURN CLOB IS
    oReturn${""?right_pad ( maiorTamanho - 6 ) } PLJSON;
    lReturn${""?right_pad ( maiorTamanho - 6 ) } CLOB;
<#list table.columns as col>
    ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } ${table.name?lower_case}.${col.columnName?lower_case}%TYPE;
</#list>
  BEGIN
    BEGIN
<#list table.columns as col><#if col.dataType?lower_case == "varchar2" || col.dataType?lower_case == "number" || col.dataType?lower_case == "date">
      ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } := pkg_types_util.<#switch col.dataType?lower_case><#case "varchar2">getVarchar2<#break><#case "number">getNumber<#break><#case "date">getDate<#break></#switch><#if col.dataType?lower_case == "number"><#if col.dataPrecision?? && col.dataPrecision != "">(ivParam     => <#else>(ivParam => </#if><#else>(ivParam => </#if>${col.columnNameCamelCase}<#if col.dataType?lower_case == "varchar2">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inSize  => ${col.dataLength}</#if><#if col.dataType?lower_case == "number" && col.dataPrecision?? && col.dataPrecision != "">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inPrecision => ${col.dataPrecision}<#if col.dataScale?? && col.dataScale != "0">
      ${""?right_pad ( maiorTamanho + 23 + col.dataType?length ) },inScale     => ${col.dataScale}</#if></#if>);
</#if></#list>
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    END;

    IF oReturn IS NULL THEN
      BEGIN
        oReturn := upd(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } => ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#sep>
                      ,</#sep></#list>);

        utils.pkg_util.checkTransaction(ioResult => oReturn);
      EXCEPTION
        WHEN OTHERS THEN
          utils.pkg_util.rollbackTransaction;
          oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
      END;
    END IF;

    oReturn.to_clob(lReturn);

    RETURN lReturn;
  END upd;

  FUNCTION del(<#list table.columnsPk as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN VARCHAR2<#sep>
              ,</#sep></#list>) RETURN CLOB IS
    oReturn${""?right_pad ( maiorTamanhoPk - 6 ) } PLJSON;
    lReturn${""?right_pad ( maiorTamanhoPk - 6 ) } CLOB;
<#list table.columnsPk as col>
    ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } ${table.name?lower_case}.${col.columnName?lower_case}%TYPE;
</#list>
  BEGIN
    BEGIN
<#list table.columnsPk as col><#if col.dataType?lower_case == "varchar2" || col.dataType?lower_case == "number" || col.dataType?lower_case == "date">
      ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } := pkg_types_util.<#switch col.dataType?lower_case><#case "varchar2">getVarchar2<#break><#case "number">getNumber<#break><#case "date">getDate<#break></#switch><#if col.dataType?lower_case == "number"><#if col.dataPrecision?? && col.dataPrecision != "">(ivParam     => <#else>(ivParam => </#if><#else>(ivParam => </#if>${col.columnNameCamelCase}<#if col.dataType?lower_case == "varchar2">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inSize  => ${col.dataLength}</#if><#if col.dataType?lower_case == "number" && col.dataPrecision?? && col.dataPrecision != "">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inPrecision => ${col.dataPrecision}<#if col.dataScale?? && col.dataScale != "0">
      ${""?right_pad ( maiorTamanhoPk + 23 + col.dataType?length ) },inScale     => ${col.dataScale}</#if></#if>);
</#if></#list>
    EXCEPTION
      WHEN OTHERS THEN
        oReturn := pkg_msg.getMsgBadRequest(ivCdMensagem => pkg_msg.vMSG_BAD_REQUEST);
    END;

    IF oReturn IS NULL THEN
      BEGIN
        oReturn := del(<#list table.columnsPk as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } => ${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}<#sep>
                      ,</#sep></#list>);

        utils.pkg_util.checkTransaction(ioResult => oReturn);
      EXCEPTION
        WHEN OTHERS THEN
          utils.pkg_util.rollbackTransaction;
          oReturn := pkg_msg.getMsgInternalServerError(ivCdMensagem => pkg_msg.vMSG_ERR);
      END;
    END IF;

    oReturn.to_clob(lReturn);

    RETURN lReturn;
  END del;

END;
/
