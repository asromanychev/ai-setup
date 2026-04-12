---
issue: 4
title: Хранилище: S3-совместимый адаптер для raw blob
status: draft
version: v1
date: 2026-04-06
---

# Specification: S3-Compatible Blob Storage Adapter (Issue #0004)

#### 1. Цель решения

Ввести `Collect::BlobStorage` — тонкий адаптер над `Aws::S3::Client`, который принимает `key` (String) и `body` (String/IO), записывает blob в S3-совместимое хранилище и возвращает тот же `key` как `storage_key`, пригодный для хранения в метаданных вместо самого содержимого.

---

#### 1.1 Потребитель решения (Who / When)

- **Кто вызывает:** ingestion-код (будущий job или orchestration layer), который получил raw payload и должен сохранить его вне PostgreSQL перед записью метаданных.
- **Когда вызывается:** после получения raw payload и до записи метаданных источника в PostgreSQL.
- **Ожидаемая частота / объём:** соответствует частоте шагов синка; объём одного blob — сырой payload от одного источника (десятки КБ — единицы МБ).
- **Ожидаемая модель ответа:** синхронный результат — строка `storage_key` для немедленного использования в метаданных.

---

#### 2. Scope

**Входит:**
- Класс `Collect::BlobStorage` в `core/lib/collect/blob_storage.rb`.
- Конструктор `BlobStorage.new(bucket:, client:)`.
- Фабричный метод `BlobStorage.from_env` — строит `Aws::S3::Client` и bucket из ENV-переменных.
- Метод `#store(key:, body:)` — записывает blob через `client.put_object` и возвращает `key`.
- Обновление `core/lib/collect.rb`: добавить `require_relative "collect/blob_storage"`.
- RSpec-покрытие без реального S3 через `Aws::S3::Client.new(stub_responses: true)`.

**НЕ входит:**
- Генерация и нормализация значения `key` (naming policy); вызывающий код передаёт готовый ключ.
- Presigned URL, lifecycle policies, retention management.
- Хранение blob-ссылок в PostgreSQL — это ответственность вызывающего кода.
- Логика вложений, отличная от рассматриваемого сценария raw blob.
- Downstream-обработка: нормализация, embedding, RAG.
- Retry-логика внутри адаптера.
- Шифрование на стороне клиента.

---

#### 3. Функциональные требования

1. `Collect::BlobStorage.new(bucket:, client:)` принимает `bucket` — непустую строку и `client` — объект, отвечающий на `put_object(bucket:, key:, body:)`. Если `bucket` — `nil` или пустая строка, поднимает `ArgumentError` с сообщением `"bucket must be a non-empty String"`. Если `client` — `nil`, поднимает `ArgumentError` с сообщением `"client must not be nil"`.
2. `Collect::BlobStorage.from_env` строит экземпляр, читая ENV-переменные `S3_BUCKET`, `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` в момент вызова. Если `S3_BUCKET` отсутствует или пустая строка, поднимает `KeyError` с сообщением `"S3_BUCKET is not set"`.
3. `#store(key:, body:)` принимает `key` — непустую строку и `body` — String или IO-совместимый объект, отвечающий на `read`. Если `key` — `nil` или пустая строка, поднимает `ArgumentError` с сообщением `"key must be a non-empty String"`. Если `body` — `nil`, поднимает `ArgumentError` с сообщением `"body must not be nil"`.
4. `#store` вызывает `client.put_object(bucket: @bucket, key: key, body: body)` ровно один раз за один вызов метода.
5. Если `put_object` не поднял исключение, `#store` возвращает строку, равную переданному `key`.
6. `#store` не модифицирует, не нормализует и не трансформирует `key` или `body` перед передачей в `client.put_object`.
7. `#store` не кэширует результат и не мемоизирует вызовы — повторный вызов с тем же `key` снова обращается к `client.put_object`.
8. Если `client.put_object` поднимает исключение, `#store` пробрасывает его без оборачивания.
9. `from_env` не кэширует значения ENV и не сохраняет client между разными вызовами `from_env`.

---

#### 4. Сценарии ошибок и состояния

**Состояние success:** `put_object` вернул результат без исключения; `#store` вернул `key`.

