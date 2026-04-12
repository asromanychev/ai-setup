# Инструкция для AI-агента (Task Definition): Применение Улучшений После Cycle Analysis

Твоя задача — взять последний `cycle-analysis-X.md` для конкретного issue и применить из него улучшения к `memory-bank/templates`, `memory-bank/issues/README.md`, `memory-bank/issues/EXMAPLES.md` и другим workflow-файлам, которые реально нуждаются в правке.

Этот шаг выполняется после `05-1-analyze-cycle.md`. Его цель — не оставить postmortem в виде пассивного отчёта, а материализовать улучшения процесса в шаблонах.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`, которая начинается с этого префикса.
4. Внутри `iterations/analysis/` найди последний файл `cycle-analysis-X.md`.
5. Если `cycle-analysis-X.md` отсутствует, остановись и сообщи пользователю, что сначала нужно выполнить `05-1-analyze-cycle.md`.
6. Прочитай:
   - последний `cycle-analysis-X.md`;
   - все prompt-файлы из `memory-bank/templates/prompts/`, которые упомянуты в рекомендациях;
   - `memory-bank/issues/README.md`;
   - `memory-bank/issues/EXMAPLES.md`;
   - связанные шаблоны из `memory-bank/templates/`, если рекомендации их затрагивают.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Считай `cycle-analysis-X.md` источником требований, но не применяй рекомендации механически: сначала проверь, что они не дублируют уже внесённые правила.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- duplicate-rule suppression: обязательна; не копируй уже существующие gates под другой формулировкой.
- minimum-effective-change: обязателен; меняй самый ранний и самый узкий файл, который предотвращает дефект.
- traceability: обязательна; каждая правка в шаблонах должна ссылаться на конкретную рекомендацию из `cycle-analysis-X.md`.

## Шаг 3. Выполнение задачи (Apply Improvements)
1. Построй таблицу применения:
   - рекомендация из `cycle-analysis-X.md`;
   - целевой файл;
   - тип изменения (`add gate`, `tighten review`, `update storage convention`, `clarify activation`, `document workflow`);
   - статус (`apply`, `skip as duplicate`, `skip as superseded`).
2. Применяй только такие рекомендации:
   - они устраняют повторяющийся дефект;
   - они не дублируют уже встроенное правило;
   - для них есть конкретный целевой файл.
3. Если рекомендация уже покрыта действующим шаблоном:
   - не вноси повторную правку;
   - зафиксируй это как `skip as duplicate` в отчёте.
4. Если несколько рекомендаций лечатся на более раннем этапе:
   - правь самый ранний релевантный prompt;
   - не размазывай одинаковую логику по нескольким шагам без необходимости.
5. Если рекомендация требует изменения общего workflow:
   - обнови `memory-bank/issues/README.md` и/или `memory-bank/issues/EXMAPLES.md`;
   - при необходимости обнови связанные `*-template.md` или JSON templates.
6. После правок подготовь краткий отчёт применения, где для каждого изменения указано:
   - что изменено;
   - какой дефект цикла это закрывает;
   - какая рекомендация из `cycle-analysis-X.md` материализована;
   - что было сознательно не применено и почему.

## Шаг 4. Финализация и Сохранение
1. Сохрани изменения прямо в файлах `memory-bank/templates/` и связанной документации.
2. Создай в `iterations/analysis/` файл `template-improvements-X.md`, где `X` — следующий номер такого отчёта для текущего issue.
3. В `template-improvements-X.md` зафиксируй:
   - какой `cycle-analysis-X.md` был входом;
   - какие файлы были изменены;
   - какие рекомендации были применены;
   - какие рекомендации были пропущены как дубликаты или уже покрытые;
   - блок `Execution Metadata`;
   - блок `Runtime Telemetry`.
4. В финальном ответе сообщи:
   - какой `cycle-analysis-X.md` был использован;
   - какие файлы в `memory-bank/templates` и документации были изменены;
   - какой `template-improvements-X.md` создан;
   - были ли рекомендации, которые оказались уже покрыты;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
