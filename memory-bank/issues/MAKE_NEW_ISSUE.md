# MAKE_NEW_ISSUE — Полный SDD-цикл реализации фичи

## Как использовать

Передай этот документ агенту вместе с номером задачи:


> «Выполни задачу 6 по `memory-bank/issues/MAKE_NEW_ISSUE.md`»

Агент извлечёт номер issue, получит текст из GitHub, пройдёт полный цикл и закроет задачу.

---

## Шаг 0. Инициализация

1. Извлеки номер issue из запроса пользователя (форматы: `задачу 6`, `issue 6`, `#6`).
2. Получи текст issue из GitHub:
   ```bash
   gh issue view N --repo asromanychev/ai-da-collect
   ```
3. Если issue не найден или репозиторий недоступен — остановись и сообщи пользователю.
4. Сформируй 4-значный префикс: `6 → 0006`.
5. Придумай короткий slug (2–3 слова на английском) по сути задачи.
6. Создай директорию `memory-bank/issues/0006-slug/` и все подпапки:
   ```bash
   mkdir -p memory-bank/issues/0006-slug/iterations/{brief,spec,plan,code,activation,analysis}
   mkdir -p memory-bank/issues/0006-slug/hw-reports
   ```
   Артефакты видимого инкремента, которые появятся в процессе цикла:
   - `acceptance-scenarios.md` — BDD-чеклист ручной проверки (после Spec)
   - `run-instructions.md` — пошаговая инструкция запуска и проверки руками (после Code)
7. Все шаблоны для каждого шага находятся в `memory-bank/templates/prompts/`.

---

## Этап 1. BRIEF

**Цель:** зафиксировать Problem Space — что сломано, для кого, наблюдаемый симптом, критерий успеха. Никакого кода, схем или решений.

### 1.1 Генерация

Выполни инструкцию из `memory-bank/templates/prompts/01-1-generate-brief.md`.

**Обязательные артефакты после этого шага:**

| Файл | Путь |
|---|---|
| `brief-rubric.json` | `iterations/brief/` |
| `brief-v1.md` | `iterations/brief/` |

### 1.2 Review

Выполни инструкцию из `memory-bank/templates/prompts/02-1-review-brief.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `brief-review-1.md` | `iterations/brief/` |
| `brief-score-1.json` | `iterations/brief/` |

### 1.3 Fix-цикл

Если `brief-score-X.json` содержит `blocker: true` или `score <= 2` по любому измерению:

1. Выполни `memory-bank/templates/prompts/03-1-fix-brief.md`.
2. Убедись, что созданы `brief-fix-contract-X.json` и `brief-v{N+1}.md`.
3. Повтори review (`02-1-review-brief.md`) → создаётся следующая пара `brief-review-X.md` + `brief-score-X.json`.
4. Повторяй `review → fix`, пока `verdict = ready_for_activation` и ни одного blocker.

### 1.4 Активация

Выполни `memory-bank/templates/prompts/04-activate-artifact.md` для `brief`.

**Gate:** активация разрешена только если последний `brief-score-X.json` имеет `verdict = ready_for_activation` и нет измерений с `score <= 2`.

**Результат:** `brief.md` в корне папки issue.

**⛔ Не переходи к Этапу 2, если `brief.md` в корне папки отсутствует.**

---

## Этап 2. SPEC

**Цель:** перевести проблему в технический контракт — FR, AC, инварианты, adversarial cases. Строго по `brief.md`.

### 2.1 Генерация

Выполни `memory-bank/templates/prompts/01-2-generate-spec.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `spec-rubric.json` | `iterations/spec/` |
| `spec-v1.md` | `iterations/spec/` |

### 2.2 Review

