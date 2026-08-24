-- ===========================================================================
--  S.C.C.V. — Sistema de Controle de Concessionária de Veículos
--  Esquema SQLite — reengenharia do sistema Clipper Summer '87 (1994)
--
--  Versão do schema : 1
--  SQLite mínimo    : 3.37.0  (tabelas STRICT)
--  Gerado na FASE C conforme docs/02-MODELO-DADOS.md §9
--
--  DECISÕES ESTRUTURAIS (rastreabilidade em docs/09-DIVERGENCIAS-MODERNIZACAO.md):
--    · Tabelas STRICT           — tipagem realmente aplicada, não afinidade
--    · Monetário em centavos    — INTEGER; nunca REAL (briefing §10)
--    · Datas ISO-8601           — TEXT 'YYYY-MM-DD', validadas como datas reais
--    · Exclusão lógica          — coluna `excluido`; views v_* reproduzem SET DELETED ON
--    · Chaves naturais          — preservadas onde o operador as digita (§5 do doc 02)
--    · Chaves técnicas          — só onde o legado não tinha identidade (D-16, D-17)
--    · Snapshots históricos     — colunas *_snapshot preservam o valor da época (D-19)
--    · Documentos normalizados  — só dígitos + coluna *_original + flag *_valido
--    · Valores que violam CHECK — vão para NULL, com o bruto em *_legado (D-11)
--
--  ATENÇÃO — a integridade referencial NÃO é ativada por este arquivo.
--  `PRAGMA foreign_keys = ON` é por conexão e deve ser emitido pela aplicação
--  (src/database/conexao.prg) em toda abertura. Ver §Verificação no fim.
--
--  FALLBACK: se o SQLite de destino for < 3.37, remover as ocorrências de
--  ") STRICT;" trocando por ");". O restante do schema é compatível com 3.24+.
-- ===========================================================================

PRAGMA journal_mode = WAL;      -- persistente no arquivo do banco
PRAGMA foreign_keys = ON;       -- vale só para esta sessão; ver ATENÇÃO acima

BEGIN;

PRAGMA user_version = 1;

