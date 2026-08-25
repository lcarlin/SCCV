/*
 * admin.prg — FASE G, onda 9
 *
 * Comandos administrativos: backup, dump, restore, verificação e purga.
 * Especificação: docs/10-PLANO-IMPLEMENTACAO.md §9 (briefing §30) e 09/D-15.
 *
 * D-15 — A PURGA DEIXOU DE SER EFEITO COLATERAL DE SAIR DO SISTEMA
 * ----------------------------------------------------------------
 * No legado, `SAIDA()` executava `PACK` em CVBCLIEN, CVBFORNE e CVBFUNC ao sair:
 * exclusão FÍSICA, irreversível, sem backup e sem verificar dependências. Um
 * PACK interrompido corrompia o arquivo. Isso não é regra de negócio — é
 * necessidade técnica do DBFNTX, que precisa compactar o arquivo para liberar
 * espaço dos registros marcados.
 *
 * Aqui sair encerra a aplicação e mais nada. A purga é um comando deliberado,
 * que EXIGE backup, verifica dependências e recusa purgar quem ainda é
 * referenciado. O resultado é mais conservador que o legado: registros
 * excluídos continuam recuperáveis até que alguém decida o contrário.
 */

#require "hbsqlit3"
#include "hbsqlit3.ch"
#include "fileio.ch"

/* Todo banco SQLite começa com "SQLite format 3" + byte zero. */
STATIC FUNCTION AdminEhSqlite( cArquivo )

   LOCAL hF, cBuf := Space( 16 ), lOk

   hF := hb_vfOpen( cArquivo, FO_READ + FO_SHARED )
   IF hF == NIL
      RETURN .F.
   ENDIF
   lOk := ( hb_vfRead( hF, @cBuf, 16 ) == 16 .AND. ;
            Left( cBuf, 15 ) == "SQLite format 3" )
   hb_vfClose( hF )

   RETURN lOk

STATIC FUNCTION AdminAgora()
   RETURN hb_TToC( hb_DateTime(), "YYYY-MM-DD", "HH:MM:SS" )

/* Tabelas com exclusão lógica, na ordem inversa da topológica. */
STATIC FUNCTION TabelasPurgaveis()
   RETURN { ;
      { "venda_peca"      , "id"     , "venda de peça"       }, ;
      { "venda_veiculo"   , "id"     , "venda de veículo"    }, ;
      { "consorcio_cota"  , "id"     , "cota de consórcio"   }, ;
      { "orcamento_reparo", "id"     , "orçamento de reparo" }, ;
      { "pedido"          , "cod_ped", "pedido"              }, ;
      { "peca"            , "cod_pec", "peça"                }, ;
      { "almoxarifado"    , "cod_alm", "item de almoxarifado" }, ;
      { "modelo_veiculo"  , "cod_car", "modelo de veículo"   }, ;
      { "cliente"         , "cod_cli", "cliente"             }, ;
      { "funcionario"     , "cod_fun", "funcionário"         }, ;
      { "fornecedor"      , "cod_for", "fornecedor"          } }

/*
 * Backup físico, com a API de backup do próprio SQLite — consistente mesmo com
 * o banco aberto e em uso, diferente de copiar o arquivo por fora.
 */
FUNCTION AdminBackup( pDb, cDestino )

   LOCAL cErro

   IF Empty( cDestino )
      cDestino := AdminNomeBackup( ConexaoArquivo() )
   ENDIF

   cErro := AdminCopiarBanco( pDb, cDestino )
   IF cErro != NIL
      RETURN { "ok" => .F., "mensagem" => cErro, "arquivo" => NIL }
   ENDIF

   LogInfo( "backup gerado", "arquivo=" + cDestino )

   RETURN { "ok" => .T., "mensagem" => "Backup gravado em " + cDestino, ;
            "arquivo" => cDestino }

