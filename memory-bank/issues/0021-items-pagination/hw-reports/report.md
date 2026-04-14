# HW Report — Issue #21

- Реализован `GET /tasks/:id/items` с query params `after_id` и `limit`.
- Добавлена строгая валидация query params с `422` вместо silent clamping.
- Request specs покрывают 3 страницы данных, stable cursor, конец потока, `404` и прямой `EXPLAIN` по индексу `(task_id, id)`.
- Проверка: `spec/requests/tasks_api_spec.rb` зелёный; полный `rspec` зелёный (`203 examples, 0 failures, 28 pending`).
