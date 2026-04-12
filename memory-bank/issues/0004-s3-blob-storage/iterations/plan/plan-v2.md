---
issue: 4
title: Хранилище: S3-совместимый адаптер для raw blob
status: draft
version: v2
date: 2026-04-06
---

# Implementation Plan: S3-Compatible Raw Blob Storage Adapter (Issue #0004)

## 1. Паттерн оркестрации

Один агент, последовательное выполнение. Порядок жёсткий: prerequisite/observational gates -> реализация сервиса -> materialized service specs -> focused verification без AWS secrets -> финальный regression gate.

## 2. Grounding

- [x] `app/services/collect/.keep` существует; новый файл [app/services/collect/blob_storage.rb](/home/aromanychev/edu/aida/ai-da-collect/app/services/collect/blob_storage.rb) допустим в уже существующей зоне.
- [x] `spec/rails_helper.rb` существует и поднимает Rails runtime для service-level specs.
- [x] `spec/spec_helper.rb` существует; coverage-assertion относится только к `core/lib`, поэтому service-layer change не требует новой coverage-политики, но не должен ломать существующий suite.
- [x] `Gemfile` уже содержит `aws-sdk-s3`; добавлять gem нельзя и не нужно.
- [x] `config/initializers/collect.rb` существует, но current scope запрещает bootstrap/load-path изменения.
- [x] `core/README.md` явно запрещает переносить S3-зависимость в `core/lib`.
- [x] `spec/core/collect/*.rb` и `spec/models/*.rb` уже существуют и должны остаться зелёными после добавления нового сервиса.

## 3. Граф зависимостей

```text
Шаг 1 -> Шаг 2 -> Шаг 3 -> Шаг 4 -> Шаг 5
```

## 4. Пошаговый план

1. Целевые файлы: нет, observational-only
   Суть шага: подтвердить два prerequisite-сигнала без правок кода:
   - Rails test runtime уже загружается через `spec/rails_helper.rb`;
   - локальная проверка blob-storage specs не требует AWS secrets и не зависит от live S3.
   Команды:
   - `bundle exec ruby -e 'require_relative "spec/rails_helper"; puts defined?(Rails); puts Gem.loaded_specs.key?("aws-sdk-s3")'`
   - `env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN -u AWS_REGION bundle exec rspec spec/core/collect/plugin_contract_spec.rb --dry-run`
   Что уже есть в текущем коде: `spec/rails_helper.rb` поднимает Rails; `Gemfile` уже содержит `aws-sdk-s3`; существующий core suite даёт безопасный dry-run smoke signal без сети.
   Чего не хватает по `spec.md`: наблюдаемого локального доказательства, что новый сервис можно добавить без bootstrap-правок и что тестовый runtime не опирается на `AWS_*` секреты.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `config/application.rb`, `config/initializers/collect.rb`, ENV wiring, credentials, deployment config.
   Наблюдаемый сигнал: первая команда печатает непустое определение `Rails` и `true` для `aws-sdk-s3`; вторая завершается с exit code 0 даже при unset `AWS_*`.
   Какие зависимости шаг разрешает: подтверждает, что реализация и проверки issue остаются в допустимом локально исполнимом scope.

2. Целевой файл: `app/services/collect/blob_storage.rb`
   Суть шага: создать `Collect::BlobStorage` с DI-конструктором `new(bucket:, client:)` и методом `#store(key:, body:, content_type: nil, metadata: {})`.
   Что уже есть в текущем коде: каталог `app/services/collect/` уже существует, но конкретного сервиса blob storage нет.
   Чего не хватает по `spec.md`: прикладного storage-адаптера, который:
   - валидирует `bucket` как непустой `String`;
   - валидирует `client` на `nil`;
   - валидирует `key`, `body`, `content_type`, `metadata`;
   - вызывает `client.put_object` ровно один раз;
   - передаёт `bucket`, `key`, `body` и только валидные optional-поля;
   - возвращает исходный `key`;
   - не нормализует `key`, не вызывает `read` заранее, не кэширует результат и не оборачивает исключения клиента;
   - защищает уже отправленные metadata-аргументы от post-call мутации входного Hash.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `Gemfile`, `config/initializers/collect.rb`, `core/lib/**`, модели AR, генерацию `storage_key`, ENV wiring и любой retry/backoff.
   Наблюдаемый сигнал: service object успешно инстанцируется при валидных `bucket` и `client`; spec doubles наблюдают ровно один `put_object` на вызов `#store`.
   Какие зависимости шаг разрешает: создаёт production implementation, к которой будут привязаны service specs.

