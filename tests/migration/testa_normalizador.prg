/*
 * testa_normalizador.prg — critério de aceite da FASE D.2
 *
 * "Testes unitários por transformação." — docs/10-PLANO-IMPLEMENTACAO.md, D.2
 *
 * Os valores de entrada são, sempre que possível, os bytes reais do acervo,
 * citados em docs/02-MODELO-DADOS.md §8 e docs/08-MIGRACAO-DADOS.md §4.
 * Sai com 0 se tudo passa, 1 caso contrário.
 */

REQUEST HB_CODEPAGE_PT860
REQUEST HB_CODEPAGE_UTF8

STATIC s_nOk := 0
STATIC s_nFalhas := 0
STATIC s_cGrupo := ""

PROCEDURE Main()

   ? "FASE D.2 — aceite do normalizador"
   ?

   TestaTexto()
   TestaNumerico()
   TestaMonetario()
   TestaRestrito()
   TestaData()
   TestaLogico()
   TestaCpf()
   TestaCnpj()
   TestaCep()
   TestaTelefone()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "D.2 ACEITA", "D.2 REPROVADA" )

   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

/* ------------------------------------------------------------------ */

STATIC PROCEDURE TestaTexto()

   LOCAL h

   Grupo( "4.1 Texto — CP860, TRIM, vazio, caixa" )

   /* 0xA7 em CVBCLIEN.ENDCLI reg. 4 */
   h := NormTexto( "RUA JONAS MARQUES DA SILVEIRA N" + hb_BChar( 167 ) + "12   " )
   Vale( "CP860: 0xA7 vira º", h[ "valor" ], "RUA JONAS MARQUES DA SILVEIRA Nº12" )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   /* RGCLI com espaço à esquerda — §4.1 exige LTRIM também */
   h := NormTexto( " 29.494.504-3  " )
   Vale( "TRIM dos dois lados", h[ "valor" ], "29.494.504-3" )

   h := NormTexto( "               " )
   Vale( "vazio vira NULL", h[ "valor" ], NIL )

   /* caixa mista é evidência histórica: preservar */
   h := NormTexto( "BatMan                             " )
   Vale( "caixa preservada", h[ "valor" ], "BatMan" )

   h := NormTexto( "Uno Mile ELX" )
   Vale( "caixa mista preservada", h[ "valor" ], "Uno Mile ELX" )

   /* byte alto não previsto pela FASE A: converte e avisa */
   h := NormTexto( "A" + hb_BChar( 130 ) + "B" )
   Vale( "byte alto inesperado gera BAIXA", Sev( h, 1 ), "BAIXA" )

   RETURN

STATIC PROCEDURE TestaNumerico()

   LOCAL h

   Grupo( "4.2 Numérico — código e quantidade" )

   h := NormCodigo( "    7" )
   Vale( "código '    7'", h[ "valor" ], 7 )

   h := NormCodigo( "     " )
   Vale( "código branco vira NULL", h[ "valor" ], NIL )

   h := NormQuantidade( "  3" )
   Vale( "quantidade '  3'", h[ "valor" ], 3 )
   Vale( "não é vazio de origem", h[ "vazio_origem" ], .F. )

   /* CVBGRUPO.NUMPAG — nunca gravado (02 §8.6) */
   h := NormQuantidade( "  " )
   Vale( "quantidade branca vira 0", h[ "valor" ], 0 )
   Vale( "marcada como vazia na origem", h[ "vazio_origem" ], .T. )

   h := NormQuantidade( "-2" )
   Vale( "quantidade negativa importa", h[ "valor" ], -2 )
   Vale( "e registra MEDIA", Sev( h, 1 ), "MEDIA" )

   RETURN

STATIC PROCEDURE TestaMonetario()

   LOCAL h

   Grupo( "4.2 Monetário — centavos exatos" )

   /* CVBGRUCO.VALPRE */
   h := NormMonetario( "     2000.00" )
   Vale( "2000.00 vira 200000 centavos", h[ "valor" ], 200000 )

   h := NormMonetario( "        0.01" )
   Vale( "0.01 vira 1 centavo", h[ "valor" ], 1 )

   /* o caso que Val()*100 erra por ponto flutuante */
   h := NormMonetario( "        1.15" )
   Vale( "1.15 vira 115 (sem erro de float)", h[ "valor" ], 115 )

   h := NormMonetario( "      129.95" )
   Vale( "129.95 vira 12995", h[ "valor" ], 12995 )

   h := NormMonetario( "            " )
   Vale( "branco vira 0", h[ "valor" ], 0 )
   Vale( "marcado como vazio na origem", h[ "vazio_origem" ], .T. )

   h := NormMonetario( "       -1.50" )
   Vale( "negativo importa", h[ "valor" ], -150 )
   Vale( "e registra MEDIA", Sev( h, 1 ), "MEDIA" )

   RETURN

