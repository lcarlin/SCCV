# 08 — ESTRATÉGIA DE MIGRAÇÃO DE DADOS

## 1. Pipeline

```
  DBF/DBT legado (CP860, somente leitura)
        │
        ▼
  [1] EXTRAÇÃO ────► leitura via RDD DBFNTX com SET DELETED OFF
        │             (registros excluídos são LIDOS e marcados, não descartados)
        ▼
  [2] NORMALIZAÇÃO ─► CP860→UTF-8 · TRIM · datas ISO · documentos só dígitos
        │             · monetário → centavos · lógico → 0/1
        ▼
  [3] VALIDAÇÃO ────► DV de CPF/CNPJ · formato de CEP · faixa de data
        │             · integridade referencial · faixa numérica
        │             (NADA é corrigido silenciosamente)
        ▼
  [4] CARGA ────────► INSERT em transação única por tabela, na ordem topológica
        │             PRAGMA foreign_keys = ON
        ▼
  [5] VERIFICAÇÃO ──► contagens · somas de controle · amostragem campo a campo
        │             · reconciliação de FK · comparação com o legado
        ▼
  SQLite (UTF-8) + relatório de inconsistências
```

---

## 2. Princípio norteador

> **Nenhum dado inválido é alterado silenciosamente.** (briefing §20)

Toda transformação cai em uma de três categorias:

| Categoria | Ação | Exemplo |
|---|---|---|
| **Reversível** | Aplicada; valor original preservado em coluna `*_original` | `(0143)051-2382` → `01430512382` (+ original) |
| **Sem perda** | Aplicada; nenhum registro necessário | `TRIM` de espaços à direita; `T`/`F` → `1`/`0` |
| **Duvidosa** | **Aplicada + registrada** em `migracao_inconsistencia`; o registro é importado marcado | CPF com DV inválido; data em 1901; `NUMMES` = `**` |

Nenhum registro é descartado. Nenhum valor é "consertado por suposição".

---

## 3. Escopo — o que migrar

### 3.1 Migrar (dados de produção)

| Origem | Destino | Regs | Observação |
|---|---|---:|---|
| `CVBCLIEN.DBF` | `cliente` | 22 | |
| `CVBFUNC.DBF` | `funcionario` | 10 | |
| `CVBFORNE.DBF` + `.DBT` | `fornecedor` | 3 | memo → coluna `observacoes` |
| `CVBPECAS.DBF` | `peca` | 4 | |
| `CVBALMOX.DBF` | `almoxarifado` | 4 | |
| `CVBFROTA.DBF` | `modelo_veiculo` | 5 | |
| `CVBPENT.DBF` | `venda_veiculo` | 23 | + PK técnica |
| `CVPECAS.DBF` | `venda_peca` + `venda_peca_item` | 75 | agrupamento — ver §6 |
| `CVBGRUPO.DBF` | `consorcio_cota` (`grupo_fechado=0`) | 2 ativos + 3 excluídos | |
| `CVBGRUCO.DBF` | `consorcio_cota` (`grupo_fechado=1`) | 3 | |
| `CVREPAR.DBF` + `.DBT` | `orcamento_reparo` | 4 | tabela órfã — ver §7 |
| `CVMGRUPO.MEM` | `sequencia('consorcio_grupo')` | 1 | |
| `CVBPEDID.DBF` | `pedido` | 0 | estrutura apenas |

**Total a migrar: 155 registros ativos + 3 marcados como excluídos.**

### 3.2 NÃO migrar para as tabelas de produção

| Origem | Regs | Motivo |
|---|---:|---|
| `CVVCAR.DBF` | 4 | Agregado materializado dessincronizado (Δ até +12); substituído pela *view* `v_venda_por_modelo` |
| `CVVPEC.DBF` | 10 | idem (Δ até −11.062); substituído por `v_venda_por_peca` |
| `CVCLIENT.DBF` | 12 | Predecessora de `CVBCLIEN`; `CODCLI=1` duplicado; nomes divergentes |
| `CVALMOX.DBF` | 1 | Registro em branco |
| `CVFORNEC`, `CVFROTA`, `CVFUNC`, `CVGRUPO`, `CVGRUCON`, `CVPRONVE`, `CVVENPEC` | 0 | Vazias |

