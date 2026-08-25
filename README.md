# S.C.C.V. — reengenharia

Reescrita do **Sistema de Controle de Concessionária de Veículos**, originalmente
em CA-Clipper Summer '87 / DOS (1994), para **Harbour + SQLite + Linux**.

## Estado

| Fase | Estado |
|---|---|
| A — Descoberta | ✅ concluída |
| B — Documentação | ✅ concluída — 12 documentos em [`docs/`](docs/) |
| **C — Modelo de dados** | ✅ concluída — [`database/`](database/) |
| **D — Migração DBF → SQLite** | ✅ concluída — `make migrate` · 222 registros |
| **E — Testes de migração** | ✅ concluída — 892 campos, 0 divergências |
| **F — Infraestrutura Harbour** | ✅ concluída — `bin/sccv` sobe e se apresenta |
| **G — Implementação dos módulos** | 🔄 ondas 1–6 de 9 — 13 de 19 destinos do menu |
| H–J — Validações, regressão, auditoria | não iniciadas |

A migração está pronta e verificada — 185 registros lidos, 222 gravados, 892
campos conferidos um a um sem divergência, 140 inconsistências documentadas.

A aplicação já sobe: `bin/sccv` abre o menu e os **seis cadastros** (cliente,
funcionário, fornecedor, frota, peça, almoxarifado) funcionam com inclusão,
alteração, exclusão lógica e consulta. Movimento, consórcio e relatórios são as
ondas 4 a 9 da FASE G.
Ver a auditoria completa em [`docs/10-PLANO-IMPLEMENTACAO.md`](docs/10-PLANO-IMPLEMENTACAO.md) §6.

> Este README será substituído pelo README final (briefing §29) quando houver
> aplicação a documentar.

## Estrutura

```
legacy/      95 arquivos originais — SOMENTE LEITURA (chmod a-w)
backup/      cópia verificada por SHA-256 do legado
docs/        engenharia reversa: inventário, arquitetura, modelo, regras,
             fluxos, validações, relatórios, dependências, migração,
             divergências, plano
database/    schema.sql · views.sql · migrations/
src/
  main.prg   ponto de entrada da aplicação
  app/       config.prg (F.6) · log.prg (F.5) · erro.prg (F.4)
  database/  conexao.prg (F.2) · transacao.prg (F.3) · sql.prg
  migration/ extrator.prg (D.1) — leitura fiel dos .DBF via RDD DBFNTX
             normalizador.prg (D.2) — CP860, datas, centavos, CPF/CNPJ/CEP/tel
             inconsistencia.prg (D.3) — registro em tabela, texto e CSV
             carregador.prg (D.4/D.5) — carga transacional e transformações
             migrar.prg (D.6) — CLI, idempotência, códigos de saída
             verificador.prg (E) — contagens, somas, campo a campo, FKs
  services/  comissao.prg (RN-030..032) · estoque.prg (RN-028/029/034/035)
  models/    modelo.prg — motor de cadastro dirigido por descritor
             cliente · funcionario · fornecedor · modelo_veiculo · peca
             · almoxarifado (só o que difere entre eles)
  validation/ validacao.prg (V-01..V-19) · integridade.prg (V-13, V-17)
tests/
  migration/ testa_extrator.prg — aceite da D.1 contra as contagens da FASE A
             testa_normalizador.prg — aceite da D.2, 100 asserções
             testa_inconsistencia.prg — aceite da D.3, 35 asserções
             testa_migracao.prg — aceite da D.4/D.5, 48 asserções
             testa_verificacao.prg — aceite da E, 56 verificações
  unit/      testa_infra.prg — aceite da F, 75 asserções
config/      sccv.conf.exemplo
tools/       dump-dbf.py · dump-ntx.py (inspeção do legado)
```

## O que o sistema faz

Gestão de uma concessionária Fiat: cadastro de clientes, funcionários e
fornecedores; estoque de peças, almoxarifado e frota; venda de peças no balcão;
reparos de automóveis; venda de veículos de pronta entrega; consórcio (adesão,
formação e fechamento de grupo, baixa de prestações, contemplação); comissões de
vendedores; 12 relatórios.

