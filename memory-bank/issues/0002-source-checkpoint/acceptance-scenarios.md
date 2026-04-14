# Acceptance Scenarios — Issue #0002

## SC-1: Source попадает в следующий sync

Given в БД есть source с `sync_enabled: true`  
And есть source с `sync_enabled: false`  
When выполняется `Source.for_sync`  
Then в результате присутствует только включённый source

## SC-2: Дубликат source отвергается

Given уже существует source с `plugin_type: "telegram"` и `external_id: "ch1"`  
When создаётся source с `plugin_type: :telegram` и `external_id: :ch1`  
Then операция завершается ошибкой уникальности

## SC-3: Checkpoint читается после сохранения

Given source без checkpoint  
When вызывается `upsert_checkpoint!(position: { cursor: 42 })`  
Then `source.sync_checkpoint.position["cursor"] == 42`

## SC-4: Повторный upsert не создаёт вторую строку

Given у source уже есть checkpoint `{ cursor: 42 }`  
When вызывается `upsert_checkpoint!(position: { cursor: 99 })`  
Then в таблице остаётся одна строка checkpoint  
And сохранённая позиция равна `99`

## SC-5: Пограничные значения position

Given source существует  
When создаётся checkpoint с `position: {}`  
Then запись сохраняется без ошибок

Given source существует  
When вызывается `upsert_checkpoint!(position: nil)`  
Then поднимается `ArgumentError`

## SC-6: Повреждённое состояние checkpoint не маскируется

Given для одного `source_id` материализованы две строки в `sync_checkpoints`  
When вызывается `source.sync_checkpoint`  
Then поднимается `Collect::CheckpointAmbiguityError`

## SC-7: Удаление source удаляет checkpoint

Given у source есть checkpoint  
When source удаляется  
Then связанный checkpoint отсутствует в БД
