/*
 * fornecedor.prg — FASE G, onda 2
 *
 * `observacoes` é o antigo memo OBSFOR (.DBT). No SQLite é apenas TEXT, sem
 * arquivo separado e sem limite de bloco. O campo é do tipo "M": a tela abre um
 * editor de várias linhas, como o MEMOEDIT do legado — um campo de uma linha
 * truncaria o texto do acervo, que tem duas linhas e cem caracteres.
 */

FUNCTION FornecedorDescritor()
   RETURN { ;
      "entidade" => "fornecedor", ;
      "tabela"   => "fornecedor", ;
      "view"     => "v_fornecedor", ;
      "chave"    => "cod_for", ;
      "titulo"   => "Manutenção de Fornecedores", ;
      "campos"   => { ;
         ModeloCampo( "nome"       , "Nome"       , "C", 35, {| x | ValObrigatorio( x, "Nome" ) } ), ;
         ModeloCampo( "telefone"   , "Telefone"   , "C", 14, {| x | ValTelefone( x ) }, "telefone_original" ), ;
         ModeloCampo( "cep"        , "CEP"        , "C",  9, {| x | ValCep( x ) }, "cep_original" ), ;
         ModeloCampo( "cidade"     , "Cidade"     , "C", 20, {| x | ValTamanho( x, 20, "Cidade" ) } ), ;
         ModeloCampo( "endereco"   , "Endereço"   , "C", 45, {| x | ValTamanho( x, 45, "Endereço" ) } ), ;
         ModeloCampo( "cod_item"   , "Cód. item"  , "C",  6, {| x | ValTamanho( x, 6, "Cód. item" ) } ), ;
         ModeloCampo( "desc_item"  , "Item"       , "C", 35, {| x | ValTamanho( x, 35, "Item" ) } ), ;
         ModeloCampo( "fabrica"    , "Fábrica"    , "C", 30, {| x | ValTamanho( x, 30, "Fábrica" ) } ), ;
         ModeloCampo( "cnpj"       , "CNPJ"       , "C", 18, {| x | ValCnpj( x ) }, "cnpj_original", "cnpj_valido" ), ;
         ModeloCampo( "observacoes", "Observações", "M", 60, NIL ) }, ;
      "defaults" => { => } }
