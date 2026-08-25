/*
 * tela_consorcio.prg — FASE G, onda 6
 *
 * Telas do consórcio: adesão, baixa de prestações, contemplação e consulta.
 * Fina de propósito — quem decide é services/consorcio.prg.
 *
 * (O nome do arquivo evita colidir com models/consorcio_cota.prg e
 * services/consorcio.prg: o hbmk2 nomeia os objetos pelo nome BASE do fonte.)
 */

#include "inkey.ch"
#include "setcurs.ch"

FUNCTION ConsorcioMenu( pDb )

   LOCAL aOp := { "Adesão", "Baixa de prestações", "Contemplação (sorteio)", ;
                  "Consultar grupo", "Voltar" }
   LOCAL nAtual := 1, nTecla, i

   DO WHILE .T.
      TelaCabecalho( "Consórcio" )
      Borda( 6, 26, 6 + Len( aOp ) + 1, 55 )
      DO WHILE .T.
         FOR i := 1 TO Len( aOp )
            hb_DispOutAt( 6 + i, 27, " " + PadR( aOp[ i ], 27 ), ;
                          iif( i == nAtual, "N/W", "W/N" ) )
         NEXT
         Aviso( "↑ ↓ escolhe · ENTER confirma · ESC volta" )
         nTecla := Inkey( 0 )
         DO CASE
         CASE nTecla == K_ESC   ; RETURN NIL
         CASE nTecla == K_DOWN  ; nAtual := iif( nAtual == Len( aOp ), 1, nAtual + 1 )
         CASE nTecla == K_UP    ; nAtual := iif( nAtual == 1, Len( aOp ), nAtual - 1 )
         CASE nTecla == K_ENTER ; EXIT
         ENDCASE
      ENDDO

      DO CASE
      CASE nAtual == 1 ; ConsorcioTelaAdesao( pDb )
      CASE nAtual == 2 ; ConsorcioTelaPrestacoes( pDb )
      CASE nAtual == 3 ; ConsorcioTelaContemplacao( pDb )
      CASE nAtual == 4 ; ConsorcioTelaConsulta( pDb )
      OTHERWISE        ; RETURN NIL
      ENDCASE
   ENDDO

   RETURN NIL

