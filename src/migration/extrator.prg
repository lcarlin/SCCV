/*
 * extrator.prg — FASE D.1
 *
 * Extração fiel dos arquivos .DBF do legado (S.C.C.V., CA-Clipper Summer '87).
 *
 * Especificação: docs/08-MIGRACAO-DADOS.md §1 (etapa 1) e §3.
 * Decisão de arquitetura: docs/07-DEPENDENCIAS.md §5.3 — a leitura usa o RDD
 * DBFNTX, com a mesma semântica do motor original.
 *
 * O extrator NÃO normaliza, NÃO valida e NÃO descarta nada. Ele só lê.
 * Toda transformação é responsabilidade de normalizador.prg (D.2).
 *
 * LEITURA DUPLA — por que
 * -----------------------
 * Cada campo é devolvido em duas formas:
 *
 *   "valores" → o valor tipado, como o RDD o entrega (o que o Clipper via)
 *   "brutos"  → os bytes exatos do registro no arquivo
 *
 * Só o RDD não basta. Dois casos reais do acervo perdem informação se lidos
 * apenas por FieldGet():
 *
 *   CVBGRUCO.NUMMES reg. 1 contém '**' — overflow gravado pelo Clipper
 *     (docs/02-MODELO-DADOS.md §8.5, RN-026, 09/D-11). FieldGet() devolve 0.
 *   CVBGRUPO.NUMPAG está em branco nos 5 registros — nunca gravado
 *     (docs/02-MODELO-DADOS.md §8.6). FieldGet() também devolve 0.
 *
 * Sem os bytes brutos, "nunca gravado", "overflow" e "zero legítimo" viram o
 * mesmo valor, e a migração perderia silenciosamente a distinção — exatamente
 * o que o princípio de docs/08 §2 proíbe.
 *
 * Texto: devolvido em CP860, SEM conversão. Quem converte é o normalizador.
 *
 * DUAS ARMADILHAS DO LINUX (docs/07-DEPENDENCIAS.md §3.3)
 * -------------------------------------------------------
 * 1. O DBFNTX deriva o nome do arquivo de memo do nome do .DBF usando extensão
 *    em MINÚSCULAS (`.dbt`). O acervo tem `.DBT`. Num sistema de arquivos
 *    sensível a caixa isso é ENOENT, e CVBFORNE, CVFORNEC e CVREPAR — os três
 *    únicos DBFs com memo — falham ao abrir. `_SET_MFILEEXT` não resolve;
 *    `_SET_FILECASE = UPPER` (com `_SET_DIRCASE = MIXED`, para não mexer no
 *    caminho do diretório) resolve. Salvo e restaurado a cada leitura.
 *
 * 2. A abertura precisa ser COMPARTILHADA. Em modo exclusivo o RDD trava o
 *    arquivo e a leitura bruta em paralelo falha silenciosamente — hdrlen e
 *    reclen vinham zerados e todos os "brutos" viravam NIL. Somos somente
 *    leitura; compartilhado é o modo correto de qualquer forma.
 */

#include "fileio.ch"
#include "dbstruct.ch"
#include "directry.ch"
#include "set.ch"

REQUEST DBFNTX

/* handles dos arquivos abertos para leitura bruta, por caminho */
STATIC s_hArquivos := { => }

/*
 * Lê um .DBF inteiro.
 *
 * cCaminho    caminho do arquivo
 * lComLinhas  .F. lê só o cabeçalho e as contagens (padrão .T.)
 *
 * Devolve um hash; em caso de falha, "erro" traz a descrição e "linhas" vem vazio.
 */
