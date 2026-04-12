# PRD: ai-da-collect

**Статус:** draft v4 (VibeContract revision)
**Дата:** 2026-04-12
**Аудитория:** AI-агенты, разработчики, PM

> **Контрактная база:** все функциональные требования опираются на явные контракты C-1 — C-7.
> Каждый раздел помечен ссылкой на соответствующий контракт.

---

## 1. Vision

`ai-da-collect` — сервис **временного буферизованного ingestion** с двумя режимами триггера: event-driven (webhook) и scheduled (polling).

Получает задания на сбор от внешних агентов и сервисов, собирает сырой контент из внешних источников через изолированные плагины, буферизует до потребления downstream-агентом, затем удаляет по сигналу потребителя или по истечению TTL.

**Архитектурные принципы:**

- Сервис хранит данные «как есть» и не знает, что с ними делает downstream. Семантика, анализ, embeddings — за его пределами.
- Каждый агент создаёт изолированный Task: один и тот же внешний источник может собираться параллельно для разных агентов без взаимного влияния.
- Self-consume допустим: один агент может быть одновременно upstream (создаёт Task) и downstream (потребляет данные).
- `requester_id` — произвольная строка от клиента, не верифицируется в MVP. Известное ограничение безопасности (см. C-6).

---

## 2. Целевая аудитория

| Роль | Описание | Критерий успеха |
|------|----------|-----------------|
| **Upstream Agent / Orchestrator** | Создаёт Task на сбор, передаёт конфигурацию источника, режим сбора и параметры retention. | Task создан корректно (C-1), Job запущен без ошибок (C-2). |
| **Downstream AI Agent / Service** | Читает `raw_ingest_items`, сигналит о потреблении, управляет удалением. | Все items получены без потерь; p99 latency чтения < 500ms (C-4). |
| **Оператор-человек** | Настройка окружения, дебаг через API и Sidekiq Web UI. | Диагностика ошибки сбора за < 5 минут через `GET /tasks/:id` + Sidekiq Web UI (C-7). |

---

## 3. Проблематика

AI-агенты и пайплайны, работающие с контентом внешних каналов, не имеют единого изолированного механизма «собери для меня временно»:

- Один набор данных не может быть собран параллельно с разными конфигами для разных агентов — нет изоляции по потребителю.
- Нет встроенного lifecycle: данные либо хранятся вечно, либо удаляются вручную.
- Отсутствует унифицированный триггер: агенты вынуждены опрашивать источники сами, дублируя логику retry и чекпойнтов.
- Повторный обход одного источника разными скриптами создаёт дубли и race condition.

---

## 4. Центральная сущность: Collection Task `[C-1]`

**Task** — задание на сбор от конкретного requester'а для конкретного внешнего источника с заданными параметрами, режимом сбора и политикой retention.

### 4.1 Создание Task

**Предусловие (C-1):** запрос должен содержать:
- `requester_id` — непустая строка.
- `plugin_type` ∈ {`telegram`}; иное значение → HTTP 422.
- `external_id` — непустая строка.
- `collection_mode` ∈ {`polling`, `webhook`}.
- `retention_policy` ∈ {`delete`, `retain`}.
- `poll_interval_seconds` > 0 — обязательно при `collection_mode: polling`.
- Комбинация `(requester_id, plugin_type, external_id)` должна отсутствовать в `collection_tasks`.

**Постусловие (C-1):** Task создан со `state = created`; Sidekiq Job поставлен → `queued`. HTTP 201 с полным Task object. При `webhook` mode — `webhook_secret` включён в ответ **однократно** и далее не возвращается в `GET /tasks/:id`.

**При дубле:** HTTP 409 с `{ "existing_task_id": N }`, новый Task не создан.

**Инвариант:** `collection_mode` — **immutable** после создания; попытка изменить → HTTP 422.

### 4.2 Уникальность

