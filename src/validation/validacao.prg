/*
 * validacao.prg — FASES G (onda 1) e H
 *
 * As validações que o legado NÃO tinha, catalogadas em
 * docs/05-VALIDACOES-LEGADO.md §8 como V-01 a V-19.
 *
 * DUAS REGRAS QUE GOVERNAM ESTE MÓDULO
 * ------------------------------------
 * 1. Nenhuma validação nova substitui regra de negócio existente. Todas cobrem
 *    lacunas em que o legado não decidia nada. As três que alteram
 *    comportamento observável (V-10 UF, V-11 igualdade, V-15 prestações) estão
 *    registradas em 09-DIVERGENCIAS-MODERNIZACAO.md.
 *
 * 2. O que o legado permitia continua permitido. §9 do mesmo documento lista o
 *    que NÃO deve virar obrigatório: CPF, CNPJ, telefone, endereço, cidade, UF,
 *    data de venda. Cliente sem CPF é válido — o legado aceita e o briefing §7
 *    é explícito. Um documento *informado* é que precisa estar correto.
 *
 * A diferença entre ERRO e AVISO é a mesma do legado: erro impede gravar; aviso
 * exige confirmação e segue (RN-028 é alerta, não bloqueio — §9).
 */

#define SEM_LIMITE   -1

/* ------------------------------------------------------------------ */
/* Acumulador                                                          */
/* ------------------------------------------------------------------ */

FUNCTION ValNovo()
   RETURN { "erros" => {}, "avisos" => {} }

FUNCTION ValErro( hV, cCampo, cMensagem )
   AAdd( hV[ "erros" ], { "campo" => cCampo, "mensagem" => cMensagem } )
   RETURN hV

FUNCTION ValAviso( hV, cCampo, cMensagem )
   AAdd( hV[ "avisos" ], { "campo" => cCampo, "mensagem" => cMensagem } )
   RETURN hV

FUNCTION ValOk( hV )
   RETURN Len( hV[ "erros" ] ) == 0

FUNCTION ValTemAviso( hV )
   RETURN Len( hV[ "avisos" ] ) > 0

/* Junta o resultado de um validador de campo ao acumulador da entidade. */
FUNCTION ValJuntar( hV, cCampo, hRes )
   IF hRes != NIL .AND. !hRes[ "ok" ]
      ValErro( hV, cCampo, hRes[ "mensagem" ] )
   ENDIF
   RETURN hV

/* Texto das mensagens, uma por linha, para exibir ao usuário. */
FUNCTION ValTexto( hV )

   LOCAL cTxt := "", i

   FOR i := 1 TO Len( hV[ "erros" ] )
      cTxt += iif( Empty( cTxt ), "", hb_eol() ) + hV[ "erros" ][ i ][ "mensagem" ]
   NEXT
   FOR i := 1 TO Len( hV[ "avisos" ] )
      cTxt += iif( Empty( cTxt ), "", hb_eol() ) + hV[ "avisos" ][ i ][ "mensagem" ]
   NEXT

   RETURN cTxt

STATIC FUNCTION Res( lOk, cMensagem, xValor )
   RETURN { "ok" => lOk, "mensagem" => cMensagem, "valor" => xValor }

/* ------------------------------------------------------------------ */
/* V-01 / V-02 / V-03 — documentos                                     */
/* ------------------------------------------------------------------ */

/*
 * Dígitos verificadores de CPF e CNPJ — módulo 11, resto < 2 → 0.
 *
 * Esta é a ÚNICA implementação da regra no projeto: normalizador.prg (migração)
 * chama daqui. Duas cópias divergiriam com o tempo, e aí um CPF seria aceito na
 * tela e recusado na migração, ou vice-versa.
 */
FUNCTION ValidaDigitos( cTexto )

   LOCAL cRes := "", i, c

   IF cTexto == NIL
      RETURN ""
   ENDIF
   FOR i := 1 TO Len( cTexto )
      c := SubStr( cTexto, i, 1 )
      IF c >= "0" .AND. c <= "9"
         cRes += c
      ENDIF
   NEXT

   RETURN cRes

FUNCTION ValidaDvOk( cDigitos, nTamanho )

   LOCAL nBase := nTamanho - 2

   IF Len( cDigitos ) != nTamanho .OR. ValidaRepetido( cDigitos )
      RETURN .F.
   ENDIF

   RETURN ValidaCalcDv( Left( cDigitos, nBase ), nTamanho ) == ;
          SubStr( cDigitos, nBase + 1, 2 )

FUNCTION ValidaRepetido( cDigitos )

   LOCAL i

   IF Empty( cDigitos )
      RETURN .F.
   ENDIF
   FOR i := 2 TO Len( cDigitos )
      IF !( SubStr( cDigitos, i, 1 ) == Left( cDigitos, 1 ) )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

