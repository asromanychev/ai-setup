---
issue: 2
title: Персистентность источников и контрольных точек синка
status: draft
version: v5
date: 2026-04-05
---

# Specification: Source и SyncCheckpoint (Issue #0002)

#### 1. Цель решения

Ввести две персистентные AR-модели — `Source` и `SyncCheckpoint` — чтобы оркестратор мог читать из БД перечень источников для следующего запуска синка и однозначную позицию возобновления по каждому из них.

---

#### 2. Scope (Границы решения)

**Входит:**
- AR-модели `Source` (с `plugin_type`, `external_id`, `sync_enabled`, scope `.for_sync`, метод `#upsert_checkpoint!`) и `SyncCheckpoint` (`position` jsonb, привязана к `Source`).
- Миграции для обеих таблиц (новый каталог `db/migrate/`).
- `Collect::CheckpointAmbiguityError` — ошибка при обнаружении нескольких точек для одного источника.
- RSpec-тесты моделей без сети и внешних API.

**НЕ входит:** логика оркестрации, фоновые джобы, хранение payload, валидация формата `position` (ответственность плагина #1), API-эндпоинты, провайдер-специфичные данные, подключение `core/lib` к Rails runtime через `config/application.rb` (отдельный infrastructure issue).

---

#### 3. Функциональные требования

1. `Source` принимает `plugin_type` (String, not null) и `external_id` (String, not null); отсутствие или пустая строка → `ActiveRecord::RecordInvalid`.
2. Пара `(plugin_type, external_id)` уникальна на уровне БД (unique composite index) и AR-валидации.
3. `plugin_type` и `external_id` нормализуются к строке через `.to_s` в `before_validation`; `:telegram` и `"telegram"` дают одну запись.
4. `sync_enabled` — boolean, default `false`. Допустимые значения: Ruby `true`/`false`; AR выполняет стандартный type-casting (`"1"` → `true`, `"0"` → `false`, `1` → `true`, `0` → `false`). Явно запрещено: `nil` → `ActiveRecord::RecordInvalid`. Строковые и числовые значения приводятся AR и не вызывают ошибки.
5. `Source.for_sync` возвращает AR-relation записей с `sync_enabled: true`; снимок состояния БД на момент запроса.
6. `SyncCheckpoint` принадлежит ровно одному `Source`; для одного источника — не более одной записи (DB unique index на `source_id`).
7. `position` — jsonb, not null; `nil` → `ActiveRecord::RecordInvalid`. Пустой Hash `{}` является допустимым значением: модель не валидирует содержимое JSON, только отсутствие самого значения (`nil`).
8. `Source#upsert_checkpoint!(position:)` создаёт или заменяет SyncCheckpoint атомарно (`INSERT ... ON CONFLICT DO UPDATE`). После вызова — ровно одна запись для данного `source_id`. Повторный вызов с тем же `position` идемпотентен: запись одна, значение не меняется, побочных эффектов на другие записи нет. Вызов с `position: nil` → `ArgumentError` до обращения к БД.
9. `source.sync_checkpoint` проверяет count: > 1 → `Collect::CheckpointAmbiguityError`; 0 → `nil`; 1 → объект `SyncCheckpoint`.

---

#### 4. Сценарии ошибок и состояния

**Применимые состояния:** все AR-операции синхронны и завершаются в рамках одного вызова; состояние `loading` для данных моделей неприменимо.

| Сценарий | Поведение |
|---|---|
| `Source.create!(plugin_type: nil)` | `ActiveRecord::RecordInvalid`: `"Plugin type can't be blank"` |
| `Source.create!(external_id: "")` | `ActiveRecord::RecordInvalid`: `"External id can't be blank"` |
| `Source.create!(sync_enabled: nil)` | `ActiveRecord::RecordInvalid` |
| Дублирующий `(plugin_type, external_id)` | `ActiveRecord::RecordInvalid` (AR) / `ActiveRecord::RecordNotUnique` (обход AR) |
| `source.upsert_checkpoint!(position: nil)` | `ArgumentError` до БД |
| Повторный `upsert_checkpoint!` с тем же `position` | Идемпотентно: одна запись, то же значение, нет ошибки |
| `SyncCheckpoint.create!` без `source_id` | `ActiveRecord::RecordInvalid` |
| Несколько `SyncCheckpoint` для одного `source_id` (прямой SQL) | `Collect::CheckpointAmbiguityError` при `source.sync_checkpoint` |
| Обновление checkpoint у source A | checkpoint source B остаётся без изменений |
| `plugin_type: :telegram` (Symbol) | Нормализуется к `"telegram"`; не создаёт дубль |
| Одновременный `upsert_checkpoint!` из двух процессов | DB unique index + `ON CONFLICT DO UPDATE`; гонка не создаёт вторую запись |
| `position: {}` (пустой Hash) | Допустимое значение: `nil`-проверка проходит; хранится как `{}` |
| `position` с отсутствующими ожидаемыми ключами | Допустимо на уровне модели: формат `position` валидирует плагин, а не `SyncCheckpoint` |
| Мутация `position` Hash после передачи | Не влияет на сохранённое: jsonb-сериализация создаёт копию до персистенции |

---

#### 5. Инварианты

1. **Уникальность источника:** нет двух строк с одинаковой парой `(plugin_type, external_id)` после нормализации к строке.
2. **Единственность checkpoint:** для каждого источника — не более одной записи в `sync_checkpoints`; нарушение на уровне приложения → `Collect::CheckpointAmbiguityError`.
3. **Неизменность позиции после upsert:** `position` в БД идентично переданному и не зависит от последующих мутаций аргумента.
4. **Независимость checkpoint:** изменение `position` одного источника не затрагивает `position` другого.
5. **Консистентность FK:** после удаления `Source` связанный `SyncCheckpoint` отсутствует в БД.

---

#### 6. Grounding (ограничения на реализацию)

**База данных:**
Доменные модели используют стандартный Rails primary database. Для него вводится новый каталог `db/migrate/`; `db/schema.rb` генерируется при первой миграции (`rails db:migrate`). Существующие `db/cache_schema.rb` и `db/queue_schema.rb` — отдельные базы, не затрагиваются этим issue.

**Тестовая архитектура:**
`spec/spec_helper.rb` — остаётся для unit-тестов `core/lib`; coverage gate ≥80% применяется только к `core/lib`. `spec/rails_helper.rb` — новый helper для Rails model specs; загружает `core/lib` через явное добавление пути в `$LOAD_PATH` (аналогично существующему `spec/spec_helper.rb`), затем `require "collect"`, затем Rails-окружение; использует стандартные Rails transactional tests (`config.use_transactional_tests = true`) без дополнительных gems. Coverage для `app/models` не входит в coverage gate этого issue.

| Файл | Роль |
|---|---|
| `db/migrate/YYYYMMDDHHMMSS_create_sources.rb` | `sources`: `plugin_type string not null`, `external_id string not null`, `sync_enabled boolean not null default false`; unique index `(plugin_type, external_id)` |
| `db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb` | `sync_checkpoints`: `source_id bigint not null references sources ON DELETE CASCADE`, `position jsonb not null`; unique index `source_id` |
| `app/models/source.rb` | AR: `validates`, `before_validation` нормализация, `scope :for_sync`, `has_one :sync_checkpoint, dependent: :destroy`, `#upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | AR: `belongs_to :source`, `validates :position, exclusion: { in: [nil] }` (разрешает `{}`, запрещает `nil`) |
| `core/lib/collect/errors.rb` | Добавить `Collect::CheckpointAmbiguityError < Collect::Error` |
| `spec/rails_helper.rb` | Новый helper: `$LOAD_PATH.unshift(File.expand_path("../core/lib", __dir__)); require "collect"` — затем `require "spec_helper"` и Rails env; transactional tests |
| `spec/models/source_spec.rb` | RSpec-тесты модели `Source` |
| `spec/models/sync_checkpoint_spec.rb` | RSpec-тесты модели `SyncCheckpoint` |

**Паттерны:**
- `upsert_checkpoint!`: `SyncCheckpoint.upsert({source_id: id, position: position}, unique_by: :source_id)`; guard `raise ArgumentError, "position must not be nil" if position.nil?`.
- Нормализация: `before_validation { self.plugin_type = plugin_type.to_s; self.external_id = external_id.to_s }`.
- Загрузка `core/lib` в `spec/rails_helper.rb`: `$LOAD_PATH.unshift(File.expand_path("../core/lib", __dir__))` перед `require "collect"` — аналогично существующему `spec/spec_helper.rb`.

---

#### 7. Acceptance Criteria (AC)

**Source — валидация:**
- [ ] `Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)` сохраняет запись без ошибок.
- [ ] `Source.create!(plugin_type: nil, ...)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(external_id: "", ...)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(sync_enabled: nil, ...)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] Создание дубля `(plugin_type, external_id)` поднимает `ActiveRecord::RecordInvalid` с `"has already been taken"`.
- [ ] `Source.create!(plugin_type: :telegram, external_id: :ch1, ...)` сохраняет `"telegram"`/`"ch1"`; не создаёт дубль рядом с уже существующей записью.

