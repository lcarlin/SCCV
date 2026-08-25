/*
 * testa_venda.prg — critério de aceite da FASE G, onda 5
 *
 * Venda de peças (balcão), reparo e pronta entrega.
 * RN-024 a RN-029, RN-034, RN-035; D-06, D-07, D-08, D-13, D-17, D-27.
 *
 * É aqui que os serviços da onda 4 passam a ser chamados de verdade: cada venda
 * gravada tem de baixar o estoque certo e creditar a comissão ao funcionário
 * certo, dentro de uma transação.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-venda.db", hC, pDb

   ? "FASE G onda 5 — aceite do movimento"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaMontagem( pDb )
   TestaBalcao( pDb )
   TestaReparo( pDb )
   TestaTransacao( pDb )
   TestaProntaEntrega( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "MOVIMENTO ACEITO", "MOVIMENTO REPROVADO" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro) VALUES (?,?,?)", ;
      { 7, "BatMan", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 1, "Primeiro" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 11, "Vendedor 11" } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque, valor_unit_cent," + ;
      " qtd_minima) VALUES (?,?,?,?,?)", { 1, "Molas", 20, 1000, 5 } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque, valor_unit_cent," + ;
      " qtd_minima) VALUES (?,?,?,?,?)", { 2, "Parafuso", 8, 2000, 0 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 1, "Uno Mile ELX", 2, 1500000 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 2, "Tempra", 3, 3500000 } )
   RETURN

STATIC PROCEDURE TestaMontagem( pDb )

   LOCAL hVenda, hV, hCli

   ? "== RN-026 / D-17 — montagem da venda em memória =="

   hVenda := VendaNova( "BALCAO", 7, "BatMan", 11 )
   Vale( "venda nova sem itens", Len( hVenda[ "itens" ] ), 0 )
   Vale( "total zero", VendaPecaTotal( hVenda ), 0 )

   hV := VendaAdicionarItem( pDb, hVenda, 1, 3 )
   Vale( "item aceito", ValOk( hV ), .T. )
   /* RN-026: subtotal = valor unitário × quantidade */
   Vale( "subtotal 3 × R$ 10,00 = R$ 30,00", ;
         hVenda[ "itens" ][ 1 ][ "subtotal_cent" ], 3000 )
   Vale( "valor unitário copiado do cadastro (D-19)", ;
         hVenda[ "itens" ][ 1 ][ "valor_unit_cent" ], 1000 )
   Vale( "descrição copiada", hVenda[ "itens" ][ 1 ][ "descricao" ], "Molas" )

   VendaAdicionarItem( pDb, hVenda, 2, 2 )
   Vale( "dois itens", Len( hVenda[ "itens" ] ), 2 )
   /* RN-026: total = soma dos subtotais. Calculado, nunca acumulado. */
   Vale( "total = 3000 + 4000", VendaPecaTotal( hVenda ), 7000 )

   Vale( "remove item", VendaRemoverItem( hVenda, 2 ), .T. )
   Vale( "total acompanha a remoção", VendaPecaTotal( hVenda ), 3000 )
   Vale( "índice inválido não remove", VendaRemoverItem( hVenda, 9 ), .F. )
   VendaAdicionarItem( pDb, hVenda, 2, 2 )

   /* peça inexistente */
   Vale( "peça inexistente é recusada", ;
         ValOk( VendaAdicionarItem( pDb, hVenda, 999, 1 ) ), .F. )
   Vale( "quantidade zero é recusada", ;
         ValOk( VendaAdicionarItem( pDb, hVenda, 1, 0 ) ), .F. )

   ? "== RN-024 / RN-025 / D-06 — cliente inexistente =="

   hCli := VendaConferirCliente( pDb, 7, "BALCAO" )
   Vale( "cliente existente é encontrado", hCli[ "existe" ], .T. )
   Vale( "com o nome", hCli[ "nome" ], "BatMan" )
   hCli := VendaConferirCliente( pDb, 999, "BALCAO" )
   Vale( "inexistente é detectado", hCli[ "existe" ], .F. )
   /* RN-024 — na venda de peças, oferece cadastrar em linha */
   Vale( "RN-024: oferece cadastro em linha", hCli[ "oferecer_cadastro" ], .T. )
   /* RN-025 — na pronta entrega, não oferece */
   hCli := VendaConferirCliente( pDb, 999, "VEICULO" )
   Vale( "RN-025: pronta entrega NÃO oferece", hCli[ "oferecer_cadastro" ], .F. )

   RETURN

