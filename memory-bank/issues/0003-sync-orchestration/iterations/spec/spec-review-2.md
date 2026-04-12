---
name: Sync Orchestration Spec Review 2
description: TAUS-ревью спецификации one-step sync orchestration для issue 0003
type: draft
status: draft
issue: 0003-sync-orchestration
reviews: spec-v2
---

# Spec Review: One-Step Sync Orchestration (Issue #0003)

Проверена спецификация `spec-v2.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

Acceptance Criteria в целом наблюдаемы и допускают автотесты: передача `plugin_type` и `source_config`, чтение `checkpoint_in`, возврат `records/checkpoint_out/finished`, откат checkpoint на ошибках, изоляция разных `Source`, отсутствие special-casing по классу plugin. Критерии описывают поведение системы, а не внутреннюю структуру реализации.

### 2. A (Ambiguous-free): Pass

По сравнению с `spec-v1` документ стал заметно точнее: минимальный duck-typed контракт для `plugin_registry` и `plugin` задан явно, `loading`/`in progress` объявлены неприменимыми, а границы по scope перечислены отдельно. Оставшиеся формулировки вроде `contract-shaped result` раскрыты контекстом Functional Requirements и Grounding достаточно, чтобы агент не гадал о базовом контракте.

### 3. U (Uniform): Fail

**Цитата из спеки:** `Успешным считается только result со структурой Hash и ключами :records, :checkpoint_out, :finished` и `Состояние error: любая ошибка построения plugin object, исполнения sync_step или сохранения checkpoint прерывает вызов исключением`.

**Проблема для AI-агента:** это не покрывает обязательные boundary cases для доменно-специфичного result-контракта. В документе нет отдельной материализации для `missing key`, `invalid state value`, `{}` vs `nil` по `checkpoint_out`, а также для malformed result, который формально является `Hash`, но нарушает ожидаемые типы (`records` не `Array`, `finished` не boolean, `checkpoint_out` равен `nil`). По инструкции ревью это блокирует `U (Uniform)`: здесь недостаточно общих success/error сценариев, нужны явные adversarial cases для shape результата.

**Вариант исправления:** добавить отдельные сценарии ошибок и AC для минимум следующих случаев:
- plugin вернул Hash без одного из ключей `:records/:checkpoint_out/:finished`;
- plugin вернул `finished` не boolean;
- plugin вернул `records` не `Array`;
- plugin вернул `checkpoint_out: nil`;
- plugin вернул `checkpoint_out: {}` и это явно зафиксировано как допустимый или недопустимый кейс.

### 4. S (Scoped): Pass

Документ описывает одну фичу: orchestration одного шага синка. Объём `spec-v2.md` составляет 1326 слов, то есть укладывается в лимит меньше 1500 слов.

### 5. Scope явно ограничен: Pass

Раздел `Scope` явно отделяет входящее в реализацию от запрещённого: хранение `source_config`, схемные изменения, планировщик, API, батчевый обход источников, реальные сетевые плагины и bootstrap-инфраструктура вынесены за пределы issue.

### 6. Инварианты перечислены: Pass

Все пять инвариантов перечислены явно, и у каждого есть хотя бы один falsifiable scenario или Acceptance Criterion:
- атомарность и отсутствие частичного прогресса закрыты ошибками `build`, `sync_step`, `upsert_checkpoint!` и повторными failing-вызовами;
- использование актуальной persisted позиции закрыто AC про существующий и отсутствующий checkpoint;
- изоляция источников закрыта сценарием `source_a/source_b`;
- независимость от конкретного класса закрыта сценарием с двумя разными plugin classes.

### 7. Grounding и реализуемость: Fail

**Цитата из спеки:** `Изменение boot-процесса Rails, добавление нового autoload/load-path для core/lib или отдельная bootstrap-инфраструктура` вынесено в `НЕ входит`, а в Grounding одновременно указаны `core/lib/collect/plugin_registry.rb`, `core/lib/collect/plugin.rb` и `spec/rails_helper.rb`.

**Проблема для AI-агента:** это `precondition-hygiene defect`. Спецификация опирается на runtime-доступность `Collect::PluginRegistry` и `Collect::Plugin`, но в текущем проекте `core/lib` подгружается только в тестовой обвязке через [spec/rails_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L1) и [spec/spec_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L1), тогда как Rails application подключает только `lib/` через [config/application.rb](/home/aromanychev/edu/aida/ai-da-collect/config/application.rb#L24). В [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) уже есть зависимость от `Collect::CheckpointAmbiguityError`, но сама спецификация не фиксирует prerequisite, при котором `Collect` гарантированно доступен в runtime приложения. Внешний prerequisite замаскирован под будто бы уже существующее состояние системы.

**Вариант исправления:** либо добавить явный `Precondition` с условием остановки, например: `Rails runtime уже загружает core/lib и константы Collect доступны в app/models; если это не так, issue блокирован до отдельной infrastructure-задачи`, либо включить минимальное runtime-подключение `core/lib` в scope текущей спеки.

## Дополнительные scope-gate проверки

### Module-budget: Pass

Спека укладывается в лимит не более 3 модульных зон:
- `app/models`
- `core/lib`
- `spec`

Отдельного `scope-defect` по смешению доменной фичи с новой инфраструктурной обвязкой в тексте scope нет, хотя prerequisite по runtime-load-path остаётся отдельным дефектом hygiene.

### Precondition hygiene: Fail

**Цитата из спеки:** `Изменение boot-процесса Rails, добавление нового autoload/load-path для core/lib или отдельная bootstrap-инфраструктура` указано в `НЕ входит`.

**Проблема для AI-агента:** без явного precondition агент получает противоречивый сигнал: реализовать оркестрацию на базе `Collect` нужно сейчас, но необходимый runtime prerequisite одновременно запрещён и не оформлен как блокирующее внешнее условие. Это делает spec неисполняемой в реальном приложении, а не только в тестах.

**Вариант исправления:** вынести prerequisite в отдельный раздел `Preconditions` и зафиксировать stop condition, либо синхронно расширить scope, чтобы текущий issue разрешал минимальное подключение `core/lib` в runtime.

## Итог

2 замечания. Спецификация требует доработки перед реализацией.

Fail-критерии:
- `U (Uniform)`
- `Grounding и реализуемость`
- `Precondition hygiene`

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T11:48:52+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
