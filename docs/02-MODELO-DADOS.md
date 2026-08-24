# 02 — MODELO DE DADOS

## 1. Nota metodológica

As estruturas abaixo foram extraídas **do binário dos arquivos DBF** (cabeçalho de 32 bytes + descritores de campo), não de documentação. Os papéis funcionais foram inferidos do código que lê e grava cada campo, e cada inferência está marcada.

Convenções:
- `C(n)` = caractere, `N(n,d)` = numérico, `D` = data (`YYYYMMDD`), `L` = lógico (`T`/`F`), `M` = memo.
- **PK implícita**: campo usado como chave de `SEEK` para decidir inclusão vs. alteração.
- **FK implícita**: campo validado por `SEEK` contra outra tabela.

---

## 2. Tabelas ativas

### 2.1 `CVBCLIEN.DBF` — Clientes  *(22 registros, 178 b/reg)*

| # | Campo | Tipo | Papel | Obrigatório? | Observação |
|--:|---|---|---|---|---|
| 1 | `CODCLI` | N(5,0) | **PK implícita** | Sim (chave de acesso) | Código manual, 1..99999. `PICT "99999"` |
| 2 | `NOMCLI` | C(35) | Nome | Não validado | `PICT "@!"` → maiúsculas |
| 3 | `ENDCLI` | C(45) | Endereço | Não | `PICT "@!"` |
| 4 | `CEPCLI` | **N(8,0)** | CEP | Não | **Numérico** — perde zeros à esquerda. Dados reais: `798797`, `5877` |
| 5 | `UFCLI` | C(2) | UF | Não | `VALID` contra lista fixa (defeituosa — ver 05) |
| 6 | `TELCLI` | C(15) | Telefone | Não | Máscara `(XXXX)XXX-XXXX` **gravada literalmente** |
| 7 | `RGCLI` | C(15) | RG | Não | Máscara `XXX.XXX.XXX-X` literal |
| 8 | `CICCLI` | C(15) | **CPF** (nome histórico "CIC") | Não | Máscara `XXXXXXXXXXX-XXX` literal. **Sem validação alguma** |
| 9 | `NASCLI` | D | Nascimento | Não | |
| 10 | `DATCLI` | D | Data de cadastro | Default `DATE()` | |
| 11 | `CIDCLI` | C(20) | Cidade | Não | |
| 12 | `CONSOR` | C(1) | **Participa de consórcio** `S`/`N` | `VALID $"SN"` | Dispara `CVMTCON` quando `="S"` |

Índice: `CVICLI1.NTX` sobre `codcli` (não único).

### 2.2 `CVBFUNC.DBF` — Funcionários  *(10 registros, 150 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODFUN` | N(6,0) | **PK implícita** | `PICT "99999"` (5) — **capacidade do campo maior que a da máscara** |
| 2 | `NOMFUN` | C(35) | Nome | |
| 3 | `ENDFUN` | C(45) | Endereço | |
| 4 | `CARFUN` | C(15) | Cargo | |
| 5 | `SALFUN` | N(12,2) | Salário | `PICT "999,999,999.99"` |
| 6 | `CIDFUN` | C(15) | Cidade | |
| 7 | `COMFUN` | N(12,2) | **Comissão acumulada** | **Campo calculado/acumulador** — nunca é zerado. Ver RN-010..013 |
| 8 | `CEPFUN` | C(9) | CEP | **`C(9)` com hífen** — inconsistente com `CEPCLI` `N(8)` |

Índice: `CVIFUN1.NTX` sobre `codfun`.

`COMFUN` é o único campo do sistema que acumula valor sem fechamento de período. Não existe rotina de pagamento, zeragem ou histórico de comissão.

### 2.3 `CVBFORNE.DBF` — Fornecedores  *(3 registros, 231 b/reg, com memo)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODFOR` | N(6,0) | **PK implícita** | `PICT "99999"` em `CVMTFOR`, `"999999"` em `CVMTPEC`/`CVMTALMX` — inconsistente |
| 2 | `NOMFOR` | C(35) | Nome | Desnormalizado em `CVBPECAS`/`CVBALMOX` |
| 3 | `TELFOR` | C(14) | Telefone | Máscara literal |
| 4 | `CEPFOR` | C(9) | CEP | Texto com hífen |
| 5 | `CIDFOR` | C(20) | Cidade | |
| 6 | `ENDFOR` | C(45) | Endereço | |
| 7 | `CODITE` | C(6) | Código do item fornecido | **Texto**, ao contrário de `CODPEC` que é numérico. Sem FK |
| 8 | `DESITE` | C(35) | Descrição do item | |
| 9 | `NOMFAB` | C(30) | Fábrica | |
| 10 | `CGCFAB` | C(20) | **CNPJ** (nome histórico "CGC") | Sem validação. Dados reais com 20 dígitos e caractere `]` |
| 11 | `OBSFOR` | M(10) | Observações → `CVBFORNE.DBT` | Editada por `MEMOEDIT()` |

Índice: `CVIFOR1.NTX` sobre `codfor`.

