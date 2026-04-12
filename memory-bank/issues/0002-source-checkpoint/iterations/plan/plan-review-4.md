---
issue: 2
type: plan-review
reviewed: plan-v4.md
review_number: 4
date: 2026-04-05
---

# Plan Review — Issue #0002 (plan-v4.md)

## Общая оценка

**2 блокирующих замечания.** План стал лучше по части ambiguity-case, но в нём остались один неисполняемый precondition-шаг и один неприземлённый тестовый bootstrap для Rails model specs.

---

## Замечания

### Замечание 1 — Шаг 1 | Внешний precondition описан как шаг реализации, но не даёт исполнимой дельты (блокирующее)

**Затронут:** шаг 1 (`core/lib/collect/errors.rb`)

**Проблема логики / выполнимости:**

`spec.md` прямо относит `Collect::CheckpointAmbiguityError` к внешнему infrastructure precondition и исключает его определение из scope текущего issue. В текущем репозитории этот класс действительно отсутствует: в `core/lib/collect/errors.rb` есть только `Collect::Error`, `Collect::ContractError`, `Collect::UnknownPluginError`.

Шаг 1 при этом не формулирует наблюдаемую дельту внутри этого issue:

1. он не говорит, какой именно change должен быть сделан в `core/lib/collect/errors.rb`;
2. он одновременно запрещает "самовольно расширять `core/lib`" в рамках issue;
3. последующие шаги 4 и 8 всё равно зависят от существования `Collect::CheckpointAmbiguityError`.

В результате шаг 1 не является ни атомарным шагом реализации, ни корректным gate-шагом: его нельзя "выполнить" внутри плана, и после него план остаётся заблокированным внешней зависимостью без отдельной команды остановки.

**Как исправить:**

Нужно убрать этот пункт из нумерованного implementation plan и оформить его как явный prerequisite перед шагом 1, например:

- "План выполняется только после появления `Collect::CheckpointAmbiguityError` в `core/lib/collect/errors.rb` в отдельном infrastructure issue";
- если precondition не закрыт, реализация этого плана не стартует.

Если команда всё же хочет закрывать precondition в этом же плане, тогда шаг 1 должен быть переписан как обычная конкретная дельта по `core/lib/collect/errors.rb`, а `spec.md` нужно синхронно пересмотреть, потому что сейчас это противоречит declared scope.

### Замечание 2 — Шаг 6 + Шаг 10 | Тестовый bootstrap не заземлён в текущем стеке и не готовит test DB (блокирующее)

**Затронут:** шаг 6 (`spec/rails_helper.rb`, `spec/spec_helper.rb`) + шаг 10 (runtime-команды)

**Проблема логики / выполнимости:**

План исходит из того, что Rails model specs можно поднять через новый `spec/rails_helper.rb` с `config.use_transactional_tests = true`, а затем проверить их командой:

```bash
bundle exec rails db:migrate
bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb
bundle exec rspec spec/core/collect
```

Но в текущем репозитории для этого нет достаточного grounding:

1. В `Gemfile` подключён `gem "rspec"`, но нет `rspec-rails`, поэтому API вида `config.use_transactional_tests = true` не подтверждён текущим test stack и потребует догадок о том, как именно интегрировать Rails fixtures/transactions в plain RSpec.
2. Команда `bundle exec rails db:migrate` готовит primary development DB, но не описывает, как test DB получит новые таблицы `sources` и `sync_checkpoints`.
3. В шаге 6 не зафиксирован наблюдаемый механизм синхронизации test schema, например `ActiveRecord::Migration.maintain_test_schema!` или отдельная runtime-команда для `RAILS_ENV=test`.

Из-за этого план не даёт исполнимого источника решения для первого прогона model specs: непонятно ни на каком API строится transactional setup, ни откуда в test DB появится целевая схема.

**Как исправить:**

Нужно сделать bootstrap полностью конкретным и совместимым с текущим стеком. Минимально:

- в шаге 6 заменить абстрактное "настроить transactional tests" на точный механизм, который реально работает без `rspec-rails` в этом репозитории;
- в шаге 6 или 10 явно добавить синхронизацию test DB, например через `ActiveRecord::Migration.maintain_test_schema!` и/или отдельную команду уровня `RAILS_ENV=test bundle exec rails db:prepare`;
- после этого оставить финальный gate только с теми командами, которые действительно воспроизводят acceptance-проверку на чистом checkout.

Пока этих уточнений нет, шаги 6 и 10 остаются partly declarative, а не executable.

---

## Проверка по остальным критериям

| Критерий | Результат | Примечание |
|---|---|---|
| Конкретность шагов | △ | Большинство шагов конкретны, но шаг 1 не задаёт исполнимую дельту, а шаг 6 опирается на неподтверждённый test API |
| Логика зависимостей | △ | Порядок в целом верный, но выполнение фактически блокируется внешним prerequisite и неготовым test bootstrap |
| Атомарность | ✓ | Шаги 2–5 и 7–10 декомпозированы приемлемо; проблема в том, что шаги 1 и 6 нельзя выполнить без дополнительных решений |
| Полнота | ✓ | Миграции, модели, helper, model specs и финальная проверка перечислены |
| Grounding | ✗ | `Collect::CheckpointAmbiguityError` отсутствует в текущем `core/lib`, а transactional config для plain `rspec` не подтверждён текущим `Gemfile` |
| Lifecycle placement | ✓ | Нормализация, runtime-методы и DB-инварианты расположены по правильным фазам |
| Invariant materialization | ✓ | Инварианты про uniqueness, cascade delete, independence и ambiguity материализованы в тестовых шагах |
| Delta-first adequacy | ✗ | Шаг 1 описывает prerequisite, а не дельту по текущему issue; шаг 6 требует более конкретной технической дельты |
| Final runtime gate | ✗ | Есть команды, но они пока не гарантируют воспроизводимую проверку на test DB |
