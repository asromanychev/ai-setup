# Spec Draft v1

`GET /tasks/:id/items` должен принимать `after_id` и `limit`, возвращать items по возрастанию `id`, скрывать deleted task и давать `422` на invalid query params. Конец потока выражается пустым массивом items, а наличие следующей страницы — `next_cursor`.
