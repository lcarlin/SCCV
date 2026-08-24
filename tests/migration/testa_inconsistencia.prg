/*
 * testa_inconsistencia.prg — critério de aceite da FASE D.3
 *
 * "Registro nos 3 formatos (tabela, texto, CSV); formato do briefing §20."
 *   — docs/10-PLANO-IMPLEMENTACAO.md, D.3
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL hReg, hNorm, pDb, cDir, cTxt, cCsv, aLin, nRc

   cDir := hb_DirTemp()

   ? "FASE D.3 — aceite do registro de inconsistências"
   ?

   ? "== 1. acumulação e contagem =="
   hReg := IncNovo()
   Vale( "registro novo começa vazio", IncTotal( hReg ), 0 )

   /* o caminho normal: absorver o que o normalizador devolveu */
   hNorm := NormCpf( "88888888888-888" )
   Vale( "normalizador produziu 1 ocorrência", Len( hNorm[ "ocorrencias" ] ), 1 )
   IncAbsorver( hReg, hNorm, "CVBCLIEN.DBF", 22, "CODCLI=24", "CICCLI", "88888888888-888" )
   Vale( "absorvida", IncTotal( hReg ), 1 )
   Vale( "contada como ALTA", IncContagem( hReg, "ALTA" ), 1 )

   hNorm := NormCepNumerico( "  798797" )
   IncAbsorver( hReg, hNorm, "CVBCLIEN.DBF", 1, "CODCLI=7", "CEPCLI", "798797" )
   Vale( "duas no total", IncTotal( hReg ), 2 )
   Vale( "uma MEDIA", IncContagem( hReg, "MEDIA" ), 1 )

   /* registro direto, sem passar pelo normalizador */
   IncRegistrar( hReg, "CVPECAS.DBF", 5, "CODCLI=7", "VALTOT", NIL, ;
      "Troca de cliente sem VALTOT: venda anterior fechada por heurística", ;
      "Venda fechada; agrupamento marcado como INDETERMINADO", "BAIXA" )
   Vale( "três no total", IncTotal( hReg ), 3 )
   Vale( "uma BAIXA", IncContagem( hReg, "BAIXA" ), 1 )

   /* valor NIL deve virar NULL, não string vazia */
   Vale( "valor_original NIL preservado", hReg[ "itens" ][ 3 ][ "valor_original" ], NIL )

   ? "== 2. formato texto (briefing §20) =="
   cTxt := cDir + "relatorio-migracao.txt"
   Vale( "gravou", IncGravarTexto( hReg, cTxt ), .T. )
   cTxt := hb_MemoRead( cTxt )
   Vale( "traz o arquivo de origem", At( "CVBCLIEN.DBF", cTxt ) > 0, .T. )
   Vale( "traz 'Registro 22'", At( "Registro 22", cTxt ) > 0, .T. )
   Vale( "traz a chave", At( "(CODCLI=24)", cTxt ) > 0, .T. )
   Vale( "traz Campo:", At( "Campo:      CICCLI", cTxt ) > 0, .T. )
   Vale( "traz Valor:", At( "88888888888-888", cTxt ) > 0, .T. )
   Vale( "traz Problema:", At( "Problema:   CPF com 14", cTxt ) > 0, .T. )
   Vale( "traz Ação:", At( "Ação:", cTxt ) > 0, .T. )
   Vale( "traz Severidade:", At( "Severidade: ALTA", cTxt ) > 0, .T. )
   Vale( "valor ausente vira (vazio)", At( "(vazio)", cTxt ) > 0, .T. )
   Vale( "cabeçalho com o total", At( "Total....: 3", cTxt ) > 0, .T. )

   ? "== 3. formato CSV =="
   cCsv := cDir + "relatorio-migracao.csv"
   Vale( "gravou", IncGravarCsv( hReg, cCsv ), .T. )
   cCsv := hb_MemoRead( cCsv )
   Vale( "tem cabeçalho", Left( cCsv, 7 ) == "arquivo", .T. )
   /* MLCount() quebra linha por largura; aqui interessa o nº de registros */
   Vale( "3 linhas + cabeçalho", NumLinhas( cCsv ), 4 )

   /* aspas e vírgulas nos dados não podem quebrar o CSV */
   hReg := IncNovo()
   IncRegistrar( hReg, "T.DBF", 1, NIL, "C", 'diz "ola", e vai', "p, com vírgula", 'a "com aspas"', "ALTA" )
   IncGravarCsv( hReg, cDir + "q.csv" )
   cCsv := hb_MemoRead( cDir + "q.csv" )
   Vale( "aspas internas duplicadas", At( '"diz ""ola"", e vai"', cCsv ) > 0, .T. )
   Vale( "chave NIL vira campo vazio", At( '"T.DBF",1,,"C"', cCsv ) > 0, .T. )

   ? "== 4. tabela migracao_inconsistencia =="
   FErase( cDir + "inc.db" )
   pDb := SqlAbrir( cDir + "inc.db" )
   nRc := SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   Vale( "schema aplicado", nRc, 0 )
   nRc := SqlExecBind( pDb, "INSERT INTO migracao_execucao " + ;
      "(iniciada_em, origem, versao_schema, status) VALUES (?,?,?,?)", ;
      { IncAgora(), "legacy/", "1", "EM_ANDAMENTO" } )
   Vale( "execução registrada", nRc, 0 )

   hReg := IncNovo()
   hNorm := NormCnpj( "27439872194873285783" )
   IncAbsorver( hReg, hNorm, "CVBFORNE.DBF", 1, "CODFOR=1", "CGCFAB", "27439872194873285783" )
   IncRegistrar( hReg, "CVBGRUCO.DBF", 1, "CODGRU=1", "NUMMES", "**", ;
      "Overflow gravado pelo Clipper", "NULL na coluna; bruto em *_legado", "ALTA" )

   Vale( "gravou as 2", IncGravarSqlite( hReg, pDb, SqlUltimoId( pDb ) ), 2 )
   Vale( "estão na tabela", SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" ), 2 )
   Vale( "FK para execucao confere", ;
      SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia i " + ;
                       "JOIN migracao_execucao e ON e.id = i.execucao_id" ), 2 )
   aLin := SqlLinhas( pDb, "SELECT arquivo, registro, campo, severidade " + ;
                           "FROM migracao_inconsistencia ORDER BY id" )
   Vale( "1ª linha: arquivo", aLin[ 1 ][ 1 ], "CVBFORNE.DBF" )
   Vale( "1ª linha: registro", aLin[ 1 ][ 2 ], 1 )
   Vale( "1ª linha: campo", aLin[ 1 ][ 3 ], "CGCFAB" )
   Vale( "1ª linha: severidade", aLin[ 1 ][ 4 ], "ALTA" )
   Vale( "CHECK de severidade barra valor inválido", ;
      SqlExecBind( pDb, "INSERT INTO migracao_inconsistencia " + ;
         "(execucao_id,arquivo,registro,campo,problema,acao,severidade) VALUES (?,?,?,?,?,?,?)", ;
         { 1, "X", 1, "C", "p", "a", "URGENTE" } ) != 0, .T. )
   pDb := NIL

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "D.3 ACEITA", "D.3 REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC FUNCTION NumLinhas( cTxt )
   LOCAL n := 0, i := 0
   DO WHILE .T.
      i := hb_At( hb_eol(), cTxt, i + 1 )
      IF i == 0 ; EXIT ; ENDIF
      n++
   ENDDO
   RETURN n

STATIC PROCEDURE Vale( cDesc, xObtido, xEsperado )
   LOCAL lOk := ( ValType( xObtido ) == ValType( xEsperado ) .AND. ;
                  hb_ValToExp( xObtido ) == hb_ValToExp( xEsperado ) )
   IF lOk
      s_nOk++
      ? "   ok   " + cDesc
   ELSE
      s_nFalhas++
      ? "   FALHA " + cDesc
      ? "         esperado: " + hb_ValToExp( xEsperado )
      ? "         obtido..: " + hb_ValToExp( xObtido )
   ENDIF
   RETURN
