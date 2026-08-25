/*
 * tela.prg — FASE G, onda 1
 *
 * Primitivas de tela. Substituem BORDA(), MEIO(), MENSAGEM(), LIMPA() e
 * CONFIRMA() do legado (01-ARQUITETURA-LEGADO.md §3.1).
 *
 * O comportamento visível é preservado; dois defeitos não são:
 *
 *   - MENSAGEM() aceitava um parâmetro de linha e o IGNORAVA, escrevendo
 *     sempre na 23. CONFIRMA() ignorava nL e nC do mesmo jeito. Aqui o
 *     parâmetro simplesmente não existe: manter um argumento que não faz nada
 *     é convidar quem lê o código a acreditar nele.
 *   - CONFIRMA() aceitava qualquer tecla como resposta por usar `$`. Aqui a
 *     comparação é exata (V-11), e a pergunta se repete até vir S ou N.
 *
 * Layout de 80×25 preservado: é o que os relatórios e as telas do legado
 * assumem, e mudar isso agora quebraria a comparação da FASE I.
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "box.ch"

REQUEST HB_CODEPAGE_UTF8

#define LINHA_MENSAGEM   23
#define COLUNAS          80

STATIC s_lIniciada := .F.

/*
 * O binário é linkado com gtcgi como padrão, para que os comandos não
 * interativos (--estado, --versao) produzam saída limpa e utilizável em
 * script. O GT de terminal entra só aqui, quando há tela de verdade.
 */
PROCEDURE TelaIniciar()
   IF s_lIniciada
      RETURN
   ENDIF
   hb_gtReload( "TRM" )
   /* Sem isto o GT trata os bytes UTF-8 dos fontes como se fossem de uma
      página DOS e os reconverte: "Concessionária" vira "Concession├íria".
      hb_SetTermCP( terminal, aplicação, lDesenhoDeCaixa ). */
   hb_cdpSelect( "UTF8" )
   hb_SetTermCP( "UTF8", "UTF8", .F. )
   SetMode( 25, COLUNAS )
   SetColor( "W/N" )
   SetCursor( SC_NONE )
   CLS
   s_lIniciada := .T.
   RETURN

PROCEDURE TelaEncerrar()
   IF !s_lIniciada
      RETURN
   ENDIF
   SetCursor( SC_NORMAL )
   SetColor( "W/N" )
   CLS
   hb_gtReload( "CGI" )
   s_lIniciada := .F.
   RETURN

/* Caixa com sombra, como BORDA() — a sombra é deslocada 1 linha e 2 colunas. */
PROCEDURE Borda( nTopo, nEsq, nBase, nDir, cTitulo )

   LOCAL nI

   /* sombra primeiro, para a caixa ficar por cima */
   FOR nI := nTopo + 1 TO nBase + 1
      hb_DispOutAt( nI, nDir + 1, "  ", "N/N" )
   NEXT
   hb_DispOutAt( nBase + 1, nEsq + 2, Replicate( " ", nDir - nEsq ), "N/N" )

   hb_Scroll( nTopo, nEsq, nBase, nDir )
   hb_DispBox( nTopo, nEsq, nBase, nDir, HB_B_SINGLE_UNI )

   IF !Empty( cTitulo )
      hb_DispOutAt( nTopo, nEsq + Max( 1, Int( ( nDir - nEsq - Len( cTitulo ) ) / 2 ) ), ;
                    " " + cTitulo + " " )
   ENDIF

   RETURN

/* Centraliza em 80 colunas, como MEIO(). */
PROCEDURE Meio( cTexto, nLinha )

   LOCAL nCol := Max( 0, Int( ( COLUNAS - Len( cTexto ) ) / 2 ) )

   hb_DispOutAt( nLinha, nCol, cTexto )

   RETURN

/* Mensagem na linha 23 e espera uma tecla, como MENSAGEM(). */
PROCEDURE Mensagem( cTexto )

   Limpa()
   hb_DispOutAt( LINHA_MENSAGEM, 1, Left( cTexto, COLUNAS - 2 ) )
   Inkey( 0 )
   Limpa()

   RETURN

/* Mensagem sem esperar tecla — para status durante operação. */
PROCEDURE Aviso( cTexto )
   Limpa()
   hb_DispOutAt( LINHA_MENSAGEM, 1, Left( cTexto, COLUNAS - 2 ) )
   RETURN

PROCEDURE Limpa()
   hb_Scroll( LINHA_MENSAGEM, 0, LINHA_MENSAGEM, COLUNAS - 1 )
   RETURN

/*
 * Pergunta S/N na linha 23. Diferente do legado, insiste até vir uma resposta
 * válida: `$` aceitava qualquer coisa, inclusive vazio.
 */
FUNCTION Confirma( cTexto )

   LOCAL nTecla, cResp

   DO WHILE .T.
      Limpa()
      hb_DispOutAt( LINHA_MENSAGEM, 1, Left( cTexto, COLUNAS - 12 ) + "  (S/N) " )
      nTecla := Inkey( 0 )
      IF nTecla == K_ESC
         Limpa()
         RETURN .F.
      ENDIF
      cResp := Upper( Chr( nTecla ) )
      IF cResp == "S"
         Limpa()
         RETURN .T.
      ELSEIF cResp == "N"
         Limpa()
         RETURN .F.
      ENDIF
   ENDDO

   RETURN .F.

/*
 * Mostra os erros de uma validação. Recebe o acumulador de validacao.prg.
 * Erros e avisos aparecem juntos, mas rotulados: o operador precisa saber o
 * que impede gravar e o que só pede atenção.
 */
PROCEDURE TelaValidacao( hV )

   LOCAL aLin := {}, i, nAlt, nTopo

   FOR i := 1 TO Len( hV[ "erros" ] )
      AAdd( aLin, "  " + hV[ "erros" ][ i ][ "mensagem" ] )
   NEXT
   FOR i := 1 TO Len( hV[ "avisos" ] )
      AAdd( aLin, "  aviso: " + hV[ "avisos" ][ i ][ "mensagem" ] )
   NEXT
   IF Len( aLin ) == 0
      RETURN
   ENDIF

   nAlt  := Min( Len( aLin ), 10 )
   nTopo := 8
   Borda( nTopo, 8, nTopo + nAlt + 3, 71, ;
          iif( Len( hV[ "erros" ] ) > 0, "Não foi possível gravar", "Atenção" ) )
   FOR i := 1 TO nAlt
      hb_DispOutAt( nTopo + 1 + i, 10, Left( aLin[ i ], 60 ) )
   NEXT
   Mensagem( "Pressione uma tecla" )

   RETURN

/* Cabeçalho padrão das telas de manutenção e consulta. */
PROCEDURE TelaCabecalho( cTitulo )

   hb_Scroll( 0, 0, 24, COLUNAS - 1 )
   hb_DispOutAt( 0, 0, PadC( "S.C.C.V. — Sistema de Controle de Concessionária", COLUNAS ), "N/W" )
   Meio( cTitulo, 2 )
   hb_DispOutAt( 24, 0, PadR( " ESC sai ", COLUNAS ), "N/W" )

   RETURN
