WRAPPER = python3 wrapper/toth.py

.PHONY: build-base build-dfir build-malware build-network build-all run stop check

build-base:
	bash images/base/build.sh

build-dfir:
	bash images/dfir/build.sh

build-malware:
	bash images/malware/build.sh

build-network:
	bash images/network/build.sh

build-all: build-base build-dfir build-malware build-network

run:
	$(WRAPPER) exec dfir

stop:
	$(WRAPPER) stop dfir

check:
	$(WRAPPER) exec dfir toth-check
