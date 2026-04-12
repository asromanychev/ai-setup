---
issue: 3
type: plan-review
reviewed: iterations/plan-v7.md (version: v7, status: draft)
review_number: 7
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v7.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает `validations`, `.for_sync`, `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH`, делает `require "collect"` до boot и оборачивает examples в outer transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; контракт `#sync_step` и shape result присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; Rails autoload-ит `lib/`, но не `core/lib` |

Наблюдение по prerequisite: команда из шага 1 в текущем application runtime по-прежнему падает с `uninitialized constant Collect`, что согласуется со stop condition из `spec.md` §3 и само по себе не является дефектом review-плана.

## Замечания

### 1. Шаг 4 — сценарий AC 17 не изолирует единственную переменную "класс плагина", поэтому инвариант duck-typing остаётся недоматериализован

**Какой шаг затронут:** Шаг 4, сценарий 17 и его verify-инструкция.

**Проблема логики или выполнимости:** план предлагает сделать два вызова `source.sync_step!` подряд и сравнить одинаковый return/update для `plugin_class_a` и `plugin_class_b`. Но после первого вызова тот же `source` уже имеет изменённый persisted checkpoint, поэтому во втором вызове меняется не только класс плагина, но и входное состояние orchestration (`checkpoint_in`). Это ломает изоляцию переменной, которую сценарий должен проверять. В таком виде тест может пройти даже если различие вызвано не duck-typed независимостью от класса, а тем, что второй вызов стартовал из другого checkpoint-состояния.

**Как исправить:** сделать стартовое состояние идентичным для обоих прогонов раньше самой проверки. Практичные варианты:
- использовать два разных `Source` с одинаковым initial checkpoint;
- либо между вызовами явно восстановить checkpoint в исходное состояние;
- и дополнительно зафиксировать, что оба плагина получают одинаковый `checkpoint_in`, чтобы единственной меняющейся переменной действительно оставался класс plugin object.

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
- `finished_at`: 2026-04-06T14:47:02+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
