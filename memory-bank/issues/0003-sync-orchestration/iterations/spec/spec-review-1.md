---
name: Sync Orchestration Spec Review 1
description: TAUS-ревью спецификации one-step sync orchestration для issue 0003
type: draft
status: draft
issue: 0003-sync-orchestration
reviews: spec-v1
---

# Spec Review: One-Step Sync Orchestration (Issue #0003)

Проверена спецификация `spec-v1.md`.

## Вердикты по критериям

### 1. T (Testable): Fail

**Цитата из спеки:** `- [ ] Инварианты не нарушены.` и `Поведение не зависит от конкретного класса плагина: единственный обязательный интерфейс задаётся существующим контрактом Collect::Plugin и Collect::PluginRegistry.`

**Проблема для AI-агента:** AC `Инварианты не нарушены` не задаёт отдельного falsifiable поведения: агент не может понять, каким именно тестом закрывать этот чекбокс и когда он считается выполненным. Дополнительно инвариант про контрактную независимость описан как общий принцип, но в AC нет наблюдаемого сценария, который бы проверял его на двух разных классах плагинов или на plugin double, удовлетворяющем контракту.

**Вариант исправления:** удалить мета-AC `Инварианты не нарушены` и заменить его на конкретные наблюдаемые критерии. Например: один AC для вызова с двумя разными plugin classes, возвращающими одинаковый contract-shaped result, и один AC для случая, когда orchestration возвращает result без изменения структуры `records`, `checkpoint_out`, `finished`.

### 2. A (Ambiguous-free): Fail

**Цитата из спеки:** `принимает plugin_registry, совместимый с Collect::PluginRegistry` и `возвращает plugin result без модификации смысловых полей`.

**Проблема для AI-агента:** формулировка `совместимый` не задаёт проверяемый минимальный интерфейс. Непонятно, достаточно ли объекта с методом `build`, обязан ли он кидать те же исключения, нужно ли требовать exact class. Фраза `смысловых полей` тоже неоднозначна: агенту неясно, разрешена ли нормализация ключей, deep-dup, freeze или смена типа ключей при возврате значения.

**Вариант исправления:** заменить на явный контракт. Например: `plugin_registry` обязан отвечать на `build(plugin_type, source_config:)` и либо возвращать объект, отвечающий на `sync_step(checkpoint_in:)`, либо поднимать исходное исключение. Вместо `смысловых полей` написать: `метод возвращает тот же object shape с ключами :records, :checkpoint_out, :finished; значения этих ключей эквивалентны значению, полученному от plugin.sync_step`.

### 3. U (Uniform): Pass

Спецификация покрывает success, error, empty и явно фиксирует неприменимость `loading`/`in progress`. Есть сценарии для отсутствующего checkpoint, ошибки registry, ошибки плагина, ошибки `upsert_checkpoint!`, повторного failing-вызова, изоляции разных `Source` и adversarial-мутирования вложенных структур.

### 4. S (Scoped): Pass

Документ описывает одну фичу: orchestration одного шага синка. По модульным зонам спецификация укладывается в лимит: `app/models`, `core/lib` и `spec`. Текст также остаётся компактным и не смешивает задачу с планировщиком, API или сетевой интеграцией.

### 5. Scope явно ограничен: Pass

Раздел Scope чётко отделяет входящее в задачу от запретов: хранение `source_config`, схемные изменения, ActiveJob/Sidekiq, API, батчевый обход, реальные сетевые плагины и новые gem-зависимости вынесены за рамки текущей реализации.

### 6. Инварианты перечислены: Fail

**Цитата из спеки:** `Контрактная независимость orchestration: orchestration не знает внутренностей плагина и опирается только на существующий plugin contract.`

**Проблема для AI-агента:** инвариант перечислен текстом, но для него нет явного falsifiable scenario ни в `Сценариях ошибок и состояний`, ни в `Acceptance Criteria`. В текущем виде это архитектурное намерение, а не проверяемый инвариант: из спеки нельзя однозначно вывести тест, который падает, если orchestration начнёт зависеть от конкретного plugin class.

**Вариант исправления:** добавить отдельный сценарий и AC. Например: `два разных plugin class с одинаковым contract-shaped result проходят через Source#sync_step! одинаково`; либо явно убрать этот пункт из инвариантов и перенести его в раздел Grounding как ограничение на реализацию.

### 7. Grounding и реализуемость: Fail

**Цитата из спеки:** `Новые bootstrap/load-path механизмы ... НЕ входят` и одновременно grounding на `core/lib/collect/plugin_registry.rb`, `core/lib/collect/plugin.rb`, `app/models/source.rb`.

**Проблема для AI-агента:** это `precondition-hygiene defect`. Спека требует использовать `Collect::PluginRegistry` и `Collect::Plugin` из `core/lib`, но в реальном runtime проекта нет зафиксированного механизма их загрузки для Rails-приложения: в [config/application.rb](/home/aromanychev/edu/aida/ai-da-collect/config/application.rb#L29) подключается только `lib/`, а `core/lib` подмешивается лишь в тестах через [spec/rails_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L3). При этом спека прямо запрещает добавлять новый load-path/bootstrap. В результате внешний prerequisite замаскирован под уже существующее состояние системы, хотя без него реализация неисполняема вне тестовой обвязки.

**Вариант исправления:** либо добавить явный `Precondition`: `runtime Rails уже загружает core/lib и константы Collect доступны в app/models`, с условием остановки, если это не так; либо расширить scope и прямо разрешить минимальное runtime-подключение `core/lib` в приложении.

## Итог

4 замечания. Спецификация требует доработки перед реализацией.

Fail-критерии:
- `T (Testable)`
- `A (Ambiguous-free)`
- `Инварианты перечислены`
- `Grounding и реализуемость`

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T11:35:15+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
