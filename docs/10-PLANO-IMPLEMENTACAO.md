# 10 — PLANO DE IMPLEMENTAÇÃO

## 1. Situação

| Fase (briefing §25) | Estado |
|---|---|
| **A — Descoberta** | **CONCLUÍDA** |
| **B — Documentação** | **CONCLUÍDA** (12 documentos) |
| **C — Modelo de dados** | **CONCLUÍDA** — `database/schema.sql` + `views.sql` aplicados e verificados |
| D — Migração | Especificada em `08-MIGRACAO-DADOS.md`; não implementada. **Próxima fase** |
| E — Testes de migração | Critérios definidos em `08` §9; não executados |
| F — Infraestrutura Harbour | **BLOQUEADA** — Harbour não instalado no ambiente (RI-01 materializado) |
| G — Implementação | Não iniciada |
| H — Validações | Especificadas em `05` §8; não implementadas |
| I — Regressão | Não iniciada |
| J — Auditoria | Não iniciada |

O legado foi movido para `legacy/` mediante autorização explícita, com backup e
**verificação SHA-256 dos 95 arquivos antes e depois (0 falhas)**, e está
protegido contra escrita (`chmod a-w`). Nenhum byte foi alterado.

Nenhuma linha de código da aplicação foi escrita — apenas DDL.

---

## 2. Estrutura de diretórios proposta

```
sccv/
├── legacy/                      ← os 90 arquivos originais, MOVIDOS na FASE C
│   ├── *.PRG  *.DBF  *.NTX  *.DBT  *.MEM  *.EXE  *.PCX
│   └── README.md                ← "somente leitura; fonte da verdade do comportamento"
│
├── src/
│   ├── main.prg                 ← ponto de entrada, argumentos de linha de comando
│   ├── app/
│   │   ├── config.prg           ← localização do banco, log, configurações
│   │   ├── log.prg              ← log estruturado em arquivo
│   │   └── erro.prg             ← ERRORBLOCK, BEGIN SEQUENCE, mensagem ao usuário
│   ├── database/
│   │   ├── conexao.prg          ← abre/fecha SQLite, PRAGMAs, WAL
│   │   ├── sql.prg              ← prepared statements, bind, step, fetch
│   │   └── transacao.prg        ← Begin/Commit/Rollback com aninhamento
│   ├── models/                  ← um arquivo por entidade; SQL vive só aqui
│   │   ├── cliente.prg          fornecedor.prg    funcionario.prg
│   │   ├── peca.prg             almoxarifado.prg  modelo_veiculo.prg
│   │   ├── venda_veiculo.prg    venda_peca.prg    consorcio.prg
│   │   └── sequencia.prg
│   ├── services/                ← regras de negócio, sem SQL e sem tela
│   │   ├── comissao.prg         ← RN-030, RN-031, RN-032 (fórmulas isoladas)
│   │   ├── estoque.prg          ← RN-014, RN-015, RN-017, RN-018
│   │   ├── consorcio.prg        ← RN-013..RN-023
│   │   └── venda.prg            ← RN-024..RN-029
│   ├── validation/
│   │   ├── documento.prg        ← CPF, CNPJ (DV)
│   │   ├── contato.prg          ← CEP, telefone
│   │   ├── data.prg             ← formato, existência, faixa
│   │   └── dominio.prg          ← UF, S/N, A/R/E
│   ├── ui/
│   │   ├── menu.prg             ← menu horizontal + submenus
│   │   ├── tela.prg             ← BORDA, MEIO, MENSAGEM, CONFIRMA, LIMPA
│   │   ├── lookup.prg           ← SelecionarCodigo() — substitui TABELA()/FUNDB()
│   │   ├── formulario.prg       ← GET/READ com validação
│   │   └── browse.prg           ← consulta (TBrowse)
│   ├── reports/
│   │   ├── relatorio.prg        ← motor: cabeçalho, paginação, destino
│   │   ├── rel_cliente.prg      rel_funcionario.prg  rel_fornecedor.prg
│   │   ├── rel_peca.prg         rel_almoxarifado.prg rel_frota.prg
│   │   ├── rel_servico.prg      ← 4 sub-relatórios
│   │   └── grafico.prg          ← barras em caracteres + CSV
│   └── migration/
│       ├── migrar.prg           ← orquestrador do pipeline
│       ├── extrator.prg         ← leitura DBF/DBT via RDD DBFNTX
│       ├── normalizador.prg     ← CP860→UTF-8, datas, centavos, documentos
│       ├── carregador.prg       ← INSERT em transação
│       ├── verificador.prg      ← contagens, somas, campo a campo
│       └── inconsistencia.prg   ← registro e relatório
│
├── database/
│   ├── schema.sql               ← DDL completo
│   ├── views.sql                ← v_* (SET DELETED ON) e agregados
│   └── migrations/              ← evolução do schema pós-implantação
│       └── 001-inicial.sql
│
├── tests/
│   ├── unit/                    ← validações, fórmulas, normalização
│   ├── integration/             ← models + services contra SQLite temporário
│   ├── migration/               ← massa legada → verificação
│   ├── regression/              ← comparação legado vs. novo (FASE I)
│   └── fixtures/                ← cópia da massa de dados de 1994
│
├── tools/
│   ├── dump-dbf.py              ← inspeção do legado (já usado na FASE A)
│   ├── dump-ntx.py              ← idem
│   └── comparar.py              ← auditoria independente da migração
│
├── config/
│   └── sccv.conf.exemplo
│
├── docs/                        ← este conjunto
├── Makefile
└── README.md
```

> **A movimentação dos arquivos originais para `legacy/` só ocorre na FASE C, mediante autorização explícita** (briefing §24). Até lá, permanecem na raiz.

---

## 3. Configuração e caminhos (briefing §14)

Ordem de precedência:

```
1. --config <arquivo>            (argumento de linha de comando)
2. $SCCV_CONFIG                  (variável de ambiente)
3. $XDG_CONFIG_HOME/sccv/sccv.conf   ou  ~/.config/sccv/sccv.conf
4. /etc/sccv/sccv.conf
5. valores embutidos
```

| Item | Padrão | Justificativa |
|---|---|---|
| Banco de dados | `$XDG_DATA_HOME/sccv/sccv.db` → `~/.local/share/sccv/sccv.db` | Dado de usuário, gravável sem privilégio (briefing §14) |
| Log | `$XDG_STATE_HOME/sccv/sccv.log` → `~/.local/state/sccv/sccv.log` | Estado volátil, não é configuração |
| Backups | `$XDG_DATA_HOME/sccv/backup/` | Junto ao dado |
| Relatórios gerados | diretório corrente ou `--saida` | Escolha do operador |
| Instalação multiusuário | `/var/lib/sccv/sccv.db` + `/var/log/sccv/` | Alternativa documentada para uso em servidor |

**A aplicação resolve todos os caminhos para absolutos na inicialização** e funciona independentemente do diretório corrente (briefing §14).

---

## 4. Roteiro por fase

### FASE C — Modelo de dados — **CONCLUÍDA** (2026-08-24)

| # | Entrega | Critério de aceite | Resultado |
|---|---|---|:-:|
| C.1 | `database/schema.sql` — 19 tabelas (12 de negócio + 1 apoio + 2 controle + 4 quarentena), 26 índices | aplica sem erro | ✅ |
| C.2 | `database/views.sql` — 14 views (`v_*` de exclusão lógica + 2 agregados) | aplica sem erro | ✅ |
| C.3 | `integrity_check` / `foreign_key_check` / `user_version` / WAL | `ok` · vazio · `1` · `wal` | ✅ |
| C.4 | Índices exercitados por `EXPLAIN QUERY PLAN` nas 12 consultas dos relatórios | usam índice; ordenação por código **sem sort temporário** | ✅ |
| C.5 | Legado movido para `legacy/` + backup + `README.md` | 95 arquivos, **SHA-256 confere antes/depois, 0 falhas**, `chmod a-w` | ✅ |
| C.6 | Decisões de tipo documentadas | `02-MODELO-DADOS.md` §9.2 (12 decisões) e §9.3; cada uma comentada no próprio SQL | ✅ |
| C.7 | `database/migrations/001-inicial.sql` (baseline) + `database/README.md` | — | ✅ |

