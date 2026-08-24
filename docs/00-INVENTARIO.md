# 00 — INVENTÁRIO DO SISTEMA LEGADO

**Sistema:** S.C.C.V. — Sistema de Controle de Concessionária de Veículos
**Cliente identificado no código:** "FIAT - Fralleti Ltda. — Piraju/SP"
**Linguagem:** CA-Clipper Summer '87
**Autores (cabeçalhos dos fontes):** Everton Morais Ventrici, Luiz A. Carlin, Oswaldo Coelho de Oliveira Junior, Wilson dos Santos Junior
**Período de desenvolvimento (datas nos cabeçalhos):** 07/01/1994 a 27/06/1994
**Última gravação de dados (header DBF):** 01/07/1994
**Diretório analisado:** `/home/lcarlin/Projects/sccv` (os originais foram movidos para `legacy/` na FASE C, com verificação SHA-256)
**Data da análise:** 2026-08-24

> Nenhum arquivo original foi alterado, movido ou removido **durante esta fase**
> (seção 24 do briefing).
>
> **Atualização (FASE C):** mediante autorização explícita, os 95 arquivos foram
> movidos para `legacy/`, com backup em `backup/legado-<timestamp>/` e verificação
> SHA-256 antes e depois (**0 falhas**). Estão protegidos contra escrita
> (`chmod a-w`). Nenhum byte foi alterado. Ver `legacy/README.md`.
> Todos os caminhos citados neste documento devem ser lidos com o prefixo `legacy/`.

---

## 1. Resumo quantitativo

| Categoria | Qtde | Observação |
|---|---:|---|
| Programas `.PRG` | 45 | 1 vazio (`B.PRG`), 1 fragmento de teste (`T.PRG`) |
| Tabelas `.DBF` | 23 | 10 em uso efetivo, 8 obsoletas/vazias, 5 auxiliares |
| Índices `.NTX` | 16 | todos com chave de campo simples |
| Memos `.DBT` | 3 | 2 com conteúdo, 1 vazio |
| Executáveis `.EXE` | 3 | `SCCV.EXE`, `CVTEABE.EXE`, `BCRETCTR.EXE`, `BCVGA.EXE` (4 no total) |
| Arquivo `.MEM` | 1 | `CVMGRUPO.MEM` — sequencial de grupo de consórcio |
| Imagem `.PCX` | 1 | `CVTEABE.PCX` — tela de abertura gráfica |
| Outros | 2 | `NORTON.INI`, `SKPLSDMP.DMP` (lixo de ferramentas DOS) |
| **Artefatos ausentes** | 4+ | `ETIQCLI.LBL`, `ETIQFOR.LBL`, `ETIQFUNC.LBL`, `CVIPED1.NTX` |

Contagem exata de executáveis: `SCCV.EXE` (362.544 b, aplicação principal), `CVTEABE.EXE` (246.192 b, tela de abertura gráfica), `BCVGA.EXE` e `BCRETCTR.EXE` (~7,5 KB cada — drivers/utilitários da biblioteca gráfica CLBC).

---

## 2. Programas `.PRG` — inventário funcional

### 2.1 Núcleo / infraestrutura

