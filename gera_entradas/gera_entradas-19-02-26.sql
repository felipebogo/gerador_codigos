DECLARE
  gvSchema    VARCHAR2(100) := UPPER('&Schema');
  gvPackage   VARCHAR2(100) := UPPER('&Package');
  gvProcedure VARCHAR2(100) := UPPER('&Procedure');
  gvTpEntrada VARCHAR2(10)  := UPPER('&TipoEntrada');
  /* gvSchema    VARCHAR2(100) := UPPER('EXECUTOR_AU');
  gvPackage   VARCHAR2(100) := UPPER('RESPFIN');
  gvProcedure VARCHAR2(100) := UPPER('RESPFINS_GET');
  gvTpEntrada VARCHAR2(10)  := UPPER('J'); */
  gcvPrint    CONSTANT VARCHAR2(10) := 'DBMS';
  gcRet       CLOB := EMPTY_CLOB;
  TYPE tab_args IS TABLE OF all_arguments%ROWTYPE;
  
  PROCEDURE pPrint IS
    PROCEDURE pDbms IS
      nTam    PLS_INTEGER;
      nTamMin PLS_INTEGER;
      nPos    PLS_INTEGER;
      nPosQ   PLS_INTEGER;
      nTamQ   PLS_INTEGER;
    BEGIN
      nTamMin := 30000;
      nTam := 32000;
      nPos := 1;

      WHILE nPos < dbms_lob.getlength ( gcRet ) LOOP
        nPosQ := dbms_lob.instr(lob_loc => gcRet,
                                pattern => chr(10),
                                offset  => nPos+nTamMin-1,
                                nth     => 1);
        nTamQ := nPosQ - nPos;
        IF dbms_lob.getlength ( gcRet ) - nPos > nTam AND nPosQ > 0 AND nTamQ <= nTam THEN
          dbms_output.put_line ( dbms_lob.substr ( gcRet, nTamQ, nPos ) );
          nPos := nPos + nTamQ+1;
        ELSE
          dbms_output.put_line ( dbms_lob.substr ( gcRet, nTam, nPos ) );
          nPos := nPos + nTam;
        END IF;
      END LOOP;
    END pDbms;
  BEGIN
    IF gcvPrint = 'DBMS' THEN
      pDbms;
    ELSIF gcvPrint = 'LOG' THEN
      gravalogclob(gcRet,'GERA_JSON'); 
    END IF;
  END pPrint;
  
  PROCEDURE pAdd(ivValor CLOB) IS
  BEGIN
    dbms_lob.append(dest_lob => gcRet
                   ,src_lob  => ivValor
                   );
  END pAdd;
  
  FUNCTION fGetArgs(ivSchema    VARCHAR2
                   ,ivPackage   VARCHAR2
                   ,ivProcedure VARCHAR2) RETURN tab_args IS
    lArgs tab_args;
    CURSOR cArgs IS
    SELECT args.OWNER
          ,args.OBJECT_NAME
          ,args.PACKAGE_NAME
          ,args.OBJECT_ID
          ,args.OVERLOAD
          ,args.SUBPROGRAM_ID
          ,args.ARGUMENT_NAME
          ,args.POSITION
          ,args.SEQUENCE
          ,args.DATA_LEVEL
          ,args.DATA_TYPE
          ,args.DEFAULTED
          ,args.DEFAULT_VALUE
          ,args.DEFAULT_LENGTH
          ,args.in_out
          ,args.DATA_LENGTH
          ,args.DATA_PRECISION
          ,args.DATA_SCALE
          ,args.radix
          ,args.CHARACTER_SET_NAME
          ,args.type_owner
          ,args.type_name
          ,args.type_subname
          ,args.TYPE_LINK
          ,args.pls_type
          ,args.CHAR_LENGTH
          ,args.CHAR_USED
      FROM all_arguments args
     WHERE args.owner = ivSchema
       AND (args.package_name = ivPackage OR (ivPackage IS NULL AND args.package_name IS NULL)) 
       AND args.object_name = ivProcedure
       AND args.ARGUMENT_NAME IS NOT NULL
  ORDER BY position;
  BEGIN
    OPEN cArgs;
    FETCH cArgs BULK COLLECT INTO lArgs;
    CLOSE cArgs;
    RETURN lArgs;
  END fGetArgs;
  FUNCTION fGetCol(irArg all_arguments%ROWTYPE) 
  RETURN VARCHAR2 IS
    vCol VARCHAR2(1000);
  BEGIN
    BEGIN
      SELECT SUBSTR(sour.text, INSTR(UPPER(sour.text), irArg.argument_name), LENGTH(irArg.argument_name)) nome 
        INTO vCol
        FROM all_source sour
        WHERE sour.owner = irArg.owner 
          AND sour.name = irArg.package_name
          AND TYPE = 'PACKAGE BODY' AND UPPER(sour.text) LIKE '%'||UPPER(irArg.argument_name)||'%' AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         vCol := REPLACE(SUBSTR(INITCAP('a'||irArg.argument_name),2),'_','');
    END; 
    RETURN vCol;
  END fGetCol;
  PROCEDURE pGeraJson IS
    lArgs tab_args;
  BEGIN
    dbms_lob.createtemporary(lob_loc => gcRet, cache => true, dur => dbms_lob.call);
    lArgs := fGetArgs(ivSchema    => gvSchema
                     ,ivPackage   => gvPackage
                     ,ivProcedure => gvProcedure
                     );
    IF gvTpEntrada = 'J' THEN
      pAdd('{');
      FOR rIdx IN 1..lArgs.COUNT LOOP
        pAdd('"'||fGetCol(lArgs(rIdx))||'" : ""');
        IF lArgs.COUNT <> rIdx THEN
          pAdd(',');
        END IF;
        pAdd(chr(10));
      END LOOP;
      pAdd('}');
    ELSIF gvTpEntrada = 'P' THEN
      FOR rIdx IN 1..lArgs.COUNT LOOP
        IF rIdx = 1 THEN
          pAdd('?');
        ELSE
          pAdd('&');
        END IF;
        pAdd(fGetCol(lArgs(rIdx))||'=');
      END LOOP;
    END IF;
    pPrint;
  END pGeraJson;
BEGIN
  pGeraJson;
END;
/