/*
 * Copia um banco aberto para um arquivo, com a API de backup do próprio SQLite.
 *
 * É melhor que copiar o arquivo por fora em dois aspectos: funciona com o banco
 * aberto e em uso (o SQLite garante a consistência da cópia), e o destino é
 * necessariamente um banco válido — copiar bytes de um arquivo em escrita
 * poderia produzir um arquivo truncado no meio de uma transação.
 *
 * Devolve NIL em sucesso, ou a mensagem do erro.
 */
STATIC FUNCTION AdminCopiarBanco( pOrigem, cDestino )

   LOCAL pDest, pBackup, nRc

   hb_vfErase( cDestino )
   pDest := sqlite3_open( cDestino, .T. )
   IF pDest == NIL
      RETURN "Não foi possível criar " + cDestino
   ENDIF

   pBackup := sqlite3_backup_init( pDest, "main", pOrigem, "main" )
   IF pBackup == NIL
      cDestino := sqlite3_errmsg( pDest )
      pDest := NIL
      RETURN "Não foi possível iniciar a cópia: " + cDestino
   ENDIF

   nRc := sqlite3_backup_step( pBackup, -1 )   /* -1 = tudo de uma vez */
   sqlite3_backup_finish( pBackup )
   pDest := NIL

   IF nRc != SQLITE_DONE .AND. nRc != SQLITE_OK
      RETURN "Falha ao copiar o banco (código " + hb_ntos( nRc ) + ")"
   ENDIF

   RETURN NIL

STATIC FUNCTION AdminNomeBackup( cBanco )

   LOCAL cDir := ConfigObter( "backup_dir", hb_DirTemp() )

   IF !( Right( cDir, 1 ) == hb_ps() )
      cDir += hb_ps()
   ENDIF
   hb_DirBuild( cDir )

   RETURN cDir + hb_FNameName( iif( cBanco == NIL, "sccv", cBanco ) ) + "-" + ;
          StrTran( hb_TToC( hb_DateTime(), "YYYYMMDD", "HHMMSS" ), " ", "-" ) + ".db"

/*
 * Backup lógico: texto SQL, versionável e portável entre versões do SQLite.
 * O backup físico é um arquivo binário; se o formato mudar, ou se o arquivo se
 * corromper, o texto continua legível e recarregável.
 */
FUNCTION AdminDump( pDb, cArquivo )

   LOCAL hF, aTabelas, i, cTxt := ""

   cTxt += "-- S.C.C.V. — dump lógico gerado em " + AdminAgora() + hb_eol()
   cTxt += "PRAGMA foreign_keys = OFF;" + hb_eol()
   cTxt += "BEGIN TRANSACTION;" + hb_eol()

   /* o schema, como está gravado no próprio banco */
   aTabelas := SqlLinhas( pDb, "SELECT sql FROM sqlite_master" + ;
      " WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY" + ;
      " CASE type WHEN 'table' THEN 1 WHEN 'index' THEN 2 ELSE 3 END, name" )
   FOR i := 1 TO Len( aTabelas )
      cTxt += aTabelas[ i ][ 1 ] + ";" + hb_eol()
   NEXT

   /* os dados */
   aTabelas := SqlLinhas( pDb, "SELECT name FROM sqlite_master WHERE type='table'" + ;
      " AND name NOT LIKE 'sqlite_%' ORDER BY name" )
   FOR i := 1 TO Len( aTabelas )
      cTxt += AdminDumpTabela( pDb, aTabelas[ i ][ 1 ] )
   NEXT

   cTxt += "COMMIT;" + hb_eol()

   hF := hb_vfOpen( cArquivo, FO_CREAT + FO_TRUNC + FO_WRITE )
   IF hF == NIL
      RETURN { "ok" => .F., "mensagem" => "Não foi possível gravar " + cArquivo }
   ENDIF
   hb_vfWrite( hF, cTxt )
   hb_vfClose( hF )

   LogInfo( "dump lógico gerado", "arquivo=" + cArquivo )

   RETURN { "ok" => .T., "mensagem" => "Dump gravado em " + cArquivo }

