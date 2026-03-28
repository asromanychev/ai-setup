See [PROJECT.md](PROJECT.md) for the product description: **ai-da-collect** (core) and the first plugin **ai-da-collect-telegram**.

This repository currently serves as the **ai-setup course bootstrap**. It contains environment setup, tooling, and agent configuration (Make, mise, scripts), but does not yet include the application codebase.

When application code is added to this repository, update this document to reflect the actual stack, architecture, and workflows.

---

## Stack

### Current (bootstrap layer)
- **Tooling:** GNU Make, Bash, [mise](https://mise.jdx.dev/)
- **Languages:** Ruby (via mise), Node.js
- **CLI tools:** GitHub CLI, direnv, jq, gitleaks, port-selector
- **Agent tools:** Claude Code, Playwright CLI, ccbox  
  (see [SETUP.md](SETUP.md) for full setup details)

### Planned (product layer)
- **Core service:** ai-da-collect (data collection and ingestion)
- **First plugin:** ai-da-collect-telegram (public Telegram channels)
- Application stack (framework, database, background jobs, tests) will be defined when implementation begins.

---

## Key commands

- `make` or `make ai` — bootstrap environment and install required tools
- `make check` — validate toolchain, CLI tools, and authentication
- `make check-context` — validate baseline agent context

Migrations, database commands, and application-level scripts are not yet applicable.

---

## Conventions

- Treat [SETUP.md](SETUP.md) as the single source of truth for environment setup.
- Follow existing patterns in `Makefile` and `scripts/*.sh` when adding new automation.
- Keep compatibility with upstream `dapi/ai-setup` when modifying shared bootstrap behavior.
- Prefer minimal, incremental changes over large refactors.

---

## Constraints

- Do not commit secrets, API keys, or credentials. Use local authentication flows (see SETUP.md).
- Do not modify `Makefile` or `SETUP.md` significantly without explicit intent.
- Do not introduce new global tools (npm, mise, etc.) unless necessary and justified.
- Avoid adding product-specific logic into bootstrap scripts.