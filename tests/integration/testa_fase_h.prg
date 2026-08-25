/*
 * testa_fase_h.prg — critério de aceite da FASE H
 *
 * "Implementar V-01..V-20 (05 §8), respeitando as proibições de 05 §9."
 *
 * As validações foram implementadas nas ondas 1 e 4 da FASE G. O que ESTE teste
 * entrega é o que faltava para a fase fechar: a verificação NOMINAL, uma a uma,
 * ligando cada V-nn a um comportamento observável — de preferência com um valor
 * real do acervo de 1994.
 *
 * Isso existe para a FASE J poder auditar. Uma matriz que diz "implementado"
 * sem apontar onde isso é verificável não é rastreabilidade, é afirmação.
 *
 * O §9 é tão normativo quanto o §8: cada proibição também é verificada, porque
 * uma validação que barra cadastro legítimo é regressão, não melhoria.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0
STATIC s_aMatriz := {}

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-fase-h.db", hC, pDb

   ? "FASE H — verificação nominal de V-01 a V-20"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )

   Documentos()
   Contato( pDb )
   Datas()
   Dominio()
   Numeros()
   Integridade( pDb )
   Estruturais( pDb )
   Proibicoes()
   Matriz()

   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "FASE H ACEITA", "FASE H REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

/* ------------------------------------------------------------------ */

STATIC PROCEDURE Documentos()

   ? "== V-01 a V-03 — documentos =="

   /* V-01: nenhum dos 22 CPFs do acervo tem DV válido; um exemplo real */
   V( "V-01", "dígito verificador de CPF", ;
      !ValCpf( "666.666.666-66" )[ "ok" ] .AND. ValCpf( "111.444.777-35" )[ "ok" ] )
   /* V-02: valores reais de CVBFORNE.CGCFAB */
   V( "V-02", "dígito verificador de CNPJ", ;
      !ValCnpj( "27439872194873285783" )[ "ok" ] .AND. ;
      !ValCnpj( "3484378438743]" )[ "ok" ] .AND. ;
      ValCnpj( "11.222.333/0001-81" )[ "ok" ] )
   /* V-03: a coluna guarda só dígitos; a máscara vai para a irmã */
   V( "V-03", "normalização de CPF/CNPJ", ;
      ValCpf( "111.444.777-35" )[ "valor" ] == "11144477735" .AND. ;
      ValCnpj( "11.222.333/0001-81" )[ "valor" ] == "11222333000181" )

   RETURN

STATIC PROCEDURE Contato( pDb )

   LOCAL aCols, i, nTexto := 0

   ? "== V-04 a V-06 — contato =="

   /* V-04: valores reais de CVBCLIEN.CEPCLI e CVBFUNC.CEPFUN */
   V( "V-04", "formato de CEP (8 dígitos)", ;
      !ValCep( "798797" )[ "ok" ] .AND. !ValCep( "5877" )[ "ok" ] .AND. ;
      ValCep( "188000-00" )[ "valor" ] == "18800000" )

   /* V-05: no legado era N(8) em cliente e C(9) em fornecedor/funcionário */
   aCols := SqlLinhas( pDb, "SELECT type FROM pragma_table_info('cliente')" + ;
      " WHERE name = 'cep' UNION ALL SELECT type FROM pragma_table_info('fornecedor')" + ;
      " WHERE name = 'cep' UNION ALL SELECT type FROM pragma_table_info('funcionario')" + ;
      " WHERE name = 'cep'" )
   FOR i := 1 TO Len( aCols )
      IF aCols[ i ][ 1 ] == "TEXT"
         nTexto++
      ENDIF
   NEXT
   V( "V-05", "tipo de CEP consistente nas três tabelas", ;
      Len( aCols ) == 3 .AND. nTexto == 3 )

   /* V-06: valor real de CVBCLIEN.TELCLI; o DDD pré-1999 NÃO é convertido */
   V( "V-06", "normalização de telefone", ;
      ValTelefone( "(0143)051-2382" )[ "valor" ] == "01430512382" )

   RETURN

