# ============================================================================
# Dotfiles tasks. `make` or `make help` lists them.
# Recipes only call the repo's own scripts; the logic stays in those scripts.
# ============================================================================
SHELL := /bin/bash
.DEFAULT_GOAL := help

BASH_SCRIPTS := install.sh update-versions.sh verify-status.sh test/uninstall.sh
ZSH_SCRIPTS  := doctor.zsh test/suite.zsh test/mock_tools.zsh \
                $(wildcard core/*.zsh plugins/*.zsh platform/*.zsh) \
                $(shell find modules -name '*.zsh' | sort) \
                $(filter-out functions/.%,$(wildcard functions/*))

.PHONY: help install setup tools reinstall doctor test lint verify-status \
        versions versions-apply check refresh clean

help: ## List the tasks
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Bootstrap this machine (packages, Oh My Zsh, font, pinned tools, loader), then open zsh
	bash install.sh

setup: ## Install without opening a shell (step 7 already runs the doctor)
	bash install.sh --no-shell

tools: ## Only the pinned tools in ~/.local/bin (no apt, no sudo)
	bash install.sh --tools-only

reinstall: ## Install again and reinstall tools already at their pin
	bash install.sh --force

doctor: ## Health check: required tools, flags and aliases (exit 1 if one is missing)
	zsh doctor.zsh

test: ## Run the test suite (mocked tools, non-interactive)
	zsh -f test/suite.zsh

lint: ## Syntax-check every script; shellcheck too when installed
	@fail=0; \
	for f in $(BASH_SCRIPTS); do bash -n "$$f" || fail=1; done; \
	for f in $(ZSH_SCRIPTS); do zsh -n "$$f" || fail=1; done; \
	if command -v shellcheck >/dev/null; then shellcheck $(BASH_SCRIPTS) || fail=1; \
	else echo "shellcheck not installed: bash -n only"; fi; \
	if [ $$fail -eq 0 ]; then echo "✅ lint ok"; else echo "❌ lint failed"; fi; \
	exit $$fail

check: lint test ## lint + test (run before committing)

verify-status: ## Visual Starship git-pill check (needs real starship)
	bash ./verify-status.sh

versions: ## Show newer pins past the .freshness window (network)
	bash ./update-versions.sh

versions-apply: ## Write newer pins to versions.toml (network)
	bash ./update-versions.sh --apply

refresh: ## Drop the cached tool detection and init output (same as the `refresh` alias, without exec zsh)
	rm -f "$$HOME/.cache/dotfiles_tools" "$$HOME/.cache/starship_init.zsh" "$$HOME/.cache/atuin_init.zsh" \
	      "$$HOME/.cache/zoxide_init.zsh" "$$HOME/.cache/gh_completion.zsh"

clean: ## Remove generated test artifacts
	rm -rf .verify-status-worktree /tmp/dotfiles_test_home /tmp/dotfiles_mock_bin
