# Active context

**Назначение:** краткий фокус текущей сессии / ветки работы. Обновляй после значимого блока работы.

## Текущий фокус

- Основной MVP slice Telegram через Bot API теперь зафиксирован как `bot-attached channels`.
- В коде уже подтверждён ручной happy path: `CollectionTask` → `CollectionTaskSyncJob` → `raw_ingest_items` для публичного канала, где бот реально получает `channel_post`.
- HTTP API для downstream теперь включает `GET /tasks/:id/items` со stable cursor pagination по `raw_ingest_items.id`.
- Новый фокус roadmap: отдельная ветка `telegram_user` (#26–#30) для public/private channels через user session / MTProto.

## Открытые вопросы

- Текущий enqueue dedupe реализован in-process callback'ом ActiveJob; если потребуется межпроцессная уникальность Sidekiq на production runtime, её нужно будет закрепить отдельной интеграцией с Redis/`sidekiq-unique-jobs`.
- Для `telegram_user` нужно отдельно спроектировать credential/session model: секреты нельзя класть в `CollectionTask.source_config`.
- Runtime verification по runbook уже пройдена на host services: full rspec зелёный с 28 pre-existing pending в legacy `Source` specs.

## Ссылки

- Telegram bot flow: `#6`, `#7`, `#8`
- Telegram user flow: `#26`, `#27`, `#28`, `#29`, `#30`
