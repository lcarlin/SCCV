/*
 * cadastro.prg — FASE G, onda 2
 *
 * Tela de manutenção, genérica, dirigida pelo descritor da entidade.
 * Uma tela serve os quatro cadastros de nível 0, pelo mesmo motivo que o motor
 * de SQL é um só: no legado, CVMTCLI/CVMTFUNC/CVMTFOR/CVMTFRO eram cópias que
 * divergiram com o tempo.
 *
 * Operações, como no legado: Incluir · Alterar · Excluir · Consultar.
 * A exclusão é LÓGICA e recusa registro referenciado (V-17).
 */

#include "inkey.ch"

FUNCTION CadastroManutencao( pDb, hDesc )

   LOCAL nOpcao

   DO WHILE .T.
      TelaCabecalho( hDesc[ "titulo" ] )
      nOpcao := CadastroMenu()
      DO CASE
      CASE nOpcao == 1 ; CadastroIncluir( pDb, hDesc )
      CASE nOpcao == 2 ; CadastroAlterar( pDb, hDesc )
      CASE nOpcao == 3 ; CadastroExcluir( pDb, hDesc )
      CASE nOpcao == 4 ; CadastroConsultar( pDb, hDesc )
      OTHERWISE        ; RETURN NIL
      ENDCASE
   ENDDO

   RETURN NIL

STATIC FUNCTION CadastroMenu()

   LOCAL aOp := { "Incluir", "Alterar", "Excluir", "Consultar", "Voltar" }
   LOCAL nAtual := 1, nTecla, i

   Borda( 6, 28, 6 + Len( aOp ) + 1, 51 )
   DO WHILE .T.
      FOR i := 1 TO Len( aOp )
         hb_DispOutAt( 6 + i, 29, " " + PadR( aOp[ i ], 21 ), ;
                       iif( i == nAtual, "N/W", "W/N" ) )
      NEXT
      Aviso( "↑ ↓ escolhe · ENTER confirma · ESC volta" )
      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC   ; RETURN 0
      CASE nTecla == K_ENTER ; RETURN iif( nAtual == Len( aOp ), 0, nAtual )
      CASE nTecla == K_DOWN  ; nAtual := iif( nAtual == Len( aOp ), 1, nAtual + 1 )
      CASE nTecla == K_UP    ; nAtual := iif( nAtual == 1, Len( aOp ), nAtual - 1 )
      ENDCASE
   ENDDO

   RETURN 0

STATIC PROCEDURE CadastroIncluir( pDb, hDesc )

   LOCAL hF, hValores, hRes, nCodigo

   nCodigo := ModeloProximoCodigo( pDb, hDesc )
   hF := CadastroFormulario( hDesc, NIL, nCodigo )

   TelaCabecalho( hDesc[ "titulo" ] + " — inclusão" )
   IF !FormEditar( hF )
      RETURN
   ENDIF

   hValores := CadastroValores( hDesc, hF )
   hRes := ModeloGravar( pDb, hDesc, hValores, .T. )
   CadastroResultado( hRes, "Registro incluído." )

   RETURN

STATIC PROCEDURE CadastroAlterar( pDb, hDesc )

   LOCAL nCodigo, hReg, hF, hRes

   nCodigo := SelecionarCodigo( pDb, hDesc[ "entidade" ] )
   IF nCodigo == NIL
      RETURN
   ENDIF
   hReg := ModeloObter( pDb, hDesc, nCodigo )
   IF hReg == NIL
      Mensagem( "Código não cadastrado" )
      RETURN
   ENDIF

   hF := CadastroFormulario( hDesc, hReg, nCodigo )
   TelaCabecalho( hDesc[ "titulo" ] + " — alteração" )
   IF !FormEditar( hF )
      RETURN
   ENDIF

   hRes := ModeloGravar( pDb, hDesc, CadastroValores( hDesc, hF ), .F. )
   CadastroResultado( hRes, "Registro alterado." )

   RETURN

STATIC PROCEDURE CadastroExcluir( pDb, hDesc )

   LOCAL nCodigo, hReg, hRes, cDesc

   nCodigo := SelecionarCodigo( pDb, hDesc[ "entidade" ] )
   IF nCodigo == NIL
      RETURN
   ENDIF
   hReg := ModeloObter( pDb, hDesc, nCodigo )
   IF hReg == NIL
      Mensagem( "Código não cadastrado" )
      RETURN
   ENDIF

   cDesc := hb_ValToStr( hReg[ hDesc[ "campos" ][ 1 ][ "nome" ] ] )
   IF !Confirma( "Excluir " + hb_ntos( nCodigo ) + " — " + AllTrim( cDesc ) + "?" )
      RETURN
   ENDIF

   hRes := ModeloExcluir( pDb, hDesc, nCodigo )
   CadastroResultado( hRes, "Registro excluído." )

   RETURN

