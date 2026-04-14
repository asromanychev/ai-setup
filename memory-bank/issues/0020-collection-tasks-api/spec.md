# Spec — Issue #20: Collection Tasks API

## Scope

- Реализовать `POST /tasks`, `GET /tasks`, `GET /tasks/:id`, `POST /tasks/:id/consume`, `DELETE /tasks/:id`.
- `POST /tasks` создаёт `CollectionTask`, переводит его в `queued` и ставит `CollectionTaskSyncJob` в очередь.
- Для `collection_mode: webhook` `webhook_secret` генерируется автоматически и возвращается только в ответе `POST /tasks`.
- `GET /tasks/:id` и `GET /tasks` не показывают tasks в состоянии `deleted`.
- `POST /tasks/:id/consume` идемпотентен для `consumed` и `deleted`; для `ready + retain` переводит task в `consumed`, для `ready + delete` каскадно чистит данные и переводит task в `deleted`.
- `DELETE /tasks/:id` каскадно чистит данные и переводит task в `deleted`; повторный вызов по deleted даёт `404`.
- `GET /tasks` поддерживает фильтры `requester_id`, `state`, а также pagination через `after_id` и `limit`.

## Functional Requirements

- `FR-1` `CollectionTask` валидирует `collection_mode` только из множества `polling|webhook` и `source_config` как `Hash`.
- `FR-2` `POST /tasks` возвращает `201`, если task создан; при дубле `(requester_id, plugin_type, external_id)` возвращает `409 {"existing_task_id": N}`; при invalid params возвращает `422 {"errors":[...]}`.
- `FR-3` `POST /tasks` для `polling` требует `poll_interval_seconds > 0`; для `webhook` не требует его и включает в ответ `webhook_secret` длиной `64` hex-символа.
- `FR-4` `GET /tasks/:id` возвращает сериализованный task с `items_count`, но без `webhook_secret`; `deleted` трактуется как `404`.
- `FR-5` `POST /tasks/:id/consume` возвращает `200` для `ready`, `consumed`, `deleted`; для остальных состояний отдаёт `409` с текущим `state`.
- `FR-6` `DELETE /tasks/:id` очищает `raw_ingest_items` и `sync_checkpoint`, затем переводит task в `deleted`; `deleted` больше не попадает в `GET`.
- `FR-7` `GET /tasks` возвращает `{ tasks: [...], next_cursor: ... }`, применяет фильтры до pagination и по умолчанию скрывает deleted records.
- `FR-8` Все endpoints продолжают работать только под Bearer из `#19`.

## Invariants

- `INV-1` `webhook_secret` никогда не возвращается в `GET` endpoints.
- `INV-2` Операции consume/delete не оставляют частично очищенных зависимых данных.
- `INV-3` Deleted task недоступен через `GET /tasks/:id` и list API, но `consume` остаётся идемпотентным.

## Verification

- Focused: `bundle exec rspec spec/requests/tasks_api_spec.rb spec/models/collection_task_spec.rb spec/models/raw_ingest_item_spec.rb spec/models/sync_checkpoint_spec.rb`
- Regression: `bundle exec rspec`
