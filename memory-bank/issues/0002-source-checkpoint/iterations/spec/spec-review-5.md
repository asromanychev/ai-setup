---
name: Source Checkpoint Spec Review 5
description: TAUS-ревью спецификации source checkpoint для issue 0002
type: draft
status: draft
issue: 0002-source-checkpoint
reviews: spec-v5
---

# Spec Review: Source и SyncCheckpoint (Issue #0002)

Проверена спецификация `spec-v5.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

`spec-v5` формулирует Acceptance Criteria как наблюдаемое поведение: создание `Source`, выборка через `for_sync`, чтение `sync_checkpoint`, идемпотентный и обновляющий `upsert_checkpoint!`, каскадное удаление, изоляцию разных source и ошибки целостности. По этим пунктам можно писать автотесты без проверки внутренних деталей реализации.

### 2. A (Ambiguous-free): Pass

В текущей версии сняты прошлые двусмысленности: явно зафиксированы `{}` vs `nil`, неприменимость `loading`, допустимость `missing key` внутри `position`, поведение повторного вызова с теми же аргументами и границы type-casting для `sync_enabled`. Формулировки в целом однозначны для AI-агента.

### 3. U (Uniform): Pass

Спецификация покрывает success, error и empty-состояния, отдельно фиксирует, что `loading` здесь неприменим, и материализует доменные boundary cases: `missing key`, `{}` vs `nil`, constructor-time validation, повторный вызов с теми же аргументами, обход AR через прямой SQL и конкурентный `upsert`. У каждого инварианта есть falsifiable сценарий в разделе состояний или в AC.

### 4. S (Scoped): Fail

**Цитата из спеки:** `| db/migrate/YYYYMMDDHHMMSS_create_sources.rb | ... |`

**Цитата из спеки:** `| db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb | ... |`

**Цитата из спеки:** `| app/models/source.rb | ... |`

**Цитата из спеки:** `| app/models/sync_checkpoint.rb | ... |`

**Цитата из спеки:** `| core/lib/collect/errors.rb | Добавить Collect::CheckpointAmbiguityError < Collect::Error |`

**Цитата из спеки:** `| spec/rails_helper.rb | Новый helper ... |`

**Цитата из спеки:** `| spec/models/source_spec.rb | RSpec-тесты модели Source |`

**Цитата из спеки:** `| spec/models/sync_checkpoint_spec.rb | RSpec-тесты модели SyncCheckpoint |`

**Проблема для AI-агента:** по ограничению шаблона спецификация должна затрагивать не более 3 модулей системы. В `spec-v5` остаются как минимум четыре отдельные модульные зоны: слой БД/миграций, AR-модели, `core/lib` и тестовая инфраструктура Rails/RSpec. Документ уже укладывается в лимит по размеру (`1228` слов), но по модульному охвату scope всё ещё шире допустимого.

**Вариант исправления:** сузить спецификацию до трёх зон. Практически это можно сделать одним из двух способов: либо вынести `Collect::CheckpointAmbiguityError` в отдельный infrastructure/core issue, оставив в этой спецификации только `db/migrate`, `app/models` и `spec/models`; либо явно переопределить границу фичи так, чтобы тестовый helper не считался отдельным модулем и не требовал отдельной инфраструктурной работы сверх модели и БД.

### 5. Scope явно ограничен: Pass

Раздел Scope явно отделяет входящее в задачу от запрещённого: оркестрация, фоновые джобы, payload, API, провайдер-специфичные данные и подключение `core/lib` к Rails runtime вынесены за рамки issue.

### 6. Инварианты перечислены: Pass

Инварианты заданы явно, и для каждого есть проверяемый сценарий: уникальность `(plugin_type, external_id)`, единственность checkpoint, неизменность сохранённой позиции, независимость checkpoint разных источников и каскадное удаление после `source.destroy`.

### 7. Grounding и реализуемость: Pass

Текущая версия привязана к реальной архитектуре репозитория: в проекте уже есть Rails/ActiveRecord-каркас (`config/application.rb`, `app/models/application_record.rb`, `config/database.yml`), `core/lib/collect/errors.rb` существует, а способ явной загрузки `core/lib` через `$LOAD_PATH.unshift(...); require "collect"` уже используется в `spec/spec_helper.rb`. Формулировка про новый `spec/rails_helper.rb` продолжает этот существующий паттерн и больше не требует несуществующих зависимостей вроде `database_cleaner` или неописанного подключения через `config/application.rb`.

## Итог

Есть Fail-критерии: `S`.
