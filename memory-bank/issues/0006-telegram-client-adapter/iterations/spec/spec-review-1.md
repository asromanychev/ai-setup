# Spec Review #1 — Issue #6

**Reviewed artifact:** `spec-v1.md`  
**Rubric:** `spec-rubric.json`  
**Date:** 2026-04-08

---

## TAUS Check

### T (Testable) — Pass (minor gaps)

14 AC, каждый описывает поведение и тестируется через stub-транспорт. Нет AC, требующих реальной сети.

**Gap 1:** Инвариант 3 ("stateless between calls") описан в Adversarial edge case как prose, но нет соответствующего AC. Falsifiable: два последовательных вызова с одним и тем же cursor дают одинаковый результат.

**Gap 2:** Инвариант 4 ("bot_token не логируется") не имеет falsifiable AC. Testable через захват Rails.logger в spec.

**Gap 3:** `Telegram::TimeoutError` присутствует в таблице состояний (строка "Таймаут"), но нет AC-N для этого случая.

### A (Ambiguous-free) — Pass

Все числа конкретны: 3 попытки, 5 сек. таймаут подключения, 10 сек. чтения, 1 сек. default retry_after. Нет слов «быстро», «удобно», «при необходимости». Семантика frozen, stateless зафиксирована однозначно.

### U (Uniform) — Pass (minor gaps)

Покрыты: happy path, empty, rate limit (retry + exhausted), 5xx, API error, timeout, nil inputs, wrong cursor type, пост без text, loading/in-progress явно признаны неприменимыми. Adversarial cases есть.

**Gap:** инварианты 3 и 4 — только в prose, не материализованы в AC (дублирует Gap 1, 2 из T).

### S (Scoped) — Pass

Одна фича: Telegram channel client. 

Подсчёт модульных зон:
1. `app/clients/telegram/` (channel_client.rb + errors.rb)
2. `spec/clients/telegram/`

Итого: 2 зоны < 3 — в пределах бюджета.

### Scope явно ограничен — Pass

Раздел 2 содержит «Входит» и «НЕ входит». Preconditions в 2.1 явно перечислены с materialized-check. Все зависимости из stdlib или уже в Gemfile.

### Инварианты — Pass

4 инварианта перечислены. Инварианты 1, 2 имеют falsifiable AC (AC-12, AC-4). Инварианты 3, 4 — gaps (см. T).

### Grounding — Pass

Все упомянутые пути создаются в этой задаче; нет ссылок на несуществующие гемы или классы. `Net::HTTP`, `JSON` — stdlib Ruby 3.4. Паттерн соответствует `tech_clients_auto_external-adapters.mdc`.

---

## Module-budget gate — Pass

2 модульные зоны.

## Precondition hygiene gate — Pass

Все prerequisite либо stdlib (✓), либо уже в Gemfile (✓), либо явно создаются в этой задаче.

## Boundary-to-AC completeness — Pass with gaps

- FR-9 (frozen DTO) → AC-4 ✓
- FR-4 (pagination) → AC-2, AC-5 ✓  
- FR-5 (rate limit) → AC-6 ✓  
- FR-3 (missing text field) → AC-11 ✓  
- FR-8 (timeout) → **gap: нет AC номера**  
- Invariant 3 (stateless) → **gap: нет AC**  
- Invariant 4 (no logging) → **gap: нет AC**

## FR/input-branch matrix

| Input branch | Success AC | Invalid-branch AC |
|---|---|---|
| bot_token nil/"" | — | AC-1 ✓ |
| channel_username nil/"" | — | AC-8 ✓ |
| cursor nil | AC-2 ✓ | — |
| cursor "string" | — | AC-9 ✓ |
| empty API response | AC-5 ✓ | — |
| 429 x3 | — | AC-6 ✓ |
| "ok":false | — | AC-7 ✓ |
| post без text | AC-11 ✓ | — |
| timeout | таблица состояний | **gap: нет AC** |

---

## Итог

| Измерение | Score | Weight | Взвешенный вклад | Blocker |
|---|---|---|---|---|
| testability | 4 | 0.25 | 1.00 | false |
| ambiguity_free | 5 | 0.20 | 1.00 | false |
| state_uniformity | 4 | 0.20 | 0.80 | false |
| precondition_hygiene | 5 | 0.20 | 1.00 | false |
| grounding_realism | 5 | 0.15 | 0.75 | false |

**Weighted score: 4.55 / 5.0**

Нет blockers, нет score <= 2. Однако три gap требуют добавления AC.

**Вердикт: `rework_required`** — добавить AC-15 (timeout), AC-16 (stateless), AC-17 (bot_token not logged), чтобы все инварианты имели falsifiable тест.

---

## fix_expectations

1. Добавить **AC-15:** stub-транспорт симулирует таймаут → `Telegram::TimeoutError`.
2. Добавить **AC-16:** два последовательных вызова `fetch_posts` с одним и тем же `cursor` через stub возвращают структурно идентичные результаты.
3. Добавить **AC-17:** при инициализации с реальным `bot_token` через `stub_transport`, Rails.logger не получает строку, содержащую значение `bot_token` — либо убрать инвариант 4 из обязательных falsifiable и пометить как «enforced by code review».

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-08 |
| prompt_id | 02-2-review-spec |

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