**18 restrições verificadas contra dados reais do legado**, todas rejeitando o
caso inválido: UF inexistente (`RC`), `S/N` vazio, CEP de 6 dígitos, CPF de 14
dígitos, `1994-02-31`, data em `DD/MM/AAAA`, nome vazio, estoque negativo,
`parcelas_restantes` negativo, cota duplicada, 3 violações de FK, tipo errado em
coluna `STRICT`, monetário negativo, faixa de chassi invertida, origem de venda
inválida. `SC` e `TO` — omitidos pela lista defeituosa do legado — são aceitos.

**Divergências acrescentadas nesta fase:** D-27 (estoque não-negativo) e o
refinamento de D-11 (padrão `*_legado`).

### FASE D — Migração  *(pré-requisito: C ✅ · Harbour ✅ em `/opt/harbour`)*

| # | Entrega | Critério de aceite | Resultado |
|---|---|---|:-:|
| D.1 | `src/migration/extrator.prg` — leitura de todos os DBFs com `SET DELETED OFF` + memos | Lê os 23 DBFs; contagens batem com a análise da FASE A | ✅ |
| D.2 | `src/migration/normalizador.prg` — CP860→UTF-8, TRIM, datas ISO, centavos, CPF/CNPJ/CEP/telefone | Testes unitários por transformação | ✅ |
| D.3 | `src/migration/inconsistencia.prg` — registro nos 3 formatos (tabela, texto, CSV) | Formato do briefing §20 | ✅ |
| D.4 | `src/migration/carregador.prg` — INSERT em transação, ordem topológica | Rollback em falha simulada | ✅ |
| D.5 | Transformações estruturais: `CVPECAS`→cabeçalho/item; `CVBGRUPO`+`CVBGRUCO`→`consorcio_cota`; `.MEM`→`sequencia` | `08` §6 | ✅ |
| D.6 | `src/migration/migrar.prg` — idempotência: `--forcar`, backup automático, códigos de saída | `08` §5 | ✅ |
| D.7 | `Makefile` — `make migrate` | Executa de ponta a ponta | ✅ |

**D.1 aceita em 2026-08-24** — `tests/migration/testa_extrator.prg`, 23/23
arquivos, 182 registros ativos + 3 excluídos, conferidos contra a FASE A
(levantada por `tools/dump-dbf.py`, um parser independente).

Duas descobertas com impacto no restante da FASE D, ambas detalhadas em
`07-DEPENDENCIAS.md` §3.3:

1. **Memo e caixa do nome.** O DBFNTX procura o arquivo de memo com extensão
   minúscula (`.dbt`); o acervo tem `.DBT`. Os 3 DBFs com memo falhavam com
   `Open error`. Resolvido com `_SET_FILECASE = UPPER` + `_SET_DIRCASE = MIXED`.
2. **Abertura compartilhada.** Em modo exclusivo a leitura bruta paralela falha
   em silêncio (todos os brutos `NIL`, sem erro).

**Decisão de projeto registrada aqui: o extrator faz leitura dupla** — valor
tipado pelo RDD *e* bytes brutos do registro. Sem os brutos, `CVBGRUCO.NUMMES`
`'**'` (overflow, §8.5) e `CVBGRUPO.NUMPAG` em branco (nunca gravado, §8.6)
seriam ambos lidos como `0`, indistinguíveis de um zero legítimo — perda
silenciosa, proibida por `08-MIGRACAO-DADOS.md` §2. D.2 depende disso para
classificar corretamente esses campos.

**D.2 aceita em 2026-08-24** — `tests/migration/testa_normalizador.prg`,
**100 asserções, 0 falhas**, uma por transformação de `08 §4`, com os bytes
reais do acervo como entrada.

Três coisas ficaram registradas nesta etapa:

1. **Severidade de data depende do campo, não do valor.** `08 §4.3` fixa a regra
   "< 1970 → MÉDIA", mas sua própria tabela atribui BAIXA, MÉDIA e ALTA a datas
   da mesma década. As duas só se conciliam se a severidade considerar o que o
   campo significa: 1910 é implausível como data de reparo e possível como data
   de nascimento. `NormData()` recebe o contexto (`NASCIMENTO` / `EVENTO`) e a
   regra derivada reproduz a tabela de `08 §4.3` caso a caso.
2. **Monetário é convertido textualmente**, não por `Val(x) * 100`: multiplicar
   um binário de ponto flutuante por 100 introduz erro exatamente onde o valor
   precisa ser exato. Os bytes trazem o ponto em posição fixa.
3. **`hb_ntos()` de um resultado de `%` traz casas decimais** (`3.00`, não `3`).
   Isso quebrou silenciosamente o cálculo de DV — os testes pegaram. Onde um
   número vira dígito, o código usa `Str( n, 1 )`.

**Correção em `08 §4.5` e `§8.1`:** medindo o acervo, os 22 valores de
`CVBCLIEN.CICCLI` têm 6, 10, 12, 14 ou 15 dígitos — **nenhum tem 11**. Nenhum CPF
chega à verificação de DV. I-01 previa 22 ocorrências MÉDIA e I-02 previa ~6
ALTA; o correto é **0 e 22**. A coluna `cliente.cpf` ficará inteiramente `NULL`,
com os 22 originais preservados em `cpf_original`. As outras seis previsões
conferidas contra os dados reais bateram exatamente.

**D.3 aceita em 2026-08-24** — `tests/migration/testa_inconsistencia.prg`,
**35 asserções, 0 falhas**: acumulação e contagem por severidade, os três
formatos de saída, escape RFC 4180 no CSV, gravação em
`migracao_inconsistencia` com a FK para `migracao_execucao` e o `CHECK` de
severidade barrando valor inválido.

Foi criada também `src/database/sql.prg` — camada mínima sobre o `hbsqlit3`
(statements preparados com bind por tipo, transações, leitura escalar). O bind
por tipo não é estilo: as tabelas são `STRICT`, então gravar texto em coluna
`INTEGER` é erro, e concatenar valor no SQL levaria as aspas dos dados do
legado (`o babaca.`) para dentro do comando.

**Armadilha encontrada: `SET EXACT OFF`.** No Clipper e no Harbour a comparação
com `=`/`!=` entre strings é por prefixo, não exata — e **toda** string "é igual"
a `""`. O cabeçalho por arquivo do relatório em texto nunca era emitido porque
`h["arquivo"] != ""` é falso. Corrigido para `!( a == b )` aqui, em
`extrator.prg` e em `normalizador.prg`. Onde a comparação de strings for de
igualdade, o código usa `==`.

**Compilação:** o `.ch` do `hbsqlit3` não está no include path padrão. É preciso
`-I/opt/harbour/contrib/hbsqlit3` além de `-lhbsqlit3 -lsqlite3`. Vai para o
`Makefile` em D.7.

**D.4 a D.7 aceitas em 2026-08-24.** `tests/migration/testa_migracao.prg` —
**48 asserções, 0 falhas**, incluindo o rollback em falha simulada (um cliente
plantado colide no registro 22; a tabela volta ao estado anterior e nenhuma
tabela seguinte é tocada). `make test` roda os quatro testes de aceite.

Resultado da migração completa sobre o acervo real:

| | |
|---|---:|
| Registros lidos | 185 |
| Registros gravados | 222 |
| Inconsistências | 102 (ALTA 38 · MEDIA 26 · BAIXA 38) |
| `integrity_check` · `foreign_key_check` | `ok` · vazio |

Contagens conferidas contra `08 §3.1`: cliente 22 · funcionario 10 ·
fornecedor 3 · peca 4 · almoxarifado 4 · modelo_veiculo 5 · venda_veiculo 23 ·
venda_peca_item 75 · consorcio_cota 5 · orcamento_reparo 4 · pedido 0 ·
sequencia 1 · quarentena 26 + 3.

Idempotência (`08 §5`) verificada nos cinco caminhos, com os códigos de saída de
`§11`: destino novo → 0 · destino populado sem `--forcar` → 3 · com `--forcar`
→ 0 e backup `.bak.<timestamp>` · origem inválida → 2 · opção desconhecida → 1.
Duas execuções independentes produzem contagens idênticas.

**Correção em `08 §6.1`:** a estimativa de "47 registros com `VALTOT` > 0 →
~47 cabeçalhos" estava errada. O real é **32** com `VALTOT` > 0, gerando **37**
cabeçalhos (32 fechados por `VALTOT`, 4 por troca de cliente, 1 pela soma final).
Conferido por duas implementações independentes do algoritmo.

