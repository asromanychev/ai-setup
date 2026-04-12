---
name: Plugin Contract Specification
description: Технический дизайн контракта ingestion-плагина для ядра ai-da-collect
type: specification
status: active
issue: 0001-plugin-contract
---

# Specification: Plugin Contract (Issue #0001)

#### 1. Цель решения

Зафиксировать контракт одного шага синка плагина через базовый класс `Collect::Plugin`, реестр `Collect::PluginRegistry` и заглушку `Collect::NullPlugin`, чтобы ядро можно было протестировать без внешних зависимостей (сеть, БД, Telegram).

---

#### 2. Scope (Границы решения)

**Входит:**
- Базовый класс `Collect::Plugin` с методом `sync_step` и обязательным контрактом входа/выхода.
- Класс `Collect::PluginRegistry` с методами `register`, `fetch`, `build` и фабрикой `default`.
- Класс `Collect::NullPlugin` — детерминированная заглушка для тестов ядра.
- Иерархия ошибок: `Collect::ContractError`, `Collect::UnknownPluginError`.
- RSpec-тесты для всех перечисленных классов, запускаемые без сети и БД.

**НЕ входит:**
- Реализация Telegram-плагина или любого другого реального источника данных.
- Модели и миграции PostgreSQL.
- S3-хранилище и формат сырых payload.
- Фоновые джобы (Sidekiq/ActiveJob).
- Сериализация, персистентность и миграция состояния checkpoint.
- Регистрация более одного реального плагина.

---

#### 3. Функциональные требования

1. Метод `Plugin.plugin_id` — обязателен для переопределения в субклассе; вызов на базовом классе поднимает `ContractError`.
2. Конструктор `Plugin.new(source_config:)` принимает только `Hash`; любое другое значение поднимает `ContractError`.
3. `source_config` немедленно глубоко копируется и замораживается после инициализации — субкласс не может мутировать оригинал.
4. `Plugin#sync_step(checkpoint_in:)` принимает `Hash` или `nil`; любой другой тип поднимает `ContractError`.
5. `checkpoint_in` глубоко копируется и замораживается до передачи в `perform_sync_step` — оригинальный объект не мутируется.
6. Метод `Plugin#perform_sync_step(checkpoint_in:)` — приватный; должен быть переопределён в субклассе; вызов нереализованного варианта поднимает `ContractError`.
7. Результат `sync_step` — всегда замороженный `Hash` с ключами `:records` (Array), `:checkpoint_out` (Hash), `:finished` (true/false); отсутствие любого ключа или неверный тип — `ContractError`.
8. `PluginRegistry#register(plugin_id, plugin_class)` проверяет: класс отвечает на `.plugin_id`; значение `plugin_class.plugin_id` совпадает с ключом регистрации; нарушение — `ContractError`.
9. `PluginRegistry#fetch(plugin_id)` — для незарегистрированного id поднимает `UnknownPluginError` с сообщением `"unknown plugin id: <id>"`.
10. `PluginRegistry#build(plugin_id, source_config:)` — делегирует к `fetch` + `new`; поднимает те же ошибки, что и `fetch`/`new`.
11. `PluginRegistry.default` возвращает реестр с единственным зарегистрированным плагином — `NullPlugin`.
12. `NullPlugin` (id: `"null"`) детерминирован: идентичные входы дают идентичный выход; эмитирует `source_config[:records]` при `cursor == 0`, пустой массив при `cursor > 0`; `checkpoint_out` всегда содержит `cursor` (инкремент от предыдущего) и `emitted_records` (длина батча).

---

#### 4. Uniform (Сценарии ошибок и состояний)

**Состояние loading/in progress: не применяется.** `sync_step` синхронный — за один вызов выполняет один шаг и возвращает итог. Промежуточного состояния «в процессе» не существует.

