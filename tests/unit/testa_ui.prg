/*
 * testa_ui.prg — critério de aceite da FASE G, onda 1 (interface)
 *
 * O desenho em si precisa de terminal e é verificado à mão. O que ESTE teste
 * cobre é tudo que foi deliberadamente separado do desenho para poder ser
 * verificado: a definição do menu, as consultas do lookup e do browse, e a
 * validação do formulário.
 *
 * Essa separação é o ponto: no legado, regra e desenho viviam juntos — a
 * validação morava na cláusula VALID de cada GET, espalhada por 27 programas.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main( cBanco )

   LOCAL pDb, hC

   hb_default( @cBanco, hb_DirTemp() + "testa-ui.db" )

   ? "FASE G onda 1 — aceite da interface"
   ?
   TestaMenu()

   /* banco de apoio com dados reais migrados */
   FErase( cBanco )
   hC  := ConexaoAbrir( cBanco, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   SemearDados( pDb )

   TestaLookup( pDb )
   TestaBrowse( pDb )
   TestaFormulario()
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "INTERFACE ACEITA", "INTERFACE REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE SemearDados( pDb )

   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, cidade, data_cadastro)" + ;
      " VALUES (?,?,?,?)", { 7, "BatMan", "Gottan CiTY", "1994-05-24" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, cidade, data_cadastro)" + ;
      " VALUES (?,?,?,?)", { 24, "Bart Simpson", "Springfield", "1994-06-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro, excluido)" + ;
      " VALUES (?,?,?,?)", { 99, "Excluído", "1994-06-01", 1 } )
   SqlExecBind( pDb, "INSERT INTO fornecedor (cod_for, nome) VALUES (?,?)", ;
      { 1, "Fiat" } )
   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque," + ;
      " valor_unit_cent, qtd_minima, cod_for) VALUES (?,?,?,?,?,?)", ;
      { 1, "Vela de ignição", 10, 12995, 2, 1 } )

   RETURN

STATIC PROCEDURE TestaMenu()

   LOCAL aDef := MenuDefinicao(), hCob, i, nItens := 0

   ? "== menu — a definição é dado, não desenho =="

   Vale( "cinco grupos, como no legado", Len( aDef ), 5 )
   Vale( "1º grupo é Clientes", aDef[ 1 ][ "titulo" ], "Clientes" )
   Vale( "5º grupo é Estoques", aDef[ 5 ][ "titulo" ], "Estoques" )
   /* as colunas são as do legado (04-FLUXOS.md §2) */
   Vale( "coluna do grupo 1", aDef[ 1 ][ "coluna" ], 1 )
   Vale( "coluna do grupo 2", aDef[ 2 ][ "coluna" ], 17 )
   Vale( "coluna do grupo 3", aDef[ 3 ][ "coluna" ], 33 )
   Vale( "coluna do grupo 4", aDef[ 4 ][ "coluna" ], 49 )
   Vale( "coluna do grupo 5", aDef[ 5 ][ "coluna" ], 63 )

   FOR i := 1 TO Len( aDef )
      nItens += Len( aDef[ i ][ "itens" ] )
      Vale( "grupo " + hb_ntos( i ) + " tem itens", Len( aDef[ i ][ "itens" ] ) > 0, .T. )
   NEXT
   /* 20 desde a onda 7, que acrescentou "Relatórios" ao grupo Serviços */
   Vale( "20 destinos declarados", nItens, 20 )

   /* o marcador de "pronto" tem de refletir a implementação real, não a
      declaração — senão o menu mente para o operador */
   hCob := MenuCobertura( {| c | HB_SYMBOL_UNUSED( c ), .F. } )
   Vale( "cobertura conta o total", hCob[ "total" ], 20 )
   Vale( "nada implementado na onda 1", hCob[ "implementados" ], 0 )
   hCob := MenuCobertura( {| c | c == "cliente.manutencao" } )
   Vale( "cobertura acompanha o predicado", hCob[ "implementados" ], 1 )

   RETURN

