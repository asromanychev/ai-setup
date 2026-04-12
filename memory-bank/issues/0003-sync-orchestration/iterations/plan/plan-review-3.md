---
issue: 3
type: plan-review
reviewed: iterations/plan-v3.md (version: v3, status: draft)
review_number: 3
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v3.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает validations / `.for_sync` / `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH`, `require "collect"` до boot, оборачивает examples в DB transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` и падает через `abort` ниже 80% |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; базовый plugin contract валидирует result shape, но spec требует Source-level защиту и для duck-typed plugins |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; Rails autoload-ит `lib/`, но не `core/lib` |

Наблюдение по prerequisite: команда из шага 1 (`bundle exec rails runner "puts Collect::CheckpointAmbiguityError"`) в текущем runtime завершается `uninitialized constant Collect`. Это соответствует stop condition из spec §3 и само по себе не является дефектом плана.

## Замечания

### 1. Шаг 3 — AC 17 про два разных plugin classes описан, но не материализован в исполнимую технику

**Какой шаг затронут:** Шаг 3, строки 116 и 143.

**Проблема логики или выполнимости:** план одновременно требует "использовать только `double` / `instance_double`-style" для plugin objects и отдельно заявляет сценарий "два разных duck-typed класса". В таком виде тестовая техника для AC 17 остаётся недоопределённой: generic doubles хорошо проверяют сообщения, но не материализуют инвариант независимости от конкретного класса. Исполнитель может формально закрыть шаг одинаковыми doubles и не доказать, что orchestration одинаково работает с двумя разными классами plugin.

**Как исправить:** в шаге 3 отдельно разрешить для AC 17 два минимальных duck-typed plugin classes (например, два анонимных класса с `#sync_step`) и явно указать, что именно этот сценарий не должен реализовываться через один и тот же тип double. Для остальных сценариев можно оставить doubles.

### 2. Шаг 4 — final runtime gate допускает `pending`, но не фиксирует, какие именно допустимы

**Какой шаг затронут:** Шаг 4, строка 201.

**Проблема логики или выполнимости:** pass criteria сформулирован как `0 pending (кроме явно pending сценариев)`, но в плане нигде не перечислены допустимые pending-сценарии. Это размывает acceptance gate: исполнитель может оставить незавершённые проверки в `pending` и всё равно трактовать шаг как пройденный. Для final runtime gate это блокирующая неоднозначность, потому что финальный шаг должен иметь однозначный критерий прохождения.

**Как исправить:** сделать gate строгим (`exit 0`, `0 failures`, `0 pending`) либо заранее, до финального шага, явно перечислить допустимые pre-existing pending cases и указать, что новые pending по `#sync_step!` недопустимы.

## Итог

**2 замечания, план не готов к реализации.**

## Execution Metadata

- `system`: Codex CLI
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T14:05:18+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
