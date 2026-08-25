/*
 * modelo.prg — FASE G, onda 2
 *
 * Motor genérico de cadastro, dirigido por DESCRITOR. Todo o SQL das entidades
 * de cadastro vive aqui (docs/10 §2: "um arquivo por entidade; SQL vive só
 * aqui" — o SQL ficou num só, e os arquivos por entidade descrevem os campos).
 *
 * POR QUE GENÉRICO
 * ----------------
 * O legado tinha CVMTCLI, CVMTFUNC, CVMTFOR e CVMTFRO como quase-cópias uma da
 * outra. É dessa duplicação que vêm defeitos como D-01: a mesma regra evolui
 * num arquivo e não nos outros, e ninguém percebe porque não há nada
 * declarando que elas deveriam ser iguais. Aqui a estrutura é dado; o que
 * difere entre entidades é o descritor, e o que é igual é igual de verdade.
 *
 * O DESCRITOR
 * -----------
 *   entidade   nome curto, usado pelo lookup e pela integridade referencial
 *   tabela     tabela real (a gravação usa a tabela; a leitura usa a view)
 *   view       v_<tabela>, que aplica excluido = 0 (exclusão lógica)
 *   chave      coluna da chave primária
 *   titulo     para o cabeçalho da tela
 *   campos     array de descritores de campo (ver ModeloCampo)
 *   defaults   hash de colunas preenchidas pelo sistema, não pelo operador
 */

/*
 * Um campo do cadastro.
 *
 * cOriginal / cValido: colunas irmãs preenchidas automaticamente. O legado
 * gravava a máscara junto com o dado (V-03); aqui a coluna guarda só o valor
 * normalizado e a coluna *_original preserva o que o operador digitou, para
 * auditoria. É o mesmo par que a migração usa.
 */
FUNCTION ModeloCampo( cNome, cRotulo, cTipo, nTamanho, bValidador, cOriginal, cValido )
   RETURN { "nome" => cNome, "rotulo" => cRotulo, "tipo" => cTipo, ;
            "tamanho" => nTamanho, "validador" => bValidador, ;
            "original" => cOriginal, "valido" => cValido }

/* Registro por chave, lido da VIEW: excluído não é encontrado. */
FUNCTION ModeloObter( pDb, hDesc, nChave )

   LOCAL aCols := ModeloColunas( hDesc ), aL, hReg, i

   aL := SqlLinhasBind( pDb, "SELECT " + ModeloListaColunas( aCols ) + ;
      " FROM " + hDesc[ "view" ] + " WHERE " + hDesc[ "chave" ] + " = ?", { nChave } )
   IF Len( aL ) == 0
      RETURN NIL
   ENDIF

   hReg := { => }
   FOR i := 1 TO Len( aCols )
      hReg[ aCols[ i ] ] := aL[ 1 ][ i ]
   NEXT

   RETURN hReg

FUNCTION ModeloExiste( pDb, hDesc, nChave )
   RETURN ModeloObter( pDb, hDesc, nChave ) != NIL

/*
 * Próximo código livre. O legado usava MAX()+1 sobre o arquivo com SET DELETED
 * ON, o que reciclava códigos de registros excluídos e produziu a colisão de
 * numeração de RN-015. Aqui o MAX é sobre a TABELA, incluindo os excluídos
 * logicamente: um código já usado não volta a ser oferecido.
 */
FUNCTION ModeloProximoCodigo( pDb, hDesc )

   LOCAL xN := SqlEscalar( pDb, "SELECT IFNULL(MAX(" + hDesc[ "chave" ] + "),0) + 1" + ;
                                " FROM " + hDesc[ "tabela" ] )

   RETURN iif( xN == NIL, 1, xN )

/* Lista para a grade de consulta: chave, primeiro campo de texto e mais dois. */
FUNCTION ModeloListar( pDb, hDesc, cFiltro )

   LOCAL aCols := ModeloColunasGrade( hDesc ), cSql, aParams := {}

   cSql := "SELECT " + ModeloListaColunas( aCols ) + " FROM " + hDesc[ "view" ]
   IF !Empty( cFiltro )
      cSql += " WHERE " + hDesc[ "campos" ][ 1 ][ "nome" ] + " LIKE ?"
      AAdd( aParams, "%" + cFiltro + "%" )
   ENDIF
   cSql += " ORDER BY " + hDesc[ "chave" ]

   RETURN SqlLinhasBind( pDb, cSql, aParams )

/*
 * Grava. lNovo = .T. insere, .F. atualiza.
 * Devolve { ok, mensagem, validacao }.
 *
 * A validação roda ANTES de qualquer escrita, e a gravação inteira acontece
 * numa transação: um cadastro não pode ficar meio gravado.
 */
