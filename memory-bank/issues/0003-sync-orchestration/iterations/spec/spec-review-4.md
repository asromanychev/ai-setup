---
name: Sync Orchestration Spec Review 4
description: TAUS-ревью спецификации one-step sync orchestration для issue 0003
type: draft
status: draft
issue: 0003-sync-orchestration
reviews: spec-v4
---

# Spec Review: One-Step Sync Orchestration (Issue #0003)

Проверена спецификация `spec-v4.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

Acceptance Criteria остаются проверяемыми и описывают наблюдаемое поведение на границе `Source#sync_step!`: передача `plugin_type/source_config`, чтение persisted checkpoint, валидация result shape, обновление `checkpoint_out`, откат при ошибках и изоляция разных `Source`. По каждому критерию можно написать model spec без сети и без догадок о скрытой логике.

### 2. A (Ambiguous-free): Pass

Критичные двусмысленности убраны. Result-контракт, поведение при ошибках, `{}` vs `nil`, constructor-time validation, stop condition и неприменимость `loading/in progress` зафиксированы falsifiable формулировками, а не общими словами.

### 3. U (Uniform): Pass

Документ покрывает применимые состояния `success`, `error`, `empty` и явно фиксирует, что `loading`/`in progress` неприменимы для синхронного one-step вызова. Adversarial cases для result shape и режимов вызова материализованы отдельно: `missing key`, не-`Array` `records`, не-boolean `finished`, `checkpoint_out: nil`, `checkpoint_out: {}`, constructor-time validation `source_config`, отсутствие checkpoint, ошибка `upsert_checkpoint!`, повтор failing-вызова и изоляция разных источников.

### 4. S (Scoped): Pass

Документ описывает ровно одну фичу и укладывается в лимит шаблона: `spec-v4.md` содержит 1499 слов, то есть меньше 1500.

### 5. Scope явно ограничен: Pass

Раздел `Scope` чётко отделяет текущую фичу от запрещённых работ: хранение `source_config` в БД, scheduler/API, сетевые плагины, батчевый обход и bootstrap/load-path изменения вынесены за пределы issue. Preconditions отдельно фиксируют, при каком внешнем условии реализация вообще допустима.

### 6. Инварианты перечислены: Pass

Инварианты перечислены явно, и у каждого есть falsifiable опора в `Сценариях ошибок и состояний` или `Acceptance Criteria`: атомарность и отсутствие частичного прогресса закрыты error-сценариями, актуальный persisted checkpoint закрыт success/empty-кейсами с `nil` и существующим checkpoint, изоляция источников и независимость от класса закрыты отдельными сценариями и AC.

### 7. Grounding и реализуемость: Pass

Спецификация привязана к реальным файлам проекта и текущей архитектуре: основная реализация ограничена `app/models/source.rb`, persistence берётся из существующего `Source#upsert_checkpoint!`, test-runtime prerequisite подтверждён `spec/rails_helper.rb` и `spec/spec_helper.rb`, а runtime-зависимость от `Collect` оформлена как явный precondition со stop condition, а не как скрытое допущение.

## Дополнительные scope-gate проверки

### Module-budget: Pass

Спецификация укладывается в допустимый бюджет модульных зон:
- `app/models`
- `core/lib`
- `spec`

Упоминание `config/application.rb` используется как grounding для существующего runtime-факта и ограничения scope, а не как зона изменений текущей фичи, поэтому блокирующего `scope-defect` нет.

### Precondition hygiene: Pass

Внешний prerequisite оформлен корректно: документ явно называет условие, без которого issue неисполняем, и фиксирует понятный stop condition вместо маскировки инфраструктурной зависимости под обычную часть реализации.

## Итог

0 замечаний, спека готова к реализации.

Fail-критерии:
- отсутствуют

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T12:52:03+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
