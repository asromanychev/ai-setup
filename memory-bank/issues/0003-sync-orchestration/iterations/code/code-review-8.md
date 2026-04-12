---
issue: 3
title: Code Review — One-Step Sync Orchestration
type: code-review
status: draft
version: v1
date: 2026-04-06
---

# Code Review: Issue #0003 — One-Step Sync Orchestration

## Контекст анализа

- `spec.md`: `memory-bank/issues/0003-sync-orchestration/spec.md` (`status: active`, `v5`) ([spec.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L4), [spec.md:5](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L5))
- `plan.md`: `memory-bank/issues/0003-sync-orchestration/plan.md` (`status: active`, `v10`) ([plan.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L4), [plan.md:5](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L5))
- allowlist и runtime-scope включают `app/models/source.rb`, `spec/models/source_spec.rb` и минимальный initializer `config/initializers/collect.rb` ([plan.md:40](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L40), [spec.md:25](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L25), [spec.md:109](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L109))
- проанализированный diff: `app/models/source.rb`, `spec/models/source_spec.rb`, `config/initializers/collect.rb`
- runtime-проверки выполнены:
  - `bin/rails runner 'puts Collect::CheckpointAmbiguityError'` → `Collect::CheckpointAmbiguityError`
  - `RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5433/ai_da_collect_test bundle exec rspec spec/models/source_spec.rb` → `37 examples, 0 failures`
  - `RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5433/ai_da_collect_test bundle exec rspec --format json` → `85 examples, 0 failures`, `pending_count: 0`, `errors_outside_of_examples_count: 0`

## Классы замечаний

### provable defect

Не найдено.

### scope breach

Не найдено. Текущий diff укладывается в обновлённый scope и allowlist ([spec.md:25](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L25), [plan.md:40](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L40)).

### runtime-unknown gate

Не найдено. Оба runtime-gate из этой задачи закрыты фактическим исполнением `rails runner` и полного RSpec suite.

## 1. Предпосылки

1. Review опирается на актуальные active-артефакты `spec.md` v5 и `plan.md` v10 ([spec.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L4), [plan.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L4)).
2. Минимальный runtime bootstrap допустим только через explicit require в initializer и без расширения autoload/load-path; текущая реализация этому соответствует ([spec.md:38](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L38), [spec.md:117](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L117), [collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/config/initializers/collect.rb#L1)).

## 2. Инварианты и контракты

1. Атомарность checkpoint сохранена: запись делается только после `validate_sync_result!` и только внутри `transaction(requires_new: true)` через существующий `upsert_checkpoint!` ([source.rb:35](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L35), [source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37)).
2. Отсутствие частичного прогресса на ошибке сохранено: ошибки из `build`, `sync_step`, `validate_sync_result!` и persistence не маскируются и не оставляют новый checkpoint ([source.rb:32](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L32), [source.rb:33](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L33), [source.rb:66](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L66)).
3. Контракт валидного result соблюдён буквально: проверяются `Hash`, mandatory keys, `Array` для `records`, `Hash` для `checkpoint_out` и boolean для `finished` ([spec.md:52](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L52), [source.rb:67](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L67), [source.rb:73](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L73)).
4. Duck-typed независимость сохранена: код использует только `build` и `sync_step`, без ветвлений по классам; это подтверждено отдельным тестом на два разных plugin-класса ([spec.md:59](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L59), [source.rb:32](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L32), [source_spec.rb:256](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L256)).
5. Runtime-contract `Collect` в application boot соблюдён: initializer явно требует `core/lib/collect`, что соответствует обновлённому scope и успешно материализуется в `rails runner` ([collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/config/initializers/collect.rb#L1), [spec.md:144](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L144)).

## 3. Трассировка путей выполнения

1. Happy-path: `registry.build` получает исходные `plugin_type` и `source_config`, `plugin.sync_step` получает текущий persisted checkpoint, валидный result проходит `validate_sync_result!`, затем `checkpoint_out` сохраняется и тот же `result` возвращается вызывающему коду ([source.rb:31](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31), [source_spec.rb:138](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L138), [source_spec.rb:177](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L177)).
2. Error-path `registry.build` и `plugin.sync_step`: исключения поднимаются наружу без fallback и checkpoint остаётся прежним ([source_spec.rb:151](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L151), [source_spec.rb:204](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L204), [source_spec.rb:214](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L214)).
3. Error-path invalid result: невалидные формы результата отсекаются до транзакции, поэтому persisted checkpoint не меняется ([source.rb:35](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L35), [source_spec.rb:298](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L298), [source_spec.rb:343](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L343)).
4. Error-path persistence failure materialized и подтверждён тестом: rollback внутри `requires_new: true` сохраняет старый checkpoint ([source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37), [source_spec.rb:223](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L223)).
5. Runtime-path boot закрыт: обычный application boot теперь поднимает `Collect::CheckpointAmbiguityError` без опоры на spec helper ([collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/config/initializers/collect.rb#L1), [spec.md:38](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L38)).

## 4. Риски и регрессии

Не найдено.

## 5. Вердикт по эквивалентности

`Эквивалентно`.

Все Acceptance Criteria из active spec выполнены: orchestration-логика реализована в `Source#sync_step!`, runtime bootstrap `Collect` проходит через обычный boot, целевой model spec зелёный, а полный suite завершился без failures, pending и ошибок вне examples ([source.rb:31](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31), [collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/config/initializers/collect.rb#L1), [source_spec.rb:124](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L124), [spec.md:145](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L145)).

## 6. Что проверить тестами

1. Повторить `bin/rails runner 'puts Collect::CheckpointAmbiguityError'` в CI, чтобы guard на runtime boot оставался materialized.
2. Повторить полный `bundle exec rspec --format json` в CI и валидировать `pending_count: 0`, `errors_outside_of_examples_count: 0`.
3. Держать rollback-сценарий `rolls back checkpoint changes when persistence fails after upsert` как регрессионный тест на savepoint semantics.
4. Держать тест на duck-typed plugin classes как защиту от будущих `is_a?`/class-branch regressions.
5. Держать негативные shape-тесты result как защиту от ослабления контракта `validate_sync_result!`.

## 7. Confidence

`0.99` — и статический анализ, и оба runtime-gate закрыты фактическим исполнением. До `1.0` не хватает только независимой CI-перепроверки вне текущей локальной среды.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-4-review-code.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T18:56:58+03:00
- `finished_at`: 2026-04-06T18:58:39+03:00
- `elapsed_seconds`: 101
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime

0 замечаний
