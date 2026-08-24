# 03 — REGRAS DE NEGÓCIO EXTRAÍDAS DO LEGADO

## Classificação da evidência

Cada regra recebe um grau de evidência:

| Grau | Significado |
|---|---|
| **[COMPROVADA]** | Explicitamente codificada; comportamento inequívoco |
| **[INFERIDA]** | Deduzida do código + dos dados, mas sem enunciado explícito |
| **[DEFEITUOSA]** | Codificada, porém o código **não faz** o que o nome/contexto indica |
| **[PENDENTE]** | Não determinada pelo legado — registrada como questão |

Total: **37 regras** — 24 comprovadas, 6 inferidas, 7 defeituosas. Mais **8 questões pendentes** (`02-MODELO-DADOS.md` §7).

---

## A. Padrão geral de manutenção de cadastros

### RN-001 — Acesso ao registro pelo código  **[COMPROVADA]**
```
REGRA:      Todo cadastro é acessado digitando-se seu código na primeira posição da tela.
Origem:     CVMTCLI.PRG, CVMTFUNC.PRG, CVMTFOR.PRG, CVMTPEC.PRG, CVMTALMX.PRG, CVMTFRO.PRG
Função:     laço DO WHILE .T. principal
Condição:   sempre
Comportamento: SEEK <codigo>; FOUND() decide entre alteração/exclusão e inclusão
Mensagem:   —
Impacto:    Define o modo de operação da tela
```

### RN-002 — Código vazio + ENTER abre a tabela de códigos  **[COMPROVADA]**
```
REGRA:      Deixar o código em branco e pressionar ENTER abre um browse de seleção.
Origem:     6 módulos de manutenção + CVMTVPEC, CVMTVREP, CVMTPENT, CVMTCON
Função:     IF EMPTY(Mcod) .AND. LASTKEY() = 13  →  TABELA()
Condição:   código vazio E última tecla = ENTER (13)
Comportamento: DBEDIT sobre os 2 primeiros campos; ENTER seleciona e devolve o código
               via macro (&"M"+FIELDNAME(1)); ESC cancela
Mensagem:   rodapé "<Esc>-Retorna <ENTER>-Tabela de Codigos"
Impacto:    Único mecanismo de busca sem conhecer o código
```

### RN-003 — Código vazio + ESC encerra o módulo  **[COMPROVADA]**
```
REGRA:      Deixar o código em branco e pressionar ESC fecha as tabelas e retorna ao menu.
Origem:     todos os módulos de manutenção e movimento
Função:     IF EMPTY(Mcod) .AND. LASTKEY() = 27 → CLOSE DATABASES; RETURN
Impacto:    Saída do módulo
```

### RN-004 — Código inexistente oferece cadastro  **[COMPROVADA]**
```
REGRA:      Se o código não existir, o sistema pergunta se deve cadastrá-lo.
Origem:     CVMTCLI:41, CVMTFUNC:38, CVMTFOR:40, CVMTPEC:39, CVMTALMX:40, CVMTFRO:39, CVMTALM:38
Função:     CONFIRMA(...,"Codigo novo! Deseja cadastrar")
Condição:   .NOT. FOUND()
Comportamento: "S" → abre os GETs em branco e faz APPEND BLANK; "N" → LOOP (volta ao código)
Mensagem:   "Codigo novo! Deseja cadastrar (S/N)?"
Impacto:    Inclusão de registro
```

### RN-005 — Código existente oferece Alterar / Retornar / Excluir  **[COMPROVADA]**
```
REGRA:      Se o código existir, o sistema exibe os dados e oferece A/R/E, com R como padrão.
Origem:     CVMTCLI:100, CVMTFUNC:82, CVMTFOR:96, CVMTPEC:96, CVMTALMX:112, CVMTFRO:88, CVMTALM:70
Função:     GET ALTER PICT "!" VALID (ALTER $ "ARE")
Condição:   FOUND()
Comportamento: A → reabre os GETs em laço até confirmação; R → LOOP; E → confirma e DELETE
Mensagem:   "<entidade> ja cadastrado <A>ltera; <R>etorna; <E>xclui"
            (textos por módulo: "Cliente", "Funcionario", "Fornecedor", "Material",
             "Almoxarifado", "Carro"; CVMTPEC exibe erroneamente "Cliente")
Impacto:    Determina alteração ou exclusão
```

