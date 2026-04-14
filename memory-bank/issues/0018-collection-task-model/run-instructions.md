# Run Instructions — Issue #18: CollectionTask Data Model

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

Пошаговая инструкция ручной проверки фичи `CollectionTask` (data model, state machine, FK-миграции).

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

---

## 1. Подготовка

### 1.1 Предварительные условия

- PostgreSQL запущен (или Docker Compose с `db` сервисом).
- `bundle install` выполнен.

### 1.2 Применить миграции

```bash
bundle exec rails db:migrate
```

Убедиться, что все три миграции в статусе UP:

```bash
bundle exec rails db:migrate:status
```

Ожидаемый вывод (фрагмент):

```
up  20260413000001  Create collection tasks
up  20260413000002  Migrate raw ingest items to collection task
up  20260413000003  Migrate sync checkpoints to collection task
```

### 1.3 Приложение стартует без ошибок

```bash
bundle exec rails runner "puts 'ok'"
```

Ожидаемый вывод: `ok` (без ошибок).

### 1.4 Начальное состояние БД

Для повторной проверки сбросить таблицу `collection_tasks`:

```sql
DELETE FROM collection_tasks;
-- raw_ingest_items и sync_checkpoints очистятся каскадно
```

---

## 2. Проверка сценариев

### Сценарий 1: Создание задания (happy path)

**Команда:**
```ruby
# rails console
task = CollectionTask.create!(
  requester_id: "agent-1",
  plugin_type: "telegram",
  external_id: "channel_123",
  collection_mode: "backfill",
  retention_policy: "delete"
)
puts "state=#{task.state}, consumed_at=#{task.consumed_at.inspect}"
```

**Ожидаемый результат:** `state=created, consumed_at=nil`

**Проверка:**
```sql
SELECT id, state, consumed_at, failed_at, last_error
FROM collection_tasks
WHERE requester_id = 'agent-1';
```
Одна строка, `state = 'created'`, все временные поля `NULL`.

---

### Сценарий 2: Полный lifecycle до consumed

**Команда:**
```ruby
t = CollectionTask.find_by!(requester_id: "agent-1")
t.queue!
t.start_collecting!
t.mark_ready!
t.consume!
puts "state=#{t.reload.state}, consumed_at=#{t.consumed_at.present?}"
```

**Ожидаемый результат:** `state=consumed, consumed_at=true`

**Проверка:**
```sql
SELECT state, consumed_at FROM collection_tasks WHERE requester_id = 'agent-1';
```
`state = 'consumed'`, `consumed_at IS NOT NULL`.

---

### Сценарий 3: fail! и retry

**Команда (fail):**
```ruby
t2 = CollectionTask.create!(
  requester_id: "agent-2", plugin_type: "telegram",
  external_id: "ch_fail", collection_mode: "backfill", retention_policy: "delete"
)
t2.queue!
t2.start_collecting!
t2.fail!(error: "timeout from Telegram API")
puts "state=#{t2.state}, last_error=#{t2.last_error}, failed_at=#{t2.failed_at.present?}"
```

**Ожидаемый результат:** `state=failed, last_error=timeout from Telegram API, failed_at=true`

**Команда (retry):**
```ruby
t2.start_collecting!
puts "state=#{t2.state}, last_error=#{t2.last_error.inspect}"
```

**Ожидаемый результат:** `state=collecting, last_error=nil`

**Проверка:**
```sql
SELECT state, last_error, failed_at FROM collection_tasks WHERE external_id = 'ch_fail';
```

---

### Сценарий 4: Недопустимый переход

**Команда:**
```ruby
t3 = CollectionTask.create!(
  requester_id: "agent-3", plugin_type: "telegram",
  external_id: "ch_invalid", collection_mode: "backfill", retention_policy: "delete"
)
begin
  t3.consume!
rescue CollectionTask::InvalidTransitionError => e
  puts "Caught: #{e.message}"
end
puts "state after error: #{t3.reload.state}"
```

**Ожидаемый результат:**
```
Caught: Cannot transition from 'created' to 'consumed'
state after error: created
```

---

### Сценарий 5: Дублирующееся задание

**Команда:**
```ruby
CollectionTask.create!(
  requester_id: "r1", plugin_type: "telegram", external_id: "ch1",
  collection_mode: "backfill", retention_policy: "delete"
)
begin
  CollectionTask.create!(
    requester_id: "r1", plugin_type: "telegram", external_id: "ch1",
    collection_mode: "backfill", retention_policy: "delete"
  )
rescue ActiveRecord::RecordInvalid => e
  puts "Caught: #{e.message}"
end
```

**Ожидаемый результат:** `Caught: Validation failed: External has already been taken`

**Проверка:**
```sql
SELECT COUNT(*) FROM collection_tasks WHERE requester_id = 'r1' AND external_id = 'ch1';
```
Результат: `1`.

---

### Сценарий 6: collection_mode неизменяем

