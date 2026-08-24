# Engenharia Reversa e Reescrita de Sistema Legado
## Clipper Summer '87 → Harbour Project + SQLite + Linux

Você é responsável pela engenharia reversa, modernização e reescrita completa de um sistema legado originalmente desenvolvido em **CA-Clipper Summer '87**, atualmente executado em ambiente DOS/compatível.

O objetivo final é produzir uma nova implementação funcional do sistema utilizando:

- **Harbour Project**
- **SQLite**
- **Linux**
- Interface de terminal/console, preservando a filosofia operacional do sistema legado sempre que isso fizer sentido.
- Código estruturado, documentado e manutenível.

A nova implementação NÃO deve ser uma simples tradução sintática de Clipper para Harbour.

O trabalho deve ser tratado como uma **engenharia reversa de comportamento + regras de negócio + persistência + modernização controlada**.

---

# 1. OBJETIVO PRINCIPAL

Analise integralmente o sistema legado fornecido neste diretório.

Identifique:

1. Todos os programas `.PRG`.
2. Todos os arquivos `.DBF`.
3. Arquivos `.NTX`, `.NDX`, `.DBT` e quaisquer outros arquivos auxiliares.
4. Menus.
5. Relatórios.
6. Rotinas de entrada de dados.
7. Rotinas de consulta.
8. Rotinas de inclusão, alteração e exclusão.
9. Rotinas de cálculo.
10. Regras de negócio.
11. Validações.
12. Relacionamentos entre arquivos.
13. Índices.
14. Chaves primárias implícitas.
15. Chaves estrangeiras implícitas.
16. Dependências entre módulos.
17. Variáveis globais/memória.
18. Variáveis de ambiente.
19. Arquivos temporários.
20. Sequências de processamento.
21. Rotinas de importação/exportação.
22. Tratamento de erros.
23. Mensagens exibidas ao usuário.
24. Fluxos de navegação.
25. Qualquer comportamento relevante que não esteja explicitamente documentado.

Não assuma que os nomes dos campos, arquivos ou funções representam corretamente suas responsabilidades.

O código legado é a principal fonte da verdade sobre o comportamento atual.

---

# 2. REGRA FUNDAMENTAL: NÃO INVENTAR REGRAS DE NEGÓCIO

Durante toda a análise, diferencie claramente:

- comportamento comprovadamente existente no código;
- comportamento inferido a partir do código;
- comportamento aparentemente desejável;
- melhoria necessária para adequação à atualidade.

NUNCA introduza uma regra de negócio simplesmente porque ela parece razoável.

Quando houver dúvida, registre explicitamente:

> REGRA NÃO DETERMINADA PELO LEGADO

e documente onde a dúvida foi encontrada.

Não faça alterações silenciosas.

---

# 3. FASE 1 — INVENTÁRIO DO SISTEMA LEGADO

Antes de escrever qualquer código novo, faça um inventário completo.

Crie documentação contendo pelo menos:

```text
docs/
├── 00-INVENTARIO.md
├── 01-ARQUITETURA-LEGADO.md
├── 02-MODELO-DADOS.md
├── 03-REGRAS-NEGOCIO.md
├── 04-FLUXOS.md
├── 05-VALIDACOES-LEGADO.md
├── 06-RELATORIOS.md
├── 07-DEPENDENCIAS.md
├── 08-MIGRACAO-DADOS.md
├── 09-DIVERGENCIAS-MODERNIZACAO.md
└── 10-PLANO-IMPLEMENTACAO.md
```

O inventário deve identificar cada arquivo, sua finalidade e suas dependências.

Exemplo:

```text
CLIENTES.PRG
    ├── acessa CLIENTES.DBF
    ├── acessa CIDADES.DBF
    ├── utiliza INDEX CLIENTES.NTX
    ├── chama VALIDACPF()
    └── chama MENUCLIENTE()
```

Não considere o inventário concluído apenas porque os arquivos foram listados.

É necessário compreender o papel funcional de cada componente.

---

# 4. FASE 2 — ENGENHARIA REVERSA DO BANCO

Analise todos os DBFs.

Para cada tabela, identifique:

- nome;
- campos;
- tipos;
- tamanhos;
- casas decimais;
- valores padrão;
- campos obrigatórios;
- campos opcionais;
- campos utilizados como chave;
- índices;
- relacionamentos;
- campos calculados;
- campos de controle;
- campos aparentemente obsoletos;
- campos utilizados apenas para apresentação.

