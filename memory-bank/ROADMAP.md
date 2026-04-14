---
title: Roadmap ai-da-collect (крупные единицы работы)
doc_kind: project
doc_function: canonical
purpose: Упорядоченный обзор эпиков и связи с GitHub Issues; не дублирует детальные спеки.
derived_from:
  - memory-bank/prd/PRD.md
  - memory-bank/index.md
  - memory-bank/progress.md
status: active
last_updated: 2026-04-14
audience: humans_and_agents
---

# Roadmap ai-da-collect

## ⚠️ Архитектурный пересмотр (PRD v4, 2026-04-12)

Центральная сущность изменена: `Source` → `CollectionTask`. PRD v4 вводит контракты C-1–C-7.
Фазы 1–6 завершены по старой архитектуре; **фаза 7 (текущая)** — пересборка под новый домен.

---

## Фазы

### Фазы 1–6 — ЗАВЕРШЕНЫ ✅

| # | Issue | Артефакт | Статус |
|---|-------|---------|--------|
| 1 | #1 | `core/lib/collect/` — Plugin контракт, реестр, NullPlugin | ✅ CLOSED |
| 2 | #2 | `app/models/source.rb`, `sync_checkpoint.rb` + миграции | ✅ CLOSED |
| 3 | #3 | `Source#sync_step!` — оркестрация + транзакция | ✅ CLOSED |
| 4 | #4 | `app/services/collect/blob_storage.rb` — S3 адаптер | ✅ CLOSED |
| 5 | #5 | `app/models/raw_ingest_item.rb` — сырая запись + идемпотентность | ✅ CLOSED |
| 6 | #6 | `app/clients/telegram/channel_client.rb` — ChannelClient + DTO | ✅ CLOSED |

---

### Фаза 7 — ТЕКУЩАЯ: пересборка под CollectionTask (PRD v4)

Логическая последовательность работ (зависимости строгие сверху вниз):

```
#18 CollectionTask: data model + state machine  [critical, блокирует всё]
  ├─→ #19 Bearer token auth                     [critical]
  │     └─→ #20 Tasks API CRUD + lifecycle       [critical]
  │           ├─→ #21 Items cursor pagination    [high]
  │           └─→ #22 Webhook mode               [high]
  ├─→ #7  Telegram plugin (bot-attached)         [high]
  │     └─→ #8  CollectionTaskSyncJob            [high]
  │           └─→ #23 Startup-recovery hook      [high]
  └─→ #10 Structured logging                     [high]

#24 GET /health endpoint                         [medium, независимо]
#11 CI / GitHub Actions                          [medium, параллельно]

#26 telegram_user credential/session model       [critical, отдельная ветка]
  └─→ #27 telegram_user MTProto client            [critical]
        └─→ #28 telegram_user plugin              [high]
              └─→ #29 telegram_user job integration [high]
                    └─→ #30 onboarding/audit        [high]
```

#### Детальная таблица

| # | Issue | Тип | Приоритет | Контракт PRD |
|---|-------|-----|-----------|-------------|
| #18 | [CollectionTask: data model + state machine](https://github.com/asromanychev/ai-da-collect/issues/18) | feature | **critical** | C-1, C-4 |
| #19 | [Bearer token auth для /tasks*](https://github.com/asromanychev/ai-da-collect/issues/19) | feature | **critical** | C-6 |
| #20 | [Collection Tasks API: CRUD + lifecycle](https://github.com/asromanychev/ai-da-collect/issues/20) | feature | **critical** | C-1, C-5 |
| #7  | [Telegram plugin: bot-attached channels only](https://github.com/asromanychev/ai-da-collect/issues/7) | feature | high | C-3 |
| #8  | [CollectionTaskSyncJob: lifecycle + retry](https://github.com/asromanychev/ai-da-collect/issues/8) | feature | high | C-2 |
| #21 | [GET /tasks/:id/items cursor pagination](https://github.com/asromanychev/ai-da-collect/issues/21) | feature | high | C-4 |
| #22 | [Webhook режим: secret + routing](https://github.com/asromanychev/ai-da-collect/issues/22) | feature | high | C-6 |
| #23 | [Startup-recovery hook](https://github.com/asromanychev/ai-da-collect/issues/23) | feature | high | C-7 |
| #10 | [Структурированные логи: JSON + task_id](https://github.com/asromanychev/ai-da-collect/issues/10) | feature | high | C-7 |
| #24 | [GET /health + Redis healthcheck](https://github.com/asromanychev/ai-da-collect/issues/24) | feature | medium | C-7 |
| #11 | [CI: GitHub Actions + coverage](https://github.com/asromanychev/ai-da-collect/issues/11) | infra | medium | — |
| #26 | [telegram_user: secure credential/session model](https://github.com/asromanychev/ai-da-collect/issues/26) | feature | **critical** | post-MVP extension |
| #27 | [telegram_user client: MTProto history + incremental fetch](https://github.com/asromanychev/ai-da-collect/issues/27) | feature | **critical** | post-MVP extension |
| #28 | [telegram_user plugin: public/private channels via user session](https://github.com/asromanychev/ai-da-collect/issues/28) | feature | high | post-MVP extension |
| #29 | [telegram_user job integration: retry/session-aware failure handling](https://github.com/asromanychev/ai-da-collect/issues/29) | feature | high | post-MVP extension |
| #30 | [telegram_user onboarding: credential verification, rotation, audit](https://github.com/asromanychev/ai-da-collect/issues/30) | feature | high | post-MVP extension |

---

## PRD v4 — покрытие контрактов

| Контракт | Описание | Issues |
|----------|----------|--------|
| **C-1** | CollectionTask lifecycle, создание, уникальность | #18, #20 |
| **C-2** | Job modes (polling/webhook), retry, unique-jobs lock | #8, #22 |
| **C-3** | Plugin contract: fetch+map, NullPlugin, ENV-config | #7, #1✅ |
| **C-4** | Cursor pagination, idempotent insert, индексы | #21, #18 |
| **C-5** | Consume (delete/retain), атомарность, идемпотентность | #20 |
| **C-6** | Auth (Bearer), webhook_secret, изоляция requester | #19, #22 |
| **C-7** | Logging, health, startup-recovery | #10, #24, #23 |

**Покрытие PRD v4: 100% (32/32 требований трасируются к issues или реализованному коду)**

---

## Telegram Roadmap Split

- `telegram_bot` / bot-attached flow:
  текущий реализованный и roadmap-совместимый путь на Telegram Bot API; работает только для каналов, где бот реально получает `channel_post`.
- `telegram_user` / user-session flow:
  новая отдельная ветка работ для чтения истории любых публичных и доступных приватных каналов через user session / MTProto.
- Эти ветки не должны смешиваться в одном plugin type или одном credential contract.

---

## Как обновлять этот файл

- После закрытия issue: переместить строку в таблицу фазы с ✅.
- При изменении PRD: обновить таблицу контрактов и граф зависимостей.
- SSoT деталей — GitHub Issues и `memory-bank/issues/<slug>/`.