STATIC PROCEDURE TestaLookup( pDb )

   LOCAL aL

   ? "== lookup — substitui TABELA()/FUNDB() (D-02) =="

   aL := LookupLinhas( pDb, "cliente" )
   Vale( "traz os clientes ativos", Len( aL ), 2 )
   Vale( "sem o excluído (exclusão lógica)", ;
         AScan( aL, {| x | x[ 1 ] == 99 } ), 0 )
   Vale( "código na 1ª coluna", aL[ 1 ][ 1 ], 7 )
   Vale( "descrição na 2ª", aL[ 1 ][ 2 ], "BatMan" )
   Vale( "ordenado por código", aL[ 2 ][ 1 ], 24 )

   Vale( "filtro por texto funciona", Len( LookupLinhas( pDb, "cliente", "Bart" ) ), 1 )
   Vale( "filtro sem resultado devolve vazio", ;
         Len( LookupLinhas( pDb, "cliente", "Ninguém" ) ), 0 )

   /* o texto vem do operador: tem de ir como parâmetro */
   Vale( "aspas no filtro não quebram a consulta", ;
         Len( LookupLinhas( pDb, "cliente", "'; DROP TABLE cliente; --" ) ), 0 )
   Vale( "e a tabela continua lá", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente" ), 3 )

   Vale( "descrição por código", LookupDescricao( pDb, "cliente", 7 ), "BatMan" )
   Vale( "código inexistente devolve NIL", LookupDescricao( pDb, "cliente", 999 ), NIL )
   Vale( "título da entidade", LookupTitulo( "cliente" ), "Clientes" )
   Vale( "entidade desconhecida não explode", Len( LookupLinhas( pDb, "xpto" ) ), 0 )
   Vale( "seis entidades disponíveis", Len( LookupEntidades() ), 6 )
   Vale( "peça também é consultável", Len( LookupLinhas( pDb, "peca" ) ), 1 )

   RETURN

STATIC PROCEDURE TestaBrowse( pDb )

   LOCAL cSql := "SELECT cod_cli, nome, cidade FROM v_cliente", aL

   ? "== browse — consulta em grade =="

   aL := BrowseCarregar( pDb, cSql, "nome", "" )
   Vale( "sem filtro traz todos os ativos", Len( aL ), 2 )
   aL := BrowseCarregar( pDb, cSql, "nome", "Bat" )
   Vale( "com filtro restringe", Len( aL ), 1 )
   Vale( "e traz as colunas pedidas", Len( aL[ 1 ] ), 3 )
   Vale( "cidade vem junto", aL[ 1 ][ 3 ], "Gottan CiTY" )

   /* WHERE já presente na consulta base tem de virar AND */
   aL := BrowseCarregar( pDb, "SELECT cod_cli, nome FROM cliente WHERE excluido = 0", ;
                         "nome", "Bart" )
   Vale( "acrescenta AND quando já há WHERE", Len( aL ), 1 )

   Vale( "aspas no filtro não quebram", ;
         Len( BrowseCarregar( pDb, cSql, "nome", "' OR 1=1 --" ) ), 0 )

   /* @E é o formato europeu/brasileiro: vírgula decimal, ponto de milhar */
   Vale( "centavos formatados em pt-BR", AllTrim( BrowseMoeda( 12995 ) ), "129,95" )
   Vale( "milhar com ponto", AllTrim( BrowseMoeda( 123456789 ) ), "1.234.567,89" )
   Vale( "NIL vira vazio", BrowseMoeda( NIL ), "" )

   RETURN

STATIC PROCEDURE TestaFormulario()

   LOCAL hF, hV

   ? "== formulário — o campo declara seu validador =="

   hF := FormNovo( "Manutenção de clientes" )
   FormCampo( hF, "nome", "Nome", "C", 6, 10, 35, ;
              {| x | ValObrigatorio( x, "Nome" ) } )
   FormCampo( hF, "cpf", "CPF", "C", 7, 10, 14, {| x | ValCpf( x ) } )
   FormCampo( hF, "uf", "UF", "C", 8, 10, 2, {| x | ValUf( x ) } )
   FormCampo( hF, "nascimento", "Nascimento", "D", 9, 10, 10, ;
              {| x | ValNascimento( x ) } )

   Vale( "quatro campos declarados", Len( hF[ "campos" ] ), 4 )
   Vale( "valor inicial vazio", FormValor( hF, "nome" ), "" )

   /* tudo vazio: só o nome é obrigatório (§9 — CPF, UF e data não são) */
   hV := FormValidar( hF )
   Vale( "formulário vazio tem 1 erro", Len( hV[ "erros" ] ), 1 )
   Vale( "e é o do nome", At( "Nome", hV[ "erros" ][ 1 ][ "mensagem" ] ) > 0, .T. )

   FormDefinir( hF, "nome", "BatMan" )
   Vale( "com nome, fica válido", ValOk( FormValidar( hF ) ), .T. )

   FormDefinir( hF, "cpf", "111.444.777-36" )
   Vale( "CPF com DV errado invalida", ValOk( FormValidar( hF ) ), .F. )
   Vale( "mensagem traz o rótulo do campo", ;
         At( "CPF:", FormValidar( hF )[ "erros" ][ 1 ][ "mensagem" ] ) > 0, .T. )

   /* o valor normalizado substitui o digitado — é o defeito V-03 do legado,
      que gravava a máscara junto com o dado */
   FormDefinir( hF, "cpf", "111.444.777-35" )
   FormDefinir( hF, "uf", "sp" )
   hV := FormValidar( hF )
   Vale( "formulário válido", ValOk( hV ), .T. )
   Vale( "CPF gravado só com dígitos", FormValor( hF, "cpf" ), "11144477735" )
   Vale( "UF normalizada para maiúscula", FormValor( hF, "uf" ), "SP" )

   FormDefinir( hF, "uf", "RC" )
   Vale( "UF inexistente invalida", ValOk( FormValidar( hF ) ), .F. )

   RETURN

STATIC PROCEDURE Vale( cDesc, xObtido, xEsperado )
   LOCAL lOk := ( ValType( xObtido ) == ValType( xEsperado ) .AND. ;
                  hb_ValToExp( xObtido ) == hb_ValToExp( xEsperado ) )
   IF lOk
      s_nOk++
      ? "   ok   " + cDesc
   ELSE
      s_nFalhas++
      ? "   FALHA " + cDesc
      ? "         esperado: " + hb_ValToExp( xEsperado )
      ? "         obtido..: " + hb_ValToExp( xObtido )
   ENDIF
   RETURN
