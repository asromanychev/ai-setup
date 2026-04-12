# Инструкция для AI-агента (Task Definition): Правка Brief

Твоя задача — исправить последнюю draft-версию Brief по замечаниям ревьюера, сохранив структуру и те части текста, к которым замечаний не было.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Внутри `iterations/brief/` найди:
   - последнюю версию `brief-vN.md`;
   - последний файл `brief-review-X.md`.
   - последний файл `brief-score-X.json`.
5. Если нет draft Brief, review-файла или scorecard, остановись и сообщи пользователю, чего именно не хватает.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Прочитай шаблон `memory-bank/templates/brief-template.md`, если он существует.
4. Прочитай `memory-bank/templates/fix-contract-template.json`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- version overwrite: отключен; существующие версии draft и review не перезаписываются.

## Шаг 3. Выполнение задачи (Fix)
1. Внимательно проанализируй каждое замечание ревьюера и каждый blocker/низкий балл из `brief-score-X.json`.
2. Перед правкой создай `brief-fix-contract-X.json`, где для каждого измерения со `score <= 3` укажи:
   - `current_score`
   - `target_score`
   - `change_scope`
   - `do_not_touch`
   - `acceptance_signal`
3. Исправь документ так, чтобы закрыть все замечания:
   - убери технические решения, если нарушено разделение Problem/Solution;
   - сделай проблему измеримой;
   - удали двусмысленные слова.
3.1. Term-closure gate:
   - если review указывает на недоопределённый термин в `Критерии успеха` или на конфликт между `Критерий успеха` и `Открытые вопросы`, исправление обязано закрыть сам термин, а не только перефразировать его;
   - каждый спорный термин либо переписывается в наблюдаемое поведение, либо выносится в открытый вопрос, который блокирует готовность документа;
   - синонимическая замена без роста проверяемости не считается исправлением.
4. Исправляй только измерения, которые scorecard пометил как проблемные. Не переписывай уже проходящие секции без новой причины.
5. Сохрани структуру документа и не выкидывай куски, которые уже были корректными.
6. Итогом должен быть полный обновленный текст Brief, а не патч или список изменений.

## Шаг 4. Финализация и Сохранение
1. Создай `brief-fix-contract-X.json` в `iterations/brief/`.
2. Создай новую версию Brief в подпапке `iterations/brief/` текущей папки issue под именем `brief-v{N+1}.md`.
3. Не перезаписывай старую версию `brief-vN.md`.
4. В финальном ответе сообщи:
   - какие файлы были использованы как вход (`brief-vN.md`, `brief-review-X.md`);
   - какой `brief-fix-contract-X.json` создан;
   - какой новый `brief-v{N+1}.md` создан;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
