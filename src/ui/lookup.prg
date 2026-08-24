/*
 * lookup.prg — FASE G, onda 1
 *
 * Substitui TABELA()/FUNDB() do legado (D-02).
 *
 * O original descobria por CONVENÇÃO DE NOMES que a variável do módulo chamador
 * se chamava "M" + FIELDNAME(1) e a preenchia por macro:
 *
 *     vara := "M" + FieldName( 1 )     // "MCODCLI"
 *     &vara := &( FieldName( 1 ) )     // MCODCLI := CODCLI
 *
 * Acoplamento por texto, sem contrato: renomear um campo quebrava a UI em
 * silêncio, e nada declarava a dependência. Aqui a função simplesmente
 * RETORNA o código escolhido, ou NIL se o operador desistiu.
 */

#include "inkey.ch"

/* Entidades que podem ser consultadas por código. */
STATIC FUNCTION Definicao( cEntidade )

   DO CASE
   CASE cEntidade == "cliente"
      RETURN { "tabela" => "v_cliente", "codigo" => "cod_cli", ;
               "descricao" => "nome", "titulo" => "Clientes" }
   CASE cEntidade == "funcionario"
      RETURN { "tabela" => "v_funcionario", "codigo" => "cod_fun", ;
               "descricao" => "nome", "titulo" => "Funcionários" }
   CASE cEntidade == "fornecedor"
      RETURN { "tabela" => "v_fornecedor", "codigo" => "cod_for", ;
               "descricao" => "nome", "titulo" => "Fornecedores" }
   CASE cEntidade == "peca"
      RETURN { "tabela" => "v_peca", "codigo" => "cod_pec", ;
               "descricao" => "descricao", "titulo" => "Peças" }
   CASE cEntidade == "almoxarifado"
      RETURN { "tabela" => "v_almoxarifado", "codigo" => "cod_alm", ;
               "descricao" => "descricao", "titulo" => "Almoxarifado" }
   CASE cEntidade == "modelo_veiculo"
      RETURN { "tabela" => "v_modelo_veiculo", "codigo" => "cod_car", ;
               "descricao" => "descricao", "titulo" => "Modelos de veículo" }
   ENDCASE

   RETURN NIL

FUNCTION LookupEntidades()
   RETURN { "cliente", "funcionario", "fornecedor", "peca", "almoxarifado", ;
            "modelo_veiculo" }

/* Linhas de uma entidade, prontas para o browse. Testável sem terminal. */
FUNCTION LookupLinhas( pDb, cEntidade, cFiltroTexto )

   LOCAL hD := Definicao( cEntidade ), cSql, aParams := {}

   IF hD == NIL
      RETURN {}
   ENDIF

   cSql := "SELECT " + hD[ "codigo" ] + ", " + hD[ "descricao" ] + ;
           " FROM " + hD[ "tabela" ]
   IF !Empty( cFiltroTexto )
      /* o texto vem do operador: parâmetro, nunca concatenação (briefing §16) */
      cSql += " WHERE " + hD[ "descricao" ] + " LIKE ?"
      AAdd( aParams, "%" + cFiltroTexto + "%" )
   ENDIF
   cSql += " ORDER BY " + hD[ "codigo" ]

   RETURN SqlLinhasBind( pDb, cSql, aParams )

FUNCTION LookupTitulo( cEntidade )

   LOCAL hD := Definicao( cEntidade )

   RETURN iif( hD == NIL, "", hD[ "titulo" ] )

/* Descrição de um código, ou NIL se não existir. */
FUNCTION LookupDescricao( pDb, cEntidade, nCodigo )

   LOCAL hD := Definicao( cEntidade ), aL

   IF hD == NIL .OR. nCodigo == NIL
      RETURN NIL
   ENDIF
   aL := SqlLinhasBind( pDb, "SELECT " + hD[ "descricao" ] + " FROM " + hD[ "tabela" ] + ;
      " WHERE " + hD[ "codigo" ] + " = ?", { nCodigo } )
   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN aL[ 1 ][ 1 ]

/*
 * Browse de seleção. Devolve o código escolhido, ou NIL.
 * Teclas: ↑ ↓ PgUp PgDn Home End · ENTER seleciona · ESC desiste.
 */
FUNCTION SelecionarCodigo( pDb, cEntidade )

   LOCAL aLinhas := LookupLinhas( pDb, cEntidade ), nAtual := 1, nTopo := 1
   LOCAL nAltura := 12, nTecla, i, nLin, cTexto

   IF Len( aLinhas ) == 0
      Mensagem( "Arquivo vazio — não há " + Lower( LookupTitulo( cEntidade ) ) + " cadastrados" )
      RETURN NIL
   ENDIF

   Borda( 4, 14, 4 + nAltura + 3, 65, LookupTitulo( cEntidade ) )

   DO WHILE .T.
      FOR i := 0 TO nAltura - 1
         nLin := nTopo + i
         cTexto := iif( nLin > Len( aLinhas ), "", ;
            PadL( hb_ValToStr( aLinhas[ nLin ][ 1 ] ), 6 ) + "  " + ;
            PadR( iif( aLinhas[ nLin ][ 2 ] == NIL, "", aLinhas[ nLin ][ 2 ] ), 40 ) )
         hb_DispOutAt( 6 + i, 16, PadR( cTexto, 48 ), ;
                       iif( nLin == nAtual, "N/W", "W/N" ) )
      NEXT
      Aviso( "ENTER seleciona · ESC desiste · " + hb_ntos( Len( aLinhas ) ) + " registro(s)" )

      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC
         Limpa()
         RETURN NIL
      CASE nTecla == K_ENTER
         Limpa()
         RETURN aLinhas[ nAtual ][ 1 ]
      CASE nTecla == K_DOWN  ; nAtual := Min( nAtual + 1, Len( aLinhas ) )
      CASE nTecla == K_UP    ; nAtual := Max( nAtual - 1, 1 )
      CASE nTecla == K_PGDN  ; nAtual := Min( nAtual + nAltura, Len( aLinhas ) )
      CASE nTecla == K_PGUP  ; nAtual := Max( nAtual - nAltura, 1 )
      CASE nTecla == K_HOME  ; nAtual := 1
      CASE nTecla == K_END   ; nAtual := Len( aLinhas )
      ENDCASE

      IF nAtual < nTopo
         nTopo := nAtual
      ELSEIF nAtual > nTopo + nAltura - 1
         nTopo := nAtual - nAltura + 1
      ENDIF
   ENDDO

   RETURN NIL
