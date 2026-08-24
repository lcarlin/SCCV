/*
 * erro.prg — FASE F.4
 *
 * Tratamento de erros conforme o briefing §18:
 *
 *   - mensagem compreensível ao usuário;
 *   - registro em log quando apropriado;
 *   - contexto técnico suficiente para diagnóstico;
 *   - tratamento de exceções;
 *   - rollback quando necessário;
 *   - SEM stack trace na tela durante operação normal.
 *
 * O briefing proíbe BREAK e QUIT como estratégia genérica. Aqui o BREAK aparece
 * uma única vez, dentro do ERRORBLOCK, que é o mecanismo do próprio Harbour para
 * transferir o controle a um BEGIN SEQUENCE — o oposto de abandonar o programa.
 * Nenhum QUIT: quem decide encerrar é main.prg, com código de saída.
 *
 * A separação que importa:
 *   ao usuário  → o que aconteceu, em português, e o que ele pode fazer
 *   ao log      → subsistema, código, operação, arquivo e linha
 */

#include "error.ch"

STATIC s_nErros := 0

/*
 * Executa bBloco protegido. Devolve:
 *   { "ok" => .T./.F., "valor" => <retorno do bloco>, "mensagem" => <ao usuário>,
 *     "tecnico" => <ao log>, "erro" => <objeto de erro ou NIL> }
 *
 * cOperacao descreve o que estava sendo feito, em linguagem de usuário:
 * "gravar o cliente", "abrir o banco de dados".
 */
FUNCTION ErroProteger( bBloco, cOperacao, bLimpeza )

   LOCAL hRes := { "ok" => .T., "valor" => NIL, "mensagem" => NIL, ;
                   "tecnico" => NIL, "erro" => NIL }
   LOCAL bAnterior, oErr

   hb_default( @cOperacao, "executar a operação" )

   bAnterior := ErrorBlock( {| e | Break( e ) } )

   BEGIN SEQUENCE
      hRes[ "valor" ] := Eval( bBloco )
   RECOVER USING oErr
      s_nErros++
      hRes[ "ok" ]       := .F.
      hRes[ "erro" ]     := oErr
      hRes[ "mensagem" ] := ErroMensagemUsuario( oErr, cOperacao )
      hRes[ "tecnico" ]  := ErroContextoTecnico( oErr, cOperacao )

      /* rollback quando necessário (briefing §18): quem sabe o que desfazer é
         quem chamou, então recebe a chance antes de a mensagem subir */
      IF bLimpeza != NIL
         BEGIN SEQUENCE
            Eval( bLimpeza, oErr )
         RECOVER
            /* falha na limpeza não pode mascarar o erro original */
         END SEQUENCE
      ENDIF

      LogErro( hRes[ "mensagem" ], hRes[ "tecnico" ] )
   END SEQUENCE

   ErrorBlock( bAnterior )

   RETURN hRes

/*
 * Mensagem ao usuário: diz o que falhou e, quando dá, o que fazer.
 * Nunca traz nome de função, número de linha ou código interno.
 */
STATIC FUNCTION ErroMensagemUsuario( oErr, cOperacao )

   LOCAL cDesc, nGen

   IF ValType( oErr ) != "O"
      RETURN "Não foi possível " + cOperacao + "."
   ENDIF

   nGen  := iif( oErr:genCode == NIL, 0, oErr:genCode )
   cDesc := iif( Empty( oErr:description ), "", oErr:description )

   DO CASE
   CASE nGen == EG_OPEN .OR. nGen == EG_CREATE
      RETURN "Não foi possível " + cOperacao + ": o arquivo não pôde ser aberto. " + ;
             "Verifique se ele existe e se você tem permissão de acesso."
   CASE nGen == EG_NOFUNC .OR. nGen == EG_NOMETHOD .OR. nGen == EG_NOVAR
      RETURN "Não foi possível " + cOperacao + " por uma falha interna do sistema. " + ;
             "O suporte técnico precisa ser acionado; o log tem os detalhes."
   CASE nGen == EG_ARG .OR. nGen == EG_BOUND
      RETURN "Não foi possível " + cOperacao + ": um valor informado não é válido " + ;
             "para esta operação."
   CASE nGen == EG_ZERODIV
      RETURN "Não foi possível " + cOperacao + ": houve uma divisão por zero no cálculo."
   CASE nGen == EG_MEM
      RETURN "Não foi possível " + cOperacao + ": memória insuficiente."
   ENDCASE

   RETURN "Não foi possível " + cOperacao + ;
          iif( Empty( cDesc ), ".", ": " + Lower( Left( cDesc, 1 ) ) + SubStr( cDesc, 2 ) + "." )

/* Contexto técnico: tudo o que o diagnóstico precisa, só para o log. */
STATIC FUNCTION ErroContextoTecnico( oErr, cOperacao )

   LOCAL cCtx, i, cPilha := ""

   IF ValType( oErr ) != "O"
      RETURN "operação=" + cOperacao + " erro=(não é objeto de erro)"
   ENDIF

   cCtx := "operação=" + cOperacao
   cCtx += " subsistema=" + hb_ValToStr( oErr:subsystem )
   cCtx += " genCode=" + hb_ValToStr( oErr:genCode )
   cCtx += " subCode=" + hb_ValToStr( oErr:subCode )
   cCtx += " osCode=" + hb_ValToStr( oErr:osCode )
   cCtx += " operação_interna=" + hb_ValToStr( oErr:operation )
   IF !Empty( oErr:description )
      cCtx += " descrição=" + oErr:description
   ENDIF
   IF !Empty( oErr:filename )
      cCtx += " arquivo=" + oErr:filename
   ENDIF

   /* a pilha vai para o log, nunca para a tela */
   FOR i := 2 TO 12
      IF Empty( ProcName( i ) )
         EXIT
      ENDIF
      cPilha += iif( Empty( cPilha ), "", " < " ) + ;
                ProcName( i ) + "(" + hb_ntos( ProcLine( i ) ) + ")"
   NEXT
   IF !Empty( cPilha )
      cCtx += " pilha=" + cPilha
   ENDIF

   RETURN cCtx

/* Quantos erros foram tratados nesta execução — usado no resumo de saída. */
FUNCTION ErroTotal()
   RETURN s_nErros

PROCEDURE ErroZerar()
   s_nErros := 0
   RETURN