### 2.4 `CVBPECAS.DBF` — Cadastro/estoque de peças  *(4 registros, 103 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODPEC` | N(6,0) | **PK implícita** | |
| 2 | `DECPEC` | C(35) | Descrição | Desnormalizada em `CVPECAS` e `CVVPEC` |
| 3 | `QTDPEC` | N(5,0) | **Quantidade em estoque** | Decrementada na venda (RN-015) |
| 4 | `VALUNI` | N(12,2) | Valor unitário | |
| 5 | `QTDMIN` | N(3,0) | Estoque mínimo | Usado no alerta RN-014 |
| 6 | `CODFOR` | N(6,0) | **FK implícita → `CVBFORNE.CODFOR`** | Validada por `SEEK` |
| 7 | `NOMFOR` | C(35) | Nome do fornecedor (**cópia**) | Desnormalização |

Índices: `CVIPEC1.NTX` sobre `codpec`.

### 2.5 `CVBALMOX.DBF` — Almoxarifado  *(4 registros, 101 b/reg)*

Estrutura **paralela** a `CVBPECAS`, para materiais de consumo interno:

| # | Campo | Tipo | Papel |
|--:|---|---|---|
| 1 | `CODALM` | N(6,0) | **PK implícita** |
| 2 | `DESCALM` | C(35) | Descrição |
| 3 | `QUANTALM` | N(3,0) | Quantidade (**máx. 999** — vs. 99999 em peças) |
| 4 | `VALALM` | N(12,2) | Valor unitário |
| 5 | `QUANALM` | N(3,0) | Quantidade mínima |
| 6 | `CODFORALM` | N(6,0) | **FK implícita → `CVBFORNE.CODFOR`** |
| 7 | `NOMFORALM` | C(35) | Nome do fornecedor (**cópia**) |

Índice usado: `CVIALM1.NTX` — **construído sobre `CVALMOX` onde `CODALM` é `C(6)`**. Chave de tipo incompatível.

**Não há nenhuma rotina de baixa de almoxarifado.** `QUANTALM` só é alterada manualmente pela manutenção. — *REGRA NÃO DETERMINADA PELO LEGADO: qual evento consome o almoxarifado?*

### 2.6 `CVBFROTA.DBF` — Frota de veículos  *(5 registros, 88 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODCAR` | N(5,0) | **PK implícita** | Código do **modelo**, não do veículo individual |
| 2 | `DESCAR` | C(35) | Modelo | Também é chave lógica de `CVVCAR` |
| 3 | `QUANTCAR` | N(3,0) | **Quantidade em estoque** | Decrementada na venda (RN-017) e no sorteio (RN-029) |
| 4 | `VALCAR` | N(12,2) | Valor unitário | |
| 5 | `DATCOMCAR` | D | Data de compra do lote | |
| 6 | `CHASSI` | N(12,0) | **Chassi inicial da faixa** | |
| 7 | `CHASDO` | N(12,0) | **Chassi final da faixa** | Calculado: `CHASSI + QUANTCAR` (RN-021) |

Índice: `CVIFRO1.NTX` sobre `codcar`.

> **Modelagem importante:** a frota é controlada **por modelo com quantidade**, não por veículo individual. `CHASSI`/`CHASDO` descrevem uma faixa, mas **não há vínculo entre um chassi específico e uma venda**. Ver §7 (pontos que exigem decisão).

### 2.7 `CVBPENT.DBF` — Vendas de pronta entrega  *(23 registros, 151 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODCAR` | N(5,0) | **FK → `CVBFROTA`** | Também é a chave do índice `CVIPENT1` |
| 2 | `DESCAR` | C(35) | Modelo (**cópia**) | 5 divergências reais contra o cadastro |
| 3 | `VALCAR` | N(12,2) | Valor da venda (**cópia**) | 3 registros com `0.00` |
| 4 | `CODFUN` | N(5,0) | **FK → `CVBFUNC`** | |
| 5 | `NOMFUN` | C(30) | Nome do vendedor (**cópia**) | Truncado a 30 (origem tem 35) |
| 6 | `CODCLI` | N(5,0) | **FK → `CVBCLIEN`** | |
| 7 | `NOMCLI` | C(30) | Nome do cliente (**cópia**) | Truncado a 30 |
| 8 | `DATAV` | D | Data da venda | Digitada, sem default nem validação |
| 9 | `FORMA` | C(20) | Forma de pagamento | **Nenhum programa grava este campo.** 2 registros preenchidos ("A VISTA") — origem desconhecida |

**Não há PK.** Não existe número de venda/nota. A identidade de um registro é apenas sua posição física. Ver §7.

### 2.8 `CVPECAS.DBF` — Itens de venda e reparo de peças  *(75 registros, 112 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODPEC` | N(6,0) | **FK → `CVBPECAS`** | Índice `CVIVPEC1` |
| 2 | `DECPEC` | C(35) | Descrição (**cópia**) | 1 divergência real (cód. 2 = "FERRARI-F40" vs. cadastro "PARAFUSO") |
| 3 | `SUBTOT` | N(12,2) | **Subtotal do item** = `VALUNI × QTPECC` | |
| 4 | `QTPECC` | N(5,0) | Quantidade vendida | |
| 5 | `VALTOT` | N(12,2) | **Total da compra inteira**, gravado apenas no **último item** | 28 de 75 registros vazios/zero |
| 6 | `NOMCLI` | C(35) | Nome do cliente (**cópia**) | |
| 7 | `CODCLI` | N(6,0) | **FK → `CVBCLIEN`** | Note: `N(6)` aqui, `N(5)` na origem |

