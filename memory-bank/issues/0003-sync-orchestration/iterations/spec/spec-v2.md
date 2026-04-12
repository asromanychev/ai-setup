---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: draft
version: v2
date: 2026-04-06
---

# Specification: One-Step Sync Orchestration (Issue #0003)

#### 1. Цель решения

Добавить в `Source` один синхронный entry point, который получает registry-объект и конфиг плагина от вызывающей стороны, вызывает один шаг синка с текущим persisted checkpoint и атомарно фиксирует новый checkpoint только после успешного plugin result.

---

#### 2. Scope

**Входит:**
- Метод уровня модели `Source#sync_step!(plugin_registry:, source_config:)` как единая orchestration-граница одного шага.
- Duck-typed контракт для входного `plugin_registry` и построенного plugin instance без жёсткой привязки `Source` к конкретному классу registry.
- Чтение текущего checkpoint источника (`nil` или `sync_checkpoint.position`) и передача его в `plugin.sync_step`.
- Транзакционное сохранение нового checkpoint только после успешного возврата contract-shaped result.
- RSpec-покрытие success/error/empty/retry сценариев без сети и без новых gems.

**НЕ входит:**
- Хранение `source_config` в БД или изменение схемы `sources`.
- Планировщик, ActiveJob/Sidekiq, API-endpoints, батчевый обход нескольких источников.
- Реальные сетевые плагины и их побочные эффекты вне инварианты checkpoint.
- Изменение boot-процесса Rails, добавление нового autoload/load-path для `core/lib` или отдельная bootstrap-инфраструктура.

---

#### 3. Функциональные требования

1. `Source#sync_step!(plugin_registry:, source_config:)` принимает объект `plugin_registry`, который отвечает на `build(plugin_type, source_config:)`, и `source_config` как `Hash`.
2. Метод не читает plugin config из БД и не нормализует `source_config`; он передаёт в `plugin_registry.build` тот `source_config`, который получил от вызывающей стороны.
3. `plugin_registry.build(plugin_type, source_config:)` должен либо вернуть plugin object, который отвечает на `sync_step(checkpoint_in:)`, либо пробросить исходное исключение без оборачивания со стороны `Source#sync_step!`.
4. Метод читает текущее состояние источника как `checkpoint_in = sync_checkpoint&.position`; отсутствие checkpoint трактуется как `nil`.
5. Метод вызывает `plugin.sync_step(checkpoint_in: checkpoint_in)` ровно один раз на вызов `Source#sync_step!`.
6. Успешным считается только result со структурой Hash и ключами `:records`, `:checkpoint_out`, `:finished`; `Source#sync_step!` возвращает Hash с теми же тремя ключами и значениями, эквивалентными значениям, полученным от `plugin.sync_step`.
7. Если `plugin.sync_step` завершился без исключения и вернул успешный result, метод сохраняет `result[:checkpoint_out]` через существующий `Source#upsert_checkpoint!` в той же транзакции, после чего возвращает result вызывающей стороне.
8. Если `plugin_registry.build`, `plugin.sync_step` или `upsert_checkpoint!` поднимает исключение, вызов завершается тем же исключением, а persisted checkpoint источника после завершения вызова совпадает с состоянием до вызова.
9. Успешный шаг с `records: []` и любым boolean `finished` считается обычным success-сценарием; пустой батч не отменяет обновление checkpoint.
10. Повторный вызов после неуспешного шага повторно использует persisted checkpoint, оставшийся до ошибки; частично обновлённое состояние не допускается.
11. Реализация orchestration не должна ветвиться по конкретному классу plugin instance или registry instance; решение зависит только от наличия методов `build` и `sync_step` и от contract-shaped result.

---

#### 4. Сценарии ошибок и состояния

**Состояние success:** plugin object построен, `sync_step` вернул contract-shaped result, `checkpoint_out` сохранён, метод возвращает result.

**Состояние error:** любая ошибка построения plugin object, исполнения `sync_step` или сохранения checkpoint прерывает вызов исключением; checkpoint источника остаётся прежним.

**Состояние empty:** успешный result с `records: []` допустим; если `checkpoint_out` валиден для `upsert_checkpoint!`, он сохраняется как новый checkpoint.

**Состояния `loading` и `in progress`:** неприменимы. В модели выполнения нет фонового процесса и нет промежуточного persisted статуса шага; есть только завершившийся синхронный вызов.

| Сценарий | Поведение |
|---|---|
| Источник ещё не имеет checkpoint | В плагин передаётся `checkpoint_in: nil`; при успехе создаётся первая запись `SyncCheckpoint` |
| `plugin_registry.build` не может построить plugin для `source.plugin_type` | Исключение из `build` пробрасывается наружу; checkpoint не меняется |
| `source_config` не подходит для конкретного plugin object | Исключение из `build` или `sync_step` пробрасывается; checkpoint не меняется |
| Plugin object поднимает ошибку после чтения checkpoint | Существующий checkpoint не изменяется |
| Plugin object вернул `records: []`, `checkpoint_out: {...}`, `finished: true/false` | Шаг успешен; checkpoint обновляется на `checkpoint_out` |
| Ошибка при `upsert_checkpoint!` после успешного plugin result | Транзакция откатывается; старый checkpoint сохраняется |
| Повтор одного и того же failing вызова | Каждый повтор видит тот же persisted checkpoint, что был до первой ошибки |
| Запуск шага для `source_a` | checkpoint `source_b` не меняется |
| Два разных plugin classes возвращают одинаковый contract-shaped result | `Source#sync_step!` возвращает эквивалентный result и одинаково обновляет checkpoint без специальной ветки по классу |
| Adversarial: checkpoint в БД содержит вложенный Hash/Array, а plugin пытается мутировать полученный `checkpoint_in` | persisted checkpoint в БД остаётся неизменным до успешного `upsert_checkpoint!`; внешняя мутация входного объекта не считается сохранением нового checkpoint |
| Adversarial: после успешного вызова вызывающая сторона повторяет вызов с тем же `source_config`, но plugin снова падает | checkpoint остаётся значением, зафиксированным последним успешным вызовом, без отката к более старому состоянию и без частичного обновления |

