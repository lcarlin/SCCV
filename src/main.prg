/*
 * main.prg — ponto de entrada do S.C.C.V.
 *
 * FASE F: a infraestrutura sobe e se apresenta. Os módulos funcionais são a
 * FASE G; até lá, `sccv` serve para verificar que configuração, log, banco e
 * tratamento de erro estão de pé no ambiente onde a aplicação vai rodar.
 *
 *   sccv [--config <arquivo>] [--banco <arquivo>]
 *   sccv --estado          estado do ambiente e do banco
 *   sccv --config-mostrar  configuração efetiva e de onde ela veio
 *   sccv --versao
 *
 * Saída: 0 sucesso · 1 erro de uso · 2 configuração/ambiente · 3 banco
 */

#define VERSAO   "0.1.0-fase-F"

#define SAIDA_OK      0
#define SAIDA_USO     1
#define SAIDA_AMBIENTE 2
#define SAIDA_BANCO   3

PROCEDURE Main( ... )

   LOCAL hArg, nSaida

   /* Começa em CGI, sem controle de tela: --estado, --versao e
      --config-mostrar precisam produzir saída limpa, utilizável em script.
      tela.prg troca para TRM ao abrir a interface. Fazer isto aqui, e não
      pela ordem dos -gt no link, deixa a decisão explícita no código. */
   hb_gtReload( "CGI" )

   hArg := Argumentos( hb_AParams() )
   IF hArg[ "erro" ] != NIL
      OutErr( "erro de uso: " + hArg[ "erro" ] + hb_eol() )
      Uso()
      ErrorLevel( SAIDA_USO )
      RETURN
   ENDIF

   IF hArg[ "versao" ]
      Escrever( "S.C.C.V. " + VERSAO )
      Escrever( Ambiente() )
      ErrorLevel( SAIDA_OK )
      RETURN
   ENDIF

   nSaida := Iniciar( hArg )
   IF nSaida != SAIDA_OK
      ErrorLevel( nSaida )
      RETURN
   ENDIF

   DO CASE
   CASE hArg[ "config_mostrar" ] ; nSaida := MostrarConfig()
   CASE hArg[ "estado" ]         ; nSaida := Estado()
   OTHERWISE                     ; nSaida := Aplicacao()
   ENDCASE

   ConexaoFechar()
   ErrorLevel( nSaida )

   RETURN

/* Sobe a infraestrutura na ordem em que uma depende da outra. */
STATIC FUNCTION Iniciar( hArg )

   LOCAL hConf, cErro, hCon, cBanco

   hConf := ConfigCarregar( hArg[ "config" ] )
   IF !Empty( hArg[ "config" ] ) .AND. !( ConfigOrigem() == hArg[ "config" ] )
      OutErr( "arquivo de configuração não encontrado: " + hArg[ "config" ] + hb_eol() )
      RETURN SAIDA_USO
   ENDIF

   cErro := ConfigPrepararDiretorios()
   IF cErro != NIL
      OutErr( cErro + hb_eol() )
      RETURN SAIDA_AMBIENTE
   ENDIF

   LogIniciar( hConf[ "log" ], hConf[ "log_nivel" ], hConf[ "log_max_bytes" ] )
   LogInfo( "início", "versão=" + VERSAO + " config=" + ConfigOrigem() )

   cBanco := iif( Empty( hArg[ "banco" ] ), hConf[ "banco" ], hArg[ "banco" ] )
   hCon := ConexaoAbrir( cBanco )
   IF !hCon[ "ok" ]
      Escrever( hCon[ "mensagem" ] )
      LogErro( "falha ao abrir o banco", "arquivo=" + cBanco )
      RETURN SAIDA_BANCO
   ENDIF

   RETURN SAIDA_OK

/*
 * Abre a aplicação. As ondas 2 a 8 da FASE G ligam os destinos do menu; até lá
 * o despachante responde honestamente que o destino não existe ainda, em vez
 * de abrir uma tela vazia.
 */
STATIC FUNCTION Aplicacao()

   LOCAL hCob

   IF !ConexaoMigrado( ConexaoDb() )
      Escrever( "O banco ainda não foi migrado. Execute:  make migrate" )
      RETURN SAIDA_BANCO
   ENDIF

   hCob := MenuCobertura( {| c | AcaoImplementada( c ) } )
   LogInfo( "menu aberto", "destinos=" + hb_ntos( hCob[ "total" ] ) + ;
            " implementados=" + hb_ntos( hCob[ "implementados" ] ) )

   TelaIniciar()
   MenuPrincipal( {| c | Despachar( c ) }, {| c | AcaoImplementada( c ) } )
   TelaEncerrar()

   Escrever( "S.C.C.V. encerrado. " + hb_ntos( hCob[ "implementados" ] ) + " de " + ;
             hb_ntos( hCob[ "total" ] ) + " destinos do menu implementados." )

   RETURN SAIDA_OK

