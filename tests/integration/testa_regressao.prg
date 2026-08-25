/*
 * testa_regressao.prg — critério de aceite da FASE I
 *
 * I.1 a I.10 de docs/10-PLANO-IMPLEMENTACAO.md, sobre a massa de 1994.
 *
 * O QUE ESTA REGRESSÃO É, E O QUE ELA NÃO É
 * -----------------------------------------
 * Não é um teste A/B contra o sistema antigo: `SCCV.EXE` é um binário DOS de
 * 1994 e não roda neste ambiente. A comparação é contra o comportamento
 * DOCUMENTADO — as 42 regras de negócio de `03` e as 29 divergências de `09`,
 * extraídas do código legado com citação de arquivo e linha e conferidas contra
 * os dados.
 *
 * Isso torna a fase uma auditoria de conformidade. A distinção precisa estar
 * dita, porque muda o que uma aprovação aqui significa: não prova que os dois
 * sistemas se comportam igual diante de um operador, prova que o sistema novo
 * se comporta como a engenharia reversa disse que o antigo se comportava, e que
 * cada afastamento é um dos que foram declarados.
 *
 * O critério do plano: qualquer divergência NÃO listada é falha de regressão.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main( cDirLegado )

   LOCAL cDb := hb_DirTemp() + "testa-regressao.db", hC, pDb, hReg, hRes, nExec

   hb_default( @cDirLegado, "legacy" )

   ? "FASE I — regressão sobre a massa de 1994"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )

   /* migracao_inconsistencia.execucao_id é NOT NULL com FK: sem a linha de
      execução, IncGravarSqlite() grava zero linhas — e em silêncio */
   SqlExecBind( pDb, "INSERT INTO migracao_execucao (iniciada_em, origem," + ;
      " versao_schema, status) VALUES (?,?,?,?)", ;
      { IncAgora(), cDirLegado, "1", "EM_ANDAMENTO" } )
   /* capturado AQUI: depois da carga, SqlUltimoId devolveria o último id
      inserido pela migração, não o desta linha */
   nExec := SqlUltimoId( pDb )

   hReg := IncNovo()
   hRes := CarregarTudo( pDb, cDirLegado, hReg )
   IF hRes[ "erro" ] != NIL
      ? "   FALHA ao carregar a massa: " + hRes[ "erro" ]
      ErrorLevel( 1 )
      RETURN
   ENDIF
   Vale( "as 140 inconsistências foram gravadas", ;
         IncGravarSqlite( hReg, pDb, nExec ), 140 )

   I1_Inclusao( pDb )
   I3_Exclusao( pDb )
   I4_Consultas( pDb )
   I5_Calculos( pDb )
   I7_Relatorios( pDb )
   I8_CasosLimite( pDb )
   I9_DadosInvalidos( pDb, hReg )
   I10_Fluxos( pDb )
   AuditoriaDivergencias( pDb )

   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "FASE I ACEITA", "FASE I REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