STATIC PROCEDURE Datas()

   ? "== V-07 a V-09 — datas =="

   /* V-07: o legado gravava ano de 2 dígitos com SET EPOCH, gerando 1910 */
   V( "V-07", "ano de 4 dígitos exigido", ;
      !ValData( "10/10/10" )[ "ok" ] .AND. ValData( "1994-06-30" )[ "ok" ] )
   /* V-08: valores reais de CVBCLIEN.NASCLI */
   V( "V-08", "faixa de data de nascimento", ;
      ValNascimentoSuspeito( "1901-01-01" ) .AND. ;
      ValNascimentoSuspeito( "1911-11-11" ) .AND. ;
      !ValNascimentoSuspeito( "1956-10-10" ) .AND. ;
      !ValNascimento( hb_DToC( Date() + 1, "YYYY-MM-DD" ) )[ "ok" ] )
   /* V-09: valor real de CVBPENT.DATAV */
   V( "V-09", "data de evento não futura", ;
      !ValDataEvento( hb_DToC( Date() + 1, "YYYY-MM-DD" ) )[ "ok" ] .AND. ;
      ValDataEvento( "1901-11-11" )[ "ok" ] )

   RETURN

STATIC PROCEDURE Dominio()

   ? "== V-10 a V-12 — domínio e obrigatoriedade =="

   /* V-10: a lista do legado omitia SC e TO e continha FN e RC */
   V( "V-10", "lista de UFs completa e correta", ;
      ValUf( "SC" )[ "ok" ] .AND. ValUf( "TO" )[ "ok" ] .AND. ;
      !ValUf( "FN" )[ "ok" ] .AND. !ValUf( "RC" )[ "ok" ] .AND. ;
      Len( ValUfLista() ) == 27 )
   /* V-11: o legado usava `$`, que aceita prefixo e string vazia */
   V( "V-11", "igualdade exata em vez de substring", ;
      !ValUf( "S" )[ "ok" ] .AND. !ValSimNao( "SIM" )[ "ok" ] )
   /* V-12: o fornecedor 2 do acervo tem 9 de 11 campos vazios */
   V( "V-12", "obrigatoriedade de nome", ;
      !ValObrigatorio( "", "Nome" )[ "ok" ] .AND. ;
      !ValObrigatorio( "   ", "Nome" )[ "ok" ] )

   RETURN

STATIC PROCEDURE Numeros()

   ? "== V-14 a V-16, V-18, V-19 — números e faixas =="

   V( "V-14", "quantidade não negativa", ;
      !ValQuantidade( -1, "Qtde" )[ "ok" ] .AND. ValQuantidade( 0, "Qtde" )[ "ok" ] )
   /* V-15: o acervo tem -2 e -3 gravados em CVBGRUCO.NUMMES */
   V( "V-15", "prestações restantes >= 0", ;
      !ValParcelas( -2, "Parcelas" )[ "ok" ] .AND. ;
      !ValParcelas( -3, "Parcelas" )[ "ok" ] )
   V( "V-16", "valor monetário não negativo", ;
      !ValMonetario( -1, "Valor" )[ "ok" ] .AND. !ValReais( "-10,00", "Valor" )[ "ok" ] )
   V( "V-18", "coerência da faixa de chassi", ;
      !ValFaixaChassi( 200, 100 )[ "ok" ] .AND. ValFaixaChassi( 100, 200 )[ "ok" ] )
   V( "V-19", "valor cabe no campo", ;
      !ValTamanho( Replicate( "x", 36 ), 35, "Nome" )[ "ok" ] .AND. ;
      ValTamanho( "BatMan", 35, "Nome" )[ "ok" ] )

   RETURN

STATIC PROCEDURE Integridade( pDb )

   LOCAL hR

   ? "== V-13 e V-17 — integridade =="

   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, cpf, data_cadastro)" + ;
      " VALUES (?,?,?,?)", { 1, "COM CPF", "11144477735", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
      " VALUES (?,?,?)", { 2, "COM VENDA", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 2, "BALCAO", 1000 } )

   V( "V-13", "unicidade de CPF", ;
      !IntegCpfUnico( pDb, "11144477735" )[ "ok" ] .AND. ;
      IntegCpfUnico( pDb, "11144477735", 1 )[ "ok" ] )

   hR := IntegPodeExcluir( pDb, "cliente", 2 )
   V( "V-17", "integridade referencial na exclusão", ;
      !hR[ "ok" ] .AND. At( "venda(s) de peça", hR[ "mensagem" ] ) > 0 .AND. ;
      IntegPodeExcluir( pDb, "cliente", 1 )[ "ok" ] )

   RETURN