-- ===========================================================================
--  1. CADASTROS — nível 0 (sem dependências)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- CLIENTE                                          ← legacy/CVBCLIEN.DBF (22 reg.)
--   PK natural CODCLI: código digitado pelo operador, faixa da máscara "99999".
--   CEPCLI era N(8,0) no legado e perdia zeros à esquerda → agora TEXT (D-09).
--   CICCLI (nome histórico de CPF) não tinha validação alguma → normalizado,
--   com DV verificado na migração; NUNCA obrigatório (briefing §7, doc 05 §9).
-- ---------------------------------------------------------------------------
CREATE TABLE cliente (
  cod_cli           INTEGER PRIMARY KEY
                    CHECK (cod_cli BETWEEN 1 AND 99999),
  nome              TEXT    NOT NULL
                    CHECK (length(trim(nome)) > 0),
  endereco          TEXT,
  cidade            TEXT,
  -- CEP: 8 dígitos, sem máscara. Original preservado para auditoria.
  cep               TEXT    CHECK (cep IS NULL OR cep GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  cep_original      TEXT,
  -- UF: lista corrigida — legado omitia SC e TO e continha FN e RC (D-20/V-10)
  uf                TEXT    CHECK (uf IS NULL OR uf IN (
                      'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS',
                      'MT','PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC',
                      'SE','SP','TO')),
  -- Telefone: só dígitos. DDD pré-1999 NÃO é convertido (D-24).
  telefone          TEXT    CHECK (telefone IS NULL OR telefone GLOB '[0-9]*'),
  telefone_original TEXT,
  -- RG não tem formato nacional único nem DV: preservado como veio (doc 08 §4.5)
  rg                TEXT,
  cpf               TEXT    CHECK (cpf IS NULL OR cpf GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  cpf_original      TEXT,
  cpf_valido        INTEGER NOT NULL DEFAULT 0 CHECK (cpf_valido IN (0,1)),
  nascimento        TEXT    CHECK (nascimento IS NULL OR
                      (nascimento GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                       AND date(nascimento) = nascimento)),
  data_cadastro     TEXT    NOT NULL
                    CHECK (data_cadastro GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                           AND date(data_cadastro) = data_cadastro),
  -- CONSOR: marca de participação em consórcio; dispara a adesão (RN-011).
  -- Aceita 'S' sem cota correspondente — 13 dos 17 casos reais (Q-08).
  consorcio         TEXT    NOT NULL DEFAULT 'N' CHECK (consorcio IN ('S','N')),
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

-- CPF único entre os clientes ativos que possuem CPF (V-13).
-- Índice parcial: não impede vários clientes sem CPF nem colisão com excluídos.
CREATE UNIQUE INDEX ux_cliente_cpf
    ON cliente (cpf) WHERE cpf IS NOT NULL AND excluido = 0;
CREATE INDEX ix_cliente_nome      ON cliente (nome)      WHERE excluido = 0;
CREATE INDEX ix_cliente_consorcio ON cliente (consorcio) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- FUNCIONARIO                                       ← legacy/CVBFUNC.DBF (10 reg.)
--   comissao_cent é ACUMULADOR PERPÉTUO: o legado nunca o zera e não há
--   fechamento, pagamento ou histórico (RN-033 / Q-07). Preservado como está.
--   CODFUN é N(6) no DBF mas a máscara só permitia 5 dígitos — adotada a
--   maior capacidade (D-20).
-- ---------------------------------------------------------------------------
CREATE TABLE funcionario (
  cod_fun           INTEGER PRIMARY KEY
                    CHECK (cod_fun BETWEEN 1 AND 999999),
  nome              TEXT    NOT NULL CHECK (length(trim(nome)) > 0),
  endereco          TEXT,
  cidade            TEXT,
  cep               TEXT    CHECK (cep IS NULL OR cep GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  cep_original      TEXT,
  cargo             TEXT,
  salario_cent      INTEGER NOT NULL DEFAULT 0 CHECK (salario_cent  >= 0),
  comissao_cent     INTEGER NOT NULL DEFAULT 0 CHECK (comissao_cent >= 0),
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE INDEX ix_funcionario_nome ON funcionario (nome) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- FORNECEDOR                              ← legacy/CVBFORNE.DBF + .DBT (3 reg.)
--   OBSFOR era memo em arquivo .DBT separado → coluna TEXT (doc 08 §6.3).
--   CODITE é texto no legado e não referencia CVBPECAS.CODPEC — mantido TEXT
--   e sem FK, por não haver relação comprovada.
-- ---------------------------------------------------------------------------
CREATE TABLE fornecedor (
  cod_for           INTEGER PRIMARY KEY
                    CHECK (cod_for BETWEEN 1 AND 999999),
  nome              TEXT    NOT NULL CHECK (length(trim(nome)) > 0),
  telefone          TEXT    CHECK (telefone IS NULL OR telefone GLOB '[0-9]*'),
  telefone_original TEXT,
  cep               TEXT    CHECK (cep IS NULL OR cep GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  cep_original      TEXT,
  cidade            TEXT,
  endereco          TEXT,
  cod_item          TEXT,
  desc_item         TEXT,
  fabrica           TEXT,
  cnpj              TEXT    CHECK (cnpj IS NULL OR cnpj GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  cnpj_original     TEXT,
  cnpj_valido       INTEGER NOT NULL DEFAULT 0 CHECK (cnpj_valido IN (0,1)),
  observacoes       TEXT,
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE UNIQUE INDEX ux_fornecedor_cnpj
    ON fornecedor (cnpj) WHERE cnpj IS NOT NULL AND excluido = 0;
CREATE INDEX ix_fornecedor_nome ON fornecedor (nome) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- MODELO_VEICULO                                   ← legacy/CVBFROTA.DBF (5 reg.)
--   O legado controla a frota POR MODELO com quantidade, não por veículo
--   individual. CHASSI/CHASDO descrevem uma faixa, mas nenhuma venda registra
--   qual chassi foi entregue (Q-03). Modelagem preservada.
--   qtd_estoque >= 0: ver D-27.
-- ---------------------------------------------------------------------------
CREATE TABLE modelo_veiculo (
  cod_car           INTEGER PRIMARY KEY
                    CHECK (cod_car BETWEEN 1 AND 99999),
  descricao         TEXT    NOT NULL CHECK (length(trim(descricao)) > 0),
  qtd_estoque       INTEGER NOT NULL DEFAULT 0 CHECK (qtd_estoque >= 0),
  valor_cent        INTEGER NOT NULL DEFAULT 0 CHECK (valor_cent   >= 0),
  data_compra       TEXT    CHECK (data_compra IS NULL OR
                      (data_compra GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                       AND date(data_compra) = data_compra)),
  chassi_ini        INTEGER CHECK (chassi_ini IS NULL OR chassi_ini >= 0),
  chassi_fim        INTEGER CHECK (chassi_fim IS NULL OR chassi_fim >= 0),
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1)),
  -- RN-037: CHASDO = CHASSI + QUANTCAR, mas o campo é editável pelo operador.
  -- Só se exige coerência da faixa (V-18), não a fórmula.
  CHECK (chassi_fim IS NULL OR chassi_ini IS NULL OR chassi_fim >= chassi_ini)
) STRICT;

CREATE INDEX ix_modelo_descricao ON modelo_veiculo (descricao) WHERE excluido = 0;

-- ===========================================================================
--  2. CADASTROS — nível 1 (dependem de fornecedor)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- PECA                                             ← legacy/CVBPECAS.DBF (4 reg.)
--   NOMFOR era cópia desnormalizada do fornecedor. Aqui vira JOIN: é cadastro,
--   não movimento — não há valor histórico a preservar (contraste com D-19).
--   qtd_estoque >= 0: o legado permitia negativo (RN-028/029) → ver D-27.
-- ---------------------------------------------------------------------------
CREATE TABLE peca (
  cod_pec           INTEGER PRIMARY KEY
                    CHECK (cod_pec BETWEEN 1 AND 999999),
  descricao         TEXT    NOT NULL CHECK (length(trim(descricao)) > 0),
  qtd_estoque       INTEGER NOT NULL DEFAULT 0 CHECK (qtd_estoque     >= 0),
  valor_unit_cent   INTEGER NOT NULL DEFAULT 0 CHECK (valor_unit_cent >= 0),
  qtd_minima        INTEGER NOT NULL DEFAULT 0 CHECK (qtd_minima      >= 0),
  cod_for           INTEGER REFERENCES fornecedor(cod_for) ON DELETE RESTRICT,
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE INDEX ix_peca_fornecedor ON peca (cod_for);
CREATE INDEX ix_peca_descricao  ON peca (descricao) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- ALMOXARIFADO                                     ← legacy/CVBALMOX.DBF (4 reg.)
--   Estrutura paralela a `peca`, para material de consumo interno.
--   NENHUMA rotina do legado consome o almoxarifado (Q-01): qtd_estoque só é
--   alterada manualmente. Preservado — nenhum evento de baixa foi inventado.
--   O legado usava CVIALM1.NTX, índice construído sobre outra tabela com tipo
--   de chave incompatível (D-14); aqui a coluna é indexada corretamente.
-- ---------------------------------------------------------------------------
CREATE TABLE almoxarifado (
  cod_alm           INTEGER PRIMARY KEY
                    CHECK (cod_alm BETWEEN 1 AND 999999),
  descricao         TEXT    NOT NULL CHECK (length(trim(descricao)) > 0),
  qtd_estoque       INTEGER NOT NULL DEFAULT 0 CHECK (qtd_estoque     >= 0),
  valor_unit_cent   INTEGER NOT NULL DEFAULT 0 CHECK (valor_unit_cent >= 0),
  qtd_minima        INTEGER NOT NULL DEFAULT 0 CHECK (qtd_minima      >= 0),
  cod_for           INTEGER REFERENCES fornecedor(cod_for) ON DELETE RESTRICT,
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE INDEX ix_almox_fornecedor ON almoxarifado (cod_for);

-- ===========================================================================
--  3. MOVIMENTO — nível 2
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- VENDA_VEICULO                                     ← legacy/CVBPENT.DBF (23 reg.)
--   O legado NÃO tinha identidade: a venda era sua posição física no arquivo.
--   Não há chave natural — os dados mostram o mesmo cliente comprando o mesmo
--   modelo na mesma data (registros 11-15, 17). PK técnica introduzida (D-16).
--
--   Colunas *_snapshot: o legado copiava descrição/nome/valor no momento da
--   venda. São 5 divergências reais contra o cadastro atual — prova de que é
--   snapshot histórico deliberado, não redundância. Preservado (D-19).
--
--   FORMA: existe na estrutura, 2 registros preenchidos, mas NENHUM programa
--   do legado o grava. Origem desconhecida (Q-05). Migrado como veio.
-- ---------------------------------------------------------------------------
CREATE TABLE venda_veiculo (
  id                  INTEGER PRIMARY KEY,
  cod_car             INTEGER NOT NULL REFERENCES modelo_veiculo(cod_car) ON DELETE RESTRICT,
  cod_cli             INTEGER NOT NULL REFERENCES cliente(cod_cli)        ON DELETE RESTRICT,
  cod_fun             INTEGER NOT NULL REFERENCES funcionario(cod_fun)    ON DELETE RESTRICT,
  data_venda          TEXT    CHECK (data_venda IS NULL OR
                        (data_venda GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                         AND date(data_venda) = data_venda)),
  valor_cent          INTEGER NOT NULL DEFAULT 0 CHECK (valor_cent >= 0),
  forma_pagamento     TEXT,
  descricao_snapshot  TEXT,
  nome_cli_snapshot   TEXT,
  nome_fun_snapshot   TEXT,
  excluido            INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE INDEX ix_vveiculo_modelo ON venda_veiculo (cod_car);
CREATE INDEX ix_vveiculo_cli    ON venda_veiculo (cod_cli);
CREATE INDEX ix_vveiculo_fun    ON venda_veiculo (cod_fun);
CREATE INDEX ix_vveiculo_data   ON venda_veiculo (data_venda) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- VENDA_PECA (cabeçalho)                                              ← D-17
--   O legado gravava itens soltos em CVPECAS, sem número de venda e SEM DATA.
--   O único indício de agrupamento era VALTOT preenchido apenas no último item
--   (RN-027) — 28 de 75 registros ficaram com total zero/vazio.
--
--   `origem` distingue venda de balcão (CVMTVPEC) de peça de reparo
--   (CVMTVREP). O legado NÃO tinha esse discriminador (Q-02): todo registro
--   migrado recebe 'INDETERMINADO'. Não será inferido.
--
--   `data_venda` é NULL para tudo que vier do legado: a tabela CVPECAS não
--   possui campo de data (a predecessora CVVENPEC possuía DATVEN — o campo se
--   perdeu na evolução do sistema). Ver doc 02 §3.
-- ---------------------------------------------------------------------------
CREATE TABLE venda_peca (
  id                INTEGER PRIMARY KEY,
  cod_cli           INTEGER NOT NULL REFERENCES cliente(cod_cli)     ON DELETE RESTRICT,
  cod_fun           INTEGER          REFERENCES funcionario(cod_fun) ON DELETE RESTRICT,
  origem            TEXT    NOT NULL CHECK (origem IN ('BALCAO','REPARO','INDETERMINADO')),
  data_venda        TEXT    CHECK (data_venda IS NULL OR
                      (data_venda GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                       AND date(data_venda) = data_venda)),
  total_cent        INTEGER NOT NULL DEFAULT 0 CHECK (total_cent >= 0),
  -- VALTOT como veio do legado, quando presente; permite auditar o agrupamento
  total_cent_legado INTEGER,
  nome_cli_snapshot TEXT,
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE INDEX ix_vpeca_cli    ON venda_peca (cod_cli);
CREATE INDEX ix_vpeca_fun    ON venda_peca (cod_fun);
CREATE INDEX ix_vpeca_origem ON venda_peca (origem) WHERE excluido = 0;
CREATE INDEX ix_vpeca_data   ON venda_peca (data_venda) WHERE excluido = 0;

-- ---------------------------------------------------------------------------
-- CONSORCIO_COTA               ← legacy/CVBGRUPO.DBF + CVBGRUCO.DBF (5+3 reg.)
--   Unifica as duas tabelas do legado, que tinham estruturas quase idênticas
--   (CVBGRUCO acrescentava SORT e QUIT). A separação física era artifício do
--   modelo DBF; aqui `grupo_fechado` distingue os estados e o fechamento vira
--   um UPDATE atômico em vez de mover N registros sem transação (D-12).
--
--   Chave composta (cod_gru, num_participante): o legado a tinha de forma
--   implícita, sem índice que a materializasse, e a numeração colidia por
--   defeito de contagem (D-10). Aqui é UNIQUE.
--
--   parcelas_restantes: o legado subtraía sem piso em zero num campo N(2,0);
--   os dados reais contêm -2, -3 e '**' (overflow gravado pelo Clipper).
--   A coluna aceita apenas >= 0; valores que violam vão para NULL e o bruto
--   fica em parcelas_restantes_legado, com inconsistência registrada (D-11).
--
--   NUMPAG e NUMGRU do legado NÃO são portados: os REPLACE estavam comentados
--   e os campos estão 100% vazios em todos os registros (Q-06).
-- ---------------------------------------------------------------------------
CREATE TABLE consorcio_cota (
  id                        INTEGER PRIMARY KEY,
  cod_gru                   INTEGER NOT NULL CHECK (cod_gru > 0),
  num_participante          INTEGER NOT NULL CHECK (num_participante > 0),
  cod_cli                   INTEGER NOT NULL REFERENCES cliente(cod_cli)         ON DELETE RESTRICT,
  cod_car                   INTEGER NOT NULL REFERENCES modelo_veiculo(cod_car)  ON DELETE RESTRICT,
  valor_prestacao_cent      INTEGER NOT NULL DEFAULT 0 CHECK (valor_prestacao_cent >= 0),
  num_participantes_previsto INTEGER NOT NULL CHECK (num_participantes_previsto > 0),
  parcelas_restantes        INTEGER CHECK (parcelas_restantes IS NULL OR parcelas_restantes >= 0),
  parcelas_restantes_legado TEXT,
  data_adesao               TEXT    NOT NULL
                            CHECK (data_adesao GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                                   AND date(data_adesao) = data_adesao),
  grupo_fechado             INTEGER NOT NULL DEFAULT 0 CHECK (grupo_fechado IN (0,1)),
  sorteado                  INTEGER NOT NULL DEFAULT 0 CHECK (sorteado      IN (0,1)),
  quitado                   INTEGER NOT NULL DEFAULT 0 CHECK (quitado       IN (0,1)),
  nome_snapshot             TEXT,
  excluido                  INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1)),
  UNIQUE (cod_gru, num_participante)
) STRICT;

CREATE INDEX ix_cota_cli    ON consorcio_cota (cod_cli);
CREATE INDEX ix_cota_car    ON consorcio_cota (cod_car);
CREATE INDEX ix_cota_grupo  ON consorcio_cota (cod_gru, grupo_fechado);

-- ---------------------------------------------------------------------------
-- ORCAMENTO_REPARO                        ← legacy/CVREPAR.DBF + .DBT (4 reg.)
--   Tabela ÓRFÃ: existe com índice e memo, CVMTVREP.PRG declara variáveis para
--   ela, mas o USE está COMENTADO. O módulo foi projetado e abandonado (Q-04).
--
--   Migrada para não descartar informação do legado (briefing §24), com FKs
--   opcionais (o registro 4 está inteiramente em branco). NENHUM módulo da
--   aplicação lê ou grava esta tabela até que Q-04 seja respondida.
--   cod_orc permanece TEXT: é a chave natural e é textual no legado.
-- ---------------------------------------------------------------------------
CREATE TABLE orcamento_reparo (
  id                INTEGER PRIMARY KEY,
  cod_orc           TEXT,
  cod_cli           INTEGER REFERENCES cliente(cod_cli)     ON DELETE RESTRICT,
  cod_fun           INTEGER REFERENCES funcionario(cod_fun) ON DELETE RESTRICT,
  cod_pec           INTEGER REFERENCES peca(cod_pec)        ON DELETE RESTRICT,
  valor_cent        INTEGER CHECK (valor_cent IS NULL OR valor_cent >= 0),
  descricao         TEXT,
  data_orcamento    TEXT    CHECK (data_orcamento IS NULL OR
                      (data_orcamento GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                       AND date(data_orcamento) = data_orcamento)),
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

CREATE UNIQUE INDEX ux_orcamento_cod ON orcamento_reparo (cod_orc)
    WHERE cod_orc IS NOT NULL AND excluido = 0;

-- ---------------------------------------------------------------------------
-- PEDIDO                                        ← legacy/CVBPEDID.DBF (0 reg.)
--   Módulo CVMTPED.PRG não compila (IF sem ENDIF) e não é chamado por nenhum
--   menu. Estrutura preservada; RN-041 (código duplicado rejeitado) fica
--   garantida pela PK. Não implementado na aplicação.
-- ---------------------------------------------------------------------------
CREATE TABLE pedido (
  cod_ped           INTEGER PRIMARY KEY CHECK (cod_ped BETWEEN 1 AND 99999),
  cod_ite           INTEGER CHECK (cod_ite IS NULL OR cod_ite BETWEEN 0 AND 99999),
  desc_ite          TEXT,
  qtd_ite           INTEGER CHECK (qtd_ite IS NULL OR qtd_ite >= 0),
  excluido          INTEGER NOT NULL DEFAULT 0 CHECK (excluido IN (0,1))
) STRICT;

-- ===========================================================================
--  4. MOVIMENTO — nível 3
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- VENDA_PECA_ITEM                                  ← legacy/CVPECAS.DBF (75 reg.)
--   RN-026: subtotal = valor unitário × quantidade. Aritmética decimal exata,
--   preservada em centavos. O legado não arredondava explicitamente.
--   DECPEC era cópia desnormalizada — mantida como snapshot (D-19); há 1
--   divergência real (CODPEC=2: movimento 'FERRARI-F40', cadastro 'PARAFUSO').
--   valor_unit_cent NÃO existia em CVPECAS: é derivado de SUBTOT/QTPECC na
--   migração quando a quantidade é > 0, senão fica NULL.
-- ---------------------------------------------------------------------------
CREATE TABLE venda_peca_item (
  id                 INTEGER PRIMARY KEY,
  venda_id           INTEGER NOT NULL REFERENCES venda_peca(id) ON DELETE CASCADE,
  cod_pec            INTEGER NOT NULL REFERENCES peca(cod_pec)  ON DELETE RESTRICT,
  quantidade         INTEGER NOT NULL CHECK (quantidade >= 0),
  valor_unit_cent    INTEGER CHECK (valor_unit_cent IS NULL OR valor_unit_cent >= 0),
  subtotal_cent      INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_cent >= 0),
  descricao_snapshot TEXT,
  ordem              INTEGER NOT NULL DEFAULT 0   -- posição do item na venda
) STRICT;

CREATE INDEX ix_vpitem_venda ON venda_peca_item (venda_id);
CREATE INDEX ix_vpitem_peca  ON venda_peca_item (cod_pec);

-- ===========================================================================
--  5. APOIO
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- SEQUENCIA                                      ← legacy/CVMGRUPO.MEM
--   Substitui o único gerador de número do sistema legado, que vivia num
--   arquivo .MEM manipulado com SAVE TO / RESTORE FROM ADDITIVE (RN-013).
--   Agora é transacional: o número só é consumido se a cota for gravada
--   (o legado consumia antes da confirmação — ver doc 04 §8).
-- ---------------------------------------------------------------------------
CREATE TABLE sequencia (
  nome              TEXT    PRIMARY KEY,
  valor             INTEGER NOT NULL DEFAULT 0 CHECK (valor >= 0),
  descricao         TEXT
) STRICT;

INSERT INTO sequencia (nome, valor, descricao) VALUES
  ('consorcio_grupo', 0, 'Número do grupo de consórcio — ex-CVMGRUPO.MEM (MCODGRU)');

-- ===========================================================================
--  6. CONTROLE DE MIGRAÇÃO
-- ===========================================================================

CREATE TABLE migracao_execucao (
  id                 INTEGER PRIMARY KEY,
  iniciada_em        TEXT    NOT NULL,
  concluida_em       TEXT,
  origem             TEXT    NOT NULL,
  versao_schema      INTEGER NOT NULL,
  status             TEXT    NOT NULL
                     CHECK (status IN ('EM_ANDAMENTO','CONCLUIDA','FALHOU')),
  registros_lidos    INTEGER NOT NULL DEFAULT 0,
  registros_gravados INTEGER NOT NULL DEFAULT 0,
  inconsistencias    INTEGER NOT NULL DEFAULT 0
) STRICT;

-- Formato exigido pelo briefing §20: registro · campo · valor · problema · ação
CREATE TABLE migracao_inconsistencia (
  id                INTEGER PRIMARY KEY,
  execucao_id       INTEGER NOT NULL REFERENCES migracao_execucao(id) ON DELETE CASCADE,
  arquivo           TEXT    NOT NULL,   -- 'CVBCLIEN.DBF'
  registro          INTEGER NOT NULL,   -- RECNO() no arquivo original
  chave             TEXT,               -- 'CODCLI=24'
  campo             TEXT    NOT NULL,   -- 'CICCLI'
  valor_original    TEXT,               -- '88888888888-888'
  problema          TEXT    NOT NULL,
  acao              TEXT    NOT NULL,
  severidade        TEXT    NOT NULL CHECK (severidade IN ('BAIXA','MEDIA','ALTA'))
) STRICT;

CREATE INDEX ix_inconsist_exec ON migracao_inconsistencia (execucao_id, severidade);
CREATE INDEX ix_inconsist_arq  ON migracao_inconsistencia (arquivo, registro);

-- ===========================================================================
--  7. QUARENTENA — evidência do legado, fora do modelo de produção
--
--  Estas tabelas guardam dados que NÃO entram no modelo por serem agregados
--  dessincronizados, predecessores obsoletos ou resíduo de transferência.
--  Não participam de FK e não são lidas pela aplicação. Existem para permitir
--  reconciliação e para não descartar informação do legado (briefing §24).
--  Colunas TEXT sem constraint: guardam o valor BRUTO, antes de normalização.
-- ===========================================================================

-- CVVCAR.DBF — agregado de vendas por modelo. Diverge da contagem real em
-- até +12 (o rótulo 'TIPO 1.6 IE' nunca casou com 'TIPO 1.6 IE 2 PORTAS').
-- Substituído pela view v_venda_por_modelo (D-18).
CREATE TABLE _legado_cvvcar (
  registro          INTEGER PRIMARY KEY,
  descar            TEXT,
  quantv            TEXT
) STRICT;

-- CVVPEC.DBF — agregado de vendas por peça. Diverge da soma real em até
-- -11.062. Substituído pela view v_venda_por_peca (D-18).
CREATE TABLE _legado_cvvpec (
  registro          INTEGER PRIMARY KEY,
  despec            TEXT,
  quantc            TEXT
) STRICT;

-- CVCLIENT.DBF — predecessora de CVBCLIEN. Contém CODCLI=1 DUPLICADO
-- (registros 4 e 12) e nomes divergentes. Não migrada para produção.
CREATE TABLE _legado_cvclient (
  registro INTEGER PRIMARY KEY,
  codcli TEXT, nomcli TEXT, endcli TEXT, cepcli TEXT, ufcli  TEXT,
  telcli TEXT, rgcli  TEXT, ciccli TEXT, nascli TEXT, datcli TEXT,
  cidcli TEXT, consor TEXT, deletado INTEGER NOT NULL DEFAULT 0
) STRICT;

-- CVBGRUPO.DBF — registros marcados como excluídos pelo fechamento do grupo 1
-- (RN-018). São os MESMOS que estão em CVBGRUCO; não são reinseridos em
-- consorcio_cota para não colidir na chave (cod_gru, num_participante).
CREATE TABLE _legado_cvbgrupo_excluido (
  registro INTEGER PRIMARY KEY,
  codcon TEXT, nomcon TEXT, codcar TEXT, codgru TEXT, valpre TEXT,
  numpag TEXT, numgru TEXT, grufec TEXT, numpar TEXT, datcon TEXT,
  nummes TEXT, nupgru TEXT
) STRICT;

COMMIT;

-- ===========================================================================
--  VERIFICAÇÃO (executar após a carga)
--
--    PRAGMA foreign_keys;          -- deve retornar 1 na conexão da aplicação
--    PRAGMA foreign_key_check;     -- deve retornar vazio
--    PRAGMA integrity_check;       -- deve retornar 'ok'
--    PRAGMA user_version;          -- deve retornar 1
-- ===========================================================================
