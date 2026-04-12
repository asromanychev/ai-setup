---
issue: 4
title: Хранилище: S3-совместимый адаптер для raw blob
status: draft
version: v1
date: 2026-04-06
---

# Implementation Plan: S3-Compatible Raw Blob Storage Adapter (Issue #0004)

## 1. Паттерн оркестрации

Один агент, последовательное выполнение. Сначала подтверждается grounding по существующим зонам `app/services/collect` и `spec`, затем добавляется сервис, потом материализуется service-level RSpec, после чего выполняется финальный runtime gate.

## 2. Grounding

- [x] `app/services/collect/.keep` существует; папка `app/services/collect/` уже создана и допускает новый service object.
- [x] `spec/rails_helper.rb` существует и уже поднимает Rails test runtime.
- [x] `spec/spec_helper.rb` существует; отдельный coverage gate сейчас относится только к `core/lib`.
- [x] `Gemfile` уже содержит `aws-sdk-s3`; новая gem не требуется.
- [x] `config/initializers/collect.rb` существует, но меняет только core boot; bootstrap менять нельзя по scope.
- [x] `core/README.md` фиксирует, что S3-зависимость не должна переезжать в `core/lib`.
- [x] Нового runtime wiring через ENV, credentials или secrets manager этот план не добавляет.

## 3. Граф зависимостей

```text
Шаг 1 -> Шаг 2 -> Шаг 3 -> Шаг 4
```

## 4. Пошаговый план

1. Целевые файлы: нет, observational-only
   Суть шага: подтвердить, что текущий Rails test runtime уже подходит для service specs без новых bootstrap-правок: `bundle exec ruby -e 'require_relative "spec/rails_helper"; puts defined?(Rails); puts Dir.exist?("app/services/collect")'`.
   Что уже есть в текущем коде: `spec/rails_helper.rb` загружает Rails environment; каталог `app/services/collect/` существует.
   Чего не хватает по `spec.md`: явного наблюдаемого сигнала, что service spec можно запускать локально без правки `config/application.rb` или initializer'ов.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `config/application.rb`, `config/initializers/collect.rb`, load-path и bootstrap-механизм.
   Наблюдаемый сигнал: stdout содержит `constant`/непустое значение для `Rails` и `true` для каталога; exit code 0.
   Какие зависимости шаг разрешает: подтверждает precondition для создания сервиса и service spec без расширения scope.

2. Целевой файл: `app/services/collect/blob_storage.rb`
   Суть шага: создать сервис `Collect::BlobStorage` с injectable-конструктором `new(bucket:, client:)`, валидировать `bucket` и `client`, реализовать `#store(key:, body:, content_type: nil, metadata: {})`, который вызывает `client.put_object` ровно один раз, возвращает исходный `key`, не нормализует `key`, не читает IO заранее, не кэширует вызовы и не оборачивает исключения клиента.
   Что уже есть в текущем коде: папка `app/services/collect/` существует, но внутри нет реализации blob storage; зависимость `aws-sdk-s3` уже подключена в проекте.
   Чего не хватает по `spec.md`: самого адаптера хранения raw blob с полным контрактом валидации и single-call upload.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `Gemfile`, `config/initializers/collect.rb`, `core/lib/**`, генерацию `storage_key`, ENV wiring и любую persistence-логику моделей.
   Наблюдаемый сигнал: service object загружается в Rails runtime; вызов `store` с test double клиента передаёт `bucket`, `key`, `body` и optional-поля только при валидном вводе.
   Какие зависимости шаг разрешает: создаёт production-код, который смогут вызывать новые service specs из шага 3.

3. Целевой файл: `spec/services/collect/blob_storage_spec.rb`
   Суть шага: добавить service-level RSpec, который материализует acceptance criteria для конструктора и `#store`: валидация `bucket`, `client`, `key`, `body`, `content_type`, `metadata`; успешный возврат исходного `key`; один вызов `client.put_object`; проброс исключения клиента; два независимых вызова с одинаковым `key`; передача того же IO-объекта без раннего `read`; post-call isolation для `metadata` через захват аргументов вызова.
   Что уже есть в текущем коде: `spec/rails_helper.rb` уже настроен для Rails runtime; service spec для blob storage отсутствует.
   Чего не хватает по `spec.md`: исполнимых проверок всех AC и инвариантов без живого S3, без секретов и без сети.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `spec/spec_helper.rb` coverage-policy, существующие `spec/core/**`, а также любые интеграционные тесты с реальным S3.
   Наблюдаемый сигнал: каждый `it` даёт измеримый `pass/fail`; IO-case проверяет, что `read` не был вызван заранее; metadata-case фиксирует аргументы `put_object` до внешней мутации входного Hash.
   Какие зависимости шаг разрешает: превращает спецификацию в наблюдаемый test suite и подготавливает финальный runtime gate.

4. Целевые файлы: `app/services/collect/blob_storage.rb`, `spec/services/collect/blob_storage_spec.rb`
   Суть шага: выполнить финальную верификацию чистым runtime gate без дополнительных правок по месту: `bundle exec rspec spec/services/collect/blob_storage_spec.rb`.
   Что уже есть в текущем коде: после шагов 2 и 3 появятся service implementation и её целевой spec.
   Чего не хватает по `spec.md`: подтверждения, что локальный service-level контракт реально проходит в test runtime без внешнего S3.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: любые production- или test-файлы; этот шаг только проверяет.
   Наблюдаемый сигнал: команда завершается с exit code 0, все examples зелёные, нет сетевых обращений и нет требований к AWS secrets.
   Какие зависимости шаг разрешает: закрывает локальный runtime gate для реализации issue.

## 5. План тестирования

- `spec/services/collect/blob_storage_spec.rb`: весь контракт `Collect::BlobStorage` на уровне сервиса и test doubles.

## 6. Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/01-3-generate-plan.md`

## 7. Runtime Telemetry

- `started_at`: 2026-04-06T22:25:45+03:00
- `finished_at`: 2026-04-06T22:25:45+03:00
- `elapsed_seconds`: 0
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
