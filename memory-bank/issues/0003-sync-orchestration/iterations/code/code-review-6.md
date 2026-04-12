---
issue: 3
title: Code Review — One-Step Sync Orchestration
type: code-review
status: draft
version: v1
date: 2026-04-06
---

# Code Review: Issue #0003 — One-Step Sync Orchestration

---

## Контекст анализа

- **spec.md**: `memory-bank/issues/0003-sync-orchestration/spec.md` (status: draft, v4)
  — Замечание: поле `status: draft`. Файл присутствует, review выполняется; дрейф от `active` зафиксирован.
- **plan.md**: `memory-bank/issues/0003-sync-orchestration/plan.md` (status: active, v9)
- **Diff**: `git diff HEAD -- app/models/source.rb spec/models/source_spec.rb` + полный рабочий дифф (включает `.env.example` и `config/database.yml`)
- **Allowlist из plan.md**: `app/models/source.rb`, `spec/models/source_spec.rb`

---

## Scope-and-Runtime Context

| Файл | Allowlist | Изменён в diff |
|---|---|---|
| `app/models/source.rb` | ✓ | ✓ |
| `spec/models/source_spec.rb` | ✓ | ✓ |
| `.env.example` | ✗ | ✓ — **scope breach** |
| `config/database.yml` | ✗ | ✓ — **scope breach** |

Materialized runtime artifacts, релевантные spec §7:
- `app/models/sync_checkpoint.rb` — не изменён; контракт `position` не меняется
- `spec/rails_helper.rb` — не изменён; outer transaction `joinable: false, requires_new: true` активна
- `core/lib/collect/` — не изменён; `Collect::UnknownPluginError`, `Collect::CheckpointAmbiguityError` доступны в spec-runtime через `$LOAD_PATH.unshift` в `spec_helper.rb`

---

## 1. Предпосылки

1. `spec/spec_helper.rb` и `spec/rails_helper.rb` добавляют `core/lib` в `$LOAD_PATH` и `require "collect"` — иначе `Collect::UnknownPluginError` в строке 203 `source_spec.rb` не резолвится.
2. `sync_step!` в `source.rb` не добавляет новых ссылок на `Collect::` — precondition из spec §3 не блокирует реализацию (все ссылки на `Collect::CheckpointAmbiguityError` в `sync_checkpoint` были до diff).
3. PostgreSQL использует JSONB для `position`: symbol-ключи Hash при записи (`{ cursor: 4 }`) при чтении возвращаются как string-ключи (`{ "cursor" => 4 }`). Тесты корректно учитывают это (строки 177, 184, 191, 197, 209, 218, 250, 301, 309, 316, 324, 333, 349).
4. Outer transactional spec fixture (`rails_helper.rb`, `requires_new: true`) оборачивает каждый example — inner savepoint из `sync_step!` (`requires_new: true`) создаёт вложенный `SAVEPOINT` в PostgreSQL.

---

## 2. Инварианты и контракты

**Инвариант 1 — Атомарность checkpoint (spec §6.1)**
`source.rb:37–39`: `transaction(requires_new: true)` оборачивает только `upsert_checkpoint!`. Если внутри поднимается исключение, savepoint откатывается. Снаружи блока (строки 31–36) checkpoint не затрагивается. Инвариант формально соблюдён по коду.

**Инвариант 2 — Нет частичного прогресса на ошибке (spec §6.2)**
Четыре точки отказа:
- `plugin_registry.build` (строка 32) — исключение до чтения checkpoint; checkpoint не меняется. ✓
- `plugin.sync_step` (строка 33) — исключение после чтения, до `validate_sync_result!`; checkpoint не затронут. ✓
- `validate_sync_result!` (строка 35) — поднимает `ArgumentError` до `transaction`; checkpoint не затронут. ✓
- `upsert_checkpoint!` внутри `transaction` (строки 37–39) — исключение приводит к rollback savepoint. ✓

**Инвариант 3 — Актуальная persisted позиция (spec §6.3)**
`sync_checkpoint&.position` вызывается как аргумент `plugin.sync_step` (строка 33): Ruby вычисляет аргумент до вызова, чтение происходит из БД на момент вызова. Нет кэширования из предыдущих операций. ✓

**Инвариант 4 — Изоляция источников (spec §6.4)**
`SyncCheckpoint.upsert` на строке 22–26 использует `{ source_id: id, unique_by: :source_id }` — апсерт только по конкретному `source_id`. Не затрагивает записи других источников. ✓

