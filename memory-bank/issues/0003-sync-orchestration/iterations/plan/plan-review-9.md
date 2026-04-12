---
issue: 3
type: plan-review
reviewed: iterations/plan-v8.md (version: v8, status: draft)
review_number: 9
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

Наблюдение по runtime:
- шаг 1 в текущем application runtime действительно падает с `uninitialized constant Collect`, что согласуется со stop condition спецификации;
- шаг 2 в текущем окружении тоже невалиден как наблюдение: `bundle exec rspec --format json | jq ...` при ошибке boot всё равно может вернуть `0`, потому что пайплайн смотрит на статус `jq`, а не `rspec`.

## Замечания

### 1. Шаг 2 — команда для pending-count маскирует ошибку загрузки RSpec и может дать ложный `0 pending`

**Какой шаг затронут:** Шаг 2.

**Проблема логики или выполнимости:** команда
```bash
bundle exec rspec --format json | jq '[.examples[] | select(.status == "pending")] | length'
```
не проверяет, что `rspec` вообще успешно загрузил suite. В текущем runtime `rspec` падает ещё на boot (`ActiveRecord::ConnectionNotEstablished`), но JSON всё равно содержит пустой массив examples, и `jq` может посчитать это как `0 pending`. Это нарушает atomicity observational-step: шаг не отличает "pending нет" от "suite вообще не стартовал".

**Как исправить:** сделать шаг 2 двухфазным и наблюдаемым:
- сначала получить JSON без сокрытия статуса загрузки;
- затем отдельно проверить `errors_outside_of_examples_count == 0`;
- и только после этого считать pending.
Практически: либо использовать команду без пайплайна и разбирать JSON по двум полям, либо явно требовать `set -o pipefail` и дополнительно проверять `summary.errors_outside_of_examples_count`.

### 2. Шаг 4 — AC 10 недоматериализован: план не фиксирует, что надо проверить отсутствие каждого обязательного ключа, а не одного произвольного

**Какой шаг затронут:** Шаг 4, сценарий 10.

**Проблема логики или выполнимости:** формулировка `Result без одного из ключей :records/:checkpoint_out/:finished` слишком широкая для одного `it` без уточнения способа проверки. В таком виде исполнитель может проверить только один вариант, например отсутствие `:records`, и формально отметить AC 10 как покрытый, хотя две другие ветки останутся непроверенными. Это блокирует invariant materialization: все три обязательных ключа участвуют в контракте success-result и должны быть наблюдаемо проверены.

**Как исправить:** зафиксировать в плане один из двух вариантов:
- либо три отдельных examples: отдельно для отсутствия `:records`, `:checkpoint_out`, `:finished`;
- либо один параметризованный example, который проходит по всем трём вариантам и после каждого ожидает `ArgumentError` и неизменность checkpoint.
После этого нужно обновить счётчик новых examples и runtime-gate в шаге 5.

### 3. Шаг 4 — инвариант `checkpoint_out` как non-`nil` `Hash` остался недоматериализован

**Какой шаг затронут:** Шаг 4, матрица сценариев 10-13 и сценарий 19.

**Проблема логики или выполнимости:** спецификация в `spec.md` §4 FR 7 требует принимать success только для result, где `checkpoint_out` является именно `Hash`. План проверяет только `checkpoint_out: nil` и полностью non-`Hash` result (`"bad"` или `[]`), но не покрывает случай валидного `Hash`-result с невалидным `checkpoint_out`, например `{ records: [], checkpoint_out: "bad", finished: false }`. Поэтому можно ошибочно реализовать валидацию как "checkpoint_out не nil", и план это не поймает.

**Как исправить:** добавить отдельный сценарий для `checkpoint_out`, который не является `Hash`, при валидных `records` и `finished`. Ожидаемый результат должен быть явным: `ArgumentError`, persisted checkpoint не меняется. После добавления обновить число examples и шаг 5.

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
- `finished_at`: 2026-04-06T15:15:52+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
