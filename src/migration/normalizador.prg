/*
 * normalizador.prg — FASE D.2
 *
 * Transformações de valor do legado para o modelo novo.
 * Especificação: docs/08-MIGRACAO-DADOS.md §4.
 *
 * CONTRATO
 * --------
 * Toda função recebe os **bytes brutos** do campo, como o extrator (D.1) os
 * entregou em `linhas[n]["brutos"][campo]`, e devolve um hash:
 *
 *   { "valor"       => <valor para a coluna nova, ou NIL para NULL>,
 *     "ocorrencias" => { { "problema"=>, "acao"=>, "severidade"=> }, ... } }
 *
 * Algumas funções acrescentam chaves próprias ("original", "valido", "legado",
 * "vazio_origem").
 *
 * Por que os bytes brutos e não o valor tipado do RDD: só eles distinguem
 * "nunca gravado" de zero e preservam o overflow `**`. Ver o cabeçalho de
 * extrator.prg e docs/02-MODELO-DADOS.md §8.5–8.6.
 *
 * O normalizador NÃO grava, NÃO decide destino de coluna e NÃO conhece o
 * schema. Ele converte um valor e relata o que achou. Quem registra as
 * ocorrências é inconsistencia.prg (D.3); quem escolhe a coluna é o
 * carregador (D.4).
 *
 * PRINCÍPIO: nenhum valor inválido é corrigido em silêncio (08 §2).
 */

#define SEV_BAIXA   "BAIXA"
#define SEV_MEDIA   "MEDIA"
#define SEV_ALTA    "ALTA"

REQUEST HB_CODEPAGE_PT860
REQUEST HB_CODEPAGE_UTF8

/* ------------------------------------------------------------------ */
/* 4.1 Texto                                                           */
/* ------------------------------------------------------------------ */

/*
 * CP860 → UTF-8, TRIM dos dois lados, vazio → NULL, caixa preservada.
 *
 * A conversão usa a tabela CP860 do próprio Harbour (`hb_Translate`), que é
 * uma tabela explícita e auditável — não um `iconv` genérico, conforme §4.1.
 *
 * A FASE A verificou que o único byte ≥ 0x80 do acervo é 0xA7 (`º`) em
 * CVBCLIEN.ENDCLI. Qualquer outro byte alto gera ocorrência informativa: se
 * aparecer, a premissa da FASE A mudou e alguém precisa olhar.
 */
FUNCTION NormTexto( cBruto )

   LOCAL hRes := NormResultado( NIL ), cTxt, i, nByte

   IF cBruto == NIL
      RETURN hRes
   ENDIF

   FOR i := 1 TO hb_BLen( cBruto )
      nByte := hb_BPeek( cBruto, i )
      IF nByte >= 128 .AND. nByte != 167          // 167 = 0xA7 = 'º'
         NormAddOc( hRes, ;
            "Byte " + hb_NumToHex( nByte, 2 ) + " fora do previsto na FASE A (só 0xA7)", ;
            "Convertido pela tabela CP860; conferir o glifo", SEV_BAIXA )
      ENDIF
   NEXT

   cTxt := AllTrim( hb_Translate( cBruto, "PT860", "UTF8" ) )
   hRes[ "valor" ] := iif( Empty( cTxt ), NIL, cTxt )

   RETURN hRes

/* RG: formatos livres, sem formato nacional nem DV. Só TRIM (§4.5). */
FUNCTION NormRg( cBruto )
   RETURN NormTexto( cBruto )

/* ------------------------------------------------------------------ */
/* 4.2 Numérico                                                        */
/* ------------------------------------------------------------------ */

/* Código N(n,0): branco → NULL. */
FUNCTION NormCodigo( cBruto )

   LOCAL hRes := NormResultado( NIL )

   IF cBruto == NIL .OR. Empty( AllTrim( cBruto ) )
      RETURN hRes
   ENDIF
   hRes[ "valor" ] := Val( AllTrim( cBruto ) )

   RETURN hRes

