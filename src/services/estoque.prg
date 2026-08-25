/*
 * estoque.prg — FASE G, onda 4
 *
 * Movimentação de estoque de peças, almoxarifado e frota.
 * Regras RN-028, RN-029, RN-034, RN-035; divergências D-08, D-13 e D-27.
 *
 * DUAS COISAS DIFERENTES QUE O LEGADO CONFUNDIA
 * ---------------------------------------------
 * O legado tinha UM alerta — "estouro do estoque mínimo" — e nenhuma checagem
 * de piso absoluto. Aqui são dois conceitos separados, e a diferença importa:
 *
 *   abaixo do MÍNIMO  → aviso, a operação prossegue mediante confirmação.
 *                       É RN-028, preservada integralmente.
 *   abaixo de ZERO    → recusa. Estoque físico negativo não significa nada:
 *                       não existe "menos três parafusos na prateleira".
 *                       É D-27, e é a ÚNICA divergência do projeto que torna
 *                       mais restritiva uma operação que o legado aceitava.
 *
 * A divergência está declarada em 09/D-27 conforme o briefing §12, e o schema a
 * sustenta com CHECK (qtd_estoque >= 0) — mas a aplicação valida ANTES, para
 * dar mensagem clara em vez de deixar o banco recusar com erro técnico.
 */

/* RN-028 — a quantidade levaria o saldo abaixo do estoque mínimo? */
FUNCTION EstoqueAbaixoDoMinimo( nAtual, nMinimo, nQuantidade )

   IF nAtual == NIL .OR. nMinimo == NIL .OR. nQuantidade == NIL
      RETURN .F.
   ENDIF
   IF nMinimo <= 0
      RETURN .F.
   ENDIF

   RETURN nQuantidade > ( nAtual - nMinimo )

/* D-27 — a quantidade levaria o saldo abaixo de zero? */
FUNCTION EstoqueInsuficiente( nAtual, nQuantidade )

   IF nAtual == NIL .OR. nQuantidade == NIL
      RETURN .F.
   ENDIF

   RETURN nQuantidade > nAtual

/*
 * Avalia uma baixa antes de executá-la. Devolve o acumulador de validação:
 * erro impede, aviso pede confirmação.
 */
FUNCTION EstoqueAvaliar( pDb, cTabela, cChave, nCodigo, nQuantidade )

   LOCAL hV := ValNovo(), hSaldo

   hSaldo := EstoqueSaldo( pDb, cTabela, cChave, nCodigo )
   IF hSaldo == NIL
      ValErro( hV, cChave, "Registro " + hb_ntos( nCodigo ) + " não encontrado em " + ;
               cTabela + "." )
      RETURN hV
   ENDIF
   IF nQuantidade == NIL .OR. nQuantidade <= 0
      ValErro( hV, "quantidade", "A quantidade deve ser maior que zero." )
      RETURN hV
   ENDIF

   IF EstoqueInsuficiente( hSaldo[ "atual" ], nQuantidade )
      ValErro( hV, "quantidade", "Estoque insuficiente: há " + ;
               hb_ntos( hSaldo[ "atual" ] ) + " e foram pedidas " + ;
               hb_ntos( nQuantidade ) + " unidades." )
      RETURN hV
   ENDIF

   IF EstoqueAbaixoDoMinimo( hSaldo[ "atual" ], hSaldo[ "minimo" ], nQuantidade )
      ValAviso( hV, "quantidade", "Esta baixa deixa o saldo (" + ;
                hb_ntos( hSaldo[ "atual" ] - nQuantidade ) + ") abaixo do estoque " + ;
                "mínimo (" + hb_ntos( hSaldo[ "minimo" ] ) + "). Confirma?" )
   ENDIF

   RETURN hV

FUNCTION EstoqueSaldo( pDb, cTabela, cChave, nCodigo )

   LOCAL cMin := iif( cTabela == "modelo_veiculo", "0", "qtd_minima" )
   LOCAL aL

   aL := SqlLinhasBind( pDb, "SELECT qtd_estoque, " + cMin + " FROM " + cTabela + ;
      " WHERE " + cChave + " = ? AND excluido = 0", { nCodigo } )
   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "atual" => aL[ 1 ][ 1 ], "minimo" => aL[ 1 ][ 2 ] }

/*
 * RN-029 — baixa de estoque de peça.
 *
 *     MNQTDPEC = MQTDPEC - MQTVEND           CVMTVPEC.PRG:117
 *
 * O legado não tinha piso: o saldo podia ficar negativo. Aqui a baixa é
 * recusada se levaria abaixo de zero (D-27). Abaixo do mínimo continua
 * passando — quem decide é quem chama, depois de confirmar o aviso.
 */
FUNCTION EstoqueBaixarPeca( pDb, nCodPec, nQuantidade )
   RETURN EstoqueBaixar( pDb, "peca", "cod_pec", nCodPec, nQuantidade )

FUNCTION EstoqueBaixarAlmoxarifado( pDb, nCodAlm, nQuantidade )
   RETURN EstoqueBaixar( pDb, "almoxarifado", "cod_alm", nCodAlm, nQuantidade )