STATIC FUNCTION AdminDumpTabela( pDb, cTabela )

   LOCAL aCols, aLin, i, j, cTxt := "", cVals, cNomes := ""

   aCols := SqlLinhas( pDb, "SELECT name FROM pragma_table_info('" + cTabela + "')" )
   IF Len( aCols ) == 0
      RETURN ""
   ENDIF
   FOR j := 1 TO Len( aCols )
      cNomes += iif( j > 1, ", ", "" ) + aCols[ j ][ 1 ]
   NEXT

   aLin := SqlLinhas( pDb, "SELECT " + cNomes + " FROM " + cTabela )
   FOR i := 1 TO Len( aLin )
      cVals := ""
      FOR j := 1 TO Len( aLin[ i ] )
         cVals += iif( j > 1, ", ", "" ) + AdminLiteral( aLin[ i ][ j ] )
      NEXT
      cTxt += "INSERT INTO " + cTabela + " (" + cNomes + ") VALUES (" + cVals + ");" + hb_eol()
   NEXT

   RETURN cTxt

/* Aspas simples dobradas, como manda o SQL. */
STATIC FUNCTION AdminLiteral( xVal )

   IF xVal == NIL
      RETURN "NULL"
   ENDIF
   IF ValType( xVal ) == "N"
      RETURN hb_ntos( xVal )
   ENDIF

   RETURN "'" + StrTran( hb_ValToStr( xVal ), "'", "''" ) + "'"

/*
 * Restore físico.
 *
 * Verifica a integridade do arquivo ANTES de substituir, e preserva o atual
 * como `.bak`. Restaurar de um backup corrompido sobre um banco bom troca um
 * problema por dois — e sem a cópia do atual não há como voltar atrás.
 */
FUNCTION AdminRestore( cOrigem, cDestino )

   LOCAL pTeste, xInteg, cBak, pAtual, pOrig, cErro

   IF !hb_vfExists( cOrigem )
      RETURN { "ok" => .F., "mensagem" => "Arquivo de backup não encontrado: " + cOrigem }
   ENDIF

   /*
    * sqlite3_open() aceita QUALQUER arquivo — ele só descobre que não é um
    * banco na primeira consulta, e aí falha lá dentro. Conferir o cabeçalho
    * antes é determinístico: todo banco SQLite começa com "SQLite format 3"
    * seguido de um byte zero.
    */
   IF !AdminEhSqlite( cOrigem )
      RETURN { "ok" => .F., "mensagem" => "O arquivo não é um banco SQLite válido: " + cOrigem }
   ENDIF

   pTeste := sqlite3_open( cOrigem, .F. )
   IF pTeste == NIL
      RETURN { "ok" => .F., "mensagem" => "Não foi possível abrir " + cOrigem }
   ENDIF
   xInteg := SqlEscalar( pTeste, "PRAGMA integrity_check" )
   IF !( hb_ValToStr( xInteg ) == "ok" )
      pTeste := NIL
      RETURN { "ok" => .F., ;
               "mensagem" => "O backup está corrompido e NÃO foi restaurado: " + ;
                             hb_ValToStr( xInteg ) }
   ENDIF
   IF SqlEscalar( pTeste, "SELECT count(*) FROM sqlite_master WHERE type='table'" + ;
                          " AND name='cliente'" ) == 0
      pTeste := NIL
      RETURN { "ok" => .F., ;
               "mensagem" => "O arquivo é um banco SQLite, mas não é um banco do S.C.C.V." }
   ENDIF
   pTeste := NIL

   IF hb_vfExists( cDestino )
      cBak := cDestino + ".bak." + ;
              StrTran( hb_TToC( hb_DateTime(), "YYYYMMDD", "HHMMSS" ), " ", "-" )
      pAtual := sqlite3_open( cDestino, .F. )
      IF pAtual == NIL
         RETURN { "ok" => .F., ;
                  "mensagem" => "Não foi possível abrir o banco atual para preservá-lo." }
      ENDIF
      cErro := AdminCopiarBanco( pAtual, cBak )
      pAtual := NIL
      IF cErro != NIL
         RETURN { "ok" => .F., ;
                  "mensagem" => "Não foi possível preservar o banco atual: " + cErro }
      ENDIF
   ENDIF

   pOrig := sqlite3_open( cOrigem, .F. )
   IF pOrig == NIL
      RETURN { "ok" => .F., "mensagem" => "Não foi possível reabrir o backup." }
   ENDIF
   cErro := AdminCopiarBanco( pOrig, cDestino )
   pOrig := NIL
   IF cErro != NIL
      RETURN { "ok" => .F., "mensagem" => cErro }
   ENDIF

   /* Empty() e não `cBak == NIL`: em Harbour a comparação EXATA contra NIL
      levanta erro de tipo quando a variável contém uma string. `!=` tolera,
      `==` não. */
   LogInfo( "restore aplicado", "origem=" + cOrigem + " destino=" + cDestino + ;
            iif( Empty( cBak ), "", " anterior=" + cBak ) )

   RETURN { "ok" => .T., ;
            "mensagem" => "Restaurado de " + cOrigem + ;
                          iif( Empty( cBak ), "", "; o banco anterior está em " + cBak ), ;
            "anterior" => cBak }