| Arquivo | Bytes | Papel | Situação |
|---|---:|---|---|
| `SCCV.PRG` | 6.385 | **Ponto de entrada.** Cria índices ausentes, define `SET`s globais, monta o menu horizontal de 5 grupos e despacha para os 18 módulos. Define `FUNAC()` (callback do `ACHOICE`). | ATIVO |
| `CV_FUNC.PRG` | 11.379 | **Biblioteca de funções.** 20 rotinas: bordas, mensagens, confirmação, tabela de códigos (browse), cabeçalhos de relatório, editor de memo, calculadora, espaço em disco, rotina de saída/reorganização. | ATIVO |
| `CVTELAS.PRG` | 5.893 | **Biblioteca de telas** (`MEN_T_1` … `MEN_T_19`). Desenha os rótulos fixos de cada formulário. | ATIVO |
| `CVTELAS1.PRG` | 5.058 | **Versão divergente** de `CVTELAS.PRG`. Mesmos nomes de procedure, layouts diferentes em `MEN_T_12/13/15/17`. | DUPLICADO — conflito de símbolos |
| `TELA.PRG` | 428 | Fragmento contendo apenas `MEN_T_11` (idêntico ao de `CVTELAS`). | MORTO |
| `CVTEABE.PRG` | 721 | Tela de abertura gráfica: detecta adaptador de vídeo via CLBC e exibe `CVTEABE.PCX`. Compilado separadamente em `CVTEABE.EXE`. | ATIVO (externo) |
| `DESARQ.PRG` | 9.028 | Biblioteca de terceiros (SoftCAD/CLBC 2.7) para desenhar DBFs de desenho vetorial. Usada por `CVTEABE.PRG`. | ATIVO (biblioteca) |
| `INICIA.PRG` | 679 | Fragmento de inicialização do mouse/CLBC. Sem `PROCEDURE`/`FUNCTION` — **não é compilável isoladamente**. | MORTO/INCOMPLETO |
| `DEFINE.PRG` | 744 | `DEFINE_CTR()` — configuração dos botões do mouse (CLBC). Chamado apenas por `INICIA.PRG`. | MORTO |
| `T.PRG` | 96 | Fragmento de teste (bloco de criação de `CVIALM1.NTX`). | MORTO |
| `B.PRG` | 1 | Vazio (apenas `^Z`). | MORTO |

### 2.2 Manutenção (inclusão / alteração / exclusão)

| Arquivo | Módulo | Tabela principal | Acionado por | Situação |
|---|---|---|---|---|
| `CVMTCLI.PRG` | Clientes | `CVBCLIEN` | menu Clientes→Manutenção; `CVMTVPEC`; `CVMTVREP`; `CVMTCON` | ATIVO |
| `CVMTFUNC.PRG` | Funcionários | `CVBFUNC` | menu Funcionários→Manutenção | ATIVO |
| `CVMTFOR.PRG` | Fornecedores | `CVBFORNE` + memo | menu Fornecedores→Manutenção | ATIVO |
| `CVMTPEC.PRG` | Estoque de peças | `CVBPECAS` + `CVBFORNE` | menu Estoques→Peças | ATIVO |
| `CVMTALMX.PRG` | Almoxarifado | `CVBALMOX` + `CVBFORNE` | menu Estoques→Almoxarifado | ATIVO |
| `CVMTFRO.PRG` | Frota | `CVBFROTA` | menu Estoques→Frota | ATIVO |
| `CVMTALM.PRG` | Almoxarifado (v. antiga) | `CVALMOX` | — | MORTO (substituído por `CVMTALMX`) |
| `CVCLI.PRG` | Clientes (v. antiga) | `CVCLIENT` | — | MORTO |
| `CVFORN.PRG` | Fornecedores (v. antiga) | `CVFORNEC` | — | MORTO |
| `CVPECAS.PRG` | Peças (v. antiga) | `CVPECAS` c/ índice inexistente `CVIPES1` | — | MORTO |
| `CVCONS.PRG` | Consorciados (v. antiga) | `CVCLIENT` filtrado por `CONSOR="S"` | — | MORTO |

### 2.3 Serviços / movimento

| Arquivo | Módulo | Tabelas gravadas | Situação |
|---|---|---|---|
| `CVMTVPEC.PRG` | **Venda de peças (balcão)** | `CVPECAS` (movimento), `CVBPECAS` (baixa), `CVBFUNC` (comissão), `CVVPEC` (agregado) | ATIVO |
| `CVMTVREP.PRG` | **Reparos de autos** (peças consumidas) | `CVPECAS`, `CVBFUNC`, `CVVPEC` | ATIVO |
| `CVMTPENT.PRG` | **Pronta entrega de veículos** | `CVBPENT`, `CVBFROTA` (baixa), `CVBFUNC` (comissão), `CVVCAR` (agregado) | ATIVO |
| `CVMTCON.PRG` | **Adesão a consórcio** (grupo de espera) | `CVBGRUPO`, `CVBGRUCO` (fechamento), `CVBFUNC` (comissão), `CVMGRUPO.MEM` | ATIVO (chamado por `CVMTCLI`) |
| `CVMTCON2.PRG` | **Baixa de prestações / sorteio** | `CVBGRUCO`, `CVBFROTA` | ATIVO |
| `CVMCOM.PRG` | Consórcio (v. anterior de `CVMTCON`) | `CVBGRUPO`, `CVBGRUCON` (tabela inexistente) | MORTO |
| `CVMTPED.PRG` | Pedidos a fornecedor | `CVBPEDID` | MORTO — não referenciado; **não compila** (bloco `IF` sem `ENDIF`) |

