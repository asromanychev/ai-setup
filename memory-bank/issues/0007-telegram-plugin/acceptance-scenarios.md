# Acceptance Scenarios — Issue #7

**Сценарий 1: Polling happy path**
- Дано: `Collect::TelegramPlugin` создан с `collection_mode: "polling"`, `bot_token_env: "TELEGRAM_BOT_TOKEN"`, `channel_username: "testchannel"`, а fake `ChannelClient` возвращает 2 поста и `next_cursor: { offset: 55 }`
- Когда: выполняется `plugin.sync_step(checkpoint_in: { last_message_id: 11, last_date: 1700000011, offset: 54 })`
- Тогда: в `records` остаётся только новый пост, а `checkpoint_out` становится `{ last_message_id: 12, last_date: 1700000012, offset: 55 }`
- Как проверить: `bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "reads bot token from ENV, fetches posts, filters duplicates, and returns checkpoint metadata"`

**Сценарий 2: Missing ENV token**
- Дано: valid polling config, но `ENV["TELEGRAM_BOT_TOKEN"]` blank
- Когда: вызывается `plugin.sync_step(checkpoint_in: nil)`
- Тогда: поднимается `Collect::ContractError`
- Как проверить: `bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "raises when the configured ENV variable is blank"`

**Сценарий 3: Invalid polling config**
- Дано: polling config без `channel_username`
- Когда: создаётся `Collect::TelegramPlugin.new(source_config: ...)`
- Тогда: конструктор поднимает `Collect::ContractError`
- Как проверить: `bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "rejects missing channel_username in polling mode"`

**Сценарий 4: Webhook happy path**
- Дано: `collection_mode: "webhook"` и `source_config[:webhook_payload]` содержит `channel_post`
- Когда: выполняется `plugin.sync_step(checkpoint_in: nil)`
- Тогда: плагин возвращает один DTO, `finished: true`, `checkpoint_out` содержит `last_message_id` и `last_date`
- Как проверить: `bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "maps webhook payload into plugin DTOs without using ChannelClient"`

**Сценарий 5: Webhook payload without channel_post**
- Дано: webhook payload содержит только `update_id`
- Когда: выполняется `plugin.sync_step(checkpoint_in: { last_message_id: 9, last_date: 1700000009 })`
- Тогда: `records: []`, `checkpoint_out` сохраняет прежний прогресс, `finished: true`
- Как проверить: `bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "returns an empty batch and preserves checkpoint when payload has no channel_post"`

**Сценарий 6: Registry registration**
- Дано: вызывается `Collect::PluginRegistry.default`
- Когда: выполняется `registry.fetch("telegram")`
- Тогда: возвращается `Collect::TelegramPlugin`, а `NullPlugin` остаётся доступным
- Как проверить: `bundle exec rspec spec/core/collect/plugin_registry_spec.rb`
