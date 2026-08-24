/*
 * testa_validacao.prg — critério de aceite da FASE G onda 1 (validação) e H
 *
 * Cobre V-01 a V-19 de docs/05-VALIDACOES-LEGADO.md §8, e — igualmente
 * importante — a lista do §9: o que o legado permitia e NÃO pode virar
 * obrigatório. Uma validação nova que barra cadastro legítimo é regressão,
 * não melhoria.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   ? "FASE G/H — aceite das validações"
   ?
   TestaDocumentos()
   TestaContato()
   TestaDatas()
   TestaDominio()
   TestaNumeros()
   TestaNaoObrigatorio()
   TestaAcumulador()
   TestaIntegridade()
   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "VALIDAÇÕES ACEITAS", "VALIDAÇÕES REPROVADAS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE TestaDocumentos()

   ? "== V-01 / V-02 — CPF e CNPJ =="

   Vale( "CPF válido aceito", ValCpf( "111.444.777-35" )[ "ok" ], .T. )
   Vale( "e normalizado para dígitos", ValCpf( "111.444.777-35" )[ "valor" ], "11144477735" )
   Vale( "DV errado recusado", ValCpf( "111.444.777-36" )[ "ok" ], .F. )
   Vale( "com mensagem sobre o DV", ;
         At( "dígito verificador", ValCpf( "111.444.777-36" )[ "mensagem" ] ) > 0, .T. )
   Vale( "sequência repetida recusada", ValCpf( "111.111.111-11" )[ "ok" ], .F. )
   Vale( "comprimento errado recusado", ValCpf( "1234567890" )[ "ok" ], .F. )
   Vale( "mensagem diz quantos dígitos vieram", ;
         At( "10", ValCpf( "1234567890" )[ "mensagem" ] ) > 0, .T. )

   /* valores reais do acervo */
   Vale( "CPF do acervo (15 díg.) recusado", ValCpf( "666666666666666" )[ "ok" ], .F. )
   Vale( "CPF do acervo ('/7556465464') recusado", ValCpf( "/7556465464" )[ "ok" ], .F. )

   Vale( "CNPJ válido aceito", ValCnpj( "11.222.333/0001-81" )[ "ok" ], .T. )
   Vale( "e normalizado", ValCnpj( "11.222.333/0001-81" )[ "valor" ], "11222333000181" )
   Vale( "DV errado recusado", ValCnpj( "11.222.333/0001-82" )[ "ok" ], .F. )
   Vale( "CNPJ do acervo (20 díg.) recusado", ValCnpj( "27439872194873285783" )[ "ok" ], .F. )
   Vale( "CNPJ do acervo (13 díg.) recusado", ValCnpj( "3484378438743]" )[ "ok" ], .F. )

   /* a regra é a mesma da migração — uma implementação só */
   Vale( "ValidaDvOk concorda com o normalizador (válido)", ;
         ValidaDvOk( "11144477735", 11 ), .T. )
   Vale( "ValidaDvOk concorda com o normalizador (inválido)", ;
         ValidaDvOk( "11144477736", 11 ), .F. )
   Vale( "normalizador usa a mesma regra", NormCpf( "111.444.777-35" )[ "valido" ], 1 )

   RETURN

