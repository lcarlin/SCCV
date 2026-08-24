# 07 — DEPENDÊNCIAS

## 1. Dependências externas de biblioteca

### 1.1 CLBC 2.7 — SoftCAD Informática (1992)

Biblioteca gráfica comercial brasileira para Clipper. **Não está presente no diretório** — foi linkada estaticamente em `SCCV.EXE` e `CVTEABE.EXE`.

**35 funções utilizadas:**

| Grupo | Funções | Usada em |
|---|---|---|
| Contexto | `BC_INIC`, `BC_FIM`, `BC_CPLACA`, `BC_INICTR`, `BC_CNCOR` | `SCCV`(saída), `CVTEABE`, gráficos |
| Vídeo | `BC_JANVD`, `BC_VIUPVD`, `BC_ARQVD` | `INICIA`, `CVTEABE` |
| Cursor/mouse | `BC_DCUR`, `BC_DELAST`, `BC_POSLOC`, `BC_REACUR`, `BC_DISLOC`, `BC_DUTLOC` | `INICIA`, `DEFINE` |
| Desenho | `BC_DRETAN`, `BC_RETANG`, `BC_DCIRC`, `BC_CIRCUN`, `BC_DPMAR`, `BC_PMARCA`, `BC_DPLIN`, `BC_PLINHA`, `BC_DELIP`, `BC_ELIPSE` | `DESARQ` |
| Gráfico | `BC_GDABJA`, `BC_GDTITU`, `BC_GDIDEN`, `BC_GABJAN`, `BC_GPIZZA`, `BC_GFEJAN` | `CVGRAFRO`, `CVGRAPEC`, `SEMNOME` |
| Fonte | `BC_FONTEM`, `BC_LIBFM` | gráficos |

**Arquivos de apoio ausentes:** `8X8.BCM` (fonte bitmap), `LASER.OBJ` (efeito laser, já desabilitado no fonte).

**Utilitários presentes:** `BCVGA.EXE` e `BCRETCTR.EXE` (~7,5 KB cada) — drivers/configuradores da CLBC.

### 1.2 GIP 1.0 — gerador de gráficos

Complemento da CLBC. **3 funções:** `GIP_ERRO(n)` (mensagem de erro), `GIP_LCOR(n)` (mapeia índice → cor do modo gráfico), `GIP_PAD(vetor, n)` (preenche vetor de padrões de hachura).

Os cabeçalhos de `CVGRAPEC.PRG` e `SEMNOME.PRG` dizem "Gerado pelo GIP 1.0" — os fontes de gráfico foram **gerados por ferramenta**, não escritos à mão.

### 1.3 Impacto na migração

Ambas as bibliotecas são **DOS-only, 16 bits, proprietárias e indisponíveis**. Não há substituto direto no Linux.

| Funcionalidade | Decisão |
|---|---|
| Splash gráfico (`CVTEABE`) | **Descartar.** Substituir por tela de abertura em caracteres |
| Mouse (`INICIA`, `DEFINE`) | **Descartar.** Código já é morto no legado |
| Desenho vetorial de DBF (`DESARQ`) | **Descartar.** Serve apenas ao splash |
| Gráficos de pizza (R-11, R-12) | **Substituir** por gráfico de barras em caracteres no terminal + exportação CSV. Ver `09-DIVERGENCIAS-MODERNIZACAO.md` (D-22) |

---

## 2. Dependências internas — matriz módulo × tabela

Legenda: **L** = leitura · **G** = gravação (`APPEND`/`REPLACE`) · **D** = exclusão (`DELETE`) · **P** = `PACK` · **R** = `REINDEX`

