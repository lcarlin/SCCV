/*
 * carregador.prg — FASES D.4 e D.5
 *
 * Carga do legado normalizado no SQLite, e as transformações estruturais.
 * Especificação: docs/08-MIGRACAO-DADOS.md §3 (escopo), §6 (transformações),
 * §7 (CVREPAR); ordem topológica em docs/07-DEPENDENCIAS.md §2.2.
 *
 * REGRAS DA CARGA
 * ---------------
 * - Uma transação POR TABELA (08 §5). Falha em qualquer registro → ROLLBACK
 *   daquela tabela e a migração para. Nunca fica um banco meio migrado sem
 *   sinalização.
 * - Ordem topológica: nada é inserido antes daquilo a que se refere.
 * - Todo INSERT usa statement preparado com bind por tipo (src/database/sql.prg).
 * - Nada é descartado e nada é corrigido em silêncio: cada desvio vira uma
 *   inconsistência ancorada no arquivo, registro, chave e campo de origem.
 */

#define ORIGEM_INDETERMINADA  "INDETERMINADO"

STATIC s_aUf := { "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS", ;
                  "MT","PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC", ;
                  "SE","SP","TO" }

/*
 * Executa a carga inteira. Devolve um hash:
 *   { "lidos", "gravados", "tabelas" => {nome=>qtde}, "erro" => NIL ou texto }
 */
FUNCTION CarregarTudo( pDb, cDir, hReg )

   LOCAL hRes := { "lidos" => 0, "gravados" => 0, "tabelas" => { => }, "erro" => NIL }
   LOCAL aEtapas, i, cErro

   IF !( Right( cDir, 1 ) == hb_ps() )
      cDir += hb_ps()
   ENDIF

   /* ordem topológica — docs/07-DEPENDENCIAS.md §2.2 */
   aEtapas := { ;
      { "cliente"          , {| | CarCliente( pDb, cDir, hReg, hRes ) } }, ;
      { "funcionario"      , {| | CarFuncionario( pDb, cDir, hReg, hRes ) } }, ;
      { "fornecedor"       , {| | CarFornecedor( pDb, cDir, hReg, hRes ) } }, ;
      { "modelo_veiculo"   , {| | CarModelo( pDb, cDir, hReg, hRes ) } }, ;
      { "peca"             , {| | CarPeca( pDb, cDir, hReg, hRes ) } }, ;
      { "almoxarifado"     , {| | CarAlmoxarifado( pDb, cDir, hReg, hRes ) } }, ;
      { "venda_veiculo"    , {| | CarVendaVeiculo( pDb, cDir, hReg, hRes ) } }, ;
      { "venda_peca"       , {| | CarVendaPeca( pDb, cDir, hReg, hRes ) } }, ;
      { "consorcio_cota"   , {| | CarConsorcio( pDb, cDir, hReg, hRes ) } }, ;
      { "orcamento_reparo" , {| | CarReparo( pDb, cDir, hReg, hRes ) } }, ;
      { "pedido"           , {| | CarPedido( pDb, cDir, hReg, hRes ) } }, ;
      { "sequencia"        , {| | CarSequencia( pDb, cDir, hReg, hRes ) } }, ;
      { "quarentena"       , {| | CarQuarentena( pDb, cDir, hReg, hRes ) } }, ;
      { "observações"      , {| | CarObservacoes( pDb, cDir, hReg, hRes ) } } }

   FOR i := 1 TO Len( aEtapas )
      cErro := Eval( aEtapas[ i ][ 2 ] )
      IF cErro != NIL
         hRes[ "erro" ] := aEtapas[ i ][ 1 ] + " — " + cErro
         RETURN hRes
      ENDIF
   NEXT

   RETURN hRes

/* ------------------------------------------------------------------ */
/* Cadastros — nível 0                                                 */
/* ------------------------------------------------------------------ */

STATIC FUNCTION CarCliente( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBCLIEN.DBF"
   LOCAL hCep, hTel, hCpf, hNasc, hCad, cUf, nGrav := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODCLI=" + AllTrim( b[ "CODCLI" ] )
      hRes[ "lidos" ]++

      hCep  := NormCepNumerico( b[ "CEPCLI" ] )
      hTel  := NormTelefone( b[ "TELCLI" ] )
      hCpf  := NormCpf( b[ "CICCLI" ] )
      hNasc := NormData( b[ "NASCLI" ], "NASCIMENTO" )
      hCad  := NormData( b[ "DATCLI" ], "EVENTO" )
      cUf   := CarUf( hReg, b[ "UFCLI" ], cArq, nRec, cChave )

      IncAbsorver( hReg, hCep,  cArq, nRec, cChave, "CEPCLI", AllTrim( b[ "CEPCLI" ] ) )
      IncAbsorver( hReg, hTel,  cArq, nRec, cChave, "TELCLI", AllTrim( b[ "TELCLI" ] ) )
      IncAbsorver( hReg, hCpf,  cArq, nRec, cChave, "CICCLI", AllTrim( b[ "CICCLI" ] ) )
      IncAbsorver( hReg, hNasc, cArq, nRec, cChave, "NASCLI", AllTrim( b[ "NASCLI" ] ) )
      IncAbsorver( hReg, hCad,  cArq, nRec, cChave, "DATCLI", AllTrim( b[ "DATCLI" ] ) )

      /* data_cadastro é NOT NULL no schema e DATCLI nunca está vazio no acervo
         (medido na FASE D.2). Se algum dia estiver, a carga precisa parar em
         vez de inventar uma data. */
      IF hCad[ "valor" ] == NIL
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": DATCLI vazio e " + ;
                "cliente.data_cadastro é NOT NULL — sem origem para o valor"
      ENDIF

      /* consorcio é TEXT com CHECK IN ('S','N') no schema, não 0/1 */
      nRc := SqlExecBind( pDb, ;
         "INSERT INTO cliente (cod_cli, nome, endereco, cidade, cep, cep_original," + ;
         " uf, telefone, telefone_original, rg, cpf, cpf_original, cpf_valido," + ;
         " nascimento, data_cadastro, consorcio, excluido)" + ;
         " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODCLI" ] )[ "valor" ], ;
         NormTexto( b[ "NOMCLI" ] )[ "valor" ], ;
         NormTexto( b[ "ENDCLI" ] )[ "valor" ], ;
         NormTexto( b[ "CIDCLI" ] )[ "valor" ], ;
         hCep[ "valor" ], hCep[ "original" ], ;
         cUf, ;
         hTel[ "valor" ], hTel[ "original" ], ;
         NormRg( b[ "RGCLI" ] )[ "valor" ], ;
         hCpf[ "valor" ], hCpf[ "original" ], hCpf[ "valido" ], ;
         hNasc[ "valor" ], hCad[ "valor" ], ;
         iif( Upper( AllTrim( b[ "CONSOR" ] ) ) == "S", "S", "N" ), ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "cliente" ] := nGrav

   RETURN NIL