/*
 * Purga: remove FISICAMENTE os registros marcados como excluídos.
 *
 * Três garantias que o `PACK` do legado não tinha:
 *   1. backup obrigatório antes, não desativável;
 *   2. registro ainda referenciado NÃO é purgado — é relatado;
 *   3. tudo numa transação: purga interrompida não deixa o banco pela metade.
 *
 * lSimular = .T. apenas relata o que seria purgado, sem apagar nada.
 */
FUNCTION AdminPurgar( pDb, lSimular, cArquivoBanco )

   LOCAL aTab := TabelasPurgaveis(), i, hRes, aCand, j, nId
   LOCAL aPurgados := {}, aRetidos := {}, hBackup := NIL, nTotal := 0

   hb_default( @lSimular, .F. )

   IF !lSimular
      hBackup := AdminBackup( pDb, NIL )
      IF !hBackup[ "ok" ]
         RETURN { "ok" => .F., ;
                  "mensagem" => "Purga cancelada: o backup obrigatório falhou. " + ;
                                hBackup[ "mensagem" ], ;
                  "purgados" => aPurgados, "retidos" => aRetidos, "backup" => NIL }
      ENDIF
   ENDIF
   HB_SYMBOL_UNUSED( cArquivoBanco )

   FOR i := 1 TO Len( aTab )
      aCand := SqlLinhas( pDb, "SELECT " + aTab[ i ][ 2 ] + " FROM " + aTab[ i ][ 1 ] + ;
                               " WHERE excluido = 1" )
      FOR j := 1 TO Len( aCand )
         nId := aCand[ j ][ 1 ]
         /* a checagem é a mesma da exclusão lógica (V-17) */
         hRes := IntegPodeExcluir( pDb, aTab[ i ][ 1 ], nId )
         IF !hRes[ "ok" ]
            AAdd( aRetidos, { "tabela" => aTab[ i ][ 1 ], "rotulo" => aTab[ i ][ 3 ], ;
                              "id" => nId, "motivo" => hRes[ "mensagem" ] } )
            LOOP
         ENDIF
         AAdd( aPurgados, { "tabela" => aTab[ i ][ 1 ], "rotulo" => aTab[ i ][ 3 ], ;
                            "id" => nId } )
      NEXT
   NEXT

   IF lSimular
      RETURN { "ok" => .T., "mensagem" => "Simulação — nada foi apagado.", ;
               "purgados" => aPurgados, "retidos" => aRetidos, "backup" => NIL }
   ENDIF

   hRes := TransExecutar( pDb, {| | AdminPurgarTudo( pDb, aPurgados, @nTotal ) }, ;
                          "purgar os registros excluídos" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], ;
               "purgados" => {}, "retidos" => aRetidos, ;
               "backup" => hBackup[ "arquivo" ] }
   ENDIF

   LogInfo( "purga concluída", "purgados=" + hb_ntos( nTotal ) + ;
            " retidos=" + hb_ntos( Len( aRetidos ) ) + ;
            " backup=" + hBackup[ "arquivo" ] )

   RETURN { "ok" => .T., ;
            "mensagem" => hb_ntos( nTotal ) + " registro(s) purgado(s); " + ;
                          hb_ntos( Len( aRetidos ) ) + " retido(s) por dependência.", ;
            "purgados" => aPurgados, "retidos" => aRetidos, ;
            "backup" => hBackup[ "arquivo" ] }