**Três defeitos que só apareceram rodando:**

1. `cliente.consorcio` é `TEXT` com `CHECK IN ('S','N')`, não `0`/`1`. O
   diagnóstico veio errado ("not an error") porque `sqlite3_errmsg()` era lido
   **depois** de `sqlite3_finalize()`, quando a mensagem já se perdeu.
   `SqlExecBind()` agora captura a mensagem antes de finalizar.
2. `database/schema.sql` já semeia a linha `sequencia('consorcio_grupo')`, então
   a carga precisa de `ON CONFLICT DO UPDATE`, não `INSERT`.
3. `hb_TToC()` junta data e hora com espaço — o backup saía como
   `sccv.db.bak.20260824 154613`, com espaço no nome do arquivo.

**Nota de sintaxe do Harbour:** um comentário em linha própria no meio de uma
expressão continuada com `;` quebra a continuação. Comentário vai antes da
instrução.

### FASE E — Testes de migração  *(pré-requisito: D ✅)* — **CONCLUÍDA** (2026-08-24)

| # | Verificação | Tolerância | Resultado |
|---|---|---|:-:|
| E.1 | Contagem por tabela (com e sem excluídos) | zero | ✅ |
| E.2 | 7 somas de controle (`08` §9.2) | zero | ✅ |
| E.3 | Comparação campo a campo — **100% dos registros** | zero | ✅ |
| E.4 | `PRAGMA foreign_key_check` + reconciliação das 13 FKs | vazio | ✅ |
| E.5 | Relatório de inconsistências gerado e revisado | ~170 esperadas (`08` §8.1) | ✅ |

`src/migration/verificador.prg` + `tests/migration/testa_verificacao.prg`:
**56 verificações, 0 falhas**; **892 campos** comparados um a um, zero
divergências; 13 relações de FK reconciliadas, zero órfãos.

**As somas de controle são independentes do código que migrou.** Elas são
calculadas a partir dos bytes brutos do DBF, em aritmética inteira de centavos,
sem passar pelo normalizador. Se a normalização estiver errada, elas acusam.

**A comparação campo a campo prova outra coisa.** Ela reaplica o normalizador ao
dado de origem, então não valida a regra de normalização — usa a mesma regra dos
dois lados. O que ela valida, e é o risco real de um `INSERT` com 17 colunas, é o
**mapeamento**: coluna trocada, campo fora de ordem, valor na linha errada. Onde
dá para conferir sem o normalizador — data ISO montada direto dos bytes, `S`/`N`
do consórcio, ordem física dos 75 itens — a conferência é feita contra os bytes.
A limitação está dita no cabeçalho do módulo, não escondida.

**A verificação foi testada contra corrupção plantada.** Uma verificação que
nunca falha não verifica nada, então o teste altera o banco de propósito e exige
que a verificação acuse: 1 centavo a mais num salário (E.2 acusa), um nome com
um caractere a mais (E.3 acusa), um item apagado (E.1 acusa) — e volta a passar
quando a alteração é desfeita.

**§9.5 — divergência esperada e confirmada:** as views `v_venda_por_modelo` e
`v_venda_por_peca` divergem das tabelas de quarentena `_legado_cvvcar` e
`_legado_cvvpec`, como previsto. As views reproduzem o movimento transacional
real; os agregados do legado estavam dessincronizados e ficam só como evidência.

#### Revisão do relatório (E.5)

O total foi de **102 → 140 inconsistências** nesta fase, ao implementar as
observações que só existem depois da carga porque comparam conjuntos, não
valores isolados: I-10, I-12, I-15, I-16, I-20, I-21 e I-24.

Reconciliação com a previsão de `08` §8.1:

| | |
|---|---:|
| Registradas | **140** |
| I-11 — deliberadamente não emitida (ver abaixo) | 28 |
| **Equivalente à previsão** | **168** |
| Previsto em §8.1 (após a correção de D.2) | ~165 |

**I-11 não é emitida de propósito.** "`VALTOT` vazio em item não-final" é o caso
**normal** do legado — `VALTOT` só é preenchido no último item da compra
(RN-027), e é exatamente esse o sinal que o agrupamento de §6.1 usa para saber
onde a venda termina. Emitir 28 linhas descrevendo o comportamento esperado
afogaria as 140 que apontam problema real. A decisão está comentada em
`carregador.prg`, junto do código, para não parecer omissão.

### FASE F — Infraestrutura Harbour — **CONCLUÍDA** (2026-08-24)

| # | Entrega | Critério de aceite | Resultado |
|---|---|---|:-:|
| F.1 | `Makefile` com `all`, `clean`, `test`, `migrate`, `run`, `install`, `check-deps` | `make check-deps` reporta corretamente | ✅ |
| F.2 | `src/database/conexao.prg` + `sql.prg` (hbsqlit3, prepared statements) | Teste: abre, PRAGMAs, consulta parametrizada, fecha | ✅ |
| F.3 | `src/database/transacao.prg` com aninhamento (savepoints) | Teste: rollback interno não derruba a transação externa | ✅ |
| F.4 | `src/app/erro.prg` — `ERRORBLOCK`/`BEGIN SEQUENCE`, mensagem sem stack trace, contexto no log | Briefing §18 | ✅ |
| F.5 | `src/app/log.prg` — níveis, rotação simples, caminho configurável | — | ✅ |
| F.6 | `src/app/config.prg` — precedência de 5 níveis, caminhos absolutos | Funciona de qualquer diretório | ✅ |
| F.7 | Documentar versão do Harbour, GCC, flags | Briefing §27 | ✅ |

`tests/unit/testa_infra.prg`: **75 asserções, 0 falhas**. Também entra em cena
`src/main.prg` (`bin/sccv`), que por enquanto sobe a infraestrutura e se
apresenta — `--estado`, `--config-mostrar`, `--versao`. Os módulos funcionais
são a FASE G.

**F.3 — por que savepoints.** O SQLite não aninha `BEGIN`: o segundo é erro. Mas
serviços chamam serviços — "registrar venda" abre transação e chama "baixar
estoque", que também quer a sua. Sem aninhamento, ou o serviço interno nunca
pode abrir transação (e deixa de ser reutilizável), ou o externo perde o
controle. O nível 1 abre `BEGIN`; os internos abrem `SAVEPOINT`. Desfazer o
interno volta ao savepoint e a transação externa continua viva — o critério de
aceite, literal.

Com uma ressalva deliberada: quando uma camada interna desfaz, a externa fica
**marcada**. Confirmar o conjunto como se estivesse completo seria mentira, então
`TransConfirmar()` no nível 1 devolve `.F.` e desfaz tudo. `TransExecutar()` é a
forma preferida — não existe caminho de saída que esqueça o rollback.

**F.4 — o que o usuário vê e o que o log recebe.** O briefing §18 proíbe `BREAK`
e `QUIT` como estratégia genérica. `BREAK` aparece uma única vez, dentro do
`ERRORBLOCK`, que é o mecanismo do próprio Harbour para transferir controle a um
`BEGIN SEQUENCE` — o oposto de abandonar o programa. Nenhum `QUIT`: quem encerra
é `main.prg`, com código de saída. Ao usuário vai o que aconteceu, em português,
e o que ele pode fazer; ao log vão subsistema, `genCode`, `subCode`, `osCode`,
arquivo e a pilha de chamadas. O teste verifica as duas metades — inclusive que a
mensagem ao usuário **não** contém nome de função nem número de linha.

**F.6 — arquivo de configuração não é mesclado.** O primeiro que existir vence, e
as chaves ausentes caem no valor embutido. Mesclar daria uma configuração efetiva
que não está escrita em lugar nenhum; quem for diagnosticar um problema precisa
poder abrir **um** arquivo e ver o que vale. `sccv --config-mostrar` imprime o
efetivo e de onde veio. Caminhos viram absolutos na carga, então mudar de
diretório depois não muda para onde a aplicação escreve.

**Detalhe do ambiente aprendido aqui:** em coluna `TEXT` de tabela `STRICT`, o
SQLite **converte** `INTEGER` e `REAL` para texto — só o inverso é erro. Está
documentado no teste, porque é fácil supor simetria e não há.

