# Run Instructions — Issue #21

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

## Feature-specific verification

1. Подготовить test schema:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rails db:prepare`
2. Прогнать focused verification:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/requests/tasks_api_spec.rb`
3. Прогнать regression gate:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec`

## Manual setup

1. Запустить приложение по общему runbook на development DB.
2. Создать task и items:
   `API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails runner 'task = CollectionTask.create!(requester_id: "agent-1", plugin_type: "telegram", external_id: "@cursor-demo", collection_mode: "polling", poll_interval_seconds: 300, retention_policy: "retain", source_config: {"bot_token_env"=>"TELEGRAM_BOT_TOKEN"}); task.queue!; task.start_collecting!; task.mark_ready!; 5.times { |i| RawIngestItem.create!(collection_task: task, external_id: "msg-#{i + 1}", metadata: {"message_id" => i + 1, "text" => "message #{i + 1}"}) }; puts task.id'`
3. Проверить первую страницу:
   `curl -s -H "Authorization: Bearer test-api-key" "http://127.0.0.1:3000/tasks/<TASK_ID>/items?after_id=0&limit=2"`
4. Проверить вторую страницу по `next_cursor` и затем конец потока.
5. Проверить негативный кейс:
   `curl -i -H "Authorization: Bearer test-api-key" "http://127.0.0.1:3000/tasks/<TASK_ID>/items?limit=1001"`

## Invariants to confirm manually

- `GET /tasks/:id/items` ничего не меняет в `collection_tasks.state`.
- `next_cursor` двигается вперёд только по `raw_ingest_items.id`.
- Повторный запрос с тем же курсором возвращает те же items, если между запросами не было новых вставок.
