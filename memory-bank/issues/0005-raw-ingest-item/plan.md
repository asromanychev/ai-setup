# Plan — Issue #0005: Raw Ingest Item Persistence

**status:** draft  
**version:** v1  
**date:** 2026-04-07

---

## 1. Паттерн оркестрации

Один агент, последовательно. Шаги строго упорядочены: миграция → модель → тест → верификация.

---

## 2. Grounding

- [x] `app/models/application_record.rb` существует.
- [x] `spec/rails_helper.rb` существует, подключает test DB, transaction rollback.
- [x] `db/migrate/` существует; паттерн миграции верифицирован по `20260406120000_create_sources.rb`.
- [x] `spec/models/source_spec.rb` существует (паттерн для spec файла).
- [x] `Source` модель и таблица `sources` существуют — FK target.
- [x] Новые файлы: `db/migrate/TIMESTAMP_create_raw_ingest_items.rb`, `app/models/raw_ingest_item.rb`, `spec/models/raw_ingest_item_spec.rb` — не существуют, создаются агентом.

---

## 3. Граф зависимостей

```
Шаг 1 (миграция) -> Шаг 2 (модель) -> Шаг 3 (тест) -> Шаг 4 (focused verification) -> Шаг 5 (regression gate)
```

---

## 4. Пошаговый план

### Шаг 1 [S]: `db/migrate/TIMESTAMP_create_raw_ingest_items.rb` → создать миграцию

**Что есть сейчас:** файл не существует.  
**Чего не хватает по spec.md:** таблица `raw_ingest_items` с колонками `source_id` (FK, NOT NULL), `external_id` (string, NOT NULL), `storage_key` (string, nullable), `metadata` (jsonb, NOT NULL, default `{}`), timestamps; уникальный индекс на (`source_id`, `external_id`); FK constraint на `sources.id`.  
**Нельзя трогать:** существующие миграции.

**Delta:**
```ruby
class CreateRawIngestItems < ActiveRecord::Migration[8.1]
  def change
    create_table :raw_ingest_items do |t|
      t.references :source, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :storage_key
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :raw_ingest_items, %i[source_id external_id], unique: true
  end
end
```

- Зависит от: нет зависимостей (Source уже существует как precondition).
- Откат: `rails db:rollback`.
- Наблюдаемый сигнал: `rails db:migrate` завершается без ошибок; в `db/schema.rb` появляется таблица `raw_ingest_items`.

---

### Шаг 2 [S]: `app/models/raw_ingest_item.rb` → создать модель

**Что есть сейчас:** файл не существует.  
**Чего не хватает по spec.md:** класс `RawIngestItem < ApplicationRecord`, `belongs_to :source`, валидации (source, external_id presence), метод `self.ingest!(source:, external_id:, storage_key: nil, metadata: {})` с семантикой skip-with-log.  
**Нельзя трогать:** `app/models/application_record.rb`, `app/models/source.rb`.

**Delta:**
- `belongs_to :source` — обеспечивает FK-проверку.
- `validates :external_id, presence: true`.
- `self.ingest!` реализован через `INSERT ... ON CONFLICT DO NOTHING` (через `insert` с `on_duplicate: :skip` или через низкоуровневый SQL) — логика:
  1. Проверить `source` не nil (иначе `ArgumentError`).
  2. Нормализовать `metadata: nil → {}`.
  3. Попытаться вставить через conflict-safe метод.
  4. Если строка не вставлена — лог info + return nil.
  5. Если строка вставлена — return объект.

- Зависит от: Шаг 1 (схема должна существовать перед тестом модели).
- Откат: удалить файл.
- Наблюдаемый сигнал: `RawIngestItem.new` в `rails console` не поднимает NameError.

---

### Шаг 3 [M]: `spec/models/raw_ingest_item_spec.rb` → создать тесты

**Что есть сейчас:** файл не существует.  
**Чего не хватает по spec.md:** тесты для AC1–AC9 по spec.md.  
**Нельзя трогать:** `spec/rails_helper.rb`, другие spec файлы.

**Покрытие AC:**

| AC | Тест |
|---|---|
| AC1 | `ingest!` с уникальным external_id создаёт запись |
| AC2 | Повторный `ingest!` возвращает nil, одна запись в БД |
| AC3 | `source: nil` → ArgumentError |
| AC4 | `external_id: ""` → ActiveRecord::RecordInvalid |
| AC5 | `metadata: nil` → сохраняется `{}` |
| AC6 | Мутация хэша после `ingest!` → сохранённые данные не изменяются |
| AC7 | `storage_key: nil` → запись создаётся успешно |
| AC9 | Уникальный индекс: прямая попытка двойного INSERT поднимает ActiveRecord::RecordNotUnique |

AC8 (regression) покрывается Шагом 5.

- Зависит от: Шаг 2 (модель должна существовать).
- Откат: удалить файл.
- Наблюдаемый сигнал: файл создан, содержит describe-блок для `RawIngestItem`.

---

### Шаг 4 [S]: Focused verification — новый spec

**Команда:**
```bash
bundle exec rspec spec/models/raw_ingest_item_spec.rb --format documentation
```

**Prerequisite:** test DB должна быть доступна и схема актуальна (`rails db:migrate RAILS_ENV=test`).  
**Наблюдаемый сигнал:** все примеры из `raw_ingest_item_spec.rb` — green (0 failures).  
**Зависит от:** Шаг 3.

---

### Шаг 5 [S]: Regression gate — существующий suite

**Команда:**
```bash
bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb
```

**Prerequisite:** test DB доступна.  
**Наблюдаемый сигнал:** 0 failures в существующих spec файлах. Pass = все examples green. Fail = любой failure.  
**Зависит от:** Шаг 4 (focused verification пройден).

---

## 5. Test Materialization Notes

- test DB: `rails db:migrate RAILS_ENV=test` применяет миграцию из Шага 1 к test schema.
- Transaction rollback между тестами уже настроен в `spec/rails_helper.rb` (без дополнительного setup).
- Нет необходимости в fixtures или seeds — все тесты создают данные in-test через ActiveRecord.

---

## Execution Metadata

| system | claude-sonnet-4-6 | Anthropic | 2026-04-07 | 01-3-generate-plan |
