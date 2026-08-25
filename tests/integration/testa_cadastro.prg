/*
 * testa_cadastro.prg — critério de aceite da FASE G, onda 2
 *
 * Cadastros de nível 0: cliente, funcionário, fornecedor, modelo_veiculo.
 * Exercita o motor de cadastro contra um banco real, com o schema real.
 *
 * A tela é fina de propósito — quem valida e grava é o modelo. É por isso que
 * este teste consegue cobrir a regra inteira sem terminal nenhum.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-cadastro.db", hC, pDb

   ? "FASE G onda 2 — aceite dos cadastros de nível 0"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )

   TestaCliente( pDb )
   TestaValoresEmReais()
   TestaFuncionario( pDb )
   TestaFornecedor( pDb )
   TestaModeloVeiculo( pDb )
   TestaExclusao( pDb )
   TestaPeca( pDb )
   TestaAlmoxarifado( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "CADASTROS ACEITOS", "CADASTROS REPROVADOS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE TestaCliente( pDb )

   LOCAL hD := ClienteDescritor(), hRes, hReg, hVal

   ? "== cliente =="

   Vale( "primeiro código é 1", ModeloProximoCodigo( pDb, hD ), 1 )

   /* nome é obrigatório; CPF, UF e telefone não são (05 §9) */
   hRes := ModeloGravar( pDb, hD, Valores( hD, { "cod_cli" => 1 } ), .T. )
   Vale( "sem nome não grava", hRes[ "ok" ], .F. )
   Vale( "e diz qual campo", At( "Nome", hRes[ "mensagem" ] ) > 0, .T. )

   hVal := Valores( hD, { "cod_cli" => 1, "nome" => "BatMan" } )
   hRes := ModeloGravar( pDb, hD, hVal, .T. )
   Vale( "só com nome, grava", hRes[ "ok" ], .T. )

   hReg := ModeloObter( pDb, hD, 1 )
   Vale( "e volta pela view", hReg[ "nome" ], "BatMan" )
   Vale( "campos vazios ficam NULL, não ''", hReg[ "cidade" ], NIL )
   Vale( "consorcio recebe o padrão N", hReg[ "consorcio" ], "N" )
   Vale( "data_cadastro preenchida pelo sistema", ;
         SqlEscalar( pDb, "SELECT data_cadastro FROM cliente WHERE cod_cli=1" ), ;
         hb_DToC( Date(), "YYYY-MM-DD" ) )

   Vale( "próximo código agora é 2", ModeloProximoCodigo( pDb, hD ), 2 )

   /* normalização: a coluna guarda o valor limpo, a irmã guarda o digitado */
   hVal := Valores( hD, { "cod_cli" => 2, "nome" => "Bart Simpson", ;
      "cpf" => "111.444.777-35", "telefone" => "(0143)051-2382", ;
      "cep" => "18800-000", "uf" => "sp" } )
   hRes := ModeloGravar( pDb, hD, hVal, .T. )
   Vale( "grava com documentos", hRes[ "ok" ], .T. )
   hReg := ModeloObter( pDb, hD, 2 )
   Vale( "CPF só com dígitos", hReg[ "cpf" ], "11144477735" )
   Vale( "e o digitado preservado (V-03)", hReg[ "cpf_original" ], "111.444.777-35" )
   Vale( "cpf_valido = 1", SqlEscalar( pDb, "SELECT cpf_valido FROM cliente WHERE cod_cli=2" ), 1 )
   Vale( "telefone só com dígitos", hReg[ "telefone" ], "01430512382" )
   Vale( "com máscara preservada", hReg[ "telefone_original" ], "(0143)051-2382" )
   Vale( "CEP normalizado", hReg[ "cep" ], "18800000" )
   Vale( "UF em maiúscula", hReg[ "uf" ], "SP" )

   /* V-13 */
   hVal := Valores( hD, { "cod_cli" => 3, "nome" => "Outro", "cpf" => "111.444.777-35" } )
   hRes := ModeloGravar( pDb, hD, hVal, .T. )
   Vale( "CPF repetido é recusado (V-13)", hRes[ "ok" ], .F. )
   Vale( "com mensagem clara", At( "já está cadastrado", hRes[ "mensagem" ] ) > 0, .T. )

   /* código duplicado */
   hVal := Valores( hD, { "cod_cli" => 1, "nome" => "Colide" } )
   Vale( "código em uso é recusado", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .F. )

   /* alteração */
   hVal := Valores( hD, { "cod_cli" => 1, "nome" => "BatMan de Gotham", "uf" => "MA" } )
   Vale( "altera", ModeloGravar( pDb, hD, hVal, .F. )[ "ok" ], .T. )
   Vale( "e o valor mudou", ModeloObter( pDb, hD, 1 )[ "nome" ], "BatMan de Gotham" )
   Vale( "alterar não exige CPF único contra si mesmo", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_cli" => 2, ;
            "nome" => "Bart", "cpf" => "111.444.777-35" } ), .F. )[ "ok" ], .T. )

   /* V-08 como aviso, não erro */
   hVal := Valores( hD, { "cod_cli" => 4, "nome" => "Idoso", "nascimento" => "1901-01-01" } )
   hRes := ModeloGravar( pDb, hD, hVal, .T. )
   Vale( "nascimento de 1901 grava", hRes[ "ok" ], .T. )
   Vale( "mas com aviso (V-08)", ValTemAviso( hRes[ "validacao" ] ), .T. )

   /* UF inválida */
   Vale( "UF inexistente recusada", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_cli" => 5, "nome" => "X", ;
            "uf" => "RC" } ), .T. )[ "ok" ], .F. )

   RETURN

