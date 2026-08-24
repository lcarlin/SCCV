# Sistema legado — SOMENTE LEITURA

Estes 95 arquivos são o **S.C.C.V. original** (CA-Clipper Summer '87, 1994) e
constituem a **fonte da verdade sobre o comportamento do sistema**.

## Regras

1. **Não altere, não remova, não sobrescreva nenhum arquivo deste diretório.**
2. Todos os arquivos estão com permissão de escrita removida (`chmod a-w`).
3. Qualquer dúvida sobre comportamento se resolve lendo o código daqui —
   não a documentação, não o sistema novo.
4. Cópia de segurança com verificação SHA-256 em `../backup/legado-<timestamp>/`.

## Procedência

Movidos da raiz do projeto para cá em 2026-08-24, após conclusão das FASES A e B
e mediante autorização explícita (briefing §24, item C.5 do plano).

Integridade verificada: os 95 checksums SHA-256 conferem antes e depois da
movimentação (`../backup/legado-<timestamp>/SHA256SUMS.antes`).

## Conteúdo

| Tipo | Qtde | Observação |
|---|---:|---|
| `.PRG` | 45 | 27 ativos, 18 mortos/duplicados — ver `../docs/00-INVENTARIO.md` §2 |
| `.DBF` | 23 | 12 ativas, 10 obsoletas/vazias, 1 órfã — ver `../docs/02-MODELO-DADOS.md` |
| `.NTX` | 16 | Índices Clipper, chave de campo simples |
| `.DBT` | 3 | Memos (2 com conteúdo) |
| `.MEM` | 1 | `CVMGRUPO.MEM` — sequencial do grupo de consórcio |
| `.EXE` | 4 | `SCCV.EXE`, `CVTEABE.EXE`, `BCVGA.EXE`, `BCRETCTR.EXE` |
| `.PCX` | 1 | Splash screen |
| outros | 2 | `NORTON.INI`, `SKPLSDMP.DMP` — lixo de ferramentas DOS, sem relação |

## Notas técnicas

- **Codificação: CP860** (Português — DOS), não CP850. Ver `../docs/05-VALIDACOES-LEGADO.md` §7.
- **Fim de linha: CRLF.** Alguns `.PRG` terminam com `^Z` (0x1A).
- **Nomes em MAIÚSCULAS.** Os fontes referenciam arquivos em caixa inconsistente —
  irrelevante no DOS, quebra no Linux. Ver `../docs/07-DEPENDENCIAS.md` §3.3.
- Para inspecionar sem abrir os binários:
  ```bash
  python3 tools/dump-dbf.py legacy/    # estrutura e registros dos DBF
  python3 tools/dump-ntx.py legacy/    # chaves dos índices NTX
  iconv -f CP860 -t UTF-8 legacy/SCCV.PRG | tr -d '\r'   # ler um fonte
  ```
