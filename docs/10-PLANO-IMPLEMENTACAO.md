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
| D.4 | `carregador.prg` — INSERT em transação, ordem topológica | Rollback em falha simulada |  |
| D.5 | Transformações estruturais: `CVPECAS`→cabeçalho/item; `CVBGRUPO`+`CVBGRUCO`→`consorcio_cota`; `.MEM`→`sequencia` | `08` §6 |  |
| D.6 | Idempotência: `--forcar`, backup automático, códigos de saída | `08` §5 |  |
| D.7 | `make migrate` | Executa de ponta a ponta |  |

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

### FASE E — Testes de migração  *(pré-requisito: D)*

| # | Verificação | Tolerância |
|---|---|---|
| E.1 | Contagem por tabela (com e sem excluídos) | zero |
| E.2 | 7 somas de controle (`08` §9.2) | zero |
| E.3 | Comparação campo a campo — **100% dos 155 registros** | zero |
| E.4 | `PRAGMA foreign_key_check` + reconciliação das 13 FKs | vazio |
| E.5 | Relatório de inconsistências gerado e revisado | ~170 esperadas (`08` §8.1) |
| E.6 | Auditoria independente com `tools/comparar.py` | concordância total com E.1–E.4 |
| E.7 | Reconciliação dos agregados legados vs. views | divergências **documentadas**, não corrigidas |

### FASE F — Infraestrutura Harbour  *(pode ocorrer em paralelo a C/D)*

| # | Entrega | Critério de aceite |
|---|---|---|
| F.1 | `Makefile` com `all`, `clean`, `test`, `migrate`, `run`, `install`, `check-deps` | `make check-deps` reporta corretamente |
| F.2 | `database/conexao.prg` + `sql.prg` (hbsqlit3, prepared statements) | Teste: abre, PRAGMAs, consulta parametrizada, fecha |
| F.3 | `transacao.prg` com aninhamento (savepoints) | Teste: rollback interno não derruba a transação externa |
| F.4 | `erro.prg` — `ERRORBLOCK`/`BEGIN SEQUENCE`, mensagem ao usuário sem stack trace, contexto técnico no log | Briefing §18 |
| F.5 | `log.prg` — níveis, rotação simples, caminho configurável | — |
| F.6 | `config.prg` — precedência de 5 níveis, caminhos absolutos | Funciona de qualquer diretório |
| F.7 | Documentar versão do Harbour, GCC, flags | Briefing §27 |

### FASE G — Implementação dos módulos

Ordem obrigatória, **por dependência** (`07` §2.2):

| Onda | Módulos | Depende de |
|---:|---|---|
| **1** | `ui/` (menu, tela, lookup, formulário, browse) · `validation/` completo | F |
| **2** | Cadastros nível 0: **cliente**, **funcionário**, **fornecedor**, **modelo_veiculo** (manutenção + consulta) | 1 |
| **3** | Cadastros nível 1: **peça**, **almoxarifado** (manutenção + consulta) | 2 |
| **4** | `services/comissao.prg` · `services/estoque.prg` | 2, 3 |
| **5** | Movimento: **venda de peças (balcão)**, **reparo**, **pronta entrega** | 3, 4 |
| **6** | **Consórcio**: adesão, fechamento de grupo, baixa de prestações, sorteio | 2, 4 |
| **7** | Relatórios R-01..R-10 | 2–6 |
| **8** | Gráficos R-11, R-12 (barras + CSV) | 5 |
| **9** | Comandos administrativos: `--purgar`, `--backup`, `--restore`, `--verificar` | todos |

Cada módulo entra em "concluído" apenas quando: implementado + validado + coberto por teste + registrado na matriz (§5).

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
| Cliente — inclusão | OK | — | — | Não iniciado |
| Cliente — alteração | OK | — | — | Não iniciado |
| Cliente — exclusão lógica | OK | — | — | Não iniciado |
| Cliente — consulta geral | OK | — | — | Não iniciado |
| Cliente — consulta por código | OK | — | — | Não iniciado |
| Cliente — tabela de códigos (lookup) | OK | — | — | Não iniciado |
| Funcionário — inclusão/alteração/exclusão | OK | — | — | Não iniciado |
| Funcionário — consulta | OK | — | — | Não iniciado |
| Fornecedor — inclusão/alteração/exclusão | OK | — | — | Não iniciado |
| Fornecedor — observações (memo) | OK | — | — | Não iniciado |
| Fornecedor — consulta | OK | — | — | Não iniciado |
| Peça — inclusão/alteração/exclusão | OK¹ | — | — | Não iniciado |
| Almoxarifado — inclusão/alteração/exclusão | OK² | — | — | Não iniciado |
| Frota — inclusão/alteração/exclusão | OK | — | — | Não iniciado |
| Frota — faixa de chassi | OK | — | — | Não iniciado |