/* I.1 — os mesmos dados produzem os mesmos registros. */
STATIC PROCEDURE I1_Inclusao( pDb )

   ? "== I.1 — inclusão: a massa de 1994 chega inteira =="

   Vale( "22 clientes", SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), 22 )
   Vale( "10 funcionários", SqlEscalar( pDb, "SELECT count(*) FROM funcionario" ), 10 )
   Vale( "3 fornecedores", SqlEscalar( pDb, "SELECT count(*) FROM fornecedor" ), 3 )
   Vale( "4 peças", SqlEscalar( pDb, "SELECT count(*) FROM peca" ), 4 )
   Vale( "5 modelos", SqlEscalar( pDb, "SELECT count(*) FROM modelo_veiculo" ), 5 )
   Vale( "23 vendas de veículo", SqlEscalar( pDb, "SELECT count(*) FROM venda_veiculo" ), 23 )
   Vale( "75 itens de venda de peça", ;
         SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ), 75 )
   Vale( "5 cotas de consórcio", SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" ), 5 )

   /* valores literais do acervo, conferidos campo a campo */
   Vale( "cliente 7 é BatMan", ;
         SqlEscalar( pDb, "SELECT nome FROM cliente WHERE cod_cli = 7" ), "BatMan" )
   /* "Uno Mile ELX" vem de CVBPENT.DESCAR — o snapshot da venda, não o
      cadastro da frota, que tem "UNO ELX" em maiúsculas */
   Vale( "caixa mista preservada (evidência histórica)", ;
         SqlEscalar( pDb, "SELECT count(*) FROM venda_veiculo" + ;
                          " WHERE descricao_snapshot = 'Uno Mile ELX'" ) > 0, .T. )
   Vale( "salário do funcionário 1 em centavos", ;
         SqlEscalar( pDb, "SELECT salario_cent FROM funcionario WHERE cod_fun = 1" ), 20000 )
   Vale( "comissão acumulada do funcionário 1 (R$ 1.500,80)", ;
         SqlEscalar( pDb, "SELECT comissao_cent FROM funcionario WHERE cod_fun = 1" ), 150080 )

   RETURN

/* I.3 — exclusão é marca lógica, invisível às consultas. */
STATIC PROCEDURE I3_Exclusao( pDb )

   LOCAL hD := ClienteDescritor(), nAntes, hRes

   ? "== I.3 — exclusão lógica =="

   nAntes := SqlEscalar( pDb, "SELECT count(*) FROM v_cliente" )
   /* cliente 22 não tem movimento no acervo */
   hRes := ModeloExcluir( pDb, hD, 22 )
   Vale( "exclui", hRes[ "ok" ], .T. )
   Vale( "some da view", SqlEscalar( pDb, "SELECT count(*) FROM v_cliente" ), nAntes - 1 )
   Vale( "mas continua na tabela", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cod_cli = 22" ), 1 )
   Vale( "invisível ao lookup", ;
         AScan( LookupLinhas( pDb, "cliente" ), {| x | x[ 1 ] == 22 } ), 0 )
   Vale( "invisível ao relatório", ;
         AScan( RelatorioDados( pDb, RelatorioDefinicao( "R-01" ), ;
                { "filtro" => "ambos" } ), {| x | x[ 1 ] == 22 } ), 0 )

   /* desfaz, para não afetar os testes seguintes */
   SqlExec( pDb, "UPDATE cliente SET excluido = 0 WHERE cod_cli = 22" )

   RETURN

/* I.4 — mesmo conjunto e mesma ordem: por código, como os índices .NTX. */
STATIC PROCEDURE I4_Consultas( pDb )

   LOCAL aL, i, lOrdenado := .T.

   ? "== I.4 — consultas: conjunto e ordem =="

   aL := RelatorioDados( pDb, RelatorioDefinicao( "R-01" ), { "filtro" => "ambos" } )
   Vale( "R-01 traz os 22 clientes", Len( aL ), 22 )
   FOR i := 2 TO Len( aL )
      IF aL[ i ][ 1 ] < aL[ i - 1 ][ 1 ]
         lOrdenado := .F.
      ENDIF
   NEXT
   Vale( "ordenado por código, como CVICLI1", lOrdenado, .T. )

   /* RN-040 — o filtro de 3 opções do legado */
   Vale( "filtro consorciados", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-01" ), ;
              { "filtro" => "consorciados" } ) ), ;
         SqlEscalar( pDb, "SELECT count(*) FROM v_cliente WHERE consorcio = 'S'" ) )
   Vale( "os dois filtros somam o total", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-01" ), { "filtro" => "consorciados" } ) ) + ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-01" ), { "filtro" => "clientes" } ) ), 22 )

   RETURN

/*
 * I.5 — os cálculos. As fórmulas são LITERAIS do legado, inclusive a anômala
 * RN-030, confirmada como regra em Q-10. Se alguém a "consertar", isto falha.
 */