Crie uma representação equivalente em SQLite.

Não faça uma conversão cega:

```text
DBF → SQLite
```

Primeiro compreenda o modelo lógico.

O modelo SQLite deve possuir:

- PRIMARY KEY quando aplicável;
- FOREIGN KEY;
- UNIQUE;
- NOT NULL;
- CHECK constraints quando apropriado;
- índices;
- tipos adequados;
- integridade referencial.

Não utilize SQLite simplesmente como "DBF moderno".

---

# 5. CHAVES E IDENTIFICADORES

Analise cuidadosamente como o sistema legado identifica registros.

Procure:

- números sequenciais;
- códigos manuais;
- chaves compostas;
- códigos reutilizados;
- IDs implícitos;
- combinações de campos;
- índices utilizados como identificadores.

Na nova implementação, determine tecnicamente a melhor representação.

Quando houver uma chave natural existente, preserve-a quando isso fizer parte da regra de negócio.

Quando for necessário introduzir uma chave técnica, documente explicitamente a decisão.

---

# 6. FASE 3 — ENGENHARIA REVERSA DAS REGRAS DE NEGÓCIO

Extraia todas as regras existentes.

Para cada regra, documente:

```text
REGRA:
Origem:
Arquivo:
Função:
Condição:
Comportamento:
Mensagem exibida:
Impacto:
```

Exemplo:

```text
REGRA:
Não permitir cadastro de cliente sem CPF.

Origem:
CLIENTES.PRG

Função:
INCLUIR_CLIENTE()

Condição:
CPF vazio ou inválido.

Comportamento:
Cadastro rejeitado.

Mensagem:
"CPF INVALIDO"

Impacto:
Registro não gravado.
```

A implementação nova deve preservar as regras de negócio existentes, salvo quando uma mudança estiver explicitamente classificada como modernização.

---

# 7. FASE 4 — MODERNIZAÇÃO DAS VALIDAÇÕES

A nova aplicação deve manter a compatibilidade funcional com o legado, mas não deve perpetuar validações inadequadas ou inexistentes que comprometam a qualidade dos dados.

Implemente validações modernas apropriadas.

## CPF

Quando CPF fizer parte do sistema:

- aceitar entrada com ou sem máscara;
- normalizar para armazenamento;
- validar quantidade de dígitos;
- validar dígitos verificadores;
- rejeitar sequências obviamente inválidas;
- definir uma única estratégia de armazenamento.

Exemplo:

Entrada:

```text
123.456.789-09
```

Armazenamento preferencial:

```text
12345678909
```

A apresentação pode utilizar máscara.

Não invente obrigatoriedade de CPF caso o legado permita ausência.

---

# 8. TELEFONES

Campos telefônicos devem ser modernizados.

Considerar:

- telefone fixo;
- celular;
- DDD;
- código do país;
- quantidade válida de dígitos;
- caracteres de máscara;
- armazenamento normalizado;
- apresentação formatada.

Evite armazenar telefone com:

```text
(11) 99999-9999
```

como valor físico do banco.

Prefira armazenamento normalizado e formatação apenas na apresentação.

Não transforme automaticamente um campo antigo em múltiplos campos sem analisar seu uso no legado.

---

# 9. DATAS

Analise todas as datas do sistema.

O formato físico utilizado no SQLite deve ser consistente.

Evite formatos ambíguos como:

```text
DD/MM/YYYY
```

como representação interna.

Prefira representação ISO:

```text
YYYY-MM-DD
```

ou outro formato tecnicamente justificável.

Na interface, entretanto, o sistema pode apresentar:

```text
DD/MM/YYYY
```

quando isso for adequado ao usuário.

Toda entrada de data deve validar:

- formato;
- existência da data;
- limites aplicáveis;
- datas impossíveis;
- datas futuras quando proibidas pela regra de negócio;
- datas anteriores quando proibidas pela regra de negócio.

---

# 10. CAMPOS NUMÉRICOS

Analise cuidadosamente valores monetários, quantidades, percentuais e códigos numéricos.

Não utilize FLOAT para valores monetários sem justificativa técnica.

Para valores financeiros, prefira representação decimal adequada e documentada.

Identifique:

- casas decimais;
- arredondamento;
- truncamento;
- valores negativos;
- zero;
- valores máximos;
- valores mínimos.

Preserve exatamente as regras matemáticas do sistema legado.

---

# 11. CAMPOS TEXTUAIS

Analise:

