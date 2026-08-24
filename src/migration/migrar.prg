/*
 * migrar.prg — FASE D.6: orquestrador da migração
 *
 * Especificação: docs/08-MIGRACAO-DADOS.md §5 (idempotência), §10 (backup e
 * reversão) e §11 (comandos e códigos de saída).
 *
 *   sccv-migrar --origem <dir> --destino <arquivo.db> [--forcar]
 *   sccv-migrar --verificar --destino <arquivo.db>
 *   sccv-migrar --relatorio --destino <arquivo.db> [--saida <arquivo.txt>]
 *
 * Códigos de saída (§11):
 *   0 sucesso · 1 erro de uso · 2 origem inválida
 *   3 destino já populado sem --forcar · 4 falha na carga (rollback aplicado)
 *   5 falha na verificação
 *
 * A migração NÃO é incremental (§5): reexecutar refaz tudo. Com 155 registros
 * isso é mais auditável do que reconciliar diferenças.
 */

#include "fileio.ch"
#include "directry.ch"

#define SAIDA_OK              0
#define SAIDA_USO             1
#define SAIDA_ORIGEM          2
#define SAIDA_POPULADO        3
#define SAIDA_CARGA           4
#define SAIDA_VERIFICACAO     5

#define VERSAO_SCHEMA         "1"

PROCEDURE Main( ... )

   LOCAL hOpc, nSaida

   hOpc := Opcoes( hb_AParams() )
   IF hOpc[ "erro" ] != NIL
      Msg( "erro de uso: " + hOpc[ "erro" ] )
      Uso()
      ErrorLevel( SAIDA_USO )
      RETURN
   ENDIF

   DO CASE
   CASE hOpc[ "verificar" ] ; nSaida := Verificar( hOpc )
   CASE hOpc[ "relatorio" ] ; nSaida := Relatorio( hOpc )
   OTHERWISE                ; nSaida := Migrar( hOpc )
   ENDCASE

   ErrorLevel( nSaida )

   RETURN

/* ------------------------------------------------------------------ */

STATIC FUNCTION Migrar( hOpc )

   LOCAL pDb, hReg, hRes, nExec, cBak, nRc, cDirSaida

   IF !hb_vfDirExists( hOpc[ "origem" ] )
      Msg( "origem inválida: " + hOpc[ "origem" ] + " não é um diretório" )
      RETURN SAIDA_ORIGEM
   ENDIF
   IF !hb_vfExists( hOpc[ "origem" ] + hb_ps() + "CVBCLIEN.DBF" )
      Msg( "origem inválida: " + hOpc[ "origem" ] + " não contém CVBCLIEN.DBF" )
      RETURN SAIDA_ORIGEM
   ENDIF

   /* §5 — idempotência */
   IF hb_vfExists( hOpc[ "destino" ] )
      IF DestinoPopulado( hOpc[ "destino" ] )
         IF !hOpc[ "forcar" ]
            Msg( "destino já contém dados: " + hOpc[ "destino" ] )
            Msg( "use --forcar para substituí-lo (o atual é preservado em .bak.<timestamp>)" )
            RETURN SAIDA_POPULADO
         ENDIF
         cBak := hOpc[ "destino" ] + ".bak." + Carimbo()
         IF !hb_vfRename( hOpc[ "destino" ], cBak ) == 0 .AND. !hb_vfExists( cBak )
            Msg( "não foi possível preservar o destino atual em " + cBak )
            RETURN SAIDA_CARGA
         ENDIF
         Msg( "destino anterior preservado em " + cBak )
      ELSE
         /* existe e está vazio: recomeça do zero, é mais simples que conferir
            se o schema aplicado confere com o atual */
         hb_vfErase( hOpc[ "destino" ] )
      ENDIF
   ENDIF

   Msg( "origem .....: " + hOpc[ "origem" ] )
   Msg( "destino ....: " + hOpc[ "destino" ] )

   pDb := SqlAbrir( hOpc[ "destino" ] )
   IF pDb == NIL
      Msg( "não foi possível criar o banco de destino" )
      RETURN SAIDA_CARGA
   ENDIF

   nRc := SqlExec( pDb, hb_MemoRead( hOpc[ "schema" ] ) )
   IF nRc != 0
      Msg( "falha ao aplicar o schema: " + SqlErro( pDb ) )
      RETURN SAIDA_CARGA
   ENDIF
   nRc := SqlExec( pDb, hb_MemoRead( hOpc[ "views" ] ) )
   IF nRc != 0
      Msg( "falha ao aplicar as views: " + SqlErro( pDb ) )
      RETURN SAIDA_CARGA
   ENDIF
   Msg( "schema aplicado" )

   SqlExecBind( pDb, "INSERT INTO migracao_execucao (iniciada_em, origem," + ;
      " versao_schema, status) VALUES (?,?,?,?)", ;
      { IncAgora(), hOpc[ "origem" ], VERSAO_SCHEMA, "EM_ANDAMENTO" } )
   nExec := SqlUltimoId( pDb )

   hReg := IncNovo()
   hRes := CarregarTudo( pDb, hOpc[ "origem" ], hReg )

   IF hRes[ "erro" ] != NIL
      SqlExecBind( pDb, "UPDATE migracao_execucao SET status = ?, concluida_em = ?" + ;
         " WHERE id = ?", { "FALHOU", IncAgora(), nExec } )
      Msg( "" )
      Msg( "FALHA NA CARGA — rollback aplicado na tabela em curso" )
      Msg( "  " + hRes[ "erro" ] )
      RETURN SAIDA_CARGA
   ENDIF

   IncGravarSqlite( hReg, pDb, nExec )
   SqlExecBind( pDb, "UPDATE migracao_execucao SET status = ?, concluida_em = ?," + ;
      " registros_lidos = ?, registros_gravados = ?, inconsistencias = ? WHERE id = ?", ;
      { "CONCLUIDA", IncAgora(), hRes[ "lidos" ], hRes[ "gravados" ], ;
        IncTotal( hReg ), nExec } )

   cDirSaida := hb_FNameDir( hOpc[ "destino" ] )
   IncGravarTexto( hReg, cDirSaida + "relatorio-migracao.txt" )
   IncGravarCsv( hReg, cDirSaida + "relatorio-migracao.csv" )

   Resumo( hRes, hReg, cDirSaida )
   pDb := NIL

   RETURN SAIDA_OK

