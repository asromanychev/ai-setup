# Spec — Issue #8: CollectionTaskSyncJob

## Scope

- Реализовать `CollectionTaskSyncJob` как оркестратор одного sync-step для `CollectionTask`.
- Job принимает только `task_id`.
- Job обязан работать поверх `CollectionTask`, `RawIngestItem`, `SyncCheckpoint`, `Collect::PluginRegistry`.
- Входит retry-логика для transient Telegram errors и immediate fail для permanent errors.
- Входит enqueue dedupe по `task_id`.
- Не входит cron/scheduler и startup-recovery.

## Preconditions

- `CollectionTask` из `#18` уже существует и поддерживает состояния `queued`, `collecting`, `ready`, `failed`.
- `Collect::TelegramPlugin` из `#7` уже умеет возвращать `records`, `checkpoint_out`, `finished`.
- `RawIngestItem.ingest!` идемпотентен по `(task_id, external_id)`.

## Functional Requirements

- `FR-1` `perform(task_id)` ищет `CollectionTask` по `id`; отсутствие task не считается ошибкой.
- `FR-2` В начале исполнения task переводится `queued -> collecting`; retry из `failed` очищает `last_error`.
- `FR-3` Job строит plugin через `Collect::PluginRegistry.default`.
- `FR-4` В plugin передаётся `source_config`, дополненный `collection_mode`; для Telegram polling `channel_username` может быть взят из `external_id`, если его нет в `source_config`.
- `FR-5` Успешный sync-step атомарно сохраняет `RawIngestItem` и `SyncCheckpoint`, затем переводит task в `ready`.
- `FR-6` Item external id берётся из `record[:message_id]`; metadata сохраняет `message_id`, `date`, `text`, `raw`.
- `FR-7` Telegram transient errors (`RateLimitError`, `TransientError`, `TimeoutError`, `ApiError` с кодом не `400/403`) не переводят task в `failed` до исчерпания лимита.
- `FR-8` `429` использует `retry_after`, если он доступен на исключении.
- `FR-9` После 5-й transient попытки task переводится в `failed`, а `last_error` фиксирует последнее сообщение ошибки.
- `FR-10` Telegram permanent errors (`400`, `403`), а также plugin contract/config errors завершают task в `failed` без retry.
- `FR-11` Повторный enqueue одного и того же `task_id` должен игнорироваться.

## Invariants

- `INV-1` Task не должен становиться `ready` без persisted checkpoint и без записи items в рамках того же successful path.
- `INV-2` `last_error` выставляется только при переходе в `failed`.
- `INV-3` Success после retry очищает старый `last_error`.
- `INV-4` Duplicate enqueue одного `task_id` не создаёт вторую независимую job в той же runtime-сессии.

## Acceptance Criteria

- [ ] Job принимает `task_id`, а не `source_id`.
- [ ] `queued -> collecting` происходит в начале исполнения.
- [ ] Success-path сохраняет items и checkpoint и завершает task в `ready`.
- [ ] `Telegram::RateLimitError(retry_after: N)` приводит к retry с задержкой `N`.
- [ ] `Telegram::ApiError(403)` немедленно завершает task в `failed`.
- [ ] После 5 transient попыток task становится `failed`.
- [ ] Повторный `perform_later(task.id)` не создаёт duplicate enqueue.