### RN-006 — Confirmação obrigatória antes de gravar  **[COMPROVADA]**
```
REGRA:      Nenhuma inclusão ou alteração é gravada sem confirmação explícita do operador.
Origem:     todos os módulos de manutenção
Função:     CONFIRMA(...,"Os dados estao corretos ")
Condição:   após o READ dos campos
Comportamento: "N" na inclusão → LOOP (descarta); "N" na alteração → repete o laço de edição
Mensagem:   "Os dados estao corretos  (S/N)?"
Impacto:    Sem confirmação não há APPEND/REPLACE
```

### RN-007 — Exclusão é lógica  **[COMPROVADA]**
```
REGRA:      Excluir marca o registro; ele deixa de ser visível mas permanece no arquivo.
Origem:     CV_FUNC/SCCV — SET DELETED ON;  DELETE nos 7 módulos de manutenção
Função:     IF CONFIRMA("Confirma exclusao") → DELETE
Comportamento: registro marcado com "*"; invisível a SEEK/SKIP/COUNT/browse/relatórios
Mensagem:   "Confirma exclusao (S/N)?"
Impacto:    Recuperável até o PACK (RN-034)
```

### RN-008 — Continuação em laço  **[COMPROVADA]**
```
REGRA:      Após gravar, o sistema pergunta se o operador deseja continuar no mesmo cadastro.
Origem:     todos os módulos de manutenção
Função:     IF .NOT. CONFIRMA("Deseja continuar") → CLOSE DATABASES; RETURN
Mensagem:   "Deseja continuar (S/N)?"
```

### RN-009 — Gravação incondicional após o bloco de decisão  **[DEFEITUOSA]**
```
REGRA:      Os REPLACE ficam FORA do IF/ELSE e executam em todos os caminhos.
Origem:     CVMTCLI:120-133, CVMTFUNC:107-115, CVMTFOR:130-140, CVMTPEC:135-142,
            CVMTALMX:170-177, CVMTFRO:120-127, CVMTALM:88-93, CVCLI, CVCONS, CVPECAS
Condição:   sempre — inclusive após "R"etorna e após "E"xcluir
Comportamento: - após "R": reescreve o registro com os mesmos valores (inócuo)
               - após "E": reescreve os campos do registro RECÉM-EXCLUÍDO
                 (o DELETE só marca a flag; o REPLACE ainda funciona)
               - se o usuário responder "N" a "Codigo novo?" o LOOP evita o REPLACE,
                 mas se responder "N" a "Os dados estao corretos" na ALTERAÇÃO,
                 o laço interno repete — nunca escapa sem gravar.
Impacto:    Escrita redundante; em CVMTPEC, corrompe CODPEC (ver RN-036)
Classificação prevista: [CORREÇÃO] — ver 09/D-04
```

---

## B. Clientes e consórcio

### RN-010 — Data de cadastro tem valor padrão  **[COMPROVADA]**
```
REGRA:      O campo "Data" do cliente é pré-preenchido com a data do sistema.
Origem:     CVMTCLI.PRG:22  →  MDATACLI = DATE()
Comportamento: Editável pelo operador; nenhuma validação de faixa
Impacto:    DATCLI
```

### RN-011 — Marcação de consorciado dispara a adesão  **[COMPROVADA]**
```
REGRA:      Gravar um cliente com "Participa de Consorcio = S" abre imediatamente
            a tela de adesão a grupo de consórcio.
Origem:     CVMTCLI.PRG:135-137
Função:     IF MCONSOR="S" → DO CVMTCON WITH MCODCLI, MNOMECLI
Condição:   após os REPLACE do cliente
Comportamento: CVMTCON recebe código e nome já gravados
Impacto:    Cria (ou não) registro em CVBGRUPO
Observação: CVMTCON pode ser abortado (ESC / "N" em "Cadastrar Consorciado"),
            deixando CONSOR="S" sem cota. Dado real: 13 dos 17 clientes
            marcados "S" não têm cota. Ver Q-08.
```

