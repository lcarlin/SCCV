/*
 * sql.prg — acesso a SQLite via hbsqlit3
 *
 * Camada mínima usada pela migração (FASE D). A FASE F a estende para a
 * aplicação. Aqui só existe o necessário para carregar dados com segurança:
 * statements preparados com bind por tipo, transações e leitura escalar.
 *
 * BIND POR TIPO É OBRIGATÓRIO, não uma preferência de estilo: as tabelas são
 * STRICT (docs/09 D-11, database/README.md), então gravar um texto numa coluna
 * INTEGER é erro, não coerção. Concatenar valores no SQL também levaria aspas
 * dos dados do legado (`o babaca.`, `28 .534.428-8`) direto para dentro do
 * comando.
 *
 * Observação sobre o hbsqlit3: ele NÃO exporta sqlite3_close(). O banco é
 * fechado pelo destrutor do ponteiro — basta descartar a referência.
 */

#require "hbsqlit3"
#include "hbsqlit3.ch"

/* Abre (criando se preciso) e aplica os PRAGMAs que não são persistentes. */
FUNCTION SqlAbrir( cArquivo, lCriar )

   LOCAL pDb

   hb_default( @lCriar, .T. )

   pDb := sqlite3_open( cArquivo, lCriar )
   IF pDb == NIL
      RETURN NIL
   ENDIF

   /* foreign_keys é por conexão e não pode ser gravado no arquivo
      (database/README.md). Sem isto, as FKs do schema não são verificadas. */
   sqlite3_exec( pDb, "PRAGMA foreign_keys = ON" )

   RETURN pDb

FUNCTION SqlExec( pDb, cSql )
   RETURN sqlite3_exec( pDb, cSql )

FUNCTION SqlErro( pDb )
   RETURN sqlite3_errmsg( pDb )

/*
 * Executa um comando com parâmetros posicionais.
 * aValores aceita: NIL → NULL · numérico → INTEGER/REAL · caractere → TEXT
 * Devolve SQLITE_OK (0) ou o código do erro.
 */
FUNCTION SqlExecBind( pDb, cSql, aValores )

   LOCAL pStmt, i, xVal, nRc

   hb_default( @aValores, {} )

   pStmt := sqlite3_prepare( pDb, cSql )
   IF pStmt == NIL
      RETURN -1
   ENDIF

   FOR i := 1 TO Len( aValores )
      xVal := aValores[ i ]
      DO CASE
      CASE xVal == NIL
         sqlite3_bind_null( pStmt, i )
      CASE ValType( xVal ) == "N"
         IF xVal == Int( xVal )
            sqlite3_bind_int64( pStmt, i, xVal )
         ELSE
            sqlite3_bind_double( pStmt, i, xVal )
         ENDIF
      CASE ValType( xVal ) == "L"
         sqlite3_bind_int( pStmt, i, iif( xVal, 1, 0 ) )
      OTHERWISE
         sqlite3_bind_text( pStmt, i, xVal )
      ENDCASE
   NEXT

   nRc := sqlite3_step( pStmt )
   sqlite3_finalize( pStmt )

   RETURN iif( nRc == SQLITE_DONE .OR. nRc == SQLITE_ROW, SQLITE_OK, nRc )

/* Primeira coluna da primeira linha; NIL se não houver linha. */
FUNCTION SqlEscalar( pDb, cSql )

   LOCAL pStmt, xRes := NIL

   pStmt := sqlite3_prepare( pDb, cSql )
   IF pStmt == NIL
      RETURN NIL
   ENDIF
   IF sqlite3_step( pStmt ) == SQLITE_ROW
      IF sqlite3_column_type( pStmt, 1 ) == SQLITE_NULL
         xRes := NIL
      ELSEIF sqlite3_column_type( pStmt, 1 ) == SQLITE_TEXT
         xRes := sqlite3_column_text( pStmt, 1 )
      ELSE
         xRes := sqlite3_column_int64( pStmt, 1 )
      ENDIF
   ENDIF
   sqlite3_finalize( pStmt )

   RETURN xRes

/* Todas as linhas como array de arrays (uso restrito: verificação). */
FUNCTION SqlLinhas( pDb, cSql )

   LOCAL pStmt, aRes := {}, aLinha, i, nCols

   pStmt := sqlite3_prepare( pDb, cSql )
   IF pStmt == NIL
      RETURN aRes
   ENDIF
   DO WHILE sqlite3_step( pStmt ) == SQLITE_ROW
      nCols := sqlite3_column_count( pStmt )
      aLinha := {}
      FOR i := 1 TO nCols
         DO CASE
         CASE sqlite3_column_type( pStmt, i ) == SQLITE_NULL
            AAdd( aLinha, NIL )
         CASE sqlite3_column_type( pStmt, i ) == SQLITE_TEXT
            AAdd( aLinha, sqlite3_column_text( pStmt, i ) )
         OTHERWISE
            AAdd( aLinha, sqlite3_column_int64( pStmt, i ) )
         ENDCASE
      NEXT
      AAdd( aRes, aLinha )
   ENDDO
   sqlite3_finalize( pStmt )

   RETURN aRes

FUNCTION SqlUltimoId( pDb )
   RETURN sqlite3_last_insert_rowid( pDb )

FUNCTION SqlInicia( pDb )
   RETURN sqlite3_exec( pDb, "BEGIN" )

FUNCTION SqlConfirma( pDb )
   RETURN sqlite3_exec( pDb, "COMMIT" )

FUNCTION SqlDesfaz( pDb )
   RETURN sqlite3_exec( pDb, "ROLLBACK" )