¹ com o defeito D-01 · ² com o índice incompatível D-14

### 5.2 Movimento

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Venda de peças (balcão) | OK | — | — | Não iniciado |
| Venda de peças — alerta de estoque mínimo | OK | — | — | Não iniciado |
| Venda de peças — baixa de estoque | OK | — | — | Não iniciado |
| Venda de peças — cadastro de cliente em linha | Defeituoso (D-06) | — | — | Não iniciado |
| Venda de peças — subtotal e total | Parcial (D-17) | — | — | Não iniciado |
| Reparo de autos — grade de itens | OK | — | — | Não iniciado |
| Reparo — baixa de estoque | **Ausente** (D-13) | — | — | Não iniciado |
| Pronta entrega — venda | OK | — | — | Não iniciado |
| Pronta entrega — baixa de frota | Defeituoso (D-08) | — | — | Não iniciado |
| Pronta entrega — aviso de último veículo | OK | — | — | Não iniciado |
| Comissão — venda de peças | **Indefinido** (D-05) | — | — | Não iniciado |
| Comissão — reparo | **Indefinido** (D-05) | — | — | Não iniciado |
| Comissão — pronta entrega (1,5%) | Defeituoso (D-07) | — | — | Não iniciado |
| Comissão — consórcio (0,15%) | OK | — | — | Não iniciado |

### 5.3 Consórcio

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Adesão — grupo novo | OK | — | — | Não iniciado |
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
| R-01 Clientes (3 filtros) | OK | — | — | Não iniciado |
| R-02 Funcionários | OK | — | — | Não iniciado |
| R-03 Fornecedores | OK (CR-06) | — | — | Não iniciado |
| R-04 Estoque de peças | OK (CR-04) | — | — | Não iniciado |
| R-05 Almoxarifado | OK | — | — | Não iniciado |
| R-06 Frota | OK (CR-05) | — | — | Não iniciado |
| R-07 Venda de peças | Parcial (CR-02) | — | — | Não iniciado |
| R-08 Orçamentos | Duplicado de R-07 (CR-03) | — | — | Não iniciado |
| R-09 Consórcios | **INOPERANTE** (B-16) | — | — | Não iniciado |
| R-10 Pronta entrega | OK (CR-07) | — | — | Não iniciado |
| R-11 Gráfico de veículos | Inoperante (biblioteca ausente) | — | — | Não iniciado |
| R-12 Gráfico de peças | Inoperante (biblioteca ausente) | — | — | Não iniciado |
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

**Bloqueio resolvido em 2026-08-24.** O Harbour foi compilado do fonte e
instalado em `/opt/harbour` (3.2.1dev, GCC 15.2, 64-bit), com `contrib/hbsqlit3`
linkado contra SQLite 3.46.1. A **Opção B** (migrar em Python primeiro) foi
descartada: a decisão de `07-DEPENDENCIAS.md` §5.3 está mantida — a migração lê o
legado pelo RDD DBFNTX, com a mesma semântica do motor original.

Toolchain validada de ponta a ponta antes de escrever a FASE D
(`07-DEPENDENCIAS.md` §6): schema real aplicado por `sqlite3_exec()`, `STRICT` e
os `CHECK` rejeitando os casos inválidos, `CVBCLIEN.DBF` lido via DBFNTX com
`SET DELETED OFF`, e CP860 decodificado por `hb_Translate( ..., "PT860", "UTF8" )`.

Notas de implementação apuradas nessa validação:

- `hbsqlit3` **não exporta `sqlite3_close()`** — descartar o ponteiro fecha o banco.
- Linkedição: `hbmk2 <fonte>.prg -lhbsqlit3 -lsqlite3`.
- `cliente.data_cadastro` é `NOT NULL` sem default; a origem é `CVBCLIEN.DATCLI`
  (`02-MODELO-DADOS.md` §2, campo 10). O nome novo não aparecia em nenhum
  documento — registrado aqui para o mapeamento de D.4.

Em andamento: **FASE D**, a partir de D.1 (`src/migration/extrator.prg`), tendo
`08-MIGRACAO-DADOS.md` como especificação e `database/schema.sql` como destino.
