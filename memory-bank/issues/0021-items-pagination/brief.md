# Brief — Issue #21: Items Cursor Pagination

После `#20` downstream-агент уже может создавать `CollectionTask`, смотреть lifecycle и завершать consume, но не может читать накопленные `raw_ingest_items` по стабильному курсору. Без этого буферизованный ingestion остаётся write-only: потребитель не может безопасно дочитывать поток страницами, прерываться и продолжать с последнего подтверждённого item id.

Наблюдаемый симптом: у `/tasks/:id` есть только `items_count`, а endpoint чтения items отсутствует. Критерий успеха для `#21` — сервис отдаёт `GET /tasks/:id/items` с stable cursor по `raw_ingest_items.id`, валидирует `after_id/limit`, скрывает deleted tasks и подтверждает использование индекса `(task_id, id)`.
