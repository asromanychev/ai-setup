---
issue: 4
title: Хранилище: S3-совместимый адаптер для raw blob
status: draft
version: v1
date: 2026-04-06
---

# Specification: S3-Compatible Raw Blob Storage Adapter (Issue #0004)

## 1. Цель решения

Добавить прикладной адаптер `Collect::BlobStorage`, который принимает уже подготовленный `storage_key` и raw blob, сохраняет его в S3-совместимое object storage и возвращает тот же `storage_key` как ссылку, пригодную для последующего сохранения в метаданных вместо самих байтов.

### 1.1 Потребитель решения (Who / When)

- **Кто вызывает:** orchestration- или ingestion-слой приложения после получения raw payload и до записи ссылочной метаинформации в PostgreSQL.
- **Когда вызывается:** один раз на каждый blob, который по архитектурному правилу проекта не должен сохраняться в PostgreSQL целиком.
- **Ожидаемая частота / объём:** соответствует частоте sync-шага; один вызов обрабатывает один blob.
- **Ожидаемая модель ответа:** синхронный результат в виде строки `storage_key` либо исключение без частичного успеха.

## 2. Scope

**Входит:**
- новый сервис `app/services/collect/blob_storage.rb`;
- конструктор `Collect::BlobStorage.new(bucket:, client:)`;
- фабричный метод `Collect::BlobStorage.from_env`;
- метод `#store(key:, body:, content_type: nil, metadata: {})`;
- unit-level RSpec без живого S3, AWS-аккаунта и секретов в репозитории.

**НЕ входит:**
- генерация `storage_key` и naming policy bucket/object;
- запись `storage_key` в модели ActiveRecord;
- presigned URL, lifecycle policies, retention, object delete;
- хранение вложений и любой downstream processing после upload;
- retry/backoff и фоновые очереди;
- изменения `config/application.rb`, load-path или bootstrap-механизмов.

## 3. Функциональные требования

1. `Collect::BlobStorage.new(bucket:, client:)` принимает `bucket` только как непустую строку и `client` как объект, который вызывается через `put_object`.
2. `Collect::BlobStorage.from_env` читает `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` во время вызова и создаёт экземпляр с `Aws::S3::Client`.
3. Если `bucket` равен `nil`, `""` или не является `String`, конструктор поднимает `ArgumentError` с сообщением `bucket must be a non-empty String`.
4. Если `client` равен `nil`, конструктор поднимает `ArgumentError` с сообщением `client must not be nil`.
5. `#store` принимает:
   - `key` только как непустую строку;
   - `body` как `String` или IO-подобный объект, отвечающий на `read`;
   - `content_type` как `nil` или непустую строку;
   - `metadata` как `Hash`.
6. Если `key` невалиден, `#store` поднимает `ArgumentError` с сообщением `key must be a non-empty String`.
7. Если `body` равен `nil`, `#store` поднимает `ArgumentError` с сообщением `body must not be nil`.
8. Если `content_type` передан как `""` или не-`String`, `#store` поднимает `ArgumentError` с сообщением `content_type must be nil or a non-empty String`.
9. Если `metadata` не является `Hash`, `#store` поднимает `ArgumentError` с сообщением `metadata must be a Hash`.
10. При валидных аргументах `#store` вызывает `client.put_object` ровно один раз с `bucket`, `key`, `body` и только теми optional-полями, которые были переданы валидно.
11. Если `client.put_object` завершился без исключения, `#store` возвращает строку, равную входному `key`.
12. `#store` не нормализует `key`, не открывает IO самостоятельно, не вызывает `read` на `body` до передачи в client и не мутирует `metadata`.
13. `#store` не кэширует успешные записи: два вызова с тем же `key` делают два отдельных вызова `put_object`.
14. Исключение из `client.put_object` пробрасывается без оборачивания и без повторной попытки.

## 4. Сценарии ошибок и состояния

- **Success:** `client.put_object` завершился без исключения, а вызывающий код получил тот же `storage_key`, который передал в `#store`.
- **Error:** любая валидационная ошибка или исключение клиента завершает вызов без возвращённого `storage_key`.
- **Empty:** неприменимо, потому что операция работает с одним blob, а не со списком.
- **Loading / in progress:** неприменимо, потому что текущий контракт синхронный и не сохраняет промежуточный статус.

| Сценарий | Поведение |
| --- | --- |
| `bucket: nil` | `ArgumentError` с сообщением `bucket must be a non-empty String` |
| `bucket: ""` | `ArgumentError` с сообщением `bucket must be a non-empty String` |
| `client: nil` | `ArgumentError` с сообщением `client must not be nil` |
| `key: nil` | `ArgumentError` с сообщением `key must be a non-empty String` |
| `key: ""` | `ArgumentError` с сообщением `key must be a non-empty String` |
| `body: nil` | `ArgumentError` с сообщением `body must not be nil` |
| `content_type: ""` | `ArgumentError` с сообщением `content_type must be nil or a non-empty String` |
| `metadata` не `Hash` | `ArgumentError` с сообщением `metadata must be a Hash` |
| `body` как IO-объект | `client.put_object` получает сам IO-объект; сервис не вызывает `read` заранее |
| `client.put_object` поднимает `Aws::S3::Errors::ServiceError` | то же исключение пробрасывается наружу |
| повторный вызов с тем же `key` | сервис делает ещё один вызов `put_object` и не использует кэш |

