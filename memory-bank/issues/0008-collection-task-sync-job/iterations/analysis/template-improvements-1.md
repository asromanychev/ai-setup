# Template Improvements 1 — Issue #8

Применённые изменения в `memory-bank/issues/MAKE_NEW_ISSUE.md`:

1. **Dependency reality check в Plan**
   - Добавлено правило: если issue требует конкретную библиотеку / инфраструктурный механизм по имени, план обязан явно зафиксировать: dependency уже есть / нужно добавить / будет временное отклонение.
   - Причина: `#8` требовал `sidekiq-unique-jobs`, но repo его не содержал; это надо было поднимать как явное решение уже на этапе Plan.

2. **Host vs sandbox verification gate в Staged Validation**
   - Добавлено правило: localhost/Docker ошибки из sandbox не считаются автоматическим feature blocker до повторной проверки теми же командами с host privileges / escalation.
   - Причина: `db:prepare`, `pg_isready`, `redis-cli` и `docker` сначала выглядели как env blocker, хотя host services реально были доступны.

3. **Upstream sanity-check и config examples в Run Instructions**
   - Добавлено требование включать raw external API check для внешних интеграций.
   - Добавлены правила про ENV indirection и канонические примеры чувствительных identifier formats.
   - Причина: ручной Telegram verify потребовал отдельный `getUpdates`, а также явное различение `"TELEGRAM_BOT_TOKEN"` vs actual token и `aidates1` vs `@aidates1`.

Что сознательно не менялось:

- Общая структура cycle-analysis/template-improvements уже адекватна и не требовала правок.
- Правила про test DB pollution уже были встроены после `#18`; дублировать их не пришлось.
