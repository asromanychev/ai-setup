# Acceptance Scenarios — Issue #18: CollectionTask Data Model

Контекст: Rails API-сервис сбора данных (ai-da-collect). Стек: Ruby 3.4 / Rails API /
PostgreSQL / Sidekiq (Redis) / S3-compatible blob storage / Docker.
Плагинная архитектура: каждый источник изолирован. Метаданные → PostgreSQL,
тела объектов → S3. Никакого AI, только ingestion.

---

## Сценарий 1: Создание задания с минимальными обязательными полями (happy path)

- **Дано:** чистая БД, таблица `collection_tasks` существует.
- **Когда:** в `rails console` выполнить:
  ```ruby
  task = CollectionTask.create!(
    requester_id: "agent-1",
    plugin_type: "telegram",
    external_id: "channel_123",
    collection_mode: "backfill",
    retention_policy: "delete"
  )
  ```
- **Тогда:** задание создано с `state: "created"`, `consumed_at: nil`, `failed_at: nil`, `last_error: nil`.
- **Как проверить:**
  ```sql
  SELECT id, state, consumed_at, failed_at, last_error FROM collection_tasks WHERE requester_id = 'agent-1';
  ```
  Результат: одна строка, `state = 'created'`, остальные поля `NULL`.

---

## Сценарий 2: Полный happy-path lifecycle от created до consumed

- **Дано:** существует задание `t = CollectionTask.find_by(requester_id: "agent-1")` в состоянии `created`.
- **Когда:** последовательно вызвать:
  ```ruby
  t.queue!
  t.start_collecting!
  t.mark_ready!
  t.consume!
  ```
- **Тогда:** задание в состоянии `consumed`, `consumed_at` установлен.
- **Как проверить:**
  ```sql
  SELECT state, consumed_at FROM collection_tasks WHERE id = <id>;
  ```
  `state = 'consumed'`, `consumed_at IS NOT NULL`.

---

## Сценарий 3: Переход в failed и retry

- **Дано:** задание в состоянии `collecting`.
- **Когда:**
  ```ruby
  t.fail!(error: "timeout from Telegram API")
  ```
- **Тогда:** `state: "failed"`, `last_error: "timeout from Telegram API"`, `failed_at IS NOT NULL`.
- **Как проверить:**
  ```sql
  SELECT state, last_error, failed_at FROM collection_tasks WHERE id = <id>;
  ```
- **Когда (retry):**
  ```ruby
  t.start_collecting!
  ```
- **Тогда:** `state: "collecting"`, `last_error: nil`.
- **Как проверить:**
  ```sql
  SELECT state, last_error FROM collection_tasks WHERE id = <id>;
  ```

---

## Сценарий 4: Недопустимый переход поднимает ошибку

- **Дано:** задание в состоянии `created`.
- **Когда:**
  ```ruby
  begin
    t.consume!
  rescue CollectionTask::InvalidTransitionError => e
    puts e.message
  end
  ```
- **Тогда:** поднято исключение `CollectionTask::InvalidTransitionError`, состояние задания не изменилось.
- **Как проверить:**
  ```sql
  SELECT state FROM collection_tasks WHERE id = <id>;
  ```
  `state = 'created'`.

---

## Сценарий 5: Дублирующееся задание отклоняется

- **Дано:** существует задание `(requester_id: 'r1', plugin_type: 'telegram', external_id: 'ch1')`.
- **Когда:**
  ```ruby
  CollectionTask.create!(
    requester_id: "r1",
    plugin_type: "telegram",
    external_id: "ch1",
    collection_mode: "backfill",
    retention_policy: "delete"
  )
  ```
- **Тогда:** поднято `ActiveRecord::RecordInvalid` (uniqueness violation).
- **Как проверить:**
  ```sql
  SELECT COUNT(*) FROM collection_tasks WHERE requester_id = 'r1' AND plugin_type = 'telegram' AND external_id = 'ch1';
  ```
  Результат: `1` (дубль не создан).

---

## Сценарий 6: collection_mode неизменяем после создания

- **Дано:** задание создано с `collection_mode: "polling"`.
- **Когда:**
  ```ruby
  t.collection_mode = "backfill"
  t.save!
  ```
- **Тогда:** поднято `ActiveRecord::RecordInvalid`, `collection_mode` остался `"polling"`.
- **Как проверить:**
  ```sql
  SELECT collection_mode FROM collection_tasks WHERE id = <id>;
  ```
  `collection_mode = 'polling'`.

---

## Сценарий 7: Каскадное удаление связанных данных

- **Дано:** существует задание с `raw_ingest_items` и `sync_checkpoints`.
  ```ruby
  task = CollectionTask.find(<id>)
  item = RawIngestItem.create!(collection_task: task, external_id: "msg_1")
  ```
- **Когда:**
  ```ruby
  task.destroy
  ```
- **Тогда:** все связанные `raw_ingest_items` и `sync_checkpoints` удалены.
- **Как проверить:**
  ```sql
  SELECT COUNT(*) FROM raw_ingest_items WHERE task_id = <id>;
  SELECT COUNT(*) FROM sync_checkpoints WHERE task_id = <id>;
  ```
  Оба результата: `0`.

---

## Сценарий 8: poll_interval_seconds обязателен при collection_mode polling

- **Дано:** чистая БД.
- **Когда:**
  ```ruby
  CollectionTask.create!(
    requester_id: "r2",
    plugin_type: "telegram",
    external_id: "ch2",
    collection_mode: "polling",
    retention_policy: "delete",
    poll_interval_seconds: nil
  )
  ```
- **Тогда:** поднято `ActiveRecord::RecordInvalid` (poll_interval_seconds invalid).
- **Как проверить:**
  ```sql
  SELECT COUNT(*) FROM collection_tasks WHERE requester_id = 'r2';
  ```
  Результат: `0` (запись не создана).
