.PHONY: test lint format check screenshots help

REPO_ROOT := $(realpath $(CURDIR)/..)

help:
	@echo "curate.nvim — make targets"
	@echo "  make test         run luacheck + busted (nlua) + e2e"
	@echo "  make lint         luacheck only"
	@echo "  make format       stylua (write)"
	@echo "  make check        stylua --check + luacheck"
	@echo "  make screenshots  regenerate VHS screenshots"

test:
	@bash $(REPO_ROOT)/scripts/test.sh

lint:
	@luacheck lua plugin spec --no-color

format:
	@stylua lua plugin spec

check:
	@stylua --check lua plugin spec
	@luacheck lua plugin spec --no-color

screenshots:
	@for t in $(REPO_ROOT)/scripts/tape/*.tape; do bash $(REPO_ROOT)/scripts/screenshot.sh $$t; done