/*
 * Quantidade N(n,0): branco → 0, negativo → importa e registra (§4.2).
 * "vazio_origem" permite ao carregador identificar campos nunca gravados
 * (I-10), que só fazem sentido como observação agregada por campo.
 */
FUNCTION NormQuantidade( cBruto )

   LOCAL hRes := NormResultado( 0 ), cTxt

   hRes[ "vazio_origem" ] := .T.
   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cTxt := AllTrim( cBruto )
   IF Empty( cTxt )
      RETURN hRes
   ENDIF

   hRes[ "vazio_origem" ] := .F.
   hRes[ "valor" ] := Val( cTxt )
   IF hRes[ "valor" ] < 0
      NormAddOc( hRes, "Quantidade negativa: " + cTxt, ;
         "Importada como está", SEV_MEDIA )
   ENDIF

   RETURN hRes

/*
 * Monetário N(12,2) → centavos INTEGER (§4.2).
 *
 * A conversão é textual, não `Val(x) * 100`: multiplicar um binário de ponto
 * flutuante por 100 e arredondar introduz erro justamente onde o valor precisa
 * ser exato. Os bytes trazem o ponto decimal em posição fixa; separá-lo em
 * inteiro e centavos e somar é exato por construção.
 */
FUNCTION NormMonetario( cBruto )

   LOCAL hRes := NormResultado( 0 ), cTxt, nPonto, cInt, cDec, lNeg

   hRes[ "vazio_origem" ] := .T.
   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cTxt := AllTrim( cBruto )
   IF Empty( cTxt )
      RETURN hRes
   ENDIF
   hRes[ "vazio_origem" ] := .F.

   lNeg := ( Left( cTxt, 1 ) == "-" )
   IF lNeg .OR. Left( cTxt, 1 ) == "+"
      cTxt := SubStr( cTxt, 2 )
   ENDIF

   nPonto := At( ".", cTxt )
   IF nPonto == 0
      cInt := cTxt
      cDec := "00"
   ELSE
      cInt := Left( cTxt, nPonto - 1 )
      cDec := SubStr( cTxt, nPonto + 1 )
   ENDIF
   cDec := PadR( cDec, 2, "0" )

   IF !NormSoTemDigitos( cInt ) .OR. !NormSoTemDigitos( Left( cDec, 2 ) )
      hRes[ "valor" ] := NIL
      NormAddOc( hRes, "Valor monetário não conversível: " + AllTrim( cBruto ), ;
         "Coluna recebe NULL; bruto preservado", SEV_ALTA )
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := Val( cInt ) * 100 + Val( Left( cDec, 2 ) )
   IF lNeg
      hRes[ "valor" ] := -hRes[ "valor" ]
      NormAddOc( hRes, "Valor monetário negativo: " + AllTrim( cBruto ), ;
         "Importado como está", SEV_MEDIA )
   ENDIF

   RETURN hRes

/*
 * Padrão *_legado (§4.2, D-11): valor que viola uma restrição do modelo novo.
 *
 *   valor  ← NULL          o invariante do modelo é mantido
 *   legado ← bruto em TEXT a evidência é preservada
 *   ocorrência ALTA        o registro fica marcado para decisão
 *
 * Único caso do acervo: CVBGRUCO.NUMMES — '**' (overflow) e -2/-3.
 */
FUNCTION NormNumeroRestrito( cBruto, nMinimo )

   LOCAL hRes := NormResultado( NIL ), cTxt

   hb_default( @nMinimo, 0 )
   hRes[ "legado" ] := NIL

   IF cBruto == NIL .OR. Empty( AllTrim( cBruto ) )
      RETURN hRes
   ENDIF

   cTxt := AllTrim( cBruto )

   IF !NormSoTemDigitos( StrTran( cTxt, "-", "" ) )
      hRes[ "legado" ] := cTxt
      NormAddOc( hRes, "Valor não numérico no campo (overflow gravado pelo Clipper): " + cTxt, ;
         "Coluna recebe NULL; bruto preservado na coluna *_legado", SEV_ALTA )
      RETURN hRes
   ENDIF

   IF Val( cTxt ) < nMinimo
      hRes[ "legado" ] := cTxt
      NormAddOc( hRes, "Valor " + cTxt + " abaixo do mínimo permitido (" + ;
         hb_ntos( nMinimo ) + ")", ;
         "Coluna recebe NULL; bruto preservado na coluna *_legado", SEV_ALTA )
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := Val( cTxt )

   RETURN hRes

