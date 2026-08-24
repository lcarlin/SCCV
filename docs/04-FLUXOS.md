# 04 — FLUXOS FUNCIONAIS

## 1. Fluxo de inicialização

```
 (operador)
     │
     ├─► CVTEABE.EXE ─── detecta adaptador gráfico (CLBC: tenta 25, 20, 21)
     │        │              └─ nenhum compatível → mensagem + QUIT
     │        └── exibe CVTEABE.PCX por 2 s (INKEY(2)) → BC_FIM(0)
     │
     └─► SCCV.EXE
              │
              ├─ SETs globais (DATE BRIT, DELETED ON, teclas F1/F2/ALT+X)
              ├─ verifica e recria 16 índices .NTX ausentes          (RN-039)
              ├─ cria CVMGRUPO.MEM com MCODGRU=0 se ausente          (RN-013)
              ├─ declara PUBLICs (códigos de impressora, estado)
              ├─ pinta moldura 80×25 + título + rodapé de teclas
              └─► LAÇO DO MENU PRINCIPAL
```

> **Nota:** não há script/batch no diretório que encadeie `CVTEABE.EXE` → `SCCV.EXE`. O encadeamento é presumido (`.BAT` ausente).

---

## 2. Navegação do menu principal

```
 Linha 2:  [Clientes] [Funcionários] [Fornecedores] [Serviços] [Estoques]
              mov=0        mov=1          mov=2        mov=3      mov=4
              cl=1         cl=17          cl=33        cl=49      cl=63

 Teclas:  →  (LASTKEY 4)   mov+1, cl+16 ; se mov>4 → mov=0, cl=1
          ←  (LASTKEY 19)  mov-1, cl-16 ; se mov<0 → mov=4, cl=65
          ↓ / ENTER        abre o submenu do grupo corrente (ACHOICE)
          ALT+X (-9 / 301) SAIDA()
          F1               DISKSPACE()
          F2               CONSORCALC()
```

O submenu é desenhado por `BORDA()` + `ACHOICE()` com callback `FUNAC()`:

| `FUNAC` modo | Situação | Retorno |
|---|---|---|
| 0 | item inválido | 2 (aborta) |
| 1 | cursor no topo, ↑ | injeta `CHR(30)` e retorna 2 |
| 2 | cursor no fim, ↓ | injeta `CHR(31)` e retorna 2 |
| 3 | tecla não tratada | ESC→2 ; ENTER→1 ; →/←→0 (sai e deixa o menu principal mover) ; ALT+X→`SAIDA()` |
| 4 | item selecionado | 0 |

**Efeito:** as setas ← → dentro do submenu **fecham** o submenu e movem o menu horizontal — a navegação é contínua entre os 5 grupos.

---

## 3. Mapa completo de destinos

```
Clientes ─┬─ 1 Manutenção ──► CVMTCLI  ──(CONSOR="S")──► CVMTCON ──► CVMTCLI (recursão)
          ├─ 2 Consulta   ──► CVCONCLI
          └─ 3 Relatório  ──► CVRCLI

Funcionários ─┬─ 1 Manutenção ──► CVMTFUNC
              ├─ 2 Consulta   ──► CVCONFUN
              └─ 3 Relatório  ──► CVRFUNC

Fornecedores ─┬─ 1 Manutenção ──► CVMTFOR (+ memo via OBSER/MEMOEDIT)
              ├─ 2 Consulta   ──► CVCONFOR
              └─ 3 Relatório  ──► CVRFOR

Serviços ─┬─ 1 Venda Peças  ──► CVMTVPEC ──(cliente novo)──► CVMTCLI
          ├─ 2 Reparos      ──► CVMTVREP ──(cliente novo)──► CVMTCLI
          ├─ 3 Consórcios   ──► CVMTCON2
          ├─ 4 Pronta Entr  ──► CVMTPENT
          └─ 5 Relatório    ──► CVRSERV ─┬─ 1 Vendas de Pecas → VEN_PEC()
                                         ├─ 2 Reparos        → REP()
                                         ├─ 3 Consorcios     → CONS()
                                         └─ 4 Pronta Entrega → PRON_ENTR()

Estoques ─┬─ 1 Peças        ──► CVMTPEC
          ├─ 2 Almoxarifado ──► CVMTALMX
          ├─ 3 Frota        ──► CVMTFRO
          ├─ 4 Relatório    ──► CVREST ─┬─ 1 Pecas       → CVRPECAS
          │                             ├─ 2 Amoxarifado → CVRALM
          │                             └─ 3 Frota       → CVRFROTA
          └─ 5 Gráficos     ──► MENU ─┬─ 1 Frota → CVGRAFRO (pizza CLBC/GIP)
                                      └─ 2 Pecas → CVGRAPEC (pizza CLBC/GIP)
```