### FASE G — Implementação dos módulos — **CONCLUÍDA** (2026-08-25)

Ordem obrigatória, **por dependência** (`07` §2.2):

| Onda | Módulos | Depende de |
|---:|---|---|
| **1** ✅ | `ui/` (menu, tela, lookup, formulário, browse) · `validation/` completo | F |
| **2** ✅ | Cadastros nível 0: **cliente**, **funcionário**, **fornecedor**, **modelo_veiculo** (manutenção + consulta) | 1 |
| **3** ✅ | Cadastros nível 1: **peça**, **almoxarifado** (manutenção + consulta) | 2 |
| **4** ✅ | `services/comissao.prg` · `services/estoque.prg` | 2, 3 |
| **5** ✅ | Movimento: **venda de peças (balcão)**, **reparo**, **pronta entrega** | 3, 4 |
| **6** ✅ | **Consórcio**: adesão, fechamento de grupo, baixa de prestações, sorteio | 2, 4 |
| **7** ✅ | Relatórios R-01..R-10 | 2–6 |
| **8** ✅ | Gráficos R-11, R-12 (barras + CSV) | 5 |
| **9** ✅ | Comandos administrativos: `--purgar`, `--backup`, `--restore`, `--verificar` | todos |

Cada módulo entra em "concluído" apenas quando: implementado + validado + coberto por teste + registrado na matriz (§5).

#### Onda 1 — concluída em 2026-08-24

`src/validation/` (101 asserções) e `src/ui/` (52 asserções).

- **A regra de dígito verificador passou a ter uma implementação só.** O
  normalizador da migração chama a de `validation/`. Duas cópias divergiriam, e
  um documento seria aceito na tela e recusado na migração.
- **V-08 ficou em dois níveis.** Não há limiar objetivo entre idade improvável e
  erro de digitação: erro acima de 130 anos, aviso acima de 110 — o mesmo padrão
  alerta-com-confirmação de RN-028. Um limiar único ou barraria cadastro
  legítimo, ou deixaria passar o `1901-01-01` que V-08 cita como evidência.
- **O `§9` de `05` é tão normativo quanto o `§8`** e está coberto por teste: CPF,
  CNPJ, telefone, endereço, UF e data de venda **não** podem virar obrigatórios.
- **O lookup retorna o código** (D-02), em vez de preencher a variável do
  chamador por macro como `TABELA()`/`FUNDB()` faziam.

#### Onda 2 — concluída em 2026-08-24

Cadastros de nível 0, com manutenção e consulta. 63 asserções em
`tests/integration/testa_cadastro.prg`. **7 dos 19 destinos do menu ligados.**

**Um motor, não quatro cópias.** O legado tinha `CVMTCLI`, `CVMTFUNC`, `CVMTFOR`
e `CVMTFRO` como quase-cópias, e é dessa duplicação que vêm defeitos como D-01: a
regra evolui num arquivo e não nos outros, e nada declara que deveriam ser iguais.
`models/modelo.prg` concentra o SQL e a mecânica, dirigido por descritor; cada
entidade traz só o que difere; `ui/cadastro.prg` é uma tela só.

Decisões desta onda:

- **Código de registro excluído não é reciclado.** `ModeloProximoCodigo` usa
  `MAX` sobre a tabela, incluindo excluídos. O legado usava `MAX` com
  `SET DELETED ON`, e foi assim que a numeração colidiu em RN-015.
- **Exclusão lógica confere dependências antes** (V-17). As FKs do schema não
  bastam: `excluido = 1` não é `DELETE`, e o SQLite não tem o que barrar.
- **Quem valida é o modelo, não o formulário.** A tela só coleta, para que a
  regra seja a mesma vindo da tela ou de qualquer outro caminho.
- **O par coluna/`*_original` vale também na digitação** (V-03).

**Dois defeitos que só apareceram executando**, ambos corrigidos em commit
próprio:

1. `tela.prg` usava `HB_B_SINGLE_UNI` sem incluir `box.ch`. O compilador aceita
   — identificador desconhecido vira busca de variável em tempo de execução —
   então compilava limpo e quebrava ao desenhar a primeira caixa. O menu subia,
   mas qualquer submenu, lookup ou cadastro derrubava a interface.
2. `SqlExecBind()` mandava qualquer tipo não previsto para `sqlite3_bind_text()`,
   que aborta o processo. Agora cada tipo é tratado e o que não é gravável vira
   erro com mensagem.

#### Onda 3 — concluída em 2026-08-24

Cadastros de nível 1: peça e almoxarifado. O motor da onda 2 foi reusado sem
alteração — os dois entraram como descritor, e o teste subiu de 63 para 85
asserções. **9 dos 19 destinos do menu ligados.**

O interesse desta onda está nos dois defeitos do legado que ela **não**
reproduz, ambos já classificados como `[CORREÇÃO]`:

- **D-01** — `CVMTPEC.PRG:73` fazia `MCODPEC = CODFOR` no caminho de alteração,
  e a linha 135 gravava isso de volta em `CODPEC`: alterar uma peça escrevia o
  código do **fornecedor** no campo de código da **peça**, corrompendo a chave
  primária. Aqui a chave não entra no `UPDATE` — só no `WHERE`. Não é precaução
  contra o defeito antigo: reatribuir a PK numa alteração não faz sentido em
  lugar nenhum. Coberto por asserção: depois de alterar a peça 10 com
  fornecedor 1, a peça 10 continua existindo e a peça 1 não foi criada.
- **D-14** — o índice `CVIALM1` era criado sobre `CVALMOX` (código `C(6)`) e
  usado sobre `CVBALMOX` (código `N(6)`). `SEEK` numérico contra índice de
  caractere nunca encontra, então o cadastro de almoxarifado provavelmente
  sempre tratou todo código como novo, sem detectar duplicata. Não houve o que
  corrigir no código: o defeito era estrutural e some com o modelo relacional.
  Coberto por asserção: código duplicado agora é recusado.

E uma regra que **continua** como no legado: estoque abaixo do mínimo é
**aviso com confirmação**, não bloqueio (RN-028, `05` §9). O cadastro grava e
avisa.

`RN-036` — o nome do fornecedor era uma coluna copiada dentro da peça
(`NOMFOR`). Não existe mais: `v_peca` traz `nome_fornecedor` por JOIN. Cadastro
não tem valor histórico a preservar, ao contrário do movimento, onde o snapshot
é deliberado (D-19).

#### Onda 4 — concluída em 2026-08-24

`services/comissao.prg` e `services/estoque.prg`. 50 asserções em
`tests/unit/testa_servicos.prg`.

Esta onda é quase toda sobre **preservar defeito de propósito**, e o teste
existe tanto para verificar o que foi feito quanto para impedir que alguém
"conserte" o que não deve ser consertado sem decisão do negócio.

**Comissão** — três fórmulas, duas coerentes e uma anômala:

| Regra | Base | Estado |
|---|---|---|
| RN-030 venda de peças e reparos | **código do funcionário** × 0,20 | preservada literal — **Q-10** |
| RN-031 pronta entrega | 1,5% do valor do veículo | preservada |
| RN-032 consórcio | 0,15% da prestação | preservada |

RN-030 usa o *código* do funcionário como base: quem tem código 11 ganha R$ 2,20
por venda e quem tem código 1 ganha R$ 0,20, independentemente do valor vendido.
Não foi corrigida — três leituras são igualmente plausíveis (20% do item, 2% da
compra, R$ 0,20 por peça) e nada decide entre elas. Fica isolada em
`ComissaoVendaPeca()`, de três linhas: responder Q-10 é alterar uma linha.

**D-07 corrigido:** a comissão vai para o funcionário informado. No legado, um
`USE CVBFUNC` redundante reposicionava a tabela e creditava sempre o primeiro do
arquivo — visível nos dados, com o funcionário 1 acumulando R$ 1.500,80 contra
R$ 0,00 de três outros, em 23 vendas distribuídas entre 6 vendedores.

**Estoque** — o legado tinha **um** alerta e **nenhuma** checagem de piso. Aqui
são dois conceitos separados, e a distinção é o ponto da onda:

- **abaixo do mínimo** → aviso, prossegue com confirmação. RN-028, preservada
  integralmente;
