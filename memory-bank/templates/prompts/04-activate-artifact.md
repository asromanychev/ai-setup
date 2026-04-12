# Инструкция для AI-агента (Task Definition): Активация Артефакта

Твоя задача — перевести последний проверенный без замечаний draft-артефакт в active-состояние в корне папки issue.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Определи тип артефакта, который нужно активировать: `brief`, `spec` или `plan`.
5. В подпапке `iterations/<artifact>/` найди:
   - последнюю draft-версию соответствующего артефакта: `brief-vN.md`, `spec-vN.md` или `plan-vN.md`;
   - последний review-файл соответствующего типа: `brief-review-X.md`, `spec-review-X.md` или `plan-review-X.md`.
   - последний scorecard соответствующего типа: `brief-score-X.json`, `spec-score-X.json` или `plan-score-X.json`.
6. Если одной из входных сущностей нет, остановись и сообщи пользователю, чего именно не хватает.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- activation gate: обязателен; активация допустима только если последний review содержит однозначный вердикт без замечаний и последний scorecard не содержит blocker.
- active overwrite: разрешен только как осознанная замена текущего active-файла последней утвержденной версией того же типа.

## Шаг 3. Выполнение задачи (Activation)
1. Проверь, что последний review-файл содержит явный положительный вердикт:
   - для Brief: `0 замечаний, Brief готов к работе`;
   - для Spec: `0 замечаний, спека готова к реализации`;
   - для Plan: `0 замечаний, план готов к реализации`.
2. Если положительного вердикта нет, остановись и сообщи пользователю, что артефакт нельзя активировать.
3. Проверь, что последний scorecard:
   - не содержит измерений со `score <= 2`;
   - имеет `verdict = ready_for_activation`;
   - содержит `weighted_score`.
4. Если scorecard не проходит gate, остановись и сообщи пользователю, что артефакт нельзя активировать.
5. Скопируй содержимое последней draft-версии в корень папки issue под именем:
   - `brief.md`
   - `spec.md`
   - `plan.md`
6. Не изменяй содержимое draft-версии в `iterations/`.
7. Создай в `iterations/activation/` файл `artifact-activation-X.md`, где `X` — следующий порядковый номер активации для текущего issue.
8. В `artifact-activation-X.md` зафиксируй:
   - тип артефакта;
   - какой draft-файл был активирован;
   - какой review-файл открыл gate;
   - какой scorecard открыл gate;
   - имя обновленного active-файла в корне issue;
   - блок `Execution Metadata`;
   - блок `Runtime Telemetry`.

## Шаг 4. Финализация и Сохранение
1. Сохрани активный артефакт в корне папки issue.
2. Сохрани отчет активации в `iterations/activation/`.
3. В финальном ответе сообщи:
   - какой draft-файл был активирован;
   - какой review-файл подтвердил активацию;
   - какой scorecard подтвердил активацию;
   - какой active-файл обновлен;
   - какой `artifact-activation-X.md` создан;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
