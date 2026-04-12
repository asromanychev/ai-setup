---
issue: 3
type: plan-review
reviewed: iterations/plan-v5.md (version: v5, status: draft)
review_number: 5
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v5.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает `validations`, `.for_sync`, `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH`, делает `require "collect"` до boot и оборачивает examples в DB transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; контракт `#sync_step` и shape result присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; Rails autoload-ит `lib/`, но не `core/lib` |

## Замечания

### 1. Шаги 4-5 — тестовая матрица и финальный gate расходятся, поэтому полнота плана не наблюдаема

**Какой шаг затронут:** Шаг 4 и Шаг 5.

**Проблема логики или выполнимости:** в шаге 4 перечислено 20 сценариев с правилом "один `it` на сценарий", причём пункт 20 вообще не является новым примером `#sync_step!`, а ссылается на общую верификацию из шага 5. Одновременно шаг 5 требует, чтобы были зелёными "все 19 новых тестов `#sync_step!`". В текущем виде исполнитель не может однозначно понять, сколько новых examples обязательно должно появиться в `spec/models/source_spec.rb`, а финальная команда `bundle exec rspec --format documentation` это число никак не проверяет. В результате можно пропустить один сценарий, получить зелёный suite и формально всё равно пройти gate.

**Как исправить:** привести шаги 4 и 5 к одному наблюдаемому критерию. Практичный вариант: оставить в шаге 4 только реальные новые examples `#sync_step!`, убрать сценарий 20 как runtime-gate вне describe-блока, затем в шаге 5 либо убрать ссылку на точное число тестов, либо явно добавить наблюдаемую проверку количества examples для `describe "#sync_step!"`. После этого pass/fail критерий станет однозначным.

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
- `finished_at`: 2026-04-06T14:28:39+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
