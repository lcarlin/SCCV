/*
 * testa_extrator.prg — critério de aceite da FASE D.1
 *
 * "Lê os 23 DBFs; contagens batem com a análise da FASE A."
 *   — docs/10-PLANO-IMPLEMENTACAO.md, item D.1
 *
 * A tabela de referência abaixo é a da FASE A (docs/00-INVENTARIO.md §3 e
 * docs/02-MODELO-DADOS.md §8.1), levantada com tools/dump-dbf.py — um parser
 * Python independente. Conferir o RDD DBFNTX contra ela é uma verificação
 * cruzada real: dois leitores distintos sobre os mesmos bytes.
 *
 * Uso: ./testa_extrator [<dir do legado>]     (padrão: ./legacy)
 * Sai com 0 se tudo confere, 1 caso contrário.
 */

#include "directry.ch"

REQUEST DBFNTX

PROCEDURE Main( cDir )

   LOCAL aRef, aRes, i, j, hTab, aAch, nFalhas := 0, nOk := 0
   LOCAL nAtivos := 0, nExcl := 0, cNome, lAchou
   LOCAL nRefAtivos := 0, nRefExcl := 0

   hb_default( @cDir, "legacy" )

   /* arquivo, ativos, excluídos, campos */
   aRef := { ;
      { "CVALMOX.DBF" ,  1, 0,  7 }, ;
      { "CVBALMOX.DBF",  4, 0,  7 }, ;
      { "CVBCLIEN.DBF", 22, 0, 12 }, ;
      { "CVBFORNE.DBF",  3, 0, 11 }, ;
      { "CVBFROTA.DBF",  5, 0,  7 }, ;
      { "CVBFUNC.DBF" , 10, 0,  8 }, ;
      { "CVBGRUCO.DBF",  3, 0, 14 }, ;
      { "CVBGRUPO.DBF",  2, 3, 12 }, ;
      { "CVBPECAS.DBF",  4, 0,  7 }, ;
      { "CVBPEDID.DBF",  0, 0,  4 }, ;
      { "CVBPENT.DBF" , 23, 0,  9 }, ;
      { "CVCLIENT.DBF", 12, 0, 12 }, ;
      { "CVFORNEC.DBF",  0, 0,  7 }, ;
      { "CVFROTA.DBF" ,  0, 0,  6 }, ;
      { "CVFUNC.DBF"  ,  0, 0,  7 }, ;
      { "CVGRUCON.DBF",  0, 0, 10 }, ;
      { "CVGRUPO.DBF" ,  0, 0,  9 }, ;
      { "CVPECAS.DBF" , 75, 0,  7 }, ;
      { "CVPRONVE.DBF",  0, 0,  5 }, ;
      { "CVREPAR.DBF" ,  4, 0,  7 }, ;
      { "CVVCAR.DBF"  ,  4, 0,  2 }, ;
      { "CVVENPEC.DBF",  0, 0,  6 }, ;
      { "CVVPEC.DBF"  , 10, 0,  2 } }

   ? "FASE D.1 — aceite do extrator"
   ? "diretório: " + cDir
   ?

   aRes := ExtratorInventario( cDir, .F. )

   ? "== 1. arquivos encontrados =="
   ? "   esperado ....: " + hb_ntos( Len( aRef ) ) + " arquivos .DBF"
   ? "   encontrado ..: " + hb_ntos( Len( aRes ) )
   IF Len( aRes ) != Len( aRef )
      ? "   FALHA: quantidade de arquivos diverge"
      nFalhas++
   ELSE
      ? "   OK"
   ENDIF
   ?

   ? "== 2. contagens por arquivo (RDD DBFNTX x FASE A) =="
   ? "   arquivo         ativos  excl  campos   resultado"
   FOR i := 1 TO Len( aRef )
      cNome  := aRef[ i ][ 1 ]
      lAchou := .F.
      FOR j := 1 TO Len( aRes )
         IF aRes[ j ][ "arquivo" ] == cNome
            lAchou := .T.
            hTab := aRes[ j ]
            EXIT
         ENDIF
      NEXT
      nRefAtivos += aRef[ i ][ 2 ]
      nRefExcl   += aRef[ i ][ 3 ]
      IF !lAchou
         ? "   " + PadR( cNome, 15 ) + "                        AUSENTE"
         nFalhas++
         LOOP
      ENDIF
      IF hTab[ "erro" ] != NIL
         ? "   " + PadR( cNome, 15 ) + "                        ERRO: " + hTab[ "erro" ]
         nFalhas++
         LOOP
      ENDIF
      aAch := { hTab[ "ativos" ], hTab[ "excluidos" ], Len( hTab[ "estrutura" ] ) }
      nAtivos += aAch[ 1 ]
      nExcl   += aAch[ 2 ]
      IF aAch[ 1 ] == aRef[ i ][ 2 ] .AND. aAch[ 2 ] == aRef[ i ][ 3 ] .AND. ;
         aAch[ 3 ] == aRef[ i ][ 4 ]
         ? "   " + PadR( cNome, 15 ) + Str( aAch[ 1 ], 5 ) + Str( aAch[ 2 ], 6 ) + ;
           Str( aAch[ 3 ], 7 ) + "   OK"
         nOk++
      ELSE
         ? "   " + PadR( cNome, 15 ) + Str( aAch[ 1 ], 5 ) + Str( aAch[ 2 ], 6 ) + ;
           Str( aAch[ 3 ], 7 ) + "   FALHA — esperado " + ;
           hb_ntos( aRef[ i ][ 2 ] ) + "/" + hb_ntos( aRef[ i ][ 3 ] ) + "/" + ;
           hb_ntos( aRef[ i ][ 4 ] )
         nFalhas++
      ENDIF
   NEXT
   ?
   ? "   totais ......: " + hb_ntos( nAtivos ) + " ativos, " + hb_ntos( nExcl ) + " excluídos"
   ? "   referência ..: " + hb_ntos( nRefAtivos ) + " ativos, " + hb_ntos( nRefExcl ) + " excluídos"
   ? "   " + iif( nAtivos == nRefAtivos .AND. nExcl == nRefExcl, "OK", "FALHA" )
   ?

   nFalhas += TestaLeituraDupla( cDir )
   nFalhas += TestaMem( cDir )

   ? "== 4. resultado =="
   ? "   arquivos conferidos ..: " + hb_ntos( nOk ) + "/" + hb_ntos( Len( aRef ) )
   ? "   falhas ...............: " + hb_ntos( nFalhas )
   ? "   " + iif( nFalhas == 0, "D.1 ACEITA", "D.1 REPROVADA" )

   ErrorLevel( iif( nFalhas == 0, 0, 1 ) )
   RETURN

