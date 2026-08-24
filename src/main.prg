/*
 * main.prg — ponto de entrada do S.C.C.V.
 *
 * FASE F: a infraestrutura sobe e se apresenta. Os módulos funcionais são a
 * FASE G; até lá, `sccv` serve para verificar que configuração, log, banco e
 * tratamento de erro estão de pé no ambiente onde a aplicação vai rodar.
 *
 *   sccv [--config <arquivo>] [--banco <arquivo>]
 *   sccv --estado          estado do ambiente e do banco
 *   sccv --config-mostrar  configuração efetiva e de onde ela veio
 *   sccv --versao
 *
 * Saída: 0 sucesso · 1 erro de uso · 2 configuração/ambiente · 3 banco
 */

#define VERSAO   "0.1.0-fase-F"

#define SAIDA_OK      0
#define SAIDA_USO     1
#define SAIDA_AMBIENTE 2
#define SAIDA_BANCO   3

PROCEDURE Main( ... )

   LOCAL hArg, nSaida

   hArg := Argumentos( hb_AParams() )
   IF hArg[ "erro" ] != NIL
      OutErr( "erro de uso: " + hArg[ "erro" ] + hb_eol() )
      Uso()
      ErrorLevel( SAIDA_USO )
      RETURN
   ENDIF

   IF hArg[ "versao" ]
      Escrever( "S.C.C.V. " + VERSAO )
      Escrever( Ambiente() )
      ErrorLevel( SAIDA_OK )
      RETURN
   ENDIF

   nSaida := Iniciar( hArg )
   IF nSaida != SAIDA_OK
      ErrorLevel( nSaida )
      RETURN
   ENDIF

   DO CASE
   CASE hArg[ "config_mostrar" ] ; nSaida := MostrarConfig()
   OTHERWISE                     ; nSaida := Estado()
   ENDCASE

   ConexaoFechar()
   ErrorLevel( nSaida )

   RETURN

/* Sobe a infraestrutura na ordem em que uma depende da outra. */
STATIC FUNCTION Iniciar( hArg )

   LOCAL hConf, cErro, hCon, cBanco

   hConf := ConfigCarregar( hArg[ "config" ] )
   IF !Empty( hArg[ "config" ] ) .AND. !( ConfigOrigem() == hArg[ "config" ] )
      OutErr( "arquivo de configuração não encontrado: " + hArg[ "config" ] + hb_eol() )
      RETURN SAIDA_USO
   ENDIF

   cErro := ConfigPrepararDiretorios()
   IF cErro != NIL
      OutErr( cErro + hb_eol() )
      RETURN SAIDA_AMBIENTE
   ENDIF

   LogIniciar( hConf[ "log" ], hConf[ "log_nivel" ], hConf[ "log_max_bytes" ] )
   LogInfo( "início", "versão=" + VERSAO + " config=" + ConfigOrigem() )

   cBanco := iif( Empty( hArg[ "banco" ] ), hConf[ "banco" ], hArg[ "banco" ] )
   hCon := ConexaoAbrir( cBanco )
   IF !hCon[ "ok" ]
      Escrever( hCon[ "mensagem" ] )
      LogErro( "falha ao abrir o banco", "arquivo=" + cBanco )
      RETURN SAIDA_BANCO
   ENDIF

   RETURN SAIDA_OK

STATIC FUNCTION Estado()

   LOCAL pDb := ConexaoDb(), lMig

   Escrever( "S.C.C.V. " + VERSAO )
   Escrever( "" )
   Escrever( "configuração .: " + ConfigOrigem() )
   Escrever( "banco ........: " + ConexaoArquivo() )
   Escrever( "log ..........: " + LogArquivo() + "  (nível " + LogNivel() + ")" )
   Escrever( "" )
   Escrever( "schema .......: user_version " + Txt( ConexaoVersaoSchema( pDb ) ) )
   Escrever( "foreign_keys .: " + Txt( SqlEscalar( pDb, "PRAGMA foreign_keys" ) ) )
   Escrever( "journal_mode .: " + Txt( SqlEscalar( pDb, "PRAGMA journal_mode" ) ) )

   lMig := ConexaoMigrado( pDb )
   Escrever( "migração .....: " + iif( lMig, "concluída", "NÃO executada" ) )
   IF lMig
      Escrever( "" )
      Escrever( "clientes .....: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_cliente" ) ) )
      Escrever( "peças ........: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_peca" ) ) )
      Escrever( "vendas de peça: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_venda_peca" ) ) )
      Escrever( "veículos ven..: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_venda_veiculo" ) ) )
      Escrever( "cotas ........: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_consorcio_cota" ) ) )
      Escrever( "inconsistênc..: " + Txt( SqlEscalar( pDb, ;
         "SELECT count(*) FROM migracao_inconsistencia" ) ) )
   ELSE
      Escrever( "" )
      Escrever( "Execute a migração antes de usar o sistema:  make migrate" )
   ENDIF
   Escrever( "" )
   Escrever( "Módulos funcionais: FASE G, ainda não implementada." )

   RETURN SAIDA_OK

