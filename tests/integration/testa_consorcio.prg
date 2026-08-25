/*
 * testa_consorcio.prg — critério de aceite da FASE G, onda 6
 *
 * RN-013 a RN-023; divergências D-10, D-11, D-12, D-25; questões Q-08 e Q-09.
 *
 * É a área que mais acumulou defeito no legado: dos cinco valores de NUMMES no
 * acervo, três são inválidos (`**`, `-2`, `-3`) — consequência direta de
 * RN-020 subtrair sem piso em zero.
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   LOCAL cDb := hb_DirTemp() + "testa-consorcio.db", hC, pDb

   ? "FASE G onda 6 — aceite do consórcio"
   ?
   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, hb_MemoRead( "database/schema.sql" ) )
   SqlExec( pDb, hb_MemoRead( "database/views.sql" ) )
   Semear( pDb )

   TestaGrupoNovo( pDb )
   TestaGrupoExistente( pDb )
   TestaFechamento( pDb )
   TestaPrestacoes( pDb )
   TestaContemplacao( pDb )
   TestaHerancaDaMigracao( pDb )
   ConexaoFechar()

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "CONSÓRCIO ACEITO", "CONSÓRCIO REPROVADO" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

STATIC PROCEDURE Semear( pDb )
   LOCAL i
   FOR i := 1 TO 6
      SqlExecBind( pDb, "INSERT INTO cliente (cod_cli, nome, data_cadastro)" + ;
         " VALUES (?,?,?)", { i, "Consorciado " + hb_ntos( i ), "1994-01-01" } )
   NEXT
   SqlExecBind( pDb, "INSERT INTO funcionario (cod_fun, nome) VALUES (?,?)", { 11, "Vendedor" } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 1, "Uno Mile ELX", 2, 200000 } )
   SqlExecBind( pDb, "INSERT INTO modelo_veiculo (cod_car, descricao, qtd_estoque," + ;
      " valor_cent) VALUES (?,?,?,?)", { 2, "Tempra", 0, 3500000 } )
   RETURN

STATIC PROCEDURE TestaGrupoNovo( pDb )

   LOCAL hPrep, hRes

   ? "== RN-013 / RN-016 — grupo novo =="

   Vale( "sequencial começa em zero", ConsorcioSequencialGrupo( pDb ), 0 )

   hPrep := ConsorcioPreparar( pDb, 1 )
   Vale( "não há grupo aberto: cria novo", hPrep[ "novo" ], .T. )
   Vale( "RN-013: número vem do sequencial + 1", hPrep[ "cod_gru" ], 1 )
   Vale( "primeiro participante", hPrep[ "num_participante" ], 1 )
   /* RN-016 / Q-09: prestação = valor CHEIO do carro, não dividido */
   Vale( "RN-016: prestação pré-preenchida com o valor do modelo", ;
         hPrep[ "valor_prestacao_cent" ], 200000 )
   Vale( "editável na criação", hPrep[ "editavel" ], .T. )

   /* DIVERGÊNCIA: o número só é consumido na gravação */
   Vale( "sequencial ainda NÃO foi consumido", ConsorcioSequencialGrupo( pDb ), 0 )

   hRes := ConsorcioAderir( pDb, Dados( hPrep, 1, 3 ) )
   Vale( "adesão gravada", hRes[ "ok" ], .T. )
   Vale( "agora o sequencial avançou", ConsorcioSequencialGrupo( pDb ), 1 )
   /* RN-017 */
   Vale( "RN-017: prestações = nº de participantes", ;
         ConsorcioCota( pDb, 1, 1 )[ "parcelas_restantes" ], 3 )
   /* RN-019 — inicializados explicitamente, não por acidente do APPEND BLANK */
   Vale( "RN-019: sorteado inicializado em 0", ConsorcioCota( pDb, 1, 1 )[ "sorteado" ], 0 )
   Vale( "RN-019: quitado inicializado em 0", ConsorcioCota( pDb, 1, 1 )[ "quitado" ], 0 )
   Vale( "grupo ainda aberto", ConsorcioCota( pDb, 1, 1 )[ "grupo_fechado" ], 0 )
   Vale( "não fechou com 1 de 3", hRes[ "fechou_grupo" ], .F. )

   RETURN

