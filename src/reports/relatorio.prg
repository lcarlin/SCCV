/*
 * relatorio.prg — FASE G, onda 7
 *
 * Motor de relatórios. Cabeçalho, colunas, totais, paginação e destino.
 * Especificação: docs/06-RELATORIOS.md §6 e §7.
 *
 * O QUE SE PRESERVA E O QUE SE DESCARTA (briefing §19)
 * ---------------------------------------------------
 * Preserva: o conjunto de colunas de cada relatório, a ordenação por código, o
 * filtro de clientes por tipo (RN-040), os títulos "FIAT - Fralleti Ltda." e
 * "S.C.C.V.", a data de emissão e o número de página.
 *
 * Descarta: códigos ESC/P, larguras fixas de impressora matricial, paginação de
 * 21/60 linhas cravada e o `ISPRINTER()` bloqueante. São limitações físicas de
 * 1994, não informação funcional.
 *
 * A GERAÇÃO DAS LINHAS É SEPARADA DO DESENHO. RelatorioLinhas() devolve texto e
 * não toca na tela — é o que permite testar os dez relatórios sem terminal, e
 * é também o que faz o mesmo relatório servir tela, arquivo e impressora sem
 * três implementações.
 */

#include "fileio.ch"
#include "inkey.ch"

#define LARGURA_PADRAO   80

/*
 * Uma coluna: { titulo, largura, alinhamento, formato }
 *   alinhamento: "E" (esquerda, padrão) ou "D" (direita)
 *   formato:     "T" texto · "N" número · "$" centavos · "D" data ISO
 */
FUNCTION RelColuna( cTitulo, nLargura, cAlinhamento, cFormato )
   RETURN { "titulo" => cTitulo, "largura" => nLargura, ;
            "alinhamento" => iif( cAlinhamento == NIL, "E", cAlinhamento ), ;
            "formato" => iif( cFormato == NIL, "T", cFormato ) }

/*
 * Gera o relatório inteiro como array de linhas de texto.
 *
 * hDef: definição do relatório (ver definicoes.prg)
 * hOpc: { "filtro" => <chave de filtro>, "largura" => 80 }
 */
FUNCTION RelatorioLinhas( pDb, hDef, hOpc )

   LOCAL aLinhas := {}, aDados, i, nLargura, aTotais

   hb_default( @hOpc, { => } )
   nLargura := iif( "largura" $ hOpc, hOpc[ "largura" ], LARGURA_PADRAO )

   aDados := RelatorioDados( pDb, hDef, hOpc )

   RelatorioCabecalho( aLinhas, hDef, nLargura, hOpc )
   AAdd( aLinhas, RelatorioLinhaColunas( hDef[ "colunas" ] ) )
   AAdd( aLinhas, Replicate( "-", nLargura ) )

   FOR i := 1 TO Len( aDados )
      AAdd( aLinhas, RelatorioLinhaDados( hDef[ "colunas" ], aDados[ i ] ) )
   NEXT

   IF Len( aDados ) == 0
      AAdd( aLinhas, "" )
      AAdd( aLinhas, "   (nenhum registro)" )
   ENDIF

   /*
    * CR-02 — o legado não totalizava NADA, em relatório nenhum. No R-07 isso
    * era especialmente ruim: ele mostrava VALTOT, que só existe na última linha
    * de cada compra, então 37% das linhas apareciam com zero e não havia total
    * para conferir. Aqui o total é a soma da coluna, calculada.
    */
   aTotais := RelatorioTotais( hDef, aDados )
   IF Len( aTotais ) > 0
      AAdd( aLinhas, Replicate( "-", nLargura ) )
      FOR i := 1 TO Len( aTotais )
         AAdd( aLinhas, aTotais[ i ] )
      NEXT
   ENDIF

   AAdd( aLinhas, "" )
   AAdd( aLinhas, hb_ntos( Len( aDados ) ) + " registro(s)" )

   RETURN aLinhas

FUNCTION RelatorioDados( pDb, hDef, hOpc )

   LOCAL cSql := hDef[ "sql" ], aParams := {}, cFiltro

   hb_default( @hOpc, { => } )

   IF "filtros" $ hDef .AND. "filtro" $ hOpc .AND. hOpc[ "filtro" ] != NIL
      cFiltro := hOpc[ "filtro" ]
      IF cFiltro $ hDef[ "filtros" ]
         cSql += " " + hDef[ "filtros" ][ cFiltro ]
      ENDIF
   ENDIF
   IF "ordem" $ hDef
      cSql += " ORDER BY " + hDef[ "ordem" ]
   ENDIF

   RETURN SqlLinhasBind( pDb, cSql, aParams )