STATIC PROCEDURE TestaContato()

   ? "== V-04 / V-06 — CEP e telefone =="

   Vale( "CEP de 8 dígitos aceito", ValCep( "18800-000" )[ "ok" ], .T. )
   Vale( "e normalizado", ValCep( "18800-000" )[ "valor" ], "18800000" )
   Vale( "CEP curto recusado", ValCep( "5877" )[ "ok" ], .F. )
   Vale( "CEP do acervo (6 díg.) recusado", ValCep( "798797" )[ "ok" ], .F. )
   /* 188000-00: a máscara move o hífen, mas os 8 dígitos são válidos */
   Vale( "máscara torta com 8 dígitos é aceita", ValCep( "188000-00" )[ "ok" ], .T. )
   Vale( "e normaliza para os 8 dígitos", ValCep( "188000-00" )[ "valor" ], "18800000" )

   Vale( "telefone com DDD pré-1999 aceito (D-24)", ;
         ValTelefone( "(0143)051-2382" )[ "ok" ], .T. )
   Vale( "e o zero do prefixo é mantido", ;
         ValTelefone( "(0143)051-2382" )[ "valor" ], "01430512382" )
   Vale( "telefone local de 8 dígitos aceito", ValTelefone( "3351-2382" )[ "ok" ], .T. )
   Vale( "celular de 11 dígitos aceito", ValTelefone( "(14) 99999-8888" )[ "ok" ], .T. )
   Vale( "telefone curto demais recusado", ValTelefone( "1234" )[ "ok" ], .F. )
   Vale( "telefone longo demais recusado", ValTelefone( "123456789012" )[ "ok" ], .F. )

   RETURN

STATIC PROCEDURE TestaDatas()

   ? "== V-07 / V-08 / V-09 — datas =="

   Vale( "data ISO válida aceita", ValData( "1994-06-30" )[ "ok" ], .T. )
   Vale( "31 de fevereiro recusado", ValData( "1994-02-31" )[ "ok" ], .F. )
   Vale( "formato DD/MM/AAAA recusado", ValData( "30/06/1994" )[ "ok" ], .F. )
   Vale( "mensagem indica o formato", ;
         At( "AAAA-MM-DD", ValData( "30/06/1994" )[ "mensagem" ] ) > 0, .T. )

   Vale( "nascimento plausível aceito", ValNascimento( "1956-10-10" )[ "ok" ], .T. )
   Vale( "e não é suspeito", ValNascimentoSuspeito( "1956-10-10" ), .F. )
   /* V-08 em dois níveis: 1901 é possível e improvável — avisa, não bloqueia */
   Vale( "nascimento de 1901 é aceito", ValNascimento( "1901-01-01" )[ "ok" ], .T. )
   Vale( "mas marcado como suspeito", ValNascimentoSuspeito( "1901-01-01" ), .T. )
   Vale( "1911 também é suspeito", ValNascimentoSuspeito( "1911-11-11" ), .T. )
   Vale( "acima de 130 anos é recusado", ;
         ValNascimento( hb_ntos( Year( Date() ) - 131 ) + "-01-01" )[ "ok" ], .F. )
   Vale( "nascimento no futuro recusado", ;
         ValNascimento( hb_DToC( Date() + 1, "YYYY-MM-DD" ) )[ "ok" ], .F. )

   Vale( "data de evento passada aceita", ValDataEvento( "1994-06-30" )[ "ok" ], .T. )
   Vale( "data de evento futura recusada", ;
         ValDataEvento( hb_DToC( Date() + 1, "YYYY-MM-DD" ) )[ "ok" ], .F. )
   Vale( "data anterior a 1970 é sinalizável", ValDataAntiga( "1910-10-10" ), .T. )
   Vale( "e 1994 não é", ValDataAntiga( "1994-06-30" ), .F. )

   RETURN

STATIC PROCEDURE TestaDominio()

   ? "== V-10 / V-11 — UF e comparação exata =="

   Vale( "SP aceita", ValUf( "SP" )[ "ok" ], .T. )
   /* SC e TO faltavam na lista do legado */
   Vale( "SC aceita (faltava no legado)", ValUf( "SC" )[ "ok" ], .T. )
   Vale( "TO aceita (faltava no legado)", ValUf( "TO" )[ "ok" ], .T. )
   /* FN e RC existiam na lista do legado e não são UFs */
   Vale( "FN recusada (existia no legado)", ValUf( "FN" )[ "ok" ], .F. )
   Vale( "RC recusada (existia no legado)", ValUf( "RC" )[ "ok" ], .F. )
   Vale( "minúscula é normalizada", ValUf( "sp" )[ "valor" ], "SP" )
   /* V-11: o legado usava $, que aceita prefixo e string vazia */
   Vale( "prefixo 'S' recusado (o legado aceitaria)", ValUf( "S" )[ "ok" ], .F. )
   Vale( "a lista tem 27 unidades", Len( ValUfLista() ), 27 )
   Vale( "27 UFs conferem", ValUf( "DF" )[ "ok" ], .T. )

   RETURN