/* V-20 é estrutural: os agregados deixaram de ser tabela materializada. */
STATIC PROCEDURE Estruturais( pDb )

   LOCAL nAntes, nDepois, nId

   ? "== V-20 — sincronismo dos agregados =="

   SqlExecBind( pDb, "INSERT INTO peca (cod_pec, descricao, qtd_estoque," + ;
      " valor_unit_cent) VALUES (?,?,?,?)", { 1, "MOLAS", 100, 1000 } )
   nAntes := SqlEscalar( pDb, "SELECT IFNULL(SUM(quantidade),0) FROM v_venda_por_peca" )

   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "BALCAO", 5000 } )
   nId := SqlUltimoId( pDb )
   SqlExecBind( pDb, "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
      " subtotal_cent, ordem) VALUES (?,?,?,?,?)", { nId, 1, 5, 5000, 1 } )

   nDepois := SqlEscalar( pDb, "SELECT IFNULL(SUM(quantidade),0) FROM v_venda_por_peca" )

   /* no legado, CVVPEC era mantida à parte e divergia em até 11.062 unidades */
   V( "V-20", "agregado acompanha o movimento sem manutenção", ;
      nDepois == nAntes + 5 )

   RETURN

/*
 * O §9 lista o que NÃO deve virar obrigatório. Cada asserção aqui protege um
 * cadastro que o legado aceitava — barrá-lo seria regressão disfarçada de rigor.
 */
STATIC PROCEDURE Proibicoes()

   ? "== 05 §9 — o que NÃO pode virar obrigatório =="

   P( "CPF obrigatório", ValCpf( "" )[ "ok" ] )
   P( "CNPJ obrigatório", ValCnpj( "" )[ "ok" ] )
   P( "telefone obrigatório", ValTelefone( "" )[ "ok" ] )
   P( "CEP obrigatório", ValCep( "" )[ "ok" ] )
   P( "UF obrigatória", ValUf( "" )[ "ok" ] )
   P( "data de nascimento obrigatória", ValNascimento( "" )[ "ok" ] )
   P( "data de venda obrigatória", ValDataEvento( "" )[ "ok" ] )
   /* RN-028 é ALERTA com confirmação, não bloqueio */
   P( "bloqueio de venda abaixo do estoque mínimo", ;
      !EstoqueInsuficiente( 10, 7 ) .AND. EstoqueAbaixoDoMinimo( 10, 4, 7 ) )
   /* RN-035 é aviso posterior à baixa, não impedimento */
   P( "bloqueio de venda com frota zerada antes da baixa", ;
      !EstoqueInsuficiente( 1, 1 ) )

   RETURN

STATIC PROCEDURE Matriz()

   LOCAL i, nFalta := 0, cId

   ? ""
   ? "== rastreabilidade V-01..V-20 =="
   FOR i := 1 TO 20
      cId := "V-" + StrZero( i, 2 )
      IF AScan( s_aMatriz, {| x | x == cId } ) == 0
         ? "   FALTA " + cId + " — sem verificação nominal"
         nFalta++
      ENDIF
   NEXT
   Vale( "as 20 validações têm verificação nominal", nFalta, 0 )
   ? "   (V-13 e V-17 dependem do banco; V-05 e V-20 são estruturais)"

   RETURN

/* ------------------------------------------------------------------ */

STATIC PROCEDURE V( cId, cDesc, lOk )
   AAdd( s_aMatriz, cId )
   Vale( cId + " — " + cDesc, lOk, .T. )
   RETURN

STATIC PROCEDURE P( cDesc, lPermitido )
   Vale( "NÃO introduzido: " + cDesc, lPermitido, .T. )
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
