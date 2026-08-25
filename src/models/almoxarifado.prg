/*
 * almoxarifado.prg — FASE G, onda 3
 *
 * Almoxarifado (ex-CVBALMOX). Estrutura igual à de peças; o que muda é a
 * tabela e o nome do campo de fornecedor no legado (CODFORALM).
 *
 * D-14 — no legado, o índice `CVIALM1` era criado sobre `CVALMOX` (código
 * `C(6)`) e usado sobre `CVBALMOX` (código `N(6)`): SEEK numérico contra índice
 * de caractere nunca encontra. Na prática o cadastro provavelmente sempre
 * tratou todo código como novo, sem detectar duplicata — os 4 registros do
 * acervo têm códigos 1..4 sequenciais, compatíveis com isso.
 *
 * Aqui a duplicidade é detectada porque a verificação é uma consulta pela
 * chave, e não uma busca em índice que pode estar construído sobre outra
 * tabela. Não há o que "corrigir" no código: o defeito era estrutural e
 * desaparece com o modelo relacional.
 */

FUNCTION AlmoxarifadoDescritor()
   RETURN { ;
      "entidade" => "almoxarifado", ;
      "tabela"   => "almoxarifado", ;
      "view"     => "v_almoxarifado", ;
      "chave"    => "cod_alm", ;
      "titulo"   => "Manutenção do Almoxarifado", ;
      "campos"   => { ;
         ModeloCampo( "descricao"      , "Descrição"  , "C", 35, {| x | ValObrigatorio( x, "Descrição" ) } ), ;
         ModeloCampo( "qtd_estoque"    , "Quantidade" , "N",  5, {| x | ValQuantidade( x, "Quantidade" ) } ), ;
         ModeloCampo( "valor_unit_cent", "Valor unit.", "$", 14, {| x | ValReais( x, "Valor unitário" ) } ), ;
         ModeloCampo( "qtd_minima"     , "Estoque mín.", "N", 5, {| x | ValQuantidade( x, "Estoque mínimo" ) } ), ;
         ModeloCampo( "cod_for"        , "Fornecedor" , "N",  6, {| x | ValCodigoOpcional( x, "Fornecedor" ) } ) }, ;
      "defaults" => { => }, ;
      "validador_extra" => {| pDb, hVal, hV, lNovo | EstoqueExtra( pDb, hVal, hV, lNovo, "cod_for" ) } }
