Дальнейший план работы делается для реализации задачи 5: https://github.com/asromanychev/ai-da-collect/issues/5

Твоя задачи пройти цикл SDD для реализации фичи !! 

все инструкции указаны ниже! 


ПОДГОТОВКА БРИФА 


1. Выполни инструкцию из файла `memory-bank/templates/prompts/01-1-generate-brief.md` для задачи `5`.
2. Убедись, что в `iterations/brief/` созданы:
   - `brief-rubric.json`
   - `brief-v1.md`
3. Выполни инструкцию из файла `memory-bank/templates/prompts/02-1-review-brief.md` для задачи `5`.
4. Убедись, что в `iterations/brief/` созданы:
   - `brief-review-1.md`
   - `brief-score-1.json`
5. Если scorecard содержит blocker или есть `score <= 2`, выполни `03-1-fix-brief.md`.
6. После fix-прохода должны появиться:
   - `brief-fix-contract-1.json`
   - `brief-v2.md`
7. Повторяй цикл `review -> fix`, пока последний `brief-score-X.json` не даст `verdict = ready_for_activation`.
8. После этого выполни `04-activate-artifact.md` для `brief`.
9. Не считай этап завершённым, если в `iterations/brief/` отсутствует любой обязательный canonical artifact этого цикла.

===

ПОДГОТОВКА СПЕКИ

1. Убедись, что `brief.md` уже активирован в корне папки задачи.
2. Выполни `memory-bank/templates/prompts/01-2-generate-spec.md` для задачи `5`.
3. Убедись, что в `iterations/spec/` созданы:
   - `spec-rubric.json`
   - `spec-v1.md`
4. Дальше крути цикл:
   - `02-2-review-spec.md`
   - `03-2-fix-spec.md`
5. На каждом review должны появляться:
   - `spec-review-X.md`
   - `spec-score-X.json`
6. На каждом fix должны появляться:
   - `spec-fix-contract-X.json`
   - `spec-v{N+1}.md`
7. После `ready_for_activation` выполни `04-activate-artifact.md` для `spec`.
8. Не сохраняй authoritative spec-review или spec-score вне `iterations/spec/`: stray-файлы не открывают gate.

=====

ПОДГОТОВКА ПЛАНА

1. Убедись, что `spec.md` уже активирован.
2. Выполни `memory-bank/templates/prompts/01-3-generate-plan.md` для задачи `5`.
3. Дальше крути цикл:
   - `02-3-review-plan.md`
   - `03-3-fix-plan.md`
4. Проверяй, что в `iterations/plan/` появляются:
   - `plan-rubric.json`
   - `plan-vN.md`
   - `plan-review-X.md`
   - `plan-score-X.json`
   - `plan-fix-contract-X.json`
5. После `ready_for_activation` выполни `04-activate-artifact.md` для `plan`.
6. Если финальный runtime gate требует regression по существующим suite, проверь, что план содержит и `focused verification`, и отдельный `regression gate`.

====

РЕАЛИЗАЦИЯ

1. Убедись, что активны `spec.md` и `plan.md`.
2. Выполни `memory-bank/templates/prompts/01-4-generate-code.md` для нужной задачи.
3. Выполни `02-4-review-code.md`.
4. Если есть blocker, `scope breach` или невыполненные измерения, выполни `03-4-fix-code.md`.
5. Проверяй, что в `iterations/code/` появляются:
   - `code-rubric.json`
   - `code-review-X.md`
   - `code-score-X.json`
   - `code-fix-contract-X.json`
6. Не считай code-review закрытым по формуле `0 замечаний`, если остался `runtime-unknown gate` или scorecard не имеет `verdict = ready_for_activation`.

======

АНАЛИЗ ПРОМПТОВ
Тепрь выполни `05-1-analyze-cycle.md`.

Результат должен лежать в `iterations/analysis/cycle-analysis-X.md` и учитывать:
- markdown review;
- scorecards;
- fix-contracts;
- active-документы;
- поздние code-review и изменения кода.
- только канонические артефакты из `iterations/<stage>/`; stray-файлы вне stage-папок не считать authoritative без явной оговорки.

======

ПРИМЕНЕНИЕ УЛУЧШЕНИЙ К ШАБЛОНАМ
В рамках задачи 5
После того как `cycle-analysis-X.md` создан, выполни `memory-bank/templates/prompts/06-1-apply-cycle-improvements.md`.

