/*
 * menu.prg — FASE G, onda 1
 *
 * Menu horizontal de 5 grupos com submenus, reproduzindo a navegação do legado
 * (04-FLUXOS.md §2), inclusive o detalhe que a torna contínua: dentro de um
 * submenu, ← e → FECHAM o submenu e movem o menu horizontal. Quem usava o
 * sistema navegava assim, e mudar isso seria mudar comportamento sem motivo.
 *
 * A definição do menu é DADO, não código de desenho — assim ela pode ser
 * verificada por teste sem terminal, e os destinos ainda não implementados
 * ficam declarados em vez de escondidos.
 */

#include "inkey.ch"

#define LINHA_MENU   2

/*
 * Cada grupo: { titulo, coluna, itens }
 * Cada item:  { titulo, acao }  — acao NIL = ainda não implementado
 *
 * As colunas 1, 17, 33, 49 e 63 são as do legado (04-FLUXOS.md §2).
 */
FUNCTION MenuDefinicao()
   RETURN { ;
      { "titulo" => "Clientes", "coluna" => 1, "itens" => { ;
         { "titulo" => "Manutenção", "acao" => "cliente.manutencao" }, ;
         { "titulo" => "Consulta"  , "acao" => "cliente.consulta"   }, ;
         { "titulo" => "Relatório" , "acao" => "cliente.relatorio"  } } }, ;
      { "titulo" => "Funcionários", "coluna" => 17, "itens" => { ;
         { "titulo" => "Manutenção", "acao" => "funcionario.manutencao" }, ;
         { "titulo" => "Consulta"  , "acao" => "funcionario.consulta"   }, ;
         { "titulo" => "Relatório" , "acao" => "funcionario.relatorio"  } } }, ;
      { "titulo" => "Fornecedores", "coluna" => 33, "itens" => { ;
         { "titulo" => "Manutenção", "acao" => "fornecedor.manutencao" }, ;
         { "titulo" => "Consulta"  , "acao" => "fornecedor.consulta"   }, ;
         { "titulo" => "Relatório" , "acao" => "fornecedor.relatorio"  } } }, ;
      { "titulo" => "Serviços", "coluna" => 49, "itens" => { ;
         { "titulo" => "Venda de peças"   , "acao" => "venda.pecas"  }, ;
         { "titulo" => "Reparo de autos"  , "acao" => "venda.reparo"  }, ;
         { "titulo" => "Pronta entrega"   , "acao" => "venda.pronta"  }, ;
         { "titulo" => "Consórcio"        , "acao" => "consorcio" }, ;
         { "titulo" => "Comissões"        , "acao" => NIL }, ;
         { "titulo" => "Relatórios"       , "acao" => "relatorio.servicos" } } }, ;
      { "titulo" => "Estoques", "coluna" => 63, "itens" => { ;
         { "titulo" => "Peças"        , "acao" => "peca.manutencao"         }, ;
         { "titulo" => "Almoxarifado" , "acao" => "almoxarifado.manutencao" }, ;
         { "titulo" => "Frota"        , "acao" => "modelo.manutencao"       }, ;
         { "titulo" => "Relatórios"   , "acao" => "relatorio.estoques" }, ;
         { "titulo" => "Gráficos"     , "acao" => "graficos" } } } }

/* Quantos destinos existem, e quantos já têm ação — para o resumo de estado. */
FUNCTION MenuCobertura( bImplementada )

   LOCAL aDef := MenuDefinicao(), i, j, nTotal := 0, nFeitos := 0, xAcao

   hb_default( @bImplementada, {| x | x != NIL } )

   FOR i := 1 TO Len( aDef )
      FOR j := 1 TO Len( aDef[ i ][ "itens" ] )
         nTotal++
         xAcao := aDef[ i ][ "itens" ][ j ][ "acao" ]
         IF xAcao != NIL .AND. Eval( bImplementada, xAcao )
            nFeitos++
         ENDIF
      NEXT
   NEXT

   RETURN { "total" => nTotal, "implementados" => nFeitos }

/*
 * Laço do menu principal. bDespachar recebe a ação (texto) e a executa;
 * devolver .F. encerra o sistema.
 */
