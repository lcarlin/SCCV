/*
 * testa_verificacao.prg — critério de aceite da FASE E
 *
 *   E.1  contagem por tabela (com e sem excluídos)        tolerância zero
 *   E.2  7 somas de controle (08 §9.2)                    tolerância zero
 *   E.3  comparação campo a campo — 100% dos registros    tolerância zero
 *   E.4  foreign_key_check + reconciliação das 13 FKs     vazio
 *   E.5  relatório de inconsistências gerado e revisado
 *
 * Migra do zero para um banco temporário e verifica. Depois planta uma
 * corrupção e confirma que a verificação a detecta — uma verificação que
 * nunca falha não verifica nada.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main( cDirLegado )

   LOCAL pDb, hReg, hRes, hV, cDb

   hb_default( @cDirLegado, "legacy" )
   cDb := hb_DirTemp() + "testa_verificacao.db"

   ? "FASE E — aceite da verificação da migração"
   ?

   FErase( cDb )
   pDb  := SqlAbrir( cDb )
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   SqlExecBind( pDb, "INSERT INTO migracao_execucao (iniciada_em, origem," + ;
      " versao_schema, status) VALUES (?,?,?,?)", ;
      { IncAgora(), cDirLegado, "1", "EM_ANDAMENTO" } )

   hReg := IncNovo()
   hRes := CarregarTudo( pDb, cDirLegado, hReg )
   Vale( "migração sem erro", hRes[ "erro" ], NIL )
   IF hRes[ "erro" ] != NIL
      ? "   " + hRes[ "erro" ]
      Fim()
      RETURN
   ENDIF
   IncGravarSqlite( hReg, pDb, 1 )
   SqlExecBind( pDb, "UPDATE migracao_execucao SET status=?, concluida_em=? WHERE id=1", ;
      { "CONCLUIDA", IncAgora() } )

   hV := VerificarTudo( pDb, cDirLegado )
   VerificarImprimir( hV )
   ?
   Vale( "E.1–E.5: nenhuma falha", hV[ "falhas" ], 0 )
   Vale( "e há verificações de fato", hV[ "ok" ] > 40, .T. )

   ? "== a verificação detecta corrupção? =="
   TestaDeteccao( pDb, cDirLegado )
   pDb := NIL

   Fim()
   RETURN

/*
 * Uma verificação que sempre passa não prova nada. Três corrupções plantadas,
 * uma por família de checagem, para confirmar que cada uma tem dente.
 */
STATIC PROCEDURE TestaDeteccao( pDb, cDirLegado )

   LOCAL hV, nAntes

   /* E.2 — muda um salário: a soma de controle tem de acusar */
   SqlExec( pDb, "UPDATE funcionario SET salario_cent = salario_cent + 1 " + ;
                 "WHERE cod_fun = (SELECT MIN(cod_fun) FROM funcionario)" )
   hV := VerificarTudo( pDb, cDirLegado )
   Vale( "E.2 detecta 1 centavo a mais no salário", hV[ "falhas" ] > 0, .T. )
   SqlExec( pDb, "UPDATE funcionario SET salario_cent = salario_cent - 1 " + ;
                 "WHERE cod_fun = (SELECT MIN(cod_fun) FROM funcionario)" )
   hV := VerificarTudo( pDb, cDirLegado )
   Vale( "e volta a passar depois de desfeito", hV[ "falhas" ], 0 )

   /* E.3 — muda um texto: a comparação campo a campo tem de acusar */
   SqlExec( pDb, "UPDATE cliente SET nome = nome || 'X' " + ;
                 "WHERE cod_cli = (SELECT MIN(cod_cli) FROM cliente)" )
   hV := VerificarTudo( pDb, cDirLegado )
   Vale( "E.3 detecta um nome alterado", hV[ "falhas" ] > 0, .T. )
   SqlExec( pDb, "UPDATE cliente SET nome = substr(nome,1,length(nome)-1) " + ;
                 "WHERE cod_cli = (SELECT MIN(cod_cli) FROM cliente)" )

   /* E.1 — apaga um item: a contagem tem de acusar */
   nAntes := SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" )
   SqlExec( pDb, "DELETE FROM venda_peca_item WHERE id = (SELECT MAX(id) FROM venda_peca_item)" )
   hV := VerificarTudo( pDb, cDirLegado )
   Vale( "E.1 detecta um item a menos", hV[ "falhas" ] > 0, .T. )
   Vale( "  (item realmente removido)", ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ), nAntes - 1 )

   RETURN

STATIC PROCEDURE Fim()
   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "FASE E ACEITA", "FASE E REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

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
