---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: active
version: v10
date: 2026-04-06
---

# Implementation Plan: One-Step Sync Orchestration (Issue #0003)

---

## 1. Паттерн оркестрации

Один агент, последовательное выполнение. Шаги строго упорядочены по зависимостям: prerequisite-check → observational gate → реализация → тесты → финальная верификация.

---

## 2. Grounding

- [x] `app/models/source.rb` — существует, содержит `upsert_checkpoint!` и `sync_checkpoint`
- [x] `app/models/sync_checkpoint.rb` — существует, контракт `position` не меняется
- [x] `spec/models/source_spec.rb` — существует, будет расширен новым describe-блоком
- [x] `spec/rails_helper.rb` — существует; outer transaction: `joinable: false, requires_new: true`; уже добавляет `core/lib` в `$LOAD_PATH`
- [x] `spec/spec_helper.rb` — существует, уже добавляет `core/lib` в `$LOAD_PATH`
- [x] `core/lib/collect/plugin_registry.rb` — существует, duck-typed reference
- [x] `core/lib/collect/plugin.rb` — существует, duck-typed reference
- [x] `core/lib/collect/errors.rb` — существует, `Collect::CheckpointAmbiguityError` уже используется в `source.rb`
- [x] `config/application.rb` — существует; `core/lib` не в autoload — расширять autoload/load-path нельзя
- [x] `config/initializers/` — доступна для минимального runtime bootstrap, если prerequisite-check покажет отсутствие `Collect` в application runtime
- [x] Нет конфликтов с текущей архитектурой
- [x] Реализуемо на текущем стеке без новых gem-зависимостей

---

## 3. Пошаговый план

### Шаг 1 — Prerequisite check: проверить доступность `Collect::` в application runtime

**Целевой файл:** `config/initializers/collect.rb` только если prerequisite-check провалился

**Суть:** Подтвердить, что `Collect::CheckpointAmbiguityError` доступен после обычного boot приложения, без опоры на spec helpers. В `spec/rails_helper.rb` есть `$LOAD_PATH.unshift` + `require "collect"` — это более permissive окружение, чем application runtime. Prerequisite должен проверять именно application boot, а не spec boot. Если check падает, разрешён минимальный initializer `config/initializers/collect.rb` c явным `require Rails.root.join("core/lib/collect").to_s`; расширять autoload/load-path нельзя.

**Команда:**
```
bundle exec rails runner "puts Collect::CheckpointAmbiguityError"
```

**Ожидаемый вывод:** `Collect::CheckpointAmbiguityError` (или `Collect::CheckpointAmbiguityError < StandardError` в зависимости от Ruby-версии). Выход 0.

**Delta:**
- Что уже есть: `source.rb:37` ссылается на `Collect::CheckpointAmbiguityError`; `config/application.rb` не добавляет `core/lib` в autoload
- Чего не хватает: явного подтверждения, что application boot уже делает `Collect::` доступным; если подтверждения нет, нужен минимальный initializer-require
- Нельзя менять: `config/application.rb` и autoload/load-path

**Trigger для дальнейших шагов:** команда завершается exit 0 и выводит имя константы → precondition из spec §3 выполнен, переходим к шагу 2.
Если `NameError` или exit != 0 — добавить `config/initializers/collect.rb` с минимальным explicit require, затем повторить prerequisite-check. Если после этого check всё ещё не проходит, реализация останавливается согласно spec §3.

**Разрешает зависимости для:** Шага 2 (подтверждает, что `source.rb` может использовать `Collect::` без нового autoload-path и с допустимым initializer-require).

---

### Шаг 2 — Observational: зафиксировать pre-existing pending count

**Целевой файл:** нет (observational-only, без правок)

**Суть:** До начала любых изменений в коде зафиксировать количество pending-тестов в текущем состоянии repo. Это значение определяет строгость финального gate (шаг 5).

**Команда (двухшаговая — сначала boot-check, потом подсчёт):**

Шаг 2a — убедиться, что suite загружается без ошибок вне examples:
```bash
bundle exec rspec --format json 2>/dev/null > /tmp/rspec_base.json; \
  jq 'if .errors_outside_of_examples_count > 0 then error("suite failed to load: \(.errors_outside_of_examples_count) errors outside examples") else "suite loaded OK" end' /tmp/rspec_base.json
```

**Ожидаемый вывод шага 2a:** строка `"suite loaded OK"`, exit 0. Если выдаётся `error(...)` или exit != 0 — suite не загрузился; дальнейший подсчёт pending не производится, реализация останавливается.