---

#### 5. Инварианты

1. **Атомарность checkpoint:** для одного вызова либо фиксируется весь `checkpoint_out`, либо сохраняется предыдущее persisted значение.
2. **Отсутствие частичного прогресса на ошибке:** ошибка построения плагина, выполнения шага или записи в БД не должна оставлять промежуточный checkpoint.
3. **Использование актуальной persisted позиции:** каждый вызов стартует от checkpoint, который хранится у источника на момент начала вызова, либо от `nil`, если checkpoint отсутствует.
4. **Изоляция источников:** операция над одним `Source` не меняет checkpoint другого `Source`.
5. **Независимость от конкретного класса:** orchestration принимает решение только по duck-typed контракту входов и result shape, а не по имени класса registry или plugin.

---

#### 6. Ограничения на реализацию и Grounding

Реализация должна оставаться в существующих модульных зонах и не вводить отдельный orchestration-helper вне scope.

| Файл | Роль |
|---|---|
| `app/models/source.rb` | Основная точка реализации `#sync_step!`, чтение текущего checkpoint, транзакция, вызов `upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | Существующая persisted модель checkpoint без изменения контракта `position` |
| `core/lib/collect/plugin_registry.rb` | Референс существующего registry-контракта для тестовых doubles и интеграционных spec-сценариев |
| `core/lib/collect/plugin.rb` | Референс существующего plugin contract и shape результата `sync_step` |
| `spec/models/source_spec.rb` | Расширение модельных сценариев orchestration без новых spec helpers |
| `spec/rails_helper.rb` | Уже существующая тестовая обвязка, которая подгружает `core/lib` для spec-runtime |

**Ограничения:**
- `Source#sync_step!` должен зависеть от duck-typed интерфейса входных объектов и не должен требовать нового Rails autoload-path для `core/lib`.
- Нельзя добавлять новый bootstrap/load-path механизм в `config/application.rb` в рамках этой задачи.
- Использовать существующий `Source#upsert_checkpoint!`, а не прямой SQL или новый persistence-helper.
- Выполнять orchestration в AR-транзакции уровня `Source`.
- Не добавлять новые gem-зависимости, отдельные сервис-реестры или инфраструктурные модули.
- Если вызывающая сторона передаёт registry/plugin object, не удовлетворяющий описанному интерфейсу, вызов может завершиться исходным исключением Ruby/Rails; обработка такого misuse вне scope.

---

#### 7. Acceptance Criteria

- [ ] Вызов `source.sync_step!(plugin_registry: registry, source_config: config)` передаёт в `registry.build` ровно `source.plugin_type` и тот же `config`, который был передан методу.
- [ ] Если у источника был checkpoint `{ "cursor" => 3 }`, `plugin.sync_step` получает `checkpoint_in: { "cursor" => 3 }`.
- [ ] Если у источника checkpoint отсутствовал, `plugin.sync_step` получает `checkpoint_in: nil`, а успешный вызов создаёт первую запись `SyncCheckpoint` из `checkpoint_out`.
- [ ] Если plugin возвращает `{ records: records, checkpoint_out: checkpoint_out, finished: finished }`, `Source#sync_step!` возвращает Hash с ключами `:records`, `:checkpoint_out`, `:finished` и значениями, эквивалентными `records`, `checkpoint_out`, `finished`.
- [ ] Если у источника был checkpoint `{ "cursor" => 3 }`, а plugin result содержит `checkpoint_out: { cursor: 4 }`, после успешного вызова `source.sync_checkpoint.position == { "cursor" => 4 }`.
- [ ] Если `plugin.sync_step` поднимает исключение, `source.sync_checkpoint.position` после вызова совпадает с состоянием до вызова.
- [ ] Если `plugin_registry.build` поднимает исключение, checkpoint источника не меняется.
- [ ] Если сохранение нового checkpoint завершается ошибкой внутри транзакции, старый checkpoint остаётся неизменным.
- [ ] Успешный result с `records: []` обновляет checkpoint так же, как result с непустым батчем.
- [ ] Повтор двух подряд failing вызовов не меняет checkpoint относительно значения до первой ошибки.
- [ ] Успешный вызов для `source_a` не меняет checkpoint `source_b`.
- [ ] Два разных plugin classes, каждый из которых отвечает на `sync_step(checkpoint_in:)` и возвращает одинаковый contract-shaped result, приводят к одинаковому возвращаемому значению и одинаковому обновлению checkpoint.
- [ ] Все существующие тесты остаются зелёными.

---

#### 8. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/03-2-fix-spec.md`

#### 9. Runtime Telemetry

- `started_at`: 2026-04-06T11:38:20+03:00
- `finished_at`: 2026-04-06T11:39:40+03:00
- `elapsed_seconds`: 80
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
