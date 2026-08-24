# 01 — ARQUITETURA DO SISTEMA LEGADO

## 1. Visão geral

O S.C.C.V. é uma aplicação **monolítica DOS de tela cheia 80×25**, escrita em CA-Clipper Summer '87, com persistência em arquivos DBF/NTX locais e uma camada gráfica opcional (biblioteca CLBC) usada apenas para a tela de abertura e dois gráficos de pizza.

Não existe separação entre interface, regra de negócio e persistência. Cada `.PRG` de módulo contém, no mesmo laço, o desenho da tela, os `GET`s, as validações, os `SEEK` e os `REPLACE`.

```
┌──────────────────────────────────────────────────────────┐
│  CVTEABE.EXE      (splash gráfico — processo separado)   │
└──────────────────────────────────────────────────────────┘
                          ↓ (execução manual / batch)
┌──────────────────────────────────────────────────────────┐
│  SCCV.EXE                                                │
│  ┌────────────────────────────────────────────────────┐  │
│  │ SCCV.PRG — bootstrap + menu horizontal (ACHOICE)   │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ 18 módulos .PRG (manutenção/consulta/relatório/    │  │
│  │ movimento/gráfico) — cada um com laço próprio      │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌──────────────────────┬─────────────────────────────┐  │
│  │ CV_FUNC.PRG          │ CVTELAS.PRG                 │  │
│  │ (20 funções comuns)  │ (19 layouts de tela)        │  │
│  └──────────────────────┴─────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ DBFNTX (RDD nativo do Clipper) — work areas 1..n   │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ CLBC 2.7 + GIP 1.0 (gráficos, mouse, PCX)          │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                          ↓
      *.DBF  *.NTX  *.DBT  *.MEM  (diretório corrente)
```

---

## 2. Bootstrap (`SCCV.PRG`)

### 2.1 Configuração global (`SET`s)

| Comando | Efeito | Relevância na migração |
|---|---|---|
| `SETCANCEL(.F.)` | Desabilita Alt+C | Substituir por tratamento de sinal |
| `SET PROC TO cvtelas` … `SET PROC TO cv_func` | Arquivo de procedures | Em Harbour não é necessário (link estático) |
| `SET DEVICE TO SCREEN` / `SET PRINT OFF` / `SET CONS ON` | Saída padrão | — |
| **`SET DATE BRIT`** | Formato de data `DD/MM/YY` na apresentação | Preservar na UI; armazenar ISO |
| **`SET DELETED ON`** | Registros marcados como excluídos ficam **invisíveis** a `SKIP`, `SEEK`, `COUNT`, browse e relatórios | **Regra semântica: exclusão é lógica.** Ver RN-034 |
| `SET KEY -1 TO DISKSPACE()` | F1 → espaço em disco | Reimplementar ou descartar |
| `SET KEY -2 TO CONSORCALC()` | F2 → calculadora | Reimplementar ou descartar |
| `SET KEY 301 TO SAIDA()` | Alt+X → sair | Reimplementar |
| `SET TALK OFF` / `SET WRAP ON` / `SET SCORE OFF` / `SET CURSOR ON` | Cosmético | — |

### 2.2 Auto-criação de índices

Antes de qualquer coisa, o bootstrap testa `FILE("<indice>.ntx")` para 16 índices e, se ausente, abre a tabela e executa `INDEX ON`. Isso torna o sistema **auto-recuperável** após perda de índice, mas é também a origem da incompatibilidade `CVIALM1` (criado sobre `CVALMOX`, usado sobre `CVBALMOX`).

Também inicializa `CVMGRUPO.MEM` com `MCODGRU = 0` se o arquivo não existir.

### 2.3 Variáveis públicas criadas

| Variável | Conteúdo | Uso |
|---|---|---|
| `ia5` = `CHR(14)` | Ativa expansão da impressora matricial | `CABER()` |
| `id5` = `CHR(20)` | Desativa expansão | `CABER()` |
| `i10` = `CHR(30)+"0"` | 10 cpp | `CABER()` |
| `i12` = `CHR(30)+"2"` | 12 cpp | `CABER()` |
| `i20` = `CHR(15)+CHR(14)` | Condensado | `CVRFOR` |
| `OP`, `ESC`, `VARA`, `SAIR`, `TECLA` | Estado do menu | `SCCV`, `FUNDB` |
| `PG` | Contador de página (declarado `PUBLIC` **dentro de cada relatório**) | `CABER()` |
| `VET[1]` | Vetor descartado | — |