### 2.4 Consultas

| Arquivo | Alvo | Situação |
|---|---|---|
| `CVCONCLI.PRG` | Clientes — geral ou por código, browse `DBEDIT` | ATIVO |
| `CVCONFUN.PRG` | Funcionários | ATIVO |
| `CVCONFOR.PRG` | Fornecedores | ATIVO |
| `CVCONCON.PRG` | Consorciados (usa `CVCLIENT` e a função inexistente `CCOR()`) | MORTO |

### 2.5 Relatórios

| Arquivo | Relatório | Situação |
|---|---|---|
| `CVRCLI.PRG` | Clientes / Consorciados / Ambos | ATIVO |
| `CVRFUNC.PRG` | Funcionários | ATIVO |
| `CVRFOR.PRG` | Fornecedores | ATIVO |
| `CVREST.PRG` | Submenu de estoques → despacha p/ os 3 abaixo | ATIVO |
| `CVRPECAS.PRG` | Estoque de peças | ATIVO |
| `CVRALM.PRG` | Almoxarifado | ATIVO |
| `CVRFROTA.PRG` | Frota | ATIVO |
| `CVRSERV.PRG` | Serviços: vendas de peças, orçamentos, consórcios, pronta entrega (4 procedures internas) | ATIVO |
| `CVRSER.PRG` | Versão anterior/quebrada de `CVRSERV` (chama `CVRVENDAS`, inexistente) | MORTO |

### 2.6 Gráficos

| Arquivo | Gráfico | Fonte | Situação |
|---|---|---|---|
| `CVGRAFRO.PRG` | Pizza — venda mensal de veículos | `CVVCAR.DBF` | ATIVO |
| `CVGRAPEC.PRG` | Pizza — venda mensal de peças | `CVVPEC.DBF` | ATIVO |
| `SEMNOME.PRG` | Cópia de `CVGRAPEC` lendo o campo errado (`QUANTV` em vez de `QUANTC`) | `CVVPEC.DBF` | MORTO |

**Total:** 45 `.PRG` — **27 ativos**, **18 mortos/duplicados/incompletos**.

---

## 3. Tabelas `.DBF` — inventário

| Arquivo | Regs | Campos | Papel | Situação |
|---|---:|---:|---|---|
| `CVBCLIEN.DBF` | 22 | 12 | **Clientes** (produção) | ATIVA |
| `CVBFUNC.DBF` | 10 | 8 | **Funcionários** | ATIVA |
| `CVBFORNE.DBF` | 3 | 11 | **Fornecedores** (+ memo) | ATIVA |
| `CVBPECAS.DBF` | 4 | 7 | **Cadastro/estoque de peças** | ATIVA |
| `CVBALMOX.DBF` | 4 | 7 | **Almoxarifado** | ATIVA |
| `CVBFROTA.DBF` | 5 | 7 | **Frota de veículos** (estoque) | ATIVA |
| `CVBPENT.DBF` | 23 | 9 | **Vendas de pronta entrega** | ATIVA |
| `CVPECAS.DBF` | 75 | 7 | **Itens de venda/reparo de peças** (movimento) | ATIVA |
| `CVBGRUPO.DBF` | 5 (3 del.) | 12 | **Consórcio — grupo em formação** | ATIVA |
| `CVBGRUCO.DBF` | 3 | 14 | **Consórcio — grupo fechado** | ATIVA |
| `CVVCAR.DBF` | 4 | 2 | **Agregado p/ gráfico** — vendas por modelo | ATIVA (derivada) |
| `CVVPEC.DBF` | 10 | 2 | **Agregado p/ gráfico** — vendas por peça | ATIVA (derivada) |
| `CVBPEDID.DBF` | 0 | 4 | Pedidos a fornecedor | VAZIA — módulo não compila |
| `CVALMOX.DBF` | 1 (branco) | 7 | Almoxarifado v. antiga (`CODALM` como `C`) | OBSOLETA |
| `CVCLIENT.DBF` | 12 | 12 | Clientes v. antiga | OBSOLETA |
| `CVFORNEC.DBF` | 0 | 7 | Fornecedores v. antiga (+ memo) | OBSOLETA |
| `CVFROTA.DBF` | 0 | 6 | Frota v. antiga | OBSOLETA |
| `CVFUNC.DBF` | 0 | 7 | Funcionários v. antiga | OBSOLETA |
| `CVGRUPO.DBF` | 0 | 9 | Consórcio v. antiga (códigos `C`) | OBSOLETA |
| `CVGRUCON.DBF` | 0 | 10 | Consórcio v. antiga (códigos `N`) | OBSOLETA |
| `CVPRONVE.DBF` | 0 | 5 | Pronta entrega v. antiga | OBSOLETA |
| `CVVENPEC.DBF` | 0 | 6 | Venda de peças v. antiga | OBSOLETA |
| `CVREPAR.DBF` | 4 | 7 | **Orçamentos de reparo** — estrutura existe, nenhum programa ativo grava nela | ÓRFÃ (dados de teste) |

