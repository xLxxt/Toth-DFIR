VERSION := $(shell cat VERSION 2>/dev/null || echo 0.2.0)

WRAPPER = python3 wrapper/toth.py

.PHONY: build-base build-dfir build-malware build-network build-all run stop check lint test clean

build-base:
	bash scripts/build-image.sh toth-base

build-dfir:
	bash scripts/build-image.sh toth-dfir

build-malware:
	bash scripts/build-image.sh toth-malware

build-network:
	bash scripts/build-image.sh toth-network

build-all: build-base build-dfir build-malware build-network

run:
	$(WRAPPER) exec dfir

stop:
	$(WRAPPER) stop dfir

check:
	$(WRAPPER) exec dfir toth-check

lint:
	shellcheck $(shell find . -path ./.git -prune -o -name '*.sh' -type f -print)

test:
	bash tests/test_tools_presents.sh

clean:
	docker rmi -f toth-base:latest toth-base:$(VERSION) toth-dfir:latest toth-dfir:$(VERSION) toth-malware:latest toth-malware:$(VERSION) toth-network:latest toth-network:$(VERSION) 2>/dev/null || true