/*
 * CABER() do legado, sem os códigos de impressora: emissão, página, empresa e
 * título. CR-05 — no legado a PRIMEIRA página do relatório de frota saía sem
 * cabeçalho, porque o bloco inicial chamava só RG() e esquecia CABER(). Aqui o
 * cabeçalho é parte da geração, não de um caminho especial.
 */
STATIC PROCEDURE RelatorioCabecalho( aLinhas, hDef, nLargura, hOpc )

   LOCAL cSub := ""

   AAdd( aLinhas, hb_UPadR( "Emissão: " + hb_DToC( Date(), "DD/MM/YYYY" ), nLargura - 16 ) + ;
         "Página No. 1" )
   AAdd( aLinhas, Replicate( "=", nLargura ) )
   AAdd( aLinhas, hb_UPadC( "FIAT  -  Fralleti Ltda.", nLargura ) )
   AAdd( aLinhas, hb_UPadC( "S.C.C.V.  -  Sistema de Controle de Concessionária de Veículos", nLargura ) )
   AAdd( aLinhas, hb_UPadC( "RELATÓRIO DE " + Upper( hDef[ "titulo" ] ), nLargura ) )

   IF "filtro" $ hOpc .AND. hOpc[ "filtro" ] != NIL .AND. "rotulos" $ hDef
      IF hOpc[ "filtro" ] $ hDef[ "rotulos" ]
         cSub := hDef[ "rotulos" ][ hOpc[ "filtro" ] ]
      ENDIF
   ENDIF
   IF !Empty( cSub )
      AAdd( aLinhas, hb_UPadC( cSub, nLargura ) )
   ENDIF

   AAdd( aLinhas, Replicate( "=", nLargura ) )
   AAdd( aLinhas, "" )

   RETURN

/* CR-07 — as colunas são posicionadas por largura acumulada, não por coluna
   fixa. No legado, campos C(35) invadiam a coluna seguinte em três relatórios. */
STATIC FUNCTION RelatorioLinhaColunas( aCols )

   LOCAL cLin := "", i

   FOR i := 1 TO Len( aCols )
      cLin += RelatorioCelula( aCols[ i ][ "titulo" ], aCols[ i ][ "largura" ], ;
                               aCols[ i ][ "alinhamento" ], "T" ) + " "
   NEXT

   RETURN RTrim( cLin )

STATIC FUNCTION RelatorioLinhaDados( aCols, aLinha )

   LOCAL cLin := "", i, xVal

   FOR i := 1 TO Len( aCols )
      xVal := iif( i > Len( aLinha ), NIL, aLinha[ i ] )
      cLin += RelatorioCelula( xVal, aCols[ i ][ "largura" ], ;
                               aCols[ i ][ "alinhamento" ], aCols[ i ][ "formato" ] ) + " "
   NEXT

   RETURN RTrim( cLin )

/*
 * Left(), PadL() e PadR() contam BYTES, não caracteres. Em UTF-8 "Ó" ocupa dois
 * bytes, então `Left( "CÓDIGO", 6 )` devolve "CÓDIG" — a coluna sai cortada, e
 * o preenchimento erra a largura na mesma medida, desalinhando tudo o que vier
 * depois. Num relatório em português isso atinge quase todo cabeçalho.
 *
 * hb_ULeft(), hb_UPadL() e hb_UPadR() contam caracteres.
 */
STATIC FUNCTION RelatorioCelula( xVal, nLarg, cAlin, cFmt )

   LOCAL cTxt

   DO CASE
   CASE xVal == NIL             ; cTxt := ""
   CASE cFmt == "$"             ; cTxt := AllTrim( BrowseMoeda( xVal ) )
   CASE ValType( xVal ) == "N"  ; cTxt := hb_ntos( xVal )
   OTHERWISE                    ; cTxt := hb_ValToStr( xVal )
   ENDCASE

   cTxt := hb_ULeft( cTxt, nLarg )

   RETURN iif( cAlin == "D", hb_UPadL( cTxt, nLarg ), hb_UPadR( cTxt, nLarg ) )

