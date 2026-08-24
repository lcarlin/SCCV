/*
 * testa_migracao.prg — critério de aceite das FASES D.4 e D.5
 *
 *   D.4  carregador.prg — INSERT em transação, ordem topológica
 *        critério: "Rollback em falha simulada"
 *   D.5  transformações estruturais (08 §6)
 *
 * As contagens esperadas vêm de docs/08-MIGRACAO-DADOS.md §3.1.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main( cDirLegado )

   LOCAL pDb, hReg, hRes, cDb, aLin

   hb_default( @cDirLegado, "legacy" )
   cDb := hb_DirTemp() + "testa_migracao.db"

   ? "FASE D.4/D.5 — aceite da carga e das transformações estruturais"
   ?

   FErase( cDb )
   pDb  := SqlAbrir( cDb )
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   hReg := IncNovo()
   hRes := CarregarTudo( pDb, cDirLegado, hReg )

   ? "== 1. a carga completa =="
   Vale( "sem erro", hRes[ "erro" ], NIL )
   IF hRes[ "erro" ] != NIL
      ? "   " + hRes[ "erro" ]
      Fim()
      RETURN
   ENDIF

   ? "== 2. contagens por tabela (08 §3.1) =="
   Conta( pDb, "cliente"          , 22 )
   Conta( pDb, "funcionario"      , 10 )
   Conta( pDb, "fornecedor"       ,  3 )
   Conta( pDb, "peca"             ,  4 )
   Conta( pDb, "almoxarifado"     ,  4 )
   Conta( pDb, "modelo_veiculo"   ,  5 )
   Conta( pDb, "venda_veiculo"    , 23 )
   Conta( pDb, "venda_peca_item"  , 75 )
   Conta( pDb, "consorcio_cota"   ,  5 )
   Conta( pDb, "orcamento_reparo" ,  4 )
   Conta( pDb, "pedido"           ,  0 )
   Conta( pDb, "sequencia"        ,  1 )
   Conta( pDb, "_legado_cvvcar"   ,  4 )
   Conta( pDb, "_legado_cvvpec"   , 10 )
   Conta( pDb, "_legado_cvclient" , 12 )
   Conta( pDb, "_legado_cvbgrupo_excluido", 3 )

   ? "== 3. integridade =="
   Vale( "integrity_check", SqlEscalar( pDb, "PRAGMA integrity_check" ), "ok" )
   Vale( "foreign_key_check vazio", Len( SqlLinhas( pDb, "PRAGMA foreign_key_check" ) ), 0 )
   Vale( "foreign_keys ON durante a carga", SqlEscalar( pDb, "PRAGMA foreign_keys" ), 1 )

   ? "== 4. §6.1 CVPECAS → venda_peca + itens =="
   Vale( "75 itens preservados", SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ), 75 )
   Vale( "todo item tem cabeçalho", ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item i " + ;
                       "LEFT JOIN venda_peca v ON v.id=i.venda_id WHERE v.id IS NULL" ), 0 )
   Vale( "origem não é inferida (Q-02)", ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_peca WHERE origem <> 'INDETERMINADO'" ), 0 )
   Vale( "ordem dos itens começa em 1", ;
      SqlEscalar( pDb, "SELECT min(ordem) FROM venda_peca_item" ), 1 )

   ? "== 5. §6.2 CVBGRUPO + CVBGRUCO → consorcio_cota =="
   Vale( "3 cotas do grupo fechado", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota WHERE grupo_fechado=1" ), 3 )
   Vale( "2 cotas do grupo em formação", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota WHERE grupo_fechado=0" ), 2 )
   Vale( "sem colisão de (cod_gru, num_participante)", ;
      SqlEscalar( pDb, "SELECT count(*) FROM (SELECT cod_gru, num_participante " + ;
                       "FROM consorcio_cota GROUP BY 1,2 HAVING count(*)>1)" ), 0 )
   Vale( "ativos renumerados para 4 e 5 (D-25)", ;
      SqlEscalar( pDb, "SELECT group_concat(num_participante) FROM " + ;
                       "(SELECT num_participante FROM consorcio_cota " + ;
                       " WHERE grupo_fechado=0 ORDER BY num_participante)" ), "4,5" )
   Vale( "excluídos não viraram cota", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota WHERE excluido=1" ), 0 )
   Vale( "'**' preservado em *_legado (D-11)", ;
      SqlEscalar( pDb, "SELECT parcelas_restantes_legado FROM consorcio_cota " + ;
                       "WHERE num_participante=1 AND grupo_fechado=1" ), "**" )
   Vale( "e a coluna restrita ficou NULL", ;
      SqlEscalar( pDb, "SELECT parcelas_restantes FROM consorcio_cota " + ;
                       "WHERE num_participante=1 AND grupo_fechado=1" ), NIL )
   Vale( "negativos também (-2)", ;
      SqlEscalar( pDb, "SELECT parcelas_restantes_legado FROM consorcio_cota " + ;
                       "WHERE num_participante=2 AND grupo_fechado=1" ), "-2" )

   ? "== 6. §6.3 memos .DBT =="
   Vale( "fornecedor 1 tem observação", ;
      SqlEscalar( pDb, "SELECT count(*) FROM fornecedor WHERE cod_for=1 " + ;
                       "AND observacoes IS NOT NULL" ), 1 )
   Vale( "conteúdo do bloco 2", ;
      SqlEscalar( pDb, "SELECT substr(observacoes,1,24) FROM fornecedor WHERE cod_for=1" ), ;
      "CODIGO DO ITEM TALVEZ N" + hb_UTF8ToStr( hb_StrToUTF8( "A" ) ) )
   Vale( "fornecedor 3 tem observação", ;
      SqlEscalar( pDb, "SELECT observacoes FROM fornecedor WHERE cod_for=3" ), "o babaca" )
   Vale( "fornecedor 2 sem observação", ;
      SqlEscalar( pDb, "SELECT observacoes FROM fornecedor WHERE cod_for=2" ), NIL )

   ? "== 7. §6.4 CVMGRUPO.MEM → sequencia =="
   Vale( "sequencia ajustada para MAX(cod_gru)", ;
      SqlEscalar( pDb, "SELECT valor FROM sequencia WHERE nome='consorcio_grupo'" ), 1 )

   ? "== 8. CPF: todos NULL, originais preservados (08 §4.5, medido em D.2) =="
   Vale( "nenhum cpf gravado", SqlEscalar( pDb, "SELECT count(cpf) FROM cliente" ), 0 )
   Vale( "22 originais preservados", ;
      SqlEscalar( pDb, "SELECT count(cpf_original) FROM cliente" ), 22 )
   Vale( "cpf_valido = 0 em todos", ;
      SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cpf_valido<>0" ), 0 )

   ? "== 9. inconsistências registradas =="
   Vale( "há inconsistências", IncTotal( hReg ) > 0, .T. )
   Vale( "gravam na tabela", IncGravarSqlite( hReg, pDb, NIL ) >= 0, .T. )
   aLin := SqlLinhas( pDb, "SELECT DISTINCT severidade FROM migracao_inconsistencia" )
   Vale( "só severidades válidas", Len( aLin ) <= 3, .T. )
   pDb := NIL

   ? "== 10. D.4 — rollback em falha simulada =="
   TestaRollback( cDirLegado )

   Fim()
   RETURN

/*
 * Critério de aceite da D.4. Um cliente pré-inserido com o mesmo cod_cli que
 * virá do legado faz o INSERT falhar no meio da tabela. A transação daquela
 * tabela precisa voltar inteira: nada parcial pode sobrar.
 */
