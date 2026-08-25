/*
 * testa_relatorios.prg — critério de aceite da FASE G, onda 7
 *
 * Os dez relatórios R-01 a R-10, e as correções de 06 §6.
 *
 * A geração de linhas foi separada do desenho justamente para isto: dá para
 * verificar conteúdo, colunas, filtros e totais dos dez relatórios sem abrir
 * terminal nenhum.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-relatorios.db", hC, pDb

   ? "FASE G onda 7 — aceite dos relatórios"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaCatalogo( pDb )
   TestaCabecalho( pDb )
   TestaFiltroClientes( pDb )
   TestaCorrecoes( pDb )
   TestaTotais( pDb )
   TestaArquivo( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "RELATÓRIOS ACEITOS", "RELATÓRIOS REPROVADOS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )

   LOCAL nId

   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, telefone, cidade," + ;
      " consorcio, data_cadastro) VALUES (?,?,?,?,?,?)", ;
      { 1, "OSWALDO COELHO", "01430512382", "PIRAJU", "S", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, telefone, cidade," + ;
      " consorcio, data_cadastro) VALUES (?,?,?,?,?,?)", ;
      { 2, "BART SIMPSON", "01430512383", "SPRINGFIELD", "N", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome, salario_cent)" + ;
      " VALUES (?,?,?)", { 1, "ALETHEIA KARINA", 20000 } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome, salario_cent)" + ;
      " VALUES (?,?,?)", { 2, "MARINARA", 30000 } )
   SqlExecBind( pDb, "INSERT INTO fornecedor (cod_for, nome, desc_item, fabrica)" + ;
      " VALUES (?,?,?,?)", { 1, "Fiat", "MOLAS", "FIAT AUTOMOVEIS" } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque," + ;
      " qtd_minima, valor_unit_cent, cod_for) VALUES (?,?,?,?,?,?)", ;
      { 1, "MOLAS", 9939, 10, 1000, 1 } )
   SqlExecBind( pDb, "INSERT INTO almoxarifado (cod_alm, descricao, qtd_estoque," + ;
      " valor_unit_cent, cod_for) VALUES (?,?,?,?,?)", { 1, "CAFE", 100, 500, 1 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent, data_compra) VALUES (?,?,?,?,?)", ;
      { 1, "UNO ELX", 89, 1500000, "1994-06-30" } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent, data_compra) VALUES (?,?,?,?,?)", ;
      { 2, "TEMPRA 16 VALVULAS", 99, 3500000, "1994-06-30" } )

   /* uma venda de BALCÃO com dois itens */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "BALCAO", 3000 } )
   nId := SqlUltimoId( pDb )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 1, 2, 2000, "MOLAS", 1 } )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 1, 1, 1000, "MOLAS", 2 } )

   /* uma venda de REPARO */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 2, "REPARO", 5000 } )
   nId := SqlUltimoId( pDb )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 1, 5, 5000, "MOLAS", 1 } )

   /* uma venda MIGRADA, origem indeterminada */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "INDETERMINADO", 9900 } )
   nId := SqlUltimoId( pDb )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 1, 9, 9900, "MOLAS", 1 } )

   SqlExecBind( pDb, "INSERT INTO venda_veiculo (cod_car, cod_cli, cod_fun," + ;
      " data_venda, valor_cent, descricao_snapshot) VALUES (?,?,?,?,?,?)", ;
      { 1, 1, 1, "1994-06-30", 1500000, "UNO ELX" } )

   /* cotas: uma de grupo fechado, outra em formação */
   SqlExecBind( pDb, "INSERT INTO consorcio_cota (cod_gru, num_participante," + ;
      " cod_cli, cod_car, valor_prestacao_cent, num_participantes_previsto," + ;
      " parcelas_restantes, data_adesao, grupo_fechado, sorteado, quitado)" + ;
      " VALUES (?,?,?,?,?,?,?,?,1,0,0)", { 1, 1, 1, 1, 200000, 3, 3, "1994-06-30" } )
   SqlExecBind( pDb, "INSERT INTO consorcio_cota (cod_gru, num_participante," + ;
      " cod_cli, cod_car, valor_prestacao_cent, num_participantes_previsto," + ;
      " parcelas_restantes, data_adesao, grupo_fechado, sorteado, quitado)" + ;
      " VALUES (?,?,?,?,?,?,?,?,0,0,0)", { 2, 1, 2, 1, 200000, 5, 5, "1994-07-01" } )
   RETURN