### RN-012 — Recursão mútua Cliente ↔ Consórcio  **[DEFEITUOSA]**
```
REGRA:      CVMTCON.PRG termina com "DO CVMTCLI" (última linha, sem RETURN).
Origem:     CVMTCON.PRG:171
Comportamento: cada adesão empilha uma nova instância de CVMTCLI, que pode
               novamente chamar CVMTCON. A pilha só é liberada quando o operador
               sai de todas as instâncias com ESC.
Impacto:    Consumo de pilha; navegação confusa
Classificação prevista: [CORREÇÃO] — ver 09/D-03
```

### RN-013 — Numeração do grupo de consórcio por sequencial persistente  **[COMPROVADA]**
```
REGRA:      Ao criar um grupo novo, o número é obtido de um contador global
            armazenado em arquivo, incrementado e regravado.
Origem:     CVMTCON.PRG:44-46, 71 ; SCCV.PRG (inicializa MCODGRU=0)
Função:     RESTORE FROM cvmgrupo ADDITIVE ; mcodgru = mcodgru + 1 ;
            SAVE TO cvmgrupo ALL LIKE mcodgru
Condição:   SEEK <cod_carro> em CVBGRUPO retorna .NOT. FOUND()
            (isto é: ainda não existe grupo em formação para aquele modelo)
Comportamento: novo CODGRU; NUMPAR, NUMMES, VALPRE zerados; DATCON = DATE();
               GRUFEC = .F.; NUPGRU = 1
Mensagem:   —
Impacto:    Único gerador de sequência do sistema
Observação: O SAVE ocorre ANTES da confirmação "Cadastrar Consorciado". Se o
            operador desistir, o número é consumido e perdido. [INFERIDA]
```

### RN-014 — Adesão a grupo existente reaproveita os parâmetros  **[COMPROVADA]**
```
REGRA:      Se já existe grupo em formação para o modelo escolhido, o novo
            consorciado herda CODGRU, NUMPAR, NUMMES, VALPRE e DATCON do grupo.
Origem:     CVMTCON.PRG:56-70
Comportamento: campos exibidos apenas para conferência (CLEAR GETS — não editáveis)
Impacto:    Todos os participantes de um grupo compartilham os mesmos parâmetros
```

### RN-015 — Número do participante = contagem + 1  **[COMPROVADA/DEFEITUOSA]**
```
REGRA:      O nº do participante dentro do grupo é a quantidade atual de
            participantes daquele grupo mais um.
Origem:     CVMTCON.PRG:62-63
Função:     count all for mcodgru=codgru to mnupgru ; mnupgru = mnupgru + 1
Comportamento: DEFEITO — a expressão "mcodgru=codgru" compara a variável de memória
               com o campo, mas em Clipper Summer '87 dentro de COUNT o nome
               não qualificado "codgru" resolve para o CAMPO e "mcodgru" para a
               memória; a comparação é válida, porém percorre TODO o arquivo,
               inclusive registros de outros grupos, e ignora SET FILTER.
               Também: COUNT sobre arquivo com SET DELETED ON não conta excluídos,
               o que é o comportamento desejado por acidente.
Impacto:    NUPGRU pode colidir se registros de um grupo forem excluídos e recriados
Classificação prevista: [CORREÇÃO] — ver 09/D-10
```

### RN-016 — Valor da prestação = valor do veículo  **[COMPROVADA]**
```
REGRA:      Ao criar/aderir a um grupo, o valor da prestação é pré-preenchido
            com o valor de tabela do modelo.
Origem:     CVMTCON.PRG:38  →  mvalpre = valcar   (após SEEK em CVBFROTA)
Comportamento: Editável apenas na criação do grupo (GET com READ);
               na adesão a grupo existente é somente leitura (CLEAR GETS)
Impacto:    VALPRE
Observação: É o valor CHEIO do carro como prestação, não o valor dividido pelo
            número de meses. Se isso é intencional ou defeito, o legado não diz.
            REGRA NÃO DETERMINADA PELO LEGADO (Q-09).
```

### RN-017 — Nº de meses inicializado com o nº de participantes  **[COMPROVADA]**
```
REGRA:      O número de prestações é inicializado igual ao número de participantes.
Origem:     CVMTCON.PRG:52  →  mnummes = mnumpar
Comportamento: exibido em GET e imediatamente congelado (CLEAR GETS) — não editável
Impacto:    NUMMES
Observação: consistente com a mecânica clássica de consórcio (1 contemplado/mês)
```