**Total:** 23 DBFs — **12 ativas**, **9 obsoletas/vazias**, **1 órfã com dados**, **1 vazia sem módulo funcional**.

> Contagem corrigida em 2026-08-24 (FASE D.1): a tabela acima continha uma linha
> `CVVCAR`/`CVVPEC` — *(já listadas)* que era um marcador, não um arquivo, e vinha
> sendo somada. São **23** arquivos `.DBF` no acervo — conferido contra `legacy/`
> e contra o backup pré-movimentação. Nada foi perdido: 45 PRG + 23 DBF + 16 NTX
> + 3 DBT + 1 MEM + 4 EXE + 1 PCX + 2 avulsos = **95 arquivos**, que é o total
> verificado por SHA-256.

---

## 4. Índices `.NTX`

Todos são NTX Clipper (assinatura `0x0006`, versão 1), chave de **campo simples**, **não únicos**.

| Índice | Tabela de origem (criação em `SCCV.PRG`) | Chave | Tam. | Consumidores |
|---|---|---|---:|---|
| `CVIALM1.NTX` | `CVALMOX` (obsoleta) | `codalm` | 6 | `CVMTALMX` (sobre `CVBALMOX`), `CVRALM`, `CVMTALM` |
| `CVICLI1.NTX` | `CVBCLIEN` | `codcli` | 5 | `CVMTCLI`, `CVCONCLI`, `CVRCLI`, `CVMTVPEC`, `CVMTVREP`, `CVMTPENT` |
| `CVIFOR1.NTX` | `CVBFORNE` | `codfor` | 6 | `CVMTFOR`, `CVCONFOR`, `CVRFOR`, `CVMTPEC`, `CVMTALMX` |
| `CVIFRO1.NTX` | `CVBFROTA` | `codcar` | 5 | `CVMTFRO`, `CVRFROTA`, `CVMTPENT`, `CVMTCON`, `CVMTCON2` |
| `CVIFUN1.NTX` | `CVBFUNC` | `codfun` | 6 | `CVMTFUNC`, `CVCONFUN`, `CVRFUNC`, e todos os módulos de comissão |
| `CVIPEC1.NTX` | `CVBPECAS` | `codpec` | 6 | `CVMTPEC`, `CVRPECAS`, `CVMTVPEC` |
| `CVIVPEC1.NTX` | `CVPECAS` | `codpec` | 6 | `CVMTVPEC`, `CVMTVREP` |
| `CVIPENT1.NTX` | `CVBPENT` | `codcar` | 5 | `CVMTPENT` |
| `CVIGRU1.NTX` | `CVBGRUPO` | `codcar` | 5 | `CVMTCON`, `CVMCOM` |
| `CVIGRU2.NTX` | `CVBGRUPO` | `codgru` | 5 | `CVMCOM` (morto) |
| `CVIGRUC1.NTX` | `CVBGRUCO` | `codcon` | 5 | `CVMTCON2` |
| `CVIGRA1.NTX` | `CVVCAR` | `descar` | 35 | — (só criado) |
| `CVIGRAC1.NTX` | `CVVCAR` | `descar` | 35 | `CVMTPENT`, `CVGRAFRO` |
| `CVIGRAV1.NTX` | `CVVCAR` | `descar` | 35 | — (só criado) |
| `CVIGRAP1.NTX` | `CVVPEC` | `despec` | 35 | `CVMTVPEC`, `CVMTVREP` |
| `CVIREP1.NTX` | `CVREPAR` | `codorc` | 6 | `CVMTVREP` (comentado) |

