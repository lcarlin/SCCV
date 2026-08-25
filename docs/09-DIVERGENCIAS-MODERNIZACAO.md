# 09 — DIVERGÊNCIAS E MODERNIZAÇÃO

## Categorias (briefing §23)

| Tag | Significado |
|---|---|
| `[COMPATIBILIDADE]` | Comportamento preservado |
| `[CORREÇÃO]` | Comportamento claramente defeituoso corrigido |
| `[MODERNIZAÇÃO]` | Melhoria necessária para o ambiente moderno |
| `[SEGURANÇA]` | Alteração necessária por segurança |
| `[VALIDAÇÃO]` | Nova validação para garantir integridade dos dados |
| `[MUDANÇA FUNCIONAL]` | Mudança deliberada de comportamento |
| `[INDEFINIDO]` | Não foi possível determinar a intenção original |

**Total: 27 divergências** — 9 correções, 8 modernizações, 3 mudanças funcionais, 3 validações, 2 indefinidos, 1 segurança, 3 compatibilidades (D-11 e D-15 contam em duas categorias).

> Atualizado na FASE C: D-11 refinada e D-27 acrescentada a partir das decisões consolidadas em `database/schema.sql`.

---

## D-01 — Corrupção da chave primária ao alterar peça

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTPEC.PRG:73` |
| **Legado** | `MCODPEC = CODFOR` no caminho de alteração; o `REPLACE CODPEC WITH MCODPEC` da linha 135 grava o código do fornecedor no campo de código da peça |
| **Novo** | `MCODPEC = CODPEC` — ou melhor: a PK não é reatribuída em alteração |
| **Justificativa** | Erro de digitação inequívoco. Nenhuma leitura plausível do sistema faz o código da peça virar o do fornecedor. O sistema já tem `MCODFOR = CODFOR` na linha 78 |
| **Impacto nos dados** | Nenhum — os 4 registros de `CVBPECAS` nunca foram alterados |
| **Regra relacionada** | RN-036 |

---

## D-02 — Mecanismo `TABELA()`/`FUNDB()` por macro substituído por retorno

**`[MODERNIZAÇÃO]`**

| | |
|---|---|
| **Local** | `CV_FUNC.PRG` — `TABELA()`, `FUNDB()` |
| **Legado** | `FUNDB()` descobre a variável de destino por convenção textual (`"M" + FIELDNAME(1)`) e a preenche via macro `&`. Funciona por acoplamento de nomes entre biblioteca e chamador |
| **Novo** | Função `SelecionarCodigo(cTabela, cTitulo) → nCodigo \| NIL`, que **retorna** o valor selecionado. O chamador atribui explicitamente |
| **Justificativa** | O comportamento observável (browse de seleção, ENTER escolhe, ESC cancela) é idêntico. Apenas o mecanismo interno muda. Elimina acoplamento invisível e permite tipagem |
| **Impacto funcional** | Nenhum |

---

## D-03 — Recursão mútua Cliente ↔ Consórcio eliminada

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTCON.PRG:171` — `DO CVMTCLI` como última instrução, sem `RETURN` |
| **Legado** | Cada adesão a consórcio empilha uma nova instância da manutenção de clientes; a pilha só se desfaz quando o operador sai de todas com ESC |
| **Novo** | `CVMTCON` retorna ao chamador (`CVMTCLI`), que prossegue normalmente |
| **Justificativa** | Não há leitura em que reabrir o cadastro de clientes ao final de uma adesão seja intencional — o operador já está *dentro* de `CVMTCLI`, que o chamou. É um `RETURN` esquecido |
| **Impacto funcional** | O operador deixa de ver uma tela de cliente em branco após cadastrar o consórcio. Comportamento mais previsível |
| **Regra relacionada** | RN-012 |

---

## D-04 — Gravação incondicional após "Retorna" e "Exclui"

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | 7 módulos de manutenção (`CVMTCLI:120`, `CVMTFUNC:107`, `CVMTFOR:130`, `CVMTPEC:135`, `CVMTALMX:170`, `CVMTFRO:120`, `CVMTALM:88`) |
| **Legado** | Os `REPLACE` estão fora do `IF/ELSE`. Após `"R"etorna` o `LOOP` os evita, mas após `"E"xcluir` eles executam, reescrevendo o registro recém-marcado |
| **Novo** | `INSERT` no caminho de inclusão; `UPDATE` apenas no caminho de alteração; `UPDATE ... SET excluido=1` no caminho de exclusão. Nada mais |
| **Justificativa** | Escrever campos de um registro que acabou de ser excluído não é uma regra de negócio — é consequência da estrutura do código. O resultado final (registro marcado com os mesmos valores) é idêntico ao esperado |
| **Impacto funcional** | Nenhum observável |
| **Regra relacionada** | RN-009 |

