---
issue: 4
type: plan-review
reviewed: iterations/plan/plan-v2.md (version: v2, status: draft)
review_number: 2
date: 2026-04-06
---

# Plan Review — Issue #0004 (plan-v2.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/services/collect/.keep` | EXISTS ✓ |
| `spec/rails_helper.rb` | EXISTS ✓ |
| `spec/spec_helper.rb` | EXISTS ✓ |
| `Gemfile` | EXISTS; `aws-sdk-s3` already present ✓ |
| `config/initializers/collect.rb` | EXISTS ✓ |
| `core/README.md` | EXISTS ✓ |
| `spec/models/source_spec.rb` | EXISTS ✓ |
| `spec/models/sync_checkpoint_spec.rb` | EXISTS ✓ |
| `spec/core/collect/*` | EXISTS ✓ |
| `app/services/collect/blob_storage.rb` | NEW FILE ALLOWED ✓ |
| `spec/services/collect/blob_storage_spec.rb` | NEW FILE ALLOWED ✓ |

## Критерии

### 1. Конкретность шагов

Каждый шаг называет конкретный файл или явный observational gate. Команды, сигналы и do-not-touch границы заданы достаточно точно для исполнения без догадок.

### 2. Логика зависимостей

Порядок корректен: prerequisite runtime check идёт до правок, production service создаётся раньше spec, focused verification отделена от финального regression gate.

### 3. Атомарность

Все шаги независимо выполнимы. Последний шаг остаётся чистым runtime gate и не смешивает verification с последующими исправлениями.

### 4. Полнота

План покрывает новый сервис, новый service spec, focused secret-free verification и регрессионную проверку существующего suite, как требует active spec.

### 5. Grounding

Все существующие файлы и директории реально присутствуют в репозитории. Новые файлы создаются только в допустимых зонах `app/services/collect` и `spec/services/collect`.

### 6. Lifecycle placement

S3-адаптер остаётся в прикладном service-layer, без переноса в `core/lib`, без bootstrap-правок и без смешения с persistence/model lifecycle.

### 7. Invariant materialization

Инварианты active spec материализованы в исполнимые примеры: single-call upload, отсутствие wrapping/retry, отсутствие early `read`, повторные вызовы без cache, metadata isolation и regression-проверка существующего suite.

## Gate-вопросы

### Delta-first adequacy

Каждый edit-step фиксирует текущее состояние, недостающую дельту и запреты на scope drift. Дельта не подменена только описанием конечного состояния.

### Final runtime gate

Последний шаг задаёт одну чистую команду для acceptance + regression:

```bash
env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN -u AWS_REGION bundle exec rspec spec/services/collect/blob_storage_spec.rb spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb spec/core/collect
```

Pass-сигнал измерим: exit code 0, новый service spec зелёный, existing suites зелёные, `AWS_*` не нужны.

## Итог

0 замечаний, план готов к реализации.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T22:28:30+03:00
- `finished_at`: 2026-04-06T22:28:30+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