/*
 * Esta lista — e não a definição do menu — decide o que aparece como pronto.
 * Cresce a cada onda da FASE G. Onda 2: cadastros de nível 0.
 */
STATIC FUNCTION AcaoImplementada( cAcao )
   RETURN AScan( { "cliente.manutencao", "cliente.consulta", ;
                   "funcionario.manutencao", "funcionario.consulta", ;
                   "fornecedor.manutencao", "fornecedor.consulta", ;
                   "modelo.manutencao", ;
                   "peca.manutencao", "almoxarifado.manutencao", ;
                   "venda.pecas", "venda.reparo", "venda.pronta", ;
                   "consorcio", ;
                   "cliente.relatorio", "funcionario.relatorio", ;
                   "fornecedor.relatorio", "relatorio.estoques", ;
                   "relatorio.servicos" }, ;
                 {| x | x == cAcao } ) > 0

STATIC FUNCTION Despachar( cAcao )

   LOCAL pDb := ConexaoDb(), hRes

   /* toda a operação corre protegida: um erro num cadastro não pode derrubar
      o sistema inteiro nem deixar transação aberta (briefing §18) */
   hRes := ErroProteger( {| | DespacharAcao( pDb, cAcao ) }, ;
                         "executar '" + cAcao + "'", ;
                         {| e | HB_SYMBOL_UNUSED( e ), TransAbortarTudo( pDb ) } )
   IF !hRes[ "ok" ]
      Mensagem( Left( hRes[ "mensagem" ], 76 ) )
   ENDIF

   RETURN .T.

STATIC FUNCTION DespacharAcao( pDb, cAcao )

   DO CASE
   CASE cAcao == "cliente.manutencao"
      CadastroManutencao( pDb, ClienteDescritor() )
   CASE cAcao == "cliente.consulta"
      CadastroManutencao( pDb, ClienteDescritor() )
   CASE cAcao == "funcionario.manutencao" .OR. cAcao == "funcionario.consulta"
      CadastroManutencao( pDb, FuncionarioDescritor() )
   CASE cAcao == "fornecedor.manutencao" .OR. cAcao == "fornecedor.consulta"
      CadastroManutencao( pDb, FornecedorDescritor() )
   CASE cAcao == "modelo.manutencao"
      CadastroManutencao( pDb, ModeloVeiculoDescritor() )
   CASE cAcao == "peca.manutencao"
      CadastroManutencao( pDb, PecaDescritor() )
   CASE cAcao == "almoxarifado.manutencao"
      CadastroManutencao( pDb, AlmoxarifadoDescritor() )
   CASE cAcao == "venda.pecas"
      MovimentoVendaPeca( pDb, "BALCAO" )
   CASE cAcao == "venda.reparo"
      MovimentoVendaPeca( pDb, "REPARO" )
   CASE cAcao == "venda.pronta"
      MovimentoProntaEntrega( pDb )
   CASE cAcao == "consorcio"
      ConsorcioMenu( pDb )
   CASE cAcao == "cliente.relatorio"
      RelatorioEmitir( pDb, "R-01" )
   CASE cAcao == "funcionario.relatorio"
      RelatorioEmitir( pDb, "R-02" )
   CASE cAcao == "fornecedor.relatorio"
      RelatorioEmitir( pDb, "R-03" )
   CASE cAcao == "relatorio.estoques"
      RelatorioSubmenu( pDb, { "R-04", "R-05", "R-06" } )
   CASE cAcao == "relatorio.servicos"
      RelatorioSubmenu( pDb, { "R-07", "R-08", "R-09", "R-10" } )
   OTHERWISE
      Mensagem( "Destino '" + cAcao + "' ainda não implementado" )
   ENDCASE

   RETURN NIL

