# Plan — Issue #7: Telegram Plugin

## VibeContract

**Предусловие:**
- `core/lib/collect/plugin.rb`, `plugin_registry.rb` и `NullPlugin` уже существуют.
- `app/clients/telegram/channel_client.rb` реализован и тестируется без сети.
- `source_config` хранит имя ENV-переменной с токеном, а не сам токен.

**Постусловие:**
- В `core/lib/collect/telegram_plugin.rb` есть Telegram-плагин с режимами `polling` и `webhook`.
- `PluginRegistry.default` регистрирует и `null`, и `telegram`.
- `spec/core/collect/telegram_plugin_spec.rb` покрывает polling/webhook, ENV и config errors.
- Focused verification и regression gate проходят локально.

**Инварианты:**
- Плагин не пишет в БД и не использует ActiveRecord.
- В `checkpoint_out` всегда есть канонический доменный прогресс `last_message_id` / `last_date`, а в polling дополнительно допускается `offset`.
- `NullPlugin` не регрессирует после регистрации Telegram plugin.

## 1. Allowlist изменений

- `core/lib/collect/telegram_plugin.rb`
- `core/lib/collect/plugin_registry.rb`
- `core/lib/collect.rb`
- `spec/core/collect/telegram_plugin_spec.rb`
- `spec/core/collect/plugin_registry_spec.rb`
- `memory-bank/issues/0007-telegram-plugin/**`
- `memory-bank/activeContext.md`

## 2. Шаги реализации

### STEP-1
Создать `core/lib/collect/telegram_plugin.rb`.

- Что есть: base contract `Collect::Plugin`, но Telegram-specific plugin отсутствует.
- Чего не хватает: реализация `plugin_id`, config validation, polling/webhook branches, ENV resolution, checkpoint mapping.
- Нельзя трогать: `Telegram::ChannelClient` и AR-модели.

### STEP-2
Обновить `core/lib/collect.rb` и `core/lib/collect/plugin_registry.rb`.

- Что есть: default registry содержит только `NullPlugin`.
- Чего не хватает: загрузка и регистрация `Collect::TelegramPlugin`.
- Нельзя трогать: контракт `PluginRegistry#register` и поведение unknown-plugin errors.

### STEP-3
Добавить `spec/core/collect/telegram_plugin_spec.rb` и расширить `spec/core/collect/plugin_registry_spec.rb`.

- Что есть: есть тесты на contract, registry и NullPlugin.
- Чего не хватает: Telegram-specific coverage без сети.
- Нельзя трогать: coverage threshold logic и существующие ожидания для `NullPlugin`.

### STEP-4
Собрать issue-артефакты `0007-telegram-plugin` по фактической реализации.

- Что есть: директория issue отсутствовала.
- Чего не хватает: active brief/spec/plan, acceptance scenarios, code review, run instructions, cycle-analysis, HW report.
- Нельзя трогать: чужие issue-папки и общие шаблоны без доказанной причины.

## 3. Runtime Gates

### Focused verification

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb spec/core/collect/plugin_registry_spec.rb
```

Pass signal: `0 failures`, polling/webhook examples зелёные, registry видит `telegram`.

### Regression gate

```bash
bundle exec rspec spec/core/collect
```

Pass signal: весь core-suite зелёный, `NullPlugin` и base contract не регрессировали.
