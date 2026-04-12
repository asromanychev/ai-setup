# Инструкция для AI-агента (Task Definition): Правка Plan

Твоя задача — исправить последнюю draft-версию Плана реализации по замечаниям ревьюера, чтобы разрешить конфликты зависимостей и выполнить требования Grounding.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Внутри `iterations/plan/` найди:
   - последнюю версию `plan-vN.md`;
   - последний файл `plan-review-X.md`.
   - последний файл `plan-score-X.json`.
5. Если одного из файлов нет, остановись и сообщи пользователю, чего не хватает.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Прочитай шаблон `memory-bank/templates/plan-template.md`, если он существует.
4. Прочитай `memory-bank/templates/fix-contract-template.json`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- version overwrite: отключен; существующие версии draft и review не перезаписываются.

## Шаг 3. Выполнение задачи (Fix)
1. Сначала создай `plan-fix-contract-X.json` по последнему scorecard.
2. Измени порядок шагов, если ревьюер указал на нарушение логики зависимостей.
3. Детализируй шаги, если ревьюер указал на недостаток атомарности.
4. Добавь пропущенные шаги, например написание тестов, обновление конфигурации или роутов, если этого требует ревью.
5. Исправляй прежде всего измерения со `score <= 3`; не переписывай уже проходящие шаги без новой причины.
6. Итогом должен быть полный обновленный План целиком в виде нумерованного списка, а не diff.

## Шаг 4. Финализация и Сохранение
1. Сохрани `plan-fix-contract-X.json` в `iterations/plan/`.
2. Сохрани исправленную версию в подпапку `iterations/plan/` текущей папки issue под именем `plan-v{N+1}.md`.
3. Не перезаписывай старую `plan-vN.md`.
4. В финальном ответе сообщи:
   - какие файлы использовались как вход;
   - какой `plan-fix-contract-X.json` создан;
   - какой `plan-v{N+1}.md` создан;
   - были ли перестроены зависимости шагов;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