`UNIQUE (requester_id, plugin_type, external_id)` на уровне БД. При попытке создать дубль сервис возвращает HTTP **409 Conflict** с телом `{ "existing_task_id": N }`.

### 4.3 Lifecycle Task `[C-1, C-2]`

```
created → queued → collecting → ready → consumed → deleted
                       ↓
                    failed
```

| Состояние | Смысл | Переход из |
|-----------|-------|------------|
| `created` | Task принят, ещё не поставлен в очередь | — |
| `queued` | Job поставлен в Sidekiq | `created` |
| `collecting` | Идёт активный сбор данных | `queued` |
| `ready` | Последний sync_step завершён; данные доступны downstream | `collecting` (polling: после каждого sync_step) |
| `consumed` | Downstream сигналил о потреблении (retention: retain) | `ready` |
| `deleted` | Все данные удалены каскадно | `ready` (delete policy) / `consumed` (retain policy) / любое (force DELETE) |
| `failed` | Job исчерпал retry; сбор прекращён | `collecting` |

**Правила перехода (C-1, C-2):**
- Webhook Task: никогда не переходит в `ready` автоматически — остаётся в `collecting` пока не вызван `POST /tasks/:id/ready` или `POST /tasks/:id/consume`.
- Polling Task: переходит в `ready` после каждого успешного sync_step; следующий poll переводит обратно в `collecting`.
- `last_error` обновляется **только** при переходе в `failed`; при успешном retry — очищается.
- `failed_at` и `consumed_at` — monotonic: после записи не обнуляются.
- После `deleted`: `GET /tasks/:id` → HTTP 404.

### 4.4 Критерий завершения сбора `[C-2]`

| Режим | Условие перехода в `ready` |
|-------|---------------------------|
| `polling` | Успешное завершение sync_step (все новые items сохранены, checkpoint обновлён атомарно) |
| `webhook` | Явный вызов `POST /tasks/:id/consume` или `POST /tasks/:id/ready` от downstream |

---

## 5. Режимы сбора (Collection Mode) `[C-2]`

```
┌─────────────────────────────────────────────────────────┐
│               Режимы запуска collecting job              │
├──────────────────────┬──────────────────────────────────┤
│  PUSH (webhook)      │  PULL (polling)                  │
│                      │                                  │
│  Источник сам шлёт   │  Sidekiq scheduled job           │
│  событие на наш      │  периодически вызывает           │
│  endpoint            │  sync_step по интервалу          │
│                      │  из Task config                  │
│  Telegram Bot API    │  RSS, публичные API,             │
│  (setWebhook mode)   │  сайты, Telegram getUpdates и др.│
└──────────────────────┴──────────────────────────────────┘
```

### 5.1 Webhook Setup `[C-2, C-6]`

**Предусловие (C-6):** Task создан с `collection_mode: webhook`.

**Постусловие (C-6):**
1. Сервис генерирует `webhook_secret` — 32-байт cryptographically random hex; уникален в БД (`UNIQUE (webhook_secret) WHERE NOT NULL`).
2. `webhook_secret` возвращается **только** в ответе `POST /tasks`; в последующих GET-запросах отсутствует.
3. **Ответственность оператора:** зарегистрировать URL `POST /webhooks/telegram/<webhook_secret>` в Telegram через `setWebhook`. Ручной шаг вне MVP автоматизации.
4. Routing: при входящем webhook сервис находит Task по `webhook_secret`; неизвестный secret → HTTP 404.

**Инвариант (C-6):** `webhook_secret` не логируется в plaintext.

### 5.2 Гарантия "не более одного Job на Task" `[C-2]`

**Инвариант:** `sidekiq-unique-jobs` lock scope `(task_id)` — в любой момент времени для одного Task активен не более одного Job. Дублирующий enqueue игнорируется.

### 5.3 Retry-стратегия `[C-2]`

