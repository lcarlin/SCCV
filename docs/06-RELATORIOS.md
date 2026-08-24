# 06 — RELATÓRIOS

## 1. Catálogo

O sistema possui **12 relatórios funcionais** (8 programas, dos quais `CVRSERV` contém 4 sub-relatórios), mais **7 chamadas a etiquetas inoperantes**.

| # | Relatório | Programa | Fonte de dados | Menu |
|--:|---|---|---|---|
| R-01 | Clientes / Consorciados / Ambos | `CVRCLI.PRG` | `CVBCLIEN` + `CVICLI1` | Clientes → Relatório |
| R-02 | Funcionários | `CVRFUNC.PRG` | `CVBFUNC` + `CVIFUN1` | Funcionários → Relatório |
| R-03 | Fornecedores | `CVRFOR.PRG` | `CVBFORNE` + `CVIFOR1` | Fornecedores → Relatório |
| R-04 | Estoque de peças | `CVRPECAS.PRG` | `CVBPECAS` + `CVIPEC1` | Estoques → Relatório → Pecas |
| R-05 | Almoxarifado | `CVRALM.PRG` | `CVBALMOX` + `CVIALM1` | Estoques → Relatório → Amoxarifado |
| R-06 | Frota | `CVRFROTA.PRG` | `CVBFROTA` + `CVIFRO1` | Estoques → Relatório → Frota |
| R-07 | Venda de peças | `CVRSERV.PRG::VEN_PEC` | `CVPECAS` (sem índice) | Serviços → Relatório → Vendas de Pecas |
| R-08 | Orçamentos (reparos) | `CVRSERV.PRG::REP` | `CVPECAS` (sem índice) | Serviços → Relatório → Reparos |
| R-09 | Consórcios | `CVRSERV.PRG::CONS` | `CVBGRUCO` (sem índice) | Serviços → Relatório → Consorcios |
| R-10 | Pronta entrega | `CVRSERV.PRG::PRON_ENTR` | `CVBPENT` (sem índice) | Serviços → Relatório → Pronta Entrega |
| R-11 | Gráfico pizza — vendas de veículos | `CVGRAFRO.PRG` | `CVVCAR` + `CVIGRAC1` | Estoques → Graficos → Frota |
| R-12 | Gráfico pizza — vendas de peças | `CVGRAPEC.PRG` | `CVVPEC` (sem índice) | Estoques → Graficos → Pecas |

Relatórios mortos: `CVRSER.PRG` (versão anterior de `CVRSERV`, quebrada), `SEMNOME.PRG` (cópia de `CVGRAPEC` lendo campo inexistente), `CABECALHO()` e `REL_EST()` em `CV_FUNC.PRG`.

---

## 2. Ficha por relatório

### R-01 — Clientes

| Atributo | Valor |
|---|---|
| **Origem** | `CVBCLIEN.DBF` |
| **Filtros** | Menu de 3 opções: `SET FILTER TO CONSOR="S"` / `CONSOR="N"` / sem filtro (RN-040) |
| **Ordenação** | `CVICLI1.NTX` → **por `CODCLI` crescente** |
| **Agrupamento** | Nenhum |
| **Cálculos / totais / subtotais** | **Nenhum** |
| **Colunas** | `CODCLI`(0), `NOMCLI`(8), `TELCLI`(44), `CIDCLI`(59) |
| **Cabeçalho de coluna** | `RG("CLI")`: `CODIGO`(0) `NOME`(8) `TELEFONE`(44) `CIDADE`(59) |
| **Destinos** | Tela / Impressora / Etiqueta (`ETIQCLI.LBL` — **ausente**) |
| **Paginação** | Tela: 21 linhas/pág. com pausa e `CLEAR` · Impressora: 60 linhas/pág. |
| **Linha inicial** | `L = 8` |

### R-02 — Funcionários

| Atributo | Valor |
|---|---|
| **Origem** | `CVBFUNC.DBF` |
| **Filtros** | Nenhum |
| **Ordenação** | `CVIFUN1.NTX` → por `CODFUN` |
| **Cálculos** | Nenhum |
| **Colunas** | `CODFUN`(0), `NOMFUN`(8), `SALFUN`(48) |
| **Cabeçalho** | `RG("FUN")`: `CODIGO` `NOME` `SALARIO` |
| **Destinos** | Tela / Impressora / Etiqueta (`ETIQFUNC.LBL` — **ausente**) |
| **Paginação** | 21 / 60 |
| **Observação** | **Não lista `COMFUN`** — não existe relatório de comissões em todo o sistema |

