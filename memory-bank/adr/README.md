---
title: Architecture Decision Records Index
doc_kind: adr
doc_function: index
purpose: Навигация по ADR проекта. Читать, чтобы найти уже принятые решения или завести новый ADR.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Architecture Decision Records Index

Каталог `memory-bank/adr/` хранит instantiated ADR проекта.

- Заводи новый ADR при принятии архитектурного решения с нетривиальным rationale.
- Держи в этом каталоге только реальные decision records, а не черновые исследования.

## Naming

- Формат файла: `ADR-NNN-short-decision-name.md`
- Нумерация монотонная, не переиспользуется
- Заголовок файла совпадает с `title` во frontmatter

## Statuses

- `proposed` — решение сформулировано, но ещё не принято
- `accepted` — принято, является canonical input для downstream-документов
- `superseded` — заменено другим ADR
- `rejected` — рассмотрено и отклонено

## Реестр

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](ADR-001-plugin-contract.md) | Plugin Contract — fetch+map only, no DB writes | `accepted` | 2025-12-01 |
| [ADR-002](ADR-002-rails-api-only-sidekiq.md) | Rails API-only + Sidekiq via ActiveJob, no UI | `accepted` | 2025-12-01 |
| [ADR-003](ADR-003-s3-compatible-storage-stub.md) | S3-compatible Storage as MVP Stub | `accepted` | 2025-12-01 |
| [ADR-004](ADR-004-collection-task-central-entity.md) | CollectionTask as Central Entity (PRD v4) | `accepted` | 2026-04-12 |
