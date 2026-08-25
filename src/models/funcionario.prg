/*
 * funcionario.prg — FASE G, onda 2
 *
 * Salário e comissão são armazenados em CENTAVOS (inteiro), não em ponto
 * flutuante — a mesma decisão da migração. O operador digita em reais; a
 * conversão é textual, para não introduzir erro de arredondamento onde o valor
 * precisa ser exato.
 */

FUNCTION FuncionarioDescritor()
   RETURN { ;
      "entidade" => "funcionario", ;
      "tabela"   => "funcionario", ;
      "view"     => "v_funcionario", ;
      "chave"    => "cod_fun", ;
      "titulo"   => "Manutenção de Funcionários", ;
      "campos"   => { ;
         ModeloCampo( "nome"         , "Nome"    , "C", 35, {| x | ValObrigatorio( x, "Nome" ) } ), ;
         ModeloCampo( "endereco"     , "Endereço", "C", 45, {| x | ValTamanho( x, 45, "Endereço" ) } ), ;
         ModeloCampo( "cidade"       , "Cidade"  , "C", 15, {| x | ValTamanho( x, 15, "Cidade" ) } ), ;
         ModeloCampo( "cep"          , "CEP"     , "C",  9, {| x | ValCep( x ) }, "cep_original" ), ;
         ModeloCampo( "cargo"        , "Cargo"   , "C", 15, {| x | ValTamanho( x, 15, "Cargo" ) } ), ;
         ModeloCampo( "salario_cent" , "Salário" , "$", 14, {| x | ValReais( x, "Salário" ) } ), ;
         ModeloCampo( "comissao_cent", "Comissão", "$", 14, {| x | ValReais( x, "Comissão" ) } ) }, ;
      "defaults" => { => } }

/*
 * Reais digitados → centavos, sem passar por ponto flutuante.
 * "1.234,56" e "1234.56" e "1234,56" chegam todos a 123456.
 */
FUNCTION ValReais( xEntrada, cNome )

   LOCAL cTxt, nSep, cInt, cDec, lNeg

   IF xEntrada == NIL
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => 0 }
   ENDIF
   IF ValType( xEntrada ) == "N"
      RETURN ValMonetario( xEntrada, cNome )
   ENDIF

   cTxt := AllTrim( xEntrada )
   IF Empty( cTxt )
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => 0 }
   ENDIF

   lNeg := ( Left( cTxt, 1 ) == "-" )
   IF lNeg
      cTxt := SubStr( cTxt, 2 )
   ENDIF
   cTxt := StrTran( cTxt, " ", "" )

   /* o separador decimal é o ÚLTIMO ponto ou vírgula; o que vier antes é
      separador de milhar e é descartado */
   nSep := Max( RAt( ",", cTxt ), RAt( ".", cTxt ) )
   IF nSep == 0
      cInt := cTxt
      cDec := "00"
   ELSE
      cInt := Left( cTxt, nSep - 1 )
      cDec := SubStr( cTxt, nSep + 1 )
      IF Len( cDec ) > 2
         /* mais de duas casas: é separador de milhar, não decimal */
         cInt := cTxt
         cDec := "00"
      ENDIF
   ENDIF
   cInt := StrTran( StrTran( cInt, ".", "" ), ",", "" )
   cDec := PadR( cDec, 2, "0" )

   IF Len( ValidaDigitos( cInt ) ) != Len( cInt ) .OR. ;
      Len( ValidaDigitos( cDec ) ) != Len( cDec )
      RETURN { "ok" => .F., "mensagem" => cNome + ": valor inválido.", "valor" => NIL }
   ENDIF
   IF lNeg
      RETURN { "ok" => .F., "mensagem" => cNome + " não pode ser negativo.", "valor" => NIL }
   ENDIF

   RETURN { "ok" => .T., "mensagem" => NIL, ;
            "valor" => Val( cInt ) * 100 + Val( Left( cDec, 2 ) ) }