### R-03 — Fornecedores

| Atributo | Valor |
|---|---|
| **Origem** | `CVBFORNE.DBF` |
| **Ordenação** | `CVIFOR1.NTX` → por `CODFOR` |
| **Colunas** | `CODFOR`(0), **`DESITE`**(8), `NOMFAB`(50) |
| **Cabeçalho** | `RG("FOR")`: `CODIGO` `DESCRICAO` `FABRICA` |
| **Destinos** | Tela (23 linhas) / Impressora (60) / Etiqueta (`ETIQFOR.LBL` — **ausente**) |
| **Observação 1** | Lista a **descrição do item**, não o nome do fornecedor. O rótulo diz "DESCRICAO" — coerente com o dado, mas o relatório se chama "de fornecedores" e não mostra `NOMFOR` |
| **Observação 2** | Emite `??i20` (condensado) na impressora — único relatório que o faz |
| **Defeito** | `IF NL = 18` no teste de quebra de página, mas `NL` só assume 23 ou 60 → **a pausa em tela nunca ocorre**; as linhas rolam sem parar |

### R-04 — Estoque de peças

| Atributo | Valor |
|---|---|
| **Origem** | `CVBPECAS.DBF` + `CVIPEC1` → por `CODPEC` |
| **Colunas** | `CODPEC`(0), `DECPEC`(8), `VALUNI`(48) |
| **Cabeçalho** | `RG("PEC")`: `CODIGO` `DESCRICAO` `VALOR UNITARIO` |
| **Cálculos** | Nenhum |
| **Observação** | **Não lista `QTDPEC` nem `QTDMIN`** — um "relatório de estoque" que não mostra a quantidade em estoque. Não existe relatório de itens abaixo do mínimo |
| **Etiqueta** | Aponta para `ETIQFUNC.LBL` (copy-paste de `CVRFUNC`) |

### R-05 — Almoxarifado

| Atributo | Valor |
|---|---|
| **Origem** | `CVBALMOX.DBF` + `CVIALM1` (**índice incompatível** — ver 09/D-14) |
| **Colunas** | `CODALM`(0), `DESCALM`(8), `QUANTALM`(48), `VALALM`(54), `CODFORALM`(68) |
| **Cabeçalho** | `RG("ALM")`: `CODIGO`(0) `DESCRICAO`(8) `QTD`(48) `VALOR`(57) `COD. FORNC.`(68) |
| **Cálculos** | Nenhum |
| **Defeito de layout** | `VALALM` é `N(12,2)` → ocupa colunas 54–65, mas o cabeçalho `VALOR` está em 57. Além disso `QUANTALM` (col. 48–50) e `VALALM` (col. 54) não colidem, mas `VALALM` (até col. 65) invade a área de `CODFORALM` (col. 68) apenas se o valor for grande |
| **Etiqueta** | `ETIQFUNC.LBL` (copy-paste) |

### R-06 — Frota

| Atributo | Valor |
|---|---|
| **Origem** | `CVBFROTA.DBF` + `CVIFRO1` → por `CODCAR` |
| **Colunas** | `CODCAR`(0), `DESCAR`(8), `QUANTCAR`(42), `VALCAR`(56), `DATCOMCAR`(70) |
| **Cabeçalho** | `RG("FRO")`: `CODIGO` `DESCRICAO` `QUANTIDADE`(42) `VALOR`(56) `DATA`(70) |
| **Cálculos** | Nenhum |
| **Não lista** | `CHASSI` / `CHASDO` |
| **Defeito** | O bloco `IF TELIMP=.T.` da primeira página chama **apenas `RG("FRO")`, sem `CABER()`** — a primeira página impressa sai sem cabeçalho de empresa/título/número de página. Nas páginas seguintes o `CABER()` aparece |
| **Etiqueta** | `ETIQFUNC.LBL` (copy-paste) |

### R-07 — Venda de peças

| Atributo | Valor |
|---|---|
| **Origem** | `CVPECAS.DBF` — **`USE CVPECAS` sem índice** |
| **Ordenação** | **Ordem física de inserção** (nenhum índice) |
| **Filtros** | Nenhum |
| **Colunas** | `CODCLI`(0), `DECPEC`(10), `QTPECC`(50), `VALTOT`(60) |
| **Cabeçalho** | `RG("VPE")`: `COD. CLI.`(0) `DESCRICAO`(10) `QUANTIDADE`(48) `VALOR DA COMPRA`(60) |
| **Cálculos / totais** | **Nenhum** — nem total geral, nem subtotal por cliente |
| **Linha inicial** | `L = 10` (vs. 8 nos demais) |
| **Problema semântico** | `VALTOT` só está preenchido no último item de cada compra (RN-027) → **37% das linhas mostram total zero/vazio**. O relatório não soma `SUBTOT`, que seria o valor correto por linha |
| **Problema semântico 2** | A tabela mistura vendas de balcão e peças de reparo sem distinção (Q-02) — este relatório mostra ambas |