Шаг 2b — подсчитать pending только при условии успешного шага 2a:
```bash
jq '[.examples[] | select(.status == "pending")] | length' /tmp/rspec_base.json
```

**Ожидаемый вывод шага 2b:** целое число ≥ 0.

**Фиксация результата:**
- Если результат = 0 → финальный gate строг: `0 pending` без исключений.
- Если результат > 0 → перечислить pending-тесты явно (их описания) и исключить только их из gate; любой новый pending из `describe "#sync_step!"` остаётся недопустимым.

**Нельзя менять:** ничего — это observational шаг.

**Разрешает зависимости для:** Шага 5 (определяет критерий прохождения финального gate).

---

### Шаг 3 — `app/models/source.rb`: добавить `sync_step!` и приватный `validate_sync_result!`

**Целевой файл:** `app/models/source.rb`

**Суть:** Добавить публичный метод `sync_step!(plugin_registry:, source_config:)` и приватный валидатор `validate_sync_result!(result)`. Новые методы добавляются в соответствующие секции файла (public и private), не меняя существующий код.

**Delta:**
- Что уже есть: `has_one :sync_checkpoint`, `upsert_checkpoint!(position:)`, `sync_checkpoint` (custom reader), `for_sync`, validations, `normalize_identifiers` (private), `reload_sync_checkpoint` (private)
- Чего не хватает по spec.md:
  - Публичный метод `sync_step!(plugin_registry:, source_config:)` (spec §4, FR 1–14)
  - Приватный метод `validate_sync_result!(result)` для валидации shape result до записи checkpoint (spec §4, FR 7–12; §5, таблица сценариев)
- Что запрещено переписывать без отдельного observational расхождения: все существующие методы (`upsert_checkpoint!`, `sync_checkpoint`, `reload_sync_checkpoint`, `normalize_identifiers`, `for_sync`, validations, association)

**Реализация `sync_step!`:**
```ruby
def sync_step!(plugin_registry:, source_config:)
  plugin = plugin_registry.build(plugin_type, source_config: source_config)
  checkpoint_in = sync_checkpoint&.position
  result = plugin.sync_step(checkpoint_in: checkpoint_in)
  validate_sync_result!(result)
  transaction(requires_new: true) { upsert_checkpoint!(position: result[:checkpoint_out]) }
  result
end
```

**Пояснение по транзакции — изменение относительно v6:**
- Использован `transaction(requires_new: true)` вместо `transaction {}`. Это создаёт явный savepoint (`SAVEPOINT` в PostgreSQL) независимо от того, существует ли ambient transaction.
- В spec-окружении `rails_helper.rb` оборачивает каждый example в `connection.transaction(joinable: false, requires_new: true)`. При этом inner `transaction(requires_new: true)` создаёт вложенный savepoint, видимый как отдельный rollback boundary внутри example. Это обеспечивает наблюдаемость rollback в сценарии 14.
- В production-окружении без ambient transaction `requires_new: true` запускает полноценную транзакцию — семантика не меняется.
- Если `upsert_checkpoint!` поднимает исключение, savepoint откатывается, старый checkpoint сохраняется (spec инвариант §6.1).
- `upsert_checkpoint!` уже защищён от `nil` через `raise ArgumentError` — `validate_sync_result!` перехватывает `checkpoint_out: nil` до вызова `upsert_checkpoint!`, поэтому два уровня защиты не конфликтуют.
- `checkpoint_out: {}` — валидный Hash, проходит `result[:checkpoint_out].is_a?(Hash)` → сохраняется (spec §4, FR 8).

**Реализация `validate_sync_result!` (в секции private):**
```ruby
def validate_sync_result!(result)
  unless result.is_a?(Hash) &&
         result.key?(:records) &&
         result.key?(:checkpoint_out) &&
         result.key?(:finished) &&
         result[:records].is_a?(Array) &&
         result[:checkpoint_out].is_a?(Hash) &&
         [true, false].include?(result[:finished])
    raise ArgumentError, "invalid sync result: #{result.inspect}"
  end
end
```

**Разрешает зависимости для:** Шага 4 (тесты могут вызывать `source.sync_step!`).

---

### Шаг 4 — `spec/models/source_spec.rb`: добавить `describe "#sync_step!"`

**Целевой файл:** `spec/models/source_spec.rb`

**Суть:** Добавить новый describe-блок `describe "#sync_step!"` после существующего `describe "#upsert_checkpoint!"`. Использовать `double` / `instance_double`-стиль для duck-typed plugin_registry и plugin — без реальных сетевых вызовов и без новых spec helpers. Исключение: сценарий 17 (AC 17) — см. примечание ниже.

