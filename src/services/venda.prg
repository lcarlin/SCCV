/*
 * venda.prg — FASE G, onda 5
 *
 * Regras de venda de peças (balcão), reparo e pronta entrega.
 * RN-024 a RN-029, RN-034, RN-035; divergências D-06, D-13, D-17, D-27.
 *
 * A venda é montada em MEMÓRIA e gravada de uma vez, numa transação. O legado
 * fazia APPEND item a item direto no arquivo: uma queda de energia no meio da
 * compra deixava metade dos itens gravados e nenhum total. Aqui, ou a venda
 * inteira existe, ou nada existe.
 *
 * Q-02 RESPONDIDA PARA VENDAS NOVAS. O legado não distinguia venda de balcão de
 * peças usadas em reparo — ambas caíam em CVPECAS sem marca alguma, e por isso
 * as 37 vendas migradas ficaram com origem = 'INDETERMINADO'. A venda nova
 * declara sua origem, e é o chamador quem a informa.
 */

#define ORIGEM_BALCAO   "BALCAO"
#define ORIGEM_REPARO   "REPARO"

/*
 * Abre uma venda em memória.
 * cOrigem: "BALCAO" (venda de balcão) ou "REPARO" (peças usadas em reparo).
 */
FUNCTION VendaNova( cOrigem, nCodCli, cNomeCli, nCodFun )
   RETURN { ;
      "origem"     => iif( cOrigem == NIL, ORIGEM_BALCAO, cOrigem ), ;
      "cod_cli"    => nCodCli, ;
      "nome_cli"   => cNomeCli, ;
      "cod_fun"    => nCodFun, ;
      "data_venda" => hb_DToC( Date(), "YYYY-MM-DD" ), ;
      "itens"      => {} }

/*
 * RN-024 / RN-025 / D-06 — o cliente existe?
 *
 * Devolve { "existe", "nome", "oferecer_cadastro" }.
 *
 * `oferecer_cadastro` é .T. em venda de peças e reparo (RN-024) e .F. na pronta
 * entrega (RN-025) — no legado, a pronta entrega exibia um texto perguntando
 * "Deseja Cadastra-lo" com MENSAGEM() em vez de CONFIRMA(), ou seja: perguntava
 * e não escutava. O texto era pergunta, o comportamento era aviso. Preservamos
 * o COMPORTAMENTO (não cadastra em linha) e corrigimos o TEXTO, porque uma
 * pergunta que ignora a resposta é defeito de interface, não regra de negócio.
 *
 * D-06 — quem chama deve REFAZER esta consulta depois do cadastro em linha. No
 * legado o fluxo seguia sem refazer o SEEK, lendo NOMCLI de uma área que
 * CVMTCLI havia fechado.
 */
FUNCTION VendaConferirCliente( pDb, nCodCli, cOrigem )

   LOCAL cNome

   IF nCodCli == NIL .OR. nCodCli <= 0
      RETURN { "existe" => .F., "nome" => NIL, "oferecer_cadastro" => .F. }
   ENDIF
   cNome := VendaNomeCliente( pDb, nCodCli )

   RETURN { "existe" => ( cNome != NIL ), "nome" => cNome, ;
            "oferecer_cadastro" => ( cNome == NIL .AND. !( cOrigem == "VEICULO" ) ) }

/*
 * RN-026 — subtotal do item = valor unitário × quantidade.
 *
 * Em centavos, aritmética inteira. O Clipper usava decimal (não binário), então
 * multiplicar e somar era exato lá; aqui a exatidão vem do inteiro.
 *
 * O valor unitário é copiado do cadastro NO MOMENTO da venda e gravado no item
 * (D-19): alterar o preço da peça depois não pode reescrever uma venda de 1994.
 *
 * Devolve o acumulador de validação. Erro impede; aviso pede confirmação.
 */