STATIC PROCEDURE Resumo( hRes, hReg, cDirSaida )

   LOCAL aChaves, i

   Msg( "" )
   Msg( "registros lidos ....: " + hb_ntos( hRes[ "lidos" ] ) )
   Msg( "registros gravados .: " + hb_ntos( hRes[ "gravados" ] ) )
   Msg( "" )
   aChaves := hb_HKeys( hRes[ "tabelas" ] )
   FOR i := 1 TO Len( aChaves )
      Msg( "  " + PadR( aChaves[ i ], 20 ) + Str( hRes[ "tabelas" ][ aChaves[ i ] ], 5 ) )
   NEXT
   Msg( "" )
   Msg( "inconsistências ....: " + hb_ntos( IncTotal( hReg ) ) + ;
        "   ALTA " + hb_ntos( IncContagem( hReg, "ALTA" ) ) + ;
        " · MEDIA " + hb_ntos( IncContagem( hReg, "MEDIA" ) ) + ;
        " · BAIXA " + hb_ntos( IncContagem( hReg, "BAIXA" ) ) )
   Msg( "relatórios .........: " + cDirSaida + "relatorio-migracao.{txt,csv}" )
   Msg( "" )
   Msg( "Nenhum registro foi descartado; nenhum valor foi corrigido em silêncio." )

   RETURN

/*
 * Verificação estrutural. A verificação completa — contagens, somas de
 * controle e comparação campo a campo — é a FASE E (verificador.prg).
 */
STATIC FUNCTION Verificar( hOpc )

   LOCAL pDb, xInteg, aFk, nSaida := SAIDA_OK

   IF !hb_vfExists( hOpc[ "destino" ] )
      Msg( "destino inexistente: " + hOpc[ "destino" ] )
      RETURN SAIDA_USO
   ENDIF

   pDb := SqlAbrir( hOpc[ "destino" ], .F. )
   IF pDb == NIL
      Msg( "não foi possível abrir " + hOpc[ "destino" ] )
      RETURN SAIDA_VERIFICACAO
   ENDIF

   xInteg := SqlEscalar( pDb, "PRAGMA integrity_check" )
   Msg( "integrity_check ....: " + hb_ValToExp( xInteg ) )
   IF !( xInteg == "ok" )
      nSaida := SAIDA_VERIFICACAO
   ENDIF

   aFk := SqlLinhas( pDb, "PRAGMA foreign_key_check" )
   Msg( "foreign_key_check ..: " + iif( Len( aFk ) == 0, "vazio", ;
        hb_ntos( Len( aFk ) ) + " violação(ões)" ) )
   IF Len( aFk ) > 0
      nSaida := SAIDA_VERIFICACAO
   ENDIF

   Msg( "foreign_keys ON ....: " + hb_ValToExp( SqlEscalar( pDb, "PRAGMA foreign_keys" ) ) )
   Msg( "user_version .......: " + hb_ValToExp( SqlEscalar( pDb, "PRAGMA user_version" ) ) )
   Msg( "execução ...........: " + hb_ValToExp( SqlEscalar( pDb, ;
        "SELECT status FROM migracao_execucao ORDER BY id DESC LIMIT 1" ) ) )
   pDb := NIL

   RETURN nSaida

