DECLARE

  cSwagger    CLOB;

  PROCEDURE pCrudGeneratorSwagger( ivServico  VARCHAR2 ) IS
    vSchema     VARCHAR(20);
    
    TYPE recTag IS RECORD ( nome VARCHAR2(100) );
    TYPE tabtag IS TABLE OF recTag INDEX BY PLS_INTEGER;
    
    TYPE recPath IS RECORD ( subprogram_id NUMBER, nome VARCHAR2(100) );
    TYPE tabPath IS TABLE OF recPath INDEX BY PLS_INTEGER;
    
    TYPE recPathFunc IS RECORD ( subprogram_id NUMBER, nome VARCHAR2(100), verbo VARCHAR2(10), function_nome VARCHAR2(100), qtdParams NUMBER );
    TYPE tabPathFunc IS TABLE OF recPathFunc INDEX BY PLS_INTEGER;
    
    TYPE recPathParam IS RECORD ( posicao NUMBER, nome VARCHAR2(200), nullable VARCHAR2(10) DEFAULT 'Y', tipo VARCHAR2(100) );
    TYPE tabPathParam IS TABLE OF recPathParam INDEX BY PLS_INTEGER;
    
    FUNCTION fLoadTags( ivSchema IN VARCHAR2, ivPath IN VARCHAR2 DEFAULT NULL ) RETURN tabtag IS
      tbTags    tabtag;
    BEGIN
      SELECT tag as nome
      BULK COLLECT INTO tbTags
      FROM (
          SELECT 
              REPLACE(REPLACE(REPLACE(REPLACE(procedure_name, '_GET', ''), '_POST', ''), '_PUT', ''), '_DELETE', '') tag
          FROM all_procedures
          WHERE owner = UPPER(ivSchema)
            AND object_type = 'PACKAGE'
            AND UPPER(object_name) = UPPER(ivServico)
            AND ( UPPER(procedure_name) LIKE '%_GET' 
                  OR UPPER(procedure_name) LIKE '%_POST'
                  OR UPPER(procedure_name) LIKE '%_PUT'
                  OR UPPER(procedure_name) LIKE '%_DELETE' )
          ORDER BY subprogram_id
      )
      WHERE ivPath IS NULL OR (tag LIKE ''||SUBSTR(UPPER(ivPath), 1, LENGTH(ivPath) - 1)||'%')
      GROUP BY tag
      HAVING COUNT(tag) > 1
      ORDER BY tag;
    
      RETURN tbTags;
    END fLoadTags;
    
    FUNCTION fLoadPaths( ivSchema IN VARCHAR2 ) RETURN tabPath IS
      tbPaths   tabPath;
    BEGIN
      SELECT serv.subprogram_id
           , serv.nome
      BULK COLLECT INTO tbPaths
      FROM ( SELECT nome
                  , subprogram_id
                  , ROW_NUMBER() OVER (PARTITION BY nome ORDER BY subprogram_id ASC ) AS ROW_NUM
               FROM ( SELECT REPLACE(REPLACE(REPLACE(REPLACE(proc.procedure_name, '_GET', ''), '_POST', ''), '_PUT', ''), '_DELETE', '') nome
                           , proc.subprogram_id
                        FROM all_procedures proc
                       WHERE owner = UPPER(ivSchema)
                         AND object_type = 'PACKAGE'
                         AND UPPER(object_name) = UPPER(ivServico)
                         AND ( UPPER(procedure_name) LIKE '%_GET' 
                               OR UPPER(procedure_name) LIKE '%_POST'
                               OR UPPER(procedure_name) LIKE '%_PUT'
                               OR UPPER(procedure_name) LIKE '%_DELETE' )
                       ORDER BY proc.subprogram_id ) serv
      ) serv
      WHERE serv.row_num = 1
      ORDER BY serv.subprogram_id;
      
      RETURN tbPaths;
    END fLoadPaths;
    
    FUNCTION fLoadPathsFunc( ivSchema IN VARCHAR2, ivPath VARCHAR2 ) RETURN tabPathFunc IS
      tbPathsFunc   tabPathFunc;
    BEGIN
      SELECT serv.subprogram_id
           , serv.nome
           , serv.verbo
           , serv.function_nome
           , serv.qtdParams
      BULK COLLECT INTO tbPathsFunc
      FROM (
        SELECT REPLACE(REPLACE(REPLACE(REPLACE(proc.procedure_name, '_GET', ''), '_POST', ''), '_PUT', ''), '_DELETE', '') nome
             , REGEXP_SUBSTR(proc.procedure_name, '('||chr(91)||'^_'||chr(93)||'+)\', 1,2,NULL,1) verbo
             , proc.procedure_name function_nome
             , proc.subprogram_id
             , (SELECT COUNT(1) qtdParams FROM all_arguments args WHERE owner = UPPER(ivSchema) AND args.package_name = UPPER(ivServico) AND SUBPROGRAM_ID = proc.subprogram_id AND in_out = 'IN') qtdParams
        FROM all_procedures proc
        WHERE owner = UPPER(ivSchema)
          AND object_type = 'PACKAGE'
          AND UPPER(object_name) = UPPER(ivServico)
          AND ( UPPER(procedure_name) LIKE '%_GET' 
                OR UPPER(procedure_name) LIKE '%_POST'
                OR UPPER(procedure_name) LIKE '%_PUT'
                OR UPPER(procedure_name) LIKE '%_DELETE' )
        ORDER BY subprogram_id ) serv
      WHERE UPPER(serv.nome) = UPPER(ivPath)
      ORDER BY serv.subprogram_id;
      
      RETURN tbPathsFunc;
    END fLoadPathsFunc;
    
    FUNCTION fLoadPathsSummaryDescription( ivPath IN VARCHAR2, ivVerbo IN VARCHAR2, inParams IN NUMBER, inRecuo IN NUMBER ) RETURN CLOB IS
      cRetorno  CLOB;
    BEGIN
      CASE ivVerbo
        WHEN 'GET' THEN
          IF (inParams = 1) THEN
            cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'summary: Detalhe de '||INITCAP(ivPath);
            cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: Detalha o objecto do tipo '||INITCAP(ivPath)||' pelo codigo informado.';
          ELSE
            cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'summary: Lista de '||INITCAP(ivPath);
            cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: Lista os(as) '||INITCAP(ivPath)||' conforme os parametros informados.';  
          END IF;
        WHEN 'POST' THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'summary: Registo de '||INITCAP(ivPath);
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: Regista um objecto do tipo '||INITCAP(ivPath)||' conforme os parametros informados.';
        WHEN 'PUT' THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'summary: Actualizacao de '||INITCAP(ivPath);
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: Actualiza um objecto do tipo '||INITCAP(ivPath)||' conforme os parametros informados.';
        WHEN 'DELETE' THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'summary: Remoção de '||INITCAP(ivPath);
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: Remove o objecto do tipo '||INITCAP(ivPath)||' pelo codigo informado.';
      END CASE;
      
      RETURN cRetorno;
    END fLoadPathsSummaryDescription;
    
    FUNCTION fLoadPathsParameters ( ivSchema IN VARCHAR2, inSubprogramId IN NUMBER ) RETURN tabPathParam IS
      tbPathParams  tabPathParam;
    BEGIN
    
      SELECT args.position
           , (SELECT SUBSTR(sour.text, INSTR(UPPER(sour.text), args.argument_name), LENGTH(args.argument_name)) nome 
              FROM all_source sour
              WHERE sour.owner = args.owner 
                AND sour.name = args.package_name
                AND TYPE = 'PACKAGE BODY' AND UPPER(sour.text) LIKE '%'||UPPER(args.argument_name)||'%' AND ROWNUM = 1) AS nome
           , args.defaulted
           , args.data_type
        BULK COLLECT INTO tbPathParams
        FROM all_arguments args 
       WHERE args.owner = UPPER(ivSchema)
         AND args.package_name = UPPER(ivServico)
         AND args.subprogram_id = inSubprogramId
         AND args.in_out = 'IN'
       ORDER BY args.position;
     
      RETURN tbPathParams;
    
    END fLoadPathsParameters;
    
    PROCEDURE pWriteVersion IS
    BEGIN
      cSwagger := 'swagger: "2.0"';
    END pWriteVersion;
    
    PROCEDURE pWriteInfo IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||'info:
  title: {{NomeApiTitulo}}
  description: API para a manutencao - {{NomeApiTitulo}}
  version: {{VersaoApi}}';
  
      cRetorno := REPLACE(cRetorno, '{{NomeApiTitulo}}', INITCAP(ivServico));
      cRetorno := REPLACE(cRetorno, '{{VersaoApi}}', '0.0.1');
      
      cSwagger := cSwagger||cRetorno;
      
    END pWriteInfo;
    
    PROCEDURE pWriteConsumes( inRecuo IN NUMBER ) IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||LPAD(' ', inRecuo)||'consumes:';
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 2)||'- application/json';
      
      cSwagger := cSwagger||cRetorno;
    END pWriteConsumes;
    
    PROCEDURE pWriteProduces( inRecuo IN NUMBER ) IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||LPAD(' ', inRecuo)||'produces:';
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 2)||'- application/json';
      
      cSwagger := cSwagger||cRetorno;
    END pWriteProduces;
    
    PROCEDURE pWriteBasePath IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||'basePath: /{{NomeApi}}';
      cRetorno := REPLACE(cRetorno, '{{NomeApi}}', LOWER(ivServico));
      
      cSwagger := cSwagger||cRetorno;
    END pWriteBasePath;
    
    PROCEDURE pWriteTags( ivSchema IN VARCHAR2 ) IS
      cRetorno  CLOB;
      tbTags    tabtag;
      nRecuo    NUMBER;
    BEGIN
      nRecuo := 2;
      tbTags := fLoadTags(ivSchema);
      
      cRetorno := CHR(10)||'tags:';
      FOR i IN 1..tbTags.count LOOP
        cRetorno := cRetorno||CHR(10)||LPAD(' ', nRecuo)||'- name: ' ||LOWER(tbTags(i).nome);
      END LOOP;
      
      cSwagger := cSwagger||cRetorno;
    END pWriteTags;
    
    PROCEDURE pWriteSchemes IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||'schemes:
  - http
  - https';
      
      cSwagger := cSwagger||cRetorno;
    END pWriteSchemes;
    
    FUNCTION fGetPathsTags( ivSchema IN VARCHAR2, ivPathFunc IN VARCHAR2, inRecuo IN NUMBER ) RETURN CLOB IS
      cRetorno      CLOB;
      tbTags        tabTag;
    BEGIN
      tbTags := fLoadTags(ivSchema, ivPathFunc);
      
      FOR k IN 1..tbTags.count LOOP
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 6)||'- '||LOWER(tbTags(k).nome);  
      END LOOP;
      
      IF(cRetorno IS NULL) THEN
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 6)||'- '||LOWER(ivPathFunc);
      END IF;
      
      RETURN cRetorno;
    END fGetPathsTags; 
    
    FUNCTION fGetPathsInfos ( ivPathFunc    IN VARCHAR2
                            , ivVerbo       IN VARCHAR2
                            , inQtdParams   IN NUMBER
                            , inRecuo       IN NUMBER ) RETURN CLOB IS
      cRetorno  CLOB;
    BEGIN
      
      cRetorno := cRetorno||fLoadPathsSummaryDescription(ivPath=>ivPathFunc, ivVerbo=>ivVerbo, inParams=>inQtdParams, inRecuo=>inRecuo + 4);
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 4)||'x-auth-type: "Application &'||' Application User"';
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 4)||'x-throttling-tier: Unlimited';
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 4)||'consumes:'||CHR(10)||LPAD(' ', inRecuo + 6)||'- x-www-form-urlencoded';
      cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 4)||'produces:'||CHR(10)||LPAD(' ', inRecuo + 6)||'- application/json';
      
      RETURN cRetorno;
    END fGetPathsInfos;
    
    FUNCTION fGetPathsParams( ivSchema IN VARCHAR2, ivPathFunc IN VARCHAR2, ivVerbo IN VARCHAR2, inSubprogramId IN NUMBER, inRecuo IN NUMBER ) RETURN CLOB IS
      cRetorno      CLOB;
      tbPathParams  tabPathParam;
    BEGIN
      
      IF ivVerbo = 'GET' THEN
        tbPathParams := fLoadPathsParameters(ivSchema=> ivSchema, inSubprogramId=>inSubprogramId);
        FOR l IN 1..tbPathParams.count LOOP
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 6)||'- name: '||tbPathParams(l).nome;
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'in: query';
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'required: '|| CASE WHEN tbPathParams(l).nullable = 'N' THEN 'true' ELSE 'false' END;
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'type: string';
        END LOOP;
      ELSE
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 6)||'- name: '||LOWER(ivPathFunc);
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'in: body';
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'required: true';
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:';
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/'||LOWER(ivPathFunc)||UPPER(ivVerbo)||'"';
      END IF;
      
      RETURN cRetorno;
    END fGetPathsParams;
    
    FUNCTION fGetPathsResponses( ivSchema       IN VARCHAR2
                               , ivPathFunc     IN VARCHAR2
                               , ivVerbo        IN VARCHAR2
                               , inQtdParams    IN NUMBER
                               , inRecuo        IN NUMBER ) RETURN CLOB IS
      cRetorno      CLOB;
    BEGIN
      IF ivVerbo = 'GET' THEN
        cRetorno := cRetorno
                        ||CHR(10)||LPAD(' ', inRecuo + 6)||'"200":'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Registo encontrado.'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                        ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/'||LOWER(ivPathFunc)||UPPER(ivVerbo)||'"';
      ELSE
        cRetorno := cRetorno
                        ||CHR(10)||LPAD(' ', inRecuo + 6)||'"200":'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Registo '||CASE ivVerbo WHEN 'POST' THEN 'incluido' WHEN 'PUT' THEN 'alterado' WHEN 'DELETE' THEN 'removido' ELSE 'encontrado' END||' com sucesso.'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                        ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/messageModel"';
      END IF;
      
      cRetorno := cRetorno
                    ||CHR(10)||LPAD(' ', inRecuo + 6)||'"400":'
                    ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Parametros invalidos'
                    ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                    ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/errorMessage"';
      
      IF ivVerbo <> 'POST' THEN              
        cRetorno := cRetorno
                        ||CHR(10)||LPAD(' ', inRecuo + 6)||'"404":'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Registo nao encontrado'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                        ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/messageModel"';
      END IF;
      
      IF ivVerbo <> 'GET' THEN
        cRetorno := cRetorno
                        ||CHR(10)||LPAD(' ', inRecuo + 6)||'"409":'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Erros de Validacao'
                        ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                        ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/errorMessage"';
      END IF;
      
      cRetorno := cRetorno
                      ||CHR(10)||LPAD(' ', inRecuo + 6)||'"500":'
                      ||CHR(10)||LPAD(' ', inRecuo + 8)||'description: Erro inesperado'
                      ||CHR(10)||LPAD(' ', inRecuo + 8)||'schema:'
                      ||CHR(10)||LPAD(' ', inRecuo + 10)||'$ref: "#/definitions/errorMessage"';
      
      RETURN cRetorno;
      
    END fGetPathsResponses;
    
    PROCEDURE pWritePaths( ivSchema IN VARCHAR2 ) IS
      cRetorno      CLOB;
      cPath         CLOB;
      
      nRecuo        NUMBER;
      nTam          PLS_INTEGER;
      nPos          PLS_INTEGER;
      
      tbPaths       tabPath;
      tbPathsFunc   tabPathFunc;
    BEGIN
      nTam := 30000;
      nPos := 1;
      nRecuo := 2;
      
      cRetorno := cRetorno||CHR(10)||'paths:';
      tbPaths := fLoadPaths(ivSchema);
      FOR i IN 1..tbPaths.count LOOP
        cPath := CHR(10)||LPAD(' ', nRecuo)||'/'||LOWER(tbPaths(i).nome)||':';
        tbPathsFunc := fLoadPathsFunc(ivSchema, tbPaths(i).nome);
        
        FOR j IN 1..tbPathsFunc.count LOOP
          cPath := cPath||CHR(10)||LPAD(' ', nRecuo + 2)||LOWER(tbPathsFunc(j).verbo)||':';
          
          cPath := cPath||CHR(10)||LPAD(' ', nRecuo + 4)||'tags:';
          cPath := cPath||fGetPathsTags(ivSchema=>ivSchema, ivPathFunc=>tbPathsFunc(j).nome, inRecuo=>nRecuo);
          
          cPath := cPath||fGetPathsInfos(ivPathFunc=>tbPathsFunc(j).nome, ivVerbo=>tbPathsFunc(j).verbo, inQtdParams=>tbPathsFunc(j).qtdParams, inRecuo=>nRecuo);
          
          cPath := cPath||CHR(10)||LPAD(' ', nRecuo + 4)||'parameters:';
          cPath := cPath||fGetPathsParams(ivSchema=>ivSchema, ivPathFunc=>tbPathsFunc(j).nome, ivVerbo=>tbPathsFunc(j).verbo, inSubprogramId=>tbPathsFunc(j).subprogram_id, inRecuo=>nRecuo);
          
          cPath := cPath||CHR(10)||LPAD(' ', nRecuo + 4)||'responses:';
          cPath := cPath||fGetPathsResponses(ivSchema=>ivSchema, ivPathFunc=>tbPathsFunc(j).nome, ivVerbo=>tbPathsFunc(j).verbo, inQtdParams=>tbPathsFunc(j).qtdParams, inRecuo=>nRecuo);
        END LOOP;
        
        cRetorno := cRetorno||cPath;
        
      END LOOP;
      
      --Concatenacao de dois CLOBs grandes
      WHILE nPos < dbms_lob.getlength (cRetorno) LOOP
        cSwagger := cSwagger||dbms_lob.substr(cRetorno, nTam, nPos);
        nPos := nPos + nTam;
      END LOOP;
      
    END pWritePaths;
    
    PROCEDURE pWriteDefinitionsDefault IS
      cRetorno  CLOB;
    BEGIN
      cRetorno := CHR(10)||'definitions:'||'
  messageModel:
    type: object
    required:
      - status
      - message
    properties:
      message:
        type: string
      status:
        format: int32
        type: integer
  errorMessage:
    type: object
    required:
      - fault
    properties:
      fault:
        $ref: "#/definitions/messageModel"';
      
      cSwagger := cSwagger||cRetorno;
      
    END pWriteDefinitionsDefault;
    
    FUNCTION fGetDefinitionParameter( ivParam IN VARCHAR2, inRecuo IN NUMBER ) RETURN CLOB IS
      cRetorno      CLOB;
    BEGIN
    
      FOR i IN (SELECT colu.column_id, comc.table_name, colu.column_name, colu.data_type, colu.nullable, comc.comments
                FROM all_tab_columns colu
                  INNER JOIN all_col_comments comc ON colu.column_name = comc.column_name
                WHERE colu.column_name = UPPER(regexp_replace(ivParam, '([[:lower:]])([[:upper:]])', '\1_\2'))
                  AND ROWNUM = 1) LOOP
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'type: '||CASE
                                                    WHEN UPPER(SUBSTR(i.column_name, 1, 2)) = 'CD' THEN 'integer'
                                                    WHEN i.data_type = 'NUMBER' THEN 'number'
                                                    ELSE 'string'
                                                 END;
        IF i.comments IS NOT NULL THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'description: '||i.comments;
        END IF;
        
        IF UPPER(SUBSTR(i.column_name, 1, 2)) = 'CD' THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'format: int32';
        ELSIF i.data_type = 'DATE' OR i.data_type LIKE 'TIMESTAMP%' THEN
          cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'format: YYYY-MM-DD';
        END IF;
      END LOOP;
      
      IF cRetorno IS NULL THEN
        cRetorno := cRetorno||CHR(10)||LPAD(' ', inRecuo)||'type: string';
      END IF;
      
      RETURN cRetorno;
     
    END fGetDefinitionParameter;
    
    PROCEDURE pWriteDefinitions( ivSchema IN VARCHAR2 ) IS
      cRetorno      CLOB;
      
      nRecuo        NUMBER;
      nTam          PLS_INTEGER;
      nPos          PLS_INTEGER;
      
      tbPaths       tabPath;
      tbPathsFunc   tabPathFunc;
      tbPathParams  tabPathParam;
    BEGIN
      nTam := 30000;
      nPos := 1;
      nRecuo := 2;
      
      tbPaths := fLoadPaths(ivSchema);
      FOR i IN 1..tbPaths.count LOOP
        
        tbPathsFunc := fLoadPathsFunc(ivSchema, tbPaths(i).nome);
        FOR j IN 1..tbPathsFunc.count LOOP
          cRetorno := cRetorno||CHR(10)||LPAD(' ', nRecuo)||LOWER(tbPathsFunc(j).nome)||UPPER(tbPathsFunc(j).verbo)||':';
          cRetorno := cRetorno||CHR(10)||LPAD(' ', nRecuo + 2)||'type: object';
          
          IF tbPathsFunc(j).verbo <> 'GET' THEN
            cRetorno := cRetorno||CHR(10)||LPAD(' ', nRecuo + 2)||'properties:';
            tbPathParams := fLoadPathsParameters(ivSchema=> ivSchema, inSubprogramId=>tbPathsFunc(j).subprogram_id);
            
            FOR l IN 1..tbPathParams.count LOOP
              cRetorno := cRetorno||CHR(10)||LPAD(' ', nRecuo + 4)||tbPathParams(l).nome||':';
              cRetorno := cRetorno||fGetDefinitionParameter(ivParam=>tbPathParams(l).nome, inRecuo=>nRecuo + 6);
            END LOOP;
          END IF;
        END LOOP;
        
      END LOOP;
      
      --Concatenacao de dois CLOBs grandes
      WHILE nPos < dbms_lob.getlength (cRetorno) LOOP
        cSwagger := cSwagger||dbms_lob.substr(cRetorno, nTam, nPos);
        nPos := nPos + nTam;
      END LOOP;
      
    END pWriteDefinitions;
    
  BEGIN
    vSchema := 'EXECUTOR_AU';
 
    pWriteVersion;
    pWriteInfo;
    pWriteConsumes(0);
    pWriteProduces(0);
    pWriteBasePath;
    pWriteTags(vSchema);
    pWriteSchemes;
    pWritePaths(vSchema);
    pWriteDefinitionsDefault;
    pWriteDefinitions(vSchema);
    
  END pCrudGeneratorSwagger;
  
BEGIN
  DECLARE
    nTam        PLS_INTEGER;
    nPos        PLS_INTEGER;
  BEGIN
    nTam := 30000;
    nPos := 1;
    dbms_output.enable(1000000);
    
    pCrudGeneratorSwagger( ivServico  => upper('&servico') );
    gravalogclob(cSwagger, 'GeradorWSO2');
    
    WHILE nPos < dbms_lob.getlength ( cSwagger ) LOOP
      dbms_output.put_line(dbms_lob.substr(cSwagger, nTam, nPos));
      nPos := nPos + nTam;
    END LOOP;
  END;
END;
/