STATIC PROCEDURE TestaValoresEmReais()

   ? "== conversão de reais para centavos =="

   Vale( "1234,56", ValReais( "1234,56", "V" )[ "valor" ], 123456 )
   Vale( "1234.56", ValReais( "1234.56", "V" )[ "valor" ], 123456 )
   Vale( "1.234,56 (milhar)", ValReais( "1.234,56", "V" )[ "valor" ], 123456 )
   Vale( "1.234.567,89", ValReais( "1.234.567,89", "V" )[ "valor" ], 123456789 )
   Vale( "sem decimais", ValReais( "1500", "V" )[ "valor" ], 150000 )
   Vale( "1.500 é milhar, não decimal", ValReais( "1.500", "V" )[ "valor" ], 150000 )
   Vale( "0,01", ValReais( "0,01", "V" )[ "valor" ], 1 )
   Vale( "vazio vira zero", ValReais( "", "V" )[ "valor" ], 0 )
   Vale( "negativo recusado (V-16)", ValReais( "-10,00", "V" )[ "ok" ], .F. )
   Vale( "texto recusado", ValReais( "abc", "V" )[ "ok" ], .F. )

   RETURN

STATIC PROCEDURE TestaFuncionario( pDb )

   LOCAL hD := FuncionarioDescritor(), hVal, hReg

   ? "== funcionário =="

   hVal := Valores( hD, { "cod_fun" => 1, "nome" => "Vendedor Um", ;
      "salario_cent" => "2.500,00", "comissao_cent" => "1,5" } )
   Vale( "grava", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .T. )
   hReg := ModeloObter( pDb, hD, 1 )
   Vale( "salário em centavos", hReg[ "salario_cent" ], 250000 )
   Vale( "comissão em centavos", hReg[ "comissao_cent" ], 150 )
   Vale( "cargo vazio fica NULL", hReg[ "cargo" ], NIL )

   RETURN

STATIC PROCEDURE TestaFornecedor( pDb )

   LOCAL hD := FornecedorDescritor(), hVal, hReg

   ? "== fornecedor =="

   hVal := Valores( hD, { "cod_for" => 1, "nome" => "Fiat", ;
      "cnpj" => "11.222.333/0001-81", ;
      "observacoes" => "entrega às terças; falar com o Oswaldo" } )
   Vale( "grava", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .T. )
   hReg := ModeloObter( pDb, hD, 1 )
   Vale( "CNPJ normalizado", hReg[ "cnpj" ], "11222333000181" )
   Vale( "digitado preservado", hReg[ "cnpj_original" ], "11.222.333/0001-81" )
   Vale( "observações (ex-memo) gravadas", ;
         At( "Oswaldo", hReg[ "observacoes" ] ) > 0, .T. )

   Vale( "CNPJ inválido recusado", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_for" => 2, "nome" => "X", ;
            "cnpj" => "11.222.333/0001-82" } ), .T. )[ "ok" ], .F. )
   /* §9: fornecedor sem CNPJ continua válido */
   Vale( "fornecedor sem CNPJ é aceito", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_for" => 2, ;
            "nome" => "Sem documento" } ), .T. )[ "ok" ], .T. )

   RETURN

