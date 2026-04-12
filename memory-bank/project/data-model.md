---
title: Модель данных (PostgreSQL + object storage)
doc_kind: project
doc_function: canonical
purpose: Каноническое текстовое описание реляционной схемы ingestion, индексов дедупликации и роли S3; дополняет `db/schema.rb`, не заменяет его.
derived_from:
  - overview.md
  - ../../aitlas/ai-da-collect/conventions/docs/architecture.md
status: active
audience: humans_and_agents
---

# Модель данных (PostgreSQL + object storage)

**SSoT по структуре таблиц:** `db/schema.rb` и миграции в `db/migrate/`. Этот файл — для агентов и людей: смысл полей, инварианты и типичные запросы без чтения всего Rails schema.

## Диаграмма связей (логическая)

```text
sources (1) ──< (N) raw_ingest_items
sources (1) ──< (0..1) sync_checkpoints   -- on_delete cascade от source
```

## Таблицы

### `sources`

Логический источник данных, привязанный к типу плагина.

| Колонка        | Тип     | Назначение |
|----------------|---------|------------|
| `id`           | bigint  | PK |
| `plugin_type`  | string  | Идентификатор плагина (строковый ключ домена) |
| `external_id`  | string  | Стабильный внешний ключ источника в рамках плагина |
| `sync_enabled` | boolean | Флаг участия в синхронизации (default `false`) |
| `created_at` / `updated_at` | datetime | Rails timestamps |

**Инварианты:** уникальность пары `(plugin_type, external_id)` — один конфигурируемый источник на ключ.

### `sync_checkpoints`

Текущая позиция инкрементального синка для источника (сериализованный checkpoint плагина).

| Колонка     | Тип     | Назначение |
|-------------|---------|------------|
| `id`        | bigint  | PK |
| `source_id` | bigint  | FK → `sources.id`, **уникальный** (один checkpoint на источник) |
| `position`  | jsonb   | Структура для `checkpoint_in` / `checkpoint_out` контракта плагина |
| `created_at` / `updated_at` | datetime | Rails timestamps |

**Инварианты:** не более одной строки на `source_id`; при удалении источника строка checkpoint удаляется каскадом.

### `raw_ingest_items`

Единица сырого ingestion: связь с источником, внешний идентификатор записи у источника, метаданные, опционально ключ объекта в object storage.

| Колонка       | Тип     | Назначение |
|---------------|---------|------------|
| `id`          | bigint  | PK |
| `source_id`   | bigint  | FK → `sources.id` |
| `external_id` | string  | Идемпотентный ключ записи **в рамках источника** |
| `metadata`    | jsonb   | Метаданные без крупных бинарных тел (default `{}`) |
| `storage_key` | string  | Ключ/указатель на объект в **S3-compatible** хранилище (тело/вложение), nullable |
| `created_at` / `updated_at` | datetime | Rails timestamps |

**Инварианты:** уникальность `(source_id, external_id)` — дедуп при повторной доставке.

## Object storage (вне PostgreSQL)

Крупные payload и файлы вложений хранятся в S3-compatible storage; в PG остаются `storage_key` и при необходимости метаданные объекта в `metadata` (не дублировать многомегабайтные blob в JSONB). Подробнее см. `.cursor/rules/tech_persistence_auto_active-record.mdc` и `aitlas/ai-da-collect/conventions/docs/architecture.md`.

## Типичные сценарии для агента

- **Новая миграция:** проверить уникальные индексы под идемпотентность и FK на `sources`.
- **Дедуп:** опираться на `index_raw_ingest_items_on_source_id_and_external_id` (unique).
- **Продолжить синк:** читать/писать `sync_checkpoints.position` в согласовании с `Collect::Plugin#sync_step`.

## Связанные артефакты

- `memory-bank/issues/0002-source-checkpoint/`, `0005-raw-ingest-item/`, `0004-s3-blob-storage/` — постановки по эволюции схемы.
