/*
 * conexao.prg — FASE F.2
 *
 * Abertura e fechamento do banco, com os PRAGMAs que precisam ser emitidos
 * a cada conexão.
 *
 * `PRAGMA foreign_keys` é POR CONEXÃO e não pode ser gravado no arquivo
 * (database/README.md). Se a aplicação esquecer de emiti-lo, as 13 chaves
 * estrangeiras do schema viram decoração: o SQLite aceita órfãos em silêncio.
 * Por isso aqui ele é emitido e depois CONFERIDO — não basta pedir.
 *
 * `journal_mode = WAL` é persistente e já está no schema; conferimos para
 * detectar um banco criado fora do nosso caminho.
 */

#include "hbsqlit3.ch"

STATIC s_pDb := NIL
STATIC s_cArquivo := NIL

/*
 * Abre o banco. Devolve { "ok", "db", "mensagem" }.
 * lCriar = .F. (padrão) recusa banco inexistente: na aplicação, um banco que
 * não existe é quase sempre caminho errado de configuração, não convite para
 * criar um vazio.
 */
FUNCTION ConexaoAbrir( cArquivo, lCriar )

   LOCAL pDb, xFk, xJournal

   hb_default( @lCriar, .F. )

   IF !lCriar .AND. !hb_vfExists( cArquivo )
      RETURN { "ok" => .F., "db" => NIL, ;
               "mensagem" => "O banco de dados não foi encontrado em " + cArquivo + ;
                             ". Verifique a configuração ou execute a migração." }
   ENDIF

   pDb := SqlAbrir( cArquivo, lCriar )
   IF pDb == NIL
      RETURN { "ok" => .F., "db" => NIL, ;
               "mensagem" => "Não foi possível abrir o banco de dados em " + cArquivo + "." }
   ENDIF

   /* controle de concorrência: espera em vez de falhar de imediato (briefing §16) */
   SqlExec( pDb, "PRAGMA busy_timeout = 5000" )

   xFk := SqlEscalar( pDb, "PRAGMA foreign_keys" )
   IF xFk == NIL .OR. xFk != 1
      LogErro( "PRAGMA foreign_keys não ficou ativo", "arquivo=" + cArquivo )
      RETURN { "ok" => .F., "db" => NIL, ;
               "mensagem" => "O banco foi aberto sem verificação de integridade " + ;
                             "referencial e por isso não será usado." }
   ENDIF

   xJournal := SqlEscalar( pDb, "PRAGMA journal_mode" )
   IF xJournal != NIL .AND. !( Lower( hb_ValToStr( xJournal ) ) == "wal" )
      LogAviso( "journal_mode não é WAL", "modo=" + hb_ValToStr( xJournal ) )
   ENDIF

   s_pDb := pDb
   s_cArquivo := cArquivo
   LogInfo( "banco aberto", "arquivo=" + cArquivo + " fk=1 journal=" + ;
            hb_ValToStr( xJournal ) )

   RETURN { "ok" => .T., "db" => pDb, "mensagem" => NIL }

/* O hbsqlit3 não exporta sqlite3_close(): descartar a referência fecha. */
PROCEDURE ConexaoFechar()
   IF s_pDb != NIL
      LogInfo( "banco fechado", "arquivo=" + hb_ValToStr( s_cArquivo ) )
   ENDIF
   s_pDb := NIL
   s_cArquivo := NIL
   RETURN

FUNCTION ConexaoDb()
   RETURN s_pDb

FUNCTION ConexaoArquivo()
   RETURN s_cArquivo

/* Confere se o banco tem o schema esperado. */
FUNCTION ConexaoVersaoSchema( pDb )
   RETURN SqlEscalar( pDb, "PRAGMA user_version" )

FUNCTION ConexaoMigrado( pDb )

   LOCAL xN := SqlEscalar( pDb, "SELECT count(*) FROM sqlite_master " + ;
                                "WHERE type='table' AND name='cliente'" )

   IF xN == NIL .OR. xN == 0
      RETURN .F.
   ENDIF

   RETURN SqlEscalar( pDb, "SELECT count(*) FROM migracao_execucao " + ;
                           "WHERE status = 'CONCLUIDA'" ) > 0
