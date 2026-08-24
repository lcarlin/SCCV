/*
 * config.prg — FASE F.6
 *
 * Configuração da aplicação, com a precedência de 5 níveis do briefing §14 e
 * de docs/10-PLANO-IMPLEMENTACAO.md §3:
 *
 *   1. --config <arquivo>              argumento de linha de comando
 *   2. $SCCV_CONFIG                    variável de ambiente
 *   3. $XDG_CONFIG_HOME/sccv/sccv.conf  ou  ~/.config/sccv/sccv.conf
 *   4. /etc/sccv/sccv.conf
 *   5. valores embutidos
 *
 * O primeiro arquivo que EXISTIR vence; os demais não são mesclados. Mesclar
 * daria uma configuração efetiva que não está escrita em lugar nenhum — quem
 * for diagnosticar um problema precisa poder abrir UM arquivo e ver o que vale.
 * Chaves ausentes caem no valor embutido, e ConfigOrigem() diz de onde veio.
 *
 * Todos os caminhos são resolvidos para ABSOLUTOS na carga: a aplicação tem de
 * funcionar a partir de qualquer diretório corrente (briefing §14).
 */

#include "fileio.ch"

STATIC s_hConf := NIL
STATIC s_cOrigem := "(embutido)"

/*
 * Carrega a configuração. cArquivoCli é o valor de --config, ou NIL.
 * Devolve o hash de configuração; idempotente dentro do processo.
 */
FUNCTION ConfigCarregar( cArquivoCli )

   LOCAL cArq

   s_hConf := ConfigEmbutido()
   s_cOrigem := "(embutido)"

   cArq := ConfigLocalizar( cArquivoCli )
   IF cArq != NIL
      ConfigLerArquivo( cArq, s_hConf )
      s_cOrigem := cArq
   ENDIF

   ConfigAbsolutizar( s_hConf )

   RETURN s_hConf

FUNCTION ConfigObter( cChave, xPadrao )
   IF s_hConf == NIL
      ConfigCarregar()
   ENDIF
   IF cChave $ s_hConf
      RETURN s_hConf[ cChave ]
   ENDIF
   RETURN xPadrao

FUNCTION ConfigOrigem()
   RETURN s_cOrigem

FUNCTION ConfigTudo()
   IF s_hConf == NIL
      ConfigCarregar()
   ENDIF
   RETURN s_hConf

/* Nível 5 — valores embutidos, todos em caminhos XDG do usuário. */
STATIC FUNCTION ConfigEmbutido()
   RETURN { ;
      "banco"         => ConfigXdg( "XDG_DATA_HOME",  ".local/share" ) + "sccv/sccv.db", ;
      "log"           => ConfigXdg( "XDG_STATE_HOME", ".local/state" ) + "sccv/sccv.log", ;
      "log_nivel"     => "INFO", ;
      "log_max_bytes" => 1048576, ;
      "backup_dir"    => ConfigXdg( "XDG_DATA_HOME",  ".local/share" ) + "sccv/backup", ;
      "relatorio_dir" => hb_cwd() }

/* Níveis 1 a 4 — o primeiro que existir. */
STATIC FUNCTION ConfigLocalizar( cArquivoCli )

   LOCAL aCand, i, cEnv

   IF !Empty( cArquivoCli )
      /* pedido explicitamente: se não existir, é erro de uso, não silêncio */
      RETURN iif( hb_vfExists( cArquivoCli ), cArquivoCli, NIL )
   ENDIF

   aCand := {}
   cEnv := GetEnv( "SCCV_CONFIG" )
   IF !Empty( cEnv )
      AAdd( aCand, cEnv )
   ENDIF
   AAdd( aCand, ConfigXdg( "XDG_CONFIG_HOME", ".config" ) + "sccv/sccv.conf" )
   AAdd( aCand, "/etc/sccv/sccv.conf" )

   FOR i := 1 TO Len( aCand )
      IF hb_vfExists( aCand[ i ] )
         RETURN aCand[ i ]
      ENDIF
   NEXT

   RETURN NIL

