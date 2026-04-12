---
issue: 2
type: code-review
iteration: 1
date: 2026-04-06
status: draft
---

# Code Review #1 — Issue #0002: Source и SyncCheckpoint

## Проанализированные файлы

**Diff рабочего дерева (`git diff HEAD`):**
- `core/lib/collect/errors.rb` — добавлен `CheckpointAmbiguityError < Error`

**Untracked новые файлы:**
- `app/models/source.rb`
- `app/models/sync_checkpoint.rb`
- `db/migrate/20260406120000_create_sources.rb`
- `db/migrate/20260406120100_create_sync_checkpoints.rb`
- `spec/rails_helper.rb`
- `spec/models/source_spec.rb`
- `spec/models/sync_checkpoint_spec.rb`

---

## 1. Предпосылки

1. `ApplicationRecord` и Rails-окружение существуют и корректно настроены — `source.rb:1` наследует от него.
2. `SyncCheckpoint.upsert` в Rails поддерживает `unique_by:` как с именем колонки (`source_id`), так и с именем индекса (`index_sync_checkpoints_on_source_id`) — оба варианта задокументированы, но различаются по поведению в некоторых версиях Rails.
3. PostgreSQL-адаптер ActiveRecord доступен; `jsonb` — нативный тип.
4. `spec/spec_helper.rb` существует (на него ссылается `rails_helper.rb:10`: `require_relative "spec_helper"`).
5. Тесты помечены `:db` — только они получают транзакционный rollback; это предположение, подтверждённое строками 3 `source_spec.rb` и `sync_checkpoint_spec.rb`.

---

## 2. Инварианты и контракты

### Инвариант 1: Уникальность источника `(plugin_type, external_id)`
- DB: `add_index :sources, %i[plugin_type external_id], unique: true` — `20260406120000_create_sources.rb:11`.
- AR: `validates :external_id, uniqueness: { scope: :plugin_type }` — `source.rb:9`.
- Нормализация: `before_validation :normalize_identifiers` → `plugin_type.to_s` / `external_id.to_s` — `source.rb:44–45`.
- **Статус: Сохраняется.** Оба уровня защиты присутствуют.

### Инвариант 2: Единственность checkpoint для источника
- DB: `index: { unique: true }` на `source_id` — `20260406120100_create_sync_checkpoints.rb:4`.
- AR: кастомный `sync_checkpoint` проверяет `count > 1 → CheckpointAmbiguityError` — `source.rb:36`.
- **Статус: Сохраняется.**

### Инвариант 3: Неизменность `position` после передачи в upsert
- `SyncCheckpoint.upsert` передаёт Hash в jsonb-колонку; PostgreSQL сериализует до персистенции, создавая независимую копию.
- Тест на мутацию аргумента: `source_spec.rb:103–109`.
- **Статус: Сохраняется** (jsonb сериализует при записи).

### Инвариант 4: Независимость checkpoint разных источников
- `upsert` использует `source_id` как conflict target → затрагивает только строку с данным `source_id`.
- **Статус: Сохраняется.**

### Инвариант 5: FK CASCADE DELETE
- Миграция: `foreign_key: { on_delete: :cascade }` — `20260406120100_create_sync_checkpoints.rb:4`.
- AR: `has_one :sync_checkpoint, dependent: :destroy` — `source.rb:2`.
- **Статус: Сохраняется** (двойная защита — DB cascade + AR dependent destroy).

---

## 3. Трассировка путей выполнения

### Happy path: создание Source с Symbol-ами

```
Source.create!(plugin_type: :telegram, external_id: :ch1, sync_enabled: true)
  → before_validation: :telegram.to_s = "telegram", :ch1.to_s = "ch1"   [source.rb:44–45]
  → validates :plugin_type, presence: true  → "telegram" ≠ "" → ✓
  → validates :external_id, uniqueness scope :plugin_type → ✓
  → validates :sync_enabled, inclusion: [true, false] → true → ✓
  → INSERT INTO sources ...
```

Соответствует FR #1, #2, #3.

### Happy path: upsert_checkpoint!

```
source.upsert_checkpoint!(position: { cursor: 42 })
  → position.nil? → false                                               [source.rb:20]
  → SyncCheckpoint.upsert(
      { source_id: id, position: { cursor: 42 } },
      unique_by: :index_sync_checkpoints_on_source_id,                  [source.rb:24]
      record_timestamps: true
    )
  → INSERT INTO sync_checkpoints ... ON CONFLICT (index) DO UPDATE
  → reload_sync_checkpoint:
      association(:sync_checkpoint).reset                               [source.rb:49]
      sync_checkpoint   [кастомный метод]
        → SyncCheckpoint.where(source_id: id)                          [source.rb:32]
        → count == 1 → return checkpoints.first                        [source.rb:38]
```

