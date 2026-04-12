---
name: Source Checkpoint Spec Review 6
description: TAUS-ревью спецификации source checkpoint для issue 0002
type: draft
status: draft
issue: 0002-source-checkpoint
reviews: spec-v6
---

# Spec Review: Source и SyncCheckpoint (Issue #0002)

Проверена спецификация `spec-v6.md`.

0 замечаний, спека готова к реализации.

## Вердикты по критериям

### 1. T (Testable): Pass

`spec-v6` формулирует Acceptance Criteria как наблюдаемое поведение: создание `Source`, выборка через `for_sync`, чтение `sync_checkpoint`, обновляющий и идемпотентный `upsert_checkpoint!`, каскадное удаление и ошибки целостности. По этим критериям можно писать автотесты без проверки внутренних деталей реализации.

### 2. A (Ambiguous-free): Pass

Двусмысленные формулировки сняты: спецификация явно фиксирует `{}` vs `nil`, неприменимость `loading`, допустимость `missing key` внутри `position`, границы type-casting для `sync_enabled` и поведение повторного вызова с теми же аргументами. Для AI-агента поведение описано однозначно.

### 3. U (Uniform): Pass

Спецификация покрывает success, error и empty-состояния и отдельно материализует, что `loading` для синхронных AR-операций неприменим. Доменные boundary cases перечислены явно: `missing key`, `{}` vs `nil`, constructor-time validation, повторный вызов с теми же аргументами, прямой SQL в обход AR, конкурентный `upsert` и мутация входного `Hash` после вызова.

### 4. S (Scoped): Pass

Документ описывает одну фичу: персистентность `Source` и `SyncCheckpoint` для возобновления синка. Текст укладывается в лимит шаблона (`1230` слов), а затронутые зоны теперь сведены к трём: `db/migrate`, `app/models` и `spec` для Rails model specs; `Collect::CheckpointAmbiguityError` вынесен за рамки этой задачи в явный precondition.

### 5. Scope явно ограничен: Pass

Раздел Scope явно отделяет входящее в задачу от запрещённого: оркестрация, фоновые джобы, payload, валидация формата `position`, API, провайдер-специфичные данные, подключение `core/lib` к Rails runtime и определение `Collect::CheckpointAmbiguityError` не входят в реализацию по этому issue.

### 6. Инварианты перечислены: Pass

Инварианты заданы явно: уникальность `(plugin_type, external_id)`, единственность checkpoint, неизменность сохранённой позиции после `upsert`, независимость checkpoint разных источников и каскадное удаление после `source.destroy`. Для каждого инварианта есть falsifiable сценарий в разделе состояний или в Acceptance Criteria.

### 7. Grounding и реализуемость: Pass

Спецификация привязана к реальной структуре репозитория: в проекте уже есть Rails/ActiveRecord-каркас (`config/application.rb`, `app/models/application_record.rb`, `config/database.yml`), существует `core/lib/collect/errors.rb`, а загрузка `core/lib` через `$LOAD_PATH.unshift(...); require "collect"` уже используется в `spec/spec_helper.rb`. При этом зависимость от `Collect::CheckpointAmbiguityError` оформлена как явный precondition отдельного infrastructure issue, поэтому граница текущей задачи остаётся реализуемой и согласованной с архитектурой.

## Итог

Fail-критериев нет.