### RN-018 — Fechamento automático do grupo  **[COMPROVADA]**
```
REGRA:      Quando o número de cotas atinge o número de participantes previsto,
            o grupo é fechado: todos os registros migram de CVBGRUPO para CVBGRUCO
            com GRUFEC=.T. e são excluídos da tabela de formação.
Origem:     CVMTCON.PRG:151-192
Função:     count all for codgru = mcodgru to totpan ; IF totpan >= mnumpar
Comportamento: 1. monta vetor grfec[] com os RECNO() do grupo (via SET FILTER)
               2. para cada um: lê os 11 campos, DELE em CVBGRUPO,
                  APPEND BLANK + REPLACE em CVBGRUCO com GRUFEC = .T.
               3. SET FILTER TO (limpa)
Mensagem:   "Aguarde!!! Grupo Fechado Transferindo dados..."  (cor N/W*+)
Impacto:    Move N registros entre tabelas SEM TRANSAÇÃO — interrupção deixa
            o grupo parcialmente migrado
Evidência nos dados: CVBGRUPO tem 3 registros marcados como excluídos
                     (CODCON 1,2,3 / CODGRU 1) e CVBGRUCO tem exatamente esses 3.
Classificação prevista: [MODERNIZAÇÃO] transação — ver 09/D-12
```

### RN-019 — Campos SORT e QUIT não são inicializados na transferência  **[INFERIDA]**
```
REGRA:      CVBGRUCO possui SORT (contemplado) e QUIT (quitado) que CVBGRUPO não tem.
Origem:     CVMTCON.PRG:176-192 (lista de REPLACE não inclui SORT nem QUIT)
Comportamento: assumem o valor do APPEND BLANK, que para campo L é .F.
Impacto:    Correto por acidente. A nova implementação deve inicializá-los explicitamente.
```

### RN-020 — Baixa de prestações  **[COMPROVADA/DEFEITUOSA]**
```
REGRA:      O operador informa quantas prestações foram pagas; o sistema subtrai
            do saldo de prestações restantes.
Origem:     CVMTCON2.PRG:38-40
Função:     mnumfal = mnummes - mnumfala ; REPLACE nummes WITH mnumfal
Condição:   consorciado localizado em CVBGRUCO
Comportamento: DEFEITO — não há piso em zero. Informar mais prestações do que
               as restantes produz saldo NEGATIVO. NUMMES é N(2,0): a faixa
               representável é -9..99; valores fora estouram e o Clipper grava "*".
Mensagem:   —
Impacto:    Dado real: CVBGRUCO registro 1 contém "**" (overflow);
            registros 2 e 3 contêm -2 e -3.
Classificação prevista: [CORREÇÃO] + [VALIDAÇÃO] — ver 09/D-11
```

### RN-021 — Quitação  **[COMPROVADA]**
```
REGRA:      Quando o saldo de prestações chega a zero, o consorciado é marcado
            como quitado.
Origem:     CVMTCON2.PRG:42-45
Função:     IF mnumfal = 0 → MENSAGEM(...) ; REPLACE quit WITH .T.
Mensagem:   "Todas As prestacoes ja quitadas! Pressione algo para continuar..."
Impacto:    QUIT = .T.
Observação: O teste é "= 0" exato. Saldo negativo (RN-020) NÃO marca quitação.
```

### RN-022 — Registro de contemplação (sorteio)  **[COMPROVADA]**
```
REGRA:      O operador informa S/N se o consorciado foi sorteado; o valor é gravado.
Origem:     CVMTCON2.PRG:46-53
Função:     GET msort PICT "!" VALID (msort $ "SN") ; REPLACE sort WITH .T./.F.
Impacto:    SORT
Observação: O sistema NÃO realiza sorteio — apenas registra o resultado externo.
```

### RN-023 — Contemplação baixa estoque de veículo  **[COMPROVADA]**
```
REGRA:      Ao marcar um consorciado como sorteado, uma unidade do modelo
            contratado é baixada do estoque de frota.
Origem:     CVMTCON2.PRG:55-70
Função:     SELE 2 ; SEEK mcodcar ; mqtacar = quantcar - 1 ;
            REPLACE quantcar WITH mqtacar
Condição:   msort = "S"
Comportamento: Se QUANTCAR já for 0, NÃO baixa e exibe aviso; a marca SORT=.T.
               permanece gravada (o REPLACE de SORT ocorre ANTES do teste).
Mensagem:   "Quantidade esgotada!!; Aguarde aproximadamente 10 dias pelo carro"
Impacto:    CVBFROTA.QUANTCAR
Observação: Não há reversão da marca SORT. [INFERIDA — possível inconsistência]
```

