# Plan Draft v1

1. Добавить route `GET /tasks/:id/items`.
2. Расширить `TasksController` action `items` и parser query params.
3. Реализовать read-only query по `raw_ingest_items` с `limit + 1`.
4. Добавить request specs на pagination, validation, `404` и `EXPLAIN`.
5. Прогнать focused verification и regression gate.
