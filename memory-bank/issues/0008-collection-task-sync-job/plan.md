# Plan — Issue #8: CollectionTaskSyncJob

## VibeContract

- Предусловие: `CollectionTask` уже существует и находится в `queued` или `failed`; plugin для `task.plugin_type` зарегистрирован.
- Постусловие success-path: task в `ready`, `sync_checkpoint.position` обновлён, `raw_ingest_items` созданы/дедуплицированы.
- Постусловие failure-path: task в `failed`, `last_error` заполнен, `failed_at` установлен.
- Инварианты: duplicate enqueue игнорируется; transient retry не записывает `last_error` до terminal failure; success после retry очищает `last_error`.

## Steps

1. Реализовать orchestration в [app/jobs/collection_task_sync_job.rb](/home/aromanychev/edu/aida/ai-da-collect/app/jobs/collection_task_sync_job.rb): state transition, plugin build, success persistence, error classification, retry/backoff, enqueue dedupe.
2. Расширить Telegram errors в [app/clients/telegram/errors.rb](/home/aromanychev/edu/aida/ai-da-collect/app/clients/telegram/errors.rb), чтобы `RateLimitError` отдавал `retry_after` наружу job.
3. Передать `retry_after` из [app/clients/telegram/channel_client.rb](/home/aromanychev/edu/aida/ai-da-collect/app/clients/telegram/channel_client.rb) в `Telegram::RateLimitError`.
4. Добавить focused specs в [spec/jobs/collection_task_sync_job_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/jobs/collection_task_sync_job_spec.rb) для success, retry, permanent fail, retry exhaustion и enqueue dedupe.
5. Дополнить клиентский spec в [spec/clients/telegram/channel_client_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/clients/telegram/channel_client_spec.rb), чтобы `retry_after` был закреплён контрактом.

## Runtime Gates

- Focused verification:
  `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/jobs/collection_task_sync_job_spec.rb spec/clients/telegram/channel_client_spec.rb`
- Regression:
  `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec`

## Blocker

- Sandbox не видел host services, но по runbook проверка с host privileges прошла: PostgreSQL на `127.0.0.1:5432` и Redis на `127.0.0.1:6379` доступны.
- Focused gate пройден: `27 examples, 0 failures`.
- Regression gate пройден с pre-existing pending в legacy `spec/models/source_spec.rb`: `197 examples, 0 failures, 28 pending`.