- **abaixo de zero** → recusa. D-27, a única divergência do projeto que torna
  *mais restritiva* uma operação que o legado aceitava. Estoque físico negativo
  não significa nada.

**D-08 corrigido:** a baixa sai do modelo efetivamente vendido. No legado saía
sempre do primeiro da tabela — está nos dados: o primeiro modelo tem 89 unidades
e os demais 99, 99, 100, 100, embora as 23 vendas envolvam 4 modelos.

**D-13 preservado (Q-12):** o reparo continua **não** baixando estoque de peças.
`EstoqueReparoBaixa()` devolve `.F.` e existe para que a decisão, quando vier,
tenha um lugar só para mudar.

**Acréscimo declarado:** `EstoqueRepor()` não existe no legado, onde não há
cancelamento de movimento. Sem ela, excluir uma venda deixaria o estoque
permanentemente errado.

**Aritmética em centavos, inteira.** O legado calculava em ponto flutuante e
gravava em `N(12,2)`, deixando o Clipper arredondar. Aqui o arredondamento é
explícito, para o centavo mais próximo — `0,015` não tem representação binária
exata, e usá-lo faria centavos aparecerem e sumirem conforme o valor.

**Erro no roteiro, corrigido:** a tabela de ondas atribuía a `estoque.prg` as
regras RN-014, RN-015, RN-017 e RN-018 — que são de **consórcio**, não de
estoque. As regras de estoque são RN-028, RN-029, RN-034 e RN-035, e são essas
que a onda implementou. As de consórcio ficam para a onda 6.

#### Onda 5 — concluída em 2026-08-25

Movimento: venda de peças (balcão), reparo e pronta entrega. 55 asserções em
`tests/integration/testa_venda.prg`. **12 dos 19 destinos do menu ligados.**

É a onda que faz os serviços da onda 4 saírem do laboratório: cada venda gravada
baixa o estoque certo e credita a comissão ao funcionário certo, dentro de uma
transação.

- **D-17 realizado.** A venda passa a ter cabeçalho e itens. O total mora no
  cabeçalho e é a soma dos subtotais, calculada — nunca acumulada numa variável
  que só chega ao disco no último item, que é o que produzia os 28 registros com
  total zero no legado (RN-027).
- **D-06 corrigido.** Depois do cadastro de cliente em linha, a busca é
  REFEITA. No legado o fluxo seguia sem refazer o `SEEK`, lendo o nome de uma
  área que `CVMTCLI` havia fechado.
- **Q-02 respondida para vendas novas.** O legado não distinguia balcão de
  reparo — ambos caíam em `CVPECAS` sem marca, e por isso as 37 vendas migradas
  ficaram com `origem = 'INDETERMINADO'`. A venda nova declara sua origem.
- **D-13 preservado.** O reparo grava a venda e credita comissão, mas **não**
  baixa estoque. A condição está num lugar só, explícita.
- **Saldo considera o que já está na venda.** Três itens de 5 unidades da mesma
  peça, num estoque de 10, passariam individualmente e estourariam na gravação.
  O legado não tinha esse problema porque gravava item a item.

**Defeito encontrado e corrigido: `TransExecutar` confirmava trabalho parcial.**

A função só desfazia a transação quando havia exceção do Harbour. Um bloco que
detectasse o problema por conta própria e devolvesse a mensagem — "estoque
insuficiente", por exemplo — era tratado como sucesso, e a transação
**confirmava**. Foi assim que uma venda de veículo ficou gravada depois de a
baixa de estoque ter falhado: o cabeçalho persistia, o estoque não mudava, e a
função devolvia erro. O pior dos dois mundos.

O contrato do bloco passou a ser explícito: devolver `NIL` ou número é sucesso;
devolver **texto** é falha, e a transação é desfeita. `ModeloGravar` e
`ModeloExcluir` foram ajustados ao mesmo contrato, onde a fragilidade era
latente. Coberto por teste em `testa_infra`.

**Nota de build:** `models/venda.prg` e `services/venda.prg` colidiam — o
`hbmk2` nomeia os objetos pelo nome BASE do fonte, então dois arquivos com o
mesmo nome em diretórios diferentes geram o mesmo `.o` e um sobrescreve o outro,
com erro de símbolo indefinido no link. Nomes de fonte precisam ser únicos no
projeto inteiro. O modelo foi dividido em `venda_peca.prg` e
`venda_veiculo.prg`, o que também alinha com a estrutura de §2.

#### Onda 6 — concluída em 2026-08-25

Consórcio: adesão, fechamento de grupo, baixa de prestações e contemplação.
70 asserções em `tests/integration/testa_consorcio.prg`. **13 dos 19 destinos.**

É a área que mais acumulou defeito no legado — dos cinco valores de `NUMMES` no
acervo, três são inválidos (`**`, `-2`, `-3`), todos consequência de RN-020
subtrair sem piso em zero.

**Corrigidos:**

- **D-10** — número do participante é `MAX + 1` sobre o grupo, incluindo
  excluídos. O legado usava `COUNT` com `SET DELETED ON`, que não conta
  excluídos: depois de fechar um grupo a numeração reiniciava em 1. Está nos
  dados — `CVBGRUPO` tinha os participantes 1 e 2 do grupo 1 enquanto `CVBGRUCO`
  já tinha 1, 2 e 3 do mesmo grupo.
- **D-11** — baixar mais prestações do que o saldo é recusado. Saldo negativo de
  prestações não significa nada, mesma natureza de D-27 para estoque.
- **D-12** — o fechamento é um `UPDATE` numa transação, não um laço movendo N
  registros entre duas tabelas sem transação.
- **D-28 (nova)** — o número do grupo só é consumido na gravação. No legado o
  `SAVE TO cvmgrupo` vinha antes da confirmação, e desistir queimava o número.

**Preservados:**

- **RN-016 / Q-09** — a prestação é o valor **cheio** do carro, não dividido
  pelo número de meses. Anômalo, mas o legado não diz se é intenção ou defeito.
- **RN-023** — se o modelo estiver esgotado na contemplação, a unidade não é
  baixada, o aviso aparece **e a marca de sorteado permanece**. No legado o
  `REPLACE` de `SORT` vinha antes do teste de estoque e não havia reversão. O
  resultado da função diz explicitamente que a marca foi gravada sem baixa.
- **RN-021** — a quitação testa `= 0` exato, como no legado.
- **RN-019** — `sorteado` e `quitado` agora são inicializados **explicitamente**;
  no legado ficavam `.F.` por acidente do `APPEND BLANK`.

**Cotas herdadas da migração com saldo inválido** (`parcelas_restantes` nulo e o
bruto em `*_legado`) recusam baixa de prestações com mensagem que explica a
origem e mostra o valor original. Sem saldo conhecido não há o que subtrair.

#### Onda 7 — concluída em 2026-08-25

Relatórios R-01 a R-10. 50 asserções em `tests/integration/testa_relatorios.prg`.
**18 dos 20 destinos do menu ligados.**

Os dez relatórios são **dado**, não código: cada um é uma definição com SQL,
colunas e totais, e o motor é um só. A geração de linhas é separada do desenho,
o que permite verificar conteúdo, filtros e totais dos dez sem abrir terminal —
e faz o mesmo relatório servir tela, arquivo e impressão sem três
implementações.

Correções de `06` §6 aplicadas:

| # | O que era | O que é |
|---|---|---|
| CR-01 | R-09 referenciava 7 campos, dos quais **6 não existem** em `CVBGRUCO` — erro de runtime na primeira linha. Nunca funcionou | Mapeado para os campos reais; funciona |
| CR-02 | R-07 mostrava `VALTOT`, que só existe na última linha de cada compra: 37% das linhas com zero, sem total | Subtotal por linha e **total geral** |
| CR-03 | R-07 e R-08 liam a mesma tabela sem filtro e mostravam os mesmos registros | Filtram por origem: balcão e reparo |
| CR-04 | "Relatório de estoque de peças" sem mostrar estoque | Quantidade e mínimo incluídos |
| CR-05 | Primeira página da frota saía sem cabeçalho | Cabeçalho é parte da geração |
| CR-06 | Pausa em tela nunca ocorria (`IF NL = 18`, mas `NL` só era 23 ou 60) | Paginação pela altura real do terminal |
| CR-07 | Colunas `C(35)` invadiam a coluna seguinte em três relatórios | Posicionamento por largura |
| CR-09 | Páginas se sobrepunham em tela | `CLS` na quebra |