---

## C. Vendas e comissões

### RN-024 — Cliente inexistente na venda de peças: cadastro em linha  **[COMPROVADA]**
```
REGRA:      Ao informar um cliente não cadastrado numa venda de peças ou reparo,
            o sistema oferece cadastrá-lo imediatamente.
Origem:     CVMTVPEC.PRG:29-34 ; CVMTVREP.PRG:34-39
Função:     IF CONFIRMA("Cliente nao Cadastrado; Deseja Cadastra-lo ") → DO CVMTCLI
Comportamento: "N" → LOOP (volta ao código)
Mensagem:   "Cliente nao Cadastrado; Deseja Cadastra-lo  (S/N)?"
Impacto:    Ao retornar de CVMTCLI o fluxo prossegue SEM reposicionar o registro
            do cliente — o SEEK original já falhou. [DEFEITO CORRELATO — 09/D-06]
```

### RN-025 — Cliente inexistente na pronta entrega: sem cadastro em linha  **[COMPROVADA]**
```
REGRA:      Na pronta entrega, cliente não cadastrado apenas gera mensagem.
Origem:     CVMTPENT.PRG:27-30
Função:     mensagem("Cliente nao Cadastrado; Deseja Cadastra-lo ",1) ; loop
Mensagem:   texto pergunta, mas o comportamento é apenas informativo (MENSAGEM,
            não CONFIRMA). Divergência entre texto e comportamento.
Impacto:    Volta ao código do cliente
```

### RN-026 — Subtotal e total da venda de peças  **[COMPROVADA]**
```
REGRA:      Subtotal do item = valor unitário × quantidade vendida.
            Total da compra = soma dos subtotais dos itens da sessão.
Origem:     CVMTVPEC.PRG:79-81  →  MSUBTOT = MVALUNI*MQTVEND ;
                                   MTOTALC = MTOTALC + MSUBTOT
            CVMTVREP.PRG:138-140 →  MSUBTOT = MVALUNI * MQUANTC ;
                                    MTOTAL = MTOTAL + MSUBTOT
Aritmética: multiplicação e soma decimais exatas (Clipper usa decimal, não binário);
            sem arredondamento explícito; N(12,2) → 2 casas.
Impacto:    CVPECAS.SUBTOT e CVPECAS.VALTOT
```

### RN-027 — Total gravado apenas no último item  **[COMPROVADA/DEFEITUOSA]**
```
REGRA:      VALTOT (total da compra) é gravado somente quando o operador encerra
            a sessão de itens.
Origem:     CVMTVPEC.PRG:145  →  REPLACE VALTOT WITH MTOTALC
Comportamento: o REPLACE ocorre fora do bloco de APPEND, atingindo o registro
               corrente — que é o último item incluído. Nos demais itens da mesma
               compra, VALTOT fica com o valor do APPEND BLANK (vazio/zero).
Impacto:    37% dos registros de CVPECAS (28 de 75) têm VALTOT vazio ou zero.
            É o ÚNICO indício de agrupamento de itens numa mesma compra.
Classificação prevista: [MUDANÇA FUNCIONAL] — modelar cabeçalho/item (09/D-17)
```

### RN-028 — Alerta de estouro do estoque mínimo  **[COMPROVADA]**
```
REGRA:      Se a quantidade vendida ultrapassar (estoque atual − estoque mínimo),
            o sistema alerta, mas PERMITE a venda mediante confirmação.
Origem:     CVMTVPEC.PRG:84-88
Função:     IF MQTVEND > (MQTDPEC-MQTDMIN)
              IF .NOT. CONFIRMA(" [ERRO] Estouro do Estoque Minimo; Continuo ") → LOOP
Mensagem:   " [ERRO] Estouro do Estoque Minimo; Continuo  (S/N)?"
Impacto:    "S" → prossegue e permite estoque abaixo do mínimo (inclusive negativo);
            "N" → descarta o item
Observação: Não existe alerta equivalente em CVMTVREP (reparos). [INFERIDA — lacuna]
```

