APP := sccv

HBMK2 := hbmk2

.PHONY: all build clean test run

all: build

build:
	$(HBMK2) $(APP).hbp

clean:
	rm -f $(APP)
	rm -f *.o *.c *.ppo *.log

test:
	@echo "Testes ainda não implementados."

run: build
	./$(APP)
