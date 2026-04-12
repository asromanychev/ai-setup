---
issue: 2
title: Персистентность источников и контрольных точек синка
status: draft
version: v1
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
8. `Source#upsert_checkpoint!(position:)` создаёт `SyncCheckpoint` для источника, если его нет, или заменяет существующий; реализуется через `SyncCheckpoint.upsert({source_id: id, position: position}, unique_by: :source_id)` — атомарный `INSERT ... ON CONFLICT DO UPDATE`.
9. Перед возвратом `SyncCheckpoint` через `source.sync_checkpoint` система проверяет на уровне приложения, что для данного источника ровно одна (или ноль) записей; если их больше одной — поднимает `Collect::CheckpointAmbiguityError` без возврата значения.

---

#### 4. Сценарии ошибок и состояния

**Состояние loading/in progress: не применяется.** AR-запросы синхронны; у чтения из БД нет промежуточного состояния «в процессе».

**Состояние empty (`Source.for_sync`): применяется.** Если нет источников с `sync_enabled: true`, метод возвращает пустой AR-relation; это не ошибка, оркестратор обрабатывает пустой список штатно.

| Сценарий | Поведение |
|---|---|
| `Source.create!(plugin_type: nil)` | `ActiveRecord::RecordInvalid`: `"Plugin type can't be blank"` |
| `Source.create!(external_id: "")` | `ActiveRecord::RecordInvalid`: `"External id can't be blank"` |
| `Source.create!(sync_enabled: nil)` | `ActiveRecord::RecordInvalid`: `"Sync enabled is not included in the list"` |
| Дублирующий `(plugin_type, external_id)` при сохранении | `ActiveRecord::RecordInvalid` с `"has already been taken"` (AR) + `ActiveRecord::RecordNotUnique` (DB, если bypassed) |
| `source.upsert_checkpoint!(position: nil)` | `ArgumentError`: `"position must not be nil"` — поднимается до обращения к БД |
| `SyncCheckpoint.create!` без `source_id` | `ActiveRecord::RecordInvalid`: FK constraint |
| Несколько `SyncCheckpoint` для одного `source_id` (прямая запись в БД) | `Collect::CheckpointAmbiguityError` при следующем вызове `source.sync_checkpoint` |

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
4. **Независимость контрольных точек:** изменение `position` одного источника не затрагивает `position` другого источника.
5. **Консистентность FK:** удаление `Source` каскадно удаляет связанный `SyncCheckpoint` (`dependent: :destroy` в AR + `ON DELETE CASCADE` в миграции).

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
| `spec/models/source_spec.rb` | RSpec-тесты модели `Source` (новый файл) |
| `spec/models/sync_checkpoint_spec.rb` | RSpec-тесты модели `SyncCheckpoint` (новый файл) |

**Паттерны:**
- `upsert_checkpoint!` использует `SyncCheckpoint.upsert({source_id: id, position: position.to_json}, unique_by: :source_id)` или AR `upsert` с `returning:`.
- Нормализация через `before_validation { self.plugin_type = plugin_type.to_s; self.external_id = external_id.to_s }`.
- `source.sync_checkpoint` реализуется через явный запрос с count-проверкой или через `has_one` + дополнительный guard.
- Тесты моделей подключают Rails-окружение и используют transactional fixtures или `database_cleaner`; не обращаются к сети.

---

#### 7. Acceptance Criteria (AC)

- [ ] `Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)` сохраняет запись в БД без ошибок.
- [ ] `Source.create!(plugin_type: nil, external_id: "ch1", sync_enabled: false)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(plugin_type: "telegram", external_id: "", sync_enabled: false)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] `Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: nil)` поднимает `ActiveRecord::RecordInvalid`.
- [ ] Создание двух `Source` с одинаковым `(plugin_type, external_id)` поднимает ошибку уникальности.
- [ ] `Source.create!(plugin_type: :telegram, external_id: :ch1, sync_enabled: false)` сохраняет `plugin_type: "telegram"`, `external_id: "ch1"`.
- [ ] `Source.for_sync` возвращает только источники с `sync_enabled: true`.
- [ ] `Source.for_sync` возвращает пустой relation, если ни один источник не включён.
- [ ] `source.upsert_checkpoint!(position: { cursor: 42 })` создаёт `SyncCheckpoint`; `source.sync_checkpoint.position["cursor"] == 42`.
- [ ] Повторный `source.upsert_checkpoint!(position: { cursor: 99 })` обновляет значение; в таблице `sync_checkpoints` остаётся ровно одна запись для данного источника.
- [ ] `source.upsert_checkpoint!(position: nil)` поднимает `ArgumentError` без создания/изменения записи в БД.
- [ ] После `pos = { cursor: 1 }; source.upsert_checkpoint!(position: pos); pos[:cursor] = 999` — `source.sync_checkpoint.reload.position["cursor"] == 1`.
- [ ] `source.sync_checkpoint` возвращает `nil`, если контрольная точка для источника не создавалась.
- [ ] `source.sync_checkpoint` возвращает объект `SyncCheckpoint`, если точка создана.
- [ ] При наличии двух `SyncCheckpoint` для одного источника (вставлены прямым SQL) — `source.sync_checkpoint` поднимает `Collect::CheckpointAmbiguityError`.
- [ ] Удаление `Source` каскадно удаляет связанный `SyncCheckpoint` (проверяется через `SyncCheckpoint.count`).
- [ ] `Collect::CheckpointAmbiguityError` является субклассом `Collect::Error`.
- [ ] Все существующие тесты в `spec/core/` остаются зелёными.
- [ ] Инварианты уникальности источника и единственности контрольной точки не нарушены.
