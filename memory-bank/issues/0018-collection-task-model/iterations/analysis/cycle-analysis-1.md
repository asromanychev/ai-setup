# Cycle Analysis — Issue #18: CollectionTask Data Model

## Проанализированная папка

`memory-bank/issues/0018-collection-task-model/`

Все файлы в `iterations/{brief,spec,plan,code,activation,analysis}/` прочитаны.  
Active-документы `brief.md`, `spec.md`, `plan.md` в корне папки прочитаны.

---

## Контекст цикла

Все четыре этапа активированы с первой итерации (0 fix-циклов). Итоговые weighted_scores:
- Brief v1: 4.80 (ready_for_activation)
- Spec v1: 4.75 (ready_for_activation)
- Plan v1: 4.60 (ready_for_activation)
- Code v1: 4.90 (ready_for_activation)

Реальные отклонения от плана произошли на этапе кодирования (runtime), а не в документах.

---

## 1. Brief

Файл для обновления: `01-1-generate-brief.md`  
Условие (Триггер): Brief содержит Критерии Успеха с упоминанием системных терминов (имён исключений, методов AR, кодов ошибок) вместо наблюдаемого поведения.  
Действие (Что добавить в промпт): Добавить правило: "Критерии успеха должны описывать наблюдаемый результат со стороны пользователя или вызывающего кода, а не техническую реализацию. Вместо «вызывает ошибку уникальности» → «система отклоняет попытку с явным сигналом отказа»."  
Избегать (Граница/Антипаттерн): Не использовать имена AR-исключений (`ActiveRecord::RecordInvalid`, `PG::UniqueViolation`) в разделе Критериев Успеха Brief — они принадлежат Spec.  
Обоснование: В issue #18 CS-2 использовал "ошибка уникальности" — это technical term, снизивший score success_criteria_observability с 5 до 4.

---

## 2. Spec

Файл для обновления: `01-2-generate-spec.md`  
Условие (Триггер): Spec описывает validation с условным `if:` (например, `validates :X if mode == 'polling'`) — есть как позитивный (polling + X), так и негативный (polling без X) путь, но отсутствует **happy-path сценарий для ветки, где условие НЕ применяется**.  
Действие (Что добавить в промпт): "Для каждой условной валидации (validates ... if:) обязательно добавь SC, который явно проверяет, что условие НЕ применяется в happy-path (т.е. запись успешно создаётся без этого поля, когда условие отключено)."  
Избегать (Граница/Антипаттерн): Не считать покрытие условной валидации полным, если есть только SC для failing-path (nil/0 при polling), но нет SC для passing-path (non-polling без поля).  
Обоснование: Reviewer нашёл пробел SC-13 (non-polling без poll_interval_seconds) только в spec-review; он был добавлен в коде, но не в spec.md — трассировка оборвалась между spec и code.

---

## 3. Plan

**Правило 3.1 — Non-standard FK names**

Файл для обновления: `01-3-generate-plan.md`  
Условие (Триггер): План содержит шаг `belongs_to :association_name` где имя FK-колонки отличается от Rails-дефолта (`association_name_id`).  
Действие (Что добавить в промпт): "Если FK-колонка называется иначе, чем Rails ожидает (не `association_name_id`), **явно укажи `foreign_key: :column_name` в delta** каждого шага, где меняется `belongs_to`, `has_many` или `has_one` на стороне ассоциации. Это касается как app/models, так и spec-файлов (через `create!(association: ...)`)."  
Избегать (Граница/Антипаттерн): Не писать в delta только `заменить belongs_to :source → belongs_to :collection_task` без явного упоминания `foreign_key:` опции при нестандартном имени колонки.  
Обоснование: Plan STEP-6 и STEP-7 не упомянули `foreign_key: :task_id`, что привело к `ActiveModel::MissingAttributeError: can't write unknown attribute collection_task_id` — ошибка была поймана только при runtime.

**Правило 3.2 — Staged validation и загрязнение тест-БД**

Файл для обновления: `01-3-generate-plan.md`  
Условие (Триггер): Plan содержит staged validation step 6 с `rails runner` для проверки записей в БД.  
Действие (Что добавить в промпт): "Если staged validation step 6 использует `rails runner` или `rails console` против test DB (RAILS_ENV=test), добавь явный пункт в план: после staged validation step 6 выполнить `RAILS_ENV=test bundle exec rails db:schema:load` перед следующим rspec-запуском. Альтернативно: использовать development DB для ручной проверки и test DB только для rspec."  
Избегать (Граница/Антипаттерн): Не использовать `RAILS_ENV=test bundle exec rails runner "Model.create!(...)"` как часть staged validation, если после этого следует запуск всего rspec suite без db:schema:load.  
Обоснование: Rails runner против test DB создал стейл-запись, которая вызвала 21/26 failures при следующем запуске suite в следующей сессии. RUG-1 в code-review-1.md.

