.DEFAULT_GOAL := help

.PHONY: help install check

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install project dependencies
	mise install

check: ## Validate environment
	@echo "Checking tools..."
	@which claude && claude --version || echo "WARN: claude not found"
	@which gh && gh --version | head -1 || echo "WARN: gh not found"
	@echo "OK"
