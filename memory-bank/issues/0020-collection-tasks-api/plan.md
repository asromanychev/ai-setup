# Plan — Issue #20: Collection Tasks API

## VibeContract

- Предусловие: `CollectionTask` и Bearer auth из `#18/#19` уже присутствуют; test env использует валидный `API_KEY`; схема содержит `collection_tasks`, `raw_ingest_items`, `sync_checkpoints`.
- Постусловие: сервис умеет создавать, читать, листить, consume и delete tasks по HTTP-контракту `C-1/C-5`; webhook secret одноразово выдаётся только при создании webhook-task; request specs покрывают happy-path и негативные сценарии.
- Инварианты: deleted tasks скрыты из GET; `consume/delete` очищают зависимые данные транзакционно; `#20` не реализует `/tasks/:id/items` и webhook routing.

## Steps

1. Расширить `CollectionTask` валидациями `collection_mode`, `source_config` и генерацией `webhook_secret`.
2. Добавить минимальный `CollectionTaskSyncJob`, чтобы `POST /tasks` реально ставил задачу в очередь без реализации логики `#8`.
3. Реализовать `TasksController` для create/index/show/consume/destroy, включая сериализацию, duplicate handling и deleted visibility rules.
4. Обновить `config/routes.rb` под полный lifecycle API.
5. Добавить request specs на все endpoints и исправить модельные спеки под актуальные `collection_mode`.
6. Focused verification:
   `bundle exec rspec spec/requests/tasks_api_spec.rb spec/models/collection_task_spec.rb spec/models/raw_ingest_item_spec.rb spec/models/sync_checkpoint_spec.rb`
7. Regression gate:
   `bundle exec rspec`