**Инвариант 5 — Duck-typed независимость (spec §6.5)**
`sync_step!` вызывает только `plugin_registry.build(plugin_type, source_config: source_config)` и `plugin.sync_step(checkpoint_in: ...)`. Нет ветвлений по `is_a?`, `respond_to?` или классу. ✓

**Контракт validate_sync_result! (spec §4, FR 7–12)**
```
source.rb:66–74:
  is_a?(Hash)                         → "sync result must be a Hash"
  key?(:records)                      → "sync result must include :records"
  key?(:checkpoint_out)               → "sync result must include :checkpoint_out"
  key?(:finished)                     → "sync result must include :finished"
  records.is_a?(Array)                → "records must be an Array"
  checkpoint_out.is_a?(Hash)          → "checkpoint_out must be a Hash"
  [true, false].include?(finished)    → "finished must be boolean"
```
`{}.is_a?(Hash)` → `true` → `checkpoint_out: {}` проходит валидацию (spec AC 7, FR 8). ✓
`nil.is_a?(Hash)` → `false` → `checkpoint_out: nil` отвергается (spec AC 13). ✓

**Видимость `validate_sync_result!`**
`private` объявлен на строке 54; `validate_sync_result!` определён на строке 66 — внутри private-секции. `sync_step!` определён на строке 31 — до `private`, то есть публичный. Оба вызова консистентны. ✓

---

## 3. Трассировка путей выполнения

### Happy path (сц 5, 6, 7)

```
sync_step!(plugin_registry: registry, source_config: config)
  → registry.build("telegram", source_config: config)          # строка 32
  → plugin.sync_step(checkpoint_in: <persisted или nil>)       # строка 33
  → validate_sync_result!(result)                              # строка 35 → OK
  → transaction(requires_new: true)                            # строка 37
      upsert_checkpoint!(position: result[:checkpoint_out])    # строка 38
        SyncCheckpoint.upsert(...)                             # source.rb:22–26
        reload_sync_checkpoint                                 # source.rb:28 / 61–64
  → return result                                             # строка 41
```

Поведение не изменилось для существующих методов (`upsert_checkpoint!`, `sync_checkpoint`, `reload_sync_checkpoint`).

### Error path — plugin error (сц 8, 9)

```
sync_step!
  → registry.build(...) → raises / plugin.sync_step → raises
  → исключение всплывает из строки 32 или 33
  → transaction не достигнута
  → checkpoint не изменён
```

### Error path — invalid result (сц 10a–10c, 11, 12, 13, 19, 20)

```
sync_step!
  → plugin.sync_step → returns invalid result
  → validate_sync_result! → raises ArgumentError   # строка 35
  → transaction не достигнута
  → checkpoint не изменён
```

### Error path — upsert failure (сц 14)

```
sync_step!
  → validate_sync_result! → OK
  → transaction(requires_new: true) { upsert → partial write → raise }
  → savepoint rollback
  → исключение всплывает из transaction-блока
  → checkpoint после rollback = состояние до savepoint
```

**Изменения относительно до-diff состояния:**
- До diff: `sync_step!` не существовал; `sync_checkpoint` уже был; `upsert_checkpoint!` уже был.
- После diff: добавлены `sync_step!` (public) и `validate_sync_result!` (private). Ни один существующий метод не изменён.

---

## 4. Риски и регрессии

### scope breach (medium) — `.env.example` и `config/database.yml`

Файлы изменены вне allowlist plan.md. Изменения:
- `.env.example`: добавлена строка `TEST_DATABASE_URL=...`
- `config/database.yml`: изменён `url:` в `default:` на `ENV.fetch(...) { fallback }`, добавлен `url:` в `test:` секцию

Функционально эти изменения необходимы для подключения тестовой БД, что является prerequisite для запуска spec suite (шаг 5 плана). Однако их отсутствие в allowlist — нарушение scope плана.

**Severity: medium** — не ломают логику задачи, но расширяют diff за пределы approved scope.

### runtime-unknown gate (не является provable defect) — сценарий 14, savepoint rollback

`source_spec.rb:221–231`: тест использует `and_wrap_original` на `SyncCheckpoint.upsert`, выполняет реальный upsert, затем поднимает `ActiveRecord::StatementInvalid`. Ожидается, что inner savepoint (`requires_new: true`) откатится, а старый checkpoint сохранится.

Логика корректна: `transaction(requires_new: true)` в PostgreSQL транслируется в `SAVEPOINT` → при исключении `ROLLBACK TO SAVEPOINT` → outer transaction (spec fixture) остаётся жива → `source.reload.sync_checkpoint.position` читает состояние до savepoint.