### RN-029 — Baixa de estoque de peças  **[COMPROVADA]**
```
REGRA:      A venda de peça reduz o estoque pela quantidade vendida.
Origem:     CVMTVPEC.PRG:117-118
Função:     MNQTDPEC = MQTDPEC - MQTVEND ; REPLACE QTDPEC WITH MNQTDPEC
Comportamento: Sem piso em zero — estoque pode ficar negativo (RN-028 permite).
Impacto:    CVBPECAS.QTDPEC
Observação: CVMTVREP (reparos) NÃO baixa estoque de peças. Peças consumidas em
            reparo saem do sistema sem controle. [DEFEITO — 09/D-13]
```

### RN-030 — Comissão de venda de peças  **[DEFEITUOSA]**
```
REGRA CODIFICADA:
            Comissão do funcionário += (CÓDIGO do funcionário) × 0,20
Origem:     CVMTVPEC.PRG:112-114 ; CVMTVREP.PRG:52-54
Função:     MCOMFUN = COMFUN ; MCOMFUN = COMFUN+(MCODFUN * 0.2) ;
            REPLACE COMFUN WITH MCOMFUN
Condição:   após localizar o funcionário
Comportamento: usa MCODFUN — o CÓDIGO do funcionário, não o valor da venda.
               Um funcionário de código 11 ganha R$ 2,20 por venda;
               um de código 1 ganha R$ 0,20 — independentemente do valor vendido.
Impacto:    CVBFUNC.COMFUN
Evidência:  os valores reais de COMFUN (1500,80 / 534,75 / 297,75 / 10,50 / 6,35)
            não guardam relação proporcional com nenhum valor de venda.
Classificação prevista: [INDEFINIDO] — a intenção original não é determinável.
            NÃO deve ser "corrigida" por suposição. Ver 09/D-05 e Q-10.
```

### RN-031 — Comissão de pronta entrega  **[COMPROVADA]**
```
REGRA:      Comissão do funcionário += 1,5% do valor do veículo vendido.
Origem:     CVMTPENT.PRG:88-89
Função:     MCOMFUN = COMFUN + (MVALCAR * 0.015)
Aritmética: 0.015 exato; sem arredondamento
Impacto:    CVBFUNC.COMFUN
Observação: A gravação atinge o registro ERRADO (ver 09/D-07) — a fórmula, porém,
            é claramente intencional e deve ser preservada.
```

### RN-032 — Comissão de consórcio  **[COMPROVADA]**
```
REGRA:      Comissão do funcionário += 0,15% do valor da prestação.
Origem:     CVMTCON.PRG:104 (e CVMCOM.PRG:106, morto)
Função:     comiss = mvalpre * 0.0015 ; com = comfun + comiss ;
            REPLACE comfun with com
Impacto:    CVBFUNC.COMFUN
Observação: Base é a PRESTAÇÃO, não o valor total do plano.
```

### RN-033 — Comissão nunca é zerada  **[INFERIDA]**
```
REGRA:      COMFUN é um acumulador perpétuo.
Origem:     ausência de qualquer "REPLACE COMFUN WITH 0" em todo o sistema
Impacto:    Não há fechamento de período, pagamento ou histórico de comissão.
            REGRA NÃO DETERMINADA PELO LEGADO (Q-07).
```

### RN-034 — Baixa de estoque na pronta entrega  **[COMPROVADA]**
```
REGRA:      A venda de um veículo baixa uma unidade do estoque do modelo.
Origem:     CVMTPENT.PRG:90-92, 118
Função:     MQUANCAR = QUANTCAR - 1 ; ... ; REPLACE QUANTCAR WITH MQUANCAR
Impacto:    CVBFROTA.QUANTCAR
Observação: A gravação atinge o registro ERRADO (ver 09/D-08).
```

### RN-035 — Aviso de último veículo  **[COMPROVADA]**
```
REGRA:      Quando a baixa zera o estoque do modelo, o sistema avisa.
Origem:     CVMTPENT.PRG:130-132
Função:     IF MQUANCAR = 0 → MENSAGEM("ATENCAO: ULTIMO CARRO SENDO VENDIDO; Tecle <ENTER>",23)
Mensagem:   "ATENCAO: ULTIMO CARRO SENDO VENDIDO; Tecle <ENTER>! Pressione algo..."
Impacto:    Informativo. Não impede a venda. Não impede venda com estoque já zero.
```