STATIC PROCEDURE TestaBalcao( pDb )

   LOCAL hVenda, hRes, aItens, hCab

   ? "== venda de balcão: grava, baixa estoque e credita comissão =="

   hVenda := VendaNova( "BALCAO", 7, "BatMan", 11 )
   VendaAdicionarItem( pDb, hVenda, 1, 3 )
   VendaAdicionarItem( pDb, hVenda, 2, 2 )

   hRes := VendaGravar( pDb, hVenda )
   Vale( "grava", hRes[ "ok" ], .T. )
   Vale( "devolve o id", hRes[ "id" ] > 0, .T. )

   hCab := VendaPecaCabecalho( pDb, hRes[ "id" ] )
   /* D-17: o total está no CABEÇALHO, não no último item */
   Vale( "D-17: total no cabeçalho", hCab[ "total_cent" ], 7000 )
   Vale( "cliente gravado", hCab[ "cod_cli" ], 7 )
   /* Q-02: a venda nova declara sua origem */
   Vale( "Q-02: origem declarada", hCab[ "origem" ], "BALCAO" )
   Vale( "nome do cliente em snapshot", hCab[ "nome_cli" ], "BatMan" )

   aItens := VendaPecaItens( pDb, hRes[ "id" ] )
   Vale( "dois itens gravados", Len( aItens ), 2 )
   Vale( "ordem preservada", aItens[ 1 ][ 5 ], 1 )
   Vale( "soma dos itens = total do cabeçalho", ;
         aItens[ 1 ][ 3 ] + aItens[ 2 ][ 3 ], hCab[ "total_cent" ] )

   /* RN-029: baixa de estoque */
   Vale( "estoque da peça 1: 20 - 3", ;
         EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], 17 )
   Vale( "estoque da peça 2: 8 - 2", ;
         EstoqueSaldo( pDb, "peca", "cod_pec", 2 )[ "atual" ], 6 )

   /* RN-030: comissão pelo CÓDIGO do funcionário (Q-10) */
   Vale( "RN-030: comissão = código 11 × R$ 0,20", ComissaoAcumulada( pDb, 11 ), 220 )
   Vale( "D-07: o funcionário 1 não recebeu nada", ComissaoAcumulada( pDb, 1 ), 0 )

   RETURN

STATIC PROCEDURE TestaReparo( pDb )

   LOCAL hVenda, hRes, nAntes

   ? "== reparo: grava, mas NÃO baixa estoque (D-13 / Q-12) =="

   nAntes := EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ]
   hVenda := VendaNova( "REPARO", 7, "BatMan", 11 )
   VendaAdicionarItem( pDb, hVenda, 1, 5 )

   hRes := VendaGravar( pDb, hVenda )
   Vale( "grava o reparo", hRes[ "ok" ], .T. )
   Vale( "origem REPARO", VendaPecaCabecalho( pDb, hRes[ "id" ] )[ "origem" ], "REPARO" )
   /* D-13: no legado o reparo não baixava estoque, e isso foi preservado */
   Vale( "D-13: o estoque NÃO foi baixado", ;
         EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], nAntes )
   /* mas a comissão é creditada igual (RN-030 vale para os dois) */
   Vale( "comissão creditada mesmo assim", ComissaoAcumulada( pDb, 11 ), 440 )

   RETURN

/*
 * O legado gravava item a item direto no arquivo, sem transação: uma queda no
 * meio da compra deixava itens gravados e nenhum total. Aqui, ou tudo, ou nada.
 */