| Módulo | CLIEN | FUNC | FORNE | PECAS | ALMOX | FROTA | PENT | CVPECAS | GRUPO | GRUCO | VCAR | VPEC | PEDID | REPAR |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `SCCV` (bootstrap) | R | R | R | R | R | R | R | R | R | R | R | R | | R |
| `CVMTCLI` | L G D | | | | | | | | | | | | | |
| `CVMTFUNC` | | L G D | | | | | | | | | | | | |
| `CVMTFOR` | | | L G D | | | | | | | | | | | |
| `CVMTPEC` | | | L | L G D | | | | | | | | | | |
| `CVMTALMX` | | | L R | | L G D R | | | | | | | | | |
| `CVMTFRO` | | | | | | L G D R | | | | | | | | |
| `CVMTVPEC` | L | L **G** | | L **G** | | | | **G** | | | | **G** | | |
| `CVMTVREP` | L | L **G** | | L | | | | **G** | | | | **G** | | |
| `CVMTPENT` | L | L **G** | | | | L **G** | **G** | | | | **G** | | | |
| `CVMTCON` | | L **G** | | | | L | | | L **G** D | **G** | | | | |
| `CVMTCON2` | | | | | | L **G** | | | | L **G** | | | L | |
| `CVCONCLI` | L | | | | | | | | | | | | | |
| `CVCONFUN` | | L | | | | | | | | | | | | |
| `CVCONFOR` | | | L | | | | | | | | | | | |
| `CVRCLI` | L | | | | | | | | | | | | | |
| `CVRFUNC` | | L | | | | | | | | | | | | |
| `CVRFOR` | | | L | | | | | | | | | | | |
| `CVRPECAS` | | | | L | | | | | | | | | | |
| `CVRALM` | | | | | L | | | | | | | | | |
| `CVRFROTA` | | | | | | L | | | | | | | | |
| `CVRSERV` | | | | | | | L | L | | L | | | | |
| `CVREST` | L | | | | | | | | | | | | | |
| `CVGRAFRO` | | | | | | | | | | | L | | | |
| `CVGRAPEC` | | | | | | | | | | | | L | | |
| **`SAIDA()`** | **P** R | **P** R | **P** R | R | R¹ | R | | R | R | R | | | | |

¹ `SAIDA()` reindexa `CVALMOX` (obsoleta), **não** `CVBALMOX`.

### 2.1 Tabelas gravadas por mais de um módulo

| Tabela | Módulos gravadores | Risco |
|---|---|---|
| `CVBFUNC.COMFUN` | `CVMTFUNC`, `CVMTVPEC`, `CVMTVREP`, `CVMTPENT`, `CVMTCON` | **5 gravadores** do mesmo acumulador, todos com `REPLACE` sem lock. `CVMTFUNC` permite editar `COMFUN` manualmente, sobrescrevendo acumulações |
| `CVBPECAS.QTDPEC` | `CVMTPEC` (manual), `CVMTVPEC` (baixa) | Edição manual pode desfazer baixas |
| `CVBFROTA.QUANTCAR` | `CVMTFRO` (manual), `CVMTPENT` (baixa), `CVMTCON2` (sorteio) | 3 gravadores |
| `CVPECAS` | `CVMTVPEC`, `CVMTVREP` | Sem discriminador de origem (Q-02) |
| `CVVPEC` | `CVMTVPEC`, `CVMTVREP` | Agregado atualizado por 2 fontes |
| `CVBGRUPO` | `CVMTCON` (insere e exclui) | — |
| `CVBGRUCO` | `CVMTCON` (insere no fechamento), `CVMTCON2` (atualiza) | — |

### 2.2 Ordem de dependência para implementação

Grafo topológico das tabelas (sem ciclos):

```
Nível 0 (sem FK):        fornecedor · cliente · funcionario · modelo_veiculo
Nível 1 (FK nível 0):    peca · almoxarifado
Nível 2 (FK nível 0/1):  venda_veiculo · consorcio_cota · venda_peca
Nível 3 (FK nível 2):    venda_peca_item
Derivadas (views):       v_venda_por_modelo · v_venda_por_peca
```

---

## 3. Dependências de plataforma

### 3.1 Sistema operacional

