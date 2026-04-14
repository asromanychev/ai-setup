# Acceptance Scenarios — Issue #8

**Сценарий 1: Success path переводит task в ready**
- Дано: task в `queued`, plugin возвращает два record и `checkpoint_out`.
- Когда: `CollectionTaskSyncJob.perform_now(task.id)`.
- Тогда: task становится `ready`, создаются `RawIngestItem`, checkpoint обновляется.
- Как проверить: `bundle exec rails runner 'task = CollectionTask.last; puts [task.state, task.sync_checkpoint&.position, task.raw_ingest_items.count].inspect'`

**Сценарий 2: 429 делает retry с retry_after**
- Дано: task в `queued`, plugin поднимает `Telegram::RateLimitError.new(attempts: 1, retry_after: 42)`.
- Когда: `CollectionTaskSyncJob.perform_now(task.id)` при `ActiveJob::Base.queue_adapter = :test`.
- Тогда: task остаётся `collecting`, в очередь ставится новая job с задержкой около 42 секунд.
- Как проверить: `puts enqueued_jobs.first.slice(:job, :args, :at)`

**Сценарий 3: 403 завершает task в failed**
- Дано: task в `queued`, plugin поднимает `Telegram::ApiError.new(error_code: 403, description: "Forbidden")`.
- Когда: `CollectionTaskSyncJob.perform_now(task.id)`.
- Тогда: retry не создаётся, task становится `failed`, `last_error` заполнен.
- Как проверить: `puts task.reload.attributes.slice("state", "last_error", "failed_at")`

**Сценарий 4: Пятый transient failure завершает task**
- Дано: task в `queued`, plugin поднимает `Telegram::TimeoutError`.
- Когда: job выполняется с `executions == 5`.
- Тогда: task становится `failed`, новая retry-job не ставится.
- Как проверить: `puts [task.reload.state, enqueued_jobs.size].inspect`

**Сценарий 5: Duplicate enqueue игнорируется**
- Дано: существует один `task_id`.
- Когда: дважды вызвать `CollectionTaskSyncJob.perform_later(task.id)`.
- Тогда: в test adapter остаётся только одна job этого класса.
- Как проверить: `puts enqueued_jobs.count { |job| job[:job] == CollectionTaskSyncJob }`