### RN-036 — Manutenção de estoque de peças corrompe o código  **[DEFEITUOSA]**
```
REGRA CODIFICADA:
            No caminho de ALTERAÇÃO, a variável do código da peça recebe o
            código do FORNECEDOR.
Origem:     CVMTPEC.PRG:73  →  MCODPEC = CODFOR      (deveria ser MCODPEC = CODPEC)
Comportamento: na gravação (CVMTPEC:135, REPLACE CODPEC WITH MCODPEC) o registro
               da peça passa a ter CODPEC = código do fornecedor.
Impacto:    Corrompe a chave primária ao alterar qualquer peça.
Evidência:  os 4 registros de CVBPECAS têm CODPEC 1..4 e CODFOR 1,1,2,2 —
            nenhuma alteração foi feita após a inclusão, por isso o defeito
            não se manifestou nos dados.
Classificação prevista: [CORREÇÃO] — ver 09/D-01
```

### RN-037 — Faixa de chassis da frota  **[COMPROVADA]**
```
REGRA:      Ao cadastrar um lote de veículos, o chassi final é calculado como
            chassi inicial + quantidade.
Origem:     CVMTFRO.PRG:48-50, 100-104
Função:     MCHASDO = MCHASSI + MQUANTCAR
Comportamento: o valor é apresentado em GET editável — o operador pode sobrescrevê-lo.
               Na alteração, o cálculo é refeito ANTES e DEPOIS do READ.
Impacto:    CVBFROTA.CHASDO
Evidência:  registros reais: (700,800) com qtd 89; (100,200) com qtd 99;
            (35000123, 35000223) com qtd 99; (895650093012, 895650093112) com qtd 100.
            Todos têm diferença 100, não a quantidade → confirmam edição manual.
Observação: A faixa é meramente descritiva; nenhuma venda referencia um chassi. Q-03.
```

---

## D. Encerramento do sistema

### RN-038 — Rotina de saída com reorganização  **[COMPROVADA]**
```
REGRA:      Sair do sistema (ALT+X) exige confirmação e dispara a reorganização
            completa dos arquivos.
Origem:     CV_FUNC.PRG — PROCEDURE SAIDA (acionada por SET KEY 301)
Função:     CONFIRMA "Deseja Realmente Sair <S/N>"
Comportamento (quando "S"), na ordem exata:
              1. TONE(250,1) — bipe
              2. barra de progresso desenhada com caracteres ░ e ▓
              3. USE CVBFROTA INDEX CVIFRO1 ; REINDEX
              4. USE CVBCLIEN INDEX CVICLI1 ; PACK ; REINDEX      ← exclusão FÍSICA
              5. USE CVALMOX  INDEX CVIALM1 ; REINDEX
              6. USE CVBFORNE INDEX CVIFOR1 ; PACK ; REINDEX      ← exclusão FÍSICA
              7. USE CVBPECAS INDEX CVIPEC1 ; REINDEX
              8. USE CVBFUNC  INDEX CVIFUN1 ; PACK ; REINDEX      ← exclusão FÍSICA
              9. USE CVBGRUCO INDEX CVIGRUC1 ; REINDEX
             10. USE CVBGRUPO INDEX CVIGRU1  ; REINDEX
             11. USE CVPECAS  INDEX CVIPEC1  ; REINDEX   ← índice de outra tabela
             12. USE CVBPECAS INDEX CVIVPEC1 ; REINDEX   ← índice de outra tabela
             13. USE CVBGRUPO INDEX CVIGRU2  ; REINDEX
             14. CLEAR ALL ; BC_FIM(0) ; CANCEL
Mensagens:  "Deseja Realmente Sair <S/N>", "Reorganizando Arquivos, Aguarde !!!",
            "Reorganizacao Completa !!!", percentuais 8%..103%
Impacto:    - PACK torna DEFINITIVA a exclusão de clientes, fornecedores e
              funcionários, SEM verificar se há movimento referenciando-os.
            - As tabelas de movimento (CVBPENT, CVPECAS, CVBGRUCO) NUNCA sofrem PACK.
            - Passos 11 e 12 aplicam índices de tabelas trocadas (defeito).
            - O contador de progresso chega a 103%.
Classificação prevista: [MODERNIZAÇÃO] + [VALIDAÇÃO] — ver 09/D-15
```

