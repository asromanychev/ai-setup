# Acceptance Scenarios — Issue #6: Telegram::ChannelClient

**Фича:** HTTP/SDK клиент для fetch сообщений публичного Telegram-канала с пагинацией и retry  
**Spec:** `spec.md`  
**Date:** 2026-04-08

---

## Рассуждение

Клиент работает в синхронном режиме, поэтому состояние `loading` неприменимо. Нужно покрыть:
1. Happy path: получение постов с пагинацией
2. Конец данных: пустой ответ API
3. Ошибки входных данных: nil/empty bot_token, nil username, неверный cursor
4. Rate limit: retry и exhaustion
5. Идемпотентность: повторный вызов с тем же cursor
6. Иммутабельность: frozen DTO
7. API error: `"ok": false`
8. Timeout: сетевой таймаут

---

**Сценарий 1: Happy path — первая страница постов**
- Дано: экземпляр `Telegram::ChannelClient` создан с `bot_token: "test_token"` и stub-транспортом, возвращающим JSON с 5 постами и `update_id` последнего = 42
- Когда: `client.fetch_posts(channel_username: "testchannel", cursor: nil)`
- Тогда: возвращается `{ posts: [5 элементов], finished: false, next_cursor: { offset: 43 } }`; каждый пост содержит ключи `message_id`, `date`, `text`, `raw`
- Как проверить: в rails console — `result = client.fetch_posts(...)` → `result[:posts].length == 5`, `result[:finished] == false`, `result[:next_cursor] == { offset: 43 }`

---

**Сценарий 2: Конец данных (нет новых постов)**
- Дано: stub-транспорт возвращает пустой массив `result: []` от API
- Когда: `client.fetch_posts(channel_username: "testchannel", cursor: { offset: 100 })`
- Тогда: возвращается `{ posts: [], finished: true, next_cursor: nil }`
- Как проверить: `result[:finished] == true`, `result[:next_cursor].nil? == true`, `result[:posts].empty? == true`

---

**Сценарий 3: Пагинация — последовательные страницы**
- Дано: stub-транспорт первого вызова возвращает 3 поста; stub второго вызова с `offset: next_update_id` — 2 поста
- Когда: первый вызов `fetch_posts(cursor: nil)` → второй вызов `fetch_posts(cursor: result[:next_cursor])`
- Тогда: первый вызов возвращает 3 поста и `finished: false`; второй вызов возвращает 2 других поста и `finished: false`; идентификаторы постов не пересекаются
- Как проверить: `first_ids = result1[:posts].map { |p| p[:message_id] }` → `second_ids = result2[:posts].map { |p| p[:message_id] }` → `(first_ids & second_ids).empty? == true`

---

**Сценарий 4: Иммутабельность DTO**
- Дано: клиент успешно вернул `posts` из сценария 1
- Когда: `posts[0][:text] = "mutated"`
- Тогда: поднимается `FrozenError`
- Как проверить: `expect { posts[0][:text] = "x" }.to raise_error(FrozenError)` — в rspec; в rails console: `posts[0][:text] = "x"` → получить `FrozenError (can't modify frozen Hash)`

---

**Сценарий 5: Ошибка входных данных — nil bot_token**
- Дано: попытка создания клиента с `bot_token: nil`
- Когда: `Telegram::ChannelClient.new(bot_token: nil, http_class: StubTransport)`
- Тогда: поднимается `ArgumentError`
- Как проверить: `expect { Telegram::ChannelClient.new(bot_token: nil) }.to raise_error(ArgumentError)` — в rspec

---

**Сценарий 6: Rate limit — exhaustion**
- Дано: stub-транспорт возвращает HTTP 429 три раза подряд (имитация `Retry-After: 0`)
- Когда: `client.fetch_posts(channel_username: "test", cursor: nil)`
- Тогда: поднимается `Telegram::RateLimitError`; количество попыток в сообщении ошибки = 3
- Как проверить: `expect { client.fetch_posts(...) }.to raise_error(Telegram::RateLimitError)` — в rspec; проверить `error.message.include?("3")`

---

**Сценарий 7: API error — ok:false**
- Дано: stub-транспорт возвращает `{ "ok": false, "error_code": 400, "description": "Bad Request" }`
- Когда: `client.fetch_posts(channel_username: "test", cursor: nil)`
- Тогда: поднимается `Telegram::ApiError`; `error.error_code == 400`; `error.description == "Bad Request"`
- Как проверить: `rescue Telegram::ApiError => e` → `e.error_code`, `e.description` в rails console

---

**Сценарий 8: Идемпотентность — повторный вызов с тем же курсором**
- Дано: stub-транспорт всегда возвращает одинаковые данные для одного `offset`
- Когда: два последовательных вызова `fetch_posts(channel_username: "test", cursor: { offset: 10 })`
- Тогда: оба вызова возвращают структурно идентичные результаты; клиент не мутирует cursor между вызовами
- Как проверить: `result1 = client.fetch_posts(cursor: {offset: 10})` → `result2 = client.fetch_posts(cursor: {offset: 10})` → `result1[:posts].map { |p| p[:message_id] } == result2[:posts].map { |p| p[:message_id] }`
