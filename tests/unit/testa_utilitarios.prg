/*
 * testa_utilitarios.prg — FASE J
 *
 * O avaliador da calculadora (F2). Espaço em disco e editor de memo dependem de
 * tela e ficam na verificação manual; o avaliador é lógica pura e é o que tem
 * risco de verdade — ele recebe texto digitado pelo operador.
 */

STATIC s_nOk := 0
STATIC s_nFalhas := 0

PROCEDURE Main()

   ? "FASE J — utilitários"
   ?
   ? "== calculadora: aritmética =="
   Vale( "soma", UtilAvaliar( "2+3" ), 5 )
   Vale( "subtração", UtilAvaliar( "10-4" ), 6 )
   Vale( "multiplicação", UtilAvaliar( "6*7" ), 42 )
   Vale( "divisão", UtilAvaliar( "20/4" ), 5 )
   Vale( "decimais", UtilAvaliar( "1.5+2.25" ), 3.75 )
   Vale( "espaços são ignorados", UtilAvaliar( " 2 + 3 " ), 5 )

   ? "== precedência e parênteses =="
   Vale( "multiplicação antes da soma", UtilAvaliar( "2+3*4" ), 14 )
   Vale( "parênteses mudam a ordem", UtilAvaliar( "(2+3)*4" ), 20 )
   Vale( "aninhados", UtilAvaliar( "((1+2)*(3+4))" ), 21 )
   Vale( "negativo", UtilAvaliar( "-5+3" ), -2 )
   Vale( "negativo em parêntese", UtilAvaliar( "3*(-2)" ), -6 )

   ? "== o que NÃO é aceito =="
   /* divisão por zero devolve inválido em vez de derrubar o processo */
   Vale( "divisão por zero", UtilAvaliar( "1/0" ), NIL )
   Vale( "parêntese não fechado", UtilAvaliar( "(2+3" ), NIL )
   Vale( "operador solto", UtilAvaliar( "2+" ), NIL )
   Vale( "vazio", UtilAvaliar( "" ), NIL )
   Vale( "texto solto", UtilAvaliar( "abc" ), NIL )

   /*
    * O ponto da implementação à mão: o texto vem do operador, e o operador de
    * macro `&()` compilaria e executaria Harbour arbitrário. Uma calculadora
    * não justifica esse risco.
    */
   Vale( "chamada de função é recusada", UtilAvaliar( "SqlExec(1,1)" ), NIL )
   Vale( "atribuição é recusada", UtilAvaliar( "x := 1" ), NIL )
   Vale( "sobra de texto é recusada", UtilAvaliar( "2+3 xyz" ), NIL )

   ?
   ? "== resultado =="
   ? "   asserções ok .: " + hb_ntos( s_nOk )
   ? "   falhas .......: " + hb_ntos( s_nFalhas )
   ? "   " + iif( s_nFalhas == 0, "UTILITÁRIOS ACEITOS", "UTILITÁRIOS REPROVADOS" )
   ErrorLevel( iif( s_nFalhas == 0, 0, 1 ) )
   RETURN

/*
 * Números são comparados por VALOR, não pela representação textual: a divisão
 * do Harbour devolve 5.00 onde o literal é 5, e hb_ValToExp() os veria como
 * diferentes.
 */
STATIC PROCEDURE Vale( cDesc, xObtido, xEsperado )
   LOCAL lOk

   IF ValType( xObtido ) == "N" .AND. ValType( xEsperado ) == "N"
      lOk := ( Abs( xObtido - xEsperado ) < 0.0000001 )
   ELSE
      lOk := ( ValType( xObtido ) == ValType( xEsperado ) .AND. ;
               hb_ValToExp( xObtido ) == hb_ValToExp( xEsperado ) )
   ENDIF
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
