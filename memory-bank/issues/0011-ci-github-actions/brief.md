# Brief — Issue #11: GitHub CI hardening and delivery baseline

## 1. Цель и проблема

В репозитории уже есть GitHub Actions, но текущий контур качества покрывает только малую часть реального риска:
- `test` job запускает только `spec/core/collect`;
- app-level specs (`spec/models`, `spec/services`, `spec/clients`) не входят в GitHub CI;
- тестовая БД и Redis в GitHub Actions не поднимаются;
- `bin/ci` и фактический GitHub workflow расходятся;
- GitHub-based delivery отсутствует: Dockerfile есть, Kamal gem есть, но нет workflow, который хотя бы валидирует и публикует release-ready image.

Из-за этого проект может получать зелёный badge при сломанной Rails-части, миграциях, моделях или контейнерной сборке.

## 2. Для кого

- Разработчики, которые открывают PR и ожидают реальный quality gate до merge.
- Оператор/владелец репозитория, которому нужен воспроизводимый путь от merge в `main` до готового container artifact.
- Будущие задачи фазы 7, которые начнут добавлять API, jobs, healthchecks и больше Rails-кода.

## 3. Доменный контекст

Для этого репозитория CI/CD на GitHub должен решать две разные задачи:
- `CI`: быстро и воспроизводимо ловить дефекты в Ruby/Rails коде, миграциях, зависимостях и security checks.
- `CD`: после merge в `main` собирать и доставлять проверяемый контейнерный артефакт, не притворяясь production deploy там, где ещё нет инфраструктурного конфига.

Текущая реальность проекта:
- есть `Dockerfile` production-ориентированной сборки;
- есть `bin/ci` и `config/ci.rb`;
- нет `config/deploy.yml` / Kamal deploy-контура;
- нет подтверждённого набора GitHub Secrets для production deployment.

## 4. Ограничения

- Нельзя ломать существующие локальные workflows разработки.
- Нельзя обещать полноценный production deploy без deploy-конфига и секретов.
- Нельзя затирать текущие пользовательские изменения в worktree.
- Решение должно работать на GitHub-hosted runners без приватной инфраструктуры.

## 5. Критерий успеха

- GitHub CI проверяет весь актуальный тестовый контур проекта, а не только `core`.
- GitHub workflow поднимает PostgreSQL/Redis и готовит test DB.
- Контейнерная сборка валидируется на PR, а на `main` публикуется артефакт в GitHub Container Registry.
- README объясняет, что именно проверяется в CI и где заканчивается текущий CD-контур.
- Отсутствие полноценного auto-deploy задокументировано как осознанное ограничение, а не скрытая дыра.

## 6. Вне скоупа

- Production deploy через Kamal/SSH.
- Управление production secrets и infrastructure provisioning.
- Preview environments.
- Автоматические миграции production базы.