3. Целевой файл: `spec/services/collect/blob_storage_spec.rb`
   Суть шага: создать service spec, который полностью материализует acceptance criteria и инварианты.
   Что уже есть в текущем коде: Rails helper готов, но каталога `spec/services/collect/` и spec для blob storage пока нет.
   Чего не хватает по `spec.md`: исполнимых examples для:
   - constructor validation: `bucket` (`nil`, `""`, non-String), `client: nil`;
   - store validation: `key`, `body`, `content_type`, `metadata`;
   - success-path возврата исходного `key`;
   - ровно одного вызова `client.put_object` с точным набором аргументов;
   - пропуска `content_type` и `metadata`, когда они не переданы;
   - IO-case, где body отвечает на `read`, но `read` не вызывается заранее;
   - exception pass-through без wrapping/retry;
   - двух независимых вызовов с тем же `key`;
   - post-call metadata isolation через захват аргументов `put_object` и проверку, что внешняя мутация исходного Hash не меняет уже зафиксированный payload.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `spec/spec_helper.rb`, существующие `spec/core/**`, любые тесты с живым S3, AWS account или секретами.
   Наблюдаемый сигнал: каждый example даёт конкретный pass/fail; IO example падает, если implementation вызовет `read` заранее; metadata example падает, если implementation передаст alias на исходный Hash.
   Какие зависимости шаг разрешает: превращает всю active spec в локально проверяемый suite.

4. Целевые файлы: `app/services/collect/blob_storage.rb`, `spec/services/collect/blob_storage_spec.rb`
   Суть шага: выполнить focused verification нового контракта в secret-free окружении, не смешивая его с regression suite.
   Команда:
   - `env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN -u AWS_REGION bundle exec rspec spec/services/collect/blob_storage_spec.rb`
   Что уже есть в текущем коде: после шагов 2 и 3 появятся implementation и его service spec.
   Чего не хватает по `spec.md`: наблюдаемого сигнала, что новый сервис проходит локально без внешнего S3 и без `AWS_*`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: любые source/spec файлы; этот шаг только проверяет.
   Наблюдаемый сигнал: exit code 0, все examples зелёные, suite не требует сетевых вызовов и не зависит от наличия AWS secrets.
   Какие зависимости шаг разрешает: даёт ранний runtime trigger перед финальным regression gate.

5. Целевые файлы: `spec/services/collect/blob_storage_spec.rb`, `spec/models/source_spec.rb`, `spec/models/sync_checkpoint_spec.rb`, `spec/core/collect/null_plugin_spec.rb`, `spec/core/collect/plugin_contract_spec.rb`, `spec/core/collect/plugin_registry_spec.rb`, `spec/core/collect/registry_null_plugin_integration_spec.rb`
   Суть шага: выполнить финальный runtime gate как чистую проверку acceptance и regression без дополнительных правок по месту.
   Команды:
   - `env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN -u AWS_REGION bundle exec rspec spec/services/collect/blob_storage_spec.rb spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb spec/core/collect`
   Что уже есть в текущем коде: после шагов 2-4 новый service contract должен быть зелёным локально; существующие suites уже материализованы в `spec/models` и `spec/core/collect`.
   Чего не хватает по `spec.md`: финального gate, который одновременно подтверждает новый blob-storage контракт и то, что существующие тесты проекта остались зелёными.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: все production/test файлы; шаг не допускает "если упало, починить тут же".
   Наблюдаемый сигнал: единая команда завершается с exit code 0; новые service specs зелёные; существующие `spec/models/*` и `spec/core/collect/*` зелёные; suite проходит при unset `AWS_*`, что подтверждает отсутствие скрытой зависимости на secrets/live S3.
   Какие зависимости шаг разрешает: закрывает runtime gates и завершает реализацию issue.

## 5. План тестирования

- `spec/services/collect/blob_storage_spec.rb`: весь сервисный контракт, включая error-paths, IO pass-through, repeated calls и metadata isolation.
- `spec/models/source_spec.rb`, `spec/models/sync_checkpoint_spec.rb`, `spec/core/collect/*`: regression coverage существующего поведения, которое active spec требует сохранить зелёным.

## 6. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/03-3-fix-plan.md`

## 7. Runtime Telemetry

- `started_at`: 2026-04-06T22:27:20+03:00
- `finished_at`: 2026-04-06T22:27:20+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
