---
issue: 3
type: plan-review
reviewed: iterations/plan-v8.md (version: v8, status: draft)
review_number: 8
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v8.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; сейчас содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers; `sync_step!` пока нет |
| `app/models/sync_checkpoint.rb` | EXISTS ✓; контракт `position` не меняется |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает `validations`, `.for_sync`, `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH`, делает `require "collect"` до boot и оборачивает examples в outer transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; контракт `#sync_step` и shape result присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; `core/lib` не autoload-ится |

## Замечания

### 1. Шаг 4 — инвариант `checkpoint_out` как non-`nil` `Hash` остался недоматериализован

**Какой шаг затронут:** Шаг 4, матрица сценариев 10-13 и сценарий 19.

**Проблема логики или выполнимости:** спецификация в [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md) §4 FR 7 требует принимать success только для result, где `checkpoint_out` является именно `Hash`. В плане есть проверка только для случая `checkpoint_out: nil` (сценарий 13) и для совсем non-Hash result (`"bad"` или `[]`, сценарий 19), но нет отдельного наблюдаемого сценария для result вида `{ records: [], checkpoint_out: "bad", finished: false }`. Из-за этого `validate_sync_result!` можно реализовать ошибочно как "checkpoint_out не nil", и все шаги плана всё равно формально пройдут.

**Как исправить:** добавить отдельный test-step в шаг 4 для случая `checkpoint_out` не `Hash` при валидном `Hash`-result и зафиксировать expected outcome: `ArgumentError`, checkpoint не меняется. После этого обновить счётчик examples и финальный gate в шаге 5 так, чтобы он проверял уже новое фактическое число сценариев.

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
- `finished_at`: 2026-04-06T15:06:04+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
