/*
 * definicoes.prg — FASE G, onda 7
 *
 * Os dez relatórios R-01 a R-10, como DADO. O motor está em relatorio.prg.
 *
 * Cada definição preserva o conjunto de colunas do legado (06 §2) e aplica as
 * correções catalogadas em 06 §6, que estão anotadas caso a caso abaixo.
 */

FUNCTION RelatorioDefinicao( cId )

   DO CASE
   CASE cId == "R-01" ; RETURN RelClientes()
   CASE cId == "R-02" ; RETURN RelFuncionarios()
   CASE cId == "R-03" ; RETURN RelFornecedores()
   CASE cId == "R-04" ; RETURN RelPecas()
   CASE cId == "R-05" ; RETURN RelAlmoxarifado()
   CASE cId == "R-06" ; RETURN RelFrota()
   CASE cId == "R-07" ; RETURN RelVendaPecas()
   CASE cId == "R-08" ; RETURN RelReparos()
   CASE cId == "R-09" ; RETURN RelConsorcios()
   CASE cId == "R-10" ; RETURN RelProntaEntrega()
   ENDCASE

   RETURN NIL

FUNCTION RelatorioCatalogo()
   RETURN { ;
      { "R-01", "Clientes"          }, ;
      { "R-02", "Funcionários"      }, ;
      { "R-03", "Fornecedores"      }, ;
      { "R-04", "Estoque de peças"  }, ;
      { "R-05", "Almoxarifado"      }, ;
      { "R-06", "Frota"             }, ;
      { "R-07", "Venda de peças"    }, ;
      { "R-08", "Reparos"           }, ;
      { "R-09", "Consórcios"        }, ;
      { "R-10", "Pronta entrega"    } }

/*
 * R-01 — RN-040: o único relatório com filtro. O menu do legado oferecia
 * consorciados, não-consorciados ou ambos, via SET FILTER.
 */
STATIC FUNCTION RelClientes()
   RETURN { ;
      "id"      => "R-01", ;
      "titulo"  => "Clientes", ;
      "sql"     => "SELECT cod_cli, nome, telefone, cidade FROM v_cliente", ;
      "ordem"   => "cod_cli", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO"  ,  6, "D", "N" ), ;
         RelColuna( "NOME"    , 35, "E", "T" ), ;
         RelColuna( "TELEFONE", 15, "E", "T" ), ;
         RelColuna( "CIDADE"  , 20, "E", "T" ) }, ;
      "filtros" => { ;
         "consorciados" => "WHERE consorcio = 'S'", ;
         "clientes"     => "WHERE consorcio = 'N'", ;
         "ambos"        => "" }, ;
      "rotulos" => { ;
         "consorciados" => "somente consorciados", ;
         "clientes"     => "somente clientes não consorciados", ;
         "ambos"        => "todos" } }

STATIC FUNCTION RelFuncionarios()
   RETURN { ;
      "id"      => "R-02", ;
      "titulo"  => "Funcionários", ;
      "sql"     => "SELECT cod_fun, nome, salario_cent FROM v_funcionario", ;
      "ordem"   => "cod_fun", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO" ,  6, "D", "N" ), ;
         RelColuna( "NOME"   , 35, "E", "T" ), ;
         RelColuna( "SALÁRIO", 14, "D", "$" ) }, ;
      "totalizar" => { 3 } }

STATIC FUNCTION RelFornecedores()
   RETURN { ;
      "id"      => "R-03", ;
      "titulo"  => "Fornecedores", ;
      "sql"     => "SELECT cod_for, desc_item, fabrica FROM v_fornecedor", ;
      "ordem"   => "cod_for", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO" ,  6, "D", "N" ), ;
         RelColuna( "ITEM"   , 35, "E", "T" ), ;
         RelColuna( "FÁBRICA", 30, "E", "T" ) } }

/*
 * R-04 — CR-04: o legado mostrava código, descrição e valor unitário, e
 * chamava isso de "relatório de estoque de peças" — sem mostrar estoque algum.
 * Quantidade e estoque mínimo entram aqui.
 */
