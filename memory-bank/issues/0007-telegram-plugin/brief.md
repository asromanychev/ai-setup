# Brief — Issue #7: Telegram Plugin

После `#6` в репозитории уже есть `Telegram::ChannelClient`, а после `#18` — новый домен `CollectionTask`, но между ними всё ещё нет плагина уровня `Collect::Plugin`. Из-за этого task с `plugin_type: "telegram"` не может выполнить ни polling-сбор, ни webhook-сбор в формате, который ждёт оркестратор PRD v4: массив DTO + checkpoint без прямой записи в БД.

Наблюдаемый симптом: `PluginRegistry.default` знает только `NullPlugin`, а Telegram-специфичная логика fetch+map отсутствует. Критерий успеха для `#7` — в кодовой базе появляется `Collect::TelegramPlugin`, зарегистрированный в реестре по `plugin_id = "telegram"`, читающий bot token из ENV по имени из `source_config[:bot_token_env]`, поддерживающий polling и webhook режимы, и возвращающий валидный plugin-result с DTO `{ message_id:, date:, text:, raw: }` и checkpoint с `last_message_id` / `last_date` без записи в БД.