STATIC FUNCTION AdminPurgarTudo( pDb, aPurgados, nTotal )

   LOCAL i, aTab := TabelasPurgaveis(), cChave, j

   FOR i := 1 TO Len( aPurgados )
      cChave := ""
      FOR j := 1 TO Len( aTab )
         IF aTab[ j ][ 1 ] == aPurgados[ i ][ "tabela" ]
            cChave := aTab[ j ][ 2 ]
            EXIT
         ENDIF
      NEXT
      IF Empty( cChave )
         LOOP
      ENDIF
      IF SqlExecBind( pDb, "DELETE FROM " + aPurgados[ i ][ "tabela" ] + ;
                           " WHERE " + cChave + " = ?", { aPurgados[ i ][ "id" ] } ) != 0
         RETURN "Não foi possível purgar " + aPurgados[ i ][ "tabela" ] + " " + ;
                hb_ntos( aPurgados[ i ][ "id" ] ) + ": " + SqlErro( pDb )
      ENDIF
      nTotal++
   NEXT

   RETURN NIL

/* Verificação de integridade, para o comando --verificar da aplicação. */
FUNCTION AdminVerificar( pDb )

   LOCAL aRes := {}, xInteg, aFk, aTab, i, xN

   xInteg := SqlEscalar( pDb, "PRAGMA integrity_check" )
   AAdd( aRes, { "item" => "integrity_check", "valor" => hb_ValToStr( xInteg ), ;
                 "ok" => ( hb_ValToStr( xInteg ) == "ok" ) } )

   aFk := SqlLinhas( pDb, "PRAGMA foreign_key_check" )
   AAdd( aRes, { "item" => "foreign_key_check", ;
                 "valor" => iif( Len( aFk ) == 0, "vazio", ;
                                 hb_ntos( Len( aFk ) ) + " violação(ões)" ), ;
                 "ok" => ( Len( aFk ) == 0 ) } )

   xN := SqlEscalar( pDb, "PRAGMA foreign_keys" )
   AAdd( aRes, { "item" => "foreign_keys", "valor" => hb_ValToStr( xN ), ;
                 "ok" => ( xN == 1 ) } )

   /* substr em vez de LIKE ... ESCAPE: o Harbour não interpreta "\" em string
      literal como o C, e o escape acabava com dois caracteres — inválido para
      a cláusula ESCAPE, que exige um só. A consulta falhava em silêncio. */
   aTab := SqlLinhas( pDb, "SELECT name FROM sqlite_master WHERE type='table'" + ;
      " AND name NOT LIKE 'sqlite_%' AND substr(name,1,1) <> '_'" + ;
      " ORDER BY name" )
   FOR i := 1 TO Len( aTab )
      xN := SqlEscalar( pDb, "SELECT count(*) FROM " + aTab[ i ][ 1 ] )
      AAdd( aRes, { "item" => aTab[ i ][ 1 ], "valor" => hb_ntos( xN ), "ok" => .T. } )
   NEXT

   RETURN aRes
