/*
 * testa_admin.prg — critério de aceite da FASE G, onda 9
 *
 * Backup, dump, restore, verificação e purga.
 * Especificação: 10 §9 (briefing §30) e 09/D-15.
 *
 * O teste de restore é o que o plano exige explicitamente: faz backup, altera
 * dados, restaura e confere que o estado voltou ao do backup.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-admin.db", hC, pDb

   ? "FASE G onda 9 — aceite dos comandos administrativos"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaVerificar( pDb )
   TestaBackupRestore( pDb, cDb )
   TestaDump( pDb )
   TestaPurga( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "ADMIN ACEITO", "ADMIN REPROVADO" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
      " VALUES (?,?,?)", { 1, "COM VENDA", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro, excluido)" + ;
      " VALUES (?,?,?,1)", { 2, "EXCLUÍDO SEM VÍNCULO", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro, excluido)" + ;
      " VALUES (?,?,?,1)", { 3, "EXCLUÍDO COM VENDA", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 1, "VENDEDOR" } )
   /* o cliente 3 está excluído mas ainda é referenciado por uma venda ativa */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 3, "BALCAO", 1000 } )
   RETURN

STATIC PROCEDURE TestaVerificar( pDb )

   LOCAL aRes := AdminVerificar( pDb ), i, nCli := 0

   ? "== --verificar =="

   Vale( "traz vários itens", Len( aRes ) > 5, .T. )
   Vale( "integrity_check é o primeiro", aRes[ 1 ][ "item" ], "integrity_check" )
   Vale( "e está ok", aRes[ 1 ][ "ok" ], .T. )
   Vale( "foreign_key_check vazio", aRes[ 2 ][ "ok" ], .T. )
   Vale( "foreign_keys ligado", aRes[ 3 ][ "ok" ], .T. )

   FOR i := 1 TO Len( aRes )
      IF aRes[ i ][ "item" ] == "cliente"
         nCli := Val( aRes[ i ][ "valor" ] )
      ENDIF
   NEXT
   Vale( "conta os clientes (inclusive excluídos)", nCli, 3 )

   RETURN

/* O teste que o plano §9 exige por escrito. */
STATIC PROCEDURE TestaBackupRestore( pDb, cDb )

   LOCAL hBkp, hRes, pDb2, nAntes, nDepois

   ? "== --backup e --restore =="

   nAntes := SqlEscalar( pDb, "SELECT count(*) FROM cliente" )
   hBkp := AdminBackup( pDb, hb_DirTemp() + "bkp-teste.db" )
   Vale( "backup gerado", hBkp[ "ok" ], .T. )
   Vale( "arquivo existe", hb_vfExists( hBkp[ "arquivo" ] ), .T. )

   /* o backup é um banco válido e completo */
   pDb2 := SqlAbrir( hBkp[ "arquivo" ], .F. )
   Vale( "backup abre como banco", pDb2 != NIL, .T. )
   Vale( "com os mesmos clientes", SqlEscalar( pDb2, "SELECT count(*) FROM cliente" ), nAntes )
   Vale( "e íntegro", SqlEscalar( pDb2, "PRAGMA integrity_check" ), "ok" )
   pDb2 := NIL

   /* altera os dados depois do backup */
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
      " VALUES (?,?,?)", { 99, "DEPOIS DO BACKUP", "1994-01-01" } )
   nDepois := SqlEscalar( pDb, "SELECT count(*) FROM cliente" )
   Vale( "banco alterado", nDepois, nAntes + 1 )
   ConexaoFechar()

   /* restaura */
   hRes := AdminRestore( hBkp[ "arquivo" ], cDb )
   Vale( "restaurado", hRes[ "ok" ], .T. )
   Vale( "o banco anterior foi preservado", hb_vfExists( hRes[ "anterior" ] ), .T. )

   pDb2 := SqlAbrir( cDb, .F. )
   Vale( "estado voltou ao do backup", ;
         SqlEscalar( pDb2, "SELECT count(*) FROM cliente" ), nAntes )
   Vale( "o registro posterior sumiu", ;
         SqlEscalar( pDb2, "SELECT count(*) FROM cliente WHERE cod_cli = 99" ), 0 )
   pDb2 := NIL

   /* e o preservado ainda tem o registro posterior — dá para voltar atrás */
   pDb2 := SqlAbrir( hRes[ "anterior" ], .F. )
   Vale( "o preservado mantém o estado de antes do restore", ;
         SqlEscalar( pDb2, "SELECT count(*) FROM cliente" ), nDepois )
   pDb2 := NIL

   /* restore de arquivo inválido NÃO destrói o banco atual */
   hb_MemoWrit( hb_DirTemp() + "lixo.db", "isto não é um banco" )
   hRes := AdminRestore( hb_DirTemp() + "lixo.db", cDb )
   Vale( "arquivo inválido é recusado", hRes[ "ok" ], .F. )
   pDb2 := SqlAbrir( cDb, .F. )
   Vale( "e o banco atual continua intacto", ;
         SqlEscalar( pDb2, "SELECT count(*) FROM cliente" ), nAntes )
   pDb2 := NIL

   /* um banco SQLite válido, mas que não é do S.C.C.V. */
   FErase( hb_DirTemp() + "outro.db" )
   pDb2 := SqlAbrir( hb_DirTemp() + "outro.db", .T. )
   SqlExec( pDb2, "CREATE TABLE outra_coisa (x INTEGER)" )
   pDb2 := NIL
   hRes := AdminRestore( hb_DirTemp() + "outro.db", cDb )
   Vale( "banco alheio é recusado", hRes[ "ok" ], .F. )
   Vale( "com mensagem clara", At( "não é um banco do S.C.C.V.", hRes[ "mensagem" ] ) > 0, .T. )

   Vale( "arquivo inexistente é recusado", ;
         AdminRestore( hb_DirTemp() + "nao-existe.db", cDb )[ "ok" ], .F. )

   /* reabre para os testes seguintes */
   ConexaoAbrir( cDb, .F. )

   RETURN

