# Run Instructions — Issue #6: Telegram::ChannelClient

**Фича:** HTTP/SDK клиент для fetch сообщений публичного Telegram-канала  
**Реализовано:**
- `app/clients/telegram/errors.rb` — 4 error-класса
- `app/clients/telegram/channel_client.rb` — `Telegram::ChannelClient`
- `spec/clients/telegram/channel_client_spec.rb` — 19 examples

---

## 1. Подготовка

```bash
# Клонировать / обновить репозиторий
git pull origin main

# Установить зависимости
bundle install

# Применить миграции (все UP, клиент не использует БД)
bundle exec rails db:migrate

# Проверить статус миграций
bundle exec rails db:migrate:status
# Ожидаемый вывод:
#   up  20260406120000  Create sources
#   up  20260406120100  Create sync checkpoints
#   up  20260407000000  Create raw ingest items
```

**Начальное состояние:** клиент не использует БД или S3 — никакой подготовки данных не требуется.

---

## 2. Проверка сценариев (через rspec + stub)

Все сценарии проверяются без реальной сети через stub-транспорт:

```bash
bundle exec rspec spec/clients/ --format documentation
```

**Ожидаемый результат:** 19 examples, 0 failures.

### Сценарий 1: Happy path — первая страница постов

**Команда:**
```bash
bundle exec rspec spec/clients/telegram/channel_client_spec.rb \
  -e "returns posts, finished: false, and next_cursor on success" \
  --format documentation
```

**Ожидаемый результат:**
```
Telegram::ChannelClient
  #fetch_posts
    returns posts, finished: false, and next_cursor on success
1 example, 0 failures
```

### Сценарий 2: Конец данных

**Команда:**
```bash
bundle exec rspec spec/clients/telegram/channel_client_spec.rb \
  -e "returns posts: [], finished: true, next_cursor: nil" \
  --format documentation
```

### Сценарий 3: Пагинация (последовательные страницы)

Проверяется через rails console:
```ruby
# В rails console — загружаем клиент вручную
$LOAD_PATH.unshift(Rails.root.join("app/clients").to_s)
require "telegram/channel_client"

# Создаём stub-транспорт:
fake_response_1 = double(:r, code: "200", body: {
  "ok" => true,
  "result" => [
    { "update_id" => 101, "channel_post" => { "message_id" => 1, "date" => 1700000001,
      "text" => "Post 1", "chat" => { "username" => "testchannel" } } },
    { "update_id" => 102, "channel_post" => { "message_id" => 2, "date" => 1700000002,
      "text" => "Post 2", "chat" => { "username" => "testchannel" } } }
  ]
}.to_json)

responses = [fake_response_1]

stub_class = Class.new do
  define_method(:initialize) { |h, p| }
  define_method(:open_timeout=) { |v| }
  define_method(:read_timeout=) { |v| }
  define_method(:use_ssl=) { |v| }
  define_method(:request) { |req| responses.shift }
end

client = Telegram::ChannelClient.new(bot_token: "test", http_class: stub_class)
result = client.fetch_posts(channel_username: "testchannel", cursor: nil)

puts result[:posts].length      # => 2
puts result[:finished]          # => false
puts result[:next_cursor]       # => {:offset=>103}
puts result[:posts].first[:text] # => "Post 1"
```

### Сценарий 4: Иммутабельность DTO

```ruby
# В rails console (после загрузки из сценария 3):
begin
  result[:posts][0][:text] = "mutated"
rescue FrozenError => e
  puts "FrozenError поднят: #{e.message}"
end
# Ожидаемый вывод: FrozenError поднят: can't modify frozen Hash
```

### Сценарий 5: Ошибка входных данных

```ruby
# В rails console:
begin
  Telegram::ChannelClient.new(bot_token: nil)
rescue ArgumentError => e
  puts "ArgumentError: #{e.message}"
end
# => ArgumentError: bot_token must not be blank
```

### Сценарий 6: Rate limit exhaustion

**Команда:**
```bash
bundle exec rspec spec/clients/telegram/channel_client_spec.rb \
  -e "raises Telegram::RateLimitError after 3 attempts" \
  --format documentation
```

**Ожидаемый результат:** 1 example, 0 failures.

### Сценарий 7: API error

**Команда:**
```bash
bundle exec rspec spec/clients/telegram/channel_client_spec.rb \
  -e "raises Telegram::ApiError with error_code and description" \
  --format documentation
```

### Сценарий 8: Идемпотентность (повторный вызов)

**Команда:**
```bash
bundle exec rspec spec/clients/telegram/channel_client_spec.rb \
  -e "returns structurally identical results on repeated calls with same cursor" \
  --format documentation
```

---

## 3. Проверка инвариантов из VibeContract

### Инвариант 1: Только fetch (no AR)

```bash
# Убедиться что нет вызовов ActiveRecord в клиентском коде:
grep -n "ActiveRecord\|\.save\|\.create\|\.insert\|\.update" \
  app/clients/telegram/channel_client.rb
# Ожидаемый вывод: пусто
```

### Инвариант 2: DTO frozen

```ruby
# В rails console (после загрузки клиента):
result = client.fetch_posts(channel_username: "testchannel", cursor: nil)
puts result[:posts].first.frozen?         # => true
puts result[:posts].first[:raw].frozen?   # => true
```

### Инвариант 3: Stateless между вызовами

Проверяется сценарием 8 через AC-16.

### Инвариант 4: bot_token не логируется

```bash
# Убедиться что нет logger-вызовов:
grep -n "logger\|puts\|print\|STDOUT" app/clients/telegram/channel_client.rb
# Ожидаемый вывод: пусто
```

---

## 4. Что смотреть в логах (при реальных запросах)

При запуске с реальным bot_token и реальным каналом:

**Признак успеха в Rails log:**
- Нет ошибок `Telegram::` в log/development.log
- Приложение не падает

**Признак скрытой ошибки:**
- `Telegram::ApiError` в логах — проверить статус бота (добавлен ли в канал?)
- Пустой массив `posts` при известном активном канале — проверить `channel_username` (без `@`)
- `Telegram::TimeoutError` — проверить сеть/firewall

---

## 5. Сброс состояния

Клиент stateless — никакого состояния нет. БД не затрагивается.

```bash
# Ничего не требуется для сброса.
# Для повторного запуска тестов:
bundle exec rspec spec/clients/
```
