---
issue: 3
type: plan-review
reviewed: iterations/plan-v8.md (version: v8, status: draft)
review_number: 10
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

Наблюдения по runtime:
- prerequisite-команда из шага 1 в текущем application runtime падает с `uninitialized constant Collect`, что согласуется со stop condition спецификации;
- команда из шага 2 может вернуть `0 pending`, даже когда suite не загрузился;
- команда 5a из шага 5 также может вернуть `0` при ошибке загрузки `spec/models/source_spec.rb`, а не только при реальном недоборе examples.

## Замечания

### 1. Шаг 2 — команда для pending-count маскирует ошибку загрузки RSpec и может дать ложный `0 pending`

**Какой шаг затронут:** Шаг 2.

**Проблема логики или выполнимости:** команда
```bash
bundle exec rspec --format json | jq '[.examples[] | select(.status == "pending")] | length'
```
не проверяет, что `rspec` успешно загрузил suite. В текущем runtime boot падает до запуска examples, но JSON всё равно содержит пустой массив examples, и `jq` превращает это в наблюдение `0 pending`. Такой шаг не различает два состояния: "pending действительно нет" и "suite не поднялся".

**Как исправить:** сделать шаг наблюдаемым по двум сигналам:
- отдельно проверять `errors_outside_of_examples_count == 0`;
- и только после этого считать pending.
Либо убрать пайплайн и разбирать JSON одним инструментом, либо явно требовать `pipefail` и проверку обоих полей.

### 2. Шаг 4 — AC 10 недоматериализован: не зафиксировано, что должны быть проверены все три варианта отсутствующего обязательного ключа

**Какой шаг затронут:** Шаг 4, сценарий 10.

**Проблема логики или выполнимости:** формулировка `Result без одного из ключей :records/:checkpoint_out/:finished` допускает реализацию одного-единственного примера на любой выбранный ключ. Тогда две остальные ветки контракта останутся непроверенными, хотя спецификация делает обязательными все три ключа.

**Как исправить:** зафиксировать в плане либо три отдельных examples, либо один параметризованный example, который последовательно проверяет отсутствие `:records`, `:checkpoint_out` и `:finished`, и каждый раз ожидает ошибку и неизменность checkpoint. После этого обновить ожидаемое число новых examples в шаге 5.

### 3. Шаг 4 — инвариант `checkpoint_out` как non-`nil` `Hash` остался недоматериализован

**Какой шаг затронут:** Шаг 4, сценарии 13 и 19.

**Проблема логики или выполнимости:** план проверяет `checkpoint_out: nil` и полностью non-`Hash` result (`"bad"` или `[]`), но не проверяет валидный `Hash`-result с невалидным `checkpoint_out`, например `{ records: [], checkpoint_out: "bad", finished: false }`. Это оставляет дыру в materialization FR 7: реализацию можно ошибочно написать как "checkpoint_out просто не nil", и текущий план этого не поймает.

**Как исправить:** добавить отдельный сценарий, где result является `Hash`, `records` и `finished` валидны, но `checkpoint_out` не `Hash`. Ожидаемое поведение должно быть зафиксировано явно: `ArgumentError`, persisted checkpoint не меняется. Затем пересчитать число новых examples и обновить шаг 5.

### 4. Шаг 5a — финальный runtime gate тоже маскирует boot-failure и неверно интерпретирует его как “меньше 19 examples”

**Какой шаг затронут:** Шаг 5, команда 5a и её pass/fail-логика.

**Проблема логики или выполнимости:** команда
```bash
bundle exec rspec spec/models/source_spec.rb --dry-run --format json \
  | jq '[.examples[] | select(.full_description | contains("#sync_step!"))] | length'
```
может вернуть `0` и exit 0, даже если `spec/models/source_spec.rb` не загрузился вообще. В таком случае план ошибочно объявляет, что “шаг 4 не завершён”, хотя реальная причина может быть в поломанном boot/runtime. Это нарушает требование к чистому runtime-gate: причина провала должна быть наблюдаема и однозначна.

**Как исправить:** разделить gate на две явные проверки:
- сначала убедиться, что dry-run загрузился без `errors_outside_of_examples_count`;
- затем считать число examples.
Или заменить команду на такую, которая атомарно валидирует и загрузку suite, и число examples в одном наблюдаемом результате.

## Итог

**4 замечания, план не готов к реализации.**

## Execution Metadata

- `system`: Codex CLI
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T15:19:07+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