STATIC PROCEDURE TestaDump( pDb )

   LOCAL cArq := hb_DirTemp() + "dump-teste.sql", hRes, cTxt

   ? "== --dump (cópia lógica) =="

   hRes := AdminDump( ConexaoDb(), cArq )
   Vale( "gerado", hRes[ "ok" ], .T. )
   cTxt := hb_MemoRead( cArq )
   Vale( "traz o schema", At( "CREATE TABLE cliente", cTxt ) > 0, .T. )
   Vale( "traz os dados", At( "INSERT INTO cliente", cTxt ) > 0, .T. )
   Vale( "é uma transação", At( "BEGIN TRANSACTION;", cTxt ) > 0, .T. )
   Vale( "e fecha", At( "COMMIT;", cTxt ) > 0, .T. )
   Vale( "acentos preservados", At( "EXCLUÍDO", cTxt ) > 0, .T. )
   Vale( "NULL é literal, não texto", At( "NULL", cTxt ) > 0, .T. )

   /* o dump precisa recarregar: é essa a razão de existir */
   FErase( hb_DirTemp() + "recarga.db" )
   Vale( "recarrega num banco novo", ;
         hb_run( "sqlite3 " + hb_DirTemp() + "recarga.db < " + cArq ) , 0 )
   Vale( "com os mesmos clientes", ;
         SqlEscalar( SqlAbrir( hb_DirTemp() + "recarga.db", .F. ), ;
                     "SELECT count(*) FROM cliente" ), ;
         SqlEscalar( ConexaoDb(), "SELECT count(*) FROM cliente" ) )

   RETURN

/*
 * D-15 — a purga que o legado fazia às escondidas, ao sair, agora é deliberada:
 * exige backup, recusa purgar quem é referenciado, e explica o que reteve.
 */
STATIC PROCEDURE TestaPurga( pDb )

   LOCAL hRes, nAntes

   ? "== --purgar (D-15) =="

   pDb := ConexaoDb()
   nAntes := SqlEscalar( pDb, "SELECT count(*) FROM cliente" )
   Vale( "há 2 clientes excluídos", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE excluido = 1" ), 2 )

   /* simulação não apaga nada */
   hRes := AdminPurgar( pDb, .T. )
   Vale( "simulação roda", hRes[ "ok" ], .T. )
   Vale( "e não gera backup", hRes[ "backup" ], NIL )
   Vale( "nada foi apagado", SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), nAntes )
   Vale( "1 seria purgado", Len( hRes[ "purgados" ] ), 1 )
   Vale( "1 seria retido", Len( hRes[ "retidos" ] ), 1 )
   Vale( "o retido é o que tem venda", hRes[ "retidos" ][ 1 ][ "id" ], 3 )
   Vale( "com o motivo", At( "venda(s) de peça", hRes[ "retidos" ][ 1 ][ "motivo" ] ) > 0, .T. )

   /* purga de verdade */
   hRes := AdminPurgar( pDb, .F. )
   Vale( "purga executa", hRes[ "ok" ], .T. )
   /* o backup obrigatório é a garantia que o PACK do legado não tinha */
   Vale( "gerou backup obrigatório", hRes[ "backup" ] != NIL, .T. )
   Vale( "e o arquivo existe", hb_vfExists( hRes[ "backup" ] ), .T. )
   Vale( "um cliente a menos", SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), nAntes - 1 )
   Vale( "o sem vínculo sumiu", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cod_cli = 2" ), 0 )
   /* V-17 — o referenciado NÃO é purgado, mesmo estando marcado como excluído */
   Vale( "o referenciado continua lá", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cod_cli = 3" ), 1 )
   Vale( "o ativo não foi tocado", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cod_cli = 1" ), 1 )
   Vale( "integridade preservada", ;
         Len( SqlLinhas( pDb, "PRAGMA foreign_key_check" ) ), 0 )

   /* purgar de novo não tem o que fazer */
   hRes := AdminPurgar( pDb, .F. )
   Vale( "segunda purga não apaga nada", Len( hRes[ "purgados" ] ), 0 )
   Vale( "e continua retendo o referenciado", Len( hRes[ "retidos" ] ), 1 )

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
