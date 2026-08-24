/*
 * inconsistencia.prg — FASE D.3
 *
 * Registro e exportação das inconsistências da migração.
 * Especificação: docs/08-MIGRACAO-DADOS.md §8; formato exigido pelo briefing §20
 * (registro original · campo · valor · problema · ação tomada).
 *
 * O normalizador (D.2) descreve o que houve com um VALOR, mas não sabe de que
 * registro ele veio. Este módulo junta as duas metades: recebe as ocorrências
 * do normalizador e as ancora no arquivo, registro, chave e campo de origem.
 *
 * Três formatos de saída, todos a partir da mesma lista (§8):
 *   - tabela `migracao_inconsistencia` no próprio banco
 *   - relatorio-migracao.txt  — texto, formato do briefing
 *   - relatorio-migracao.csv  — para conferência em planilha
 */

#include "fileio.ch"

#define SEV_BAIXA   "BAIXA"
#define SEV_MEDIA   "MEDIA"
#define SEV_ALTA    "ALTA"

FUNCTION IncNovo()
   RETURN { ;
      "itens"    => {}, ;
      "por_sev"  => { SEV_BAIXA => 0, SEV_MEDIA => 0, SEV_ALTA => 0 }, ;
      "por_arq"  => { => } }

/*
 * Registra uma inconsistência já descrita.
 * xValorOriginal é convertido para texto (a coluna é TEXT); NIL continua NULL.
 */
FUNCTION IncRegistrar( hReg, cArquivo, nRegistro, cChave, cCampo, ;
                       xValorOriginal, cProblema, cAcao, cSeveridade )

   LOCAL hItem

   hItem := { ;
      "arquivo"        => cArquivo, ;
      "registro"       => nRegistro, ;
      "chave"          => cChave, ;
      "campo"          => cCampo, ;
      "valor_original" => IncTexto( xValorOriginal ), ;
      "problema"       => cProblema, ;
      "acao"           => cAcao, ;
      "severidade"     => cSeveridade }

   AAdd( hReg[ "itens" ], hItem )

   IF cSeveridade $ hReg[ "por_sev" ]
      hReg[ "por_sev" ][ cSeveridade ]++
   ELSE
      hReg[ "por_sev" ][ cSeveridade ] := 1
   ENDIF
   IF cArquivo $ hReg[ "por_arq" ]
      hReg[ "por_arq" ][ cArquivo ]++
   ELSE
      hReg[ "por_arq" ][ cArquivo ] := 1
   ENDIF

   RETURN hItem

/*
 * Absorve as ocorrências que o normalizador devolveu para um campo,
 * ancorando cada uma no registro de origem. Devolve quantas foram registradas.
 */
FUNCTION IncAbsorver( hReg, hResNorm, cArquivo, nRegistro, cChave, cCampo, xValorOriginal )

   LOCAL i, aOc

   IF hResNorm == NIL .OR. !( "ocorrencias" $ hResNorm )
      RETURN 0
   ENDIF

   aOc := hResNorm[ "ocorrencias" ]
   FOR i := 1 TO Len( aOc )
      IncRegistrar( hReg, cArquivo, nRegistro, cChave, cCampo, xValorOriginal, ;
         aOc[ i ][ "problema" ], aOc[ i ][ "acao" ], aOc[ i ][ "severidade" ] )
   NEXT

   RETURN Len( aOc )

FUNCTION IncTotal( hReg )
   RETURN Len( hReg[ "itens" ] )

FUNCTION IncContagem( hReg, cSeveridade )
   RETURN iif( cSeveridade $ hReg[ "por_sev" ], hReg[ "por_sev" ][ cSeveridade ], 0 )

/* ------------------------------------------------------------------ */
/* Saída 1: tabela no próprio banco                                    */
/* ------------------------------------------------------------------ */

FUNCTION IncGravarSqlite( hReg, pDb, nExecucaoId )

   LOCAL i, h, nRc, nGravadas := 0
   LOCAL cSql := "INSERT INTO migracao_inconsistencia " + ;
      "(execucao_id, arquivo, registro, chave, campo, valor_original, " + ;
      " problema, acao, severidade) VALUES (?,?,?,?,?,?,?,?,?)"

   FOR i := 1 TO Len( hReg[ "itens" ] )
      h := hReg[ "itens" ][ i ]
      nRc := SqlExecBind( pDb, cSql, { ;
         nExecucaoId, h[ "arquivo" ], h[ "registro" ], h[ "chave" ], h[ "campo" ], ;
         h[ "valor_original" ], h[ "problema" ], h[ "acao" ], h[ "severidade" ] } )
      IF nRc == 0
         nGravadas++
      ENDIF
   NEXT

   RETURN nGravadas

/* ------------------------------------------------------------------ */
/* Saída 2: texto no formato do briefing §20                           */
/* ------------------------------------------------------------------ */