STATIC FUNCTION MostrarConfig()

   LOCAL hConf := ConfigTudo(), aChaves := hb_HKeys( hConf ), i

   Escrever( "configuração efetiva (origem: " + ConfigOrigem() + ")" )
   Escrever( "" )
   FOR i := 1 TO Len( aChaves )
      Escrever( "  " + PadR( aChaves[ i ], 16 ) + Txt( hConf[ aChaves[ i ] ] ) )
   NEXT
   Escrever( "" )
   Escrever( "precedência: --config · $SCCV_CONFIG · $XDG_CONFIG_HOME/sccv/sccv.conf" )
   Escrever( "             · /etc/sccv/sccv.conf · valores embutidos" )

   RETURN SAIDA_OK

STATIC FUNCTION Ambiente()
   RETURN "Harbour " + Version() + " · " + OS() + hb_eol() + ;
          "SQLite " + Txt( SqlEscalar( SqlAbrir( ":memory:" ), ;
                                               "SELECT sqlite_version()" ) )

STATIC FUNCTION Argumentos( aArgs )

   LOCAL hArg, i, cArg

   hArg := { "config" => NIL, "banco" => NIL, "versao" => .F., ;
             "config_mostrar" => .F., "erro" => NIL }

   i := 1
   DO WHILE i <= Len( aArgs )
      cArg := aArgs[ i ]
      DO CASE
      CASE cArg == "--config"
         i++
         IF i > Len( aArgs )
            hArg[ "erro" ] := "faltou o arquivo de --config"
            RETURN hArg
         ENDIF
         hArg[ "config" ] := aArgs[ i ]
      CASE cArg == "--banco"
         i++
         IF i > Len( aArgs )
            hArg[ "erro" ] := "faltou o arquivo de --banco"
            RETURN hArg
         ENDIF
         hArg[ "banco" ] := aArgs[ i ]
      CASE cArg == "--versao"         ; hArg[ "versao" ] := .T.
      CASE cArg == "--config-mostrar" ; hArg[ "config_mostrar" ] := .T.
      CASE cArg == "--estado"
         /* é o comportamento padrão; aceito explicitamente por clareza */
      CASE cArg == "--ajuda" .OR. cArg == "-h"
         Uso()
         hArg[ "versao" ] := .T.
      OTHERWISE
         hArg[ "erro" ] := "opção desconhecida: " + cArg
         RETURN hArg
      ENDCASE
      i++
   ENDDO

   RETURN hArg

STATIC PROCEDURE Uso()
   Escrever( "" )
   Escrever( "uso: sccv [opções]" )
   Escrever( "  --config <arquivo>   arquivo de configuração" )
   Escrever( "  --banco <arquivo>    banco de dados (sobrepõe a configuração)" )
   Escrever( "  --estado             estado do ambiente e do banco (padrão)" )
   Escrever( "  --config-mostrar     configuração efetiva e sua origem" )
   Escrever( "  --versao             versão e ambiente" )
   RETURN

/* hb_ValToStr() de numérico vem preenchido à esquerda; aqui interessa o valor. */
STATIC FUNCTION Txt( xValor )
   IF xValor == NIL
      RETURN "(nenhum)"
   ENDIF
   RETURN AllTrim( hb_ValToStr( xValor ) )

STATIC PROCEDURE Escrever( cTexto )
   OutStd( cTexto + hb_eol() )
   RETURN