| Dependência | Local | Criticidade | Substituição |
|---|---|---|---|
| MS-DOS 16 bits | executáveis | **Bloqueante** | Recompilar em Harbour |
| `!c:\command` | `CV_FUNC.PRG:DOS()` | Baixa (código morto) | Remover |
| Diretório corrente como raiz de dados | todo o sistema | **Alta** | Configuração XDG/`/var/lib` |
| Nomes 8.3 em maiúsculas | todos os arquivos | Média | **Linux é case-sensitive** — ver §3.3 |
| Terminador `^Z` (0x1A) nos fontes | `SCCV.PRG`, `CVTEABE.PRG`, `B.PRG` | Baixa | Remover na conversão |
| Fim de linha CRLF | todos os `.PRG` | Baixa | Converter para LF |
| Codepage CP860 | fontes e dados | **Alta** | Converter para UTF-8 |
| Impressora paralela `PRN`/`LPT1` | 8 relatórios | Média | CUPS ou arquivo |
| Adaptadores VGA/EGA/CGA (CLBC) | splash e gráficos | Baixa | Descartar |
| Driver de mouse DOS INT 33h | `INICIA`, `DEFINE` | Nula (código morto) | Descartar |

### 3.2 Clipper Summer '87 — limitações herdadas

| Limitação | Manifestação | Situação em Harbour |
|---|---|---|
| Sem tipos de dados compostos | Arrays só via `DECLARE` estático | Arrays dinâmicos, hashes, objetos |
| Sem escopo léxico real | `PRIVATE` visível a toda a cadeia de chamadas | `LOCAL`/`STATIC` |
| Macro `&` como único mecanismo de indireção | `TABELA()`/`FUNDB()` (§ Arquitetura 3.2) | Code blocks, funções de primeira classe |
| `SET PROCEDURE TO` (1 arquivo por vez) | `SCCV.PRG` faz 2 `SET PROC` seguidos | Link estático de múltiplos módulos |
| Sem tratamento de exceção | Nenhum `BEGIN SEQUENCE` no sistema | `BEGIN SEQUENCE`/`RECOVER`, `ERRORBLOCK()` |
| Sem transações no RDD | Fechamento de grupo pode ficar pela metade | SQLite `BEGIN`/`COMMIT`/`ROLLBACK` |
| Índices `.NTX` de chave única simples | 16 índices de campo único | Índices compostos e parciais no SQLite |
| Campos numéricos de largura fixa | Overflow grava `*` (`NUMMES` = `**`) | `INTEGER` de 64 bits |
| Data com ano de 2 dígitos + `SET EPOCH` | 12 datas anteriores a 1970 | ISO-8601 com ano de 4 dígitos |
| `SET DELETED ON` implícito | Semântica de exclusão lógica | Coluna `excluido` + *views* |
| Sem locking | Monousuário | Conexão SQLite + WAL |
| Limite de work areas | Máx. 255 (nunca atingido) | Irrelevante |

### 3.3 Case-sensitivity — risco específico do Linux

Os fontes referenciam os mesmos arquivos com caixa inconsistente:

| Referência | Ocorrências |
|---|---|
| `cvialm1.ntx` (minúsculo) vs. `CVIALM1.NTX` (arquivo) | `SCCV.PRG` usa minúsculo |
| `CVIGRAC1.NTX` (maiúsculo) | `CVGRAFRO.PRG:41` — `set index to CVIGRAC1.NTX` |
| `use cvvpec.dbf` vs. `USE CVVPEC INDEX ...` | `CVGRAPEC` vs. `CVMTVPEC` |
| `USE CVBCLIEN INDEX CVIcli1` | `CV_FUNC.PRG:SAIDA()` — caixa mista |

No DOS isso é irrelevante. **No Linux, quebra.** Para a nova implementação a
questão desaparece — o acesso passa a ser por SQLite. Para a **migração**, não:
ela lê os arquivos originais, com os nomes originais.

#### O caso do memo — encontrado na FASE D.1 (2026-08-24)

O problema não está só nos nomes escritos nos fontes. O RDD **DBFNTX deriva
sozinho** o nome do arquivo de memo a partir do nome do `.DBF`, usando a extensão
em **minúsculas** (`.dbt`). O acervo tem `.DBT`. Num sistema de arquivos sensível
a caixa o resultado é `ENOENT`, e os **três únicos DBFs com memo** — `CVBFORNE`,
`CVFORNEC` e `CVREPAR` — falham ao abrir com `Open error`, sem qualquer indício
de que a causa é o memo.

Testado e medido:

| Tentativa | Resultado |
|---|---|
| Abrir `CVBFORNE.DBF` com `.DBT` presente | `Open error` (`os code 2`) |
| `Set( _SET_MFILEEXT, ".DBT" )` | `Open error` — **não resolve** |
| Cópia do `.DBT` como `.dbt` ao lado | abre |
| `Set( _SET_FILECASE, HB_SET_CASE_UPPER )` + `_SET_DIRCASE = MIXED` | **abre, memo lido corretamente** |

Adotado o último: `_SET_FILECASE = UPPER` faz o RDD procurar `.DBT`, e
`_SET_DIRCASE = MIXED` impede que o caminho do diretório (`legacy/`, minúsculo)
também seja convertido. `src/migration/extrator.prg` salva e restaura os dois
valores a cada leitura, para não impor um estado global ao resto da aplicação.
Duplicar os `.DBT` em minúsculas foi descartado: escreveria no acervo, que é
somente leitura.

#### Abertura compartilhada — mesma fase

O extrator lê cada registro duas vezes: o valor tipado pelo RDD e os bytes brutos
do arquivo (ver o cabeçalho de `extrator.prg`). Em modo **exclusivo**, o RDD trava
o arquivo e a leitura bruta em paralelo falha **em silêncio** — `hdrlen` e
`reclen` voltam zerados e todos os valores brutos viram `NIL`, sem erro algum.
`dbUseArea()` é chamado com `lShared = .T.` e `lReadonly = .T.`.

---

## 4. Referências quebradas — inventário completo

| # | Referência | Origem | Tipo | Consequência |
|---|---|---|---|---|
| B-01 | `ETIQCLI.LBL` | `CVRCLI:64`, `CVRSER:59` | arquivo | Erro de runtime na opção Etiqueta |
| B-02 | `ETIQFOR.LBL` | `CVRFOR:41` | arquivo | idem |
| B-03 | `ETIQFUNC.LBL` | `CVRFUNC:42`, `CVRALM:42`, `CVRPECAS:42`, `CVRFROTA:42` | arquivo | idem (4 relatórios) |
| B-04 | `CVIPED1.NTX` | `CVMTPED:9` | índice | Módulo inoperante |
| B-05 | `CVIPES1.NTX` | `CVPECAS:9` | índice | Programa morto |
| B-06 | `CVRVENDAS.PRG` | `CVRSER:17` | programa | Programa morto |
| B-07 | `CVBGRUCON.DBF` | `CVMCOM:12` | tabela | Programa morto |
| B-08 | `CCOR()` | `CVCONCON:14,44` | função | Programa morto |
| B-09 | `TABELAP()` | `CVPECAS:22` | função | Programa morto |
| B-10 | `TABELAF()` | `CVFORN:24` | função | Programa morto |
| B-11 | `AUX_COD` | `CVCLI:26`, `CVCONS:31`, `CVPECAS:23`, `CVFORN:25` | variável | Programas mortos |
| B-12 | `DESENHA_LASER()` / `LASER.OBJ` | `DESARQ:159` | função | Já comentada |
| B-13 | `8X8.BCM` | `CVGRAFRO:120`, `CVGRAPEC:117`, `SEMNOME:116` | fonte bitmap | Gráficos falham |
| B-14 | `MEN_T_5` … `MEN_T_10` | `CVFORN:16` chama `TELA(7)` | procedure | Programa morto |
| B-15 | `MEN_T_18` | `CVMTALM:15` chama `TELA(18)` | procedure | `MEN_T_18` existe, mas é a tela de **consórcio**, não de almoxarifado |
| B-16 | Campos `NUMGRUP`,`NUMPRES`,`DATENT`,`DATFEC`,`VALPRES`,`CODCLI` | `CVRSERV::CONS` | campos | **R-09 inoperante** (relatório ativo!) |
| B-17 | `RG("RE")` | `CVRSERV::CONS` | ramo de função | Sem cabeçalho de coluna |
| B-18 | `CVMGRUPO.MEM` | `CVMTCON:44` | arquivo de estado | Recriado por `SCCV.PRG` se ausente |
| B-19 | `.BAT` de inicialização | — | script | Encadeamento `CVTEABE` → `SCCV` não documentado |