> `CVVCAR`, `CVVPEC` e `CVCLIENT` **serão importadas em tabelas de quarentena** (`_legado_cvvcar`, `_legado_cvvpec`, `_legado_cvclient`) para preservar a evidência e permitir reconciliação. Não participam do modelo de produção nem de FK.

### 3.3 Registros marcados como excluídos

`SET DELETED OFF` na extração. Os 3 registros de `CVBGRUPO` marcados com `*` são importados com `excluido = 1`. Isso preserva a semântica de exclusão lógica do legado e mantém a evidência do fechamento do grupo 1 (RN-018).

---

## 4. Regras de normalização por tipo

### 4.1 Texto

| Passo | Regra |
|---|---|
| Codificação | **CP860 → UTF-8**. Tabela de conversão explícita, não `iconv` genérico |
| Espaços | `RTRIM` (o DBF preenche à direita); `LTRIM` **também**, pois há dados com espaço inicial (`RGCLI` = `' 29.494.504-3'`) |
| Vazio | String vazia após `TRIM` → `NULL` |
| Caixa | **Preservada como está.** Não normalizar — o legado gravou com `"@!"` (maiúsculas), e os dados em caixa mista (`BatMan`, `Uno Mile ELX`) são evidência histórica |

Verificação prévia executada: **nenhum byte ≥ 0x80 nos DBFs**, exceto `0xA7` (`º`) em `CVBCLIEN.ENDCLI` (2 registros) — glifo idêntico em CP437/850/860, conversão inequívoca.

### 4.2 Numérico

| Tipo | Regra |
|---|---|
| Código (`N(n,0)`) | `VAL(TRIM(...))`. Branco → `NULL` (só ocorre em tabelas obsoletas) |
| Quantidade (`N(n,0)`) | `VAL(...)`. Branco → `0`. **Negativo → importa e registra inconsistência** |
| Monetário (`N(12,2)`) | `ROUND(VAL(...) * 100, 0)` → `INTEGER` de centavos. Branco → `0` |
| **Overflow (`*`)** | `CVBGRUCO.NUMMES` reg. 1 = `**`. **Não é conversível.** Ver padrão `*_legado` abaixo |
| **Viola um `CHECK` do schema** | Coluna restrita recebe `NULL`; valor **bruto** vai para a coluna irmã `*_legado TEXT`; inconsistência ALTA |

### Padrão `*_legado` (definido na FASE C)

Nenhum valor do legado é convertido por suposição nem descartado. Quando um
valor viola uma restrição do modelo novo:

```
coluna_restrita   ← NULL                 (o invariante do modelo é mantido)
coluna_legado     ← valor BRUTO em TEXT  (a evidência é preservada)
inconsistência    ← severidade ALTA      (o registro fica marcado p/ decisão)
```

**Alcance verificado nos 23 DBFs: apenas `CVBGRUCO.NUMMES` precisa deste
tratamento.** Os três registros da tabela ficam assim:

| Reg. | `NUMMES` bruto | `parcelas_restantes` | `parcelas_restantes_legado` |
|---:|---|---|---|
| 1 | `**` (overflow) | `NULL` | `'**'` |
| 2 | `-2` | `NULL` | `'-2'` |
| 3 | `-3` | `NULL` | `'-3'` |

Converter `-2` para `0` seria inventar um saldo; manter `-2` na coluna seria
propagar a corrupção para o sistema novo. Ver `09-DIVERGENCIAS-MODERNIZACAO.md` (D-11).

### 4.3 Datas

