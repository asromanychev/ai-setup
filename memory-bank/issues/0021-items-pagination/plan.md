# Plan — Issue #21: Items Cursor Pagination

## VibeContract

- Предусловие: `CollectionTask` и `RawIngestItem` уже живут на новой схеме из `#18`, `TasksController` из `#20` существует, Bearer auth из `#19` включён, индекс `index_raw_ingest_items_on_task_id_and_id` присутствует в `db/schema.rb`.
- Постусловие: downstream может читать `raw_ingest_items` по `GET /tasks/:id/items` через `after_id/limit`, получать `next_cursor`, отличать конец потока от ошибок и продолжать чтение с любого валидного курсора.
- Инварианты: endpoint read-only; deleted task остаётся невидимым; невалидные query params не деградируют в молчаливые default values; query использует `(task_id, id)` вместо полного скана.

## Steps

1. Расширить `config/routes.rb` новым member route `GET /tasks/:id/items` без изменения существующего lifecycle API.
2. Добавить в `TasksController` action `items`, переиспользуя visibility rule для existing/non-deleted task.
3. Реализовать строгий parser query params: `after_id >= 0`, `limit ∈ 1..1000`, `422` при invalid input.
4. Построить query по `@task.raw_ingest_items.order(:id).where("id > ?", after_id).limit(limit + 1)` и сериализацию `{items, next_cursor}`.
5. Добавить request specs на happy path с минимум 3 страницами, стабильность повторного запроса, конец потока, invalid params, `404` и `EXPLAIN` по индексу.
6. Focused verification:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/requests/tasks_api_spec.rb`
7. Regression gate:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec`