## 5. Инварианты

1. Raw blob не становится частью PostgreSQL-контракта этой фичи: вызывающий код получает только ссылку `storage_key`.
2. Один вызов `#store` приводит максимум к одному вызову `client.put_object`.
3. Ошибка upload не превращается в частичный успех: при исключении `storage_key` не возвращается.
4. `key` передаётся в object storage без нормализации и возвращается вызывающему коду в эквивалентном значении.
5. Повторный вызов с тем же `key` не мемоизируется внутри сервиса.
6. Внешняя мутация `metadata` после завершения `#store` не должна изменять уже отправленные в client значения.

## 6. Ограничения на реализацию и Grounding

- [app/services/collect/blob_storage.rb](/home/aromanychev/edu/aida/ai-da-collect/app/services/collect/blob_storage.rb): новая модульная зона для provider-specific storage-адаптера; существующая папка `app/services/collect/` уже создана.
- [Gemfile](/home/aromanychev/edu/aida/ai-da-collect/Gemfile): зависимость `aws-sdk-s3` уже присутствует, новую gem добавлять не требуется.
- [core/README.md](/home/aromanychev/edu/aida/ai-da-collect/core/README.md): ядро на текущем этапе не должно получать прямую S3-зависимость, поэтому адаптер остаётся вне `core/lib`.
- [config/initializers/collect.rb](/home/aromanychev/edu/aida/ai-da-collect/config/initializers/collect.rb): текущий initializer загружает только core; изменения bootstrap для этой фичи не входят в scope.
- [spec/rails_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb): Rails test-runtime уже настроен для model/service-спеков без внешних сервисов.
- [spec/spec_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb): RSpec runtime уже существует; новые проверки должны работать без сетевых зависимостей.
- [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb): файл важен как архитектурный ориентир, но не входит в текущую реализацию; запись `storage_key` в метаданные вынесена за пределы issue.

Паттерны реализации:
- dependency injection для `bucket` и `client` в основном конструкторе;
- provider-specific код остаётся в `app/services`, а не в `core/lib`;
- тесты используют stub/double вместо реального S3 или ручной подготовки внешнего bucket.

## 7. Acceptance Criteria

- [ ] `Collect::BlobStorage.new(bucket: "raw-bucket", client: client)` не поднимает исключение, если `bucket` непустой `String`, а `client` не `nil`.
- [ ] `Collect::BlobStorage.new(bucket: nil, client: client)` поднимает `ArgumentError` с сообщением `bucket must be a non-empty String`.
- [ ] `Collect::BlobStorage.new(bucket: "", client: client)` поднимает `ArgumentError` с сообщением `bucket must be a non-empty String`.
- [ ] `Collect::BlobStorage.new(bucket: "raw-bucket", client: nil)` поднимает `ArgumentError` с сообщением `client must not be nil`.
- [ ] `storage.store(key: "raw/source-1/blob.json", body: "{\"id\":1}")` возвращает строку `raw/source-1/blob.json`.
- [ ] Успешный вызов `storage.store(key: "raw/source-1/blob.json", body: "{\"id\":1}")` приводит ровно к одному вызову `client.put_object` с `bucket: "raw-bucket"`, `key: "raw/source-1/blob.json"` и тем же `body`.
- [ ] `storage.store(key: nil, body: "x")` поднимает `ArgumentError` с сообщением `key must be a non-empty String`.
- [ ] `storage.store(key: "", body: "x")` поднимает `ArgumentError` с сообщением `key must be a non-empty String`.
- [ ] `storage.store(key: "raw/source-1/blob.json", body: nil)` поднимает `ArgumentError` с сообщением `body must not be nil`.
- [ ] `storage.store(key: "raw/source-1/blob.json", body: "{}", content_type: "")` поднимает `ArgumentError` с сообщением `content_type must be nil or a non-empty String`.
- [ ] `storage.store(key: "raw/source-1/blob.json", body: "{}", metadata: "bad")` поднимает `ArgumentError` с сообщением `metadata must be a Hash`.
- [ ] Если `client.put_object` поднимает исключение, `#store` пробрасывает то же исключение без оборачивания.
- [ ] Два последовательных вызова `storage.store(key: "raw/source-1/blob.json", body: "a")` и `storage.store(key: "raw/source-1/blob.json", body: "b")` приводят к двум разным вызовам `client.put_object`.
- [ ] `Collect::BlobStorage.from_env` создаёт экземпляр, если обязательные `S3_*` переменные установлены в runtime.
- [ ] Все новые тесты для blob storage проходят без живого AWS-аккаунта и без секретов в репозитории.
- [ ] Все существующие тесты остаются зелёными.
- [ ] Инварианты не нарушены.

## 8. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/01-2-generate-spec.md`

## 9. Runtime Telemetry

- `started_at`: 2026-04-06T22:15:49+03:00
- `finished_at`: 2026-04-06T22:15:49+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