- tamanho original;
- truncamento;
- preenchimento com espaços;
- comparação case-sensitive/case-insensitive;
- caracteres especiais;
- acentuação;
- conversão de charset.

O sistema legado provavelmente utiliza uma codificação histórica.

Investigue explicitamente possíveis problemas:

```text
ASCII
CP437
CP850
Windows-1252
ISO-8859-1
UTF-8
```

A nova aplicação deverá utilizar **UTF-8**.

Faça conversão dos dados de forma controlada.

---

# 12. CONTROLE DE INTEGRIDADE

A nova aplicação deve impedir situações que o legado eventualmente permitia por limitações técnicas.

Exemplos:

- registros órfãos;
- códigos duplicados;
- CPF duplicado quando isso for proibido;
- campos obrigatórios vazios;
- valores impossíveis;
- datas inválidas;
- referências inexistentes;
- inconsistências entre tabelas.

Entretanto, não introduza restrições que possam quebrar dados legítimos do sistema legado sem antes documentar a divergência.

---

# 13. INTERFACE

A aplicação deve ser adequada ao Linux.

Prioridade:

```text
Harbour
   ↓
Terminal Linux
   ↓
SQLite
```

Evite dependências específicas de:

- DOS;
- Windows;
- caminhos `C:\`;
- `COMMAND.COM`;
- APIs DOS;
- chamadas externas específicas de DOS;
- recursos proprietários do Clipper.

Identifique cada dependência e substitua por mecanismo compatível com Linux.

---

# 14. ARQUIVOS E DIRETÓRIOS

Não utilize caminhos hard-coded como:

```text
C:\SISTEMA\
C:\DADOS\
A:\
B:\
```

Adote configuração apropriada para Linux.

Considere:

```text
/etc/<aplicacao>/
~/.config/<aplicacao>/
var/lib/<aplicacao>/
var/log/<aplicacao>/
```

A escolha deve ser documentada.

A aplicação deve funcionar corretamente independentemente do diretório atual de execução.

---

# 15. PORTABILIDADE HARBOUR

O código deve ser escrito para Harbour moderno.

Evite reproduzir desnecessariamente limitações do Clipper Summer '87.

Quando uma construção antiga puder ser substituída por uma construção moderna de Harbour, faça isso, desde que o comportamento funcional seja preservado.

Identifique explicitamente:

```text
Clipper original
        ↓
Harbour equivalente
        ↓
Justificativa
```

---

# 16. SQLite

A camada de persistência deverá utilizar SQLite.

Utilize:

- prepared statements;
- transactions;
- foreign keys;
- índices adequados;
- WAL quando apropriado;
- tratamento de erros;
- controle de concorrência adequado.

Habilite explicitamente:

```sql
PRAGMA foreign_keys = ON;
```

quando aplicável.

Não construa SQL concatenando diretamente valores fornecidos pelo usuário.

---

# 17. TRANSAÇÕES

Operações que alterem múltiplas tabelas devem utilizar transações.

Exemplo conceitual:

```text
BEGIN
    operação 1
    operação 2
    operação 3

    se tudo OK:
        COMMIT

    caso contrário:
        ROLLBACK
```

O comportamento transacional deve ser compatível com a intenção funcional do sistema legado.

---

# 18. LOG E TRATAMENTO DE ERROS

A aplicação nova deverá possuir tratamento de erros adequado.

Não utilizar:

```text
BREAK
QUIT
```

como estratégia genérica de tratamento de falhas.

Erros devem possuir:

- mensagem compreensível ao usuário;
- registro em log quando apropriado;
- contexto técnico suficiente para diagnóstico;
- tratamento de exceções;
- rollback quando necessário.

Não exponha stack traces técnicos ao usuário final durante operação normal.

---

# 19. RELATÓRIOS

Identifique todos os relatórios existentes.

Para cada um, documente:

- origem dos dados;
- filtros;
- ordenação;
- agrupamentos;
- cálculos;
- totais;
- subtotais;
- formato;
- destino;
- paginação.

Preserve a informação funcional.

Não é necessário reproduzir limitações físicas de impressoras matriciais/DOS.

Caso o legado produza relatório textual, considerar saída compatível com:

- terminal;
- arquivo;
- impressão Linux;
- PDF, quando tecnicamente justificável.

Não implemente PDF automaticamente se isso aumentar desnecessariamente a complexidade.

---

# 20. MIGRAÇÃO DOS DADOS

Crie uma estratégia de migração:

```text
DBF
 ↓