STATIC PROCEDURE TestaTransacao( pDb )

   LOCAL hVenda, hRes, nVendasAntes, nEstoqueAntes, nComissaoAntes

   ? "== transação: venda parcial não existe =="

   nVendasAntes   := SqlEscalar( pDb, "SELECT count(*) FROM venda_peca" )
   nEstoqueAntes  := EstoqueSaldo( pDb, "peca", "cod_pec", 2 )[ "atual" ]
   nComissaoAntes := ComissaoAcumulada( pDb, 11 )

   /* dois itens da mesma peça: individualmente cabem, somados não */
   hVenda := VendaNova( "BALCAO", 7, "BatMan", 11 )
   Vale( "primeiro item de 4 cabe", ValOk( VendaAdicionarItem( pDb, hVenda, 2, 4 ) ), .T. )
   Vale( "segundo item de 4 NÃO cabe (saldo 6)", ;
         ValOk( VendaAdicionarItem( pDb, hVenda, 2, 4 ) ), .F. )
   Vale( "e não foi acrescentado", Len( hVenda[ "itens" ] ), 1 )

   /* venda sem itens */
   Vale( "venda sem itens é recusada", ;
         VendaGravar( pDb, VendaNova( "BALCAO", 7, "BatMan", 11 ) )[ "ok" ], .F. )
   /* cliente inexistente */
   hVenda := VendaNova( "BALCAO", 999, "Fantasma", 11 )
   VendaAdicionarItem( pDb, hVenda, 1, 1 )
   hRes := VendaGravar( pDb, hVenda )
   Vale( "cliente inexistente é recusado", hRes[ "ok" ], .F. )
   Vale( "nada foi gravado", SqlEscalar( pDb, "SELECT count(*) FROM venda_peca" ), nVendasAntes )
   Vale( "estoque intacto", EstoqueSaldo( pDb, "peca", "cod_pec", 2 )[ "atual" ], nEstoqueAntes )
   Vale( "comissão intacta", ComissaoAcumulada( pDb, 11 ), nComissaoAntes )
   Vale( "sem transação pendente", TransNivel(), 0 )

   /* origem inválida */
   hVenda := VendaNova( "XPTO", 7, "BatMan", 11 )
   VendaAdicionarItem( pDb, hVenda, 1, 1 )
   Vale( "origem inválida é recusada", VendaGravar( pDb, hVenda )[ "ok" ], .F. )

   RETURN

STATIC PROCEDURE TestaProntaEntrega( pDb )

   LOCAL hDados, hRes

   ? "== RN-031 / RN-034 / RN-035 — pronta entrega (D-07, D-08) =="

   hDados := { "cod_car" => 2, "cod_cli" => 7, "cod_fun" => 11, ;
      "data_venda" => "1994-06-30", "valor_cent" => 3500000, ;
      "forma_pagamento" => "A VISTA", "descricao" => "Tempra", ;
      "nome_cli" => "BatMan", "nome_fun" => "Vendedor 11" }

   hRes := VendaVeiculoRegistrar( pDb, hDados )
   Vale( "grava", hRes[ "ok" ], .T. )
   /* D-08: a baixa sai do modelo vendido, não do primeiro da tabela */
   Vale( "D-08: baixa no modelo 2", ;
         EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 2 )[ "atual" ], 2 )
   Vale( "D-08: o modelo 1 não foi tocado", ;
         EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 2 )
   /* RN-031: 1,5% de R$ 35.000,00 = R$ 525,00 */
   Vale( "RN-031: comissão de 1,5%", ComissaoAcumulada( pDb, 11 ), 440 + 52500 )
   Vale( "não é o último veículo", hRes[ "ultimo" ], .F. )

   /* RN-035 — aviso ao zerar */
   VendaVeiculoRegistrar( pDb, hDados )
   hRes := VendaVeiculoRegistrar( pDb, hDados )
   Vale( "RN-035: avisa no último veículo", hRes[ "ultimo" ], .T. )
   Vale( "estoque zerado", EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 2 )[ "atual" ], 0 )
   /* D-27: com estoque zero, a venda é recusada — divergência declarada */
   hRes := VendaVeiculoRegistrar( pDb, hDados )
   Vale( "D-27: venda com estoque zero é recusada", hRes[ "ok" ], .F. )
   Vale( "e nada foi gravado", ;
         SqlEscalar( pDb, "SELECT count(*) FROM venda_veiculo WHERE cod_car = 2" ), 3 )

   /* vendedor é obrigatório na pronta entrega (schema: NOT NULL) */
   hDados[ "cod_fun" ] := NIL
   Vale( "vendedor obrigatório", VendaVeiculoRegistrar( pDb, hDados )[ "ok" ], .F. )

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