STATIC PROCEDURE TestaNumeros()

   ? "== V-14 / V-15 / V-16 / V-18 / V-19 — números e faixas =="

   Vale( "quantidade positiva aceita", ValQuantidade( 5, "Quantidade" )[ "ok" ], .T. )
   Vale( "zero aceito", ValQuantidade( 0, "Quantidade" )[ "ok" ], .T. )
   Vale( "negativa recusada (V-14)", ValQuantidade( -1, "Quantidade" )[ "ok" ], .F. )
   Vale( "fracionária recusada", ValQuantidade( 1.5, "Quantidade" )[ "ok" ], .F. )

   Vale( "monetário positivo aceito", ValMonetario( 200000, "Valor" )[ "ok" ], .T. )
   Vale( "monetário negativo recusado (V-16)", ValMonetario( -1, "Valor" )[ "ok" ], .F. )

   /* V-15 — os valores reais que o legado gravou */
   Vale( "parcelas -2 recusadas (V-15)", ValParcelas( -2, "Parcelas restantes" )[ "ok" ], .F. )
   Vale( "mensagem explica a origem", ;
         At( "piso em zero", ValParcelas( -2, "Parcelas" )[ "mensagem" ] ) > 0, .T. )
   Vale( "parcelas 0 aceitas", ValParcelas( 0, "Parcelas" )[ "ok" ], .T. )

   Vale( "faixa de chassi coerente aceita", ValFaixaChassi( 100, 200 )[ "ok" ], .T. )
   Vale( "faixa invertida recusada (V-18)", ValFaixaChassi( 200, 100 )[ "ok" ], .F. )
   Vale( "faixa com um lado vazio é aceita", ValFaixaChassi( 100, NIL )[ "ok" ], .T. )

   Vale( "texto dentro do limite aceito", ValTamanho( "BatMan", 35, "Nome" )[ "ok" ], .T. )
   Vale( "texto acima do limite recusado (V-19)", ;
         ValTamanho( Replicate( "x", 36 ), 35, "Nome" )[ "ok" ], .F. )

   Vale( "código válido aceito", ValCodigo( 7, "Código" )[ "ok" ], .T. )
   Vale( "código zero recusado", ValCodigo( 0, "Código" )[ "ok" ], .F. )
   Vale( "código acima do limite recusado", ValCodigo( 100000, "Código" )[ "ok" ], .F. )
   Vale( "código em texto é convertido", ValCodigo( "  7", "Código" )[ "valor" ], 7 )

   RETURN

/*
 * O §9 é tão normativo quanto o §8: estas validações NÃO devem existir.
 * Cada asserção aqui protege um cadastro que o legado aceitava.
 */
STATIC PROCEDURE TestaNaoObrigatorio()

   ? "== §9 — o que NÃO pode virar obrigatório =="

   Vale( "cliente sem CPF é válido", ValCpf( "" )[ "ok" ], .T. )
   Vale( "e sem valor gravado", ValCpf( "" )[ "valor" ], NIL )
   Vale( "fornecedor sem CNPJ é válido", ValCnpj( "" )[ "ok" ], .T. )
   Vale( "sem telefone é válido", ValTelefone( "" )[ "ok" ], .T. )
   Vale( "sem CEP é válido", ValCep( "" )[ "ok" ], .T. )
   Vale( "sem UF é válido", ValUf( "" )[ "ok" ], .T. )
   Vale( "sem data de nascimento é válido", ValNascimento( "" )[ "ok" ], .T. )
   Vale( "sem data de venda é válido", ValDataEvento( "" )[ "ok" ], .T. )

   /* nome, esse sim, é obrigatório — o schema exige e V-12 pede */
   Vale( "nome vazio recusado (V-12)", ValObrigatorio( "", "Nome" )[ "ok" ], .F. )
   Vale( "nome só com espaços recusado", ValObrigatorio( "   ", "Nome" )[ "ok" ], .F. )
   Vale( "nome preenchido aceito", ValObrigatorio( "BatMan", "Nome" )[ "ok" ], .T. )

   RETURN

