---
issue: 2
title: Персистентность источников и контрольных точек синка
status: draft
version: v2
date: 2026-04-05
---

# Specification: Source и SyncCheckpoint (Issue #0002)

#### 1. Цель решения

Ввести две персистентные AR-модели — `Source` и `SyncCheckpoint` — чтобы оркестратор мог читать из БД перечень источников для следующего запуска синка и однозначную позицию возобновления по каждому из них.

---

#### 2. Scope (Границы решения)

**Входит:**
- AR-модель `Source` с полями `plugin_type`, `external_id`, `sync_enabled` и scope `.for_sync`.
- AR-модель `SyncCheckpoint` с полем `position` (jsonb), привязанная к `Source` через `belongs_to`.
- Миграции для обеих таблиц.
- Метод `Source#upsert_checkpoint!(position:)` — создаёт или заменяет контрольную точку источника.
- `Collect::CheckpointAmbiguityError` — новая ошибка для случая обнаружения нескольких точек для одного источника.
- RSpec-тесты моделей без сети и внешних API.

**НЕ входит:**
- Логика оркестрации синка (планирование, очереди, retry).
- Фоновые джобы (Sidekiq/ActiveJob).
- Хранение payload и вложений.
- Валидация формата содержимого `position` — это ответственность контракта плагина (#1).
- API-эндпоинты для управления источниками.
- Данные, специфичные для конкретного провайдера (Telegram-метаданные и т.п.).

---

#### 3. Функциональные требования

1. `Source` принимает `plugin_type` (String, not null) и `external_id` (String, not null); оба поля обязательны при создании — отсутствие либо пустая строка → `ActiveRecord::RecordInvalid`.
2. Пара `(plugin_type, external_id)` уникальна на уровне БД (unique composite index) и на уровне AR-валидации (`validates :external_id, uniqueness: { scope: :plugin_type }`).
3. `plugin_type` и `external_id` нормализуются к строке через `.to_s` в `before_validation` callback; `"telegram"` и `:telegram` дают одну запись.
4. `Source#sync_enabled` — boolean, default `false`; допустимые значения `true` или `false`; `nil` — `ActiveRecord::RecordInvalid`.
5. `Source.for_sync` возвращает AR-relation всех записей с `sync_enabled: true`; результат — снимок состояния БД на момент запроса.
6. `SyncCheckpoint` принадлежит ровно одному `Source` (`belongs_to :source`, not null FK); для одного источника может существовать не более одной записи (DB unique index на `source_id`).
7. `position` в `SyncCheckpoint` хранится как jsonb, not null; значение `nil` → `ActiveRecord::RecordInvalid`.
8. `Source#upsert_checkpoint!(position:)` создаёт `SyncCheckpoint` для источника, если его нет, или заменяет существующий атомарной операцией `INSERT ... ON CONFLICT DO UPDATE`; после вызова в таблице ровно одна запись для данного `source_id` с последним переданным `position`.
9. Перед возвратом `SyncCheckpoint` через `source.sync_checkpoint` система проверяет на уровне приложения, что для данного источника ровно одна (или ноль) записей; если их больше одной — поднимает `Collect::CheckpointAmbiguityError` без возврата значения.

---

#### 4. Сценарии ошибок и состояния

**Состояния для `Source.for_sync`:**
- `empty`: нет источников с `sync_enabled: true` — метод возвращает пустой AR-relation; не ошибка.
- `success`: возвращает AR-relation только записей с `sync_enabled: true`.

**Состояния для `source.sync_checkpoint`:**
- `empty`: контрольная точка для источника ещё не создавалась — метод возвращает `nil`; не ошибка.
- `success`: ровно одна `SyncCheckpoint` для данного источника — метод возвращает объект `SyncCheckpoint`.
- `error`: более одной `SyncCheckpoint` для данного источника (нарушение DB unique через прямой SQL) — метод поднимает `Collect::CheckpointAmbiguityError`.

**Состояние loading/in progress: не применяется.** AR-запросы синхронны; у чтения из БД нет промежуточного состояния «в процессе».

| Сценарий | Поведение |
|---|---|
| `Source.create!(plugin_type: nil)` | `ActiveRecord::RecordInvalid`: `"Plugin type can't be blank"` |
| `Source.create!(external_id: "")` | `ActiveRecord::RecordInvalid`: `"External id can't be blank"` |
| `Source.create!(sync_enabled: nil)` | `ActiveRecord::RecordInvalid`: `"Sync enabled is not included in the list"` |
| Дублирующий `(plugin_type, external_id)` при сохранении | `ActiveRecord::RecordInvalid` с `"has already been taken"` (AR); при обходе AR — `ActiveRecord::RecordNotUnique` (DB) |
| `source.upsert_checkpoint!(position: nil)` | `ArgumentError`: `"position must not be nil"` — поднимается до обращения к БД |
| `SyncCheckpoint.create!` без `source_id` через AR | `ActiveRecord::RecordInvalid` — `belongs_to :source` валидирует присутствие |
| `SyncCheckpoint` вставлен прямым SQL без `source_id` | `ActiveRecord::NotNullViolation` или `ActiveRecord::InvalidForeignKey` на уровне БД — не регулируется AR-валидацией |
| Несколько `SyncCheckpoint` для одного `source_id` (прямая запись в БД) | `Collect::CheckpointAmbiguityError` при следующем вызове `source.sync_checkpoint` |
| Обновление checkpoint у source A при наличии checkpoint у source B | checkpoint source B остаётся без изменений |

**Adversarial edge cases:**

| Сценарий | Поведение |
|---|---|
| `plugin_type: :telegram` (Symbol) при создании | `before_validation` нормализует к `"telegram"`; не создаёт дублирующую запись рядом с уже существующей `"telegram"` |
| Одновременный `upsert_checkpoint!` из двух процессов для одного источника | DB unique index + `ON CONFLICT DO UPDATE` обеспечивает атомарность; гонка не создаёт вторую запись |
| Мутация `position` Hash после передачи в `upsert_checkpoint!` | Не влияет на сохранённое значение: jsonb-сериализация PG создаёт структурную копию до персистенции |
| `SyncCheckpoint` с `position: {}` (пустой Hash) | Валидация проходит (`{}` — валидный jsonb not null); хранится как `{}` |
| `source.sync_checkpoint` при двух записях в таблице (нарушение DB unique через прямой SQL) | `Collect::CheckpointAmbiguityError`; оркестратор не может продолжить возобновление по этому источнику |
| `Source.for_sync` при `sync_enabled` сохранённом как нестандартное значение через прямой SQL | PG boolean column; результат чтения определяется приведением типа PG; запись с нестандартным значением в выборку не попадёт штатным path `for_sync` |
| Создание `Source` с `plugin_type: "Telegram"` и последующее создание с `plugin_type: "telegram"` | Нормализации к нижнему регистру нет (только `.to_s`); `"Telegram"` и `"telegram"` — разные записи; документируется как ожидаемое поведение |

---

#### 5. Инварианты

1. **Уникальность идентичности источника:** в таблице `sources` не существует двух строк с одинаковой парой `(plugin_type, external_id)` после нормализации к строке через `.to_s`.
2. **Единственность контрольной точки:** для каждого источника существует не более одной записи в `sync_checkpoints`; нарушение на уровне приложения → `Collect::CheckpointAmbiguityError`.
3. **Неизменность позиции после upsert:** после успешного `upsert_checkpoint!` значение `position` в БД идентично переданному (по структуре) и не зависит от последующих мутаций аргумента в вызывающем коде.
4. **Независимость контрольных точек:** изменение `position` одного источника не затрагивает `position` другого источника; проверяется сценарием с двумя источниками и разными checkpoint.
5. **Консистентность FK:** после удаления `Source` связанный `SyncCheckpoint` недоступен через `SyncCheckpoint.find` — запись отсутствует в БД.

---

#### 6. Grounding (ограничения на реализацию)

| Файл | Роль |
|---|---|
| `db/migrate/YYYYMMDDHHMMSS_create_sources.rb` | Таблица `sources`: `plugin_type string not null`, `external_id string not null`, `sync_enabled boolean not null default false`; unique index на `(plugin_type, external_id)` |
| `db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb` | Таблица `sync_checkpoints`: `source_id bigint not null references sources ON DELETE CASCADE`, `position jsonb not null`; unique index на `source_id` |
| `app/models/source.rb` | AR-модель: `validates`, `before_validation` нормализация, `scope :for_sync`, `has_one :sync_checkpoint, dependent: :destroy`, `#upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | AR-модель: `belongs_to :source`, `validates :position, presence: true` |
| `app/models/application_record.rb` | Родительский класс (уже существует, не изменяется) |
| `core/lib/collect/errors.rb` | Добавить `Collect::CheckpointAmbiguityError < Collect::Error` |
| `spec/rails_helper.rb` | Новый файл: загружает Rails-окружение (`require 'rails_helper'`-конфигурация), подключает AR и подключает `core/lib` через `require 'collect'` — так модели получают доступ к `Collect::Error`. Использует `DatabaseCleaner` со стратегией `:transaction` для изоляции тестов |
| `spec/models/source_spec.rb` | RSpec-тесты модели `Source` (новый файл, подключает `rails_helper`) |
| `spec/models/sync_checkpoint_spec.rb` | RSpec-тесты модели `SyncCheckpoint` (новый файл, подключает `rails_helper`) |

**Связь `app/models` → `core/lib/collect/errors.rb`:** Rails autoload загружает `app/models`, а `Collect::Error` доступен через `require 'collect'` в `spec/rails_helper.rb` и через `require_relative` / `require 'collect'` в `config/application.rb`. Явная точка подключения фиксируется в `config/application.rb` или `config/initializers/collect.rb`.

**Паттерны:**
- `upsert_checkpoint!` реализует атомарный upsert через `SyncCheckpoint.upsert({source_id: id, position: position}, unique_by: :source_id)`; вызов с `position: nil` поднимает `ArgumentError` до обращения к БД.
- Нормализация: `before_validation { self.plugin_type = plugin_type.to_s; self.external_id = external_id.to_s }`.
- `source.sync_checkpoint`: явный запрос с count-проверкой — если count > 1, поднять `Collect::CheckpointAmbiguityError`; если 0, вернуть `nil`; если 1, вернуть объект.

---

#### 7. Acceptance Criteria (AC)

**Source — валидация:**
- [ ] `Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)` сохраняет запись в БД без ошибок.
- [ ] `Source.create!(plugin_type: nil, external_id: "ch1", sync_enabled: false)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(plugin_type: "telegram", external_id: "", sync_enabled: false)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: nil)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] Создание двух `Source` с одинаковым `(plugin_type, external_id)` поднимает `ActiveRecord::RecordInvalid` с `"has already been taken"`.
- [ ] `Source.create!(plugin_type: :telegram, external_id: :ch1, sync_enabled: false)` сохраняет `plugin_type: "telegram"`, `external_id: "ch1"` без дублирования рядом с записью `"telegram"/"ch1"`.

