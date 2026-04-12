---
title: Product Requirements Documents Index
doc_kind: prd
doc_function: index
purpose: Навигация по PRD проекта. Читать, чтобы найти существующий Product Requirements Document или завести новый по шаблону.
derived_from:
  - ../dna/governance.md
  - ../flows/templates/prd/PRD-XXX.md
status: active
audience: humans_and_agents
---

# Product Requirements Documents Index

Каталог `memory-bank/prd/` хранит instantiated PRD проекта.

PRD нужен, когда задача живёт на уровне продуктовой инициативы или capability, а не одного вертикального слайса. Обычно PRD стоит между общим контекстом из [`../domain/problem.md`](../domain/problem.md) и downstream issues из [`../issues/README.md`](../issues/README.md).

## Когда заводить PRD

- инициатива распадается на несколько issues;
- нужно зафиксировать users, goals, product scope и success metrics до проектирования реализации;
- есть риск смешать продуктовые требования с architecture/design detail.

## Когда PRD не нужен

- задача локальна и полностью помещается в один `spec.md`;
- общий контекст уже покрыт `domain/problem.md`, а issue не требует отдельного product-layer документа.

## Naming

- Формат файла: `PRD-XXX-short-name.md` (или `PRD.md` для единственного главного PRD проекта)
- Один PRD может быть upstream для нескольких issues

## Реестр

| Файл | Title | Status |
| --- | --- | --- |
| [`PRD.md`](PRD.md) | ai-da-collect MVP PRD v4 | `active` |

## Template

- Используй шаблон [`../flows/templates/prd/PRD-XXX.md`](../flows/templates/prd/PRD-XXX.md)
