# Spec — Issue #19: Bearer Auth

## Scope

- Ввести обязательный `API_KEY` из ENV; boot без него должен завершаться исключением.
- Все запросы к `/tasks*` проходят через Bearer-аутентификацию.
- `/health` и `/webhooks/*` остаются публичными.
- Сравнение токенов выполняется через `ActiveSupport::SecurityUtils.secure_compare`.
- Секреты `webhook_secret` и `api_key` фильтруются из параметров логирования.
- Для runtime-проверки добавить минимальные реальные endpoints: `GET /tasks`, `GET /health`, `POST /webhooks/telegram/:secret`.

## Functional Requirements

- `FR-1` `config/initializers/api_key.rb` читает `ENV["API_KEY"]`, сохраняет значение в `Rails.configuration.x.api_key` и `raise`, если переменная пустая.
- `FR-2` `ApplicationController` содержит глобальный `before_action :authenticate!`.
- `FR-3` `authenticate!` пропускает только `/health` и пути под `/webhooks/`.
- `FR-4` Bearer-token извлекается только из заголовка `Authorization: Bearer ...`; пустой, отсутствующий или неверный токен даёт `401` и JSON `{"error":"Unauthorized"}`.
- `FR-5` Сравнение выполняется через `secure_compare` на SHA256-дижестах ожидаемого и переданного токена.
- `FR-6` `GET /tasks` с валидным Bearer возвращает `200`, не реализуя CRUD из `#20`; достаточно минимального JSON-контракта `{"tasks":[]}`.
- `FR-7` `GET /health` без Bearer возвращает `200 {"status":"ok"}`.
- `FR-8` `POST /webhooks/telegram/:secret` без Bearer не отвечает `401`; временно допустим `404` как placeholder до `#22`.
- `FR-9` `Rails.application.config.filter_parameters` скрывает `webhook_secret` и `api_key`.

## Invariants

- `INV-1` Bearer auth применяется только к `/tasks*`; публичные endpoints не зависят от `Authorization`.
- `INV-2` Отсутствие `API_KEY` обнаруживается на boot, а не при первом запросе.
- `INV-3` Секреты не должны появляться в plaintext в параметрах логирования.

## Verification

- Focused: `bundle exec rspec spec/requests/api_authentication_spec.rb spec/config/filter_parameter_logging_spec.rb`
- Regression: `bundle exec rspec`
