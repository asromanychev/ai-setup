# Spec: Telegram::ChannelClient — fetch + маппинг в DTO

**Issue:** #6  
**Status:** draft  
**Version:** v1  
**Brief:** `brief.md` (активирован)  
**Date:** 2026-04-08

---

## 1. Цель решения

Создать класс `Telegram::ChannelClient` в `app/clients/telegram/channel_client.rb`, который через Telegram Bot API получает посты публичного канала постранично и возвращает их в виде массива простых Ruby Hash (DTO) — без записи в БД, без бизнес-логики.

### 1.1 Потребитель решения

- **Кто вызывает:** будущий Telegram-плагин (`plugins/ai-da-collect-telegram/`), тесты.
- **Когда вызывается:** по требованию плагина в рамках `sync_step`; в тестах — напрямую через stub-транспорт.
- **Ожидаемая частота / объём:** ~100 постов/пакет; реальная частота определяется плагином.
- **Ожидаемая модель ответа:** синхронный результат — `{ posts:, next_cursor:, finished: }`.

---

## 2. Scope

**Входит:**
- Класс `Telegram::ChannelClient` с методом `#fetch_posts(channel_username:, cursor:)`.
- DTO-структура поста (Hash с фиксированными ключами).
- Обработка пагинации через offset-курсор.
- Обработка rate limit (429) — ограниченный retry.
- Поддержка инжекции транспорта через конструктор для тестов.
- Тесты в `spec/clients/telegram/channel_client_spec.rb` с stub-транспортом (без реальной сети).

**НЕ входит:**
- Запись в ActiveRecord.
- Интерпретация содержимого постов.
- Загрузка вложений.
- Приватные каналы.
- Telegram-плагин (`sync_step` и checkpoint).
- Авторизация userbot / MTProto.

### 2.1 Preconditions

- `net/http` — входит в Ruby stdlib (Ruby 3.4); отдельный gem не требуется. ✓
- `json` — входит в Ruby stdlib (Ruby 3.4). ✓
- `rspec` — уже в `Gemfile` (group `development, :test`). ✓
- Директория `app/clients/` не существует — **создаётся в рамках этой задачи** (не Precondition).
- Директория `spec/clients/` не существует — **создаётся в рамках этой задачи**.
- Telegram Bot API token поставляется через `source_config[:bot_token]` (ENV-based конфигурация плагина; тесты используют stub-транспорт и не требуют реального токена).

---

## 3. Функциональные требования

**FR-1. Конструктор клиента**  
`Telegram::ChannelClient.new(bot_token:, http_class: Net::HTTP)` — принимает строку `bot_token` (непустая) и инжектируемый `http_class` для тестов. Если `bot_token` пустой или nil — поднимает `ArgumentError`.

**FR-2. Метод fetch_posts**  
`client.fetch_posts(channel_username:, cursor: nil)` — возвращает Hash:
```
{
  posts:       Array<Hash>,   # массив DTO, может быть пустым
  next_cursor: Hash | nil,    # nil если finished: true
  finished:    Boolean        # true если постов больше нет
}
```

**FR-3. DTO-структура поста**  
Каждый элемент `posts` — Hash со следующими ключами (все обязательны в DTO):
```
{
  message_id: Integer,   # уникальный идентификатор сообщения
  date:       Integer,   # Unix timestamp публикации
  text:       String,    # текст поста (может быть пустой строкой, но не nil)
  raw:        Hash       # полный оригинальный объект от API (frozen)
}
```

**FR-4. Пагинация**  
Курсор имеет форму `{ offset: Integer }`, где `offset` — `update_id` последнего обработанного обновления + 1. `cursor: nil` запрашивает самые ранние доступные обновления (offset = 0). `finished: true` устанавливается когда API вернул 0 обновлений; `next_cursor` в этом случае `nil`.

**FR-5. Rate limit**  
При получении HTTP 429 от API: клиент ожидает `retry_after` секунд (из тела ответа, если есть; иначе 1 секунда) и повторяет запрос. Максимум **3 попытки** суммарно. После исчерпания попыток поднимает `Telegram::RateLimitError` с сообщением, включающим количество попыток.

**FR-6. Транзиентные ошибки**  
HTTP 5xx трактуются как транзиентные: повторный запрос через 1 секунду, максимум **3 попытки** суммарно. После исчерпания попыток поднимает `Telegram::TransientError`.

**FR-7. Ошибки API**  
Ответ API с `"ok": false` поднимает `Telegram::ApiError` с `error_code` и `description` из тела ответа.

**FR-8. Таймауты**  
Все HTTP-запросы выполняются с таймаутом подключения 5 секунд и чтения 10 секунд. Превышение таймаута поднимает `Telegram::TimeoutError`.

**FR-9. Иммутабельность DTO**  
Каждый Hash поста и поле `:raw` — frozen; внешняя мутация поднимает `FrozenError`. Мутация входного `cursor` Hash не влияет на внутреннее состояние клиента.

---

## 4. Uniform — состояния и edge cases