STATIC FUNCTION RelPecas()
   RETURN { ;
      "id"      => "R-04", ;
      "titulo"  => "Estoque de Peças", ;
      "sql"     => "SELECT cod_pec, descricao, qtd_estoque, qtd_minima," + ;
                   " valor_unit_cent FROM v_peca", ;
      "ordem"   => "cod_pec", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO"   ,  6, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 30, "E", "T" ), ;
         RelColuna( "QTDE"     ,  6, "D", "N" ), ;
         RelColuna( "MÍNIMO"   ,  6, "D", "N" ), ;
         RelColuna( "VLR UNIT" , 12, "D", "$" ) } }

STATIC FUNCTION RelAlmoxarifado()
   RETURN { ;
      "id"      => "R-05", ;
      "titulo"  => "Almoxarifado", ;
      "sql"     => "SELECT cod_alm, descricao, qtd_estoque, valor_unit_cent," + ;
                   " cod_for FROM v_almoxarifado", ;
      "ordem"   => "cod_alm", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO"   ,  6, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 30, "E", "T" ), ;
         RelColuna( "QTDE"     ,  6, "D", "N" ), ;
         RelColuna( "VLR UNIT" , 12, "D", "$" ), ;
         RelColuna( "FORNEC."  ,  7, "D", "N" ) } }

STATIC FUNCTION RelFrota()
   RETURN { ;
      "id"      => "R-06", ;
      "titulo"  => "Frota", ;
      "sql"     => "SELECT cod_car, descricao, qtd_estoque, valor_cent," + ;
                   " data_compra FROM v_modelo_veiculo", ;
      "ordem"   => "cod_car", ;
      "colunas" => { ;
         RelColuna( "CÓDIGO"   ,  6, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 30, "E", "T" ), ;
         RelColuna( "QTDE"     ,  6, "D", "N" ), ;
         RelColuna( "VALOR"    , 14, "D", "$" ), ;
         RelColuna( "DT COMPRA", 10, "E", "T" ) }, ;
      "totalizar" => { 3 } }

/*
 * R-07 — duas correções, e são as mais substanciais do conjunto.
 *
 * CR-02 — o legado mostrava `VALTOT`, que só é gravado no ÚLTIMO item de cada
 * compra (RN-027): 37% das linhas saíam com zero, e não havia total geral para
 * conferir. Aqui cada linha mostra o SUBTOTAL do item, que é o valor correto
 * por linha, e o relatório totaliza.
 *
 * CR-03 — o legado listava venda de balcão e peças de reparo misturadas, sem
 * distinção, porque `CVPECAS` não tinha como separá-las (Q-02). Agora a venda
 * declara sua origem, e este relatório filtra por 'BALCAO'.
 *
 * As vendas MIGRADAS têm origem 'INDETERMINADO' e não aparecem em R-07 nem em
 * R-08 — o dado do legado não permite classificá-las, e inventar a classificação
 * seria pior do que declarar a lacuna.
 */
STATIC FUNCTION RelVendaPecas()
   RETURN { ;
      "id"      => "R-07", ;
      "titulo"  => "Venda de Peças (Balcão)", ;
      "sql"     => "SELECT v.cod_cli, i.descricao_snapshot, i.quantidade," + ;
                   " i.subtotal_cent FROM venda_peca_item i" + ;
                   " JOIN venda_peca v ON v.id = i.venda_id" + ;
                   " WHERE v.excluido = 0 AND v.origem = 'BALCAO'", ;
      "ordem"   => "v.id, i.ordem", ;
      "colunas" => { ;
         RelColuna( "COD.CLI" ,  7, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 32, "E", "T" ), ;
         RelColuna( "QUANT."  ,  7, "D", "N" ), ;
         RelColuna( "SUBTOTAL", 14, "D", "$" ) }, ;
      "totalizar" => { 4 } }

/*
 * R-08 — CR-03. No legado, R-07 e R-08 liam a MESMA tabela sem filtro algum e
 * mostravam exatamente os mesmos registros, apenas com as colunas reordenadas.
 * O relatório de reparos sequer lia `CVREPAR`, que era a tabela que existiria
 * para isso. Agora filtra por origem 'REPARO'.
 */
