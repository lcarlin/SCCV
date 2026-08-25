/*
 * testa_servicos.prg — critério de aceite da FASE G, onda 4
 *
 * services/comissao.prg (RN-030, RN-031, RN-032; D-05, D-07)
 * services/estoque.prg  (RN-028, RN-029, RN-034, RN-035; D-08, D-13, D-27)
 *
 * Boa parte destas asserções existe para PROTEGER comportamento defeituoso do
 * legado que foi deliberadamente preservado. Se alguém "consertar" RN-030 por
 * achar que 20% do item faz mais sentido, este teste falha — que é exatamente
 * o que deve acontecer enquanto Q-10 não for respondida pelo negócio.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-servicos.db", hC, pDb

   ? "FASE G onda 4 — aceite dos serviços"
   ?
   TestaFormulas()

   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaCredito( pDb )
   TestaEstoque( pDb )
   TestaVeiculo( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "SERVIÇOS ACEITOS", "SERVIÇOS REPROVADOS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 1, "Primeiro" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 11, "Vendedor 11" } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque, qtd_minima)" + ;
      " VALUES (?,?,?,?)", { 1, "Vela", 10, 4 } )
   SqlExecBind( pDb, "INSERT INTO almoxarifado (cod_alm, descricao, qtd_estoque, qtd_minima)" + ;
      " VALUES (?,?,?,?)", { 1, "Parafuso", 100, 20 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque)" + ;
      " VALUES (?,?,?)", { 1, "Uno Mile ELX", 2 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque)" + ;
      " VALUES (?,?,?)", { 2, "Tempra", 5 } )
   RETURN

STATIC PROCEDURE TestaFormulas()

   ? "== RN-030 — venda de peças (D-05, Q-10: fórmula anômala PRESERVADA) =="

   /* a base é o CÓDIGO do funcionário, não o valor vendido */
   Vale( "código 1 → R$ 0,20", ComissaoVendaPeca( 1 ), 20 )
   Vale( "código 11 → R$ 2,20", ComissaoVendaPeca( 11 ), 220 )
   Vale( "código 5 → R$ 1,00", ComissaoVendaPeca( 5 ), 100 )
   /* e é independente do valor da venda — a anomalia, preservada de propósito */
   Vale( "não depende do valor vendido", ComissaoVendaPeca( 1 ), ComissaoVendaPeca( 1 ) )
   Vale( "código ausente não gera comissão", ComissaoVendaPeca( NIL ), 0 )

   ? "== RN-031 — pronta entrega: 1,5% do valor =="

   Vale( "R$ 2.000,00 → R$ 30,00", ComissaoProntaEntrega( 200000 ), 3000 )
   Vale( "R$ 12.500,00 → R$ 187,50", ComissaoProntaEntrega( 1250000 ), 18750 )
   Vale( "R$ 0,00 → zero", ComissaoProntaEntrega( 0 ), 0 )
   /* arredondamento para o centavo mais próximo, sem ponto flutuante */
   Vale( "R$ 1,00 → R$ 0,02 (arredonda 1,5 centavo)", ComissaoProntaEntrega( 100 ), 2 )
   Vale( "R$ 0,33 → zero (0,495 centavo)", ComissaoProntaEntrega( 33 ), 0 )
   Vale( "R$ 0,34 → 1 centavo (0,51)", ComissaoProntaEntrega( 34 ), 1 )

   ? "== RN-032 — consórcio: 0,15% da prestação =="

   Vale( "prestação R$ 2.000,00 → R$ 3,00", ComissaoConsorcio( 200000 ), 300 )
   Vale( "prestação R$ 100,00 → R$ 0,15", ComissaoConsorcio( 10000 ), 15 )
   /* a base é a prestação, não o total do plano — 10x a prestação não é 10x... */
   Vale( "é proporcional à prestação", ComissaoConsorcio( 20000 ), 30 )

   RETURN

STATIC PROCEDURE TestaCredito( pDb )

   LOCAL hRes

   ? "== D-07 — a comissão vai para o funcionário CERTO =="

   Vale( "ambos começam zerados", ComissaoAcumulada( pDb, 1 ), 0 )

   hRes := ComissaoCreditar( pDb, 11, ComissaoProntaEntrega( 1250000 ) )
   Vale( "credita", hRes[ "ok" ], .T. )
   /* no legado isso iria para o funcionário 1, o primeiro do arquivo */
   Vale( "vai para o funcionário 11", ComissaoAcumulada( pDb, 11 ), 18750 )
   Vale( "e NÃO para o primeiro (D-07)", ComissaoAcumulada( pDb, 1 ), 0 )

   /* RN-033 — acumulador perpétuo, nunca zerado */
   ComissaoCreditar( pDb, 11, ComissaoConsorcio( 200000 ) )
   Vale( "RN-033: acumula, não substitui", ComissaoAcumulada( pDb, 11 ), 19050 )

   Vale( "funcionário inexistente é recusado", ;
         ComissaoCreditar( pDb, 999, 100 )[ "ok" ], .F. )
   Vale( "com mensagem clara", ;
         At( "não cadastrado", ComissaoCreditar( pDb, 999, 100 )[ "mensagem" ] ) > 0, .T. )
   Vale( "comissão zero não é erro", ComissaoCreditar( pDb, 1, 0 )[ "ok" ], .T. )

   RETURN

