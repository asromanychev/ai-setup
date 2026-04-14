# Spec — Issue #18: CollectionTask Data Model

## 1. Цель решения

Создать таблицу `collection_tasks`, модель `CollectionTask` с валидациями и ручным state machine, обновить FK в `raw_ingest_items` и `sync_checkpoints` с `source_id` → `task_id`.

## 1.1 Потребитель решения

- **Кто вызывает:** модульные тесты (`rspec spec/models/collection_task_spec.rb`) и будущий `CollectionJob` (issue #7).
- **Когда вызывается:** при создании задания, при переходе по lifecycle, при удалении задания.
- **Ожидаемая частота:** однократное создание задания + цепочка переходов до `consumed` или `failed`.
- **Ожидаемая модель ответа:** синхронный side-effect в БД; исключение при нарушении инварианта.

## 2. Scope

- `REQ-1` Создать миграцию для таблицы `collection_tasks` с полным набором полей и индексами.
- `REQ-2` Создать миграцию для изменения `raw_ingest_items`: переименовать `source_id` → `task_id`, обновить FK на `collection_tasks` с `ON DELETE CASCADE`.
- `REQ-3` Создать миграцию для изменения `sync_checkpoints`: переименовать `source_id` → `task_id`, обновить FK на `collection_tasks` с `ON DELETE CASCADE`.
- `REQ-4` Добавить составной индекс `(task_id, id)` на `raw_ingest_items` для cursor pagination.
- `REQ-5` Реализовать модель `CollectionTask < ApplicationRecord` с валидациями.
- `REQ-6` Реализовать state machine через явные методы перехода без внешнего гема.
- `REQ-7` Обновить `RawIngestItem` и `SyncCheckpoint`: заменить `belongs_to :source` → `belongs_to :collection_task`.
- `NS-1` НЕ входит: удаление модели `Source` или её данных из БД.
- `NS-2` НЕ входит: API-эндпоинты (issue NEW-3).
- `NS-3` НЕ входит: Job-оркестрация (issue #7).
- `NS-4` НЕ входит: удаление старых миграций `sources`.

## 2.1 Preconditions

Все prerequisites материализованы в текущей кодовой базе:
- PostgreSQL доступен, `db/schema.rb` актуален.
- Гемы `rails`, `pg` уже в `Gemfile`.
- Таблицы `raw_ingest_items` и `sync_checkpoints` существуют с FK `source_id`.
- `ApplicationRecord` существует в `app/models/application_record.rb`.

Нет внешних prerequisites, блокирующих исполнение спеки.

## 3. Функциональные требования

**FR-1. Схема таблицы `collection_tasks`.**  
Таблица содержит следующие поля:
- `requester_id` — string, NOT NULL
- `plugin_type` — string, NOT NULL
- `external_id` — string, NOT NULL
- `source_config` — jsonb, NOT NULL, default `{}`
- `collection_mode` — string, NOT NULL
- `poll_interval_seconds` — integer, nullable
- `webhook_secret` — string, nullable
- `state` — string, NOT NULL, default `'created'`
- `retention_policy` — string, NOT NULL
- `last_error` — text, nullable
- `consumed_at` — datetime, nullable
- `failed_at` — datetime, nullable
- `created_at`, `updated_at` — datetime, NOT NULL

Индексы:
- `UNIQUE (requester_id, plugin_type, external_id)`
- `INDEX (state)`
- `UNIQUE (webhook_secret) WHERE webhook_secret IS NOT NULL` (partial index)

**FR-2. FK миграции.**  
В `raw_ingest_items`: переименовать `source_id` → `task_id`, FK → `collection_tasks(id) ON DELETE CASCADE`, составной индекс `(task_id, id)`.  
В `sync_checkpoints`: переименовать `source_id` → `task_id`, FK → `collection_tasks(id) ON DELETE CASCADE`, уникальный индекс `(task_id)`.

**FR-3. Валидации модели `CollectionTask`.**  
- `requester_id`, `plugin_type`, `external_id`, `collection_mode`, `retention_policy` — обязательны (presence).
- `plugin_type` ∈ `['telegram']` — нарушение → `ActiveRecord::RecordInvalid`.
- `collection_mode` — immutable после создания: попытка изменить у persisted-записи → `ActiveRecord::RecordInvalid`.
- `retention_policy` ∈ `['delete', 'retain']`.
- `poll_interval_seconds` > 0 обязателен, если `collection_mode == 'polling'`; иначе не проверяется.
- Уникальность `(requester_id, plugin_type, external_id)` — проверка на уровне модели (`validates :external_id, uniqueness: { scope: [:requester_id, :plugin_type] }`) + уникальный индекс в БД.
- `consumed_at` и `failed_at` монотонны: если поле уже установлено, запись нового значения должна быть отклонена валидатором — нарушение → `ActiveRecord::RecordInvalid`.

**FR-4. State machine — методы перехода.**  
Допустимые переходы (source_state → target_state):

| Метод | Из состояния | В состояние |
|-------|-------------|-------------|
| `queue!` | `created` | `queued` |
| `start_collecting!` | `queued` | `collecting` |
| `mark_ready!` | `collecting` | `ready` |
| `consume!` | `ready` | `consumed` |
| `fail!(error:)` | `collecting` | `failed` |
| `delete!` | любое | `deleted` |

- Попытка недопустимого перехода: метод поднимает `CollectionTask::InvalidTransitionError` (наследник `StandardError`) с указанием текущего состояния.
- При `fail!(error:)`: записывает `error.to_s` в `last_error`, устанавливает `failed_at` (если ещё не установлен).
- При `start_collecting!` после `failed` (retry): очищает `last_error` (устанавливает `nil`). Переход `failed → collecting` должен быть явно задокументирован и допустим.
- `delete!`: переход из любого состояния; запись остаётся в БД с `state: 'deleted'` (soft delete).

**FR-5. Обновление зависимых моделей.**  
`RawIngestItem`: заменить `belongs_to :source` → `belongs_to :collection_task`.  
`SyncCheckpoint`: заменить `belongs_to :source` → `belongs_to :collection_task`.

## 4. Сценарии ошибок и состояния

**SC-E1. Попытка недопустимого перехода:**  
Дано: задание в состоянии `created`. Вызов `consume!`. Ожидаемо: `CollectionTask::InvalidTransitionError`. Состояние задания не изменяется.

**SC-E2. Нарушение уникальности:**  
Дано: существует задание с `(requester_id: 'r1', plugin_type: 'telegram', external_id: 'ch1')`. Попытка создать дубль → `ActiveRecord::RecordInvalid` (uniqueness). Adversarial: отправка одних и тех же параметров из двух конкурентных запросов — БД-уровень уникального индекса обеспечивает защиту после AR validation.

**SC-E3. Попытка изменить `collection_mode` у persisted-записи:**  
Дано: задание создано с `collection_mode: 'polling'`. Вызов `task.collection_mode = 'backfill'; task.save!` → `ActiveRecord::RecordInvalid`. Adversarial: обход через `update_attribute(:collection_mode, ...)` — валидатор должен вызываться через `before_validation` callback.

**SC-E4. Перезапись уже установленного `consumed_at`:**  
Дано: задание в состоянии `consumed` с установленным `consumed_at`. Попытка `task.update!(consumed_at: Time.current + 1.hour)` → `ActiveRecord::RecordInvalid` (monotonic violation). Adversarial: `task.consumed_at = nil; task.save!` → отклонено.

**SC-E5. `poll_interval_seconds` отсутствует при `collection_mode: 'polling'`:**  
`CollectionTask.create!(collection_mode: 'polling', poll_interval_seconds: nil, ...)` → `ActiveRecord::RecordInvalid`.

**SC-E6. `poll_interval_seconds: 0` при `collection_mode: 'polling'`:**  
Значение 0 недопустимо (FR-3 требует > 0) → `ActiveRecord::RecordInvalid`.

**SC-E7. `fail!(error:)` повторно после уже установленного `failed_at`:**  
Задание в состоянии `failed` нельзя перевести в `failed` снова напрямую — только через retry (`start_collecting!`). Попытка `fail!` из `failed` → `InvalidTransitionError`.

**SC-E8. `fail!(error:)` с nil error:**  
`error.to_s` вернёт пустую строку; `last_error` будет записан как `""`. Это допустимо — AC должен явно покрыть этот edge case.

**Состояния TAUS:**
- `loading`: неприменимо — модель синхронная, нет async-операций на уровне AR.
- `empty`: неприменимо — модель описывает единичную запись, не коллекцию.
- `in progress`: эквивалентно состоянию `collecting`.
- `error`: состояние `failed` с заполненным `last_error`.

## 5. Инварианты

**INV-1. Метаданные всегда в PostgreSQL, тела объектов — в S3 (storage_key).**  
`collection_tasks` хранит только конфиг и lifecycle; тела объектов — в `raw_ingest_items.storage_key`. Никогда наоборот.

**INV-2. Orphan protection.**  
После удаления `CollectionTask` (переход в `deleted` с последующим hard delete, если реализован) все связанные `raw_ingest_items` и `sync_checkpoints` удаляются через `ON DELETE CASCADE`. Adversarial: удалить запись через `destroy` — orphan в `raw_ingest_items` невозможен.

**INV-3. Уникальность `(requester_id, plugin_type, external_id)`.**  
Дублирующих заданий нет. Adversarial: конкурентные INSERT — уникальный индекс на уровне БД отклонит второй.

**INV-4. Immutable `collection_mode`.**  
После create поле не изменяется. Adversarial: прямой `UPDATE collection_tasks SET collection_mode = ...` в тестах — AR validation не вызывается; защита только через callback при использовании AR. Это известное ограничение — задокументировать в комментарии модели.

**INV-5. Monotonic timestamps.**  
`consumed_at` и `failed_at` не обнуляются после записи.

## 6. Grounding

Файлы, которые будут изменены или созданы:

| Действие | Путь |
|----------|------|
| СОЗДАТЬ | `db/migrate/<ts>_create_collection_tasks.rb` |
| СОЗДАТЬ | `db/migrate/<ts>_migrate_raw_ingest_items_to_task.rb` |
| СОЗДАТЬ | `db/migrate/<ts>_migrate_sync_checkpoints_to_task.rb` |
| СОЗДАТЬ | `app/models/collection_task.rb` |
| ИЗМЕНИТЬ | `app/models/raw_ingest_item.rb` — `belongs_to :source` → `belongs_to :collection_task` |
| ИЗМЕНИТЬ | `app/models/sync_checkpoint.rb` — `belongs_to :source` → `belongs_to :collection_task` |
| ОБНОВИТЬ | `db/schema.rb` — автоматически после `db:migrate` |
| СОЗДАТЬ | `spec/models/collection_task_spec.rb` |
| ОБНОВИТЬ | `spec/models/raw_ingest_item_spec.rb` — обновить ссылки с `Source` на `CollectionTask` |
| ОБНОВИТЬ | `spec/models/sync_checkpoint_spec.rb` — обновить ссылки |

**Паттерны:**
- State machine: ручная реализация через `before_validation` (immutability, monotonic), явные методы `queue!`, etc. Нет внешнего гема.
- Валидации: стандартные `validates` в `CollectionTask`.
- `CollectionTask::InvalidTransitionError` — вложенный класс ошибки, наследник `StandardError`.
- Тесты: `require_relative "../rails_helper"`, без FactoryBot (нет в Gemfile), создание через `CollectionTask.create!(...)`.
- Partial unique index для `webhook_secret`: `CREATE UNIQUE INDEX ... WHERE webhook_secret IS NOT NULL`.

## 7. Acceptance Criteria

**Scenarios:**

`SC-1` Задание проходит full lifecycle: `created → queued → collecting → ready → consumed`.  
`SC-2` Задание переходит в `failed` при вызове `fail!(error:)` из `collecting`; `last_error` и `failed_at` установлены.  
`SC-3` Retry после `failed`: `start_collecting!` очищает `last_error`, переводит в `collecting`.  
`SC-4` Попытка недопустимого перехода поднимает `CollectionTask::InvalidTransitionError`.  
`SC-5` Дублирующееся задание отклоняется на уровне AR (uniqueness validation).  
`SC-6` Дублирующееся задание отклоняется на уровне БД (unique index — конкурентный insert).  
`SC-7` Попытка изменить `collection_mode` у persisted-записи → `ActiveRecord::RecordInvalid`.  
`SC-8` `consumed_at` и `failed_at` монотонны: обнуление отклоняется.  
`SC-9` `poll_interval_seconds` обязателен и > 0 при `collection_mode: 'polling'`.  
`SC-10` После `delete!` запись остаётся в БД с `state: 'deleted'`.  
`SC-11` При удалении `CollectionTask` через `destroy` связанные `raw_ingest_items` и `sync_checkpoints` удаляются (cascade).  
`SC-12` `fail!(error:)` с nil: `last_error` записывается как пустая строка.

**Traceability:**

| SC | Покрывает REQ |
|----|---------------|
| SC-1 | REQ-1, REQ-5, REQ-6 |
| SC-2 | REQ-6 |
| SC-3 | REQ-6 |
| SC-4 | REQ-6 |
| SC-5 | REQ-5 |
| SC-6 | REQ-1 |
| SC-7 | REQ-5 |
| SC-8 | REQ-5 |
| SC-9 | REQ-5 |
| SC-10 | REQ-6 |
| SC-11 | REQ-2, REQ-3 |
| SC-12 | REQ-6 |

**Checks & Evidence:**

- `CHK-1` [ ] `db/schema.rb` содержит `collection_tasks` с полным набором полей и индексами (UNIQUE, partial UNIQUE, INDEX state).
- `CHK-2` [ ] FK в `raw_ingest_items` и `sync_checkpoints` переключены на `task_id → collection_tasks`.
- `CHK-3` [ ] Все state transitions реализованы; допустимые — успешны, недопустимые — поднимают `InvalidTransitionError`.
- `CHK-4` [ ] `collection_mode` immutable: попытка изменить → `ActiveRecord::RecordInvalid`.
- `CHK-5` [ ] Duplicate `(requester_id, plugin_type, external_id)` → `ActiveRecord::RecordInvalid` (uniqueness).
- `CHK-6` [ ] `consumed_at`/`failed_at` монотонны: обнуление → `ActiveRecord::RecordInvalid`.
- `CHK-7` [ ] `bundle exec rspec spec/models/collection_task_spec.rb` — 0 failures.
- `CHK-8` [ ] `bin/ci` проходит (все существующие spec зелёные).
- `EVID-1` Carrier: `spec/models/collection_task_spec.rb` + вывод `bundle exec rspec`.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 01-2-generate-spec |

## Runtime Telemetry

| Поле | Значение |
|------|----------|
| started_at | 2026-04-13T00:00:00Z |
| finished_at | 2026-04-13T00:00:00Z |
| elapsed_seconds | unknown |
| input_tokens | not available in current runtime |
| output_tokens | not available in current runtime |
| total_tokens | not available in current runtime |
| estimated_cost | not available in current runtime |
| limit_context | not available in current runtime |
