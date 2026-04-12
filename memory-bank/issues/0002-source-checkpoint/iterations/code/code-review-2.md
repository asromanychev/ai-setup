---
issue: 2
type: code-review
iteration: 2
date: 2026-04-06
status: draft
---

# Code Review #2 — Issue #0002: Source и SyncCheckpoint

> Это повторное ревью. Относительно `code-review-1.md` добавлен `db/schema.rb` (ранее не был прочитан), уточнена оценка рисков Risk 1 и Risk 2.

## Проанализированные файлы

**Diff рабочего дерева (`git diff HEAD`):**
- `core/lib/collect/errors.rb` — добавлен `CheckpointAmbiguityError < Error`

**Untracked новые файлы:**
- `app/models/source.rb`
- `app/models/sync_checkpoint.rb`
- `db/migrate/20260406120000_create_sources.rb`
- `db/migrate/20260406120100_create_sync_checkpoints.rb`
- `db/schema.rb`
- `spec/rails_helper.rb`
- `spec/models/source_spec.rb`
- `spec/models/sync_checkpoint_spec.rb`

---

## 1. Предпосылки

1. `ApplicationRecord` и Rails-окружение существуют и корректно настроены — `source.rb:1` наследует от него.
2. Rails 7+ / 8.x с PostgreSQL-адаптером: `upsert` с `unique_by:` принимает как имя колонки, так и имя индекса (строка/символ).
3. `db/schema.rb` сгенерирован реальным `rails db:migrate` — подтверждение, что миграции применялись.
4. `spec/spec_helper.rb` существует и подгружается через `require_relative "spec_helper"` в `rails_helper.rb:10`; двойной `require "collect"` идемпотентен.
5. Транзакционная изоляция тестов реализована через `config.around(:each)` без тегов — охватывает все примеры.

---

## 2. Инварианты и контракты

### Инвариант 1: Уникальность источника `(plugin_type, external_id)`

- DB: `add_index :sources, %i[plugin_type external_id], unique: true` — `20260406120000_create_sources.rb:11`, подтверждён `schema.rb:23`.
- AR: `validates :external_id, uniqueness: { scope: :plugin_type }` — `source.rb:9`.
- Нормализация: `before_validation :normalize_identifiers` → `.to_s` — `source.rb:44–45`.
- **Статус: Сохраняется.** Оба уровня защиты присутствуют и подтверждены схемой.

### Инвариант 2: Единственность checkpoint для источника

- DB: `index: { unique: true }` на `source_id` — `20260406120100_create_sync_checkpoints.rb:4`, подтверждён `schema.rb:31` (имя индекса `index_sync_checkpoints_on_source_id`).
- AR: кастомный `sync_checkpoint` проверяет `count > 1 → CheckpointAmbiguityError` — `source.rb:36`.
- `upsert` использует `unique_by: :index_sync_checkpoints_on_source_id` — `source.rb:24`. Имя индекса совпадает с `schema.rb:31`.
- **Статус: Сохраняется.**

### Инвариант 3: Неизменность `position` после upsert

- jsonb сериализует hash при передаче в INSERT; мутация оригинала после вызова не влияет.
- Подкреплён тестом `source_spec.rb:103–109`.
- **Статус: Сохраняется.**

### Инвариант 4: Независимость checkpoint разных источников

- `upsert` ограничен `source_id` как conflict target → только строка конкретного источника.
- Подкреплён тестом `source_spec.rb:112–121` и `sync_checkpoint_spec.rb:71–78`.
- **Статус: Сохраняется.**

### Инвариант 5: FK CASCADE DELETE

- DB: `foreign_key: { on_delete: :cascade }` — миграция `20260406120100_create_sync_checkpoints.rb:4`, подтверждён `schema.rb:34`.
- AR: `has_one :sync_checkpoint, dependent: :destroy` — `source.rb:2`.
- **Статус: Сохраняется** (двойная защита).

---

## 3. Трассировка путей выполнения

### Happy path: `Source.create!` с Symbol-ами

```
Source.create!(plugin_type: :telegram, external_id: :ch1, sync_enabled: true)
  → before_validation: :telegram.to_s = "telegram", :ch1.to_s = "ch1"   [source.rb:44–45]
  → validates :plugin_type, presence: true  → "telegram" ≠ "" → ✓
  → validates :external_id, uniqueness scope :plugin_type → ✓
  → validates :sync_enabled, inclusion: [true, false] → true → ✓
  → INSERT INTO sources ...
```

### Happy path: `upsert_checkpoint!`

