---
issue: 4
type: plan-review
reviewed: iterations/plan/plan-v1.md (version: v1, status: draft)
review_number: 1
date: 2026-04-06
---

# Plan Review — Issue #0004 (plan-v1.md)

## Grounding

| Файл из плана | Статус |
|---|---|
| `app/services/collect/.keep` | EXISTS ✓ |
| `spec/rails_helper.rb` | EXISTS ✓ |
| `spec/spec_helper.rb` | EXISTS ✓ |
| `Gemfile` | EXISTS; `aws-sdk-s3` already present ✓ |
| `config/initializers/collect.rb` | EXISTS ✓ |
| `core/README.md` | EXISTS ✓ |
| `app/services/collect/blob_storage.rb` | NEW FILE ALLOWED ✓ |
| `spec/services/collect/blob_storage_spec.rb` | NEW FILE ALLOWED ✓ |

## Критерии

### 1. Конкретность шагов

Шаги 1-4 привязаны к конкретным зонам кода и не требуют выдумывать новые bootstrap-точки. Формулировка дельты для сервиса и service spec в целом достаточно конкретна.

### 2. Логика зависимостей

Порядок базово корректен: observational check идёт раньше редактирования, реализация сервиса предшествует тестам, финальная проверка вынесена в последний шаг.

### 3. Атомарность

Финальный шаг остаётся чистым runtime gate и не смешивает правки с диагностикой. Отдельного блокирующего нарушения атомарности нет.

### 4. Полнота

Есть два пробела, которые не позволяют считать план готовым к реализации.

### 5. Grounding

План остаётся в допустимых зонах `app/services` и `spec`, не тянет S3 в `core/lib` и не требует правок bootstrap.

### 6. Lifecycle placement

Контракт расположен в правильной фазе жизненного цикла: синхронный service object с DI-конструктором и runtime-методом `#store`, без ухода в initializer или persistence layer.

### 7. Invariant materialization

Большинство инвариантов материализованы, но regression-gate и runtime-prerequisite для "без секретов / без живого S3" ещё недостаточно исполнимы.

## Замечания

### Проблема 1 — финальный runtime gate не покрывает требование "все существующие тесты остаются зелёными"

- Затронутый шаг: 4.
- В чём проблема логики или выполнимости: шаг 4 запускает только `spec/services/collect/blob_storage_spec.rb`. Это подтверждает новый контракт сервиса, но не материализует AC из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0004-s3-blob-storage/spec.md), где отдельно зафиксировано, что существующие тесты тоже должны остаться зелёными. При таком плане можно сломать `spec/models/*` или `spec/core/collect/*`, пройти единственный новый spec и формально "закрыть" план.
- Как исправить: добавить отдельный regression/runtime-gate шаг с конкретным набором команд по существующему suite, либо расширить финальный шаг до чистого gate, который проверяет и новый service spec, и существующие тесты проекта. Команда и pass-сигнал должны быть зафиксированы явно.

### Проблема 2 — prerequisite "без AWS secrets и без живого S3" остался декларативным, а не исполнимым

- Затронутые шаги: 1, 3, 4.
- В чём проблема логики или выполнимости: план несколько раз обещает отсутствие внешнего S3 и секретов, но не превращает это в наблюдаемый локальный сигнал. Шаг 1 проверяет только Rails/runtime и наличие каталога, а шаг 4 не фиксирует запуск suite в env без `AWS_*` и не отделяет focused service check от финального regression gate. В результате требование из спеки можно понять как "просто надеемся, что doubles хватит".
- Как исправить: добавить отдельный prerequisite/setup шаг или усилить verification-шаги так, чтобы минимум одна команда явно запускала проверки в окружении без `AWS_*` переменных и с измеримым сигналом `exit 0`, показывающим, что suite не требует secrets и не ходит в сеть.

## Итог

Есть замечания, план требует доработки.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-3-review-plan.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T22:26:10+03:00
- `finished_at`: 2026-04-06T22:26:10+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