---

## D-05 — Fórmula da comissão de venda de peças

**`[INDEFINIDO]`**

| | |
|---|---|
| **Local** | `CVMTVPEC.PRG:113`, `CVMTVREP.PRG:53` |
| **Legado** | `COMFUN = COMFUN + (MCODFUN * 0.2)` — usa o **código** do funcionário como base de cálculo |
| **Novo** | **Preservado como está**, com aviso registrado |
| **Justificativa** | A intenção original **não é determinável**. Três leituras são igualmente plausíveis: (a) deveria ser `MSUBTOT * 0.2` (20% do item); (b) deveria ser `MTOTALC * 0.02` (2% da compra); (c) deveria ser `MQTVEND * 0.2` (R$ 0,20 por peça). O briefing §2 é explícito: *"NUNCA introduza uma regra de negócio simplesmente porque ela parece razoável"* |
| **Ação** | Implementar a fórmula literal do legado, isolada em uma função `ComissaoVendaPeca()` documentada, e escalar a questão como **Q-10** |
| **Regra relacionada** | RN-030 |

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-10.** Qual é a base de cálculo correta da comissão sobre venda de peças e reparos? O legado usa o código do funcionário. Encontrado em `CVMTVPEC.PRG:113` e `CVMTVREP.PRG:53`. As comissões de pronta entrega (1,5% do valor) e de consórcio (0,15% da prestação) usam bases coerentes, o que reforça que esta é anômala — mas não indica qual seria a correta.

---

## D-06 — Cadastro de cliente em linha sem reposicionamento

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTVPEC.PRG:29-34`, `CVMTVREP.PRG:34-39` |
| **Legado** | Após `DO CVMTCLI`, o fluxo prossegue para `MNOMCLI = NOMCLI` sem refazer o `SEEK`. `CVMTCLI` executa `CLOSE DATABASES` ao sair, então `NOMCLI` refere-se a uma área fechada |
| **Novo** | Após o cadastro em linha, refazer a busca do cliente; se ainda não existir (operador desistiu), voltar ao campo de código |
| **Justificativa** | A intenção é clara (cadastrar e continuar a venda). O código não a realiza |
| **Regra relacionada** | RN-024 |

---

## D-07 — Comissão de pronta entrega creditada ao funcionário errado

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTPENT.PRG:87-89` e `:133-134` |
| **Legado** | Após localizar o funcionário com `SEEK`, o código executa `USE CVBFUNC INDEX CVIFUN1` novamente — reabrindo a tabela e posicionando no primeiro registro. `MCOMFUN = COMFUN + (MVALCAR*0.015)` lê a comissão do **primeiro** funcionário, e o `REPLACE COMFUN` grava nele |
| **Novo** | Ler e gravar a comissão do funcionário efetivamente informado |
| **Justificativa** | A fórmula (1,5% do valor do veículo) é claramente intencional. O destino errado é consequência do `USE` redundante — não há leitura em que creditar sempre ao primeiro funcionário da tabela seja uma regra |
| **Impacto nos dados** | Confirmado: `COMFUN` do funcionário 1 (ALETHEIA KARINA) = R$ 1.500,80, contra R$ 534,75 do segundo e R$ 0,00 de três outros. `CVBPENT` tem 23 vendas distribuídas entre 6 funcionários |
| **Regra relacionada** | RN-031 |

---

## D-08 — Baixa de estoque de frota no modelo errado

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTPENT.PRG:90-92` e `:120` |
| **Legado** | Mesmo defeito de D-07: `USE CVBFROTA INDEX CVIFRO1` reabre a tabela, `MQUANCAR = QUANTCAR - 1` lê o estoque do **primeiro** modelo, e `REPLACE QUANTCAR` grava nele |
| **Novo** | Baixar o estoque do modelo efetivamente vendido |
| **Justificativa** | Idêntica a D-07 |
| **Impacto nos dados** | `CVBFROTA`: `UNO ELX` (cód. 1, primeiro registro) tem 89 unidades; os demais têm 99, 99, 100, 100. As 23 vendas de `CVBPENT` envolvem 4 modelos distintos, mas apenas o primeiro sofreu baixa |
| **Regra relacionada** | RN-034 |

---

## D-09 — CEP do cliente deixa de ser numérico

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVBCLIEN.CEPCLI` `N(8,0)` |
| **Legado** | CEP armazenado como número, perdendo zeros à esquerda. Valores reais: `798797` (6 dígitos), `5877` (4 dígitos) |
| **Novo** | `TEXT` de 8 dígitos, com `STRZERO` na migração |
| **Justificativa** | CEP não é grandeza numérica — não se soma nem se compara por magnitude. Os próprios `CEPFOR` e `CEPFUN` do legado já são texto. A inconsistência entre as três tabelas é um defeito, não uma regra |
| **Impacto na migração** | `798797` → `00798797` e `5877` → `00005877`, ambos com inconsistência registrada (provavelmente dígitos faltantes, não zeros à esquerda) |
| **Validação relacionada** | V-04, V-05 |

