# Spec — Issue #7: Telegram Plugin

## 1. Цель решения

Добавить Telegram-плагин уровня `Collect::Plugin`, который связывает `CollectionTask`-конфигурацию с `Telegram::ChannelClient`: получает сообщения, маппирует их в DTO, возвращает `records` и `checkpoint_out`, но не пишет в БД.

## 2. Scope

- `REQ-1` Создать `Collect::TelegramPlugin` как реализацию `Collect::Plugin`.
- `REQ-2` Зарегистрировать плагин в `Collect::PluginRegistry.default` под `plugin_id = "telegram"`.
- `REQ-3` Поддержать `collection_mode: "polling"` через `Telegram::ChannelClient`.
- `REQ-4` Поддержать `collection_mode: "webhook"` через `source_config[:webhook_payload]` без сетевого вызова.
- `REQ-5` Читать секрет из ENV по имени из `source_config[:bot_token_env]`; в `source_config` хранится только имя переменной.
- `REQ-6` Возвращать DTO `{ message_id:, date:, text:, raw: }` и checkpoint, содержащий как минимум `last_message_id` и `last_date`.
- `NS-1` Не входит: запись `RawIngestItem` и `SyncCheckpoint` в БД.
- `NS-2` Не входит: HTTP-обработка webhook endpoint и Job orchestration.
- `NS-3` Не входит: приватные каналы, вложения, MTProto.

## 3. Preconditions

- `Telegram::ChannelClient` из issue `#6` уже существует и умеет polling через `offset`.
- Базовый контракт `Collect::Plugin` и `PluginRegistry` уже реализованы.
- `CollectionTask` уже валидирует `plugin_type: "telegram"` и `collection_mode: polling|webhook`.

## 4. Functional Requirements

**FR-1. Класс и идентификатор.**  
Плагин реализован как `Collect::TelegramPlugin < Collect::Plugin`; `self.plugin_id` возвращает `"telegram"`.

**FR-2. Конфигурация polling.**  
Для `collection_mode: "polling"` плагин требует:
- `source_config[:bot_token_env]` — непустое имя ENV-переменной;
- `source_config[:channel_username]` — публичный username канала.

Если ключ отсутствует или blank — поднимается `Collect::ContractError`.

**FR-3. Конфигурация webhook.**  
Для `collection_mode: "webhook"` плагин требует `source_config[:bot_token_env]`; `source_config[:webhook_payload]` допускается как `Hash` или `nil`. Если payload передан не хешем — `Collect::ContractError`.

**FR-4. ENV resolution.**  
Плагин читает токен через `ENV[source_config[:bot_token_env]]`. Если имя переменной задано, но значение отсутствует или blank, `sync_step` поднимает `Collect::ContractError`. Значение токена не попадает в `source_config` и не хардкодится в коде.

**FR-5. Polling mode.**  
В `polling` режиме плагин строит `Telegram::ChannelClient`, вызывает `fetch_posts(channel_username:, cursor:)`, получает `{ posts:, next_cursor:, finished: }`, фильтрует уже обработанные записи по `checkpoint_in.last_message_id` / `checkpoint_in.last_date`, и возвращает plugin-result:

```ruby
{
  records: [...],
  checkpoint_out: {
    last_message_id: Integer | nil,
    last_date: Integer | nil,
    offset: Integer | nil
  },
  finished: true | false
}
```

`offset` добавляется как internal resume-key, потому что `ChannelClient` уже работает через `getUpdates offset`; это не отменяет канонические поля `last_message_id` / `last_date` из PRD.

**FR-6. Webhook mode.**  
В `webhook` режиме плагин не создаёт `ChannelClient`. Он читает `source_config[:webhook_payload]`, берёт `channel_post`, маппирует его в один DTO и возвращает `finished: true`. Если `channel_post` отсутствует, плагин возвращает пустой батч и сохраняет предыдущий checkpoint.

**FR-7. DTO.**  
Каждый элемент `records` имеет вид:

```ruby
{
  message_id: Integer,
  date: Integer,
  text: String,
  raw: Hash
}
```

`raw` является deep-frozen копией payload/post. Сам DTO также frozen через базовый контракт `Collect::Plugin`.

## 5. Error and Edge Cases

- `SC-1` `PluginRegistry.default.fetch("telegram")` возвращает `Collect::TelegramPlugin`.
- `SC-2` Missing / blank `bot_token_env` → `Collect::ContractError`.
- `SC-3` Missing / blank `channel_username` в polling → `Collect::ContractError`.
- `SC-4` Unsupported `collection_mode` → `Collect::ContractError`.
- `SC-5` Blank ENV token при valid `bot_token_env` → `Collect::ContractError`.
- `SC-6` Polling path возвращает только записи новее checkpoint и обновляет `last_message_id`, `last_date`, `offset`.
- `SC-7` Webhook path не строит `ChannelClient`, маппирует `channel_post` в один DTO и возвращает `finished: true`.
- `SC-8` Webhook payload без `channel_post` → `records: []`, checkpoint сохраняется.

## 6. Invariants

- `INV-1` Плагин никогда не пишет в БД и не вызывает ActiveRecord.
- `INV-2` `source_config` хранит имя ENV-переменной, а не секрет.
- `INV-3` Polling и webhook используют один и тот же DTO-контракт.
- `INV-4` `NullPlugin` остаётся доступным и работоспособным в default registry.

## 7. Grounding

| Действие | Путь |
|---|---|
| СОЗДАТЬ | `core/lib/collect/telegram_plugin.rb` |
| ИЗМЕНИТЬ | `core/lib/collect.rb` |
| ИЗМЕНИТЬ | `core/lib/collect/plugin_registry.rb` |
| СОЗДАТЬ | `spec/core/collect/telegram_plugin_spec.rb` |
| ИЗМЕНИТЬ | `spec/core/collect/plugin_registry_spec.rb` |

## 8. Acceptance Criteria

- [ ] `Collect::TelegramPlugin.plugin_id == "telegram"`.
- [ ] `Collect::PluginRegistry.default.fetch("telegram")` возвращает класс плагина.
- [ ] В polling-режиме плагин читает bot token из ENV по имени из `source_config[:bot_token_env]`.
- [ ] В polling-режиме плагин вызывает `Telegram::ChannelClient` без реальной сети и возвращает валидный plugin-result.
- [ ] `checkpoint_out` содержит `last_message_id` и `last_date`; для polling дополнительно сохраняется `offset` как resume-key.
- [ ] В webhook-режиме плагин маппирует `channel_post` без построения `ChannelClient`.
- [ ] Missing/invalid config и blank ENV token приводят к `Collect::ContractError`.
- [ ] `NullPlugin` остаётся зарегистрированным и existing core specs не ломаются.
