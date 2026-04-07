---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: active
version: v5
date: 2026-04-06
---

# Specification: One-Step Sync Orchestration (Issue #0003)

#### 1. Цель решения

Добавить в `Source` синхронный entry point, который выполняет один шаг синка с persisted checkpoint и фиксирует новый checkpoint только после успешного result.

---

#### 2. Scope

**Входит:**
- Метод `Source#sync_step!(plugin_registry:, source_config:)` как граница одного шага.
- Duck-typed контракт для `plugin_registry` и plugin instance без привязки к классам.
- Чтение текущего checkpoint (`nil` или `sync_checkpoint.position`) и передача его в `plugin.sync_step`.
- Валидация shape и типов plugin result до записи нового checkpoint.
- Транзакционное сохранение checkpoint только после успешного валидного result.
- Минимальный runtime bootstrap через initializer, который явно `require`-ит `core/lib/collect` без расширения Rails autoload-path.
- RSpec-покрытие success/error/empty сценариев без сети, новых gems.

**НЕ входит:**
- Хранение `source_config` в БД или изменение `sources`.
- Планировщик, ActiveJob/Sidekiq, API-endpoints, батчевый обход нескольких источников.
- Реальные сетевые плагины и их побочные эффекты вне инварианты checkpoint.
- Изменение boot-процесса Rails сверх минимального initializer-require для `Collect` или добавление нового autoload/load-path для `core/lib`.

---

#### 3. Preconditions и stop condition

1. Runtime приложения должен позволять загрузить константы `Collect` из `app/models/source.rb`; допустим минимальный initializer, который явно `require`-ит `core/lib/collect` без расширения autoload/load-path.
2. `spec/rails_helper.rb` и `spec/spec_helper.rb` уже подгружают `core/lib`; тестовый prerequisite считается выполненным.
3. Если даже после такого минимального initializer runtime не может обращаться к `Collect`, реализация issue останавливается.

---

#### 4. Функциональные требования

1. `Source#sync_step!(plugin_registry:, source_config:)` принимает `plugin_registry`, который отвечает на `build(plugin_type, source_config:)`, и `source_config` как `Hash`.
2. Метод не читает plugin config из БД, не нормализует `source_config` и передаёт в `plugin_registry.build` ровно полученный `source_config`.
3. `plugin_registry.build(plugin_type, source_config:)` либо возвращает plugin object, который отвечает на `sync_step(checkpoint_in:)`, либо пробрасывает исходное исключение.
4. Если `source_config` не проходит валидацию plugin constructor во время `plugin_registry.build`, метод не делает fallback, не исправляет конфигурацию и завершает вызов тем же исключением; checkpoint остаётся прежним.
5. Метод читает текущее состояние источника как `checkpoint_in = sync_checkpoint&.position`; отсутствие checkpoint означает `nil`.
6. Метод вызывает `plugin.sync_step(checkpoint_in: checkpoint_in)` ровно один раз на вызов `Source#sync_step!`.
7. Успешным считается только `Hash` с ключами `:records`, `:checkpoint_out`, `:finished`, где `records` является `Array`, `finished` является boolean, а `checkpoint_out` является не-`nil` `Hash`.
8. `checkpoint_out: {}` считается допустимым success-сценарием и сохраняется как новый checkpoint.
9. Если result валиден, `Source#sync_step!` возвращает эквивалентный Hash.
10. Если `plugin.sync_step` завершился без исключения и вернул валидный result, метод сохраняет `result[:checkpoint_out]` через существующий `Source#upsert_checkpoint!` в той же транзакции и возвращает result.
11. Если `plugin_registry.build`, `plugin.sync_step`, валидация result или `upsert_checkpoint!` поднимает исключение, вызов завершается исключением, а checkpoint после завершения совпадает с состоянием до вызова.
12. Успешный шаг с `records: []` и любым boolean `finished` считается success-сценарием; пустой батч не отменяет обновление checkpoint.
13. Повторный вызов после неуспешного шага использует persisted checkpoint, оставшийся до ошибки; частично обновлённое состояние не допускается.
14. Реализация orchestration не должна ветвиться по конкретному классу plugin или registry; решение зависит только от методов `build` и `sync_step` и от result-контракта.