---

## D-10 — Numeração do participante do grupo

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTCON.PRG:62-63` |
| **Legado** | `COUNT ALL FOR mcodgru=codgru TO mnupgru` — a contagem varre todo o arquivo e, com `SET DELETED ON`, **não conta registros excluídos**. Após um fechamento de grupo (que exclui todos os participantes), a numeração reinicia em 1 |
| **Novo** | `num_participante = COALESCE(MAX(num_participante), 0) + 1` sobre o grupo, **incluindo registros excluídos**, com restrição `UNIQUE (cod_gru, num_participante)` |
| **Justificativa** | Dois participantes com o mesmo número no mesmo grupo não é uma regra — é a definição de um identificador quebrado. Confirmado nos dados: `CVBGRUPO` ativo tem participantes 1 e 2 do grupo 1, enquanto `CVBGRUCO` já tem os participantes 1, 2 e 3 do grupo 1 |
| **Impacto na migração** | Ver D-25 |
| **Regra relacionada** | RN-015 |

---

## D-11 — Prestações restantes não podem ficar negativas

**`[CORREÇÃO]` + `[VALIDAÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTCON2.PRG:38-40` |
| **Legado** | `nummes = nummes - <informado>` sem piso. Campo `N(2,0)` estoura e grava `*` |
| **Novo** | Validar na entrada: `parcelas_informadas <= parcelas_restantes`. Rejeitar com mensagem clara. Coluna `parcelas_restantes INTEGER CHECK (... IS NULL OR ... >= 0)` |
| **Justificativa** | Um saldo negativo de prestações não tem significado no domínio. O overflow que grava `**` no arquivo é corrupção de dado. Além disso, o teste de quitação é `= 0` exato (RN-021): um saldo negativo **nunca marca quitação**, o que é claramente indesejado |
| **Impacto nos dados** | 3 dos 3 registros de `CVBGRUCO` afetados: `**`, `-2`, `-3` |
| **Tratamento na migração** | **Padrão `*_legado` (definido na FASE C).** Um valor do legado que viole um `CHECK` **não é convertido nem descartado**: a coluna restrita recebe `NULL` e o valor **bruto** vai para a coluna irmã `parcelas_restantes_legado TEXT`, com inconsistência ALTA. Assim os três casos ficam preservados literalmente (`'**'`, `'-2'`, `'-3'`), o invariante do modelo é mantido, e o registro fica marcado como pendente de decisão humana. Converter `-2` para `0` seria inventar; deixar `-2` na coluna seria propagar a corrupção |
| **Alcance do padrão** | Verificado em todos os 23 DBFs: **este é o único campo do acervo que viola um `CHECK`.** Nenhuma outra coluna precisa do par `*_legado` |
| **Regra relacionada** | RN-020, RN-021 · Validação V-15 |

---

## D-12 — Fechamento de grupo passa a ser transacional

**`[MODERNIZAÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTCON.PRG:151-192` |
| **Legado** | Move N registros de `CVBGRUPO` para `CVBGRUCO` em laço, sem transação. Interrupção deixa o grupo parcialmente migrado |
| **Novo** | Modelo unificado (`consorcio_cota`): o fechamento é um único `UPDATE ... SET grupo_fechado = 1 WHERE cod_gru = ?` dentro de `BEGIN`/`COMMIT` |
| **Justificativa** | Briefing §17. O comportamento funcional (todas as cotas do grupo passam a "fechadas") é preservado; a atomicidade é acrescentada. A duplicação em duas tabelas com estruturas quase idênticas era um artifício do modelo DBF |
| **Impacto funcional** | Nenhum observável. Consultas que antes liam `CVBGRUCO` passam a filtrar `grupo_fechado = 1` |
| **Regra relacionada** | RN-018 |

---

## D-13 — Reparo não baixa estoque de peças

**`[INDEFINIDO]`**

| | |
|---|---|
| **Local** | `CVMTVREP.PRG` — ausência de `REPLACE QTDPEC` |
| **Legado** | A venda de balcão (`CVMTVPEC`) baixa o estoque; o reparo (`CVMTVREP`) **não** |
| **Novo** | **Preservado como está**, com aviso registrado |
| **Justificativa** | Duas leituras plausíveis: (a) omissão — peças de reparo saem do mesmo estoque e deveriam baixar; (b) intencional — reparos usam peças de outra origem (o `CVBALMOX` existe e nunca é baixado, Q-01). Não há evidência que decida. O briefing §2 proíbe introduzir a regra por parecer razoável |
| **Ação** | Implementar sem baixa (como o legado), com a fórmula isolada e a questão escalada como **Q-12** |
| **Regra relacionada** | RN-029 |

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-12.** Peças consumidas em reparo devem baixar o estoque de `CVBPECAS`? E o almoxarifado (Q-01), é consumido por algum evento? Encontrado em `CVMTVREP.PRG` (sem baixa) vs. `CVMTVPEC.PRG:117` (com baixa).

---

## D-14 — Índice `CVIALM1` construído sobre a tabela errada

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `SCCV.PRG:29-33` (cria sobre `CVALMOX`, `CODALM` `C(6)`) vs. `CVMTALMX.PRG:14` e `CVRALM.PRG:10` (usam sobre `CVBALMOX`, `CODALM` `N(6)`) |
| **Legado** | Chave de índice de tipo caractere aplicada a uma tabela cujo campo é numérico. `SEEK` numérico contra índice de caractere **nunca encontra** |
| **Novo** | Não se aplica — o SQLite indexa a coluna real |
| **Justificativa** | Defeito inequívoco de manutenção (a tabela foi renomeada de `CVALMOX` para `CVBALMOX` sem atualizar o bootstrap) |
| **Impacto observável no legado** | O cadastro de almoxarifado provavelmente sempre tratou todo código como "novo". Os 4 registros existentes têm códigos 1..4 sequenciais, compatíveis com inclusões sem verificação de duplicata |
| **Regra relacionada** | RN-039 |

---

## D-15 — `PACK` na saída substituído por operação administrativa explícita

**`[MODERNIZAÇÃO]` + `[VALIDAÇÃO]`**

| | |
|---|---|
| **Local** | `CV_FUNC.PRG` — `SAIDA()` |
| **Legado** | Sair do sistema executa `PACK` (exclusão física irreversível) em `CVBCLIEN`, `CVBFORNE` e `CVBFUNC`, sem backup e sem verificar dependências. Um `PACK` interrompido corrompe o arquivo |
| **Novo** | (1) Sair encerra a aplicação limpamente — nenhuma operação destrutiva. (2) A purga de registros excluídos passa a ser um comando administrativo explícito (`sccv --purgar`) que **exige backup prévio, verifica dependências e recusa purgar registros referenciados** |
| **Justificativa** | Briefing §12 e §30. A reorganização de índices deixa de existir (o SQLite mantém os próprios). A exclusão física acoplada à saída não é regra de negócio — é uma necessidade técnica do DBFNTX |
| **Impacto funcional** | Registros excluídos permanecem recuperáveis até uma purga deliberada — **mais conservador** que o legado |
| **Regra relacionada** | RN-038 · Validação V-17 |

---

## D-16 — PK técnica em `venda_veiculo`

**`[MODERNIZAÇÃO]`**

| | |
|---|---|
| **Legado** | `CVBPENT` não tem chave. A identidade de uma venda é sua posição física no arquivo |
| **Novo** | `id INTEGER PRIMARY KEY` |
| **Justificativa** | Sem identificador, é impossível referenciar, corrigir ou estornar uma venda. Nenhuma chave natural existe (mesmo cliente pode comprar o mesmo modelo no mesmo dia — e os dados mostram exatamente isso: registros 11–15 e 17 são o cliente 1 comprando `UNO ELX` na mesma data) |
| **Impacto funcional** | Nenhum na operação; a UI não expõe o `id` a menos que seja útil |

---

## D-17 — Venda de peças passa a ter cabeçalho e itens

**`[MUDANÇA FUNCIONAL]`**

| | |
|---|---|
| **Legado** | `CVPECAS` grava itens soltos. `VALTOT` (total da compra) é gravado apenas no último item da sessão. Os demais ficam com zero/vazio (28 de 75 registros) |
| **Novo** | Duas tabelas: `venda_peca` (cabeçalho: cliente, funcionário, origem, data, total) e `venda_peca_item` (item: peça, quantidade, valor unitário, subtotal) |
| **Justificativa** | O legado **já tem** o conceito de "compra com vários itens" — o laço interno de `CVMTVPEC` e o `VALTOT` no último item comprovam. Apenas não tem estrutura para representá-lo. Sem cabeçalho é impossível: totalizar corretamente um relatório (R-07 mostra 37% de linhas com total zero), estornar uma venda, ou saber quais itens pertencem à mesma compra |
| **Impacto** | O relatório R-07 passa a exibir totais corretos (CR-02). Migração conforme `08-MIGRACAO-DADOS.md` §6.1 |
| **Regra relacionada** | RN-026, RN-027 · Questão Q-02 |

---

## D-18 — Agregados materializados substituídos por *views*

**`[CORREÇÃO]`**

| | |
|---|---|
| **Legado** | `CVVCAR` e `CVVPEC` são tabelas mantidas incrementalmente pelos módulos de venda, com **chave textual** (descrição de 35 caracteres) |
| **Novo** | *Views* `v_venda_por_modelo` e `v_venda_por_peca` calculadas a partir dos dados transacionais |
| **Justificativa** | Os agregados estão dessincronizados em até **11.062 unidades** (`02-MODELO-DADOS.md` §8.8). A chave textual falhou: `TIPO 1.6 IE` no agregado nunca casou com `TIPO 1.6 IE 2 PORTAS` no cadastro, acumulando 12 vendas fantasma. Um relatório que não reflete os dados não cumpre função |
| **Impacto** | Os gráficos (R-11, R-12) passam a mostrar números reais — **diferentes dos atuais**. Os valores antigos ficam preservados nas tabelas de quarentena `_legado_cvvcar`/`_legado_cvvpec` |
| **Regra relacionada** | RN-019, RN-020 · Correção CR-08 |

---

## D-19 — Desnormalização histórica preservada

**`[COMPATIBILIDADE]`**

| | |
|---|---|
| **Legado** | Tabelas de movimento copiam nome/descrição/valor do cadastro no momento da gravação |
| **Novo** | **Preservado.** Colunas `*_snapshot` nas tabelas de movimento, além da FK |
| **Justificativa** | Não é redundância acidental: é *snapshot* histórico. As 5 divergências em `CVBPENT.DESCAR` e 1 em `CVPECAS.DECPEC` comprovam que os movimentos precedem alterações do cadastro. Substituir por `JOIN` **destruiria** informação (o nome do modelo no dia da venda) |
| **Impacto** | Nenhum. Relatórios podem escolher entre o *snapshot* e o valor atual |

---

## D-20 — Máscara e capacidade do campo alinhadas

**`[CORREÇÃO]`**

| | |
|---|---|
| **Legado** | 4 campos com máscara menor que o campo: `CODFUN` `N(6)` com `"99999"`; `CODFOR` `N(6)` com `"99999"` em `CVMTFOR` mas `"999999"` em `CVMTPEC`/`CVMTALMX`; `CODPEC` `N(6)` com `"99999"`. Também `CEPFUN` `C(9)` com `"XXXXXX-XXX"` (10 posições) no caminho de alteração |
| **Novo** | Faixa única e coerente por campo, aplicada em **todos** os pontos de entrada, com `CHECK` no banco |
| **Justificativa** | A divergência entre telas do mesmo campo é defeito, não regra. `CEPFUN` malformado nos dados (`188000-00`) é consequência direta |
| **Decisão** | Adotar a **maior** capacidade encontrada: `cod_fun`, `cod_for`, `cod_pec`, `cod_alm` até 999999; `cod_cli`, `cod_car`, `cod_con` até 99999 |
| **Validação relacionada** | V-19 |

---

## D-21 — Etiquetas não serão implementadas

**`[MUDANÇA FUNCIONAL]`**

| | |
|---|---|
| **Legado** | Opção "ETIQUETA" em 7 relatórios, via `LABEL FORM ETIQCLI/ETIQFOR/ETIQFUNC TO PRINT` |
| **Novo** | **Funcionalidade não portada.** A opção é removida do menu |
| **Justificativa** | Os três arquivos `.LBL` **não existem** no acervo. O formato `.LBL` do Clipper armazena o layout (nº de etiquetas por linha, largura, altura, margens, expressões de cada linha) — **sem o arquivo, o layout não é recuperável**. Reconstruí-lo por suposição violaria o briefing §2 |
| **Estado atual no legado** | A opção **já falha em runtime** — nenhuma etiqueta pode ser emitida hoje |
| **Ação** | Registrar como funcionalidade perdida. Se o responsável pelo negócio fornecer os `.LBL` ou especificar o layout, pode ser implementada depois |

---

## D-22 — Gráficos de pizza substituídos

**`[MODERNIZAÇÃO]`**

| | |
|---|---|
| **Legado** | `BC_GPIZZA()` da CLBC 2.7 em modo gráfico VGA/EGA, com fonte bitmap `8X8.BCM` |
| **Novo** | Gráfico de barras horizontais em caracteres no terminal + exportação CSV para ferramenta externa |
| **Justificativa** | CLBC e GIP são bibliotecas DOS proprietárias de 1992, indisponíveis e sem substituto. `8X8.BCM` também está ausente — **os gráficos já não funcionam hoje**. A informação transmitida (proporção de vendas por modelo/peça) é preservável em caracteres |
| **Impacto** | Perda da apresentação gráfica; preservação integral da informação. Combinado com D-18, os números passam a estar corretos |

---

## D-23 — Datas anteriores a 1970 preservadas

**`[COMPATIBILIDADE]`**

| | |
|---|---|
| **Legado** | Máscara `"99/99/99"` + `SET EPOCH` default (1900) fez `10/10/10` virar 1910. 12 datas afetadas |
| **Novo** | Ano de **4 dígitos** na entrada (impede novos casos). As datas existentes são **migradas como estão**, com inconsistência registrada |
| **Justificativa** | Presumir que `1910-10-10` significava `2010-10-10` seria inventar. Não há critério objetivo: `NASCLI = 1908` é implausível mas possível para um cliente idoso em 1994; `DATREP = 1910` é claramente errado; `DATAV = 1901` idem. A correção caso a caso é decisão do responsável pelos dados, informada pelo relatório de migração |
| **Validação relacionada** | V-07, V-08, V-09 |

---

## D-24 — DDD pré-1999 não é convertido

**`[COMPATIBILIDADE]`**

| | |
|---|---|
| **Legado** | Telefones no formato `(0143)051-2382` — DDD de 4 dígitos com zero de prefixo interurbano, padrão anterior à renumeração da Anatel de 1999 |
| **Novo** | Normaliza para **apenas dígitos** (`01430512382`), preserva o original com máscara, e **não converte** `0143` → `14` |
| **Justificativa** | A renumeração de 1999 é posterior aos dados (1994). Converter seria aplicar uma regra que o legado não conhece e que pode estar errada para números que não sejam de Piraju/SP. O briefing §8 pede armazenamento normalizado e apresentação formatada — ambos são atendidos sem inferir a renumeração |
| **Impacto** | A UI exibe o número com formatação; a decisão de renumerar fica com o responsável pelo negócio |
| **Validação relacionada** | V-06 |

---

## D-25 — Colisão de número de participante na migração

**`[MUDANÇA FUNCIONAL]`**

| | |
|---|---|
| **Local** | `CVBGRUPO` (2 ativos) vs. `CVBGRUCO` (3) — todos no grupo 1, participantes 1, 2 e 1, 2, 3 |
| **Legado** | Após o fechamento do grupo 1, os 3 participantes foram excluídos de `CVBGRUPO`; o `COUNT` com `SET DELETED ON` não os viu e reiniciou a numeração em 1 (defeito D-10). Dois novos consorciados (clientes 6 e 24) receberam os números 1 e 2 do mesmo grupo 1 |
| **Novo** | Os 2 registros ativos de `CVBGRUPO` recebem `num_participante` renumerado a partir de `MAX(CVBGRUCO)+1` → **4 e 5**, com inconsistência ALTA registrando os valores originais |
| **Justificativa** | A restrição `UNIQUE (cod_gru, num_participante)` (D-10) impede a carga com colisão. Duas alternativas foram descartadas: (a) atribuir um novo `cod_gru` aos ativos — inventaria um número de grupo que o legado não gerou; (b) remover a restrição — perpetuaria o defeito. A renumeração preserva ambos os registros, mantém o grupo correto e documenta a alteração |
| **Alternativa** | Se o responsável pelo negócio determinar que os clientes 6 e 24 pertencem a um **novo** grupo, a migração pode ser reexecutada com `--novo-grupo-para-ativos` |
| **Regra relacionada** | RN-015 · D-10 |

---

## D-26 — SQL sempre por *prepared statements*

**`[SEGURANÇA]`**

| | |
|---|---|
| **Legado** | Não se aplica (sem SQL). Porém o legado usa macro `&` em 6 pontos, incluindo `SET COLOR TO &CORATU` e `DO &PROG` com valores derivados de entrada indireta |
| **Novo** | Nenhuma concatenação de valores em SQL. `sqlite3_prepare_v2` + `sqlite3_bind_*` em 100% dos acessos. Nenhum uso de macro `&` com dados |
| **Justificativa** | Briefing §16. Ainda que a aplicação seja local e monousuário, a disciplina evita corrupção por dados com aspas/apóstrofos — que **existem no acervo** (`LUIZAO "TONHO DA MULA, ESCRAVAO"` em `CVCLIENT`, `4387943784378453]` em `CVBFORNE`) |

---

## D-27 — Estoque não pode ficar negativo

**`[VALIDAÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTVPEC.PRG:84-88` e `:117` · `CVMTPENT.PRG:90-92` |
| **Legado** | A venda de peças alerta quando `MQTVEND > (QTDPEC - QTDMIN)` — isto é, quando o saldo cairia **abaixo do mínimo** — e permite prosseguir mediante confirmação (RN-028). **Não existe teste algum contra o saldo cair abaixo de zero.** A pronta entrega decrementa `QUANTCAR` sem verificação prévia e só avisa *depois*, quando o saldo chegou a zero (RN-035) |
| **Novo** | `CHECK (qtd_estoque >= 0)` em `peca`, `almoxarifado` e `modelo_veiculo`. A aplicação valida antes e rejeita a operação com mensagem clara |
| **Justificativa** | Estoque físico negativo não tem significado no domínio — não existe "menos três parafusos na prateleira". O legado já demonstra intenção de controlar estoque (mantém `QTDMIN`, alerta no estouro, avisa no último veículo); o que falta é a checagem do piso absoluto, não a intenção |
| **Divergência de comportamento — declarada** | Uma venda que o legado **aceitaria** (quantidade acima do saldo, com o operador confirmando o alerta) passa a ser **rejeitada**. Esta é a única divergência deste documento que torna *mais restritiva* uma operação corrente. Registrada aqui conforme o briefing §12: *"não introduza restrições que possam quebrar dados legítimos do sistema legado sem antes documentar a divergência"* |
| **Impacto na migração** | **Nenhum.** Verificado: nenhuma das 3 tabelas tem quantidade negativa no acervo (`peca`: 9908–9950; `almoxarifado`: 10–100; `modelo_veiculo`: 89–100). A carga não é afetada |
| **O que NÃO muda** | RN-028 é preservada integralmente: vender **abaixo do estoque mínimo** continua permitido mediante confirmação. Só o piso zero é novo |
| **Alternativa, se rejeitada pelo negócio** | Trocar o `CHECK` por um aviso na aplicação, permitindo saldo negativo como o legado. É uma linha no schema e uma no serviço de estoque |
| **Regra relacionada** | RN-028, RN-029, RN-034, RN-035 · Validação V-14 |

---

## D-28 — Número do grupo de consórcio só é consumido na gravação

**`[CORREÇÃO]`**

| | |
|---|---|
| **Local** | `CVMTCON.PRG:44-46, 71` |
| **Legado** | `SAVE TO cvmgrupo ALL LIKE mcodgru` executa **antes** da confirmação "Cadastrar Consorciado". Se o operador desistir da adesão, o número já foi consumido e se perde |
| **Novo** | O sequencial só avança dentro da transação que grava a cota. Desistir não consome número |
| **Justificativa** | É consequência da ordem das instruções, não regra: nada no sistema atribui significado a buracos na numeração de grupos. RN-013 registra o comportamento como [INFERIDA], sem decidi-lo |
| **Impacto nos dados** | Nenhum. O sequencial migrado (`0`) já divergia do maior grupo existente (`1`) — sintoma do mesmo descontrole, tratado em `08` §6.4 |
| **Regra relacionada** | RN-013 |

---

## D-29 — Placa de veículo: registrada como ausência, não implementada

**`[REGISTRO]`**

| | |
|---|---|
| **Legado** | **Não existe** campo de placa em nenhum dos 23 DBFs. A frota identifica veículo por `CODCAR`, `DESCAR` e faixa de chassi (`CHASSI`/`CHASDO`); o orçamento de reparo (`CVREPAR`) não identifica o carro de forma alguma |
| **Cuidado** | Os fontes mencionam "placa" nove vezes, mas trata-se de **placa de vídeo** — `bc_cplaca()` e `bc_inictr()` são da biblioteca gráfica BCVGA, usadas em `CVGRAFRO`, `CVGRAPEC` e `CVTEABE`. As demais ocorrências em `grep` são falso positivo de `RE-PLAC-E` |
| **Novo** | Mantido ausente, por decisão do responsável em 2026-08-25 |
| **Justificativa** | O sistema modela **modelo de veículo com quantidade em estoque**, não veículo individual — 487 unidades em 5 modelos, nenhuma com identidade própria. Coerente para venda de zero-quilômetro, em que a placa só existe após o emplacamento. Acrescentar placa seria funcionalidade nova, não adaptação |
| **Se vier a ser pedido** | O caminho mínimo é uma coluna `placa` em `orcamento_reparo` (o reparo é o único ponto em que o carro do cliente importa) mais um validador dos três formatos em uso: `LL-NNNN`, `LLL-NNNN` e Mercosul `LLLNLNN`. Criar uma tabela de veículos individuais exigiria **inventar 487 registros** sem chassi nem placa reais, o que o briefing §2 proíbe |

---

## Matriz de rastreabilidade

| Divergência | Categoria | Regra/Validação | Documento de origem |
|---|---|---|---|
| D-01 | CORREÇÃO | RN-036 | 03 §C |
| D-02 | MODERNIZAÇÃO | — | 01 §3.2 |
| D-03 | CORREÇÃO | RN-012 | 03 §B |
| D-04 | CORREÇÃO | RN-009 | 03 §A |
| D-05 | **INDEFINIDO** | RN-030 / Q-10 | 03 §C |
| D-06 | CORREÇÃO | RN-024 | 03 §C |
| D-07 | CORREÇÃO | RN-031 | 03 §C |
| D-08 | CORREÇÃO | RN-034 | 03 §C |
| D-09 | CORREÇÃO | V-04, V-05 | 02 §2.1, 05 §8 |
| D-10 | CORREÇÃO | RN-015 | 03 §B |
| D-11 | CORREÇÃO + VALIDAÇÃO | RN-020, V-15 | 03 §B, 02 §8.5 |
| D-12 | MODERNIZAÇÃO | RN-018 | 03 §B |
| D-13 | **INDEFINIDO** | RN-029 / Q-12 | 03 §C |
| D-14 | CORREÇÃO | RN-039 | 00 §4, 01 §2.2 |
| D-15 | MODERNIZAÇÃO + VALIDAÇÃO | RN-038, V-17 | 03 §D |
| D-16 | MODERNIZAÇÃO | — | 02 §5 |
| D-17 | **MUDANÇA FUNCIONAL** | RN-026, RN-027 / Q-02 | 03 §C, 02 §7 |
| D-18 | CORREÇÃO | RN-019, RN-020, CR-08 | 02 §8.8, 06 §2 |
| D-19 | COMPATIBILIDADE | — | 02 §6 |
| D-20 | CORREÇÃO | V-19 | 05 §2.1 |
| D-21 | **MUDANÇA FUNCIONAL** | — | 06 §4, 07 §4 |
| D-22 | MODERNIZAÇÃO | — | 07 §1.3 |
| D-23 | COMPATIBILIDADE | V-07..V-09 | 02 §8.4, 08 §4.3 |
| D-24 | COMPATIBILIDADE | V-06 | 08 §4.5 |
| D-25 | **MUDANÇA FUNCIONAL** | RN-015, D-10 | 08 §6.2 |
| D-26 | SEGURANÇA | — | briefing §16 |
| D-27 | **VALIDAÇÃO** | RN-028, RN-029, V-14 | 03 §C, 05 §8 |

---

## Questões pendentes consolidadas

| # | Questão | Origem | Bloqueia? |
|---|---|---|---|
| Q-01 | Que evento consome o almoxarifado? | 02 §7 | Não — implementar sem consumo |
| Q-02 | Como agrupar itens de venda de peças? Origem balcão vs. reparo? | 02 §7 | Não — `origem='INDETERMINADO'` na migração |
| Q-03 | Rastreio de chassi individual é necessário? | 02 §7 | Não — manter controle por modelo |
| Q-04 | O módulo de orçamento (`CVREPAR`) deve ser implementado? | 02 §7 | Não — migrar dados, não implementar |
| Q-05 | Origem do campo `CVBPENT.FORMA` | 02 §7 | Não — migrar como está |
| Q-06 | Papel de `NUMPAG` e `NUMGRU` (sempre vazios) | 02 §7 | Não — não portar |
| Q-07 | Ciclo de vida da comissão (fechamento/pagamento) | 02 §7 | Não — manter acumulador |
| Q-08 | `CONSOR='S'` sem cota é estado válido? | 02 §7 | Não — permitir |
| Q-09 | Prestação = valor cheio do carro? | 03 RN-016 | Não — preservar |
| Q-10 | Base de cálculo da comissão de venda de peças | 09 D-05 | Não — preservar fórmula literal |
| Q-11 | Relatórios ausentes (comissões, estoque mínimo, movimento por período) | 06 §6 | Não — não criar |
| Q-12 | Reparo deve baixar estoque de peças? | 09 D-13 | Não — preservar |

**Nenhuma questão bloqueia a implementação.** Todas foram resolvidas preservando o comportamento do legado e registrando a dúvida.
