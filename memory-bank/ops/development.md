---
title: Development Environment
doc_kind: engineering
doc_function: canonical
purpose: Локальная разработка, установка зависимостей, запуск тестов и CI. Canonical source для dev-команд агента.
derived_from:
  - ../dna/governance.md
  - ../project/overview.md
status: active
audience: humans_and_agents
---

# Development Environment

## Setup

```bash
# Установить зависимости (mise управляет Ruby-версией)
make install   # или: mise install && bundle install

# Проверить окружение
make check
```

Для работы с БД нужен запущенный PostgreSQL и Redis (используй Docker Compose, если доступен):

```bash
docker compose up -d db redis
```

## Daily Commands

```bash
# Запустить core specs
bundle exec rspec spec/core/collect

# Запустить полный CI-скрипт (lint + тесты)
bin/ci

# Запустить конкретный spec-файл
bundle exec rspec spec/path/to/file_spec.rb
```

## Database

```bash
# Применить миграции
bundle exec rails db:migrate

# Проверить статус миграций
bundle exec rails db:migrate:status

# Пересоздать БД (development only)
bundle exec rails db:reset
```

## Staged Validation (6 стадий)

При проверке реализации агент прогоняет последовательно:

| # | Что | Команда |
|---|-----|---------|
| 1 | Файлы созданы | `ls <paths>` |
| 2 | Синтаксис OK | `bundle exec ruby -c <file>` |
| 3 | Приложение стартует | `bundle exec rails runner "puts 'ok'"` |
| 4 | Схема актуальна | `bundle exec rails db:migrate:status` |
| 5 | Тесты зелёные | `bundle exec rspec spec/...` |
| 6 | Данные сохраняются | команды из `run-instructions.md` |

Провал на любой стадии → стоп, исправить, повторить с этой же стадии.

## Known Pitfalls

- Плагины изолированы — не тянуть зависимости плагина в `core/`.
- Клиенты и адаптеры — только fetch + маппинг, без бизнес-логики.
- Секреты и учётные данные — только через ENV, не коммитить.
- Текущий блокер: схема БД на старой модели (`sources`), миграция на `collection_tasks` — issue **#18**.