**Source — for_sync:**
- [ ] `Source.for_sync` возвращает только источники с `sync_enabled: true`; `false`-записи не попадают.
- [ ] `Source.for_sync` возвращает пустой relation, если ни один источник не включён.

**Source — upsert_checkpoint!:**
- [ ] `source.upsert_checkpoint!(position: { cursor: 42 })` создаёт `SyncCheckpoint`; `source.sync_checkpoint.position["cursor"] == 42`.
- [ ] Повторный `upsert_checkpoint!(position: { cursor: 99 })` обновляет значение; в таблице ровно одна запись; `reload.position["cursor"] == 99`.
- [ ] Повторный `upsert_checkpoint!(position: { cursor: 42 })` с тем же значением идемпотентен: одна запись, `position["cursor"] == 42`, нет ошибки.
- [ ] `upsert_checkpoint!(position: nil)` поднимает `ArgumentError`; количество записей не меняется.
- [ ] После мутации аргумента `pos[:cursor] = 999` — `reload.position["cursor"]` равен исходному значению.

**SyncCheckpoint — состояния:**
- [ ] `source.sync_checkpoint` возвращает `nil`, если checkpoint не создавался.
- [ ] `source.sync_checkpoint` возвращает объект `SyncCheckpoint`, если создан.
- [ ] При двух `SyncCheckpoint` для одного источника (прямой SQL) — `source.sync_checkpoint` поднимает `Collect::CheckpointAmbiguityError`.
- [ ] `SyncCheckpoint.create!` без `source_id` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `SyncCheckpoint.create!(source: source, position: {})` сохраняет запись без ошибок; `position` равно `{}`.
- [ ] `SyncCheckpoint.create!(source: source, position: nil)` поднимает `ActiveRecord::RecordInvalid`.

**Инварианты:**
- [ ] Нет двух строк с одинаковым `(plugin_type, external_id)`: дубль поднимает ошибку.
- [ ] `SyncCheckpoint.where(source_id: source.id).count <= 1` после любого числа вызовов `upsert_checkpoint!`.
- [ ] Обновление checkpoint `source_a` не изменяет `position` `source_b`.
- [ ] После `source.destroy` — `SyncCheckpoint.where(source_id: source.id).count == 0`.
- [ ] `Collect::CheckpointAmbiguityError` является субклассом `Collect::Error`.
- [ ] Все существующие тесты `core/lib` остаются зелёными.