Выполни `memory-bank/templates/prompts/02-2-review-spec.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `spec-review-1.md` | `iterations/spec/` |
| `spec-score-1.json` | `iterations/spec/` |

**⚠ Не сохраняй spec-review или spec-score вне `iterations/spec/` — stray-файлы не открывают gate.**

### 2.3 Fix-цикл

Аналогично Brief: если есть blocker или `score <= 2`:

1. `03-2-fix-spec.md` → `spec-fix-contract-X.json` + `spec-v{N+1}.md`
2. `02-2-review-spec.md` → следующая пара review + score
3. Повторять до `verdict = ready_for_activation`

### 2.4 Активация

Выполни `04-activate-artifact.md` для `spec`.

**Результат:** `spec.md` в корне папки issue.

**⛔ Не переходи к Этапу 2.5, если `spec.md` отсутствует.**

---

## Этап 2.5. BDD-СЦЕНАРИИ

**Цель:** превратить `spec.md` в конкретный чеклист ручной проверки — список из 5–8 сценариев «Дано / Когда / Тогда / Как проверить», которые позволят убедиться руками, что фича работает.

На основе активированного `spec.md` сгенерируй сценарии приёмки, используя следующий промпт:

```
Контекст: Rails API-сервис сбора данных (ai-da-collect). Стек: Ruby 3.4 / Rails API /
PostgreSQL / Sidekiq (Redis) / S3-compatible blob storage / Docker.
Плагинная архитектура: каждый источник изолирован. Метаданные → PostgreSQL,
тела объектов → S3. Никакого AI, только ingestion.

Рассуди по шагам: какие ситуации и граничные случаи нужно покрыть для этой фичи.
Потом напиши сценарии в формате «Дано / Когда / Тогда / Как проверить».

Описание фичи (spec.md):
[вставить содержимое spec.md целиком]

Напиши сценарии для:
- успешного пути (happy path)
- ошибки входных данных (nil, blank, invalid)
- дублирующегося объекта (идемпотентность)
- граничных случаев, специфичных для этой фичи

Формат каждого сценария:
**Сценарий N: [название]**
- Дано: [начальное состояние системы]
- Когда: [действие — конкретная команда в rails console или rspec]
- Тогда: [ожидаемый результат, проверяемый руками]
- Как проверить: [SQL-запрос, команда, лог — что именно смотреть]
```

**Обязательный артефакт:**

| Файл | Путь |
|---|---|
| `acceptance-scenarios.md` | корень папки issue |

Этот файл будет входом для `run-instructions.md` (Этап 4.5) и Staged Validation (Этап 4.4).

**⛔ Не переходи к Этапу 3, если `acceptance-scenarios.md` отсутствует.**

---

## Этап 3. PLAN

**Цель:** разбить spec на атомарные шаги с дельтами, зависимостями и two-tier runtime gate.

### 3.1 Генерация

Выполни `memory-bank/templates/prompts/01-3-generate-plan.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `plan-rubric.json` | `iterations/plan/` |
| `plan-v1.md` | `iterations/plan/` |

**Обязательные требования к плану:**
- Каждый шаг: один файл или одна логическая операция.
- Для каждого шага редактирования: «что есть», «чего не хватает», «нельзя трогать».
- Финал плана — **two-tier runtime gate**:
  - Шаг N: `focused verification` нового контракта (конкретная команда + pass/fail сигнал).
  - Шаг N+1: `regression gate` по существующим suites (конкретная команда + pass/fail сигнал).
- **Раздел VibeContract** (обязателен): перед шагами реализации план должен содержать явные контракты фичи:
  - **Предусловие:** что должно быть верно в системе до запуска (записи в БД, переменные окружения, схема).
  - **Постусловие:** что гарантированно появится после успешного выполнения (записи, файлы, события).
  - **Инварианты:** что никогда не должно нарушаться (например: «тело объекта всегда в S3, ссылка в PG; никогда наоборот»).

  Эти контракты становятся критериями проверки в `run-instructions.md` и Стадии 6 Staged Validation.

### 3.2 Review