### R-08 — Orçamentos (reparos)

| Atributo | Valor |
|---|---|
| **Origem** | `CVPECAS.DBF` — **a mesma tabela de R-07, sem filtro algum** |
| **Ordenação** | Ordem física |
| **Colunas** | `CODPEC`(0), `CODCLI`(12), `QTPECC`(24), `DECPEC`(36), `VALTOT`(66) |
| **Cabeçalho** | `RG("VRE")`: `COD. PEC.`(0) `COD. CLI.`(12) `QUANTIDADE`(24) `DESCRICAO`(36) `VALOR TOT.`(70) |
| **Cálculos** | Nenhum |
| **Problema** | **R-07 e R-08 listam exatamente os mesmos registros**, apenas com colunas reordenadas. Não há critério que separe "venda" de "orçamento". O relatório de orçamentos **não lê `CVREPAR.DBF`**, que é a tabela que existiria para isso |
| **Defeito de layout** | `DECPEC` é `C(35)` na coluna 36 → ocupa até a coluna 70, sobrepondo `VALTOT` (coluna 66) |

### R-09 — Consórcios

| Atributo | Valor |
|---|---|
| **Origem** | `CVBGRUCO.DBF` — sem índice; apenas grupos **fechados** |
| **Colunas referenciadas** | `CODCLI`(4), `NUMGRUP`(12), `NUMPRES`(24), `CODCAR`(36), `DATENT`(48), `DATFEC`(58), `VALPRES`(68) |
| **Cabeçalho** | `RG("RE")` — **`RG()` não possui ramo `"RE"`** → nenhum cabeçalho de coluna é impresso |
| **DEFEITO FATAL** | **Nenhum dos 7 campos existe em `CVBGRUCO`.** Os campos reais são `CODCON`, `NUMGRU`, `NUMPAR`, `CODCAR`, `DATCON`, `VALPRE`, `NUMMES`, `NUPGRU`, `GRUFEC`, `SORT`, `QUIT`. Apenas `CODCAR` casa. `CODCLI`, `NUMGRUP`, `NUMPRES`, `DATENT`, `DATFEC`, `VALPRES` **não existem** → **erro de runtime do Clipper na primeira linha** |
| **Situação** | **Relatório inoperante.** Nunca pode ter funcionado |
| **Não lista** | Grupos em formação (`CVBGRUPO`) |

### R-10 — Pronta entrega

| Atributo | Valor |
|---|---|
| **Origem** | `CVBPENT.DBF` — sem índice, ordem física |
| **Colunas** | `CODCAR`(0), `DESCAR`(11), `VALCAR`(39), `DATAV`(55), `CODCLI`(66) |
| **Cabeçalho** | `RG("PRE")`: `COD.  CAR.`(0) `DESCRICAO`(11) `VALOR CAR.`(42) `DATA. VEN.`(55) `COD.  CLI.`(66) |
| **Cálculos** | **Nenhum** — sem total de vendas nem contagem |
| **Defeito de layout** | `DESCAR` é `C(35)` na coluna 11 → ocupa até 46, sobrepondo `VALCAR` (39). O cabeçalho posiciona "VALOR CAR." em 42, mas o dado sai em 39 |
| **Não lista** | `CODFUN`/`NOMFUN` (vendedor) e `FORMA` |

### R-11 / R-12 — Gráficos de pizza

| Atributo | R-11 (Frota) | R-12 (Peças) |
|---|---|---|
| **Origem** | `CVVCAR.DBF` | `CVVPEC.DBF` |
| **Índice** | recria `CVIGRAC1` sobre `descar` e o abre | nenhum |
| **Valor da fatia** | `QUANTV` | `QUANTC` |
| **Rótulo da fatia** | `ALLTRIM(DESCAR)` | `ALLTRIM(DESPEC)` |
| **Título** | `Fiat - Fralleti Ltda. Piraju SP` / `Grafico de Venda Mensal de Veiculos` | `Fiat Fralleti Ltd. Piraju SP` / `Grafico de Venda de Pecas Mensal` |
| **Destaque** | Fatia de maior valor (`nFatDes`) | idem |
| **Paleta** | 16 cores cíclicas (`gip_lcor`) + padrões de preenchimento (`gip_pad`) | idem |
| **Fonte** | `8X8.BCM` (**ausente**) | idem |
| **Arquivo vazio** | `gip_erro(1)` e retorna | idem |
| **Encerramento** | `INKEY(0)` → `bc_gfejan()` → `bc_fim(0)` | idem |
| **Bibliotecas** | CLBC 2.7 + GIP 1.0 (**ausentes**) | idem |

