# 05 — VALIDAÇÕES EXISTENTES NO LEGADO

## 1. Panorama

O legado possui **apenas 6 tipos de validação**, todas de superfície:

| Mecanismo | Ocorrências | Força |
|---|---:|---|
| `PICTURE` (máscara de entrada) | ~120 | Restringe o que pode ser digitado; **não valida o conteúdo** |
| `VALID` com `$` (substring) | 12 | Fraca — ver §3 |
| `SEEK` + `FOUND()` (existência de FK) | 14 | Efetiva enquanto o índice estiver correto |
| `EMPTY()` (campo vazio) | 30 | Usada só para **controle de fluxo**, nunca como obrigatoriedade |
| `ISPRINTER()` | 8 | Disponibilidade de dispositivo |
| Comparação numérica (estoque mínimo) | 1 | Alerta não bloqueante |

**Não existe nenhuma validação de:** dígito verificador de CPF/CNPJ, formato de CEP, faixa de datas, obrigatoriedade de campo, unicidade além do `SEEK` de fluxo, coerência entre campos, valor mínimo/máximo, ou integridade referencial na exclusão.

---

## 2. Máscaras `PICTURE` — catálogo completo

### 2.1 Códigos

| Campo | Módulo | Máscara | Tipo no DBF | Observação |
|---|---|---|---|---|
| `CODCLI` | `CVMTCLI`, `CVMTVPEC`, `CVMTVREP`, `CVMTPENT` | `"99999"` | `N(5,0)` | Coerente |
| `CODFUN` | `CVMTFUNC`, `CVMTVPEC`, `CVMTVREP`, `CVMTPENT`, `CVMTCON` | `"99999"` | **`N(6,0)`** | Máscara menor que o campo — códigos ≥ 100000 são inatingíveis pela UI |
| `CODFOR` | `CVMTFOR` | `"99999"` | **`N(6,0)`** | idem |
| `CODFOR` | `CVMTPEC`, `CVMTALMX` | `"999999"` | `N(6,0)` | **Inconsistente com `CVMTFOR`** |
| `CODPEC` | `CVMTPEC`, `CVMTVPEC`, `CVMTVREP` | `"99999"` | **`N(6,0)`** | Máscara menor |
| `CODALM` | `CVMTALM` | `"99999"` | — | tabela obsoleta |
| `CODALM` | `CVMTALMX` | `"999999"` | `N(6,0)` | Coerente |
| `CODCAR` | `CVMTFRO`, `CVMTPENT`, `CVMTCON` | `"99999"` | `N(5,0)` | Coerente |
| `CODCON` | `CVMTCON2` | `"99999"` | `N(5,0)` | Coerente |
| `CODGRU` | `CVMTCON` | `"99999"` | `N(5,0)` | Coerente (somente leitura) |
| `CODPED`, `CODITE` | `CVMTPED` | `"99999"` | `N(5,0)` | Módulo inoperante |

**Constatação:** 4 campos numéricos têm capacidade de armazenamento **maior** do que a máscara permite digitar. Na prática, a máscara é o limite efetivo. Ver 09/D-20.

### 2.2 Textos

| Máscara | Efeito | Campos |
|---|---|---|
| `"@!"` | Converte para **maiúsculas**, tamanho da variável | Nome, endereço, cidade, cargo, descrição, fábrica, CGC, item |

Todos os campos texto do sistema usam `"@!"` — não há campo que preserve caixa mista na entrada. Os dados existentes com caixa mista (`"BatMan"`, `"Gottan CiTY"`, `"Uno Mile ELX"`) foram gravados por versões antigas ou editados externamente.

### 2.3 Documentos e contatos

