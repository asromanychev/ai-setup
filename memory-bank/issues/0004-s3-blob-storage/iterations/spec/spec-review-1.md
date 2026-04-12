---
name: S3 Blob Storage Spec Review 1
description: TAUS-ревью спецификации S3-compatible raw blob storage для issue 0004
type: draft
status: draft
issue: 0004-s3-blob-storage
reviews: spec-v1
---

# Spec Review: S3-Compatible Raw Blob Storage Adapter (Issue #0004)

Проверена спецификация `spec-v1.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

Большая часть AC уже описывает наблюдаемое поведение на границе `Collect::BlobStorage`: валидацию аргументов, single-call upload, отсутствие retry и проброс ошибок. По документу можно написать service spec без доступа к реальному S3.

### 2. A (Ambiguous-free): Pass

Формулировки в основном конкретны: указаны типы аргументов, сообщения ошибок, границы scope и синхронная модель вызова. В документе нет слов-паразитов вроде `быстро`, `удобно` или `и т.д.`.

### 3. U (Uniform): Fail

Спецификация перечисляет IO-сценарий в секции состояний, но не материализует его как falsifiable AC.

Цитата:
> `body` как IO-объект | `client.put_object` получает сам IO-объект; сервис не вызывает `read` заранее

Проблема для AI-агента: boundary case уровня structural contract остаётся только в prose. По нему можно догадаться о желаемом поведении, но нельзя однозначно проверить, что сервис не прочитал IO заранее и передал тот же объект в client.

Вариант исправления:
- добавить AC с IO-double, который падает, если кто-то вызовет `read` до `put_object`;
- явно проверить, что `client.put_object` получает тот же IO-объект.

### 4. S (Scoped): Pass

Документ описывает одну фичу, не уходит в presigned URL, retention или PostgreSQL persistence и укладывается в лимит по размеру и модульному бюджету.

### 5. Scope явно ограничен: Pass

В `Scope` чётко отделены разрешённые изменения от запрещённых: naming policy, БД, presigned URL, retries и bootstrap вынесены за пределы текущей задачи.

### 6. Инварианты перечислены: Pass

Инварианты перечислены явно: отсутствие хранения blob в PostgreSQL-контракте, single-call upload, отсутствие partial success, no memoization, отсутствие post-call aliasing для уже отправленных metadata.

### 7. Grounding и реализуемость: Fail

В спецификации внешний runtime prerequisite замаскирован под обычную часть реализации вместо явного `Preconditions`.

Цитата:
> `Collect::BlobStorage.from_env` читает `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` во время вызова и создаёт экземпляр с `Aws::S3::Client`.

Проблема для AI-агента: обязательные `S3_*` значения живут вне репозитория, но текущая версия не фиксирует stop condition и не отделяет runtime wiring от локально верифицируемого scope. Это нарушает precondition hygiene и делает часть grounding неявной.

Вариант исправления:
- добавить раздел `Preconditions` с явным условием, что production/runtime wiring через `S3_*` возможен только при внешне предоставленных параметрах;
- либо сузить scope до injectable-конструктора и вынести `from_env` из текущей спеки.

## Дополнительные scope-gate проверки

### Module-budget: Pass

Спецификация ограничена тремя модульными зонами:
- `app/services`
- `spec`
- `config` как зона существующего grounding-ограничения без обязательных изменений

### Precondition hygiene: Fail

Внешние runtime prerequisites для `from_env` не оформлены как отдельный `Preconditions`-раздел со stop condition.

### Boundary-to-AC completeness: Fail

IO-contract из раздела состояний должен быть материализован отдельным AC.

## Итог

Fail-критерии:
- `state_uniformity`
- `precondition_hygiene`
- `grounding_realism`

Спека не готова к реализации, пока не будут закрыты дефект precondition hygiene для `from_env` и boundary-to-AC дефект для IO-body.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T22:15:49+03:00
- `finished_at`: 2026-04-06T22:15:49+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
