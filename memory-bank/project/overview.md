# Обзор проекта ai-da-collect

Каноническое описание продукта и стека для агентов (перенесено из корневого `CLAUDE.md`).

## Что это

Сервис сбора и ingestion данных из внешних источников (плагинная архитектура). Первый плагин — **ai-da-collect-telegram** (публичные Telegram-каналы).

## Стек

| Слой | Выбор |
|------|--------|
| Language | Ruby 3.4 |
| Framework | Rails API-only |
| Database | PostgreSQL — метаданные, чекпойнты, ключи идемпотентности |
| Object storage | S3-compatible — сырые payload и вложения; в PG только ссылки |
| Background jobs | Sidekiq (Redis) через ActiveJob |
| Deploy | Docker-first, конфигурация через ENV |

## Архитектура (логические слои)

- **Core** — контракт плагинов, оркестрация sync/incremental, checkpoint, retry
- **Plugins** — изолированные модули по источнику (`plugins/`)
- **Clients** — HTTP/SDK к внешним API, только fetch + маппинг в сырой формат
- **Jobs** — сетевые и длительные проходы по источникам

Сервис **не** делает: нормализацию, embeddings, RAG, ИИ-анализ.

## Команды

- `make install` — установить зависимости (mise install)
- `make check` — проверить окружение

Дополнительно для разработки и CI см. корневой `README.md` (`bundle install`, `bundle exec rspec`, `bin/ci`).

## Ссылки на документацию

- Архитектура: `aitlas/ai-da-collect/conventions/docs/architecture.md`
- Правила Cursor: `aitlas/ai-da-collect/cursor/rules/`
- Функциональность по источникам: `aitlas/ai-da-collect/features/`

## Ограничения

- Не коммитить секреты и учётные данные — конфиг только через ENV
- Плагины изолированы: не тянуть зависимости плагина в ядро
- Клиенты/адаптеры — только fetch + маппинг, без бизнес-логики
