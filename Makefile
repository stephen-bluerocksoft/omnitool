.PHONY: help lint install update

help:
	@echo "Omnitool"
	@echo "========"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  lint       Check every Markdown file against .markdownlint.jsonc"
	@echo "  install    Install skills and agents to ~/.claude/ and inject rules into ~/.claude/CLAUDE.md"
	@echo "  update     Pull latest changes and run install"

# Pinned to an exact version for the same reason CI pins it: a new upstream
# release must not change what passes without a commit here.
lint:
	@npx --yes markdownlint-cli@0.48.0 --ignore temp '**/*.md'

install:
	@./scripts/install.sh

update:
	@echo "Pulling latest changes..."
	@git pull
	@echo ""
	@$(MAKE) install
