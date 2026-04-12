---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: draft
version: v1
date: 2026-04-06
---

# Specification: One-Step Sync Orchestration (Issue #0003)

#### 1. Цель решения

Добавить на уровне `Source` один транзакционный entry point, который строит плагин по `plugin_type`, передает ему текущий persisted checkpoint и при успешном завершении заменяет checkpoint источника на `checkpoint_out`, не меняя его при любой ошибке.

---

#### 2. Scope

**Входит:**
- Метод уровня модели `Source#sync_step!(plugin_registry:, source_config:)` как единая orchestration-граница одного шага.
- Чтение текущего checkpoint источника (`nil` или `sync_checkpoint.position`) и передача его в `plugin.sync_step`.
- Транзакционное сохранение нового checkpoint только после успешного возврата валидного plugin result.
- RSpec-покрытие success/error/empty/retry сценариев без сети и без новых gems.

**НЕ входит:**
- Хранение `source_config` в БД или изменение схемы `sources`.
- Планировщик, ActiveJob/Sidekiq, API-endpoints, батчевый обход нескольких источников.
- Реальные сетевые плагины и их побочные эффекты вне инварианты checkpoint.
- Новые bootstrap/load-path механизмы, helper-инфраструктура, внешние error-классы или новые gem-зависимости.

---

#### 3. Функциональные требования

1. `Source#sync_step!(plugin_registry:, source_config:)` принимает `plugin_registry`, совместимый с `Collect::PluginRegistry`, и `source_config` как `Hash`; метод сам не извлекает plugin config из БД.
2. Метод использует `plugin_registry.build(plugin_type, source_config: source_config)`; если `plugin_type` не зарегистрирован или плагин не может быть построен, исключение пробрасывается наружу, checkpoint источника не меняется.
3. Внутри вызова метод читает текущее состояние источника как `checkpoint_in = sync_checkpoint&.position`; отсутствие checkpoint трактуется как `nil`.
4. Метод вызывает `plugin.sync_step(checkpoint_in: checkpoint_in)` ровно один раз на вызов.
5. Если `plugin.sync_step` завершился без исключения и вернул валидный результат контракта `Collect::Plugin`, метод сохраняет `result[:checkpoint_out]` через существующий `Source#upsert_checkpoint!` в той же транзакционной операции и возвращает plugin result без модификации смысловых полей.
6. Если `plugin.sync_step` поднимает исключение любого типа, источник после завершения вызова сохраняет checkpoint, идентичный состоянию до вызова.
7. Если сохранение нового checkpoint завершается ошибкой БД или приложенческой ошибкой, транзакция откатывается; ранее существовавший checkpoint источника остаётся без изменений.
8. Успешный шаг с `records: []` и любым boolean `finished` считается успешным, если `checkpoint_out` валиден; пустой батч не отменяет обновление checkpoint.
9. Повторный вызов после неуспешного шага повторно использует persisted checkpoint, оставшийся до ошибки; частично обновлённое состояние не допускается.
10. Поведение не зависит от конкретного класса плагина: единственный обязательный интерфейс задаётся существующим контрактом `Collect::Plugin` и `Collect::PluginRegistry`.

---

#### 4. Сценарии ошибок и состояния

**Состояние success:** плагин построен, `sync_step` вернул валидный результат, `checkpoint_out` сохранён, метод возвращает result.

**Состояние error:** любая ошибка построения плагина, исполнения `sync_step` или сохранения checkpoint прерывает вызов исключением; checkpoint источника остаётся прежним.

**Состояние empty:** успешный result с `records: []` допустим; если `checkpoint_out` валиден, он сохраняется как новый checkpoint.

**Состояния `loading` и `in progress`:** неприменимы. В модели выполнения нет фонового процесса и нет промежуточного persisted статуса шага; есть только завершившийся синхронный вызов.

| Сценарий | Поведение |
|---|---|
| Источник ещё не имеет checkpoint | В плагин передаётся `checkpoint_in: nil`; при успехе создаётся первая запись `SyncCheckpoint` |
| `plugin_type` источника отсутствует в registry | `Collect::UnknownPluginError`; checkpoint не меняется |
| `source_config` не подходит для конкретного плагина | Исключение плагина/контракта пробрасывается; checkpoint не меняется |
| Плагин поднимает ошибку после чтения checkpoint | Существующий checkpoint не изменяется |
| Плагин вернул `records: []`, `checkpoint_out: {...}`, `finished: true/false` | Шаг успешен; checkpoint обновляется на `checkpoint_out` |
| Ошибка при `upsert_checkpoint!` после успешного plugin result | Транзакция откатывается; старый checkpoint сохраняется |
| Повтор одного и того же failing вызова | Каждый повтор видит тот же persisted checkpoint, что был до первой ошибки |
| Запуск шага для source A | checkpoint source B не меняется |
| Adversarial: checkpoint в БД содержит вложенный Hash/Array, а плагин пытается мутировать вход | Мутация не проходит через контракт `Collect::Plugin`; persisted checkpoint в БД остаётся неизменным |
| Adversarial: после успешного вызова вызывающая сторона повторяет вызов с тем же `source_config`, но плагин снова падает | checkpoint остаётся значением, зафиксированным последним успешным вызовом, без отката к более старому состоянию и без частичного обновления |

