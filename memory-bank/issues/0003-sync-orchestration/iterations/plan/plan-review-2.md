---
issue: 3
type: plan-review
reviewed: iterations/plan-v2.md (version: v2, status: draft)
review_number: 2
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v2.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓ |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH` и `require "collect"` до boot |
| `spec/spec_helper.rb` | EXISTS ✓; включает coverage gate только для `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; plugin contract валидирует result shape, но `Source#sync_step!` по spec должен защищаться и для duck-typed plugins вне этого базового класса |
| `core/lib/collect/errors.rb` | EXISTS ✓ |
| `config/application.rb` | EXISTS ✓; `core/lib` не добавлен в Rails autoload |

## Замечания

### 1. Шаг 3 — не материализован функциональный requirement про ровно один вызов `plugin.sync_step`

**Проблема логики:** spec §4 FR 6 требует, чтобы `Source#sync_step!` вызывал `plugin.sync_step(checkpoint_in: ...)` ровно один раз на один вызов метода. В текущем плане есть проверка аргументов `checkpoint_in`, но нет сценария, который блокирует двойной вызов. Из-за этого реализация с повторным вызовом `plugin.sync_step` могла бы пройти описанные тесты, если возвращает одинаковый валидный result.

**Как исправить:** в шаг 3 добавить отдельный `it`, который явно проверяет одноразовый вызов, например через `expect(plugin).to receive(:sync_step).once.with(checkpoint_in: expected_checkpoint).and_return(valid_result)`, а затем проверяет persisted checkpoint и возврат результата.

### 2. Шаг 3 — не покрыт Source-level reject для non-Hash result от duck-typed plugin

**Проблема логики:** в шаге 2 план добавляет ветку `unless result.is_a?(Hash)` в `validate_sync_result!`, но в шаге 3 нет сценария, который доказывает, что `Source#sync_step!` действительно отвергает non-Hash result и оставляет checkpoint неизменным. Ссылаться только на `spec/core/collect/plugin_contract_spec.rb` недостаточно: spec issue разрешает любой duck-typed plugin object, а не только наследников `Collect::Plugin`, поэтому эта защита должна быть проверена на уровне `Source`.

**Как исправить:** добавить в шаг 3 отдельный сценарий вида "plugin returns non-Hash result (`\"bad\"` или `[]`) -> `Source#sync_step!` raises, checkpoint remains unchanged". Источник решения уже наблюдаем: это прямой вызов `source.sync_step!` в model spec с предварительно созданным persisted checkpoint и последующей проверкой через `source.reload.sync_checkpoint.position`.

## Итог

**2 замечания, план не готов к реализации.**

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T13:55:36+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