## Requisitos

| Dependência | Versão | Estado no ambiente |
|---|---|---|
| Harbour + hbmk2 | 3.0+ | ✅ 3.2.1dev em `/opt/harbour` |
| GCC | qualquer | ✅ 15.2.0 |
| SQLite | **3.37+** (tabelas `STRICT`) | ✅ 3.46.1 (também dentro do `hbsqlit3`) |
| GNU Make | 3.81+ | ✅ 4.4.1 |
| Python 3 | 3.8+ (só ferramentas de análise) | ✅ 3.14.4 |

O Harbour **não existe como pacote no Ubuntu 26.04** — foi compilado do fonte e
instalado em `/opt/harbour`. Para reproduzir o ambiente:

```bash
sudo apt install libsqlite3-dev libncurses-dev   # dependências de compilação
git clone https://github.com/harbour/core.git && cd core
make && sudo HB_INSTALL_PREFIX=/opt/harbour make install
export PATH=/opt/harbour/bin:$PATH
```

Verificação do que a FASE D exige (`harbour -build`, `libhbsqlit3.a`,
`sqlite3_libversion() ≥ 3.37`, RDD DBFNTX, codepage `PT860`):

```bash
hbmk2 -version && ls /opt/harbour/lib/harbour/libhbsqlit3.a
```

## Criar o banco

```bash
sqlite3 sccv.db < database/schema.sql
sqlite3 sccv.db < database/views.sql
```

## Rodar

```bash
make                  # compila bin/sccv e bin/sccv-migrar
make run              # estado do ambiente e do banco
bin/sccv --config-mostrar     # configuração efetiva e de onde veio
make install          # instala em ~/.local/bin (PREFIX=...)
```

Configuração: veja [`config/sccv.conf.exemplo`](config/sccv.conf.exemplo). A
precedência é `--config` · `$SCCV_CONFIG` · `$XDG_CONFIG_HOME/sccv/sccv.conf` ·
`/etc/sccv/sccv.conf` · valores embutidos — o primeiro que existir vence, sem
mesclar.

## Migrar o legado

```bash
make check-deps                    # confere a toolchain
make                               # compila bin/sccv-migrar
make migrate                       # legacy/ → sccv.db
make verificar                     # integridade do banco migrado
make test                          # os quatro testes de aceite
```

Ou direto:

```bash
bin/sccv-migrar --origem legacy --destino sccv.db [--forcar]
bin/sccv-migrar --verificar --destino sccv.db
bin/sccv-migrar --relatorio --destino sccv.db
```

Saída: `0` sucesso · `1` uso · `2` origem inválida · `3` destino já populado sem
`--forcar` · `4` falha na carga (rollback aplicado) · `5` falha na verificação.

A migração não é incremental: reexecutar refaz tudo. Um destino já populado só é
substituído com `--forcar`, e o banco anterior é preservado em
`<nome>.db.bak.<timestamp>`. Cada execução gera `relatorio-migracao.txt` (formato
do briefing §20) e `relatorio-migracao.csv`.

## Inspecionar o legado

```bash
python3 tools/dump-dbf.py legacy/                       # estrutura e registros
python3 tools/dump-ntx.py legacy/                       # chaves dos índices
iconv -f CP860 -t UTF-8 legacy/SCCV.PRG | tr -d '\r'    # ler um fonte
```

O legado usa **CP860** (Português — DOS), não CP850 — determinado
empiricamente. Ver [`docs/05-VALIDACOES-LEGADO.md`](docs/05-VALIDACOES-LEGADO.md) §7.

## Princípio do trabalho

O código legado é a fonte da verdade sobre o comportamento. Nenhuma regra de
negócio é inventada: onde a intenção original não é determinável, o comportamento
literal é preservado e a dúvida fica registrada (12 questões abertas, Q-01..Q-12).
Toda diferença entre legado e sistema novo é classificada e rastreável —
27 divergências em [`docs/09-DIVERGENCIAS-MODERNIZACAO.md`](docs/09-DIVERGENCIAS-MODERNIZACAO.md).
