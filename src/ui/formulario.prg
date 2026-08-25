/*
 * formulario.prg — FASE G, onda 1
 *
 * Entrada de dados com validação. Substitui os blocos GET/READ do legado.
 *
 * A diferença de fundo: no legado a validação morava na cláusula VALID de cada
 * GET, espalhada por 27 programas, e por isso a mesma regra tinha versões
 * diferentes em lugares diferentes (05-VALIDACOES-LEGADO.md §3). Aqui o campo
 * DECLARA seu validador, que vem de src/validation — uma regra, um lugar.
 *
 * O formulário é um DADO: a lista de campos pode ser montada e validada sem
 * terminal nenhum, o que torna a regra testável. O desenho é a parte fina.
 */

#include "inkey.ch"
#include "setcurs.ch"

FUNCTION FormNovo( cTitulo )
   RETURN { "titulo" => cTitulo, "campos" => {}, "valores" => { => } }

/*
 * cTipo: "C" texto · "N" número · "D" data ISO · "$" centavos · "M" memo
 * bValidador: bloco que recebe o valor e devolve { ok, mensagem, valor },
 *             no formato de src/validation/validacao.prg. Pode ser NIL.
 */
FUNCTION FormCampo( hF, cNome, cRotulo, cTipo, nLinha, nColuna, nTamanho, ;
                    bValidador, xInicial )

   AAdd( hF[ "campos" ], { ;
      "nome"      => cNome, ;
      "rotulo"    => cRotulo, ;
      "tipo"      => cTipo, ;
      "linha"     => nLinha, ;
      "coluna"    => nColuna, ;
      "tamanho"   => nTamanho, ;
      "validador" => bValidador } )
   hF[ "valores" ][ cNome ] := iif( xInicial == NIL, FormVazio( cTipo ), xInicial )

   RETURN hF

STATIC FUNCTION FormVazio( cTipo )
   RETURN iif( cTipo == "N", 0, "" )

FUNCTION FormValor( hF, cNome )
   RETURN iif( cNome $ hF[ "valores" ], hF[ "valores" ][ cNome ], NIL )

FUNCTION FormDefinir( hF, cNome, xValor )
   hF[ "valores" ][ cNome ] := xValor
   RETURN hF

/*
 * Aplica os validadores de todos os campos e devolve o acumulador de
 * validacao.prg. Os valores normalizados (CPF só com dígitos, UF em
 * maiúsculas) substituem os digitados: normalizar depois de validar evita
 * gravar a máscara junto com o dado, que é o defeito V-03 do legado.
 */
FUNCTION FormValidar( hF )

   LOCAL hV := ValNovo(), i, hC, hR

   FOR i := 1 TO Len( hF[ "campos" ] )
      hC := hF[ "campos" ][ i ]
      IF hC[ "validador" ] == NIL
         LOOP
      ENDIF
      hR := Eval( hC[ "validador" ], hF[ "valores" ][ hC[ "nome" ] ] )
      IF hR == NIL
         LOOP
      ENDIF
      IF !hR[ "ok" ]
         ValErro( hV, hC[ "nome" ], hC[ "rotulo" ] + ": " + hR[ "mensagem" ] )
      ELSEIF hR[ "valor" ] != NIL
         hF[ "valores" ][ hC[ "nome" ] ] := hR[ "valor" ]
      ENDIF
   NEXT

   RETURN hV

/*
 * Edita o formulário na tela. Devolve .T. se o operador confirmou.
 * ESC desiste. F2 grava. As setas e ENTER movem entre campos.
 */
FUNCTION FormEditar( hF )

   LOCAL nAtual := 1, nTecla, hV

   SetCursor( SC_NORMAL )
   FormDesenhar( hF, nAtual )

   DO WHILE .T.
      FormDesenhar( hF, nAtual )
      Aviso( "F2 grava · ESC desiste · ↑ ↓ ENTER movem" )
      hF[ "valores" ][ hF[ "campos" ][ nAtual ][ "nome" ] ] := ;
         FormLerCampo( hF[ "campos" ][ nAtual ], ;
                       hF[ "valores" ][ hF[ "campos" ][ nAtual ][ "nome" ] ] )
      nTecla := LastKey()

      DO CASE
      CASE nTecla == K_ESC
         SetCursor( SC_NONE )
         RETURN .F.
      CASE nTecla == K_F2
         hV := FormValidar( hF )
         IF ValOk( hV )
            SetCursor( SC_NONE )
            RETURN .T.
         ENDIF
         TelaValidacao( hV )
      CASE nTecla == K_UP
         nAtual := iif( nAtual == 1, Len( hF[ "campos" ] ), nAtual - 1 )
      OTHERWISE
         nAtual := iif( nAtual == Len( hF[ "campos" ] ), 1, nAtual + 1 )
      ENDCASE
   ENDDO

   RETURN .F.

STATIC PROCEDURE FormDesenhar( hF, nAtual )

   LOCAL i, hC, cVal

   FOR i := 1 TO Len( hF[ "campos" ] )
      hC := hF[ "campos" ][ i ]
      cVal := FormTexto( hF[ "valores" ][ hC[ "nome" ] ], hC[ "tipo" ] )
      hb_DispOutAt( hC[ "linha" ], hC[ "coluna" ], PadR( hC[ "rotulo" ] + ":", 16 ) )
      hb_DispOutAt( hC[ "linha" ], hC[ "coluna" ] + 16, ;
         PadR( cVal, hC[ "tamanho" ] ), iif( i == nAtual, "N/W", "W/N" ) )
   NEXT

   RETURN

STATIC FUNCTION FormLerCampo( hC, xAtual )

   LOCAL cBuf

   /* memo abre o editor de várias linhas; o legado usava MEMOEDIT para OBSFOR */
   IF hC[ "tipo" ] == "M"
      RETURN UtilEditarMemo( FormTexto( xAtual, "C" ), hC[ "rotulo" ] )
   ENDIF

   cBuf := PadR( FormTexto( xAtual, hC[ "tipo" ] ), hC[ "tamanho" ] )

   @ hC[ "linha" ], hC[ "coluna" ] + 16 GET cBuf PICTURE Replicate( "X", hC[ "tamanho" ] )
   READ

   IF hC[ "tipo" ] == "N"
      RETURN Val( AllTrim( cBuf ) )
   ENDIF

   RETURN AllTrim( cBuf )

STATIC FUNCTION FormTexto( xValor, cTipo )

   IF xValor == NIL
      RETURN ""
   ENDIF
   IF cTipo == "N"
      RETURN AllTrim( hb_ValToStr( xValor ) )
   ENDIF

   RETURN hb_ValToStr( xValor )