**Observação crítica:** `CVIALM1.NTX` é gerado a partir de `CVALMOX` (onde `CODALM` é `C(6)`) mas é usado por `CVMTALMX` e `CVRALM` sobre `CVBALMOX` (onde `CODALM` é `N(6)`). Tipos de chave incompatíveis. Ver `09-DIVERGENCIAS-MODERNIZACAO.md` (D-14).

---

## 5. Arquivos auxiliares

| Arquivo | Tipo | Conteúdo | Papel |
|---|---|---|---|
| `CVBFORNE.DBT` | Memo (bloco 512 b) | 2 memos: *"CODIGO DO ITEM TALVEZ NAO ESTEJA CORRETO PORQUE O OSWALDO COELHO DE OLIVEIRA JUNIOR e o genio universal. CIDADE"* e *"o babaca."* | Observações de fornecedor |
| `CVFORNEC.DBT` | Memo | vazio (só cabeçalho) | Tabela obsoleta |
| `CVREPAR.DBT` | Memo | vazio | Descrição do orçamento (`ORCREP`) |
| `CVMGRUPO.MEM` | Variável Clipper `.MEM` | `MCODGRU` (numérico) | **Sequencial global do código de grupo de consórcio.** Persiste entre execuções via `SAVE TO` / `RESTORE FROM ADDITIVE`. |
| `CVTEABE.PCX` | Imagem PCX 55 KB | Splash screen | Exibida por `CVTEABE.EXE` |
| `NORTON.INI` | Binário | Configuração do Norton Commander/Utilities | Sem relação com o sistema |
| `SKPLSDMP.DMP` | 10 bytes | Dump de ferramenta DOS | Sem relação com o sistema |

---

## 6. Artefatos referenciados e AUSENTES

| Referência | Onde | Impacto |
|---|---|---|
| `ETIQCLI.LBL` | `CVRCLI.PRG:64`, `CVRSER.PRG:59` | Opção "ETIQUETA" do menu de relatório de clientes **falha em runtime** |
| `ETIQFOR.LBL` | `CVRFOR.PRG:41` | idem — fornecedores |
| `ETIQFUNC.LBL` | `CVRFUNC/CVRALM/CVRPECAS/CVRFROTA:42` | idem — funcionários, almoxarifado, peças e frota (todos usam o mesmo `.LBL`, provável copy-paste) |
| `CVIPED1.NTX` | `CVMTPED.PRG:9` | Módulo de pedidos inoperante |
| `CVRVENDAS.PRG` | `CVRSER.PRG:17` | Programa inexistente |
| `CVBGRUCON.DBF` | `CVMCOM.PRG:12` | Tabela inexistente (a correta é `CVBGRUCO`) |
| `CVIPES1.NTX` | `CVPECAS.PRG:9` | Índice inexistente |
| `CCOR()` | `CVCONCON.PRG` | Função inexistente (provável nome anterior de `BORDA()`) |
| `TABELAP()`, `TABELAF()` | `CVPECAS.PRG`, `CVFORN.PRG` | Funções inexistentes |
| `AUX_COD` | `CVCLI`, `CVCONS`, `CVPECAS`, `CVFORN` | Variável nunca atribuída |
| `DESENHA_LASER()` | `DESARQ.PRG` | Já comentada no fonte; `LASER.OBJ` ausente |
| `8X8.BCM` | `CVGRAFRO`, `CVGRAPEC`, `SEMNOME` | Fonte bitmap da CLBC — necessária para os gráficos |
| Biblioteca **CLBC 2.7** (SoftCAD) | 35 funções `BC_*` | Não presente no diretório (linkada no `.EXE`) |
| Biblioteca **GIP 1.0** | 3 funções `GIP_*` | Idem |

