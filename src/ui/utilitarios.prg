/*
 * utilitarios.prg — FASE J
 *
 * As três conveniências do legado que faltavam: espaço em disco (F1),
 * calculadora (F2) e edição de memo.
 *
 * No legado F1 e F2 eram atalhos GLOBAIS, ligados por `SET KEY -1` e
 * `SET KEY -2` em `SCCV.PRG:16-17` — funcionavam de qualquer tela. Aqui são
 * funções chamadas pelo laço do menu, que é onde o operador passa a maior parte
 * do tempo; um `SET KEY` global reintroduziria o acoplamento por efeito
 * colateral que o resto do sistema evitou.
 *
 * Nenhuma delas toca em dado de negócio.
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "box.ch"

/*
 * F1 — espaço em disco. `DISKSPACE()` no legado mostrava o espaço da unidade
 * corrente do DOS; aqui mostra o do sistema de arquivos onde o BANCO está, que
 * é a informação que interessa a quem opera.
 */
PROCEDURE UtilEspacoDisco( cBanco )

   LOCAL nLivre, cDir

   cDir := iif( Empty( cBanco ), hb_cwd(), hb_FNameDir( cBanco ) )
   nLivre := hb_DiskSpace( cDir )

   Borda( 9, 16, 14, 63, "Espaço em disco" )
   hb_DispOutAt( 11, 18, "Local: " + hb_ULeft( cDir, 38 ) )
   hb_DispOutAt( 12, 18, "Livre: " + AllTrim( Transform( nLivre / 1048576, ;
                 "@E 999,999,999" ) ) + " MB" )
   Mensagem( "Pressione uma tecla" )

   RETURN

/*
 * F2 — calculadora. No legado chamava-se `CONSORcalc()`, mas apesar do nome não
 * tem nada de consórcio: é uma calculadora comum, com os dígitos e os
 * operadores desenhados numa régua na tela (`CV_FUNC.PRG:17-29`).
 *
 * Aqui ela aceita a expressão digitada e a avalia. Sem macro-substituição: o
 * texto vem do operador, e `&()` executaria qualquer coisa que ele escrevesse.
 */
PROCEDURE UtilCalculadora()

   LOCAL cExpr := Space( 40 ), nRes, cSaida

   DO WHILE .T.
      Borda( 9, 12, 15, 67, "Calculadora" )
      hb_DispOutAt( 11, 14, "Operadores: +  -  *  /  ( )" )
      hb_DispOutAt( 12, 14, "Expressão: " )
      cExpr := Space( 40 )
      SetCursor( SC_NORMAL )
      @ 12, 25 GET cExpr PICTURE "@S40"
      READ
      SetCursor( SC_NONE )
      IF LastKey() == K_ESC .OR. Empty( AllTrim( cExpr ) )
         RETURN
      ENDIF

      nRes := UtilAvaliar( AllTrim( cExpr ) )
      cSaida := iif( nRes == NIL, "expressão inválida", ;
                     AllTrim( Transform( nRes, "@E 999,999,999.99" ) ) )
      hb_DispOutAt( 14, 14, hb_UPadR( "= " + cSaida, 51 ) )
      Mensagem( "ENTER calcula outra · ESC sai" )
      IF LastKey() == K_ESC
         RETURN
      ENDIF
   ENDDO

   RETURN

/*
 * Avalia uma expressão aritmética simples. Devolve NIL se não for válida.
 *
 * Feito à mão, e não com o operador de macro `&()`, porque o texto vem do
 * operador: `&()` compila e executa Harbour arbitrário — bastaria digitar uma
 * chamada de função para fazer o que quisesse com o banco. Uma calculadora não
 * justifica esse risco.
 */
FUNCTION UtilAvaliar( cExpr )

   LOCAL i, c, nPos := 1, nRes

   /* só dígitos, operadores, parênteses, ponto e espaço passam */
   FOR i := 1 TO Len( cExpr )
      c := SubStr( cExpr, i, 1 )
      IF !( c $ "0123456789.+-*/() " )
         RETURN NIL
      ENDIF
   NEXT

   nRes := UtilSoma( cExpr, @nPos )
   IF nRes == NIL
      RETURN NIL
   ENDIF
   /* sobrou texto: a expressão não foi consumida inteira */
   IF UtilPula( cExpr, @nPos ) <= Len( cExpr )
      RETURN NIL
   ENDIF

   RETURN nRes