Os códigos de escape são de **impressora matricial Epson/IBM ProPrinter** — ver `06-RELATORIOS.md` §5.

### 2.4 Menu principal

Menu horizontal de 5 grupos na linha 2, navegado por `Ctrl+D`/`Ctrl+S` (teclas 4 e 19 de `LASTKEY()`, isto é, setas direita/esquerda), com submenus verticais desenhados por `ACHOICE()` e callback `FUNAC()`.

| Índice `mov` | Coluna `cl` | Grupo | Opções |
|---:|---:|---|---|
| 0 | 1 | Clientes | Manutenção, Consulta, Relatório |
| 1 | 17 | Funcionários | Manutenção, Consulta, Relatório |
| 2 | 33 | Fornecedores | Manutenção, Consulta, Relatório |
| 3 | 49 | Serviços | Venda Peças, Reparos, Consórcios, Pronta Entr, Relatório |
| 4 | 63 (65 ao voltar) | Estoques | Peças, Almoxarifado, Frota, Relatório, Gráficos → (Frota \| Peças) |

**Total: 18 pontos de entrada funcionais.**

> Observação: os vetores `cons` e `forn` são cópias de `clie` via `ACOPY()`; os três submenus de cadastro exibem literalmente os mesmos rótulos.

---

## 3. Camada de apresentação (`CV_FUNC.PRG` + `CVTELAS.PRG`)

### 3.1 Funções de UI (`CV_FUNC.PRG`)

| Função | Assinatura | Papel |
|---|---|---|
| `BORDA()` | `(lTop,cLeft,lBot,cRight [,cCor])` | Caixa com sombra (`BOX` deslocado 1×2) |
| `MEIO()` | `(cTit, nLin)` | Centraliza texto em 80 colunas |
| `MENSAGEM()` | `(cTexto [,nLin])` | Mensagem na linha 23 + `INKEY(0)` bloqueante. **O parâmetro de linha é aceito mas ignorado** — sempre escreve em 23 |
| `LIMPA()` | `()` | Limpa a linha 23 |
| `CONFIRMA()` | `(nL,nC,cTexto) → lógico` | Pergunta S/N na linha 23. **`nL`/`nC` também são ignorados** |
| `TELA()` | `(nNum)` | Despacha para `MEN_T_<n>` via macro `&` |
| `MENU_CON()` | `(nL,nC) → 0/1/2` | Menu "Geral / Por código" das consultas |
| `TABELA()` | `() → RECNO()` | **Browse de seleção de código** — ver §3.2 |
| `FUNDB()` | callback `DBEDIT` | Devolve o código selecionado |
| `FUNDBCON()` | callback `DBEDIT` | Browse de consulta: F3 pesquisa, ENTER abre memo, ESC sai |
| `OBSER()` | `(lEdit, cVarCampo [,lEdt2])` | `MEMOEDIT()` sobre campo memo |
| `OPREL()` | `(nL,nC) → 1/2/3` | Menu de destino: Tela / Impressora / Etiqueta |
| `REL()` | `(cTit)` | Cabeçalho de relatório em **tela** |
| `CABER()` | `(cTit1,cTit2,cEmpresa,lImp)` | Cabeçalho de relatório em **impressora** |
| `RG()` | `(cArq)` | Cabeçalho de colunas por tipo de relatório (9 variantes) |
| `CABECALHO()` | `(nPag,nTipo)` | Cabeçalho alternativo — **nunca chamado** (morto) |
| `REL_EST()` | `()` | Submenu de estoque — **nunca chamado** (`CVREST.PRG` o substituiu) |
| `DISKSPACE()` | tecla F1 | Espaço livre em disco |
| `CONSORCALC()` | tecla F2 | Calculadora de 500 posições |
| `SAIDA()` | Alt+X | Confirmação + reorganização + `CANCEL` |
| `DOS()` | `()` | Shell `!c:\command` — **nunca chamado** (morto) |