STATIC PROCEDURE TestaModeloVeiculo( pDb )

   LOCAL hD := ModeloVeiculoDescritor(), hVal, hReg, hRes

   ? "== modelo de veículo (frota) =="

   hVal := Valores( hD, { "cod_car" => 1, "descricao" => "Uno Mile ELX", ;
      "qtd_estoque" => 5, "valor_cent" => "12.500,00", ;
      "chassi_ini" => "100", "chassi_fim" => "200" } )
   Vale( "grava", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .T. )
   hReg := ModeloObter( pDb, hD, 1 )
   Vale( "descrição preservada com a caixa original", hReg[ "descricao" ], "Uno Mile ELX" )
   Vale( "valor em centavos", hReg[ "valor_cent" ], 1250000 )
   Vale( "chassi inicial", hReg[ "chassi_ini" ], 100 )

   /* V-18 — regra do conjunto, não de um campo isolado */
   hVal := Valores( hD, { "cod_car" => 2, "descricao" => "Invertido", ;
      "chassi_ini" => "200", "chassi_fim" => "100" } )
   hRes := ModeloGravar( pDb, hD, hVal, .T. )
   Vale( "faixa de chassi invertida recusada (V-18)", hRes[ "ok" ], .F. )
   Vale( "com mensagem explicando", At( "menor que o inicial", hRes[ "mensagem" ] ) > 0, .T. )

   Vale( "chassi vazio fica NULL, não zero", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_car" => 3, ;
            "descricao" => "Sem chassi" } ), .T. )[ "ok" ], .T. )
   Vale( "e é NULL mesmo", ModeloObter( pDb, hD, 3 )[ "chassi_ini" ], NIL )

   Vale( "quantidade negativa recusada (V-14)", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_car" => 4, "descricao" => "X", ;
            "qtd_estoque" => -1 } ), .T. )[ "ok" ], .F. )

   RETURN

/* V-17 — exclusão lógica que respeita quem depende do registro. */
STATIC PROCEDURE TestaExclusao( pDb )

   LOCAL hD := ClienteDescritor(), hRes

   ? "== exclusão lógica e integridade (V-17) =="

   Vale( "cliente sem dependência é excluído", ModeloExcluir( pDb, hD, 4 )[ "ok" ], .T. )
   Vale( "some da view", ModeloObter( pDb, hD, 4 ), NIL )
   Vale( "mas continua na tabela", ;
         SqlEscalar( pDb, "SELECT count(*) FROM cliente WHERE cod_cli=4" ), 1 )
   Vale( "e o código NÃO é reciclado (evita RN-015)", ;
         ModeloProximoCodigo( pDb, hD ) > 4, .T. )
   Vale( "excluir de novo é recusado", ModeloExcluir( pDb, hD, 4 )[ "ok" ], .F. )

   /* agora um cliente com venda */
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "BALCAO", 5000 } )
   hRes := ModeloExcluir( pDb, hD, 1 )
   Vale( "cliente com venda NÃO é excluído", hRes[ "ok" ], .F. )
   Vale( "e a mensagem diz onde está preso", ;
         At( "venda(s) de peça", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "o registro continua visível", ModeloObter( pDb, hD, 1 ) != NIL, .T. )

   RETURN

/*
 * Onda 3 — peça. Cobre os dois defeitos do legado que este cadastro não
 * reproduz: D-01 (a alteração corrompia a chave primária) e RN-036 (o nome do
 * fornecedor era copiado para dentro da peça).
 */
STATIC PROCEDURE TestaPeca( pDb )

   LOCAL hD := PecaDescritor(), hVal, hReg, hRes

   ? "== peça (onda 3) =="

   hVal := Valores( hD, { "cod_pec" => 10, "descricao" => "Vela de ignição", ;
      "qtd_estoque" => 20, "valor_unit_cent" => "12,95", ;
      "qtd_minima" => 5, "cod_for" => 1 } )
   Vale( "grava", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .T. )
   hReg := ModeloObter( pDb, hD, 10 )
   Vale( "valor unitário em centavos", hReg[ "valor_unit_cent" ], 1295 )
   Vale( "fornecedor gravado", hReg[ "cod_for" ], 1 )

   /* RN-036: o nome do fornecedor não é coluna da peça; vem por JOIN na view */
   Vale( "nome do fornecedor vem da view, não de cópia", ;
         SqlEscalar( pDb, "SELECT nome_fornecedor FROM v_peca WHERE cod_pec = 10" ), ;
         "Fiat" )
   Vale( "e peca não tem coluna de nome de fornecedor", ;
         SqlEscalar( pDb, "SELECT count(*) FROM pragma_table_info('peca')" + ;
                          " WHERE name LIKE '%nome%'" ), 0 )

   /* D-01 — no legado, alterar uma peça gravava o código do FORNECEDOR no
      campo de código da PEÇA. Aqui a chave não entra no UPDATE. */
   hVal := Valores( hD, { "cod_pec" => 10, "descricao" => "Vela alterada", ;
      "qtd_estoque" => 20, "qtd_minima" => 5, "cod_for" => 1 } )
   Vale( "altera", ModeloGravar( pDb, hD, hVal, .F. )[ "ok" ], .T. )
   Vale( "D-01: a chave da peça NÃO vira o código do fornecedor", ;
         ModeloObter( pDb, hD, 10 ) != NIL, .T. )
   Vale( "e a peça 1 (código do fornecedor) não foi criada", ;
         ModeloObter( pDb, hD, 1 ), NIL )
   Vale( "a descrição, essa sim, mudou", ;
         ModeloObter( pDb, hD, 10 )[ "descricao" ], "Vela alterada" )

   /* fornecedor inexistente */
   hRes := ModeloGravar( pDb, hD, Valores( hD, { "cod_pec" => 11, ;
      "descricao" => "Órfã", "cod_for" => 999 } ), .T. )
   Vale( "fornecedor inexistente é recusado", hRes[ "ok" ], .F. )
   Vale( "com mensagem clara", At( "não cadastrado", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "sem fornecedor é aceito", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_pec" => 11, ;
            "descricao" => "Sem fornecedor" } ), .T. )[ "ok" ], .T. )
   Vale( "e fica NULL", ModeloObter( pDb, hD, 11 )[ "cod_for" ], NIL )

   /* RN-028 — estoque abaixo do mínimo é aviso, não bloqueio (05 §9) */
   hRes := ModeloGravar( pDb, hD, Valores( hD, { "cod_pec" => 12, ;
      "descricao" => "Acabando", "qtd_estoque" => 1, "qtd_minima" => 10 } ), .T. )
   Vale( "estoque abaixo do mínimo GRAVA (RN-028)", hRes[ "ok" ], .T. )
   Vale( "mas avisa", ValTemAviso( hRes[ "validacao" ] ), .T. )

   RETURN

