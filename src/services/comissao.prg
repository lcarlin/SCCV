/*
 * comissao.prg — FASE G, onda 4
 *
 * As três fórmulas de comissão do legado, isoladas. Regras RN-030, RN-031 e
 * RN-032; divergências D-05 e D-07.
 *
 * ESTÃO ISOLADAS DE PROPÓSITO. Uma delas (RN-030) é reconhecidamente anômala: a
 * base de cálculo é o CÓDIGO do funcionário. A intenção original não era
 * determinável, e a questão foi escalada como Q-10 — **respondida pelo
 * responsável em 2026-08-25: manter a fórmula do legado.**
 *
 * Ela deixou de ser um literal preservado à espera de decisão e passou a ser
 * regra de negócio confirmada. Continua isolada em três linhas, mas agora pelo
 * motivo ordinário: fórmula de comissão é o tipo de regra que muda com o tempo.
 *
 * ARREDONDAMENTO
 * --------------
 * Tudo em centavos, aritmética inteira. O legado calculava em ponto flutuante e
 * gravava em `N(12,2)`, e o Clipper arredonda na gravação — então arredondar
 * para o centavo mais próximo reproduz o resultado, sem herdar o erro de
 * representação binária.
 */

/*
 * RN-030 — comissão de venda de peças e de reparos.
 *
 *     COMFUN = COMFUN + (MCODFUN * 0.2)      CVMTVPEC.PRG:113
 *                                            CVMTVREP.PRG:53
 *
 * A base é o CÓDIGO do funcionário, não o valor vendido. Um funcionário de
 * código 11 ganha R$ 2,20 por venda; um de código 1 ganha R$ 0,20 —
 * independentemente do valor. Os valores reais de COMFUN no acervo
 * (1500,80 · 534,75 · 297,75 · 10,50 · 6,35) não guardam relação proporcional
 * com nenhum valor de venda, o que confirma a leitura do código.
 *
 * NÃO FOI CORRIGIDA. Três leituras eram igualmente plausíveis — 20% do item,
 * 2% da compra, R$ 0,20 por peça — e nenhuma evidência decidia entre elas. A
 * questão foi levada ao responsável com os números que cada hipótese produziria
 * sobre o acervo, e a decisão (Q-10, 2026-08-25) foi **manter esta fórmula**.
 *
 * O destino, esse sim, foi corrigido: no legado a comissão era creditada ao
 * primeiro funcionário do arquivo, não ao informado (D-07, que alcança este
 * programa, CVMTVREP e CVMTPENT). Ver 09/D-05 e 09/D-07.
 */
FUNCTION ComissaoVendaPeca( nCodFun )

   IF nCodFun == NIL .OR. nCodFun < 0
      RETURN 0
   ENDIF

   RETURN Int( nCodFun ) * 20        // R$ 0,20 por unidade de código

/*
 * RN-031 — pronta entrega: 1,5% do valor do veículo.
 *
 *     MCOMFUN = COMFUN + (MVALCAR * 0.015)   CVMTPENT.PRG:88
 *
 * A fórmula é claramente intencional e fica como está. O que NÃO fica é o
 * destino: no legado, um `USE CVBFUNC` redundante reposicionava a tabela no
 * primeiro registro, e a comissão era creditada ao primeiro funcionário do
 * arquivo em vez do vendedor (D-07). Isso é visível nos dados — o funcionário 1
 * acumulou R$ 1.500,80 contra R$ 0,00 de três outros, com 23 vendas
 * distribuídas entre 6 vendedores. Quem credita é ComissaoCreditar(), pelo
 * código informado.
 */
FUNCTION ComissaoProntaEntrega( nValorCent )
   RETURN ComissaoPercentual( nValorCent, 15, 1000 )

/*
 * RN-032 — consórcio: 0,15% do valor da PRESTAÇÃO.
 *
 *     comiss = mvalpre * 0.0015              CVMTCON.PRG:104
 *
 * A base é a prestação, não o valor total do plano.
 */
FUNCTION ComissaoConsorcio( nPrestacaoCent )
   RETURN ComissaoPercentual( nPrestacaoCent, 15, 10000 )

/*
 * Percentual em aritmética inteira, arredondando para o centavo mais próximo
 * (meio para cima). Sem ponto flutuante: 0,015 não tem representação binária
 * exata, e usá-lo faria centavos aparecerem e sumirem conforme o valor.
 */
STATIC FUNCTION ComissaoPercentual( nCent, nNum, nDen )

   IF nCent == NIL .OR. nCent <= 0
      RETURN 0
   ENDIF

   RETURN Int( ( Int( nCent ) * nNum + nDen / 2 ) / nDen )

/*
 * Credita a comissão ao funcionário INFORMADO (corrige D-07).
 *
 * RN-033 — `COMFUN` é acumulador perpétuo: não há em todo o legado um único
 * `REPLACE COMFUN WITH 0`. Não existe fechamento de período, pagamento nem
 * histórico. Isso é preservado, e a lacuna está registrada como Q-07 — quando o
 * negócio definir o ciclo, é aqui que ele entra.
 */
FUNCTION ComissaoCreditar( pDb, nCodFun, nCent )

   LOCAL nRc

   IF nCodFun == NIL
      RETURN { "ok" => .F., "mensagem" => "Funcionário não informado." }
   ENDIF
   IF nCent == NIL .OR. nCent == 0
      RETURN { "ok" => .T., "mensagem" => NIL, "creditado" => 0 }
   ENDIF
   IF !IntegExiste( pDb, "funcionario", "cod_fun", nCodFun )
      RETURN { "ok" => .F., ;
               "mensagem" => "Funcionário " + hb_ntos( nCodFun ) + " não cadastrado." }
   ENDIF

   nRc := SqlExecBind( pDb, "UPDATE funcionario SET comissao_cent = comissao_cent + ?" + ;
      " WHERE cod_fun = ?", { nCent, nCodFun } )
   IF nRc != 0
      RETURN { "ok" => .F., "mensagem" => "Não foi possível creditar a comissão: " + ;
               SqlErro( pDb ) }
   ENDIF

   LogInfo( "comissão creditada", "cod_fun=" + hb_ntos( nCodFun ) + ;
            " centavos=" + hb_ntos( nCent ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "creditado" => nCent }

/* Comissão acumulada de um funcionário, em centavos. */
FUNCTION ComissaoAcumulada( pDb, nCodFun )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT comissao_cent FROM funcionario" + ;
      " WHERE cod_fun = ?", { nCodFun } )

   IF Len( aL ) == 0 .OR. aL[ 1 ][ 1 ] == NIL
      RETURN 0
   ENDIF

   RETURN aL[ 1 ][ 1 ]