### 3.2 O padrão `TABELA()` — seleção de código por browse

Mecanismo central de toda a UI de entrada de dados:

```
TABELA()
  ├─ monta VCAMP[1..2] com FIELDNAME(1) e FIELDNAME(2) da área ativa
  ├─ DBEDIT com callback FUNDB()
  └─ FUNDB(), ao receber ENTER (modo 4, LASTKEY()=13):
        vara = "M" + FIELDNAME(1)      →  ex.: "MCODCLI"
        varb =        FIELDNAME(1)     →  ex.: "CODCLI"
        &vara = &varb                  →  MCODCLI := CODCLI   (macro)
```

Ou seja: a função **descobre por convenção de nomes** que a variável de memória do módulo chamador se chama `M` + nome do primeiro campo, e a preenche por substituição de macro. É acoplamento por convenção textual, sem contrato explícito.

**Consequência para a migração:** este mecanismo não tem equivalente direto e deve ser substituído por uma função de *lookup* que **retorne** o código selecionado. Ver `09-DIVERGENCIAS-MODERNIZACAO.md` (D-02).

### 3.3 Telas (`CVTELAS.PRG`)

19 procedures `MEN_T_1` … `MEN_T_19` que apenas desenham rótulos fixos.

| Proc | Tela | Usada por |
|---|---|---|
| `MEN_T_1` | Manutenção de Clientes | `CVMTCLI`, `CVCLI`, `CVCONS` |
| `MEN_T_2` | Manutenção de Funcionários | `CVMTFUNC` |
| `MEN_T_3` | Manutenção de Fornecedores | `CVMTFOR` |
| `MEN_T_4` | Vendas de Peças (layout antigo) | — (morta) |
| `MEN_T_11` | Reparos de Autos | `CVMTVREP` |
| `MEN_T_12` | Consórcios | `CVMTCON`, `CVMCOM` |
| `MEN_T_13` | Pronta Entrega de Veículos | `CVMTPENT` |
| `MEN_T_14` | Estoque de Peças | `CVMTPEC`, `CVPECAS` |
| `MEN_T_15` | Estoque – Peças (venda) | `CVMTVPEC` |
| `MEN_T_16` | Estoque – Almoxarifado | `CVMTALMX` |
| `MEN_T_17` | Estoque – Frota | `CVMTFRO` |
| `MEN_T_18` | Consórcio – baixa de prestações | `CVMTCON2`, `CVMTALM` |
| `MEN_T_19` | Pedidos | `CVMTPED` |
| `MEN_T_5..10` | **Não existem** | `CVFORN.PRG` chama `TELA(7)` → falha em runtime |
| `MENS` | Rodapé `<Esc>-Retorna <ENTER>-Tabela de Codigos` | todas |

`CVTELAS1.PRG` redefine `MEN_T_1..17` com **layouts diferentes** em `MEN_T_12`, `MEN_T_13`, `MEN_T_15` e `MEN_T_17`. Como ambos os arquivos definem os mesmos símbolos, apenas um pode ser linkado. As coordenadas usadas em `CVMTPENT.PRG` (linhas 08–15) correspondem a **`CVTELAS.PRG`**; as de `CVMTVPEC.PRG` (linhas 07–18) correspondem a `CVTELAS.PRG` `MEN_T_15`. Conclusão: **`CVTELAS.PRG` é a versão vigente; `CVTELAS1.PRG` é resíduo.**

---

## 4. Camada de persistência

### 4.1 Modelo de acesso

- RDD **DBFNTX** nativo, arquivos no **diretório corrente**.
- Nenhum caminho é qualificado — a aplicação **só funciona se executada de dentro do diretório de dados**.
- Índices `.NTX` abertos com `USE <tabela> INDEX <indice>` — no máximo 1 índice por área.
- Navegação por `SEEK` / `FOUND()` / `SKIP` / `GO TOP` / `RECNO()`.
- Gravação por `APPEND BLANK` + série de `REPLACE` campo a campo (**sem transação**).
- Filtros por `SET FILTER TO` (avaliação registro a registro).