---

## 7. Grafo de dependências dos módulos ativos

```
SCCV.PRG (entrada)
├── [globais] cv_func.prg, cvtelas.prg
├── Clientes
│   ├── CVMTCLI.PRG ──► CVBCLIEN + CVICLI1
│   │                 └─► CVMTCON.PRG (se CONSOR="S")
│   ├── CVCONCLI.PRG ─► CVBCLIEN + CVICLI1        [DBEDIT/FUNDBCON]
│   └── CVRCLI.PRG ───► CVBCLIEN + CVICLI1        [+ ETIQCLI.LBL AUSENTE]
├── Funcionários
│   ├── CVMTFUNC.PRG ─► CVBFUNC + CVIFUN1
│   ├── CVCONFUN.PRG ─► CVBFUNC + CVIFUN1
│   └── CVRFUNC.PRG ──► CVBFUNC + CVIFUN1         [+ ETIQFUNC.LBL AUSENTE]
├── Fornecedores
│   ├── CVMTFOR.PRG ──► CVBFORNE + CVIFOR1 + CVBFORNE.DBT
│   ├── CVCONFOR.PRG ─► CVBFORNE + CVIFOR1
│   └── CVRFOR.PRG ───► CVBFORNE + CVIFOR1        [+ ETIQFOR.LBL AUSENTE]
├── Serviços
│   ├── CVMTVPEC.PRG ─► CVBCLIEN, CVBPECAS, CVBFUNC, CVPECAS, CVVPEC
│   │                 └─► CVMTCLI.PRG (cadastro inline)
│   ├── CVMTVREP.PRG ─► CVBCLIEN, CVBFUNC, CVBPECAS, CVPECAS, CVVPEC
│   │                 └─► CVMTCLI.PRG (cadastro inline)
│   ├── CVMTCON2.PRG ─► CVBGRUCO, CVBFROTA, CVBPEDID
│   ├── CVMTPENT.PRG ─► CVBCLIEN, CVBFROTA, CVBFUNC, CVBPENT, CVVCAR
│   └── CVRSERV.PRG ──► CVPECAS, CVBGRUCO, CVBPENT   [4 sub-relatórios]
└── Estoques
    ├── CVMTPEC.PRG ──► CVBFORNE, CVBPECAS
    ├── CVMTALMX.PRG ─► CVBFORNE, CVBALMOX (índice CVIALM1 incompatível)
    ├── CVMTFRO.PRG ──► CVBFROTA + CVIFRO1
    ├── CVREST.PRG ───► CVRPECAS | CVRALM | CVRFROTA
    └── Gráficos
        ├── CVGRAFRO.PRG ─► CVVCAR + CVIGRAC1 + CLBC/GIP
        └── CVGRAPEC.PRG ─► CVVPEC + CLBC/GIP
```

### Módulo chamado fora do menu

`CVMTCON.PRG` só é alcançável através de `CVMTCLI.PRG` (quando o campo `CONSOR` recebe `"S"`). Ao final, `CVMTCON.PRG` chama **de volta** `CVMTCLI.PRG` (`DO CVMTCLI` na última linha, sem `RETURN`), criando **recursão mútua não terminada** — cada adesão a consórcio empilha uma nova instância da manutenção de clientes.

---

## 8. Estado do inventário

- [x] Todos os `.PRG` lidos integralmente e classificados por papel funcional.
- [x] Todos os `.DBF` abertos, estrutura e registros extraídos.
- [x] Todos os `.NTX` decodificados (chave, tamanho, unicidade).
- [x] Todos os `.DBT` inspecionados.
- [x] Grafo de chamadas construído por varredura de `DO`/`USE`.
- [x] Artefatos ausentes identificados por varredura de referências + `strings SCCV.EXE`.
- [x] Codificação de caracteres determinada empiricamente (**CP860**, ver `05-VALIDACOES-LEGADO.md` §7).
