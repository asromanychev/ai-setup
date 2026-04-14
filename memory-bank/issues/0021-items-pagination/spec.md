# Spec — Issue #21: GET /tasks/:id/items

## Scope

- Реализовать `GET /tasks/:id/items?after_id=<bigint>&limit=<int>`.
- Stable cursor строится по `raw_ingest_items.id` внутри конкретного task.
- Endpoint доступен только для существующего и не-`deleted` `CollectionTask`.
- Response возвращает `items` и `next_cursor`; пустой `items: []` означает конец потока.
- Query должен идти по индексу `index_raw_ingest_items_on_task_id_and_id`.

## Functional Requirements

- `FR-1` `after_id` по умолчанию равен `0`; допустимы только целые значения `>= 0`; невалидные значения дают `422 {"errors":[...]}`.
- `FR-2` `limit` по умолчанию равен `100`; допустимы только целые значения в диапазоне `1..1000`; невалидные значения дают `422 {"errors":[...]}`.
- `FR-3` Endpoint возвращает items в порядке возрастания `raw_ingest_items.id` и применяет фильтр `id > after_id`.
- `FR-4` Каждый item сериализуется как `id`, `external_id`, `metadata`, `created_at`.
- `FR-5` `next_cursor` равен id последнего item на странице, только если существует следующая страница; иначе `null`.
- `FR-6` Повторный запрос с тем же `after_id` и `limit` возвращает идентичный результат, пока набор items не менялся.
- `FR-7` Если task не существует или находится в состоянии `deleted`, endpoint возвращает `404 {"error":"Not Found"}`.
- `FR-8` Bearer auth из `#19` продолжает защищать endpoint.

## Invariants

- `INV-1` Cursor pagination не меняет состояние task и не пишет в БД.
- `INV-2` Порядок items монотонен по `id`; курсор никогда не перескакивает назад.
- `INV-3` Endpoint не раскрывает поля вне read-contract items и не возвращает items для deleted task.

## Verification

- Focused: `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/requests/tasks_api_spec.rb`
- Regression: `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec`
