# Cycle Analysis 1 — Issue #7

## Что сработало

- Scope задачи оказался узким и хорошо заземлённым: `ChannelClient` уже готов, `CollectionTask` уже ввёл `polling/webhook`, поэтому реализация свелась к plugin-layer и registry.
- Главный архитектурный конфликт был найден до кода: PRD хочет `last_message_id` / `last_date`, а `ChannelClient` живёт на `offset`. Это снято явной договорённостью о расширенном checkpoint: канон домена + internal resume-key.
- Размещение плагина в `core/lib/collect/` позволило покрыть его existing pure-Ruby suite без полной загрузки Rails и без риска сломать `spec_helper`.

## Что осталось хрупким

- `webhook_payload` пока передаётся через `source_config`, то есть это transport bridge для issue `#7`, а не финальная интеграция webhook endpoint. Реальная подача payload останется на `#22` и `#8`.
- `channel_username` пока берётся из `source_config`, а не из `CollectionTask.external_id`; это осознанная локальная договорённость текущего plugin contract.

## Вывод

- Цикл прошёл за 1 итерацию на Brief/Spec/Plan, потому что доменный конфликт был вскрыт сразу.
- Template change не обязателен: правила already enough, дополнительный guard нужен только как локальная фиксация в issue docs.
