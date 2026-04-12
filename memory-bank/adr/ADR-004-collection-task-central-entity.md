---
title: "ADR-004: CollectionTask as Central Entity (PRD v4)"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует переход от модели sources к CollectionTask как центральной сущности MVP. Старая модель sources — блокер issue #18."
derived_from:
  - ../prd/PRD.md
status: active
decision_status: accepted
date: 2026-04-12
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-004: CollectionTask as Central Entity (PRD v4)

## Контекст

Первоначальная модель данных (`sources`, `sync_checkpoints`, `raw_ingest_items`) была спроектирована под концепцию «источника». PRD v4 (2026-04-12) пересмотрел продуктовую модель: центральной сущностью стал `CollectionTask` — задание на сбор от конкретного `requester_id` с явным lifecycle.

Текущая схема БД (`db/schema.rb`) остаётся на старой модели — это критический блокер (#18).

## Драйверы решения

- AI-агенты создают задания на сбор, а не «подключают источники» — семантика `CollectionTask` точнее отражает модель потребления.
- Явный lifecycle (`created→queued→collecting→ready→consumed→deleted/failed`) необходим для буферизации и управления TTL.
- `requester_id` позволяет изолировать задания по потребителю.
- Старая модель `sources` не поддерживает lifecycle и TTL без значительного рефакторинга.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Решение |
| --- | --- | --- | --- |
| Расширить `sources` до lifecycle | Меньший scope миграции | Семантика не соответствует модели потребления | Отклонён |
| Ввести `CollectionTask` поверх `sources` | Постепенный переход | Дублирование, temporary complexity | Отклонён |
| Заменить `sources` на `CollectionTask` | Чистая модель, точная семантика | Миграция блокирует все downstream issues | **Принято** |

## Решение

`CollectionTask` — центральная сущность MVP. Lifecycle: `created→queued→collecting→ready→consumed→deleted/failed`. Поля: `requester_id`, `plugin_id`, `params`, `status`, `ttl_at`, `consumed_at`. Старые таблицы (`sources`, `sync_checkpoints`, `raw_ingest_items`) заменяются новой схемой в рамках issue #18.

Canonical owner lifecycle: `memory-bank/use-cases/README.md` → UC-001.

## Последствия

### Положительные

- Модель точно отражает семантику «задание на сбор».
- Lifecycle управляется явно: агент знает статус, TTL, consumed_at.
- Все downstream issues (#7, #8, #10, #11, #19–#24) строятся на стабильном контракте.

### Отрицательные

- Issue #18 — критический блокер: без миграции схемы ни одна downstream задача не начинается.
- Код первых 6 issues (plugin contract, checkpoints, etc.) написан под старую модель — требует адаптации.

### Нейтральные / организационные

- `memory-bank/index.md` зафиксировал расхождение «код ↔ PRD» (2026-04-12).
- `memory-bank/ROADMAP.md` → фаза 7, стартовая точка — #18.

## Follow-up

- Issue **#18** — миграция схемы на `collection_tasks` (critical, блокирует #7, #8, #10, #11, #19–#24).
- UC-001 (`collection-task-lifecycle`) создать когда #18 перейдёт в `in_progress`.