| Passo | Regra |
|---|---|
| Formato origem | `YYYYMMDD` (8 caracteres, formato interno do DBF — já sem ambiguidade) |
| Formato destino | `YYYY-MM-DD` (ISO-8601) |
| Vazio (`'        '`) | → `NULL` |
| Data impossível | Registra inconsistência; importa `NULL` |
| **Data válida mas suspeita (< 1970)** | **Importa o valor como está** + inconsistência de severidade MÉDIA |

**Justificativa da última regra:** as 12 datas anteriores a 1970 são sintaticamente válidas. Presumir que `10/10/10` significava 2010 seria **inventar** — o legado gravou 1910 e o operador pode ter digitado 1910 de propósito (`NASCLI` de 1908–1912 é plausível para um cliente idoso em 1994; `DATREP` de 1910 claramente não é). Não há critério objetivo para separar os casos. Ver `09-DIVERGENCIAS-MODERNIZACAO.md` (D-23).

Datas suspeitas conhecidas:

| Tabela.Campo | Registro | Valor | Severidade |
|---|---:|---|---|
| `CVBCLIEN.NASCLI` | 1 | 1956-10-10 | BAIXA (plausível) |
| `CVBCLIEN.NASCLI` | 13 | 1911-11-11 | MÉDIA |
| `CVBCLIEN.NASCLI` | 19 | 1908-10-10 | MÉDIA |
| `CVBCLIEN.NASCLI` | 20 | 1910-07-02 | MÉDIA |
| `CVBCLIEN.NASCLI` | 21 | 1912-03-10 | MÉDIA |
| `CVBCLIEN.NASCLI` | 22 | 1901-01-01 | ALTA |
| `CVBPENT.DATAV` | 9 | 1901-11-11 | ALTA |
| `CVBPENT.DATAV` | 14 | 1901-01-01 | ALTA |
| `CVREPAR.DATREP` | 1,2,3 | 1910-10-10 | ALTA |
| `CVREPAR.DATREP` | 4 | vazia | — |

### 4.4 Lógico

`T`/`Y` → `1` · `F`/`N`/branco → `0`. Sem ambiguidade nos dados (todos são `T` ou `F`).

### 4.5 Documentos

#### CPF (`CVBCLIEN.CICCLI`)

```
  original ──► preserva em cpf_original
      │
      ├─ remove tudo que não é dígito
      ├─ se resultar em 0 dígitos      → cpf = NULL,  cpf_valido = 0
      ├─ se resultar em ≠ 11 dígitos   → cpf = NULL,  cpf_valido = 0, inconsistência ALTA
      └─ se 11 dígitos:
             ├─ calcula os 2 DVs
             ├─ verifica sequência repetida (00000000000 … 99999999999)
             ├─ DV ok e não repetida   → cpf = <11 dígitos>, cpf_valido = 1
             └─ caso contrário         → cpf = <11 dígitos>, cpf_valido = 0, inconsistência MÉDIA
```

**Todos os 22 CPFs do acervo falham** (são sequências de teste), mas **não onde
esta seção previa** — corrigido na FASE D.2 (2026-08-24) medindo o acervo:

| Dígitos após limpeza | Registros |
|---:|---:|
| 6 | 1 |
| 10 | 3 |
| 12 | 2 |
| 14 | 1 |
| 15 | 15 |
| **11** | **0** |

`CICCLI` é `C(15)` e foi preenchido com sequências de teste de 15 dígitos.
**Nenhum valor chega à verificação de DV** — todos param antes, na checagem de
comprimento. Portanto:

- `cpf` fica `NULL` em **todos os 22 registros** (é o que o fluxo acima manda
  fazer quando o comprimento é diferente de 11);
- `cpf_valido` fica `0` em todos;
- `cpf_original` preserva os 22 valores;
- as 22 inconsistências são **I-02 (ALTA)**, não I-01 (MÉDIA).

