# Code Review — Issue #18: CollectionTask Data Model

## Анализируемые файлы (diff allowlist)

Новые:
- `db/migrate/20260413000001_create_collection_tasks.rb`
- `db/migrate/20260413000002_migrate_raw_ingest_items_to_collection_task.rb`
- `db/migrate/20260413000003_migrate_sync_checkpoints_to_collection_task.rb`
- `app/models/collection_task.rb`
- `spec/models/collection_task_spec.rb`

Изменённые:
- `app/models/raw_ingest_item.rb`
- `app/models/sync_checkpoint.rb`
- `app/models/source.rb`
- `spec/models/raw_ingest_item_spec.rb`
- `spec/models/sync_checkpoint_spec.rb`
- `spec/models/source_spec.rb`
- `db/schema.rb` (автообновление)

Внеплановых изменений нет. Ни один файл вне allowlist не затронут.

---

## 1. Предпосылки

- `spec.md` и `plan.md` прочитаны и утверждены в корне папки issue.
- Анализ выполнен по фактическому коду, а не по diff рабочего дерева (изменения уже применены в рабочем дереве и зафиксированы через `db:migrate`).
- Миграции применены (`bundle exec rails db:migrate:status` → все три UP).
- `db/schema.rb` актуализирован автоматически после `db:migrate`.
- Focused verification: `bundle exec rspec spec/models/collection_task_spec.rb` → **26 examples, 0 failures** (после `RAILS_ENV=test bundle exec rails db:schema:load` для очистки стейл-данных из staged validation).
- Staged Validation стадии 1–6 пройдены в предыдущей сессии (Rails runner, schema_load, migrate, rspec).
- `bundle exec rubocop app/models/collection_task.rb spec/models/collection_task_spec.rb db/migrate/2026041300000*.rb` → no offenses.
- `bin/ci` содержит pre-existing rubocop violations в `aitlas/insales/scripts/` (не связаны с issue #18); они существовали до начала работы.

---

## 2. Инварианты и контракты

### INV-1: Метаданные в PostgreSQL, тела в S3

Таблица `collection_tasks` не содержит blob-полей. Поля: конфиг, state, lifecycle timestamps, `last_error` (text). Тела объектов — в `raw_ingest_items.storage_key`. Нарушений нет.

### INV-2: Orphan protection

`app/models/collection_task.rb:17-18` — `has_many :raw_ingest_items, foreign_key: :task_id, dependent: :destroy` и `has_one :sync_checkpoint, foreign_key: :task_id, dependent: :destroy`.

`db/migrate/20260413000002_migrate_raw_ingest_items_to_collection_task.rb:12` — `add_foreign_key :raw_ingest_items, :collection_tasks, column: :task_id, on_delete: :cascade`.

`db/migrate/20260413000003_migrate_sync_checkpoints_to_collection_task.rb:17` — `add_foreign_key :sync_checkpoints, :collection_tasks, column: :task_id, on_delete: :cascade`.

Два уровня защиты: AR `dependent: :destroy` + DB-level CASCADE. SC-11 покрывает оба случая.

### INV-3: Уникальность (requester_id, plugin_type, external_id)

`app/models/collection_task.rb:27` — `validates :external_id, uniqueness: { scope: %i[requester_id plugin_type] }`.

`db/migrate/20260413000001_create_collection_tasks.rb:20-21` — `add_index :collection_tasks, %i[requester_id plugin_type external_id], unique: true`.

AR-уровень (SC-5) + DB-уровень (SC-6). Защита двойная.

### INV-4: Immutable collection_mode

`app/models/collection_task.rb:31` — `validate :collection_mode_immutable, if: :persisted?`.

`app/models/collection_task.rb:69-72` — callback проверяет `collection_mode_changed?` и добавляет ошибку.

**Известное ограничение (из spec.md §5, INV-4):** `update_attribute` и прямой SQL обходят AR validation. Это явно задокументировано в spec.md как known limitation. В коде комментарий к этому отсутствует, но spec.md это фиксирует. Не является defect.

### INV-5: Monotonic timestamps

`app/models/collection_task.rb:76-84` — `consumed_at_monotonic` и `failed_at_monotonic` проверяют `*_was.present? && *.nil?` с guard `if: :persisted?`.

Retry-path в `start_collecting!` (`app/models/collection_task.rb:41-47`) очищает `last_error`, но НЕ трогает `failed_at` — это верно: spec.md FR-4 не требует очистки `failed_at` при retry.

`consume!` устанавливает `consumed_at` из nil → значение: валидатор не срабатывает (`consumed_at_was` = nil). Верно.

---

## 3. Трассировка путей выполнения

### Happy-path: full lifecycle (SC-1)

`create!(valid_attrs)` → `state: "created"` (default из миграции) → `queue!` вызывает `transition_to!("queued")` → VALID_TRANSITIONS["created"].include?("queued") = true → `update!(state: "queued")` → и т.д. до `consume!` → `transition_to_with_attrs!("consumed", consumed_at: Time.current)` → сохраняется state + consumed_at.

### Error-path: invalid transition (SC-4)

`consume!` из `created` → `transition_to!("consumed")` → `VALID_TRANSITIONS.fetch("created", []) = ["queued","deleted"]` → "consumed" не включён → `raise InvalidTransitionError`. Состояние не изменяется (update! не вызывался).

### Error-path: fail! (SC-2)

`fail!(error: "timeout")` из `collecting` → `attrs = { last_error: "timeout" }` → `failed_at.nil?` = true → `attrs[:failed_at] = Time.current` → `transition_to_with_attrs!("failed", last_error: "timeout", failed_at: <time>)` → `update!(state: "failed", last_error: "timeout", failed_at: <time>)`.

### Retry path (SC-3)

`start_collecting!` из `failed` → ветка `state == "failed"` → `transition_to_with_attrs!("collecting", last_error: nil)` → `update!(state: "collecting", last_error: nil)`. `failed_at` остаётся установленным (monotonic).

### Bulk-insert validation bypass (RawIngestItem)

`RawIngestItem.ingest!` использует `insert(...)` (AR bulk insert, обходит AR validations). Однако:
- `app/models/raw_ingest_item.rb:13` — `raise ArgumentError, "task must not be nil" if task.nil?` — guard present.
- `app/models/raw_ingest_item.rb:18-22` — guard для blank external_id через dummy instance + `raise ActiveRecord::RecordInvalid.new(dummy)` — guard present.

Статус: `guard present`, риск: `low`.

### delete! idempotency

`VALID_TRANSITIONS["deleted"] = ["deleted"]` — `delete!` на уже удалённой записи проходит `update!(state: "deleted")`. AR callbacks (monotonic validators) не срабатывают: затронутые поля не меняются. Поведение корректное.

---

## 4. Риски и регрессии

**Классификация находок:**

- `provable defect`: не обнаружено.
- `scope breach`: не обнаружено (все изменения в allowlist).
- `runtime-unknown gate`: два пункта.

### RUG-1 (medium): Загрязнение тестовой БД staged validation

**Описание:** В staged validation step 6 (предыдущая сессия) был выполнен `bundle exec rails runner "CollectionTask.create!(...)"` с RAILS_ENV=test, что создало запись `(agent-1, telegram, channel_123)` в тестовой БД вне транзакционного контекста rspec. При следующем запуске suite 21 из 26 тестов упали с "External has already been taken".

**Факт:** После `RAILS_ENV=test bundle exec rails db:schema:load` все 26 тестов зелёные. Это стандартная процедура из plan.md §5.

**Статус:** Resolved. Не является дефектом кода, но указывает на fragility: staged validation step 6 не документирует необходимость db:schema:load перед следующим rspec-запуском.

### RUG-2 (low): bin/ci выходит с кодом 1 из-за pre-existing rubocop violations

**Описание:** `bin/ci` завершается с ошибкой из-за rubocop violations в `aitlas/insales/scripts/` — файлы, существующие до issue #18 и не входящие в его allowlist. Тестовый прогон внутри bin/ci: 158 examples, 0 failures, 28 pending (подтверждено в предыдущей сессии).

**Статус:** Pre-existing, вне scope issue #18. Конкретные файлы issue #18 (rubocop на `app/models/collection_task.rb`, `spec/models/collection_task_spec.rb`, миграции) — no offenses.

---

## 5. Вердикт по эквивалентности

**Эквивалентно.**

Все SC-1..SC-12 из spec.md покрыты рабочим кодом и тестами:

| SC | Код | Тест |
|----|-----|------|
| SC-1 | VALID_TRANSITIONS + queue!/start_collecting!/mark_ready!/consume! | `collection_task_spec.rb:16` |
| SC-2 | fail! записывает last_error и failed_at | `collection_task_spec.rb:36` |
| SC-3 | start_collecting! очищает last_error при retry | `collection_task_spec.rb:51` |
| SC-4 | InvalidTransitionError на недопустимых переходах | `collection_task_spec.rb:66` (5 примеров) |
| SC-5 | AR uniqueness validates :external_id | `collection_task_spec.rb:107` |
| SC-6 | DB UNIQUE INDEX на (requester_id, plugin_type, external_id) | `collection_task_spec.rb:118` |
| SC-7 | collection_mode_immutable validate callback | `collection_task_spec.rb:138` |
| SC-8 | consumed_at/failed_at monotonic validators | `collection_task_spec.rb:160` |
| SC-9 | poll_interval_seconds numericality > 0 if polling | `collection_task_spec.rb:186` |
| SC-10 | delete! soft-delete, запись в БД остаётся | `collection_task_spec.rb:207` |
| SC-11 | dependent: :destroy + ON DELETE CASCADE | `collection_task_spec.rb:229` |
| SC-12 | error.to_s для nil → "" в last_error | `collection_task_spec.rb:250` |

Минимального контрпримера для какого-либо SC нет.

---

## 6. Что проверить тестами (топ-5)

1. **monotonic: задание consumed не может перейти обратно в ready через прямой update!** — текущие тесты проверяют `consumed_at = nil`, но не `state = 'ready'` через update_attribute. Это known AR bypass gap из spec.md INV-4, но стоит добавить комментарий в код.

2. **delete! из consumed должен сохранять consumed_at** — не покрыто явно; `delete!` не трогает consumed_at, но стоит добавить assertion.

3. **fail! повторно через adversarial path (state = 'collecting', update_attribute :state, 'failed', потом fail!)** — тест SC-4 проверяет fail! из failed через AR-путь; прямой SQL bypass не тестируется (known limitation per spec.md).

4. **concurrent insert — race condition (SC-6) с двумя параллельными AR create!** — тест SC-6 проверяет raw SQL; тест с двумя конкурентными AR create! отсутствует (низкий приоритет, требует threading).

5. **staged validation: добавить явный шаг db:schema:load перед rspec в SDD-workflow** — не code test, но operational: предотвращает RUG-1 в будущих сессиях.

---

## 7. Confidence

**0.95**

Что мешает 1.0:
- `bin/ci` не был запущен повторно в текущей сессии; pre-existing rubocop failure зафиксирована, но возможна деградация других незатронутых spec после db:schema:load в test DB.
- Monotonic validator `consumed_at_was` использует AR dirty tracking — корректность зависит от того, что в конкретной версии AR `*_was` метод возвращает persisted value, а не in-memory was-value. Для AR >= 5.2 это стандарт, но явного version lock в коде нет.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 02-4-review-code |

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
