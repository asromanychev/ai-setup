# Plan: Telegram::ChannelClient — fetch + маппинг в DTO

**Issue:** #6  
**Status:** draft  
**Version:** v1  
**Spec:** `spec.md` (активирован)  
**Date:** 2026-04-08

---

## Паттерн оркестрации

Один агент, последовательно. Нет параллельных задач.

---

## VibeContract

**Предусловие:**
- Ruby 3.4 со stdlib (`net/http`, `uri`, `json`) — проверено.
- `rspec` в `Gemfile` — проверено (`gem "rspec"` в group `:development, :test`).
- `app/clients/` — **не существует** (создаётся в Шаге 1).
- `spec/clients/` — **не существует** (создаётся в Шаге 3).
- `Gemfile` — **не изменяется**.

**Постусловие:**
- `app/clients/telegram/errors.rb` существует и определяет 4 error-класса в `Telegram::`.
- `app/clients/telegram/channel_client.rb` существует и определяет `Telegram::ChannelClient`.
- `spec/clients/telegram/channel_client_spec.rb` существует и содержит ≥ 16 examples.
- `bundle exec rspec spec/clients/` → все examples green.
- `bundle exec rspec spec/` → все examples green (regression gate).
- `Gemfile` не изменился.

**Инварианты:**
- Клиент никогда не вызывает ActiveRecord (`.save`, `.create`, `.update`, `.insert`).
- Каждый элемент `posts` и его поле `:raw` — frozen после возврата.
- `@bot_token` не попадает ни в одну строку логирования.
- `Gemfile` и `db/schema.rb` не изменяются.

---

## Граф зависимостей

```
Шаг 1 (errors.rb) → Шаг 2 (channel_client.rb)
Шаг 2 → Шаг 3 (spec)
Шаг 3 → Шаг 4 (staged validation 1-4)
Шаг 4 → Шаг 5 (focused verification)
Шаг 5 → Шаг 6 (regression gate)
```

---

## Пошаговый план

---

### Шаг 1 [S]: Создать `app/clients/telegram/errors.rb`

**Целевой файл:** `app/clients/telegram/errors.rb` *(новый)*

**Дельта:**
- Что есть: файл не существует; `app/clients/` не существует.
- Чего не хватает: модуль `Telegram` с 4 классами ошибок (`RateLimitError`, `TransientError`, `ApiError`, `TimeoutError`).
- Что нельзя трогать: `core/lib/collect/errors.rb`, `Gemfile`.

**Содержимое файла:**
```ruby
# frozen_string_literal: true

module Telegram
  class Error < StandardError; end

  class RateLimitError < Error
    def initialize(attempts:)
      super("Telegram rate limit exceeded after #{attempts} attempt(s)")
    end
  end

  class TransientError < Error
    def initialize(attempts:)
      super("Telegram transient error after #{attempts} attempt(s)")
    end
  end

  class ApiError < Error
    attr_reader :error_code, :description

    def initialize(error_code:, description:)
      @error_code = error_code
      @description = description
      super("Telegram API error #{error_code}: #{description}")
    end
  end

  class TimeoutError < Error; end
end
```

**Зависит от:** нет зависимостей  
**Откат:** удалить файл и папку `app/clients/telegram/`.  
**Наблюдаемый сигнал:** `ls app/clients/telegram/errors.rb` → файл существует; `ruby -c app/clients/telegram/errors.rb` → `Syntax OK`.

---

### Шаг 2 [M]: Создать `app/clients/telegram/channel_client.rb`

**Целевой файл:** `app/clients/telegram/channel_client.rb` *(новый)*

**Дельта:**
- Что есть: `errors.rb` из Шага 1.
- Чего не хватает: класс `Telegram::ChannelClient` с конструктором и методом `fetch_posts`; логика пагинации, retry, маппинга в DTO.
- Что нельзя трогать: `core/lib/collect/`, `app/models/`, `Gemfile`, `config/application.rb`.

