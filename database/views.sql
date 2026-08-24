-- ===========================================================================
--  S.C.C.V. — Views
--  Aplicar DEPOIS de schema.sql.
--
--  Dois propósitos:
--
--  1. REPRODUZIR `SET DELETED ON` (docs/01-ARQUITETURA-LEGADO.md §2.1).
--     No legado, registros marcados como excluídos ficavam invisíveis a SEEK,
--     SKIP, COUNT, browse e relatórios. As views v_* preservam essa semântica:
--     a aplicação lê v_*, nunca a tabela base, exceto em operações
--     administrativas explícitas (purga, auditoria, restore).
--
--  2. SUBSTITUIR OS AGREGADOS MATERIALIZADOS (D-18).
--     CVVCAR e CVVPEC eram tabelas mantidas incrementalmente pelos módulos de
--     venda, com chave TEXTUAL (descrição de 35 caracteres). Divergiam dos
--     dados reais em até 11.062 unidades. Aqui são calculadas na consulta.
-- ===========================================================================

BEGIN;

-- ===========================================================================
--  1. Views de exclusão lógica (SET DELETED ON)
-- ===========================================================================

CREATE VIEW v_cliente          AS SELECT * FROM cliente          WHERE excluido = 0;
CREATE VIEW v_funcionario      AS SELECT * FROM funcionario      WHERE excluido = 0;
CREATE VIEW v_fornecedor       AS SELECT * FROM fornecedor       WHERE excluido = 0;
CREATE VIEW v_modelo_veiculo   AS SELECT * FROM modelo_veiculo   WHERE excluido = 0;
CREATE VIEW v_venda_veiculo    AS SELECT * FROM venda_veiculo    WHERE excluido = 0;
CREATE VIEW v_venda_peca       AS SELECT * FROM venda_peca       WHERE excluido = 0;
CREATE VIEW v_consorcio_cota   AS SELECT * FROM consorcio_cota   WHERE excluido = 0;
CREATE VIEW v_orcamento_reparo AS SELECT * FROM orcamento_reparo WHERE excluido = 0;
CREATE VIEW v_pedido           AS SELECT * FROM pedido           WHERE excluido = 0;

-- `peca` e `almoxarifado`: além da exclusão lógica, resolvem o nome do
-- fornecedor por JOIN. No legado esse nome era uma coluna copiada (NOMFOR /
-- NOMFORALM). Cadastro não tem valor histórico a preservar — ao contrário do
-- movimento, onde o snapshot é deliberado (D-19).
CREATE VIEW v_peca AS
  SELECT p.*, f.nome AS nome_fornecedor
    FROM peca p
    LEFT JOIN fornecedor f ON f.cod_for = p.cod_for
   WHERE p.excluido = 0;

CREATE VIEW v_almoxarifado AS
  SELECT a.*, f.nome AS nome_fornecedor
    FROM almoxarifado a
    LEFT JOIN fornecedor f ON f.cod_for = a.cod_for
   WHERE a.excluido = 0;

-- Itens não têm `excluido` próprio: seguem o cabeçalho (ON DELETE CASCADE).
CREATE VIEW v_venda_peca_item AS
  SELECT i.*
    FROM venda_peca_item i
    JOIN venda_peca v ON v.id = i.venda_id
   WHERE v.excluido = 0;

-- ===========================================================================
--  2. Agregados — substituem CVVCAR.DBF e CVVPEC.DBF (D-18)
--
--  Diferenças em relação ao legado, todas deliberadas:
--    · agrupam por CÓDIGO, não por descrição textual (a chave textual falhou:
--      'TIPO 1.6 IE' do agregado nunca casou com 'TIPO 1.6 IE 2 PORTAS');
--    · refletem os dados transacionais reais, sempre;
--    · ignoram vendas logicamente excluídas.
--
--  Os valores antigos ficam preservados em _legado_cvvcar / _legado_cvvpec
--  para reconciliação (docs/08-MIGRACAO-DADOS.md §9.5).
--
--  NOTA: nem estas views nem as tabelas do legado têm recorte temporal.
--  Os gráficos do legado se intitulavam "mensal" mas acumulavam desde sempre —
--  CVPECAS não possui campo de data (docs/06-RELATORIOS.md §2, R-11/R-12).
-- ===========================================================================

CREATE VIEW v_venda_por_modelo AS
  SELECT m.cod_car,
         m.descricao,
         COUNT(*)                       AS quantidade,
         COALESCE(SUM(v.valor_cent), 0) AS valor_total_cent
    FROM venda_veiculo v
    JOIN modelo_veiculo m ON m.cod_car = v.cod_car
   WHERE v.excluido = 0
   GROUP BY m.cod_car, m.descricao;

CREATE VIEW v_venda_por_peca AS
  SELECT p.cod_pec,
         p.descricao,
         COALESCE(SUM(i.quantidade), 0)    AS quantidade,
         COALESCE(SUM(i.subtotal_cent), 0) AS valor_total_cent
    FROM venda_peca_item i
    JOIN venda_peca v ON v.id = i.venda_id AND v.excluido = 0
    JOIN peca       p ON p.cod_pec = i.cod_pec
   GROUP BY p.cod_pec, p.descricao;

COMMIT;