| Тип ошибки | HTTP-коды / условие | Поведение |
|------------|---------------------|-----------|
| Transient | 429, 5xx, network timeout | Exponential backoff, max 5 попыток; `retry_after` из ответа Telegram при 429 |
| Permanent | 400, 403 | Немедленный переход в `failed`, retry не производится |
| После 5 попыток transient | — | Task → `failed`, `last_error` записан |

### 5.4 Восстановление при рестарте `[C-7]`

**Предусловие (C-7):** Redis доступен.

**Постусловие (C-7):** при старте сервиса (startup-hook) — сканирование Tasks в `state ∈ {collecting, queued}` без активного Job → Jobs переподаются в Sidekiq.

**Инвариант:** startup-recovery идемпотентна (`sidekiq-unique-jobs` предотвращает дубликаты).

---

## 6. Границы MVP

### 6.1 In Scope

- **Collection Task API:** создание Task, переход по lifecycle (C-1), endpoint потребления и удаления (C-5).
- **List Tasks:** `GET /tasks?requester_id=&state=` — поиск своих Tasks.
- **Аутентификация:** API key (из ENV, Bearer token) — обязательно (C-6). TLS — ответственность reverse proxy.
- **Webhook setup:** генерация `webhook_secret` (32-байт random hex) при создании Task в webhook-режиме; routing по secret (C-6).
- **Двойной режим триггера:** PUSH + PULL (C-2).
- **Изоляция по requester:** параллельные Tasks для одного источника без взаимного влияния (C-6).
- **Персистентность:** `collection_tasks`, `sync_checkpoints`, `raw_ingest_items` (PostgreSQL); тексты — в `metadata` JSONB (C-4).
- **Идемпотентность записи:** `UNIQUE (task_id, external_id)` в `raw_ingest_items`; INSERT OR IGNORE семантика (C-4).
- **Инкрементальный sync:** `sync_checkpoints.position` (jsonb) per Task; обновляется атомарно с сохранением items (C-3, C-4).
- **Retention policy:**
  - `delete` — каскадное удаление при `consume` (C-5).
  - `retain` — данные остаются до явного DELETE (C-5).
  - `ttl:<seconds>` — out of scope MVP, зарезервировано в модели.
- **Cursor pagination:** `GET /tasks/:id/items?after_id=<bigint>&limit=<int>` — stable cursor по `id`; p99 < 500ms (C-4).
- **Первый плагин — Telegram public channels:** оба режима; DTO `{ message_id:, date:, text:, raw: }` (C-3).
- **Plugin isolation:** плагины не пишут в БД напрямую; `source_config` хранит имена ENV-переменных, не секреты (C-3, C-6).
- **Фоновые задачи:** Sidekiq + ActiveJob; unique jobs lock per Task (C-2).
- **Structured logging:** JSON-формат, уровни INFO/WARN/ERROR; `task_id` в каждом log line; секреты не логируются (C-7).
- **Health endpoint:** `GET /health` → 200 OK без auth (C-7).
- **Деплой:** Docker-first, конфигурация через ENV.

### 6.2 Out of Scope (MVP)

- Нормализация, embeddings, RAG, LLM-анализ.
- Верификация `requester_id` — multi-tenancy с изолированными API keys.
- Авторизованный доступ к приватному контенту (MTProto/userbot) — отдельный плагин.
- Автоматическая регистрация webhook в Telegram при создании Task.
- Загрузка вложений в S3.
- Webhook-доставка downstream (push к агенту).
- TTL-автоудаление по возрасту (GC).
- Продуктовый UI.
- Любые источники кроме Telegram public channels.
- Rate limiting на webhook endpoint (рекомендуется reverse proxy).

---

## 7. Ключевые сценарии

#### SC-1 — Upstream агент создаёт polling Task `[C-1, C-2]`
Агент `POST /tasks` (plugin_type: telegram, external_id: @channel, requester_id: agent-X, collection_mode: polling, poll_interval_seconds: 300, retention_policy: delete).
Сервис проверяет предусловие C-1 (уникальность, валидность полей). Task создан → `created`. Sidekiq scheduler ставит Job → `queued` → `collecting`.