**18 destinos funcionais.**

---

## 4. Fluxo canônico de manutenção (aplica-se a 7 módulos)

```
┌─ DO WHILE .T. ───────────────────────────────────────────────────┐
│                                                                  │
│  USE <tabela> INDEX <indice> ; GOTO TOP                          │
│  TELA(n)                        ← desenha rótulos                │
│  inicializa M<campos> em branco/zero                             │
│                                                                  │
│  @ .. GET M<codigo> PICT "99999" ; READ                          │
│         │                                                        │
│         ├─ vazio + ENTER  ──► TABELA()  [browse DBEDIT/FUNDB]    │
│         │                        ├─ ENTER → M<cod> = campo       │
│         │                        └─ ESC   → LOOP                 │
│         └─ vazio + ESC    ──► CLOSE DATABASES ; RETURN           │
│                                                                  │
│  SEEK M<codigo>                                                  │
│    │                                                             │
│    ├─ .NOT. FOUND()  ────────────► [INCLUSÃO]                    │
│    │     CONFIRMA "Codigo novo! Deseja cadastrar"                │
│    │        ├─ N → LOOP                                          │
│    │        └─ S → GETs em branco ; READ                         │
│    │              CONFIRMA "Os dados estao corretos"             │
│    │                 ├─ N → LOOP                                 │
│    │                 └─ S → APPEND BLANK                         │
│    │                                                             │
│    └─ FOUND()  ──────────────────► [CONSULTA/ALTERAÇÃO/EXCLUSÃO] │
│          carrega M<campos> ← campos do registro                  │
│          exibe GETs ; CLEAR GETS (somente leitura)               │
│          GET ALTER VALID $"ARE"  (default "R")                   │
│             ├─ "R" → LOOP                                        │
│             ├─ "E" → CONFIRMA "Confirma exclusao" → DELETE       │
│             └─ "A" → DO WHILE .T.                                │
│                        GETs editáveis ; READ                     │
│                        CONFIRMA "Os dados estao corretos"        │
│                           ├─ S → EXIT                            │
│                           └─ N → LIMPA() ; repete                │
│                                                                  │
│  REPLACE <campo1> WITH M<campo1>      ◄── FORA do IF (RN-009)    │
│  REPLACE <campo2> WITH M<campo2>          executa em TODOS os    │
│  ...                                       caminhos, inclusive   │
│                                            após "R" e após "E"   │
│                                                                  │
│  CONFIRMA "Deseja continuar"                                     │
│     ├─ S → LIMPA() ; volta ao topo do laço                       │
│     └─ N → CLOSE DATABASES ; RETURN                              │
└──────────────────────────────────────────────────────────────────┘
```

Variações por módulo:

| Módulo | Diferença |
|---|---|
| `CVMTCLI` | + `DO CVMTCON` quando `CONSOR="S"` (RN-011) |
| `CVMTFOR` | + `GET V_OBS $"SN"` → `OBSER(.T.,"obsfor")` (memo); `REPLACE OBSFOR` condicional a `V_OBS="S"` |
| `CVMTPEC` | 2 work areas; sub-laço de validação do fornecedor com `SEEK` em `CVBFORNE`; **defeito RN-036** |
| `CVMTALMX` | idem `CVMTPEC`; + `REINDEX` na abertura das duas tabelas |
| `CVMTFRO` | + cálculo `CHASDO = CHASSI + QUANTCAR` com segundo `READ` (RN-037) |

---

## 5. Fluxo: Venda de peças (balcão) — `CVMTVPEC`