FUNCTION ModeloGravar( pDb, hDesc, hValores, lNovo )

   LOCAL hV, hRes, cSql, aParams := {}, aSet := {}, i, hC, xVal

   hV := ModeloValidar( pDb, hDesc, hValores, lNovo )
   IF !ValOk( hV )
      RETURN { "ok" => .F., "mensagem" => ValTexto( hV ), "validacao" => hV }
   ENDIF

   /* colunas do operador */
   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hC := hDesc[ "campos" ][ i ]
      xVal := hValores[ hC[ "nome" ] ]
      ModeloAcrescentar( aSet, aParams, hC[ "nome" ], ModeloNulo( xVal ) )
      IF hC[ "original" ] != NIL
         ModeloAcrescentar( aSet, aParams, hC[ "original" ], ;
            ModeloNulo( hValores[ hC[ "nome" ] + "__digitado" ] ) )
      ENDIF
      IF hC[ "valido" ] != NIL
         ModeloAcrescentar( aSet, aParams, hC[ "valido" ], ;
            iif( ModeloNulo( xVal ) == NIL, 0, 1 ) )
      ENDIF
   NEXT

   /* colunas do sistema */
   IF lNovo .AND. "defaults" $ hDesc
      FOR i := 1 TO Len( hb_HKeys( hDesc[ "defaults" ] ) )
         ModeloAcrescentar( aSet, aParams, hb_HKeys( hDesc[ "defaults" ] )[ i ], ;
            Eval( hDesc[ "defaults" ][ hb_HKeys( hDesc[ "defaults" ] )[ i ] ] ) )
      NEXT
   ENDIF

   IF lNovo
      ModeloAcrescentar( aSet, aParams, hDesc[ "chave" ], hValores[ hDesc[ "chave" ] ] )
      cSql := "INSERT INTO " + hDesc[ "tabela" ] + " (" + ;
              ModeloListaColunas( aSet ) + ") VALUES (" + ;
              ModeloInterrogacoes( Len( aSet ) ) + ")"
   ELSE
      cSql := "UPDATE " + hDesc[ "tabela" ] + " SET " + ModeloListaSet( aSet ) + ;
              " WHERE " + hDesc[ "chave" ] + " = ?"
      AAdd( aParams, hValores[ hDesc[ "chave" ] ] )
   ENDIF

   hRes := TransExecutar( pDb, {| | SqlExecBind( pDb, cSql, aParams ) }, ;
                          iif( lNovo, "incluir o registro", "alterar o registro" ) )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ], "validacao" => hV }
   ENDIF
   IF hRes[ "valor" ] != 0
      RETURN { "ok" => .F., ;
               "mensagem" => "Não foi possível gravar: " + SqlErro( pDb ), ;
               "validacao" => hV }
   ENDIF

   LogInfo( iif( lNovo, "incluído", "alterado" ) + " em " + hDesc[ "tabela" ], ;
            hDesc[ "chave" ] + "=" + hb_ValToStr( hValores[ hDesc[ "chave" ] ] ) )

   RETURN { "ok" => .T., "mensagem" => NIL, "validacao" => hV }

/*
 * Exclusão LÓGICA (excluido = 1), como no restante do sistema.
 *
 * O legado excluía fisicamente com PACK em SAIDA(), sem verificar dependências
 * (02 §8.2). Aqui a integridade referencial é conferida antes: as FKs do schema
 * não bastam, porque marcar excluido = 1 não é DELETE e o SQLite não tem o que
 * barrar.
 */
FUNCTION ModeloExcluir( pDb, hDesc, nChave )

   LOCAL hInt, hRes

   IF !ModeloExiste( pDb, hDesc, nChave )
      RETURN { "ok" => .F., "mensagem" => "Registro não encontrado." }
   ENDIF

   hInt := IntegPodeExcluir( pDb, hDesc[ "entidade" ], nChave )
   IF !hInt[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hInt[ "mensagem" ] }
   ENDIF

   hRes := TransExecutar( pDb, ;
      {| | SqlExecBind( pDb, "UPDATE " + hDesc[ "tabela" ] + " SET excluido = 1" + ;
                             " WHERE " + hDesc[ "chave" ] + " = ?", { nChave } ) }, ;
      "excluir o registro" )
   IF !hRes[ "ok" ]
      RETURN { "ok" => .F., "mensagem" => hRes[ "mensagem" ] }
   ENDIF

   LogInfo( "excluído de " + hDesc[ "tabela" ], ;
            hDesc[ "chave" ] + "=" + hb_ntos( nChave ) )

   RETURN { "ok" => .T., "mensagem" => NIL }

