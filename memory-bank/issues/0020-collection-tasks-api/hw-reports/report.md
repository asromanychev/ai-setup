# HW Report — Issue #20

- Созданы канонические артефакты issue в `memory-bank/issues/0020-collection-tasks-api/`.
- Реализованы lifecycle endpoints для `CollectionTask` и минимальный enqueue через `CollectionTaskSyncJob`.
- Добавлены request specs и синхронизированы model specs с допустимыми `collection_mode`.
- Локальная верификация: `ruby -c`, `rails runner`, `rails routes`.
- Неполная часть: `rspec` не прогнан из-за отсутствующего подключения к PostgreSQL в текущем shell.
