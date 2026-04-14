# Acceptance Scenarios — Issue #21

**Сценарий 1: Первая страница от начала потока**
- Дано: в `CollectionTask` со state `ready` есть минимум 3 `raw_ingest_items`.
- Когда: выполнить `curl -H "Authorization: Bearer test-api-key" "http://127.0.0.1:3000/tasks/<TASK_ID>/items?after_id=0&limit=2"`.
- Тогда: ответ `200`, внутри `items` два первых item по возрастанию `id`, а `next_cursor` равен id второго item.
- Как проверить: сверить JSON и выполнить `bundle exec rails runner 'task = CollectionTask.find(<TASK_ID>); puts task.raw_ingest_items.order(:id).limit(2).pluck(:id).inspect'`.

**Сценарий 2: Повторный запрос с тем же курсором**
- Дано: task и items из сценария 1 не менялись.
- Когда: выполнить тот же `curl` второй раз с тем же `after_id` и `limit`.
- Тогда: JSON идентичен предыдущему ответу.
- Как проверить: сравнить оба ответа побайтно или через `jq -S`.

**Сценарий 3: Переход на следующую страницу и конец потока**
- Дано: известен `next_cursor` из предыдущего ответа.
- Когда: вызвать `GET /tasks/<TASK_ID>/items?after_id=<NEXT_CURSOR>&limit=2` до тех пор, пока поток не закончится.
- Тогда: каждая следующая страница содержит только items с `id > after_id`, а финальный запрос возвращает `{"items":[],"next_cursor":null}`.
- Как проверить: сравнить с `bundle exec rails runner 'task = CollectionTask.find(<TASK_ID>); puts task.raw_ingest_items.order(:id).pluck(:id).inspect'`.

**Сценарий 4: Невалидные query params**
- Дано: существующий task.
- Когда: вызвать `GET /tasks/<TASK_ID>/items?after_id=-1` и `GET /tasks/<TASK_ID>/items?limit=1001`.
- Тогда: оба ответа имеют статус `422` и содержат текстовые ошибки в `errors`.
- Как проверить: убедиться, что status `422`, а тело содержит `After id must be an integer greater than or equal to 0` и `Limit must be an integer between 1 and 1000`.

**Сценарий 5: Deleted task скрыт**
- Дано: task переведён в `deleted`.
- Когда: вызвать `GET /tasks/<TASK_ID>/items`.
- Тогда: сервис возвращает `404 {"error":"Not Found"}` и не раскрывает items.
- Как проверить: `bundle exec rails runner 'task = CollectionTask.find(<TASK_ID>); puts task.state'` должен показать `deleted`.