**Delta:**
- Что уже есть: `describe "validations"`, `describe ".for_sync"`, `describe "#upsert_checkpoint!"` с полным покрытием
- Чего не хватает по spec.md: тесты для всех Acceptance Criteria из spec §8, а также явные сценарии для одноразового вызова `plugin.sync_step` и отклонения non-Hash result от duck-typed плагина
- Что запрещено менять без observational расхождения: существующие it-блоки и shared setup

**Сценарии, которые должны быть покрыты (итого 22 новых examples):**

| # | Сценарий | Acceptance Criteria из spec §8 |
|---|---|---|
| 1 | `registry.build` вызывается с `source.plugin_type` и тем же `source_config` | AC 1 |
| 2 | `source_config` не проходит валидацию в `build` → исходное исключение, checkpoint не меняется | AC 2 |
| 3 | Источник имел checkpoint → `plugin.sync_step` получает `checkpoint_in: { "cursor" => 3 }` | AC 3 |
| 4 | Источник без checkpoint → `plugin.sync_step` получает `checkpoint_in: nil`, создаётся первая запись `SyncCheckpoint` | AC 4 |
| 5 | Валидный result → метод возвращает эквивалентный Hash и сохраняет `checkpoint_out` | AC 5 |
| 6 | Checkpoint обновляется с `{ "cursor" => 3 }` на `{ cursor: 4 }` | AC 6 |
| 7 | `records: []`, `checkpoint_out: {}`, `finished: false` → успех, persisted checkpoint становится `{}` | AC 7 |
| 8 | `plugin.sync_step` поднимает исключение → `source.sync_checkpoint.position` совпадает с состоянием до вызова | AC 8 |
| 9 | `registry.build` поднимает исключение → checkpoint не меняется | AC 9 |
| 10a | Result без ключа `:records` → `ArgumentError`, checkpoint не меняется | AC 10 |
| 10b | Result без ключа `:checkpoint_out` → `ArgumentError`, checkpoint не меняется | AC 10 |
| 10c | Result без ключа `:finished` → `ArgumentError`, checkpoint не меняется | AC 10 |
| 11 | `records` не `Array` → ошибка, checkpoint не меняется | AC 11 |
| 12 | `finished` не boolean → ошибка, checkpoint не меняется | AC 12 |
| 13 | `checkpoint_out: nil` → ошибка, checkpoint не меняется | AC 13 |
| 14 | `upsert_checkpoint!` начинает запись внутри savepoint, затем поднимает исключение → savepoint откатывается, старый checkpoint сохраняется | AC 14 |
| 15 | Два подряд failing вызова → checkpoint совпадает с состоянием до первой ошибки | AC 15 |
| 16 | Успешный вызов для `source_a` не меняет checkpoint `source_b` | AC 16 |
| 17 | Два разных duck-typed класса с одинаковым валидным result → одинаковый возврат и одинаковое обновление checkpoint | AC 17 |
| 18 | `plugin.sync_step` вызывается ровно один раз с корректным `checkpoint_in` | AC 6 (spec §4 FR 6) |
| 19 | Duck-typed plugin возвращает non-Hash result (`"bad"` или `[]`) → `Source#sync_step!` raises `ArgumentError`, checkpoint не меняется | spec §4 FR 7 |
| 20 | Result является Hash, `records` и `finished` валидны, но `checkpoint_out` не является Hash (например `"bad"`) → `ArgumentError`, checkpoint не меняется | spec §4 FR 7 |

**Пояснение к сценариям 10a–10c (три кейса вместо одного):**

Каждый из трёх mandatory ключей (`:records`, `:checkpoint_out`, `:finished`) должен быть проверен независимо. Допускается реализация в виде трёх отдельных `it`-блоков или одного параметризованного с `shared_examples` / inline-таблицей. В обоих вариантах это засчитывается как 3 отдельных examples в RSpec. В каждом кейсе:
- Передаётся Hash со всеми ключами, кроме одного проверяемого.
- Ожидается `raise_error(ArgumentError)`.
- Checkpoint не меняется: `expect(source.reload.sync_checkpoint.position).to eq(pre_existing_position)`.

**Пояснение к сценарию 20 (checkpoint_out non-Hash при иначе валидном result):**

Цель — доказать, что `validate_sync_result!` проверяет не только присутствие ключа `:checkpoint_out`, но и тип его значения (`is_a?(Hash)`). Сценарий дополняет сц. 13 (`nil`) и сц. 19 (полностью non-Hash result).