```
source.upsert_checkpoint!(position: { cursor: 42 })
  → position.nil? → false                                                [source.rb:20]
  → SyncCheckpoint.upsert(
      { source_id: id, position: { cursor: 42 } },
      unique_by: :index_sync_checkpoints_on_source_id,                   [source.rb:24]
      record_timestamps: true
    )
  → INSERT INTO sync_checkpoints ... ON CONFLICT (index_sync_checkpoints_on_source_id)
    DO UPDATE SET position = excluded.position, updated_at = ...
  → reload_sync_checkpoint:
      association(:sync_checkpoint).reset                                [source.rb:49]
      sync_checkpoint  [кастомный метод → count query + first query]     [source.rb:31–38]
```

### Error path: `plugin_type: nil`

```
Source.create!(plugin_type: nil, ...)
  → before_validation: nil.to_s = ""
  → validates :plugin_type, presence: true → "" → RecordInvalid "Plugin type can't be blank"
```

Соответствует FR #1, таблице `spec.md:50`.

### Error path: `upsert_checkpoint!(position: nil)`

```
source.upsert_checkpoint!(position: nil)
  → raise ArgumentError, "position must not be nil"                      [source.rb:20]
  → БД не затрагивается
```

Соответствует FR #8, `spec.md:54`.

### Error path: `sync_checkpoint` при `count > 1`

```
source.sync_checkpoint
  → SyncCheckpoint.where(source_id: id).count → 2
  → raise Collect::CheckpointAmbiguityError                             [source.rb:36]
```

Соответствует FR #9.

### Нюанс: кастомный `sync_checkpoint` перекрывает AR-аксессор

`has_one :sync_checkpoint, dependent: :destroy` (`source.rb:2`) регистрирует reflection; кастомный `def sync_checkpoint` (`source.rb:31`) перекрывает публичный аксессор. Rails `dependent: :destroy` использует `association_scope` через reflection — **не вызывает публичный метод**, поэтому CASCADE-поведение не нарушено. Подтверждено тестом `sync_checkpoint_spec.rb:63–69`.

---

## 4. Риски и регрессии

### Risk 1 [low]: `unique_by:` — имя индекса вместо имени колонки (пересмотрен)

- **Где:** `source.rb:24` — `unique_by: :index_sync_checkpoints_on_source_id`.
- **Spec-паттерн:** `spec.md:96` — `unique_by: :source_id`.
- **Новое:** `db/schema.rb:31` подтверждает существование индекса `index_sync_checkpoints_on_source_id`. В Rails 7+ (см. `ActiveRecord::InsertAll`) `unique_by:` принимает как column symbol, так и index name symbol для PostgreSQL-адаптера.
- **Оценка:** это отклонение от шаблона спецификации, но не провальный дефект. `runtime-unknown gate`: корректность `ON CONFLICT` clause верифицируется при запуске.
- **Downgraded с medium → low** по сравнению с code-review-1, поскольку индекс подтверждён в схеме.

### Risk 2 [low]: `config.use_transactional_tests = true` не задан явно (пересмотрен)

- **Где:** `spec/rails_helper.rb` — отсутствует `config.use_transactional_tests = true`.
- **Spec требует:** `spec.md:83`.
- **Реализовано:** `config.around(:each)` без тегов — `rails_helper.rb:15–21`. Охватывает **все** примеры (не только с тегом `:db`, как ошибочно предполагалось в code-review-1).
- **Функционально:** `around(:each)` с `raise ActiveRecord::Rollback` эквивалентно `use_transactional_tests = true` — обе стратегии оборачивают каждый пример в транзакцию, откатываемую после завершения.
- **Остаток риска:** нет типичного lifecycle: `use_transactional_tests` вызывает `before/after_setup_fixtures`, что важно при фикстурах. При отсутствии фикстур в этом issue — **функционально нейтрально**. Отклонение от буквы спецификации сохраняется.
- **Downgraded с medium → low**.

### Risk 3 [low]: двойной DB-запрос в `reload_sync_checkpoint`

- **Где:** `source.rb:48–51`. Каждый `upsert_checkpoint!` делает `count` + `first`.
- Функционально корректно; `runtime-unknown` по нагрузочному эффекту.

---

## 5. Вердикт по эквивалентности

### Acceptance Criteria: Source — валидация

| AC | Реализовано | Тест |
|---|---|---|
| Создаёт с валидными атрибутами | ✓ `source.rb:6–9` | `source_spec.rb:5–11` |
| Отклоняет `plugin_type: nil` | ✓ `nil.to_s = ""`, presence ловит | `source_spec.rb:13–17` |
| Отклоняет `external_id: ""` | ✓ нормализуется к `""`, presence ловит | `source_spec.rb:19–23` |
| Отклоняет `sync_enabled: nil` | ✓ `inclusion: [true, false]` | `source_spec.rb:25–29` |
| Дубль → RecordInvalid "has already been taken" | ✓ AR uniqueness scope | `source_spec.rb:31–37` |
| Symbol нормализуется, не создаёт дубль | ✓ `before_validation` | `source_spec.rb:39–44` |

### Acceptance Criteria: Source — for_sync

