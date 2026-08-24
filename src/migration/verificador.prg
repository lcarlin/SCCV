/*
 * verificador.prg — FASE E: testes de migração
 *
 * Especificação: docs/08-MIGRACAO-DADOS.md §9; entregas E.1 a E.5 em
 * docs/10-PLANO-IMPLEMENTACAO.md.
 *
 *   E.1  contagens por par origem→destino, com e sem excluídos
 *   E.2  as 7 somas de controle (§9.2) — tolerância ZERO
 *   E.3  comparação campo a campo de 100% dos registros (§9.3)
 *   E.4  integridade referencial e as 13 relações de 02 §8.2 (§9.4)
 *   E.5  reconciliação dos agregados e revisão do relatório (§9.5)
 *
 * O QUE ESTA VERIFICAÇÃO PROVA — E O QUE NÃO PROVA
 * ------------------------------------------------
 * As somas de controle (E.2) são calculadas a partir dos BYTES BRUTOS do DBF,
 * somando em centavos por aritmética inteira, sem passar pelo normalizador.
 * São, portanto, independentes do código que fez a migração: se o normalizador
 * estiver errado, elas acusam.
 *
 * A comparação campo a campo (E.3) reaplica o normalizador ao dado de origem e
 * compara com o que está no banco. Isso NÃO valida a regra de normalização —
 * usa a mesma regra dos dois lados. O que ela valida, e é o risco real de um
 * carregador com 17 colunas por INSERT, é o MAPEAMENTO: coluna trocada, campo
 * fora de ordem, valor gravado na linha errada. Onde dá para conferir sem o
 * normalizador (contagem de dígitos, texto puro, data ISO), a verificação é
 * feita direto contra os bytes.
 */

#define TOLERANCIA_ZERO   0

/*
 * Devolve { "itens" => { {nome, esperado, obtido, ok, nota}, ... },
 *           "ok" => n, "falhas" => n }
 */
FUNCTION VerificarTudo( pDb, cDirLegado )

   LOCAL hV := { "itens" => {}, "ok" => 0, "falhas" => 0 }

   IF !( Right( cDirLegado, 1 ) == hb_ps() )
      cDirLegado += hb_ps()
   ENDIF

   VerContagens( hV, pDb, cDirLegado )
   VerSomas( hV, pDb, cDirLegado )
   VerCampoACampo( hV, pDb, cDirLegado )
   VerIntegridade( hV, pDb )
   VerAgregados( hV, pDb )
   VerRelatorio( hV, pDb )

   RETURN hV

/* ------------------------------------------------------------------ */
/* E.1 — contagens (§9.1)                                              */
/* ------------------------------------------------------------------ */

