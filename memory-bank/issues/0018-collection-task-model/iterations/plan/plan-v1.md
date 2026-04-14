# Plan — Issue #18: CollectionTask Data Model

## VibeContract

**Предусловие:**
- БД доступна с таблицами `sources`, `raw_ingest_items` (FK `source_id → sources`), `sync_checkpoints` (FK `source_id → sources`).
- Миграции из `db/migrate/` до этого issue применены; `db/schema.rb` актуален.
- Гемы `rails`, `pg` установлены.
- `ApplicationRecord` существует в `app/models/application_record.rb`.

**Постусловие:**
- Таблица `collection_tasks` существует с полным набором полей, индексами (UNIQUE, partial UNIQUE, INDEX state).
- `raw_ingest_items.task_id` — FK → `collection_tasks(id) ON DELETE CASCADE`; составной индекс `(task_id, id)`.
- `sync_checkpoints.task_id` — FK → `collection_tasks(id) ON DELETE CASCADE`; уникальный индекс `(task_id)`.
- Модель `CollectionTask` с валидациями и state machine доступна в `app/models/collection_task.rb`.
- `RawIngestItem` и `SyncCheckpoint` используют `belongs_to :collection_task`.
- `bundle exec rspec spec/models/collection_task_spec.rb` → 0 failures.
- `bin/ci` → 0 failures.

**Инварианты:**
- Тела объектов всегда в S3 (`storage_key`), метаданные в PostgreSQL. `collection_tasks` не хранит blob-данные.
- После удаления `CollectionTask` через `destroy`: нет orphan-записей в `raw_ingest_items` и `sync_checkpoints` (ON DELETE CASCADE).
- `collection_mode` не меняется у persisted-записи.
- `consumed_at` и `failed_at` монотонны.

---

## 1. Паттерн оркестрации

Один агент, последовательно. Зависимости: схема → модели → тесты → gate.

---

## 2. Preconditions

- `PRE-1` Таблицы `raw_ingest_items`, `sync_checkpoints` существуют — подтверждено через `db/schema.rb`.
- `PRE-2` Нет внешних prerequisite вне кодовой базы.

---

## 3. Граф зависимостей

```
STEP-1 → STEP-4 → STEP-5 → STEP-8 → STEP-11
STEP-2 → STEP-5 → STEP-9
STEP-3 → STEP-6 → STEP-10
STEP-4 → STEP-7 (Source cleanup)
STEP-1,2,3 → STEP-4b (run migrations) → все model-шаги
STEP-8,9,10 → STEP-11 (focused verification)
STEP-11 → STEP-12 (regression gate)
```

---

## 4. Пошаговый план

### STEP-1 [S]: Миграция — создание таблицы `collection_tasks`

**Файл:** `db/migrate/<YYYYMMDDHHMMSS>_create_collection_tasks.rb` (СОЗДАТЬ)

**Дельта:**
- *Что есть:* таблицы `collection_tasks` не существует.
- *Что добавить:* миграция создаёт таблицу с полями согласно FR-1 (spec.md §3): `requester_id string NOT NULL`, `plugin_type string NOT NULL`, `external_id string NOT NULL`, `source_config jsonb NOT NULL default {}`, `collection_mode string NOT NULL`, `poll_interval_seconds integer`, `webhook_secret string`, `state string NOT NULL default 'created'`, `retention_policy string NOT NULL`, `last_error text`, `consumed_at datetime`, `failed_at datetime`, `timestamps NOT NULL`. Индексы: `UNIQUE (requester_id, plugin_type, external_id)`, `INDEX (state)`, `UNIQUE (webhook_secret) WHERE webhook_secret IS NOT NULL` (partial).
- *Нельзя трогать:* существующие миграции, `sources` table.

**Implements:** REQ-1  
**Depends on:** нет зависимостей  
**Rollback:** `bundle exec rails db:rollback` — удаляет таблицу `collection_tasks`  
**Signal:** `bundle exec rails db:migrate:status` → строка `collection_tasks` UP

---

### STEP-2 [S]: Миграция — обновление `raw_ingest_items` (source_id → task_id)