**Tabela usada por dois módulos com semânticas diferentes** (`CVMTVPEC` = venda de balcão; `CVMTVREP` = peças consumidas em reparo) **sem campo que distinga a origem**. Não há número de venda/OS, nem data. Ver §7.

### 2.9 `CVBGRUPO.DBF` — Consórcio: grupo em formação  *(5 reg., 3 marcados como excluídos, 84 b/reg)*

| # | Campo | Tipo | Papel | Observação |
|--:|---|---|---|---|
| 1 | `CODCON` | N(5,0) | **FK → `CVBCLIEN.CODCLI`** | Consorciado = cliente |
| 2 | `NOMCON` | C(35) | Nome (**cópia**) | |
| 3 | `CODCAR` | N(5,0) | **FK → `CVBFROTA`** | Chave do índice `CVIGRU1` |
| 4 | `CODGRU` | N(5,0) | **Nº do grupo** | Vem de `CVMGRUPO.MEM` (RN-022). Chave do índice `CVIGRU2` |
| 5 | `VALPRE` | N(12,2) | Valor da prestação | Default = `VALCAR` do modelo |
| 6 | `NUMPAG` | N(2,0) | Nº de parcelas pagas | **Nunca gravado** (`REPLACE` comentado) — sempre vazio |
| 7 | `NUMGRU` | N(3,0) | (indeterminado) | **Nunca gravado** — sempre vazio |
| 8 | `GRUFEC` | L | Grupo fechado | `.F.` enquanto em formação |
| 9 | `NUMPAR` | N(3,0) | **Nº de participantes previsto** (cota do grupo) | Define o gatilho de fechamento |
| 10 | `DATCON` | D | Data da adesão | Default `DATE()` |
| 11 | `NUMMES` | N(2,0) | **Nº de meses / prestações restantes** | Inicializado = `NUMPAR` (RN-023). **`N(2)` é insuficiente** — ver 09/D-11 |
| 12 | `NUPGRU` | N(2,0) | **Nº do participante dentro do grupo** | `COUNT + 1` (RN-024) |

**Chave composta lógica: `(CODGRU, NUPGRU)`.** Nenhum índice a materializa.

### 2.10 `CVBGRUCO.DBF` — Consórcio: grupo fechado  *(3 registros, 86 b/reg)*

Mesmos 12 campos de `CVBGRUPO` **mais dois**:

| # | Campo | Tipo | Papel |
|--:|---|---|---|
| 13 | `SORT` | L | **Contemplado no sorteio** |
| 14 | `QUIT` | L | **Quitado** (todas as prestações pagas) |

Índice: `CVIGRUC1.NTX` sobre `codcon`.

Os registros migram de `CVBGRUPO` para cá quando o grupo atinge a cota (RN-025). Os campos `SORT`/`QUIT` **não são inicializados na transferência** — herdam o valor de `APPEND BLANK` (`.F.`), o que é correto por acidente.

### 2.11 `CVVCAR.DBF` — Agregado de vendas por modelo  *(4 registros, 39 b/reg)*

| # | Campo | Tipo | Papel |
|--:|---|---|---|
| 1 | `DESCAR` | C(35) | **PK implícita: descrição do modelo** (não o código!) |
| 2 | `QUANTV` | N(3,0) | Contador de veículos vendidos |

Tabela **derivada**, mantida incrementalmente por `CVMTPENT` (RN-019) e lida por `CVGRAFRO`. Índice `CVIGRAC1` sobre `descar`.

### 2.12 `CVVPEC.DBF` — Agregado de vendas por peça  *(10 registros, 40 b/reg)*

| # | Campo | Tipo | Papel |
|--:|---|---|---|
| 1 | `DESPEC` | C(35) | **PK implícita: descrição da peça** |
| 2 | `QUANTC` | N(4,0) | Contador de peças vendidas |

Derivada, mantida por `CVMTVPEC`/`CVMTVREP` (RN-020), lida por `CVGRAPEC`. Índice `CVIGRAP1` sobre `despec`.

**Ambas as agregadas estão dessincronizadas dos dados de origem** — ver §8.

### 2.13 `CVREPAR.DBF` — Orçamentos de reparo  *(4 registros, 55 b/reg — ÓRFÃ)*

| # | Campo | Tipo | Papel |
|--:|---|---|---|
| 1 | `CODCLI` | **C(6)** | Cliente (texto!) |
| 2 | `CODFUN` | C(6) | Funcionário |
| 3 | `VALORC` | N(12,2) | Valor do orçamento |
| 4 | `CODORC` | C(6) | **Nº do orçamento** — índice `CVIREP1` |
| 5 | `ORCREP` | M(10) | Descrição do orçamento (memo vazio) |
| 6 | `CODPEC` | C(6) | Peça |
| 7 | `DATREP` | D | Data |

`CVMTVREP.PRG` declara as variáveis `MCODORC`, `MDATORC`, `MVALORC` e tem o `USE CVREPAR INDEX CVIREP1` **comentado**. Conclusão: **o módulo de orçamento foi projetado e abandonado.** Os 4 registros existentes (com valores como `4.359.848,00` e datas `10/10/1910`) são dados de teste. Ver §7.

