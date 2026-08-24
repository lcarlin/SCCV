/*
 * testa_infra.prg — critério de aceite da FASE F
 *
 *   F.2  conexao.prg + sql.prg   abre, PRAGMAs, consulta parametrizada, fecha
 *   F.3  transacao.prg           rollback interno NÃO derruba a transação externa
 *   F.4  erro.prg                mensagem ao usuário sem stack trace, contexto no log
 *   F.5  log.prg                 níveis, rotação, caminho configurável
 *   F.6  config.prg              precedência de 5 níveis, caminhos absolutos
 */

#require "hbsqlit3"

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   ? "FASE F — aceite da infraestrutura"
   ?
   TestaConfig()
   TestaLog()
   TestaErro()
   TestaConexao()
   TestaTransacao()
   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "FASE F ACEITA", "FASE F REPROVADA" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

/* ------------------------------------------------------------------ */

STATIC PROCEDURE TestaConfig()

   LOCAL cDir := hb_DirTemp(), cArq := cDir + "sccv-teste.conf", hC, cCwd

   ? "== F.6 — configuração =="

   hC := ConfigCarregar()
   Vale( "sem arquivo, usa embutido", ConfigOrigem(), "(embutido)" )
   Vale( "banco padrão é XDG", ;
         At( ".local/share/sccv/sccv.db", hC[ "banco" ] ) > 0 .OR. ;
         At( "sccv/sccv.db", hC[ "banco" ] ) > 0, .T. )
   Vale( "caminho do banco é absoluto", Left( hC[ "banco" ], 1 ), hb_ps() )
   Vale( "caminho do log é absoluto", Left( hC[ "log" ], 1 ), hb_ps() )

   /* nível 1: --config vence tudo */
   hb_MemoWrit( cArq, "# teste" + hb_eol() + ;
      "banco = /tmp/teste-sccv.db" + hb_eol() + ;
      "log_nivel = DEBUG" + hb_eol() + ;
      "log_max_bytes = 2048" + hb_eol() )
   hC := ConfigCarregar( cArq )
   Vale( "--config vence", ConfigOrigem(), cArq )
   Vale( "valor lido do arquivo", hC[ "banco" ], "/tmp/teste-sccv.db" )
   Vale( "nível lido do arquivo", hC[ "log_nivel" ], "DEBUG" )
   Vale( "numérico continua numérico", ValType( hC[ "log_max_bytes" ] ), "N" )
   Vale( "e vale 2048", hC[ "log_max_bytes" ], 2048 )
   Vale( "chave ausente cai no embutido", ValType( hC[ "backup_dir" ] ), "C" )

   /* nível 2: $SCCV_CONFIG */
   hb_SetEnv( "SCCV_CONFIG", cArq )
   ConfigCarregar()
   Vale( "$SCCV_CONFIG é usado quando não há --config", ConfigOrigem(), cArq )
   hb_SetEnv( "SCCV_CONFIG", NIL )

   /* --config inexistente não pode virar silêncio */
   ConfigCarregar( cDir + "nao-existe.conf" )
   Vale( "--config inexistente cai no embutido (e main avisa)", ;
         ConfigOrigem(), "(embutido)" )

   /* caminho relativo vira absoluto a partir do cwd da carga */
   hb_MemoWrit( cArq, "banco = relativo/sccv.db" + hb_eol() )
   cCwd := hb_cwd()
   hC := ConfigCarregar( cArq )
   Vale( "relativo vira absoluto", Left( hC[ "banco" ], 1 ), hb_ps() )
   Vale( "e é relativo ao cwd da carga", At( "relativo", hC[ "banco" ] ) > 0, .T. )
   HB_SYMBOL_UNUSED( cCwd )
   FErase( cArq )

   RETURN