### 4.2 Uso de work areas

A maioria dos módulos **não usa `SELECT`** — opera na área 1 implícita e troca de tabela com `USE`, o que **fecha a tabela anterior e perde o posicionamento**. Este é o mecanismo por trás de vários defeitos de gravação em registro errado (ver `09-DIVERGENCIAS-MODERNIZACAO.md`, D-05, D-07, D-08).

Módulos que usam `SELECT` explicitamente:

| Módulo | Áreas |
|---|---|
| `CVMTPEC` | 1=`CVBFORNE`, 2=`CVBPECAS` |
| `CVMTALMX` | 1=`CVBFORNE`, 2=`CVBALMOX` |
| `CVMTCON` | 1=`CVBGRUPO`, 2=`CVBFROTA`, 3=`CVBGRUCO`, 4=`CVBFUNC` |
| `CVMTCON2` | 1=`CVBGRUCO`, 2=`CVBFROTA`, 3=`CVBPEDID` |
| `CVMCOM` (morto) | 1..5 |
| `CVMTPED` (morto) | 1=`CVBPEDID` |

### 4.3 Concorrência

**Inexistente.** Nenhum `USE ... SHARED`, `RLOCK()`, `FLOCK()` ou `SET EXCLUSIVE`. O sistema pressupõe **monousuário**.

### 4.4 Integridade referencial

**Inexistente no motor.** É emulada por `SEEK` + `IF .NOT. FOUND()` nos pontos de entrada, e por **desnormalização defensiva**: as tabelas de movimento copiam a descrição/nome do cadastro no momento da gravação (`NOMCLI` em `CVPECAS` e `CVBPENT`, `DESCAR` em `CVBPENT`, `NOMFOR` em `CVBPECAS`/`CVBALMOX`). Ver `02-MODELO-DADOS.md` §6.

---

## 5. Tratamento de erros

**Não existe.** Não há `BEGIN SEQUENCE`, `ERRORBLOCK()`, `RECOVER` ou log em nenhum dos 45 fontes.

Estratégias efetivamente empregadas:

| Situação | Tratamento |
|---|---|
| Código não encontrado | `MENSAGEM("Codigo Nao Cadastrado")` + `INKEY()` |
| Impressora ausente | Laço `DO WHILE .NOT. ISPRINTER()` com `MEIO(...)` e saída por ESC |
| Adaptador gráfico incompatível | Mensagem + `QUIT` (`CVTEABE.PRG`) |
| Arquivo de dados vazio | `FUNDBCON()` modo 3 → `MENSAGEM("Arquivo Vazio")` |
| Erro de runtime do Clipper | **Abortar com a tela de erro padrão do Clipper** |
| Saída normal | `SAIDA()` → `CANCEL` |

`CANCEL` e `QUIT` são as duas únicas formas de encerramento. Ambas foram explicitamente vetadas para a nova implementação (briefing §18).

---

## 6. Estado global e persistente

| Mecanismo | Onde | Conteúdo |
|---|---|---|
| Variáveis `PUBLIC` | `SCCV.PRG` | Códigos de impressora, estado do menu |
| Variável `PUBLIC PG` | redeclarada em cada relatório | Número da página |
| Variáveis `M<campo>` | criadas em cada módulo, lidas por `FUNDB()` via macro | Buffer de edição |
| `SAVE SCREEN TO <var>` | ~15 pontos | Pilha manual de telas (`TEL_MEN`, `TELA_TE`, `TELANT`, `TELDB`, `TEL_CON`, `TELA_RCLI`, `TELA_RFUNC`, `CLI`, `TEL`, `TEL_DOS`) |
| **`CVMGRUPO.MEM`** | `CVMTCON.PRG` | **`MCODGRU` — sequencial persistente do código de grupo de consórcio.** Único contador global do sistema |

---

## 7. Dependências de plataforma DOS/Clipper a eliminar