**Нельзя доказать без запуска:** зависит от того, что AR при `and_wrap_original` поднимает исключение уже после `SAVEPOINT`, что outer spec transaction действительно открыта и совместима с `requires_new: true`. Это `runtime-unknown gate`, не `provable defect`.

**Severity: low** — паттерн стандартный, из документации AR/PostgreSQL; риск реален только при необычной конфигурации БД или версии AR.

### low — сценарий 4: неполная верификация первого создания SyncCheckpoint

`source_spec.rb:169–173` (сц 4): тест проверяет только `checkpoint_in: nil`, но **не** проверяет, что после успешного вызова создаётся первая запись `SyncCheckpoint` (что требует AC 4 в spec §8).

Это частично покрыто `source_spec.rb:175–178` (сц 5): `expect(source.reload.sync_checkpoint.position).to eq("cursor" => 4)` — source создаётся без prior checkpoint, то есть сц 5 неявно покрывает создание. Однако явной проверки `count == 1` нет.

**Это не provable defect** — реализация корректно создаёт SyncCheckpoint через `upsert_checkpoint!` при любом вызове (включая первый). Риск лишь в adequacy теста.

**Severity: low**.

---

## 5. Вердикт по эквивалентности

**Эквивалентно** — по всем 18 Acceptance Criteria spec §8 и инвариантам spec §6.

| AC | Тест (строки в source_spec.rb) | Статус |
|---|---|---|
| AC 1 | 138–149 | ✓ |
| AC 2 | 151–159 | ✓ |
| AC 3 | 161–167 | ✓ |
| AC 4 | 169–173 (+ неявно 175–178) | ✓ |
| AC 5 | 175–178 | ✓ |
| AC 6 | 180–185 | ✓ |
| AC 7 | 187–192 | ✓ |
| AC 8 | 212–219 | ✓ |
| AC 9 | 202–210 | ✓ |
| AC 10 (a/b/c) | 336–351 | ✓ |
| AC 11 | 304–310 | ✓ |
| AC 12 | 312–318 | ✓ |
| AC 13 | 320–326 | ✓ |
| AC 14 | 221–231 | ✓ (runtime-unknown gate) |
| AC 15 | 233–242 | ✓ |
| AC 16 | 244–252 | ✓ |
| AC 17 | 254–294 | ✓ |
| AC 18 (все тесты зелёные) | runtime-only | runtime-unknown gate |

Контрпример для опровержения `Эквивалентно`: не найден в коде. Все FR и инварианты соблюдены по статическому анализу.

Единственный открытый вопрос — прохождение полного suite (в т.ч. сц 14) — является `runtime-unknown gate`, а не `provable defect`.

---

## 6. Что проверить тестами (топ-5)

1. **Savepoint rollback (сц 14)** — запустить `bundle exec rspec spec/models/source_spec.rb -e "rolls back checkpoint"` против реальной PostgreSQL. Единственный способ закрыть главную runtime-неопределённость.

2. **Первое создание SyncCheckpoint (AC 4)** — добавить в сц 4 explicit assertion: `expect(SyncCheckpoint.where(source_id: source.id).count).to eq(1)` после `sync_step!`. Текущий тест не провалится, но добавит явность.

3. **`checkpoint_out: {}` persistence (сц 7)** — `expect(source.reload.sync_checkpoint.position).to eq({})` — проверяется (строка 191), но важно убедиться, что PostgreSQL JSONB round-trip для пустого Hash не теряет `{}` → `nil`.

4. **Полный suite с pre-existing pending = 0 (шаг 2 плана)** — `bundle exec rspec --format documentation` должен показать 0 failures, 0 pending, coverage ≥ 80% на `core/lib`.

5. **`config/database.yml` fallback** — убедиться, что в CI `TEST_DATABASE_URL` проставляется, иначе fallback `postgresql://ai_da_collect:...@127.0.0.1:5432/ai_da_collect_test` не работает вне локальной машины (это scope breach, но он функционально влияет на CI-gate).

---

## 7. Confidence

**0.88**

Что мешает 1.0:
- Сц 14 (savepoint rollback) невозможно верифицировать без запуска против реальной PostgreSQL.
- Spec.md имеет `status: draft` — незначительная неопределённость: финальная версия spec могла отличаться от v4.
- Scope breach (`.env.example`, `config/database.yml`) не влияет на функциональные AC, но создаёт расхождение с планом.

---

## Execution Metadata

- `system`: Claude Code CLI
- `model`: claude-sonnet-4-6
- `provider`: Anthropic
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-4-review-code.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T00:00:00+03:00
- `finished_at`: unknown
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
