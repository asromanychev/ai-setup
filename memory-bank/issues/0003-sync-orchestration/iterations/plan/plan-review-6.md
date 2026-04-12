---
issue: 3
type: plan-review
reviewed: iterations/plan-v6.md (version: v6, status: draft)
review_number: 6
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v6.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓; сейчас покрывает `validations`, `.for_sync`, `#upsert_checkpoint!` |
| `spec/rails_helper.rb` | EXISTS ✓; оборачивает каждый example в outer DB transaction |
| `spec/spec_helper.rb` | EXISTS ✓; coverage gate проверяет только `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; контракт `#sync_step` и shape result присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` определён |
| `config/application.rb` | EXISTS ✓; Rails autoload-ит `lib/`, но не `core/lib` |

Наблюдение по prerequisite: команда из шага 1 в текущем runtime действительно падает с `uninitialized constant Collect`, что соответствует stop condition из spec §3 и само по себе не является дефектом плана.

## Замечания

### 1. Шаги 3-4 — rollback-инвариант не материализован наблюдаемым тестом в текущем lifecycle транзакций

**Какой шаг затронут:** Шаг 3 и сценарий 14 в шаге 4.

**Проблема логики или выполнимости:** план требует доказать AC 14 через `transaction { upsert_checkpoint!(...) }` в `Source#sync_step!`, а затем в тесте подменить `SyncCheckpoint.upsert`, дать original `upsert` выполниться и только после этого поднять исключение. Но в текущей архитектуре `spec/rails_helper.rb` уже оборачивает каждый example в outer transaction. В таком окружении обычный `transaction` из шага 3 присоединяется к ambient transaction, а не создаёт наблюдаемый отдельный rollback boundary. Если исключение будет поднято и перехвачено внутри example через `expect { ... }.to raise_error(...)`, внешний spec-транзакционный контур останется жив до конца теста, и план не фиксирует ни `requires_new: true`, ни savepoint, ни запуск этого сценария вне outer transaction. В результате сценарий 14 не гарантирует наблюдаемый сигнал "старый checkpoint сохранился именно из-за rollback шага", а может смешать rollback orchestration с тестовой обвязкой.

**Как исправить:** сделать rollback-boundary явным раньше самого теста. Практичные варианты:
- либо в шаге 3 зафиксировать `Source.transaction(requires_new: true)` или иной отдельный savepoint/runtime boundary, который сценарий 14 реально наблюдает;
- либо в шаге 4 явно вывести сценарий 14 из outer transactional wrapper и проверять persisted состояние отдельными коммитами/очисткой;
- либо заменить формулировку AC 14 на наблюдаемую проверку, которая не зависит от неявного поведения вложенных AR-транзакций в текущем `rails_helper.rb`.

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
- `finished_at`: 2026-04-06T14:37:31+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
