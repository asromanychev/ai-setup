---
name: Source Checkpoint Spec Review 4
description: TAUS-ревью спецификации source checkpoint для issue 0002
type: draft
status: draft
issue: 0002-source-checkpoint
reviews: spec-v4
---

# Spec Review: Source и SyncCheckpoint (Issue #0002)

Проверена спецификация `spec-v4.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

Acceptance Criteria в основном сформулированы как наблюдаемое поведение: создание и выборка `Source`, поведение `upsert_checkpoint!`, чтение `sync_checkpoint`, каскадное удаление и ошибки целостности. По этим пунктам можно написать автотесты без привязки к внутренней реализации.

### 2. A (Ambiguous-free): Pass

В `spec-v4` сняты основные двусмысленности из прошлых итераций: явно зафиксированы правила для `{}` vs `nil`, для `loading` как неприменимого состояния, для `missing key` внутри `position` и для повторного вызова `upsert_checkpoint!`. Формулировки в целом достаточно однозначны для реализации агентом.

### 3. U (Uniform): Pass

Спецификация явно покрывает success, error и empty-состояния, отдельно фиксирует неприменимость `loading`, перечисляет гонку при `upsert`, `missing key` внутри `position`, `{}` vs `nil`, повторный вызов с теми же аргументами и сценарий обхода ограничений через прямой SQL. Инварианты также материализованы в falsifiable AC.

### 4. S (Scoped): Fail

**Цитата из спеки:** `Документ должен быть меньше 1500 слов и затрагивать не более 3 модулей системы.`

**Цитата из спеки:** `| db/migrate/YYYYMMDDHHMMSS_create_sources.rb | ... |`

**Цитата из спеки:** `| db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb | ... |`

**Цитата из спеки:** `| app/models/source.rb | ... |`

**Цитата из спеки:** `| app/models/sync_checkpoint.rb | ... |`

**Цитата из спеки:** `| core/lib/collect/errors.rb | ... |`

**Цитата из спеки:** `| config/application.rb | require 'collect' — точка подключения core/lib к Rails autoload |`

**Цитата из спеки:** `| spec/rails_helper.rb | Новый helper для Rails model specs (см. выше) |`

**Проблема для AI-агента:** по факту спека тянет как минимум пять разных модульных зон: миграции/схема БД, AR-модели, ядро `core/lib`, bootstrapping Rails-приложения и тестовую инфраструктуру. Это уже не «ровно одна фича в пределах до 3 модулей», а смесь доменной фичи и инфраструктурной обвязки. Для агента это увеличивает риск расползания реализации и конфликтов по приоритетам: что из этого обязательно для issue, а что лишь способ подружить текущий репозиторий с новой доменной моделью.

**Вариант исправления:** сузить спецификацию до не более чем трёх модулей. Практически это можно сделать так: оставить `db/migrate`, `app/models` и `spec/models`, а подключение `core/lib` в Rails и правки `config/application.rb` вынести в отдельный infrastructure issue либо заменить на уже существующий способ загрузки без расширения scope.

### 5. Scope явно ограничен: Pass

Раздел Scope чётко отделяет реализуемое от запрещённого: оркестрация, фоновые джобы, payload, API и провайдер-специфичная логика исключены явно, а не подразумеваются.

### 6. Инварианты перечислены: Pass

Инварианты перечислены явно, и у каждого есть проверяемый сценарий в разделе состояний или в Acceptance Criteria: уникальность источника, единственность checkpoint, независимость записей, каскадное удаление и сохранение переданного `position`.

### 7. Grounding и реализуемость: Fail

**Цитата из спеки:** `| config/application.rb | require 'collect' — точка подключения core/lib к Rails autoload |`

**Цитата из текущего проекта:** `spec/spec_helper.rb` содержит `$LOAD_PATH.unshift(File.expand_path("../core/lib", __dir__))` перед `require "collect"`.

**Проблема для AI-агента:** текущий репозиторий не делает `core/lib` доступным для обычного `require "collect"` внутри Rails-приложения. Сейчас это работает только в `spec/spec_helper.rb` через ручное добавление `core/lib` в `$LOAD_PATH`. Формулировка про `require 'collect'` в `config/application.rb` не привязана к реальному механизму загрузки: без дополнительного шага этот `require` просто неразрешим. Агенту всё ещё придётся гадать, нужно ли добавлять `core/lib` в `autoload_paths`, `eager_load_paths`, `$LOAD_PATH` или подключать файлы иначе.

**Вариант исправления:** явно зафиксировать механизм подключения `core/lib` до `require "collect"`. Например: добавить `Rails.root.join("core/lib")` в путь загрузки и только затем вызывать `require "collect"`, либо отказаться от `config/application.rb` как точки интеграции и использовать явную загрузку `core/lib` только в `spec/rails_helper.rb`, если для этого issue runtime-интеграция Rails с `Collect` не нужна.

## Итог

Есть Fail-критерии: `S`, `Grounding и реализуемость`.