As vendas **migradas** têm `origem = 'INDETERMINADO'` e não aparecem em R-07 nem
em R-08. O dado do legado não permite classificá-las (Q-02), e inventar a
classificação seria pior do que declarar a lacuna.

R-09 lista apenas grupos **fechados**, como o legado — ele lia `CVBGRUCO`.
Relatório de grupos em formação é uma das lacunas de Q-11, e não foi criado.

**Defeito encontrado e corrigido: `Left()` e `PadR()` contam bytes.**

Em UTF-8 `Ó` ocupa dois bytes, então `Left( "CÓDIGO", 6 )` devolve `CÓDIG` — a
coluna sai cortada e o preenchimento erra a largura na mesma medida,
desalinhando tudo o que vier depois. Num relatório em português isso atinge
quase todo cabeçalho. O motor passou a usar `hb_ULeft()`, `hb_UPadL()`,
`hb_UPadR()` e `hb_UPadC()`, que contam caracteres.

Etiquetas continuam **não implementadas** (D-21): os `.LBL` estão ausentes e o
layout não é recuperável.

#### Onda 8 — concluída em 2026-08-25

Gráficos R-11 e R-12. 34 asserções em `tests/integration/testa_graficos.prg`.
**19 dos 20 destinos do menu ligados** — só "Comissões" falta, e é uma das
lacunas de Q-11.

**Barras em caracteres, não pizza.** O legado desenhava pizza com as bibliotecas
CLBC 2.7 e GIP 1.0 mais a fonte `8X8.BCM` — nenhuma delas existe no acervo, só
os executáveis `BCVGA.EXE` e `BCRETCTR.EXE`, que não são fonte. Reproduzir a
pizza exigiria escolher uma biblioteca gráfica nova e uma janela gráfica, para
um sistema de terminal. A informação funcional — a distribuição das vendas por
item — é preservada; a representação, que era limitação da época, não.

**CR-08 / D-18 — o agregado vem de consulta.** Os gráficos liam `CVVCAR` e
`CVVPEC`, tabelas mantidas incrementalmente e com chave **textual**. Estavam
dessincronizadas em até 11.062 unidades: `TIPO 1.6 IE` no agregado nunca casou
com `TIPO 1.6 IE 2 PORTAS` no cadastro, acumulando 12 vendas fantasma. Agora o
número vem das views sobre o movimento real.

**A divergência é mostrada, não escondida.** Como D-18 previu que os números
mudariam, e mudança de número sem explicação é indistinguível de erro, o gráfico
exibe o confronto: o que o movimento real diz, o que o agregado antigo dizia, e
a observação de que ele ficou dessincronizado.

**O título deixou de dizer "mensal".** Os gráficos do legado se chamavam "Venda
Mensal", mas não há recorte temporal algum — `CVPECAS` não tem campo de data e
as agregadas acumulavam desde sempre. Chamar de mensal um acumulado histórico é
afirmar algo falso na tela. O recorte por período segue registrado em Q-11.

**Detalhe do CSV:** o valor monetário usa **ponto** como separador decimal, não
a vírgula brasileira — porque a vírgula é o separador de campo do arquivo, e
`100,00` partiria a linha em duas colunas. Quem abre a planilha ajusta a
localidade; um CSV quebrado não tem conserto.

#### Onda 9 — concluída em 2026-08-25

Comandos administrativos. 49 asserções em `tests/integration/testa_admin.prg`.
**Encerra a FASE G.**

| Comando | O que faz |
|---|---|
| `sccv --backup` | Cópia física pela API de backup do SQLite |
| `sccv --dump <arq>` | Cópia lógica em SQL, versionável e recarregável |
| `sccv --restore <arq>` | Confere o backup **antes** e preserva o atual em `.bak` |
| `sccv --verificar` | `integrity_check`, `foreign_key_check` e contagens |
| `sccv --purgar [--simular]` | Apaga definitivamente os excluídos, com backup obrigatório |

**D-15 — a purga deixou de ser efeito colateral de sair do sistema.** No legado,
`SAIDA()` executava `PACK` em `CVBCLIEN`, `CVBFORNE` e `CVBFUNC` ao encerrar:
exclusão física, irreversível, sem backup e sem verificar dependências. Um
`PACK` interrompido corrompia o arquivo. Agora sair encerra a aplicação e mais
nada; a purga é deliberada e tem três garantias que o `PACK` não tinha:

1. **backup obrigatório**, não desativável — se ele falhar, a purga não ocorre;
2. registro ainda referenciado **não é purgado**, é relatado com o motivo (V-17);
3. tudo numa transação — purga interrompida não deixa o banco pela metade.

`--simular` mostra o que seria apagado sem apagar nada.

**A cópia de banco usa a API do próprio SQLite**, não cópia de arquivo. Funciona
com o banco aberto e em uso, e o destino é necessariamente um banco válido —
copiar bytes de um arquivo em escrita poderia produzir algo truncado no meio de
uma transação. O restore usa a mesma API nas duas pontas: preserva o atual e
grava o novo.

**Três defeitos encontrados escrevendo esta onda:**

1. `hb_vfCopyFile()` não devolve lógico, e `IF !hb_vfCopyFile(...)` derrubava o
   processo. Resolvido usando a API de backup, que era o meio certo desde o
   início.
2. **`==` contra `NIL` levanta erro de tipo** quando a variável contém string —
   `!=` tolera, `==` não. Onde o valor pode ser texto ou nada, usar `Empty()`.
3. **O Harbour não interpreta `\` em string literal** como o C: a cláusula
   `LIKE '\_%' ESCAPE '\'` virava dois caracteres onde o SQL exige um, e a
   consulta falhava em silêncio, devolvendo lista vazia. Trocado por `substr()`.

E um cuidado que virou verificação: `sqlite3_open()` aceita **qualquer** arquivo
e só descobre que não é um banco na primeira consulta. O restore confere o
cabeçalho (`SQLite format 3`) antes de qualquer coisa, e depois confere que o
banco é mesmo do S.C.C.V. — restaurar um arquivo alheio sobre o banco bom troca
um problema por dois.

**Limite declarado:** os fluxos interativos (navegação, edição em tela) **não têm
teste automatizado**. O que é testável foi separado do desenho e está coberto; o
desenho depende de verificação à mão. Injeção por pseudo-terminal se mostrou não
confiável (um ESC isolado vindo por pipe chega ao GT como `K_RIGHT`);
`hb_keyPut()` funciona — foi ela que encontrou o defeito do `box.ch` — mas o
arnês não foi fechado.

### FASE H — Validações  *(paralela às ondas 1–3 da FASE G)*

Implementar V-01..V-20 (`05` §8), respeitando as proibições de `05` §9.

### FASE I — Regressão  *(pré-requisito: G, H)*

| # | Teste | Método |
|---|---|---|
| I.1 | Inclusão: os mesmos dados produzem os mesmos registros | Comparar SQLite vs. DBF campo a campo |
| I.2 | Alteração: mesmo resultado (exceto D-01, D-04) | idem |
| I.3 | Exclusão: marca lógica, invisível às consultas | Contagem antes/depois |
| I.4 | Consultas: mesmo conjunto e mesma ordem | Ordenação por código |
| I.5 | Cálculos: subtotal, total, 3 fórmulas de comissão, faixa de chassi | Valores idênticos ao legado (fórmulas literais) |
| I.6 | Validações: cada `VALID`/`PICTURE` do legado + as novas | Casos positivos e negativos |
| I.7 | Relatórios: mesmas colunas, mesma ordem, mesmos registros | Comparação de saída textual |
| I.8 | Casos limite: código 0, código máximo, campos vazios, estoque zero, grupo fechando | — |
| I.9 | Dados inválidos: os 170 casos do relatório de migração | Comportamento documentado |
| I.10 | Fluxos completos: os 4 fluxos de `04-FLUXOS.md` §5–9 | Roteiro passo a passo |

**Massa de teste: os próprios dados de 1994** (briefing §21).

**Divergências esperadas e aceitas:** as 25 de `09-DIVERGENCIAS-MODERNIZACAO.md`. Qualquer divergência **não listada** é falha de regressão.

### FASE J — Auditoria final  *(pré-requisito: I)*