PROCEDURE MenuPrincipal( bDespachar, bImplementada )

   LOCAL aDef := MenuDefinicao(), nGrupo := 1, nTecla, xAcao

   /* o marcador "·" tem de dizer a verdade: um destino declarado mas ainda sem
      implementação não pode aparecer como pronto */
   hb_default( @bImplementada, {| x | x != NIL } )

   DO WHILE .T.
      MenuDesenhar( aDef, nGrupo )
      nTecla := Inkey( 0 )

      DO CASE
      CASE nTecla == K_RIGHT
         nGrupo := iif( nGrupo == Len( aDef ), 1, nGrupo + 1 )
      CASE nTecla == K_LEFT
         nGrupo := iif( nGrupo == 1, Len( aDef ), nGrupo - 1 )
      CASE nTecla == K_DOWN .OR. nTecla == K_ENTER
         /* o submenu devolve: NIL = ESC · "<-" / "->" = mover o grupo ·
            outro = ação escolhida. É assim que a navegação fica contínua. */
         xAcao := MenuSubmenu( aDef[ nGrupo ], bImplementada )
         DO CASE
         CASE xAcao == NIL
         CASE xAcao == "->"
            nGrupo := iif( nGrupo == Len( aDef ), 1, nGrupo + 1 )
         CASE xAcao == "<-"
            nGrupo := iif( nGrupo == 1, Len( aDef ), nGrupo - 1 )
         OTHERWISE
            IF !Eval( bDespachar, xAcao )
               RETURN
            ENDIF
         ENDCASE
      CASE nTecla == K_ESC .OR. nTecla == K_ALT_X
         IF Confirma( "Encerrar o sistema?" )
            RETURN
         ENDIF
      ENDCASE
   ENDDO

   RETURN

STATIC PROCEDURE MenuDesenhar( aDef, nGrupo )

   LOCAL i

   TelaCabecalho( "" )
   FOR i := 1 TO Len( aDef )
      hb_DispOutAt( LINHA_MENU, aDef[ i ][ "coluna" ], ;
         " " + PadR( aDef[ i ][ "titulo" ], 13 ) + " ", ;
         iif( i == nGrupo, "N/W", "W/N" ) )
   NEXT
   Aviso( "← → escolhe o grupo · ↓ ou ENTER abre · ESC encerra" )

   RETURN

STATIC FUNCTION MenuSubmenu( hGrupo, bImplementada )

   LOCAL aItens := hGrupo[ "itens" ], nAtual := 1, nTecla, i, lPronto
   LOCAL nTopo := LINHA_MENU + 1, nEsq := hGrupo[ "coluna" ]
   LOCAL nLarg := 26

   Borda( nTopo, nEsq, nTopo + Len( aItens ) + 1, nEsq + nLarg )

   DO WHILE .T.
      FOR i := 1 TO Len( aItens )
         lPronto := aItens[ i ][ "acao" ] != NIL .AND. ;
                    Eval( bImplementada, aItens[ i ][ "acao" ] )
         hb_DispOutAt( nTopo + i, nEsq + 1, ;
            " " + PadR( aItens[ i ][ "titulo" ], nLarg - 3 ) + ;
            iif( lPronto, " ", "·" ), ;
            iif( i == nAtual, "N/W", "W/N" ) )
      NEXT
      Aviso( "ENTER escolhe · ← → muda de grupo · ESC volta · · = não implementado" )

      nTecla := Inkey( 0 )
      DO CASE
      CASE nTecla == K_ESC
         RETURN NIL
      CASE nTecla == K_RIGHT
         RETURN "->"
      CASE nTecla == K_LEFT
         RETURN "<-"
      CASE nTecla == K_DOWN
         nAtual := iif( nAtual == Len( aItens ), 1, nAtual + 1 )
      CASE nTecla == K_UP
         nAtual := iif( nAtual == 1, Len( aItens ), nAtual - 1 )
      CASE nTecla == K_ENTER
         IF aItens[ nAtual ][ "acao" ] == NIL .OR. ;
            !Eval( bImplementada, aItens[ nAtual ][ "acao" ] )
            Mensagem( "'" + aItens[ nAtual ][ "titulo" ] + ;
                      "' ainda não foi implementado (FASE G, ondas 2 a 8)" )
         ELSE
            RETURN aItens[ nAtual ][ "acao" ]
         ENDIF
      ENDCASE
   ENDDO

   RETURN NIL
