/*
 * grafico.prg — FASE G, onda 8
 *
 * Gráficos R-11 (vendas de veículos) e R-12 (vendas de peças).
 *
 * POR QUE BARRAS EM CARACTERES, E NÃO PIZZA
 * -----------------------------------------
 * O legado desenhava pizza com as bibliotecas CLBC 2.7 e GIP 1.0, mais a fonte
 * `8X8.BCM`. Nenhuma delas existe no acervo — só os executáveis `BCVGA.EXE` e
 * `BCRETCTR.EXE`, que não são fonte. Reproduzir a pizza exigiria escolher uma
 * biblioteca gráfica nova e uma janela gráfica, para um sistema de terminal.
 * O plano prevê barras em caracteres e exportação CSV: a informação funcional
 * — a distribuição das vendas por item — é preservada; a representação visual,
 * que era limitação da época, não é.
 *
 * CR-08 / D-18 — O AGREGADO VEM DE CONSULTA, NÃO DE TABELA MATERIALIZADA
 * ---------------------------------------------------------------------
 * Os gráficos do legado liam `CVVCAR` e `CVVPEC`, tabelas mantidas
 * incrementalmente pelos módulos de venda e com chave TEXTUAL (a descrição de
 * 35 caracteres). Elas estão dessincronizadas dos dados transacionais em até
 * 11.062 unidades: `TIPO 1.6 IE` no agregado nunca casou com
 * `TIPO 1.6 IE 2 PORTAS` no cadastro, e acumulou 12 vendas fantasma.
 *
 * Aqui o agregado é calculado das views `v_venda_por_modelo` e
 * `v_venda_por_peca`. Os números são DIFERENTES dos que o legado mostrava — e
 * são os certos. Os valores antigos seguem preservados na quarentena.
 *
 * O TÍTULO NÃO DIZ MAIS "MENSAL"
 * ------------------------------
 * Os gráficos do legado se chamavam "Venda Mensal", mas não há recorte temporal
 * algum: `CVPECAS` não tem campo de data, e as agregadas acumulavam desde
 * sempre. Chamar de mensal um acumulado histórico é afirmar algo falso na tela.
 * O título foi corrigido; o recorte por período está registrado como lacuna em
 * Q-11 e não foi criado aqui.
 */

#include "fileio.ch"

FUNCTION GraficoCatalogo()
   RETURN { ;
      { "R-11", "Vendas de veículos por modelo" }, ;
      { "R-12", "Vendas de peças por item"      } }

FUNCTION GraficoDefinicao( cId )

   DO CASE
   CASE cId == "R-11"
      RETURN { "id" => "R-11", ;
               "titulo" => "Venda de Veículos por Modelo", ;
               "subtitulo" => "FIAT - Fralleti Ltda. — Piraju/SP", ;
               "sql" => "SELECT descricao, quantidade, valor_total_cent" + ;
                        " FROM v_venda_por_modelo ORDER BY quantidade DESC, descricao", ;
               "quarentena" => "_legado_cvvcar", ;
               "col_desc" => "descar", "col_qtd" => "quantv" }
   CASE cId == "R-12"
      RETURN { "id" => "R-12", ;
               "titulo" => "Venda de Peças por Item", ;
               "subtitulo" => "FIAT - Fralleti Ltda. — Piraju/SP", ;
               "sql" => "SELECT descricao, quantidade, valor_total_cent" + ;
                        " FROM v_venda_por_peca ORDER BY quantidade DESC, descricao", ;
               "quarentena" => "_legado_cvvpec", ;
               "col_desc" => "despec", "col_qtd" => "quantc" }
   ENDCASE

   RETURN NIL

FUNCTION GraficoDados( pDb, hDef )
   RETURN SqlLinhasBind( pDb, hDef[ "sql" ], {} )

/*
 * Gráfico de barras em caracteres. Devolve array de linhas — testável sem tela,
 * como os relatórios.
 *
 * A fatia de maior valor é destacada, como o `nFatDes` do legado destacava a
 * maior fatia da pizza.
 */