- Setup: source с existing checkpoint `{ "cursor" => 5 }`.
- Plugin возвращает `{ records: [], checkpoint_out: "bad_string", finished: false }`.
- Ожидается `raise_error(ArgumentError)`.
- Verify: `expect(source.reload.sync_checkpoint.position).to eq({ "cursor" => 5 })`.

**Примечание по сценарию 14 (материализация инварианта rollback через явный savepoint):**

Цель сценария — доказать, что `transaction(requires_new: true)` в `sync_step!` создаёт наблюдаемый savepoint-boundary, откат которого сохраняет старый checkpoint.

**Контекст транзакций в spec-окружении:**
- Outer spec transaction: `connection.transaction(joinable: false, requires_new: true)` — это savepoint, созданный `rails_helper.rb`, откатывается автоматически после каждого example.
- Inner transaction в `sync_step!`: `transaction(requires_new: true)` создаёт вложенный savepoint (`SAVEPOINT svpt_N` в PostgreSQL) поверх outer savepoint. Этот inner savepoint — отдельный rollback boundary: если inner savepoint откатывается (из-за исключения), outer savepoint остаётся жив и управляет cleanup всего example.

**Setup:**
- `source` с existing checkpoint `{ "cursor" => 1 }`.
- Использовать `and_wrap_original` на `SyncCheckpoint`, чтобы оригинальный `upsert` выполнился (записал в рамках inner savepoint), а затем поднять исключение:
  ```ruby
  allow(SyncCheckpoint).to receive(:upsert).and_wrap_original do |original, *args, **kwargs|
    original.call(*args, **kwargs)
    raise ActiveRecord::StatementInvalid, "simulated DB error after upsert"
  end
  ```
- Trigger: `expect { source.sync_step!(...) }.to raise_error(ActiveRecord::StatementInvalid)`.
- Verify: `expect(source.reload.sync_checkpoint.position).to eq({ "cursor" => 1 })` — inner savepoint откатился (upsert отменён), outer savepoint жив, checkpoint читается из БД как прежний.
- Откат тест-состояния обеспечивается outer transactional фикстурами из `rails_helper.rb`.

**Почему это работает с `requires_new: true`:** AR при `requires_new: true` выдаёт `SAVEPOINT` в PostgreSQL. Исключение внутри блока → `ROLLBACK TO SAVEPOINT`. Outer transaction остаётся открытой. После `ROLLBACK TO SAVEPOINT` состояние таблицы внутри outer transaction соответствует состоянию до `SAVEPOINT`, то есть старый checkpoint.

**Примечание по сценарию 17 (два разных duck-typed plugin класса — AC 17):**

Цель сценария — доказать, что `Source#sync_step!` не зависит от конкретного класса plugin и одинаково работает с любым объектом, реализующим `#sync_step`. Единственная меняющаяся переменная между двумя прогонами — класс plugin object; всё остальное (включая initial checkpoint и `checkpoint_in`) должно быть идентичным.

- Для этого сценария **не использовать** `double` / `instance_double`. Вместо этого объявить два минимальных анонимных класса внутри `it`-блока:
  ```ruby
  plugin_class_a = Class.new do
    def sync_step(checkpoint_in:) = { records: [], checkpoint_out: { "cursor" => 1 }, finished: false }
  end
  plugin_class_b = Class.new do
    def sync_step(checkpoint_in:) = { records: [], checkpoint_out: { "cursor" => 1 }, finished: false }
  end
  ```
- Использовать **два разных `Source`** (`source_a` и `source_b`) с одинаковым initial checkpoint (например, `{ "cursor" => 0 }`), созданных до вызовов. Это гарантирует, что оба вызова `sync_step!` стартуют из идентичного состояния и получают одинаковый `checkpoint_in`.
- Registry doubles для обоих источников настраиваются независимо: `registry_a` при вызове `build` возвращает `plugin_class_a.new`, `registry_b` — `plugin_class_b.new`.
- Verify для каждого source:
  - возвращённый Hash одинаков: `{ records: [], checkpoint_out: { "cursor" => 1 }, finished: false }`;
  - persisted checkpoint обоих source обновился до `{ "cursor" => 1 }`;
  - оба plugin'а получили одинаковый `checkpoint_in: { "cursor" => 0 }`, что подтверждает: единственная различавшаяся переменная — класс плагина.
- Для всех остальных сценариев (1–16, 18–20) продолжать использовать `double` / `instance_double`.

**Примечание по сценарию 18 (ровно один вызов `plugin.sync_step`):**

Цель сценария — доказать, что реализация `sync_step!` не вызывает `plugin.sync_step` повторно (например, при retry или двойном вызове внутри метода). Сценарий материализует spec §4 FR 6.