Preencher §6 com números medidos, não estimados. Revisar as 25 divergências. Confirmar os 9 critérios do briefing §32.

---

## 5. Matriz de compatibilidade (briefing §22)

Estado inicial. `Status`: `Não iniciado` · `Em implementação` · `Implementado` · **`Concluído`** (implementado **e** validado).

### 5.1 Cadastros

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Cliente — inclusão | OK | OK | OK | **Concluído** |
| Cliente — alteração | OK | OK | OK | **Concluído** |
| Cliente — exclusão lógica | OK | OK | OK | **Concluído** — agora confere dependências (V-17) |
| Cliente — consulta geral | OK | OK | OK | **Concluído** |
| Cliente — consulta por código | OK | OK | OK | **Concluído** |
| Cliente — tabela de códigos (lookup) | OK | OK | OK | **Concluído** — retorna o código (D-02) |
| Funcionário — inclusão/alteração/exclusão | OK | OK | OK | **Concluído** |
| Funcionário — consulta | OK | OK | OK | **Concluído** |
| Fornecedor — inclusão/alteração/exclusão | OK | OK | OK | **Concluído** |
| Fornecedor — observações (memo) | OK | OK | OK | **Concluído** — `TEXT`, sem `.DBT` |
| Fornecedor — consulta | OK | OK | OK | **Concluído** |
| Peça — inclusão/alteração/exclusão | OK¹ | OK | OK | **Concluído** — sem D-01 |
| Almoxarifado — inclusão/alteração/exclusão | OK² | OK | OK | **Concluído** — sem D-14 |
| Frota — inclusão/alteração/exclusão | OK | OK | OK | **Concluído** |
| Frota — faixa de chassi | OK | OK | OK | **Concluído** — coerência exigida (V-18) |

¹ com o defeito D-01 · ² com o índice incompatível D-14

### 5.2 Movimento

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Venda de peças (balcão) | OK | OK | OK | **Concluído** |
| Venda de peças — alerta de estoque mínimo | OK | OK | OK | **Concluído** — RN-028 preservada |
| Venda de peças — baixa de estoque | OK | OK | OK | **Concluído** |
| Venda de peças — cadastro de cliente em linha | Defeituoso (D-06) | OK | OK | **Concluído** — sem D-06 |
| Venda de peças — subtotal e total | Parcial (D-17) | OK | OK | **Concluído** — cabeçalho + itens |
| Reparo de autos — grade de itens | OK | OK | OK | **Concluído** |
| Reparo — baixa de estoque | **Ausente** (D-13) | — | — | Preservado ausente — **Q-12 aberta** |
| Pronta entrega — venda | OK | OK | OK | **Concluído** |
| Pronta entrega — baixa de frota | Defeituoso (D-08) | OK | OK | **Concluído** — sem D-08 |
| Pronta entrega — aviso de último veículo | OK | OK | OK | **Concluído** — RN-035 |
| Comissão — venda de peças | **Indefinido** (D-05) | OK | OK | **Concluído** — fórmula literal, **Q-10 aberta** |
| Comissão — reparo | **Indefinido** (D-05) | OK | OK | **Concluído** — mesma fórmula, **Q-10 aberta** |
| Comissão — pronta entrega (1,5%) | Defeituoso (D-07) | OK | OK | **Concluído** — sem D-07 |
| Comissão — consórcio (0,15%) | OK | OK | OK | Em implementação — serviço pronto (onda 4) |

### 5.3 Consórcio

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Adesão — grupo novo | OK | OK | OK | **Concluído** — nº só consumido na gravação (D-28) |
| Adesão — grupo existente | OK | — | — | Não iniciado |
| Sequencial de grupo (`.MEM` → tabela) | OK | — | — | Não iniciado |
| Numeração do participante | Defeituoso (D-10) | — | — | Não iniciado |
| Fechamento automático do grupo | OK (sem transação) | — | — | Não iniciado |
| Baixa de prestações | Defeituoso (D-11) | — | — | Não iniciado |
| Quitação | OK | — | — | Não iniciado |
| Registro de sorteio | OK | — | — | Não iniciado |
| Sorteio — baixa de frota | OK | — | — | Não iniciado |

### 5.4 Relatórios

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| R-01 Clientes (3 filtros) | OK | OK | OK | **Concluído** — RN-040 preservada |
| R-02 Funcionários | OK | OK | OK | **Concluído** — com total |
| R-03 Fornecedores | OK (CR-06) | OK | OK | **Concluído** — CR-06 |
| R-04 Estoque de peças | OK (CR-04) | OK | OK | **Concluído** — CR-04: agora mostra estoque |
| R-05 Almoxarifado | OK | OK | OK | **Concluído** |
| R-06 Frota | OK (CR-05) | OK | OK | **Concluído** — CR-05 |
| R-07 Venda de peças | Parcial (CR-02) | OK | OK | **Concluído** — CR-02 e CR-03 |
| R-08 Orçamentos | Duplicado de R-07 (CR-03) | OK | OK | **Concluído** — CR-03 |
| R-09 Consórcios | **INOPERANTE** (B-16) | OK | OK | **Concluído** — CR-01, agora funciona |
| R-10 Pronta entrega | OK (CR-07) | OK | OK | **Concluído** — CR-07 |
| R-11 Gráfico de veículos | Inoperante (biblioteca ausente) | OK | OK | **Concluído** — barras + CSV, agregado por consulta |
| R-12 Gráfico de peças | Inoperante (biblioteca ausente) | OK | OK | **Concluído** — barras + CSV, agregado por consulta |
| Destino: tela | OK | — | — | Não iniciado |
| Destino: impressora | OK (matricial) | — | — | Não iniciado |
| Destino: arquivo | **Ausente** | — | — | Não iniciado |
| Destino: etiqueta | **INOPERANTE** (D-21) | — | — | **Não portado** |

### 5.5 Infraestrutura

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Menu horizontal + submenus | OK | — | — | Não iniciado |
| Tabela de códigos (lookup) | OK (macro) | — | — | Não iniciado |
| Editor de memo | OK | — | — | Não iniciado |
| Espaço em disco (F1) | OK | — | — | Não iniciado |
| Calculadora (F2) | OK | — | — | Não iniciado |
| Saída confirmada (ALT+X) | OK | — | — | Não iniciado |
| Reorganização/`PACK` na saída | OK (D-15) | — | — | **Substituído** |
| Auto-reconstrução de índices | OK (D-14) | n/a | n/a | **Não aplicável** |
| Splash gráfico | Inoperante | — | — | **Não portado** |
| Mouse | Código morto | — | — | **Não portado** |
| Tratamento de erros | **Ausente** | — | — | Não iniciado |
| Log | **Ausente** | — | — | Não iniciado |
| Transações | **Ausente** | — | — | Não iniciado |
| Backup / restore | **Ausente** | — | — | Não iniciado |
| Migração DBF → SQLite | n/a | — | — | Não iniciado |

**Totais:** 68 funcionalidades mapeadas · 4 explicitamente não portadas (com justificativa) · 1 não aplicável · **63 a implementar**.

---

## 6. Auditoria (briefing §31) — estado ao fim da FASE B

```
Quantidade de módulos encontrados:            45 arquivos .PRG
  … ativos:                                   27
  … mortos/duplicados/incompletos:            18
Quantidade de módulos migrados:                0

Quantidade de DBFs:                           24
  … ativos:                                   12
  … obsoletos/vazios:                         11
  … órfãos com dados:                          1
Quantidade de tabelas SQLite:                 19 IMPLEMENTADAS E VERIFICADAS
  … de negócio:                               12
  … de apoio:                                  1
  … de controle de migração:                   2
  … de quarentena:                             4
Quantidade de views SQLite:                   14 (11 de exclusão lógica + 1 de item + 2 agregados)
Quantidade de índices SQLite:                 26

Quantidade de relatórios:                     12  (10 textuais + 2 gráficos)
  … operantes no legado:                       9
  … inoperantes no legado:                     3  (R-09 e os 2 gráficos)

Quantidade de regras de negócio:              42 documentadas
  … comprovadas:                              24
  … inferidas:                                 6
  … defeituosas:                               7
  … em módulos inoperantes:                    5

Quantidade de validações:
  … existentes no legado:                      6 mecanismos / ~176 ocorrências
  … a introduzir:                             20 (V-01..V-20)
  … proibidas de introduzir:                   9

Quantidade de testes:                          0 automatizados escritos
  … verificações manuais de schema executadas: 18 restrições + 12 planos de consulta

Quantidade de funcionalidades pendentes:      63 de 68

Quantidade de divergências:                   27 classificadas
  … CORREÇÃO:                                  9
  … MODERNIZAÇÃO:                               8
  … MUDANÇA FUNCIONAL:                          3
  … VALIDAÇÃO:                                  3
  … COMPATIBILIDADE:                            3
  … SEGURANÇA:                                  1
  … INDEFINIDO:                                 2
  (D-11 e D-15 contam em duas categorias)

Quantidade de questões pendentes:             12 (Q-01..Q-12) — nenhuma bloqueante
Quantidade de referências quebradas:          19 (B-01..B-19), 1 em caminho ativo
Registros de dados a migrar:                 155 ativos + 3 excluídos
Inconsistências previstas na migração:      ~170
```

