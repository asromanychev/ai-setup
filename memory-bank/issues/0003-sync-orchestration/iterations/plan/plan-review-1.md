---
issue: 3
type: plan-review
reviewed: iterations/plan-v1.md (version: v1, status: draft)
review_number: 1
date: 2026-04-06
---

# Plan Review — Issue #0003 (plan-v1.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/models/source.rb` | EXISTS ✓; содержит `upsert_checkpoint!`, `sync_checkpoint`, private helpers |
| `app/models/sync_checkpoint.rb` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓ |
| `spec/rails_helper.rb` | EXISTS ✓; добавляет `core/lib` в `$LOAD_PATH` и `require "collect"` до boot |
| `spec/spec_helper.rb` | EXISTS ✓; включает coverage gate для `/core/lib/` |
| `core/lib/collect/plugin_registry.rb` | EXISTS ✓; `build(plugin_id, source_config:)` присутствует |
| `core/lib/collect/plugin.rb` | EXISTS ✓; duck-typed contract и result shape присутствуют |
| `core/lib/collect/errors.rb` | EXISTS ✓; `Collect::CheckpointAmbiguityError` присутствует |
| `config/application.rb` | EXISTS ✓; `core/lib` не добавлен в Rails autoload |

## Замечания

### 1. Шаг 1 — prerequisite-check проверяет не ту фазу runtime

**Проблема логики:** шаг заявлен как подтверждение runtime-доступности `Collect::` для `app/models/source.rb`, но фактически запускает `spec/models/source_spec.rb`, где `spec/rails_helper.rb` заранее делает `$LOAD_PATH.unshift("../core/lib")` и `require "collect"`. Это более permissive окружение, чем application runtime из spec §3. Такой шаг не наблюдает stop condition "runtime приложения уже должен позволять загрузить `Collect` без нового bootstrap/load-path".

**Как исправить:** заменить шаг 1 на чистый observational check именно в application runtime, без опоры на spec helpers. Например, отдельной командой через `rails runner` или эквивалентный boot-check, который подтверждает доступность `Collect::CheckpointAmbiguityError` после обычного boot приложения. После этого уже переходить к реализации и model specs.

### 2. Шаг 3 — сценарий 14 не материализует инвариант rollback внутри транзакции

**Проблема логики:** план предлагает для AC 14 заstubить `source.upsert_checkpoint!` через `allow(source).to receive(:upsert_checkpoint!).and_raise(...)`. Это обходит реальную запись checkpoint и не доказывает, что transaction в `sync_step!` откатывает уже начатое persisted-изменение. В таком виде проверяется только propagation exception, а не инвариант spec §6.1 / error-сценарий spec §5.

**Как исправить:** в шаге 3 заменить сценарий 14 на тест, который вызывает реальную запись внутри транзакции и роняет выполнение после начала persistence. Например, обернуть `SyncCheckpoint.upsert` через `and_wrap_original`, дать оригинальному `upsert` выполниться и затем поднять исключение, после чего проверить через `source.reload.sync_checkpoint.position`, что persisted checkpoint остался прежним.

### 3. Шаг 4 — финальный runtime gate неадекватен и нарушает atomicity

**Проблема логики:** шаг назван "запустить полный spec suite", но команда запускает только `spec/models/source_spec.rb`. Это не подтверждает AC 18 ("все существующие тесты остаются зелёными") и не даёт надёжного coverage-gate по `/core/lib/`, который объявлен в `spec/spec_helper.rb`. Дополнительно внутри шага есть условная ветка "если тест красный — триггер для правки", то есть verification и последующий edit-loop смешаны в одном финальном шаге, что нарушает требование final runtime gate atomicity.

Наблюдаемое подтверждение проблемы: текущая команда из плана (`bundle exec rspec spec/models/source_spec.rb`) в этой среде падает до выполнения примеров на `PG::ConnectionBad`, то есть сама по себе ещё не является устойчивым acceptance gate.

**Как исправить:** сделать последний шаг чистым runtime-gate без любых follow-up правок. Указать точный набор команд, который действительно проверяет acceptance gates, например полный `bundle exec rspec` либо явно перечисленные model/core specs, и отдельно зафиксировать pass criteria. Если для запуска нужна подготовка test runtime, вынести её в отдельный предыдущий observational/prerequisite шаг, а не смешивать с финальной верификацией.

## Итог

**3 замечания, план не готов к реализации.**

## Execution Metadata

- `system`: Codex CLI
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T13:15:14+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
