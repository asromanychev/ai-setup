# Как реализовывать задачи через AI-агента

## Одна команда запускает всё

```
Выполни задачу N по memory-bank/issues/MAKE_NEW_ISSUE.md
```

Агент сам: получит issue из GitHub → пройдёт полный цикл → закроет issue.

---

## Полный цикл (что происходит внутри)

```
GitHub Issue
    ↓
[1] Brief          — формулируем проблему (без кода)
    ↓
[2] Spec           — технический контракт: FR, AC, инварианты
    ↓
[2.5] BDD-сценарии — acceptance-scenarios.md: чеклист ручной проверки
    ↓
[3] Plan           — атомарные шаги + VibeContract (pre/post/invariants)
    ↓
[4] Code           — реализация строго по allowlist из плана
    ↓
[4.4] Staged Validation — 6 стадий: файлы → синтаксис → boot → схема → rspec → данные
    ↓
[4.5] run-instructions.md — инструкция ручной проверки руками
    ↓
[5] Cycle analysis  — postmortem, уроки
[6] Template improvements — правки в шаблоны
[7] HW-отчёт
    ↓
[8] git commit (доку) + git commit (код) + push + close issue
```

Детали каждого шага: [`memory-bank/issues/MAKE_NEW_ISSUE.md`](issues/MAKE_NEW_ISSUE.md)

---

## Lifecycle Gates

Каждый переход — набор обязательных предикатов. Агент не переходит на следующий этап, пока все не выполнены.

### Issue → Brief Ready

- [ ] `brief.md` создан по `templates/brief-template.md`
- [ ] `brief.md` содержит проблему, стейкхолдера, критерий успеха и Out of Scope
- [ ] Rubric scorecard прошла: ни одно измерение `score <= 2`
- [ ] `brief.md` → `status: active`

### Brief Ready → Spec Ready

- [ ] `spec.md` создан по `templates/spec-template.md`
- [ ] `spec.md` содержит ≥ 1 `REQ-*`, ≥ 1 `NS-*`, ≥ 1 `SC-*`, ≥ 1 `CHK-*`, ≥ 1 `EVID-*`
- [ ] Rubric scorecard прошла: ни одно измерение `score <= 2`
- [ ] Grounding выполнен: реальные пути файлов и паттерны зафиксированы в spec
- [ ] `spec.md` → `status: active`, `delivery_status: planned`

### Spec Ready → Plan Ready

- [ ] `plan.md` создан по `templates/plan-template.md`
- [ ] `plan.md` содержит ≥ 1 `PRE-*`, ≥ 1 `STEP-*`, ≥ 1 `CHK-*`, ≥ 1 `EVID-*`
- [ ] Каждый `STEP-*` ссылается на `REQ-*` или `SC-*` из spec
- [ ] Rubric scorecard прошла: ни одно измерение `score <= 2`
- [ ] `plan.md` → `status: active`

### Plan Ready → Execution (Code)

- [ ] `spec.md` → `delivery_status: in_progress`
- [ ] Все `PRE-*` из `plan.md` выполнены или явно помечены как acceptable risk
- [ ] Test strategy в `plan.md` задана: какие spec-файлы будут добавлены/обновлены

### Execution → Done

- [ ] Все `CHK-*` из `spec.md` имеют результат pass в evidence
- [ ] Все `EVID-*` заполнены конкретными carriers (CI run, путь к файлу, вывод команды)
- [ ] `bin/ci` зелёный локально
- [ ] Simplify review выполнен
- [ ] `spec.md` → `delivery_status: done`
- [ ] `plan.md` → `status: archived`

---

## Что получаешь на выходе

После завершения цикла в `memory-bank/issues/NNNN-slug/` лежат:

| Файл | Что это |
|---|---|
| `brief.md` | Проблема и критерии успеха |
| `spec.md` | Технический контракт |
| `plan.md` | Пошаговый план с VibeContract |
| `acceptance-scenarios.md` | BDD-сценарии для ручной проверки |
| `run-instructions.md` | **Инструкция: как проверить фичу руками** |
| `hw-reports/report.md` | Отчёт об итерациях и уроках |
| `iterations/` | Все черновики, scorecards, fix-contracts |

---

## Как проверить фичу руками после реализации

1. Открой `memory-bank/issues/NNNN-slug/run-instructions.md`
2. Следуй разделу «Подготовка» — запусти сервисы и миграции
3. Выполни команды из каждого сценария в `acceptance-scenarios.md`
4. Сверь результат с полем «Ожидаемый результат»

Если всё сходится — фича работает.

---

## Staged Validation (6 стадий)

Агент прогоняет их автоматически. При ручной проверке:

| # | Что | Команда |
|---|---|---|
| 1 | Файлы созданы | `ls app/models/ spec/models/` |
| 2 | Синтаксис OK | `bundle exec ruby -c <file>` |
| 3 | Приложение стартует | `bundle exec rails runner "puts 'ok'"` |
| 4 | Схема актуальна | `bundle exec rails db:migrate:status` |
| 5 | Тесты зелёные | `bundle exec rspec spec/models/<feature>_spec.rb` |
| 6 | Данные сохраняются | команды из `run-instructions.md` |

Провал на любой стадии → стоп, исправить, повторить с этой же стадии.

---

## Системные промпты `.prompts/` — когда и как использовать

Файлы в `.prompts/` — это **праймеры для агента**: загружают роль, правила и порядок чтения Memory Bank до начала работы. Они не заменяют `MAKE_NEW_ISSUE.md` и шаблоны из `memory-bank/templates/prompts/` — работают как отдельный слой поверх них.

| Ситуация | Используй |
|---|---|
| Новая сессия, непонятно где остановились | `.prompts/resume.md` → агент читает `activeContext.md` и говорит что дальше |
| Пришла идея / баг — нужно решить, делать ли Issue | `.prompts/triage.md` → triage-отчёт с типом, скоупом и приоритетом |
| Запускаешь отдельный этап Spec без полного цикла | `.prompts/spec.md` как системный контекст + `01-2-generate-spec.md` |
| Запускаешь отдельный этап Plan или Code | `.prompts/implement.md` как системный контекст + `01-3-generate-plan.md` / `01-4-generate-code.md` |
| Запускаешь ревью любого артефакта отдельно | `.prompts/review.md` как системный контекст + `02-X-review-*.md` |
| Запускаешь полный цикл через `MAKE_NEW_ISSUE.md` | `.prompts/*` обязательны по этапам; сам `MAKE_NEW_ISSUE.md` не считается самодостаточным |

**Порядок загрузки при использовании промпта:**
1. Загрузи `.prompts/<роль>.md` как системный промпт агента.
2. Затем дай задачу: «Выполни Spec для задачи 8 по `memory-bank/templates/prompts/01-2-generate-spec.md`».
3. Агент работает с ролью из праймера + детальными шагами из шаблона.

---

## Если нужно только отдельный этап

```
Выполни Brief для задачи N по memory-bank/templates/prompts/01-1-generate-brief.md
Выполни Spec для задачи N по memory-bank/templates/prompts/01-2-generate-spec.md
Выполни Plan для задачи N по memory-bank/templates/prompts/01-3-generate-plan.md
```

Но полный цикл через `MAKE_NEW_ISSUE.md` всегда предпочтительнее — он не пропускает gates.

---

## Файловая структура memory-bank

```
memory-bank/
├── index.md                     ← главный индекс для агентов (читать первым)
├── activeContext.md             ← фокус сессии (обновлять по итогам работы)
├── progress.md                  ← решения и расхождения docs↔код
├── WORKFLOW.md                  ← этот файл (цикл + lifecycle gates)
├── ROADMAP.md                   ← фазы и граф зависимостей issues
├── dna/                         ← конституция документации (SSoT, frontmatter, lifecycle)
├── adr/                         ← Architecture Decision Records
├── use-cases/                   ← канонические продуктовые сценарии
├── prd/
│   └── PRD.md                   ← Vision, MVP In/Out of Scope
├── project/
│   ├── overview.md              ← продукт, стек, архитектура
│   └── data-model.md            ← логическая модель данных
├── engineering/
│   ├── coding-style.md          ← стиль и границы ответственности
│   ├── testing-policy.md        ← RSpec, sufficient coverage, simplify review
│   ├── git-workflow.md          ← conventional commits, ветки, PR
│   └── autonomy-boundaries.md  ← автопилот / супервизия / эскалация
├── issues/
│   ├── MAKE_NEW_ISSUE.md        ← полный промпт для агента
│   ├── README.md                ← правила именования и хранения артефактов
│   └── NNNN-slug/
│       ├── brief.md             ← status: active | draft
│       ├── spec.md              ← status + delivery_status; REQ-*, NS-*, SC-*, CHK-*, EVID-*
│       ├── plan.md              ← status; PRE-*, STEP-*, CHK-*, EVID-*
│       ├── acceptance-scenarios.md
│       ├── run-instructions.md
│       ├── hw-reports/
│       └── iterations/
└── templates/
    ├── brief-template.md
    ├── spec-template.md         ← включает REQ-*, NS-*, SC-*, CHK-*, EVID-*
    ├── plan-template.md         ← включает PRE-*, STEP-*, CHK-*, EVID-*
    └── prompts/                 ← шаблоны для каждого этапа цикла
```
