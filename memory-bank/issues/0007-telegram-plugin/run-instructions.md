# Run Instructions — Issue #7

Общий baseline запуска и проверки: `memory-bank/issues/RUNBOOK.md`

## 1. Подготовка

- Убедиться, что gems установлены: `bundle install`
- Экспортировать тестовый токен:

```bash
export TELEGRAM_BOT_TOKEN=test-token
```

## 2. Проверка сценариев

### Сценарий 1: Polling happy path

- Команда:

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "reads bot token from ENV, fetches posts, filters duplicates, and returns checkpoint metadata"
```

- Ожидаемый результат: пример зелёный; checkpoint включает `last_message_id`, `last_date`, `offset`
- Проверка: в выводе rspec `0 failures`

### Сценарий 2: Missing ENV token

- Команда:

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "raises when the configured ENV variable is blank"
```

- Ожидаемый результат: пример зелёный; внутри спеки ловится `Collect::ContractError`
- Проверка: `0 failures`

### Сценарий 3: Invalid polling config

- Команда:

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "rejects missing channel_username in polling mode"
```

- Ожидаемый результат: пример зелёный; конструктор отклоняет config
- Проверка: `0 failures`

### Сценарий 4: Webhook happy path

- Команда:

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "maps webhook payload into plugin DTOs without using ChannelClient"
```

- Ожидаемый результат: один DTO в `records`, `finished: true`
- Проверка: `0 failures`

### Сценарий 5: Empty webhook payload

- Команда:

```bash
bundle exec rspec spec/core/collect/telegram_plugin_spec.rb -e "returns an empty batch and preserves checkpoint when payload has no channel_post"
```

- Ожидаемый результат: `records: []`, checkpoint сохраняется
- Проверка: `0 failures`

### Сценарий 6: Registry registration

- Команда:

```bash
bundle exec rspec spec/core/collect/plugin_registry_spec.rb
```

- Ожидаемый результат: реестр резолвит и `null`, и `telegram`
- Проверка: `0 failures`

## 3. Проверка инвариантов

- Плагин не пишет в БД:

```bash
rg -n "ActiveRecord|create!|save!|update!|insert" core/lib/collect/telegram_plugin.rb
```

- Реестр сохраняет `NullPlugin`:

```bash
bundle exec rspec spec/core/collect/registry_null_plugin_integration_spec.rb
```

## 4. Что смотреть в логах

- Для этой задачи логов Rails не требуется: проверка полностью через core rspec.
- Признак скрытой ошибки: rspec показывает неизвестный plugin id, попытку создать `ChannelClient` в webhook mode или падение по blank ENV.

## 5. Сброс состояния

- Специфичных данных в БД нет.
- Если переменная окружения больше не нужна:

```bash
unset TELEGRAM_BOT_TOKEN
```

## 6. Git verification

```bash
git status --short
git diff --stat
git diff --name-only
```

Проверка scope: в diff должны быть только allowlist-файлы issue `#7` и `memory-bank/issues/0007-telegram-plugin/`.