STATIC FUNCTION RelReparos()
   RETURN { ;
      "id"      => "R-08", ;
      "titulo"  => "Reparos", ;
      "sql"     => "SELECT i.cod_pec, v.cod_cli, i.quantidade," + ;
                   " i.descricao_snapshot, i.subtotal_cent FROM venda_peca_item i" + ;
                   " JOIN venda_peca v ON v.id = i.venda_id" + ;
                   " WHERE v.excluido = 0 AND v.origem = 'REPARO'", ;
      "ordem"   => "v.id, i.ordem", ;
      "colunas" => { ;
         RelColuna( "COD.PEC" ,  7, "D", "N" ), ;
         RelColuna( "COD.CLI" ,  7, "D", "N" ), ;
         RelColuna( "QUANT."  ,  7, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 28, "E", "T" ), ;
         RelColuna( "VALOR"   , 14, "D", "$" ) }, ;
      "totalizar" => { 5 } }

/*
 * R-09 — CR-01. Este relatório NUNCA funcionou: dos sete campos que ele
 * referenciava em `CVBGRUCO`, apenas `CODCAR` existia. `CODCLI`, `NUMGRUP`,
 * `NUMPRES`, `DATENT`, `DATFEC` e `VALPRES` não existem na tabela — erro de
 * runtime do Clipper na primeira linha. O cabeçalho também não saía, porque
 * `RG()` não tem ramo "RE".
 *
 * Aqui ele é mapeado para os campos reais. Como no legado, lista apenas grupos
 * FECHADOS — ele lia `CVBGRUCO`. Relatório de grupos em formação é uma das
 * lacunas registradas em Q-11, e não é criado aqui.
 */
STATIC FUNCTION RelConsorcios()
   RETURN { ;
      "id"      => "R-09", ;
      "titulo"  => "Consórcios", ;
      "sql"     => "SELECT cod_cli, cod_gru, num_participante, cod_car," + ;
                   " data_adesao, parcelas_restantes, valor_prestacao_cent" + ;
                   " FROM v_consorcio_cota WHERE grupo_fechado = 1", ;
      "ordem"   => "cod_gru, num_participante", ;
      "colunas" => { ;
         RelColuna( "COD.CLI",  7, "D", "N" ), ;
         RelColuna( "GRUPO"  ,  6, "D", "N" ), ;
         RelColuna( "PART."  ,  6, "D", "N" ), ;
         RelColuna( "COD.CAR",  7, "D", "N" ), ;
         RelColuna( "ADESÃO" , 10, "E", "T" ), ;
         RelColuna( "RESTAM" ,  6, "D", "N" ), ;
         RelColuna( "PRESTAÇÃO", 14, "D", "$" ) } }

/*
 * R-10 — CR-07: no legado a descrição do modelo, `C(35)` na coluna 11, invadia
 * a coluna do valor, em 39; e o cabeçalho anunciava "VALOR CAR." em 42 enquanto
 * o dado saía em 39. Aqui as colunas são posicionadas por largura.
 *
 * O vendedor e a forma de pagamento continuam fora, como no legado — são dados
 * que o relatório nunca mostrou.
 */
STATIC FUNCTION RelProntaEntrega()
   RETURN { ;
      "id"      => "R-10", ;
      "titulo"  => "Pronta Entrega", ;
      "sql"     => "SELECT cod_car, descricao_snapshot, valor_cent," + ;
                   " data_venda, cod_cli FROM v_venda_veiculo", ;
      "ordem"   => "id", ;
      "colunas" => { ;
         RelColuna( "COD.CAR" ,  7, "D", "N" ), ;
         RelColuna( "DESCRIÇÃO", 28, "E", "T" ), ;
         RelColuna( "VALOR"   , 14, "D", "$" ), ;
         RelColuna( "DT VENDA", 10, "E", "T" ), ;
         RelColuna( "COD.CLI" ,  7, "D", "N" ) }, ;
      "totalizar" => { 3 } }
