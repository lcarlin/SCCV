/*
 * testa_graficos.prg — critério de aceite da FASE G, onda 8
 *
 * Gráficos R-11 e R-12: barras em caracteres e CSV, com o agregado vindo de
 * CONSULTA e não da tabela materializada (CR-08 / D-18).
 *
 * A parte mais importante deste teste não é o desenho da barra: é provar que o
 * número mostrado vem do movimento real e diverge do agregado do legado, que
 * estava dessincronizado em até 11.062 unidades.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-graficos.db", hC, pDb

   ? "FASE G onda 8 — aceite dos gráficos"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaAgregado( pDb )
   TestaBarras( pDb )
   TestaDivergencia( pDb )
   TestaCsv( pDb )
   TestaVazio( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "GRÁFICOS ACEITOS", "GRÁFICOS REPROVADOS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )

   LOCAL nId, i

   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
      " VALUES (?,?,?)", { 1, "Cliente", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 1, "Vendedor" } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 1, "UNO ELX", 100, 1500000 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 2, "TIPO 1.6 IE 2 PORTAS", 100, 3200000 } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque," + ;
      " valor_unit_cent) VALUES (?,?,?,?)", { 1, "MOLAS", 9999, 1000 } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque," + ;
      " valor_unit_cent) VALUES (?,?,?,?)", { 2, "PARAFUSO", 9999, 2000 } )

   /* 3 vendas do UNO, 1 do TIPO */
   FOR i := 1 TO 3
      SqlExecBind( pDb, "INSERT INTO venda_veiculo (cod_car, cod_cli, cod_fun," + ;
         " valor_cent, descricao_snapshot) VALUES (?,?,?,?,?)", ;
         { 1, 1, 1, 1500000, "UNO ELX" } )
   NEXT
   SqlExecBind( pDb, "INSERT INTO venda_veiculo (cod_car, cod_cli, cod_fun," + ;
      " valor_cent, descricao_snapshot) VALUES (?,?,?,?,?)", ;
      { 2, 1, 1, 3200000, "TIPO 1.6 IE 2 PORTAS" } )

   /* itens de peça: 10 molas, 4 parafusos */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "BALCAO", 18000 } )
   nId := SqlUltimoId( pDb )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 1, 10, 10000, "MOLAS", 1 } )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, descricao_snapshot, ordem) VALUES (?,?,?,?,?,?)", ;
      { nId, 2, 4, 8000, "PARAFUSO", 2 } )

   /*
    * A quarentena com os agregados do legado. O caso real: o agregado tinha
    * "TIPO 1.6 IE" enquanto o cadastro tinha "TIPO 1.6 IE 2 PORTAS" — a chave
    * TEXTUAL nunca casou, e 12 vendas fantasma ficaram acumuladas.
    */
   SqlExecBind( pDb, "INSERT INTO _legado_cvvcar (registro, descar, quantv)" + ;
      " VALUES (?,?,?)", { 1, "UNO ELX", "5" } )
   SqlExecBind( pDb, "INSERT INTO _legado_cvvcar (registro, descar, quantv)" + ;
      " VALUES (?,?,?)", { 2, "TIPO 1.6 IE", "12" } )
   SqlExecBind( pDb, "INSERT INTO _legado_cvvpec (registro, despec, quantc)" + ;
      " VALUES (?,?,?)", { 1, "MOLAS", "9999" } )
   RETURN

STATIC PROCEDURE TestaAgregado( pDb )

   LOCAL aD

   ? "== CR-08 / D-18 — o agregado vem de consulta =="

   aD := GraficoDados( pDb, GraficoDefinicao( "R-11" ) )
   Vale( "R-11 traz dois modelos", Len( aD ), 2 )
   /* ordenado por quantidade decrescente: UNO (3) antes de TIPO (1) */
   Vale( "maior volume primeiro", aD[ 1 ][ 1 ], "UNO ELX" )
   Vale( "UNO: 3 vendas REAIS", aD[ 1 ][ 2 ], 3 )
   Vale( "TIPO: 1 venda real", aD[ 2 ][ 2 ], 1 )
   /* o legado dizia 5 e 12 — números que nunca corresponderam ao movimento */
   Vale( "e NÃO os 5 que o agregado antigo dizia", aD[ 1 ][ 2 ] != 5, .T. )
   Vale( "valor total acompanha", aD[ 1 ][ 3 ], 4500000 )

   aD := GraficoDados( pDb, GraficoDefinicao( "R-12" ) )
   Vale( "R-12 traz duas peças", Len( aD ), 2 )
   Vale( "MOLAS: 10 unidades reais", aD[ 1 ][ 2 ], 10 )
   Vale( "PARAFUSO: 4", aD[ 2 ][ 2 ], 4 )

   RETURN