A frase anterior — "todos são importados com `cpf_valido = 0`" — dava a entender
que a coluna `cpf` receberia os dígitos. Não recebe: com comprimento errado, o
próprio fluxo desta seção manda gravar `NULL`.

O índice `ux_cliente_cpf` é **parcial** (`WHERE cpf IS NOT NULL AND excluido = 0`); não há CPFs duplicados no acervo, então não bloqueia a carga.

#### CNPJ (`CVBFORNE.CGCFAB`)

Mesmo tratamento, com 14 dígitos. Valores reais: `27439872194873285783` (20 dígitos → `NULL`, ALTA), `3484378438743]` (13 dígitos após limpeza → `NULL`, ALTA), branco (→ `NULL`, sem inconsistência).

#### CEP

| Origem | Tipo | Tratamento |
|---|---|---|
| `CVBCLIEN.CEPCLI` | `N(8,0)` | `STRZERO(valor, 8)` → **recupera os zeros à esquerda perdidos**. Valores `798797` → `00798797` e `5877` → `00005877` recebem inconsistência MÉDIA (provável dígito faltante, não CEP com zeros) |
| `CVBFORNE.CEPFOR` | `C(9)` | Remove não-dígitos → 8 dígitos esperados |
| `CVBFUNC.CEPFUN` | `C(9)` | idem. `188000-00` → `18800000` (8 dígitos) — **coincide** com o CEP de Piraju, mas a máscara errada moveu o hífen. Importa + inconsistência BAIXA |

Sempre preserva `cep_original`.

#### Telefone

```
  original ──► preserva em telefone_original
      │
      ├─ remove tudo que não é dígito     ex.: "(0143) 51-2665" → "0143512665"
      ├─ se começa com "0" e tem 10-11 díg. → remove o 0 de prefixo interurbano
      │                                       "0143512665" → "143512665"  ⚠ ver abaixo
      └─ grava só dígitos + registra o comprimento
```

> **Cautela:** os DDDs do acervo estão no formato antigo de **4 dígitos com zero** (`0143` = Piraju/SP, hoje DDD 14). Converter `0143` → `14` seria **inferir uma renumeração da Anatel de 1999**, posterior aos dados. **Decisão: não converter.** Armazenar apenas os dígitos originais (`0143512665`), preservar o original com máscara, e registrar inconsistência BAIXA informando que o formato é pré-1999. A decisão de renumerar é do responsável pelo negócio. Ver 09/D-24.

#### RG

`C(15)`, formatos livres (`636.363.636-3`, `27-456744546545`, `28 .534.428-8`). **Não normalizar** — o RG não tem formato nacional único nem DV padronizado. Preservar `TRIM` do original.

---

## 5. Idempotência

A migração é **idempotente por reexecução completa**:

```
sccv-migrar --origem <dir-legado> --destino <arquivo.db> [--forcar]
```

| Situação | Comportamento |
|---|---|
| Banco de destino não existe | Cria, aplica o schema, migra |
| Banco existe e está **vazio** | Migra |
| Banco existe **com dados** e sem `--forcar` | **Recusa** com mensagem clara e código de saída ≠ 0 |
| Banco existe **com dados** e com `--forcar` | Renomeia o arquivo existente para `<nome>.bak.<timestamp>`, cria novo, migra |

Não há migração incremental — o volume (155 registros) não justifica, e a reexecução completa é mais auditável.

**Tabela de controle:**

```sql
CREATE TABLE migracao_execucao (
  id            INTEGER PRIMARY KEY,
  iniciada_em   TEXT NOT NULL,
  concluida_em  TEXT,
  origem        TEXT NOT NULL,
  versao_schema TEXT NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('EM_ANDAMENTO','CONCLUIDA','FALHOU')),
  registros_lidos      INTEGER NOT NULL DEFAULT 0,
  registros_gravados   INTEGER NOT NULL DEFAULT 0,
  inconsistencias      INTEGER NOT NULL DEFAULT 0
);
```