**Содержимое файла:**
```ruby
# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require_relative "errors"

module Telegram
  class ChannelClient
    MAX_RETRIES = 3
    DEFAULT_RETRY_AFTER = 1
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    API_HOST = "api.telegram.org"
    API_PORT = 443

    def initialize(bot_token:, http_class: Net::HTTP)
      raise ArgumentError, "bot_token must not be blank" if bot_token.nil? || bot_token.to_s.strip.empty?

      @bot_token = bot_token
      @http_class = http_class
    end

    def fetch_posts(channel_username:, cursor: nil)
      raise ArgumentError, "channel_username must not be blank" if channel_username.nil? || channel_username.to_s.strip.empty?
      raise ArgumentError, "cursor must be a Hash or nil" unless cursor.nil? || cursor.is_a?(Hash)

      offset = cursor.nil? ? 0 : cursor.dup.fetch(:offset, 0)
      body = request_updates(offset: offset)
      updates = body.fetch("result", [])

      if updates.empty?
        return { posts: [].freeze, finished: true, next_cursor: nil }.freeze
      end

      posts = updates
        .select { |u| u.key?("channel_post") }
        .select { |u| channel_match?(u["channel_post"], channel_username) }
        .map { |u| build_dto(u["channel_post"]) }
        .freeze

      last_update_id = updates.last.fetch("update_id")
      next_cursor = { offset: last_update_id + 1 }.freeze

      { posts: posts, finished: false, next_cursor: next_cursor }.freeze
    end

    private

    def request_updates(offset:)
      attempts = 0
      begin
        loop do
          attempts += 1
          response = make_request(path: "getUpdates", params: { offset: offset, limit: 100 })

          case response.code
          when "200"
            body = JSON.parse(response.body)
            unless body["ok"]
              raise ApiError.new(
                error_code: body.fetch("error_code", 0),
                description: body.fetch("description", "Unknown error")
              )
            end
            return body
          when "429"
            raise RateLimitError.new(attempts: attempts) if attempts >= MAX_RETRIES

            retry_after = extract_retry_after(response) || DEFAULT_RETRY_AFTER
            sleep(retry_after)
          else
            raise TransientError.new(attempts: attempts) if attempts >= MAX_RETRIES

            sleep(DEFAULT_RETRY_AFTER)
          end
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise TimeoutError, "Request to Telegram API timed out"
      end
    end

    def make_request(path:, params:)
      http = @http_class.new(API_HOST, API_PORT)
      http.open_timeout = OPEN_TIMEOUT if http.respond_to?(:open_timeout=)
      http.read_timeout = READ_TIMEOUT if http.respond_to?(:read_timeout=)
      http.use_ssl = true if http.respond_to?(:use_ssl=)

      uri_path = "/bot#{@bot_token}/#{path}?#{URI.encode_www_form(params)}"
      request = Net::HTTP::Get.new(uri_path)
      http.request(request)
    end

    def extract_retry_after(response)
      body = JSON.parse(response.body)
      body.dig("parameters", "retry_after")
    rescue JSON::ParserError
      nil
    end

    def channel_match?(post, username)
      chat = post&.fetch("chat", nil)
      return false unless chat

      chat["username"] == username.to_s ||
        chat["id"].to_s == username.to_s
    end

    def build_dto(post)
      {
        message_id: post.fetch("message_id"),
        date:       post.fetch("date"),
        text:       post.fetch("text", "") || "",
        raw:        deep_freeze(deep_dup(post))
      }.freeze
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each { |k, v| deep_freeze(k); deep_freeze(v) }
        value.freeze
      when Array
        value.each { |v| deep_freeze(v) }
        value.freeze
      when String
        value.freeze
      else
        value
      end
    end

    def deep_dup(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), h| h[deep_dup(k)] = deep_dup(v) }
      when Array
        value.map { |v| deep_dup(v) }
      when String
        value.dup
      else
        value
      end
    end
  end
end
```

**Зависит от:** Шаг 1  
**Откат:** удалить `app/clients/telegram/channel_client.rb`.  
**Наблюдаемый сигнал:** `ruby -c app/clients/telegram/channel_client.rb` → `Syntax OK`; файл существует.

---

### Шаг 3 [M]: Создать `spec/clients/telegram/channel_client_spec.rb`

**Целевой файл:** `spec/clients/telegram/channel_client_spec.rb` *(новый)*

**Дельта:**
- Что есть: `spec/spec_helper.rb` (существует, содержит `require "collect"`, `$LOAD_PATH.unshift` для core); `app/clients/telegram/channel_client.rb` из Шага 2.
- Чего не хватает: spec-файл с 16 examples, покрывающими AC-1–AC-16; stub-транспорт как вложенный класс в spec.
- Что нельзя трогать: `spec/rails_helper.rb`, `spec/spec_helper.rb`, существующие spec-файлы.

**Механизм stub-транспорта:**
```ruby
# В spec-файле определяется StubHttpClass:
def stub_http_class(responses)
  response_queue = responses.dup
  Class.new do
    define_method(:initialize) { |host, port| }
    define_method(:open_timeout=) { |v| }
    define_method(:read_timeout=) { |v| }
    define_method(:use_ssl=) { |v| }
    define_method(:request) { |req| response_queue.shift || response_queue.last }
  end
end

def stub_response(code:, body:)
  double(:response, code: code.to_s, body: body.to_json)
end
```

**Покрытие AC:**