STATIC PROCEDURE TestaRollback( cDirLegado )

   LOCAL pDb, hReg, hRes, cDb := hb_DirTemp() + "testa_rollback.db"

   FErase( cDb )
   pDb := SqlAbrir( cDb )
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )

   /* CVBCLIEN tem 22 registros; plantamos uma colisão no meio do caminho */
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro) " + ;
      "VALUES (?,?,?)", { 24, "PLANTADO PARA COLIDIR", "1994-01-01" } )
   Vale( "1 cliente plantado", SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), 1 )

   hReg := IncNovo()
   hRes := CarregarTudo( pDb, cDirLegado, hReg )

   Vale( "a carga falhou", hRes[ "erro" ] != NIL, .T. )
   IF hRes[ "erro" ] != NIL
      ? "   erro relatado: " + hRes[ "erro" ]
   ENDIF
   Vale( "ROLLBACK devolveu a tabela ao estado anterior", ;
      SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), 1 )
   Vale( "o cliente plantado continua lá", ;
      SqlEscalar( pDb, "SELECT nome FROM cliente WHERE cod_cli=24" ), ;
      "PLANTADO PARA COLIDIR" )
   Vale( "nenhuma tabela seguinte foi tocada", ;
      SqlEscalar( pDb, "SELECT count(*) FROM funcionario" ), 0 )
   pDb := NIL

   RETURN

STATIC PROCEDURE Conta( pDb, cTabela, nEsperado )
   Vale( PadR( cTabela, 26 ), SqlEscalar( pDb, "SELECT count(*) FROM " + cTabela ), nEsperado )
   RETURN

STATIC PROCEDURE Fim()
   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "D.4/D.5 ACEITAS", "D.4/D.5 REPROVADAS" )
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