### Error path: plugin_type: nil

```
Source.create!(plugin_type: nil, ...)
  → before_validation: nil.to_s = ""
  → validates :plugin_type, presence: true → "" → RecordInvalid "Plugin type can't be blank"
```

Соответствует FR #1 и таблице сценариев `spec.md:50`.

### Error path: upsert_checkpoint!(position: nil)

```
source.upsert_checkpoint!(position: nil)
  → raise ArgumentError, "position must not be nil"                     [source.rb:20]
  → БД не затрагивается
```

Соответствует FR #8 и `spec.md:54`.

### Error path: sync_checkpoint при count > 1

```
source.sync_checkpoint
  → SyncCheckpoint.where(source_id: id).count → 2
  → raise Collect::CheckpointAmbiguityError, "multiple checkpoints..."  [source.rb:36]
```

Соответствует FR #9.

### Важный нюанс: переопределение AR-ассоциации

`has_one :sync_checkpoint, dependent: :destroy` (source.rb:2) объявляет ассоциацию, но кастомный метод `def sync_checkpoint` (source.rb:31) перекрывает сгенерированный Rails аксессор.

- `dependent: :destroy` использует внутренний `association_scope` через reflection, а не публичный метод — CASCADE destroy **не нарушается**.
- `reload_sync_checkpoint` вызывает `association(:sync_checkpoint).reset` (сбрасывает AR-кэш) и затем кастомный `sync_checkpoint` (делает fresh query). Логически корректно.
- `runtime-unknown gate`: подтверждается тестом `"deletes dependent checkpoints when the source is destroyed"` в `sync_checkpoint_spec.rb:63–69`.

---

## 4. Риски и регрессии

### Risk 1 [medium]: `unique_by:` с именем индекса вместо column symbol

- **Где:** `source.rb:24` — `unique_by: :index_sync_checkpoints_on_source_id`.
- **Spec-паттерн:** `spec.md:96` — `unique_by: :source_id`.
- **Почему реален:** Rails `upsert` с `unique_by:` принимает имя индекса, однако поведение зависит от версии Rails и адаптера. В некоторых версиях Rails 7.x неизвестное имя индекса в `unique_by:` игнорируется и `upsert` выполняется как обычный INSERT без `ON CONFLICT DO UPDATE`, что нарушит инвариант единственности checkpoint (`RecordNotUnique` вместо тихого upsert). Это отклонение от явно указанного паттерна спецификации — `runtime-unknown gate`.
- **Тест который поймает:** `source_spec.rb:79–85` — "updates an existing checkpoint without creating duplicates" при запуске покажет, работает ли upsert корректно.

### Risk 2 [medium]: `config.use_transactional_tests` не задан явно

- **Где:** `spec/rails_helper.rb` — отсутствует `config.use_transactional_tests = true`.
- **Spec требует:** `spec.md:83` — "использует стандартные Rails transactional tests (`config.use_transactional_tests = true`)".
- **Реализовано:** manual `config.around(:each, :db)` с rollback — `rails_helper.rb:15–21`.
- **Provable defect относительно буквы спецификации:** все текущие тесты помечены `:db` и получают изоляцию. Но любой тест без `:db` тега (добавленный в будущем) не будет изолирован, что нарушит намерение спецификации. Кроме того, `use_transactional_tests = true` применяется глобально включая хелперы и fixtures.

### Risk 3 [low]: двойной DB-запрос в `reload_sync_checkpoint`

- **Где:** `source.rb:48–51`.
- После каждого `upsert_checkpoint!`: count-query + first-query через кастомный `sync_checkpoint`. Итого 2 дополнительных запроса к БД.
- **Функционально корректно.** `runtime-unknown`: насколько это критично при высокой нагрузке.

### Risk 4 [low]: переопределение AR-ассоциации `has_one`

- **Где:** `source.rb:2` (ассоциация) vs `source.rb:31` (кастомный метод).
- `dependent: :destroy` работает через Rails reflection, а не публичный метод — риск минимален. Покрыт тестом `sync_checkpoint_spec.rb:63–69`.

---

## 5. Вердикт по эквивалентности

**Acceptance Criteria: Source — валидация**

| AC | Реализовано | Тест |
|---|---|---|
| Создаёт с валидными атрибутами | ✓ `source.rb:6–9` | `source_spec.rb:5–11` |
| Отклоняет `plugin_type: nil` | ✓ нормализуется к `""`, `presence` ловит | `source_spec.rb:13–17` |
| Отклоняет `external_id: ""` | ✓ нормализуется к `""`, `presence` ловит | `source_spec.rb:19–23` |
| Отклоняет `sync_enabled: nil` | ✓ `inclusion: [true, false]` | `source_spec.rb:25–29` |
| Дубль → RecordInvalid "has already been taken" | ✓ `uniqueness` scope | `source_spec.rb:31–37` |
| Symbol нормализуется к String | ✓ `before_validation` | `source_spec.rb:39–44` |

