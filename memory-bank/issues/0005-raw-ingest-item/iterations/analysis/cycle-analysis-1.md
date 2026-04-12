# Cycle Analysis #1 — Issue #0005: Raw Ingest Item

**Дата:** 2026-04-07  
**Папка:** `memory-bank/issues/0005-raw-ingest-item/`  
**Artifacts analysed:** brief-v1/v2, spec-v1, plan-v1, code-review-1, scorecards, fix-contracts, activation records.

---

## 1. Brief

**Файл для обновления:** `01-1-generate-brief.md`  
**Условие (Триггер):** Issue содержит «семантику» или «поведение при дубле» как открытый вопрос (upsert vs skip-with-log, overwrite vs no-op).  
**Действие:** Перед сохранением Brief, если Критерий успеха зависит от выбора семантики (конкретного режима поведения при дубле, конфликте, ошибке), агент обязан зафиксировать одну выбранную семантику в §3 «Доменный контекст» и использовать её как единственный термин в Критерии успеха. Альтернативы в Критерии успеха (`X или Y`) запрещены.  
**Избегать:** Не оставлять в Критерии успеха нераскрытые альтернативы вида «(A или B)» — это создаёт неверифицируемый критерий.  
**Обоснование:** brief-v1 содержал «перезапись или пропуск с логом» — неразрешённую альтернативу, которая заблокировала активацию и потребовала fix-pass.

---

**Файл для обновления:** `02-1-review-brief.md`  
**Условие:** Критерий успеха содержит нераскрытую альтернативу в скобках.  
**Действие:** Добавить явный check в Шаг 3 перед analysis: «Если любой Критерий успеха содержит нераскрытую альтернативу вида `(A или B)`, это автоматически blocker для `success_criteria_observability`, независимо от остального текста».  
**Избегать:** Не давать score 3 (не-blocker) для неразрешённой альтернативы в Критерии успеха — это ключевая точка блокировки.  
**Обоснование:** score 3 был допустим, но критерий реально неверифицируем — нужен score ≤ 2 / blocker.

---

## 2. Spec

**Файл для обновления:** `01-2-generate-spec.md`  
**Условие:** Spec использует `insert` (bulk insert / AR class method) в `ingest!` как атомарную skip-on-conflict операцию.  
**Действие:** Если в FR или §2 Scope описана skip-on-conflict / idempotent insert семантика через low-level `insert`, добавить обязательный validation gate: перед `insert` все AR validations, которые задействованы в `validates`, должны быть явно вызваны или продублированы, так как `insert` обходит instance-level validations. Это должно быть зафиксировано в FR5 или как отдельный инвариант.  
**Избегать:** Не описывать `insert` + `validates :external_id, presence: true` как достаточно защищённую пару без явного упоминания того, что `insert` обходит AR validations.  
**Обоснование:** В коде первая версия `ingest!` пропускала validation для blank external_id — блокер был локальный, но его можно было предотвратить на уровне Spec.

---

**Файл для обновления:** `01-2-generate-spec.md`  
**Условие:** Spec вводит метод с name convention `X!` (bang method), который опирается на AR `validates`.  
**Действие:** Добавить в §3 FR explicit note: для bang методов, использующих bulk-insert операции, добавить пункт FR, который явно перечисляет, какие validations проверяются до insert и какие — на уровне БД (constraint). Граница «AR validation vs DB constraint» должна быть явной.  
**Избегать:** Молчаливо предполагать, что `validates :X, presence: true` защищает и bulk insert пути тоже.  
**Обоснование:** Предотвращает повторение паттерна «validation bypass через insert» в следующих моделях с аналогичным контрактом.

---

## 3. Plan

_Цикл Plan-v1 прошёл review без замечаний. Нет corrective findings._

**Файл для обновления:** `01-3-generate-plan.md`  
**Условие:** Plan содержит шаг с bang методом, использующим bulk insert.  
**Действие:** Добавить в Шаг 2 (модель): если метод `X!` использует `insert` (AR bulk insert), явно указать в delta step, какие validations должны быть вызваны до `insert` вручную (или через temporary instance). Это observable prerequisite шага, а не подразумеваемый факт.  
**Избегать:** Описывать delta как «реализовать ingest! с семантикой skip» без явного указания на validation bypass риск.  
**Обоснование:** Предотвращает первый pass с failing tests по AC4-типу в следующих задачах.

---

## 4. Code

**Файл для обновления:** `02-4-review-code.md`  
**Условие:** Код содержит bang метод + `insert` + AR `validates`.  
**Действие:** Добавить в review checklist явный пункт: «Если метод использует bulk `insert`, убедиться, что все AR validations явно вызываются до insert для non-DB-enforced constraints (presence, format, custom). Если нет — это blocker».  
**Избегать:** Принимать наличие `validates :X, presence: true` как достаточное без проверки, что `insert` path проходит через instance validations.  
**Обоснование:** code-review-1 потребовал fix для AC4 именно из-за отсутствия такой проверки.

---

**Файл для обновления:** `01-4-generate-code.md`  
**Условие:** `ingest!`-подобный метод с `human_attribute_name` в родительском паттерне (Source).  
**Действие:** Добавить в FR/Invariant → code path трассировку: если тест ожидает human-readable error message вида «X id can't be blank», проверить, что модель имеет `human_attribute_name` override. Если существующий паттерн (Source) использует такой override — следовать ему.  
**Избегать:** Не полагаться на умолчание Rails humanize для составных атрибутов вида `external_id` — Rails генерирует «External» вместо «External id» по умолчанию.  
**Обоснование:** Второй failing test в первом прогоне был вызван именно отсутствием `human_attribute_name`.

---

## 5. Кросс-цикловая оптимизация

**Правило 1 — Semantics-first gate для Brief:**  
Перед написанием любого Критерия успеха, который зависит от выбора между двумя конкурирующими семантиками поведения (idempotent insert vs upsert, error vs log, skip vs overwrite), Brief обязан зафиксировать выбранную семантику в доменном контексте. Переход к написанию AC без этого выбора запрещён. Применимо к любому prompt.

**Правило 2 — Validation bypass pre-check:**  
Если в Spec/Plan появляется bulk insert операция (`insert`, `upsert`, SQL `ON CONFLICT`) как часть idempotent contract, следующий generation step (01-4-generate-code) обязан явно материализовать validation bypass check до первого `insert` вызова. Это cross-stage invariant: спека вводит контракт, план описывает delta, код реализует explicit validation guard.

---

## Execution Metadata

| Поле | Значение |
|---|---|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-07 |
| prompt_id | 05-1-analyze-cycle |
