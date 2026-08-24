# Banco de dados

| Arquivo | Conteúdo |
|---|---|
| `schema.sql` | DDL completo: 19 tabelas, 26 índices |
| `views.sql` | 14 views: exclusão lógica (`SET DELETED ON`) + agregados (D-18) |
| `migrations/` | Evolução do schema pós-implantação; `001-inicial.sql` é a baseline |

## Aplicar em banco novo

```bash
sqlite3 sccv.db < database/schema.sql
sqlite3 sccv.db < database/views.sql
```

## Requisitos

- **SQLite ≥ 3.37.0** — as tabelas usam `STRICT` (tipagem realmente aplicada).
  *Fallback:* trocar `) STRICT;` por `);` reduz o requisito para 3.24+, ao custo
  de perder a checagem de tipo. Ver cabeçalho de `schema.sql`.
- `PRAGMA foreign_keys = ON` **é por conexão** e não pode ser gravado no arquivo.
  A aplicação deve emiti-lo em toda abertura (`src/database/conexao.prg`).
  `PRAGMA journal_mode = WAL` é persistente e já está no schema.

## Composição

| Grupo | Tabelas |
|---|---|
| Cadastros nível 0 | `cliente` `funcionario` `fornecedor` `modelo_veiculo` |
| Cadastros nível 1 | `peca` `almoxarifado` |
| Movimento nível 2 | `venda_veiculo` `venda_peca` `consorcio_cota` `orcamento_reparo` `pedido` |
| Movimento nível 3 | `venda_peca_item` |
| Apoio | `sequencia` |
| Controle de migração | `migracao_execucao` `migracao_inconsistencia` |
| Quarentena | `_legado_cvvcar` `_legado_cvvpec` `_legado_cvclient` `_legado_cvbgrupo_excluido` |

A ordem acima é a **ordem topológica de carga** (docs/07-DEPENDENCIAS.md §2.2).

## Verificação

```sql
PRAGMA foreign_keys;        -- 1 na conexão da aplicação
PRAGMA foreign_key_check;   -- vazio
PRAGMA integrity_check;     -- ok
PRAGMA user_version;        -- 1
```

## Rastreabilidade

Cada decisão de modelagem está comentada no próprio `schema.sql` e detalhada em:

- `docs/02-MODELO-DADOS.md` — estrutura do legado e justificativa de tipos
- `docs/09-DIVERGENCIAS-MODERNIZACAO.md` — as 27 divergências classificadas
- `docs/08-MIGRACAO-DADOS.md` — como os dados do legado chegam aqui