**B-16 é a única referência quebrada em um caminho ativo do menu.** Todas as outras estão em código morto ou em opções secundárias (etiquetas).

---

## 5. Dependências da nova implementação

### 5.1 Obrigatórias

| Dependência | Versão mínima | Papel | Licença |
|---|---|---|---|
| **Harbour** | 3.0.0 (recomendado 3.2 / nightly) | Compilador e runtime | GPL c/ exceção de linking |
| **GCC** ou **Clang** | qualquer versão suportada pelo Harbour | Backend C | GPL / Apache |
| **SQLite** | **3.37.0+** (tabelas `STRICT`) | Motor de banco | Domínio público |
| **GNU Make** | 3.81+ | Build | GPL |
| Terminal com 80×25 mínimo | — | UI | — |

> **Requisito elevado na FASE C.** O schema usa tabelas `STRICT` (SQLite 3.37,
> nov/2021) para obter tipagem realmente aplicada. *Fallback documentado:*
> remover `) STRICT;` do schema reduz o requisito para 3.24+, ao custo de perder
> a checagem de tipo. Ver `database/README.md`.
>
> **Risco RI-02b:** `hbsqlit3` pode linkar contra um SQLite embutido antigo,
> dependendo da build do Harbour. Verificar na FASE F com
> `SELECT sqlite_version();` antes de decidir manter `STRICT`.

### 5.2 Vínculo Harbour ↔ SQLite

Três opções avaliadas:

| Opção | Descrição | Avaliação |
|---|---|---|
| **`hbsqlit3`** | Contribuição oficial em `contrib/hbsqlit3`, binding direto da API C do SQLite | **Recomendada.** Faz parte da árvore do Harbour, expõe `sqlite3_prepare_v2`, `sqlite3_bind_*` e `sqlite3_step` — atende ao requisito de *prepared statements* (briefing §16) |
| `rddsql` + `sddsqlite3` | RDD SQL que emula work areas sobre SQLite | Rejeitada: reintroduz a semântica de work area/`SEEK`/`SKIP` que a modernização pretende eliminar; não expõe transações e *prepared statements* de forma natural |
| `hbcurl`/ODBC | Camada genérica | Rejeitada: dependência externa desnecessária |

**Decisão técnica (não altera regra de negócio):** usar `hbsqlit3`, encapsulado em um módulo `src/database/` que exponha `DbOpen()`, `DbExec()`, `DbQuery()`, `DbBegin()`, `DbCommit()`, `DbRollback()` — nenhum SQL fora dessa camada e de `src/models/`.

### 5.3 Para a ferramenta de migração

A migração precisa **ler DBF/DBT/NTX legados**. Duas alternativas:

| Alternativa | Prós | Contras |
|---|---|---|
| **Harbour com RDD DBFNTX** | Zero dependência extra; lê o formato nativamente; permite validar a leitura contra o próprio motor original | Precisa lidar com CP860 → UTF-8 manualmente (`hb_Translate` ou tabela própria) |
| Python + biblioteca `dbfread` | Rápido de escrever | Introduz dependência de runtime não requerida pelo projeto |

**Decisão técnica:** implementar a migração **em Harbour**, no mesmo binário (`sccv --migrar`) ou em binário separado (`sccv-migrar`). Motivos: (a) o RDD DBFNTX lê o legado com a mesma semântica do sistema original, inclusive `SET DELETED`; (b) elimina dependência externa; (c) o briefing §27 exige build reproduzível — menos dependências, melhor.

Para a **auditoria independente** dos dados migrados (FASE E), scripts Python de conferência podem ser usados como ferramenta de verificação cruzada, sem fazer parte do produto.

### 5.4 Opcionais

| Dependência | Papel | Necessária? |
|---|---|---|
| `sqlite3` (CLI) | Inspeção manual, backup lógico (`.dump`) | Recomendada |
| CUPS (`lp`/`lpstat`) | Impressão | Só se a impressão for usada |
| `enscript` / `paps` | Texto → PostScript/PDF | Não (briefing §19) |
| `valgrind` | Diagnóstico | Não |

---