STATIC FUNCTION UtilSoma( cExpr, nPos )

   LOCAL nEsq := UtilProduto( cExpr, @nPos ), c, nDir

   IF nEsq == NIL
      RETURN NIL
   ENDIF
   DO WHILE UtilPula( cExpr, @nPos ) <= Len( cExpr )
      c := SubStr( cExpr, nPos, 1 )
      IF !( c == "+" ) .AND. !( c == "-" )
         EXIT
      ENDIF
      nPos++
      nDir := UtilProduto( cExpr, @nPos )
      IF nDir == NIL
         RETURN NIL
      ENDIF
      nEsq := iif( c == "+", nEsq + nDir, nEsq - nDir )
   ENDDO

   RETURN nEsq

STATIC FUNCTION UtilProduto( cExpr, nPos )

   LOCAL nEsq := UtilFator( cExpr, @nPos ), c, nDir

   IF nEsq == NIL
      RETURN NIL
   ENDIF
   DO WHILE UtilPula( cExpr, @nPos ) <= Len( cExpr )
      c := SubStr( cExpr, nPos, 1 )
      IF !( c == "*" ) .AND. !( c == "/" )
         EXIT
      ENDIF
      nPos++
      nDir := UtilFator( cExpr, @nPos )
      IF nDir == NIL
         RETURN NIL
      ENDIF
      IF c == "/" .AND. nDir == 0
         RETURN NIL          /* divisão por zero devolve inválido, não derruba */
      ENDIF
      nEsq := iif( c == "*", nEsq * nDir, nEsq / nDir )
   ENDDO

   RETURN nEsq

STATIC FUNCTION UtilFator( cExpr, nPos )

   LOCAL cNum := "", c, nRes

   UtilPula( cExpr, @nPos )
   IF nPos > Len( cExpr )
      RETURN NIL
   ENDIF

   c := SubStr( cExpr, nPos, 1 )
   IF c == "-"
      nPos++
      nRes := UtilFator( cExpr, @nPos )
      RETURN iif( nRes == NIL, NIL, -nRes )
   ENDIF
   IF c == "("
      nPos++
      nRes := UtilSoma( cExpr, @nPos )
      UtilPula( cExpr, @nPos )
      IF nRes == NIL .OR. nPos > Len( cExpr ) .OR. !( SubStr( cExpr, nPos, 1 ) == ")" )
         RETURN NIL
      ENDIF
      nPos++
      RETURN nRes
   ENDIF

   DO WHILE nPos <= Len( cExpr )
      c := SubStr( cExpr, nPos, 1 )
      IF !( c $ "0123456789." )
         EXIT
      ENDIF
      cNum += c
      nPos++
   ENDDO

   RETURN iif( Empty( cNum ), NIL, Val( cNum ) )

STATIC FUNCTION UtilPula( cExpr, nPos )
   DO WHILE nPos <= Len( cExpr ) .AND. SubStr( cExpr, nPos, 1 ) == " "
      nPos++
   ENDDO
   RETURN nPos

/*
 * Editor de memo. O legado usava MEMOEDIT para OBSFOR (o memo do fornecedor,
 * em .DBT); o formulário genérico só oferecia um campo de uma linha, o que
 * trunca um texto que no acervo tem duas linhas e 100 caracteres.
 */
FUNCTION UtilEditarMemo( cTexto, cTitulo )

   LOCAL cNovo

   hb_default( @cTexto, "" )
   hb_default( @cTitulo, "Observações" )

   Borda( 6, 8, 19, 71, cTitulo )
   Aviso( "Ctrl+W grava · ESC descarta" )
   SetCursor( SC_NORMAL )
   cNovo := MemoEdit( cTexto, 7, 9, 18, 70, .T. )
   SetCursor( SC_NONE )
   Limpa()

   RETURN iif( LastKey() == K_ESC, cTexto, cNovo )
