# Spec — Issue #0005: Raw Ingest Item Persistence

**status:** draft  
**version:** v1  
**date:** 2026-04-07

---

## 1. Цель решения

Добавить ActiveRecord-модель `RawIngestItem`, которая фиксирует каждый ingested raw-объект в PostgreSQL: связь с `Source`, внешний идентификатор провайдера, опциональный `storage_key`, произвольные метаданные и семантику skip-with-log при дублировании.

### 1.1 Потребитель решения

- **Кто вызывает:** sync-оркестратор или фоновый Sidekiq job, выполняющий шаг ingestion для конкретного Source.
- **Когда:** после получения пакета объектов от плагина и сохранения тела в blob storage (если применимо).
- **Частота:** одна вставка на один объект провайдера за один sync-шаг.
- **Модель ответа:** синхронный side-effect в БД (create or skip); метод возвращает запись или сигнализирует о пропуске через лог.

---

## 2. Scope

**Входит:**
- Миграция: создание таблицы `raw_ingest_items` с колонками `source_id`, `external_id`, `storage_key` (nullable), `metadata` (jsonb), timestamps.
- Уникальный индекс на (`source_id`, `external_id`).
- Модель `RawIngestItem < ApplicationRecord` с валидациями и методом идемпотентной вставки.
- Метод `RawIngestItem.ingest!(source:, external_id:, storage_key: nil, metadata: {})` с семантикой skip-with-log.
- Spec: `spec/models/raw_ingest_item_spec.rb`.

**НЕ входит:**
- Парсинг или нормализация `metadata`.
- Downstream pipeline, embeddings, AI-анализ.
- API-эндпоинты для чтения.
- Управление retention.
- Интеграция с конкретным плагином (Telegram и др.).
- Upsert-перезапись (семантика уже исключена в Brief).

### 2.1 Preconditions

- Модель `Source` с полем `id` должна существовать в БД (задача #2 выполнена). **Stop condition:** если `Source` не существует, миграция завершится с ошибкой foreign key.
- Таблица `raw_ingest_items` должна отсутствовать до запуска миграции (первый запуск). **Stop condition:** если таблица уже существует, `rails db:migrate` пропустит миграцию.

---

## 3. Функциональные требования

**FR1.** `RawIngestItem` принимает обязательные атрибуты: `source_id` (integer, FK на `sources.id`), `external_id` (string, non-blank).

**FR2.** `storage_key` (string) опционален: может быть nil или пустым.

**FR3.** `metadata` (jsonb) опционален: по умолчанию `{}`. Хранится как-есть, без парсинга.

**FR4.** Уникальный индекс на (`source_id`, `external_id`) обеспечивает целостность на уровне БД.

**FR5.** Метод `RawIngestItem.ingest!(source:, external_id:, storage_key: nil, metadata: {})`:
  - Если запись с (source.id, external_id) не существует — создаёт её и возвращает созданный объект.
  - Если запись уже существует — пропускает вставку, записывает в Rails logger сообщение уровня `info` с указанием source_id и external_id, возвращает nil.
  - Метод атомарен: вставка происходит через одну операцию (INSERT ... ON CONFLICT DO NOTHING или эквивалент), а не через SELECT + INSERT.

**FR6.** `RawIngestItem` валидирует: наличие `source`, наличие и непустоту `external_id`.

---

## 4. Сценарии ошибок и состояния

**S1. Happy-path (новый объект):** `ingest!` с уникальным external_id создаёт запись, возвращает объект `RawIngestItem`.

**S2. Дубль (skip-with-log):** `ingest!` с уже существующим (source_id, external_id) не создаёт запись, возвращает nil, логирует сообщение `[RawIngestItem] skipped duplicate: source_id=X external_id=Y`.

**S3. Отсутствие source:** `ingest!` с `source: nil` поднимает `ArgumentError` (до обращения к БД).

**S4. Пустой external_id:** `ingest!` с `external_id: ""` или `external_id: nil` поднимает `ActiveRecord::RecordInvalid`.

**S5. Metadata nil vs {}:** `ingest!` с `metadata: nil` сохраняет `{}` (нормализация при вставке). Existing invariant: `metadata` никогда не nil в БД.

**S6. Adversarial aliasing metadata:** если вызывающий передаёт хэш и затем мутирует его после вызова `ingest!`, сохранённые данные не должны измениться. `metadata` должен быть сохранён как deep copy на уровне БД (jsonb сериализует по значению).

**S7. Повторный вызов ingest! с теми же аргументами дважды подряд:** второй вызов возвращает nil, первый — объект; итого одна запись в БД.

**S8. storage_key = "" (пустая строка):** допустим — сохраняется как-есть (не nil). Не валидируется как отсутствующий.

**Неприменимые состояния TAUS:**
- **Loading:** модель не реализует асинхронное состояние. Inapplicable.
- **In-progress:** операция синхронная, промежуточное состояние отсутствует. Inapplicable.

---

## 5. Инварианты

**I1.** Для любой пары (source_id, external_id) в таблице существует не более одной записи (обеспечено уникальным индексом + логикой вставки).

**I2.** `metadata` никогда не хранится как nil в БД — при nil-вводе нормализуется в `{}`.

**I3.** Существующие модели `Source`, `SyncCheckpoint` не изменяются этой задачей.

**I4.** Все существующие тесты остаются зелёными после добавления новой модели.

---

## 6. Grounding

**Новые файлы:**
- `db/migrate/TIMESTAMP_create_raw_ingest_items.rb` — новый файл, создаётся агентом.
- `app/models/raw_ingest_item.rb` — новый файл.
- `spec/models/raw_ingest_item_spec.rb` — новый файл.

**Существующие файлы (read-only):**
- `app/models/application_record.rb` — базовый класс, наследуется.
- `app/models/source.rb` — `has_many :raw_ingest_items` добавляется опционально, но НЕ обязательно для этой задачи (вне scope).
- `spec/rails_helper.rb` — уже существует, подключает test DB, transaction rollback.

**Паттерны проекта:**
- Миграции: `ActiveRecord::Migration[8.1]`, `create_table ... t.timestamps`, `add_index ... unique: true` — по образцу `20260406120000_create_sources.rb`.
- Модели: `class X < ApplicationRecord`, валидации через `validates`.
- Specs: `RSpec.describe X` + транзакционные тесты через `rails_helper.rb`.

---

## 7. Acceptance Criteria

- [ ] AC1: `RawIngestItem.ingest!(source: s, external_id: "X")` создаёт запись при первом вызове.
- [ ] AC2: Повторный `ingest!` с теми же (source, external_id) возвращает nil и не создаёт дубль.
- [ ] AC3: При `source: nil` поднимается `ArgumentError`.
- [ ] AC4: При `external_id: ""` поднимается `ActiveRecord::RecordInvalid`.
- [ ] AC5: `metadata: nil` нормализуется в `{}` при сохранении.
- [ ] AC6: Мутация хэша metadata после `ingest!` не изменяет сохранённые данные.
- [ ] AC7: `storage_key` может быть nil (объект без тела сохраняется успешно).
- [ ] AC8: Все существующие тесты остаются зелёными (`bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb`).
- [ ] AC9: Уникальный индекс на (`source_id`, `external_id`) присутствует в schema.

---

## Execution Metadata

| system | claude-sonnet-4-6 | Anthropic | 2026-04-07 | 01-2-generate-spec |