/*
 * Valida o registro inteiro: os validadores de cada campo, mais as regras que
 * só existem no conjunto (chave duplicada, CPF já usado por outro cliente).
 */
FUNCTION ModeloValidar( pDb, hDesc, hValores, lNovo )

   LOCAL hV := ValNovo(), i, hC, hR, xChave

   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hC := hDesc[ "campos" ][ i ]
      IF hC[ "validador" ] == NIL
         LOOP
      ENDIF
      hR := Eval( hC[ "validador" ], hValores[ hC[ "nome" ] ] )
      IF hR == NIL
         LOOP
      ENDIF
      IF !hR[ "ok" ]
         ValErro( hV, hC[ "nome" ], hC[ "rotulo" ] + ": " + hR[ "mensagem" ] )
      ELSE
         /* guarda o digitado antes de normalizar, para a coluna *_original */
         IF hC[ "original" ] != NIL
            hValores[ hC[ "nome" ] + "__digitado" ] := hValores[ hC[ "nome" ] ]
         ENDIF
         hValores[ hC[ "nome" ] ] := hR[ "valor" ]
      ENDIF
   NEXT

   xChave := hValores[ hDesc[ "chave" ] ]
   hR := ValCodigo( xChave, "Código" )
   IF !hR[ "ok" ]
      ValErro( hV, hDesc[ "chave" ], hR[ "mensagem" ] )
   ELSE
      hValores[ hDesc[ "chave" ] ] := hR[ "valor" ]
      IF lNovo .AND. ModeloChaveEmUso( pDb, hDesc, hR[ "valor" ] )
         ValErro( hV, hDesc[ "chave" ], ;
            "O código " + hb_ntos( hR[ "valor" ] ) + " já está em uso." )
      ENDIF
   ENDIF

   IF "validador_extra" $ hDesc .AND. hDesc[ "validador_extra" ] != NIL
      Eval( hDesc[ "validador_extra" ], pDb, hValores, hV, lNovo )
   ENDIF

   RETURN hV

/*
 * Chave em uso: sobre a TABELA, não a view. Um código de registro excluído
 * continua ocupado — reaproveitá-lo confundiria o histórico, que é o que
 * RN-015 fez no legado.
 */
STATIC FUNCTION ModeloChaveEmUso( pDb, hDesc, nChave )

   LOCAL aL := SqlLinhasBind( pDb, "SELECT 1 FROM " + hDesc[ "tabela" ] + ;
      " WHERE " + hDesc[ "chave" ] + " = ?", { nChave } )

   RETURN Len( aL ) > 0

/* ------------------------------------------------------------------ */

STATIC PROCEDURE ModeloAcrescentar( aSet, aParams, cColuna, xValor )
   AAdd( aSet, cColuna )
   AAdd( aParams, xValor )
   RETURN

/* String vazia vira NULL: o schema distingue "não informado" de "vazio". */
STATIC FUNCTION ModeloNulo( xVal )
   IF xVal == NIL
      RETURN NIL
   ENDIF
   IF ValType( xVal ) == "C" .AND. Empty( AllTrim( xVal ) )
      RETURN NIL
   ENDIF
   RETURN xVal

FUNCTION ModeloColunas( hDesc )

   LOCAL aC := { hDesc[ "chave" ] }, i, hCampo

   FOR i := 1 TO Len( hDesc[ "campos" ] )
      hCampo := hDesc[ "campos" ][ i ]
      AAdd( aC, hCampo[ "nome" ] )
      IF hCampo[ "original" ] != NIL
         AAdd( aC, hCampo[ "original" ] )
      ENDIF
   NEXT

   RETURN aC

STATIC FUNCTION ModeloColunasGrade( hDesc )

   LOCAL aC := { hDesc[ "chave" ] }, i

   FOR i := 1 TO Min( 3, Len( hDesc[ "campos" ] ) )
      AAdd( aC, hDesc[ "campos" ][ i ][ "nome" ] )
   NEXT

   RETURN aC

STATIC FUNCTION ModeloListaColunas( aCols )

   LOCAL cTxt := "", i

   FOR i := 1 TO Len( aCols )
      cTxt += iif( i > 1, ", ", "" ) + aCols[ i ]
   NEXT

   RETURN cTxt

STATIC FUNCTION ModeloListaSet( aCols )

   LOCAL cTxt := "", i

   FOR i := 1 TO Len( aCols )
      cTxt += iif( i > 1, ", ", "" ) + aCols[ i ] + " = ?"
   NEXT

   RETURN cTxt

STATIC FUNCTION ModeloInterrogacoes( n )

   LOCAL cTxt := "", i

   FOR i := 1 TO n
      cTxt += iif( i > 1, ",", "" ) + "?"
   NEXT

   RETURN cTxt