FUNCTION IncGravarTexto( hReg, cArquivoSaida )

   LOCAL hF, i, h, cArqAtual := "", cTxt := ""

   cTxt += "RELATÓRIO DE INCONSISTÊNCIAS DA MIGRAÇÃO" + hb_eol()
   cTxt += "S.C.C.V. — DBF (CA-Clipper, 1994) para SQLite" + hb_eol()
   cTxt += Replicate( "=", 60 ) + hb_eol() + hb_eol()
   cTxt += "Gerado em: " + IncAgora() + hb_eol()
   cTxt += "Total....: " + hb_ntos( IncTotal( hReg ) ) + hb_eol()
   cTxt += "  ALTA...: " + hb_ntos( IncContagem( hReg, SEV_ALTA ) ) + hb_eol()
   cTxt += "  MEDIA..: " + hb_ntos( IncContagem( hReg, SEV_MEDIA ) ) + hb_eol()
   cTxt += "  BAIXA..: " + hb_ntos( IncContagem( hReg, SEV_BAIXA ) ) + hb_eol()
   cTxt += hb_eol()
   cTxt += "Nenhum registro foi descartado. Nenhum valor foi corrigido em" + hb_eol()
   cTxt += "silêncio: cada item abaixo diz o que foi encontrado e o que foi" + hb_eol()
   cTxt += "feito com o dado." + hb_eol() + hb_eol()

   FOR i := 1 TO Len( hReg[ "itens" ] )
      h := hReg[ "itens" ][ i ]
      /* '==' e não '!=': com SET EXACT OFF (padrão do Clipper e do Harbour),
         qualquer string "é igual" a "" — a comparação não-exata testa prefixo.
         Com '!=' o cabeçalho por arquivo nunca era emitido. */
      IF !( h[ "arquivo" ] == cArqAtual )
         cArqAtual := h[ "arquivo" ]
         cTxt += Replicate( "-", 60 ) + hb_eol()
         cTxt += cArqAtual + hb_eol()
         cTxt += Replicate( "-", 60 ) + hb_eol() + hb_eol()
      ENDIF
      cTxt += "Registro " + hb_ntos( h[ "registro" ] ) + ;
              iif( h[ "chave" ] == NIL, "", "   (" + h[ "chave" ] + ")" ) + hb_eol()
      cTxt += "Campo:      " + h[ "campo" ] + hb_eol()
      cTxt += "Valor:      " + iif( h[ "valor_original" ] == NIL, "(vazio)", ;
                                    h[ "valor_original" ] ) + hb_eol()
      cTxt += "Problema:   " + h[ "problema" ] + hb_eol()
      cTxt += "Ação:       " + h[ "acao" ] + hb_eol()
      cTxt += "Severidade: " + h[ "severidade" ] + hb_eol()
      cTxt += hb_eol()
   NEXT

   hF := hb_vfOpen( cArquivoSaida, FO_CREAT + FO_TRUNC + FO_WRITE )
   IF hF == NIL
      RETURN .F.
   ENDIF
   hb_vfWrite( hF, cTxt )
   hb_vfClose( hF )

   RETURN .T.

/* ------------------------------------------------------------------ */
/* Saída 3: CSV                                                        */
/* ------------------------------------------------------------------ */

FUNCTION IncGravarCsv( hReg, cArquivoSaida )

   LOCAL hF, i, h, cTxt := ""

   cTxt += "arquivo,registro,chave,campo,valor_original,problema,acao,severidade" + hb_eol()

   FOR i := 1 TO Len( hReg[ "itens" ] )
      h := hReg[ "itens" ][ i ]
      cTxt += IncCsvCampo( h[ "arquivo" ] ) + "," + ;
              hb_ntos( h[ "registro" ] ) + "," + ;
              IncCsvCampo( h[ "chave" ] ) + "," + ;
              IncCsvCampo( h[ "campo" ] ) + "," + ;
              IncCsvCampo( h[ "valor_original" ] ) + "," + ;
              IncCsvCampo( h[ "problema" ] ) + "," + ;
              IncCsvCampo( h[ "acao" ] ) + "," + ;
              IncCsvCampo( h[ "severidade" ] ) + hb_eol()
   NEXT

   hF := hb_vfOpen( cArquivoSaida, FO_CREAT + FO_TRUNC + FO_WRITE )
   IF hF == NIL
      RETURN .F.
   ENDIF
   hb_vfWrite( hF, cTxt )
   hb_vfClose( hF )

   RETURN .T.

/*
 * Aspas conforme RFC 4180: sempre entre aspas, aspas internas duplicadas.
 * Os dados do legado contêm vírgula, aspas e quebras de linha (memos), então
 * escapar não é zelo excessivo — é o que impede o CSV de sair torto.
 */
STATIC FUNCTION IncCsvCampo( cValor )

   IF cValor == NIL
      RETURN ""
   ENDIF

   RETURN '"' + StrTran( cValor, '"', '""' ) + '"'

STATIC FUNCTION IncTexto( xValor )

   DO CASE
   CASE xValor == NIL             ; RETURN NIL
   CASE ValType( xValor ) == "C"  ; RETURN xValor
   CASE ValType( xValor ) == "N"  ; RETURN hb_ntos( xValor )
   CASE ValType( xValor ) == "L"  ; RETURN iif( xValor, ".T.", ".F." )
   CASE ValType( xValor ) == "D"  ; RETURN DToC( xValor )
   ENDCASE

   RETURN hb_ValToExp( xValor )

FUNCTION IncAgora()
   RETURN hb_TToC( hb_DateTime(), "YYYY-MM-DD", "HH:MM:SS" )
