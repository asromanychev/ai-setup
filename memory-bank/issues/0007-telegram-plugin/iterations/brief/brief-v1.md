# Brief v1 — Issue #7

После появления `Telegram::ChannelClient` и нового домена `CollectionTask` в системе всё ещё отсутствует слой `Collect::Plugin`, который превращает Telegram-specific fetch в общий контракт ядра `{ records:, checkpoint_out:, finished: }`. Из-за этого task с `plugin_type: "telegram"` не может быть исполнен через реестр плагинов ни в polling, ни в webhook режиме.

Критерий успеха: в реестре появляется Telegram plugin, который читает bot token из ENV по имени из `source_config`, возвращает DTO без записи в БД, поддерживает оба режима сбора и сохраняет checkpoint домена Telegram через `last_message_id` / `last_date`.
