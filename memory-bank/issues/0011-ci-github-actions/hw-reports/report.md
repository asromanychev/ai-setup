# HW Report — Issue #11

## Изменения

- Обновлён `.github/workflows/ci.yml`: concurrency, permissions, lint/security/full rspec, PostgreSQL/Redis services.
- Добавлен `.github/workflows/delivery.yml`: PR build-only, publish to GHCR on `main`.
- Обновлён `config/ci.rb`: локальный CI теперь готовит test DB и запускает весь `spec`.
- Обновлён `README.md`: зафиксированы новые CI/CD правила и границы.

## Локальная валидация

- `bundle exec ruby -c config/ci.rb` — OK
- `ruby -e 'require "yaml"; ...'` для обоих workflow — OK
- `bundle exec rspec spec/core/collect` — 40 examples, 0 failures
- `bundle exec rspec spec` — локально blocked из-за недоступной test DB

## Блокеры

- `gh auth status` показывает невалидный токен, поэтому отдельный GitHub issue под CD в этой сессии не создан.
- Полноценный production deploy pipeline не реализован: нет deploy-конфига и секретного контракта.