```
DO WHILE .T.                                        ← laço externo (por cliente)
 │
 ├ TELA(15) ; USE CVBCLIEN INDEX CVICLI1
 ├ GET MCODCLI ; READ                    [ENTER vazio → TABELA() ; ESC vazio → sai]
 ├ SEEK MCODCLI
 │   └ .NOT.FOUND → CONFIRMA "Deseja Cadastra-lo" ─┬ S → DO CVMTCLI  ⚠ sem reposicionar
 │                                                 └ N → LOOP
 ├ MNOMCLI = NOMCLI ; SAVE SCREEN TO CLI
 ├ MTOTALC = 0
 │
 └ DO WHILE .T.                                     ← laço interno (por item)
    │
    ├ TELA(15) ; RESTORE SCREEN FROM CLI
    ├ USE CVBPECAS INDEX CVIPEC1
    ├ GET MCODPEC ; READ                 [ENTER vazio → TABELA() ; ESC vazio → sai]
    ├ SEEK MCODPEC
    │   └ .NOT.FOUND → MENSAGEM "Codigo nao Cadastrado" ; WAIT ; LOOP
    │
    ├ exibe DECPEC, QTDPEC, VALUNI, QTDMIN  (somente leitura)
    ├ GET MQTVEND ; READ
    ├ MSUBTOT = MVALUNI * MQTVEND                             (RN-026)
    ├ MTOTALC = MTOTALC + MSUBTOT
    │
    ├ IF MQTVEND > (MQTDPEC - MQTDMIN)                        (RN-028)
    │     CONFIRMA " [ERRO] Estouro do Estoque Minimo; Continuo "
    │        └ N → LOOP  (descarta o item; MTOTALC JÁ FOI SOMADO ⚠)
    │
    ├ USE CVBFUNC INDEX CVIFUN1
    ├ GET MCODFUN ; READ ; SEEK MCODFUN
    │   └ .NOT.FOUND → MENSAGEM "Funcionario nao Cadastrado" ; WAIT ; LOOP
    ├ MNOMFUN = NOMFUN
    │
    ├ USE CVBFUNC INDEX CVIFUN1          ⚠ reabre: perde o posicionamento
    ├ REPLACE COMFUN WITH COMFUN+(MCODFUN*0.2)                (RN-030, defeituosa)
    │
    ├ USE CVBPECAS INDEX CVIPEC1         ⚠ reabre: perde o posicionamento
    ├ REPLACE QTDPEC WITH MQTDPEC-MQTVEND                     (RN-029)
    │
    ├ USE CVPECAS INDEX CVIVPEC1
    ├ CONFIRMA "Dados Estao Corretos"
    │   └ S → APPEND BLANK
    │         REPLACE CODPEC, DECPEC, QTPECC, NOMCLI, CODCLI, SUBTOT
    │         USE CVVPEC INDEX CVIGRAP1 ; SEEK MDECPEC        (RN-020 agregado)
    │            ├ .NOT.FOUND → APPEND BLANK ; DESPEC=MDECPEC ; QUANTC=MQTVEND
    │            └ FOUND      → QUANTC = QUANTC + MQTVEND
    │         USE CVPECAS INDEX CVIVPEC1
    │
    ├ CONFIRMA "Continua cadastrando pecas"
    │   └ S → CLEAR ; LOOP  (próximo item)
    │
    └ N → REPLACE VALTOT WITH MTOTALC       ⚠ só no ÚLTIMO registro (RN-027)
          SET FILTER TO CODCLI=MCODCLI ; GO TOP
          DBEDIT(...)  ← exibe os itens do cliente
          RETURN                            ⚠ sai do módulo, não do laço externo
```

**Observações de fluxo:**
1. O `RETURN` final encerra o módulo inteiro — o laço externo "por cliente" nunca dá uma segunda volta.
2. Se o operador cancela um item pelo estouro de estoque mínimo, `MTOTALC` **já foi somado** e não é revertido.
3. Não há transação: em caso de interrupção entre a baixa de estoque e o `APPEND`, o estoque fica baixado sem venda registrada.

---

## 6. Fluxo: Reparos de autos — `CVMTVREP`

