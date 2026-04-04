# Implementation Plan: Контракт `Collect::Plugin`, реестр плагинов и `NullPlugin`

**Issue:** https://github.com/asromanychev/ai-da-collect/issues/1
**Дата:** 2026-04-04
**Система генерации:** [CODEX]
**Основано на Spec:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/spec.md`
**Связанный review:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/plan-review-001.md`
**Связанные промежуточные решения:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/intermediate_solutions/git_issue_1/questions-and-decisions.md`

## Файловая структура

Создать или изменить:
- `core/lib/collect.rb`
- `core/lib/collect/errors.rb`
- `core/lib/collect/plugin.rb`
- `core/lib/collect/plugin_registry.rb`
- `core/lib/collect/null_plugin.rb`
- `spec/spec_helper.rb`
- `spec/core/collect/plugin_contract_spec.rb`
- `spec/core/collect/plugin_registry_spec.rb`
- `spec/core/collect/null_plugin_spec.rb`
- `spec/core/collect/registry_null_plugin_integration_spec.rb`
- `core/README.md`
- `.github/workflows/ci.yml`
- `README.md`

## Задачи (в порядке выполнения)

### Задача 1: Подготовить каркас ядра `Collect`
- Файл: `core/lib/collect.rb`, `core/lib/collect/errors.rb`
- Что делаем: создать namespace `Collect`, определить минимальные ошибки контракта и ошибки разрешения плагина, подключить компоненты ядра.
- Тест: smoke-проверка загрузки `Collect` и доступности базовых ошибок.
- Зависит от: ничего.

### Задача 2: Зафиксировать контракт `Collect::Plugin`
- Файл: `core/lib/collect/plugin.rb`, `core/README.md`
- Что делаем: описать интерфейс плагина, требования к `source_config`, семантику `checkpoint_in`, структуру результата одного шага синка и запрет на мутацию входного checkpoint.
- Тест: unit-тесты на обязательные поля результата и явные ошибки при невалидных входных данных.
- Зависит от: Задача 1.

### Задача 3: Реализовать реестр плагинов
- Файл: `core/lib/collect/plugin_registry.rb`
- Что делаем: реализовать регистрацию и разрешение плагинов по `plugin_id`, гарантировать отсутствие fallback-логики и наличие тестируемой ошибки для неизвестного идентификатора.
- Тест: unit-тесты на регистрацию, успешное разрешение и ошибку для неизвестного `plugin_id`.
- Зависит от: Задача 2.

### Задача 4: Реализовать `NullPlugin`
- Файл: `core/lib/collect/null_plugin.rb`
- Что делаем: реализовать детерминированный плагин для тестов, который работает только на локальных входных данных, обрабатывает `checkpoint_in = nil`, умеет возвращать пустой батч и формирует валидный `checkpoint_out`.
- Тест: unit-тесты на первый запуск, повторный запуск, пустой батч, `finished` и детерминированность результата.
- Зависит от: Задача 2.

### Задача 5: Зарегистрировать встроенный `NullPlugin`
- Файл: `core/lib/collect/plugin_registry.rb`, `core/lib/collect/null_plugin.rb`
- Что делаем: определить стабильный `plugin_id` для `NullPlugin`, зарегистрировать его как встроенный и проверить согласованность контракта и реестра.
- Тест: интеграционный тест разрешения `NullPlugin` через реестр и выполнения одного шага синка end-to-end.
- Зависит от: Задача 3, Задача 4.

### Задача 6: Настроить test harness и coverage
- Файл: `spec/spec_helper.rb`, `spec/core/collect/*.rb`
- Что делаем: организовать изолированную тестовую инфраструктуру для ядра без внешних сервисов и добавить контроль покрытия больше 80%.
- Тест: запуск всего набора core-specs одной командой и получение отчёта покрытия.
- Зависит от: Задача 1.

### Задача 7: Обновить CI и документацию
- Файл: `.github/workflows/ci.yml`, `README.md`, `core/README.md`
- Что делаем: добавить workflow для запуска core-specs и обновить документацию по текущему vertical slice.
- Тест: CI-конфигурация валидна, README содержит команду запуска и описание фичи.
- Зависит от: Задача 5, Задача 6.

## Тесты
- Unit-тесты: ошибки контракта, структура результата синка, валидация входов, реестр, `NullPlugin`.
- Интеграционные тесты: реестр + `NullPlugin` + один шаг синка без внешних зависимостей.
- Ожидаемое покрытие: >80%.

## CI/CD
- [ ] Добавить GitHub Actions workflow для `RSpec`-набора ядра.
- [ ] Добавить badge в `README.md`.

## Критерии завершения
- [ ] Все задачи выполнены.
- [ ] Тесты проходят.
- [ ] Покрытие >80%.
- [ ] CI зелёный.

## Связанные документы
- Issue: https://github.com/asromanychev/ai-da-collect/issues/1
- Brief: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/brief.md`
- Spec: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/spec.md`
- Plan Review: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/plan-review-001.md`
- Intermediate Decisions: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/intermediate_solutions/git_issue_1/questions-and-decisions.md`