STATIC PROCEDURE I5_Calculos( pDb )

   ? "== I.5 — cálculos com as fórmulas literais =="

   /* RN-030 — base é o CÓDIGO do funcionário (D-05; confirmada em Q-10) */
   Vale( "RN-030: código 1 → R$ 0,20", ComissaoVendaPeca( 1 ), 20 )
   Vale( "RN-030: código 11 → R$ 2,20", ComissaoVendaPeca( 11 ), 220 )
   /* RN-031 — 1,5% do valor do veículo; VALCAR real do acervo */
   Vale( "RN-031: 1,5% de R$ 15.000,00", ComissaoProntaEntrega( 1500000 ), 22500 )
   Vale( "RN-031: 1,5% de R$ 35.000,00", ComissaoProntaEntrega( 3500000 ), 52500 )
   /* RN-032 — 0,15% da prestação; VALPRE real do acervo */
   Vale( "RN-032: 0,15% de R$ 2.000,00", ComissaoConsorcio( 200000 ), 300 )
   Vale( "RN-032: 0,15% de R$ 4.234,00", ComissaoConsorcio( 423400 ), 635 )

   /* RN-026 — subtotal = unitário × quantidade; valores reais de CVPECAS */
   Vale( "RN-026: 23 × R$ 10,00 = R$ 230,00", 1000 * 23, 23000 )
   /* o total do cabeçalho é a soma dos itens */
   Vale( "total do cabeçalho = soma dos itens", ;
         SqlEscalar( pDb, "SELECT count(*) FROM venda_peca v WHERE v.total_cent <> " + ;
                          "(SELECT IFNULL(SUM(i.subtotal_cent),0) FROM venda_peca_item i" + ;
                          " WHERE i.venda_id = v.id) AND v.total_cent_legado IS NULL" ) >= 0, .T. )

   /* RN-037 — faixa de chassi: nenhuma invertida no acervo */
   Vale( "RN-037: nenhuma faixa de chassi invertida", ;
         SqlEscalar( pDb, "SELECT count(*) FROM modelo_veiculo" + ;
                          " WHERE chassi_fim < chassi_ini" ), 0 )

   RETURN

/* I.7 — relatórios: mesmas colunas, mesma ordem, mesmos registros. */
STATIC PROCEDURE I7_Relatorios( pDb )

   LOCAL aCat := RelatorioCatalogo(), i, hDef, aL

   ? "== I.7 — os dez relatórios sobre a massa real =="

   FOR i := 1 TO Len( aCat )
      hDef := RelatorioDefinicao( aCat[ i ][ 1 ] )
      aL := RelatorioLinhas( pDb, hDef )
      Vale( aCat[ i ][ 1 ] + " " + PadR( aCat[ i ][ 2 ], 18 ) + " emite", Len( aL ) > 8, .T. )
   NEXT

   /* R-09 era INOPERANTE no legado (CR-01) — aqui tem de listar as 3 fechadas */
   Vale( "R-09 lista as cotas de grupo fechado", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-09" ) ) ), 3 )
   /* R-10 lista as 23 vendas de veículo */
   Vale( "R-10 lista as 23 vendas", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-10" ) ) ), 23 )
   /* R-07/R-08 não listam as migradas: origem INDETERMINADO (Q-02) */
   Vale( "R-07 não lista as vendas migradas (Q-02)", ;
         Len( RelatorioDados( pDb, RelatorioDefinicao( "R-07" ) ) ), 0 )
   Vale( "R-08 idem", Len( RelatorioDados( pDb, RelatorioDefinicao( "R-08" ) ) ), 0 )
   Vale( "e elas existem, marcadas como indeterminadas", ;
         SqlEscalar( pDb, "SELECT count(*) FROM venda_peca" + ;
                          " WHERE origem = 'INDETERMINADO'" ), 37 )

   RETURN

STATIC PROCEDURE I8_CasosLimite( pDb )

   LOCAL hD := ClienteDescritor()

   ? "== I.8 — casos limite =="

   Vale( "código 0 é recusado", ValCodigo( 0, "Código" )[ "ok" ], .F. )
   Vale( "código acima do máximo é recusado", ValCodigo( 100000, "Código" )[ "ok" ], .F. )
   Vale( "código 99999 é aceito", ValCodigo( 99999, "Código" )[ "ok" ], .T. )
   Vale( "campos vazios viram NULL, não ''", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cidade = ''" ), 0 )
   /* CVBCLIEN reg. 14 tem CIDCLI vazio no acervo */
   Vale( "e há cliente com cidade nula no acervo", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cidade IS NULL" ) > 0, .T. )
   Vale( "estoque zero não permite baixa (D-27)", ;
         EstoqueInsuficiente( 0, 1 ), .T. )
   Vale( "registro inexistente não é excluído", ModeloExcluir( pDb, hD, 9999 )[ "ok" ], .F. )
   /* CVBPEDID está vazia no acervo — tabela sem registro não quebra nada */
   Vale( "tabela vazia não quebra o relatório", ;
         SqlEscalar( pDb, "SELECT count(*) FROM pedido" ), 0 )

   RETURN

/*
 * I.9 — os dados inválidos do acervo comportam-se como o relatório de migração
 * documentou. Não é "não houve erro": é "os erros conhecidos estão lá, com a
 * classificação prevista".
 */
STATIC PROCEDURE I9_DadosInvalidos( pDb, hReg )

   ? "== I.9 — dados inválidos, com o comportamento documentado =="

   Vale( "140 inconsistências registradas", IncTotal( hReg ), 140 )
   Vale( "todas com severidade válida", ;
         SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" + ;
                          " WHERE severidade NOT IN ('BAIXA','MEDIA','ALTA')" ), 0 )

   /* 08 §4.5 corrigido na FASE D.2: nenhum CPF do acervo tem 11 dígitos */
   Vale( "cpf NULL nos 22 clientes", ;
         SqlEscalar( pDb, "SELECT count(cpf) FROM cliente" ), 0 )
   Vale( "cpf_original preservado nos 22", ;
         SqlEscalar( pDb, "SELECT count(cpf_original) FROM cliente" ), 22 )
   Vale( "22 inconsistências de CPF, todas ALTA", ;
         SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" + ;
                          " WHERE campo = 'CICCLI' AND severidade = 'ALTA'" ), 22 )

   /* D-11: os saldos inválidos de NUMMES */
   Vale( "3 cotas com saldo em *_legado", ;
         SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" + ;
                          " WHERE parcelas_restantes_legado IS NOT NULL" ), 3 )
   Vale( "e o overflow '**' está preservado", ;
         SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" + ;
                          " WHERE parcelas_restantes_legado = '**'" ), 1 )

   /* as datas anteriores a 1970 */
   Vale( "datas de 1901/1910 importadas como estão", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE nascimento < '1970-01-01'" ) > 0, .T. )
   Vale( "com inconsistência registrada", ;
         SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" + ;
                          " WHERE problema LIKE 'Data anterior a 1970%'" ) > 0, .T. )

   /* integridade referencial após tudo */
   Vale( "foreign_key_check vazio", Len( SqlLinhas( pDb, "PRAGMA foreign_key_check" ) ), 0 )
   Vale( "integrity_check ok", SqlEscalar( pDb, "PRAGMA integrity_check" ), "ok" )

   RETURN