Toda a carga ocorre em **uma transação por tabela**. Falha em qualquer tabela → `ROLLBACK` daquela tabela + `status = 'FALHOU'` + saída com erro. Nunca deixa um banco meio migrado sem sinalização.

---

## 6. Transformações estruturais

### 6.1 `CVPECAS` → `venda_peca` (cabeçalho) + `venda_peca_item`

O legado grava itens soltos sem número de venda. O único agrupamento observável é `VALTOT` preenchido apenas no **último item** da compra (RN-027).

**Algoritmo de agrupamento** (percorrendo em ordem física, que é a ordem de inserção):

```
venda_atual = novo cabeçalho
para cada registro r de CVPECAS na ordem física:
    se venda_atual.cod_cli é NULL:
        venda_atual.cod_cli = r.CODCLI
    senão se r.CODCLI ≠ venda_atual.cod_cli:
        # troca de cliente sem VALTOT: fecha a venda anterior
        fecha(venda_atual)  ; registra inconsistência BAIXA
        venda_atual = novo cabeçalho com r.CODCLI
    grava item(venda_atual, r)
    se r.VALTOT não é vazio e r.VALTOT > 0:
        venda_atual.total_cent = r.VALTOT
        fecha(venda_atual)
        venda_atual = novo cabeçalho
ao final: se venda_atual tem itens, fecha (total = soma dos subtotais)
```

Validação: para cada venda fechada por `VALTOT`, comparar `VALTOT` com `SUM(SUBTOT)` dos itens. Divergência → inconsistência MÉDIA (não altera o dado; grava ambos).

**Campo `origem`:** não é determinável a partir de `CVPECAS` (Q-02). **Todos os registros migrados recebem `origem = 'INDETERMINADO'`.** Não será inferido. A partir da nova implementação, cada venda registrará sua origem corretamente.

Estimativa: 75 itens; 47 registros com `VALTOT` preenchido e > 0 → aproximadamente 47 cabeçalhos.

### 6.2 `CVBGRUPO` + `CVBGRUCO` → `consorcio_cota`

Union das duas tabelas na tabela unificada:

| Campo destino | De `CVBGRUPO` | De `CVBGRUCO` |
|---|---|---|
| `grupo_fechado` | `GRUFEC` (sempre 0) | `GRUFEC` (sempre 1) |
| `sorteado` | `0` (campo não existe) | `SORT` |
| `quitado` | `0` (campo não existe) | `QUIT` |
| `parcelas_restantes` | `NUMMES` | `NUMMES` (com o `**` → `NULL`) |
| `num_participante` | `NUPGRU` | `NUPGRU` |
| demais | mapeamento direto | mapeamento direto |

**Colisão da chave `UNIQUE (cod_gru, num_participante)`:** os 3 registros excluídos de `CVBGRUPO` (grupo 1, participantes 1, 2, 3) colidem com os 3 de `CVBGRUCO` (grupo 1, participantes 1, 2, 3). São **os mesmos registros** — os de `CVBGRUPO` são o resto da transferência (RN-018).

**Decisão:** os registros de `CVBGRUPO` marcados como excluídos que já existem em `CVBGRUCO` **não são inseridos**; a evidência é preservada em `_legado_cvbgrupo_excluidos` + inconsistência informativa. Os 2 registros ativos de `CVBGRUPO` (grupo 1, participantes 1 e 2 — códigos de cliente 6 e 24) **também colidem** com `CVBGRUCO` (participantes 1, 2, 3).

Análise dos dados:

| Fonte | `CODGRU` | `NUPGRU` | `CODCON` | Excluído |
|---|---:|---:|---:|:-:|
| `CVBGRUPO` | 1 | 1 | 1 | sim |
| `CVBGRUPO` | 1 | 2 | 2 | sim |
| `CVBGRUPO` | 1 | 3 | 3 | sim |
| `CVBGRUPO` | 1 | **1** | 6 | não |
| `CVBGRUPO` | 1 | **2** | 24 | não |
| `CVBGRUCO` | 1 | 1 | 1 | não |
| `CVBGRUCO` | 1 | 2 | 2 | não |
| `CVBGRUCO` | 1 | 3 | 3 | não |