---

## 4. Code

**Правило 4.1 — Non-standard FK in belongs_to review**

Файл для обновления: `02-4-review-code.md`  
Условие (Триггер): Diff содержит `belongs_to :association_name` или `has_many`/`has_one` с нестандартным FK (определяемым по существующим колонкам в db/schema.rb).  
Действие (Что добавить в промпт): "Добавить в раздел 'Bulk-insert validation bypass check' аналогичный gate: **Non-standard FK check** — если diff содержит `belongs_to :X` без явного `foreign_key:` и в db/schema.rb FK-колонка называется иначе, чем `x_id`, это `provable defect`: AR будет искать колонку `x_id` вместо реальной."  
Избегать (Граница/Антипаттерн): Не проверять только semantics (правильная ли ассоциация) без проверки синтаксиса (совпадает ли Rails-конвенция с реальным именем колонки).  
Обоснование: Code review без запуска тестов не поймал бы `belongs_to :collection_task` без `foreign_key: :task_id` — это доказуемый дефект, доступный статически из db/schema.rb.

**Правило 4.2 — Orphan data in dev DB перед FK migration**

Файл для обновления: `01-4-generate-code.md`  
Условие (Триггер): Миграция добавляет `add_foreign_key :child_table, :parent_table` после переименования FK-колонки, а `parent_table` — новая таблица (только что созданная).  
Действие (Что добавить в промпт): "Перед `add_foreign_key` выполни `DELETE FROM child_table WHERE new_fk_col NOT IN (SELECT id FROM parent_table)` прямо в теле миграции. Это необходимо при наличии стейл-данных в dev DB от предыдущих тестов. Без этого миграция упадёт с PG::ForeignKeyViolation на первом же dev-запуске."  
Избегать (Граница/Антипаттерн): Не добавлять `add_foreign_key` без предварительной очистки orphan rows, когда parent_table создана в рамках того же набора миграций.  
Обоснование: Migration 3 упала с PG::ForeignKeyViolation на dev DB из-за строк sync_checkpoints с source_id=193, отсутствующим в новой таблице collection_tasks. Потребовалась дополнительная DELETE-команда.

---

## 5. Кросс-цикловая оптимизация

**Правило K-1: Non-standard FK — единый gate**

Файл для обновления: `MAKE_NEW_ISSUE.md` (Этап 3. PLAN → обязательные требования к плану)  
Условие: В diff появляется `belongs_to`, `has_many`, `has_one` с переименованным FK.  
Действие: Добавить в "Ключевые ограничения" Этапа 4 (Реализация): "Если FK-колонка не соответствует Rails-конвенции `association_name_id`, обязательно укажи `foreign_key:` в delta плана И проверь его наличие в code review. Без этого `belongs_to` создаёт тихую ошибку, которая проявляется только при сохранении."  
Обоснование: Одна и та же ошибка (отсутствие `foreign_key: :task_id`) проявилась на трёх уровнях (plan delta → implementation → test failures) и была исправлена только на уровне кода. Ранний gate в Plan устранил бы её за один шаг.

**Правило K-2: Staged validation не должна загрязнять test DB**

Файл для обновления: `MAKE_NEW_ISSUE.md` (Этап 4.4 Staged Validation)  
Условие: Staged validation stage 6 использует `rails runner` или `rails console`.  
Действие: Добавить в таблицу стадий колонку "Среда" — и явно указать для stage 6: "Используй development DB (без RAILS_ENV=test), или добавь `RAILS_ENV=test rails db:schema:load` как последний шаг staged validation перед сдачей."  
Обоснование: RUG-1 в code-score-1.json — стейл-запись в test DB вызвала 21/26 failures при возобновлении работы в новой сессии.

---

## Execution Metadata

| Поле | Значение |
|------|----------|
| system | Claude Code CLI |
| model | claude-sonnet-4-6 |
| provider | Anthropic |
| execution_date | 2026-04-13 |
| prompt_id | 05-1-analyze-cycle |

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