**Состояние error:** любая ошибка валидации аргументов или пробрасывание исключения от `put_object` прерывает вызов.

**Состояние empty:** неприменимо — у `BlobStorage` нет коллекции объектов и нет пустого списка. Единственная операция — запись одного blob.

**Состояние loading / in progress:** неприменимо — вызов синхронный, нет промежуточного persisted статуса.

| Сценарий | Поведение |
|---|---|
| `bucket` при конструировании — `nil` | `ArgumentError` с сообщением `"bucket must be a non-empty String"` |
| `bucket` при конструировании — пустая строка `""` | `ArgumentError` с сообщением `"bucket must be a non-empty String"` |
| `client` при конструировании — `nil` | `ArgumentError` с сообщением `"client must not be nil"` |
| `key` при `#store` — `nil` | `ArgumentError` с сообщением `"key must be a non-empty String"` |
| `key` при `#store` — пустая строка `""` | `ArgumentError` с сообщением `"key must be a non-empty String"` |
| `body` при `#store` — `nil` | `ArgumentError` с сообщением `"body must not be nil"` |
| `put_object` поднимает `Aws::S3::Errors::NoSuchBucket` | Исключение пробрасывается без оборачивания |
| `put_object` поднимает сетевую ошибку (например, `Seahorse::Client::NetworkingError`) | Исключение пробрасывается без оборачивания |
| `S3_BUCKET` не задан в ENV при вызове `from_env` | `KeyError` с сообщением `"S3_BUCKET is not set"` |
| Мутация `key`-строки после вызова `#store` | `put_object` уже был вызван с исходным значением до мутации; возвращённый `storage_key` — независимая строка |
| Повторный вызов `#store` с тем же `key` и другим `body` | `put_object` вызывается второй раз с новыми аргументами; адаптер не мемоизирует предыдущий вызов |
| `body` — непустой IO-объект, отвечающий на `read` | `put_object` получает IO-объект как `body`; адаптер не вызывает `read` самостоятельно |
| `body` — пустая строка `""` | Валидация проходит (`body` не `nil`); `put_object` получает пустую строку |
| `client` — объект без метода `put_object` | При вызове `#store` поднимается `NoMethodError`; пробрасывается без оборачивания |

---

#### 5. Инварианты

1. **Ровно один `put_object` на вызов `#store`:** адаптер не повторяет вызов при успехе и не делает retry при ошибке.
2. **Иммутабельность аргументов:** `#store` не мутирует переданные `key` и `body`; возвращённая строка `storage_key` является независимой копией `key` (или тем же объектом, если Ruby не копирует литерал — но адаптер не должен мутировать его впоследствии).
3. **Отсутствие хранения state между вызовами:** `BlobStorage` не накапливает список сохранённых ключей и не хранит копии `body`.
4. **Отсутствие кэширования ENV:** `from_env` читает ENV в момент своего вызова; изменение ENV между двумя вызовами `from_env` отражается в результате второго вызова.
5. **Прозрачный проброс ошибок:** исключения от `client.put_object` не оборачиваются и не подавляются.

**Adversarial edge cases для инвариантов:**
- *Алиасинг key:* `k = "blob_1"; storage.store(key: k, body: "x"); k << "_mutated"` — `put_object` уже вызван с `"blob_1"`, возвращённый `storage_key` должен оставаться `"blob_1"`.
- *Повтор с тем же ключом:* вызов `store(key: "k1", body: "a")` и затем `store(key: "k1", body: "b")` приводит к двум вызовам `put_object` — мемоизации нет.
- *Мутабельный hash-ключ:* если кто-то передаёт объект вместо строки в `key` — валидация на `non-empty String` отвергает его; адаптер не принимает Hash или Symbol как ключ.
- *Одновременное изменение ENV:* `ENV["S3_BUCKET"] = nil` между двумя вызовами `from_env` приводит к `KeyError` при втором вызове, а не к использованию кэша первого.

---

#### 6. Ограничения на реализацию и Grounding