| Campo | Módulo | Máscara | Armazenamento resultante |
|---|---|---|---|
| `TELCLI` | `CVMTCLI` | `"(XXXX)XXX-XXXX"` | **A máscara é gravada literalmente**: `(0143)051-2382` |
| `TELCLI` | `CVCLI`, `CVCONS` (mortos) | `"(9999)999-9999"` | idem, mas exige dígitos |
| `TELFOR` | `CVMTFOR` | `"(XXXX)XXX-XXXX"` | idem |
| `RGCLI` | `CVMTCLI`, `CVCLI`, `CVCONS` | `"XXX.XXX.XXX-X"` | `636.363.636-3` |
| `CICCLI` (CPF) | `CVMTCLI` | `"XXXXXXXXXXX-XXX"` | **15 posições** para um CPF de 11 dígitos |
| `CICCLI` (CPF) | `CVCLI`, `CVCONS` (mortos) | `"@!"` | Livre |
| `CGCFAB` (CNPJ) | `CVMTFOR` | `"@!"` | **Sem máscara nenhuma** |
| `CEPCLI` | `CVMTCLI` | `"99999-999"` | Campo é `N(8,0)` — a máscara é só de exibição; grava número |
| `CEPFOR` | `CVMTFOR` | `"XXXXX-XXX"` | Campo `C(9)` — grava `18800-000` |
| `CEPFUN` | `CVMTFUNC` (inclusão) | `"XXXXX-XXX"` | Campo `C(9)` |
| `CEPFUN` | `CVMTFUNC` (**alteração**) | **`"XXXXXX-XXX"`** | **10 posições em campo de 9** — origem do dado malformado `188000-00` |
| `CHASSI`, `CHASDO` | `CVMTFRO` | `"999999999999"` | `N(12,0)` |

**Achado:** a máscara `"XXXXXX-XXX"` no caminho de alteração de `CVMTFUNC.PRG:97` difere da do caminho de inclusão (`"XXXXX-XXX"`, linha 47). O registro 1 de `CVBFUNC` contém `188000-00` — exatamente o resultado de digitar um CEP na máscara errada e truncar em 9 caracteres.

### 2.4 Datas

Todas usam `"99/99/99"` — **ano de 2 dígitos**. Com `SET DATE BRIT` e `SET EPOCH` no default (1900), digitar `10/10/10` produz **10/10/1910**.

| Campo | Módulo |
|---|---|
| `NASCLI`, `DATCLI` | `CVMTCLI`, `CVCLI`, `CVCONS` |
| `DATCOMCAR` | `CVMTFRO` |
| `DATCON` | `CVMTCON` (`"99/99/99"` na criação, `"@e"` na adesão) |
| `DATAV` | `CVMTPENT` |

Consequência nos dados: 12 datas anteriores a 1970 (ver `02-MODELO-DADOS.md` §8.4).

### 2.5 Valores monetários e quantidades

| Máscara | Faixa efetiva | Campos |
|---|---|---|
| `"999,999,999.99"` | 0 a 999.999.999,99 | `SALFUN`, `COMFUN`, `VALPRE` |
| `"9,999,999.99"` | 0 a 9.999.999,99 | `VALUNI`, `VALALM`, `VALCAR` (em `CVMTPENT`) |
| `"@E 9,999,999.99"` | idem, formato europeu (`.` milhar, `,` decimal) | `VALALM` em `CVMTALM`, `VALCAR` em `CVMTFRO` |
| `"@E 99,999,999.99"` | 0 a 99.999.999,99 | `MSUBTOT` em `CVMTVREP` |
| `"999999999999.99"` | 12 inteiros + 2 decimais | `VALUNI` em `CVPECAS` (morto) |
| `"99999"` | 0 a 99999 | `QTDPEC`, `QTDMIN` (em `CVMTVPEC`), `MQTVEND` |
| `"9999"` | 0 a 9999 | `MQUANTC` em `CVMTVREP` |
| `"999"` | 0 a 999 | `QTDMIN`, `QUANTALM`, `QUANALM`, `QUANTCAR`, `NUMPAR`, `MNUMFALA` |
| `"99"` | 0 a 99 | `NUMMES`, `NUPGRU` |

**Nenhuma máscara aceita sinal negativo.** Porém, o cálculo interno pode produzir negativo (RN-020, RN-029) e o `REPLACE` grava sem passar por máscara. É exatamente assim que `CVBGRUCO.NUMMES` acabou com `-2`, `-3` e `**`.

**Inconsistência crítica:** o `@E` (formato europeu) é aplicado a **alguns** campos monetários e não a outros, no mesmo sistema. Em `CVMTFRO` o valor do carro usa `"@e 9,999,999.99"`; em `CVMTPENT` o mesmo campo é exibido com `"9,999,999.99"`. O operador vê o mesmo dado com separadores trocados em telas diferentes.

---

## 3. Cláusulas `VALID`

### 3.1 UF do cliente — a única validação de domínio

```clipper
@ 13,22 GET MUFCLI PICT "!!" VALID (mufcli $ "AC,Al,AM,AP,BA,CE,DF,ES,FN,GO,MA,MG,MS,MT,PA,PB,PE,PI,PR,RJ,RN,RO,RR,RS,RC,SE,SP")
```

Ocorre em `CVMTCLI.PRG:26` (inclusão) e `:110` (alteração), `CVCLI.PRG`, `CVCONS.PRG`.

