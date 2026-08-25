/*
 * peca.prg — FASE G, onda 3
 *
 * Cadastro/estoque de peças (ex-CVBPECAS).
 *
 * DOIS DEFEITOS DO LEGADO QUE ESTE CADASTRO NÃO REPRODUZ
 * ------------------------------------------------------
 * D-01 — `CVMTPEC.PRG:73` fazia `MCODPEC = CODFOR` no caminho de alteração, e a
 * linha 135 gravava isso de volta em `CODPEC`: alterar uma peça corrompia sua
 * chave primária, escrevendo nela o código do fornecedor. Aqui a chave
 * simplesmente NÃO entra no UPDATE — ela só aparece no WHERE. Não é uma
 * precaução contra o defeito antigo: é que reatribuir a PK numa alteração não
 * faz sentido em lugar nenhum.
 *
 * RN-036 — o campo NOMFOR era o nome do fornecedor copiado para dentro da peça.
 * Não existe mais coluna: a view `v_peca` traz `nome_fornecedor` por JOIN.
 * Cadastro não tem valor histórico a preservar — ao contrário do movimento,
 * onde o snapshot é deliberado (D-19).
 */

FUNCTION PecaDescritor()
   RETURN { ;
      "entidade" => "peca", ;
      "tabela"   => "peca", ;
      "view"     => "v_peca", ;
      "chave"    => "cod_pec", ;
      "titulo"   => "Manutenção de Peças", ;
      "campos"   => { ;
         ModeloCampo( "descricao"      , "Descrição"  , "C", 35, {| x | ValObrigatorio( x, "Descrição" ) } ), ;
         ModeloCampo( "qtd_estoque"    , "Quantidade" , "N",  5, {| x | ValQuantidade( x, "Quantidade" ) } ), ;
         ModeloCampo( "valor_unit_cent", "Valor unit.", "$", 14, {| x | ValReais( x, "Valor unitário" ) } ), ;
         ModeloCampo( "qtd_minima"     , "Estoque mín.", "N", 5, {| x | ValQuantidade( x, "Estoque mínimo" ) } ), ;
         ModeloCampo( "cod_for"        , "Fornecedor" , "N",  6, {| x | ValCodigoOpcional( x, "Fornecedor" ) } ) }, ;
      "defaults" => { => }, ;
      "validador_extra" => {| pDb, hVal, hV, lNovo | EstoqueExtra( pDb, hVal, hV, lNovo, "cod_for" ) } }

/*
 * Regras comuns a peça e almoxarifado.
 *
 * O fornecedor é opcional, mas se informado tem de existir. O legado conferia
 * isso por SEEK no índice — e no almoxarifado o índice estava construído sobre
 * a tabela errada (D-14), então a verificação nunca encontrava nada e o
 * cadastro tratava todo código como novo. Aqui a checagem é uma consulta, e
 * vale igual para os dois.
 */
FUNCTION EstoqueExtra( pDb, hValores, hV, lNovo, cCampoFor )

   LOCAL nFor := hValores[ cCampoFor ]

   HB_SYMBOL_UNUSED( lNovo )

   IF nFor != NIL .AND. nFor > 0
      IF !IntegExiste( pDb, "fornecedor", "cod_for", nFor )
         ValErro( hV, cCampoFor, "Fornecedor " + hb_ntos( nFor ) + " não cadastrado." )
      ENDIF
   ENDIF

   /* RN-028: estoque abaixo do mínimo é ALERTA, não bloqueio (05 §9). */
   IF hValores[ "qtd_estoque" ] != NIL .AND. hValores[ "qtd_minima" ] != NIL .AND. ;
      hValores[ "qtd_minima" ] > 0 .AND. ;
      hValores[ "qtd_estoque" ] < hValores[ "qtd_minima" ]
      ValAviso( hV, "qtd_estoque", "Quantidade (" + hb_ntos( hValores[ "qtd_estoque" ] ) + ;
                ") está abaixo do estoque mínimo (" + hb_ntos( hValores[ "qtd_minima" ] ) + ")." )
   ENDIF

   RETURN NIL

/* Código de referência opcional: vazio ou zero vira NULL, não erro. */
FUNCTION ValCodigoOpcional( xCod, cNome )

   LOCAL nC

   IF xCod == NIL .OR. ( ValType( xCod ) == "C" .AND. Empty( AllTrim( xCod ) ) )
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => NIL }
   ENDIF
   nC := iif( ValType( xCod ) == "C", Val( AllTrim( xCod ) ), xCod )
   IF nC == 0
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => NIL }
   ENDIF

   RETURN ValCodigo( nC, cNome )