/* Regera os relatórios a partir da tabela, sem reexecutar a migração. */
STATIC FUNCTION Relatorio( hOpc )

   LOCAL pDb, aLin, i, hReg, cSaida

   IF !hb_vfExists( hOpc[ "destino" ] )
      Msg( "destino inexistente: " + hOpc[ "destino" ] )
      RETURN SAIDA_USO
   ENDIF

   pDb  := SqlAbrir( hOpc[ "destino" ], .F. )
   hReg := IncNovo()
   aLin := SqlLinhas( pDb, "SELECT arquivo, registro, chave, campo," + ;
      " valor_original, problema, acao, severidade FROM migracao_inconsistencia" + ;
      " ORDER BY id" )
   FOR i := 1 TO Len( aLin )
      IncRegistrar( hReg, aLin[ i ][ 1 ], aLin[ i ][ 2 ], aLin[ i ][ 3 ], ;
         aLin[ i ][ 4 ], aLin[ i ][ 5 ], aLin[ i ][ 6 ], aLin[ i ][ 7 ], aLin[ i ][ 8 ] )
   NEXT
   pDb := NIL

   cSaida := iif( hOpc[ "saida" ] == NIL, ;
      hb_FNameDir( hOpc[ "destino" ] ) + "relatorio-migracao.txt", hOpc[ "saida" ] )
   IncGravarTexto( hReg, cSaida )
   IncGravarCsv( hReg, hb_FNameExtSet( cSaida, ".csv" ) )
   Msg( hb_ntos( IncTotal( hReg ) ) + " inconsistências em " + cSaida )

   RETURN SAIDA_OK

/* ------------------------------------------------------------------ */

/* "Com dados" = alguma tabela de negócio tem linha. */
STATIC FUNCTION DestinoPopulado( cArquivo )

   LOCAL pDb, xN, lPop := .F.

   pDb := SqlAbrir( cArquivo, .F. )
   IF pDb == NIL
      RETURN .F.
   ENDIF
   xN := SqlEscalar( pDb, "SELECT count(*) FROM sqlite_master WHERE type='table'" + ;
                          " AND name='cliente'" )
   IF xN != NIL .AND. xN > 0
      xN := SqlEscalar( pDb, "SELECT count(*) FROM cliente" )
      lPop := ( xN != NIL .AND. xN > 0 )
   ENDIF
   pDb := NIL

   RETURN lPop

STATIC FUNCTION Opcoes( aArgs )

   LOCAL hOpc, i, cArg

   hOpc := { "origem" => "legacy", "destino" => "sccv.db", "forcar" => .F., ;
             "verificar" => .F., "relatorio" => .F., "saida" => NIL, ;
             "schema" => "database/schema.sql", "views" => "database/views.sql", ;
             "erro" => NIL }

   i := 1
   DO WHILE i <= Len( aArgs )
      cArg := aArgs[ i ]
      DO CASE
      CASE cArg == "--origem"    ; i++ ; hOpc[ "origem" ]  := Valor( aArgs, i, hOpc )
      CASE cArg == "--destino"   ; i++ ; hOpc[ "destino" ] := Valor( aArgs, i, hOpc )
      CASE cArg == "--saida"     ; i++ ; hOpc[ "saida" ]   := Valor( aArgs, i, hOpc )
      CASE cArg == "--schema"    ; i++ ; hOpc[ "schema" ]  := Valor( aArgs, i, hOpc )
      CASE cArg == "--views"     ; i++ ; hOpc[ "views" ]   := Valor( aArgs, i, hOpc )
      CASE cArg == "--forcar"    ; hOpc[ "forcar" ]    := .T.
      CASE cArg == "--verificar" ; hOpc[ "verificar" ] := .T.
      CASE cArg == "--relatorio" ; hOpc[ "relatorio" ] := .T.
      CASE cArg == "--ajuda" .OR. cArg == "-h" ; Uso() ; hOpc[ "erro" ] := NIL
      OTHERWISE
         hOpc[ "erro" ] := "opção desconhecida: " + cArg
         RETURN hOpc
      ENDCASE
      i++
   ENDDO

   RETURN hOpc

STATIC FUNCTION Valor( aArgs, i, hOpc )
   IF i > Len( aArgs )
      hOpc[ "erro" ] := "faltou o valor de " + aArgs[ i - 1 ]
      RETURN ""
   ENDIF
   RETURN aArgs[ i ]

STATIC PROCEDURE Uso()
   Msg( "" )
   Msg( "uso: sccv-migrar [opções]" )
   Msg( "  --origem <dir>       diretório do legado          (padrão: legacy)" )
   Msg( "  --destino <arquivo>  banco SQLite de destino      (padrão: sccv.db)" )
   Msg( "  --forcar             substitui destino já populado (preserva .bak)" )
   Msg( "  --verificar          só verifica o destino" )
   Msg( "  --relatorio          regera os relatórios do destino" )
   Msg( "  --saida <arquivo>    caminho do relatório em texto" )
   Msg( "" )
   Msg( "saída: 0 ok · 1 uso · 2 origem · 3 destino populado · 4 carga · 5 verificação" )
   RETURN

/* hb_TToC junta data e hora com espaço; nome de arquivo não leva espaço. */
STATIC FUNCTION Carimbo()
   RETURN StrTran( hb_TToC( hb_DateTime(), "YYYYMMDD", "HHMMSS" ), " ", "-" )

STATIC PROCEDURE Msg( cTexto )
   OutStd( cTexto + hb_eol() )
   RETURN