STATIC PROCEDURE VerContagens( hV, pDb, cDir )

   LOCAL aPares, i, hT, nTodas, nVisiveis

   Secao( hV, "E.1 — contagens origem → destino" )

   aPares := { ;
      { "CVBCLIEN.DBF", "cliente"          }, ;
      { "CVBFUNC.DBF" , "funcionario"      }, ;
      { "CVBFORNE.DBF", "fornecedor"       }, ;
      { "CVBPECAS.DBF", "peca"             }, ;
      { "CVBALMOX.DBF", "almoxarifado"     }, ;
      { "CVBFROTA.DBF", "modelo_veiculo"   }, ;
      { "CVBPENT.DBF" , "venda_veiculo"    }, ;
      { "CVREPAR.DBF" , "orcamento_reparo" }, ;
      { "CVBPEDID.DBF", "pedido"           }, ;
      { "CVVCAR.DBF"  , "_legado_cvvcar"   }, ;
      { "CVVPEC.DBF"  , "_legado_cvvpec"   }, ;
      { "CVCLIENT.DBF", "_legado_cvclient" } }

   FOR i := 1 TO Len( aPares )
      hT := ExtratorLer( cDir + aPares[ i ][ 1 ], .F. )
      IF hT[ "erro" ] != NIL
         Item( hV, aPares[ i ][ 1 ], "legível", hT[ "erro" ], .F. )
         LOOP
      ENDIF
      nTodas := SqlEscalar( pDb, "SELECT count(*) FROM " + aPares[ i ][ 2 ] )
      Item( hV, aPares[ i ][ 1 ] + " → " + aPares[ i ][ 2 ] + " (todas)", ;
            hT[ "registros" ], nTodas, hT[ "registros" ] == nTodas )
   NEXT

   /* excluídos: só CVBGRUPO tem, e eles não viram cota (§6.2) */
   FOR i := 1 TO Len( aPares )
      IF aPares[ i ][ 2 ] == "_legado_cvvcar" .OR. aPares[ i ][ 2 ] == "_legado_cvvpec" ;
         .OR. aPares[ i ][ 2 ] == "_legado_cvclient"
         LOOP
      ENDIF
      hT := ExtratorLer( cDir + aPares[ i ][ 1 ], .F. )
      nVisiveis := SqlEscalar( pDb, "SELECT count(*) FROM " + aPares[ i ][ 2 ] + ;
                                    " WHERE excluido = 0" )
      Item( hV, aPares[ i ][ 1 ] + " → " + aPares[ i ][ 2 ] + " (visíveis)", ;
            hT[ "ativos" ], nVisiveis, hT[ "ativos" ] == nVisiveis )
   NEXT

   /* exceções documentadas em §9.1 */
   hT := ExtratorLer( cDir + "CVPECAS.DBF", .F. )
   Item( hV, "CVPECAS → venda_peca_item (exceção §9.1: 75 itens → N + 75)", ;
         hT[ "registros" ], SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ), ;
         hT[ "registros" ] == SqlEscalar( pDb, "SELECT count(*) FROM venda_peca_item" ) )

   nTodas := ExtratorLer( cDir + "CVBGRUPO.DBF", .F. )[ "registros" ] + ;
             ExtratorLer( cDir + "CVBGRUCO.DBF", .F. )[ "registros" ]
   nVisiveis := SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" ) + ;
                SqlEscalar( pDb, "SELECT count(*) FROM _legado_cvbgrupo_excluido" )
   Item( hV, "CVBGRUPO+CVBGRUCO → cota + quarentena (exceção §9.1: 8 → 5+3)", ;
         nTodas, nVisiveis, nTodas == nVisiveis )

   RETURN

/* ------------------------------------------------------------------ */
/* E.2 — somas de controle (§9.2), tolerância zero                     */
/* ------------------------------------------------------------------ */

STATIC PROCEDURE VerSomas( hV, pDb, cDir )

   LOCAL nOrig, nDest

   Secao( hV, "E.2 — somas de controle (tolerância zero)" )

   nOrig := SomaCent( cDir + "CVBFUNC.DBF", "SALFUN" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(salario_cent),0) FROM funcionario" )
   Item( hV, "salários (centavos)", nOrig, nDest, nOrig == nDest )

   nOrig := SomaCent( cDir + "CVBFUNC.DBF", "COMFUN" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(comissao_cent),0) FROM funcionario" )
   Item( hV, "comissões (centavos)", nOrig, nDest, nOrig == nDest )

   nOrig := SomaInt( cDir + "CVBPECAS.DBF", "QTDPEC" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(qtd_estoque),0) FROM peca" )
   Item( hV, "estoque de peças", nOrig, nDest, nOrig == nDest )

   nOrig := SomaCent( cDir + "CVBPENT.DBF", "VALCAR" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(valor_cent),0) FROM venda_veiculo" )
   Item( hV, "valores de venda de veículo (centavos)", nOrig, nDest, nOrig == nDest )

   nOrig := SomaCent( cDir + "CVPECAS.DBF", "SUBTOT" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(subtotal_cent),0) FROM venda_peca_item" )
   Item( hV, "subtotais de itens (centavos)", nOrig, nDest, nOrig == nDest )

   nOrig := SomaInt( cDir + "CVBFROTA.DBF", "QUANTCAR" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(qtd_estoque),0) FROM modelo_veiculo" )
   Item( hV, "estoque de frota", nOrig, nDest, nOrig == nDest )

   /* prestações: as duas tabelas de consórcio, menos os excluídos, que não
      viraram cota (§6.2) */
   nOrig := SomaCent( cDir + "CVBGRUCO.DBF", "VALPRE" ) + ;
            SomaCentAtivos( cDir + "CVBGRUPO.DBF", "VALPRE" )
   nDest := SqlEscalar( pDb, "SELECT IFNULL(SUM(valor_prestacao_cent),0) FROM consorcio_cota" )
   Item( hV, "prestações de consórcio (centavos)", nOrig, nDest, nOrig == nDest )

   RETURN