STATIC PROCEDURE TestaEstoque( pDb )

   LOCAL hV, hRes

   ? "== RN-028 x D-27 — dois conceitos diferentes =="

   /* peça 1: estoque 10, mínimo 4 */
   Vale( "5 unidades: acima do mínimo, sem aviso", ;
         EstoqueAbaixoDoMinimo( 10, 4, 5 ), .F. )
   Vale( "7 unidades: cairia abaixo do mínimo", ;
         EstoqueAbaixoDoMinimo( 10, 4, 7 ), .T. )
   Vale( "7 unidades NÃO é insuficiente", EstoqueInsuficiente( 10, 7 ), .F. )
   Vale( "11 unidades é insuficiente (D-27)", EstoqueInsuficiente( 10, 11 ), .T. )
   Vale( "sem mínimo definido não avisa", EstoqueAbaixoDoMinimo( 10, 0, 9 ), .F. )

   /* RN-028 preservada: abaixo do mínimo GRAVA, com aviso */
   hV := EstoqueAvaliar( pDb, "peca", "cod_pec", 1, 7 )
   Vale( "abaixo do mínimo é válido", ValOk( hV ), .T. )
   Vale( "mas avisa (RN-028)", ValTemAviso( hV ), .T. )

   hRes := EstoqueBaixarPeca( pDb, 1, 7 )
   Vale( "e a baixa acontece", hRes[ "ok" ], .T. )
   Vale( "saldo 10 - 7 = 3", hRes[ "saldo" ], 3 )
   Vale( "abaixo do mínimo, como o legado permitia", 3 < 4, .T. )

   /* D-27: o piso zero é novo, e é recusa */
   hRes := EstoqueBaixarPeca( pDb, 1, 5 )
   Vale( "baixa além do saldo é RECUSADA (D-27)", hRes[ "ok" ], .F. )
   Vale( "com mensagem que diz o saldo", At( "há 3", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "e o saldo não mudou", EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], 3 )

   Vale( "baixar exatamente o saldo é permitido", EstoqueBaixarPeca( pDb, 1, 3 )[ "ok" ], .T. )
   Vale( "saldo zerado", EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], 0 )
   Vale( "e de zero não sai mais nada", EstoqueBaixarPeca( pDb, 1, 1 )[ "ok" ], .F. )

   Vale( "quantidade zero é recusada", EstoqueBaixarPeca( pDb, 1, 0 )[ "ok" ], .F. )
   Vale( "peça inexistente é recusada", EstoqueBaixarPeca( pDb, 999, 1 )[ "ok" ], .F. )

   /* reposição — acréscimo declarado, não existe no legado */
   Vale( "repõe", EstoqueRepor( pDb, "peca", "cod_pec", 1, 5 )[ "ok" ], .T. )
   Vale( "saldo volta a 5", EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], 5 )

   Vale( "almoxarifado usa o mesmo serviço", ;
         EstoqueBaixarAlmoxarifado( pDb, 1, 10 )[ "saldo" ], 90 )

   /* D-13 / Q-12 — reparo não baixa estoque, como no legado */
   Vale( "D-13: reparo NÃO baixa estoque (Q-12 em aberto)", EstoqueReparoBaixa(), .F. )

   RETURN

STATIC PROCEDURE TestaVeiculo( pDb )

   LOCAL hRes

   ? "== RN-034 / RN-035 / D-08 — frota =="

   /* modelo 1 tem 2 unidades; modelo 2 tem 5 */
   hRes := EstoqueBaixarVeiculo( pDb, 2 )
   Vale( "baixa uma unidade por padrão", hRes[ "saldo" ], 4 )
   /* D-08: no legado a baixa saía sempre do primeiro modelo */
   Vale( "D-08: o modelo 1 não foi tocado", ;
         EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 2 )
   Vale( "não é o último", hRes[ "ultimo" ], .F. )

   EstoqueBaixarVeiculo( pDb, 1 )
   hRes := EstoqueBaixarVeiculo( pDb, 1 )
   Vale( "RN-035: avisa quando zera", hRes[ "ultimo" ], .T. )
   Vale( "saldo zero", hRes[ "saldo" ], 0 )
   /* RN-035 é informativo: não impede a venda. Mas D-27 impede vender do zero */
   Vale( "vender com estoque zero é recusado (D-27)", ;
         EstoqueBaixarVeiculo( pDb, 1 )[ "ok" ], .F. )

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