**Файл:** `db/migrate/<YYYYMMDDHHMMSS>_migrate_raw_ingest_items_to_collection_task.rb` (СОЗДАТЬ)

**Дельта:**
- *Что есть:* `raw_ingest_items` имеет `source_id bigint NOT NULL`, FK → `sources`, уникальный индекс `(source_id, external_id)`.
- *Что добавить:* (1) удалить FK `fk_rails_*` на `sources`; (2) удалить старый уникальный индекс `(source_id, external_id)`; (3) переименовать колонку `source_id` → `task_id`; (4) добавить FK `task_id → collection_tasks(id) ON DELETE CASCADE`; (5) добавить уникальный индекс `(task_id, external_id)`; (6) добавить составной индекс `(task_id, id)` для cursor pagination.
- *Нельзя трогать:* другие колонки `raw_ingest_items`, таблицу `sources`.

**Implements:** REQ-2, REQ-4  
**Depends on:** STEP-1 (таблица `collection_tasks` должна существовать до добавления FK на неё)  
**Rollback:** `bundle exec rails db:rollback` — восстанавливает `source_id`  
**Signal:** `bundle exec rails db:migrate:status` → строка миграции UP; `\d raw_ingest_items` в psql показывает `task_id`

---

### STEP-3 [S]: Миграция — обновление `sync_checkpoints` (source_id → task_id)

**Файл:** `db/migrate/<YYYYMMDDHHMMSS>_migrate_sync_checkpoints_to_collection_task.rb` (СОЗДАТЬ)

**Дельта:**
- *Что есть:* `sync_checkpoints` имеет `source_id bigint NOT NULL`, FK → `sources` (с ON DELETE CASCADE), уникальный индекс `(source_id)`.
- *Что добавить:* (1) удалить FK `fk_rails_*` на `sources`; (2) удалить уникальный индекс `(source_id)`; (3) переименовать `source_id` → `task_id`; (4) добавить FK `task_id → collection_tasks(id) ON DELETE CASCADE`; (5) добавить уникальный индекс `(task_id)`.
- *Нельзя трогать:* колонку `position`, таблицу `sources`.

**Implements:** REQ-3  
**Depends on:** STEP-1  
**Rollback:** `bundle exec rails db:rollback`  
**Signal:** `bundle exec rails db:migrate:status` → строка UP; `\d sync_checkpoints` показывает `task_id`

---

### STEP-4b [S]: Применить миграции

**Команда:** `bundle exec rails db:migrate`

**Дельта:**
- *Что есть:* 3 новых файла миграции созданы, но не применены.
- *Что добавить:* применить STEP-1, STEP-2, STEP-3.
- *Нельзя трогать:* данные в `sources` (они останутся нетронутыми).

**Implements:** REQ-1, REQ-2, REQ-3, REQ-4  
**Depends on:** STEP-1, STEP-2, STEP-3  
**Rollback:** `bundle exec rails db:rollback STEP=3`  
**Signal:** `bundle exec rails db:migrate:status` → все три миграции UP; `db/schema.rb` обновлён

---

### STEP-5 [M]: Модель `CollectionTask`

**Файл:** `app/models/collection_task.rb` (СОЗДАТЬ)

**Дельта:**
- *Что есть:* файл отсутствует.
- *Что добавить:* класс `CollectionTask < ApplicationRecord` с:
  - `has_many :raw_ingest_items, foreign_key: :task_id, dependent: :destroy`
  - `has_one :sync_checkpoint, foreign_key: :task_id, dependent: :destroy`
  - Валидации presence: `requester_id`, `plugin_type`, `external_id`, `collection_mode`, `retention_policy`.
  - Валидация inclusion `plugin_type` ∈ `['telegram']`.
  - Валидация inclusion `retention_policy` ∈ `['delete', 'retain']`.
  - Валидация uniqueness `external_id, scope: [:requester_id, :plugin_type]`.
  - Валидация `poll_interval_seconds` > 0 если `collection_mode == 'polling'`.
  - `before_validation :enforce_collection_mode_immutability` — если `persisted?` и `collection_mode_changed?` → `errors.add`.
  - `before_validation :enforce_monotonic_timestamps` — если `consumed_at_was.present?` и `consumed_at.nil?` → `errors.add`; аналогично для `failed_at`.
  - Вложенный класс `InvalidTransitionError < StandardError`.
  - Константа `VALID_TRANSITIONS`: hash допустимых переходов (source_state → target_states).
  - Методы `queue!`, `start_collecting!`, `mark_ready!`, `consume!`, `fail!(error:)`, `delete!`.
  - Приватный метод `transition_to!(target_state)` — проверяет VALID_TRANSITIONS, затем `update!` state.
