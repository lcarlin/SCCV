/*
 * venda_peca.prg — FASE G, onda 5
 *
 * SQL do cabeçalho e dos itens da venda de peças. As regras ficam em
 * services/venda.prg; aqui só persistência.
 *
 * D-17 — O legado gravava itens SOLTOS em CVPECAS e punha o total da compra
 * apenas no ÚLTIMO item da sessão; os demais ficavam com zero (28 de 75
 * registros). Isso não era desleixo de modelagem: o conceito de "compra com
 * vários itens" existe no legado — o laço interno de CVMTVPEC e o próprio
 * VALTOT comprovam. O que faltava era estrutura para representá-lo. Sem
 * cabeçalho é impossível totalizar um relatório corretamente, estornar uma
 * venda, ou saber quais itens pertencem à mesma compra.
 *
 * NOTA DE BUILD: este arquivo se chamava venda.prg e colidia com
 * services/venda.prg — o hbmk2 nomeia os objetos pelo nome BASE do fonte, então
 * dois `venda.prg` em diretórios diferentes geram o mesmo .o e um sobrescreve o
 * outro, com erro de símbolo indefinido no link. Nomes de fonte precisam ser
 * únicos no projeto inteiro, não só por diretório.
 */

/* Cabeçalho + itens numa transação só. Devolve o id da venda, ou NIL. */
FUNCTION VendaPecaInserir( pDb, hVenda )

   LOCAL nRc, nId, i, hItem

   nRc := SqlExecBind( pDb, ;
      "INSERT INTO venda_peca (cod_cli, cod_fun, origem, data_venda," + ;
      " total_cent, nome_cli_snapshot, excluido) VALUES (?,?,?,?,?,?,0)", { ;
      hVenda[ "cod_cli" ], hVenda[ "cod_fun" ], hVenda[ "origem" ], ;
      hVenda[ "data_venda" ], VendaPecaTotal( hVenda ), hVenda[ "nome_cli" ] } )
   IF nRc != 0
      RETURN NIL
   ENDIF
   nId := SqlUltimoId( pDb )

   FOR i := 1 TO Len( hVenda[ "itens" ] )
      hItem := hVenda[ "itens" ][ i ]
      nRc := SqlExecBind( pDb, ;
         "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
         " valor_unit_cent, subtotal_cent, descricao_snapshot, ordem)" + ;
         " VALUES (?,?,?,?,?,?,?)", { ;
         nId, hItem[ "cod_pec" ], hItem[ "quantidade" ], ;
         hItem[ "valor_unit_cent" ], hItem[ "subtotal_cent" ], ;
         hItem[ "descricao" ], i } )
      IF nRc != 0
         RETURN NIL
      ENDIF
   NEXT

   RETURN nId

/*
 * Dados de uma peça para compor o item: preço e saldo no momento da venda.
 *
 * O valor unitário é COPIADO para o item (snapshot), diferente do cadastro,
 * onde o nome do fornecedor vem por JOIN. Aqui a cópia é deliberada (D-19): o
 * preço de uma venda de 1994 é o preço daquele dia, e alterar o cadastro da
 * peça não pode reescrever o histórico.
 */
FUNCTION VendaPecaDados( pDb, nCodPec )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT descricao, valor_unit_cent," + ;
      " qtd_estoque, qtd_minima FROM peca WHERE cod_pec = ? AND excluido = 0", ;
      { nCodPec } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "descricao" => aL[ 1 ][ 1 ], "valor_unit_cent" => aL[ 1 ][ 2 ], ;
            "qtd_estoque" => aL[ 1 ][ 3 ], "qtd_minima" => aL[ 1 ][ 4 ] }

FUNCTION VendaNomeCliente( pDb, nCodCli )
   RETURN LookupDescricao( pDb, "cliente", nCodCli )

FUNCTION VendaNomeFuncionario( pDb, nCodFun )
   RETURN LookupDescricao( pDb, "funcionario", nCodFun )

/* Itens de uma venda gravada — para consulta e para o estorno. */
FUNCTION VendaPecaItens( pDb, nVendaId )
   RETURN SqlLinhasBind( pDb, "SELECT cod_pec, quantidade, subtotal_cent," + ;
      " descricao_snapshot, ordem FROM venda_peca_item WHERE venda_id = ?" + ;
      " ORDER BY ordem", { nVendaId } )

FUNCTION VendaPecaCabecalho( pDb, nVendaId )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT cod_cli, cod_fun, origem, data_venda," + ;
      " total_cent, nome_cli_snapshot, excluido FROM venda_peca WHERE id = ?", ;
      { nVendaId } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "cod_cli" => aL[ 1 ][ 1 ], "cod_fun" => aL[ 1 ][ 2 ], ;
            "origem" => aL[ 1 ][ 3 ], "data_venda" => aL[ 1 ][ 4 ], ;
            "total_cent" => aL[ 1 ][ 5 ], "nome_cli" => aL[ 1 ][ 6 ], ;
            "excluido" => aL[ 1 ][ 7 ] }