#### SC-2 — Event-driven сбор по webhook `[C-2, C-6]`
Task создан с `collection_mode: webhook`. Сервис вернул `webhook_secret` (32-байт hex) однократно в ответе POST. Оператор зарегистрировал URL в Telegram.
Telegram присылает событие на `POST /webhooks/telegram/:secret`. Сервис находит Task по secret (неизвестный → 404). Job поставлен с unique lock. Job сохраняет items (INSERT OR IGNORE), обновляет checkpoint.

#### SC-3 — Параллельная изолированная сборка `[C-6]`
Agent-A и Agent-B имеют Tasks на @channel с разными конфигами. `raw_ingest_items` и `sync_checkpoints` полностью независимы. Сбой Job для Task-A не влияет на Task-B.

#### SC-4 — Downstream потребляет и удаляет (delete policy) `[C-4, C-5]`
Agent-A: `GET /tasks/:id/items?after_id=0&limit=100` постранично.
После пустого ответа `items: []`: `POST /tasks/:id/consume`.
Постусловие C-5: `retention_policy: delete` → атомарная транзакция: каскадное удаление raw_ingest_items + sync_checkpoint + task → `deleted`.
Повторный `POST /tasks/:id/consume` → 200 (idempotent).
`GET /tasks/:id` после удаления → 404.

#### SC-5 — Downstream потребляет без удаления (retain policy) `[C-5]`
Аналогично SC-4, но `retention_policy: retain`. После consume Task → `consumed`, `consumed_at` записан, данные остаются. Явное удаление — `DELETE /tasks/:id`.

#### SC-6 — Обработка ошибки источника `[C-2]`
Rate-limit (HTTP 429): Job применяет exponential backoff с учётом `retry_after` из ответа Telegram (transient).
Сетевой сбой: exponential backoff, до 5 попыток (transient).
Invalid channel (Telegram 400): немедленный `failed`, retry не производится (permanent).
После перехода в `failed`: `last_error` обновлён; оператор видит через `GET /tasks/:id`. Recovery: `DELETE /tasks/:id` + создать новый.

#### SC-7 — Поиск своих Tasks после рестарта `[C-1, C-7]`
Agent-A не помнит task_id. Запрос: `GET /tasks?requester_id=agent-X&state=collecting`.
Сервис возвращает список Tasks с пагинацией. Startup-hook уже переподал Jobs для Tasks в `collecting`/`queued` (C-7).

#### SC-8 — Resumable consumption `[C-4, C-5]`
Downstream читает items, падает на cursor = 450.
При следующем запуске: `GET /tasks/:id/items?after_id=450`.
Постусловие C-4: stable cursor гарантирует идентичный результат при повторном запросе.
Task остаётся в `ready` до вызова `POST /tasks/:id/consume`.

#### SC-9 — Конкурентный consume `[C-5]`
Два downstream-агента одновременно вызывают `POST /tasks/:id/consume`.
Инвариант C-5: операция атомарна — первый выполняет транзакцию (state → deleted/consumed), второй → 200 (idempotent). Частичных удалений нет.

---

## 8. HTTP API (контракт MVP) `[C-1, C-4, C-5, C-6]`

| Метод | Endpoint | Назначение | Auth |
|-------|----------|------------|------|
| POST | `/tasks` | Создать Task | Bearer |
| GET | `/tasks` | Список Tasks (фильтры: requester_id, state) | Bearer |
| GET | `/tasks/:id` | Статус Task | Bearer |
| POST | `/tasks/:id/consume` | Сигнал о потреблении | Bearer |
| DELETE | `/tasks/:id` | Принудительное каскадное удаление | Bearer |
| GET | `/tasks/:id/items` | Cursor-based список raw_ingest_items | Bearer |
| POST | `/webhooks/:plugin_type/:secret` | Приём webhook | По secret |
| GET | `/health` | Health check | Нет |