STATIC PROCEDURE TestaLog()

   LOCAL cLog := hb_DirTemp() + "teste-sccv.log", cTxt

   ? "== F.5 — log =="

   FErase( cLog ) ; FErase( cLog + ".1" )
   LogIniciar( cLog, "INFO", 1048576 )
   Vale( "caminho configurável", LogArquivo(), cLog )
   Vale( "nível ativo", LogNivel(), "INFO" )

   LogDebug( "isto nao deve aparecer" )
   LogInfo( "operação concluída", "registros=22" )
   LogErro( "falhou", "genCode=21" )
   cTxt := hb_MemoRead( cLog )
   Vale( "DEBUG filtrado pelo nível", At( "isto nao deve aparecer", cTxt ), 0 )
   Vale( "INFO registrado", At( "operação concluída", cTxt ) > 0, .T. )
   Vale( "contexto técnico junto", At( "registros=22", cTxt ) > 0, .T. )
   Vale( "ERRO registrado", At( "[ERRO ]", cTxt ) > 0, .T. )
   Vale( "linha tem data ISO", At( hb_TToC( hb_DateTime(), "YYYY-MM-DD", "" ), cTxt ) > 0, .T. )

   LogIniciar( cLog, "DEBUG", 1048576 )
   LogDebug( "agora aparece" )
   Vale( "DEBUG passa quando o nível abaixa", ;
         At( "agora aparece", hb_MemoRead( cLog ) ) > 0, .T. )

   /* rotação */
   FErase( cLog ) ; FErase( cLog + ".1" )
   LogIniciar( cLog, "INFO", 200 )
   LogInfo( Replicate( "x", 300 ) )
   LogInfo( "depois da rotação" )
   Vale( "rotacionou para .1", hb_vfExists( cLog + ".1" ), .T. )
   Vale( "novo log tem a linha seguinte", ;
         At( "depois da rotação", hb_MemoRead( cLog ) ) > 0, .T. )

   /* log inacessível não pode derrubar a aplicação */
   LogIniciar( "/proc/nao/existe/sccv.log", "INFO", 1024 )
   LogInfo( "isto vai falhar em silêncio" )
   Vale( "log inacessível não interrompe a execução", .T., .T. )
   LogIniciar( cLog, "INFO", 1048576 )

   RETURN

STATIC PROCEDURE TestaErro()

   LOCAL hR, cLog := hb_DirTemp() + "teste-erro.log", cTxt, lLimpou := .F.

   ? "== F.4 — tratamento de erros =="

   FErase( cLog )
   LogIniciar( cLog, "DEBUG", 1048576 )

   hR := ErroProteger( {| | 2 + 2 }, "somar" )
   Vale( "sucesso devolve ok", hR[ "ok" ], .T. )
   Vale( "e o valor do bloco", hR[ "valor" ], 4 )
   Vale( "sem mensagem quando dá certo", hR[ "mensagem" ], NIL )

   /* macro: a função só é resolvida em tempo de execução, que é o caso real —
      escrita direto no fonte, ela seria erro de link, não erro tratável */
   hR := ErroProteger( &( "{|| FuncaoQueNaoExiste() }" ), "gravar o cliente" )
   Vale( "falha devolve ok = .F.", hR[ "ok" ], .F. )
   Vale( "mensagem cita a operação em português", ;
         At( "gravar o cliente", hR[ "mensagem" ] ) > 0, .T. )
   Vale( "mensagem NÃO traz nome de função", ;
         At( "FUNCAOQUENAOEXISTE", Upper( hR[ "mensagem" ] ) ), 0 )
   Vale( "mensagem NÃO traz número de linha", ;
         At( "(", hR[ "mensagem" ] ), 0 )
   Vale( "contexto técnico traz genCode", At( "genCode=", hR[ "tecnico" ] ) > 0, .T. )
   Vale( "contexto técnico traz a pilha", At( "pilha=", hR[ "tecnico" ] ) > 0, .T. )

   cTxt := hb_MemoRead( cLog )
   Vale( "erro foi para o log", At( "gravar o cliente", cTxt ) > 0, .T. )
   Vale( "e o log tem o contexto técnico", At( "genCode=", cTxt ) > 0, .T. )

   /* a limpeza (rollback) roda antes de a mensagem subir */
   hR := ErroProteger( &( "{|| FuncaoQueNaoExiste() }" ), "gravar", ;
                       {| e | HB_SYMBOL_UNUSED( e ), lLimpou := .T. } )
   Vale( "bloco de limpeza executado na falha", lLimpou, .T. )

   /* erro dentro da limpeza não pode mascarar o erro original */
   hR := ErroProteger( &( "{|| FuncaoQueNaoExiste() }" ), "gravar", ;
                       {| e | HB_SYMBOL_UNUSED( e ), Eval( &( "{|| OutraQueNaoExiste() }" ) ) } )
   Vale( "falha na limpeza não mascara o erro original", hR[ "ok" ], .F. )
   Vale( "e a mensagem original sobrevive", At( "gravar", hR[ "mensagem" ] ) > 0, .T. )

   /* o programa continua vivo depois de tudo isso — é o ponto do §18 */
   Vale( "execução continua após os erros", 1 + 1, 2 )

   RETURN

