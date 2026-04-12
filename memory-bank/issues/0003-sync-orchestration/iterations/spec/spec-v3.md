---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: draft
version: v3
date: 2026-04-06
---

# Specification: One-Step Sync Orchestration (Issue #0003)

#### 1. Цель решения

Добавить в `Source` синхронный entry point, который вызывает один шаг синка с текущим persisted checkpoint и атомарно фиксирует новый checkpoint только после успешного plugin result.

---

#### 2. Scope

**Входит:**
- Метод уровня модели `Source#sync_step!(plugin_registry:, source_config:)` как граница одного шага.
- Duck-typed контракт для входного `plugin_registry` и plugin instance без привязки `Source` к конкретному классу registry.
- Чтение текущего checkpoint источника (`nil` или `sync_checkpoint.position`) и передача его в `plugin.sync_step`.
- Валидация shape и типов plugin result до записи нового checkpoint.
- Транзакционное сохранение нового checkpoint только после успешного возврата валидного result.
- RSpec-покрытие success/error/empty/adversarial сценариев без сети, без новых gems.

**НЕ входит:**
- Хранение `source_config` в БД или изменение схемы `sources`.
- Планировщик, ActiveJob/Sidekiq, API-endpoints, батчевый обход нескольких источников.
- Реальные сетевые плагины и их побочные эффекты вне инварианты checkpoint.
- Изменение boot-процесса Rails или добавление нового autoload/load-path для `core/lib`.

---

#### 3. Preconditions и stop condition

1. Runtime приложения уже должен позволять загрузить константы `Collect`, используемые из `app/models/source.rb`, без нового bootstrap/load-path механизма в рамках этой задачи.
2. `spec/rails_helper.rb` и `spec/spec_helper.rb` уже подгружают `core/lib`; runtime-пререквизит для application code остаётся внешним условием.
3. Если в рабочем runtime `app/models/source.rb` не может обращаться к `Collect` без дополнительной настройки, реализация issue останавливается и выносится в отдельную infrastructure-задачу.

---

#### 4. Функциональные требования

1. `Source#sync_step!(plugin_registry:, source_config:)` принимает объект `plugin_registry`, который отвечает на `build(plugin_type, source_config:)`, и `source_config` как `Hash`.
2. Метод не читает plugin config из БД и не нормализует `source_config`; он передаёт в `plugin_registry.build` тот `source_config`, который получил от вызывающей стороны.
3. `plugin_registry.build(plugin_type, source_config:)` должен либо вернуть plugin object, который отвечает на `sync_step(checkpoint_in:)`, либо пробросить исходное исключение без оборачивания со стороны `Source#sync_step!`.
4. Метод читает текущее состояние источника как `checkpoint_in = sync_checkpoint&.position`; отсутствие checkpoint трактуется как `nil`.
5. Метод вызывает `plugin.sync_step(checkpoint_in: checkpoint_in)` ровно один раз на вызов `Source#sync_step!`.
6. Успешным считается только result, который является `Hash`, содержит ключи `:records`, `:checkpoint_out`, `:finished`, содержит `records` как `Array`, `finished` как boolean и `checkpoint_out` как не-`nil` Hash.
7. `checkpoint_out: {}` считается допустимым success-сценарием и сохраняется как новый checkpoint.
8. Если result валиден, `Source#sync_step!` возвращает Hash с ключами `:records`, `:checkpoint_out`, `:finished` и значениями, эквивалентными значениям, полученным от `plugin.sync_step`.
9. Если `plugin.sync_step` завершился без исключения и вернул валидный result, метод сохраняет `result[:checkpoint_out]` через существующий `Source#upsert_checkpoint!` в той же транзакции, после чего возвращает result вызывающей стороне.
10. Если `plugin_registry.build`, `plugin.sync_step`, валидация result или `upsert_checkpoint!` поднимает исключение, вызов завершается исключением, а persisted checkpoint источника после завершения вызова совпадает с состоянием до вызова.
11. Успешный шаг с `records: []` и любым boolean `finished` считается обычным success-сценарием; пустой батч не отменяет обновление checkpoint.
12. Повторный вызов после неуспешного шага повторно использует persisted checkpoint, оставшийся до ошибки; частично обновлённое состояние не допускается.
13. Реализация orchestration не должна ветвиться по конкретному классу plugin instance или registry instance; решение зависит только от методов `build` и `sync_step` и от result-контракта.

---

#### 5. Сценарии ошибок и состояния

**Состояние success:** plugin object построен, `sync_step` вернул валидный result, `checkpoint_out` сохранён.

**Состояние error:** любая ошибка построения plugin object, исполнения `sync_step`, валидации result или сохранения checkpoint прерывает вызов исключением; checkpoint источника остаётся прежним.

