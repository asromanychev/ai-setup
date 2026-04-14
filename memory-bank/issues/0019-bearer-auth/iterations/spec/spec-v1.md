# Spec v1

Технический контракт:
- `API_KEY` обязателен на boot;
- `/tasks*` защищены Bearer auth;
- `/health` и `/webhooks/*` публичны;
- сравнение идёт через `secure_compare`;
- `api_key` и `webhook_secret` фильтруются;
- минимальный `GET /tasks` допустим как auth probe до `#20`.