**Инвариант (C-6):** запросы к `/tasks*` без валидного Bearer token → HTTP 401.

### 8.1 POST /tasks — Создать Task `[C-1, C-6]`

**Request body:**
```jsonc
{
  "requester_id": "agent-X",
  "plugin_type": "telegram",
  "external_id": "@channel_username",
  "collection_mode": "polling",       // "polling" | "webhook"
  "poll_interval_seconds": 300,       // required if polling, > 0
  "retention_policy": "delete",       // "delete" | "retain"
  "source_config": {
    "bot_token_env": "TELEGRAM_BOT_TOKEN"  // имя ENV-переменной, не секрет
  }
}
```

**Responses:**

| HTTP | Условие |
|------|---------|
| 201 Created | Task создан; тело: полный Task object + `webhook_secret` (только если webhook mode, однократно) |
| 409 Conflict | `(requester_id, plugin_type, external_id)` уже существует; тело: `{ "existing_task_id": 123 }` |
| 422 | Невалидные параметры (отсутствуют обязательные поля, неизвестный plugin_type, poll_interval_seconds ≤ 0) |

### 8.2 GET /tasks/:id — Статус Task `[C-1]`

**Response body:**
```jsonc
{
  "id": 1,
  "requester_id": "agent-X",
  "plugin_type": "telegram",
  "external_id": "@channel",
  "collection_mode": "polling",
  "state": "collecting",
  "retention_policy": "delete",
  "items_count": 142,
  "last_error": null,
  "consumed_at": null,
  "failed_at": null,
  "created_at": "...",
  "updated_at": "..."
}
```

**Инвариант (C-6):** `webhook_secret` не включается в этот ответ.

### 8.3 GET /tasks/:id/items — Cursor pagination `[C-4]`

```
GET /tasks/:id/items?after_id=0&limit=100
```

- `after_id` — bigint ≥ 0, default 0. Stable cursor по полю `id`.
- `limit` — integer ∈ [1, 1000], default 100.
- Пустой `items: []` — конец потока (нет items с `id > after_id`).
- p99 latency < 500ms (индекс `(task_id, id)` обязателен).

**Response:**
```jsonc
{
  "items": [
    {
      "id": 1,
      "external_id": "123456",
      "metadata": { "message_id": 123456, "date": 1700000000, "text": "...", "raw": {} },
      "created_at": "..."
    }
  ],
  "next_cursor": 101
}
```

### 8.4 POST /tasks/:id/consume — Идемпотентный сигнал потребления `[C-5]`

| Task state | Результат |
|------------|-----------|
| `ready` | Атомарная транзакция: retention policy применена; Task → `consumed` или `deleted` |
| `consumed` / `deleted` | 200 OK (idempotent) |
| Другое | 409 Conflict с текущим state |

**Инвариант (C-5):** операция атомарна — нет частичных удалений. Повторный вызов никогда не возвращает 4xx/5xx.

---

## 9. Модель данных (логическая) `[C-4]`

```
collection_tasks (1) ──< (N) raw_ingest_items
collection_tasks (1) ──< (0..1) sync_checkpoints
```

### collection_tasks `[C-1, C-2, C-6]`

| Поле | Тип | Назначение |
|------|-----|------------|
| `id` | bigint PK | |
| `requester_id` | string NOT NULL | Идентификатор upstream агента |
| `plugin_type` | string NOT NULL | Тип плагина (telegram) |
| `external_id` | string NOT NULL | Внешний ключ источника |
| `source_config` | jsonb NOT NULL | Имена ENV-переменных, **не секреты** |
| `collection_mode` | string NOT NULL | `webhook` / `polling` — **immutable** |
| `poll_interval_seconds` | integer nullable | Интервал для polling; > 0 если задан |
| `webhook_secret` | string nullable | 32-байт random hex; не возвращается в GET |
| `state` | string NOT NULL | Lifecycle state |
| `retention_policy` | string NOT NULL | `delete` / `retain` |
| `last_error` | text nullable | Последняя ошибка сбора; обновляется только при → `failed` |
| `consumed_at` | datetime nullable | Monotonic; не обнуляется после записи |
| `failed_at` | datetime nullable | Monotonic; не обнуляется после записи |
| `created_at` / `updated_at` | datetime | |