### 2.14 `CVBPEDID.DBF` — Pedidos a fornecedor  *(0 registros)*

`CODPED N(5)`, `CODITE N(5)`, `DESITE C(30)`, `QTDITE N(4)`. Módulo `CVMTPED.PRG` não compila e não é chamado.

---

## 3. Tabelas obsoletas (predecessoras)

Sete tabelas são versões anteriores das ativas, distinguíveis pelo prefixo `CVB*` (nova) vs. sem `B` (antiga), e pela tipagem dos códigos:

| Obsoleta | Sucessora | Diferença principal |
|---|---|---|
| `CVCLIENT` (12 reg.) | `CVBCLIEN` | Estrutura **idêntica**. Dados divergentes: `CODCLI=1` duplicado; nomes diferentes; `CONSOR` invertido em vários registros |
| `CVFORNEC` (0) | `CVBFORNE` | Códigos `C(6)`; sem telefone/CEP/cidade/endereço |
| `CVFROTA` (0) | `CVBFROTA` | `CODCAR C(6)`, `CHASSI C(12)`; sem `CHASDO` |
| `CVFUNC` (0) | `CVBFUNC` | `CODFUN C(6)`, campos `NOMEFUN`/`CARGOFUN`/`COMISFUN`; sem CEP |
| `CVGRUPO` (0) | `CVBGRUPO` | Todos os códigos `C(6)`; campo `CARMOD C(10)` |
| `CVGRUCON` (0) | `CVBGRUCO` | Códigos `N`; ainda com `CARMOD`; sem `DATCON`/`NUMMES`/`NUPGRU`/`SORT`/`QUIT` |
| `CVPRONVE` (0) | `CVBPENT` | Só chaves + `DATVEN` + `VALPAG`; sem desnormalização |
| `CVVENPEC` (0) | `CVPECAS` | Tinha `DATVEN` e `VALUNI` — **campos perdidos na "evolução"** |
| `CVALMOX` (1 branco) | `CVBALMOX` | `CODALM`/`CODFORALM` como `C(6)` |

**Observação relevante:** `CVVENPEC` (antiga) possuía `DATVEN` (data da venda) e `VALUNI`. A sucessora `CVPECAS` **não tem data**. Isso significa que o movimento de peças **perdeu a dimensão temporal** ao longo do desenvolvimento. Ver §7.

---

## 4. Diagrama de relacionamentos (inferido)

```
                 ┌──────────────┐
                 │  CVBFORNE    │  CODFOR (PK)
                 └──────┬───────┘
                        │ 1
             ┌──────────┴────────────┐
             │ N                     │ N
      ┌──────▼──────┐        ┌───────▼──────┐
      │  CVBPECAS   │        │  CVBALMOX    │
      │ CODPEC (PK) │        │ CODALM (PK)  │
      │ QTDPEC ◄────┼──baixa │ (sem baixa)  │
      └──────┬──────┘        └──────────────┘
             │ 1
             │ N
      ┌──────▼───────────────┐        ┌──────────────┐
      │  CVPECAS (movimento) │◄───────┤  CVBCLIEN    │ CODCLI (PK)
      │  CODPEC, CODCLI      │  N   1 │  CONSOR      │
      └──────────────────────┘        └───┬──────┬───┘
                                      1   │      │ 1
      ┌──────────────┐        ┌───────────▼──┐   │
      │  CVBFROTA    │  1   N │  CVBPENT     │   │
      │ CODCAR (PK)  ├───────►│ CODCAR,CODCLI│   │
      │ QUANTCAR ◄───┼─baixa  │ CODFUN       │   │
      └───┬──────┬───┘        └───────┬──────┘   │
        1 │      │ 1                N │          │ N
          │      │            ┌───────▼──────┐   │
          │      │            │  CVBFUNC     │   │
          │      │            │ CODFUN (PK)  │   │
          │      │            │ COMFUN ◄─────┼───┼── acumula comissão
          │      │            └──────────────┘   │
          │ N    │ N                             │
   ┌──────▼──────┴─┐  fechamento  ┌──────────────▼──┐
   │  CVBGRUPO     ├─────────────►│  CVBGRUCO       │
   │ CODCON,CODCAR │  (RN-025)    │ + SORT, + QUIT  │
   │ CODGRU,NUPGRU │              │                 │
   └───────────────┘              └────────┬────────┘
           ▲                               │ sorteio
           │ CODGRU                        └──► baixa CVBFROTA
     ┌─────┴──────────┐
     │ CVMGRUPO.MEM   │  sequencial global
     └────────────────┘

  Derivadas (agregados para gráfico):
     CVVCAR (DESCAR → QUANTV)   ← CVBPENT
     CVVPEC (DESPEC → QUANTC)   ← CVPECAS
```

---

## 5. Chaves e identificadores — análise