---

#### 5. Сценарии ошибок и состояния

**Состояние success:** plugin object построен, `sync_step` вернул валидный result, `checkpoint_out` сохранён.

**Состояние error:** любая ошибка построения plugin object, валидации `source_config`, исполнения `sync_step`, валидации result или сохранения checkpoint прерывает вызов исключением; checkpoint остаётся прежним.

**Состояние empty:** успешный result с `records: []` допустим; `checkpoint_out` сохраняется.

**Состояния `loading` и `in progress`:** неприменимы; есть только завершившийся синхронный вызов без промежуточного persisted статуса.

| Сценарий | Поведение |
|---|---|
| Источник ещё не имеет checkpoint | В плагин передаётся `checkpoint_in: nil`; при успехе создаётся первая запись `SyncCheckpoint` |
| `source_config` не проходит валидацию plugin constructor во время `plugin_registry.build` | Исходное исключение из `build` пробрасывается без оборачивания; checkpoint не меняется; метод не нормализует конфигурацию |
| `plugin_registry.build` не может построить plugin для `source.plugin_type` по иной причине | Исключение из `build` пробрасывается наружу; checkpoint не меняется |
| Plugin object поднимает ошибку после чтения checkpoint | Существующий checkpoint не изменяется |
| Plugin object вернул `records: []`, `checkpoint_out: {...}`, `finished: true/false` | Шаг успешен; checkpoint обновляется |
| Plugin object вернул Hash без одного из ключей `:records`, `:checkpoint_out`, `:finished` | Result отвергается как невалидный; вызов завершается ошибкой; checkpoint не меняется |
| Plugin object вернул `records`, который не является `Array` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `finished`, который не равен `true` или `false` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `checkpoint_out: nil` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `checkpoint_out: {}` | Шаг считается успешным; persisted checkpoint обновляется на пустой Hash |
| Ошибка при `upsert_checkpoint!` после успешного plugin result | Транзакция откатывается; старый checkpoint сохраняется |
| Повтор одного и того же failing вызова | Каждый повтор видит тот же persisted checkpoint, что был до первой ошибки |
| Запуск шага для `source_a` | checkpoint `source_b` не меняется |
| Два разных plugin classes возвращают одинаковый валидный result | `Source#sync_step!` возвращает эквивалентный result и одинаково обновляет checkpoint без ветки по классу |

---

#### 6. Инварианты

1. **Атомарность checkpoint:** для одного вызова либо фиксируется весь `checkpoint_out`, либо сохраняется предыдущее persisted значение.
2. **Отсутствие частичного прогресса на ошибке:** ошибка построения плагина, валидации `source_config`, выполнения шага, валидации result или записи в БД не оставляет промежуточный checkpoint.
3. **Использование актуальной persisted позиции:** каждый вызов стартует от checkpoint, который хранится у источника на момент начала вызова, либо от `nil`, если checkpoint отсутствует.
4. **Изоляция источников:** операция над одним `Source` не меняет checkpoint другого `Source`.
5. **Независимость от конкретного класса:** orchestration опирается только на duck-typed контракт входов и result shape, а не на имя класса registry или plugin.

---

#### 7. Ограничения на реализацию и Grounding

| Файл | Роль |
|---|---|
| `app/models/source.rb` | Основная точка реализации `#sync_step!`, чтение checkpoint, транзакция, валидация result, вызов `upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | Существующая persisted модель checkpoint без изменения контракта `position` |
| `config/application.rb` | Референс runtime-факта: Rails autoload-ит `lib/`, но не `core/lib`; расширять autoload/load-path в рамках issue нельзя |
| `config/initializers/collect.rb` | Минимальный runtime bootstrap: явный `require` для `core/lib/collect` без изменения autoload/load-path |
| `core/lib/collect/plugin_registry.rb` | Референс существующего registry-контракта для doubles и spec-сценариев |
| `core/lib/collect/plugin.rb` | Референс существующего plugin contract и shape результата |
| `spec/rails_helper.rb` | Референс тестового prerequisite: `core/lib` уже подключён в spec-runtime |
| `spec/spec_helper.rb` | Дополнительный тестовый prerequisite для загрузки `Collect` |
| `spec/models/source_spec.rb` | Расширение модельных сценариев orchestration без новых spec helpers |

**Ограничения:**
- `Source#sync_step!` должен зависеть от duck-typed интерфейса входных объектов и не должен требовать нового Rails autoload-path для `core/lib`; допустим только минимальный initializer-require.
- Использовать существующий `Source#upsert_checkpoint!`, а не прямой SQL или новый persistence-helper.
- Выполнять orchestration в AR-транзакции уровня `Source`.
- Не добавлять новые gem-зависимости, сервис-реестры или инфраструктурные модули.
- Если runtime prerequisite из раздела `Preconditions` не выполнен, реализация issue останавливается; допустим только минимальный initializer-require, явно описанный в scope.

