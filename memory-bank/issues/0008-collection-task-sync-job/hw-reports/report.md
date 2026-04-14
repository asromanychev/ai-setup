# HW Report — Issue #8

## Что сделано

- Реализован `CollectionTaskSyncJob` вместо stub.
- Добавлена классификация transient/permanent Telegram errors.
- Добавлен retry с `retry_after`.
- Добавлен enqueue dedupe по `task_id` на уровне runtime.
- Добавлены focused specs для job и расширен spec `Telegram::ChannelClient`.

## Runtime verification

- `RAILS_ENV=test ... bundle exec rspec spec/jobs/collection_task_sync_job_spec.rb spec/clients/telegram/channel_client_spec.rb`
  Результат: `27 examples, 0 failures`.
- `RAILS_ENV=test ... bundle exec rspec`
  Результат: `197 examples, 0 failures, 28 pending`.

## Следующий шаг

- Если понадобится production-grade межпроцессная уникальность, заменить текущий in-process enqueue lock на Redis-backed механизм уровня Sidekiq.
