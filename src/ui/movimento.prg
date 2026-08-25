/*
 * movimento.prg — FASE G, onda 5
 *
 * Telas de venda de peças (balcão), reparo e pronta entrega.
 *
 * Fina de propósito: quem valida, calcula e grava é services/venda.prg. Esta
 * camada coleta, mostra e confirma. É o que permite que a regra inteira do
 * movimento esteja coberta por teste sem terminal nenhum.
 */

#include "inkey.ch"
#include "setcurs.ch"

/* cOrigem: "BALCAO" ou "REPARO" */
FUNCTION MovimentoVendaPeca( pDb, cOrigem )

   LOCAL nCodCli, hCli, hVenda, nCodFun, nTecla, hRes, cTitulo

   cTitulo := iif( cOrigem == "BALCAO", "Venda de Peças (Balcão)", "Reparo de Automóveis" )
   TelaCabecalho( cTitulo )

   nCodCli := MovimentoPedirCliente( pDb, cOrigem )
   IF nCodCli == NIL
      RETURN NIL
   ENDIF
   hCli := VendaConferirCliente( pDb, nCodCli, cOrigem )

   nCodFun := SelecionarCodigo( pDb, "funcionario" )

   hVenda := VendaNova( cOrigem, nCodCli, hCli[ "nome" ], nCodFun )

   DO WHILE .T.
      MovimentoDesenhar( hVenda, cTitulo, hCli[ "nome" ] )
      Aviso( "F2 grava · INS acrescenta item · DEL remove o último · ESC desiste" )
      nTecla := Inkey( 0 )

      DO CASE
      CASE nTecla == K_ESC
         IF Len( hVenda[ "itens" ] ) == 0 .OR. Confirma( "Abandonar esta venda?" )
            RETURN NIL
         ENDIF
      CASE nTecla == K_INS
         MovimentoAcrescentarItem( pDb, hVenda )
      CASE nTecla == K_DEL
         IF Len( hVenda[ "itens" ] ) > 0
            VendaRemoverItem( hVenda, Len( hVenda[ "itens" ] ) )
         ENDIF
      CASE nTecla == K_F2
         hRes := VendaGravar( pDb, hVenda )
         IF hRes[ "ok" ]
            Mensagem( "Venda registrada — total " + ;
                      BrowseMoeda( VendaPecaTotal( hVenda ) ) )
            RETURN hRes[ "id" ]
         ENDIF
         Mensagem( Left( StrTran( hRes[ "mensagem" ], hb_eol(), " · " ), 76 ) )
      ENDCASE
   ENDDO

   RETURN NIL

/*
 * RN-024 / D-06 — cliente não cadastrado: oferece cadastrar em linha e, ao
 * voltar, REFAZ a busca. No legado o fluxo seguia sem refazer o SEEK, lendo o
 * nome de uma área que o cadastro havia fechado.
 */
STATIC FUNCTION MovimentoPedirCliente( pDb, cOrigem )

   LOCAL nCodCli, hCli

   DO WHILE .T.
      nCodCli := SelecionarCodigo( pDb, "cliente" )
      IF nCodCli == NIL
         RETURN NIL
      ENDIF
      hCli := VendaConferirCliente( pDb, nCodCli, cOrigem )
      IF hCli[ "existe" ]
         RETURN nCodCli
      ENDIF

      IF !hCli[ "oferecer_cadastro" ]
         Mensagem( "Cliente não cadastrado" )
         LOOP
      ENDIF
      IF !Confirma( "Cliente não cadastrado. Deseja cadastrá-lo?" )
         LOOP
      ENDIF

      CadastroManutencao( pDb, ClienteDescritor() )
      /* D-06: refaz a consulta em vez de presumir que o cadastro aconteceu */
      hCli := VendaConferirCliente( pDb, nCodCli, cOrigem )
      IF hCli[ "existe" ]
         RETURN nCodCli
      ENDIF
   ENDDO

   RETURN NIL

STATIC PROCEDURE MovimentoAcrescentarItem( pDb, hVenda )

   LOCAL nCodPec, cQtd, hV

   nCodPec := SelecionarCodigo( pDb, "peca" )
   IF nCodPec == NIL
      RETURN
   ENDIF

   cQtd := Space( 5 )
   Limpa()
   hb_DispOutAt( 23, 1, "Quantidade: " )
   SetCursor( SC_NORMAL )
   @ 23, 13 GET cQtd PICTURE "99999"
   READ
   SetCursor( SC_NONE )
   Limpa()
   IF LastKey() == K_ESC
      RETURN
   ENDIF

   hV := VendaAdicionarItem( pDb, hVenda, nCodPec, Val( AllTrim( cQtd ) ) )
   IF !ValOk( hV )
      TelaValidacao( hV )
      RETURN
   ENDIF
   /* RN-028 — estouro do mínimo é alerta com confirmação, não bloqueio.
      Se o operador recusar, o item sai da venda. */
   IF ValTemAviso( hV )
      IF !Confirma( Left( hV[ "avisos" ][ 1 ][ "mensagem" ], 66 ) )
         VendaRemoverItem( hVenda, Len( hVenda[ "itens" ] ) )
      ENDIF
   ENDIF

   RETURN

