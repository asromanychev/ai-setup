# Spec v1 — Issue #7

См. активированный `spec.md`: он фиксирует два режима (`polling`, `webhook`), ENV resolution, DTO и расширенный checkpoint с обязательными `last_message_id` / `last_date` и internal `offset` для resume polling поверх уже существующего `ChannelClient`.
