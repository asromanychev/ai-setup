# AI agents, CLI tools, skills, and plugins

BLUE := \033[0;34m
NC := \033[0m
UNAME := $(shell uname)

NPM ?= mise exec -- npm
CLAUDE ?= mise exec -- claude
SKILLS_NPX ?= mise exec -- npx
SKILLS ?= $(SKILLS_NPX) skills
AGENTS_TARGETS := codex claude-code
AGENTS_SKILLS_AGENT_FLAGS := $(foreach agent,$(AGENTS_TARGETS),-a $(agent))

GOOGLE_WORKSPACE_SKILLS := \
	gws-docs \
	gws-docs-write \
	gws-drive \
	gws-sheets

.PHONY: ai bootstrap mise-package mise-install
.PHONY: agents-install agents agents-cli agents-skills agents-claude-plugins
.PHONY: agents-skills-install agents-skills-list agents-skills-check-npx

bootstrap: mise-package mise-install

mise-package:
ifeq ($(UNAME),Darwin)
	@if command -v mise > /dev/null 2>&1; then \
		echo "Install mise - already exists"; \
	else \
		brew install mise && echo "Install mise - installed"; \
	fi
else
	@if command -v mise > /dev/null 2>&1; then \
		echo "Install mise - already exists"; \
	else \
		sudo apt-get install -y mise && echo "Install mise - installed"; \
	fi
endif

mise-install: mise-package
	@echo "Install mise tools"
	@mise install --quiet

ai: bootstrap
	@$(MAKE) agents-install

agents-install: agents agents-cli agents-skills agents-claude-plugins

# --- AI Agents ---

agents:
	@$(NPM) install -g @anthropic-ai/claude-code
	@$(NPM) install -g @openai/codex

# --- CLI tools used by agents ---

agents-cli:
	@$(NPM) install -g @playwright/cli@latest
	@$(NPM) install -g @dapi/tgcli
	@$(NPM) install -g @dapi/docmost-cli
	@$(NPM) install -g @googleworkspace/cli

# --- Skills for agents ---

agents-skills: agents-skills-install

agents-skills-check-npx:
	@$(SKILLS_NPX) --version >/dev/null 2>&1 || (echo "❌ npx not available via mise. Run 'make ai' after bootstrap installs Node.js." && exit 1)

agents-skills-install: agents-skills-check-npx
	@echo "$(BLUE)📦 Installing curated skills...$(NC)"
	@echo "  📥 Installing tgcli from dapi/tgcli"
	@$(SKILLS) add dapi/tgcli --skill tgcli -g $(AGENTS_SKILLS_AGENT_FLAGS) -y
	@echo "  📥 Installing docmost from dapi/docmost-cli"
	@$(SKILLS) add dapi/docmost-cli --skill docmost -g $(AGENTS_SKILLS_AGENT_FLAGS) -y
	@echo "  📥 Installing playwright-cli from microsoft/playwright-cli"
	@$(SKILLS) add microsoft/playwright-cli --skill playwright-cli -g $(AGENTS_SKILLS_AGENT_FLAGS) -y
	@echo "  📥 Installing fpf-simple from CodeAlive-AI/fpf-simple-skill"
	@$(SKILLS) add CodeAlive-AI/fpf-simple-skill --skill fpf-simple -g $(AGENTS_SKILLS_AGENT_FLAGS) -y
	@echo "  📥 Installing prompt-engeneering from CodeAlive-AI/prompt-engineering-skill"
	@$(SKILLS) add CodeAlive-AI/prompt-engineering-skill@prompt-engeneering -g -y
	@for skill in $(GOOGLE_WORKSPACE_SKILLS); do \
		echo "  📥 Installing $$skill from googleworkspace/cli"; \
		$(SKILLS) add googleworkspace/cli --skill "$$skill" -g $(AGENTS_SKILLS_AGENT_FLAGS) -y; \
	done

agents-skills-list:
	@echo "$(BLUE)📋 Curated skills:$(NC)"
	@printf "  tgcli (dapi/tgcli)\n"
	@printf "  playwright-cli (microsoft/playwright-cli)\n"
	@printf "  fpf-simple (CodeAlive-AI/fpf-simple-skill)\n"
	@printf "  prompt-engeneering (CodeAlive-AI/prompt-engineering-skill)\n"
	@for skill in $(GOOGLE_WORKSPACE_SKILLS); do \
		printf "  %s (googleworkspace/cli)\n" "$$skill"; \
	done

# --- Claude Code plugins ---

CLAUDE_PLUGINS_MARKETPLACES = lackeyjb/playwright-skill dapi/claude-code-marketplace

CLAUDE_PLUGINS = \
	playwright-skill@playwright-skill \
	pr-review-fix-loop@dapi

agents-claude-plugins:
	@for mp in $(CLAUDE_PLUGINS_MARKETPLACES); do \
		echo "Adding marketplace $$mp..."; \
		$(CLAUDE) plugins marketplace add $$mp; \
	done
	@for plugin in $(CLAUDE_PLUGINS); do \
		echo "Installing plugin $$plugin..."; \
		$(CLAUDE) plugins install $$plugin; \
	done