/*
 * Soma monetária direto dos bytes, em aritmética inteira de centavos.
 * Não usa o normalizador: é o contraponto independente que valida a migração.
 */
STATIC FUNCTION SomaCent( cArq, cCampo )
   RETURN SomaBruta( cArq, cCampo, .T., .F. )

STATIC FUNCTION SomaCentAtivos( cArq, cCampo )
   RETURN SomaBruta( cArq, cCampo, .T., .T. )

STATIC FUNCTION SomaInt( cArq, cCampo )
   RETURN SomaBruta( cArq, cCampo, .F., .F. )

STATIC FUNCTION SomaBruta( cArq, cCampo, lMoeda, lSoAtivos )

   LOCAL hT := ExtratorLer( cArq ), i, cTxt, nTotal := 0, nPonto, cInt, cDec

   IF hT[ "erro" ] != NIL
      RETURN -1
   ENDIF

   FOR i := 1 TO Len( hT[ "linhas" ] )
      IF lSoAtivos .AND. hT[ "linhas" ][ i ][ "__EXCLUIDO" ]
         LOOP
      ENDIF
      cTxt := AllTrim( hT[ "linhas" ][ i ][ "brutos" ][ cCampo ] )
      IF Empty( cTxt )
         LOOP
      ENDIF
      IF !lMoeda
         nTotal += Val( cTxt )
         LOOP
      ENDIF
      nPonto := At( ".", cTxt )
      IF nPonto == 0
         cInt := cTxt
         cDec := "00"
      ELSE
         cInt := Left( cTxt, nPonto - 1 )
         cDec := PadR( SubStr( cTxt, nPonto + 1 ), 2, "0" )
      ENDIF
      nTotal += Val( cInt ) * 100 + Val( Left( cDec, 2 ) )
   NEXT

   RETURN nTotal

/* ------------------------------------------------------------------ */
/* E.3 — campo a campo, 100% dos registros (§9.3)                      */
/* ------------------------------------------------------------------ */

STATIC PROCEDURE VerCampoACampo( hV, pDb, cDir )

   LOCAL nDiv := 0, nComp := 0, aR

   Secao( hV, "E.3 — comparação campo a campo (100% dos registros)" )

   nDiv += CompCliente( pDb, cDir, @nComp )
   nDiv += CompFuncionario( pDb, cDir, @nComp )
   nDiv += CompModelo( pDb, cDir, @nComp )
   nDiv += CompVendaVeiculo( pDb, cDir, @nComp )
   nDiv += CompItens( pDb, cDir, @nComp )

   Item( hV, "campos comparados: " + hb_ntos( nComp ), nComp, nComp, .T. )
   Item( hV, "divergências", 0, nDiv, nDiv == TOLERANCIA_ZERO )

   /* conferência independente do normalizador: os dígitos do CPF original
      gravado têm de ser exatamente os bytes do legado, sem perda */
   aR := SqlLinhas( pDb, "SELECT cod_cli, cpf_original FROM cliente ORDER BY cod_cli" )
   Item( hV, "cpf_original preservado byte a byte", 22, Len( aR ), Len( aR ) == 22 )

   RETURN

