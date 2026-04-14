# HW-2: Memory Bank

**Проект:** `ai-da-collect`  
**Репозиторий сдачи:** `ai-setup`  
**Дата актуализации артефактов:** 2026-04-14

## Что требовалось по заданию

Нужно было:

- внедрить `memory-bank/` как минимальную систему routing + durable knowledge;
- превратить `AGENTS.md` / `CLAUDE.md` в routing-таблицу;
- перенести продуктовые, инженерные и процессные знания в соответствующие слои `memory-bank`;
- завести `PRD.md`;
- подготовить `.prompts/` для типовых flow;
- провести несколько feature-циклов с артефактами внутри `memory-bank/`.

## Что сделано в этом репозитории

### 1. Routing вынесен в Memory Bank

- `AGENTS.md` и `CLAUDE.md` больше не дублируют знания о проекте.
- Оба файла отправляют агента в `memory-bank/index.md` как в канонический вход.
- `memory-bank/index.md` стал SSoT для навигации по документации и flow-ам.

### 2. Собран адаптированный Memory Bank

В корне репозитория присутствуют и связаны между собой:

- `memory-bank/prd/PRD.md`
- `memory-bank/project/*`
- `memory-bank/domain/*`
- `memory-bank/engineering/*`
- `memory-bank/ops/*`
- `memory-bank/adr/*`
- `memory-bank/flows/*`
- `memory-bank/WORKFLOW.md`
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`
- `memory-bank/ROADMAP.md`

Это покрывает routing, продуктовый контекст, инженерные правила, ops-слой и lifecycle knowledge.

### 3. Добавлены process artifacts для полного feature-flow

В `memory-bank/issues/` лежат:

- `README.md`
- `RUNBOOK.md`
- `AGENT_PRIMERING.md`
- `MAKE_NEW_ISSUE.md`

Они описывают полный цикл `brief -> spec -> acceptance -> plan -> code -> manual-check -> analysis`, а также правила активации артефактов, scorecards и machine-readable workflow.

### 4. Добавлены праймеры для типовых процессов

В `.prompts/` лежат системные праймеры:

- `triage.md`
- `spec.md`
- `implement.md`
- `review.md`
- `resume.md`
- `compare.md`
- `manual-check.md`

Эти файлы покрывают основные flow-ы новой сессии и отдельных этапов цикла.

### 5. В репозитории есть несколько feature-циклов

Для проверки доступны артефакты задач:

- `#0001 plugin-contract`
- `#0002 source-checkpoint`
- `#0003 sync-orchestration`
- `#0004 s3-blob-storage`
- `#0005 raw-ingest-item`
- `#0006 telegram-client-adapter`
- `#0007 telegram-plugin`
- `#0008 collection-task-sync-job`
- `#0011 ci-github-actions`
- `#0018 collection-task-model`
- `#0019 bearer-auth`
- `#0020 collection-tasks-api`
- `#0021 items-pagination`

Особенно показательные для Week 2:

- `0018-collection-task-model`
- `0019-bearer-auth`
- `0020-collection-tasks-api`
- `0021-items-pagination`

Они показывают уже зрелую схему `memory-bank/issues/<issue>/` с `brief.md`, `spec.md`, `plan.md`, `acceptance-scenarios.md`, `run-instructions.md`, `iterations/` и `hw-reports/`.

## Где смотреть доказательства выполнения

### Routing и вход

- [AGENTS.md](/home/aromanychev/edu/ai-setup/AGENTS.md)
- [CLAUDE.md](/home/aromanychev/edu/ai-setup/CLAUDE.md)
- [memory-bank/index.md](/home/aromanychev/edu/ai-setup/memory-bank/index.md)

### PRD и слои knowledge

- [PRD.md](/home/aromanychev/edu/ai-setup/memory-bank/prd/PRD.md)
- [WORKFLOW.md](/home/aromanychev/edu/ai-setup/memory-bank/WORKFLOW.md)
- [progress.md](/home/aromanychev/edu/ai-setup/memory-bank/progress.md)
- [ROADMAP.md](/home/aromanychev/edu/ai-setup/memory-bank/ROADMAP.md)

### Праймеры

- [.prompts](/home/aromanychev/edu/ai-setup/.prompts)

### Feature cycles

- [0001-plugin-contract](/home/aromanychev/edu/ai-setup/memory-bank/issues/0001-plugin-contract)
- [0002-source-checkpoint](/home/aromanychev/edu/ai-setup/memory-bank/issues/0002-source-checkpoint)
- [0018-collection-task-model](/home/aromanychev/edu/ai-setup/memory-bank/issues/0018-collection-task-model)
- [0019-bearer-auth](/home/aromanychev/edu/ai-setup/memory-bank/issues/0019-bearer-auth)
- [0020-collection-tasks-api](/home/aromanychev/edu/ai-setup/memory-bank/issues/0020-collection-tasks-api)
- [0021-items-pagination](/home/aromanychev/edu/ai-setup/memory-bank/issues/0021-items-pagination)

## Итог

Домашка Week 2 в репозитории закрыта:

- `memory-bank/` адаптирован и лежит в проекте;
- routing вынесен из корневых agent-файлов в индекс;
- есть `PRD.md`;
- есть `.prompts/` под типовые flow;
- есть существенно больше 3–5 feature-циклов, оформленных через `memory-bank/issues/`.