STATIC FUNCTION CarFuncionario( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBFUNC.DBF", hCep, nGrav := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODFUN=" + AllTrim( b[ "CODFUN" ] )
      hRes[ "lidos" ]++

      hCep := NormCepTexto( b[ "CEPFUN" ] )
      IncAbsorver( hReg, hCep, cArq, nRec, cChave, "CEPFUN", AllTrim( b[ "CEPFUN" ] ) )

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO funcionario (cod_fun, nome, endereco, cidade, cep," + ;
         " cep_original, cargo, salario_cent, comissao_cent, excluido)" + ;
         " VALUES (?,?,?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODFUN" ] )[ "valor" ], ;
         NormTexto( b[ "NOMFUN" ] )[ "valor" ], ;
         NormTexto( b[ "ENDFUN" ] )[ "valor" ], ;
         NormTexto( b[ "CIDFUN" ] )[ "valor" ], ;
         hCep[ "valor" ], hCep[ "original" ], ;
         NormTexto( b[ "CARFUN" ] )[ "valor" ], ;
         CarCent( hReg, b[ "SALFUN" ], cArq, nRec, cChave, "SALFUN" ), ;
         CarCent( hReg, b[ "COMFUN" ], cArq, nRec, cChave, "COMFUN" ), ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "funcionario" ] := nGrav

   RETURN NIL

STATIC FUNCTION CarFornecedor( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, v, nRec, cChave, nRc, cArq := "CVBFORNE.DBF"
   LOCAL hCep, hTel, hCnpj, nGrav := 0, cObs

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      v      := hT[ "linhas" ][ i ][ "valores" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODFOR=" + AllTrim( b[ "CODFOR" ] )
      hRes[ "lidos" ]++

      hCep  := NormCepTexto( b[ "CEPFOR" ] )
      hTel  := NormTelefone( b[ "TELFOR" ] )
      hCnpj := NormCnpj( b[ "CGCFAB" ] )
      IncAbsorver( hReg, hCep,  cArq, nRec, cChave, "CEPFOR", AllTrim( b[ "CEPFOR" ] ) )
      IncAbsorver( hReg, hTel,  cArq, nRec, cChave, "TELFOR", AllTrim( b[ "TELFOR" ] ) )
      IncAbsorver( hReg, hCnpj, cArq, nRec, cChave, "CGCFAB", AllTrim( b[ "CGCFAB" ] ) )

      /* §6.3 — o memo vem do valor tipado: o bruto do .DBF traz só o nº do bloco */
      cObs := NormTexto( v[ "OBSFOR" ] )[ "valor" ]

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO fornecedor (cod_for, nome, telefone, telefone_original," + ;
         " cep, cep_original, cidade, endereco, cod_item, desc_item, fabrica," + ;
         " cnpj, cnpj_original, cnpj_valido, observacoes, excluido)" + ;
         " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODFOR" ] )[ "valor" ], ;
         NormTexto( b[ "NOMFOR" ] )[ "valor" ], ;
         hTel[ "valor" ], hTel[ "original" ], ;
         hCep[ "valor" ], hCep[ "original" ], ;
         NormTexto( b[ "CIDFOR" ] )[ "valor" ], ;
         NormTexto( b[ "ENDFOR" ] )[ "valor" ], ;
         NormTexto( b[ "CODITE" ] )[ "valor" ], ;
         NormTexto( b[ "DESITE" ] )[ "valor" ], ;
         NormTexto( b[ "NOMFAB" ] )[ "valor" ], ;
         hCnpj[ "valor" ], hCnpj[ "original" ], hCnpj[ "valido" ], ;
         cObs, ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "fornecedor" ] := nGrav

   RETURN NIL

STATIC FUNCTION CarModelo( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBFROTA.DBF", hData, nGrav := 0
   LOCAL nIni, nFim

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODCAR=" + AllTrim( b[ "CODCAR" ] )
      hRes[ "lidos" ]++

      hData := NormData( b[ "DATCOMCAR" ], "EVENTO" )
      IncAbsorver( hReg, hData, cArq, nRec, cChave, "DATCOMCAR", AllTrim( b[ "DATCOMCAR" ] ) )

      nIni := NormCodigo( b[ "CHASSI" ] )[ "valor" ]
      nFim := NormCodigo( b[ "CHASDO" ] )[ "valor" ]
      /* o schema exige chassi_fim >= chassi_ini; se vier invertido, não
         reordenamos — isso mudaria o dado. Registra e deixa ambos NULL. */
      IF nIni != NIL .AND. nFim != NIL .AND. nFim < nIni
         IncRegistrar( hReg, cArq, nRec, cChave, "CHASSI/CHASDO", ;
            AllTrim( b[ "CHASSI" ] ) + ".." + AllTrim( b[ "CHASDO" ] ), ;
            "Faixa de chassi invertida (fim < início)", ;
            "Ambos gravados como NULL; valores originais neste relatório", "ALTA" )
         nIni := NIL
         nFim := NIL
      ENDIF

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque, valor_cent," + ;
         " data_compra, chassi_ini, chassi_fim, excluido) VALUES (?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODCAR" ] )[ "valor" ], ;
         NormTexto( b[ "DESCAR" ] )[ "valor" ], ;
         CarQtd( hReg, b[ "QUANTCAR" ], cArq, nRec, cChave, "QUANTCAR" ), ;
         CarCent( hReg, b[ "VALCAR" ], cArq, nRec, cChave, "VALCAR" ), ;
         hData[ "valor" ], nIni, nFim, ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "modelo_veiculo" ] := nGrav

   RETURN NIL

/* ------------------------------------------------------------------ */
/* Cadastros — nível 1                                                 */
/* ------------------------------------------------------------------ */

