---
issue: 2
title: Персистентность источников и контрольных точек синка
status: draft
version: v9
date: 2026-04-12
---

# Implementation Plan: Source and SyncCheckpoint Persistence

## 1. Паттерн оркестрации

Один агент, последовательное выполнение. Для historical reprocess код не переписывается автоматически: сначала восстанавливается active contract, затем отдельно оценивается текущий working tree на соответствие scope и runtime gates.

## 1.5 Preconditions

- `PRE-1`: `Collect::CheckpointAmbiguityError` существует в `core/lib/collect/errors.rb`.
- `PRE-2`: primary/test DB доступны для Rails model runtime; если нет, code-stage фиксирует `runtime_unknown` вместо ложного успеха.
- `PRE-3`: reprocess выполняется поверх legacy feature `sources`, даже если текущий roadmap уже мигрирует проект на `CollectionTask`.

## 2. Grounding

- [x] `app/models/source.rb` существует.
- [x] `app/models/sync_checkpoint.rb` существует.
- [x] `spec/models/source_spec.rb` и `spec/models/sync_checkpoint_spec.rb` существуют.
- [x] `spec/rails_helper.rb` существует и является точкой отказа при отсутствии test DB.
- [x] `db/schema.rb` содержит нужные таблицы.
- [x] `core/lib/collect/errors.rb` содержит `Collect::CheckpointAmbiguityError`.

## 3. Граф зависимостей

```text
STEP-1 -> STEP-2 -> STEP-3 -> STEP-4 -> STEP-5 -> STEP-6
```

## 4. Пошаговый план

- `STEP-1` [S]: `memory-bank/issues/0002-source-checkpoint/brief.md` -> переписать brief в новый канон без solution leakage.
  - Implements: REQ-1, REQ-2, REQ-3, REQ-4, REQ-5, REQ-6
  - Depends on: нет зависимостей
  - Rollback: вернуть предыдущую active версию из `iterations/brief/*`
  - Signal: brief содержит явные `When`, наблюдаемые success criteria и out-of-scope

- `STEP-2` [S]: `memory-bank/issues/0002-source-checkpoint/spec.md` -> переписать spec под stable IDs и traceability.
  - Implements: REQ-1, REQ-2, REQ-3, REQ-4, REQ-5, REQ-6
  - Depends on: STEP-1
  - Rollback: вернуть предыдущую active версию из `iterations/spec/*`
  - Signal: в spec есть `REQ-*`, `NS-*`, `SC-*`, `CHK-*`, `EVID-*`

- `STEP-3` [S]: `memory-bank/issues/0002-source-checkpoint/plan.md` -> привести план к atomized-step и runtime-gate формату.
  - Implements: REQ-1, REQ-4, REQ-5, REQ-6
  - Depends on: STEP-2
  - Rollback: вернуть предыдущую active версию из `iterations/plan/*`
  - Signal: каждый `STEP-*` ссылается на `REQ-*` или `SC-*`, а финальный gate отделён от правок

- `STEP-4` [S]: `memory-bank/issues/0002-source-checkpoint/acceptance-scenarios.md`, `run-instructions.md` -> materialize manual verification layer.
  - Implements: SC-1, SC-3, SC-4, SC-5, SC-7
  - Depends on: STEP-2
  - Rollback: удалить новые feature-level manual artifacts
  - Signal: ручные сценарии можно выполнить через Rails runner/console без домысливания шагов

- `STEP-5` [M]: `iterations/brief/*`, `iterations/spec/*`, `iterations/plan/*`, `iterations/activation/*` -> добавить rubric/review/score/activation следы для новых active docs.
  - Implements: REQ-1, REQ-2, REQ-3, REQ-4, REQ-5, REQ-6
  - Depends on: STEP-1, STEP-2, STEP-3
  - Rollback: удалить только newly-added canonical artifacts текущего reprocess
  - Signal: для каждого active артефакта есть machine-readable gate и activation trace

- `STEP-6` [M]: `iterations/code/*`, `iterations/analysis/*`, `hw-reports/*` -> провести code review и сравнение старого/нового процесса без скрытых правок к production code.
  - Implements: SC-1, SC-6, CHK-1, CHK-2, CHK-3, CHK-4
  - Depends on: STEP-4, STEP-5
  - Rollback: удалить newly-added review/report artifacts
  - Signal: есть явный verdict по scope/runtime quality текущего working tree и итоговое сравнение процесса

## 5. План тестирования

- `spec/models/source_spec.rb`: source validation, normalization, `for_sync`, checkpoint upsert, isolation.
- `spec/models/sync_checkpoint_spec.rb`: checkpoint validation, zero/one/many states, cascade delete.
- `spec/core/collect/*`: regression для prerequisite/core contract.
- `acceptance-scenarios.md`: manual scenarios для human verification legacy feature.

## 6. Финальный Runtime Gate

- `CHK-1` `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` -> feature-level model suite зелёный или явно фиксируется infrastructure blocker.
- `CHK-2` `bundle exec rspec spec/core/collect` -> зелёный.
- `CHK-3` `bundle exec rails runner 'puts Source.count'` -> выполним только при доступной DB; иначе blocker остаётся infrastructure-level.
- `CHK-4` Code review working tree против active spec/plan -> без доказуемого logic defect, с отдельной фиксацией scope/runtime drift.

- `EVID-1` Carrier: `iterations/code/code-score-3.json`
- `EVID-2` Carrier: `iterations/analysis/cycle-analysis-2.md`
