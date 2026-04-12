# Инструкция для AI-агента (Task Definition): Ревью Spec

Ты — строгий ревьюер спецификаций для AI-агентов. Твоя задача — проверить последнюю draft-версию Спецификации на соответствие TAUS и полноту ограничений.

## Шаг 1. Сбор контекста (Grounding on Memory Bank)
1. Извлеки номер Issue из запроса пользователя.
2. Сформируй 4-значный префикс.
3. Найди папку issue в `memory-bank/issues/`.
4. Внутри `iterations/spec/` найди последнюю версию `spec-vN.md` и `spec-rubric.json`.
5. Если ни одного `spec-vN.md` нет, остановись и сообщи пользователю, что ревьюировать нечего.
6. Если `spec-rubric.json` отсутствует, остановись и сообщи пользователю, что для этапа не создана рубрика.

## Шаг 2. Изучение правил
1. Прочитай `.claude/CLAUDE.md`.
2. Прочитай `.codex/CODEX.md`, если файл существует.
3. Прочитай шаблон `memory-bank/templates/spec-template.md`, если он существует.
4. Прочитай `memory-bank/templates/scorecard-template.json`, если файл существует.

## Факторы выполнения
- execution metadata: фиксируй `system`, `model`, `provider`, `execution_date`, `prompt_id`; если среда не раскрывает значение, записывай `unknown`.
- telemetry capture: фиксируй `started_at`, `finished_at`, `elapsed_seconds`; если runtime отдает usage, добавляй `input_tokens`, `output_tokens`, `total_tokens`; если billing или лимиты недоступны, записывай `not available in current runtime`.
- scope-defect: блокирующий дефект.
- precondition hygiene: обязательна.

## Шаг 3. Выполнение задачи (TAUS Review)
Оценивай измерения из `spec-rubric.json` изолированно. Хороший Scope не компенсирует провал в `precondition_hygiene`, а хороший набор AC не компенсирует плохой grounding.

Для каждого критерия вынеси вердикт Pass/Fail и обоснуй его:
1. T (Testable):
   есть ли конкретные Acceptance Criteria, по которым можно написать автотесты; описывают ли они поведение системы, а не код.
2. A (Ambiguous-free):
   есть ли двусмысленные слова вроде «быстро», «удобно», «корректно обработать», «при необходимости», «и т.д.».
3. U (Uniform):
   описаны ли все состояния (success, loading, error, empty), edge cases и сценарии ошибок.
4. S (Scoped):
   это ровно одна фича, текст меньше 1500 слов, затрагивает не более 3 модулей.
5. Scope явно ограничен:
   указано ли, что входит и что не входит.
6. Инварианты перечислены:
   указано ли, какие существующие свойства системы нельзя сломать.
7. Grounding и реализуемость:
   привязана ли спека к реальным файлам проекта и архитектуре.

Дополнительно проверь invariant-to-AC completeness:
- у каждого инварианта должен быть хотя бы один falsifiable scenario в `Сценариях ошибок и состояний` или в `Acceptance Criteria`;
- если инвариант сформулирован текстом, но из него нельзя вывести тест, который может упасть при нарушении, это Fail;
- если state из TAUS неприменим, это должно быть явно зафиксировано, а не подразумеваться.
- если в спецификации есть доменно-специфичные поля или режимы выполнения, проверь boundary cases для них отдельно: `missing key`, `invalid state value`, `{}` vs `nil`, constructor-time validation, повторный вызов с теми же аргументами;
- не ставь Pass по `U (Uniform)` только потому, что перечислены общие success/error сценарии: неприменимые состояния и adversarial cases тоже должны быть явно материализованы.

Дополнительно проверь два scope-gate:
1. Module-budget:
   - посчитай модульные зоны, которые затрагивает спецификация по `Scope`, `Grounding`, FR и AC;
   - если документ затрагивает более 3 модульных зон или смешивает доменную фичу с инфраструктурной обвязкой, это блокирующий `scope-defect`.
2. Precondition hygiene:
   - любой внешний prerequisite, без которого спека неисполняема, должен быть оформлен как явный `Precondition` с понятным условием остановки;
   - если внешний prerequisite описан как обычная часть текущей реализации, это Fail, даже если сам prerequisite выглядит разумным.
3. Boundary-to-AC completeness:
   - если FR вводят доменный режим, структурный контракт или гарантию уровня `determinism`, `normalization`, `deep copy`, `isolation`, `idempotence`, проверь, что для этого есть отдельный falsifiable AC или error scenario;
   - если boundary case описан только в prose FR, но его нельзя отследить через `Сценарии ошибок и состояний` или `Acceptance Criteria`, это Fail.
4. FR/input-branch matrix:
   - если FR описывает union-type, duck-typed контракт, optional branch или adversarial case, построй матрицу `FR/input branch -> success AC -> invalid-branch AC`;
   - считай это Fail, если хотя бы одна типовая ветка осталась только в prose, покрыта только happy-path/nil-case или описана в таблице состояний без отдельного falsifiable AC.

Для каждого вердикта Fail выведи:
- цитату из спеки;
- объяснение проблемы для AI-агента;
- вариант исправления.

Если проблема связана со scope, явно помечай её как `scope-defect` или `precondition-hygiene defect`, а не как stylistic issue.

Если по любому измерению `score <= 2`, начни markdown review с блока:
`🚨 КРИТИЧЕСКИЕ РИСКИ`

После анализа рассчитай `weighted_score` как взвешенную сумму по рубрике.

Если все критерии Pass и в scorecard нет blocker, выведи:
`0 замечаний, спека готова к реализации`.

## Шаг 4. Финализация и Сохранение
1. Сохрани markdown review в `iterations/spec/spec-review-X.md`.
2. Сохрани scorecard рядом в `iterations/spec/spec-score-X.json`.
3. Не перезаписывай старые review-файлы и scorecards.
4. В финальном ответе сообщи:
   - какой `spec-vN.md` был проверен;
   - какой `spec-review-X.md` создан;
   - какой `spec-score-X.json` создан;
   - есть ли Fail-критерии;
   - блок `Execution Metadata` со значениями `system`, `model`, `provider`, `execution_date`, `prompt_id`;
   - блок `Runtime Telemetry` со значениями `started_at`, `finished_at`, `elapsed_seconds`, `input_tokens`, `output_tokens`, `total_tokens`, `estimated_cost`, `limit_context`, где недоступные поля помечены как `unknown` или `not available in current runtime`.