---

#### 5. Инварианты

1. **Атомарность checkpoint:** для одного вызова либо фиксируется весь `checkpoint_out`, либо сохраняется предыдущее persisted значение.
2. **Отсутствие частичного прогресса на ошибке:** ошибка построения плагина, выполнения шага или записи в БД не должна оставлять промежуточный checkpoint.
3. **Использование актуальной persisted позиции:** каждый вызов стартует от checkpoint, который хранится у источника на момент начала вызова, либо от `nil`, если checkpoint отсутствует.
4. **Изоляция источников:** операция над одним `Source` не меняет checkpoint другого `Source`.
5. **Контрактная независимость orchestration:** orchestration не знает внутренностей плагина и опирается только на существующий plugin contract.

---

#### 6. Grounding

Реализация должна оставаться в уже существующих модульных зонах и не вводить отдельный orchestration-helper вне scope.

| Файл | Роль |
|---|---|
| `app/models/source.rb` | Основная точка реализации `#sync_step!`, чтение текущего checkpoint, транзакция, вызов `upsert_checkpoint!` |
| `app/models/sync_checkpoint.rb` | Существующая persisted модель checkpoint без изменения контракта `position` |
| `core/lib/collect/plugin_registry.rb` | Существующий способ построить plugin по `plugin_type` |
| `core/lib/collect/plugin.rb` | Существующий контракт `sync_step` и гарантия валидности/иммутабельности result |
| `spec/models/source_spec.rb` | Расширение модельных сценариев orchestration без новых spec helpers |
| `spec/rails_helper.rb` | Используется как существующая тестовая обвязка, без новых bootstrap-механизмов |

**Паттерны реализации:**
- Использовать существующий `Source#upsert_checkpoint!`, а не прямой SQL или новый persistence-helper.
- Выполнять orchestration в AR-транзакции уровня `Source`.
- Не добавлять новые gem-зависимости, отдельные сервис-реестры, новые load-path или инфраструктурные модули.
- `source_config` передаётся вызывающей стороной как вход метода; сохранение/нормализация этого конфига вне scope текущей фичи.

---

#### 7. Acceptance Criteria

- [ ] `source.sync_step!(plugin_registry: registry, source_config: config)` строит plugin по `source.plugin_type`, передаёт в него текущий persisted checkpoint и возвращает plugin result.
- [ ] Если у источника был checkpoint `{ "cursor" => 3 }`, а plugin result содержит `checkpoint_out: { cursor: 4 }`, после успешного вызова `source.sync_checkpoint.position == { "cursor" => 4 }`.
- [ ] Если у источника checkpoint отсутствовал, успешный вызов создаёт первую запись `SyncCheckpoint` из `checkpoint_out`.
- [ ] Если `plugin.sync_step` поднимает исключение, `source.sync_checkpoint.position` после вызова совпадает с состоянием до вызова.
- [ ] Если `plugin_registry.build` поднимает `Collect::UnknownPluginError`, checkpoint источника не меняется.
- [ ] Если сохранение нового checkpoint завершается ошибкой внутри транзакции, старый checkpoint остаётся неизменным.
- [ ] Успешный result с `records: []` обновляет checkpoint так же, как result с непустым батчем.
- [ ] Повтор двух подряд failing вызовов не меняет checkpoint относительно значения до первой ошибки.
- [ ] Успешный вызов для `source_a` не меняет checkpoint `source_b`.
- [ ] Adversarial: вложенные структуры в исходном checkpoint не приводят к внешней мутации persisted состояния через plugin call.
- [ ] Все существующие тесты остаются зелёными.
- [ ] Инварианты не нарушены.

---

#### 8. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/01-2-generate-spec.md`

#### 9. Runtime Telemetry

- `started_at`: 2026-04-06T11:24:52+03:00
- `finished_at`: 2026-04-06T11:27:04+03:00
- `elapsed_seconds`: 132
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
