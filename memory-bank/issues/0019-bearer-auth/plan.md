# Plan — Issue #19: Bearer Auth

## VibeContract

- Предусловие: приложение загружается на Rails 8; `CollectionTask` уже существует после `#18`; `API_KEY` доступен в runtime/test ENV.
- Постусловие: `/tasks` требует Bearer token, `/health` и `/webhooks/*` не требуют Bearer, секреты фильтруются, boot без `API_KEY` невозможен.
- Инварианты: сравнение токенов идёт через `secure_compare`; `#20` не реализуется сверх минимального `GET /tasks`.

## Steps

1. Добавить fail-fast initializer `config/initializers/api_key.rb`.
2. Реализовать глобальную Bearer-аутентификацию в `app/controllers/application_controller.rb`.
3. Добавить минимальные контроллеры и маршруты для `GET /tasks`, `GET /health`, `POST /webhooks/telegram/:secret`.
4. Зафиксировать request-level сценарии plain RSpec через `ActionDispatch::Integration::Session`.
5. Проверить фильтрацию `webhook_secret` и `api_key`.
6. Focused verification:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/requests/api_authentication_spec.rb spec/config/filter_parameter_logging_spec.rb`
7. Regression gate:
   `RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec`