Выполни `memory-bank/templates/prompts/02-3-review-plan.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `plan-review-1.md` | `iterations/plan/` |
| `plan-score-1.json` | `iterations/plan/` |

### 3.3 Fix-цикл

Аналогично предыдущим этапам:

1. `03-3-fix-plan.md` → `plan-fix-contract-X.json` + `plan-v{N+1}.md`
2. `02-3-review-plan.md` → следующая пара
3. Повторять до `verdict = ready_for_activation`

### 3.4 Активация

Выполни `04-activate-artifact.md` для `plan`.

**Результат:** `plan.md` в корне папки issue.

**⛔ Не переходи к Этапу 4, если `spec.md` или `plan.md` отсутствуют.**

---

## Этап 4. РЕАЛИЗАЦИЯ

**Цель:** написать код строго по allowlist из `plan.md`, пройти оба runtime gates.

### 4.1 Генерация кода

Выполни `memory-bank/templates/prompts/01-4-generate-code.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `code-rubric.json` | `iterations/code/` |
| изменённые файлы проекта | по allowlist из `plan.md` |

**Ключевые ограничения:**
- Изменяй только файлы из allowlist `plan.md`. Любое отклонение — явная эскалация.
- Выполни оба runtime gates из плана локально и зафикcируй результат.
- Если focused verification прошёл, но regression gate не пройден — не объявляй реализацию завершённой.

### 4.2 Code Review

Выполни `memory-bank/templates/prompts/02-4-review-code.md`.

**Обязательные артефакты:**

| Файл | Путь |
|---|---|
| `code-review-1.md` | `iterations/code/` |
| `code-score-1.json` | `iterations/code/` |

### 4.3 Fix-цикл (если нужен)

Если есть `provable defect`, `scope breach` или `runtime-unknown gate`:

1. `03-4-fix-code.md` → `code-fix-contract-X.json` + правки в коде
2. `02-4-review-code.md` → следующая пара
3. Повторять до `verdict = ready_for_activation`

**⛔ Не считай code-review закрытым, если scorecard имеет `verdict = runtime_unknown` или остался незакрытый runtime gate.**

---

## Этап 4.4. STAGED VALIDATION

**Цель:** убедиться, что фича работает по стадиям — от дешёвого к дорогому. Провал на любой стадии = стоп, показать ошибку, исправить.

| Стадия | Что проверяем | Как проверяем | Стоимость |
|---|---|---|---|
| 1 | Файлы созданы, модель/сервис подключены | `ls app/models/ spec/models/` | секунды |
| 2 | Синтаксис Ruby | `bundle exec ruby -c <file>` или `bundle exec rubocop <file>` | секунды |
| 3 | Приложение стартует без ошибок | `bundle exec rails runner "puts 'ok'"` | секунды |
| 4 | Миграция применена, схема актуальна | `bundle exec rails db:migrate:status` — все UP | секунды |
| 5 | Автотесты зелёные | `bundle exec rspec spec/models/<feature>_spec.rb` | секунды–минуты |
| 6 | Данные сохраняются правильно (BDD-сценарии) | `rails console` + SQL по `acceptance-scenarios.md` | минуты |

**Стадии 1–4** выполняются агентом автоматически в рамках кодового этапа.  
**Стадии 5–6** фиксируются в `code-review-X.md` и `run-instructions.md`.

Стадия 6 — это буквально проверка каждого «Тогда» из `acceptance-scenarios.md`.

---

## Этап 4.5. RUN INSTRUCTIONS

**Цель:** создать `run-instructions.md` — конкретную пошаговую инструкцию, по которой человек может руками убедиться, что фича работает.

Сгенерируй файл на основе `spec.md`, `plan.md` и `acceptance-scenarios.md`, используя следующий промпт:

```
Ты — эксперт по Ruby on Rails API, Docker и ручному тестированию.

Контекст проекта ai-da-collect:
- Rails API, Ruby 3.4, PostgreSQL, Sidekiq, S3-compatible blob storage, Docker
- Плагинная архитектура, только ingestion — никакого AI

Фича: [название из brief.md]

Что реализовано (из plan.md):
[список изменённых файлов и суть каждого]

VibeContract (из plan.md):
- Предусловие: [...]
- Постусловие: [...]
- Инварианты: [...]

BDD-сценарии для проверки (из acceptance-scenarios.md):
[вставить все сценарии]

Напиши пошаговую инструкцию ручной проверки. Только конкретные команды — ничего абстрактного.

## 1. Подготовка
- Команды запуска сервисов и миграций
- Как убедиться что всё поднялось (health check, лог)
- Начальное состояние БД/S3 до проверки

## 2. Проверка сценариев
Для каждого сценария из acceptance-scenarios.md:
**Сценарий N: [название]**
- Команда: [rails console / curl / rake — скопировать и выполнить]
- Ожидаемый результат: [точно что появится]
- Проверка: [SQL-запрос или команда верификации]

## 3. Проверка инвариантов
- Команды для проверки каждого инварианта из VibeContract

## 4. Что смотреть в логах
- Rails log: признак успеха
- Признак скрытой ошибки (200 OK, но данные не сохранились)

## 5. Сброс состояния
- Команды очистки тестовых данных для повторной проверки
```

**Обязательный артефакт:**

| Файл | Путь |
|---|---|
| `run-instructions.md` | корень папки issue |

**⛔ Не переходи к Этапу 5, если `run-instructions.md` отсутствует.**

---

## Этап 5. АНАЛИЗ ЦИКЛА

Выполни `memory-bank/templates/prompts/05-1-analyze-cycle.md`.

**Обязательный артефакт:**

| Файл | Путь |
|---|---|
| `cycle-analysis-1.md` | `iterations/analysis/` |

Анализ должен охватывать:
- все canonical артефакты из `iterations/<stage>/` (rubrics, scorecards, fix-contracts, reviews);
- active-документы в корне папки;
- поздние code-review и фактические изменения кода.

Stray-файлы вне `iterations/<stage>/` не считаются authoritative без явной оговорки.

---

## Этап 6. УЛУЧШЕНИЯ ШАБЛОНОВ

Выполни `memory-bank/templates/prompts/06-1-apply-cycle-improvements.md`.

**Обязательный артефакт:**

| Файл | Путь |
|---|---|
| `template-improvements-1.md` | `iterations/analysis/` |

Шаг должен:
- прочитать `cycle-analysis-1.md`;
- внести только те правки в `memory-bank/templates/prompts/`, `memory-bank/issues/README.md`, `MAKE_NEW_ISSUE.md`, которые не дублируют уже встроенные правила;
- зафиксировать, что применено, что пропущено как дубликат.

---

## Этап 7. HW-ОТЧЁТ

Создай `memory-bank/issues/NNNN-slug/hw-reports/report.md` по образцу предыдущих задач:
- `memory-bank/issues/0001-plugin-contract/hw-reports/report.md`
- `memory-bank/issues/0005-raw-ingest-item/hw-reports/report.md`

Структура отчёта:

```
# HW-1 Report — Issue #NNNN: <название>

## 1. Затраченное время (таблица: этап / итераций / личное время / время агента)
## 2. Итерации по этапам (Brief / Spec / Plan / Code — что было, что исправлено)
## 3. Качество результата (что хорошо, где потребовалась правка, оценка /10)
## 4. Что нового по сравнению с предыдущими задачами
## 5. Что нужно изменить в промптах (ссылки на cycle-analysis)
## 6. Наблюдения по Context Engineering
## Ссылки
```

---

## Этап 8. КОММИТЫ, ПУШ, ЗАКРЫТИЕ ISSUE

### Коммит 1 — документация

Стейджи:
```bash
git add memory-bank/issues/NNNN-slug/
git add memory-bank/templates/prompts/        # только если были изменения
git add memory-bank/issues/README.md          # только если было изменение
git add memory-bank/issues/MAKE_NEW_ISSUE.md  # только если было изменение
```

