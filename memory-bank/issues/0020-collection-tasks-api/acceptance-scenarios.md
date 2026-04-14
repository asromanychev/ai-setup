# Acceptance Scenarios — Issue #20

**Сценарий 1: создание polling task**
- Дано: Bearer token валиден, в БД нет task с тем же `(requester_id, plugin_type, external_id)`.
- Когда: выполнить `POST /tasks` с `collection_mode=polling` и `poll_interval_seconds=300`.
- Тогда: ответ `201`, task создан со `state=queued`, job поставлен в очередь, `webhook_secret` отсутствует.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:35`

**Сценарий 2: создание webhook task**
- Дано: валидный Bearer token.
- Когда: выполнить `POST /tasks` с `collection_mode=webhook`.
- Тогда: ответ `201`, в теле есть одноразовый `webhook_secret`, а последующий `GET /tasks/:id` его не содержит.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:68`

**Сценарий 3: дубли и невалидные параметры**
- Дано: в БД уже есть task и/или запрос содержит пустые/некорректные поля.
- Когда: повторно вызвать `POST /tasks` с тем же ключом или передать invalid payload.
- Тогда: сервис возвращает `409 {"existing_task_id":...}` либо `422 {"errors":[...]}`.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:94 spec/requests/tasks_api_spec.rb:117`

**Сценарий 4: consume c retention retain**
- Дано: task находится в `ready`, retention=`retain`, есть связанные items.
- Когда: вызвать `POST /tasks/:id/consume`.
- Тогда: task переходит в `consumed`, `consumed_at` заполнен, данные остаются, повторный вызов остаётся `200`.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:166`

**Сценарий 5: consume c retention delete**
- Дано: task находится в `ready`, retention=`delete`, есть items и checkpoint.
- Когда: вызвать `POST /tasks/:id/consume`.
- Тогда: зависимые данные удалены, task переведён в `deleted`, повторный consume остаётся `200`, а `GET /tasks/:id` даёт `404`.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:186 spec/requests/tasks_api_spec.rb:156`

**Сценарий 6: consume в неподходящем state**
- Дано: task в состоянии `queued` или `collecting`.
- Когда: вызвать `POST /tasks/:id/consume`.
- Тогда: ответ `409` и тело содержит текущий `state`.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:210`

**Сценарий 7: force delete**
- Дано: task существует и имеет связанные items/checkpoint.
- Когда: вызвать `DELETE /tasks/:id`.
- Тогда: task получает `state=deleted`, связанные данные очищены, повторный delete возвращает `404`.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:223`

**Сценарий 8: list API**
- Дано: в БД есть tasks разных requester/state, одна из них deleted.
- Когда: вызвать `GET /tasks` с фильтрами `requester_id`, `state`, `after_id`, `limit`.
- Тогда: список отфильтрован и пагинирован по `id`, deleted task не попадает в выдачу.
- Как проверить: `bundle exec rspec spec/requests/tasks_api_spec.rb:248`