**Problema de fundo:** ambos leem tabelas **agregadas materializadas** que estão dessincronizadas dos dados transacionais — divergências de até 11.062 unidades (`02-MODELO-DADOS.md` §8.8). O gráfico "mensal" **não tem recorte temporal algum**: as agregadas não têm data e acumulam desde sempre.

---

## 3. Funções de cabeçalho

### 3.1 `REL(cTit)` — cabeçalho de **tela**

```
 linha 1: ┌────────────────────────────── (moldura @1,0 TO 5,80)
 linha 2:              FIAT  -  Fralleti  ltda.                (col. 25)
 linha 3:      SCCV  -  Controle de Concessionaria e Veiculos  (col. 17)
 linha 4:              RELATORIO DE <TIT>                      (col. 25)
 linha 5: └──────────────────────────────
```

Sem data, sem número de página.

### 3.2 `CABER(cTit1, cTit2, lImp)` — cabeçalho de **impressora**

```
 linha 1: Emissao: <DATE()>                          Pagina No. <PG>
 linha 2: ================================================================================
 linha 3:        <expandido> Sistema Concessionaria de Veiculos
 linha 4:        <expandido> <titulo1 centralizado em 40 col.>
 linha 5:        <titulo2 centralizado em 40 col.>
 linha 6: ================================================================================
```

Incrementa `PG` internamente (`pg = pg + 1`).

**Defeito relevante:** a primeira instrução do corpo é `telimp = .F.` — **sobrescreve o parâmetro recebido**. O bloco `IF telimp / ?? i10 / ENDIF` que enviaria o código de 10 cpp **nunca executa**. O `?? i12` (12 cpp) na linha seguinte, porém, executa sempre. Efeito líquido: a impressora sempre recebe 12 cpp, nunca 10.

Além disso, `CABER` é chamada com **3 argumentos** em todos os relatórios (`CABER("FIAT...", "RELATORIO DE ...", telimp)`) mas declara **4 parâmetros** (`titulo1, titulo2, empresa, telimp`). O terceiro argumento cai em `empresa` e `telimp` chega **`NIL`** — o que torna o defeito acima irrelevante na prática, mas revela que o parâmetro nunca foi usado como pretendido.

### 3.3 `RG(cArq)` — cabeçalho de colunas

9 ramos: `CLI`, `FUN`, `FOR`, `PEC`, `FRO`, `ALM`, `VPE`, `VRE`, `PRE`. **O ramo `RE` (usado por R-09) não existe.**

### 3.4 `CABECALHO(nPag, nTipo)` — **função morta**

Cabeçalho alternativo com data, título por tipo (1=clientes, 2=consorciados) e colunas fixas. Nunca é chamada.

---

## 4. Paginação e destinos

| Destino | `NL` | Comportamento na quebra |
|---|---:|---|
| Tela | 21 (23 em `CVRFOR`) | `PG++`, `MENSAGEM(" ",24)` → pausa até tecla, `CLEAR` (só em `CVRCLI`, `CVRSERV`), `L = 8` (ou 10), reimprime cabeçalho |
| Impressora | 60 | `PG++`, reimprime cabeçalho. **Sem `EJECT`** — não há salto de página físico |
| Etiqueta | — | `LABEL FORM <arquivo> TO PRINT` — todos os `.LBL` estão ausentes |

**Defeitos de paginação:**
- `CVRFUNC`, `CVRPECAS`, `CVRALM`, `CVRFROTA`: fazem `MENSAGEM` + `L=8` mas **não fazem `CLEAR`** — as linhas novas sobrescrevem parcialmente as antigas na tela.
- `CVRFOR`: testa `IF NL = 18` quando `NL` só pode ser 23 ou 60 → **nunca pausa em tela**.
- Nenhum relatório emite `EJECT` entre páginas na impressora.
- `PG` é declarada `PUBLIC` dentro de cada relatório e zerada; `CABER()` a incrementa. Em tela, `PG` também é incrementada mas `REL()` não a exibe.

---

## 5. Dependências de impressora DOS

