# Plan — Issue #11: GitHub CI hardening and delivery baseline

## 1. Порядок работ

1. Обновить `config/ci.rb`, чтобы локальный `bin/ci` отражал реальный quality gate проекта.
2. Переписать `.github/workflows/ci.yml`: concurrency, permissions, lint/security, DB-backed `rspec`.
3. Добавить новый workflow доставки container artifact через GHCR.
4. Обновить README под новый CI/CD контур и границы auto-deploy.
5. Прогнать доступную локальную валидацию: YAML parsing, Ruby syntax, релевантные specs/CI команды.

## 2. Инварианты

- CI не должен больше ограничиваться только `spec/core/collect`.
- Delivery workflow не должен притворяться production deploy.
- Изменения не должны трогать текущие feature-правки пользователя вне CI/CD-файлов и issue-артефактов.

## 3. Целевые файлы

- `.github/workflows/ci.yml`
- `.github/workflows/delivery.yml`
- `config/ci.rb`
- `README.md`

