# Template Improvements — Issue #18: CollectionTask Data Model

**Входной артефакт:** `iterations/analysis/cycle-analysis-1.md`

---

## Таблица применения

| Рекомендация | Целевой файл | Тип | Статус |
|---|---|---|---|
| Brief: observability rule (Brief §1) | `01-1-generate-brief.md` | add gate | applied |
| Spec: conditional validation coverage (Spec §1) | `01-2-generate-spec.md` | add gate | applied |
| Plan: non-standard FK in delta (Plan §3.1) | `01-3-generate-plan.md` | add gate | applied |
| Plan: orphan data before add_foreign_key (Plan §3.2) | `01-3-generate-plan.md` | add gate | applied |
| Code: non-standard FK association check (Code §4.1) | `02-4-review-code.md` | tighten review | applied |
| K-2: staged validation test DB pollution | `MAKE_NEW_ISSUE.md` | document workflow | applied |
| Code: orphan data guard in migration (Code §4.2) | `01-4-generate-code.md` | — | skip as superseded |
| K-1: cross-cycle FK gate | `MAKE_NEW_ISSUE.md` | — | skip as duplicate |

---

## Что изменено

### 1. `memory-bank/templates/prompts/01-1-generate-brief.md`

Добавлен **Observability gate** под «Критерий успеха»:
> Критерии успеха должны описывать наблюдаемое поведение системы, а не техническую реализацию. Запрещено использовать имена AR-исключений, имена классов или методов в разделе Критериев Успеха Brief.

Закрывает: CS-2 в issue #18 использовал "ошибка уникальности" (technical term), что снизило score с 5 до 4.

### 2. `memory-bank/templates/prompts/01-2-generate-spec.md`

Добавлен **Conditional validation coverage gate** перед Bulk-insert gate:
> Для каждой условной валидации (if:) обязательно добавь SC для обеих ветвей: failing-path (поле nil/0 при включённом условии) И happy-path для ветки, где условие отключено.

Закрывает: SC-13 (non-polling без poll_interval_seconds) был выявлен только в spec-review и добавлен непосредственно в код без обновления spec.md — трассировка оборвалась.

### 3. `memory-bank/templates/prompts/01-3-generate-plan.md`

Добавлены два новых правила (10.2 и 10.3) перед существующим 10.1:

**10.2 Non-standard FK delta:**
> Если belongs_to/has_many/has_one и FK-колонка нестандартная — явно указать `foreign_key:` в delta каждого шага.

**10.3 Orphan data gate перед add_foreign_key:**
> Если миграция переименовывает FK и добавляет foreign_key на новую таблицу — добавить DELETE orphans перед add_foreign_key.

Закрывает: `ActiveModel::MissingAttributeError` из-за отсутствия `foreign_key: :task_id` в delta STEP-6/7, и `PG::ForeignKeyViolation` в migration 3 из-за orphan sync_checkpoints.

### 4. `memory-bank/templates/prompts/02-4-review-code.md`

Добавлен **Non-standard FK association check** перед существующим Bulk-insert check:
> Проверять в db/schema.rb имя FK-колонки. Если отличается от Rails-дефолта и foreign_key: отсутствует — это provable defect high.

Закрывает: статический анализ без запуска тестов должен ловить `belongs_to :collection_task` без `foreign_key: :task_id`.

### 5. `memory-bank/issues/MAKE_NEW_ISSUE.md`

Добавлен **⚠ Test DB pollution gate** в раздел 4.4 Staged Validation:
> После staged validation stage 6 с RAILS_ENV=test — выполнить db:schema:load перед следующим rspec.

Закрывает: RUG-1 в code-score-1.json — 21/26 failures из-за стейл-записи, созданной rails runner против test DB.

---

## Что пропущено

**Code §4.2 → 01-4-generate-code.md (orphan data guard in migration):**  
Правило покрыто добавленным пунктом 10.3 в `01-3-generate-plan.md`. Дублировать в `01-4-generate-code.md` нецелесообразно — план уже обязывает агента описать DELETE-шаг, а кодовый prompt читает план как обязательный контекст.

**K-1 → MAKE_NEW_ISSUE.md (cross-cycle FK gate):**  
Уже покрыто правилами 10.2 в `01-3-generate-plan.md` и Non-standard FK check в `02-4-review-code.md`. Дублировать в MAKE_NEW_ISSUE.md как отдельное правило излишне.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 06-1-apply-cycle-improvements |

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