/* ------------------------------------------------------------------ */
/* 4.3 Datas                                                           */
/* ------------------------------------------------------------------ */

/*
 * 'YYYYMMDD' → 'YYYY-MM-DD'. Branco → NULL. Impossível → NULL + ALTA.
 * Válida mas anterior a 1970 → importa como está + ocorrência (§4.3, D-23).
 *
 * SEVERIDADE — como a regra foi derivada
 * --------------------------------------
 * §4.3 fixa a regra ("< 1970 → MÉDIA") mas a tabela de datas suspeitas atribui
 * BAIXA, MÉDIA e ALTA a valores diferentes. As duas só se conciliam se a
 * severidade depender do que o campo significa, não só do valor: 1910 é
 * implausível como data de reparo e possível como data de nascimento.
 *
 * Daí o parâmetro cContexto ("NASCIMENTO" ou "EVENTO"):
 *
 *   ano 1901                      → ALTA   (lixo do SET EPOCH — 02 §8.4)
 *   EVENTO com ano < 1970         → ALTA   (não há evento de 1994 em 1910)
 *   NASCIMENTO com ano < 1920     → MEDIA  (idade improvável, não impossível)
 *   NASCIMENTO 1920 <= ano < 1970 → BAIXA  (plausível)
 *
 * Esta regra reproduz exatamente a tabela de 08 §4.3, caso a caso.
 */
FUNCTION NormData( cBruto, cContexto )

   LOCAL hRes := NormResultado( NIL ), cTxt, dData, nAno, cSev

   hb_default( @cContexto, "EVENTO" )

   IF cBruto == NIL .OR. Empty( AllTrim( cBruto ) )
      RETURN hRes
   ENDIF

   cTxt := AllTrim( cBruto )

   IF Len( cTxt ) != 8 .OR. !NormSoTemDigitos( cTxt )
      NormAddOc( hRes, "Data com formato inesperado: '" + cTxt + "'", ;
         "Coluna recebe NULL", SEV_ALTA )
      RETURN hRes
   ENDIF

   dData := hb_SToD( cTxt )
   IF Empty( dData )
      NormAddOc( hRes, "Data inexistente no calendário: " + cTxt, ;
         "Coluna recebe NULL", SEV_ALTA )
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := Left( cTxt, 4 ) + "-" + SubStr( cTxt, 5, 2 ) + "-" + SubStr( cTxt, 7, 2 )

   nAno := Val( Left( cTxt, 4 ) )
   IF nAno < 1970
      DO CASE
      CASE nAno == 1901                    ; cSev := SEV_ALTA
      CASE cContexto == "EVENTO"           ; cSev := SEV_ALTA
      CASE nAno < 1920                     ; cSev := SEV_MEDIA
      OTHERWISE                            ; cSev := SEV_BAIXA
      ENDCASE
      NormAddOc( hRes, "Data anterior a 1970: " + hRes[ "valor" ] + ;
         " (provável SET EPOCH com ano de 2 dígitos)", ;
         "Importada como está — converter seria inventar o século (D-23)", cSev )
   ENDIF

   RETURN hRes

/* ------------------------------------------------------------------ */
/* 4.4 Lógico                                                          */
/* ------------------------------------------------------------------ */