| Состояние | Поведение |
|---|---|
| Happy path | `posts` содержит массив DTO; `finished: false`; `next_cursor: { offset: N }` |
| Пустой канал / нет новых постов | `posts: []`, `finished: true`, `next_cursor: nil` |
| Курсор `nil` | Используется `offset: 0` (начало) |
| Rate limit (429), попыток не исчерпано | Ожидание + retry; результат прозрачен для вызывающего |
| Rate limit (429), 3 попытки исчерпаны | `Telegram::RateLimitError` |
| HTTP 5xx, 3 попытки исчерпаны | `Telegram::TransientError` |
| API вернул `"ok": false` | `Telegram::ApiError` с `error_code` и `description` |
| Таймаут соединения или чтения | `Telegram::TimeoutError` |
| `bot_token: nil` или `""` | `ArgumentError` из конструктора |
| `channel_username: nil` или `""` | `ArgumentError` из `fetch_posts` |
| `cursor` — не Hash и не nil | `ArgumentError` из `fetch_posts` |
| Пост без поля `text` в ответе API | DTO[:text] = `""` (не nil) |
| Состояние `loading` | **Неприменимо**: клиент синхронный, нет async-состояния |
| Состояние `in progress` | **Неприменимо**: один вызов — один пакет |

**Adversarial edge cases:**

- **Мутация DTO после получения:** вызывающий пытается изменить `posts[0][:text] = "new"` → `FrozenError`. DTO не мутируется извне.
- **Алиасинг cursor:** вызывающий передаёт тот же объект cursor дважды; второй вызов не видит мутацию первого — cursor копируется внутри клиента.
- **`raw` содержит вложенные mutable объекты:** после возврата DTO `posts[0][:raw]["nested"]["key"] = "x"` → `FrozenError`.
- **Повторный вызов fetch_posts:** два последовательных вызова с одним и тем же cursor дают идентичный результат (нет скрытого состояния в клиенте).

---

## 5. Инварианты

1. **Только fetch:** клиент никогда не вызывает ActiveRecord-методы (`save`, `create`, `update`, etc.).
2. **DTO frozen:** каждый элемент массива `posts` и его поле `:raw` — frozen после возврата.
3. **Без скрытого состояния:** состояние cursor не хранится внутри объекта клиента между вызовами; клиент stateless между вызовами `fetch_posts`.
4. **bot_token не логируется:** в Rails log не попадает значение `bot_token` ни при инициализации, ни при запросах.

---

## 6. Grounding (ограничения на реализацию)

| Что | Где / Как |
|---|---|
| Основной файл | `app/clients/telegram/channel_client.rb` — создать |
| Файл ошибок | `app/clients/telegram/errors.rb` — создать |
| Spec | `spec/clients/telegram/channel_client_spec.rb` — создать |
| Транспорт | `Net::HTTP` (Ruby stdlib) — без дополнительных gem |
| JSON-парсинг | `JSON.parse` (Ruby stdlib) — без дополнительных gem |
| Тест-транспорт | Stub-класс с методом `.new(host, port)` и `#request(req)` инжектируется через конструктор |
| Паттерн | Соответствует `tech_clients_auto_external-adapters.mdc`: конфиг через конструктор; no ActiveRecord |
| Конфиг приложения | `config/application.rb` — **не изменяется** |
| Gemfile | **не изменяется** (всё из stdlib) |

---

## 7. Acceptance Criteria

- [ ] **AC-1:** `Telegram::ChannelClient.new(bot_token: "", ...)` поднимает `ArgumentError`.
- [ ] **AC-2:** `client.fetch_posts(channel_username: "test", cursor: nil)` с stub-транспортом, возвращающим список постов, возвращает `{ posts: [...], finished: false, next_cursor: { offset: N } }`.
- [ ] **AC-3:** каждый элемент `posts` содержит ключи `message_id`, `date`, `text`, `raw`; `raw` — frozen Hash.
- [ ] **AC-4:** `posts[0][:text] = "x"` поднимает `FrozenError`.
- [ ] **AC-5:** stub-транспорт возвращает `[]` → `{ posts: [], finished: true, next_cursor: nil }`.
- [ ] **AC-6:** stub-транспорт возвращает HTTP 429 трижды → `Telegram::RateLimitError`.
- [ ] **AC-7:** stub-транспорт возвращает `"ok": false` → `Telegram::ApiError`.
- [ ] **AC-8:** `fetch_posts(channel_username: nil, ...)` поднимает `ArgumentError`.
- [ ] **AC-9:** `fetch_posts(..., cursor: "not-a-hash")` поднимает `ArgumentError`.
- [ ] **AC-10:** мутация переданного `cursor` Hash после вызова не изменяет результат следующего вызова.
- [ ] **AC-11:** пост без поля `text` в raw ответе API → `DTO[:text] == ""` (не nil).
- [ ] **AC-12:** клиент не вызывает ни один ActiveRecord-метод (`.save`, `.create`, `.update`, `.insert`).
- [ ] **AC-13:** все существующие тесты (`spec/`) остаются зелёными после добавления новых файлов.
- [ ] **AC-14:** инварианты не нарушены.

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-08 |
| prompt_id | 01-2-generate-spec |

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
