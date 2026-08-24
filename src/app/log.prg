/*
 * log.prg — FASE F.5
 *
 * Log em arquivo, com níveis, rotação simples e caminho configurável.
 *
 * O log é o lugar onde o contexto técnico de um erro vai parar — a mensagem que
 * o usuário NÃO vê (briefing §18). Por isso ele nunca pode ser a causa de uma
 * falha: se o arquivo não puder ser aberto, o registro é descartado e a
 * aplicação segue. Um sistema que morre porque não conseguiu escrever no log
 * troca um problema pequeno por um grande.
 */

#include "fileio.ch"

#define LOG_DEBUG   1
#define LOG_INFO    2
#define LOG_AVISO   3
#define LOG_ERRO    4

STATIC s_cArquivo := NIL
STATIC s_nNivel := LOG_INFO
STATIC s_nMaxBytes := 1048576
STATIC s_lFalhou := .F.

FUNCTION LogIniciar( cArquivo, cNivel, nMaxBytes )

   s_cArquivo  := cArquivo
   s_nNivel    := LogNivelNum( cNivel )
   s_nMaxBytes := iif( nMaxBytes == NIL .OR. nMaxBytes <= 0, 1048576, nMaxBytes )
   s_lFalhou   := .F.

   RETURN s_cArquivo

FUNCTION LogNivel()
   RETURN LogNivelTexto( s_nNivel )

FUNCTION LogArquivo()
   RETURN s_cArquivo

PROCEDURE LogDebug( cMsg, cContexto )
   LogEscrever( LOG_DEBUG, cMsg, cContexto )
   RETURN

PROCEDURE LogInfo( cMsg, cContexto )
   LogEscrever( LOG_INFO, cMsg, cContexto )
   RETURN

PROCEDURE LogAviso( cMsg, cContexto )
   LogEscrever( LOG_AVISO, cMsg, cContexto )
   RETURN

PROCEDURE LogErro( cMsg, cContexto )
   LogEscrever( LOG_ERRO, cMsg, cContexto )
   RETURN

STATIC PROCEDURE LogEscrever( nNivel, cMsg, cContexto )

   LOCAL hF, cLinha

   IF s_cArquivo == NIL .OR. nNivel < s_nNivel
      RETURN
   ENDIF

   LogRotacionar()

   cLinha := hb_TToC( hb_DateTime(), "YYYY-MM-DD", "HH:MM:SS" ) + ;
             " [" + PadR( LogNivelTexto( nNivel ), 5 ) + "] " + cMsg
   IF !Empty( cContexto )
      cLinha += " | " + cContexto
   ENDIF

   hF := hb_vfOpen( s_cArquivo, FO_CREAT + FO_WRITE )
   IF hF == NIL
      /* avisa uma vez no stderr e desiste do log; não derruba a aplicação */
      IF !s_lFalhou
         s_lFalhou := .T.
         OutErr( "aviso: não foi possível escrever em " + s_cArquivo + hb_eol() )
      ENDIF
      RETURN
   ENDIF
   hb_vfSeek( hF, 0, FS_END )
   hb_vfWrite( hF, cLinha + hb_eol() )
   hb_vfClose( hF )

   RETURN

/* Rotação simples: ao passar do limite, o atual vira .1 e um novo começa. */
STATIC PROCEDURE LogRotacionar()

   LOCAL nTam := hb_vfSize( s_cArquivo )

   IF nTam == NIL .OR. nTam < s_nMaxBytes
      RETURN
   ENDIF
   hb_vfErase( s_cArquivo + ".1" )
   hb_vfRename( s_cArquivo, s_cArquivo + ".1" )

   RETURN

STATIC FUNCTION LogNivelNum( cNivel )
   DO CASE
   CASE Upper( AllTrim( hb_defaultValue( cNivel, "INFO" ) ) ) == "DEBUG" ; RETURN LOG_DEBUG
   CASE Upper( AllTrim( hb_defaultValue( cNivel, "INFO" ) ) ) == "AVISO" ; RETURN LOG_AVISO
   CASE Upper( AllTrim( hb_defaultValue( cNivel, "INFO" ) ) ) == "ERRO"  ; RETURN LOG_ERRO
   ENDCASE
   RETURN LOG_INFO

STATIC FUNCTION LogNivelTexto( nNivel )
   DO CASE
   CASE nNivel == LOG_DEBUG ; RETURN "DEBUG"
   CASE nNivel == LOG_AVISO ; RETURN "AVISO"
   CASE nNivel == LOG_ERRO  ; RETURN "ERRO"
   ENDCASE
   RETURN "INFO"