- Setup: создать `source` с existing checkpoint, сконфигурировать `plugin` через `expect(plugin).to receive(:sync_step).once.with(checkpoint_in: { "cursor" => 3 }).and_return(valid_result)`.
- Trigger: `source.sync_step!(plugin_registry: registry, source_config: source_config)`.
- Verify: RSpec автоматически провалит тест, если `plugin.sync_step` не был вызван ровно один раз. Дополнительно проверить, что persisted checkpoint обновился до `valid_result[:checkpoint_out]`.

**Примечание по сценарию 19 (non-Hash result от duck-typed plugin):**

Цель сценария — доказать, что `validate_sync_result!` реально выполняется и отвергает non-Hash результаты, даже если плагин не наследуется от `Collect::Plugin`.

- Setup: создать `source` с existing checkpoint `{ "cursor" => 5 }`. Сконфигурировать duck-typed plugin через `allow(plugin).to receive(:sync_step).and_return("bad")` (или `[]`).
- Trigger: `expect { source.sync_step!(...) }.to raise_error(ArgumentError)`.
- Verify: `expect(source.reload.sync_checkpoint.position).to eq({ "cursor" => 5 })` — checkpoint не изменился.

**Разрешает зависимости для:** Шага 5 (финальная верификация выполняет эти тесты).

---

### Шаг 5 — Финальная верификация: запустить полный spec suite (чистый runtime gate)

**Целевые файлы:** весь `spec/` (все тесты)

**Суть:** Запустить полный spec suite и подтвердить, что все тесты зелёные и coverage ≥ 80% по `core/lib` (gate из `spec/spec_helper.rb`). Этот шаг — чистый acceptance gate: никаких условных правок или edit-loop. Критерий pending определён шагом 2: если pre-existing pending = 0, ожидается `0 pending`; если > 0 — допустимы только зафиксированные в шаге 2 pending-тесты.

**Команда 5a-1 — проверка boot-success (до счёта examples):**

```bash
bundle exec rspec spec/models/source_spec.rb --dry-run --format json 2>/dev/null \
  > /tmp/rspec_dryrun.json; \
  jq 'if .errors_outside_of_examples_count > 0 \
      then error("spec boot failed: \(.errors_outside_of_examples_count) errors outside examples") \
      else "spec boot OK" \
      end' /tmp/rspec_dryrun.json
```

**Ожидаемый вывод команды 5a-1:** строка `"spec boot OK"`, exit 0. Если boot провален — шаг 5 прерывается, причина фиксируется как отдельное observational расхождение.

**Команда 5a-2 — подсчёт новых examples в `#sync_step!` (только после успешного 5a-1):**

```bash
jq '[.examples[] | select(.full_description | contains("#sync_step!"))] | length' \
  /tmp/rspec_dryrun.json
```

**Ожидаемый вывод команды 5a-2:** `22`. Если число меньше — шаг 4 не завершён (добавлены не все сценарии), реализация не продолжается.

**Команда 5b — полный suite:**
```
bundle exec rspec --format documentation
```

**Gate-условия (строгие):**
- [ ] Команда 5a-1 выводит `"spec boot OK"` (exit 0, `errors_outside_of_examples_count == 0`)
- [ ] Команда 5a-2 выводит `22`
- [ ] Все existing тесты зелёные (validations, .for_sync, #upsert_checkpoint!)
- [ ] Все 22 новых тестов `#sync_step!` зелёные
- [ ] Coverage по `core/lib` ≥ 80% (spec_helper.rb `CoverageAssertions.verify!`)
- [ ] Checkpoint-инварианты проверены через прямые `.reload` вызовы в тестах
- [ ] 0 failures; pending — только те, что зафиксированы в шаге 2 (ожидается 0)

**Pass criteria:** exit 0, 0 failures, команда 5a-1 = boot OK, команда 5a-2 = 22, pending совпадает со значением из шага 2.

**Если тест красный или команда 5a-2 < 22:** шаг считается failed. Падение фиксируется как observational расхождение (failing output → отдельная задача Fix), реализация текущего плана на этом останавливается.

---

## 4. Новые файлы

Новые файлы в этом плане **не создаются**. Все изменения вносятся в существующие файлы:
- `app/models/source.rb` — добавление методов
- `spec/models/source_spec.rb` — добавление describe-блока

---

## 5. Execution Metadata

- `system`: Claude Code CLI
- `model`: claude-sonnet-4-6
- `provider`: Anthropic
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/03-3-fix-plan.md`

## 6. Runtime Telemetry

- `started_at`: 2026-04-06T00:00:00+03:00
- `finished_at`: unknown
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
