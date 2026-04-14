# Brief — Issue #20: Collection Tasks API

После `#18` и `#19` в приложении уже есть `CollectionTask` и Bearer-защита для `/tasks*`, но сама HTTP-граница почти пустая: upstream-агент не может создать task, downstream не может узнать статус, зафиксировать consume или удалить собранные данные. Это блокирует основной MVP-флоу PRD v4 по контрактам `C-1` и `C-5`.

Наблюдаемый симптом: `GET /tasks` пока служит только auth-probe, а остальные lifecycle endpoints отсутствуют. Критерий успеха для `#20` — сервис отдаёт полный CRUD/lifecycle API для `CollectionTask`, корректно обрабатывает дубли, invalid input, deleted/consumed semantics и не раскрывает `webhook_secret` за пределами `POST /tasks`.