STATIC PROCEDURE TestaRestrito()

   LOCAL h

   Grupo( "4.2 Padrão *_legado — D-11" )

   /* CVBGRUCO.NUMMES reg. 1 — overflow gravado pelo Clipper (02 §8.5) */
   h := NormNumeroRestrito( "**", 0 )
   Vale( "'**' não entra na coluna", h[ "valor" ], NIL )
   Vale( "'**' vai para *_legado", h[ "legado" ], "**" )
   Vale( "severidade ALTA", Sev( h, 1 ), "ALTA" )

   /* regs. 2 e 3 */
   h := NormNumeroRestrito( "-2", 0 )
   Vale( "-2 não entra na coluna", h[ "valor" ], NIL )
   Vale( "-2 vai para *_legado", h[ "legado" ], "-2" )
   Vale( "severidade ALTA", Sev( h, 1 ), "ALTA" )

   h := NormNumeroRestrito( " 1", 0 )
   Vale( "valor válido entra normalmente", h[ "valor" ], 1 )
   Vale( "sem *_legado", h[ "legado" ], NIL )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormNumeroRestrito( "  ", 0 )
   Vale( "branco vira NULL sem ocorrência", h[ "valor" ], NIL )
   Vale( "e sem *_legado", Len( h[ "ocorrencias" ] ), 0 )

   RETURN

