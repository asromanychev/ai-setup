# Spec Review 1 — Issue #18: CollectionTask Data Model

**Проверен:** `spec-v1.md`  
**Рубрика:** `spec-rubric.json`

---

## T (Testable) — Pass

Все 12 сценариев (SC-1..SC-12) имеют конкретный Observable output:
- SC-1: цепочка вызовов с проверкой `state`.
- SC-4: ожидаемое исключение `CollectionTask::InvalidTransitionError`.
- SC-7: ожидаемое `ActiveRecord::RecordInvalid` при изменении `collection_mode`.
- SC-12: `last_error == ""` при `fail!(error: nil)`.

CHK-1..CHK-8 содержат конкретные команды и Observable facts. EVID-1 указывает на `spec/models/collection_task_spec.rb`.

**Score: 5 / Confidence: 0.90**

---

## A (Ambiguous-free) — Pass

Нет слов-паразитов («быстро», «удобно», «при необходимости»). Все семантики явно выбраны:
- Immutable collection_mode: зафиксировано через `before_validation` callback.
- Soft delete: `state: 'deleted'`, запись остаётся в БД.
- `fail!(error: nil)` → `last_error = ""` — семантика явно описана в SC-E8.
- Retry-семантика: `start_collecting!` после `failed` очищает `last_error`.

Все доменные термины (`collection_mode`, `retention_policy`, `state`, `requester_id`) определены в brief.md и используются последовательно.

**Score: 5 / Confidence: 0.90**

---

## U (Uniform) — Pass с замечанием

**Хорошо:**
- SC-E1..SC-E8 покрывают ошибки (недопустимый переход, дубль, monotonic violation, polling validation).
- Состояния TAUS (`loading`, `empty`) явно помечены как неприменимые с объяснением.
- Adversarial cases для INV-2 (direct DELETE без cascade) и INV-3 (конкурентный INSERT) задокументированы.
- INV-4 (immutable collection_mode) содержит честное замечание об ограничении AR-callback при прямом SQL UPDATE.

**Незначительный пробел (не blocker):**  
В спеке нет явного SC или AC для happy-path создания задания с `collection_mode != 'polling'` (т.е. без `poll_interval_seconds`). FR-3 описывает, что `poll_interval_seconds` проверяется только для `polling`, но нет сценария, подтверждающего, что создание с другим collection_mode и без `poll_interval_seconds` успешно.

> Рекомендация: добавить `SC-13: CollectionTask с collection_mode != 'polling' создаётся успешно без poll_interval_seconds` в следующей итерации (при необходимости).

**Score: 4 / Confidence: 0.85**

---

## S (Scoped) — Pass

Модульные зоны:
1. `collection_tasks` — новая таблица + модель `CollectionTask` + spec.
2. `raw_ingest_items` — FK-миграция + обновление `RawIngestItem`.
3. `sync_checkpoints` — FK-миграция + обновление `SyncCheckpoint`.

Ровно 3 зоны — на границе лимита. Все три зоны атомарно связаны с одной доменной сущностью и не смешивают инфраструктурную обвязку с доменной логикой.

Текст спеки в рамках 1500 слов.

**Score: 5 / Confidence: 0.90**

---

## Precondition Hygiene — Pass

Раздел `2.1 Preconditions` явно перечислен:
- PostgreSQL доступен.
- Гемы `rails`, `pg` в Gemfile (подтверждено).
- Таблицы `raw_ingest_items` и `sync_checkpoints` существуют (подтверждено через `db/schema.rb`).
- `ApplicationRecord` существует (подтверждено через `app/models/application_record.rb`).

Нет ссылок на несуществующие гемы (state machine реализован ручным способом без внешнего гема).

**Score: 5 / Confidence: 0.95**

---

## Grounding Realism — Pass

Таблица Grounding в §6:

| Файл | Статус |
|------|--------|
| `db/schema.rb` | существует ✓ |
| `app/models/raw_ingest_item.rb` | существует ✓ |
| `app/models/sync_checkpoint.rb` | существует ✓ |
| `app/models/application_record.rb` | существует ✓ |
| `spec/models/raw_ingest_item_spec.rb` | существует ✓ |
| `spec/models/sync_checkpoint_spec.rb` | существует ✓ |
| `spec/rails_helper.rb` | существует ✓ |

Новые файлы (`collection_task.rb`, `collection_task_spec.rb`, 3 миграции) не требуют внешних зависимостей.  
`CollectionTask::InvalidTransitionError` — вложенный класс в модели, no external dependency.

**Score: 5 / Confidence: 0.95**

---

## Invariant-to-AC completeness

| Инвариант | Falsifiable AC/Scenario |
|-----------|------------------------|
| INV-1 (PG vs S3) | CHK-1 (схема не содержит blob-полей в collection_tasks) |
| INV-2 (orphan protection) | SC-11 |
| INV-3 (uniqueness) | SC-5, SC-6 |
| INV-4 (immutable collection_mode) | SC-7 |
| INV-5 (monotonic timestamps) | SC-8 |

Все инварианты покрыты.

---

## Итог

| Измерение | Score | Weight | Вклад |
|-----------|-------|--------|-------|
| testability | 5 | 0.25 | 1.25 |
| ambiguity_free | 5 | 0.20 | 1.00 |
| state_uniformity | 4 | 0.25 | 1.00 |
| precondition_hygiene | 5 | 0.15 | 0.75 |
| grounding_realism | 5 | 0.15 | 0.75 |
| **weighted_score** | | | **4.75** |

**Блокеров: 0**  
**Verdict: `ready_for_activation`**

0 замечаний, спека готова к реализации.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 02-2-review-spec |

## Runtime Telemetry

| Поле | Значение |
|------|----------|
| started_at | 2026-04-13T00:00:00Z |
| finished_at | 2026-04-13T00:00:00Z |
| elapsed_seconds | unknown |
| input_tokens | not available in current runtime |
| output_tokens | not available in current runtime |
| total_tokens | not available in current runtime |
| estimated_cost | not available in current runtime |
| limit_context | not available in current runtime |
