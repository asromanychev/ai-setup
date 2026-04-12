---
title: Glossary
doc_kind: governance
doc_function: canonical
purpose: Определения ключевых терминов проекта. Устраняет разночтения между людьми и агентами.
derived_from:
  - dna/principles.md
status: active
audience: humans_and_agents
---

# Glossary

## Термины документации

### SSoT

`SSoT` (`Single Source of Truth`) — принцип, по которому каждый факт имеет ровно одного canonical owner. Если один и тот же факт начинает жить в нескольких местах — это дефект документации.

### Canonical Owner

`Canonical owner` — документ, который владеет конкретным фактом и имеет приоритет над downstream-описаниями. Изменение такого документа — изменение источника истины.

### Governed Document

`Governed document` — markdown-файл внутри `memory-bank/`, подчиняющийся governance-правилам: валидный YAML frontmatter, понятная роль документа, явные связи с upstream через `derived_from`.

### Authoritative Document

`Authoritative document` — governed-документ со `status: active`, считающийся действующим источником истины.

### Upstream / Downstream

`Upstream` — документ-источник, от которого наследуется контекст, ограничения или решения.  
`Downstream` — документ, который использует этот контекст и не должен ему противоречить.

### Derived From

`Derived from` — frontmatter-поле, перечисляющее прямые upstream-документы. Делает происхождение знания явным.

### Dependency Tree

`Dependency tree` — граф зависимостей документов, построенный через `derived_from`. Authority течёт upstream → downstream. Карта графа: [`dependency-tree.md`](../dependency-tree.md).

### Progressive Disclosure

`Progressive disclosure` — правило организации документации: сначала короткий обзор, потом ссылки в детали. Удерживает верхний уровень читаемым.

### Index-First

`Index-first` — каждый значимый документ достижим из индекса. Orphan-файл, на который ничто не ссылается, считается дефектом knowledge layer.

### Durable Knowledge Layer

`Durable knowledge layer` — устойчивый слой знаний: набор versioned документов, сохраняющий контекст между сессиями, людьми и изменениями кода. В проекте — `memory-bank/`.

---

## Термины домена ai-da-collect

### CollectionTask

`CollectionTask` — центральная сущность MVP. Задание на сбор контента от конкретного `requester_id` с lifecycle `created → queued → collecting → ready → consumed → deleted / failed`.  
Canonical owner: [`memory-bank/prd/PRD.md`](prd/PRD.md).

### Plugin

`Plugin` — изолированный модуль сбора данных из одного источника (например, Telegram). Реализует контракт `Collect::Plugin`: только fetch + map, не пишет в БД напрямую.  
Canonical owner: [`core/README.md`](../core/README.md).

### sync_step

`sync_step` — атомарная единица работы плагина: один вызов, один checkpoint. Инвариант: при повторном вызове результат идемпотентен в пределах cursor.  
Canonical owner: [`core/README.md`](../core/README.md).

### Ingestion

`Ingestion` — процесс приёма и буферизации сырого контента от плагина. Сервис — временный буфер; семантика, нормализация и embeddings — вне MVP.

### Requester

`Requester` — внешний агент или система, создающая `CollectionTask`. Идентифицируется `requester_id`; аутентификация — Bearer token.

---

## Термины процесса (issues workflow)

### Brief

`Brief` — первый артефакт задачи. Фиксирует проблему, цель, скоуп и ожидаемый результат. Canonical owner: `memory-bank/issues/<slug>/brief.md`.

### Spec

`Spec` — спецификация поведения: контракты, acceptance scenarios, non-scope. Производный от brief.

### Plan

`Plan` — план исполнения: preconditions, атомарные шаги, checkpoints. Производный от spec.

### Issue Slug

`Issue slug` — уникальный идентификатор папки задачи в формате `NNNN-short-description` (4-значный номер с нулями + краткое описание на английском). Пример: `0018-collection-task-migration`.

### ADR

`ADR` (`Architecture Decision Record`) — документ, фиксирующий архитектурное решение, его контекст и rationale. Отвечает на «почему именно это решение».  
Реестр: [`memory-bank/adr/README.md`](adr/README.md).

### Status / Delivery Status

`Status` — публикационный статус документа: `draft`, `active`, `archived`.  
`Delivery status` — lifecycle задачи: `planned`, `in_progress`, `done`, `cancelled`. Не смешивать с `status`.