| Tabela | Identificação no legado | Natureza | Decisão proposta |
|---|---|---|---|
| `CVBCLIEN` | `CODCLI` digitado pelo usuário | **Chave natural manual.** Sem geração automática; o operador escolhe um número livre | **Preservar** como PK (regra de negócio: o código é conhecido pelo operador) |
| `CVBFUNC` | `CODFUN` manual | idem | **Preservar** |
| `CVBFORNE` | `CODFOR` manual | idem | **Preservar** |
| `CVBPECAS` | `CODPEC` manual | idem | **Preservar** |
| `CVBALMOX` | `CODALM` manual | idem | **Preservar** |
| `CVBFROTA` | `CODCAR` manual — identifica **modelo** | idem | **Preservar** |
| `CVBGRUPO`/`CVBGRUCO` | `(CODGRU, NUPGRU)` | **Chave composta** implícita; `CODGRU` gerado por sequencial em `.MEM` | Preservar a composta como `UNIQUE`; PK técnica `id` |
| `CVBPENT` | **nenhuma** | Identidade posicional | **Introduzir PK técnica** `id INTEGER PRIMARY KEY` — decisão documentada em 09/D-16 |
| `CVPECAS` | **nenhuma** | Identidade posicional; sem número de venda | **Introduzir PK técnica** + campo `origem` ('VENDA'/'REPARO') — 09/D-17 |
| `CVVCAR`/`CVVPEC` | Descrição textual | **Chave natural frágil** (texto de 35 caracteres) | Substituir por FK ao código; manter como *view* agregada — 09/D-18 |
| `CVREPAR` | `CODORC` (`C(6)`) | Chave textual | Migrar como está; tabela sem módulo ativo |
| `CVBPEDID` | `CODPED` | Chave manual, verificada por `SEEK` | Migrar estrutura |

### Sequenciais

O único gerador de número do sistema é `MCODGRU` em `CVMGRUPO.MEM`, incrementado em `CVMTCON.PRG`. Todos os demais códigos são digitados.

---

## 6. Desnormalização deliberada

O legado copia atributos do cadastro para as tabelas de movimento no instante da gravação:

| Tabela de movimento | Campos copiados | Origem | Divergências reais encontradas |
|---|---|---|---|
| `CVBPECAS` | `NOMFOR` | `CVBFORNE.NOMFOR` | 0 |
| `CVBALMOX` | `NOMFORALM` | `CVBFORNE.NOMFOR` | 0 |
| `CVPECAS` | `DECPEC`, `NOMCLI` | `CVBPECAS`, `CVBCLIEN` | **1** (`CODPEC=2`: mov. "FERRARI-F40" vs. cad. "PARAFUSO") |
| `CVBPENT` | `DESCAR`, `VALCAR`, `NOMFUN`, `NOMCLI` | `CVBFROTA`, `CVBFUNC`, `CVBCLIEN` | **5 em `DESCAR`** (ver 08) |
| `CVBGRUPO`/`CVBGRUCO` | `NOMCON`, `VALPRE` | `CVBCLIEN`, `CVBFROTA.VALCAR` | 0 |

**Interpretação:** a cópia funciona como *snapshot histórico* (o nome/valor no momento da venda). Isso é legítimo e deve ser **preservado** — não substituído por *join*. As divergências encontradas comprovam que os dados de movimento **precedem** alterações no cadastro, o que confirma a intenção de *snapshot*.

Ver decisão em `09-DIVERGENCIAS-MODERNIZACAO.md` (D-19).

---

## 7. Pontos que exigem decisão (não determinados pelo legado)

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-01: Baixa de almoxarifado.**
> `CVBALMOX.QUANTALM` e `QUANALM` (mínimo) existem, mas **nenhuma rotina consome o almoxarifado**. Não há evento de requisição/consumo. Encontrado em: ausência de `REPLACE QUANTALM` fora de `CVMTALMX.PRG`.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-02: Identidade da venda de peças.**
> `CVPECAS` mistura vendas de balcão (`CVMTVPEC`) e peças de reparo (`CVMTVREP`) sem discriminador, sem número de venda e **sem data**. Não é possível determinar, a partir do legado, se duas linhas do mesmo cliente pertencem à mesma venda. O único indício de agrupamento é `VALTOT` preenchido apenas na última linha. Encontrado em: `CVMTVPEC.PRG:120-160`, `CVMTVREP.PRG:150-190`.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-03: Chassi individual.**
> `CVBFROTA.CHASSI`/`CHASDO` definem uma faixa, mas nenhuma venda registra **qual** chassi foi entregue. Não é possível rastrear veículo individual. Encontrado em: `CVBPENT` não possui campo de chassi.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-04: Módulo de orçamento.**
> `CVREPAR.DBF` + `CVIREP1.NTX` + `CVREPAR.DBT` existem e `CVMTVREP.PRG` declara variáveis para eles, mas o `USE` está comentado. Não é possível determinar se o orçamento deveria ser gravado, nem sua relação com `CVPECAS`. Encontrado em: `CVMTVREP.PRG:10-13` e `:8` (comentado).

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-05: Campo `CVBPENT.FORMA`.**
> Existe na estrutura, tem 2 registros preenchidos ("A VISTA"), mas **nenhum programa o grava**. Origem desconhecida (provavelmente edição manual em ferramenta externa). Encontrado em: ausência de `REPLACE FORMA` em todos os fontes.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-06: `CVBGRUPO.NUMPAG` e `NUMGRU`.**
> Ambos os `REPLACE` estão **comentados** em `CVMTCON.PRG` (linhas 145-146 e 165-166). Os campos estão sempre vazios. `NUMPAG` (parcelas pagas) parece redundante com `NUMMES` (parcelas restantes). Encontrado em: `CVMTCON.PRG`, `CVMCOM.PRG`.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-07: Ciclo de vida da comissão.**
> `CVBFUNC.COMFUN` acumula indefinidamente. Não há fechamento, pagamento, zeragem ou histórico. Encontrado em: nenhum `REPLACE COMFUN WITH 0` em todo o sistema.

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-08: Consorciado ≠ cliente.**
> `CVBCLIEN.CONSOR="S"` marca 17 clientes, mas só 5 têm registro em `CVBGRUPO`/`CVBGRUCO`. `CVMTCON` só é disparado ao **gravar** o cliente com `CONSOR="S"`, e pode ser abortado (ESC) deixando a marca sem o consórcio. Não é possível determinar se `CONSOR="S"` sem grupo é estado válido ou inconsistência. Encontrado em: `CVMTCLI.PRG:135-137`.

