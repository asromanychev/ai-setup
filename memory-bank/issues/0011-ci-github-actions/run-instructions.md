# Run Instructions — Issue #11

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

## Локально

1. Проверить синтаксис и YAML:
   ```sh
   bundle exec ruby -c config/ci.rb
   ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml"); YAML.load_file(".github/workflows/delivery.yml")'
   ```

2. Прогнать fast path без БД:
   ```sh
   bundle exec rspec spec/core/collect
   ```

3. Если локально доступна test DB:
   ```sh
   RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rails db:prepare
   RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec
   ```

## На GitHub

1. Открыть PR с любым изменением.
2. Убедиться, что `CI` запускает `lint`, `security`, `rspec`.
3. Убедиться, что `Delivery` на PR выполняет build без push.
4. После merge в `main` проверить, что `Delivery` публикует image в GHCR.

## Известные локальные блокеры

- В текущей сессии full suite локально не прошёл из-за недоступной test DB на `127.0.0.1` и отсутствия подготовленного локального test окружения.
- Это не блокирует GitHub workflow design, потому что в Actions PostgreSQL и Redis поднимаются как service containers.
