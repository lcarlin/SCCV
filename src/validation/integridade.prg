/*
 * integridade.prg — FASES G (onda 1) e H
 *
 * Validações que precisam consultar o banco: V-13 (unicidade de CPF) e V-17
 * (integridade referencial na exclusão).
 *
 * V-17 é a mais importante das duas. `SAIDA()` no legado executava PACK em
 * CVBCLIEN, CVBFORNE e CVBFUNC sem verificar dependências — exclusão física,
 * sem rede. O acervo sobreviveu porque o volume é pequeno e ninguém excluiu um
 * cliente com venda pendente, não porque houvesse proteção
 * (02-MODELO-DADOS.md §8.2).
 *
 * Aqui a exclusão é LÓGICA (excluido = 1), como no restante do sistema, e o
 * que esta função impede é marcar como excluído quem ainda é referenciado.
 * As FKs do schema não bastam: `excluido = 1` não é DELETE, então o SQLite não
 * tem o que barrar.
 */

FUNCTION IntegCpfUnico( pDb, cCpf, nCodCliAtual )

   LOCAL cSql, nQtd

   IF Empty( cCpf )
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => NIL }
   ENDIF

   cSql := "SELECT count(*) FROM cliente WHERE cpf = ? AND excluido = 0"
   IF nCodCliAtual != NIL
      cSql += " AND cod_cli <> " + hb_ntos( nCodCliAtual )
   ENDIF

   nQtd := IntegContar( pDb, cSql, { cCpf } )
   IF nQtd > 0
      RETURN { "ok" => .F., ;
               "mensagem" => "Este CPF já está cadastrado para outro cliente.", ;
               "valor" => NIL }
   ENDIF

   RETURN { "ok" => .T., "mensagem" => NIL, "valor" => cCpf }

/*
 * Devolve { "ok", "mensagem", "referencias" => { {tabela, quantidade}, ... } }.
 * A mensagem diz ONDE está preso — "não é possível excluir" sem dizer por quê
 * obriga o operador a adivinhar.
 */
FUNCTION IntegPodeExcluir( pDb, cEntidade, nCodigo )

   LOCAL aDeps, i, nQtd, aRef := {}, cMsg

   aDeps := IntegDependencias( cEntidade )
   IF aDeps == NIL
      RETURN { "ok" => .T., "mensagem" => NIL, "referencias" => aRef }
   ENDIF

   FOR i := 1 TO Len( aDeps )
      nQtd := IntegContar( pDb, "SELECT count(*) FROM " + aDeps[ i ][ 1 ] + ;
         " WHERE " + aDeps[ i ][ 2 ] + " = " + hb_ntos( nCodigo ) + ;
         iif( aDeps[ i ][ 4 ], " AND excluido = 0", "" ), {} )
      IF nQtd > 0
         AAdd( aRef, { "tabela" => aDeps[ i ][ 3 ], "quantidade" => nQtd } )
      ENDIF
   NEXT

   IF Len( aRef ) == 0
      RETURN { "ok" => .T., "mensagem" => NIL, "referencias" => aRef }
   ENDIF

   cMsg := "Não é possível excluir: há registros que dependem deste cadastro — "
   FOR i := 1 TO Len( aRef )
      cMsg += iif( i > 1, ", ", "" ) + hb_ntos( aRef[ i ][ "quantidade" ] ) + " " + ;
              aRef[ i ][ "tabela" ]
   NEXT
   cMsg += "."

   RETURN { "ok" => .F., "mensagem" => cMsg, "referencias" => aRef }

/*
 * { tabela, coluna, nome para o usuário, filtrar por excluido = 0 }
 *
 * venda_peca_item não tem coluna `excluido` — quem é excluído é a venda —
 * então a checagem de peça passa pela venda.
 */
STATIC FUNCTION IntegDependencias( cEntidade )

   DO CASE
   CASE cEntidade == "cliente"
      RETURN { ;
         { "venda_veiculo"   , "cod_cli", "venda(s) de veículo"   , .T. }, ;
         { "venda_peca"      , "cod_cli", "venda(s) de peça"      , .T. }, ;
         { "consorcio_cota"  , "cod_cli", "cota(s) de consórcio"  , .T. }, ;
         { "orcamento_reparo", "cod_cli", "orçamento(s) de reparo", .T. } }
   CASE cEntidade == "funcionario"
      RETURN { ;
         { "venda_veiculo"   , "cod_fun", "venda(s) de veículo"   , .T. }, ;
         { "venda_peca"      , "cod_fun", "venda(s) de peça"      , .T. }, ;
         { "orcamento_reparo", "cod_fun", "orçamento(s) de reparo", .T. } }
   CASE cEntidade == "fornecedor"
      RETURN { ;
         { "peca"        , "cod_for", "peça(s)"                , .T. }, ;
         { "almoxarifado", "cod_for", "item(ns) de almoxarifado", .T. } }
   CASE cEntidade == "modelo_veiculo"
      RETURN { ;
         { "venda_veiculo" , "cod_car", "venda(s) de veículo"  , .T. }, ;
         { "consorcio_cota", "cod_car", "cota(s) de consórcio" , .T. } }
   CASE cEntidade == "peca"
      RETURN { ;
         { "orcamento_reparo", "cod_pec", "orçamento(s) de reparo", .T. } }
   ENDCASE

   RETURN NIL

/* Peça precisa de consulta própria: o item não tem excluido, a venda tem. */
FUNCTION IntegPecaEmVenda( pDb, nCodPec )
   RETURN IntegContar( pDb, ;
      "SELECT count(*) FROM venda_peca_item i JOIN venda_peca v ON v.id = i.venda_id" + ;
      " WHERE i.cod_pec = " + hb_ntos( nCodPec ) + " AND v.excluido = 0", {} )

FUNCTION IntegExiste( pDb, cTabela, cColuna, nCodigo )

   IF nCodigo == NIL
      RETURN .F.
   ENDIF

   RETURN IntegContar( pDb, "SELECT count(*) FROM " + cTabela + " WHERE " + ;
      cColuna + " = " + hb_ntos( nCodigo ) + " AND excluido = 0", {} ) > 0

STATIC FUNCTION IntegContar( pDb, cSql, aParams )

   LOCAL xN

   IF Len( aParams ) == 0
      xN := SqlEscalar( pDb, cSql )
      RETURN iif( xN == NIL, 0, xN )
   ENDIF

   RETURN IntegContarBind( pDb, cSql, aParams )

/* Com parâmetro: o CPF vem do usuário e não entra no SQL por concatenação. */
STATIC FUNCTION IntegContarBind( pDb, cSql, aParams )

   LOCAL aLin := SqlLinhasBind( pDb, cSql, aParams )

   IF Len( aLin ) == 0 .OR. aLin[ 1 ][ 1 ] == NIL
      RETURN 0
   ENDIF

   RETURN aLin[ 1 ][ 1 ]
