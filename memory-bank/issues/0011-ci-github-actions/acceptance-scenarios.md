# Acceptance Scenarios — Issue #11

**Сценарий 1: CI поднимает app-level test stack**
- Дано: PR с изменением в `app/models` или `spec/models`.
- Когда: GitHub запускает `CI`.
- Тогда: job `rspec` поднимает PostgreSQL и Redis, выполняет `rails db:prepare`, затем `bundle exec rspec spec`.
- Как проверить: лог job содержит service containers, шаг `Prepare test database` и полный запуск `rspec spec`.

**Сценарий 2: Линтер и security checks отделены**
- Дано: PR с нарушением стиля или уязвимой зависимостью.
- Когда: GitHub запускает `CI`.
- Тогда: падает соответствующий job (`lint` или `security`) без смешивания с тестовым рантаймом.
- Как проверить: в workflow есть отдельные jobs и отдельные failing steps.

**Сценарий 3: Dockerfile валидируется до merge**
- Дано: PR меняет `Dockerfile`.
- Когда: GitHub запускает workflow доставки.
- Тогда: образ собирается без push; ошибка сборки блокирует merge.
- Как проверить: в PR есть workflow run c build step и без шага push в registry.

**Сценарий 4: Main публикует image**
- Дано: commit попал в `main`.
- Когда: запускается workflow доставки.
- Тогда: образ публикуется в GHCR с tag по SHA и `latest`.
- Как проверить: лог содержит login в `ghcr.io`, metadata tags и push step.

**Сценарий 5: Документация не обещает несуществующий deploy**
- Дано: новый разработчик читает README.
- Когда: он смотрит раздел про CI/CD.
- Тогда: он видит, что GitHub сейчас довозит контейнерный артефакт до GHCR, но production deploy не автоматизирован.
- Как проверить: README содержит явное текстовое ограничение.