STATIC PROCEDURE TestaCatalogo( pDb )

   LOCAL aCat := RelatorioCatalogo(), i, hDef, aL

   ? "== os dez relatórios geram saída =="

   Vale( "dez relatórios no catálogo", Len( aCat ), 10 )

   FOR i := 1 TO Len( aCat )
      hDef := RelatorioDefinicao( aCat[ i ][ 1 ] )
      IF hDef == NIL
         Vale( aCat[ i ][ 1 ] + " tem definição", .F., .T. )
         LOOP
      ENDIF
      aL := RelatorioLinhas( pDb, hDef )
      Vale( aCat[ i ][ 1 ] + " " + PadR( aCat[ i ][ 2 ], 18 ) + " gera linhas", ;
            Len( aL ) > 8, .T. )
   NEXT

   RETURN

STATIC PROCEDURE TestaCabecalho( pDb )

   LOCAL aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-01" ) ), cTudo := "", i

   ? "== cabeçalho preservado (06 §3.2) =="

   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT

   Vale( "traz a data de emissão", At( "Emissão:", cTudo ) > 0, .T. )
   Vale( "traz o número de página", At( "Página No.", cTudo ) > 0, .T. )
   Vale( "traz o nome da empresa", At( "FIAT  -  Fralleti Ltda.", cTudo ) > 0, .T. )
   Vale( "traz o nome do sistema", At( "S.C.C.V.", cTudo ) > 0, .T. )
   Vale( "traz o título do relatório", At( "RELATÓRIO DE CLIENTES", cTudo ) > 0, .T. )
   /* CR-05 — no legado a primeira página da frota saía SEM cabeçalho */
   aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-06" ) )
   Vale( "CR-05: a frota também tem cabeçalho na 1ª página", ;
         At( "FIAT", aL[ 3 ] ) > 0, .T. )

   RETURN

