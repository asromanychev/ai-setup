# Agent Primering Guide

Проектный guide по праймерингу ИИ-агентов для `ai-da-collect`.  
Цель: чтобы разные модели и разные рантаймы работали по одной архитектуре контекста, а не по случайному длинному промпту.

## 1. Базовый принцип

В этом проекте праймеринг строится не вокруг модели, а вокруг роли и этапа workflow.

- Один этап workflow = один основной primer.
- Один агент = одна зона ответственности.
- Planning, implementation, review и manual verification разделяются.
- Если задача длинная, память должна быть role-specific, а не общим длинным чат-логом.

Практическое следствие: лучше отдельные узкие праймеры, чем один «универсальный мегапромпт».

## 2. Каноническая карта праймеров

| Задача | Primer |
|---|---|
| Resume / orient | `.prompts/resume.md` |
| Triage / brief problem framing | `.prompts/triage.md` |
| Spec writing | `.prompts/spec.md` |
| Plan + code implementation | `.prompts/implement.md` |
| Review / quality gate | `.prompts/review.md` |
| Manual verification / run-instructions / app startup | `.prompts/manual-check.md` |
| External comparison | `.prompts/compare.md` |

## 3. Рекомендуемая архитектура агентов

### Graph-based flow — основной паттерн проекта

Для обычной feature-задачи использовать строгую цепочку:

1. `Resume`
2. `Brief`
3. `Spec`
4. `Plan`
5. `Implement`
6. `Review`
7. `Manual Check`
8. `Commit / Push`

Это основной режим, потому что у проекта уже есть SDD-артефакты и deterministic lifecycle.

### Role-based flow — только для сложных проверок

Использовать отдельные роли параллельно только если нужна независимая экспертиза:

- один агент читает diff;
- второй ищет runtime blockers;
- третий сверяет scope с PRD.

Координатор обязан искать конфликты между выводами, а не просто суммировать их.

### Что не делать

- Не просить один и тот же агент одновременно писать код, ревьюить свой код и писать ручную проверку без смены праймера.
- Не запускать много одинаково праймированных «экспертов»: это даёт groupthink, а не качество.

## 4. Слоёный контекст

Контекст агенту выдаётся в таком порядке:

1. Цель текущего этапа.
2. Канонический primer этапа.
3. Общие project docs:
   - `memory-bank/index.md`
   - `memory-bank/issues/RUNBOOK.md`
4. Active issue docs:
   - `brief.md`
   - `spec.md`
   - `plan.md`
   - `acceptance-scenarios.md`
   - `run-instructions.md`
5. Только потом локальные детали: diff, error log, command output.

Если контекст нужно сокращать, сначала отбрасывай длинные логи, а не active docs и не primer.

## 5. Как праймировать разные модели

### Claude / Codex / GPT

Для всех моделей использовать один и тот же набор артефактов и один и тот же stage-specific primer.  
Различия между моделями не должны компенсироваться разными правилами проекта.

Допустимы только такие отличия:

- формат tool-use;
- ограничения рантайма;
- длина промежуточных отчётов.

Недопустимы такие отличия:

- одна модель работает без `memory-bank/index.md`, другая с ним;
- одна модель пишет `run-instructions` из головы, другая читает acceptance scenarios;
- одна модель сразу кодит, другая сначала делает plan.

## 6. Manual-check agent — отдельная роль

Ручная проверка и генерация `run-instructions.md` должны идти через отдельный primer `.prompts/manual-check.md`.

Почему:

- implementer думает в allowlist и diff;
- reviewer думает в defects и gates;
- manual-check agent думает в reproducible runtime steps.

У него другой output contract:

- как поднять окружение;
- какие ENV использовать;
- как проверить boot;
- какие exact команды выполнять;
- как подтвердить постусловия;
- как сбросить состояние;
- как пройти git verification.

## 7. Git verification как обязательная часть праймеринга

Агент, который завершает реализацию или пишет `run-instructions.md`, обязан включать git-check:

1. `git status --short`
2. `git diff --stat`
3. `git diff --name-only`
4. Проверка, что diff укладывается в scope issue
5. Проверка, что verification results зафиксированы

Если этого блока нет, инструкция считается неполной.

## 8. Память агента

Для длинных задач память должна быть role-specific:

- `Resume`: active issue, current workflow step, git status.
- `Implement`: allowlist, active plan step, runtime gates.
- `Review`: defects, blocked invariants, missing coverage.
- `Manual Check`: env, startup steps, verification commands, reset steps.

Не смешивать эти поля в одну общую «универсальную память».

## 9. Обязательные проектные запреты

- Не пропускать `memory-bank/index.md` в новой сессии.
- Не использовать draft-артефакты вместо active, если этап требует active.
- Не писать runbook внутри каждой issue заново: общий baseline живёт в `memory-bank/issues/RUNBOOK.md`.
- Не писать manual verification без `acceptance-scenarios.md`.
- Не считать задачу завершённой без focused verification и явного статуса regression.

## 10. Практический шаблон для новых агентов

Если в проекте появляется новый ИИ-агент или новый рантайм, его надо подключать так:

1. Определить его роль:
   - resume;
   - triage;
   - spec;
   - implement;
   - review;
   - manual-check;
   - compare.
2. Привязать его к существующему primer из `.prompts/`.
3. Привязать к общему runtime baseline:
   - `memory-bank/issues/RUNBOOK.md`
   - `memory-bank/issues/AGENT_PRIMERING.md`
4. Проверить, что он умеет писать:
   - staged verification;
   - manual steps;
   - git verification.
5. Только после этого использовать его в workflow.