---

## 8. Qualidade dos dados atuais (medida)

Levantamento executado sobre os arquivos reais:

### 8.1 Volumes

| Tabela | Ativos | Excluídos (`*`) |
|---|---:|---:|
| `CVBCLIEN` | 22 | 0 |
| `CVBFUNC` | 10 | 0 |
| `CVBFORNE` | 3 | 0 |
| `CVBPECAS` | 4 | 0 |
| `CVBALMOX` | 4 | 0 |
| `CVBFROTA` | 5 | 0 |
| `CVBPENT` | 23 | 0 |
| `CVPECAS` | 75 | 0 |
| `CVBGRUPO` | 2 | **3** |
| `CVBGRUCO` | 3 | 0 |
| `CVVCAR` | 4 | 0 |
| `CVVPEC` | 10 | 0 |
| `CVREPAR` | 4 | 0 |
| `CVCLIENT` (obsoleta) | 12 | 0 |
| **Total ativo** | **169** | **3** |

Os 3 excluídos de `CVBGRUPO` são exatamente os 3 transferidos para `CVBGRUCO` — confirma o funcionamento de RN-025.

### 8.2 Integridade referencial — resultado

**Nenhum registro órfão foi encontrado** em nenhuma das 13 relações FK verificadas (`CVBPENT`→CLI/FUN/CAR, `CVPECAS`→CLI/PEC, `CVBPECAS`→FOR, `CVBALMOX`→FOR, `CVBGRUCO`→CLI/CAR, `CVBGRUPO`→CLI/CAR, `CVREPAR`→CLI/PEC).

A integridade sobrevive porque o volume é pequeno e nenhuma exclusão física (`PACK`) ocorreu em tabelas referenciadas com movimento pendente. **Isto não é garantia estrutural** — `SAIDA()` executa `PACK` em `CVBCLIEN`, `CVBFORNE` e `CVBFUNC` sem verificar dependências.

### 8.3 Chaves duplicadas

| Tabela | Resultado |
|---|---|
| `CVCLIENT` (obsoleta) | **`CODCLI=1` duplicado** (registros 4 e 12) |
| Todas as tabelas ativas | Sem duplicatas |

### 8.4 Datas suspeitas

| Tabela.Campo | Qtde | Exemplos |
|---|---:|---|
| `CVBCLIEN.NASCLI` | 6 | `1956-10-10`, `1911-11-11`, `1908-10-10`, `1910-07-02`, `1912-03-10`, `1901-01-01` |
| `CVBPENT.DATAV` | 2 | `1901-11-11`, `1901-01-01` |
| `CVREPAR.DATREP` | 4 | 3× `1910-10-10`, 1 vazia |

Causa provável: `SET DATE BRIT` com ano de 2 dígitos (`PICT "99/99/99"`) e `SET EPOCH` default (1900) — digitar `10/10/10` produz **1910**, não 2010. Nenhuma validação de faixa existe.

### 8.5 Estouro de campo numérico

`CVBGRUCO.NUMMES` registro 1 contém `**` — **overflow gravado pelo Clipper**. Os registros 2 e 3 contêm `-2` e `-3`.

Causa: `CVMTCON2.PRG` faz `NUMMES = NUMMES - <parcelas informadas>` sem piso em zero, e `NUMMES` é `N(2,0)` (faixa `-9..99`). Ver RN-026 e 09/D-11.

### 8.6 Campos numéricos vazios (nunca gravados)

| Campo | Vazios |
|---|---:|
| `CVBGRUPO.NUMPAG` | 5/5 (100%) |
| `CVBGRUPO.NUMGRU` | 5/5 (100%) |
| `CVBGRUCO.NUMPAG` | 3/3 (100%) |
| `CVBGRUCO.NUMGRU` | 3/3 (100%) |
| `CVPECAS.VALTOT` | 28/75 (37%) |
| `CVVPEC.QUANTC` | 6/10 (60%) |
| `CVALMOX.*` | 1/1 (registro em branco) |

### 8.7 Desnormalização divergente

`CVBPENT.DESCAR` vs. `CVBFROTA.DESCAR` — **5 divergências**:

