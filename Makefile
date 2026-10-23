.PHONY: help check lint install update

help:
	@echo "Omnitool"
	@echo "========"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  check      Check skill frontmatter (one-line descriptions, at most 1,024 characters, no angle brackets) and the always-loaded rules size"
	@echo "  lint       Check every Markdown file against .markdownlint.jsonc"
	@echo "  install    Install skills and agents to ~/.claude/ and inject rules into ~/.claude/CLAUDE.md"
	@echo "  update     Pull latest changes and run install"

check:
	@./scripts/check-skills.sh

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