STATIC FUNCTION Estado()

   LOCAL pDb := ConexaoDb(), lMig

   Escrever( "S.C.C.V. " + VERSAO )
   Escrever( "" )
   Escrever( "configuração .: " + ConfigOrigem() )
   Escrever( "banco ........: " + ConexaoArquivo() )
   Escrever( "log ..........: " + LogArquivo() + "  (nível " + LogNivel() + ")" )
   Escrever( "" )
   Escrever( "schema .......: user_version " + Txt( ConexaoVersaoSchema( pDb ) ) )
   Escrever( "foreign_keys .: " + Txt( SqlEscalar( pDb, "PRAGMA foreign_keys" ) ) )
   Escrever( "journal_mode .: " + Txt( SqlEscalar( pDb, "PRAGMA journal_mode" ) ) )

   lMig := ConexaoMigrado( pDb )
   Escrever( "migração .....: " + iif( lMig, "concluída", "NÃO executada" ) )
   IF lMig
      Escrever( "" )
      Escrever( "clientes .....: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_cliente" ) ) )
      Escrever( "peças ........: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_peca" ) ) )
      Escrever( "vendas de peça: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_venda_peca" ) ) )
      Escrever( "veículos ven..: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_venda_veiculo" ) ) )
      Escrever( "cotas ........: " + Txt( SqlEscalar( pDb, "SELECT count(*) FROM v_consorcio_cota" ) ) )
      Escrever( "inconsistênc..: " + Txt( SqlEscalar( pDb, ;
         "SELECT count(*) FROM migracao_inconsistencia" ) ) )
   ELSE
      Escrever( "" )
      Escrever( "Execute a migração antes de usar o sistema:  make migrate" )
   ENDIF
   Escrever( "" )
   Escrever( "" )
   Escrever( "menu .........: " + hb_ntos( MenuCobertura( {| c | AcaoImplementada( c ) } )[ "implementados" ] ) + ;
             " de " + hb_ntos( MenuCobertura()[ "total" ] ) + " destinos implementados" )

   RETURN SAIDA_OK

STATIC FUNCTION MostrarConfig()

   LOCAL hConf := ConfigTudo(), aChaves := hb_HKeys( hConf ), i

   Escrever( "configuração efetiva (origem: " + ConfigOrigem() + ")" )
   Escrever( "" )
   FOR i := 1 TO Len( aChaves )
      Escrever( "  " + PadR( aChaves[ i ], 16 ) + Txt( hConf[ aChaves[ i ] ] ) )
   NEXT
   Escrever( "" )
   Escrever( "precedência: --config · $SCCV_CONFIG · $XDG_CONFIG_HOME/sccv/sccv.conf" )
   Escrever( "             · /etc/sccv/sccv.conf · valores embutidos" )

   RETURN SAIDA_OK

STATIC FUNCTION Ambiente()
   RETURN "Harbour " + Version() + " · " + OS() + hb_eol() + ;
          "SQLite " + Txt( SqlEscalar( SqlAbrir( ":memory:" ), ;
                                               "SELECT sqlite_version()" ) )

STATIC FUNCTION Argumentos( aArgs )

   LOCAL hArg, i, cArg

   hArg := { "config" => NIL, "banco" => NIL, "versao" => .F., ;
             "config_mostrar" => .F., "estado" => .F., "erro" => NIL }

   i := 1
   DO WHILE i <= Len( aArgs )
      cArg := aArgs[ i ]
      DO CASE
      CASE cArg == "--config"
         i++
         IF i > Len( aArgs )
            hArg[ "erro" ] := "faltou o arquivo de --config"
            RETURN hArg
         ENDIF
         hArg[ "config" ] := aArgs[ i ]
      CASE cArg == "--banco"
         i++
         IF i > Len( aArgs )
            hArg[ "erro" ] := "faltou o arquivo de --banco"
            RETURN hArg
         ENDIF
         hArg[ "banco" ] := aArgs[ i ]
      CASE cArg == "--versao"         ; hArg[ "versao" ] := .T.
      CASE cArg == "--config-mostrar" ; hArg[ "config_mostrar" ] := .T.
      CASE cArg == "--estado"         ; hArg[ "estado" ] := .T.
      CASE cArg == "--ajuda" .OR. cArg == "-h"
         Uso()
         hArg[ "versao" ] := .T.
      OTHERWISE
         hArg[ "erro" ] := "opção desconhecida: " + cArg
         RETURN hArg
      ENDCASE
      i++
   ENDDO

   RETURN hArg

STATIC PROCEDURE Uso()
   Escrever( "" )
   Escrever( "uso: sccv [opções]" )
   Escrever( "  --config <arquivo>   arquivo de configuração" )
   Escrever( "  --banco <arquivo>    banco de dados (sobrepõe a configuração)" )
   Escrever( "  --estado             estado do ambiente e do banco" )
   Escrever( "  --config-mostrar     configuração efetiva e sua origem" )
   Escrever( "  --versao             versão e ambiente" )
   RETURN

/* hb_ValToStr() de numérico vem preenchido à esquerda; aqui interessa o valor. */
STATIC FUNCTION Txt( xValor )
   IF xValor == NIL
      RETURN "(nenhum)"
   ENDIF
   RETURN AllTrim( hb_ValToStr( xValor ) )

STATIC PROCEDURE Escrever( cTexto )
   OutStd( cTexto + hb_eol() )
   RETURN