### Percentual de conclusão

Calculado sobre funcionalidades identificadas e seus estados (briefing §31: *"não utilize porcentagens subjetivas"*):

| Denominador | Numerador | % |
|---|---|---|
| **Projeto completo** — 68 funcionalidades implementadas e validadas | 0 | **0,0 %** |
| **Fases do briefing** — 10 fases (A–J) | 3 concluídas (A, B, C) | **30,0 %** |
| **Trabalho de engenharia reversa** — 45 PRG + 23 DBF + 16 NTX + 3 DBT analisados | 87 de 87 | **100,0 %** |
| **Modelo de dados** — 12 entidades do legado representadas em SQLite | 12 de 12 | **100,0 %** |

**Estado global: 0 % de funcionalidades implementadas.** Descoberta, documentação
e modelo de dados concluídos; nenhuma linha da aplicação escrita.

---

## 7. Riscos

| # | Risco | Prob. | Impacto | Mitigação |
|---|---|:-:|:-:|---|
| RI-01 | ~~Harbour indisponível~~ **FECHADO** (2026-08-24) | — | — | Compilado do fonte em `/opt/harbour` — 3.2.1dev. Não há pacote `harbour` no Ubuntu 26.04; a instrução `apt install harbour` era falsa. Ver `07-DEPENDENCIAS.md` §6 |
| RI-02 | ~~`hbsqlit3` ausente~~ **FECHADO** (2026-08-24) | — | — | `libhbsqlit3.a` presente; `schema.sql` e `views.sql` aplicados por `sqlite3_exec()` de dentro do Harbour |
| RI-02b | ~~SQLite < 3.37 dentro do `hbsqlit3`~~ **FECHADO** (2026-08-24) | — | — | `sqlite3_libversion()` = `3.46.1`; `STRICT` verificado rejeitando texto em coluna `INTEGER`. Fallback de `database/README.md` não será necessário |
| RI-10 | D-27 (estoque não-negativo) rejeitada pelo negócio | Baixa | Baixo | Alternativa registrada em D-27: trocar `CHECK` por aviso — 1 linha no schema, 1 no serviço |
| RI-03 | Q-10 (comissão) resolvida tarde, invalidando dados gerados | Baixa | Médio | Fórmula isolada em `services/comissao.prg`; trocar é uma linha |
| RI-04 | Q-02 (agrupamento de itens) heurística produz agrupamento errado | Alta | Médio | `origem='INDETERMINADO'`; agrupamento auditável no relatório; reexecutável |
| RI-05 | D-25 (renumeração de cotas) rejeitada pelo negócio | Média | Baixo | Opção `--novo-grupo-para-ativos` prevista |
| RI-06 | Regressão exige reproduzir defeitos (D-05, D-13) que o negócio quer corrigir | Média | Médio | Divergências documentadas; correção é decisão, não descoberta |
| RI-07 | Massa de teste (155 registros) insuficiente para exercitar casos limite | Alta | Médio | Complementar com massa sintética em `tests/fixtures/` |
| RI-08 | Etiquetas exigidas depois (D-21) | Baixa | Baixo | Registrado; implementável se os `.LBL` ou a especificação surgirem |
| RI-09 | ~~Perda acidental do legado na movimentação~~ **FECHADO** (2026-08-24) | — | — | Movido em C.5; 95/95 checksums SHA-256 conferidos após a movimentação, 0 falhas; `chmod a-w` aplicado |

---

## 8. Build (briefing §27)

```makefile
make            # compila src/ → bin/sccv
make clean      # remove bin/, obj/, *.ppo
make test       # tests/unit + tests/integration
make migrate    # executa a migração conforme config
make run        # compila (se necessário) e executa
make install    # instala em PREFIX (padrão /usr/local)
make check-deps # verifica harbour, gcc, sqlite3, make
```

Documentar em `README.md`: versão do Harbour testada, versão do GCC, versão mínima do SQLite, flags de compilação (`-w3 -es2 -gc0`), bibliotecas linkadas (`hbsqlit3`, `sqlite3`), requisitos de SO (Linux, terminal ≥ 80×25, UTF-8).

---

## 9. Backup e recuperação (briefing §30)

| Operação | Comando | Observação |
|---|---|---|
| Backup físico | `sccv --backup` | Usa `sqlite3_backup_*` (consistente com o banco aberto) |
| Backup lógico | `sccv --dump > arquivo.sql` | Texto, versionável, portável entre versões do SQLite |
| Verificação de integridade | `sccv --verificar` | `PRAGMA integrity_check` + `foreign_key_check` + contagens |
| Restore físico | `sccv --restore <arquivo>` | Verifica integridade **antes** de substituir; preserva o atual como `.bak` |
| Restore lógico | `sqlite3 novo.db < arquivo.sql` | Documentado no README |
| Backup automático | Antes de `--purgar` e de `--migrar --forcar` | Obrigatório, não desativável |

**O procedimento de restore é testável** (`tests/integration/backup_restore.prg`): faz backup, altera dados, restaura, verifica que o estado é idêntico ao do backup.

---

## 10. Critérios de conclusão (briefing §32)

O projeto só será declarado concluído quando **todos** os 9 critérios forem verificáveis:

| # | Critério | Estado |
|---|---|:-:|
| 1 | Funcionalidades do legado identificadas | ✅ 68 mapeadas |
| 2 | Regras de negócio documentadas | ✅ 42 documentadas |
| 3 | Funcionalidades implementadas | ❌ 0/63 |
| 4 | Dados migráveis | ❌ não implementado |
| 5 | Validações implementadas | ❌ 0/20 |
| 6 | Testes executados | ❌ 0 |
| 7 | Divergências documentadas | ✅ 25 classificadas |
| 8 | Compila e executa no Linux | ❌ não iniciado |
| 9 | Regressão funcional satisfatória | ❌ não iniciada |

**3 de 9 atendidos.** A FASE C entrega a estrutura para o critério 4, mas o critério só é atendido quando os dados forem efetivamente migráveis (FASE D+E). Compilar, iniciar, converter DBFs ou exibir menus **não** conta como conclusão (briefing §32).

---

## 11. Próximo passo

**FASES A a G concluídas.** As nove ondas da FASE G estão fechadas: 19 dos 20
destinos do menu funcionam, e o único desligado — relatório de comissões — é uma
lacuna que o **legado nunca teve** (Q-11), registrada e não criada por decisão de
método.

| | |
|---|---|
| Suítes de teste | 15, todas passando (`make test`) |
| Destinos do menu | 19 de 20 |
| Matriz §5 | 12 linhas pendentes |

**Próxima: FASE H — validações.** Na prática já está quase toda entregue: V-01 a
V-19 foram implementadas na onda 1 e cobertas por 101 asserções, e as regras de
estoque e comissão vieram na onda 4. O que falta é **consolidar o registro** e
conferir uma a uma contra `05` §8, incluindo as três que alteram comportamento
observável (V-10, V-11, V-15).

Depois: **FASE I — regressão**, comparando o comportamento do sistema novo com o
do legado sobre a mesma massa de dados; e **FASE J — auditoria final**.

As duas questões abertas que dependem de decisão de negócio continuam de pé, sem
bloquear: **Q-10** (base da comissão sobre venda de peças) e **Q-12** (se o
reparo deve baixar estoque). Ambas isoladas em uma função, de propósito.