FUNCTION ExtratorLer( cCaminho, lComLinhas )

   LOCAL hTab, aEstru, i, nOffset, cAlias, oErr
   LOCAL hLinha, hValores, hBrutos, cReg, nRec
   LOCAL bAntigo, nCaseAnt, nDirAnt

   hb_default( @lComLinhas, .T. )

   hTab := { ;
      "arquivo"   => hb_FNameNameExt( cCaminho ), ;
      "caminho"   => cCaminho, ;
      "erro"      => NIL, ;
      "estrutura" => {}, ;
      "hdrlen"    => 0, ;
      "reclen"    => 0, ;
      "registros" => 0, ;
      "ativos"    => 0, ;
      "excluidos" => 0, ;
      "memo"      => .F., ;
      "linhas"    => {} }

   IF !hb_vfExists( cCaminho )
      hTab[ "erro" ] := "arquivo inexistente"
      RETURN hTab
   ENDIF

   /* O legado é somente leitura (chmod a-w). Abrir READONLY torna a garantia
      explícita no código, não só na permissão do sistema de arquivos. */
   cAlias := "EXT_" + StrTran( Upper( hb_FNameName( cCaminho ) ), "-", "_" )

   /* Armadilha 1: extensão do memo em minúsculas. Ver cabeçalho. */
   nCaseAnt := Set( _SET_FILECASE, HB_SET_CASE_UPPER )
   nDirAnt  := Set( _SET_DIRCASE, HB_SET_CASE_MIXED )

   /* Armadilha 2: compartilhado (.T.) + somente leitura (.T.). Ver cabeçalho. */
   bAntigo := ErrorBlock( {| e | Break( e ) } )
   BEGIN SEQUENCE
      dbUseArea( .T., "DBFNTX", cCaminho, cAlias, .T., .T. )
   RECOVER USING oErr
      ErrorBlock( bAntigo )
      Set( _SET_FILECASE, nCaseAnt )
      Set( _SET_DIRCASE, nDirAnt )
      hTab[ "erro" ] := "falha ao abrir via DBFNTX: " + ;
                        iif( ValType( oErr ) == "O", oErr:description, "?" )
      RETURN hTab
   END SEQUENCE
   ErrorBlock( bAntigo )

   /* §3.3: registros marcados como excluídos são LIDOS e marcados, não descartados. */
   SET DELETED OFF

   aEstru := dbStruct()
   nOffset := 2                      // byte 1 do registro é a marca de exclusão
   FOR i := 1 TO Len( aEstru )
      AAdd( hTab[ "estrutura" ], { ;
         "nome"      => aEstru[ i ][ DBS_NAME ], ;
         "tipo"      => aEstru[ i ][ DBS_TYPE ], ;
         "tamanho"   => aEstru[ i ][ DBS_LEN ], ;
         "decimais"  => aEstru[ i ][ DBS_DEC ], ;
         "offset"    => nOffset } )
      IF aEstru[ i ][ DBS_TYPE ] == "M"
         hTab[ "memo" ] := .T.
      ENDIF
      nOffset += aEstru[ i ][ DBS_LEN ]
   NEXT

   hTab[ "registros" ] := LastRec()
   ExtLerCabecalho( cCaminho, hTab )

   /* Contagem de ativos/excluídos: sempre, mesmo sem carregar as linhas. */
   FOR nRec := 1 TO LastRec()
      dbGoto( nRec )
      IF Deleted()
         hTab[ "excluidos" ]++
      ELSE
         hTab[ "ativos" ]++
      ENDIF
   NEXT

   IF lComLinhas
      FOR nRec := 1 TO LastRec()
         dbGoto( nRec )
         cReg := ExtLerRegistroBruto( cCaminho, hTab, nRec )
         hValores := { => }
         hBrutos  := { => }
         FOR i := 1 TO Len( hTab[ "estrutura" ] )
            hValores[ hTab[ "estrutura" ][ i ][ "nome" ] ] := FieldGet( i )
            hBrutos[ hTab[ "estrutura" ][ i ][ "nome" ] ] := ;
               iif( cReg == NIL, NIL, ;
                    SubStr( cReg, hTab[ "estrutura" ][ i ][ "offset" ], ;
                            hTab[ "estrutura" ][ i ][ "tamanho" ] ) )
         NEXT
         hLinha := { ;
            "__RECNO"    => nRec, ;
            "__EXCLUIDO" => Deleted(), ;
            "valores"    => hValores, ;
            "brutos"     => hBrutos }
         AAdd( hTab[ "linhas" ], hLinha )
      NEXT
   ENDIF

   dbCloseArea()
   ExtFecharBruto( cCaminho )
   Set( _SET_FILECASE, nCaseAnt )
   Set( _SET_DIRCASE, nDirAnt )

   RETURN hTab

/*
 * Percorre um diretório e extrai todos os .DBF encontrados.
 * lComLinhas = .F. produz só o inventário (cabeçalhos e contagens).
 */
FUNCTION ExtratorInventario( cDir, lComLinhas )

   LOCAL aArqs, aRes := {}, i, cSep := hb_ps()

   hb_default( @lComLinhas, .F. )
   IF !( Right( cDir, 1 ) == cSep )   // == exato: ver SET EXACT OFF
      cDir += cSep
   ENDIF

   aArqs := Directory( cDir + "*.DBF" )
   ASort( aArqs,,, {| x, y | x[ F_NAME ] < y[ F_NAME ] } )

   FOR i := 1 TO Len( aArqs )
      AAdd( aRes, ExtratorLer( cDir + aArqs[ i ][ F_NAME ], lComLinhas ) )
   NEXT

   RETURN aRes