STATIC PROCEDURE TestaGrupoExistente( pDb )

   LOCAL hPrep, hRes

   ? "== RN-014 / RN-015 / D-10 — adesão a grupo existente =="

   hPrep := ConsorcioPreparar( pDb, 1 )
   Vale( "encontra o grupo aberto", hPrep[ "novo" ], .F. )
   Vale( "mesmo grupo", hPrep[ "cod_gru" ], 1 )
   /* RN-014: herda os parâmetros, e eles NÃO são editáveis */
   Vale( "RN-014: herda o nº de participantes", hPrep[ "num_participantes_previsto" ], 3 )
   Vale( "RN-014: herda o valor da prestação", hPrep[ "valor_prestacao_cent" ], 200000 )
   Vale( "RN-014: não editável na adesão", hPrep[ "editavel" ], .F. )
   /* D-10: MAX + 1, não COUNT + 1 */
   Vale( "D-10: próximo participante é 2", hPrep[ "num_participante" ], 2 )

   hRes := ConsorcioAderir( pDb, Dados( hPrep, 2, 3 ) )
   Vale( "segunda adesão gravada", hRes[ "ok" ], .T. )
   Vale( "sequencial NÃO avança em grupo existente", ConsorcioSequencialGrupo( pDb ), 1 )

   /* colisão de (grupo, participante) é recusada */
   hRes := ConsorcioAderir( pDb, Dados( hPrep, 3, 3 ) )
   Vale( "D-10: participante repetido é recusado", hRes[ "ok" ], .F. )
   Vale( "com mensagem clara", At( "Já existe o participante", hRes[ "mensagem" ] ) > 0, .T. )

   RETURN

STATIC PROCEDURE TestaFechamento( pDb )

   LOCAL hPrep, hRes

   ? "== RN-018 / D-12 — fechamento automático, transacional =="

   hPrep := ConsorcioPreparar( pDb, 1 )
   Vale( "terceiro participante", hPrep[ "num_participante" ], 3 )
   hRes := ConsorcioAderir( pDb, Dados( hPrep, 3, 3 ) )
   Vale( "terceira adesão gravada", hRes[ "ok" ], .T. )
   /* RN-018: completou 3 de 3 → fecha */
   Vale( "RN-018: o grupo FECHOU", hRes[ "fechou_grupo" ], .T. )
   /* D-12: é um UPDATE, e atinge TODAS as cotas do grupo */
   Vale( "cota 1 fechada", ConsorcioCota( pDb, 1, 1 )[ "grupo_fechado" ], 1 )
   Vale( "cota 2 fechada", ConsorcioCota( pDb, 1, 2 )[ "grupo_fechado" ], 1 )
   Vale( "cota 3 fechada", ConsorcioCota( pDb, 1, 3 )[ "grupo_fechado" ], 1 )
   Vale( "as três continuam na MESMA tabela (D-12)", ;
         Len( ConsorcioCotasDoGrupo( pDb, 1 ) ), 3 )

   /* grupo fechado não recebe mais adesão: uma nova adesão abre grupo novo */
   hPrep := ConsorcioPreparar( pDb, 1 )
   Vale( "modelo sem grupo aberto: cria novo", hPrep[ "novo" ], .T. )
   Vale( "e o número é 2", hPrep[ "cod_gru" ], 2 )
   /* D-25/D-10: a numeração do participante NÃO reinicia por causa do
      fechamento — mas em grupo NOVO ela começa em 1, o que é correto */
   Vale( "participante 1 do grupo novo", hPrep[ "num_participante" ], 1 )

   RETURN