| Сценарий | Поведение |
|---|---|
| `Plugin.new(source_config: "string")` | `ContractError`: `"source_config must be a Hash"` |
| `plugin.sync_step(checkpoint_in: 42)` | `ContractError`: `"checkpoint_in must be a Hash or nil"` |
| `perform_sync_step` не переопределён | `ContractError`: `"<ClassName> must implement #perform_sync_step"` |
| Результат `perform_sync_step` — не Hash | `ContractError`: `"sync result must be a Hash"` |
| В результате отсутствует `:records` | `ContractError`: `"sync result must include :records"` |
| В результате отсутствует `:checkpoint_out` | `ContractError`: `"sync result must include :checkpoint_out"` |
| В результате отсутствует `:finished` | `ContractError`: `"sync result must include :finished"` |
| `:records` — не Array | `ContractError`: `"records must be an Array"` |
| `:checkpoint_out` — не Hash | `ContractError`: `"checkpoint_out must be a Hash"` |
| `:finished` — не boolean | `ContractError`: `"finished must be boolean"` |
| `registry.fetch("unknown")` | `UnknownPluginError`: `"unknown plugin id: unknown"` |
| `registry.register(:key, mismatched_class)` | `ContractError`: `"<Class> plugin_id does not match registry key <key>"` |
| `registry.register(:key, class_without_plugin_id)` | `ContractError`: `"<Class> must define .plugin_id"` |
| `NullPlugin`, `checkpoint_in: nil` | Возвращает батч из `source_config[:records]`, `cursor: 1` |
| `NullPlugin`, `checkpoint_in: { cursor: N }` где N > 0 | Возвращает пустой `records: []`, `cursor: N+1` |
| `NullPlugin`, `source_config: { records: [], finished: true }` | Возвращает `records: []`, `finished: true` |

**Edge cases для NullPlugin — cursor в checkpoint_in:**

| Сценарий | Поведение |
|---|---|
| `checkpoint_in: {}` (Hash без `:cursor`) | Трактуется как `cursor: 0` — эквивалентно `checkpoint_in: nil`; возвращает батч из `source_config[:records]`, `cursor: 1` |
| `checkpoint_in: { cursor: "abc" }` (`:cursor` — не Integer) | `ContractError`: `"NullPlugin checkpoint_in[:cursor] must be a non-negative Integer"` |
| `checkpoint_in: { cursor: -1 }` (`:cursor` — отрицательный Integer) | `ContractError`: `"NullPlugin checkpoint_in[:cursor] must be a non-negative Integer"` |

**Edge cases для NullPlugin — source_config[:records]:**

| Сценарий | Поведение |
|---|---|
| `source_config: {}` (нет ключа `:records`) | `ContractError` при построении NullPlugin: `"NullPlugin source_config must include :records Array"` |
| `source_config: { records: "not_array" }` (`:records` — не Array) | `ContractError` при построении NullPlugin: `"NullPlugin source_config must include :records Array"` |

---

#### 5. Инварианты

1. **Иммутабельность входов:** `source_config` и `checkpoint_in`, переданные в Plugin, не мутируются ни во время инициализации, ни во время `sync_step`.
2. **Иммутабельность выхода:** результат `sync_step` всегда заморожен (`frozen?` == true) вместе со вложенными `records` и `checkpoint_out`.
3. **Соответствие ключа реестра:** `plugin_class.plugin_id` всегда совпадает с ключом, под которым класс зарегистрирован в `PluginRegistry`.
4. **Детерминизм NullPlugin:** одинаковый `source_config` + `checkpoint_in` → одинаковый результат при каждом вызове.
5. **Изоляция от внешних систем:** весь код в `core/lib/collect/` не содержит зависимостей от сети, ActiveRecord, Redis или Telegram; тесты проходят без них.

---

#### 6. Ограничения на реализацию и Grounding

Файлы, которые затрагивает реализация:

