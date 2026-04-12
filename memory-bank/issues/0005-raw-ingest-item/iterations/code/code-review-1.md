# Code Review #1 — Issue #0005

**Дата:** 2026-04-07

---

## Scope Compliance

**Allowlist из plan.md:**
- `db/migrate/20260407000000_create_raw_ingest_items.rb` ✓ создан
- `app/models/raw_ingest_item.rb` ✓ создан
- `spec/models/raw_ingest_item_spec.rb` ✓ создан

Файлы вне allowlist не изменялись. 0 scope breach.

---

## AC Coverage

| AC | Статус | Примечание |
|---|---|---|
| AC1 | ✓ Pass | Covered |
| AC2 | ✓ Pass | skip-with-log + nil return + log assertion |
| AC3 | ✓ Pass | ArgumentError |
| AC4 | ✓ Pass (после fix) | Потребовалась правка: human_attribute_name + явная проверка пустой строки |
| AC5 | ✓ Pass | nil→{} нормализация |
| AC6 | ✓ Pass | Adversarial aliasing через jsonb сериализацию |
| AC7 | ✓ Pass | nil storage_key допустим |
| AC8 | ✓ Pass | Regression: 45 examples, 0 failures |
| AC9 | ✓ Pass | Прямой duplicate INSERT через create! поднимает RecordNotUnique |

---

## Инварианты

- **I1** (unique pair): уникальный индекс в миграции + skip-on-conflict логика в `ingest!`.
- **I2** (metadata nil→{}): нормализация в `ingest!` перед insert.
- **I3** (Source/SyncCheckpoint не изменены): файлы не тронуты.
- **I4** (regression): 45 examples, 0 failures.

---

## Технические замечания по реализации

**Правка в процессе:** первая версия модели использовала `insert` без предварительной AR-валидации, что пропускало `validates :external_id, presence: true` при пустой строке. Блокер решён в рамках allowlist добавлением явной проверки пустой строки и `human_attribute_name` переопределением (паттерн из `Source`).

**Атомарность вставки:** метод `insert` с `unique_by:` делает `INSERT ... ON CONFLICT DO NOTHING` — одна операция БД, без SELECT + INSERT race condition.

**Metadata aliasing:** защита обеспечена через jsonb сериализацию PostgreSQL — значение снимается как deep copy при вставке. Тест AC6 подтверждает: мутация входного хэша после `ingest!` не изменяет сохранённые данные.

---

## Runtime Gate Results

- **Focused verification:** `bundle exec rspec spec/models/raw_ingest_item_spec.rb` → **10 examples, 0 failures**
- **Regression gate:** `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` → **45 examples, 0 failures**

---

## Вердикт

0 замечаний. Все AC покрыты, оба runtime gates пройдены.

---

## Execution Metadata

| system | claude-sonnet-4-6 | Anthropic | 2026-04-07 | 02-4-review-code |