STATIC PROCEDURE TestaPrestacoes( pDb )

   LOCAL hRes

   ? "== RN-020 / RN-021 / D-11 — baixa de prestações e quitação =="

   Vale( "saldo inicial 3", ConsorcioCota( pDb, 1, 1 )[ "parcelas_restantes" ], 3 )

   hRes := ConsorcioBaixarPrestacoes( pDb, 1, 1, 1 )
   Vale( "baixa 1", hRes[ "ok" ], .T. )
   Vale( "saldo 2", hRes[ "saldo" ], 2 )
   Vale( "não quitou", hRes[ "quitou" ], .F. )

   /* D-11 — o legado subtraía sem piso e gravou -2, -3 e ** no acervo */
   hRes := ConsorcioBaixarPrestacoes( pDb, 1, 1, 5 )
   Vale( "D-11: baixar mais que o saldo é RECUSADO", hRes[ "ok" ], .F. )
   Vale( "com mensagem que diz o saldo", At( "Restam 2", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "e o saldo não mudou", ConsorcioCota( pDb, 1, 1 )[ "parcelas_restantes" ], 2 )

   Vale( "quantidade zero é recusada", ;
         ConsorcioBaixarPrestacoes( pDb, 1, 1, 0 )[ "ok" ], .F. )
   Vale( "consorciado inexistente é recusado", ;
         ConsorcioBaixarPrestacoes( pDb, 9, 9, 1 )[ "ok" ], .F. )

   /* RN-021 — quitação no zero EXATO */
   hRes := ConsorcioBaixarPrestacoes( pDb, 1, 1, 2 )
   Vale( "baixa o saldo restante", hRes[ "ok" ], .T. )
   Vale( "saldo zero", hRes[ "saldo" ], 0 )
   Vale( "RN-021: quitou", hRes[ "quitou" ], .T. )
   Vale( "e ficou gravado", ConsorcioCota( pDb, 1, 1 )[ "quitado" ], 1 )
   Vale( "de zero não se baixa mais", ConsorcioBaixarPrestacoes( pDb, 1, 1, 1 )[ "ok" ], .F. )

   RETURN

STATIC PROCEDURE TestaContemplacao( pDb )

   LOCAL hRes, nAntes

   ? "== RN-022 / RN-023 — contemplação =="

   nAntes := EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ]
   Vale( "estoque do modelo antes", nAntes, 2 )

   /* RN-022 — o sistema não sorteia: registra o resultado */
   hRes := ConsorcioContemplar( pDb, 1, 2, .T. )
   Vale( "registra a contemplação", hRes[ "ok" ], .T. )
   Vale( "marca gravada", ConsorcioCota( pDb, 1, 2 )[ "sorteado" ], 1 )
   /* RN-023 — baixa uma unidade do modelo contratado */
   Vale( "RN-023: baixou uma unidade", hRes[ "baixou_estoque" ], .T. )
   Vale( "estoque 2 - 1", EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 1 )

   /* não sorteado: grava a marca, não mexe no estoque */
   hRes := ConsorcioContemplar( pDb, 1, 3, .F. )
   Vale( "não sorteado não baixa", hRes[ "baixou_estoque" ], .F. )
   Vale( "marca em 0", ConsorcioCota( pDb, 1, 3 )[ "sorteado" ], 0 )
   Vale( "estoque intacto", EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 1 )

   /* último veículo */
   hRes := ConsorcioContemplar( pDb, 1, 3, .T. )
   Vale( "baixa o último", hRes[ "baixou_estoque" ], .T. )
   Vale( "avisa que era o último", At( "Último veículo", hRes[ "aviso" ] ) > 0, .T. )
   Vale( "estoque zerado", EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 0 )

   /*
    * RN-023 com estoque esgotado: NÃO baixa, avisa — e a marca de sorteado
    * PERMANECE. No legado o REPLACE de SORT vinha antes do teste de estoque e
    * não havia reversão. Preservado, com o resultado dizendo o que houve.
    */
   hRes := ConsorcioContemplar( pDb, 1, 1, .T. )
   Vale( "esgotado: a operação não falha", hRes[ "ok" ], .T. )
   Vale( "RN-023: não baixou estoque", hRes[ "baixou_estoque" ], .F. )
   Vale( "mas a marca de sorteado PERMANECE (legado)", ;
         ConsorcioCota( pDb, 1, 1 )[ "sorteado" ], 1 )
   Vale( "com o aviso do legado", At( "esgotada", hRes[ "aviso" ] ) > 0, .T. )
   Vale( "estoque continua zero, nunca negativo", ;
         EstoqueSaldo( pDb, "modelo_veiculo", "cod_car", 1 )[ "atual" ], 0 )

   RETURN

/*
 * D-11 — cotas que vieram da migração com saldo inválido: parcelas_restantes é
 * NULL e o valor bruto ('**', '-2') está em parcelas_restantes_legado. Sem saldo
 * conhecido não há o que subtrair, e a mensagem tem de dizer isso.
 */
STATIC PROCEDURE TestaHerancaDaMigracao( pDb )

   LOCAL hRes

   ? "== D-11 — cota herdada com saldo inválido =="

   SqlExecBind( pDb, "INSERT INTO consorcio_cota (cod_gru, num_participante," + ;
      " cod_cli, cod_car, valor_prestacao_cent, num_participantes_previsto," + ;
      " parcelas_restantes, parcelas_restantes_legado, data_adesao," + ;
      " grupo_fechado, sorteado, quitado) VALUES (?,?,?,?,?,?,NULL,?,?,1,0,0)", ;
      { 9, 1, 1, 1, 200000, 3, "**", "1994-06-30" } )

   Vale( "cota existe", ConsorcioCota( pDb, 9, 1 ) != NIL, .T. )
   Vale( "saldo é NULL", ConsorcioCota( pDb, 9, 1 )[ "parcelas_restantes" ], NIL )
   Vale( "bruto preservado", ConsorcioCota( pDb, 9, 1 )[ "parcelas_restantes_legado" ], "**" )

   hRes := ConsorcioBaixarPrestacoes( pDb, 9, 1, 1 )
   Vale( "baixar é recusado", hRes[ "ok" ], .F. )
   Vale( "mensagem explica a origem", At( "sistema antigo", hRes[ "mensagem" ] ) > 0, .T. )
   Vale( "e mostra o valor original", At( "**", hRes[ "mensagem" ] ) > 0, .T. )

   RETURN

STATIC FUNCTION Dados( hPrep, nCodCli, nPrevisto )
   RETURN { ;
      "novo"                       => hPrep[ "novo" ], ;
      "cod_gru"                    => hPrep[ "cod_gru" ], ;
      "num_participante"           => hPrep[ "num_participante" ], ;
      "cod_cli"                    => nCodCli, ;
      "cod_car"                    => hPrep[ "cod_car" ], ;
      "valor_prestacao_cent"       => hPrep[ "valor_prestacao_cent" ], ;
      "num_participantes_previsto" => iif( hPrep[ "novo" ], nPrevisto, ;
                                           hPrep[ "num_participantes_previsto" ] ), ;
      "data_adesao"                => hPrep[ "data_adesao" ], ;
      "nome_cli"                   => "Consorciado " + hb_ntos( nCodCli ) }

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
