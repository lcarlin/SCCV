# Documentação de Engenharia Reversa — S.C.C.V.

Reengenharia do S.C.C.V. — Sistema de Controle de Concessionária de Veículos,
originalmente escrito em CA-Clipper Summer '87 (1994) para MS-DOS.

| Fase | Estado |
|---|---|
| A — Descoberta | ✅ concluída |
| B — Documentação | ✅ concluída |
| **C — Modelo de dados** | ✅ concluída → [`database/`](../database/) |
| D — Migração | ⏸ bloqueada: Harbour não instalado |
| E … J | não iniciadas |

**O sistema legado está em [`legacy/`](../legacy/), somente leitura**, com backup
verificado por SHA-256. Nenhum byte foi alterado.

## Índice

| Documento | Conteúdo |
|---|---|
| [00-INVENTARIO.md](00-INVENTARIO.md) | 45 PRG, 23 DBF, 16 NTX, 3 DBT classificados por papel funcional; grafo de dependências; artefatos ausentes |
| [01-ARQUITETURA-LEGADO.md](01-ARQUITETURA-LEGADO.md) | Bootstrap, menu, camadas, estado global, dependências DOS, correspondência Clipper → Harbour |
| [02-MODELO-DADOS.md](02-MODELO-DADOS.md) | Estrutura de cada DBF, chaves implícitas, relacionamentos, qualidade dos dados medida, esquema SQLite proposto |
| [03-REGRAS-NEGOCIO.md](03-REGRAS-NEGOCIO.md) | 42 regras no formato do briefing, com grau de evidência (comprovada / inferida / defeituosa) |
| [04-FLUXOS.md](04-FLUXOS.md) | Navegação, fluxo canônico de manutenção, 4 fluxos de movimento detalhados, 38 mensagens ao usuário |
| [05-VALIDACOES-LEGADO.md](05-VALIDACOES-LEGADO.md) | Catálogo de máscaras e `VALID`, determinação do charset (CP860), 20 validações a introduzir, 9 proibidas |
| [06-RELATORIOS.md](06-RELATORIOS.md) | Ficha dos 12 relatórios: origem, filtros, ordenação, cálculos, paginação, destino; 9 correções necessárias |
| [07-DEPENDENCIAS.md](07-DEPENDENCIAS.md) | CLBC/GIP, matriz módulo × tabela, dependências de plataforma, 19 referências quebradas, stack novo |
| [08-MIGRACAO-DADOS.md](08-MIGRACAO-DADOS.md) | Pipeline de 5 etapas, regras de normalização, idempotência, transformações estruturais, verificação |
| [09-DIVERGENCIAS-MODERNIZACAO.md](09-DIVERGENCIAS-MODERNIZACAO.md) | 25 divergências classificadas conforme o briefing §23; 12 questões pendentes |
| [10-PLANO-IMPLEMENTACAO.md](10-PLANO-IMPLEMENTACAO.md) | Estrutura, roteiro por fase, matriz de compatibilidade (68 funcionalidades), auditoria, riscos |

> `09` traz **27 divergências** (D-27 e o refinamento de D-11 vieram da FASE C).

## Achados principais

1. **Codificação é CP860** (Português DOS), não CP850 — determinado empiricamente pelos bytes `0x84`/`0x94`.
2. **18 dos 45 programas são código morto** (versões anteriores, duplicatas, fragmentos).
3. **11 das 24 tabelas são predecessoras obsoletas.**
4. **7 defeitos alteram a semântica de negócio** — comissões creditadas ao funcionário errado, baixa de estoque no modelo errado, corrupção de chave primária ao alterar peça, saldo negativo de prestações com overflow gravado no arquivo.
5. **1 relatório ativo (Consórcios) é inoperante** — referencia 6 campos que não existem na tabela.
6. **Os agregados dos gráficos divergem dos dados reais em até 11.062 unidades.**
7. **Nenhum registro órfão** nas 13 relações verificadas — a integridade sobreviveu por baixo volume, não por estrutura.
8. **Nenhuma validação de CPF/CNPJ** — os 22 CPFs do acervo são sequências de teste.

## Ferramentas de análise

`../tools/dump-dbf.py` e `../tools/dump-ntx.py` reproduzem as extrações citadas nos documentos.

```bash
python3 tools/dump-dbf.py legacy/    # estrutura e registros de todos os DBF
python3 tools/dump-ntx.py legacy/    # chaves de todos os índices NTX
```

## Artefatos da FASE C

| Arquivo | Conteúdo |
|---|---|
| [`../database/schema.sql`](../database/schema.sql) | 19 tabelas, 26 índices — cada decisão comentada no SQL |
| [`../database/views.sql`](../database/views.sql) | 14 views — exclusão lógica e agregados |
| [`../database/README.md`](../database/README.md) | Como aplicar, requisitos, verificação |