STATIC PROCEDURE TestaConexao()

   LOCAL cDb := hb_DirTemp() + "teste-conexao.db", hC, pDb, aL

   ? "== F.2 — conexão e SQL =="

   FErase( cDb )
   hC := ConexaoAbrir( cDb )
   Vale( "recusa banco inexistente por padrão", hC[ "ok" ], .F. )
   Vale( "com mensagem ao usuário", At( "não foi encontrado", hC[ "mensagem" ] ) > 0, .T. )

   hC := ConexaoAbrir( cDb, .T. )
   Vale( "cria quando pedido", hC[ "ok" ], .T. )
   pDb := hC[ "db" ]
   Vale( "foreign_keys ligado", SqlEscalar( pDb, "PRAGMA foreign_keys" ), 1 )
   Vale( "busy_timeout definido", SqlEscalar( pDb, "PRAGMA busy_timeout" ) > 0, .T. )
   Vale( "ConexaoDb devolve a conexão", ConexaoDb() != NIL, .T. )

   SqlExec( pDb, "CREATE TABLE t (id INTEGER PRIMARY KEY, nome TEXT) STRICT" )
   Vale( "consulta parametrizada grava", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", ;
                      { 1, "aspas ' e ; ponto-e-vírgula" } ), 0 )
   Vale( "e o valor volta íntegro", ;
         SqlEscalar( pDb, "SELECT nome FROM t WHERE id = 1" ), ;
         "aspas ' e ; ponto-e-vírgula" )
   Vale( "NULL é ligado como NULL", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", { 2, NIL } ), 0 )
   Vale( "e volta como NIL", SqlEscalar( pDb, "SELECT nome FROM t WHERE id = 2" ), NIL )
   Vale( "STRICT rejeita tipo errado", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", { "x", "y" } ) != 0, .T. )
   /* o defeito corrigido na FASE D: lido depois do finalize, sqlite3_errmsg()
      devolve "not an error" e o diagnóstico se perde */
   Vale( "mensagem do erro sobrevive ao finalize", ;
         !Empty( SqlErro( pDb ) ) .AND. !( SqlErro( pDb ) == "not an error" ), .T. )
   Vale( "e é a mensagem do SQLite", SqlErro( pDb ), "datatype mismatch" )
   /* nuance do STRICT: em coluna TEXT, INTEGER e REAL são convertidos, não
      rejeitados — só o inverso é erro. Documentado aqui para quem for mexer. */
   Vale( "STRICT converte número para TEXT", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", { 3, 5 } ), 0 )
   Vale( "e o valor vira texto", SqlEscalar( pDb, "SELECT nome FROM t WHERE id = 3" ), "5" )

   /* tipos que o ramo OTHERWISE antigo mandava para bind_text e derrubavam o
      processo com "Argument error: SQLITE3_BIND_TEXT (Quit)" */
   Vale( "data é gravada como texto ISO", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", ;
                      { 4, hb_SToD( "19940630" ) } ), 0 )
   Vale( "e no formato do schema", ;
         SqlEscalar( pDb, "SELECT nome FROM t WHERE id = 4" ), "1994-06-30" )
   Vale( "data vazia vira NULL", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", { 5, hb_SToD( "" ) } ), 0 )
   Vale( "e é NULL mesmo", SqlEscalar( pDb, "SELECT nome FROM t WHERE id = 5" ), NIL )
   Vale( "tipo não gravável é recusado, não derruba o processo", ;
         SqlExecBind( pDb, "INSERT INTO t (id, nome) VALUES (?,?)", { 6, { 1, 2 } } ) != 0, .T. )
   Vale( "com mensagem dizendo qual parâmetro", ;
         At( "parâmetro 2", SqlErro( pDb ) ) > 0, .T. )
   Vale( "e a execução continua", 1 + 1, 2 )

   aL := SqlLinhas( pDb, "SELECT id, nome FROM t ORDER BY id" )
   Vale( "SqlLinhas devolve as linhas", Len( aL ), 5 )

   ConexaoFechar()
   Vale( "fechar limpa a conexão", ConexaoDb(), NIL )

   RETURN

STATIC PROCEDURE TestaTransacao()

   LOCAL cDb := hb_DirTemp() + "teste-trans.db", hC, pDb, hR

   ? "== F.3 — transações aninhadas (savepoints) =="

   FErase( cDb )
   hC  := ConexaoAbrir( cDb, .T. )
   pDb := hC[ "db" ]
   SqlExec( pDb, "CREATE TABLE t (id INTEGER PRIMARY KEY) STRICT" )

   Vale( "nível começa em zero", TransNivel(), 0 )

   /* o critério de aceite de F.3, literal */
   TransIniciar( pDb )
   Vale( "nível 1 após iniciar", TransNivel(), 1 )
   SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", { 1 } )

   TransIniciar( pDb )
   Vale( "nível 2 aninhado", TransNivel(), 2 )
   SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", { 2 } )
   TransDesfazer( pDb )
   Vale( "voltou ao nível 1", TransNivel(), 1 )
   Vale( "rollback interno desfez só o interno", ;
         SqlEscalar( pDb, "SELECT count(*) FROM t WHERE id = 2" ), 0 )
   Vale( "a transação externa continua viva", ;
         SqlEscalar( pDb, "SELECT count(*) FROM t WHERE id = 1" ), 1 )

   /* mas a externa fica marcada: confirmar como se estivesse completa seria mentira */
   Vale( "externa marcada como condenada", TransCondenada(), .T. )
   Vale( "confirmar devolve falso", TransConfirmar( pDb ), .F. )
   Vale( "e desfaz tudo", SqlEscalar( pDb, "SELECT count(*) FROM t" ), 0 )
   Vale( "nível zerado", TransNivel(), 0 )

   /* caminho feliz aninhado */
   TransIniciar( pDb )
   SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", { 10 } )
   TransIniciar( pDb )
   SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", { 11 } )
   Vale( "interna confirma", TransConfirmar( pDb ), .T. )
   Vale( "externa confirma", TransConfirmar( pDb ), .T. )
   Vale( "os dois registros ficaram", SqlEscalar( pDb, "SELECT count(*) FROM t" ), 2 )

   /* TransExecutar: erro no bloco desfaz sozinho */
   hR := TransExecutar( pDb, {| | SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", ;
                                               { 99 } ), ;
                                  Eval( &( "{|| FuncaoInexistente() }" ) ) }, "gravar" )
   Vale( "TransExecutar relata a falha", hR[ "ok" ], .F. )
   Vale( "e desfez o insert", SqlEscalar( pDb, "SELECT count(*) FROM t WHERE id = 99" ), 0 )
   Vale( "sem transação pendente", TransNivel(), 0 )

   hR := TransExecutar( pDb, {| | SqlExecBind( pDb, "INSERT INTO t (id) VALUES (?)", ;
                                               { 20 } ) }, "gravar" )
   Vale( "TransExecutar confirma no sucesso", hR[ "ok" ], .T. )
   Vale( "e o registro ficou", SqlEscalar( pDb, "SELECT count(*) FROM t WHERE id = 20" ), 1 )

   ConexaoFechar()

   RETURN

STATIC PROCEDURE Vale( cDesc, xObtido, xEsperado )
   LOCAL lOk := ( ValType( xObtido ) == ValType( xEsperado ) .AND. ;
                  hb_ValToExp( xObtido ) == hb_ValToExp( xEsperado ) )
   IF lOk
      s_nOk++
      ? "   ok   " + cDesc
   ELSE
      s_nFalhas++
      ? "   FALHA " + cDesc
      ? "         esperado: " + hb_ValToExp( xEsperado )
      ? "         obtido..: " + hb_ValToExp( xObtido )
   ENDIF
   RETURN
