/*
 * consorcio.prg — FASE G, onda 6
 *
 * Regras do consórcio: RN-013 a RN-023. Divergências D-10, D-11, D-12, D-25.
 * Questões abertas que aparecem aqui: Q-08 e Q-09.
 *
 * É a área mais densa do sistema, e a que mais acumulou defeito no legado —
 * três dos cinco valores gravados em `NUMMES` no acervo são inválidos (`**`,
 * `-2`, `-3`), consequência direta de RN-020 subtrair sem piso em zero.
 */

/*
 * Prepara uma adesão. Devolve os parâmetros que a tela deve mostrar, já
 * decidindo entre grupo novo e grupo existente.
 *
 * RN-013 — se NÃO existe grupo em formação para o modelo, cria-se um novo, com
 * número vindo do sequencial global (ex-CVMGRUPO.MEM).
 * RN-014 — se existe, o novo consorciado HERDA os parâmetros do grupo: número,
 * quantidade de participantes prevista, valor da prestação e data. No legado
 * esses campos apareciam na tela apenas para conferência (CLEAR GETS).
 * RN-016 — na criação, o valor da prestação é pré-preenchido com o valor de
 * tabela do modelo. É o valor CHEIO do carro como prestação, não dividido pelo
 * número de meses. Se é intenção ou defeito, o legado não diz — Q-09. Fica
 * como está, e o valor é editável só na criação, como no legado.
 */
FUNCTION ConsorcioPreparar( pDb, nCodCar )

   LOCAL hGrupo, hMod

   hMod := VendaModeloDados( pDb, nCodCar )
   IF hMod == NIL
      RETURN { "ok" => .F., "mensagem" => "Modelo " + hb_ntos( nCodCar ) + ;
               " não cadastrado." }
   ENDIF

   hGrupo := ConsorcioGrupoAberto( pDb, nCodCar )
   IF hGrupo != NIL
      RETURN { "ok" => .T., "mensagem" => NIL, "novo" => .F., ;
               "cod_car" => nCodCar, "descricao" => hMod[ "descricao" ], ;
               "cod_gru" => hGrupo[ "cod_gru" ], ;
               "num_participante" => ConsorcioProximoParticipante( pDb, hGrupo[ "cod_gru" ] ), ;
               "num_participantes_previsto" => hGrupo[ "num_participantes_previsto" ], ;
               "valor_prestacao_cent" => hGrupo[ "valor_prestacao_cent" ], ;
               "parcelas_restantes" => hGrupo[ "parcelas_restantes" ], ;
               "data_adesao" => hGrupo[ "data_adesao" ], ;
               "editavel" => .F. }
   ENDIF

   /* grupo novo: o número só é CONSUMIDO na gravação — ver ConsorcioAderir */
   RETURN { "ok" => .T., "mensagem" => NIL, "novo" => .T., ;
            "cod_car" => nCodCar, "descricao" => hMod[ "descricao" ], ;
            "cod_gru" => ConsorcioSequencialGrupo( pDb ) + 1, ;
            "num_participante" => 1, ;
            "num_participantes_previsto" => 0, ;
            "valor_prestacao_cent" => hMod[ "valor_cent" ], ;
            "parcelas_restantes" => 0, ;
            "data_adesao" => hb_DToC( Date(), "YYYY-MM-DD" ), ;
            "editavel" => .T. }

/*
 * Efetiva a adesão, numa transação.
 *
 * RN-017 — o número de prestações é inicializado igual ao número de
 * participantes previsto. Consistente com a mecânica clássica de consórcio,
 * um contemplado por mês.
 * RN-019 — `sorteado` e `quitado` são inicializados EXPLICITAMENTE em 0. No
 * legado eles vinham do APPEND BLANK e ficavam .F. por acidente, porque a lista
 * de REPLACE da transferência simplesmente não os mencionava.
 * RN-018 — se esta adesão completa o grupo, ele é FECHADO na mesma transação.
 *
 * DIVERGÊNCIA DECLARADA — o número do grupo é consumido só aqui.
 * No legado, `SAVE TO cvmgrupo` acontecia ANTES da confirmação "Cadastrar
 * Consorciado": desistir da adesão queimava o número, que se perdia. Isso é
 * consequência da ordem das instruções, não regra — e produz buracos sem
 * significado na numeração. Aqui o sequencial só avança quando a cota existe.
 */