| Файл | Роль |
|---|---|
| `core/lib/collect/blob_storage.rb` | Новый файл: класс `Collect::BlobStorage` с конструктором, `from_env` и `#store` |
| `core/lib/collect.rb` | Добавить `require_relative "collect/blob_storage"` |
| `Gemfile` | `aws-sdk-s3 ~> 1.0` — уже присутствует; новых gem не требуется |
| `.env.example` | `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` — уже объявлены |
| `spec/spec_helper.rb` | `$LOAD_PATH` уже включает `core/lib` — тестовый prerequisite выполнен |
| `spec/core/collect/blob_storage_spec.rb` | Новый spec: использовать `Aws::S3::Client.new(stub_responses: true)` или `double`; не требует реального S3 |
| `config/initializers/collect.rb` | Уже загружает `core/lib/collect`; не требует изменений |

**Паттерны реализации:**
- Конструктор сохраняет `@bucket` и `@client` как frozen-строку и объект соответственно.
- `from_env` строит `Aws::S3::Client` с параметрами из ENV: `endpoint`, `region`, `access_key_id`, `secret_access_key`, `force_path_style: true` (для MinIO-совместимых endpoint).
- В тестах использовать `Aws::S3::Client.new(stub_responses: true)` — работает без сети и без внешнего сервиса.
- Не расширять autoload-path; модуль загружается через уже существующий `require` в `collect.rb`.

---

#### 7. Acceptance Criteria

- [ ] `Collect::BlobStorage.new(bucket: "test-bucket", client: s3_client)` не поднимает исключение, если `bucket` — непустая строка и `client` — не `nil`.
- [ ] `Collect::BlobStorage.new(bucket: nil, client: s3_client)` поднимает `ArgumentError` с сообщением `"bucket must be a non-empty String"`.
- [ ] `Collect::BlobStorage.new(bucket: "", client: s3_client)` поднимает `ArgumentError` с сообщением `"bucket must be a non-empty String"`.
- [ ] `Collect::BlobStorage.new(bucket: "b", client: nil)` поднимает `ArgumentError` с сообщением `"client must not be nil"`.
- [ ] `storage.store(key: "raw/post_1.json", body: '{"id":1}')` возвращает строку `"raw/post_1.json"`.
- [ ] После успешного вызова `store` `client.put_object` был вызван ровно один раз с `bucket: "test-bucket"`, `key: "raw/post_1.json"`, `body: '{"id":1}'`.
- [ ] `storage.store(key: nil, body: "x")` поднимает `ArgumentError` с сообщением `"key must be a non-empty String"`.
- [ ] `storage.store(key: "", body: "x")` поднимает `ArgumentError` с сообщением `"key must be a non-empty String"`.
- [ ] `storage.store(key: "k", body: nil)` поднимает `ArgumentError` с сообщением `"body must not be nil"`.
- [ ] `storage.store(key: "k", body: "")` не поднимает исключение и возвращает `"k"`.
- [ ] Если `put_object` поднимает `Aws::S3::Errors::NoSuchBucket`, `#store` пробрасывает это исключение без оборачивания.
- [ ] Два последовательных вызова `store(key: "k1", body: "a")` и `store(key: "k1", body: "b")` приводят к двум вызовам `put_object` (мемоизации нет).
- [ ] `k = "blob_1"; result = storage.store(key: k, body: "x"); k << "_mutated"` — `result` равен `"blob_1"` и не изменяется после мутации `k`.
- [ ] `Collect::BlobStorage.from_env` при установленных `S3_BUCKET`, `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` возвращает экземпляр `Collect::BlobStorage`.
- [ ] `Collect::BlobStorage.from_env` при отсутствующем `S3_BUCKET` поднимает `KeyError` с сообщением `"S3_BUCKET is not set"`.
- [ ] Тест для `BlobStorage` проходит без реального S3-сервиса, используя `Aws::S3::Client.new(stub_responses: true)` или `double`.
- [ ] Все существующие тесты остаются зелёными.
- [ ] Инварианты не нарушены.

---

#### 8. Execution Metadata

- `system`: unknown
- `model`: claude-sonnet-4-6
- `provider`: Anthropic
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/01-2-generate-spec.md`

#### 9. Runtime Telemetry

- `started_at`: 2026-04-06T21:00:00+03:00
- `finished_at`: 2026-04-06T21:05:00+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
