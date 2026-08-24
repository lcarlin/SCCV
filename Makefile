# S.C.C.V. — reengenharia Clipper Summer '87 → Harbour + SQLite
#
# O Harbour não existe como pacote no Ubuntu 26.04; foi compilado do fonte.
# Ver docs/07-DEPENDENCIAS.md §6.

HB_DIR    ?= /opt/harbour
HBMK2     := $(HB_DIR)/bin/hbmk2
HB_INC    := -I$(HB_DIR)/contrib/hbsqlit3
HB_LIBS   := -lhbsqlit3 -lsqlite3
HBFLAGS   := $(HB_INC) $(HB_LIBS) -gtcgi

BIN       := bin
PREFIX    ?= $(HOME)/.local
ORIGEM    ?= legacy
DESTINO   ?= sccv.db

APP_SRC   := src/app/config.prg src/app/log.prg src/app/erro.prg \
             src/database/conexao.prg src/database/transacao.prg \
             src/database/sql.prg

MIG_SRC   := src/migration/carregador.prg src/migration/extrator.prg \
             src/migration/normalizador.prg src/migration/inconsistencia.prg \
             src/migration/verificador.prg src/database/sql.prg

TESTES    := testa_extrator testa_normalizador testa_inconsistencia testa_migracao \
             testa_verificacao testa_infra

.PHONY: all migrate verificar relatorio test clean check-deps ajuda run install desinstalar

all: $(BIN)/sccv $(BIN)/sccv-migrar

$(BIN)/sccv: src/main.prg $(APP_SRC) | $(BIN)
	$(HBMK2) $< $(APP_SRC) $(HBFLAGS) -o$@

$(BIN)/sccv-migrar: src/migration/migrar.prg $(MIG_SRC) | $(BIN)
	$(HBMK2) $< $(MIG_SRC) $(HBFLAGS) -o$@

$(BIN):
	mkdir -p $(BIN)

# --- migração ---------------------------------------------------------

migrate: $(BIN)/sccv-migrar
	$(BIN)/sccv-migrar --origem $(ORIGEM) --destino $(DESTINO)

migrate-forcar: $(BIN)/sccv-migrar
	$(BIN)/sccv-migrar --origem $(ORIGEM) --destino $(DESTINO) --forcar

verificar: $(BIN)/sccv-migrar
	$(BIN)/sccv-migrar --verificar --origem $(ORIGEM) --destino $(DESTINO)

relatorio: $(BIN)/sccv-migrar
	$(BIN)/sccv-migrar --relatorio --destino $(DESTINO)

run: $(BIN)/sccv
	$(BIN)/sccv --estado

# --- instalação -------------------------------------------------------

install: all
	install -d $(PREFIX)/bin $(PREFIX)/share/sccv
	install -m 755 $(BIN)/sccv         $(PREFIX)/bin/sccv
	install -m 755 $(BIN)/sccv-migrar  $(PREFIX)/bin/sccv-migrar
	install -m 644 database/schema.sql database/views.sql $(PREFIX)/share/sccv/
	install -d $(PREFIX)/../etc 2>/dev/null || true
	@echo "instalado em $(PREFIX)/bin"
	@echo "exemplo de configuração: config/sccv.conf.exemplo"

desinstalar:
	rm -f $(PREFIX)/bin/sccv $(PREFIX)/bin/sccv-migrar
	rm -rf $(PREFIX)/share/sccv

# --- testes -----------------------------------------------------------

test: $(addprefix $(BIN)/,$(TESTES))
	@rc=0; for t in $(TESTES); do \
	  echo "── $$t"; $(BIN)/$$t || rc=1; echo; \
	done; \
	if [ $$rc -eq 0 ]; then echo "TODOS OS TESTES PASSARAM"; else echo "HÁ TESTES FALHANDO"; fi; \
	exit $$rc

$(BIN)/testa_extrator: tests/migration/testa_extrator.prg src/migration/extrator.prg | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

$(BIN)/testa_normalizador: tests/migration/testa_normalizador.prg src/migration/normalizador.prg | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

$(BIN)/testa_inconsistencia: tests/migration/testa_inconsistencia.prg \
        src/migration/inconsistencia.prg src/migration/normalizador.prg src/database/sql.prg | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

$(BIN)/testa_migracao: tests/migration/testa_migracao.prg $(MIG_SRC) | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

$(BIN)/testa_verificacao: tests/migration/testa_verificacao.prg $(MIG_SRC) | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

$(BIN)/testa_infra: tests/unit/testa_infra.prg $(APP_SRC) | $(BIN)
	$(HBMK2) $^ $(HBFLAGS) -o$@

# --- utilidades -------------------------------------------------------

check-deps:
	@test -x $(HBMK2) && echo "hbmk2 ....... $(HBMK2)" || \
	  { echo "hbmk2 AUSENTE em $(HBMK2) — ver docs/07-DEPENDENCIAS.md §6"; exit 1; }
	@test -f $(HB_DIR)/lib/harbour/libhbsqlit3.a && echo "hbsqlit3 .... ok" || \
	  { echo "libhbsqlit3.a AUSENTE"; exit 1; }
	@sqlite3 --version | awk '{print "sqlite3 ..... " $$1}'
	@$(HB_DIR)/bin/harbour -build 2>/dev/null | head -1
	@$(CC) --version 2>/dev/null | head -1 || gcc --version | head -1
	@echo "flags ....... $(HBFLAGS)"

clean:
	rm -rf $(BIN) *.ppo

ajuda:
	@echo "make            compila bin/sccv e bin/sccv-migrar"
	@echo "make run        mostra o estado do ambiente e do banco"
	@echo "make install    instala em PREFIX=$(PREFIX)"
	@echo "make migrate    migra ORIGEM=$(ORIGEM) para DESTINO=$(DESTINO)"
	@echo "make verificar  verifica o banco de destino"
	@echo "make relatorio  regera os relatórios de inconsistências"
	@echo "make test       roda os testes de aceite"
	@echo "make check-deps confere a toolchain"