/*
 * Onda 3 — almoxarifado. D-14: o índice do legado era construído sobre a
 * tabela errada, então a verificação de duplicidade nunca encontrava nada.
 */
STATIC PROCEDURE TestaAlmoxarifado( pDb )

   LOCAL hD := AlmoxarifadoDescritor(), hVal, hRes

   ? "== almoxarifado (onda 3) =="

   hVal := Valores( hD, { "cod_alm" => 1, "descricao" => "Parafuso M8", ;
      "qtd_estoque" => 500, "valor_unit_cent" => "0,35", "qtd_minima" => 100 } )
   Vale( "grava", ModeloGravar( pDb, hD, hVal, .T. )[ "ok" ], .T. )
   Vale( "valor unitário de centavos baixos", ;
         ModeloObter( pDb, hD, 1 )[ "valor_unit_cent" ], 35 )

   /* D-14 — no legado esta duplicidade passava despercebida */
   hRes := ModeloGravar( pDb, hD, Valores( hD, { "cod_alm" => 1, ;
      "descricao" => "Duplicado" } ), .T. )
   Vale( "D-14: código duplicado é detectado", hRes[ "ok" ], .F. )
   Vale( "com mensagem clara", At( "já está em uso", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "e o registro original não foi tocado", ;
         ModeloObter( pDb, hD, 1 )[ "descricao" ], "Parafuso M8" )

   Vale( "próximo código é 2", ModeloProximoCodigo( pDb, hD ), 2 )
   Vale( "descrição obrigatória", ;
         ModeloGravar( pDb, hD, Valores( hD, { "cod_alm" => 2 } ), .T. )[ "ok" ], .F. )

   RETURN

/* Monta o hash de valores com todos os campos do descritor, vazios por padrão. */
STATIC FUNCTION Valores( hDesc, hInformados )

   LOCAL hVal := { => }, i, cNome, aChaves

   hVal[ hDesc[ "chave" ] ] := NIL
   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hVal[ hDesc[ "campos" ][ i ][ "nome" ] ] := ""
   NEXT
   aChaves := hb_HKeys( hInformados )
   FOR i := 1 TO Len( aChaves )
      cNome := aChaves[ i ]
      hVal[ cNome ] := hInformados[ cNome ]
   NEXT

   RETURN hVal

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