/*
 * RN-034 — baixa de veículo na pronta entrega, e RN-035 — aviso de último.
 *
 * Corrige D-08: no legado, um `USE CVBFROTA` redundante reposicionava a tabela
 * no primeiro registro, e a baixa saía do modelo errado. Está nos dados: o
 * primeiro modelo tem 89 unidades e os demais 99, 99, 100, 100 — as 23 vendas
 * envolvem 4 modelos, mas só o primeiro sofreu baixa. Aqui a baixa é no modelo
 * efetivamente vendido.
 *
 * O aviso de RN-035 é devolvido em "ultimo", não impresso: quem tem tela é a
 * camada de cima. E ele é informativo — não impede a venda, exatamente como no
 * legado.
 */
FUNCTION EstoqueBaixarVeiculo( pDb, nCodCar, nQuantidade )

   LOCAL hRes

   hb_default( @nQuantidade, 1 )
   hRes := EstoqueBaixar( pDb, "modelo_veiculo", "cod_car", nCodCar, nQuantidade )
   IF hRes[ "ok" ]
      hRes[ "ultimo" ] := ( hRes[ "saldo" ] == 0 )
   ENDIF

   RETURN hRes

STATIC FUNCTION EstoqueBaixar( pDb, cTabela, cChave, nCodigo, nQuantidade )

   LOCAL hV, hSaldo, nRc, nNovo

   hV := EstoqueAvaliar( pDb, cTabela, cChave, nCodigo, nQuantidade )
   IF !ValOk( hV )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "saldo" => NIL, "ultimo" => .F. }
   ENDIF

   hSaldo := EstoqueSaldo( pDb, cTabela, cChave, nCodigo )
   nNovo  := hSaldo[ "atual" ] - nQuantidade

   nRc := SqlExecBind( pDb, "UPDATE " + cTabela + " SET qtd_estoque = ?" + ;
      " WHERE " + cChave + " = ?", { nNovo, nCodigo } )
   IF nRc != 0
      RETURN { "ok" => .F., "mensagem" => "Não foi possível baixar o estoque: " + ;
               SqlErro( pDb ), "validacao" => hV, "saldo" => NIL, "ultimo" => .F. }
   ENDIF

   LogInfo( "baixa de estoque em " + cTabela, cChave + "=" + hb_ntos( nCodigo ) + ;
            " qtde=" + hb_ntos( nQuantidade ) + " saldo=" + hb_ntos( nNovo ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV, ;
            "saldo" => nNovo, "ultimo" => .F. }

/*
 * Devolve ao estoque — usado ao cancelar ou corrigir um movimento.
 *
 * Não existe no legado: lá não há cancelamento, e uma venda gravada errada só
 * se conserta editando o cadastro à mão. É acréscimo declarado, não regra
 * inventada: sem ele, a exclusão de uma venda deixaria o estoque
 * permanentemente errado.
 */
FUNCTION EstoqueRepor( pDb, cTabela, cChave, nCodigo, nQuantidade )

   LOCAL nRc

   IF nQuantidade == NIL .OR. nQuantidade <= 0
      RETURN { "ok" => .F., "mensagem" => "A quantidade deve ser maior que zero." }
   ENDIF
   IF EstoqueSaldo( pDb, cTabela, cChave, nCodigo ) == NIL
      RETURN { "ok" => .F., "mensagem" => "Registro não encontrado." }
   ENDIF

   nRc := SqlExecBind( pDb, "UPDATE " + cTabela + " SET qtd_estoque = qtd_estoque + ?" + ;
      " WHERE " + cChave + " = ?", { nQuantidade, nCodigo } )
   IF nRc != 0
      RETURN { "ok" => .F., "mensagem" => "Não foi possível repor o estoque: " + SqlErro( pDb ) }
   ENDIF

   LogInfo( "reposição de estoque em " + cTabela, cChave + "=" + hb_ntos( nCodigo ) + ;
            " qtde=" + hb_ntos( nQuantidade ) )

   RETURN { "ok" => .T., "mensagem" => NIL }

/*
 * D-13 / Q-12 — o reparo NÃO baixa estoque de peças.
 *
 * A venda de balcão baixa (CVMTVPEC.PRG:117); o reparo não (ausência de
 * REPLACE QTDPEC em CVMTVREP). Duas leituras eram plausíveis: omissão, ou peças
 * de reparo saindo de outra origem — o CVBALMOX existe e nunca é baixado.
 *
 * Q-12 foi levada ao responsável em 2026-08-25, com as três possibilidades
 * (estoque de peças · almoxarifado · controle externo). **A intenção original
 * não foi recuperada** — o que é esperado num sistema de 32 anos — e a decisão
 * foi manter como está.
 *
 * Pelo método do projeto essa é a resposta certa quando a memória não alcança:
 * preserva-se o literal e registra-se a decisão, em vez de escolher a leitura
 * que parece mais razoável (briefing §2). A função continua aqui: se a intenção
 * for recuperada algum dia, há um lugar único para mudar.
 *
 * Q-01 segue aberta — o almoxarifado continua sem evento que o consuma.
 */
FUNCTION EstoqueReparoBaixa()
   RETURN .F.