/* T/Y → 1 · F/N/branco → 0 (§4.4). */
FUNCTION NormLogico( cBruto )

   LOCAL hRes := NormResultado( 0 ), cTxt

   IF cBruto == NIL
      RETURN hRes
   ENDIF
   cTxt := Upper( AllTrim( cBruto ) )
   hRes[ "valor" ] := iif( cTxt == "T" .OR. cTxt == "Y", 1, 0 )

   RETURN hRes

/* ------------------------------------------------------------------ */
/* 4.5 Documentos                                                      */
/* ------------------------------------------------------------------ */

/* CPF: 11 dígitos + 2 DVs + rejeição de sequência repetida (§4.5). */
FUNCTION NormCpf( cBruto )
   RETURN NormDocumento( cBruto, 11, "CPF" )

/* CNPJ: mesmo tratamento, 14 dígitos (§4.5). */
FUNCTION NormCnpj( cBruto )
   RETURN NormDocumento( cBruto, 14, "CNPJ" )

STATIC FUNCTION NormDocumento( cBruto, nDigitos, cNome )

   LOCAL hRes := NormResultado( NIL ), cDig, cOrig

   hRes[ "valido" ]   := 0
   hRes[ "original" ] := NIL

   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cOrig := AllTrim( hb_Translate( cBruto, "PT860", "UTF8" ) )
   hRes[ "original" ] := iif( Empty( cOrig ), NIL, cOrig )
   cDig := NormSoDigitos( cBruto )

   IF Len( cDig ) == 0
      RETURN hRes                      // ausente: NULL, sem inconsistência
   ENDIF

   IF Len( cDig ) != nDigitos
      NormAddOc( hRes, cNome + " com " + hb_ntos( Len( cDig ) ) + ;
         " dígitos após normalização (esperado " + hb_ntos( nDigitos ) + ")", ;
         "Importado com " + Lower( cNome ) + " = NULL e " + Lower( cNome ) + ;
         "_valido = 0; original preservado", SEV_ALTA )
      RETURN hRes
   ENDIF

   /* Comprimento correto: o valor entra na coluna, válido ou não. */
   hRes[ "valor" ] := cDig

   IF NormDigitosIguais( cDig )
      NormAddOc( hRes, cNome + " é sequência de dígitos repetidos: " + cDig, ;
         "Importado com " + Lower( cNome ) + "_valido = 0", SEV_MEDIA )
   ELSEIF !NormDvOk( cDig, nDigitos )
      NormAddOc( hRes, cNome + " com dígito verificador inválido: " + cDig, ;
         "Importado com " + Lower( cNome ) + "_valido = 0", SEV_MEDIA )
   ELSE
      hRes[ "valido" ] := 1
   ENDIF

   RETURN hRes

/*
 * CEP vindo de N(8,0) — CVBCLIEN.CEPCLI.
 * STRZERO recupera os zeros à esquerda que o campo numérico perdeu; menos de
 * 8 dígitos significativos é provável dígito faltante, não CEP com zeros (§4.5).
 */
FUNCTION NormCepNumerico( cBruto )

   LOCAL hRes := NormResultado( NIL ), cDig

   hRes[ "original" ] := NIL
   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cDig := NormSoDigitos( cBruto )
   hRes[ "original" ] := iif( Empty( AllTrim( cBruto ) ), NIL, AllTrim( cBruto ) )

   IF Len( cDig ) == 0 .OR. Val( cDig ) == 0
      NormAddOc( hRes, "CEP ausente", "Coluna recebe NULL", SEV_BAIXA )
      RETURN hRes
   ENDIF

   IF Len( cDig ) < 8
      NormAddOc( hRes, "CEP com " + hb_ntos( Len( cDig ) ) + ;
         " dígitos significativos (esperado 8): " + cDig, ;
         "Completado com zeros à esquerda para " + PadL( cDig, 8, "0" ) + ;
         "; provável dígito faltante, não CEP com zeros", SEV_MEDIA )
   ENDIF

   hRes[ "valor" ] := PadL( cDig, 8, "0" )

   RETURN hRes