Этот шаг должен:
- прочитать последний `iterations/analysis/cycle-analysis-X.md`;
- внести релевантные правки в `memory-bank/templates/`, `memory-bank/issues/README.md`, `memory-bank/issues/EXMAPLES.md` и связанные workflow-файлы;
- не дублировать уже встроенные правила;
- материализовать postmortem в реальные улучшения процесса.
- зафиксировать, какие рекомендации уже покрыты текущими шаблонами и поэтому не требуют новых правок.

Результат должен лежать в `iterations/analysis/template-improvements-X.md` и фиксировать:
- какой `cycle-analysis-X.md` был входом;
- какие шаблоны и документы были изменены;
- какие рекомендации были применены;
- какие рекомендации были пропущены как уже покрытые или дублирующие.


=====

Домашка 
по подобию memory-bank/issues/0001-plugin-contract/hw-reports и memory-bank/issues/0003-sync-orchestration/hw-reports и memory-bank/issues/0002-source-checkpoint/hw-reports сделай отчет для memory-bank/issues/0004-s3-blob-storage на основе промежуточных артефакторв цилка разработки 

=====

## Пример цикла Issue 5: RawIngestItem (2026-04-07)

Характерный цикл для AR-модели с идемпотентной вставкой:

### Brief — 2 итерации (v1 → v2)

Blocker в v1: Критерий успеха содержал нераскрытую альтернативу «(upsert или skip-with-log)».
Fix: зафиксировать одну семантику (skip-with-log) в Доменном контексте до написания AC.
Lesson: **Semantics-first gate** — перед любым AC с поведением при конфликте выбрать одну семантику.

### Spec — 1 итерация (v1 → активация)

Прошла с первого прохода благодаря явному Preconditions section, полной FR/input-branch матрице, и explicit adversarial AC (aliasing, duplicate INSERT).

### Plan — 1 итерация (v1 → активация)

Two-tier gate (focused + regression) спроектирован с первого прохода. test DB prerequisite явно материализован командой `rails db:migrate RAILS_ENV=test`.

### Code — 1 итерация + runtime fix

Первый прогон тестов: 2 failures в AC4 (blank external_id).
Причина: AR `insert` обходит `validates :external_id, presence: true`.
Fix: добавить explicit validation guard до `insert` + `human_attribute_name` override.
Lesson: **Bulk-insert validation bypass** — `insert` не вызывает AR validations; нужен явный guard.

### Итог

- 10 новых examples, 0 failures (focused)
- 45 existing examples, 0 failures (regression)
- 3 файла: migration, model, spec

=====

## ЗАВЕРШЕНИЕ ЦИКЛА: коммиты, пуш, закрытие issue

После завершения реализации делай **два отдельных коммита** и закрывай issue.

### Коммит 1 — документация

Стейджи:
- `memory-bank/issues/NNNN-slug/` (все SDD-артефакты)
- `memory-bank/templates/prompts/` (если были улучшения шаблонов)
- `memory-bank/issues/EXMAPLES.md`, `memory-bank/issues/README.md` (если обновлялись)

Формат сообщения:
```
Add SDD artifacts for issue #N: <short description>

Brief (vX→vY, <ключевой fix>), Spec (vX), Plan (vX, <ключевое решение>),
code-review, cycle-analysis, template-improvements, hw-report.

<Если были template improvements — перечислить кратко.>

Ref #N
```

### Коммит 2 — код

Стейджи:
- `app/models/`, `db/migrate/`, `db/schema.rb`, `spec/` — только файлы из allowlist плана

Формат сообщения:
```
Add <FeatureName>: <одна строка о сути>

- Migration: <что создано>
- Model / Service: <контракт и ключевая семантика>
- Spec: <N examples, что покрыто>

Closes #N
```

`Closes #N` в теле коммита закрывает GitHub issue автоматически при пуше в main.

### Пуш

```bash
git push origin main
```

### Закрытие issue

Если `Closes #N` не закрыл issue автоматически:
```bash
gh issue close N --repo owner/repo --comment "..."
```

Если issue уже закрыт — добавить только комментарий:
```bash
gh issue comment N --repo owner/repo --body "..."
```