STATIC PROCEDURE TestaBarras( pDb )

   LOCAL hDef := GraficoDefinicao( "R-11" ), aL, cTudo := "", i

   ? "== barras em caracteres =="

   aL := GraficoBarras( hDef, GraficoDados( pDb, hDef ), 78 )
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT

   Vale( "traz a empresa", At( "Fralleti", cTudo ) > 0, .T. )
   Vale( "traz o título", At( "Venda de Veículos por Modelo", cTudo ) > 0, .T. )
   /* o legado dizia "Mensal" sem ter recorte temporal algum */
   Vale( "NÃO diz 'mensal' (não há recorte temporal)", At( "Mensal", cTudo ), 0 )
   Vale( "traz os rótulos", At( "UNO ELX", cTudo ) > 0, .T. )
   Vale( "desenha barras", At( "#", cTudo ) > 0, .T. )
   /* o maior item é destacado, como o nFatDes destacava a maior fatia */
   Vale( "destaca o maior com '#'", At( "###", cTudo ) > 0, .T. )
   Vale( "os demais usam '='", At( "===", cTudo ) > 0, .T. )
   Vale( "mostra percentual", At( "%", cTudo ) > 0, .T. )
   Vale( "totaliza", At( "TOTAL", cTudo ) > 0, .T. )
   Vale( "legenda explica os símbolos", At( "maior volume", cTudo ) > 0, .T. )

   /* nenhuma linha estoura a largura pedida */
   FOR i := 1 TO Len( aL )
      IF hb_ULen( aL[ i ] ) > 78
         Vale( "linha " + hb_ntos( i ) + " dentro da largura", hb_ULen( aL[ i ] ), 78 )
         RETURN
      ENDIF
   NEXT
   Vale( "nenhuma linha estoura a largura", .T., .T. )

   RETURN

STATIC PROCEDURE TestaDivergencia( pDb )

   LOCAL hDef := GraficoDefinicao( "R-11" ), aD, aDiv, aL, cTudo := "", i

   ? "== D-18 — a divergência é mostrada, não escondida =="

   aD   := GraficoDados( pDb, hDef )
   aDiv := GraficoDivergencia( pDb, hDef, aD )

   Vale( "há divergência com o agregado antigo", Len( aDiv ) > 0, .T. )
   Vale( "UNO: real 3", aDiv[ 1 ][ "real" ], 3 )
   Vale( "UNO: antigo 5", aDiv[ 1 ][ "legado" ], 5 )
   /* o caso da chave textual: "TIPO 1.6 IE" nunca casou com o nome completo */
   Vale( "TIPO não casa por nome no agregado antigo", aDiv[ 2 ][ "legado" ], NIL )

   aL := GraficoLinhasDivergencia( aDiv )
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   Vale( "explica ao operador", At( "sistema antigo", cTudo ) > 0, .T. )
   Vale( "mostra os dois números", At( "movimento real", cTudo ) > 0, .T. )
   Vale( "e diz que o antigo ficou dessincronizado", ;
         At( "dessincronizado", cTudo ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaCsv( pDb )

   LOCAL hDef := GraficoDefinicao( "R-12" ), cArq := hb_DirTemp() + "graf.csv", cTxt

   ? "== exportação CSV =="

   Vale( "exporta", GraficoCsv( hDef, GraficoDados( pDb, hDef ), cArq ), .T. )
   cTxt := hb_MemoRead( cArq )
   Vale( "tem cabeçalho", At( "descricao,quantidade,valor_total", cTxt ) > 0, .T. )
   Vale( "traz os dados", At( '"MOLAS",10', cTxt ) > 0, .T. )
   Vale( "com o valor", At( "100.00", cTxt ) > 0, .T. )

   /* descrição com vírgula não pode quebrar o CSV */
   SqlExecBind( pDb, "UPDATE peca SET descricao = ? WHERE cod_pec = 2", ;
      { 'PARAFUSO, SEXTAVADO 8"' } )
   GraficoCsv( hDef, GraficoDados( pDb, hDef ), cArq )
   cTxt := hb_MemoRead( cArq )
   Vale( "vírgula na descrição é escapada", ;
         At( '"PARAFUSO, SEXTAVADO 8""",4', cTxt ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaVazio( pDb )

   LOCAL hDef := GraficoDefinicao( "R-11" ), aL, cTudo := "", i

   ? "== arquivo vazio (gip_erro do legado) =="

   SqlExec( pDb, "DELETE FROM venda_veiculo" )
   aL := GraficoBarras( hDef, GraficoDados( pDb, hDef ), 78 )
   FOR i := 1 TO Len( aL )
      cTudo += aL[ i ] + hb_eol()
   NEXT
   Vale( "não quebra sem dados", Len( aL ) > 0, .T. )
   Vale( "explica ao operador", At( "Não há vendas registradas", cTudo ) > 0, .T. )

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
