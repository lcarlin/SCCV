/*
 * browse.prg — FASE G, onda 1
 *
 * Consulta em grade. Substitui FUNDBCON() do legado, mantendo as teclas que o
 * operador conhecia: F3 pesquisa, ENTER abre o detalhe, ESC sai
 * (01-ARQUITETURA-LEGADO.md §3.1).
 *
 * O legado tratava "arquivo vazio" com MENSAGEM("Arquivo Vazio") — comportamento
 * preservado, porque uma grade vazia sem explicação faz o operador achar que o
 * sistema travou.
 *
 * A consulta é montada com parâmetros: o texto da pesquisa vem do operador.
 */

#include "inkey.ch"

/*
 * aColunas: { { titulo, largura, alinhamento("E"/"D") }, ... }
 * O SELECT deve devolver as colunas na mesma ordem.
 */
FUNCTION BrowseConsulta( pDb, cTitulo, cSqlBase, aColunas, cColunaBusca )

   LOCAL aLinhas, nAtual := 1, nTopo := 1, nAltura := 14, nTecla
   LOCAL cFiltro := "", i

   aLinhas := BrowseCarregar( pDb, cSqlBase, cColunaBusca, cFiltro )

   DO WHILE .T.
      TelaCabecalho( cTitulo )
      IF Len( aLinhas ) == 0
         Mensagem( iif( Empty( cFiltro ), "Arquivo vazio", ;
                        "Nenhum registro encontrado para '" + cFiltro + "'" ) )
         IF Empty( cFiltro )
            RETURN NIL
         ENDIF
         cFiltro := ""
         aLinhas := BrowseCarregar( pDb, cSqlBase, cColunaBusca, cFiltro )
         LOOP
      ENDIF

      BrowseCabecalho( aColunas )
      FOR i := 0 TO nAltura - 1
         BrowseLinha( aLinhas, aColunas, nTopo + i, 6 + i, nTopo + i == nAtual )
      NEXT
      Aviso( "F3 pesquisa · ENTER detalha · ESC sai · " + ;
             hb_ntos( Len( aLinhas ) ) + " registro(s)" + ;
             iif( Empty( cFiltro ), "", " · filtro: " + cFiltro ) )

      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC
         RETURN NIL
      CASE nTecla == K_ENTER
         RETURN aLinhas[ nAtual ]
      CASE nTecla == K_F3
         cFiltro := BrowsePerguntar()
         aLinhas := BrowseCarregar( pDb, cSqlBase, cColunaBusca, cFiltro )
         nAtual := 1
         nTopo := 1
      CASE nTecla == K_DOWN ; nAtual := Min( nAtual + 1, Len( aLinhas ) )
      CASE nTecla == K_UP   ; nAtual := Max( nAtual - 1, 1 )
      CASE nTecla == K_PGDN ; nAtual := Min( nAtual + nAltura, Len( aLinhas ) )
      CASE nTecla == K_PGUP ; nAtual := Max( nAtual - nAltura, 1 )
      CASE nTecla == K_HOME ; nAtual := 1
      CASE nTecla == K_END  ; nAtual := Len( aLinhas )
      ENDCASE

      IF nAtual < nTopo
         nTopo := nAtual
      ELSEIF nAtual > nTopo + nAltura - 1
         nTopo := nAtual - nAltura + 1
      ENDIF
   ENDDO

   RETURN NIL

/* Separada do desenho de propósito: assim a consulta é testável sem terminal. */
FUNCTION BrowseCarregar( pDb, cSqlBase, cColunaBusca, cFiltro )

   LOCAL cSql := cSqlBase, aParams := {}

   IF !Empty( cFiltro ) .AND. !Empty( cColunaBusca )
      cSql += iif( At( " WHERE ", Upper( cSqlBase ) ) > 0, " AND ", " WHERE " ) + ;
              cColunaBusca + " LIKE ?"
      AAdd( aParams, "%" + cFiltro + "%" )
   ENDIF

   RETURN SqlLinhasBind( pDb, cSql, aParams )

STATIC PROCEDURE BrowseCabecalho( aColunas )

   LOCAL cLin := "", i

   FOR i := 1 TO Len( aColunas )
      cLin += PadR( aColunas[ i ][ 1 ], aColunas[ i ][ 2 ] ) + " "
   NEXT
   hb_DispOutAt( 4, 2, PadR( cLin, 76 ), "N/W" )

   RETURN

STATIC PROCEDURE BrowseLinha( aLinhas, aColunas, nIndice, nTela, lAtual )

   LOCAL cLin := "", i, xVal

   IF nIndice > Len( aLinhas )
      hb_DispOutAt( nTela, 2, Space( 76 ) )
      RETURN
   ENDIF

   FOR i := 1 TO Len( aColunas )
      xVal := iif( i > Len( aLinhas[ nIndice ] ), NIL, aLinhas[ nIndice ][ i ] )
      cLin += BrowseCelula( xVal, aColunas[ i ] ) + " "
   NEXT
   hb_DispOutAt( nTela, 2, PadR( cLin, 76 ), iif( lAtual, "N/W", "W/N" ) )

   RETURN

STATIC FUNCTION BrowseCelula( xVal, aCol )

   LOCAL cTxt := iif( xVal == NIL, "", AllTrim( hb_ValToStr( xVal ) ) )

   IF Len( aCol ) >= 3 .AND. aCol[ 3 ] == "D"
      RETURN PadL( Left( cTxt, aCol[ 2 ] ), aCol[ 2 ] )
   ENDIF

   RETURN PadR( Left( cTxt, aCol[ 2 ] ), aCol[ 2 ] )

STATIC FUNCTION BrowsePerguntar()

   LOCAL cBuf := Space( 30 )

   Limpa()
   hb_DispOutAt( 23, 1, "Pesquisar: " )
   SetCursor( 1 )
   @ 23, 12 GET cBuf PICTURE "@S30"
   READ
   SetCursor( 0 )
   Limpa()

   RETURN AllTrim( cBuf )

/* Valor monetário em centavos para exibição. */
FUNCTION BrowseMoeda( nCent )
   IF nCent == NIL
      RETURN ""
   ENDIF
   RETURN Transform( nCent / 100, "@E 999,999,999.99" )