```
DO WHILE .T.
 ├ TELA(11)
 ├ USE CVBCLIEN ; GET MCODCLI ; SEEK  → [não achou: oferece DO CVMTCLI]
 ├ USE CVBFUNC  ; GET MCODFUN ; SEEK  → [não achou: MENSAGEM + LOOP]
 ├ REPLACE COMFUN WITH COMFUN+(MCODFUN*0.2)     (RN-030, defeituosa)
 ├ LIN = 15 ; MTOTAL = 0 ; SCROLL = .F.
 │
 └ DO WHILE .T.                                  ← grade de itens (linhas 15..18)
    ├ USE CVBPECAS INDEX CVIVPEC1                ⚠ índice de CVPECAS aplicado a CVBPECAS
    ├ se LIN >= 19 → SCROLL(15,1,18,78,1) ; LIN = 18
    ├ GET MCODPEC na linha LIN ; READ ; SEEK
    │   └ .NOT.FOUND → MENSAGEM "Peca nao Cadastrada" ; WAIT ; LOOP
    ├ exibe MDECPEC ; GET MQUANTC ; READ
    ├ MSUBTOT = MVALUNI * MQUANTC ; MTOTAL = MTOTAL + MSUBTOT
    ├ USE CVPECAS INDEX CVIPEC1                  ⚠ índice de CVBPECAS aplicado a CVPECAS
    ├ CONFIRMA "Dados Estao Corretos "
    │   ├ N → conf = .F. ; LOOP  (repete a mesma linha, sem rolar)
    │   └ S → USE CVVPEC INDEX CVIGRAP1 ; REINDEX ; SEEK MDECPEC
    │         ├ .NOT.FOUND → APPEND ; DECPEC=MDECPEC ; QUANTC = MQTVEND  ⚠ variável errada
    │         └ FOUND      → QUANTC = QUANTC + MQTVEND                   ⚠ variável errada
    │
    │         CONFIRMA "Continua Cadastrando Pecas "
    │           ├ N → APPEND BLANK ; grava item COM VALTOT=MTOTAL ; RETURN
    │           └ S → APPEND BLANK ; grava item SEM VALTOT
    └ LIN = LIN + 1
```

**Diferenças relevantes vs. venda de balcão:**
- **Não baixa estoque de peças** (RN-029, lacuna).
- **Não alerta estoque mínimo** (RN-028, lacuna).
- Usa `MQTVEND` (nunca atribuída neste módulo) ao atualizar `CVVPEC` — a variável correta é `MQUANTC`. Em Clipper Summer '87 uma variável não declarada em expressão gera erro de runtime; se `MQTVEND` sobreviver de uma execução anterior de `CVMTVPEC` (variável `PRIVATE` do escopo pai), grava valor de outra venda.
- Aplica índices trocados às duas tabelas de peças.
- Escreve em `CVPECAS` os mesmos campos da venda de balcão, **sem discriminador de origem** — daí a questão Q-02.

---

## 7. Fluxo: Pronta entrega de veículos — `CVMTPENT`

```
DO WHILE .T.
 ├ TELA(13)
 ├ USE CVBCLIEN ; GET MCODCLI ; SEEK
 │   └ .NOT.FOUND → MENSAGEM "Cliente nao Cadastrado; Deseja Cadastra-lo" ; LOOP  (RN-025)
 ├ MNOMCLI = NOMCLI
 ├ USE CVBFROTA INDEX CVIFRO1 ; GET MCODCAR ; SEEK
 │   └ .NOT.FOUND → MENSAGEM "Carro nao Cadastrado" ; WAIT ; LOOP
 ├ MVALCAR = VALCAR ; MDESCAR = DESCAR   (snapshot)
 ├ USE CVBFUNC ; GET MCODFUN ; SEEK
 │   └ .NOT.FOUND → MENSAGEM "Funcionario nao Cadastrado" ; WAIT ; LOOP
 ├ MNOMFUN = NOMFUN
 │
 ├ USE CVBFUNC INDEX CVIFUN1      ⚠ reabre → posiciona no PRIMEIRO registro
 ├ MCOMFUN = COMFUN + (MVALCAR * 0.015)   ← lê comissão do registro ERRADO  (RN-031)
 ├ USE CVBFROTA INDEX CVIFRO1     ⚠ reabre → posiciona no PRIMEIRO registro
 ├ MQUANCAR = QUANTCAR - 1                ← lê estoque do registro ERRADO   (RN-034)
 ├ USE CVBPENT INDEX CVIPENT1
 ├ GET MDATA PICT "99/99/99"      ⚠ sem READ — o GET nunca é lido!
 │
 └ CONFIRMA "Dados Estao Corretos"
     └ S → APPEND BLANK em CVBPENT
           REPLACE CODCAR, DESCAR, VALCAR, CODFUN, NOMFUN, CODCLI, NOMCLI, DATAV
           USE CVBFROTA ; REPLACE QUANTCAR WITH MQUANCAR   ← grava no registro ERRADO
           USE CVVCAR INDEX CVIGRAC1 ; SEEK MDESCAR             (RN-019 agregado)
              ├ .NOT.FOUND → APPEND ; DESCAR=MDESCAR ; QUANTV=1
              └ FOUND      → QUANTV = QUANTV + 1
           IF MQUANCAR = 0 → MENSAGEM "ULTIMO CARRO SENDO VENDIDO"   (RN-035)
           USE CVBFUNC ; REPLACE COMFUN WITH MCOMFUN       ← grava no registro ERRADO
     └ (implícito) N → não grava nada, mas o estoque já foi calculado
   CONFIRMA "Deseja continuar" → N: CLOSE DATABASES ; RETURN
```

