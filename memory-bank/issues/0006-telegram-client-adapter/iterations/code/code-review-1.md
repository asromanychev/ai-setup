# Code Review #1 — Issue #6

**Reviewed files:**
- `app/clients/telegram/errors.rb` (новый)
- `app/clients/telegram/channel_client.rb` (новый)
- `spec/clients/telegram/channel_client_spec.rb` (новый)

**Rubric:** `code-rubric.json`  
**Runtime:** 19 focused examples 0 failures; 132 regression examples 0 failures  
**Date:** 2026-04-08

---

## Scope & Runtime Context

**allowlist из plan.md:**
- `app/clients/telegram/errors.rb` ✓
- `app/clients/telegram/channel_client.rb` ✓
- `spec/clients/telegram/channel_client_spec.rb` ✓

**Фактически изменено:** только эти 3 файла + `memory-bank/` (документация). `Gemfile`, `core/lib/`, `app/models/`, `db/schema.rb` — не тронуты.

---

## 1. Предпосылки

- Runtime-тесты прошли (подтверждено фактическим выполнением): 19 examples, 0 failures; 132 regression, 0 failures.
- `Net::HTTP`, `uri`, `json` — stdlib Ruby 3.4 (в Gemfile не требуются).
- `deep_freeze` / `deep_dup` дублирует логику из `core/lib/collect/plugin.rb` — допустимо, т.к. plan запрещает трогать core.

---

## 2. Инварианты и контракты

| Инвариант | Код | Статус |
|---|---|---|
| Только fetch — no AR | Нет ни одного `require "active_record"` или вызова `.save/.create/.insert` | ✓ |
| DTO frozen | `build_dto` возвращает `.freeze`; `raw: deep_freeze(deep_dup(post))` | ✓ |
| Stateless | `@bot_token`, `@http_class`, `@retry_delay` — readonly после initialize; `attempts` — локальная переменная в `request_updates` | ✓ |
| bot_token не логируется | Нет вызовов `Rails.logger` или `puts`; токен встроен в URL-путь (`/bot#{@bot_token}/...`), но не передаётся в logger | ✓ |

---

## 3. Трассировка путей выполнения

**Happy path:**
1. `fetch_posts(channel_username: "c", cursor: nil)` → offset = 0
2. `request_updates(offset: 0)` → `make_request(path: "getUpdates", params: { offset: 0, limit: 100 })`
3. HTTP 200 + `ok: true` → `return body`
4. `updates` фильтруется по `channel_post` и username, маппится в DTO
5. Возвращается frozen Hash `{ posts:, finished: false, next_cursor: { offset: last_update_id + 1 } }`

**Rate limit path:**
- 429 → `attempts < MAX_RETRIES` → `sleep_for(retry_after)` → retry
- На 3-й попытке → `RateLimitError.new(attempts: 3)` ✓

**Timeout path:**
- `Net::OpenTimeout` / `Net::ReadTimeout` в `make_request` → rescue → `raise TimeoutError` ✓

**API error path:**
- HTTP 200 + `"ok" => false` → `raise ApiError.new(error_code:, description:)` ✓

**Empty updates:**
- `updates.empty?` → `{ posts: [], finished: true, next_cursor: nil }` ✓

---

## 4. Риски и регрессии

**Severity: LOW**

1. **Symbol vs String cursor key** (`channel_client.rb:34`): `cursor.dup.fetch(:offset, 0)` — если внешний код передаёт `{ "offset" => 100 }` (строковый ключ), метод вернёт 0 вместо 100. Но spec.md явно задаёт форму `{ offset: Integer }` (symbol); клиент сам создаёт next_cursor с symbol key — пользователи будут передавать именно его. Риск минимален.

2. **channel_match? при nil post** (`channel_client.rb:85`): `post&.fetch("chat", nil)` — safe navigation оператор защищает от nil post. ✓ Но если `"channel_post"` ключ присутствует с nil значением в update, `post` будет nil и строка вернёт false (пост пропускается). Это корректное поведение.

3. **deep_freeze дублирование** (`channel_client.rb:94`): Логика идентична `core/lib/collect/plugin.rb`. Если в будущем поведение core изменится, клиент не унаследует изменения. Технический долг, но не дефект в текущей задаче.

**Нет рисков severity high или medium.**

---

## 5. Вердикт по эквивалентности

**Эквивалентно.**

Все 16 AC из spec.md доказуемо реализованы:

| AC | Код | Тест |
|---|---|---|
| AC-1 (blank bot_token) | initialize raises ArgumentError | ✓ |
| AC-2 (happy path structure) | fetch_posts returns correct Hash | ✓ |
| AC-3 (DTO keys + raw frozen) | build_dto + deep_freeze | ✓ |
| AC-4 (FrozenError on mutation) | build_dto returns .freeze | ✓ |
| AC-5 (empty → finished:true) | updates.empty? branch | ✓ |
| AC-6 (RateLimitError x3) | MAX_RETRIES=3, sleep_for | ✓ |
| AC-7 (ApiError ok:false) | unless body["ok"] | ✓ |
| AC-8 (blank channel_username) | raises ArgumentError | ✓ |
| AC-9 (invalid cursor type) | raises ArgumentError | ✓ |
| AC-10 (cursor isolation) | cursor.dup before use | ✓ |
| AC-11 (missing text → "") | build_dto: `post.fetch("text", "")` | ✓ |
| AC-12 (no AR calls) | нет импортов AR в файле | ✓ |
| AC-13 (regression green) | 132 examples, 0 failures | ✓ |
| AC-14 (инварианты не нарушены) | см. п. 2 выше | ✓ |
| AC-15 (TimeoutError) | rescue Net::OpenTimeout | ✓ |
| AC-16 (stateless repeat call) | нет изменяемого состояния | ✓ |

---

## 6. Что проверить тестами

*(Уже проверено — для справки)*

1. **cursor.dup isolation** — AC-10 проверяет мутацию после вызова ✓
2. **raw nested freeze** — дополнительный тест на `posts[0][:raw]["text"] = "x"` ✓
3. **retry_delay: 0** в AC-6 и 5xx ✓
4. **Net::OpenTimeout** в отдельном http_class stub ✓
5. **Repeated call idempotency** — AC-16 ✓

---

## 7. Confidence: 0.97

Единственное, что снижает с 1.0: `deep_freeze`/`deep_dup` — дубликат core-логики. Если эти методы содержат баг, он скопирован. Но тесты покрывают frozen behavior напрямую, так что риск маловероятен.

---

## Staged Validation Results

| Стадия | Результат |
|---|---|
| 1. Файлы созданы | ✓ |
| 2. Синтаксис OK | ✓ (Syntax OK для всех 3 файлов) |
| 3. Boot (клиент не в Rails autoload) | n/a — spec использует ручной $LOAD_PATH |
| 4. Migrations — все UP | ✓ (без изменений схемы) |
| 5. Focused: 19 examples, 0 failures | ✓ |
| 6. Regression: 132 examples, 0 failures | ✓ |

---

0 замечаний.

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-08 |
| prompt_id | 02-4-review-code |

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
