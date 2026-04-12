---
title: Configuration
doc_kind: engineering
doc_function: canonical
purpose: ENV contract, ownership модель конфигурации и naming conventions. Читать при добавлении новых ENV-переменных или изменении конфигурации.
derived_from:
  - ../dna/governance.md
  - ../project/overview.md
status: active
audience: humans_and_agents
---

# Configuration

## Ownership Model

- **Canonical source:** ENV-переменные (Docker / runtime environment).
- **Не коммитить** секреты и учётные данные в репозиторий.
- Для локальной разработки использовать `.env` файл (в `.gitignore`).
- Плагины конфигурируются через ENV; ядро не знает о деталях конфигурации плагинов.

## ENV Contract

### Core / Application

| Variable | Description | Required |
| --- | --- | --- |
| `DATABASE_URL` | PostgreSQL connection string | yes |
| `REDIS_URL` | Redis connection string (Sidekiq) | yes |
| `SECRET_KEY_BASE` | Rails secret key | yes |

### Telegram Plugin

| Variable | Description | Required |
| --- | --- | --- |
| `TELEGRAM_BOT_TOKEN` | Bot token для доступа к Telegram API | yes (для telegram plugin) |

### Storage (S3-compatible)

| Variable | Description | Required |
| --- | --- | --- |
| `S3_BUCKET` | Bucket name | MVP: stub, не загружается |
| `S3_ENDPOINT` | S3-compatible endpoint URL | MVP: stub |
| `AWS_ACCESS_KEY_ID` | Access key | MVP: stub |
| `AWS_SECRET_ACCESS_KEY` | Secret key | MVP: stub |

### Auth

| Variable | Description | Required |
| --- | --- | --- |
| `BEARER_TOKEN` | Bearer token для API аутентификации | yes |

## Naming Conventions

- Все переменные в `SCREAMING_SNAKE_CASE`.
- Плагин-специфичные переменные с префиксом плагина: `TELEGRAM_*`, `S3_*`.
- Секреты не хардкодить в коде — только ENV lookup.

## Примечание по MVP

S3-загрузка вложений — заглушка MVP. S3-переменные присутствуют в contract, но реальная загрузка не реализована до момента выхода за MVP.