/* $VAR se definida, senão $HOME/<padrão>; sempre com barra ao final. */
STATIC FUNCTION ConfigXdg( cVar, cPadrao )

   LOCAL cDir := GetEnv( cVar )

   IF Empty( cDir )
      cDir := GetEnv( "HOME" ) + hb_ps() + cPadrao
   ENDIF
   IF !( Right( cDir, 1 ) == hb_ps() )
      cDir += hb_ps()
   ENDIF

   RETURN cDir

/*
 * Formato: `chave = valor`, um por linha. `#` e `;` iniciam comentário.
 * Chave desconhecida é ignorada em silêncio? Não — ela vai para o hash mesmo
 * assim, para que um erro de digitação apareça em `sccv --config-mostrar`
 * em vez de sumir.
 */
STATIC PROCEDURE ConfigLerArquivo( cArquivo, hConf )

   LOCAL cTexto, aLinhas, i, cLinha, nIgual, cChave, cValor

   cTexto := hb_MemoRead( cArquivo )
   aLinhas := hb_ATokens( StrTran( cTexto, Chr( 13 ), "" ), Chr( 10 ) )

   FOR i := 1 TO Len( aLinhas )
      cLinha := AllTrim( aLinhas[ i ] )
      IF Empty( cLinha ) .OR. Left( cLinha, 1 ) == "#" .OR. Left( cLinha, 1 ) == ";"
         LOOP
      ENDIF
      nIgual := At( "=", cLinha )
      IF nIgual == 0
         LOOP
      ENDIF
      cChave := Lower( AllTrim( Left( cLinha, nIgual - 1 ) ) )
      cValor := AllTrim( SubStr( cLinha, nIgual + 1 ) )
      IF Empty( cChave )
         LOOP
      ENDIF
      /* preserva o tipo do valor embutido: numérico continua numérico */
      IF cChave $ hConf .AND. ValType( hConf[ cChave ] ) == "N"
         hConf[ cChave ] := Val( cValor )
      ELSE
         hConf[ cChave ] := cValor
      ENDIF
   NEXT

   RETURN

/*
 * Caminho relativo vira absoluto a partir do diretório corrente NA CARGA.
 * Depois disso, mudar de diretório não muda para onde a aplicação escreve.
 */
STATIC PROCEDURE ConfigAbsolutizar( hConf )

   LOCAL aChaves := { "banco", "log", "backup_dir", "relatorio_dir" }, i, cVal

   FOR i := 1 TO Len( aChaves )
      cVal := hConf[ aChaves[ i ] ]
      IF ValType( cVal ) != "C" .OR. Empty( cVal )
         LOOP
      ENDIF
      IF !( Left( cVal, 1 ) == hb_ps() )
         cVal := hb_cwd() + cVal
      ENDIF
      hConf[ aChaves[ i ] ] := hb_PathNormalize( cVal )
   NEXT

   RETURN

/* Cria os diretórios de banco, log e backup. Devolve NIL ou a mensagem de erro. */
FUNCTION ConfigPrepararDiretorios()

   LOCAL aDirs, i, cDir

   IF s_hConf == NIL
      ConfigCarregar()
   ENDIF

   aDirs := { hb_FNameDir( s_hConf[ "banco" ] ), ;
              hb_FNameDir( s_hConf[ "log" ] ), ;
              s_hConf[ "backup_dir" ] }

   FOR i := 1 TO Len( aDirs )
      cDir := aDirs[ i ]
      IF Empty( cDir ) .OR. hb_vfDirExists( cDir )
         LOOP
      ENDIF
      IF !hb_DirBuild( cDir )
         RETURN "não foi possível criar o diretório " + cDir
      ENDIF
   NEXT

   RETURN NIL