/*
 * CEP vindo de C(9) — CVBFORNE.CEPFOR, CVBFUNC.CEPFUN.
 * '188000-00' → '18800000': a máscara moveu o hífen, mas os 8 dígitos são os
 * do CEP de Piraju. Importa e registra BAIXA (§4.5, I-05).
 */
FUNCTION NormCepTexto( cBruto )

   LOCAL hRes := NormResultado( NIL ), cDig, cOrig

   hRes[ "original" ] := NIL
   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cOrig := AllTrim( cBruto )
   hRes[ "original" ] := iif( Empty( cOrig ), NIL, cOrig )
   cDig := NormSoDigitos( cBruto )

   IF Len( cDig ) == 0
      NormAddOc( hRes, "CEP ausente", "Coluna recebe NULL", SEV_BAIXA )
      RETURN hRes
   ENDIF

   IF Len( cDig ) != 8
      NormAddOc( hRes, "CEP com " + hb_ntos( Len( cDig ) ) + ;
         " dígitos após remover a máscara (esperado 8): " + cOrig, ;
         "Coluna recebe NULL; original preservado", SEV_MEDIA )
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := cDig
   IF !( cOrig == cDig ) .AND. At( "-", cOrig ) > 0 .AND. At( "-", cOrig ) != 6
      NormAddOc( hRes, "Máscara de CEP malformada: " + cOrig, ;
         "Importado como " + cDig + " (os 8 dígitos conferem)", SEV_BAIXA )
   ENDIF

   RETURN hRes

/*
 * Telefone: só dígitos, original preservado com máscara.
 *
 * O zero do prefixo interurbano NÃO é removido e o DDD de 4 dígitos NÃO é
 * convertido: a renumeração da Anatel é de 1999, posterior aos dados de 1994
 * (D-24, §4.5). '(0143)051-2382' → '01430512382'.
 */
FUNCTION NormTelefone( cBruto )

   LOCAL hRes := NormResultado( NIL ), cDig, cOrig

   hRes[ "original" ] := NIL
   IF cBruto == NIL
      RETURN hRes
   ENDIF

   cOrig := AllTrim( cBruto )
   hRes[ "original" ] := iif( Empty( cOrig ), NIL, cOrig )
   cDig := NormSoDigitos( cBruto )

   IF Len( cDig ) == 0
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := cDig

   IF Left( cDig, 1 ) == "0" .AND. Len( cDig ) >= 10 .AND. Len( cDig ) <= 11
      NormAddOc( hRes, "Telefone em formato de DDD pré-1999: " + cOrig, ;
         "Importados apenas os dígitos, sem converter o DDD (D-24)", SEV_BAIXA )
   ENDIF

   RETURN hRes

/* ------------------------------------------------------------------ */
/* Auxiliares                                                          */
/* ------------------------------------------------------------------ */

FUNCTION NormSoDigitos( cBruto )
   RETURN ValidaDigitos( cBruto )

STATIC FUNCTION NormSoTemDigitos( cTxt )
   RETURN !Empty( cTxt ) .AND. Len( NormSoDigitos( cTxt ) ) == Len( cTxt )

STATIC FUNCTION NormDigitosIguais( cDig )
   RETURN ValidaRepetido( cDig )

/*
 * DV de CPF e CNPJ: a regra vive em src/validation/validacao.prg e é a MESMA
 * usada pela aplicação. Duas cópias divergiriam com o tempo, e um documento
 * seria aceito na tela e recusado na migração, ou vice-versa.
 */
STATIC FUNCTION NormDvOk( cDig, nDigitos )
   RETURN ValidaDvOk( cDig, nDigitos )

STATIC FUNCTION NormResultado( xValor )
   RETURN { "valor" => xValor, "ocorrencias" => {} }

STATIC PROCEDURE NormAddOc( hRes, cProblema, cAcao, cSeveridade )
   AAdd( hRes[ "ocorrencias" ], { ;
      "problema"   => cProblema, ;
      "acao"       => cAcao, ;
      "severidade" => cSeveridade } )
   RETURN