**Defeitos de fluxo confirmados pelos dados:**
- `@ 15,29 GET MDATA` **sem `READ`** → `DATAV` recebe sempre a data em branco resultante de `CTOD("  /  /  ")`. Os dados mostram, no entanto, `DATAV` preenchida na maioria dos registros — provavelmente porque `MDATA` sobrevive do escopo `PRIVATE` de execuções anteriores, ou porque o `READ` do `CONFIRMA` seguinte consome o `GET` pendente (comportamento do `GetList` do Clipper). **Registros 9 e 14 têm `DATAV` = 1901-11-11 e 1901-01-01**, compatíveis com lixo.
- `COMFUN` do funcionário 1 (ALETHEIA KARINA) = 1.500,80, muito acima dos demais — consistente com todas as comissões de pronta entrega sendo creditadas ao primeiro registro.

---

## 8. Fluxo: Consórcio — adesão (`CVMTCON`)

```
CVMTCON(MCODCON, MNOMCON)                    ← recebe do CVMTCLI
 ├ áreas: 1=CVBGRUPO/CVIGRU1  2=CVBFROTA/CVIFRO1  3=CVBGRUCO  4=CVBFUNC/CVIFUN1
 ├ TELA(12)
 ├ exibe código e nome do consorciado (somente leitura)
 ├ SELE 2 ; GET MCODCAR ; READ  [ESC → RETURN ; ENTER vazio → TABELA()]
 ├ SEEK MCODCAR → .NOT.FOUND: MENSAGEM "Carro näo Cadastrado" ; RETURN
 ├ MCARMOD = DESCAR ; MVALPRE = VALCAR                      (RN-016)
 │
 ├ SELE 1 ; SEEK MCODCAR              ← existe grupo em formação para este modelo?
 │   ├ .NOT.FOUND ─► [GRUPO NOVO]
 │   │    RESTORE FROM cvmgrupo ADDITIVE ; MCODGRU = MCODGRU + 1   (RN-013)
 │   │    MNUMPAR=0 ; MNUMMES=0 ; MVALPRE=0 ; MDATCON=DATE()
 │   │    MGRUFEC=.F. ; MNUPGRU=1
 │   │    GET MCODGRU (só leitura) ; GET MNUMPAR ; GET MVALPRE ; READ
 │   │    MNUMMES = MNUMPAR  (RN-017) ; GET MNUMMES (só leitura)
 │   │    GET MDATCON ; READ ; GET MNUPGRU (só leitura)
 │   │    SAVE TO cvmgrupo ALL LIKE mcodgru      ⚠ consome o nº antes de confirmar
 │   │
 │   └ FOUND ─► [GRUPO EXISTENTE]                            (RN-014)
 │        herda NUMPAR, CODGRU, NUMMES, VALPRE, DATCON
 │        COUNT ALL FOR mcodgru=codgru TO MNUPGRU ; MNUPGRU+1 (RN-015)
 │        todos os campos exibidos somente leitura
 │
 ├ SELE 4 ; COMISS = MVALPRE * 0.0015                        (RN-032)
 ├ DO WHILE EMPTY(MCODFUN)
 │     GET MCODFUN ; READ  [ENTER vazio → TABELA()]
 │     SEEK MCODFUN → .NOT.FOUND: MENSAGEM ; LIMPA ; LOOP
 │     REPLACE COMFUN WITH COMFUN + COMISS
 │  ⚠ o laço "DO WHILE EMPTY(MCODFUN)" não tem saída se o operador insistir em vazio
 │
 ├ SELE 1 ; CONFIRMA "Cadastrar Consorciado"
 │    └ N → RETURN   ⚠ mas a comissão JÁ foi gravada e o nº de grupo JÁ foi consumido
 │
 ├ APPEND BLANK ; REPLACE CODCON, NOMCON, CODCAR, CODGRU, VALPRE,
 │                        GRUFEC, NUMPAR, NUMMES, DATCON, NUPGRU
 │                (NUMPAG e NUMGRU: REPLACE comentados — Q-06)
 │
 ├ COUNT ALL FOR codgru = mcodgru TO TOTPAN
 └ IF TOTPAN >= MNUMPAR ─► [FECHAMENTO DO GRUPO]             (RN-018)
      MENSAGEM "Aguarde!!! Grupo Fechado Transferindo dados..."
      DECLARE grfec[TOTPAN] ; SET FILTER TO codgru=mcodgru ; GO TOP
      for i = 1 to TOTPAN : grfec[i] = RECNO() ; SKIP : next
      for k = 1 to TOTPAN
          SELE 1 ; GO grfec[k] ; lê os 11 campos ; DELE
          SELE 3 ; APPEND BLANK ; REPLACE (11 campos) com GRUFEC = .T.
      next
      SET FILTER TO
   │
   └ DO CVMTCLI     ⚠ recursão mútua (RN-012)
```