Os participantes ativos 1 e 2 de `CVBGRUPO` (clientes 6 e 24) reusaram os números após o fechamento do grupo — consequência direta do defeito RN-015 (o `COUNT` com `SET DELETED ON` não contou os 3 excluídos, reiniciando a numeração).

**Decisão de migração:** manter `CODGRU = 1` para ambos os conjuntos seria semanticamente errado — o segundo conjunto é um **novo grupo em formação** que herdou o número por defeito. Como não é possível determinar o número correto, os 2 registros ativos de `CVBGRUPO` recebem `cod_gru = 1` e `num_participante` **renumerado a partir do máximo de `CVBGRUCO` + 1** (isto é, 4 e 5), **com inconsistência de severidade ALTA registrando o valor original e o motivo**. Ver 09/D-25.

### 6.3 Memos `.DBT` → `TEXT`

```
CVBFORNE.DBT bloco 2 → fornecedor(cod_for=1).observacoes
CVBFORNE.DBT bloco 3 → fornecedor(cod_for=3).observacoes
```

Conteúdo (CP860 → UTF-8, `TRIM`):
- Bloco 2: `"CODIGO DO ITEM TALVEZ NAO ESTEJA CORRETO PORQUE O OSWALDO\nCOELHO DE OLIVEIRA JUNIOR e o genio universal. CIDADE"`
- Bloco 3: `"o babaca."`

Fornecedor 2 tem `OBSFOR` em branco → `NULL`.

`CVREPAR.DBT` e `CVFORNEC.DBT` estão vazios.

### 6.4 `CVMGRUPO.MEM` → tabela `sequencia`

```sql
INSERT INTO sequencia (nome, valor) VALUES ('consorcio_grupo', <MCODGRU>);
```

Valor lido do `.MEM` via `RESTORE FROM`. Se o valor for menor que `MAX(cod_gru)` das cotas migradas, ajustar para o máximo e registrar inconsistência.

---

## 7. Tratamento de `CVREPAR.DBF`

Tabela órfã com 4 registros de teste. Módulo correspondente **abandonado** (Q-04).

**Decisão:** criar a tabela `orcamento_reparo` no schema e migrar os 4 registros, **sem FK obrigatória** e marcados como dados de origem indeterminada. Motivos:
1. Briefing §24: não descartar informação do legado.
2. Preserva a estrutura caso o módulo venha a ser implementado.
3. Os códigos (`'1     '`, `'2     '`, `'3     '`, `'      '`) são texto e apontam para clientes/peças que **existem** — a verificação de integridade passou.

Os valores (`4.359.848,00`, `278.547,00`, `3.765.475,00`) e as datas (`1910-10-10`) recebem inconsistência ALTA. O registro 4, inteiramente em branco, recebe inconsistência ALTA e é importado com todos os campos `NULL`.

**Nenhum módulo da nova aplicação lerá ou gravará esta tabela** até que Q-04 seja respondida.

---

## 8. Relatório de inconsistências

Formato exigido pelo briefing §20: *registro original · campo · valor · problema · ação tomada*.

```sql
CREATE TABLE migracao_inconsistencia (
  id             INTEGER PRIMARY KEY,
  execucao_id    INTEGER NOT NULL REFERENCES migracao_execucao(id),
  arquivo        TEXT NOT NULL,      -- 'CVBCLIEN.DBF'
  registro       INTEGER NOT NULL,   -- RECNO() no arquivo original
  chave          TEXT,               -- 'CODCLI=22'
  campo          TEXT NOT NULL,      -- 'CICCLI'
  valor_original TEXT,               -- '88888888888-888'
  problema       TEXT NOT NULL,      -- 'CPF com digito verificador invalido'
  acao           TEXT NOT NULL,      -- 'Importado com cpf_valido=0'
  severidade     TEXT NOT NULL CHECK (severidade IN ('BAIXA','MEDIA','ALTA'))
);
```