/* RN-040 — o único relatório com filtro. */
STATIC PROCEDURE TestaFiltroClientes( pDb )

   LOCAL hDef := RelatorioDefinicao( "R-01" ), aD

   ? "== RN-040 — filtro de clientes =="

   aD := RelatorioDados( pDb, hDef, { "filtro" => "ambos" } )
   Vale( "ambos: 2 clientes", Len( aD ), 2 )
   aD := RelatorioDados( pDb, hDef, { "filtro" => "consorciados" } )
   Vale( "só consorciados: 1", Len( aD ), 1 )
   Vale( "e é o cliente 1", aD[ 1 ][ 1 ], 1 )
   aD := RelatorioDados( pDb, hDef, { "filtro" => "clientes" } )
   Vale( "só não-consorciados: 1", Len( aD ), 1 )
   Vale( "e é o cliente 2", aD[ 1 ][ 1 ], 2 )
   Vale( "o rótulo do filtro aparece no cabeçalho", ;
         At( "somente consorciados", ;
             RelatorioLinhas( pDb, hDef, { "filtro" => "consorciados" } )[ 6 ] ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaCorrecoes( pDb )

   LOCAL hDef, aD, aL, i, cTudo := ""

   ? "== correções de 06 §6 =="

   /* CR-04 — relatório de estoque que mostra estoque */
   hDef := RelatorioDefinicao( "R-04" )
   Vale( "CR-04: peças tem 5 colunas (com estoque e mínimo)", ;
         Len( hDef[ "colunas" ] ), 5 )
   aD := RelatorioDados( pDb, hDef )
   Vale( "CR-04: quantidade vem no dado", aD[ 1 ][ 3 ], 9939 )
   Vale( "CR-04: mínimo vem no dado", aD[ 1 ][ 4 ], 10 )

   /* CR-03 — R-07 e R-08 deixam de listar os mesmos registros */
   aD := RelatorioDados( pDb, RelatorioDefinicao( "R-07" ) )
   Vale( "CR-03: R-07 traz só o balcão (2 itens)", Len( aD ), 2 )
   aD := RelatorioDados( pDb, RelatorioDefinicao( "R-08" ) )
   Vale( "CR-03: R-08 traz só o reparo (1 item)", Len( aD ), 1 )
   Vale( "CR-03: e são registros diferentes", aD[ 1 ][ 2 ], 2 )

   /* as vendas migradas não entram em nenhum dos dois */
   Vale( "vendas INDETERMINADO ficam fora de R-07", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-07" ) ) ), 2 )

   /* CR-02 — subtotal por linha, e nenhuma linha com zero */
   aD := RelatorioDados( pDb, RelatorioDefinicao( "R-07" ) )
   Vale( "CR-02: 1ª linha tem subtotal", aD[ 1 ][ 4 ], 2000 )
   Vale( "CR-02: 2ª linha tem subtotal", aD[ 2 ][ 4 ], 1000 )
   Vale( "CR-02: nenhuma linha com valor zero", ;
         AScan( aD, {| x | x[ 4 ] == 0 } ), 0 )

   /* CR-01 — R-09 mapeado para os campos reais; no legado nem executava */
   hDef := RelatorioDefinicao( "R-09" )
   aD := RelatorioDados( pDb, hDef )
   Vale( "CR-01: R-09 executa", Len( aD ), 1 )
   Vale( "CR-01: traz o cliente", aD[ 1 ][ 1 ], 1 )
   Vale( "CR-01: traz o grupo", aD[ 1 ][ 2 ], 1 )
   Vale( "CR-01: traz a prestação", aD[ 1 ][ 7 ], 200000 )
   /* como no legado, só grupos fechados */
   Vale( "só grupos fechados, como o legado", Len( aD ), 1 )

   /* CR-07 — colunas não se sobrepõem */
   aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-10" ) )
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   Vale( "CR-07: descrição longa não invade a coluna do valor", ;
         At( "TEMPRA 16 VALVULAS15", cTudo ), 0 )
   Vale( "R-10 mostra a descrição", At( "UNO ELX", cTudo ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaTotais( pDb )

   LOCAL aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-07" ) ), cTudo := "", i

   ? "== CR-02 — totalização, que o legado não tinha =="

   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   /* 2000 + 1000 = 3000 centavos = 30,00 */
   Vale( "R-07 totaliza os subtotais", At( "TOTAL SUBTOTAL: 30,00", cTudo ) > 0, .T. )
   Vale( "e informa a contagem", At( "2 registro(s)", cTudo ) > 0, .T. )

   aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-02" ) )
   cTudo := ""
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   /* 200,00 + 300,00 = 500,00 */
   Vale( "R-02 totaliza salários", At( "TOTAL SALÁRIO: 500,00", cTudo ) > 0, .T. )

   /* relatório sem dados não quebra */
   SqlExec( pDb, "DELETE FROM venda_peca WHERE origem = 'REPARO'" )
   aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-08" ) )
   cTudo := ""
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   Vale( "relatório vazio se explica", At( "(nenhum registro)", cTudo ) > 0, .T. )
   Vale( "e conta zero", At( "0 registro(s)", cTudo ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaArquivo( pDb )

   LOCAL cArq := hb_DirTemp() + "rel-teste.txt", aL, cTxt

   ? "== destino arquivo (06 §7) =="

   aL := RelatorioLinhas( pDb, RelatorioDefinicao( "R-01" ) )
   Vale( "grava", RelatorioGravar( aL, cArq, 60 ), .T. )
   cTxt := hb_MemoRead( cArq )
   Vale( "arquivo tem conteúdo", Len( cTxt ) > 100, .T. )
   Vale( "e é UTF-8 legível", At( "RELATÓRIO DE CLIENTES", cTxt ) > 0, .T. )
   Vale( "sem códigos de escape de impressora", At( Chr( 27 ), cTxt ), 0 )

   /* quebra de página por \f, e não por código proprietário */
   Vale( "quebra de página curta insere \f", ;
         At( Chr( 12 ), hb_MemoRead( ArquivoCurto( aL, cArq ) ) ) > 0, .T. )

   RETURN

STATIC FUNCTION ArquivoCurto( aL, cArq )
   RelatorioGravar( aL, cArq, 5 )
   RETURN cArq

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
