# Cycle Analysis 1 — Issue #8

## Что сработало

- Scope `#8` хорошо лёг на уже готовый фундамент `#18 + #7`: job был действительно последним orchestration-layer, а не скрытым redesign всей модели.
- Runtime gates оказались достаточными, чтобы быстро отделить code-level ошибки от проблем окружения: после выхода из sandbox `db:prepare`, focused suite и full rspec подтвердили, что реализация рабочая.
- Ручная проверка на реальном Telegram-канале вскрыла не дефект job, а два transport/config нюанса: `bot_token_env` хранит **имя ENV-переменной**, и username в update приходит без обязательного `@`.

## Что оказалось хрупким

- Issue body требовал `sidekiq-unique-jobs`, но в repo не было ни gem dependency, ни существующей Redis-backed реализации. В результате был сделан in-process enqueue lock как временный суррогат. Это нормально как локальное решение, но pipeline должен раньше заставлять агента явно зафиксировать: "библиотека отсутствует, будет временное отклонение" вместо молчаливого смещения requirement.
- RUNBOOK для localhost-сервисов правильный, но из sandbox команды выглядели как реальный env blocker (`Operation not permitted`, `permission denied`). Без явного workflow-гейта агент почти зафиксировал ложный blocker на feature, хотя проблема была только в доступе к host services.
- Manual verification для внешнего API сначала проверяла только внутренний job-path. До отдельного `getUpdates` sanity-check было неочевидно, пустой ли upstream результат, не получает ли бот updates, или наш plugin неправильно фильтрует канал.

## Выводы

1. Для задач, где issue явно называет библиотеку или infra-механизм, этап Plan должен включать dependency reality check.
2. Для ручных проверок внешних интеграций нужен обязательный raw upstream sanity-check отдельно от plugin/job.
3. `run-instructions.md` должен сильнее акцентировать ENV indirection и канонические примеры входных идентификаторов, чтобы не терять время на конфиги вида `bot_token_env=<real secret>`.