| `CODCAR` | Em `CVBPENT` | No cadastro atual |
|---:|---|---|
| 3 | `Uno Mile ELX` | `FIORINO 1.6 IE` |
| 1 | `BatMovel` | `UNO ELX` |
| 3 | `BRASILIA` | `FIORINO 1.6 IE` |
| 4 | `FERRARI F-40` | `TIPO 1.6 IE 2 PORTAS` |
| 1 | `FUSCAO PRETO` | `UNO ELX` |

`CVPECAS.DECPEC` vs. `CVBPECAS.DECPEC` — **1 divergência** (`CODPEC=2`).

### 8.8 Agregados dessincronizados

`CVVPEC` (usado pelo gráfico de peças) vs. soma real de `CVPECAS.QTPECC`:

| Descrição | `CVVPEC.QUANTC` | Soma real | Δ |
|---|---:|---:|---:|
| MOLAS | 22 | 249 | −227 |
| PORCAS | 1 | 11.063 | −11.062 |
| ROELAS | 100 | 192 | −92 |
| PARAFUSO | 70 | 122 | −52 |
| PARAFUSOS / PORTAS / PNEUS / BANCOS / SUSPENSAO / (vazio) | vazio | 0 | — |

`CVVCAR` vs. contagem real de `CVBPENT`:

| Modelo | `CVVCAR.QUANTV` | Contagem real | Δ |
|---|---:|---:|---:|
| UNO ELX | 11 | 8 | +3 |
| TEMPRA 16 VALVULAS | 8 | 1 | +7 |
| FIORINO 1.6 IE | 9 | 5 | +4 |
| TIPO 1.6 IE | 12 | **0** | +12 |

**Conclusão:** ambos os agregados contêm dados **pré-carregados manualmente** e/ou perderam atualizações. `TIPO 1.6 IE` (agregado) nem sequer casa com `TIPO 1.6 IE 2 PORTAS` (cadastro) — a chave textual falhou. Os gráficos do legado **não refletem os dados transacionais**.

### 8.9 Consistência de estoque

`CVBPECAS.QTDPEC` atual: peça 1 = 9.939; peça 2 = 9.950; peça 3 = 9.940; peça 4 = 9.908. Somas vendidas em `CVPECAS`: 249, 122, 11.063, 192. Os saldos não reconstituem nenhum estoque inicial coerente — o estoque foi editado manualmente pela manutenção durante os testes.

### 8.10 Formato de dados heterogêneo

| Campo | Formatos observados |
|---|---|
| `CVBCLIEN.TELCLI` | `(0143)051-2382`, `(0143) 51-2665`, `(0143)51 -2529`, `(6666)666-6666` |
| `CVBCLIEN.CEPCLI` | numérico: `18800000`, `798797` (6 díg.), `5877` (4 díg.) |
| `CVBFORNE.CEPFOR` | texto: `18800-000` |
| `CVBFUNC.CEPFUN` | texto: `18800-000`, **`188000-00`** (malformado), vazio (7/10) |
| `CVBCLIEN.RGCLI` | `636.363.636-3`, `27-456744546545`, `28 .534.428-8`, ` 29.494.504-3` |
| `CVBCLIEN.CICCLI` | `465465465465465`, `/7556465464`, `285785454545`, `88888888888-888` |

---

## 9. Modelo SQLite proposto

### 9.1 Princípios adotados

1. **Uma tabela por entidade real**, descartando as 9 predecessoras obsoletas (migradas apenas se contiverem dados — só `CVCLIENT` contém, e será tratada como massa histórica separada).
2. **Exclusão lógica preservada** (`excluido INTEGER NOT NULL DEFAULT 0`) para reproduzir `SET DELETED ON`, com *views* `v_*` que já filtram.
3. **Chaves naturais preservadas** onde o operador as digita; **PK técnica introduzida** onde o legado não tinha identidade (`CVBPENT`, `CVPECAS`).
4. **Datas em ISO-8601** (`TEXT` `YYYY-MM-DD`), com `CHECK` de formato.
5. **Monetário em INTEGER de centavos** — evita ponto flutuante; o legado usa `N(12,2)`, exatamente 2 casas, sem operação que exija mais precisão.
6. **Texto em UTF-8**, `TRIM` aplicado na migração (o DBF preenche com espaços).
7. **Documentos normalizados** (`CPF`/`CNPJ`/`CEP`/telefone só dígitos), com o valor original preservado em coluna `*_original` para auditoria.
8. **Snapshot histórico mantido** nas tabelas de movimento (colunas `*_snapshot`).
9. `PRAGMA foreign_keys = ON`, WAL, prepared statements.

### 9.2 Esquema — CONSOLIDADO NA FASE C

> O esboço desta seção foi substituído pelo artefato real:
>
> | Arquivo | Conteúdo |
> |---|---|
> | **[`database/schema.sql`](../database/schema.sql)** | DDL completo — 19 tabelas, 26 índices, com a justificativa de cada decisão comentada no próprio SQL |
> | **[`database/views.sql`](../database/views.sql)** | 14 views — exclusão lógica (`SET DELETED ON`) e agregados (D-18) |
> | **[`database/README.md`](../database/README.md)** | Como aplicar, requisitos, composição, verificação |
>
> Aplicado e verificado com SQLite 3.46.1: `integrity_check = ok`,
> `foreign_key_check` vazio, `user_version = 1`, WAL persistido.

#### Composição final