| AC | Тест |
|---|---|
| AC-1 | `expect { ChannelClient.new(bot_token: "") }.to raise_error(ArgumentError)` |
| AC-2 | happy path через stub, проверить `posts.length`, `finished`, `next_cursor` |
| AC-3 | каждый post имеет ключи `:message_id`, `:date`, `:text`, `:raw`; `raw.frozen?` |
| AC-4 | `expect { posts[0][:text] = "x" }.to raise_error(FrozenError)` |
| AC-5 | stub с пустым `result: []` → `finished: true, next_cursor: nil` |
| AC-6 | stub возвращает 429 трижды → `RateLimitError` |
| AC-7 | stub возвращает `ok: false` → `ApiError` с проверкой `.error_code` |
| AC-8 | `fetch_posts(channel_username: nil)` → `ArgumentError` |
| AC-9 | `fetch_posts(cursor: "string")` → `ArgumentError` |
| AC-10 | передать cursor, мутировать hash после вызова, повторить — результат не изменился |
| AC-11 | post без поля `text` в raw → `DTO[:text] == ""` |
| AC-12 | нет вызовов ActiveRecord (проверяется наличием только stdlib в imports) |
| AC-13 | все существующие spec — в regression gate (Шаг 6) |
| AC-14 | инварианты не нарушены (проверяется через AC-4, AC-12, AC-16) |
| AC-15 | stub поднимает `Net::OpenTimeout` → клиент поднимает `Telegram::TimeoutError` |
| AC-16 | два последовательных вызова с одним cursor → структурно идентичные результаты |

**Заголовок spec-файла:**
```ruby
# frozen_string_literal: true

require "spec_helper"

$LOAD_PATH.unshift(File.expand_path("../../../app/clients", __dir__))
require "telegram/channel_client"

RSpec.describe Telegram::ChannelClient do
  # ...
end
```

**Зависит от:** Шаг 2  
**Откат:** удалить `spec/clients/telegram/channel_client_spec.rb`.  
**Наблюдаемый сигнал:** `ruby -c spec/clients/telegram/channel_client_spec.rb` → `Syntax OK`.

---

### Шаг 4 [S]: Staged Validation 1–4

**Цель:** убедиться что файлы созданы, синтаксис OK, приложение стартует (если применимо), миграций нет.

| Стадия | Команда | Pass signal |
|---|---|---|
| 1. Файлы существуют | `ls app/clients/telegram/ spec/clients/telegram/` | оба файла в выводе |
| 2. Синтаксис Ruby | `bundle exec ruby -c app/clients/telegram/errors.rb && bundle exec ruby -c app/clients/telegram/channel_client.rb` | `Syntax OK` для обоих |
| 3. Boot (опционально) | `bundle exec rails runner "require 'telegram/channel_client'; puts Telegram::ChannelClient.name"` | `Telegram::ChannelClient` в stdout — *этот шаг пропускается, если $LOAD_PATH клиентов не настроен в Rails autoload; клиент тестируется через rspec с ручным require* |
| 4. Миграции | `bundle exec rails db:migrate:status` | все UP; клиент не затрагивает БД |

**Зависит от:** Шаг 3  
**Наблюдаемый сигнал:** `Syntax OK` для обоих файлов; `ls` выводит файлы.

---

### Шаг 5 [S]: Focused Verification (новый suite)

**Команда:**
```bash
bundle exec rspec spec/clients/ --format documentation
```

**Pass signal:** все examples green, 0 failures, 16+ examples.  
**Fail signal:** любой example RED → остановить, не переходить к Шагу 6.

**Зависит от:** Шаг 4  
**Откат:** нет side-effects; исправить код и повторить.

---

### Шаг 6 [S]: Regression Gate (существующие suites)

**Команда:**
```bash
bundle exec rspec spec/ --format progress
```

**Pass signal:** все examples green; `0 failures`; coverage ≥ 80% (если coverage guard активен).  
**Fail signal:** любой existing example RED → не объявлять реализацию завершённой; исправить до выхода из этого шага.

**Зависит от:** Шаг 5  
**Откат:** нет side-effects.

---

## Файлы в allowlist (только эти)

| Файл | Действие |
|---|---|
| `app/clients/telegram/errors.rb` | создать (Шаг 1) |
| `app/clients/telegram/channel_client.rb` | создать (Шаг 2) |
| `spec/clients/telegram/channel_client_spec.rb` | создать (Шаг 3) |

**Не трогать:** `Gemfile`, `Gemfile.lock`, `db/schema.rb`, `config/application.rb`, `core/lib/`, `app/models/`, `spec/rails_helper.rb`, `spec/spec_helper.rb`.

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-08 |
| prompt_id | 01-3-generate-plan |

## Runtime Telemetry

| Поле | Значение |
|---|---|
| started_at | 2026-04-08T00:00:00Z |
| finished_at | 2026-04-08T00:00:00Z |
| elapsed_seconds | unknown |
| input_tokens | not available in current runtime |
| output_tokens | not available in current runtime |
| total_tokens | not available in current runtime |
| estimated_cost | not available in current runtime |
| limit_context | not available in current runtime |