- *Нельзя трогать:* `Source`, `RawIngestItem`, `SyncCheckpoint` (отдельные шаги).

**Implements:** REQ-5, REQ-6  
**Depends on:** STEP-4b  
**Rollback:** удалить файл `app/models/collection_task.rb`  
**Signal:** `bundle exec ruby -c app/models/collection_task.rb` → `Syntax OK`; `bundle exec rails runner "puts CollectionTask.count"` → без ошибок

---

### STEP-6 [S]: Обновить `app/models/raw_ingest_item.rb`

**Файл:** `app/models/raw_ingest_item.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* `belongs_to :source`; метод `ingest!` принимает `source:` и использует `source_id: source.id`; лог содержит `source_id=`.
- *Что добавить:* (1) заменить `belongs_to :source` → `belongs_to :collection_task`; (2) в `ingest!`: параметр `source:` → `task:`, проверку `source.nil?` → `task.nil?`, `source_id: source.id` → `task_id: task.id`, лог `source_id=#{source.id}` → `task_id=#{task.id}`; (3) обновить `human_attribute_name` убрать ненужное (если есть); (4) в `insert(...)` убрать `source_id`, добавить `task_id`.
- *Нельзя трогать:* логику дедупликации (unique_by), нормализацию `external_id`, обработку nil `external_id`, нормализацию metadata.
- **Bulk-insert validation delta:** метод `ingest!` использует `insert` (bulk-path). AR-validations (presence, uniqueness) не вызываются автоматически при `insert`. Проверка nil/blank `external_id` и nil `task` уже реализована вручную перед `insert` через dummy instance + `raise`. Новый параметр `task:` должен использовать ту же логику: `raise ArgumentError, "task must not be nil" if task.nil?`.

**Implements:** REQ-7  
**Depends on:** STEP-4b, STEP-5  
**Rollback:** `git checkout app/models/raw_ingest_item.rb`  
**Signal:** `bundle exec ruby -c app/models/raw_ingest_item.rb` → `Syntax OK`

---

### STEP-7 [S]: Обновить `app/models/sync_checkpoint.rb`

**Файл:** `app/models/sync_checkpoint.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* `belongs_to :source`; `validates :position, exclusion: { in: [nil] }`.
- *Что добавить:* заменить `belongs_to :source` → `belongs_to :collection_task`.
- *Нельзя трогать:* валидацию `position`.

**Implements:** REQ-7  
**Depends on:** STEP-4b, STEP-5  
**Rollback:** `git checkout app/models/sync_checkpoint.rb`  
**Signal:** `bundle exec ruby -c app/models/sync_checkpoint.rb` → `Syntax OK`

---

### STEP-8 [S]: Обновить `app/models/source.rb` (deprecate broken associations)

**Файл:** `app/models/source.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* `has_one :sync_checkpoint, dependent: :destroy`; методы `upsert_checkpoint!` (использует `SyncCheckpoint.upsert({ source_id: id, ... })`), `sync_step!`, `reload_sync_checkpoint`, `validate_sync_result!`; `def sync_checkpoint` (custom query через `source_id`).
- *Что убрать:* удалить `has_one :sync_checkpoint, dependent: :destroy`; удалить методы `upsert_checkpoint!`, `sync_step!`, `reload_sync_checkpoint`, `validate_sync_result!`, `sync_checkpoint` (custom query). Эти методы опираются на `sync_checkpoints.source_id`, которого больше нет.
- *Что оставить:* `before_validation :normalize_identifiers`, все `validates`, `scope :for_sync`, `human_attribute_name`.
- *Нельзя трогать:* `plugin_type`, `external_id`, `sync_enabled` — логику валидации и нормализации.