**Defeitos:**

| Problema | Detalhe |
|---|---|
| **UFs faltantes** | `SC` (Santa Catarina) e `TO` (Tocantins) **não estão na lista** |
| **UF extinta** | `FN` = Fernando de Noronha, extinto como território em 1988 |
| **UF inexistente** | `RC` não corresponde a nenhuma unidade federativa |
| **Caixa inconsistente** | `Al` está em caixa mista; a máscara `"!!"` força maiúsculas, então **`AL` (Alagoas) é rejeitado** |
| **`$` é substring, não igualdade** | Qualquer substring da cadeia passa: `"A"`, `"C,"`, `",A"`, `"CE"`, e até `""` (string vazia é substring de tudo) |
| **Campo vazio passa** | `EMPTY(uf)` → `"" $ "AC,Al,..."` é `.T.` |
| **Só na inclusão em `CVMTCLI`** | Na exibição inicial do caminho de alteração a máscara é `"@!"` **sem `VALID`** (linha 84); o `VALID` só reaparece dentro do sub-laço de edição |

Resultado nos dados: 22 clientes, UFs `SP` (18), `MA` (1), `GO` (1), `SP` nos demais — nenhum inválido gravado, por sorte.

### 3.2 Demais `VALID`

| Expressão | Local | Comentário |
|---|---|---|
| `MCONSOR $ "SN"` | `CVMTCLI` (2×), `CVCLI`, `CVCONS` | Substring: `""` passa → `CONSOR` vazio é aceito |
| `ALTER $ "ARE"` | 7 módulos de manutenção | idem; `""` passa e cai no `ELSE` implícito (nenhum ramo) → **grava sem escolha** |
| `V_OBS $ "SN"` | `CVMTFOR` (2×) | idem |
| `msort $ "SN"` | `CVMTCON2` | idem |
| `conf $ "SN"` | `SAIDA()` | idem — `""` passa e **não** entra no ramo `"S"`, logo não sai (comportamento tolerável) |
| `SN $ "SN"` | `CONFIRMA()` | idem — `""` passa e retorna `.F.` (equivale a "não") |

**Padrão sistemático:** o uso de `$` em vez de `==` torna **toda** validação de domínio permeável à string vazia. Como o valor inicial da variável é `" "` (espaço) e a máscara `"!"` converte espaço em espaço, o operador consegue passar por qualquer confirmação apenas pressionando ENTER.

---

## 4. Validação de existência (FK) por `SEEK`

| Origem | Campo | Tabela consultada | Bloqueia? | Mensagem |
|---|---|---|---|---|
| `CVMTPEC` | `CODFOR` | `CVBFORNE` | Sim (`LOOP`) | `Codigo nao cadastrado` |
| `CVMTALMX` | `CODFORALM` | `CVBFORNE` | Sim (`LOOP`) | `Codigo nao cadastrado` |
| `CVMTVPEC` | `CODCLI` | `CVBCLIEN` | Não — oferece cadastro | `Cliente nao Cadastrado; Deseja Cadastra-lo ` |
| `CVMTVPEC` | `CODPEC` | `CVBPECAS` | Sim (`LOOP`) | `Codigo nao Cadastrado; Tecle <ENTER> ` |
| `CVMTVPEC` | `CODFUN` | `CVBFUNC` | Sim (`LOOP`) | `Funcionario nao Cadastrado; Tecle <ENTER> ` |
| `CVMTVREP` | `CODCLI` | `CVBCLIEN` | Não — oferece cadastro | idem |
| `CVMTVREP` | `CODFUN` | `CVBFUNC` | Sim (`LOOP`) | idem |
| `CVMTVREP` | `CODPEC` | `CVBPECAS` (índice errado) | Sim (`LOOP`) | `Peca nao Cadastrada; Tecle <ENTER> ` |
| `CVMTPENT` | `CODCLI` | `CVBCLIEN` | Sim (`LOOP`) | `Cliente nao Cadastrado; Deseja Cadastra-lo ` (texto enganoso) |
| `CVMTPENT` | `CODCAR` | `CVBFROTA` | Sim (`LOOP`) | `Carro nao Cadastrado; Tecle <ENTER> ` |
| `CVMTPENT` | `CODFUN` | `CVBFUNC` | Sim (`LOOP`) | `Funcionario nao Cadastrado; Tecle <ENTER> ` |
| `CVMTCON` | `CODCAR` | `CVBFROTA` | Sim (`RETURN`) | `Carro näo Cadastrado` |
| `CVMTCON` | `CODFUN` | `CVBFUNC` | Sim (`LOOP`) | `Funcionario nao Cadastrado` |
| `CVMTCON2` | `CODCON` | `CVBGRUCO` | Sim (`RETURN`) | `Consorciado näo Cadastrado` |

