# Инструкция для AI-агента (Task Definition): Правка Code

Твоя задача — исправить код так, чтобы закрыть все найденные регрессии, риски и невыполненные Acceptance Criteria по итогам semi-formal code review.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Прочитай утвержденный `spec.md` в корне папки issue.
5. Внутри `iterations/code/` найди:
   - последний `code-review-X.md`;
   - последний `code-score-X.json`.
6. Если `spec.md`, `code-review-X.md` или `code-score-X.json` отсутствуют, остановись и сообщи пользователю, что контекста недостаточно.
7. Собери текущий код:
   - прочитай текущие изменённые файлы проекта, относящиеся к issue;
   - если пользователь указал конкретные файлы, используй их как приоритетный контекст.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Прочитай шаблон `memory-bank/templates/code-template.md`, если он существует.
4. Прочитай `memory-bank/templates/fix-contract-template.json`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- scope expansion: только через явную эскалацию.
- blocker handling: локальные блокеры подлежат разрешению до завершения правки; внешние prerequisites подлежат эскалации.

## Шаг 3. Выполнение задачи (Fix)
0. Перед любыми правками переклассифицируй каждое замечание из `code-review-X.md` в одну из трёх групп:
   - `provable defect`, который исправляется кодом;
   - `scope/precondition gap`, который требует обновления active `spec.md`/`plan.md` или явной эскалации;
   - `runtime-unknown gate`, который требует исполнения/подтверждения, а не обязательно изменения кода.
   Не лечи `scope/precondition gap` скрытой кодовой правкой вне утверждённого active scope.
1. Перед изменениями создай `code-fix-contract-X.json`, используя последний scorecard.
2. Исправь логику кода строго в соответствии с контрпримерами и рисками, указанными в `code-review-X.md`.
3. Реализуй те Acceptance Criteria, которые были отмечены как `Неэквивалентно` или пропущены.
4. Не нарушай инварианты из Спецификации.
5. Обнови или добавь тесты, покрывающие исправленные участки.
6. Изменяй только те файлы, которые действительно потребовали исправлений по результатам ревью.
7. Если review уже даёт `Эквивалентно`, а открытыми остались только `runtime-unknown gate`, сначала добейся materialized runtime confirmation в рамках active scope и только потом решай, нужен ли новый код.
   Если для такого подтверждения требуется внешний prerequisite или новый файл вне scope, остановись и верни цикл к обновлению документов вместо неявного расширения реализации.

## Шаг 4. Финализация и Сохранение
1. Сохрани `code-fix-contract-X.json` в `iterations/code/`.
2. Сохрани результат в исходных файлах проекта и тестах; не создавай отдельный `code-vN.md`.
3. Если у тебя есть возможность, запусти релевантные тесты.
4. В финальном ответе сообщи:
   - какие файлы были исправлены;
   - какие тесты добавлены или обновлены;
   - какой `code-fix-contract-X.json` создан;
   - какие риски из `code-review-X.md` были закрыты;
   - что ещё осталось непроверенным, если это есть;
   - какие блокеры встретились, как они были разрешены или почему потребовали эскалации;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