FUNCTION GraficoBarras( hDef, aDados, nLargura )

   LOCAL aLinhas := {}, i, nMax := 0, nTotal := 0, nBarra, cRotulo, nQtd
   LOCAL nLargRot := 28, nLargBarra

   hb_default( @nLargura, 80 )
   /* rótulo(28) + espaço + barra + espaço + quantidade(6) + percentual(7) */
   nLargBarra := nLargura - nLargRot - 15

   AAdd( aLinhas, hb_UPadC( hDef[ "subtitulo" ], nLargura ) )
   AAdd( aLinhas, hb_UPadC( hDef[ "titulo" ], nLargura ) )
   AAdd( aLinhas, Replicate( "=", nLargura ) )
   AAdd( aLinhas, "" )

   /* "Arquivo vazio" era gip_erro(1) no legado — a mensagem é preservada */
   IF Len( aDados ) == 0
      AAdd( aLinhas, "   Não há vendas registradas para este gráfico." )
      RETURN aLinhas
   ENDIF

   FOR i := 1 TO Len( aDados )
      nQtd := iif( aDados[ i ][ 2 ] == NIL, 0, aDados[ i ][ 2 ] )
      nMax := Max( nMax, nQtd )
      nTotal += nQtd
   NEXT
   IF nMax == 0
      nMax := 1
   ENDIF

   FOR i := 1 TO Len( aDados )
      cRotulo := iif( aDados[ i ][ 1 ] == NIL, "(sem descrição)", aDados[ i ][ 1 ] )
      nQtd    := iif( aDados[ i ][ 2 ] == NIL, 0, aDados[ i ][ 2 ] )
      nBarra  := Int( nQtd * nLargBarra / nMax )
      AAdd( aLinhas, ;
         hb_UPadR( hb_ULeft( cRotulo, nLargRot ), nLargRot ) + " " + ;
         Replicate( iif( nQtd == nMax, "#", "=" ), nBarra ) + ;
         Space( Max( 0, nLargBarra - nBarra ) ) + " " + ;
         hb_UPadL( hb_ntos( nQtd ), 6 ) + ;
         hb_UPadL( GraficoPercentual( nQtd, nTotal ), 7 ) )
   NEXT

   AAdd( aLinhas, "" )
   AAdd( aLinhas, hb_UPadR( "TOTAL", nLargRot ) + " " + ;
         Space( nLargBarra ) + " " + hb_UPadL( hb_ntos( nTotal ), 6 ) )
   AAdd( aLinhas, "" )
   AAdd( aLinhas, "  #  item de maior volume    =  demais itens" )

   RETURN aLinhas

STATIC FUNCTION GraficoPercentual( nQtd, nTotal )

   IF nTotal == 0
      RETURN "0,0%"
   ENDIF

   RETURN AllTrim( Transform( nQtd * 100 / nTotal, "@E 999.9" ) ) + "%"

/*
 * Exportação CSV, prevista no plano para a onda 8.
 *
 * Aspas conforme RFC 4180, como no relatório de inconsistências: as descrições
 * do acervo contêm vírgula e a exportação precisa sobreviver a isso.
 */
FUNCTION GraficoCsv( hDef, aDados, cArquivo )

   LOCAL hF, cTxt := "", i, nQtd, nVal

   cTxt += "descricao,quantidade,valor_total" + hb_eol()
   FOR i := 1 TO Len( aDados )
      nQtd := iif( aDados[ i ][ 2 ] == NIL, 0, aDados[ i ][ 2 ] )
      nVal := iif( Len( aDados[ i ] ) < 3 .OR. aDados[ i ][ 3 ] == NIL, 0, aDados[ i ][ 3 ] )
      cTxt += GraficoCsvCampo( aDados[ i ][ 1 ] ) + "," + ;
              hb_ntos( nQtd ) + "," + GraficoCsvValor( nVal ) + hb_eol()
   NEXT

   hF := hb_vfOpen( cArquivo, FO_CREAT + FO_TRUNC + FO_WRITE )
   IF hF == NIL
      RETURN .F.
   ENDIF
   hb_vfWrite( hF, cTxt )
   hb_vfClose( hF )

   RETURN .T.