**Nenhuma validação na exclusão.** É possível excluir um cliente com vendas pendentes, um fornecedor com peças cadastradas, um funcionário com comissões — e o `PACK` de `SAIDA()` (RN-038) torna a perda definitiva.

---

## 5. `EMPTY()` — controle de fluxo, não obrigatoriedade

O padrão `IF EMPTY(Mcod) .AND. LASTKEY() = 13` aparece 30 vezes. Sua função é **detectar a intenção de abrir a tabela de códigos**, não exigir preenchimento.

Consequência: **nenhum campo do sistema é obrigatório**. É possível gravar um cliente com nome, endereço, CPF, telefone e todas as datas em branco. Não há `VALID .NOT. EMPTY(...)` em lugar algum.

Evidência nos dados: `CVBFORNE` registro 2 (`WILSON DOS SANTOS JUNIOR`) tem **9 dos 11 campos em branco**.

---

## 6. Validação de dispositivo

`ISPRINTER()` é chamada em 8 relatórios, com dois padrões:

```clipper
* Padrão A (CVRCLI, CVRFUNC, CVRFOR, CVRPECAS, CVRALM, CVRFROTA):
IF .NOT. ISPRINTER()
   MENSAGEM("VERIFIQUE A IMPRESSORA",12)     ← pausa
ENDIF
IF .NOT. ISPRINTER()                          ← testa de novo
    CLOSE DATABASES ; RESTORE SCREEN ; RETURN
ENDIF

* Padrão B (opção ETIQUETA, e CVRSERV para impressora):
DO WHILE .NOT. ISPRINTER()
   MEIO("Impressora nao Preparada; [ENTER] p/ Continuar ou [ESC] P/ Sair",24)
   if inkey(.1) = 27
      return
   endif
ENDDO
```

O padrão B é um laço de espera ativa com timeout de 0,1 s — o operador precisa manter ESC pressionado para sair.

---

## 7. Codificação de caracteres — determinação empírica

**Resultado: CP860 (Português — DOS).**

Método: os fontes contêm bytes ≥ 0x80 apenas em literais de tela. Testando a decodificação:

| Byte | Contexto | CP437/CP850 | **CP860** | Palavra pretendida |
|---|---|---|---|---|
| `0x87` | `Manuten<87><84>o` | `ç` | `ç` | Manuten**ç**ão |
| `0x84` | idem | `ä` ✗ | **`ã`** ✓ | Manutenç**ã**o |
| `0xA2` | `Relat<A2>rio` | `ó` | `ó` | Relat**ó**rio |
| `0xA0` | `Funcion<A0>rios` | `á` | `á` | Funcion**á**rios |
| `0x94` | `Observa<87><94>es` | `ö` ✗ | **`õ`** ✓ | Observa**çõ**es |
| `0xA7` | `N<A7>12` | `º` | `º` | N**º**12 |
| `0xB3` | `Codigo Peca<B3>Descricao` | `│` | `│` | separador de coluna |
| `0xB0`,`0xB2`,`0xDB` | barra de progresso | `░`,`▓`,`█` | `░`,`▓`,`█` | idem |

Decisiva: `0x84` e `0x94`. Em CP437/CP850 produzem `ä`/`ö` (alemão), palavras sem sentido em português. Em **CP860** produzem `ã`/`õ`, formando "Manutenção", "Descrição", "Comissão", "Observações", "não", "Consórcios", "Peças", "Serviços", "Funcionários".

Os caracteres de desenho de caixa (0xB0–0xDF) são idênticos entre CP437, CP850 e CP860, o que explica por que uma leitura em CP850 parece "quase certa".

**Nos dados (`.DBF`):** nenhum byte ≥ 0x80 foi encontrado exceto `0xA7` (`º`) em `CVBCLIEN.ENDCLI` — mesmo glifo nos três *codepages*. Os textos foram digitados sem acentuação. Ainda assim, a migração deve declarar **CP860 → UTF-8** para os fontes e para qualquer dado futuro.

Ação de migração: ver `08-MIGRACAO-DADOS.md` §4.

---

## 8. Validações AUSENTES que a nova implementação deve introduzir