STATIC PROCEDURE TestaAcumulador()

   LOCAL hV

   ? "== acumulador de erros e avisos =="

   hV := ValNovo()
   Vale( "começa válido", ValOk( hV ), .T. )
   ValJuntar( hV, "cpf", ValCpf( "111.444.777-36" ) )
   Vale( "erro derruba a validação", ValOk( hV ), .F. )
   ValJuntar( hV, "nome", ValObrigatorio( "BatMan", "Nome" ) )
   Vale( "acerto não acrescenta erro", Len( hV[ "erros" ] ), 1 )
   ValAviso( hV, "estoque", "Estoque abaixo do mínimo." )
   Vale( "aviso não é erro", Len( hV[ "erros" ] ), 1 )
   Vale( "mas é registrado", ValTemAviso( hV ), .T. )
   Vale( "texto reúne as mensagens", At( "dígito verificador", ValTexto( hV ) ) > 0, .T. )
   Vale( "e também os avisos", At( "abaixo do mínimo", ValTexto( hV ) ) > 0, .T. )

   RETURN

/* V-13 e V-17 — dependem do banco. */
STATIC PROCEDURE TestaIntegridade()

   LOCAL cDb := hb_DirTemp() + "testa-validacao.db", hC, pDb, hR

   ? "== V-13 / V-17 — unicidade e integridade referencial =="

   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )

   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, cpf, data_cadastro)" + ;
      " VALUES (?,?,?,?)", { 1, "Cliente Um", "11144477735", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
      " VALUES (?,?,?)", { 2, "Cliente Dois", "1994-01-01" } )

   Vale( "CPF novo é único", IntegCpfUnico( pDb, "52998224725" )[ "ok" ], .T. )
   Vale( "CPF já usado é recusado (V-13)", IntegCpfUnico( pDb, "11144477735" )[ "ok" ], .F. )
   Vale( "mas não contra o próprio registro", ;
         IntegCpfUnico( pDb, "11144477735", 1 )[ "ok" ], .T. )
   Vale( "CPF vazio não colide", IntegCpfUnico( pDb, "" )[ "ok" ], .T. )

   /* V-17: cliente sem dependência pode ser excluído */
   hR := IntegPodeExcluir( pDb, "cliente", 2 )
   Vale( "cliente sem dependência pode ser excluído", hR[ "ok" ], .T. )

   /* agora damos uma venda ao cliente 1 */
   SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro) VALUES (?,?,?)", ;
      { 3, "Vendedor", "1994-01-01" } )
   SqlExecBind( pDb, "INSERT INTO venda_peca (cod_cli, origem, total_cent)" + ;
      " VALUES (?,?,?)", { 1, "BALCAO", 1000 } )

   hR := IntegPodeExcluir( pDb, "cliente", 1 )
   Vale( "cliente com venda NÃO pode ser excluído (V-17)", hR[ "ok" ], .F. )
   Vale( "e a mensagem diz onde está preso", ;
         At( "venda(s) de peça", hR[ "mensagem" ] ) > 0, .T. )
   Vale( "com a quantidade", At( "1 venda", hR[ "mensagem" ] ) > 0, .T. )
   Vale( "referências devolvidas para a tela", Len( hR[ "referencias" ] ), 1 )

   /* exclusão lógica da venda libera o cliente */
   SqlExec( pDb, "UPDATE venda_peca SET excluido = 1" )
   Vale( "venda excluída deixa de prender", IntegPodeExcluir( pDb, "cliente", 1 )[ "ok" ], .T. )

   Vale( "IntegExiste acha cliente ativo", IntegExiste( pDb, "cliente", "cod_cli", 1 ), .T. )
   Vale( "e não acha código inexistente", IntegExiste( pDb, "cliente", "cod_cli", 999 ), .F. )

   ConexaoFechar()

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