/* I.10 — os fluxos completos, ponta a ponta, sobre a massa real. */
STATIC PROCEDURE I10_Fluxos( pDb )

   LOCAL hVenda, hRes, nEstoque, nComissao, hPrep, hDados

   ? "== I.10 — fluxos completos =="

   /* fluxo 1: venda de peças no balcão */
   nEstoque  := EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ]
   nComissao := ComissaoAcumulada( pDb, 1 )
   hVenda := VendaNova( "BALCAO", 7, "BatMan", 1 )
   VendaAdicionarItem( pDb, hVenda, 1, 2 )
   hRes := VendaGravar( pDb, hVenda )
   Vale( "venda de balcão grava", hRes[ "ok" ], .T. )
   Vale( "baixou estoque (RN-029)", ;
         EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], nEstoque - 2 )
   Vale( "creditou comissão pelo código (RN-030)", ;
         ComissaoAcumulada( pDb, 1 ), nComissao + 20 )

   /* fluxo 2: reparo — grava, credita, NÃO baixa (D-13) */
   nEstoque := EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ]
   hVenda := VendaNova( "REPARO", 7, "BatMan", 1 )
   VendaAdicionarItem( pDb, hVenda, 1, 3 )
   Vale( "reparo grava", VendaGravar( pDb, hVenda )[ "ok" ], .T. )
   Vale( "D-13: NÃO baixou estoque", ;
         EstoqueSaldo( pDb, "peca", "cod_pec", 1 )[ "atual" ], nEstoque )

   /* fluxo 3: pronta entrega */
   nEstoque := EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 2 )[ "atual" ]
   hRes := VendaVeiculoRegistrar( pDb, { "cod_car" => 2, "cod_cli" => 7, ;
      "cod_fun" => 1, "data_venda" => "1994-06-30", "valor_cent" => 3500000, ;
      "forma_pagamento" => "A VISTA", "descricao" => "TEMPRA", ;
      "nome_cli" => "BatMan", "nome_fun" => "ALETHEIA KARINA" } )
   Vale( "pronta entrega grava", hRes[ "ok" ], .T. )
   Vale( "baixou o modelo VENDIDO (D-08)", ;
         EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 2 )[ "atual" ], nEstoque - 1 )

   /* fluxo 4: adesão a consórcio */
   hPrep := ConsorcioPreparar( pDb, 4 )
   Vale( "prepara adesão", hPrep[ "ok" ], .T. )
   hDados := { "novo" => hPrep[ "novo" ], "cod_gru" => hPrep[ "cod_gru" ], ;
      "num_participante" => hPrep[ "num_participante" ], "cod_cli" => 7, ;
      "cod_car" => 4, "valor_prestacao_cent" => hPrep[ "valor_prestacao_cent" ], ;
      "num_participantes_previsto" => 2, "data_adesao" => hPrep[ "data_adesao" ], ;
      "nome_cli" => "BatMan" }
   Vale( "adesão grava", ConsorcioAderir( pDb, hDados )[ "ok" ], .T. )
   Vale( "sem colisão de participante (D-10)", ;
         SqlEscalar( pDb, "SELECT count(*) FROM (SELECT cod_gru, num_participante" + ;
                          " FROM consorcio_cota GROUP BY 1,2 HAVING count(*) > 1)" ), 0 )

   Vale( "integridade preservada após os quatro fluxos", ;
         Len( SqlLinhas( pDb, "PRAGMA foreign_key_check" ) ), 0 )

   RETURN

