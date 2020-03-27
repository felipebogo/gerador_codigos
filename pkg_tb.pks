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
  <#if col.pk == 'Y' && col.columnNameCamelCase?length gt maiorTamanhoPk>
    <#assign maiorTamanhoPk = col.columnNameCamelCase?length>
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
CREATE OR REPLACE PACKAGE <#if table.schema?? && table.schema != "">${table.schema?lower_case}_app.</#if>pkg_api_${table.name?lower_case?replace("ev_", "")?replace("tb_", "")} IS

  TYPE ${v_rec} IS RECORD
  (<#list table.columns as col>${col.columnName?lower_case?right_pad(maiorTamanho)} ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#sep>
  ,</#sep></#list>
  ,${"total_linhas"?right_pad(maiorTamanho)} NUMBER
  ,${"nro_linha"?right_pad(maiorTamanho)} NUMBER
  );
  
  TYPE ${v_tab} IS TABLE OF ${v_rec} INDEX BY PLS_INTEGER;
  
  TYPE ${v_rec_det} IS RECORD
  ( rec ${v_rec}
  );
  
  FUNCTION fLst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL
               ,</#list>ivOrderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT NULL
               ,inPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
               ,inPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
               ) RETURN ${v_tab};
               
  FUNCTION fGetByPk(<#list table.columnsPk as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#sep>
                   ,</#sep></#list>) RETURN ${v_rec_det};
  
  FUNCTION ${v_get_json}(irRecDet IN ${v_rec_det}) RETURN pljson;
  
  FUNCTION ${v_get_json_list}(ilTab IN ${v_tab}) RETURN pljson_list;
  
  PROCEDURE pManter(<#list table.columns as col>i<#if col.pk == "Y">o</#if>${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } <#if col.pk != "Y"> IN    <#else>IN OUT</#if> ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#if col.pk != "Y"> DEFAULT NULL</#if><#if col.pk != "Y">
                   ,ib${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) }  IN     NUMBER DEFAULT 0</#if><#sep>
                   ,</#sep></#list>
                   );
                   
  PROCEDURE pExcluir(${v_p_pk} IN ${v_table}.${v_pk}%TYPE);
  
  FUNCTION getByPk(<#list table.columnsPk as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#sep>
                  ,</#sep></#list>) RETURN PLJSON;

  FUNCTION lst(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL
              ,</#list>ivOrderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT NULL
              ,inPagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
              ,inPagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN NUMBER
              ) RETURN PLJSON;

  FUNCTION ins(<#list table.columns as col><#if col.pk != "Y">i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length )} IN ${table.name?lower_case}.${col.columnName?lower_case}%TYPE DEFAULT NULL<#sep>
              ,</#sep></#if></#list>
              ) RETURN PLJSON;

  FUNCTION upd(<#list table.columns as col>i${col.dataType[0]?lower_case}${col.columnNameCamelCase?cap_first}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN  ${table.name?lower_case}.${col.columnName?lower_case}%TYPE<#if col.pk != "Y"> DEFAULT NULL</#if><#sep>
              ,</#sep></#list>
              ) RETURN PLJSON;

  FUNCTION del(${v_p_pk} IN ${v_table}.${v_pk}%TYPE) RETURN PLJSON;

  FUNCTION getByPk(<#list table.columnsPk as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN VARCHAR2<#sep>
                  ,</#sep></#list>) RETURN CLOB;

  FUNCTION lst(<#list table.columns as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoCamelCaseVarchar - col.columnNameCamelCase?length ) } IN VARCHAR2 DEFAULT NULL
              ,</#list>orderBy${""?right_pad ( maiorTamanhoCamelCaseVarchar - 7 ) } IN VARCHAR2 DEFAULT '1'
              ,pagIni${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN VARCHAR2
              ,pagTam${""?right_pad ( maiorTamanhoCamelCaseVarchar - 6 ) } IN VARCHAR2) RETURN CLOB;

  FUNCTION ins(<#list table.columns as col><#if col.pk != "Y">${col.columnNameCamelCase}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN VARCHAR2 DEFAULT NULL<#sep>
              ,</#sep></#if></#list>) RETURN CLOB;

  FUNCTION upd(<#list table.columns as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanho - col.columnNameCamelCase?length ) } IN VARCHAR2<#if col.pk != "Y"> DEFAULT NULL</#if><#sep>
              ,</#sep></#list>) RETURN CLOB;

  FUNCTION del(<#list table.columnsPk as col>${col.columnNameCamelCase}${""?right_pad ( maiorTamanhoPk - col.columnNameCamelCase?length ) } IN VARCHAR2<#sep>
              ,</#sep></#list>) RETURN CLOB;

END;
/
GRANT EXECUTE ON <#if table.schema?? && table.schema != "">${table.schema?lower_case}_app.</#if>pkg_${table.name?lower_case?replace("ev_", "")?replace("tb_", "")} TO executor_au;

GRANT EXECUTE ON <#if table.schema?? && table.schema != "">${table.schema?lower_case}_app.</#if>pkg_${table.name?lower_case?replace("ev_", "")?replace("tb_", "")} TO utils;

<#if table.schema?? && table.schema != "">GRANT EXECUTE ON utils.pkg_util TO ${table.schema?lower_case}_app;</#if>
