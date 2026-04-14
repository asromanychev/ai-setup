# Brief — Issue #8: CollectionTaskSyncJob

После `#7` и `#18` в системе уже есть `CollectionTask`, `SyncCheckpoint`, `RawIngestItem` и Telegram plugin, но фонового оркестратора всё ещё нет: `CollectionTaskSyncJob` остаётся stub и не переводит task через lifecycle, не сохраняет результат шага синка и не различает transient/permanent ошибки.

Из-за этого `POST /tasks` может поставить task в `queued`, но дальше жизненный цикл не продолжается: данные не собираются, checkpoint не обновляется, `last_error` не фиксируется, а retry semantics из PRD C-2 остаются нереализованными.

Критерий успеха: один job по `task_id` поднимает task в `collecting`, вызывает plugin с корректным `source_config`/checkpoint, атомарно сохраняет items + checkpoint, переводит task в `ready` на success, а на 429/timeout/5xx делает bounded retry; 400/403 и contract/config errors завершают task в `failed` с `last_error`.