Убедись, что в папке issue присутствуют `acceptance-scenarios.md` и `run-instructions.md` — они входят в этот коммит как часть документации задачи.

Формат сообщения:
```
Add SDD artifacts for issue #N: <краткое описание фичи>

Brief (vX→vY, <ключевой fix>), Spec (vX), Plan (vX, <ключевое решение>),
code-review, cycle-analysis, template-improvements, hw-report.

[Template improvements: <перечислить gate/rule если были>]

Ref #N

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Коммит 2 — код

Стейджи — только файлы из allowlist `plan.md`:
```bash
git add app/models/<new_file>.rb
git add db/migrate/<timestamp>_<migration>.rb
git add db/schema.rb
git add spec/models/<new_file>_spec.rb
# и другие файлы строго по allowlist
```

Формат сообщения:
```
Add <FeatureName>: <одна строка о сути>

- Migration: <что создано в схеме>
- Model / Service: <контракт и ключевая семантика>
- Spec: <N examples, что покрыто>

Closes #N

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

`Closes #N` автоматически закрывает issue при пуше в `main`.

### Пуш

```bash
git push origin main
```

### Закрытие issue

Если `Closes #N` сработал — issue уже закрыт. Добавь комментарий с итогом:

```bash
gh issue comment N --repo asromanychev/ai-da-collect --body "Реализовано в коммите <hash>.

**<FeatureName>:**
- <ключевые детали реализации>
- Spec: N examples, 0 failures (focused)
- Regression: M examples, 0 failures

SDD-артефакты: \`memory-bank/issues/NNNN-slug/\`"
```

Если issue не закрылся автоматически:

```bash
gh issue close N --repo asromanychev/ai-da-collect --comment "..."
```

---

## Контрольный список завершения цикла

Перед тем как объявить задачу выполненной, убедись, что все пункты закрыты:

### Артефакты

- [ ] `acceptance-scenarios.md` существует в корне папки issue
- [ ] `run-instructions.md` существует в корне папки issue
- [ ] `iterations/brief/brief-rubric.json` существует
- [ ] `iterations/brief/brief-vN.md` существует (последняя версия)
- [ ] `iterations/brief/brief-review-X.md` + `brief-score-X.json` существуют
- [ ] `brief.md` активирован в корне папки
- [ ] `iterations/spec/spec-rubric.json` существует
- [ ] `iterations/spec/spec-vN.md` существует
- [ ] `iterations/spec/spec-review-X.md` + `spec-score-X.json` существуют
- [ ] `spec.md` активирован в корне папки
- [ ] `iterations/plan/plan-rubric.json` существует
- [ ] `iterations/plan/plan-vN.md` существует
- [ ] `iterations/plan/plan-review-X.md` + `plan-score-X.json` существуют
- [ ] `plan.md` активирован в корне папки
- [ ] `iterations/code/code-rubric.json` существует
- [ ] `iterations/code/code-review-X.md` + `code-score-X.json` существуют
- [ ] `iterations/activation/artifact-activation-*.md` существуют (по одному на каждый активированный артефакт)
- [ ] `iterations/analysis/cycle-analysis-1.md` существует
- [ ] `iterations/analysis/template-improvements-1.md` существует
- [ ] `hw-reports/report.md` существует

### Код и видимый инкремент

- [ ] Staged Validation: Стадии 1–4 пройдены (файлы, синтаксис, boot, схема)
- [ ] Focused verification: все новые examples зелёные (Стадия 5)
- [ ] Regression gate: все существующие examples зелёные
- [ ] Стадия 6: хотя бы один BDD-сценарий из `acceptance-scenarios.md` верифицирован через `rails console` или эквивалент
- [ ] Изменены только файлы из allowlist `plan.md`

### Git

- [ ] Коммит 1 (доку) запушен
- [ ] Коммит 2 (код) запушен с `Closes #N`
- [ ] GitHub issue закрыт
- [ ] Комментарий с итогом оставлен в issue