| # | Validação ausente | Evidência do impacto | Classificação |
|---|---|---|---|
| V-01 | **Dígito verificador de CPF** | 22 clientes; nenhum CPF real (`666666666666666`, `465465465465465`, `/7556465464`) | [VALIDAÇÃO] |
| V-02 | **Dígito verificador de CNPJ** | `CGCFAB` = `27439872194873285783` (20 díg.), `3484378438743]` | [VALIDAÇÃO] |
| V-03 | **Normalização de CPF/CNPJ** | Máscara gravada junto com o dado, formatos heterogêneos | [MODERNIZAÇÃO] |
| V-04 | **Formato de CEP (8 dígitos)** | `CEPFUN` = `188000-00`; `CEPCLI` = `798797`, `5877` | [VALIDAÇÃO] |
| V-05 | **Consistência de tipo de CEP** | `N(8)` em cliente vs. `C(9)` em fornecedor/funcionário | [CORREÇÃO] |
| V-06 | **Normalização de telefone (DDD + número)** | `(0143)051-2382`, `(0143) 51-2665`, `(0143)51 -2529` | [MODERNIZAÇÃO] |
| V-07 | **Ano de 4 dígitos nas datas** | 12 datas anteriores a 1970 | [CORREÇÃO] |
| V-08 | **Faixa válida de data de nascimento** | `1901-01-01`, `1911-11-11` | [VALIDAÇÃO] |
| V-09 | **Data de venda não futura / não absurda** | `DATAV` = `1901-11-11` | [VALIDAÇÃO] |
| V-10 | **Lista completa e correta de UFs** | `SC`/`TO` ausentes; `FN`/`RC` inválidas; `Al` inalcançável | [CORREÇÃO] |
| V-11 | **Igualdade em vez de substring nos domínios** | `$` deixa passar string vazia em 12 pontos | [CORREÇÃO] |
| V-12 | **Obrigatoriedade de nome** | Fornecedor 2 com 9 campos vazios | [VALIDAÇÃO] |
| V-13 | **Unicidade de CPF** | Não verificada | [VALIDAÇÃO] |
| V-14 | **Quantidade não negativa** | `QTDPEC` pode ficar negativo (RN-028/029) | [VALIDAÇÃO] |
| V-15 | **Prestações restantes ≥ 0** | Dados reais: `-2`, `-3`, `**` | [CORREÇÃO] |
| V-16 | **Valor monetário não negativo** | Sem validação | [VALIDAÇÃO] |
| V-17 | **Integridade referencial na exclusão** | `PACK` sem verificação em `SAIDA()` | [VALIDAÇÃO] |
| V-18 | **Coerência da faixa de chassi** (`fim ≥ ini`) | Editável livremente | [VALIDAÇÃO] |
| V-19 | **Capacidade do campo ≥ capacidade da máscara** | 4 campos com máscara menor que o campo | [CORREÇÃO] |
| V-20 | **Sincronismo dos agregados** | `CVVPEC`/`CVVCAR` divergem em até 11.062 unidades | [CORREÇÃO] |

> **Regra observada:** nenhuma dessas validações substitui uma regra de negócio existente. Todas cobrem lacunas em que o legado **não decidia nada**. As três marcadas `[CORREÇÃO]` que alteram comportamento observável (V-10, V-11, V-15) estão detalhadas em `09-DIVERGENCIAS-MODERNIZACAO.md`.

---

## 9. Validações que NÃO devem ser introduzidas

Conforme o briefing §2 e §7, as seguintes obrigatoriedades **não existem no legado** e não serão criadas:

| Não introduzir | Porquê |
|---|---|
| **CPF obrigatório** | O legado permite cliente sem CPF (`CICCLI` pode ficar em branco); briefing §7 é explícito |
| **CNPJ obrigatório para fornecedor** | idem |
| **Telefone obrigatório** | Fornecedor 2 existe sem telefone |
| **Endereço/cidade/UF obrigatórios** | Cliente 14 tem `CIDCLI` vazio |
| **Bloqueio de venda com estoque insuficiente** | RN-028 é explicitamente um **alerta com confirmação**, não um bloqueio |
| **Bloqueio de venda com frota zerada** | RN-035 é apenas aviso posterior à baixa |
| **Unicidade de `CVBPENT`/`CVPECAS`** | Não há chave natural; duplicatas legítimas existem (mesmo cliente, mesmo carro, mesmo dia) |
| **Exigir cota de consórcio quando `CONSOR="S"`** | 13 dos 17 casos reais violariam; ver Q-08 |
| **Data de venda obrigatória** | `CVMTPENT` nem sequer lê o `GET` de data (§ Fluxos 7) |