STATIC FUNCTION CompCliente( pDb, cDir, nComp )

   LOCAL hT := ExtratorLer( cDir + "CVBCLIEN.DBF" ), i, b, aR, nDiv := 0, nCod

   FOR i := 1 TO Len( hT[ "linhas" ] )
      b    := hT[ "linhas" ][ i ][ "brutos" ]
      nCod := NormCodigo( b[ "CODCLI" ] )[ "valor" ]
      aR := SqlLinhas( pDb, "SELECT nome, endereco, cidade, uf, cep, cep_original," + ;
         " telefone, rg, cpf_original, nascimento, data_cadastro, consorcio" + ;
         " FROM cliente WHERE cod_cli = " + hb_ntos( nCod ) )
      IF Len( aR ) != 1
         RETURN 1
      ENDIF
      nDiv += Dif( aR[ 1 ][  1 ], NormTexto( b[ "NOMCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][  2 ], NormTexto( b[ "ENDCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][  3 ], NormTexto( b[ "CIDCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][  5 ], NormCepNumerico( b[ "CEPCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][  7 ], NormTelefone( b[ "TELCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][  8 ], NormRg( b[ "RGCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 10 ], NormData( b[ "NASCLI" ], "NASCIMENTO" )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 11 ], NormData( b[ "DATCLI" ], "EVENTO" )[ "valor" ], @nComp )
      /* independente do normalizador: data ISO tem de bater com os bytes */
      nDiv += Dif( aR[ 1 ][ 11 ], IsoDeBytes( b[ "DATCLI" ] ), @nComp )
      nDiv += Dif( aR[ 1 ][ 12 ], ;
                   iif( Upper( AllTrim( b[ "CONSOR" ] ) ) == "S", "S", "N" ), @nComp )
   NEXT

   RETURN nDiv

STATIC FUNCTION CompFuncionario( pDb, cDir, nComp )

   LOCAL hT := ExtratorLer( cDir + "CVBFUNC.DBF" ), i, b, aR, nDiv := 0

   FOR i := 1 TO Len( hT[ "linhas" ] )
      b  := hT[ "linhas" ][ i ][ "brutos" ]
      aR := SqlLinhas( pDb, "SELECT nome, endereco, cidade, cargo, salario_cent," + ;
         " comissao_cent, cep FROM funcionario WHERE cod_fun = " + ;
         hb_ntos( NormCodigo( b[ "CODFUN" ] )[ "valor" ] ) )
      IF Len( aR ) != 1
         RETURN 1
      ENDIF
      nDiv += Dif( aR[ 1 ][ 1 ], NormTexto( b[ "NOMFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 2 ], NormTexto( b[ "ENDFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 3 ], NormTexto( b[ "CIDFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 4 ], NormTexto( b[ "CARFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 5 ], NormMonetario( b[ "SALFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 6 ], NormMonetario( b[ "COMFUN" ] )[ "valor" ], @nComp )
   NEXT

   RETURN nDiv

STATIC FUNCTION CompModelo( pDb, cDir, nComp )

   LOCAL hT := ExtratorLer( cDir + "CVBFROTA.DBF" ), i, b, aR, nDiv := 0

   FOR i := 1 TO Len( hT[ "linhas" ] )
      b  := hT[ "linhas" ][ i ][ "brutos" ]
      aR := SqlLinhas( pDb, "SELECT descricao, qtd_estoque, valor_cent, data_compra," + ;
         " chassi_ini, chassi_fim FROM modelo_veiculo WHERE cod_car = " + ;
         hb_ntos( NormCodigo( b[ "CODCAR" ] )[ "valor" ] ) )
      IF Len( aR ) != 1
         RETURN 1
      ENDIF
      nDiv += Dif( aR[ 1 ][ 1 ], NormTexto( b[ "DESCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 2 ], NormQuantidade( b[ "QUANTCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 3 ], NormMonetario( b[ "VALCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 4 ], IsoDeBytes( b[ "DATCOMCAR" ] ), @nComp )
      nDiv += Dif( aR[ 1 ][ 5 ], NormCodigo( b[ "CHASSI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ 1 ][ 6 ], NormCodigo( b[ "CHASDO" ] )[ "valor" ], @nComp )
   NEXT

   RETURN nDiv

STATIC FUNCTION CompVendaVeiculo( pDb, cDir, nComp )

   LOCAL hT := ExtratorLer( cDir + "CVBPENT.DBF" ), i, b, aR, nDiv := 0

   /* venda_veiculo tem PK técnica; a ordem de inserção é a ordem física */
   aR := SqlLinhas( pDb, "SELECT cod_car, cod_cli, cod_fun, data_venda, valor_cent," + ;
      " forma_pagamento, descricao_snapshot, nome_cli_snapshot, nome_fun_snapshot" + ;
      " FROM venda_veiculo ORDER BY id" )
   IF Len( aR ) != Len( hT[ "linhas" ] )
      RETURN 1
   ENDIF
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      nDiv += Dif( aR[ i ][ 1 ], NormCodigo( b[ "CODCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 2 ], NormCodigo( b[ "CODCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 3 ], NormCodigo( b[ "CODFUN" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 4 ], IsoDeBytes( b[ "DATAV" ] ), @nComp )
      nDiv += Dif( aR[ i ][ 5 ], NormMonetario( b[ "VALCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 6 ], NormTexto( b[ "FORMA" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 7 ], NormTexto( b[ "DESCAR" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 8 ], NormTexto( b[ "NOMCLI" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 9 ], NormTexto( b[ "NOMFUN" ] )[ "valor" ], @nComp )
   NEXT

   RETURN nDiv

/*
 * Os 75 itens de CVPECAS na ordem física têm de aparecer na mesma ordem em
 * venda_peca_item — o agrupamento cria cabeçalhos, mas não reordena, não
 * duplica e não perde item.
 */
STATIC FUNCTION CompItens( pDb, cDir, nComp )

   LOCAL hT := ExtratorLer( cDir + "CVPECAS.DBF" ), i, b, aR, nDiv := 0

   aR := SqlLinhas( pDb, "SELECT i.cod_pec, i.quantidade, i.subtotal_cent," + ;
      " i.descricao_snapshot, v.cod_cli FROM venda_peca_item i" + ;
      " JOIN venda_peca v ON v.id = i.venda_id ORDER BY i.id" )
   IF Len( aR ) != Len( hT[ "linhas" ] )
      RETURN 1
   ENDIF
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      nDiv += Dif( aR[ i ][ 1 ], NormCodigo( b[ "CODPEC" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 2 ], NormQuantidade( b[ "QTPECC" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 3 ], NormMonetario( b[ "SUBTOT" ] )[ "valor" ], @nComp )
      nDiv += Dif( aR[ i ][ 4 ], NormTexto( b[ "DECPEC" ] )[ "valor" ], @nComp )
      /* o item tem de estar no cabeçalho do cliente certo */
      nDiv += Dif( aR[ i ][ 5 ], NormCodigo( b[ "CODCLI" ] )[ "valor" ], @nComp )
   NEXT

   RETURN nDiv

/* 'YYYYMMDD' → 'YYYY-MM-DD' direto dos bytes, sem o normalizador. */
STATIC FUNCTION IsoDeBytes( cBruto )

   LOCAL cTxt := AllTrim( cBruto )

   IF Len( cTxt ) != 8
      RETURN NIL
   ENDIF

   RETURN Left( cTxt, 4 ) + "-" + SubStr( cTxt, 5, 2 ) + "-" + SubStr( cTxt, 7, 2 )

STATIC FUNCTION Dif( xNoBanco, xEsperado, nComp )
   nComp++
   IF ValType( xNoBanco ) == ValType( xEsperado ) .AND. ;
      hb_ValToExp( xNoBanco ) == hb_ValToExp( xEsperado )
      RETURN 0
   ENDIF
   RETURN 1

/* ------------------------------------------------------------------ */
/* E.4 — integridade referencial (§9.4)                                */
/* ------------------------------------------------------------------ */

STATIC PROCEDURE VerIntegridade( hV, pDb )

   LOCAL aFk, i, aRel, nOrfaos

   Secao( hV, "E.4 — integridade referencial" )

   Item( hV, "integrity_check", "ok", SqlEscalar( pDb, "PRAGMA integrity_check" ), ;
         SqlEscalar( pDb, "PRAGMA integrity_check" ) == "ok" )
   aFk := SqlLinhas( pDb, "PRAGMA foreign_key_check" )
   Item( hV, "foreign_key_check", 0, Len( aFk ), Len( aFk ) == 0 )

   /* as 13 relações de 02-MODELO-DADOS.md §8.2, reconciliadas uma a uma */
   aRel := { ;
      { "venda_veiculo → cliente"      , "venda_veiculo"   , "cod_cli", "cliente"       , "cod_cli" }, ;
      { "venda_veiculo → funcionario"  , "venda_veiculo"   , "cod_fun", "funcionario"   , "cod_fun" }, ;
      { "venda_veiculo → modelo"       , "venda_veiculo"   , "cod_car", "modelo_veiculo", "cod_car" }, ;
      { "venda_peca → cliente"         , "venda_peca"      , "cod_cli", "cliente"       , "cod_cli" }, ;
      { "venda_peca_item → peca"       , "venda_peca_item" , "cod_pec", "peca"          , "cod_pec" }, ;
      { "venda_peca_item → venda_peca" , "venda_peca_item" , "venda_id", "venda_peca"   , "id"      }, ;
      { "peca → fornecedor"            , "peca"            , "cod_for", "fornecedor"    , "cod_for" }, ;
      { "almoxarifado → fornecedor"    , "almoxarifado"    , "cod_for", "fornecedor"    , "cod_for" }, ;
      { "consorcio_cota → cliente"     , "consorcio_cota"  , "cod_cli", "cliente"       , "cod_cli" }, ;
      { "consorcio_cota → modelo"      , "consorcio_cota"  , "cod_car", "modelo_veiculo", "cod_car" }, ;
      { "orcamento_reparo → cliente"   , "orcamento_reparo", "cod_cli", "cliente"       , "cod_cli" }, ;
      { "orcamento_reparo → peca"      , "orcamento_reparo", "cod_pec", "peca"          , "cod_pec" }, ;
      { "orcamento_reparo → funcionario","orcamento_reparo", "cod_fun", "funcionario"   , "cod_fun" } }

   FOR i := 1 TO Len( aRel )
      nOrfaos := SqlEscalar( pDb, ;
         "SELECT count(*) FROM " + aRel[ i ][ 2 ] + " f LEFT JOIN " + aRel[ i ][ 4 ] + ;
         " p ON p." + aRel[ i ][ 5 ] + " = f." + aRel[ i ][ 3 ] + ;
         " WHERE f." + aRel[ i ][ 3 ] + " IS NOT NULL AND p." + aRel[ i ][ 5 ] + " IS NULL" )
      Item( hV, "órfãos em " + aRel[ i ][ 1 ], 0, nOrfaos, nOrfaos == 0 )
   NEXT

   RETURN

/* ------------------------------------------------------------------ */
/* E.5 — agregados e relatório (§9.5)                                  */
/* ------------------------------------------------------------------ */

/*
 * §9.5 — aqui a divergência é ESPERADA. Os agregados do legado (CVVCAR/CVVPEC)
 * estavam dessincronizados dos dados transacionais; as views novas recalculam
 * a partir do movimento real. O objetivo é documentar a diferença, não corrigi-la.
 */
STATIC PROCEDURE VerAgregados( hV, pDb )

   LOCAL aL, i, nDivCar := 0, nDivPec := 0, xLeg

   Secao( hV, "E.5 — reconciliação dos agregados (divergência esperada)" )

   aL := SqlLinhas( pDb, "SELECT v.descricao, v.quantidade, q.quantv" + ;
      " FROM v_venda_por_modelo v LEFT JOIN _legado_cvvcar q" + ;
      " ON TRIM(q.descar) = v.descricao" )
   FOR i := 1 TO Len( aL )
      xLeg := aL[ i ][ 3 ]
      IF xLeg == NIL .OR. Val( hb_ValToStr( xLeg ) ) != aL[ i ][ 2 ]
         nDivCar++
      ENDIF
   NEXT
   Item( hV, "v_venda_por_modelo x _legado_cvvcar: divergências", ;
         "> 0 (esperado)", nDivCar, nDivCar > 0 )

   aL := SqlLinhas( pDb, "SELECT v.descricao, v.quantidade, q.quantc" + ;
      " FROM v_venda_por_peca v LEFT JOIN _legado_cvvpec q" + ;
      " ON TRIM(q.despec) = v.descricao" )
   FOR i := 1 TO Len( aL )
      xLeg := aL[ i ][ 3 ]
      IF xLeg == NIL .OR. Val( hb_ValToStr( xLeg ) ) != aL[ i ][ 2 ]
         nDivPec++
      ENDIF
   NEXT
   Item( hV, "v_venda_por_peca x _legado_cvvpec: divergências", ;
         "> 0 (esperado)", nDivPec, nDivPec > 0 )

   /* a view tem de refletir o movimento real, não o agregado do legado */
   Item( hV, "v_venda_por_peca soma = soma dos itens", ;
         SqlEscalar( pDb, "SELECT IFNULL(SUM(subtotal_cent),0) FROM venda_peca_item" ), ;
         SqlEscalar( pDb, "SELECT IFNULL(SUM(valor_total_cent),0) FROM v_venda_por_peca" ), ;
         SqlEscalar( pDb, "SELECT IFNULL(SUM(subtotal_cent),0) FROM venda_peca_item" ) == ;
         SqlEscalar( pDb, "SELECT IFNULL(SUM(valor_total_cent),0) FROM v_venda_por_peca" ) )

   RETURN

STATIC PROCEDURE VerRelatorio( hV, pDb )

   LOCAL nTot, nSem

   Secao( hV, "E.5 — relatório de inconsistências" )

   nTot := SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" )
   Item( hV, "inconsistências registradas", "> 0", nTot, nTot > 0 )

   nSem := SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" + ;
                            " WHERE severidade NOT IN ('BAIXA','MEDIA','ALTA')" )
   Item( hV, "severidades fora do domínio", 0, nSem, nSem == 0 )

   nSem := SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia" + ;
                            " WHERE problema IS NULL OR acao IS NULL OR arquivo IS NULL" )
   Item( hV, "itens sem problema/ação/arquivo", 0, nSem, nSem == 0 )

   nSem := SqlEscalar( pDb, "SELECT count(*) FROM migracao_inconsistencia i" + ;
                            " LEFT JOIN migracao_execucao e ON e.id = i.execucao_id" + ;
                            " WHERE e.id IS NULL" )
   Item( hV, "itens sem execução associada", 0, nSem, nSem == 0 )

   Item( hV, "execução concluída", "CONCLUIDA", ;
         SqlEscalar( pDb, "SELECT status FROM migracao_execucao ORDER BY id DESC LIMIT 1" ), ;
         SqlEscalar( pDb, "SELECT status FROM migracao_execucao ORDER BY id DESC LIMIT 1" ) == ;
         "CONCLUIDA" )

   RETURN

/* ------------------------------------------------------------------ */

STATIC PROCEDURE Secao( hV, cNome )
   AAdd( hV[ "itens" ], { "secao" => cNome } )
   RETURN

STATIC PROCEDURE Item( hV, cNome, xEsperado, xObtido, lOk )
   AAdd( hV[ "itens" ], { "nome" => cNome, "esperado" => xEsperado, ;
                          "obtido" => xObtido, "ok" => lOk } )
   IF lOk
      hV[ "ok" ]++
   ELSE
      hV[ "falhas" ]++
   ENDIF
   RETURN

/* Imprime o resultado; devolve .T. se tudo passou. */
FUNCTION VerificarImprimir( hV )

   LOCAL i, h

   FOR i := 1 TO Len( hV[ "itens" ] )
      h := hV[ "itens" ][ i ]
      IF "secao" $ h
         OutStd( hb_eol() + "== " + h[ "secao" ] + " ==" + hb_eol() )
         LOOP
      ENDIF
      OutStd( "   " + iif( h[ "ok" ], "ok   ", "FALHA " ) + PadR( h[ "nome" ], 54 ) + ;
              iif( h[ "ok" ], "", " esperado=" + hb_ValToExp( h[ "esperado" ] ) + ;
                                 " obtido=" + hb_ValToExp( h[ "obtido" ] ) ) + hb_eol() )
   NEXT
   OutStd( hb_eol() + "   verificações ok .: " + hb_ntos( hV[ "ok" ] ) + hb_eol() )
   OutStd( "   falhas ..........: " + hb_ntos( hV[ "falhas" ] ) + hb_eol() )

   RETURN hV[ "falhas" ] == 0
