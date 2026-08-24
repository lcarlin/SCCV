# SCCV — Instruções do Projeto

## Objetivo

Este projeto realiza a engenharia reversa e reescrita do sistema SCCV,
originalmente desenvolvido em Clipper Summer '87.

A nova implementação será feita em:

- Harbour Project
- SQLite
- Linux
- UTF-8

## Regra fundamental

O sistema legado é a principal fonte de verdade sobre o comportamento
funcional existente.

NÃO inventar regras de negócio.

Toda regra identificada deve ser documentada.

Quando houver dúvida sobre a intenção do sistema legado, registrar como
pendência em vez de assumir comportamento.

## Modernização

A nova implementação deve:

- eliminar dependências de DOS;
- utilizar UTF-8;
- utilizar SQLite;
- utilizar prepared statements;
- utilizar transações quando necessário;
- possuir tratamento adequado de erros;
- possuir testes;
- possuir validações modernas;
- funcionar nativamente em Linux.

## Validações

Quando aplicável, implementar validação de:

- CPF;
- telefone;
- datas;
- campos obrigatórios;
- valores numéricos;
- limites;
- integridade referencial;
- duplicidade;
- formatos de entrada.

Uma nova validação não deve alterar silenciosamente uma regra de negócio
existente.

## Dados legados

Os arquivos existentes em `legacy/` devem ser tratados como fonte histórica.

Não modificar ou sobrescrever arquivos originais sem autorização explícita.

## Harbour

O ambiente de desenvolvimento utiliza:

    /opt/harbour/bin/harbour
    /opt/harbour/bin/hbmk2

## Banco

SQLite é o banco de dados da nova implementação.

Foreign keys devem ser habilitadas.

SQL deve utilizar prepared statements sempre que houver valores externos.

## Documentação

As descobertas da engenharia reversa devem ser documentadas em `docs/`.

## Processo

Seguir preferencialmente:

1. Descoberta
2. Engenharia reversa
3. Documentação
4. Modelo de dados
5. Migração
6. Implementação
7. Testes
8. Validação
9. Auditoria

Não considerar o projeto concluído apenas porque compila.

## Git

Utilizar commits pequenos e semanticamente claros.

Não misturar refatoração, mudança funcional e documentação sem necessidade.

Não fazer commits contendo dados de produção, credenciais ou arquivos SQLite
de execução.
Harbour:
  /opt/harbour/bin/harbour
  /opt/harbour/bin/hbmk2

Target:
  Linux x86_64
  SQLite
  UTF-8

