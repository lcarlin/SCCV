/*
 * transacao.prg — FASE F.3
 *
 * Transações com ANINHAMENTO, via SAVEPOINT.
 *
 * O SQLite não aninha BEGIN: um segundo BEGIN é erro. Mas serviços chamam
 * serviços — "registrar venda" abre transação e chama "baixar estoque", que
 * também quer a sua. Sem aninhamento, ou o serviço interno nunca pode abrir
 * transação (e deixa de ser reutilizável), ou o externo perde o controle.
 *
 * A solução é SAVEPOINT: o nível 1 abre BEGIN de verdade; os internos abrem
 * savepoints nomeados. Desfazer o interno volta ao savepoint e a transação
 * externa continua viva — que é exatamente o critério de aceite de F.3.
 *
 * Falha no nível 1 desfaz tudo.
 */

STATIC s_nNivel := 0
STATIC s_lFalhou := .F.

FUNCTION TransNivel()
   RETURN s_nNivel

/* .T. se alguma camada interna falhou e a transação está condenada. */
FUNCTION TransCondenada()
   RETURN s_lFalhou

FUNCTION TransIniciar( pDb )

   LOCAL nRc

   IF s_nNivel == 0
      nRc := SqlExec( pDb, "BEGIN" )
      IF nRc != 0
         RETURN .F.
      ENDIF
      s_lFalhou := .F.
   ELSE
      nRc := SqlExec( pDb, "SAVEPOINT " + TransNome( s_nNivel + 1 ) )
      IF nRc != 0
         RETURN .F.
      ENDIF
   ENDIF
   s_nNivel++

   RETURN .T.

FUNCTION TransConfirmar( pDb )

   LOCAL nRc

   IF s_nNivel == 0
      RETURN .F.
   ENDIF

   IF s_nNivel == 1
      /* uma camada interna já desfez: confirmar aqui gravaria pela metade */
      IF s_lFalhou
         SqlExec( pDb, "ROLLBACK" )
         s_nNivel := 0
         s_lFalhou := .F.
         RETURN .F.
      ENDIF
      nRc := SqlExec( pDb, "COMMIT" )
      s_nNivel := 0
      RETURN nRc == 0
   ENDIF

   /* RELEASE não grava nada: só descarta o ponto de retorno */
   nRc := SqlExec( pDb, "RELEASE " + TransNome( s_nNivel ) )
   s_nNivel--

   RETURN nRc == 0

FUNCTION TransDesfazer( pDb )

   LOCAL nRc

   IF s_nNivel == 0
      RETURN .F.
   ENDIF

   IF s_nNivel == 1
      nRc := SqlExec( pDb, "ROLLBACK" )
      s_nNivel := 0
      s_lFalhou := .F.
      RETURN nRc == 0
   ENDIF

   nRc := SqlExec( pDb, "ROLLBACK TO " + TransNome( s_nNivel ) )
   SqlExec( pDb, "RELEASE " + TransNome( s_nNivel ) )
   s_nNivel--
   /* a externa fica marcada: o trabalho interno foi desfeito, e confirmar o
      conjunto como se estivesse completo seria mentira */
   s_lFalhou := .T.

   RETURN nRc == 0

/*
 * Executa bBloco dentro de uma transação, confirmando no sucesso e desfazendo
 * em qualquer erro. É a forma preferida: não há caminho de saída que esqueça
 * o rollback.
 */
FUNCTION TransExecutar( pDb, bBloco, cOperacao )

   LOCAL hRes

   IF !TransIniciar( pDb )
      RETURN { "ok" => .F., "valor" => NIL, ;
               "mensagem" => "Não foi possível iniciar a transação." }
   ENDIF

   hRes := ErroProteger( bBloco, cOperacao, {| e | HB_SYMBOL_UNUSED( e ), ;
                                                   TransDesfazer( pDb ) } )
   IF !hRes[ "ok" ]
      RETURN hRes
   ENDIF

   IF !TransConfirmar( pDb )
      hRes[ "ok" ] := .F.
      hRes[ "mensagem" ] := "A operação foi desfeita porque uma etapa interna falhou."
   ENDIF

   RETURN hRes

STATIC FUNCTION TransNome( nNivel )
   RETURN "sccv_sp" + hb_ntos( nNivel )

/* Emergência: abandona qualquer transação aberta. Só para o encerramento. */
PROCEDURE TransAbortarTudo( pDb )
   DO WHILE s_nNivel > 0
      TransDesfazer( pDb )
   ENDDO
   RETURN
