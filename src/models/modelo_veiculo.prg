/*
 * modelo_veiculo.prg — FASE G, onda 2
 *
 * A antiga "frota" (CVBFROTA). Guarda o modelo, o estoque e a faixa de chassi.
 *
 * A coerência da faixa (fim >= início, V-18) é uma regra do CONJUNTO de dois
 * campos, então mora no validador extra, não em nenhum dos dois isoladamente.
 * O legado deixava editar os dois livremente, sem conferir.
 */

FUNCTION ModeloVeiculoDescritor()
   RETURN { ;
      "entidade" => "modelo_veiculo", ;
      "tabela"   => "modelo_veiculo", ;
      "view"     => "v_modelo_veiculo", ;
      "chave"    => "cod_car", ;
      "titulo"   => "Manutenção da Frota", ;
      "campos"   => { ;
         ModeloCampo( "descricao"  , "Descrição"   , "C", 35, {| x | ValObrigatorio( x, "Descrição" ) } ), ;
         ModeloCampo( "qtd_estoque", "Quantidade"  , "N",  5, {| x | ValQuantidade( x, "Quantidade" ) } ), ;
         ModeloCampo( "valor_cent" , "Valor"       , "$", 14, {| x | ValReais( x, "Valor" ) } ), ;
         ModeloCampo( "data_compra", "Data compra" , "D", 10, {| x | ValDataEvento( x ) } ), ;
         ModeloCampo( "chassi_ini" , "Chassi de"   , "N", 12, {| x | ValChassi( x, "Chassi inicial" ) } ), ;
         ModeloCampo( "chassi_fim" , "Chassi até"  , "N", 12, {| x | ValChassi( x, "Chassi final" ) } ) }, ;
      "defaults" => { => }, ;
      "validador_extra" => {| pDb, hVal, hV, lNovo | ModeloVeiculoExtra( pDb, hVal, hV, lNovo ) } }

STATIC PROCEDURE ModeloVeiculoExtra( pDb, hValores, hV, lNovo )

   LOCAL hR

   HB_SYMBOL_UNUSED( pDb )
   HB_SYMBOL_UNUSED( lNovo )

   hR := ValFaixaChassi( hValores[ "chassi_ini" ], hValores[ "chassi_fim" ] )
   IF !hR[ "ok" ]
      ValErro( hV, "chassi_fim", hR[ "mensagem" ] )
   ENDIF

   RETURN

/* Chassi é numérico e opcional; vazio fica NULL, não zero. */
FUNCTION ValChassi( xEntrada, cNome )

   LOCAL cTxt

   IF xEntrada == NIL
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => NIL }
   ENDIF
   IF ValType( xEntrada ) == "N"
      RETURN iif( xEntrada == 0, ;
         { "ok" => .T., "mensagem" => NIL, "valor" => NIL }, ;
         ValQuantidade( xEntrada, cNome ) )
   ENDIF
   cTxt := AllTrim( xEntrada )
   IF Empty( cTxt )
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => NIL }
   ENDIF
   IF !( Len( ValidaDigitos( cTxt ) ) == Len( cTxt ) )
      RETURN { "ok" => .F., "mensagem" => cNome + " deve conter apenas dígitos.", ;
               "valor" => NIL }
   ENDIF

   RETURN { "ok" => .T., "mensagem" => NIL, "valor" => Val( cTxt ) }
