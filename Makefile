SHELL := /bin/bash

.PHONY: build check diagnose dmg test test-edr run

build:
	./scripts/build-app.sh

check:
	./scripts/check.sh

diagnose: check
	.build/native/edr-probe

dmg: build
	./scripts/package-dmg.sh

test: check

test-edr:
	./scripts/test-edr.sh

run: build
	open .build/VividBrightness.app
