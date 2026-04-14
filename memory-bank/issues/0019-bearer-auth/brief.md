# Brief — Issue #19: Bearer Auth

`#19` вводит обязательную аутентификацию для всех `/tasks*` endpoints по заголовку `Authorization: Bearer <API_KEY>`. Без валидного токена сервис должен стабильно отвечать `401 {"error":"Unauthorized"}`, при этом публичные operational endpoints `/health` и `/webhooks/*` не должны ломаться из-за глобального auth-filter.

Проблема после `#18`: доменная модель `CollectionTask` уже появилась, но HTTP-граница ещё никак не защищена. Это делает будущие `/tasks*` endpoints небезопасными по контракту PRD C-6 и оставляет сервис без fail-fast проверки обязательного секрета на старте.