---

#### 8. Acceptance Criteria

- [ ] Вызов `source.sync_step!(plugin_registry: registry, source_config: config)` передаёт в `registry.build` ровно `source.plugin_type` и тот же `config`, который был передан методу.
- [ ] Если `source_config` не проходит валидацию plugin constructor во время `registry.build`, `Source#sync_step!` пробрасывает исходное исключение без оборачивания, не нормализует конфигурацию и не меняет checkpoint.
- [ ] Если у источника был checkpoint `{ "cursor" => 3 }`, `plugin.sync_step` получает `checkpoint_in: { "cursor" => 3 }`.
- [ ] Если у источника checkpoint отсутствовал, `plugin.sync_step` получает `checkpoint_in: nil`, а успешный вызов создаёт первую запись `SyncCheckpoint` из `checkpoint_out`.
- [ ] Если plugin возвращает `{ records: records, checkpoint_out: checkpoint_out, finished: finished }`, где `records` является `Array`, `checkpoint_out` является не-`nil` Hash, а `finished` является boolean, `Source#sync_step!` возвращает эквивалентный Hash и сохраняет `checkpoint_out`.
- [ ] Если у источника был checkpoint `{ "cursor" => 3 }`, а plugin result содержит `checkpoint_out: { cursor: 4 }`, после успешного вызова `source.sync_checkpoint.position == { "cursor" => 4 }`.
- [ ] Если plugin возвращает `records: []`, `checkpoint_out: {}`, `finished: false`, вызов считается успешным и persisted checkpoint становится `{}`.
- [ ] Если `plugin.sync_step` поднимает исключение, `source.sync_checkpoint.position` после вызова совпадает с состоянием до вызова.
- [ ] Если `plugin_registry.build` поднимает исключение, checkpoint источника не меняется.
- [ ] Если plugin возвращает Hash без одного из ключей `:records`, `:checkpoint_out`, `:finished`, вызов завершается ошибкой и checkpoint источника не меняется.
- [ ] Если plugin возвращает `records`, который не является `Array`, вызов завершается ошибкой и checkpoint источника не меняется.
- [ ] Если plugin возвращает `finished`, который не является boolean, вызов завершается ошибкой и checkpoint источника не меняется.
- [ ] Если plugin возвращает `checkpoint_out: nil`, вызов завершается ошибкой и checkpoint источника не меняется.
- [ ] Если сохранение нового checkpoint завершается ошибкой внутри транзакции, старый checkpoint остаётся неизменным.
- [ ] Повтор двух подряд failing вызовов не меняет checkpoint относительно значения до первой ошибки.
- [ ] Успешный вызов для `source_a` не меняет checkpoint `source_b`.
- [ ] Два разных plugin classes, каждый из которых отвечает на `sync_step(checkpoint_in:)` и возвращает одинаковый валидный result, приводят к одинаковому возвращаемому значению и одинаковому обновлению checkpoint.
- [ ] `bin/rails runner "puts Collect::CheckpointAmbiguityError"` завершается успешно и печатает имя константы после обычного application boot.
- [ ] Все существующие тесты остаются зелёными.
- [ ] Инварианты не нарушены.

---

#### 9. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/03-2-fix-spec.md`

#### 10. Runtime Telemetry

- `started_at`: 2026-04-06T12:32:13+03:00
- `finished_at`: 2026-04-06T12:33:34+03:00
- `elapsed_seconds`: 81
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