| Recurso | Uso | Substituição Linux |
|---|---|---|
| `SET DEVICE TO PRINTER` | 8 relatórios | Redirecionar `@..SAY` para arquivo de texto |
| `SET CONSOLE OFF/ON` | idem | Não aplicável |
| `ISPRINTER()` | 8 pontos | Verificar fila CUPS (`lpstat`) ou aceitar destino arquivo |
| `i10` = `CHR(30)+"0"` | 10 cpp (nunca ativo — §3.2) | Descartar |
| `i12` = `CHR(30)+"2"` | 12 cpp | Descartar |
| `i20` = `CHR(15)+CHR(14)` | Condensado + expandido | Descartar |
| `ia5` = `CHR(14)` / `id5` = `CHR(20)` | Expansão liga/desliga | Descartar |
| `EJECT` | Só em `CVMTPED` (morto) | `\f` ou quebra lógica |
| `LABEL FORM ... TO PRINT` | 7 pontos | Gerador próprio |

`CHR(30)` = `RS` — sequência da **IBM ProPrinter**; `CHR(14)`/`CHR(15)`/`CHR(20)` são ESC/P (Epson). Ambos os dialetos são usados no mesmo sistema.

---

## 6. Requisitos funcionais do relatório novo

Preservar (briefing §19: *"Preserve a informação funcional. Não é necessário reproduzir limitações físicas de impressoras matriciais/DOS"*):

| Preservar | Descartar |
|---|---|
| Conjunto de colunas de cada relatório | Códigos ESC/P e larguras de coluna fixas |
| Ordenação por código (via índice) | Paginação de 21/60 linhas |
| Filtro de clientes por tipo (RN-040) | `ISPRINTER()` bloqueante |
| Título "FIAT - Fralleti Ltda." e "S.C.C.V." | Detecção de impressora matricial |
| Data de emissão e número de página | — |
| Destinos tela e impressão | Destino "etiqueta" (arquivos ausentes; não há como determinar o layout) |

### Correções necessárias

| # | Correção | Motivo |
|---|---|---|
| CR-01 | R-09 (Consórcios): mapear para os campos reais de `CVBGRUCO` | Relatório inoperante |
| CR-02 | R-07 (Venda de peças): usar `SUBTOT` por linha e **totalizar** | `VALTOT` só existe na última linha |
| CR-03 | R-07/R-08: **discriminar** venda de balcão vs. reparo | Hoje listam os mesmos dados |
| CR-04 | R-04 (Peças): incluir `QTDPEC` e `QTDMIN` | Relatório de estoque sem estoque |
| CR-05 | R-06 (Frota): emitir `CABER()` na primeira página | Página 1 sem cabeçalho |
| CR-06 | R-03 (Fornecedores): corrigir o teste `IF NL = 18` | Pausa em tela nunca ocorre |
| CR-07 | R-08/R-10: corrigir sobreposição de colunas | Colunas se sobrepõem |
| CR-08 | R-11/R-12: gerar o agregado por consulta, não por tabela materializada | Agregados dessincronizados |
| CR-09 | Adicionar `CLEAR` na quebra de página em tela (4 relatórios) | Sobreposição visual |

### Relatórios ausentes que o negócio pareceria exigir

> **REGRA NÃO DETERMINADA PELO LEGADO — Q-11.** Não existe relatório de: comissões por funcionário (o dado é acumulado mas nunca listado), itens abaixo do estoque mínimo (o dado existe mas nunca é usado em relatório), grupos de consórcio em formação, movimento por período (não há data no movimento de peças). **Não serão criados nesta migração** — apenas registrados como lacuna, para decisão do responsável pelo negócio.

---

## 7. Formato de saída proposto

Conforme briefing §19:

| Destino | Implementação |
|---|---|
| **Terminal** | Paginação por altura real do terminal (`MaxRow()`), com pausa |
| **Arquivo** | Texto UTF-8, largura 80 ou 132 configurável, quebra de página por `\f` |
| **Impressão Linux** | Gerar arquivo e enviar via `lp`/`lpr`, sem códigos de escape proprietários |
| **PDF** | **Não implementar** — briefing §19: *"Não implemente PDF automaticamente se isso aumentar desnecessariamente a complexidade"*. Um arquivo de texto pode ser convertido externamente (`enscript`, `paps`) se necessário |
| **Etiqueta** | **Não implementar** — os arquivos `.LBL` estão ausentes e o layout não é recuperável. Registrar como funcionalidade perdida em `09-DIVERGENCIAS-MODERNIZACAO.md` (D-21) |