| Grupo | Tabelas | Origem no legado |
|---|---|---|
| Cadastros nível 0 | `cliente` `funcionario` `fornecedor` `modelo_veiculo` | `CVBCLIEN` `CVBFUNC` `CVBFORNE`+`.DBT` `CVBFROTA` |
| Cadastros nível 1 | `peca` `almoxarifado` | `CVBPECAS` `CVBALMOX` |
| Movimento nível 2 | `venda_veiculo` `venda_peca` `consorcio_cota` `orcamento_reparo` `pedido` | `CVBPENT` `CVPECAS`(cab.) `CVBGRUPO`+`CVBGRUCO` `CVREPAR`+`.DBT` `CVBPEDID` |
| Movimento nível 3 | `venda_peca_item` | `CVPECAS` (itens) |
| Apoio | `sequencia` | `CVMGRUPO.MEM` |
| Controle | `migracao_execucao` `migracao_inconsistencia` | — |
| Quarentena | `_legado_cvvcar` `_legado_cvvpec` `_legado_cvclient` `_legado_cvbgrupo_excluido` | `CVVCAR` `CVVPEC` `CVCLIENT` `CVBGRUPO`(excluídos) |

#### Decisões acrescentadas na consolidação

| # | Decisão | Motivo |
|---|---|---|
| 1 | **Tabelas `STRICT`** (SQLite ≥ 3.37) | Tipagem realmente aplicada, não mera afinidade. Atende ao briefing §4: *"não utilize SQLite simplesmente como DBF moderno"*. Verificado: `UPDATE peca SET qtd_estoque='muitas'` é rejeitado |
| 2 | **Datas validadas como datas reais**, não só pelo formato | `CHECK (d GLOB '...' AND date(d) = d)` rejeita `1994-02-31`, que um `GLOB` sozinho aceitaria |
| 3 | **Padrão `*_legado`** para valores que violam `CHECK` | Ver D-11 e `08-MIGRACAO-DADOS.md` §4.2. Único caso no acervo: `CVBGRUCO.NUMMES` |
| 4 | **`CHECK (qtd_estoque >= 0)`** nas 3 tabelas de estoque | Nova divergência **D-27**, declarada por tornar mais restritiva uma operação que o legado aceitava |
| 5 | **`venda_peca.total_cent_legado`** e **`venda_peca_item.ordem`** | Permitem auditar o agrupamento heurístico de `CVPECAS` (D-17, risco RI-04) |
| 6 | **`venda_peca_item.valor_unit_cent` derivado** de `SUBTOT/QTPECC` | `CVPECAS` não tinha valor unitário; fica `NULL` quando a quantidade é 0 |
| 7 | **`ON DELETE RESTRICT`** em todas as FKs | O legado fazia `PACK` sem verificar dependências (D-15). `RESTRICT` só afeta exclusão **física**; a exclusão lógica (`excluido = 1`) continua livre, como no legado |
| 8 | **`ON DELETE CASCADE`** de `venda_peca_item` → `venda_peca` | Item não existe sem cabeçalho |
| 9 | **Índices parciais** (`WHERE excluido = 0`) | Menores e alinhados ao padrão de consulta da aplicação |
| 10 | **PKs `INTEGER` = rowid** | Ordenação por código não exige sort temporário — verificado em `EXPLAIN QUERY PLAN`. Reproduz de graça a ordem dos índices `.NTX` usada por todos os relatórios |
| 11 | **`NUMPAG` e `NUMGRU` não portados** | 100% vazios nos 8 registros; `REPLACE` comentado no legado (Q-06) |
| 12 | **`peca.nome_fornecedor` deixa de ser coluna** | Vira `JOIN` na view `v_peca`. É cadastro, não movimento — não há valor histórico a preservar, ao contrário de D-19 |

### 9.3 Justificativa de tipos

| Legado | SQLite | Motivo |
|---|---|---|
| `N(n,0)` código | `INTEGER` + `CHECK` de faixa | Preserva a faixa da máscara original |
| `N(12,2)` monetário | `INTEGER` (centavos) | Briefing §10: sem `FLOAT` para dinheiro. `N(12,2)` cabe em `INTEGER` de 64 bits com folga |
| `N(n,0)` quantidade | `INTEGER` + `CHECK >= 0` | Legado permitia negativo por falta de validação |
| `C(n)` | `TEXT` + `TRIM` na migração | DBF preenche com espaços à direita |
| `D` (`YYYYMMDD`) | `TEXT` `YYYY-MM-DD` + `CHECK GLOB` | Briefing §9: ISO interno, `DD/MM/YYYY` na UI |
| `L` (`T`/`F`) | `INTEGER 0/1` + `CHECK` | SQLite não tem booleano |
| `M` (memo `.DBT`) | `TEXT` | Elimina o arquivo separado |
| `L` inexistente em `CVBGRUPO` (`SORT`/`QUIT`) | `INTEGER DEFAULT 0` | O legado não os inicializava na transferência (RN-019); agora são explícitos |
| `CEPCLI N(8)` | `TEXT(8)` | Preserva zeros à esquerda — **[CORREÇÃO]**, ver 09/D-09 |
| flag `DELETED` do DBF | `excluido INTEGER` | Preserva `SET DELETED ON` |
