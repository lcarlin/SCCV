/*
 * cliente.prg — FASE G, onda 2
 *
 * Descritor do cadastro de clientes. Campos e validadores; o SQL é do motor
 * genérico em modelo.prg.
 *
 * Ordem e rótulos seguem a tela MEN_T_1 do legado (CVTELAS.PRG), para que
 * quem operava o sistema antigo reconheça a tela.
 */

/* data_cadastro é NOT NULL e não é digitada: quem a grava é o sistema. */
FUNCTION ClienteDescritor()

   LOCAL hD := { ;
      "entidade" => "cliente", ;
      "tabela"   => "cliente", ;
      "view"     => "v_cliente", ;
      "chave"    => "cod_cli", ;
      "titulo"   => "Manutenção de Clientes", ;
      "campos"   => { ;
         ModeloCampo( "nome"      , "Nome"      , "C", 35, {| x | ValObrigatorio( x, "Nome" ) } ), ;
         ModeloCampo( "endereco"  , "Endereço"  , "C", 45, {| x | ValTamanho( x, 45, "Endereço" ) } ), ;
         ModeloCampo( "cidade"    , "Cidade"    , "C", 20, {| x | ValTamanho( x, 20, "Cidade" ) } ), ;
         ModeloCampo( "uf"        , "UF"        , "C",  2, {| x | ValUf( x ) } ), ;
         ModeloCampo( "cep"       , "CEP"       , "C",  9, {| x | ValCep( x ) }, "cep_original" ), ;
         ModeloCampo( "telefone"  , "Telefone"  , "C", 15, {| x | ValTelefone( x ) }, "telefone_original" ), ;
         ModeloCampo( "rg"        , "RG"        , "C", 15, {| x | ValTamanho( x, 15, "RG" ) } ), ;
         ModeloCampo( "cpf"       , "CPF"       , "C", 14, {| x | ValCpf( x ) }, "cpf_original", "cpf_valido" ), ;
         ModeloCampo( "nascimento", "Nascimento", "D", 10, {| x | ValNascimento( x ) } ), ;
         ModeloCampo( "consorcio" , "Consorciado (S/N)", "C", 1, {| x | ValSimNao( x ) } ) }, ;
      "defaults" => { "data_cadastro" => {| | hb_DToC( Date(), "YYYY-MM-DD" ) } }, ;
      "validador_extra" => {| pDb, hVal, hV, lNovo | ClienteExtra( pDb, hVal, hV, lNovo ) } }

   RETURN hD

/*
 * Regras que não cabem num campo isolado.
 *
 * Unicidade de CPF (V-13) é uma delas: só se sabe consultando os outros
 * registros. E o aviso de nascimento improvável (V-08) entra aqui como AVISO,
 * não erro — o operador confirma e segue, como o legado fazia com estoque
 * mínimo.
 */
STATIC PROCEDURE ClienteExtra( pDb, hValores, hV, lNovo )

   LOCAL hR

   IF !Empty( hValores[ "cpf" ] )
      hR := IntegCpfUnico( pDb, hValores[ "cpf" ], ;
                           iif( lNovo, NIL, hValores[ "cod_cli" ] ) )
      IF !hR[ "ok" ]
         ValErro( hV, "cpf", hR[ "mensagem" ] )
      ENDIF
   ENDIF

   IF !Empty( hValores[ "nascimento" ] ) .AND. ;
      ValNascimentoSuspeito( hValores[ "nascimento" ] )
      ValAviso( hV, "nascimento", "Data de nascimento resulta em idade acima de " + ;
                "110 anos. Confirme se está correta." )
   ENDIF

   RETURN

/*
 * S/N — o legado gravava 'S' ou branco e comparava com `$`, que aceita
 * qualquer coisa (V-11). Aqui só S e N passam; vazio vira N, que é o padrão
 * da coluna no schema.
 */
FUNCTION ValSimNao( cValor )

   LOCAL c

   IF Empty( cValor )
      RETURN { "ok" => .T., "mensagem" => NIL, "valor" => "N" }
   ENDIF
   c := Upper( AllTrim( cValor ) )
   IF !( c == "S" ) .AND. !( c == "N" )
      RETURN { "ok" => .F., "mensagem" => "Informe S ou N.", "valor" => NIL }
   ENDIF

   RETURN { "ok" => .T., "mensagem" => NIL, "valor" => c }