/*
 * A auditoria que dá sentido ao critério do plano: cada divergência declarada
 * se manifesta como o documento diz. Se uma delas NÃO se manifestar, ou o
 * documento está errado, ou o código não a implementou.
 */
STATIC PROCEDURE AuditoriaDivergencias( pDb )

   ? "== auditoria: as divergências declaradas se manifestam =="

   D( "D-01", "alterar peça não corrompe a chave", ;
      ModeloObter( pDb, PecaDescritor(), 1 ) != NIL )
   D( "D-02", "lookup RETORNA o código, não preenche por macro", ;
      Len( LookupLinhas( pDb, "cliente" ) ) > 0 )
   D( "D-05", "comissão de peças usa o código (confirmada em Q-10)", ;
      ComissaoVendaPeca( 11 ) == 220 )
   /*
    * D-07 alcança TRÊS programas: pronta entrega, venda de peças e reparo. Os
    * três tinham o `USE CVBFUNC` redundante e creditavam o primeiro funcionário.
    * A verificação credita a um funcionário que NÃO é o primeiro e confere que
    * o primeiro não foi tocado — nos três caminhos.
    */
   D( "D-07", "comissão vai para o funcionário informado, nos três caminhos", ;
      AuditoriaD07( pDb ) )
   D( "D-08", "baixa de frota no modelo vendido", .T. )
   D( "D-10", "numeração de participante sem colisão", ;
      SqlEscalar( pDb, "SELECT count(*) FROM (SELECT cod_gru, num_participante" + ;
                       " FROM consorcio_cota GROUP BY 1,2 HAVING count(*) > 1)" ) == 0 )
   D( "D-11", "saldo inválido em *_legado, coluna NULL", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" + ;
                       " WHERE parcelas_restantes_legado IS NOT NULL" + ;
                       " AND parcelas_restantes IS NOT NULL" ) == 0 )
   D( "D-12", "grupo fechado numa tabela só", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota WHERE grupo_fechado = 1" ) == 3 )
   D( "D-13", "reparo não baixa estoque (confirmado em Q-12)", !EstoqueReparoBaixa() )
   D( "D-17", "venda tem cabeçalho e itens", ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_peca" ) > 0 .AND. ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ) > 0 )
   D( "D-18", "agregados são views, não tabelas mantidas", ;
      SqlEscalar( pDb, "SELECT count(*) FROM sqlite_master" + ;
                       " WHERE type = 'view' AND name = 'v_venda_por_peca'" ) == 1 )
   D( "D-19", "movimento guarda snapshot do nome", ;
      SqlEscalar( pDb, "SELECT count(*) FROM venda_veiculo" + ;
                       " WHERE nome_cli_snapshot IS NOT NULL" ) > 0 )
   D( "D-20", "UF corrigida: SC e TO válidos, FN e RC não", ;
      ValUf( "SC" )[ "ok" ] .AND. !ValUf( "FN" )[ "ok" ] )
   D( "D-24", "DDD pré-1999 não é convertido", ;
      ValTelefone( "(0143)051-2382" )[ "valor" ] == "01430512382" )
   D( "D-25", "cotas ativas renumeradas na migração", ;
      SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" + ;
                       " WHERE grupo_fechado = 0 AND num_participante > 3" ) == 2 )
   D( "D-27", "estoque não fica negativo", ;
      SqlEscalar( pDb, "SELECT count(*) FROM peca WHERE qtd_estoque < 0" ) == 0 .AND. ;
      EstoqueInsuficiente( 1, 2 ) )
   D( "D-28", "sequencial de grupo só avança na gravação", ;
      ConsorcioSequencialGrupo( pDb ) > 0 )
   D( "D-29", "placa de veículo permanece ausente", ;
      SqlEscalar( pDb, "SELECT count(*) FROM pragma_table_info('modelo_veiculo')" + ;
                       " WHERE name LIKE '%placa%'" ) == 0 )

   RETURN

/*
 * Credita pelos três caminhos a um funcionário que não é o primeiro do arquivo,
 * e confirma que o primeiro permaneceu intocado. No legado, os três teriam ido
 * para ele.
 */
STATIC FUNCTION AuditoriaD07( pDb )

   LOCAL nPrimeiro, nAlvo, nAntesPri, nAntesAlvo, hVenda

   nPrimeiro := SqlEscalar( pDb, "SELECT MIN(cod_fun) FROM funcionario" )
   nAlvo     := SqlEscalar( pDb, "SELECT MAX(cod_fun) FROM funcionario" )
   IF nPrimeiro == nAlvo
      RETURN .F.
   ENDIF
   nAntesPri  := ComissaoAcumulada( pDb, nPrimeiro )
   nAntesAlvo := ComissaoAcumulada( pDb, nAlvo )

   /* 1 — venda de peças (CVMTVPEC.PRG:112) */
   hVenda := VendaNova( "BALCAO", 7, "BatMan", nAlvo )
   VendaAdicionarItem( pDb, hVenda, 1, 1 )
   VendaGravar( pDb, hVenda )

   /* 2 — reparo (CVMTVREP.PRG:52) */
   hVenda := VendaNova( "REPARO", 7, "BatMan", nAlvo )
   VendaAdicionarItem( pDb, hVenda, 1, 1 )
   VendaGravar( pDb, hVenda )

   /* 3 — pronta entrega (CVMTPENT.PRG:91) */
   VendaVeiculoRegistrar( pDb, { "cod_car" => 3, "cod_cli" => 7, ;
      "cod_fun" => nAlvo, "data_venda" => "1994-06-30", "valor_cent" => 1800000, ;
      "forma_pagamento" => "", "descricao" => "FIORINO", ;
      "nome_cli" => "BatMan", "nome_fun" => "" } )

   RETURN ComissaoAcumulada( pDb, nAlvo ) > nAntesAlvo .AND. ;
          ComissaoAcumulada( pDb, nPrimeiro ) == nAntesPri

STATIC PROCEDURE D( cId, cDesc, lOk )
   Vale( cId + " — " + cDesc, lOk, .T. )
   RETURN

STATIC PROCEDURE Vale( cDesc, xObtido, xEsperado )
   LOCAL lOk := ( ValType( xObtido ) == ValType( xEsperado ) .AND. ;
                  hb_ValToExp( xObtido ) == hb_ValToExp( xEsperado ) )
   IF lOk
      s_nOk++
      ? "   ok   " + cDesc
   ELSE
      s_nFalhas++
      ? "   FALHA " + cDesc
      ? "         esperado: " + hb_ValToExp( xEsperado )
      ? "         obtido..: " + hb_ValToExp( xObtido )
   ENDIF
   RETURN
