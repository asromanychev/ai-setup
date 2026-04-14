# Spec — Issue #11: GitHub CI hardening and delivery baseline

## 1. Цель решения

Усилить GitHub Actions так, чтобы репозиторий получал:
- полноценный CI для Ruby/Rails кода, включая DB-backed specs;
- проверку production container build на PR;
- публикацию container image в GHCR после push в `main`;
- явную документацию по границам текущего CD.

## 2. Scope

- `REQ-1` Обновить `.github/workflows/ci.yml`, чтобы CI запускал lint, security checks и полный RSpec-контур проекта.
- `REQ-2` В `ci.yml` поднять PostgreSQL и Redis services, задать `DATABASE_URL`/`REDIS_URL`, выполнить `rails db:prepare`.
- `REQ-3` Синхронизировать локальный `bin/ci` / `config/ci.rb` с новым quality gate, чтобы локальный и GitHub контуры не расходились по смыслу.
- `REQ-4` Добавить отдельный workflow доставки container artifact на GitHub: PR должен валидировать `Dockerfile`, `main` должен публиковать image в GHCR.
- `REQ-5` Обновить README: что именно покрывает CI, как работает delivery, и почему production deploy пока не автоматизирован.

- `NS-1` Не входит: production deploy через Kamal.
- `NS-2` Не входит: coverage badge через внешний сервис.
- `NS-3` Не входит: matrix по нескольким версиям Ruby/PostgreSQL.

## 3. Функциональные требования

### FR-1. CI workflow

`ci.yml` должен:
- запускаться на `pull_request` и `push` в `main`;
- отменять устаревшие запуски по той же ветке;
- иметь `permissions: contents: read`;
- иметь отдельные jobs как минимум для `lint`, `security`, `rspec`.

### FR-2. RSpec job

RSpec job должен:
- использовать `ubuntu-latest`;
- поднимать `postgres:16-alpine` и `redis:7-alpine` как services;
- задавать `RAILS_ENV=test`;
- задавать `DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test`;
- задавать `REDIS_URL=redis://127.0.0.1:6379/1`;
- выполнять `bundle exec rails db:prepare`;
- выполнять `bundle exec rspec spec`.

### FR-3. Local CI parity

`config/ci.rb` должен:
- сохранять существующие style/security checks;
- подготавливать test DB;
- запускать `bundle exec rspec spec`, а не только `spec/core/collect`.

### FR-4. Delivery workflow

Новый workflow должен:
- запускаться на `pull_request`, `push` в `main` и `workflow_dispatch`;
- на PR выполнять только сборку image без публикации;
- на `main` логиниться в GHCR через `GITHUB_TOKEN` и публиковать image;
- использовать `docker/metadata-action` для тегов минимум по `sha` и `latest` на default branch;
- использовать Buildx и cache через GitHub Actions cache backend.

### FR-5. Documentation

README должен:
- описывать, что GitHub CI теперь покрывает lint/security/full RSpec;
- объяснять, что GitHub CD сейчас заканчивается на release-ready image в GHCR;
- явно фиксировать, что auto-deploy не настроен из-за отсутствия deploy-конфига и секрета/инфраструктуры.

## 4. Сценарии и ошибки

- `SC-1` PR ломает model spec: `rspec` job падает.
- `SC-2` PR ломает `Dockerfile`: delivery workflow падает на build step до merge.
- `SC-3` `main` получает зелёный delivery workflow: в GHCR публикуется новый image tag.
- `SC-4` В репозитории нет production deploy-конфига: документация не обещает auto-deploy и не создаёт ложное ожидание.

## 5. Acceptance Criteria

- `CHK-1` В `.github/workflows/ci.yml` есть jobs для lint, security и rspec.
- `CHK-2` `rspec` job поднимает PostgreSQL и Redis и выполняет `rails db:prepare`.
- `CHK-3` В `config/ci.rb` локальный CI запускает `bundle exec rspec spec`.
- `CHK-4` В репозитории есть отдельный delivery workflow с PR build и publish на `main`.
- `CHK-5` README описывает новый CI/CD контур и его границы.