**Implements:** REQ-7 (cleanup deprecated interface)  
**Depends on:** STEP-4b  
**Rollback:** `git checkout app/models/source.rb`  
**Signal:** `bundle exec ruby -c app/models/source.rb` → `Syntax OK`; `bundle exec rspec spec/models/source_spec.rb -e "validations"` → только validation examples зелёные

---

### STEP-9 [M]: Создать `spec/models/collection_task_spec.rb`

**Файл:** `spec/models/collection_task_spec.rb` (СОЗДАТЬ)

**Дельта:**
- *Что есть:* файл отсутствует.
- *Что добавить:* RSpec-файл с `require_relative "../rails_helper"`, покрывающий SC-1..SC-12 из spec.md:
  - Validations: presence полей, inclusion plugin_type, inclusion retention_policy, uniqueness, poll_interval_seconds с polling mode.
  - State machine: все допустимые переходы, InvalidTransitionError на недопустимых, fail!/retry, last_error cleanup.
  - Immutable collection_mode.
  - Monotonic consumed_at/failed_at.
  - Delete!: soft delete.
  - Cascade: уничтожение CollectionTask удаляет raw_ingest_items и sync_checkpoints.
  - Уникальность: AR-level + DB-level (adversarial RecordNotUnique).
- *Нельзя трогать:* существующие spec-файлы (отдельные шаги).

**Implements:** REQ-5, REQ-6 (test materialization)  
**Depends on:** STEP-5, STEP-4b  
**Rollback:** удалить файл  
**Signal:** `bundle exec rspec spec/models/collection_task_spec.rb --dry-run` → список examples без ошибок

---

### STEP-10 [S]: Обновить `spec/models/raw_ingest_item_spec.rb`

**Файл:** `spec/models/raw_ingest_item_spec.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* `let(:source) { Source.create!(...) }`; все вызовы `ingest!(source: source, ...)`; проверки `item.source_id`; лог-строка `"[RawIngestItem] skipped duplicate: source_id=#{source.id}..."`.
- *Что изменить:* (1) заменить `let(:source)` → `let(:task) { CollectionTask.create!(...) }`; (2) все `ingest!(source: source, ...)` → `ingest!(task: task, ...)`; (3) `item.source_id` → `item.task_id`; (4) лог-строку `source_id=#{source.id}` → `task_id=#{task.id}`; (5) `described_class.create!(source: source, ...)` → `described_class.create!(collection_task: task, ...)`.
- *Нельзя трогать:* логику тестов, проверки metadata, storage_key, дедупликации.

**Implements:** REQ-7 (test update)  
**Depends on:** STEP-6, STEP-9  
**Rollback:** `git checkout spec/models/raw_ingest_item_spec.rb`  
**Signal:** `bundle exec rspec spec/models/raw_ingest_item_spec.rb` → 0 failures

---

### STEP-11 [S]: Обновить `spec/models/sync_checkpoint_spec.rb`

**Файл:** `spec/models/sync_checkpoint_spec.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* `let(:source) { Source.create!(...) }`; `SyncCheckpoint.create!(source: source, ...)`; прямые SQL-INSERT с `source_id`; проверки `source.sync_checkpoint`; `SyncCheckpoint.where(source_id: source.id)`.
- *Что изменить:* (1) заменить `let(:source)` → `let(:task) { CollectionTask.create!(...) }`; (2) `SyncCheckpoint.create!(source: source, ...)` → `SyncCheckpoint.create!(collection_task: task, ...)`; (3) SQL-INSERT в ambiguity test: заменить `source_id` → `task_id`, индекс на `task_id`; (4) `source.sync_checkpoint` → необходимо переписать вокруг `task.sync_checkpoint` или прямых запросов; (5) `SyncCheckpoint.where(source_id: ...)` → `SyncCheckpoint.where(task_id: ...)`.
- *Что убрать:* тесты, завязанные на `Source#sync_checkpoint` (кастомный метод удалён в STEP-8); переписать как прямые AR-запросы через `CollectionTask`.
- *Нельзя трогать:* логику проверки валидации `position`.

