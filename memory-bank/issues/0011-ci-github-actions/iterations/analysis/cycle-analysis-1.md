# Cycle Analysis 1

## Что обнаружено по аудиту

- Текущий GitHub CI создавал ложное чувство зелёности: app-level specs вообще не входили в workflow.
- Локальный `bin/ci` и GitHub `ci.yml` жили в разных мирах: локально был один quality gate, в GitHub другой.
- В репозитории уже есть production-oriented `Dockerfile`, но GitHub не валидировал и не доставлял контейнерный артефакт.

## Что исправлено

- CI расширен до lint + security + full RSpec suite c service containers.
- Локальный `config/ci.rb` синхронизирован по смыслу с GitHub CI.
- Добавлен delivery workflow: PR build-only, `main` publish to GHCR.
- README теперь явно описывает реальную границу CD.

## Что осталось вне скоупа

- Auto-deploy в production.
- Отдельный GitHub issue под CD не создан в этой сессии, потому что `gh auth status` вернул невалидный токен для аккаунта `asromanychev`.

## Вывод

Для текущего состояния проекта корректный «мощный CI/CD» на GitHub выглядит как:
- жёсткий CI для всего Rails/Ruby контура;
- delivery до container registry;
- явная остановка перед deploy, пока не появятся infra config и secrets.