**Индексы:**
- `UNIQUE (requester_id, plugin_type, external_id)`
- `INDEX (state)` — для startup-recovery (C-7)
- `UNIQUE (webhook_secret)` WHERE webhook_secret IS NOT NULL

### raw_ingest_items `[C-4]`

| Поле | Тип | Назначение |
|------|-----|------------|
| `id` | bigint PK | Monotonically increasing; stable cursor для pagination |
| `task_id` | bigint FK → collection_tasks ON DELETE CASCADE | |
| `external_id` | string NOT NULL | Идемпотентный ключ у источника |
| `metadata` | jsonb NOT NULL default '{}' | DTO: `{ message_id:, date:, text:, raw: }`; `text` доступен без полной десериализации |
| `storage_key` | string nullable | Заглушка для будущих вложений S3 |
| `created_at` / `updated_at` | datetime | |

**Индексы:**
- `UNIQUE (task_id, external_id)` — INSERT OR IGNORE семантика (C-4)
- `INDEX (task_id, id)` — для cursor pagination; p99 < 500ms (C-4)

### sync_checkpoints `[C-3, C-4]`

| Поле | Тип | Назначение |
|------|-----|------------|
| `id` | bigint PK | |
| `task_id` | bigint FK → collection_tasks ON DELETE CASCADE, UNIQUE | |
| `position` | jsonb NOT NULL | Обновляется атомарно с сохранением items в одной транзакции |
| `created_at` / `updated_at` | datetime | |

**Формат `position` для Telegram плагина:**
```jsonc
{
  "last_message_id": 12345,
  "last_date": 1700000000
}
```

---

## 10. Plugin System `[C-3]`

**Предусловие:** ENV-переменная из `source_config.bot_token_env` задана и содержит валидный токен. Plugin вызывается строго из Job-контекста.

**Постусловие:** Plugin возвращает массив DTO и новое `position`. Данные сохраняются через основной код (не плагином напрямую). `sync_checkpoints.position` обновляется атомарно с items в одной транзакции.

**Инварианты:**
- Плагины **не пишут** в БД напрямую — только возвращают данные.
- `source_config` содержит имена ENV-переменных, не секреты.
- `plugin_type ∉ {telegram}` → HTTP 422 при создании Task.
- **NullPlugin** доступен для CI без реального Telegram и S3.

---

## 11. Ограничения и стек

| Категория | Решение |
|-----------|---------|
| Language / Framework | Ruby 3.4, Rails 8 API-only |
| База данных | PostgreSQL |
| Object storage | S3-compatible — out of scope MVP; `storage_key` nullable-заглушка |
| Очереди | Sidekiq + Redis через ActiveJob |
| Unique Jobs | `sidekiq-unique-jobs` — lock scope `(task_id)`; гарантия C-2 |
| Sidekiq concurrency | Configurable via ENV `SIDEKIQ_CONCURRENCY` |
| Аутентификация | API key из ENV (Bearer token); webhook защищён `webhook_secret` в URL (C-6) |
| TLS | Ответственность reverse proxy (nginx/caddy); сервис принимает трафик только из доверенной сети |
| Деплой | Docker-first, конфигурация через ENV |
| Изоляция плагинов | Плагины не пишут в БД; только fetch + маппинг (C-3) |
| Авторизация источников | `source_config` хранит имена ENV-переменных, не секреты (C-3, C-6) |
| Logging | Structured JSON, INFO/WARN/ERROR, `task_id` в каждой строке; секреты не логируются (C-7) |
| Recovery при рестарте | Startup-hook: re-enqueue Jobs для Tasks в `collecting`/`queued`; идемпотентно (C-7) |
| Тестируемость | NullPlugin + in-memory адаптеры; CI без реального Telegram и S3 (C-3) |
| Health при недоступности Redis | `/health` → 503; Job scheduling недоступен (C-7) |