---

## E. Outras regras

### RN-039 — Auto-reconstrução de índices  **[COMPROVADA]**
```
REGRA:      Na inicialização, qualquer índice ausente é reconstruído automaticamente.
Origem:     SCCV.PRG:29-105 — 16 blocos IF .NOT. FILE("<x>.ntx")
Impacto:    Sistema tolerante à perda de .NTX
Observação: CVIALM1 é reconstruído a partir de CVALMOX (obsoleta) e depois usado
            sobre CVBALMOX (tipos de chave incompatíveis). Ver 09/D-14.
```

### RN-040 — Relatório de clientes com filtro por tipo  **[COMPROVADA]**
```
REGRA:      O relatório de clientes permite listar consorciados, não-consorciados
            ou ambos.
Origem:     CVRCLI.PRG:9-32
Função:     MENU TO OPR → 1: SET FILTER TO CONSOR="S"
                          2: SET FILTER TO CONSOR="N"
                          3: SET FILTER TO         (sem filtro)
Impacto:    Escopo da listagem
Observação: A opção "Consorciados" filtra pela MARCA no cadastro de clientes,
            não pela existência de cota em CVBGRUPO/CVBGRUCO. Dado real: retorna
            17 clientes, dos quais só 5 têm cota.
```

### RN-041 — Pedidos: código duplicado é rejeitado  **[COMPROVADA — módulo inoperante]**
```
REGRA:      Um código de pedido já existente não pode ser reincluído.
Origem:     CVMTPED.PRG:52-54
Função:     SEEK mcodped ; IF .NOT. FOUND() → inclui ; ELSE → rejeita
Mensagem:   "Codigo ja existente"
Impacto:    Nenhum — o módulo não compila (IF sem ENDIF, linha 34) e não é chamado.
```

### RN-042 — Impressão de comprovante do pedido  **[COMPROVADA — módulo inoperante]**
```
REGRA:      Ao incluir um pedido, se houver impressora pronta, imprime o comprovante.
Origem:     CVMTPED.PRG:34-50
Função:     IF ISPRINTER() → SET DEVICE TO PRINTER ; EJECT ; ... ; SET DEVICE TO SCREEN
Impacto:    Nenhum (ver RN-041)
```

---

## F. Resumo de defeitos que alteram semântica

| Regra | Defeito | Efeito observável | Classificação prevista |
|---|---|---|---|
| RN-009 | `REPLACE` fora do `IF` | Grava após "Retorna" e após "Exclui" | [CORREÇÃO] D-04 |
| RN-012 | `DO CVMTCLI` no fim de `CVMTCON` | Recursão mútua | [CORREÇÃO] D-03 |
| RN-015 | `COUNT` sem filtro correto | `NUPGRU` pode colidir | [CORREÇÃO] D-10 |
| RN-020 | Sem piso em zero + `N(2,0)` | `NUMMES` negativo e overflow `**` nos dados | [CORREÇÃO]+[VALIDAÇÃO] D-11 |
| RN-027 | `VALTOT` só no último item | 37% dos registros sem total | [MUDANÇA FUNCIONAL] D-17 |
| RN-029 | Reparo não baixa estoque | Peças somem sem controle | [CORREÇÃO] D-13 |
| RN-030 | Comissão usa `CODFUN` em vez de valor | Comissões sem relação com vendas | **[INDEFINIDO]** D-05 |
| RN-031 | `REPLACE COMFUN` em registro errado | Comissão creditada ao 1º funcionário | [CORREÇÃO] D-07 |
| RN-034 | `REPLACE QUANTCAR` em registro errado | Baixa no 1º modelo da tabela | [CORREÇÃO] D-08 |
| RN-036 | `MCODPEC = CODFOR` | Corrompe PK ao alterar peça | [CORREÇÃO] D-01 |
| RN-038 | `PACK` sem verificar dependências | Pode criar órfãos irreversíveis | [VALIDAÇÃO] D-15 |