---

## 9. Fluxo: Consórcio — baixa de prestações e sorteio (`CVMTCON2`)

```
 ├ áreas: 1=CVBGRUCO/CVIGRUC1  2=CVBFROTA/CVIFRO1  3=CVBPEDID
 ├ TELA(18)
 ├ GET MCODCON ; READ  [ENTER vazio → TABELA()]
 │    ⚠ ao voltar da TABELA(), o GET é reposicionado em @10,38 (deveria ser @08,38)
 ├ SEEK MCODCON → .NOT.FOUND: MENSAGEM "Consorciado näo Cadastrado" ; RETURN
 ├ carrega NOMCON, CODCAR, CODGRU, NUMMES, DATCON, VALPRE, NUMPAG, SORT
 ├ converte SORT lógico → "S"/"N"
 ├ exibe nome, carro, grupo (somente leitura)
 │
 ├ GET MNUMFALA ("Num. prest. a serem pagas") ; READ
 ├ MNUMFAL = MNUMMES - MNUMFALA ; REPLACE NUMMES WITH MNUMFAL     (RN-020)
 │    ⚠ sem piso em zero → saldo negativo → overflow em N(2,0)
 ├ NUM = RECNO()
 ├ IF MNUMFAL = 0 → MENSAGEM "Todas As prestacoes ja quitadas" ; REPLACE QUIT=.T.  (RN-021)
 │
 ├ GET MSORT VALID $"SN" ; READ ; REPLACE SORT WITH .T./.F.       (RN-022)
 │
 └ IF MSORT = "S"                                                  (RN-023)
      SELE 2 ; SEEK MCODCAR ; MQTACAR = QUANTCAR
      ├ IF MQTACAR = 0 → aviso "Quantidade esgotada!!; Aguarde ~10 dias" ; RETURN
      └ MQTACAR = MQTACAR - 1 ; REPLACE QUANTCAR WITH MQTACAR
        SELE 1 ; GO NUM        ← restaura o posicionamento
   RETURN
```

> A área 3 (`CVBPEDID`) é aberta e nunca usada.

---

## 10. Fluxo de consulta (3 módulos)

```
 USE <tabela> INDEX <indice> ; SAVE SCREEN
 │
 ├ MENU_CON(l,c) ─┬ 0 (ESC) → RESTORE SCREEN ; RETURN
 │                ├ 1 "Geral"      → sem posicionamento
 │                └ 2 "Por codigo" → BORDA + GET Mcod + SEEK
 │                                    └ .NOT.FOUND → MENSAGEM ; INKEY(2) ; RETURN
 │
 ├ DECLARE VCAB[n]  ← rótulos das colunas
 ├ BORDA(...) ; DBEDIT(l1,c1,l2,c2, .T., "FUNDBCON", .T., VCAB, .T.,.T.,.T.)
 │       ⚠ o 5º parâmetro deveria ser a lista de campos; passar .T. faz o DBEDIT
 │         exibir TODOS os campos na ordem física
 │
 │  FUNDBCON():
 │    ├ modo 3 (arquivo vazio)  → MENSAGEM "Arquivo Vazio" ; INKEY(3) ; retorna 0
 │    ├ modo 4 + F3 (-3)        → BORDA + GET PESQ + SEEK  → não achou: MENSAGEM
 │    ├ modo 4 + ENTER          → se o campo é memo, abre OBSER() em leitura
 │    ├ modo 4 + ESC            → retorna 0 (encerra o browse)
 │    └ modo 4 + tecla 48..128  → retorna 1 (ignora)
 │
 └ RESTORE SCREEN
```

