# Инструкция для AI-агента (Task Definition): Правка Spec

Твоя задача — исправить последнюю draft-версию Спецификации по замечаниям TAUS-ревьюера и закрыть каждый Fail.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Внутри `iterations/spec/` найди:
   - последнюю версию `spec-vN.md`;
   - последний файл `spec-review-X.md`.
   - последний файл `spec-score-X.json`.
5. Если одного из этих файлов нет, остановись и сообщи пользователю, чего не хватает.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Прочитай шаблон `memory-bank/templates/spec-template.md`, если он существует.
4. Прочитай `memory-bank/templates/fix-contract-template.json`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- version overwrite: отключен; существующие версии draft и review не перезаписываются.

## Шаг 3. Выполнение задачи (Fix)
Сначала создай `spec-fix-contract-X.json` по scorecard. Для каждого измерения со `score <= 3` укажи целевую секцию, target score и acceptance signal.

Исправь Спецификацию так, чтобы закрыть каждый Fail:
1. Если нет Acceptance Criteria (Testable) — допиши их так, чтобы они проверяли поведение, а не код.
2. Если есть слова-паразиты (Ambiguous-free) — замени их точными метриками или условиями.
3. Если пропущены Edge Cases или сценарии ошибок (Uniform) — добавь их явно.
4. Если нарушен Scope или отсутствуют Инварианты/Grounding — допиши эти ограничения.
5. Не переписывай секции, которые уже проходят rubric review, без нового доказательства.
6. Итогом должен быть полный обновленный текст Спецификации, а не набор правок.

## Шаг 4. Финализация и Сохранение
1. Сохрани `spec-fix-contract-X.json` в `iterations/spec/`.
2. Сохрани исправленную версию в подпапку `iterations/spec/` текущей папки issue под именем `spec-v{N+1}.md`.
3. Не перезаписывай старую `spec-vN.md`.
4. В финальном ответе сообщи:
   - какие файлы были использованы как вход;
   - какой `spec-fix-contract-X.json` создан;
   - какой `spec-v{N+1}.md` создан;
   - какие категории проблем были закрыты;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
