# Acceptance Scenarios — Issue #19

**Сценарий 1: `/tasks` без Bearer**
- Дано: приложение запущено с `API_KEY=test-api-key`
- Когда: выполнить `GET /tasks` без заголовка `Authorization`
- Тогда: ответ `401` и JSON `{"error":"Unauthorized"}`
- Как проверить: `bundle exec rspec spec/requests/api_authentication_spec.rb`

**Сценарий 2: `/tasks` с неверным Bearer**
- Дано: приложение запущено с `API_KEY=test-api-key`
- Когда: выполнить `GET /tasks` с `Authorization: Bearer wrong-token`
- Тогда: ответ `401`
- Как проверить: focused request spec

**Сценарий 3: `/tasks` с валидным Bearer**
- Дано: приложение запущено с `API_KEY=test-api-key`
- Когда: выполнить `GET /tasks` с `Authorization: Bearer test-api-key`
- Тогда: ответ `200` и JSON `{"tasks":[]}`
- Как проверить: focused request spec

**Сценарий 4: `/health` публичный**
- Дано: приложение запущено
- Когда: выполнить `GET /health` без Bearer
- Тогда: ответ `200 {"status":"ok"}`
- Как проверить: focused request spec

**Сценарий 5: `/webhooks/telegram/:secret` не требует Bearer**
- Дано: приложение запущено
- Когда: выполнить `POST /webhooks/telegram/test-secret` без Bearer
- Тогда: ответ не `401` (в текущем placeholder-слое `404`)
- Как проверить: focused request spec

**Сценарий 6: secure compare**
- Дано: включён spy на `ActiveSupport::SecurityUtils.secure_compare`
- Когда: выполнить авторизованный `GET /tasks`
- Тогда: аутентификация использует `secure_compare`
- Как проверить: focused request spec

**Сценарий 7: фильтрация секретов**
- Дано: собран `ActiveSupport::ParameterFilter`
- Когда: пропустить через него `webhook_secret` и `api_key`
- Тогда: оба значения заменяются на `[FILTERED]`
- Как проверить: `bundle exec rspec spec/config/filter_parameter_logging_spec.rb`
