.PHONY: help install update

help:
	@echo "Omnitool"
	@echo "========"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  install    Install commands to ~/.cursor/commands/"
	@echo "  update     Pull latest changes and run install"

install:
	@./scripts/install.sh

update:
	@echo "Pulling latest changes..."
	@git pull
	@echo ""
	@$(MAKE) install
