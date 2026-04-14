# Run Instructions — Issue #20

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

1. Подготовить тестовую БД:
   `RAILS_ENV=test bundle exec rails db:prepare`
2. Прогнать целевые спеки:
   `bundle exec rspec spec/requests/tasks_api_spec.rb spec/models/collection_task_spec.rb spec/models/raw_ingest_item_spec.rb spec/models/sync_checkpoint_spec.rb`
3. Прогнать полный regression:
   `bundle exec rspec`
4. Для ручной проверки через Rails console:
   `bundle exec rails console`
5. В консоли можно проверить lifecycle:
   `task = CollectionTask.create!(requester_id: "agent-1", plugin_type: "telegram", external_id: "@channel", collection_mode: "polling", poll_interval_seconds: 300, retention_policy: "delete", source_config: {"bot_token_env"=>"TELEGRAM_BOT_TOKEN"})`
6. Проверить постусловия:
   `task.reload.state == "created"` до HTTP API и `queued` после `POST /tasks`; `GET /tasks/:id` не содержит `webhook_secret`; `POST /tasks/:id/consume` либо ставит `consumed_at`, либо очищает `RawIngestItem.where(task_id: task.id)` и `SyncCheckpoint.where(task_id: task.id)`.
