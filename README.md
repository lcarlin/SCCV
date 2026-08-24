# S.C.C.V. — reengenharia

Reescrita do **Sistema de Controle de Concessionária de Veículos**, originalmente
em CA-Clipper Summer '87 / DOS (1994), para **Harbour + SQLite + Linux**.

## Estado

| Fase | Estado |
|---|---|
| A — Descoberta | ✅ concluída |
| B — Documentação | ✅ concluída — 12 documentos em [`docs/`](docs/) |
| **C — Modelo de dados** | ✅ concluída — [`database/`](database/) |
| **D — Migração DBF → SQLite** | 🔄 em andamento |
| E — Testes de migração | não iniciada |
| F — Infraestrutura Harbour | não iniciada |
| G–J — Implementação, validações, regressão, auditoria | não iniciadas |

**0 de 68 funcionalidades implementadas.** Nenhuma linha da aplicação escrita.
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
  migration/ extrator.prg (D.1) — leitura fiel dos .DBF via RDD DBFNTX
             normalizador.prg (D.2) — CP860, datas, centavos, CPF/CNPJ/CEP/tel
             inconsistencia.prg (D.3) — registro em tabela, texto e CSV
  database/  sql.prg — hbsqlit3 com bind por tipo e transações
tests/
  migration/ testa_extrator.prg — aceite da D.1 contra as contagens da FASE A
             testa_normalizador.prg — aceite da D.2, 100 asserções
             testa_inconsistencia.prg — aceite da D.3, 35 asserções
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

## Rodar o aceite da migração

```bash
export PATH=/opt/harbour/bin:$PATH
hbmk2 tests/migration/testa_extrator.prg src/migration/extrator.prg -gtcgi -otesta_extrator
./testa_extrator            # sai com 0 se as contagens conferem

hbmk2 tests/migration/testa_normalizador.prg src/migration/normalizador.prg -gtcgi -otesta_norm
./testa_norm                # sai com 0 se as 100 asserções passam
```

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