**Acceptance Criteria: Source — for_sync**

| AC | Реализовано | Тест |
|---|---|---|
| Только `sync_enabled: true` | ✓ `where(sync_enabled: true)` `source.rb:11` | `source_spec.rb:57–61` |
| Пустой relation | ✓ | `source_spec.rb:63–67` |

**Acceptance Criteria: Source — upsert_checkpoint!**

| AC | Реализовано | Тест |
|---|---|---|
| Создаёт checkpoint | ✓ | `source_spec.rb:73–76` |
| Обновляет без дублей | ✓ (runtime-unknown: зависит от `unique_by`) | `source_spec.rb:79–85` |
| Идемпотентность | ✓ | `source_spec.rb:88–93` |
| ArgumentError для nil до БД | ✓ `source.rb:20` | `source_spec.rb:95–100` |
| Мутация аргумента не влияет | ✓ jsonb сериализует | `source_spec.rb:103–109` |

**Acceptance Criteria: SyncCheckpoint**

| AC | Реализовано | Тест |
|---|---|---|
| nil если нет checkpoint | ✓ `source.rb:35` | `sync_checkpoint_spec.rb:27–29` |
| Возвращает объект | ✓ `source.rb:38` | `sync_checkpoint_spec.rb:31–34` |
| CheckpointAmbiguityError при count > 1 | ✓ `source.rb:36` | `sync_checkpoint_spec.rb:37–60` |
| Без source_id → RecordInvalid | ✓ `belongs_to :source` | `sync_checkpoint_spec.rb:8–10` |
| position: {} допустимо | ✓ `exclusion: { in: [nil] }` | `sync_checkpoint_spec.rb:13–17` |
| position: nil → RecordInvalid | ✓ | `sync_checkpoint_spec.rb:19–23` |

**Инварианты (AC):**

| AC | Реализовано | Тест |
|---|---|---|
| Нет дублей `(plugin_type, external_id)` | ✓ DB index + AR uniqueness | `source_spec.rb:31–37` |
| count <= 1 после upsert | ✓ (runtime-unknown) | `source_spec.rb:88–93` |
| Обновление source_a не меняет source_b | ✓ `upsert` по `source_id` | `source_spec.rb:112–121` |
| После destroy → count == 0 | ✓ CASCADE + dependent: :destroy | `sync_checkpoint_spec.rb:63–69` |
| core/lib тесты зелёные | `runtime-unknown gate` — нет изменений логики, только добавление класса |  |

**Вердикт: Эквивалентно**

Все функциональные FR и инварианты выглядят соблюдёнными по статическому анализу кода. Остающиеся неопределённости (Risk 1, Risk 2) являются `runtime-unknown gate`-ами: их нельзя опровергнуть без запуска тестов.

> Контрпример для Risk 1 потребовал бы доказательства, что конкретная версия Rails игнорирует имя индекса в `unique_by:` — это нельзя доказать без запуска, поэтому не является `provable defect`.

---

## 6. Что проверить тестами (топ-5)

1. **Idempotency `upsert_checkpoint!` при повторном вызове** — `source_spec.rb:79–85` проверит, что `unique_by: :index_sync_checkpoints_on_source_id` работает как `ON CONFLICT DO UPDATE`, а не как вставка с ошибкой. Закрывает Risk 1.

2. **`source.destroy` → отсутствие checkpoint в БД** — `sync_checkpoint_spec.rb:63–69`. Закрывает Risk 4 (конфликт кастомного метода и `dependent: :destroy`).

3. **CheckpointAmbiguityError через прямой SQL** — `sync_checkpoint_spec.rb:37–60`. Тест сложен (drop/recreate index), но покрывает ключевой инвариант FR #9.

4. **Транзакционная изоляция между тестами** — убедиться, что `:db` тег обеспечивает rollback и данные не протекают между it-блоками. Закрывает Risk 2.

5. **`source.sync_checkpoint` при прямом `SyncCheckpoint.create!`** — что кастомный метод возвращает объект, а не обходит его через AR-ассоциацию. Покрыт `sync_checkpoint_spec.rb:31–34`.

---

## 7. Confidence

**0.82**

Мешает дать 1.0:
- `unique_by: :index_sync_checkpoints_on_source_id` (source.rb:24) — отклонение от spec-паттерна (`unique_by: :source_id`); поведение верифицируется только запуском. Если Rails-версия не резолвит имя индекса, upsert сломается.
- `rails_helper.rb` не устанавливает `config.use_transactional_tests = true` явно — отклонение от буквы спецификации (spec.md:83).
- `db/schema.rb` не читался (untracked file) — нет подтверждения, что схема совпадает с миграциями.