FUNCTION VendaAdicionarItem( pDb, hVenda, nCodPec, nQuantidade )

   LOCAL hV := ValNovo(), hPeca, nSubtotal, nJaPedido

   hPeca := VendaPecaDados( pDb, nCodPec )
   IF hPeca == NIL
      ValErro( hV, "cod_pec", "Peça " + hb_ntos( nCodPec ) + " não cadastrada." )
      RETURN hV
   ENDIF
   IF nQuantidade == NIL .OR. nQuantidade <= 0
      ValErro( hV, "quantidade", "A quantidade deve ser maior que zero." )
      RETURN hV
   ENDIF

   /*
    * O saldo tem de considerar o que já foi pedido desta mesma peça nesta mesma
    * venda, e ainda não foi gravado. Sem isso, três itens de 5 unidades cada
    * passariam individualmente num estoque de 10 e estourariam na gravação.
    */
   nJaPedido := VendaQuantidadeDaPeca( hVenda, nCodPec )

   IF EstoqueInsuficiente( hPeca[ "qtd_estoque" ], nQuantidade + nJaPedido )
      ValErro( hV, "quantidade", "Estoque insuficiente: há " + ;
               hb_ntos( hPeca[ "qtd_estoque" ] ) + " unidades" + ;
               iif( nJaPedido > 0, " e " + hb_ntos( nJaPedido ) + ;
                    " já estão nesta venda", "" ) + "." )
      RETURN hV
   ENDIF

   IF EstoqueAbaixoDoMinimo( hPeca[ "qtd_estoque" ], hPeca[ "qtd_minima" ], ;
                             nQuantidade + nJaPedido )
      ValAviso( hV, "quantidade", "Estouro do estoque mínimo: o saldo ficará em " + ;
                hb_ntos( hPeca[ "qtd_estoque" ] - nQuantidade - nJaPedido ) + ;
                ", abaixo do mínimo de " + hb_ntos( hPeca[ "qtd_minima" ] ) + ". Continua?" )
   ENDIF

   nSubtotal := hPeca[ "valor_unit_cent" ] * nQuantidade
   AAdd( hVenda[ "itens" ], { ;
      "cod_pec"         => nCodPec, ;
      "descricao"       => hPeca[ "descricao" ], ;
      "quantidade"      => nQuantidade, ;
      "valor_unit_cent" => hPeca[ "valor_unit_cent" ], ;
      "subtotal_cent"   => nSubtotal } )

   RETURN hV

FUNCTION VendaRemoverItem( hVenda, nIndice )

   IF nIndice < 1 .OR. nIndice > Len( hVenda[ "itens" ] )
      RETURN .F.
   ENDIF
   hb_ADel( hVenda[ "itens" ], nIndice, .T. )

   RETURN .T.

/* Quantidade já pedida de uma peça nesta venda. */
FUNCTION VendaQuantidadeDaPeca( hVenda, nCodPec )

   LOCAL n := 0, i

   FOR i := 1 TO Len( hVenda[ "itens" ] )
      IF hVenda[ "itens" ][ i ][ "cod_pec" ] == nCodPec
         n += hVenda[ "itens" ][ i ][ "quantidade" ]
      ENDIF
   NEXT

   RETURN n

/*
 * RN-026 — total da compra = soma dos subtotais.
 *
 * Calculado, nunca armazenado em memória: no legado o total era uma variável
 * acumulada (MTOTALC) que só chegava ao disco no último item (RN-027), e é daí
 * que vêm os 28 registros com total zero. Somar sob demanda não tem como
 * divergir dos itens.
 */
FUNCTION VendaPecaTotal( hVenda )

   LOCAL n := 0, i

   FOR i := 1 TO Len( hVenda[ "itens" ] )
      n += hVenda[ "itens" ][ i ][ "subtotal_cent" ]
   NEXT

   RETURN n

/*
 * Grava a venda inteira: cabeçalho, itens, baixa de estoque e comissão — tudo
 * numa transação.
 *
 * D-13 / Q-12 — o REPARO não baixa estoque. A venda de balcão baixa
 * (CVMTVPEC.PRG:117); o reparo não (ausência de REPLACE QTDPEC em CVMTVREP).
 * Nenhuma evidência decide se é omissão ou intenção, então fica como está e a
 * condição está aqui, explícita e num lugar só.
 *
 * RN-030 — a comissão usa o CÓDIGO do funcionário como base. Fórmula anômala,
 * preservada, isolada em ComissaoVendaPeca(). Ver Q-10.
 */