/*
 * Gera os dois DVs a partir da base. O 2º sai da base acrescida do 1º gerado —
 * é assim que o número é emitido, e comparar o par gerado com o informado
 * rejeita corretamente erro em qualquer um dos dois.
 *
 * Str( n, 1 ) e não hb_ntos(): o operador % do Harbour devolve numérico COM
 * casas decimais, e hb_ntos( 3.00 ) produz "3.00".
 */
STATIC FUNCTION ValidaCalcDv( cBase, nTamanho )

   LOCAL j, i, nSoma, nDv, cCalc := "", cNum := cBase, aPesos

   FOR j := 1 TO 2
      nSoma := 0
      IF nTamanho == 11
         FOR i := 1 TO Len( cNum )
            nSoma += Val( SubStr( cNum, i, 1 ) ) * ( Len( cNum ) + 2 - i )
         NEXT
      ELSE
         aPesos := iif( j == 1, ;
            { 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 }, ;
            { 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 } )
         FOR i := 1 TO Len( aPesos )
            nSoma += Val( SubStr( cNum, i, 1 ) ) * aPesos[ i ]
         NEXT
      ENDIF
      nDv := nSoma % 11
      nDv := iif( nDv < 2, 0, 11 - nDv )
      cCalc += Str( nDv, 1 )
      cNum  += Str( nDv, 1 )
   NEXT

   RETURN cCalc

/* V-01 — CPF. Vazio é VÁLIDO: o legado permite cliente sem CPF (§9). */
FUNCTION ValCpf( cEntrada )

   LOCAL cDig := ValidaDigitos( cEntrada )

   IF Len( cDig ) == 0
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( cDig ) != 11
      RETURN Res( .F., "CPF deve ter 11 dígitos; foram informados " + ;
                  hb_ntos( Len( cDig ) ) + ".", NIL )
   ENDIF
   IF ValidaRepetido( cDig )
      RETURN Res( .F., "CPF inválido: todos os dígitos são iguais.", NIL )
   ENDIF
   IF !ValidaDvOk( cDig, 11 )
      RETURN Res( .F., "CPF inválido: o dígito verificador não confere.", NIL )
   ENDIF

   RETURN Res( .T., NIL, cDig )

/* V-02 — CNPJ. Vazio também é válido (§9). */
FUNCTION ValCnpj( cEntrada )

   LOCAL cDig := ValidaDigitos( cEntrada )

   IF Len( cDig ) == 0
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( cDig ) != 14
      RETURN Res( .F., "CNPJ deve ter 14 dígitos; foram informados " + ;
                  hb_ntos( Len( cDig ) ) + ".", NIL )
   ENDIF
   IF ValidaRepetido( cDig )
      RETURN Res( .F., "CNPJ inválido: todos os dígitos são iguais.", NIL )
   ENDIF
   IF !ValidaDvOk( cDig, 14 )
      RETURN Res( .F., "CNPJ inválido: o dígito verificador não confere.", NIL )
   ENDIF

   RETURN Res( .T., NIL, cDig )

/* ------------------------------------------------------------------ */
/* V-04 / V-06 — contato                                               */
/* ------------------------------------------------------------------ */

FUNCTION ValCep( cEntrada )

   LOCAL cDig := ValidaDigitos( cEntrada )

   IF Len( cDig ) == 0
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( cDig ) != 8
      RETURN Res( .F., "CEP deve ter 8 dígitos; foram informados " + ;
                  hb_ntos( Len( cDig ) ) + ".", NIL )
   ENDIF

   RETURN Res( .T., NIL, cDig )

/*
 * V-06 — telefone. Aceita 8 a 11 dígitos, faixa que cobre o número local sem
 * DDD (8), com DDD moderno (10-11) e o formato pré-1999 do acervo, de DDD com
 * quatro dígitos (11). O DDD antigo NÃO é convertido: a renumeração da Anatel
 * é de 1999, posterior aos dados (D-24).
 */
FUNCTION ValTelefone( cEntrada )

   LOCAL cDig := ValidaDigitos( cEntrada )

   IF Len( cDig ) == 0
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( cDig ) < 8 .OR. Len( cDig ) > 11
      RETURN Res( .F., "Telefone deve ter de 8 a 11 dígitos; foram informados " + ;
                  hb_ntos( Len( cDig ) ) + ".", NIL )
   ENDIF

   RETURN Res( .T., NIL, cDig )

/* ------------------------------------------------------------------ */
/* V-07 / V-08 / V-09 — datas                                          */
/* ------------------------------------------------------------------ */