O modo "Por codigo" apenas **posiciona** o browse — não filtra. O operador continua livre para navegar por todo o arquivo.

---

## 11. Fluxo de relatório (padrão de 8 módulos)

```
 SAVE SCREEN ; USE <tabela> INDEX <indice> ; GO TOP
 │
 ├ [somente CVRCLI] MENU: Consorciados / Clientes / Ambos → SET FILTER  (RN-040)
 │
 ├ OPREL(l,c) → MENU: "TELA" / "IMPRESSORA" / " ETIQUETA "
 │   ├ 0 ou 4 (ESC)  → CLOSE DATABASES ; RESTORE SCREEN ; RETURN
 │   ├ 1 TELA        → NL = 21 (ou 23 em CVRFOR) ; telimp = .F. ; CLEAR
 │   ├ 2 IMPRESSORA  → IF .NOT. ISPRINTER() → MENSAGEM "VERIFIQUE A IMPRESSORA"
 │   │                 IF .NOT. ISPRINTER() → aborta
 │   │                 telimp = .T. ; NL = 60 ; SET DEVICE TO PRINTER ; SET CONSOLE OFF
 │   └ 3 ETIQUETA    → DO WHILE .NOT. ISPRINTER(): aviso ; ESC sai
 │                     LABEL FORM <ETIQxxx> TO PRINT    ⚠ arquivo .LBL AUSENTE
 │
 ├ PUBLIC PG ; PG = 0 ; L = 8   (L = 10 nos sub-relatórios de CVRSERV)
 ├ cabeçalho: telimp ? CABER(empresa, titulo, telimp) : REL(titulo)
 │            + RG(<sigla>)   ← rótulos de coluna
 │
 └ DO WHILE .NOT. EOF()
      @ L, col SAY <campo> ... (3 a 7 colunas por relatório)
      L = L + 1 ; SKIP
      IF L >= NL
         PG = PG + 1
         IF NL = 21 → MENSAGEM(" ",24)  [pausa]  ; CLEAR (nem sempre) ; L = 8
         reimprime cabeçalho
      ENDIF
   ENDDO
   SET DEVICE TO SCREEN ; MENSAGEM("Final da Listagem ",24) ; RESTORE SCREEN
```

---

## 12. Fluxo de encerramento (`SAIDA`)

```
 ALT+X (em qualquer ponto, via SET KEY 301)
   │
   ├ SAVE SCREEN ; BORDA(7,19,9,50) ; TONE(250,1)
   ├ GET conf VALID $"SN"  "Deseja Realmente Sair <S/N>"
   │
   ├ "N" → RESTORE SCREEN ; RETURN  (volta ao ponto de origem)
   │
   └ "S" → tela "Reorganizando Arquivos, Aguarde !!!"
           barra de progresso ░ → ▓  (0% .. 103%)
           │
           ├ CVBFROTA : REINDEX
           ├ CVBCLIEN : PACK + REINDEX      ← EXCLUSÃO FÍSICA
           ├ CVALMOX  : REINDEX
           ├ CVBFORNE : PACK + REINDEX      ← EXCLUSÃO FÍSICA
           ├ CVBPECAS : REINDEX
           ├ CVBFUNC  : PACK + REINDEX      ← EXCLUSÃO FÍSICA
           ├ CVBGRUCO : REINDEX
           ├ CVBGRUPO : REINDEX
           ├ CVPECAS  : REINDEX com CVIPEC1   ⚠ índice de outra tabela
           ├ CVBPECAS : REINDEX com CVIVPEC1  ⚠ índice de outra tabela
           ├ CVBGRUPO : REINDEX com CVIGRU2
           │
           ├ "Reorganizacao Completa !!!"
           └ CLEAR ALL ; BC_FIM(0) ; CANCEL
```

**Nenhum backup é feito antes do `PACK`.** Um `PACK` interrompido corrompe o arquivo.