/* CVMGRUPO.MEM — sequencial do grupo de consórcio (08 §6.4). */
STATIC FUNCTION TestaMem( cDir )

   LOCAL hRes, nFalhas := 0

   ? "== 3b. CVMGRUPO.MEM =="
   hRes := ExtratorLerMem( cDir + hb_ps() + "CVMGRUPO.MEM", "MCODGRU" )
   IF hRes[ "erro" ] != NIL
      ? "   FALHA: " + hRes[ "erro" ]
      nFalhas++
   ELSE
      ? "   MCODGRU .................: " + hb_ValToExp( hRes[ "valor" ] )
      IF ValType( hRes[ "valor" ] ) == "N"
         ? "      OK — numérico, pronto para a tabela sequencia"
      ELSE
         ? "      FALHA — esperado numérico"
         nFalhas++
      ENDIF
   ENDIF
   ?

   RETURN nFalhas

/*
 * Os dois casos do acervo em que o valor tipado do RDD perde informação.
 * Se este teste passar a falhar, o extrator voltou a ler só pelo RDD.
 */
STATIC FUNCTION TestaLeituraDupla( cDir )

   LOCAL hTab, hL, nFalhas := 0, i, cBruto, xValor

   ? "== 3. leitura dupla: valor tipado x bytes brutos =="

   /* CVBGRUCO.NUMMES reg.1 = '**' (overflow do Clipper — 02 §8.5) */
   hTab := ExtratorLer( cDir + hb_ps() + "CVBGRUCO.DBF" )
   IF hTab[ "erro" ] != NIL .OR. Len( hTab[ "linhas" ] ) < 1
      ? "   FALHA ao ler CVBGRUCO.DBF"
      nFalhas++
   ELSE
      hL     := hTab[ "linhas" ][ 1 ]
      cBruto := hL[ "brutos" ][ "NUMMES" ]
      xValor := hL[ "valores" ][ "NUMMES" ]
      ? "   CVBGRUCO.NUMMES reg.1  bruto=[" + cBruto + "]  tipado=" + hb_ntos( xValor )
      IF cBruto == "**"
         ? "      OK — overflow preservado nos bytes brutos"
      ELSE
         ? "      FALHA — esperado '**' nos bytes brutos"
         nFalhas++
      ENDIF
   ENDIF

   /* CVBGRUPO.NUMPAG em branco nos 5 registros — nunca gravado (02 §8.6) */
   hTab := ExtratorLer( cDir + hb_ps() + "CVBGRUPO.DBF" )
   IF hTab[ "erro" ] != NIL .OR. Len( hTab[ "linhas" ] ) < 5
      ? "   FALHA ao ler CVBGRUPO.DBF"
      nFalhas++
   ELSE
      FOR i := 1 TO Len( hTab[ "linhas" ] )
         IF !Empty( StrTran( hTab[ "linhas" ][ i ][ "brutos" ][ "NUMPAG" ], " ", "" ) )
            EXIT
         ENDIF
      NEXT
      ? "   CVBGRUPO.NUMPAG: " + hb_ntos( Len( hTab[ "linhas" ] ) ) + " registros, " + ;
        iif( i > Len( hTab[ "linhas" ] ), "todos em branco", "há valor gravado" )
      IF i > Len( hTab[ "linhas" ] )
         ? "      OK — 'nunca gravado' distinguível de zero"
      ELSE
         ? "      FALHA — esperado branco em 5/5 (02 §8.6)"
         nFalhas++
      ENDIF
      /* a marca de exclusão precisa vir do RDD, não do byte bruto apenas */
      ? "   CVBGRUPO excluídos (Deleted()): " + hb_ntos( hTab[ "excluidos" ] )
      IF hTab[ "excluidos" ] == 3
         ? "      OK — os 3 de RN-025 (08 §3.3)"
      ELSE
         ? "      FALHA — esperados 3"
         nFalhas++
      ENDIF
   ENDIF
   ?

   RETURN nFalhas