Exportação em três formatos: tabela SQLite, `relatorio-migracao.txt` (texto, formato do briefing) e `relatorio-migracao.csv`.

Exemplo do arquivo de texto:

```
CVBCLIEN.DBF
Registro 22   (CODCLI=24)
Campo:    CICCLI
Valor:    88888888888-888
Problema: CPF com 14 digitos apos normalizacao (esperado 11)
Acao:     Importado com cpf = NULL e cpf_valido = 0; original preservado
Severidade: ALTA
```

### 8.1 Inconsistências previstas (levantamento prévio)

| # | Origem | Qtde estimada | Severidade |
|---|---|---:|---|
| I-01 | CPF com DV inválido ou sequência repetida | **0** (medido) | MÉDIA |
| I-02 | CPF com nº de dígitos ≠ 11 | **22** (medido) | ALTA |
| I-03 | CNPJ inválido | 2 | ALTA |
| I-04 | CEP com < 8 dígitos | 2 | MÉDIA |
| I-05 | CEP com máscara malformada (`188000-00`) | 1 | BAIXA |
| I-06 | CEP ausente (funcionários) | 7 | BAIXA |
| I-07 | Data anterior a 1970 | 12 | MÉDIA/ALTA |
| I-08 | `NUMMES` com overflow (`**`) | 1 | ALTA |
| I-09 | `NUMMES` negativo | 2 | ALTA |
| I-10 | `NUMPAG`/`NUMGRU` sempre vazios | 8 (2 campos × 4 reg.) | BAIXA (informativa) |
| I-11 | `VALTOT` vazio/zero em item não-final | 28 | BAIXA (esperado — RN-027) |
| I-12 | `QUANTC` vazio em `CVVPEC` | 6 | BAIXA (quarentena) |
| I-13 | Desnormalização divergente `DESCAR` | 5 | MÉDIA |
| I-14 | Desnormalização divergente `DECPEC` | 1 | MÉDIA |
| I-15 | Agregado dessincronizado `CVVPEC` | 4 | ALTA (quarentena) |
| I-16 | Agregado dessincronizado `CVVCAR` | 4 | ALTA (quarentena) |
| I-17 | Colisão de `(cod_gru, num_participante)` | 2 | ALTA |
| I-18 | `CVREPAR` — valores e datas implausíveis | 4 | ALTA |
| I-19 | `CVREPAR` — registro em branco | 1 | ALTA |
| I-20 | `CVBFORNE` reg. 2 — 9 de 11 campos vazios | 1 | BAIXA |
| I-21 | Cliente com `CONSOR='S'` sem cota (Q-08) | 13 | BAIXA (informativa) |
| I-22 | Telefone em formato de DDD pré-1999 | ~30 | BAIXA (informativa) |
| I-23 | `VALCAR = 0` em `CVBPENT` | 3 | MÉDIA |
| I-24 | `CVCLIENT` — `CODCLI=1` duplicado (quarentena) | 1 | ALTA |

**Total estimado: ~165 inconsistências** sobre 155 registros. Este número alto é
esperado: os dados são uma massa de teste de 1994, não um acervo de produção.

> As linhas marcadas **(medido)** deixaram de ser estimativa na FASE D.2: foram
> contadas rodando o extrator (D.1) e o normalizador (D.2) sobre os arquivos
> reais. Conferidas e batendo com a previsão original: I-03 (2), I-04 (2),
> I-05+I-06 (8), I-07 em `NASCLI` (6), I-08+I-09 (3). As demais linhas continuam
> estimadas até a FASE E.

---

## 9. Verificação pós-migração

### 9.1 Contagens

Para cada par origem→destino:

```
COUNT(DBF, DELETED OFF)  ==  COUNT(SQLite, todas as linhas)
COUNT(DBF, DELETED ON)   ==  COUNT(SQLite, WHERE excluido = 0)
```

Exceções documentadas: `CVPECAS` (75 itens → N cabeçalhos + 75 itens) e `CVBGRUPO`+`CVBGRUCO` (8 → 5 em `consorcio_cota` + 3 em quarentena).

### 9.2 Somas de controle

| Verificação | Origem | Destino |
|---|---|---|
| Soma de salários | `SUM(CVBFUNC.SALFUN)` | `SUM(funcionario.salario_cent)/100` |
| Soma de comissões | `SUM(CVBFUNC.COMFUN)` | `SUM(funcionario.comissao_cent)/100` |
| Soma de estoque de peças | `SUM(CVBPECAS.QTDPEC)` | `SUM(peca.qtd_estoque)` |
| Soma de valores de venda | `SUM(CVBPENT.VALCAR)` | `SUM(venda_veiculo.valor_cent)/100` |
| Soma de subtotais | `SUM(CVPECAS.SUBTOT)` | `SUM(venda_peca_item.subtotal_cent)/100` |
| Soma de frota | `SUM(CVBFROTA.QUANTCAR)` | `SUM(modelo_veiculo.qtd_estoque)` |
| Soma de prestações | `SUM(VALPRE)` das 2 tabelas | `SUM(consorcio_cota.valor_prestacao_cent)/100` |

Tolerância: **zero**. Qualquer divergência é falha da migração.

### 9.3 Amostragem campo a campo

Para cada tabela, comparar **100% dos registros** (o volume permite): cada campo do DBF contra o campo correspondente no SQLite, aplicando a transformação inversa quando aplicável. Falha em qualquer campo aborta a verificação com relatório detalhado.

### 9.4 Integridade referencial

```sql
PRAGMA foreign_key_check;     -- deve retornar vazio
PRAGMA integrity_check;       -- deve retornar 'ok'
```

Mais reconciliação explícita das 13 relações listadas em `02-MODELO-DADOS.md` §8.2 (todas passaram no levantamento prévio).

### 9.5 Reconciliação dos agregados

Comparar as *views* `v_venda_por_modelo` / `v_venda_por_peca` com as tabelas de quarentena `_legado_cvvcar` / `_legado_cvvpec`. **Espera-se divergência** — o objetivo é documentá-la, não corrigi-la. O relatório de verificação registra as diferenças conhecidas (§ `02-MODELO-DADOS.md` 8.8) e confirma que a nova *view* reproduz os dados transacionais reais.

---

## 10. Backup e reversão

| Momento | Ação |
|---|---|
| Antes da migração | Cópia de todo o diretório legado para `backup/legado-<timestamp>/` — **o legado é somente leitura, esta é uma segunda camada de proteção** |
| Antes de sobrescrever um banco existente (`--forcar`) | `<destino>.bak.<timestamp>` |
| Após a migração | `sqlite3 <destino> .dump > backup/sccv-<timestamp>.sql` (backup lógico) |
| Reversão | O legado nunca é alterado. Reverter = apagar o `.db` e reexecutar |

O arquivo SQLite resultante **não substitui** o legado — ambos coexistem até a validação de regressão (FASE I).

---

## 11. Comandos previstos

```bash
make migrate                        # migração padrão com os caminhos do config
sccv-migrar --origem ./            --destino ~/.local/share/sccv/sccv.db
sccv-migrar --origem ./ --destino ./teste.db --forcar
sccv-migrar --verificar --destino ~/.local/share/sccv/sccv.db   # só a etapa 5
sccv-migrar --relatorio --destino ... --saida relatorio-migracao.txt
```

Códigos de saída: `0` sucesso · `1` erro de uso · `2` origem inválida · `3` destino já populado sem `--forcar` · `4` falha na carga (rollback aplicado) · `5` falha na verificação.
