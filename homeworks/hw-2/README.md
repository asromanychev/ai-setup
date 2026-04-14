# HW-2 Artifact Layout

Эта папка фиксирует сдачный комплект для домашки Week 2: адаптация `memory-bank` и праймеров для проекта `ai-da-collect`, перенесённых в репозиторий `ai-setup`.

## Канонический комплект сдачи

- `memory-bank/`
- `.prompts/`
- `AGENTS.md`
- `CLAUDE.md`
- `report.md`

Проверять домашку следует по корневому `memory-bank/` этого репозитория: именно там лежит актуальный routing, durable knowledge, flow-документация и feature-артефакты.

## Что именно входит в Week 2

### Routing

- `AGENTS.md`
- `CLAUDE.md`
- `memory-bank/index.md`

Корневые agent-файлы сокращены до routing-слоя и отправляют любой новый агент в `memory-bank/index.md` как единый вход.

### Product / Domain / Engineering / Ops

- `memory-bank/prd/PRD.md`
- `memory-bank/project/overview.md`
- `memory-bank/project/data-model.md`
- `memory-bank/domain/*`
- `memory-bank/engineering/*`
- `memory-bank/ops/*`
- `memory-bank/adr/*`

### Workflow и durable process knowledge

- `memory-bank/WORKFLOW.md`
- `memory-bank/flows/*`
- `memory-bank/issues/README.md`
- `memory-bank/issues/RUNBOOK.md`
- `memory-bank/issues/AGENT_PRIMERING.md`
- `memory-bank/issues/MAKE_NEW_ISSUE.md`
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`
- `memory-bank/ROADMAP.md`

### Prompts для праймеринга

- `.prompts/triage.md`
- `.prompts/spec.md`
- `.prompts/implement.md`
- `.prompts/review.md`
- `.prompts/resume.md`
- `.prompts/compare.md`
- `.prompts/manual-check.md`

### Feature-циклы в memory-bank/issues

В репозитории лежат полные или частично полные циклы для задач:

- `0001-plugin-contract`
- `0002-source-checkpoint`
- `0003-sync-orchestration`
- `0004-s3-blob-storage`
- `0005-raw-ingest-item`
- `0006-telegram-client-adapter`
- `0007-telegram-plugin`
- `0008-collection-task-sync-job`
- `0011-ci-github-actions`
- `0018-collection-task-model`
- `0019-bearer-auth`
- `0020-collection-tasks-api`
- `0021-items-pagination`

Это покрывает требование домашки про 3–5 и более feature-циклов через артефакты в `memory-bank/`.

## Что читать проверяющему

1. `AGENTS.md`
2. `memory-bank/index.md`
3. `memory-bank/prd/PRD.md`
4. `memory-bank/WORKFLOW.md`
5. `.prompts/`
6. `memory-bank/issues/0001-plugin-contract/`
7. `memory-bank/issues/0018-collection-task-model/`
8. `memory-bank/issues/0019-bearer-auth/`
9. `memory-bank/issues/0020-collection-tasks-api/`
10. `memory-bank/issues/0021-items-pagination/`
11. `report.md`