extração
 ↓
normalização
 ↓
validação
 ↓
SQLite
 ↓
verificação
```

A migração deve ser idempotente ou possuir mecanismo seguro de repetição.

Não altere silenciosamente dados inválidos.

Crie relatório de inconsistências contendo:

- registro original;
- campo;
- valor;
- problema;
- ação tomada.

Exemplo:

```text
CLIENTES.DBF
Registro 1523
CPF: 12345678900
Problema: CPF inválido
Ação: registro importado como inválido / pendente
```

A decisão exata deve ser definida após analisar o comportamento do sistema.

---

# 21. TESTES DE REGRESSÃO

Antes de considerar a implementação concluída, crie testes que comparem o comportamento do legado com o sistema novo.

Testar principalmente:

- inclusão;
- alteração;
- exclusão;
- consultas;
- cálculos;
- validações;
- relatórios;
- ordenação;
- filtros;
- regras de negócio;
- casos limites;
- dados inválidos.

Sempre que possível, utilizar os próprios dados do legado como massa de testes.

---

# 22. MATRIZ DE COMPATIBILIDADE

Crie uma matriz:

| Funcionalidade | Clipper | Harbour | SQLite | Status |
|---|---|---|---|---|
| Cadastro | OK | OK | OK | Concluído |
| Consulta | OK | OK | OK | Concluído |
| Relatório | OK | OK | OK | Concluído |

Toda funcionalidade existente no legado deve aparecer nessa matriz.

Não marque algo como concluído apenas porque o código foi escrito.

"Concluído" significa que foi implementado e validado.

---

# 23. CLASSIFICAÇÃO DAS DIFERENÇAS

Toda diferença entre legado e novo sistema deve ser classificada como uma destas categorias:

```text
[COMPATIBILIDADE]
Comportamento preservado.

[CORREÇÃO]
Comportamento claramente defeituoso corrigido.

[MODERNIZAÇÃO]
Melhoria necessária para ambiente moderno.

[SEGURANÇA]
Alteração necessária por segurança.

[VALIDAÇÃO]
Nova validação para garantir integridade dos dados.

[MUDANÇA FUNCIONAL]
Mudança deliberada de comportamento.