---

## 13. Mapa de mensagens ao usuário

| Mensagem | Origem | Tipo |
|---|---|---|
| `Deseja Realmente Sair <S/N>` | `SAIDA()` | Confirmação |
| `Reorganizando Arquivos, Aguarde !!!` | `SAIDA()` | Progresso |
| `Reorganizacao Completa !!!` | `SAIDA()` | Informativa |
| `Espaco de Disco==><n>` | `DISKSPACE()` (F1) | Informativa |
| `Codigo novo! Deseja cadastrar` | 7 módulos | Confirmação |
| `Os dados estao corretos ` | 8 módulos | Confirmação |
| `Deseja continuar` | 7 módulos | Confirmação |
| `Confirma exclusao` | 7 módulos | Confirmação |
| `<X> ja cadastrado <A>ltera; <R>etorna; <E>xclui` | 7 módulos | Escolha |
| `Codigo Nao Cadastrado ` | `FUNDBCON`, `CVCONCLI`, `CVCONFOR`, `CVCONFUN` | Erro |
| `Codigo nao cadastrado` | `CVMTPEC`, `CVMTALMX` (fornecedor) | Erro |
| `Codigo nao Cadastrado; Tecle <ENTER> ` | `CVMTVPEC` (peça) | Erro |
| `Peca nao Cadastrada; Tecle <ENTER> ` | `CVMTVREP` | Erro |
| `Funcionario nao Cadastrado; Tecle <ENTER> ` | `CVMTVPEC`, `CVMTVREP`, `CVMTPENT` | Erro |
| `Funcionario nao Cadastrado` | `CVMTCON`, `CVMCOM` | Erro |
| `Carro nao Cadastrado; Tecle <ENTER> ` | `CVMTPENT` | Erro |
| `Carro näo Cadastrado` | `CVMTCON`, `CVMCOM` | Erro |
| `Cliente nao Cadastrado; Deseja Cadastra-lo ` | `CVMTVPEC`, `CVMTVREP` (confirm.) / `CVMTPENT` (só aviso) | Misto |
| `Consorciado näo Cadastrado` | `CVMTCON2` | Erro |
| `Cadastrar Consorciado` | `CVMTCON` | Confirmação |
| `Aguarde!!! Grupo Fechado Transferindo dados...` | `CVMTCON` | Progresso |
| `Todas As prestacoes ja quitadas` | `CVMTCON2` | Informativa |
| `Quantidade esgotada!!; Aguarde aproximadamente 10 dias pelo carro` | `CVMTCON2` | Bloqueio |
| ` [ERRO] Estouro do Estoque Minimo; Continuo ` | `CVMTVPEC` | Confirmação |
| `ATENCAO: ULTIMO CARRO SENDO VENDIDO; Tecle <ENTER>` | `CVMTPENT` | Alerta |
| `Arquivo Vazio ` | `FUNDBCON` | Informativa |
| `VERIFIQUE A IMPRESSORA` | 6 relatórios | Erro |
| `Impressora nao Preparada; [ENTER] p/ Continuar ou [ESC] P/ Sair` | 7 relatórios | Bloqueio |
| `Final da Listagem ` | 8 relatórios | Informativa |
| `Codigo ja existente` | `CVMTPED` (inoperante) | Erro |
| `Adaptadores Graficos nao Compativeis; SCCV no Modo Grafico nao Pode Ser Ativado` | `CVTEABE` | Fatal |
| `Digite EXIT Para Retornar ao SCCV...` | `DOS()` (morta) | Informativa |
| `^W Grava; ^Y Apaga Linha; <ESC> Sai` | `OBSER()` edição | Ajuda |
| `<ESC> - Retorna` | `OBSER()` leitura | Ajuda |
| `<Esc>-Retorna <ENTER>-Tabela de Codigos` | `MENS` (todas as telas) | Ajuda |
| `<ESC>-Retorna ; <ENTER>-Tabela de codigos` | `MEN_T_12` | Ajuda |
| `<F1>-Espaco de Disco  <F2>-Calculadora  <ALT>+<X>-Sair` | `SCCV` rodapé | Ajuda |

**Total: 38 mensagens distintas.** Sufixo automático de `MENSAGEM()`: `"! Pressione algo para continuar..."`. Sufixo de `CONFIRMA()`: `" (S/N)?"`.
