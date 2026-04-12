---
title: Use Cases Index
doc_kind: use_case
doc_function: index
purpose: Навигация по instantiated use cases проекта. Читать, чтобы найти канонический сценарий или зарегистрировать новый.
derived_from:
  - ../dna/governance.md
  - ../prd/PRD.md
status: active
audience: humans_and_agents
---

# Use Cases Index

Каталог `memory-bank/use-cases/` хранит канонические пользовательские и операционные сценарии проекта.

Use case нужен для сценария, который живёт на уровне продукта, повторяется во времени и может быть upstream для нескольких issues. Это не замена `SC-*` внутри spec: `SC-*` описывают acceptance-сценарии delivery-единицы, а `UC-*` — устойчивое поведение системы на уровне проекта.

## Когда заводить Use Case

- Появляется новый стабильный пользовательский или операционный сценарий
- Несколько issues реализуют или меняют один и тот же flow
- Нужен canonical owner для trigger, preconditions, main flow и postconditions

## Когда Use Case не нужен

- Сценарий одноразовый и живёт только внутри одной issue
- Это implementation detail, а не продуктовый flow
- Достаточно описать через `SC-*` в spec

## Naming

- Формат файла: `UC-NNN-short-name.md`
- Нумерация монотонная, не переиспользуется

## Реестр

| UC ID | Title | Status | Primary actor | Upstream PRD | Implemented by | Last updated |
|-------|-------|--------|---------------|--------------|----------------|--------------|
| UC-001 | CollectionTask Lifecycle | `draft` | External agent / requester | PRD.md C-1 | #18–#24 | 2026-04-12 |

> **UC-001** — кандидат на первый use case: lifecycle `created→queued→collecting→ready→consumed→deleted/failed`.  
> Создать файл `UC-001-collection-task-lifecycle.md` по шаблону когда issue #18 перейдёт в `in_progress`.