[INDEFINIDO]
Não foi possível determinar a intenção original.
```

Nunca esconda uma diferença dentro do código.

---

# 24. NÃO APAGAR O LEGADO

Não altere ou remova os arquivos originais durante a análise.

O sistema legado deve permanecer disponível como referência.

Não sobrescreva:

```text
.PRG
.DBF
.NTX
.NDX
.DBT
```

sem autorização explícita.

---

# 25. ORDEM DE EXECUÇÃO DO TRABALHO

Siga obrigatoriamente esta sequência:

## FASE A — DESCOBERTA

Analise todo o projeto.

Não escreva a aplicação nova ainda.

## FASE B — DOCUMENTAÇÃO

Produza a documentação de engenharia reversa.

## FASE C — MODELO DE DADOS

Defina o modelo SQLite.

## FASE D — MIGRAÇÃO

Implemente a ferramenta de migração DBF → SQLite.

## FASE E — TESTES DE MIGRAÇÃO

Valide quantidade de registros, campos, valores e relacionamentos.

## FASE F — INFRAESTRUTURA HARBOUR

Crie a estrutura da aplicação Harbour.

## FASE G — IMPLEMENTAÇÃO

Implemente os módulos por ordem de dependência.

## FASE H — VALIDAÇÕES

Implemente e teste as validações modernas.

## FASE I — REGRESSÃO

Compare o comportamento com o sistema legado.

## FASE J — AUDITORIA

Execute uma revisão final completa.

---

# 26. ESTRUTURA SUGERIDA

Adapte conforme a análise real:

```text
projeto/
├── legacy/
│   ├── *.PRG
│   ├── *.DBF
│   ├── *.NTX
│   └── ...
│
├── src/
│   ├── main.prg
│   ├── ui/
│   ├── database/
│   ├── models/
│   ├── services/
│   ├── validation/
│   ├── reports/
│   └── migration/
│
├── database/
│   ├── schema.sql
│   └── migrations/
│
├── tests/
│
├── tools/
│
├── docs/
│
├── config/
│
├── Makefile
└── README.md
```

Não considere essa estrutura obrigatória. Adapte-a ao resultado da engenharia reversa.

---

# 27. BUILD

A aplicação deve possuir um processo de build reproduzível no Linux.

Criar, quando apropriado:

```text
Makefile
```

com comandos equivalentes a:

```bash
make
make clean
make test
make migrate
make run
```

O processo deve documentar:

- versão do Harbour;
- dependências;
- bibliotecas;
- compilador;
- flags;
- requisitos do sistema operacional.

---

# 28. EXECUÇÃO

O resultado deverá ser executável em Linux.

Preferencialmente:

```bash
./aplicacao
```

ou:

```bash
aplicacao
```

mediante instalação apropriada.

Não depender de Wine, DOSBox ou máquinas virtuais para executar o sistema novo.

---

# 29. DOCUMENTAÇÃO

O README final deve explicar:

1. O que o sistema faz.
2. Arquitetura.
3. Requisitos.
4. Instalação.
5. Compilação.
6. Configuração.
7. Inicialização.
8. Estrutura do banco.
9. Migração dos dados.
10. Backup.
11. Restore.
12. Logs.
13. Troubleshooting.
14. Testes.

---

# 30. BACKUP E RECUPERAÇÃO

Como o banco será SQLite, documente uma estratégia de backup.

Considere:

```text
backup lógico
backup do arquivo SQLite
integridade do banco
restore
```

O procedimento de restore deve ser testável.

---

# 31. AUDITORIA FINAL

Antes de declarar o projeto concluído, execute uma auditoria final.

Responda objetivamente:

```text
Quantidade de módulos encontrados:
Quantidade de módulos migrados:
Quantidade de DBFs:
Quantidade de tabelas SQLite:
Quantidade de relatórios:
Quantidade de regras de negócio:
Quantidade de validações:
Quantidade de testes:
Quantidade de funcionalidades pendentes:
Quantidade de divergências:
```

Também produza:

```text
% estimado de conclusão
```

Mas não utilize porcentagens subjetivas.

Calcule o percentual a partir de funcionalidades identificadas e seus respectivos estados.

---

# 32. REGRA CONTRA FALSA CONCLUSÃO

NÃO declare:

```text
"migração concluída"
```

simplesmente porque:

- o projeto compila;
- o executável inicia;
- os DBFs foram convertidos;
- os menus existem.

O sistema somente poderá ser considerado concluído quando:

1. As funcionalidades do legado forem identificadas.
2. As regras de negócio forem documentadas.
3. As funcionalidades forem implementadas.
4. Os dados forem migráveis.
5. As validações estiverem implementadas.
6. Os testes estiverem executados.
7. As divergências estiverem documentadas.
8. O sistema puder ser compilado e executado no Linux.
9. A regressão funcional estiver satisfatória.

---

# 33. COMO VOCÊ DEVE TRABALHAR

Você está autorizado a:

- criar arquivos;
- criar diretórios;
- analisar código;
- criar scripts;
- criar testes;
- criar schema SQLite;
- criar ferramentas de migração;
- compilar;
- executar testes;
- corrigir erros;
- refatorar;
- documentar.

Porém:

**não pule etapas de análise para começar a programar.**

Primeiro compreenda.

Depois documente.

Depois modele.

Depois implemente.

Depois valide.

Depois audite.

---

# 34. PRIMEIRA TAREFA

Neste primeiro momento, NÃO comece a reescrever o sistema.

Faça exclusivamente a **FASE DE DESCOBERTA E ENGENHARIA REVERSA**.

Analise todos os arquivos disponíveis.

Ao terminar essa fase, apresente:

1. Inventário completo.
2. Arquitetura identificada.
3. Modelo de dados preliminar.
4. Fluxos funcionais.
5. Regras de negócio encontradas.
6. Validações existentes.
7. Dependências externas.
8. Problemas encontrados.
9. Pontos que exigem decisão.
10. Plano detalhado de implementação.

Crie os documentos correspondentes em `docs/`.

Somente após concluir essa análise será iniciada a implementação.

**Não peça confirmação para cada pequena decisão técnica.**

Quando uma decisão puder ser tomada tecnicamente sem alterar regra de negócio, tome a decisão, documente-a e prossiga.

Quando uma decisão puder alterar uma regra de negócio existente, NÃO invente. Registre a questão como pendência.

O objetivo é produzir uma implementação moderna em **Harbour + SQLite + Linux**, preservando a semântica e as regras do sistema legado, mas eliminando as limitações técnicas inerentes ao Clipper Summer '87 e incorporando validações e práticas atuais de qualidade de dados.