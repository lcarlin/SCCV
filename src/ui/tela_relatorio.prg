/*
 * tela_relatorio.prg — FASE G, onda 7
 *
 * Escolha de destino e emissão. O conteúdo vem inteiro de reports/, que não
 * conhece tela: aqui só se decide para onde a saída vai.
 *
 * Destinos: tela, arquivo e impressão (06 §7). "Etiqueta" NÃO é oferecido — os
 * arquivos `.LBL` estão ausentes e o layout não é recuperável (D-21).
 */

#include "inkey.ch"
#include "setcurs.ch"

/* Emite um relatório pelo id, perguntando filtro (se houver) e destino. */
PROCEDURE RelatorioEmitir( pDb, cId )

   LOCAL hDef := RelatorioDefinicao( cId ), hOpc := { => }, aLinhas, nDestino

   IF hDef == NIL
      Mensagem( "Relatório " + cId + " não encontrado" )
      RETURN
   ENDIF

   TelaCabecalho( "Relatório de " + hDef[ "titulo" ] )

   /* RN-040 — só o relatório de clientes tem filtro */
   IF "filtros" $ hDef
      hOpc[ "filtro" ] := RelatorioPerguntarFiltro( hDef )
      IF hOpc[ "filtro" ] == NIL
         RETURN
      ENDIF
   ENDIF

   nDestino := RelatorioPerguntarDestino()
   IF nDestino == 0
      RETURN
   ENDIF

   aLinhas := RelatorioLinhas( pDb, hDef, hOpc )

   DO CASE
   CASE nDestino == 1
      RelatorioTela( aLinhas )
   CASE nDestino == 2
      RelatorioParaArquivo( aLinhas, hDef )
   CASE nDestino == 3
      Aviso( "Enviando para impressão..." )
      Mensagem( RelatorioImprimir( aLinhas )[ "mensagem" ] )
   ENDCASE

   RETURN

STATIC PROCEDURE RelatorioParaArquivo( aLinhas, hDef )

   LOCAL cArq := ConfigObter( "relatorio_dir", hb_cwd() )

   IF !( Right( cArq, 1 ) == hb_ps() )
      cArq += hb_ps()
   ENDIF
   cArq += "sccv-" + Lower( hDef[ "id" ] ) + ".txt"

   IF RelatorioGravar( aLinhas, cArq, 60 )
      Mensagem( "Gravado em " + cArq )
   ELSE
      Mensagem( "Não foi possível gravar em " + cArq )
   ENDIF

   RETURN

STATIC FUNCTION RelatorioPerguntarFiltro( hDef )

   LOCAL aOp := { "Consorciados", "Clientes", "Ambos" }
   LOCAL aVal := { "consorciados", "clientes", "ambos" }
   LOCAL n := RelatorioEscolher( aOp, "Filtro" )

   RETURN iif( n == 0, NIL, aVal[ n ] )

STATIC FUNCTION RelatorioPerguntarDestino()
   RETURN RelatorioEscolher( { "Tela", "Arquivo", "Impressora" }, "Destino" )

STATIC FUNCTION RelatorioEscolher( aOp, cTitulo )

   LOCAL nAtual := 1, nTecla, i

   Borda( 8, 28, 8 + Len( aOp ) + 1, 51, cTitulo )
   DO WHILE .T.
      FOR i := 1 TO Len( aOp )
         hb_DispOutAt( 8 + i, 29, " " + hb_UPadR( aOp[ i ], 21 ), ;
                       iif( i == nAtual, "N/W", "W/N" ) )
      NEXT
      Aviso( "↑ ↓ escolhe · ENTER confirma · ESC cancela" )
      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC   ; Limpa() ; RETURN 0
      CASE nTecla == K_ENTER ; Limpa() ; RETURN nAtual
      CASE nTecla == K_DOWN  ; nAtual := iif( nAtual == Len( aOp ), 1, nAtual + 1 )
      CASE nTecla == K_UP    ; nAtual := iif( nAtual == 1, Len( aOp ), nAtual - 1 )
      ENDCASE
   ENDDO

   RETURN 0

/* Submenu de relatórios, para os grupos que têm mais de um. */
PROCEDURE RelatorioSubmenu( pDb, aIds )

   LOCAL aOp := {}, i, n, hDef

   FOR i := 1 TO Len( aIds )
      hDef := RelatorioDefinicao( aIds[ i ] )
      AAdd( aOp, iif( hDef == NIL, aIds[ i ], hDef[ "titulo" ] ) )
   NEXT
   AAdd( aOp, "Voltar" )

   DO WHILE .T.
      TelaCabecalho( "Relatórios" )
      n := RelatorioEscolher( aOp, "Relatório" )
      IF n == 0 .OR. n > Len( aIds )
         RETURN
      ENDIF
      RelatorioEmitir( pDb, aIds[ n ] )
   ENDDO

   RETURN