STATIC PROCEDURE MovimentoDesenhar( hVenda, cTitulo, cNomeCli )

   LOCAL i, hItem, nLin := 8

   TelaCabecalho( cTitulo )
   hb_DispOutAt( 4, 2, "Cliente: " + PadR( hb_ntos( hVenda[ "cod_cli" ] ) + " — " + ;
                 iif( cNomeCli == NIL, "", cNomeCli ), 45 ) )
   hb_DispOutAt( 5, 2, "Vendedor: " + iif( hVenda[ "cod_fun" ] == NIL, "(nenhum)", ;
                 hb_ntos( hVenda[ "cod_fun" ] ) ) )
   hb_DispOutAt( 7, 2, PadR( "Cód  Descrição                        Qtde      Unit.    Subtotal", 76 ), "N/W" )

   FOR i := 1 TO Len( hVenda[ "itens" ] )
      IF nLin > 20
         EXIT
      ENDIF
      hItem := hVenda[ "itens" ][ i ]
      hb_DispOutAt( nLin, 2, ;
         PadL( hb_ntos( hItem[ "cod_pec" ] ), 4 ) + " " + ;
         PadR( Left( hItem[ "descricao" ], 32 ), 33 ) + ;
         PadL( hb_ntos( hItem[ "quantidade" ] ), 5 ) + " " + ;
         PadL( BrowseMoeda( hItem[ "valor_unit_cent" ] ), 11 ) + " " + ;
         PadL( BrowseMoeda( hItem[ "subtotal_cent" ] ), 11 ) )
      nLin++
   NEXT

   hb_DispOutAt( 21, 2, PadR( "", 76 ) )
   hb_DispOutAt( 21, 2, PadL( "TOTAL: " + BrowseMoeda( VendaPecaTotal( hVenda ) ), 76 ), "N/W" )

   RETURN

/* ------------------------------------------------------------------ */

FUNCTION MovimentoProntaEntrega( pDb )

   LOCAL nCodCli, nCodCar, nCodFun, hMod, hCli, hDados, hRes, hF

   TelaCabecalho( "Venda de Veículo — Pronta Entrega" )

   /* RN-025 — aqui NÃO há cadastro de cliente em linha */
   nCodCli := SelecionarCodigo( pDb, "cliente" )
   IF nCodCli == NIL
      RETURN NIL
   ENDIF
   hCli := VendaConferirCliente( pDb, nCodCli, "VEICULO" )
   IF !hCli[ "existe" ]
      Mensagem( "Cliente não cadastrado" )
      RETURN NIL
   ENDIF

   nCodCar := SelecionarCodigo( pDb, "modelo_veiculo" )
   IF nCodCar == NIL
      RETURN NIL
   ENDIF
   hMod := VendaModeloDados( pDb, nCodCar )
   IF hMod == NIL
      Mensagem( "Modelo não cadastrado" )
      RETURN NIL
   ENDIF
   IF hMod[ "qtd_estoque" ] <= 0
      Mensagem( "Não há unidades deste modelo em estoque" )
      RETURN NIL
   ENDIF

   nCodFun := SelecionarCodigo( pDb, "funcionario" )
   IF nCodFun == NIL
      Mensagem( "A venda de veículo exige o funcionário" )
      RETURN NIL
   ENDIF

   TelaCabecalho( "Venda de Veículo — Pronta Entrega" )
   hb_DispOutAt( 4, 2, "Cliente : " + hCli[ "nome" ] )
   hb_DispOutAt( 5, 2, "Modelo  : " + hMod[ "descricao" ] + ;
                 "   (" + hb_ntos( hMod[ "qtd_estoque" ] ) + " em estoque)" )

   hF := FormNovo( "Pronta entrega" )
   FormCampo( hF, "valor", "Valor", "$", 7, 2, 14, NIL, ;
              AllTrim( BrowseMoeda( hMod[ "valor_cent" ] ) ) )
   FormCampo( hF, "forma", "Forma de pgto", "C", 8, 2, 20, NIL, "" )
   FormCampo( hF, "data", "Data", "D", 9, 2, 10, NIL, hb_DToC( Date(), "YYYY-MM-DD" ) )
   IF !FormEditar( hF )
      RETURN NIL
   ENDIF

   hDados := { ;
      "cod_car"         => nCodCar, ;
      "cod_cli"         => nCodCli, ;
      "cod_fun"         => nCodFun, ;
      "data_venda"      => FormValor( hF, "data" ), ;
      "valor_cent"      => ValReais( FormValor( hF, "valor" ), "Valor" )[ "valor" ], ;
      "forma_pagamento" => FormValor( hF, "forma" ), ;
      "descricao"       => hMod[ "descricao" ], ;
      "nome_cli"        => hCli[ "nome" ], ;
      "nome_fun"        => VendaNomeFuncionario( pDb, nCodFun ) }

   hRes := VendaVeiculoRegistrar( pDb, hDados )
   IF !hRes[ "ok" ]
      Mensagem( Left( StrTran( hRes[ "mensagem" ], hb_eol(), " · " ), 76 ) )
      RETURN NIL
   ENDIF

   Mensagem( "Venda registrada — comissão de " + ;
             BrowseMoeda( ComissaoProntaEntrega( hDados[ "valor_cent" ] ) ) + ;
             " creditada" )
   /* RN-035 — aviso informativo, não impede nada */
   IF hRes[ "ultimo" ]
      Mensagem( "ATENÇÃO: último veículo deste modelo foi vendido" )
   ENDIF

   RETURN hRes[ "id" ]
