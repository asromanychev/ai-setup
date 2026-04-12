---
issue: 3
type: plan-review
reviewed: iterations/plan-v4.md (version: v4, status: draft)
review_number: 4
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v4.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает validations / `.for_sync` / `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH`, `require "collect"` до boot, оборачивает examples в DB transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; контракт `#sync_step` и shape result присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; Rails autoload-ит `lib/`, но не `core/lib` |

## Замечания

### 1. Шаг 4 — финальный runtime gate остаётся неатомарным

**Какой шаг затронут:** Шаг 4.

**Проблема логики или выполнимости:** шаг объявлен как "чистый runtime gate", но внутри него встроена отдельная обязательная операция, которую нужно выполнить ещё до начала шага 2: `bundle exec rspec --format json | jq ...` для фиксации pre-existing pending. Это нарушает требование final runtime gate atomicity из инструкции ревью: последний шаг плана должен содержать только финальные команды проверки, ожидаемый результат и критерий прохождения. Сейчас шаг 4 одновременно описывает и предварительное наблюдение, влияющее на трактовку gate, и сам финальный gate.

**Как исправить:** вынести проверку pre-existing pending в отдельный ранний observational step до шага 2 и оставить последний шаг только как финальный runtime gate с одной группой команд, ожидаемым результатом и строгим pass/fail критерием. Альтернатива: зафиксировать строгий критерий `0 failures, 0 pending` без отдельной предварительной проверки.

## Итог

**1 замечание, план не готов к реализации.**

## Execution Metadata

- `system`: Codex CLI
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T14:21:03+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