STATIC FUNCTION CarPeca( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBPECAS.DBF", nGrav := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODPEC=" + AllTrim( b[ "CODPEC" ] )
      hRes[ "lidos" ]++

      /* NOMFOR é desnormalização do legado; a fonte da verdade é fornecedor.nome.
         Divergência é registrada, não corrigida (I-14). */
      CarConfereSnapshot( pDb, hReg, cArq, nRec, cChave, "NOMFOR", ;
         NormTexto( b[ "NOMFOR" ] )[ "valor" ], ;
         "SELECT nome FROM fornecedor WHERE cod_for = " + ;
         hb_ntos( NormCodigo( b[ "CODFOR" ] )[ "valor" ] ) )

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO peca (cod_pec, descricao, qtd_estoque, valor_unit_cent," + ;
         " qtd_minima, cod_for, excluido) VALUES (?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODPEC" ] )[ "valor" ], ;
         NormTexto( b[ "DECPEC" ] )[ "valor" ], ;
         CarQtd( hReg, b[ "QTDPEC" ], cArq, nRec, cChave, "QTDPEC" ), ;
         CarCent( hReg, b[ "VALUNI" ], cArq, nRec, cChave, "VALUNI" ), ;
         CarQtd( hReg, b[ "QTDMIN" ], cArq, nRec, cChave, "QTDMIN" ), ;
         NormCodigo( b[ "CODFOR" ] )[ "valor" ], ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "peca" ] := nGrav

   RETURN NIL

STATIC FUNCTION CarAlmoxarifado( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBALMOX.DBF", nGrav := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODALM=" + AllTrim( b[ "CODALM" ] )
      hRes[ "lidos" ]++

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO almoxarifado (cod_alm, descricao, qtd_estoque," + ;
         " valor_unit_cent, qtd_minima, cod_for, excluido) VALUES (?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODALM" ] )[ "valor" ], ;
         NormTexto( b[ "DESCALM" ] )[ "valor" ], ;
         CarQtd( hReg, b[ "QUANTALM" ], cArq, nRec, cChave, "QUANTALM" ), ;
         CarCent( hReg, b[ "VALALM" ], cArq, nRec, cChave, "VALALM" ), ;
         CarQtd( hReg, b[ "QUANALM" ], cArq, nRec, cChave, "QUANALM" ), ;
         NormCodigo( b[ "CODFORALM" ] )[ "valor" ], ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "almoxarifado" ] := nGrav

   RETURN NIL

/* ------------------------------------------------------------------ */
/* Movimento — nível 2                                                 */
/* ------------------------------------------------------------------ */

STATIC FUNCTION CarVendaVeiculo( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, nRc, cArq := "CVBPENT.DBF"
   LOCAL hData, nGrav := 0, nValor

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODCLI=" + AllTrim( b[ "CODCLI" ] ) + ";CODCAR=" + AllTrim( b[ "CODCAR" ] )
      hRes[ "lidos" ]++

      hData := NormData( b[ "DATAV" ], "EVENTO" )
      IncAbsorver( hReg, hData, cArq, nRec, cChave, "DATAV", AllTrim( b[ "DATAV" ] ) )

      nValor := CarCent( hReg, b[ "VALCAR" ], cArq, nRec, cChave, "VALCAR" )
      IF nValor == 0                                          /* I-23 */
         IncRegistrar( hReg, cArq, nRec, cChave, "VALCAR", AllTrim( b[ "VALCAR" ] ), ;
            "Venda de veículo com valor zero", ;
            "Importada como está; valor não é inferido do cadastro", "MEDIA" )
      ENDIF

      /* DESCAR e NOMCLI/NOMFUN são desnormalização do legado (I-13) */
      CarConfereSnapshot( pDb, hReg, cArq, nRec, cChave, "DESCAR", ;
         NormTexto( b[ "DESCAR" ] )[ "valor" ], ;
         "SELECT descricao FROM modelo_veiculo WHERE cod_car = " + ;
         hb_ntos( NormCodigo( b[ "CODCAR" ] )[ "valor" ] ) )

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO venda_veiculo (cod_car, cod_cli, cod_fun, data_venda," + ;
         " valor_cent, forma_pagamento, descricao_snapshot, nome_cli_snapshot," + ;
         " nome_fun_snapshot, excluido) VALUES (?,?,?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODCAR" ] )[ "valor" ], ;
         NormCodigo( b[ "CODCLI" ] )[ "valor" ], ;
         NormCodigo( b[ "CODFUN" ] )[ "valor" ], ;
         hData[ "valor" ], nValor, ;
         NormTexto( b[ "FORMA" ] )[ "valor" ], ;
         NormTexto( b[ "DESCAR" ] )[ "valor" ], ;
         NormTexto( b[ "NOMCLI" ] )[ "valor" ], ;
         NormTexto( b[ "NOMFUN" ] )[ "valor" ], ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "venda_veiculo" ] := nGrav

   RETURN NIL

/*
 * D.5 — §6.1: CVPECAS (itens soltos) → venda_peca (cabeçalho) + venda_peca_item.
 *
 * O legado não grava número de venda. O único agrupamento observável é VALTOT
 * preenchido apenas no último item da compra (RN-027). O algoritmo abaixo é o
 * da especificação, literal.
 *
 * `origem` NÃO é inferida: todos os cabeçalhos recebem 'INDETERMINADO' (Q-02).
 */