/* Totais das colunas marcadas em hDef["totalizar"] = { índice, ... }. */
STATIC FUNCTION RelatorioTotais( hDef, aDados )

   LOCAL aRes := {}, i, j, nCol, nSoma, aCols, cLin

   IF !( "totalizar" $ hDef ) .OR. Len( hDef[ "totalizar" ] ) == 0
      RETURN aRes
   ENDIF
   aCols := hDef[ "colunas" ]

   FOR i := 1 TO Len( hDef[ "totalizar" ] )
      nCol := hDef[ "totalizar" ][ i ]
      nSoma := 0
      FOR j := 1 TO Len( aDados )
         IF nCol <= Len( aDados[ j ] ) .AND. aDados[ j ][ nCol ] != NIL
            nSoma += aDados[ j ][ nCol ]
         ENDIF
      NEXT
      cLin := "TOTAL " + AllTrim( aCols[ nCol ][ "titulo" ] ) + ": " + ;
              iif( aCols[ nCol ][ "formato" ] == "$", AllTrim( BrowseMoeda( nSoma ) ), ;
                   hb_ntos( nSoma ) )
      AAdd( aRes, cLin )
   NEXT

   RETURN aRes

/* ------------------------------------------------------------------ */
/* Destinos                                                            */
/* ------------------------------------------------------------------ */

/*
 * Arquivo de texto UTF-8, com quebra de página por \f a cada nAltura linhas.
 * Sem códigos de escape proprietários: o arquivo é convertível por enscript ou
 * paps, e imprimível por lp — que é o caminho do §7 para impressão em Linux.
 */
FUNCTION RelatorioGravar( aLinhas, cArquivo, nAltura )

   LOCAL hF, cTxt := "", i, nNaPagina := 0

   hb_default( @nAltura, 60 )

   FOR i := 1 TO Len( aLinhas )
      cTxt += aLinhas[ i ] + hb_eol()
      nNaPagina++
      IF nNaPagina >= nAltura .AND. i < Len( aLinhas )
         cTxt += Chr( 12 )
         nNaPagina := 0
      ENDIF
   NEXT

   hF := hb_vfOpen( cArquivo, FO_CREAT + FO_TRUNC + FO_WRITE )
   IF hF == NIL
      RETURN .F.
   ENDIF
   hb_vfWrite( hF, cTxt )
   hb_vfClose( hF )

   RETURN .T.

/*
 * Tela, com paginação pela altura REAL do terminal (§7) em vez das 21 linhas
 * cravadas do legado.
 *
 * CR-06 — no legado o teste de quebra do relatório de fornecedores era
 * `IF NL = 18`, mas NL só assumia 23 ou 60: a pausa nunca acontecia e as linhas
 * rolavam sem parar.
 * CR-09 — a quebra limpa a tela antes de continuar; sem isso as páginas se
 * sobrepunham visualmente.
 */
PROCEDURE RelatorioTela( aLinhas )

   LOCAL i, nAltura := MaxRow() - 2, nNaPagina := 0

   TelaIniciar()
   CLS
   FOR i := 1 TO Len( aLinhas )
      hb_DispOutAt( nNaPagina, 0, Left( aLinhas[ i ], MaxCol() + 1 ) )
      nNaPagina++
      IF nNaPagina >= nAltura .AND. i < Len( aLinhas )
         Aviso( "Página cheia — pressione uma tecla (ESC interrompe)" )
         IF Inkey( 0 ) == K_ESC
            EXIT
         ENDIF
         CLS
         nNaPagina := 0
      ENDIF
   NEXT
   Aviso( "Fim do relatório — pressione uma tecla" )
   Inkey( 0 )
   Limpa()

   RETURN

/*
 * Impressão: gera o arquivo e entrega ao lp. Sem detecção de impressora
 * matricial e sem o laço bloqueante `DO WHILE .NOT. ISPRINTER()` do legado —
 * em Linux quem enfileira é o sistema de impressão.
 */
FUNCTION RelatorioImprimir( aLinhas, cImpressora )

   LOCAL cArq := hb_DirTemp() + "sccv-relatorio.txt", cCmd

   IF !RelatorioGravar( aLinhas, cArq )
      RETURN { "ok" => .F., "mensagem" => "Não foi possível gerar o arquivo do relatório." }
   ENDIF

   cCmd := "lp" + iif( Empty( cImpressora ), "", " -d " + cImpressora ) + " " + cArq
   IF hb_run( cCmd ) != 0
      RETURN { "ok" => .F., ;
               "mensagem" => "Não foi possível imprimir. O relatório está em " + cArq }
   ENDIF

   RETURN { "ok" => .T., "mensagem" => "Enviado para impressão." }