**Implements:** REQ-7 (test update)  
**Depends on:** STEP-7, STEP-8, STEP-9  
**Rollback:** `git checkout spec/models/sync_checkpoint_spec.rb`  
**Signal:** `bundle exec rspec spec/models/sync_checkpoint_spec.rb` → 0 failures

---

### STEP-12 [S]: Обновить `spec/models/source_spec.rb` (mark deprecated)

**Файл:** `spec/models/source_spec.rb` (ИЗМЕНИТЬ)

**Дельта:**
- *Что есть:* тесты `#upsert_checkpoint!` и `#sync_step!` используют `SyncCheckpoint.where(source_id: ...)`, `source.sync_checkpoint` — методы удалены в STEP-8.
- *Что изменить:* пометить все примеры в `describe "#upsert_checkpoint!"` и `describe "#sync_step!"` как `pending "deprecated: Source#upsert_checkpoint! removed in #18"`. Тесты из `describe "validations"` и `describe ".for_sync"` остаются зелёными.
- *Нельзя трогать:* тесты валидаций, `.for_sync`, `normalize_identifiers`, `human_attribute_name`.

**Implements:** (regression safety)  
**Depends on:** STEP-8  
**Rollback:** `git checkout spec/models/source_spec.rb`  
**Signal:** `bundle exec rspec spec/models/source_spec.rb` → 0 failures, N pending

---

## 5. План тестирования

| Файл | Покрывает SC/REQ |
|------|-----------------|
| `spec/models/collection_task_spec.rb` (НОВЫЙ) | SC-1..SC-12; REQ-5, REQ-6 |
| `spec/models/raw_ingest_item_spec.rb` (ОБНОВЛЁН) | SC-11; REQ-7 |
| `spec/models/sync_checkpoint_spec.rb` (ОБНОВЛЁН) | SC-11; REQ-7 |
| `spec/models/source_spec.rb` (ОБНОВЛЁН — pending) | валидации Source остаются зелёными |

**Test materialization setup:**  
Тесты используют реальную БД (не моки). Перед запуском требуется:
```bash
RAILS_ENV=test bundle exec rails db:schema:load
```
Или если работает test DB уже: `bundle exec rails db:migrate RAILS_ENV=test`.  
В `spec/rails_helper.rb` конфигурация БД уже настроена — проверить перед запуском.

---

## 6. Финальный Runtime Gate

### Focused Verification (новый контракт)

```bash
bundle exec rspec spec/models/collection_task_spec.rb
```

Pass/fail signal: `N examples, 0 failures`. Если есть failures — стоп, диагностика.

### Regression Gate

```bash
bin/ci
```

Pass/fail signal: `N examples, 0 failures, N pending`. Если есть failures — стоп, диагностика.

**CHK-1** `bundle exec rails db:migrate:status` → все миграции UP  
**CHK-2** `bundle exec rspec spec/models/collection_task_spec.rb` → 0 failures  
**CHK-3** `bundle exec rspec spec/models/raw_ingest_item_spec.rb` → 0 failures  
**CHK-4** `bundle exec rspec spec/models/sync_checkpoint_spec.rb` → 0 failures  
**CHK-5** `bundle exec rspec spec/models/source_spec.rb` → 0 failures, pending examples  
**CHK-6** `bin/ci` → 0 failures  
**EVID-1** Carrier: `spec/models/collection_task_spec.rb` + вывод `bundle exec rspec`

---

## Allowlist (файлы, которые разрешено изменять)

Новые файлы:
- `db/migrate/<ts>_create_collection_tasks.rb`
- `db/migrate/<ts>_migrate_raw_ingest_items_to_collection_task.rb`
- `db/migrate/<ts>_migrate_sync_checkpoints_to_collection_task.rb`
- `app/models/collection_task.rb`
- `spec/models/collection_task_spec.rb`

Изменяемые файлы:
- `app/models/raw_ingest_item.rb`
- `app/models/sync_checkpoint.rb`
- `app/models/source.rb`
- `spec/models/raw_ingest_item_spec.rb`
- `spec/models/sync_checkpoint_spec.rb`
- `spec/models/source_spec.rb`
- `db/schema.rb` (автообновление)

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 01-3-generate-plan |

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