STATIC PROCEDURE ConsorcioTelaAdesao( pDb )

   LOCAL nCodCar, nCodCli, nCodFun, hPrep, hF, hDados, hRes, cNomeCli

   TelaCabecalho( "Consórcio — Adesão" )

   nCodCar := SelecionarCodigo( pDb, "modelo_veiculo" )
   IF nCodCar == NIL
      RETURN
   ENDIF
   hPrep := ConsorcioPreparar( pDb, nCodCar )
   IF !hPrep[ "ok" ]
      Mensagem( hPrep[ "mensagem" ] )
      RETURN
   ENDIF

   nCodCli := SelecionarCodigo( pDb, "cliente" )
   IF nCodCli == NIL
      RETURN
   ENDIF
   cNomeCli := LookupDescricao( pDb, "cliente", nCodCli )

   TelaCabecalho( "Consórcio — Adesão" )
   hb_DispOutAt( 4, 2, "Modelo ......: " + hPrep[ "descricao" ] )
   hb_DispOutAt( 5, 2, "Consorciado .: " + iif( cNomeCli == NIL, "", cNomeCli ) )
   hb_DispOutAt( 6, 2, "Grupo .......: " + hb_ntos( hPrep[ "cod_gru" ] ) + ;
                 iif( hPrep[ "novo" ], "  (novo)", "  (em formação)" ) )
   hb_DispOutAt( 7, 2, "Participante : " + hb_ntos( hPrep[ "num_participante" ] ) )

   /*
    * RN-014 — em grupo existente os parâmetros são herdados e NÃO editáveis;
    * no legado apareciam na tela só para conferência (CLEAR GETS).
    */
   IF hPrep[ "editavel" ]
      hF := FormNovo( "Adesão" )
      FormCampo( hF, "participantes", "Nº participantes", "N", 9, 2, 5, NIL, 0 )
      FormCampo( hF, "prestacao", "Valor prestação", "$", 10, 2, 14, NIL, ;
                 AllTrim( BrowseMoeda( hPrep[ "valor_prestacao_cent" ] ) ) )
      IF !FormEditar( hF )
         RETURN
      ENDIF
   ELSE
      hb_DispOutAt( 9, 2, "Nº participantes: " + ;
                    hb_ntos( hPrep[ "num_participantes_previsto" ] ) + "   (herdado)" )
      hb_DispOutAt( 10, 2, "Valor prestação.: " + ;
                    BrowseMoeda( hPrep[ "valor_prestacao_cent" ] ) + "   (herdado)" )
      IF !Confirma( "Confirma a adesão?" )
         RETURN
      ENDIF
   ENDIF

   hDados := { ;
      "novo"                       => hPrep[ "novo" ], ;
      "cod_gru"                    => hPrep[ "cod_gru" ], ;
      "num_participante"           => hPrep[ "num_participante" ], ;
      "cod_cli"                    => nCodCli, ;
      "cod_car"                    => nCodCar, ;
      "data_adesao"                => hPrep[ "data_adesao" ], ;
      "nome_cli"                   => cNomeCli }

   IF hPrep[ "editavel" ]
      hDados[ "num_participantes_previsto" ] := FormValor( hF, "participantes" )
      hDados[ "valor_prestacao_cent" ] := ;
         ValReais( FormValor( hF, "prestacao" ), "Valor" )[ "valor" ]
   ELSE
      hDados[ "num_participantes_previsto" ] := hPrep[ "num_participantes_previsto" ]
      hDados[ "valor_prestacao_cent" ] := hPrep[ "valor_prestacao_cent" ]
   ENDIF

   hRes := ConsorcioAderir( pDb, hDados )
   IF !hRes[ "ok" ]
      Mensagem( Left( StrTran( hRes[ "mensagem" ], hb_eol(), " · " ), 76 ) )
      RETURN
   ENDIF

   /* RN-032 — comissão de 0,15% da prestação, se houver vendedor */
   nCodFun := SelecionarCodigo( pDb, "funcionario" )
   IF nCodFun != NIL
      ConsorcioCreditarComissao( pDb, nCodFun, hDados[ "valor_prestacao_cent" ] )
   ENDIF

   Mensagem( "Adesão registrada — grupo " + hb_ntos( hDados[ "cod_gru" ] ) + ;
             ", participante " + hb_ntos( hDados[ "num_participante" ] ) )
   IF hRes[ "fechou_grupo" ]
      Mensagem( "Grupo " + hb_ntos( hDados[ "cod_gru" ] ) + " FECHADO — " + ;
                "o número de participantes previsto foi atingido" )
   ENDIF

   RETURN

STATIC PROCEDURE ConsorcioTelaPrestacoes( pDb )

   LOCAL hCota, nGru, nPart, cQtd, hRes

   TelaCabecalho( "Consórcio — Baixa de prestações" )
   IF !ConsorcioPedirCota( pDb, @nGru, @nPart, @hCota )
      RETURN
   ENDIF

   hb_DispOutAt( 9, 2, "Prestações restantes: " + ;
                 iif( hCota[ "parcelas_restantes" ] == NIL, ;
                      "(inválido: " + hb_ValToStr( hCota[ "parcelas_restantes_legado" ] ) + ")", ;
                      hb_ntos( hCota[ "parcelas_restantes" ] ) ) )

   cQtd := Space( 3 )
   Limpa()
   hb_DispOutAt( 23, 1, "Prestações pagas: " )
   SetCursor( SC_NORMAL )
   @ 23, 19 GET cQtd PICTURE "999"
   READ
   SetCursor( SC_NONE )
   Limpa()
   IF LastKey() == K_ESC
      RETURN
   ENDIF

   hRes := ConsorcioBaixarPrestacoes( pDb, nGru, nPart, Val( AllTrim( cQtd ) ) )
   IF !hRes[ "ok" ]
      Mensagem( Left( StrTran( hRes[ "mensagem" ], hb_eol(), " · " ), 76 ) )
      RETURN
   ENDIF
   Mensagem( "Baixa registrada — restam " + hb_ntos( hRes[ "saldo" ] ) + " prestações" )
   /* RN-021 — mensagem do legado, preservada */
   IF hRes[ "quitou" ]
      Mensagem( "Todas as prestações já quitadas!" )
   ENDIF

   RETURN