| Dependência | Local | Substituto Linux/Harbour |
|---|---|---|
| `!c:\command` | `CV_FUNC.PRG:DOS()` | Remover (função já é morta) |
| `DISKSPACE()` | F1 | `HB_DISKSPACE()` ou `statvfs` |
| `ISPRINTER()` | 7 relatórios | Verificação de fila CUPS / `lp` |
| `SET DEVICE TO PRINTER` | 8 relatórios | Redirecionar para arquivo + `lp` |
| Códigos ESC/P (`CHR(14)`, `CHR(15)`, `CHR(30)`) | `CABER()`, `CVRFOR` | Descartar; formatar texto puro |
| `TONE(250,1)` | `SAIDA()` | `HB_ALERT` / bell do terminal ou remover |
| `LABEL FORM ... TO PRINT` | 7 pontos | Gerador de etiquetas próprio (arquivos `.LBL` ausentes) |
| Biblioteca **CLBC 2.7** (35 funções `BC_*`) | gráficos, mouse, PCX | Remover; gráfico em caracteres ou exportação de dados |
| Biblioteca **GIP 1.0** (3 funções `GIP_*`) | gráficos de pizza | idem |
| `ACHOICE()` / `DBEDIT()` | menus e browses | `HB_ACHOICE` (compatível) ou `TBrowse` |
| `MEMOEDIT()` | observações | `MEMOEDIT()` do Harbour (compatível) |
| `SAVE/RESTORE SCREEN` | 15 pontos | `SAVESCREEN()`/`RESTSCREEN()` (compatível) |
| Charset **CP860** | todos os fontes e dados | Converter para UTF-8 |
| `SET DATE BRIT` | global | Manter na apresentação |
| `.MEM` (`SAVE TO`/`RESTORE FROM`) | sequencial de grupo | Tabela de sequências no SQLite |
| Diretório corrente como raiz de dados | todo o sistema | XDG / `/var/lib` configurável |

---

## 8. Correspondência Clipper Summer '87 → Harbour

| Construção original | Equivalente Harbour | Justificativa |
|---|---|---|
| `USE x INDEX y` | `USE x INDEX y` ou camada SQLite | Mantida na migração de dados; substituída na aplicação |
| `SEEK` / `FOUND()` | `SELECT ... WHERE` | Índice B-Tree do SQLite |
| `APPEND BLANK` + `REPLACE` | `INSERT` preparado | Atomicidade |
| `DELETE` + `SET DELETED ON` | Coluna `excluido INTEGER DEFAULT 0` + *views* | Preserva a semântica de exclusão lógica |
| `PACK` | `DELETE FROM ... WHERE excluido=1` explícito | Operação administrativa, não implícita na saída |
| `REINDEX` | desnecessário | SQLite mantém os índices |
| `SET FILTER TO` | cláusula `WHERE` | Elimina varredura registro a registro |
| `&macro` (`&vara = &varb`) | função com retorno tipado | Remove acoplamento por convenção de nome |
| `PUBLIC` / `PRIVATE` | `STATIC` de módulo, `LOCAL`, parâmetros | Escopo léxico do Harbour |
| `DECLARE v[n]` | `LOCAL a := Array(n)` ou `{...}` | Arrays dinâmicos |
| `@..GET..PICT..VALID` + `READ` | `@..GET..PICTURE..VALID` + `READ` (compatível) ou `Get`/`GetList` | Compatível; validações reforçadas |
| `MEMOEDIT()` | `MEMOEDIT()` | Compatível |
| `DBEDIT()` | `DBEDIT()` (compat.) ou `TBrowseDB()` | `TBrowse` é o caminho moderno |
| `ACHOICE()` | `ACHOICE()` (compat.) | Compatível |
| `SAVE TO .MEM` | tabela `sequencia` no SQLite | Persistência transacional |
| `CANCEL` / `QUIT` | `RETURN` + código de saída | Briefing §18 |
| Sem tratamento de erro | `BEGIN SEQUENCE` / `ERRORBLOCK()` / `TRY-CATCH` | Briefing §18 |
| Sem transação | `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` | Briefing §17 |
| Sem locking | conexão SQLite + WAL | Briefing §16 |