## 6. Verificação de disponibilidade no ambiente

Estado atual do ambiente de desenvolvimento (a confirmar na FASE F):

Verificado em 2026-08-24:

```
harbour   → 3.2.1dev (r2608161531), /opt/harbour  ✔
hbmk2     → 3.2.1dev                                ✔
gcc       → 15.2.0 (Ubuntu)  ✔
sqlite3   → 3.46.1           ✔  (STRICT exige 3.37+)
make      → GNU Make 4.4.1   ✔
python3   → 3.14.4           ✔  (ferramentas de análise e auditoria)
```

**Resolvido em 2026-08-24.** O risco RI-01 se materializou e foi fechado
compilando o Harbour do fonte — **não existe pacote `harbour` no Ubuntu 26.04**
(componente `universe` habilitado, 177k pacotes indexados, nenhuma
correspondência). A instrução `apt install harbour`, que constava aqui, estava
errada.

```bash
sudo apt install libsqlite3-dev libncurses-dev   # dependências de compilação
git clone https://github.com/harbour/core.git && cd core
make && sudo HB_INSTALL_PREFIX=/opt/harbour make install
export PATH=/opt/harbour/bin:$PATH               # acrescentado ao ~/.bashrc
```

`contrib/hbsqlit3` é compilado junto: `/opt/harbour/lib/harbour/libhbsqlit3.a`.
Linkedição: `hbmk2 <fonte>.prg -lhbsqlit3 -lsqlite3`.

**Atenção:** o `hbsqlit3` não exporta `sqlite3_close()` — o banco é fechado pelo
destrutor do ponteiro (basta descartar a referência).

Verificado de dentro do Harbour em 2026-08-24 (fecha RI-02 e RI-02b):

| Verificação | Resultado |
|---|---|
| `sqlite3_libversion()` via `hbsqlit3` | `3.46.1` — ≥ 3.37, `STRICT` suportado |
| `database/schema.sql` aplicado por `sqlite3_exec()` | sem erro |
| `database/views.sql` aplicado por `sqlite3_exec()` | sem erro |
| `STRICT` rejeita texto em coluna `INTEGER` | rejeitado |
| `CHECK` de UF rejeita `RC` e aceita `SC` (D-20) | conforme |
| `CVBCLIEN.DBF` via RDD `DBFNTX`, `SET DELETED OFF` | 12 campos, 22 registros, 0 excluídos |
| `hb_Translate( cValor, "PT860", "UTF8" )` | byte `0xA7` em `CVBCLIEN.ENDCLI` → `º` (`Nº12`) — CP860 confirmado |

O `Makefile` contém o alvo `make check-deps`, que confere cada dependência e
imprime o que está em uso.

### Build de referência (FASE F.7, briefing §27)

Ambiente em que o sistema foi compilado e os testes passam:

| Item | Versão |
|---|---|
| Harbour | 3.2.1dev (r2608161531), compilado do fonte em `/opt/harbour` |
| Compilador C | GNU C 15.2 (Ubuntu 15.2.0-16ubuntu1), 64-bit |
| SQLite (biblioteca e `hbsqlit3`) | 3.46.1 |
| SQLite (CLI, ferramentas) | 3.46.1 |
| GNU Make | 4.4.1 |
| Sistema | Ubuntu 26.04 LTS, Linux x86_64 |
| PCode do Harbour | 0.3 |

Flags de compilação, definidas no `Makefile`:

```make
HB_INC  := -I/opt/harbour/contrib/hbsqlit3   # o .ch do hbsqlit3 não está no
                                             # include path padrão
HB_LIBS := -lhbsqlit3 -lsqlite3
HBFLAGS := $(HB_INC) $(HB_LIBS) -gtcgi
```

`-gtcgi` seleciona o terminal sem controle de tela: a migração e os testes são
programas de linha de comando, e o GT padrão emitiria sequências de
posicionamento no meio da saída. A FASE G, que tem telas, usará outro GT.

Alvos disponíveis: `all` · `run` · `migrate` · `migrate-forcar` · `verificar` ·
`relatorio` · `test` · `install` · `desinstalar` · `clean` · `check-deps` ·
`ajuda`.
