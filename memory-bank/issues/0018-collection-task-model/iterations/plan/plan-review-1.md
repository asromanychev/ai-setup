# Plan Review 1 — Issue #18: CollectionTask Data Model

**Проверен:** `plan-v1.md`  
**Рубрика:** `plan-rubric.json`

---

## Измерение 1: dependency_order (вес 0.25)

**Score: 4 / Confidence: 0.85**

**Хорошо:**
- Топологический порядок корректен: STEP-1,2,3 (миграции) → STEP-4b (apply) → STEP-5 (модель) → STEP-6,7,8 (обновление зависимых моделей) → STEP-9..12 (тесты) → Gate.
- Зависимости STEP-2 и STEP-3 от STEP-1 обоснованы (FK на `collection_tasks`).

**Незначительное замечание (не blocker):**  
Шаг нумерован как `STEP-4b` вместо `STEP-4`, при этом в графе зависимостей он указан как `STEP-4`. Это вызывает лёгкую путаницу при трассировке. Рекомендация: переименовать `STEP-4b` → `STEP-4` в следующей версии или добавить примечание.

**fix_expectation:** переименовать `STEP-4b` в `STEP-4` или добавить сноску в граф зависимостей. Не блокирует активацию.

---

## Измерение 2: step_atomicity (вес 0.20)

**Score: 5 / Confidence: 0.90**

Каждый шаг затрагивает ровно один файл или одну логическую операцию:
- STEP-1,2,3: по одному файлу миграции.
- STEP-4b: одна команда `rails db:migrate`.
- STEP-5: один файл `collection_task.rb`.
- STEP-6,7,8: по одному файлу модели.
- STEP-9..12: по одному файлу spec.

STEP-5 является наибольшим по объёму, но это логически единый файл с единственной ответственностью — `CollectionTask` model. Атомарность сохранена.

---

## Измерение 3: delta_specificity (вес 0.25)

**Score: 5 / Confidence: 0.90**

Каждый шаг содержит явную дельту в формате «что есть / что добавить / нельзя трогать»:
- STEP-2: точный список действий (удалить FK, удалить индекс, переименовать, добавить FK, добавить индексы).
- STEP-6: Bulk-insert validation delta явно описана: AR validations не вызываются при `insert`, guard реализуется через ручную проверку + raise.
- STEP-8: явно перечислено что убрать (upsert_checkpoint!, sync_step!, has_one :sync_checkpoint) и что оставить (validates, scope, normalize_identifiers).
- STEP-12: явно указано, какие `describe` блоки маркировать pending.

---

## Измерение 4: runtime_gate_quality (вес 0.15)

**Score: 5 / Confidence: 0.95**

**Two-tier gate:**
1. Focused verification: `bundle exec rspec spec/models/collection_task_spec.rb` → `N examples, 0 failures`.
2. Regression gate: `bin/ci` → `N examples, 0 failures, N pending`.

Оба имеют конкретные команды и pass/fail сигналы. CHK-1..CHK-6 + EVID-1 явно задокументированы. Финальный шаг является чистым gate без дополнительных правок.

**Observable signal validity:** у каждого промежуточного шага указан Signal в виде конкретной команды.

---

## Измерение 5: test_materialization (вес 0.15)

**Score: 4 / Confidence: 0.85**

**Хорошо:**
- STEP-9 создаёт `collection_task_spec.rb` с явным покрытием SC-1..SC-12.
- STEP-10,11,12 обновляют все зависимые spec-файлы с конкретными дельтами.
- Трассировка spec → SC/REQ из spec.md представлена в таблице.

**Незначительное замечание (не blocker):**  
Test materialization setup описан в prose-разделе, но не оформлен как отдельный STEP. Для edge case `CheckpointAmbiguityError` (в `sync_checkpoint_spec.rb`) используется прямой SQL с DROP/CREATE INDEX — это особый prerequisite-materialization. STEP-11 описывает его в дельте, но не содержит отдельного observable gate для этого конкретного adversarial case (только итоговый `bundle exec rspec` в Signal).

**fix_expectation:** добавить в STEP-11 явное упоминание о сохранении adversarial ambiguity test через прямой SQL с `task_id`. Не блокирует.

---

## Lifecycle Placement — Pass

- Immutable collection_mode: `before_validation` callback в STEP-5 → lifecycle-phase корректен.
- Monotonic timestamps: `before_validation` callback в STEP-5 → lifecycle-phase корректен.
- State machine: методы на модели в STEP-5 → runtime, правильная фаза.
- ON DELETE CASCADE: определён в миграции (STEP-2, STEP-3) → schema-phase, корректно.

## Invariant Materialization — Pass

| Инвариант | Шаг | Тест |
|-----------|-----|------|
| INV-1 (PG/S3) | STEP-5 — нет blob-полей в схеме | CHK-1 |
| INV-2 (orphan) | STEP-2,3 ON DELETE CASCADE | SC-11 в STEP-9 |
| INV-3 (uniqueness) | STEP-5 validate + STEP-1 index | SC-5, SC-6 в STEP-9 |
| INV-4 (immutable collection_mode) | STEP-5 before_validation | SC-7 в STEP-9 |
| INV-5 (monotonic) | STEP-5 before_validation | SC-8 в STEP-9 |

## Verification-Prerequisite Closure — Pass

Финальная команда `bin/ci` требует: test DB с актуальной схемой. STEP-4b применяет миграции в development. Test materialization section явно указывает команду `RAILS_ENV=test bundle exec rails db:schema:load` перед запуском. Достаточно для прохождения CI.

---

## Итог

| Измерение | Score | Weight | Вклад |
|-----------|-------|--------|-------|
| dependency_order | 4 | 0.25 | 1.00 |
| step_atomicity | 5 | 0.20 | 1.00 |
| delta_specificity | 5 | 0.25 | 1.25 |
| runtime_gate_quality | 5 | 0.15 | 0.75 |
| test_materialization | 4 | 0.15 | 0.60 |
| **weighted_score** | | | **4.60** |

**Блокеров: 0**  
**Verdict: `ready_for_activation`**

0 замечаний, план готов к реализации.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 02-3-review-plan |

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