STATIC PROCEDURE CadastroConsultar( pDb, hDesc )

   LOCAL aCols := { { "Código", 6, "D" } }, i, aSel

   FOR i := 1 TO Min( 3, Len( hDesc[ "campos" ] ) )
      AAdd( aCols, { hDesc[ "campos" ][ i ][ "rotulo" ], ;
                     Min( hDesc[ "campos" ][ i ][ "tamanho" ], 30 ) } )
   NEXT

   aSel := BrowseConsulta( pDb, hDesc[ "titulo" ] + " — consulta", ;
      "SELECT " + hDesc[ "chave" ] + ", " + ;
      CadastroColunasGrade( hDesc ) + " FROM " + hDesc[ "view" ], ;
      aCols, hDesc[ "campos" ][ 1 ][ "nome" ] )

   IF aSel != NIL
      CadastroDetalhe( pDb, hDesc, aSel[ 1 ] )
   ENDIF

   RETURN

/* Ficha completa de um registro — o que FUNDBCON() fazia com ENTER. */
STATIC PROCEDURE CadastroDetalhe( pDb, hDesc, nCodigo )

   LOCAL hReg := ModeloObter( pDb, hDesc, nCodigo ), i, hC, nLin := 6, xVal

   IF hReg == NIL
      Mensagem( "Código não cadastrado" )
      RETURN
   ENDIF

   TelaCabecalho( hDesc[ "titulo" ] + " — ficha" )
   hb_DispOutAt( 4, 4, "Código: " + hb_ntos( nCodigo ) )
   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hC := hDesc[ "campos" ][ i ]
      xVal := hReg[ hC[ "nome" ] ]
      hb_DispOutAt( nLin, 4, PadR( hC[ "rotulo" ] + ":", 18 ) + ;
         Left( CadastroTexto( xVal, hC[ "tipo" ] ), 55 ) )
      nLin++
      IF nLin > 21
         EXIT
      ENDIF
   NEXT
   Mensagem( "Pressione uma tecla" )

   RETURN

/* ------------------------------------------------------------------ */

STATIC FUNCTION CadastroFormulario( hDesc, hReg, nCodigo )

   LOCAL hF := FormNovo( hDesc[ "titulo" ] ), i, hC, nLin := 5, xVal

   FormCampo( hF, hDesc[ "chave" ], "Código", "N", 4, 4, 6, NIL, nCodigo )
   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hC := hDesc[ "campos" ][ i ]
      xVal := iif( hReg == NIL, NIL, hReg[ hC[ "nome" ] ] )
      FormCampo( hF, hC[ "nome" ], hC[ "rotulo" ], hC[ "tipo" ], nLin, 4, ;
                 Min( hC[ "tamanho" ], 45 ), NIL, ;
                 CadastroTexto( xVal, hC[ "tipo" ] ) )
      nLin++
   NEXT

   RETURN hF

/*
 * Os validadores NÃO são ligados ao formulário: quem valida é o modelo, para
 * que a regra seja a mesma vindo da tela ou de qualquer outro caminho. O
 * formulário só coleta.
 */
STATIC FUNCTION CadastroValores( hDesc, hF )

   LOCAL hVal := { => }, i, hC

   hVal[ hDesc[ "chave" ] ] := FormValor( hF, hDesc[ "chave" ] )
   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hC := hDesc[ "campos" ][ i ]
      hVal[ hC[ "nome" ] ] := FormValor( hF, hC[ "nome" ] )
   NEXT

   RETURN hVal

STATIC FUNCTION CadastroTexto( xVal, cTipo )

   IF xVal == NIL
      RETURN ""
   ENDIF
   IF cTipo == "$"
      RETURN AllTrim( Transform( xVal / 100, "@E 999,999,999.99" ) )
   ENDIF

   RETURN AllTrim( hb_ValToStr( xVal ) )

STATIC FUNCTION CadastroColunasGrade( hDesc )

   LOCAL cTxt := "", i

   FOR i := 1 TO Min( 3, Len( hDesc[ "campos" ] ) )
      cTxt += iif( i > 1, ", ", "" ) + hDesc[ "campos" ][ i ][ "nome" ]
   NEXT

   RETURN cTxt

STATIC PROCEDURE CadastroResultado( hRes, cSucesso )

   IF hRes[ "ok" ]
      Mensagem( cSucesso )
      IF "validacao" $ hRes .AND. ValTemAviso( hRes[ "validacao" ] )
         TelaValidacao( hRes[ "validacao" ] )
      ENDIF
   ELSE
      Mensagem( Left( StrTran( hRes[ "mensagem" ], hb_eol(), " · " ), 76 ) )
   ENDIF

   RETURN