**Состояние empty:** успешный result с `records: []` допустим; валидный `checkpoint_out` сохраняется.

**Состояния `loading` и `in progress`:** неприменимы. Есть только завершившийся синхронный вызов без промежуточного persisted статуса.

| Сценарий | Поведение |
|---|---|
| Источник ещё не имеет checkpoint | В плагин передаётся `checkpoint_in: nil`; при успехе создаётся первая запись `SyncCheckpoint` |
| `plugin_registry.build` не может построить plugin для `source.plugin_type` | Исключение из `build` пробрасывается наружу; checkpoint не меняется |
| Plugin object поднимает ошибку после чтения checkpoint | Существующий checkpoint не изменяется |
| Plugin object вернул `records: []`, `checkpoint_out: {...}`, `finished: true/false` | Шаг успешен; checkpoint обновляется на `checkpoint_out` |
| Plugin object вернул Hash без одного из ключей `:records`, `:checkpoint_out`, `:finished` | Result отвергается как невалидный; вызов завершается ошибкой; checkpoint не меняется |
| Plugin object вернул `records`, который не является `Array` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `finished`, который не равен `true` или `false` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `checkpoint_out: nil` | Result отвергается как невалидный; checkpoint не меняется |
| Plugin object вернул `checkpoint_out: {}` | Шаг считается успешным; persisted checkpoint обновляется на пустой Hash |
| Ошибка при `upsert_checkpoint!` после успешного plugin result | Транзакция откатывается; старый checkpoint сохраняется |
| Повтор одного и того же failing вызова | Каждый повтор видит тот же persisted checkpoint, что был до первой ошибки |
| Запуск шага для `source_a` | checkpoint `source_b` не меняется |
| Два разных plugin classes возвращают одинаковый валидный result | `Source#sync_step!` возвращает эквивалентный result и одинаково обновляет checkpoint без специальной ветки по классу |

---

#### 6. Инварианты

1. **Атомарность checkpoint:** для одного вызова либо фиксируется весь `checkpoint_out`, либо сохраняется предыдущее persisted значение.
2. **Отсутствие частичного прогресса на ошибке:** ошибка построения плагина, выполнения шага, валидации result или записи в БД не должна оставлять промежуточный checkpoint.
3. **Использование актуальной persisted позиции:** каждый вызов стартует от checkpoint, который хранится у источника на момент начала вызова, либо от `nil`, если checkpoint отсутствует.
4. **Изоляция источников:** операция над одним `Source` не меняет checkpoint другого `Source`.
5. **Независимость от конкретного класса:** orchestration принимает решение только по duck-typed контракту входов и result shape, а не по имени класса registry или plugin.

---

#### 7. Ограничения на реализацию и Grounding

Реализация должна оставаться в существующих модульных зонах.

| Файл | Роль |
|---|---|
| `app/models/source.rb` | Основная точка реализации `#sync_step!`, чтение текущего checkpoint, транзакция, валидация result, вызов `upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | Существующая persisted модель checkpoint без изменения контракта `position` |
| `config/application.rb` | Референс runtime-факта: Rails autoload-ит `lib/`, но не объявляет отдельный load-path для `core/lib`; менять это в рамках issue нельзя |
| `core/lib/collect/plugin_registry.rb` | Референс существующего registry-контракта для doubles и spec-сценариев |
| `core/lib/collect/plugin.rb` | Референс существующего plugin contract и shape результата |
| `spec/rails_helper.rb` | Референс тестового prerequisite: `core/lib` уже подключён для spec-runtime |
| `spec/spec_helper.rb` | Дополнительный тестовый prerequisite для загрузки `Collect` в spec-runtime |
| `spec/models/source_spec.rb` | Расширение модельных сценариев orchestration без новых spec helpers |

**Ограничения:**
- `Source#sync_step!` должен зависеть от duck-typed интерфейса входных объектов и не должен требовать нового Rails autoload-path для `core/lib`.
- Использовать существующий `Source#upsert_checkpoint!`, а не прямой SQL или новый persistence-helper.
- Выполнять orchestration в AR-транзакции уровня `Source`.
- Не добавлять новые gem-зависимости, отдельные сервис-реестры или инфраструктурные модули.
- Если runtime prerequisite из раздела `Preconditions` не выполнен, реализация issue останавливается, а не маскируется локальным bootstrap-хаком.

---

#### 8. Acceptance Criteria

- [ ] Вызов `source.sync_step!(plugin_registry: registry, source_config: config)` передаёт в `registry.build` ровно `source.plugin_type` и тот же `config`, который был передан методу.
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

- `started_at`: 2026-04-06T11:52:13+03:00
- `finished_at`: 2026-04-06T11:53:31+03:00
- `elapsed_seconds`: 78
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