/* ------------------------------------------------------------------ */
/* Leitura dos bytes brutos — em paralelo ao RDD                       */
/* ------------------------------------------------------------------ */

STATIC FUNCTION ExtHandle( cCaminho )
   IF !( cCaminho $ s_hArquivos )
      s_hArquivos[ cCaminho ] := hb_vfOpen( cCaminho, FO_READ + FO_SHARED )
   ENDIF
   RETURN s_hArquivos[ cCaminho ]

STATIC PROCEDURE ExtFecharBruto( cCaminho )
   IF cCaminho $ s_hArquivos
      IF s_hArquivos[ cCaminho ] != NIL
         hb_vfClose( s_hArquivos[ cCaminho ] )
      ENDIF
      hb_HDel( s_hArquivos, cCaminho )
   ENDIF
   RETURN

/* Cabeçalho DBF: bytes 8-9 = tamanho do cabeçalho, 10-11 = tamanho do registro. */
STATIC PROCEDURE ExtLerCabecalho( cCaminho, hTab )
   LOCAL h := ExtHandle( cCaminho ), cBuf := Space( 32 )
   IF h == NIL
      RETURN
   ENDIF
   hb_vfSeek( h, 0, FS_SET )
   IF hb_vfRead( h, @cBuf, 32 ) == 32
      hTab[ "hdrlen" ] := Bin2W( SubStr( cBuf, 9, 2 ) )
      hTab[ "reclen" ] := Bin2W( SubStr( cBuf, 11, 2 ) )
   ENDIF
   RETURN

/* Registro nRec (1-based) inteiro, incluindo a marca de exclusão no byte 1. */
STATIC FUNCTION ExtLerRegistroBruto( cCaminho, hTab, nRec )
   LOCAL h := ExtHandle( cCaminho ), cBuf
   IF h == NIL .OR. hTab[ "reclen" ] == 0
      RETURN NIL
   ENDIF
   cBuf := Space( hTab[ "reclen" ] )
   hb_vfSeek( h, hTab[ "hdrlen" ] + ( nRec - 1 ) * hTab[ "reclen" ], FS_SET )
   IF hb_vfRead( h, @cBuf, hTab[ "reclen" ] ) != hTab[ "reclen" ]
      RETURN NIL
   ENDIF
   RETURN cBuf

/*
 * Lê uma variável de um arquivo .MEM do Clipper.
 *
 * Usado por CVMGRUPO.MEM → tabela `sequencia` (docs/08-MIGRACAO-DADOS.md §6.4),
 * que guarda o sequencial do grupo de consórcio.
 *
 * Mesma armadilha de caixa dos .DBT: o Harbour resolve o nome do arquivo pelo
 * SET FILECASE, e o acervo está em MAIÚSCULAS. Salvo e restaurado, como em
 * ExtratorLer().
 *
 * Devolve um hash { "valor" =>, "erro" => } — "valor" NIL se não houver.
 */
FUNCTION ExtratorLerMem( cCaminho, cVariavel )

   LOCAL hRes := { "valor" => NIL, "erro" => NIL }
   LOCAL nCaseAnt, nDirAnt, nRc

   IF !hb_vfExists( cCaminho )
      hRes[ "erro" ] := "arquivo inexistente"
      RETURN hRes
   ENDIF

   nCaseAnt := Set( _SET_FILECASE, HB_SET_CASE_UPPER )
   nDirAnt  := Set( _SET_DIRCASE, HB_SET_CASE_MIXED )
   nRc := __mvRestore( cCaminho, .T. )        // .T. = additive
   Set( _SET_FILECASE, nCaseAnt )
   Set( _SET_DIRCASE, nDirAnt )

   IF nRc != 0
      hRes[ "erro" ] := "falha ao restaurar o .MEM (código " + hb_ntos( nRc ) + ")"
      RETURN hRes
   ENDIF

   IF !__mvExist( cVariavel )
      hRes[ "erro" ] := "variável " + cVariavel + " não encontrada no .MEM"
      RETURN hRes
   ENDIF

   hRes[ "valor" ] := __mvGet( cVariavel )

   RETURN hRes
