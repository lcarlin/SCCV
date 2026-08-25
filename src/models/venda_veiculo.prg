/*
 * venda_veiculo.prg — FASE G, onda 5
 *
 * SQL da venda de veículo (pronta entrega). As regras ficam em
 * services/venda.prg.
 *
 * Os campos *_snapshot guardam descrição do modelo e nomes de cliente e
 * funcionário como estavam NO DIA da venda. Diferente do cadastro, onde o nome
 * do fornecedor vem por JOIN, aqui a cópia é deliberada (D-19): o histórico de
 * uma venda não pode ser reescrito por uma alteração posterior no cadastro.
 */

FUNCTION VendaVeiculoInserir( pDb, hVenda )

   LOCAL nRc := SqlExecBind( pDb, ;
      "INSERT INTO venda_veiculo (cod_car, cod_cli, cod_fun, data_venda," + ;
      " valor_cent, forma_pagamento, descricao_snapshot, nome_cli_snapshot," + ;
      " nome_fun_snapshot, excluido) VALUES (?,?,?,?,?,?,?,?,?,0)", { ;
      hVenda[ "cod_car" ], hVenda[ "cod_cli" ], hVenda[ "cod_fun" ], ;
      hVenda[ "data_venda" ], hVenda[ "valor_cent" ], hVenda[ "forma_pagamento" ], ;
      hVenda[ "descricao" ], hVenda[ "nome_cli" ], hVenda[ "nome_fun" ] } )

   IF nRc != 0
      RETURN NIL
   ENDIF

   RETURN SqlUltimoId( pDb )

FUNCTION VendaModeloDados( pDb, nCodCar )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT descricao, valor_cent, qtd_estoque" + ;
      " FROM modelo_veiculo WHERE cod_car = ? AND excluido = 0", { nCodCar } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "descricao" => aL[ 1 ][ 1 ], "valor_cent" => aL[ 1 ][ 2 ], ;
            "qtd_estoque" => aL[ 1 ][ 3 ] }