FUNCTION VendaGravar( pDb, hVenda )

   LOCAL hV, hRes, nId

   hV := VendaValidar( pDb, hVenda )
   IF !ValOk( hV )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, "id" => NIL }
   ENDIF

   hRes := TransExecutar( pDb, {| | VendaGravarTudo( pDb, hVenda, @nId ) }, ;
                          "registrar a venda" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], "validacao" => hV, "id" => NIL }
   ENDIF

   LogInfo( "venda registrada", "id=" + hb_ntos( nId ) + " origem=" + hVenda[ "origem" ] + ;
            " itens=" + hb_ntos( Len( hVenda[ "itens" ] ) ) + ;
            " total=" + hb_ntos( VendaPecaTotal( hVenda ) ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV, "id" => nId }

/* Devolve NIL em sucesso, ou a mensagem do erro — para o TransExecutar desfazer. */
STATIC FUNCTION VendaGravarTudo( pDb, hVenda, nId )

   LOCAL i, hItem, hBaixa, hCom

   nId := VendaPecaInserir( pDb, hVenda )
   IF nId == NIL
      RETURN "Não foi possível gravar a venda: " + SqlErro( pDb )
   ENDIF

   IF hVenda[ "origem" ] == ORIGEM_BALCAO
      FOR i := 1 TO Len( hVenda[ "itens" ] )
         hItem := hVenda[ "itens" ][ i ]
         hBaixa := EstoqueBaixarPeca( pDb, hItem[ "cod_pec" ], hItem[ "quantidade" ] )
         IF !hBaixa[ "ok" ]
            RETURN hBaixa[ "mensagem" ]
         ENDIF
      NEXT
   ENDIF

   IF hVenda[ "cod_fun" ] != NIL
      hCom := ComissaoCreditar( pDb, hVenda[ "cod_fun" ], ;
                                ComissaoVendaPeca( hVenda[ "cod_fun" ] ) )
      IF !hCom[ "ok" ]
         RETURN hCom[ "mensagem" ]
      ENDIF
   ENDIF

   RETURN NIL

FUNCTION VendaValidar( pDb, hVenda )

   LOCAL hV := ValNovo()

   IF Len( hVenda[ "itens" ] ) == 0
      ValErro( hV, "itens", "A venda não tem itens." )
   ENDIF
   IF hVenda[ "cod_cli" ] == NIL
      ValErro( hV, "cod_cli", "Informe o cliente." )
   ELSEIF !IntegExiste( pDb, "cliente", "cod_cli", hVenda[ "cod_cli" ] )
      ValErro( hV, "cod_cli", "Cliente " + hb_ntos( hVenda[ "cod_cli" ] ) + ;
               " não cadastrado." )
   ENDIF
   IF hVenda[ "cod_fun" ] != NIL .AND. ;
      !IntegExiste( pDb, "funcionario", "cod_fun", hVenda[ "cod_fun" ] )
      ValErro( hV, "cod_fun", "Funcionário " + hb_ntos( hVenda[ "cod_fun" ] ) + ;
               " não cadastrado." )
   ENDIF
   IF !( hVenda[ "origem" ] == ORIGEM_BALCAO ) .AND. !( hVenda[ "origem" ] == ORIGEM_REPARO )
      ValErro( hV, "origem", "Origem inválida: " + hb_ValToStr( hVenda[ "origem" ] ) )
   ENDIF

   RETURN hV

/* ------------------------------------------------------------------ */
/* Pronta entrega — RN-025, RN-031, RN-034, RN-035; D-07, D-08         */
/* ------------------------------------------------------------------ */

/*
 * Registra a venda de um veículo: grava, baixa uma unidade do modelo VENDIDO
 * (D-08) e credita 1,5% ao funcionário INFORMADO (D-07) — os dois defeitos do
 * legado vinham do mesmo `USE` redundante, que reposicionava a tabela no
 * primeiro registro.
 *
 * Devolve "ultimo" = .T. quando a baixa zerou o estoque do modelo (RN-035).
 * O aviso é informativo e não impede a venda, como no legado — o que impede é
 * o estoque já estar em zero (D-27).
 */
FUNCTION VendaVeiculoRegistrar( pDb, hDados )

   LOCAL hV, hRes, nId, lUltimo := .F.

   hV := VendaVeiculoValidar( pDb, hDados )
   IF !ValOk( hV )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV, ;
               "id" => NIL, "ultimo" => .F. }
   ENDIF

   hRes := TransExecutar( pDb, ;
      {| | VendaVeiculoGravarTudo( pDb, hDados, @nId, @lUltimo ) }, ;
      "registrar a venda do veículo" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], "validacao" => hV, ;
               "id" => NIL, "ultimo" => .F. }
   ENDIF

   LogInfo( "venda de veículo registrada", "id=" + hb_ntos( nId ) + ;
            " cod_car=" + hb_ntos( hDados[ "cod_car" ] ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV, ;
            "id" => nId, "ultimo" => lUltimo }

STATIC FUNCTION VendaVeiculoGravarTudo( pDb, hDados, nId, lUltimo )

   LOCAL hBaixa, hCom

   nId := VendaVeiculoInserir( pDb, hDados )
   IF nId == NIL
      RETURN "Não foi possível gravar a venda: " + SqlErro( pDb )
   ENDIF

   hBaixa := EstoqueBaixarVeiculo( pDb, hDados[ "cod_car" ], 1 )
   IF !hBaixa[ "ok" ]
      RETURN hBaixa[ "mensagem" ]
   ENDIF
   lUltimo := hBaixa[ "ultimo" ]

   IF hDados[ "cod_fun" ] != NIL
      hCom := ComissaoCreditar( pDb, hDados[ "cod_fun" ], ;
                                ComissaoProntaEntrega( hDados[ "valor_cent" ] ) )
      IF !hCom[ "ok" ]
         RETURN hCom[ "mensagem" ]
      ENDIF
   ENDIF

   RETURN NIL

FUNCTION VendaVeiculoValidar( pDb, hDados )

   LOCAL hV := ValNovo(), hR

   IF hDados[ "cod_car" ] == NIL
      ValErro( hV, "cod_car", "Informe o modelo do veículo." )
   ELSEIF !IntegExiste( pDb, "modelo_veiculo", "cod_car", hDados[ "cod_car" ] )
      ValErro( hV, "cod_car", "Modelo " + hb_ntos( hDados[ "cod_car" ] ) + ;
               " não cadastrado." )
   ENDIF
   IF hDados[ "cod_cli" ] == NIL
      ValErro( hV, "cod_cli", "Informe o cliente." )
   ELSEIF !IntegExiste( pDb, "cliente", "cod_cli", hDados[ "cod_cli" ] )
      ValErro( hV, "cod_cli", "Cliente " + hb_ntos( hDados[ "cod_cli" ] ) + ;
               " não cadastrado." )
   ENDIF
   /* venda_veiculo.cod_fun é NOT NULL no schema: o vendedor é obrigatório aqui,
      diferente da venda de peças */
   IF hDados[ "cod_fun" ] == NIL
      ValErro( hV, "cod_fun", "Informe o funcionário que fez a venda." )
   ELSEIF !IntegExiste( pDb, "funcionario", "cod_fun", hDados[ "cod_fun" ] )
      ValErro( hV, "cod_fun", "Funcionário " + hb_ntos( hDados[ "cod_fun" ] ) + ;
               " não cadastrado." )
   ENDIF

   hR := ValMonetario( hDados[ "valor_cent" ], "Valor" )
   IF !hR[ "ok" ]
      ValErro( hV, "valor_cent", hR[ "mensagem" ] )
   ENDIF
   IF !Empty( hDados[ "data_venda" ] )
      hR := ValDataEvento( hDados[ "data_venda" ] )
      IF !hR[ "ok" ]
         ValErro( hV, "data_venda", hR[ "mensagem" ] )
      ENDIF
   ENDIF

   RETURN hV
