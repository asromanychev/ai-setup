# Template Improvements #1 — Issue #0005

**Вход:** `iterations/analysis/cycle-analysis-1.md`  
**Дата:** 2026-04-07

---

## Таблица применения

| Рекомендация из cycle-analysis-1 | Целевой файл | Тип изменения | Статус |
|---|---|---|---|
| Semantics-first gate (Brief) | `01-1-generate-brief.md` | add gate | applied |
| Unresolved-alternative = auto blocker | `02-1-review-brief.md` | tighten review | applied |
| Bulk-insert validation bypass gate (Spec) | `01-2-generate-spec.md` | add gate | applied |
| Bulk-insert validation delta (Plan) | `01-3-generate-plan.md` | add gate | applied |
| Human-attribute-name + validation guard (Code) | `01-4-generate-code.md` | add gate | applied |
| Bulk-insert validation bypass check (Review) | `02-4-review-code.md` | tighten review | applied |
| Cross-cycle: Semantics-first gate | `01-1-generate-brief.md` | already covered by semantics-first gate | skip as duplicate |
| Cross-cycle: Validation bypass pre-check | `01-2-generate-spec.md` + `01-4-generate-code.md` | already covered by bulk-insert gates | skip as duplicate |
| EXMAPLES.md — пример цикла Issue 5 | `memory-bank/issues/EXMAPLES.md` | document workflow | applied |

---

## Применённые изменения

### 1. `01-1-generate-brief.md`
**Добавлен:** раздел `6.2. Semantics-first gate`.  
Агент обязан зафиксировать одну семантику в Доменном контексте до написания AC. Альтернативы `(A или B)` в AC запрещены.  
**Закрывает:** brief-v1 blocker — нераскрытая альтернатива «upsert или skip-with-log» в Критерии успеха.

### 2. `02-1-review-brief.md`
**Добавлен:** раздел `1.1. Unresolved-alternative gate`.  
Нераскрытая альтернатива в любом Критерии успеха = автоматически blocker для `success_criteria_observability`. Score > 2 запрещён при наличии нераскрытой альтернативы.  
**Закрывает:** в review-1 альтернатива получила score 3 (не blocker) — по факту это блокирующий дефект.

### 3. `01-2-generate-spec.md`
**Добавлен:** раздел `Bulk-insert validation bypass gate`.  
Если FR использует bulk insert, требуется явное разграничение AR validations (до `insert`) и DB constraints. Falsifiable AC для blank/nil inputs обязателен.  
**Закрывает:** spec-v1 не зафиксировала, что `insert` обходит AR validations — это позволило коду пройти с bug до runtime.

### 4. `01-3-generate-plan.md`
**Добавлен:** раздел `10.1. Bulk-insert validation delta`.  
В delta шага с bulk `insert` явно указываются: какие AR validations не вызываются; как validation guard реализуется до `insert`.  
**Закрывает:** plan-v1 не упомянул validation bypass риск — агент реализовал без guard на первом прогоне.

### 5. `01-4-generate-code.md`
**Добавлены:** `Bulk-insert validation guard` и `Human-attribute-name consistency`.  
Явный guard до `insert`; проверка `human_attribute_name` override при наличии паттерна в соседних моделях.  
**Закрывает:** 2 failing tests в первом прогоне кода (AC4: blank external_id, неправильный error message).

### 6. `02-4-review-code.md`
**Добавлен:** `Bulk-insert validation bypass check`.  
Если diff содержит `insert` + AR validates → проверить наличие guard. Отсутствие guard = `provable defect high`.  
**Закрывает:** code-review не имел явного checklist для этого паттерна.

### 7. `memory-bank/issues/EXMAPLES.md`
**Добавлен:** пример цикла Issue 5 с ключевыми lessons (semantics-first, bulk-insert bypass).  
**Закрывает:** документирует новые паттерны для использования в будущих циклах.

---

## Пропущенные рекомендации

| Рекомендация | Причина пропуска |
|---|---|
| Cross-cycle semantics-first gate (как отдельное правило) | Уже полностью покрыт `6.2. Semantics-first gate` в `01-1-generate-brief.md` |
| Cross-cycle validation bypass pre-check (как общий workflow rule) | Уже покрыт специализированными gates в `01-2-generate-spec.md` и `01-4-generate-code.md` |

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-07 |
| prompt_id | 06-1-apply-cycle-improvements |

## Runtime Telemetry

| started_at | finished_at | elapsed_seconds | tokens |
|---|---|---|---|
| 2026-04-07T00:00:00Z | unknown | unknown | not available in current runtime |