| AC | Реализовано | Тест |
|---|---|---|
| Только `sync_enabled: true` | ✓ `where(sync_enabled: true)` `source.rb:11` | `source_spec.rb:57–61` |
| Пустой relation | ✓ | `source_spec.rb:63–67` |

### Acceptance Criteria: Source — upsert_checkpoint!

| AC | Реализовано | Тест |
|---|---|---|
| Создаёт checkpoint | ✓ | `source_spec.rb:73–76` |
| Обновляет без дублей | ✓ (runtime-unknown: `unique_by` с именем индекса) | `source_spec.rb:79–85` |
| Идемпотентность | ✓ | `source_spec.rb:88–93` |
| ArgumentError для nil до БД | ✓ `source.rb:20` | `source_spec.rb:95–100` |
| Мутация аргумента не влияет | ✓ jsonb сериализует копию | `source_spec.rb:103–109` |
| Обновление A не меняет B | ✓ `upsert` по `source_id` | `source_spec.rb:112–121` |

### Acceptance Criteria: SyncCheckpoint

| AC | Реализовано | Тест |
|---|---|---|
| nil если нет checkpoint | ✓ `source.rb:35` | `sync_checkpoint_spec.rb:27–29` |
| Возвращает объект | ✓ `source.rb:38` | `sync_checkpoint_spec.rb:31–34` |
| CheckpointAmbiguityError при count > 1 | ✓ `source.rb:36` | `sync_checkpoint_spec.rb:37–60` |
| Без source_id → RecordInvalid | ✓ `belongs_to :source` | `sync_checkpoint_spec.rb:8–10` |
| `position: {}` допустимо | ✓ `exclusion: { in: [nil] }` | `sync_checkpoint_spec.rb:13–17` |
| `position: nil` → RecordInvalid | ✓ | `sync_checkpoint_spec.rb:19–23` |

### Инварианты (AC)

| AC | Реализовано | Тест |
|---|---|---|
| Нет дублей `(plugin_type, external_id)` | ✓ DB index + AR | `source_spec.rb:31–37` |
| count ≤ 1 после upsert | ✓ (`runtime-unknown gate`) | `source_spec.rb:88–93` |
| Обновление source_a не меняет source_b | ✓ | `source_spec.rb:112–121` |
| После destroy → count == 0 | ✓ CASCADE + dependent:destroy | `sync_checkpoint_spec.rb:63–69` |
| `core/lib` тесты зелёные | `runtime-unknown gate` — только добавлен класс-потомок | — |

**Вердикт: Эквивалентно**

Все функциональные FR и инварианты выглядят соблюдёнными по статическому анализу. `db/schema.rb` подтверждает, что структура таблиц и индексов соответствует миграциям и спецификации. Остающиеся неопределённости (Risk 1, Risk 2) являются `runtime-unknown gate`-ами: нет провального контрпримера, строимого только по коду.

---

## 6. Что проверить тестами (топ-5)

1. **`upsert_checkpoint!` дважды подряд с разным `position`** — `source_spec.rb:79–85` подтвердит, что `unique_by: :index_sync_checkpoints_on_source_id` резолвится в `ON CONFLICT DO UPDATE`, а не CREATE DUPLICATE. Закрывает Risk 1.

2. **`source.destroy` → `SyncCheckpoint.where(source_id:).count == 0`** — `sync_checkpoint_spec.rb:63–69`. Проверяет, что кастомный `def sync_checkpoint` не сломал `dependent: :destroy`.

3. **`source.sync_checkpoint` при двух строках через прямой SQL** — `sync_checkpoint_spec.rb:37–60`. Тест сложен (DROP/RECREATE index), но покрывает инвариант FR #9 и Collect::CheckpointAmbiguityError.

4. **Транзакционная изоляция**: убедиться, что данные не протекают между примерами — данные, созданные в одном `it`-блоке, не видны в следующем. Подтвердит корректность `around(:each)`.

5. **`SyncCheckpoint.upsert` с `record_timestamps: true`** — `updated_at` обновляется при конфликте. Менее критично, но проверяет, что `record_timestamps` работает корректно при `ON CONFLICT DO UPDATE`.

---

## 7. Confidence

**0.88**

Мешает дать 1.0:
- `unique_by: :index_sync_checkpoints_on_source_id` (`source.rb:24`) — индекс подтверждён в `schema.rb:31`, но Rails-обработка имени индекса в `ON CONFLICT` clause верифицируется только при запуске. В code-review-1 этот риск был medium; после проверки схемы снижен до low.
- `config.use_transactional_tests = true` не задан явно (`rails_helper.rb`) — отклонение от буквы spec, функционально нейтральное при отсутствии fixtures.
- Green suite `core/lib` — `runtime-unknown gate`, без запуска тестов нельзя подтвердить, что добавление `CheckpointAmbiguityError` не сломало ничего в `spec/collect/` (хотя статически это невозможно при чисто аддитивном изменении).

---

0 замечаний
