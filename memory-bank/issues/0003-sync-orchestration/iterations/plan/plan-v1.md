---
issue: 3
title: Ядро: оркестрация одного шага синка (плагин + checkpoint + транзакция)
status: draft
version: v1
date: 2026-04-06
---

# Implementation Plan: One-Step Sync Orchestration (Issue #0003)

---

## 1. Паттерн оркестрации

Один агент, последовательное выполнение. Шаги строго упорядочены по зависимостям: prerequisite-check → реализация → тесты → финальная верификация.

---

## 2. Grounding

- [x] `app/models/source.rb` — существует, содержит `upsert_checkpoint!` и `sync_checkpoint`
- [x] `app/models/sync_checkpoint.rb` — существует, контракт `position` не меняется
- [x] `spec/models/source_spec.rb` — существует, будет расширен новым describe-блоком
- [x] `spec/rails_helper.rb` — существует, уже добавляет `core/lib` в `$LOAD_PATH`
- [x] `spec/spec_helper.rb` — существует, уже добавляет `core/lib` в `$LOAD_PATH`
- [x] `core/lib/collect/plugin_registry.rb` — существует, duck-typed reference
- [x] `core/lib/collect/plugin.rb` — существует, duck-typed reference
- [x] `core/lib/collect/errors.rb` — существует, `Collect::CheckpointAmbiguityError` уже используется в `source.rb`
- [x] `config/application.rb` — существует; `core/lib` не в autoload — менять нельзя
- [x] Нет конфликтов с текущей архитектурой
- [x] Реализуемо на текущем стеке без новых gem-зависимостей

---

## 3. Пошаговый план

### Шаг 1 — Prerequisite check: проверить runtime-доступность `Collect::` в тест-окружении

**Целевой файл:** `spec/models/source_spec.rb` (только запуск, без правок)

**Суть:** Запустить существующий тестовый набор `source_spec.rb`, чтобы подтвердить, что `Collect::CheckpointAmbiguityError`, уже используемый в `source.rb:37`, доступен в тест-runtime без изменений boot-процесса.

**Команда:**
```
bundle exec rspec spec/models/source_spec.rb
```

**Delta:**
- Что уже есть: `source.rb` ссылается на `Collect::CheckpointAmbiguityError`; `rails_helper.rb` добавляет `core/lib` в `$LOAD_PATH` до `require "collect"`
- Чего не хватает: явного подтверждения, что это работает в текущем состоянии кодовой базы
- Нельзя менять: ничего — это observational шаг

**Trigger для дальнейших шагов:** все тесты зелёные → precondition из spec §3 выполнен, переходим к реализации.
Если тесты красные — реализация останавливается согласно spec §3 (stop condition).

**Разрешает зависимости для:** Шага 2 (подтверждает, что `source.rb` может использовать `Collect::` без нового autoload-path)

---

### Шаг 2 — `app/models/source.rb`: добавить `sync_step!` и приватный `validate_sync_result!`

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
  transaction { upsert_checkpoint!(position: result[:checkpoint_out]) }
  result
end
```

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

**Пояснение по транзакции:**
- `transaction { upsert_checkpoint!(position: result[:checkpoint_out]) }` оборачивает upsert в AR-транзакцию.
- Если `upsert_checkpoint!` поднимает исключение внутри transaction-блока, транзакция откатывается и старый checkpoint сохраняется (spec инвариант §6.1).
- `upsert_checkpoint!` уже защищён от `nil` через `raise ArgumentError` — `validate_sync_result!` перехватывает `checkpoint_out: nil` до вызова `upsert_checkpoint!`, поэтому два уровня защиты не конфликтуют.
- `checkpoint_out: {}` — валидный Hash, проходит `result[:checkpoint_out].is_a?(Hash)` → сохраняется (spec §4, FR 8).

**Разрешает зависимости для:** Шага 3 (тесты могут вызывать `source.sync_step!`)

---

### Шаг 3 — `spec/models/source_spec.rb`: добавить `describe "#sync_step!"`

**Целевой файл:** `spec/models/source_spec.rb`

**Суть:** Добавить новый describe-блок `describe "#sync_step!"` после существующего `describe "#upsert_checkpoint!"`. Использовать только `double` / `instance_double`-стиль для duck-typed plugin_registry и plugin — без реальных сетевых вызовов и без новых spec helpers.

**Delta:**
- Что уже есть: `describe "validations"`, `describe ".for_sync"`, `describe "#upsert_checkpoint!"` с полным покрытием
- Чего не хватает по spec.md: тесты для всех 18 Acceptance Criteria из spec §8
- Что запрещено менять без observational расхождения: существующие it-блоки и shared setup

**Сценарии, которые должны быть покрыты (один it на сценарий):**

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
| 10 | Result без одного из ключей `:records`/`:checkpoint_out`/`:finished` → ошибка, checkpoint не меняется | AC 10 |
| 11 | `records` не `Array` → ошибка, checkpoint не меняется | AC 11 |
| 12 | `finished` не boolean → ошибка, checkpoint не меняется | AC 12 |
| 13 | `checkpoint_out: nil` → ошибка, checkpoint не меняется | AC 13 |
| 14 | `upsert_checkpoint!` поднимает исключение внутри transaction → старый checkpoint сохраняется | AC 14 |
| 15 | Два подряд failing вызова → checkpoint совпадает с состоянием до первой ошибки | AC 15 |
| 16 | Успешный вызов для `source_a` не меняет checkpoint `source_b` | AC 16 |
| 17 | Два разных duck-typed класса с одинаковым валидным result → одинаковый возврат и одинаковое обновление checkpoint | AC 17 |
| 18 | Все существующие тесты остаются зелёными (верифицируется в шаге 4) | AC 18 |

**Примечание по сценарию 14 (materialization ошибки upsert внутри транзакции):**
- Prerequisite: `source` с existing checkpoint
- Setup: заглушка `source.stub(:upsert_checkpoint!)` (или `allow(source).to receive(:upsert_checkpoint!).and_raise(...)`) до вызова `sync_step!`
- Verify: `source.reload.sync_checkpoint.position` совпадает со значением до вызова
- После теста: откат обеспечивается тест-транзакцией из `rails_helper.rb`

**Разрешает зависимости для:** Шага 4 (финальная верификация выполняет эти тесты)

---

### Шаг 4 — Финальная верификация: запустить полный spec suite

**Целевые файлы:** `spec/models/source_spec.rb` (все тесты), runtime coverage gate

**Суть:** Запустить полный набор тестов, подтвердить, что все тесты зелёные и coverage ≥ 80% по `core/lib` (gate из `spec/spec_helper.rb`).

**Команда:**
```
bundle exec rspec spec/models/source_spec.rb --format documentation
```

**Gate-условия:**
- [ ] Все existing тесты зелёные (validations, .for_sync, #upsert_checkpoint!)
- [ ] Все 17 новых тестов `#sync_step!` зелёные
- [ ] Coverage по `core/lib` ≥ 80% (spec_helper.rb `CoverageAssertions.verify!`)
- [ ] Checkpoint-инварианты проверены через прямые `.reload` вызовы в тестах

**Условное действие:** если какой-либо тест красный — триггер для правки идёт из его failing output (наблюдаемое расхождение), а не из умозаключений.

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
- `prompt_id`: `memory-bank/templates/prompts/01-3-generate-plan.md`

## 6. Runtime Telemetry

- `started_at`: 2026-04-06T15:35:00+03:00
- `finished_at`: 2026-04-06T15:36:20+03:00
- `elapsed_seconds`: 80
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
