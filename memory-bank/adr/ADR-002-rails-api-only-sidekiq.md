---
title: "ADR-002: Rails API-only + Sidekiq via ActiveJob, no UI"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует выбор Rails API-only без UI, фоновые задачи через Sidekiq (ActiveJob)."
derived_from:
  - ../prd/PRD.md
status: active
decision_status: accepted
date: 2025-12-01
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---

# ADR-002: Rails API-only + Sidekiq via ActiveJob, no UI

## Контекст

Сервис `ai-da-collect` — ingestion backend для AI-агентов и пайплайнов. Нужно выбрать стек и определить, нужен ли UI.

## Драйверы решения

- Целевые потребители — AI-агенты и пайплайны, не люди через браузер.
- Фоновая обработка длительных сборов — обязательна.
- Быстрый старт MVP без frontend-инфраструктуры.
- Команда знает Ruby/Rails — снижает риск.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Решение |
| --- | --- | --- | --- |
| Rails full-stack + UI | Всё в одном | Лишняя сложность для API-сервиса | Отклонён |
| Rails API-only + Sidekiq | Простота, известный стек, ActiveJob абстрагирует бэкенд | Нет UI из коробки | **Принято** |
| Sinatra / другой фреймворк | Легковесность | Меньше tooling | Отклонён |

## Решение

Rails 8 в режиме API-only (`config.api_only = true`). Фоновые задачи через ActiveJob с Sidekiq-бэкендом (Redis). UI вне скоупа MVP и вне скоупа проекта в целом.

## Последствия

### Положительные

- Нет frontend-инфраструктуры (webpack, assets pipeline).
- ActiveJob позволяет при необходимости сменить бэкенд без изменения кода задач.
- Стандартный Rails-tooling для тестирования, миграций, routing.

### Отрицательные

- Нет встроенного UI для мониторинга (Sidekiq Web UI доступен отдельно).

### Нейтральные / организационные

- `project/overview.md` документирует стек.
- Все новые задачи наследуют от `ApplicationJob`.

## Follow-up

- CollectionTask lifecycle реализуется через Job (issue #18+).
