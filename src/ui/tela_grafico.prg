/*
 * tela_grafico.prg — FASE G, onda 8
 *
 * Exibição dos gráficos R-11 e R-12 e exportação CSV.
 * O conteúdo vem de reports/grafico.prg, que não conhece tela.
 */

#include "inkey.ch"

PROCEDURE GraficoMenu( pDb )

   LOCAL aCat := GraficoCatalogo(), aOp := {}, i, n

   FOR i := 1 TO Len( aCat )
      AAdd( aOp, aCat[ i ][ 2 ] )
   NEXT
   AAdd( aOp, "Voltar" )

   DO WHILE .T.
      TelaCabecalho( "Gráficos" )
      n := GraficoEscolher( aOp, "Gráfico" )
      IF n == 0 .OR. n > Len( aCat )
         RETURN
      ENDIF
      GraficoExibir( pDb, aCat[ n ][ 1 ] )
   ENDDO

   RETURN

STATIC PROCEDURE GraficoExibir( pDb, cId )

   LOCAL hDef := GraficoDefinicao( cId ), aDados, aLinhas, aDiv, i, n

   IF hDef == NIL
      Mensagem( "Gráfico " + cId + " não encontrado" )
      RETURN
   ENDIF

   aDados  := GraficoDados( pDb, hDef )
   aLinhas := GraficoBarras( hDef, aDados, 78 )

   /*
    * D-18 — os números aqui são DIFERENTES dos que o sistema antigo mostrava,
    * porque agora vêm do movimento real. Mostrar a diferença junto evita que a
    * mudança pareça erro.
    */
   aDiv := GraficoDivergencia( pDb, hDef, aDados )
   FOR i := 1 TO Len( GraficoLinhasDivergencia( aDiv ) )
      AAdd( aLinhas, GraficoLinhasDivergencia( aDiv )[ i ] )
   NEXT

   RelatorioTela( aLinhas )

   IF Len( aDados ) > 0 .AND. Confirma( "Exportar para CSV?" )
      n := GraficoExportar( hDef, aDados )
      HB_SYMBOL_UNUSED( n )
   ENDIF

   RETURN

STATIC FUNCTION GraficoExportar( hDef, aDados )

   LOCAL cArq := ConfigObter( "relatorio_dir", hb_cwd() )

   IF !( Right( cArq, 1 ) == hb_ps() )
      cArq += hb_ps()
   ENDIF
   cArq += "sccv-" + Lower( hDef[ "id" ] ) + ".csv"

   IF GraficoCsv( hDef, aDados, cArq )
      Mensagem( "Exportado para " + cArq )
      RETURN .T.
   ENDIF
   Mensagem( "Não foi possível exportar para " + cArq )

   RETURN .F.

STATIC FUNCTION GraficoEscolher( aOp, cTitulo )

   LOCAL nAtual := 1, nTecla, i

   Borda( 8, 22, 8 + Len( aOp ) + 1, 57, cTitulo )
   DO WHILE .T.
      FOR i := 1 TO Len( aOp )
         hb_DispOutAt( 8 + i, 23, " " + hb_UPadR( aOp[ i ], 33 ), ;
                       iif( i == nAtual, "N/W", "W/N" ) )
      NEXT
      Aviso( "↑ ↓ escolhe · ENTER confirma · ESC volta" )
      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC   ; Limpa() ; RETURN 0
      CASE nTecla == K_ENTER ; Limpa() ; RETURN nAtual
      CASE nTecla == K_DOWN  ; nAtual := iif( nAtual == Len( aOp ), 1, nAtual + 1 )
      CASE nTecla == K_UP    ; nAtual := iif( nAtual == 1, Len( aOp ), nAtual - 1 )
      ENDCASE
   ENDDO

   RETURN 0