/* Data ISO 'AAAA-MM-DD' que existe no calendário. Vazia é válida. */
FUNCTION ValData( cIso )

   LOCAL dData

   IF Empty( cIso )
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( cIso ) != 10 .OR. !( SubStr( cIso, 5, 1 ) == "-" ) .OR. ;
      !( SubStr( cIso, 8, 1 ) == "-" )
      RETURN Res( .F., "Data deve estar no formato AAAA-MM-DD.", NIL )
   ENDIF
   dData := hb_SToD( StrTran( cIso, "-", "" ) )
   IF Empty( dData )
      RETURN Res( .F., "Data inexistente no calendário: " + cIso + ".", NIL )
   ENDIF

   RETURN Res( .T., NIL, cIso )

/*
 * V-08 — nascimento, em dois níveis.
 *
 * Não existe limiar objetivo entre "idade improvável" e "erro de digitação", e
 * o documento não fixa um. Fixar um só produziria uma das duas falhas: barrar
 * cadastro legítimo, ou deixar passar o `1901-01-01` que V-08 cita como
 * evidência. Então são dois:
 *
 *   ERRO  — acima de 130 anos ou no futuro. Fisicamente impossível; a pessoa
 *           mais velha com idade verificada chegou a 122.
 *   AVISO — acima de 110 anos. Possível, improvável. Pede confirmação, como o
 *           legado fazia com estoque abaixo do mínimo (RN-028) — alerta, não
 *           bloqueio.
 *
 * Nada de idade mínima: o legado não a tinha, e inventá-la barraria o cadastro
 * legítimo de um menor.
 */
FUNCTION ValNascimento( cIso )

   LOCAL hR := ValData( cIso ), nIdade

   IF !hR[ "ok" ] .OR. hR[ "valor" ] == NIL
      RETURN hR
   ENDIF
   IF hb_SToD( StrTran( cIso, "-", "" ) ) > Date()
      RETURN Res( .F., "Data de nascimento no futuro.", NIL )
   ENDIF
   nIdade := Year( Date() ) - Val( Left( cIso, 4 ) )
   IF nIdade > 130
      RETURN Res( .F., "Data de nascimento impossível: resultaria em " + ;
                  hb_ntos( nIdade ) + " anos.", NIL )
   ENDIF

   RETURN Res( .T., NIL, cIso )

/* .T. quando a data merece confirmação do operador, sem ser recusada. */
FUNCTION ValNascimentoSuspeito( cIso )

   IF Empty( cIso ) .OR. Len( cIso ) != 10
      RETURN .F.
   ENDIF

   RETURN ( Year( Date() ) - Val( Left( cIso, 4 ) ) ) > 110

/*
 * V-09 — data de evento (venda, adesão, orçamento). Não pode ser futura.
 * Anterior ao início do sistema é AVISO, não erro: pode ser lançamento
 * retroativo legítimo, e o legado aceitava qualquer coisa.
 */
FUNCTION ValDataEvento( cIso )

   LOCAL hR := ValData( cIso )

   IF !hR[ "ok" ] .OR. hR[ "valor" ] == NIL
      RETURN hR
   ENDIF
   IF hb_SToD( StrTran( cIso, "-", "" ) ) > Date()
      RETURN Res( .F., "A data não pode ser futura.", NIL )
   ENDIF

   RETURN Res( .T., NIL, cIso )

FUNCTION ValDataAntiga( cIso )
   IF Empty( cIso )
      RETURN .F.
   ENDIF
   RETURN Val( Left( cIso, 4 ) ) < 1970

/* ------------------------------------------------------------------ */
/* V-10 / V-11 / V-12 — domínio e obrigatoriedade                      */
/* ------------------------------------------------------------------ */

STATIC FUNCTION ListaUf()
   RETURN { "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS", ;
            "MT","PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC", ;
            "SE","SP","TO" }

/*
 * V-10 + V-11 — UF. A lista do legado omitia SC e TO e continha FN e RC.
 * E a comparação era com `$`, que deixa passar string vazia e prefixo: aqui a
 * comparação é de igualdade exata (V-11). UF vazia continua permitida (§9).
 */
FUNCTION ValUf( cUf )

   LOCAL cU

   IF Empty( cUf )
      RETURN Res( .T., NIL, NIL )
   ENDIF
   cU := Upper( AllTrim( cUf ) )
   IF AScan( ListaUf(), {| x | x == cU } ) == 0
      RETURN Res( .F., "UF inválida: " + cU + ".", NIL )
   ENDIF

   RETURN Res( .T., NIL, cU )

FUNCTION ValUfLista()
   RETURN ListaUf()

