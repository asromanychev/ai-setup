---
issue: 2
type: plan-review
reviewed: plan-v2.md
review_number: 2
date: 2026-04-05
---

# Plan Review — Issue #0002 (plan-v2.md)

## Общая оценка

**1 блокирующее замечание.** Замечание из plan-review-1.md (каскадное удаление) устранено в plan-v2.md. Выявлена новая проблема, связанная с реальной реализацией `spec/spec_helper.rb`.

---

## Замечания

### Замечание 1 — Шаг 6 | Coverage gate сломает первую команду step 10 (блокирующее)

**Затронут:** шаг 6 (`spec/rails_helper.rb`, `spec/spec_helper.rb`) + шаг 10 (финальная верификация)

**Проблема логики / выполнимости:**

`spec/spec_helper.rb` запускает Ruby-native `Coverage.start(lines: true)` на строке 1 — до любых require — и регистрирует `after(:suite) { CoverageAssertions.verify! }`, который вызывает `Coverage.result` и проверяет покрытие `/core/lib/` ≥ 80%.

Шаг 6 говорит, что `rails_helper.rb` делает `require "spec_helper"`. Это означает:
1. При запуске модельных спеков (`rails_helper.rb` → `spec_helper.rb`) вызывается `Coverage.start`.
2. `require "collect"` в `spec_helper.rb` загружает файлы `core/lib`, Coverage начинает их отслеживать.
3. Модельные спеки выполняются — методы `core/lib` не вызываются; тела методов в `core/lib` остаются непокрытыми.
4. `after(:suite)` → `CoverageAssertions.verify!` → `Coverage.result` → coverage для `/core/lib/` значительно ниже 80% (тела методов `plugin.rb`, `plugin_registry.rb` и т.д. не выполняются) → `abort("Coverage ... is below 80%")`.

Шаг 10 выполняет две **отдельные** команды:
```
bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb
bundle exec rspec spec/core/collect
```
Первая команда упадёт из-за coverage gate ещё до запуска второй.

Шаг 6 оговаривает "кроме минимальной совместимости, если её потребует подключение rails specs", но не указывает, какое именно изменение нужно сделать. Это не наблюдаемый источник решения — это условие без конкретной дельты, что является блокирующим по критериям ревью.

**Как исправить (выбрать один вариант):**

Вариант A — исправить шаг 10: объединить обе команды в одну, чтобы core specs покрывали core/lib в рамках одного прогона:
```
bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb spec/core/collect
```
Это простейшее решение без изменения `spec_helper.rb`.

Вариант B — исправить шаг 6: явно указать конкретную дельту в `rails_helper.rb`, которая не вызывает `spec_helper` (или вызывает его без старта coverage). Например, `rails_helper.rb` самостоятельно настраивает RSpec без require `spec_helper`, либо добавляет guard `return if Coverage.running?` перед `Coverage.start` в `spec_helper.rb` (при условии, что это семантически допустимо в текущем стеке).

Вариант A проще и не требует изменений в существующих файлах.

---

## Проверка по остальным критериям

| Критерий | Результат | Примечание |
|---|---|---|
| Конкретность шагов | ✓ | Шаги 1–9 указывают конкретный файл и дельту |
| Логика зависимостей | ✓ | Порядок корректен: precondition → миграции → модели → helpers → specs → fixes → gate |
| Атомарность | ✓ | Каждый шаг выполняем и проверяем независимо (шаг 9 условный, но источник — red-тесты шагов 7–8, наблюдаемы) |
| Полнота | ✓ | Каскадное удаление добавлено в шаг 8; все AC из `spec.md` покрыты шагами 7–8 |
| Grounding | ✓ | `core/lib/collect/errors.rb`, `app/models/application_record.rb`, `spec/spec_helper.rb`, `spec/core/` — существуют; новые файлы корректно помечены |
| Lifecycle placement | ✓ | `before_validation` для нормализации; `upsert_checkpoint!` как instance method; всё в правильных фазах |
| Invariant materialization | ✓ | Инвариант 5 (FK-консистентность) материализован в шаге 8; инварианты 1–4 — в шаге 7 |
| Delta-first adequacy | ✓ | Каждый шаг описывает конкретную дельту; шаг 9 условный с наблюдаемым источником (шаги 7–8) |
| Final runtime gate | ✗ | Шаг 10 содержит конкретные команды, но первая команда сломает coverage gate из-за замечания 1 |