/*
 * Valor monetário no CSV usa PONTO como separador decimal, não a vírgula do
 * formato brasileiro — porque a vírgula é o separador de CAMPO do arquivo, e
 * "100,00" partiria a linha em duas colunas. Quem abre a planilha ajusta a
 * localidade na importação; um CSV quebrado não tem conserto.
 *
 * A divisão é textual, em centavos, pelo mesmo motivo de sempre: ponto
 * flutuante não representa 0,01 exatamente.
 */
STATIC FUNCTION GraficoCsvValor( nCent )

   LOCAL nInt, nDec

   IF nCent == NIL
      RETURN "0.00"
   ENDIF
   nInt := Int( nCent / 100 )
   nDec := Int( nCent - nInt * 100 )

   RETURN hb_ntos( nInt ) + "." + PadL( hb_ntos( nDec ), 2, "0" )

STATIC FUNCTION GraficoCsvCampo( cValor )
   IF cValor == NIL
      RETURN ""
   ENDIF
   RETURN '"' + StrTran( cValor, '"', '""' ) + '"'

/*
 * Compara o agregado calculado com o que o legado tinha materializado.
 *
 * Existe porque D-18 previu que os números MUDARIAM, e uma mudança de número
 * sem explicação é indistinguível de um erro. Isto dá ao operador a conta:
 * o que o sistema antigo dizia, o que o movimento real diz, e a diferença.
 */
FUNCTION GraficoDivergencia( pDb, hDef, aDados )

   LOCAL aRes := {}, i, aL, nLeg, cDesc, nQtd

   FOR i := 1 TO Len( aDados )
      cDesc := iif( aDados[ i ][ 1 ] == NIL, "", aDados[ i ][ 1 ] )
      nQtd  := iif( aDados[ i ][ 2 ] == NIL, 0, aDados[ i ][ 2 ] )
      aL := SqlLinhasBind( pDb, "SELECT " + hDef[ "col_qtd" ] + " FROM " + ;
         hDef[ "quarentena" ] + " WHERE TRIM(" + hDef[ "col_desc" ] + ") = ?", ;
         { cDesc } )
      nLeg := iif( Len( aL ) == 0 .OR. aL[ 1 ][ 1 ] == NIL, NIL, ;
                   Val( hb_ValToStr( aL[ 1 ][ 1 ] ) ) )
      IF nLeg == NIL .OR. nLeg != nQtd
         AAdd( aRes, { "descricao" => cDesc, "real" => nQtd, "legado" => nLeg } )
      ENDIF
   NEXT

   RETURN aRes

FUNCTION GraficoLinhasDivergencia( aDiv )

   LOCAL aLinhas := {}, i, h

   IF Len( aDiv ) == 0
      RETURN aLinhas
   ENDIF

   AAdd( aLinhas, "" )
   AAdd( aLinhas, "Divergências em relação ao agregado do sistema antigo (D-18):" )
   FOR i := 1 TO Len( aDiv )
      h := aDiv[ i ]
      AAdd( aLinhas, "  " + hb_UPadR( hb_ULeft( h[ "descricao" ], 30 ), 31 ) + ;
            " movimento real: " + hb_UPadL( hb_ntos( h[ "real" ] ), 6 ) + ;
            "   antigo: " + iif( h[ "legado" ] == NIL, "(ausente)", ;
                                 hb_ntos( h[ "legado" ] ) ) )
   NEXT
   AAdd( aLinhas, "  O agregado antigo era mantido à parte e ficou dessincronizado." )

   RETURN aLinhas
