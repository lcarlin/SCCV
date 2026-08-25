/*
 * consorcio_cota.prg — FASE G, onda 6
 *
 * SQL das cotas de consórcio. As regras ficam em services/consorcio.prg.
 *
 * O nome do arquivo segue a tabela, e não o domínio, para não colidir com
 * services/consorcio.prg: o hbmk2 nomeia os objetos pelo nome BASE do fonte.
 *
 * D-12 — O legado mantinha DUAS tabelas quase idênticas: CVBGRUPO (grupo em
 * formação) e CVBGRUCO (grupo fechado). Fechar um grupo era mover N registros
 * de uma para outra, em laço, sem transação — interrupção deixava o grupo pela
 * metade. Aqui existe uma tabela só, `consorcio_cota`, e o fechamento é um
 * UPDATE. A duplicação era artifício do modelo DBF, não conceito do negócio.
 */

FUNCTION ConsorcioCotaInserir( pDb, hCota )
   RETURN SqlExecBind( pDb, ;
      "INSERT INTO consorcio_cota (cod_gru, num_participante, cod_cli, cod_car," + ;
      " valor_prestacao_cent, num_participantes_previsto, parcelas_restantes," + ;
      " data_adesao, grupo_fechado, sorteado, quitado, nome_snapshot, excluido)" + ;
      " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,0)", { ;
      hCota[ "cod_gru" ], hCota[ "num_participante" ], hCota[ "cod_cli" ], ;
      hCota[ "cod_car" ], hCota[ "valor_prestacao_cent" ], ;
      hCota[ "num_participantes_previsto" ], hCota[ "parcelas_restantes" ], ;
      hCota[ "data_adesao" ], hCota[ "grupo_fechado" ], ;
      hCota[ "sorteado" ], hCota[ "quitado" ], hCota[ "nome_snapshot" ] } )

/*
 * Grupo EM FORMAÇÃO de um modelo, se houver.
 *
 * RN-013 — a condição do legado é `SEEK <cod_carro>` em CVBGRUPO sem encontrar,
 * isto é: não existe grupo em formação para aquele modelo. Grupos já fechados
 * não contam — por isso o filtro por grupo_fechado = 0.
 */
FUNCTION ConsorcioGrupoAberto( pDb, nCodCar )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT cod_gru, num_participantes_previsto," + ;
      " valor_prestacao_cent, parcelas_restantes, data_adesao FROM consorcio_cota" + ;
      " WHERE cod_car = ? AND grupo_fechado = 0 AND excluido = 0" + ;
      " ORDER BY cod_gru LIMIT 1", { nCodCar } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "cod_gru" => aL[ 1 ][ 1 ], "num_participantes_previsto" => aL[ 1 ][ 2 ], ;
            "valor_prestacao_cent" => aL[ 1 ][ 3 ], "parcelas_restantes" => aL[ 1 ][ 4 ], ;
            "data_adesao" => aL[ 1 ][ 5 ] }

/*
 * D-10 — próximo número de participante: MAX + 1 sobre o grupo, INCLUINDO
 * excluídos.
 *
 * O legado usava COUNT com SET DELETED ON, que não conta excluídos: depois de
 * um fechamento de grupo (que excluía todos os participantes), a numeração
 * reiniciava em 1. Está nos dados — CVBGRUPO tem os participantes 1 e 2 do
 * grupo 1 enquanto CVBGRUCO já tem 1, 2 e 3 do mesmo grupo. Dois participantes
 * com o mesmo número no mesmo grupo não é regra: é identificador quebrado.
 */
FUNCTION ConsorcioProximoParticipante( pDb, nCodGru )

   LOCAL xN := SqlEscalar( pDb, "SELECT IFNULL(MAX(num_participante),0) + 1" + ;
      " FROM consorcio_cota WHERE cod_gru = " + hb_ntos( nCodGru ) )

   RETURN iif( xN == NIL, 1, xN )

FUNCTION ConsorcioContarCotas( pDb, nCodGru )

   LOCAL xN := SqlEscalar( pDb, "SELECT count(*) FROM consorcio_cota" + ;
      " WHERE cod_gru = " + hb_ntos( nCodGru ) + " AND excluido = 0" )

   RETURN iif( xN == NIL, 0, xN )

FUNCTION ConsorcioCota( pDb, nCodGru, nParticipante )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT id, cod_cli, cod_car," + ;
      " valor_prestacao_cent, num_participantes_previsto, parcelas_restantes," + ;
      " parcelas_restantes_legado, data_adesao, grupo_fechado, sorteado," + ;
      " quitado, nome_snapshot FROM consorcio_cota" + ;
      " WHERE cod_gru = ? AND num_participante = ? AND excluido = 0", ;
      { nCodGru, nParticipante } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN { "id" => aL[ 1 ][ 1 ], "cod_cli" => aL[ 1 ][ 2 ], "cod_car" => aL[ 1 ][ 3 ], ;
            "valor_prestacao_cent" => aL[ 1 ][ 4 ], ;
            "num_participantes_previsto" => aL[ 1 ][ 5 ], ;
            "parcelas_restantes" => aL[ 1 ][ 6 ], ;
            "parcelas_restantes_legado" => aL[ 1 ][ 7 ], ;
            "data_adesao" => aL[ 1 ][ 8 ], "grupo_fechado" => aL[ 1 ][ 9 ], ;
            "sorteado" => aL[ 1 ][ 10 ], "quitado" => aL[ 1 ][ 11 ], ;
            "nome_snapshot" => aL[ 1 ][ 12 ] }

FUNCTION ConsorcioCotaPorId( pDb, nId )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT cod_gru, num_participante" + ;
      " FROM consorcio_cota WHERE id = ?", { nId } )

   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   RETURN ConsorcioCota( pDb, aL[ 1 ][ 1 ], aL[ 1 ][ 2 ] )

FUNCTION ConsorcioAtualizarCota( pDb, nId, cColuna, xValor )
   RETURN SqlExecBind( pDb, "UPDATE consorcio_cota SET " + cColuna + " = ?" + ;
      " WHERE id = ?", { xValor, nId } )

/* D-12 — fechar o grupo é um UPDATE, não um laço entre tabelas. */
FUNCTION ConsorcioFecharGrupo( pDb, nCodGru )
   RETURN SqlExecBind( pDb, "UPDATE consorcio_cota SET grupo_fechado = 1" + ;
      " WHERE cod_gru = ? AND excluido = 0", { nCodGru } )

FUNCTION ConsorcioCotasDoGrupo( pDb, nCodGru )
   RETURN SqlLinhasBind( pDb, "SELECT num_participante, cod_cli, nome_snapshot," + ;
      " parcelas_restantes, sorteado, quitado FROM consorcio_cota" + ;
      " WHERE cod_gru = ? AND excluido = 0 ORDER BY num_participante", { nCodGru } )

/* RN-013 — o sequencial de grupos, que veio do CVMGRUPO.MEM. */
FUNCTION ConsorcioSequencialGrupo( pDb )

   LOCAL xN := SqlEscalar( pDb, "SELECT valor FROM sequencia" + ;
      " WHERE nome = 'consorcio_grupo'" )

   RETURN iif( xN == NIL, 0, xN )

FUNCTION ConsorcioGravarSequencial( pDb, nValor )
   RETURN SqlExecBind( pDb, "UPDATE sequencia SET valor = ? WHERE nome = ?", ;
      { nValor, "consorcio_grupo" } )