STATIC PROCEDURE TestaData()

   LOCAL h

   Grupo( "4.3 Datas — ISO e severidade por contexto" )

   h := NormData( "19940630", "EVENTO" )
   Vale( "19940630 vira 1994-06-30", h[ "valor" ], "1994-06-30" )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormData( "        ", "EVENTO" )
   Vale( "data vazia vira NULL", h[ "valor" ], NIL )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormData( "19940231", "EVENTO" )
   Vale( "31 de fevereiro vira NULL", h[ "valor" ], NIL )
   Vale( "e registra ALTA", Sev( h, 1 ), "ALTA" )

   /* a tabela de 08 §4.3, caso a caso */
   h := NormData( "19561010", "NASCIMENTO" )
   Vale( "NASCLI 1956-10-10 é BAIXA", Sev( h, 1 ), "BAIXA" )
   Vale( "mas é importada", h[ "valor" ], "1956-10-10" )

   h := NormData( "19111111", "NASCIMENTO" )
   Vale( "NASCLI 1911-11-11 é MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormData( "19081010", "NASCIMENTO" )
   Vale( "NASCLI 1908-10-10 é MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormData( "19100702", "NASCIMENTO" )
   Vale( "NASCLI 1910-07-02 é MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormData( "19120310", "NASCIMENTO" )
   Vale( "NASCLI 1912-03-10 é MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormData( "19010101", "NASCIMENTO" )
   Vale( "NASCLI 1901-01-01 é ALTA", Sev( h, 1 ), "ALTA" )

   h := NormData( "19011111", "EVENTO" )
   Vale( "DATAV 1901-11-11 é ALTA", Sev( h, 1 ), "ALTA" )

   h := NormData( "19101010", "EVENTO" )
   Vale( "DATREP 1910-10-10 é ALTA", Sev( h, 1 ), "ALTA" )

   RETURN

STATIC PROCEDURE TestaLogico()

   LOCAL h

   Grupo( "4.4 Lógico" )

   h := NormLogico( "T" ) ; Vale( "T vira 1", h[ "valor" ], 1 )
   h := NormLogico( "F" ) ; Vale( "F vira 0", h[ "valor" ], 0 )
   h := NormLogico( "Y" ) ; Vale( "Y vira 1", h[ "valor" ], 1 )
   h := NormLogico( " " ) ; Vale( "branco vira 0", h[ "valor" ], 0 )

   RETURN

STATIC PROCEDURE TestaCpf()

   LOCAL h

   Grupo( "4.5 CPF" )

   h := NormCpf( "111.444.777-35 " )
   Vale( "CPF válido normaliza", h[ "valor" ], "11144477735" )
   Vale( "marcado como válido", h[ "valido" ], 1 )
   Vale( "original preservado", h[ "original" ], "111.444.777-35" )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormCpf( "111.444.777-36 " )
   Vale( "DV errado ainda entra na coluna", h[ "valor" ], "11144477736" )
   Vale( "mas com valido = 0", h[ "valido" ], 0 )
   Vale( "e ocorrência MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormCpf( "11111111111" )
   Vale( "sequência repetida: valido = 0", h[ "valido" ], 0 )
   Vale( "com MEDIA", Sev( h, 1 ), "MEDIA" )

   /* exemplo literal de 08 §8 */
   h := NormCpf( "88888888888-888" )
   Vale( "14 dígitos vira NULL", h[ "valor" ], NIL )
   Vale( "com ALTA", Sev( h, 1 ), "ALTA" )
   Vale( "original preservado", h[ "original" ], "88888888888-888" )

   /* CVBCLIEN.CICCLI reg. 1 — 10 dígitos */
   h := NormCpf( "/7556465464    " )
   Vale( "10 dígitos vira NULL", h[ "valor" ], NIL )
   Vale( "com ALTA", Sev( h, 1 ), "ALTA" )

   h := NormCpf( "               " )
   Vale( "ausente vira NULL", h[ "valor" ], NIL )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   RETURN

STATIC PROCEDURE TestaCnpj()

   LOCAL h

   Grupo( "4.5 CNPJ" )

   h := NormCnpj( "11.222.333/0001-81" )
   Vale( "CNPJ válido normaliza", h[ "valor" ], "11222333000181" )
   Vale( "marcado como válido", h[ "valido" ], 1 )

   h := NormCnpj( "11.222.333/0001-82" )
   Vale( "DV errado: valido = 0", h[ "valido" ], 0 )
   Vale( "com MEDIA", Sev( h, 1 ), "MEDIA" )

   /* valores reais de CVBFORNE.CGCFAB (08 §4.5) */
   h := NormCnpj( "27439872194873285783" )
   Vale( "20 dígitos vira NULL", h[ "valor" ], NIL )
   Vale( "com ALTA", Sev( h, 1 ), "ALTA" )

   h := NormCnpj( "3484378438743]" )
   Vale( "13 dígitos vira NULL", h[ "valor" ], NIL )
   Vale( "com ALTA", Sev( h, 1 ), "ALTA" )

   h := NormCnpj( "              " )
   Vale( "branco vira NULL sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   RETURN

STATIC PROCEDURE TestaCep()

   LOCAL h

   Grupo( "4.5 CEP" )

   /* CVBCLIEN.CEPCLI — N(8,0), zeros à esquerda perdidos */
   h := NormCepNumerico( "  798797" )
   Vale( "798797 completa para 00798797", h[ "valor" ], "00798797" )
   Vale( "com MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormCepNumerico( "    5877" )
   Vale( "5877 completa para 00005877", h[ "valor" ], "00005877" )
   Vale( "com MEDIA", Sev( h, 1 ), "MEDIA" )

   h := NormCepNumerico( "18800000" )
   Vale( "8 dígitos passa direto", h[ "valor" ], "18800000" )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormCepNumerico( "        " )
   Vale( "ausente vira NULL", h[ "valor" ], NIL )
   Vale( "com BAIXA", Sev( h, 1 ), "BAIXA" )

   /* CVBFUNC.CEPFUN — C(9) com máscara deslocada (I-05) */
   h := NormCepTexto( "188000-00" )
   Vale( "188000-00 vira 18800000", h[ "valor" ], "18800000" )
   Vale( "com BAIXA", Sev( h, 1 ), "BAIXA" )
   Vale( "original preservado", h[ "original" ], "188000-00" )

   h := NormCepTexto( "18800-000" )
   Vale( "máscara correta vira 18800000", h[ "valor" ], "18800000" )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormCepTexto( "1234     " )
   Vale( "4 dígitos vira NULL", h[ "valor" ], NIL )
   Vale( "com MEDIA", Sev( h, 1 ), "MEDIA" )

   RETURN

STATIC PROCEDURE TestaTelefone()

   LOCAL h

   Grupo( "4.5 Telefone — D-24" )

   h := NormTelefone( "(0143)051-2382 " )
   Vale( "zero do prefixo é mantido", h[ "valor" ], "01430512382" )
   Vale( "original com máscara preservado", h[ "original" ], "(0143)051-2382" )
   Vale( "com BAIXA informativa", Sev( h, 1 ), "BAIXA" )

   /* CVBCLIEN.TELCLI reg. 1 */
   h := NormTelefone( "(8978)798-798  " )
   Vale( "só dígitos", h[ "valor" ], "8978798798" )
   Vale( "não começa com 0: sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   h := NormTelefone( "               " )
   Vale( "ausente vira NULL", h[ "valor" ], NIL )
   Vale( "sem ocorrência", Len( h[ "ocorrencias" ] ), 0 )

   RETURN

/* ------------------------------------------------------------------ */
/* Infraestrutura mínima de asserção                                   */
/* ------------------------------------------------------------------ */

STATIC PROCEDURE Grupo( cNome )
   s_cGrupo := cNome
   ? "== " + cNome + " =="
   RETURN

STATIC FUNCTION Sev( hRes, nIdx )
   IF Len( hRes[ "ocorrencias" ] ) < nIdx
      RETURN "(nenhuma ocorrência)"
   ENDIF
   RETURN hRes[ "ocorrencias" ][ nIdx ][ "severidade" ]

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