STATIC FUNCTION CarVendaPeca( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, cChave, cArq := "CVPECAS.DBF"
   LOCAL aVendas := {}, hVenda := NIL, nCodCli, nValTot, nSub
   LOCAL nRc, j, nIdVenda, nGravV := 0, nGravI := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   /* ---- passo 1: agrupar em memória, na ordem física (ordem de inserção) ---- */
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b       := hT[ "linhas" ][ i ][ "brutos" ]
      nRec    := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave  := "CODCLI=" + AllTrim( b[ "CODCLI" ] )
      nCodCli := NormCodigo( b[ "CODCLI" ] )[ "valor" ]
      hRes[ "lidos" ]++

      IF hVenda == NIL
         hVenda := CarNovaVenda( nCodCli, NormTexto( b[ "NOMCLI" ] )[ "valor" ] )
      ELSEIF !( hVenda[ "cod_cli" ] == nCodCli )
         /* troca de cliente sem VALTOT: fecha a anterior por heurística */
         IncRegistrar( hReg, cArq, nRec, cChave, "CODCLI", AllTrim( b[ "CODCLI" ] ), ;
            "Troca de cliente sem VALTOT no item anterior — fim de venda inferido", ;
            "Venda anterior fechada pelo total dos subtotais; origem INDETERMINADO", ;
            "BAIXA" )
         AAdd( aVendas, hVenda )
         hVenda := CarNovaVenda( nCodCli, NormTexto( b[ "NOMCLI" ] )[ "valor" ] )
      ENDIF

      nSub := CarCent( hReg, b[ "SUBTOT" ], cArq, nRec, cChave, "SUBTOT" )
      AAdd( hVenda[ "itens" ], { ;
         "cod_pec"   => NormCodigo( b[ "CODPEC" ] )[ "valor" ], ;
         "quantidade"=> CarQtd( hReg, b[ "QTPECC" ], cArq, nRec, cChave, "QTPECC" ), ;
         "subtotal"  => nSub, ;
         "descricao" => NormTexto( b[ "DECPEC" ] )[ "valor" ], ;
         "registro"  => nRec } )
      hVenda[ "soma_itens" ] += nSub

      nValTot := CarCent( hReg, b[ "VALTOT" ], cArq, nRec, cChave, "VALTOT" )
      IF nValTot != NIL .AND. nValTot > 0
         hVenda[ "total" ]    := nValTot
         hVenda[ "registro" ] := nRec
         hVenda[ "chave" ]    := cChave
         /* §6.1: comparar VALTOT com a soma dos subtotais; divergência é
            registrada, nunca corrigida — os dois valores são gravados. */
         IF nValTot != hVenda[ "soma_itens" ]
            IncRegistrar( hReg, cArq, nRec, cChave, "VALTOT", AllTrim( b[ "VALTOT" ] ), ;
               "VALTOT (" + CarMoeda( nValTot ) + ") difere da soma dos subtotais (" + ;
               CarMoeda( hVenda[ "soma_itens" ] ) + ")", ;
               "VALTOT gravado em total_cent; soma dos itens preservada nos itens", ;
               "MEDIA" )
         ENDIF
         AAdd( aVendas, hVenda )
         hVenda := NIL
      ENDIF
   NEXT
   IF hVenda != NIL .AND. Len( hVenda[ "itens" ] ) > 0
      hVenda[ "total" ] := hVenda[ "soma_itens" ]
      AAdd( aVendas, hVenda )
   ENDIF

   /* ---- passo 2: gravar ---- */
   SqlInicia( pDb )
   FOR i := 1 TO Len( aVendas )
      hVenda := aVendas[ i ]
      nRc := SqlExecBind( pDb, ;
         "INSERT INTO venda_peca (cod_cli, cod_fun, origem, data_venda," + ;
         " total_cent, nome_cli_snapshot, excluido) VALUES (?,?,?,?,?,?,?)", { ;
         hVenda[ "cod_cli" ], NIL, ORIGEM_INDETERMINADA, NIL, ;
         iif( hVenda[ "total" ] == NIL, hVenda[ "soma_itens" ], hVenda[ "total" ] ), ;
         hVenda[ "nome_cli" ], 0 } )
      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " cabeçalho " + hb_ntos( i ) + ": " + SqlErro( pDb )
      ENDIF
      nIdVenda := SqlUltimoId( pDb )
      nGravV++

      FOR j := 1 TO Len( hVenda[ "itens" ] )
         nRc := SqlExecBind( pDb, ;
            "INSERT INTO venda_peca_item (venda_id, cod_pec, quantidade," + ;
            " valor_unit_cent, subtotal_cent, descricao_snapshot, ordem)" + ;
            " VALUES (?,?,?,?,?,?,?)", { ;
            nIdVenda, ;
            hVenda[ "itens" ][ j ][ "cod_pec" ], ;
            hVenda[ "itens" ][ j ][ "quantidade" ], ;
            NIL, ;                       /* CVPECAS não guarda valor unitário */
            hVenda[ "itens" ][ j ][ "subtotal" ], ;
            hVenda[ "itens" ][ j ][ "descricao" ], ;
            j } )
         IF nRc != 0
            SqlDesfaz( pDb )
            RETURN cArq + " item reg " + hb_ntos( hVenda[ "itens" ][ j ][ "registro" ] ) + ;
                   ": " + SqlErro( pDb )
         ENDIF
         nGravI++
      NEXT
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGravV + nGravI
   hRes[ "tabelas" ][ "venda_peca" ]      := nGravV
   hRes[ "tabelas" ][ "venda_peca_item" ] := nGravI

   RETURN NIL

STATIC FUNCTION CarNovaVenda( nCodCli, cNome )
   RETURN { "cod_cli" => nCodCli, "nome_cli" => cNome, "itens" => {}, ;
            "soma_itens" => 0, "total" => NIL, "registro" => 0, "chave" => NIL }

/*
 * D.5 — §6.2: CVBGRUPO + CVBGRUCO → consorcio_cota.
 *
 * CVBGRUCO (grupo fechado) entra primeiro e mantém os números originais.
 * De CVBGRUPO:
 *   - os excluídos são o resto da transferência (RN-018): NÃO entram; a
 *     evidência vai para _legado_cvbgrupo_excluido;
 *   - os ativos são um novo grupo em formação que herdou o número por defeito
 *     (RN-015): entram renumerados a partir do máximo de CVBGRUCO + 1, com
 *     inconsistência ALTA guardando o número original (D-25).
 */
STATIC FUNCTION CarConsorcio( pDb, cDir, hReg, hRes )

   LOCAL cErro, nProximo

   cErro := CarConsorcioArquivo( pDb, cDir, hReg, hRes, "CVBGRUCO.DBF", 1, 0 )
   IF cErro != NIL
      RETURN cErro
   ENDIF

   nProximo := SqlEscalar( pDb, "SELECT IFNULL(MAX(num_participante),0)+1 " + ;
                                "FROM consorcio_cota WHERE cod_gru = 1" )

   RETURN CarConsorcioArquivo( pDb, cDir, hReg, hRes, "CVBGRUPO.DBF", 0, nProximo )

STATIC FUNCTION CarConsorcioArquivo( pDb, cDir, hReg, hRes, cArq, nFechado, nRenumDe )

   LOCAL hT, i, b, nRec, cChave, nRc, hData, hMes, nGrav := 0, nNum, nOrig

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODGRU=" + AllTrim( b[ "CODGRU" ] ) + ";NUPGRU=" + AllTrim( b[ "NUPGRU" ] )
      hRes[ "lidos" ]++

      /* excluídos de CVBGRUPO: evidência, não cota (RN-018) */
      IF hT[ "linhas" ][ i ][ "__EXCLUIDO" ]
         nRc := CarQuarentenaGrupo( pDb, b, nRec )
         IF nRc != 0
            SqlDesfaz( pDb )
            RETURN cArq + " reg " + hb_ntos( nRec ) + " (quarentena): " + SqlErro( pDb )
         ENDIF
         IncRegistrar( hReg, cArq, nRec, cChave, "(registro)", ;
            "CODCON=" + AllTrim( b[ "CODCON" ] ), ;
            "Registro marcado como excluído: é o resto da transferência para " + ;
            "CVBGRUCO ao fechar o grupo (RN-018)", ;
            "Não inserido em consorcio_cota; preservado em _legado_cvbgrupo_excluido", ;
            "BAIXA" )
         hRes[ "gravados" ]++
         hRes[ "tabelas" ][ "_legado_cvbgrupo_excluido" ] := ;
            iif( "_legado_cvbgrupo_excluido" $ hRes[ "tabelas" ], ;
                 hRes[ "tabelas" ][ "_legado_cvbgrupo_excluido" ], 0 ) + 1
         LOOP
      ENDIF

      hData := NormData( b[ "DATCON" ], "EVENTO" )
      hMes  := NormNumeroRestrito( b[ "NUMMES" ], 0 )
      IncAbsorver( hReg, hData, cArq, nRec, cChave, "DATCON", AllTrim( b[ "DATCON" ] ) )
      IncAbsorver( hReg, hMes,  cArq, nRec, cChave, "NUMMES", AllTrim( b[ "NUMMES" ] ) )

      nOrig := NormCodigo( b[ "NUPGRU" ] )[ "valor" ]
      nNum  := nOrig
      IF nRenumDe > 0
         nNum := nRenumDe + nGrav
         IncRegistrar( hReg, cArq, nRec, cChave, "NUPGRU", hb_ntos( nOrig ), ;
            "Número de participante " + hb_ntos( nOrig ) + " colide com o grupo " + ;
            "já fechado — o legado reiniciou a numeração sem contar os excluídos (RN-015)", ;
            "Renumerado para " + hb_ntos( nNum ) + "; original neste relatório (D-25)", ;
            "ALTA" )
      ENDIF

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO consorcio_cota (cod_gru, num_participante, cod_cli, cod_car," + ;
         " valor_prestacao_cent, num_participantes_previsto, parcelas_restantes," + ;
         " parcelas_restantes_legado, data_adesao, grupo_fechado, sorteado, quitado," + ;
         " nome_snapshot, excluido) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", { ;
         NormCodigo( b[ "CODGRU" ] )[ "valor" ], nNum, ;
         NormCodigo( b[ "CODCON" ] )[ "valor" ], ;
         NormCodigo( b[ "CODCAR" ] )[ "valor" ], ;
         CarCent( hReg, b[ "VALPRE" ], cArq, nRec, cChave, "VALPRE" ), ;
         CarQtd( hReg, b[ "NUMPAR" ], cArq, nRec, cChave, "NUMPAR" ), ;
         hMes[ "valor" ], hMes[ "legado" ], ;
         hData[ "valor" ], nFechado, ;
         iif( "SORT" $ b, NormLogico( b[ "SORT" ] )[ "valor" ], 0 ), ;
         iif( "QUIT" $ b, NormLogico( b[ "QUIT" ] )[ "valor" ], 0 ), ;
         NormTexto( b[ "NOMCON" ] )[ "valor" ], 0 } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "consorcio_cota" ] := ;
      iif( "consorcio_cota" $ hRes[ "tabelas" ], hRes[ "tabelas" ][ "consorcio_cota" ], 0 ) + nGrav

   RETURN NIL

STATIC FUNCTION CarQuarentenaGrupo( pDb, b, nRec )
   RETURN SqlExecBind( pDb, ;
      "INSERT INTO _legado_cvbgrupo_excluido (registro, codcon, nomcon, codcar," + ;
      " codgru, valpre, numpag, numgru, grufec, numpar, datcon, nummes, nupgru)" + ;
      " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", { ;
      nRec, AllTrim( b[ "CODCON" ] ), AllTrim( b[ "NOMCON" ] ), AllTrim( b[ "CODCAR" ] ), ;
      AllTrim( b[ "CODGRU" ] ), AllTrim( b[ "VALPRE" ] ), AllTrim( b[ "NUMPAG" ] ), ;
      AllTrim( b[ "NUMGRU" ] ), AllTrim( b[ "GRUFEC" ] ), AllTrim( b[ "NUMPAR" ] ), ;
      AllTrim( b[ "DATCON" ] ), AllTrim( b[ "NUMMES" ] ), AllTrim( b[ "NUPGRU" ] ) } )

/* §7 — CVREPAR: tabela órfã, 4 registros de teste, sem FK obrigatória. */
STATIC FUNCTION CarReparo( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, v, nRec, cChave, nRc, cArq := "CVREPAR.DBF"
   LOCAL hData, nGrav := 0, nCli, nPec, nFun, nValor, lBranco

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b      := hT[ "linhas" ][ i ][ "brutos" ]
      v      := hT[ "linhas" ][ i ][ "valores" ]
      nRec   := hT[ "linhas" ][ i ][ "__RECNO" ]
      cChave := "CODORC=" + AllTrim( b[ "CODORC" ] )
      hRes[ "lidos" ]++

      lBranco := Empty( AllTrim( b[ "CODCLI" ] ) ) .AND. Empty( AllTrim( b[ "CODPEC" ] ) ) ;
                 .AND. Empty( AllTrim( b[ "CODORC" ] ) )
      IF lBranco
         IncRegistrar( hReg, cArq, nRec, NIL, "(registro)", NIL, ;
            "Registro inteiramente em branco", ;
            "Importado com todos os campos NULL, para não descartar evidência", "ALTA" )
      ENDIF

      hData := NormData( b[ "DATREP" ], "EVENTO" )
      IncAbsorver( hReg, hData, cArq, nRec, cChave, "DATREP", AllTrim( b[ "DATREP" ] ) )

      /* os códigos são C(6) no legado; sem FK garantida, conferimos a existência */
      nCli := CarFk( pDb, hReg, b[ "CODCLI" ], "cliente", "cod_cli", cArq, nRec, cChave, "CODCLI" )
      nPec := CarFk( pDb, hReg, b[ "CODPEC" ], "peca", "cod_pec", cArq, nRec, cChave, "CODPEC" )
      nFun := CarFk( pDb, hReg, b[ "CODFUN" ], "funcionario", "cod_fun", cArq, nRec, cChave, "CODFUN" )

      nValor := CarCent( hReg, b[ "VALORC" ], cArq, nRec, cChave, "VALORC" )
      IF nValor != NIL .AND. nValor > 100000000            /* > R$ 1.000.000,00 */
         IncRegistrar( hReg, cArq, nRec, cChave, "VALORC", AllTrim( b[ "VALORC" ] ), ;
            "Valor de orçamento implausível para 1994: " + CarMoeda( nValor ), ;
            "Importado como está; nenhum valor é inferido", "ALTA" )
      ENDIF

      nRc := SqlExecBind( pDb, ;
         "INSERT INTO orcamento_reparo (cod_orc, cod_cli, cod_fun, cod_pec," + ;
         " valor_cent, descricao, data_orcamento, excluido) VALUES (?,?,?,?,?,?,?,?)", { ;
         NormTexto( b[ "CODORC" ] )[ "valor" ], nCli, nFun, nPec, ;
         iif( nValor == 0 .AND. lBranco, NIL, nValor ), ;
         NormTexto( v[ "ORCREP" ] )[ "valor" ], ;
         hData[ "valor" ], ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )

      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "orcamento_reparo" ] := nGrav

   RETURN NIL

STATIC FUNCTION CarPedido( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRec, nRc, cArq := "CVBPEDID.DBF", nGrav := 0

   hT := ExtratorLer( cDir + cArq )
   IF hT[ "erro" ] != NIL
      RETURN cArq + ": " + hT[ "erro" ]
   ENDIF

   SqlInicia( pDb )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b    := hT[ "linhas" ][ i ][ "brutos" ]
      nRec := hT[ "linhas" ][ i ][ "__RECNO" ]
      hRes[ "lidos" ]++
      nRc := SqlExecBind( pDb, ;
         "INSERT INTO pedido (cod_ped, cod_ite, desc_ite, qtd_ite, excluido)" + ;
         " VALUES (?,?,?,?,?)", { ;
         NormCodigo( b[ "CODPED" ] )[ "valor" ], ;
         NormCodigo( b[ "CODITE" ] )[ "valor" ], ;
         NormTexto( b[ "DESITE" ] )[ "valor" ], ;
         NormQuantidade( b[ "QTDITE" ] )[ "valor" ], ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )
      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN cArq + " reg " + hb_ntos( nRec ) + ": " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT
   SqlConfirma( pDb )

   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "pedido" ] := nGrav

   RETURN NIL

/* D.5 — §6.4: CVMGRUPO.MEM → sequencia('consorcio_grupo'). */
STATIC FUNCTION CarSequencia( pDb, cDir, hReg, hRes )

   LOCAL hMem, nValor, nMax, nRc, cArq := "CVMGRUPO.MEM"

   hMem := ExtratorLerMem( cDir + cArq, "MCODGRU" )
   IF hMem[ "erro" ] != NIL
      RETURN cArq + ": " + hMem[ "erro" ]
   ENDIF
   hRes[ "lidos" ]++

   nValor := iif( ValType( hMem[ "valor" ] ) == "N", Int( hMem[ "valor" ] ), 0 )
   nMax   := SqlEscalar( pDb, "SELECT IFNULL(MAX(cod_gru),0) FROM consorcio_cota" )

   /* §6.4: se o sequencial for menor que o maior grupo migrado, ajustar —
      senão o próximo grupo criado reusaria um número já em uso. */
   IF nValor < nMax
      IncRegistrar( hReg, cArq, 1, NIL, "MCODGRU", hb_ntos( nValor ), ;
         "Sequencial do grupo (" + hb_ntos( nValor ) + ") é menor que o maior " + ;
         "grupo migrado (" + hb_ntos( nMax ) + ")", ;
         "Ajustado para " + hb_ntos( nMax ) + "; sem o ajuste o próximo grupo " + ;
         "reusaria um número existente", "MEDIA" )
      nValor := nMax
   ENDIF

   /* database/schema.sql já semeia a linha 'consorcio_grupo' com 0, então aqui
      é atualização, não inserção. ON CONFLICT cobre os dois casos. */
   SqlInicia( pDb )
   nRc := SqlExecBind( pDb, ;
      "INSERT INTO sequencia (nome, valor, descricao) VALUES (?,?,?)" + ;
      " ON CONFLICT(nome) DO UPDATE SET valor = excluded.valor", { ;
      "consorcio_grupo", nValor, ;
      "Último número de grupo de consórcio usado; vinha de CVMGRUPO.MEM" } )
   IF nRc != 0
      SqlDesfaz( pDb )
      RETURN cArq + ": " + SqlErro( pDb )
   ENDIF
   SqlConfirma( pDb )

   hRes[ "gravados" ]++
   hRes[ "tabelas" ][ "sequencia" ] := 1

   RETURN NIL

/*
 * §3.2 — quarentena: agregados dessincronizados e a tabela de clientes
 * predecessora. Preservam a evidência sem participar do modelo de produção.
 */
STATIC FUNCTION CarQuarentena( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, nRc, nGrav := 0

   SqlInicia( pDb )

   hT := ExtratorLer( cDir + "CVVCAR.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      hRes[ "lidos" ]++
      nRc := SqlExecBind( pDb, "INSERT INTO _legado_cvvcar (registro, descar, quantv)" + ;
         " VALUES (?,?,?)", { hT[ "linhas" ][ i ][ "__RECNO" ], ;
         AllTrim( b[ "DESCAR" ] ), AllTrim( b[ "QUANTV" ] ) } )
      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN "CVVCAR.DBF: " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT

   hT := ExtratorLer( cDir + "CVVPEC.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      hRes[ "lidos" ]++
      nRc := SqlExecBind( pDb, "INSERT INTO _legado_cvvpec (registro, despec, quantc)" + ;
         " VALUES (?,?,?)", { hT[ "linhas" ][ i ][ "__RECNO" ], ;
         AllTrim( b[ "DESPEC" ] ), AllTrim( b[ "QUANTC" ] ) } )
      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN "CVVPEC.DBF: " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT

   hT := ExtratorLer( cDir + "CVCLIENT.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      hRes[ "lidos" ]++
      nRc := SqlExecBind( pDb, "INSERT INTO _legado_cvclient (registro, codcli," + ;
         " nomcli, endcli, cepcli, ufcli, telcli, rgcli, ciccli, nascli, datcli," + ;
         " cidcli, consor, deletado) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", { ;
         hT[ "linhas" ][ i ][ "__RECNO" ], ;
         AllTrim( b[ "CODCLI" ] ), AllTrim( b[ "NOMCLI" ] ), AllTrim( b[ "ENDCLI" ] ), ;
         AllTrim( b[ "CEPCLI" ] ), AllTrim( b[ "UFCLI" ] ), AllTrim( b[ "TELCLI" ] ), ;
         AllTrim( b[ "RGCLI" ] ), AllTrim( b[ "CICCLI" ] ), AllTrim( b[ "NASCLI" ] ), ;
         AllTrim( b[ "DATCLI" ] ), AllTrim( b[ "CIDCLI" ] ), AllTrim( b[ "CONSOR" ] ), ;
         iif( hT[ "linhas" ][ i ][ "__EXCLUIDO" ], 1, 0 ) } )
      IF nRc != 0
         SqlDesfaz( pDb )
         RETURN "CVCLIENT.DBF: " + SqlErro( pDb )
      ENDIF
      nGrav++
   NEXT

   SqlConfirma( pDb )
   hRes[ "gravados" ] += nGrav
   hRes[ "tabelas" ][ "quarentena" ] := nGrav

   RETURN NIL

/*
 * Observações que só existem depois que tudo está carregado, porque comparam
 * conjuntos — não valores isolados. São as famílias I-10, I-12, I-15, I-16,
 * I-20, I-21 e I-24 de docs/08-MIGRACAO-DADOS.md §8.1.
 *
 * I-11 ("VALTOT vazio em item não-final", 28 previstas) NÃO é emitida de
 * propósito: é o caso NORMAL do legado — VALTOT só é preenchido no último item
 * da compra (RN-027), e é justamente isso que o agrupamento de §6.1 usa como
 * sinal. Emitir 28 linhas para o comportamento esperado afogaria o que importa.
 * A decisão está registrada aqui para não parecer omissão.
 */
STATIC FUNCTION CarObservacoes( pDb, cDir, hReg, hRes )

   LOCAL hT, i, b, aL, nQtd, xLeg, nObs := 0

   /* I-10 — campos numéricos que nunca foram gravados em CVBGRUPO */
   hT := ExtratorLer( cDir + "CVBGRUPO.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      IF Empty( AllTrim( b[ "NUMPAG" ] ) )
         IncRegistrar( hReg, "CVBGRUPO.DBF", hT[ "linhas" ][ i ][ "__RECNO" ], ;
            "CODCON=" + AllTrim( b[ "CODCON" ] ), "NUMPAG", NIL, ;
            "Campo numérico nunca gravado (branco na origem, não zero)", ;
            "Coluna recebe 0; a distinção fica registrada aqui", "BAIXA" )
         nObs++
      ENDIF
      IF Empty( AllTrim( b[ "NUMGRU" ] ) )
         IncRegistrar( hReg, "CVBGRUPO.DBF", hT[ "linhas" ][ i ][ "__RECNO" ], ;
            "CODCON=" + AllTrim( b[ "CODCON" ] ), "NUMGRU", NIL, ;
            "Campo numérico nunca gravado (branco na origem, não zero)", ;
            "Coluna recebe 0; a distinção fica registrada aqui", "BAIXA" )
         nObs++
      ENDIF
   NEXT

   /* I-12 — QUANTC vazio na quarentena de CVVPEC */
   hT := ExtratorLer( cDir + "CVVPEC.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      IF Empty( AllTrim( b[ "QUANTC" ] ) )
         IncRegistrar( hReg, "CVVPEC.DBF", hT[ "linhas" ][ i ][ "__RECNO" ], NIL, ;
            "QUANTC", NIL, "Quantidade vazia no agregado do legado", ;
            "Preservado como veio na quarentena; não participa do modelo", "BAIXA" )
         nObs++
      ENDIF
   NEXT

   /* I-20 — fornecedor com a maioria dos campos vazios */
   hT := ExtratorLer( cDir + "CVBFORNE.DBF" )
   FOR i := 1 TO Len( hT[ "linhas" ] )
      b := hT[ "linhas" ][ i ][ "brutos" ]
      nQtd := 0
      IF Empty( AllTrim( b[ "TELFOR" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "CEPFOR" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "CIDFOR" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "ENDFOR" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "CODITE" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "DESITE" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "NOMFAB" ] ) ) ; nQtd++ ; ENDIF
      IF Empty( AllTrim( b[ "CGCFAB" ] ) ) ; nQtd++ ; ENDIF
      IF nQtd >= 7
         IncRegistrar( hReg, "CVBFORNE.DBF", hT[ "linhas" ][ i ][ "__RECNO" ], ;
            "CODFOR=" + AllTrim( b[ "CODFOR" ] ), "(registro)", NIL, ;
            "Cadastro quase vazio: " + hb_ntos( nQtd ) + " de 11 campos em branco", ;
            "Importado como está; nenhum campo é preenchido por suposição", "BAIXA" )
         nObs++
      ENDIF
   NEXT

   /* I-21 — cliente marcado como consorciado, sem cota (Q-08) */
   aL := SqlLinhas( pDb, "SELECT cod_cli, nome FROM cliente WHERE consorcio = 'S'" + ;
      " AND cod_cli NOT IN (SELECT cod_cli FROM consorcio_cota) ORDER BY cod_cli" )
   FOR i := 1 TO Len( aL )
      IncRegistrar( hReg, "CVBCLIEN.DBF", 0, "CODCLI=" + hb_ntos( aL[ i ][ 1 ] ), ;
         "CONSOR", "S", ;
         "Cliente marcado como consorciado, mas sem cota em nenhum grupo (Q-08)", ;
         "Marca preservada; o legado não permite saber se é dado perdido ou erro", ;
         "BAIXA" )
      nObs++
   NEXT

   /* I-24 — código duplicado na tabela predecessora, já em quarentena */
   aL := SqlLinhas( pDb, "SELECT codcli, count(*) FROM _legado_cvclient" + ;
      " GROUP BY codcli HAVING count(*) > 1" )
   FOR i := 1 TO Len( aL )
      IncRegistrar( hReg, "CVCLIENT.DBF", 0, "CODCLI=" + hb_ValToStr( aL[ i ][ 1 ] ), ;
         "CODCLI", hb_ValToStr( aL[ i ][ 1 ] ), ;
         "Código de cliente duplicado na tabela predecessora (" + ;
         hb_ntos( aL[ i ][ 2 ] ) + " ocorrências)", ;
         "Mantido na quarentena; não entra no modelo de produção", "ALTA" )
      nObs++
   NEXT

   /* I-15 / I-16 — agregados do legado fora de sincronia com o movimento real */
   nObs += CarAgregadoFora( pDb, hReg, "CVVCAR.DBF", "_legado_cvvcar", "descar", ;
      "quantv", "v_venda_por_modelo" )
   nObs += CarAgregadoFora( pDb, hReg, "CVVPEC.DBF", "_legado_cvvpec", "despec", ;
      "quantc", "v_venda_por_peca" )

   hRes[ "tabelas" ][ "(observações)" ] := nObs

   RETURN NIL

STATIC FUNCTION CarAgregadoFora( pDb, hReg, cArq, cQuar, cDesc, cQtd, cView )

   LOCAL aL, i, nObs := 0, nReal, nLeg

   aL := SqlLinhas( pDb, "SELECT q.registro, TRIM(q." + cDesc + "), q." + cQtd + ", " + ;
      " (SELECT quantidade FROM " + cView + " v WHERE v.descricao = TRIM(q." + cDesc + "))" + ;
      " FROM " + cQuar + " q ORDER BY q.registro" )

   FOR i := 1 TO Len( aL )
      nLeg  := Val( hb_ValToStr( aL[ i ][ 3 ] ) )
      nReal := iif( aL[ i ][ 4 ] == NIL, 0, aL[ i ][ 4 ] )
      IF nLeg != nReal
         IncRegistrar( hReg, cArq, aL[ i ][ 1 ], NIL, cQtd, hb_ValToStr( aL[ i ][ 3 ] ), ;
            "Agregado do legado (" + hb_ntos( nLeg ) + ") difere do movimento real (" + ;
            hb_ntos( nReal ) + ") para '" + aL[ i ][ 2 ] + "'", ;
            "Agregado fica só na quarentena; a view " + cView + " recalcula do movimento", ;
            "ALTA" )
         nObs++
      ENDIF
   NEXT

   RETURN nObs

/* ------------------------------------------------------------------ */
/* Auxiliares                                                          */
/* ------------------------------------------------------------------ */

/* Monetário: absorve as ocorrências e devolve o valor em centavos. */
STATIC FUNCTION CarCent( hReg, cBruto, cArq, nRec, cChave, cCampo )
   LOCAL h := NormMonetario( cBruto )
   IncAbsorver( hReg, h, cArq, nRec, cChave, cCampo, AllTrim( cBruto ) )
   RETURN h[ "valor" ]

/* Quantidade: idem. */
STATIC FUNCTION CarQtd( hReg, cBruto, cArq, nRec, cChave, cCampo )
   LOCAL h := NormQuantidade( cBruto )
   IncAbsorver( hReg, h, cArq, nRec, cChave, cCampo, AllTrim( cBruto ) )
   RETURN h[ "valor" ]

/* UF: o legado não validava; a lista do schema é a corrigida (D-20/V-10). */
STATIC FUNCTION CarUf( hReg, cBruto, cArq, nRec, cChave )

   LOCAL xUf := NormTexto( cBruto )[ "valor" ], cUf

   IF xUf == NIL
      RETURN NIL
   ENDIF
   cUf := Upper( AllTrim( xUf ) )
   IF Empty( cUf )
      RETURN NIL
   ENDIF
   IF AScan( s_aUf, {| x | x == cUf } ) == 0
      IncRegistrar( hReg, cArq, nRec, cChave, "UFCLI", cUf, ;
         "UF inexistente: " + cUf, ;
         "Coluna recebe NULL; valor original neste relatório", "ALTA" )
      RETURN NIL
   ENDIF

   RETURN cUf

/*
 * Código que aponta para outra tabela sem FK garantida (CVREPAR, §7).
 * Se o alvo não existir, grava NULL e registra — inserir quebraria a FK e
 * derrubaria a transação inteira por um dado de teste de 1994.
 */
STATIC FUNCTION CarFk( pDb, hReg, cBruto, cTabela, cColuna, cArq, nRec, cChave, cCampo )

   LOCAL nCod := NormCodigo( cBruto )[ "valor" ]

   IF nCod == NIL .OR. nCod == 0
      RETURN NIL
   ENDIF
   IF SqlEscalar( pDb, "SELECT count(*) FROM " + cTabela + " WHERE " + cColuna + ;
                       " = " + hb_ntos( nCod ) ) == 0
      IncRegistrar( hReg, cArq, nRec, cChave, cCampo, hb_ntos( nCod ), ;
         "Referência para " + cTabela + " inexistente: " + hb_ntos( nCod ), ;
         "Coluna recebe NULL; código original neste relatório", "ALTA" )
      RETURN NIL
   ENDIF

   RETURN nCod

/*
 * Confere um campo desnormalizado do legado contra a fonte da verdade.
 * Divergência é registrada, nunca corrigida: o snapshot é gravado como veio,
 * porque é o que o legado mostrava na tela (I-13, I-14).
 */
STATIC PROCEDURE CarConfereSnapshot( pDb, hReg, cArq, nRec, cChave, cCampo, cSnap, cSql )

   LOCAL cAtual

   IF cSnap == NIL
      RETURN
   ENDIF
   cAtual := SqlEscalar( pDb, cSql )
   IF cAtual == NIL .OR. cAtual == cSnap
      RETURN
   ENDIF
   IncRegistrar( hReg, cArq, nRec, cChave, cCampo, cSnap, ;
      "Desnormalização divergente: o cadastro diz '" + cAtual + "'", ;
      "Snapshot gravado como veio do legado; o cadastro continua sendo a fonte da verdade", ;
      "MEDIA" )

   RETURN

STATIC FUNCTION CarMoeda( nCent )
   IF nCent == NIL
      RETURN "(vazio)"
   ENDIF
   RETURN "R$ " + Transform( nCent / 100, "@E 999,999,999.99" )