/* V-12 — obrigatoriedade. Só onde o legado já exigia, ou onde o schema exige. */
FUNCTION ValObrigatorio( xValor, cNome )

   LOCAL cTxt

   IF xValor == NIL
      RETURN Res( .F., cNome + " é obrigatório.", NIL )
   ENDIF
   IF ValType( xValor ) == "C"
      cTxt := AllTrim( xValor )
      IF Empty( cTxt )
         RETURN Res( .F., cNome + " é obrigatório.", NIL )
      ENDIF
      RETURN Res( .T., NIL, cTxt )
   ENDIF

   RETURN Res( .T., NIL, xValor )

/* ------------------------------------------------------------------ */
/* V-14 / V-15 / V-16 / V-18 / V-19 — números e faixas                 */
/* ------------------------------------------------------------------ */

FUNCTION ValCodigo( xCod, cNome, nMax )

   LOCAL nC

   hb_default( @nMax, 99999 )
   IF xCod == NIL .OR. ( ValType( xCod ) == "C" .AND. Empty( AllTrim( xCod ) ) )
      RETURN Res( .F., cNome + " é obrigatório.", NIL )
   ENDIF
   nC := iif( ValType( xCod ) == "C", Val( AllTrim( xCod ) ), xCod )
   IF nC != Int( nC )
      RETURN Res( .F., cNome + " deve ser um número inteiro.", NIL )
   ENDIF
   IF nC < 1 .OR. nC > nMax
      RETURN Res( .F., cNome + " deve estar entre 1 e " + hb_ntos( nMax ) + ".", NIL )
   ENDIF

   RETURN Res( .T., NIL, nC )

/* V-14 — quantidade não negativa. */
FUNCTION ValQuantidade( xQtd, cNome )

   LOCAL nQ

   IF xQtd == NIL
      RETURN Res( .T., NIL, 0 )
   ENDIF
   nQ := iif( ValType( xQtd ) == "C", Val( AllTrim( xQtd ) ), xQtd )
   IF nQ != Int( nQ )
      RETURN Res( .F., cNome + " deve ser um número inteiro.", NIL )
   ENDIF
   IF nQ < 0
      RETURN Res( .F., cNome + " não pode ser negativa.", NIL )
   ENDIF

   RETURN Res( .T., NIL, nQ )

/* V-16 — monetário não negativo, em centavos. */
FUNCTION ValMonetario( xCent, cNome )

   LOCAL nV

   IF xCent == NIL
      RETURN Res( .T., NIL, 0 )
   ENDIF
   nV := iif( ValType( xCent ) == "C", Val( AllTrim( xCent ) ), xCent )
   IF nV != Int( nV )
      RETURN Res( .F., cNome + " em centavos deve ser um número inteiro.", NIL )
   ENDIF
   IF nV < 0
      RETURN Res( .F., cNome + " não pode ser negativo.", NIL )
   ENDIF

   RETURN Res( .T., NIL, nV )

/* V-15 — prestações restantes ≥ 0. O legado gravou -2, -3 e '**' (RN-026). */
FUNCTION ValParcelas( xN, cNome )

   LOCAL hR := ValQuantidade( xN, cNome )

   IF !hR[ "ok" ]
      RETURN Res( .F., cNome + " não pode ser negativo — o legado subtraía sem " + ;
                  "piso em zero, o que produziu saldos negativos.", NIL )
   ENDIF

   RETURN hR

/* V-18 — faixa de chassi coerente. */
FUNCTION ValFaixaChassi( xIni, xFim )

   LOCAL nI, nF

   IF xIni == NIL .OR. xFim == NIL
      RETURN Res( .T., NIL, NIL )
   ENDIF
   nI := iif( ValType( xIni ) == "C", Val( AllTrim( xIni ) ), xIni )
   nF := iif( ValType( xFim ) == "C", Val( AllTrim( xFim ) ), xFim )
   IF nI < 0 .OR. nF < 0
      RETURN Res( .F., "A faixa de chassi não pode ser negativa.", NIL )
   ENDIF
   IF nF < nI
      RETURN Res( .F., "O chassi final (" + hb_ntos( nF ) + ") não pode ser " + ;
                  "menor que o inicial (" + hb_ntos( nI ) + ").", NIL )
   ENDIF

   RETURN Res( .T., NIL, NIL )

/* V-19 — o valor cabe no campo. */
FUNCTION ValTamanho( cTexto, nMax, cNome )

   IF cTexto == NIL
      RETURN Res( .T., NIL, NIL )
   ENDIF
   IF Len( AllTrim( cTexto ) ) > nMax
      RETURN Res( .F., cNome + " excede o limite de " + hb_ntos( nMax ) + ;
                  " caracteres.", NIL )
   ENDIF

   RETURN Res( .T., NIL, AllTrim( cTexto ) )
