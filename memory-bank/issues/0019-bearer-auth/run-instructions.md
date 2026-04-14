# Run Instructions — Issue #19

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

## Prerequisites

- Поднять PostgreSQL из `docker-compose.yml`: `docker compose up -d postgres`
- Использовать:
  `RAILS_ENV=test`
  `API_KEY=test-api-key`
  `DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test`

## Focused Verification

```sh
/usr/bin/zsh -lc 'RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec spec/requests/api_authentication_spec.rb spec/config/filter_parameter_logging_spec.rb'
```

Ожидаемый результат: `7 examples, 0 failures`.

## Regression

```sh
/usr/bin/zsh -lc 'RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec'
```

Ожидаемый результат: `165 examples, 0 failures, 28 pending`.

## Manual Notes

- Boot без `API_KEY` должен падать на `config/initializers/api_key.rb`.
- `GET /tasks` используется здесь как минимальный auth probe; полный CRUD остаётся в `#20`.