| Файл | Роль |
|---|---|
| `core/lib/collect/errors.rb` | Иерархия ошибок: `Collect::Error`, `ContractError`, `UnknownPluginError` |
| `core/lib/collect/plugin.rb` | Базовый класс контракта: `Plugin` |
| `core/lib/collect/plugin_registry.rb` | Реестр плагинов: `PluginRegistry` |
| `core/lib/collect/null_plugin.rb` | Тестовая заглушка: `NullPlugin < Plugin` |
| `core/lib/collect.rb` | Точка входа: подключает все четыре файла через `require_relative` |
| `spec/spec_helper.rb` | Загружает `core/lib` через `$LOAD_PATH`, включает coverage assertion (порог 80%) |
| `spec/core/collect/plugin_contract_spec.rb` | Тесты контракта Plugin |
| `spec/core/collect/plugin_registry_spec.rb` | Тесты PluginRegistry |
| `spec/core/collect/null_plugin_spec.rb` | Тесты NullPlugin |
| `spec/core/collect/registry_null_plugin_integration_spec.rb` | Интеграция: default registry → NullPlugin → sync_step |

**Паттерны:**
- Наследование от `Collect::Plugin` через `Class.new(described_class)` в тестах — без регистрации в реестре.
- `deep_dup` реализован внутри `Plugin` как приватный метод; субклассы могут им пользоваться.
- `normalize_plugin_id` приводит id к строке через `.to_s` — Symbol и String эквивалентны при регистрации и поиске.

---

#### 7. Acceptance Criteria (AC)

- [ ] `Collect::Plugin.new(source_config: "bad")` поднимает `Collect::ContractError`.
- [ ] `plugin.sync_step(checkpoint_in: 42)` поднимает `Collect::ContractError`.
- [ ] `plugin.sync_step(checkpoint_in: { cursor: 0 })` возвращает замороженный Hash с ключами `:records`, `:checkpoint_out`, `:finished`.
- [ ] После вызова `sync_step` исходный объект `checkpoint_in` не изменён.
- [ ] Субкласс, не реализующий `perform_sync_step`, поднимает `ContractError` при вызове `sync_step`.
- [ ] Субкласс, возвращающий неполный результат из `perform_sync_step`, поднимает `ContractError`.
- [ ] `PluginRegistry#fetch("unknown")` поднимает `Collect::UnknownPluginError` с сообщением `"unknown plugin id: unknown"`.
- [ ] `PluginRegistry#register` отклоняет класс, чей `plugin_id` не совпадает с ключом регистрации.
- [ ] `PluginRegistry.default` содержит `NullPlugin` под ключом `"null"`.
- [ ] `NullPlugin.new(source_config: {})` поднимает `ContractError` с сообщением `"NullPlugin source_config must include :records Array"`.
- [ ] `NullPlugin.new(source_config: { records: "bad" })` поднимает `ContractError` с сообщением `"NullPlugin source_config must include :records Array"`.
- [ ] `NullPlugin#sync_step(checkpoint_in: nil)` возвращает `source_config[:records]` и `checkpoint_out: { cursor: 1, emitted_records: N }`.
- [ ] `NullPlugin#sync_step(checkpoint_in: {})` (без `:cursor`) ведёт себя идентично `checkpoint_in: nil`.
- [ ] `NullPlugin#sync_step(checkpoint_in: { cursor: "abc" })` поднимает `ContractError`.
- [ ] `NullPlugin#sync_step(checkpoint_in: { cursor: -1 })` поднимает `ContractError`.
- [ ] `NullPlugin#sync_step(checkpoint_in: { cursor: N })` при N > 0 возвращает `records: []`.
- [ ] `NullPlugin` детерминирован: два вызова с одинаковыми аргументами дают равный результат.
- [ ] Полный сценарий `PluginRegistry.default → build("null") → sync_step` проходит без сети, Telegram и БД.
- [ ] Все существующие тесты остаются зелёными.
- [ ] Покрытие кода `core/lib/` не ниже 80% (проверяется через `CoverageAssertions`).
- [ ] Инварианты иммутабельности и детерминизма не нарушены.