STATIC PROCEDURE ConsorcioTelaContemplacao( pDb )

   LOCAL hCota, nGru, nPart, hRes, lSorteado

   TelaCabecalho( "Consórcio — Contemplação" )
   IF !ConsorcioPedirCota( pDb, @nGru, @nPart, @hCota )
      RETURN
   ENDIF

   hb_DispOutAt( 9, 2, "Situação atual: " + ;
                 iif( hCota[ "sorteado" ] == 1, "SORTEADO", "não sorteado" ) )

   /* RN-022 — o sistema não sorteia; registra o resultado de um sorteio externo */
   lSorteado := Confirma( "Este consorciado foi sorteado?" )

   hRes := ConsorcioContemplar( pDb, nGru, nPart, lSorteado )
   IF !hRes[ "ok" ]
      Mensagem( Left( hRes[ "mensagem" ], 76 ) )
      RETURN
   ENDIF

   Mensagem( "Contemplação registrada" + ;
             iif( hRes[ "baixou_estoque" ], " — uma unidade baixada do estoque", "" ) )
   IF hRes[ "aviso" ] != NIL
      Mensagem( hRes[ "aviso" ] )
   ENDIF

   RETURN

STATIC PROCEDURE ConsorcioTelaConsulta( pDb )

   LOCAL nGru, aCotas, i, nLin := 7, aC

   TelaCabecalho( "Consórcio — Consulta de grupo" )
   nGru := ConsorcioPedirGrupo( pDb )
   IF nGru == NIL
      RETURN
   ENDIF

   aCotas := ConsorcioCotasDoGrupo( pDb, nGru )
   IF Len( aCotas ) == 0
      Mensagem( "Grupo " + hb_ntos( nGru ) + " não tem cotas" )
      RETURN
   ENDIF

   TelaCabecalho( "Consórcio — Grupo " + hb_ntos( nGru ) )
   hb_DispOutAt( 6, 2, PadR( "  Nº  Cliente                          Restam  Sort  Quit", 76 ), "N/W" )
   FOR i := 1 TO Len( aCotas )
      IF nLin > 21
         EXIT
      ENDIF
      aC := aCotas[ i ]
      hb_DispOutAt( nLin, 2, ;
         PadL( hb_ValToStr( aC[ 1 ] ), 4 ) + "  " + ;
         PadR( Left( iif( aC[ 3 ] == NIL, "", aC[ 3 ] ), 32 ), 33 ) + ;
         PadL( iif( aC[ 4 ] == NIL, "?", hb_ValToStr( aC[ 4 ] ) ), 6 ) + ;
         PadL( iif( aC[ 5 ] == 1, "S", "-" ), 6 ) + ;
         PadL( iif( aC[ 6 ] == 1, "S", "-" ), 6 ) )
      nLin++
   NEXT
   Mensagem( hb_ntos( Len( aCotas ) ) + " cota(s) — pressione uma tecla" )

   RETURN

/* ------------------------------------------------------------------ */

STATIC FUNCTION ConsorcioPedirGrupo( pDb )

   LOCAL cBuf := Space( 5 )

   Limpa()
   hb_DispOutAt( 23, 1, "Grupo: " )
   SetCursor( SC_NORMAL )
   @ 23, 8 GET cBuf PICTURE "99999"
   READ
   SetCursor( SC_NONE )
   Limpa()
   IF LastKey() == K_ESC .OR. Empty( AllTrim( cBuf ) )
      RETURN NIL
   ENDIF

   RETURN Val( AllTrim( cBuf ) )

STATIC FUNCTION ConsorcioPedirCota( pDb, nGru, nPart, hCota )

   LOCAL cBuf := Space( 3 )

   nGru := ConsorcioPedirGrupo( pDb )
   IF nGru == NIL
      RETURN .F.
   ENDIF

   Limpa()
   hb_DispOutAt( 23, 1, "Participante: " )
   SetCursor( SC_NORMAL )
   @ 23, 15 GET cBuf PICTURE "999"
   READ
   SetCursor( SC_NONE )
   Limpa()
   IF LastKey() == K_ESC .OR. Empty( AllTrim( cBuf ) )
      RETURN .F.
   ENDIF
   nPart := Val( AllTrim( cBuf ) )

   hCota := ConsorcioCota( pDb, nGru, nPart )
   IF hCota == NIL
      Mensagem( "Consorciado não encontrado no grupo " + hb_ntos( nGru ) )
      RETURN .F.
   ENDIF

   hb_DispOutAt( 7, 2, "Grupo " + hb_ntos( nGru ) + ", participante " + ;
                 hb_ntos( nPart ) + " — " + ;
                 iif( hCota[ "nome_snapshot" ] == NIL, "", hCota[ "nome_snapshot" ] ) )

   RETURN .T.