**Команда:**
```ruby
tp = CollectionTask.create!(
  requester_id: "agent-poll", plugin_type: "telegram",
  external_id: "ch_poll", collection_mode: "polling",
  poll_interval_seconds: 60, retention_policy: "delete"
)
tp.collection_mode = "backfill"
begin
  tp.save!
rescue ActiveRecord::RecordInvalid => e
  puts "Caught: #{e.message}"
end
puts "collection_mode: #{tp.reload.collection_mode}"
```

**Ожидаемый результат:**
```
Caught: Validation failed: Collection mode cannot be changed after creation
collection_mode: polling
```

---

### Сценарий 7: Каскадное удаление

**Команда:**
```ruby
tc = CollectionTask.create!(
  requester_id: "agent-cascade", plugin_type: "telegram",
  external_id: "ch_cascade", collection_mode: "backfill", retention_policy: "delete"
)
RawIngestItem.create!(collection_task: tc, external_id: "msg_1")
SyncCheckpoint.create!(collection_task: tc, position: { cursor: 1 })
tc_id = tc.id
tc.destroy
puts "raw_ingest_items: #{RawIngestItem.where(task_id: tc_id).count}"
puts "sync_checkpoints: #{SyncCheckpoint.where(task_id: tc_id).count}"
```

**Ожидаемый результат:**
```
raw_ingest_items: 0
sync_checkpoints: 0
```

---

### Сценарий 8: poll_interval_seconds обязателен при polling

**Команда:**
```ruby
begin
  CollectionTask.create!(
    requester_id: "r2", plugin_type: "telegram", external_id: "ch2",
    collection_mode: "polling", retention_policy: "delete", poll_interval_seconds: nil
  )
rescue ActiveRecord::RecordInvalid => e
  puts "Caught: #{e.message}"
end
```

**Ожидаемый результат:** `Caught: Validation failed: Poll interval seconds ...`

**Проверка:**
```sql
SELECT COUNT(*) FROM collection_tasks WHERE requester_id = 'r2';
```
Результат: `0`.

---

## 3. Проверка инвариантов (VibeContract)

### INV-2: Orphan protection

Выполнено в Сценарии 7. Дополнительно — через прямой SQL:

```sql
-- Создать задание и связанные записи, затем удалить через SQL
DELETE FROM collection_tasks WHERE id = <id>;
-- Убедиться, что raw_ingest_items и sync_checkpoints удалены (ON DELETE CASCADE)
SELECT * FROM raw_ingest_items WHERE task_id = <id>;  -- пусто
SELECT * FROM sync_checkpoints WHERE task_id = <id>;  -- пусто
```

### INV-3: Уникальность на уровне БД

```sql
-- Попытка прямого дублирующегося INSERT:
INSERT INTO collection_tasks
  (requester_id, plugin_type, external_id, collection_mode, retention_policy, state, source_config, created_at, updated_at)
VALUES
  ('r1', 'telegram', 'ch1', 'backfill', 'delete', 'created', '{}', NOW(), NOW());
-- Ожидаемо: ERROR: duplicate key value violates unique constraint
```

### INV-5: Monotonic timestamps

```ruby
# rails console
t = CollectionTask.last  # задание в состоянии consumed
begin
  t.update!(consumed_at: nil)
rescue ActiveRecord::RecordInvalid => e
  puts "Monotonic: #{e.message}"
end
```

Ожидаемый результат: `Monotonic: Validation failed: Consumed at cannot be unset once established`

---

## 4. Что смотреть в логах

**Rails log (development.log):**

- Успешный create: `INSERT INTO "collection_tasks"` с корректными полями.
- Успешный transition (queue!): `UPDATE "collection_tasks" SET "state" = 'queued'`.
- Ошибка уникальности: `ActiveRecord::RecordInvalid (Validation failed: External has already been taken)`.
- InvalidTransitionError: не логируется AR, только код приложения (нет DB query после проверки VALID_TRANSITIONS).

**Признак скрытой ошибки:** если `create!` не поднял исключение, но `SELECT COUNT(*) FROM collection_tasks` показывает 0 — значит, используется другая БД (проверь RAILS_ENV).

---

## 5. Сброс состояния

После проверки всех сценариев:

```sql
-- Удалить все тестовые данные (cascade удалит raw_ingest_items и sync_checkpoints)
DELETE FROM collection_tasks;
```

Или для полного сброса test DB:

```bash
RAILS_ENV=test bundle exec rails db:schema:load
```

**Важно:** `RAILS_ENV=test bundle exec rails runner "..."` пишет данные в тестовую БД. Перед запуском rspec suite выполни `db:schema:load` если использовал rails runner против test DB.

---

## Automated verification

```bash
# Focused verification
bundle exec rspec spec/models/collection_task_spec.rb
# Ожидаемо: 26 examples, 0 failures

# Regression gate
bundle exec rspec spec/models/
# Ожидаемо: N examples, 0 failures, 28 pending
```