---

## 12. Открытые архитектурные вопросы

| # | Вопрос | Влияние | Предварительное решение |
|---|--------|---------|------------------------|
| OQ-1 | Поведение `DELETE /tasks/:id` при Task в `collecting` — прервать Job или дождаться? | Sidekiq job lifecycle | Graceful: Job получает сигнал stop через Redis flag; DELETE ждёт max 30s, затем force-delete |
| OQ-2 | Стратегия retry: дифференцировать transient vs. permanent ошибки? | Надёжность vs. нагрузка | Transient (429, 5xx, network): exponential backoff, max 5. Permanent (400, 403): немедленный `failed` (C-2) |
| OQ-3 | Порог text vs. S3: когда `metadata` jsonb недостаточно? | Актуально при тяжёлых источниках | Решается при появлении источников с payload > 64KB |
| OQ-4 | Webhook-доставка downstream (push от сервиса к агенту) — дизайн контракта | Post-MVP | Отложено |
| OQ-5 | Capacity targets MVP: сколько одновременных Tasks / items/day? | Sizing PostgreSQL и Redis | Открыто — нужна оценка от команды |
| OQ-6 | Rate limiting на `POST /webhooks/...` endpoint (DoS protection) | Безопасность (C-6) | Рекомендуется на уровне reverse proxy; в MVP не реализуется в коде |

---

## 13. Анализ рисков

| # | Риск | Вероятность | Влияние | Контракт | Mitigation |
|---|------|-------------|---------|----------|------------|
| R-1 | Redis потерял данные → polling Jobs не восстановятся | Средняя | Высокое | C-7 | Startup-hook; Redis persistence (AOF) рекомендована |
| R-2 | `retain` policy → бесконечный рост raw_ingest_items без TTL | Высокая | Среднее | C-5 | Мониторинг размера таблицы; предупреждение оператору при > N items |
| R-3 | Один API key → любой клиент может удалить Task другого агента | Средняя | Высокое | C-6 | Known limitation MVP; mitigation post-MVP — per-requester API keys |
| R-4 | Webhook flooding / DoS на `/webhooks/...` | Низкая | Высокое | C-6 | Rate limiting на reverse proxy |
| R-5 | Concurrent collecting jobs для одного Task | Средняя | Среднее | C-2 | `sidekiq-unique-jobs` lock per task_id |
| R-6 | Partial write при DELETE во время collecting | Низкая | Высокое | C-5 | Атомарная транзакция consume (C-5); graceful shutdown Job перед DELETE (OQ-1) |

---

## Changelog

| Версия | Дата | Изменения |
|--------|------|-----------|
| v1 | — | Первоначальный черновик |
| v2 | 2026-04-11 | Расширение модели данных, сценарии, стек |
| v3 | 2026-04-12 | QoT revision: состояние `failed`, `GET /tasks` list, webhook_secret flow, cursor standardized на `after_id`, идемпотентность consume, индексы БД, structured logging, startup-hook, раздел рисков, 3 новых сценария (SC-7, SC-8, SC-9) |
| v4 | 2026-04-12 | VibeContract revision: внедрены контракты C-1 — C-7; абстрактные формулировки заменены на измеримые pre/postcondition/invariant; каждый раздел маркирован ссылкой на контракт; добавлена колонка «Контракт» в таблицу рисков; явно указаны атомарность consume, monotonic timestamps, 32-байт webhook_secret, NullPlugin, 503 при недоступности Redis |