FUNCTION ConsorcioAderir( pDb, hDados )

   LOCAL hV, hRes, lFechou := .F.

   hV := ConsorcioValidarAdesao( pDb, hDados )
   IF !ValOk( hV )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "fechou_grupo" => .F. }
   ENDIF

   hRes := TransExecutar( pDb, {| | ConsorcioAderirTudo( pDb, hDados, @lFechou ) }, ;
                          "registrar a adesão ao consórcio" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], "validacao" => hV, ;
               "fechou_grupo" => .F. }
   ENDIF

   LogInfo( "adesão ao consórcio", "grupo=" + hb_ntos( hDados[ "cod_gru" ] ) + ;
            " participante=" + hb_ntos( hDados[ "num_participante" ] ) + ;
            iif( lFechou, " (grupo fechado)", "" ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV, ;
            "fechou_grupo" => lFechou }

STATIC FUNCTION ConsorcioAderirTudo( pDb, hDados, lFechou )

   LOCAL hCota, nRc, nCotas

   hCota := { ;
      "cod_gru"                    => hDados[ "cod_gru" ], ;
      "num_participante"           => hDados[ "num_participante" ], ;
      "cod_cli"                    => hDados[ "cod_cli" ], ;
      "cod_car"                    => hDados[ "cod_car" ], ;
      "valor_prestacao_cent"       => hDados[ "valor_prestacao_cent" ], ;
      "num_participantes_previsto" => hDados[ "num_participantes_previsto" ], ;
      "parcelas_restantes"         => hDados[ "num_participantes_previsto" ], ;
      "data_adesao"                => hDados[ "data_adesao" ], ;
      "grupo_fechado"              => 0, ;
      "sorteado"                   => 0, ;
      "quitado"                    => 0, ;
      "nome_snapshot"              => hDados[ "nome_cli" ] }

   nRc := ConsorcioCotaInserir( pDb, hCota )
   IF nRc != 0
      RETURN "Não foi possível gravar a cota: " + SqlErro( pDb )
   ENDIF

   IF hDados[ "novo" ]
      nRc := ConsorcioGravarSequencial( pDb, hDados[ "cod_gru" ] )
      IF nRc != 0
         RETURN "Não foi possível atualizar o sequencial de grupos: " + SqlErro( pDb )
      ENDIF
   ENDIF

   /* RN-018 — completou o previsto? fecha o grupo, aqui mesmo (D-12) */
   nCotas := ConsorcioContarCotas( pDb, hDados[ "cod_gru" ] )
   IF hDados[ "num_participantes_previsto" ] > 0 .AND. ;
      nCotas >= hDados[ "num_participantes_previsto" ]
      IF ConsorcioFecharGrupo( pDb, hDados[ "cod_gru" ] ) != 0
         RETURN "Não foi possível fechar o grupo: " + SqlErro( pDb )
      ENDIF
      lFechou := .T.
   ENDIF

   RETURN NIL

FUNCTION ConsorcioValidarAdesao( pDb, hDados )

   LOCAL hV := ValNovo(), hR

   IF hDados[ "cod_cli" ] == NIL
      ValErro( hV, "cod_cli", "Informe o consorciado." )
   ELSEIF !IntegExiste( pDb, "cliente", "cod_cli", hDados[ "cod_cli" ] )
      ValErro( hV, "cod_cli", "Cliente " + hb_ntos( hDados[ "cod_cli" ] ) + ;
               " não cadastrado." )
   ENDIF
   IF !IntegExiste( pDb, "modelo_veiculo", "cod_car", hDados[ "cod_car" ] )
      ValErro( hV, "cod_car", "Modelo não cadastrado." )
   ENDIF

   hR := ValQuantidade( hDados[ "num_participantes_previsto" ], "Nº de participantes" )
   IF !hR[ "ok" ]
      ValErro( hV, "num_participantes_previsto", hR[ "mensagem" ] )
   ELSEIF hDados[ "num_participantes_previsto" ] <= 0
      ValErro( hV, "num_participantes_previsto", ;
               "O número de participantes deve ser maior que zero." )
   ENDIF

   hR := ValMonetario( hDados[ "valor_prestacao_cent" ], "Valor da prestação" )
   IF !hR[ "ok" ]
      ValErro( hV, "valor_prestacao_cent", hR[ "mensagem" ] )
   ENDIF

   /* D-10 — a colisão de (grupo, participante) é barrada aqui e no schema */
   IF ConsorcioCota( pDb, hDados[ "cod_gru" ], hDados[ "num_participante" ] ) != NIL
      ValErro( hV, "num_participante", "Já existe o participante " + ;
               hb_ntos( hDados[ "num_participante" ] ) + " no grupo " + ;
               hb_ntos( hDados[ "cod_gru" ] ) + "." )
   ENDIF

   RETURN hV

/*
 * RN-020 / RN-021 — baixa de prestações e quitação.
 *
 * O legado fazia `mnumfal = mnummes - mnumfala` e gravava, sem piso. Informar
 * mais prestações do que as restantes produzia saldo NEGATIVO, e como NUMMES é
 * N(2,0) (faixa -9..99), valores fora estouravam e o Clipper gravava `*`. Está
 * nos dados: dos três registros de CVBGRUCO, um tem `**` e dois têm -2 e -3.
 *
 * Aqui a baixa maior que o saldo é RECUSADA (D-11). Saldo de prestações
 * negativo não significa nada — é a mesma natureza de D-27 para estoque.
 *
 * RN-021 — a quitação testa `= 0` EXATO, como no legado. Saldo negativo não
 * marcava quitação lá, e aqui saldo negativo nem existe.
 */
FUNCTION ConsorcioBaixarPrestacoes( pDb, nCodGru, nParticipante, nQuantidade )

   LOCAL hCota, hV := ValNovo(), hRes, nNovo, lQuitou := .F.

   hCota := ConsorcioCota( pDb, nCodGru, nParticipante )
   IF hCota == NIL
      ValErro( hV, "cota", "Consorciado não encontrado no grupo " + ;
               hb_ntos( nCodGru ) + "." )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "saldo" => NIL, "quitou" => .F. }
   ENDIF
   IF nQuantidade == NIL .OR. nQuantidade <= 0
      ValErro( hV, "quantidade", "A quantidade de prestações deve ser maior que zero." )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "saldo" => NIL, "quitou" => .F. }
   ENDIF

   /*
    * D-11 — a cota pode ter chegado da migração com parcelas_restantes NULL,
    * porque o valor original violava a restrição e foi para *_legado. Sem saldo
    * conhecido não há o que subtrair.
    */
   IF hCota[ "parcelas_restantes" ] == NIL
      ValErro( hV, "parcelas_restantes", "Esta cota veio do sistema antigo com " + ;
               "saldo inválido (" + hb_ValToStr( hCota[ "parcelas_restantes_legado" ] ) + ;
               "). Corrija o saldo antes de baixar prestações." )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "saldo" => NIL, "quitou" => .F. }
   ENDIF

   IF nQuantidade > hCota[ "parcelas_restantes" ]
      ValErro( hV, "quantidade", "Restam " + hb_ntos( hCota[ "parcelas_restantes" ] ) + ;
               " prestações e foram informadas " + hb_ntos( nQuantidade ) + "." )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "saldo" => hCota[ "parcelas_restantes" ], "quitou" => .F. }
   ENDIF

   nNovo := hCota[ "parcelas_restantes" ] - nQuantidade

   hRes := TransExecutar( pDb, ;
      {| | ConsorcioBaixarTudo( pDb, hCota[ "id" ], nNovo, @lQuitou ) }, ;
      "baixar as prestações" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], "validacao" => hV, ;
               "saldo" => NIL, "quitou" => .F. }
   ENDIF

   LogInfo( "baixa de prestações", "grupo=" + hb_ntos( nCodGru ) + ;
            " participante=" + hb_ntos( nParticipante ) + ;
            " baixadas=" + hb_ntos( nQuantidade ) + " saldo=" + hb_ntos( nNovo ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV, ;
            "saldo" => nNovo, "quitou" => lQuitou }

STATIC FUNCTION ConsorcioBaixarTudo( pDb, nId, nNovo, lQuitou )

   IF ConsorcioAtualizarCota( pDb, nId, "parcelas_restantes", nNovo ) != 0
      RETURN "Não foi possível gravar o saldo: " + SqlErro( pDb )
   ENDIF

   /* RN-021 — teste de igualdade exata com zero, como no legado */
   IF nNovo == 0
      IF ConsorcioAtualizarCota( pDb, nId, "quitado", 1 ) != 0
         RETURN "Não foi possível marcar a quitação: " + SqlErro( pDb )
      ENDIF
      lQuitou := .T.
   ENDIF

   RETURN NIL

/*
 * RN-022 / RN-023 — contemplação.
 *
 * O sistema NÃO sorteia: apenas registra o resultado de um sorteio externo.
 *
 * A baixa de estoque tem uma sutileza preservada do legado: se o modelo estiver
 * esgotado, a unidade NÃO é baixada, o aviso é exibido — e a marca de sorteado
 * PERMANECE. No legado isso acontecia porque o REPLACE de SORT vinha ANTES do
 * teste de estoque, e não há reversão. O documento classifica como possível
 * inconsistência [INFERIDA], sem decidir; então fica como está, e o resultado
 * diz explicitamente que a marca foi gravada sem baixa.
 */
FUNCTION ConsorcioContemplar( pDb, nCodGru, nParticipante, lSorteado )

   LOCAL hCota, hRes, lBaixou := .F., cAviso := NIL

   hCota := ConsorcioCota( pDb, nCodGru, nParticipante )
   IF hCota == NIL
      RETURN { "ok" => .F., "mensagem" => "Consorciado não encontrado.", ;
               "baixou_estoque" => .F., "aviso" => NIL }
   ENDIF

   hRes := TransExecutar( pDb, ;
      {| | ConsorcioContemplarTudo( pDb, hCota, lSorteado, @lBaixou, @cAviso ) }, ;
      "registrar a contemplação" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], ;
               "baixou_estoque" => .F., "aviso" => NIL }
   ENDIF

   LogInfo( "contemplação registrada", "grupo=" + hb_ntos( nCodGru ) + ;
            " participante=" + hb_ntos( nParticipante ) + ;
            " sorteado=" + iif( lSorteado, "S", "N" ) + ;
            " baixou=" + iif( lBaixou, "S", "N" ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "baixou_estoque" => lBaixou, ;
            "aviso" => cAviso }

STATIC FUNCTION ConsorcioContemplarTudo( pDb, hCota, lSorteado, lBaixou, cAviso )

   LOCAL hSaldo, hBaixa

   IF ConsorcioAtualizarCota( pDb, hCota[ "id" ], "sorteado", ;
                              iif( lSorteado, 1, 0 ) ) != 0
      RETURN "Não foi possível gravar a contemplação: " + SqlErro( pDb )
   ENDIF

   IF !lSorteado
      RETURN NIL
   ENDIF

   hSaldo := EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", hCota[ "cod_car" ] )
   IF hSaldo == NIL .OR. hSaldo[ "atual" ] <= 0
      /* RN-023 — esgotado: não baixa, avisa, e a marca de sorteado permanece */
      cAviso := "Quantidade esgotada. Aguarde aproximadamente 10 dias pelo carro."
      RETURN NIL
   ENDIF

   hBaixa := EstoqueBaixarVeiculo( pDb, hCota[ "cod_car" ], 1 )
   IF !hBaixa[ "ok" ]
      RETURN hBaixa[ "mensagem" ]
   ENDIF
   lBaixou := .T.
   IF hBaixa[ "ultimo" ]
      cAviso := "Último veículo deste modelo foi entregue."
   ENDIF

   RETURN NIL

/* RN-032 — comissão do consórcio: 0,15% da prestação, creditada na adesão. */
FUNCTION ConsorcioCreditarComissao( pDb, nCodFun, nPrestacaoCent )
   RETURN ComissaoCreditar( pDb, nCodFun, ComissaoConsorcio( nPrestacaoCent ) )