**Source — for_sync:**
- [ ] `Source.for_sync` возвращает только источники с `sync_enabled: true`; источники с `sync_enabled: false` в результат не попадают.
- [ ] `Source.for_sync` возвращает пустой relation, если ни один источник не включён (`sync_enabled: true`).

**Source — upsert_checkpoint!:**
- [ ] `source.upsert_checkpoint!(position: { cursor: 42 })` создаёт `SyncCheckpoint`; `source.sync_checkpoint.position["cursor"] == 42`.
- [ ] Повторный `source.upsert_checkpoint!(position: { cursor: 99 })` обновляет значение; в таблице `sync_checkpoints` остаётся ровно одна запись для данного источника; `source.sync_checkpoint.reload.position["cursor"] == 99`.
- [ ] `source.upsert_checkpoint!(position: nil)` поднимает `ArgumentError` до записи в БД; количество записей в `sync_checkpoints` для источника не меняется.
- [ ] После `pos = { cursor: 1 }; source.upsert_checkpoint!(position: pos); pos[:cursor] = 999` — `source.sync_checkpoint.reload.position["cursor"] == 1`.

**SyncCheckpoint — состояния:**
- [ ] `source.sync_checkpoint` возвращает `nil`, если контрольная точка для источника не создавалась.
- [ ] `source.sync_checkpoint` возвращает объект `SyncCheckpoint`, если точка создана.
- [ ] При наличии двух `SyncCheckpoint` для одного источника (вставлены прямым SQL) — `source.sync_checkpoint` поднимает `Collect::CheckpointAmbiguityError`.

**SyncCheckpoint — валидация AR:**
- [ ] `SyncCheckpoint.create!` без `source_id` через AR поднимает `ActiveRecord::RecordInvalid`.

**Инварианты — уникальность и независимость:**
- [ ] В таблице `sources` нет двух строк с одинаковым `(plugin_type, external_id)` после нормализации: создание дубля поднимает ошибку уникальности.
- [ ] Для каждого `source_id` в таблице `sync_checkpoints` существует не более одной записи: повторный `upsert_checkpoint!` не увеличивает `SyncCheckpoint.where(source_id: source.id).count` выше 1.
- [ ] Обновление checkpoint у `source_a` (`upsert_checkpoint!(position: { cursor: 10 })`) не изменяет `position` `source_b`, у которого уже есть checkpoint с `position: { cursor: 5 }`; после обновления `source_b.sync_checkpoint.reload.position["cursor"] == 5`.

**Инварианты — консистентность FK:**
- [ ] Удаление `Source` каскадно удаляет связанный `SyncCheckpoint`: после `source.destroy` — `SyncCheckpoint.where(source_id: source.id).count == 0`.

**Ошибка:**
- [ ] `Collect::CheckpointAmbiguityError` является субклассом `Collect::Error`.
