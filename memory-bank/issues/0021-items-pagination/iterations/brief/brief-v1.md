# Brief Draft v1

Downstream не может читать `raw_ingest_items` страницами после `#20`, потому что lifecycle API возвращает только `items_count`. Нужен read-only endpoint с курсором по `id`, чтобы агент мог безопасно возобновлять чтение потока без дублирования и без привязки к offset pagination.
