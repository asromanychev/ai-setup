# Run Instructions — Issue #8: CollectionTaskSyncJob

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

## Focused Verification

```bash
RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/jobs/collection_task_sync_job_spec.rb spec/clients/telegram/channel_client_spec.rb
```

## Manual Checks

1. Подготовить test DB:
```bash
RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rails db:prepare
```

2. Выполнить сценарии из [acceptance-scenarios.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0008-collection-task-sync-job/acceptance-scenarios.md).

## Feature-specific checks

- Проверить, что success-path создаёт `sync_checkpoints.task_id` и `raw_ingest_items.task_id` для одного и того же task.
- Проверить, что `last_error` остаётся `nil` между transient retry и terminal failure.
- Проверить, что duplicate enqueue не размножает job в test adapter.

## Verification Status

- Focused verification подтверждена:
  `27 examples, 0 failures`
- Full regression подтверждена:
  `197 examples, 0 failures, 28 pending`
- Pending относятся к pre-existing legacy `Source#upsert_checkpoint!` / `Source#sync_step!` сценариям в `spec/models/source_spec.rb`, а не к `#8`.
