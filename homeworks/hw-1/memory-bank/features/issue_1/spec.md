# Specification: Контракт `Collect::Plugin`, реестр плагинов и `NullPlugin`

**Issue:** https://github.com/asromanychev/ai-da-collect/issues/1
**Дата:** 2026-04-04
**Система генерации:** [CODEX]
**Основано на Brief:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/issue_1/brief.md`
**Связанный review:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/spec-review-issue_1.md`
**Связанные промежуточные решения:** `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/intermediate_solutions/git_issue_1/questions-and-decisions.md`

## Назначение

Фича вводит минимальное ядро plugin-based ingestion для `ai-da-collect v1`. Ядро должно дать единый контракт для выполнения одного шага синка источника, способ разрешать встроенные плагины по идентификатору и предоставлять `NullPlugin` как полностью локальную и детерминированную реализацию для unit/integration tests. Спецификация ограничена границей ядра и не включает сеть, Telegram, БД, S3 или фоновые задачи.

## Интерфейс

### Входные данные

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `plugin_id` | `String` или `Symbol` | да | Уникальный идентификатор плагина для разрешения через реестр |
| `source_config` | `Hash` | да | Конфигурация источника, передаваемая плагину |
| `checkpoint_in` | `Hash` или `nil` | нет | Последний checkpoint синка; `nil` означает первый запуск |
| `sync_request` | вызов одного шага синка | да | Команда на выполнение ровно одного шага синка |

### Выходные данные

| Параметр | Тип | Описание |
|----------|-----|----------|
| `plugin` | реализация `Collect::Plugin` | Плагин, разрешённый реестром по `plugin_id` |
| `records` | `Array` | Набор элементов, возвращённых за один шаг синка; может быть пустым |
| `checkpoint_out` | `Hash` | Новый структурированный checkpoint после выполнения шага |
| `finished` | `Boolean` | Признак, что текущий проход по источнику завершён |
| `error` | явная ошибка | Ошибка разрешения неизвестного плагина или нарушения контракта |

## Поведение

### Основной сценарий (Happy Path)
1. Реестр получает `plugin_id` и находит зарегистрированную реализацию плагина.
2. Плагин вызывается с `source_config`.
3. Один шаг синка принимает `checkpoint_in`, где checkpoint фиксируется как структурированный `Hash`.
4. Плагин возвращает результат шага, содержащий как минимум `records`, `checkpoint_out` и `finished`.
5. Вызывающий код может использовать `checkpoint_out` как вход в следующий шаг, не зная внутренней логики конкретного плагина.

### Граничные случаи
- Если `plugin_id` не зарегистрирован, реестр выбрасывает явную ошибку разрешения, пригодную для проверки в тестах.
- Если `checkpoint_in` равен `nil`, плагин обязан обработать это как первый запуск без аварии.
- Если в шаге синка нет новых данных, возвращается пустой `records`, валидный `checkpoint_out` и корректный `finished`.
- Если `checkpoint_in` имеет неподдерживаемую форму, плагин выбрасывает явную ошибку контракта.
- Если `source_config` отсутствует или не является `Hash`, создание или вызов плагина завершается явной ошибкой валидации.
- Для `NullPlugin` одинаковые `source_config` и `checkpoint_in` обязаны давать одинаковый результат.

### Запрещённое поведение
- Нельзя обращаться к сети, Telegram API, БД, S3 или Sidekiq в рамках `NullPlugin` и тестов ядра.
- Нельзя возвращать результат шага без `checkpoint_out`.
- Нельзя скрывать неизвестный `plugin_id` за `nil`, fallback-плагином или молчаливой подстановкой.
- Нельзя мутировать входной `checkpoint_in` на месте.
- Нельзя делать вызов синка зависимым от внешнего состояния, которое не передано через `source_config` и `checkpoint_in`.

## Критерии правильного результата
- [ ] Реестр разрешает зарегистрированный плагин по `plugin_id` и выдаёт тестируемую ошибку для неизвестного идентификатора.
- [ ] Контракт шага синка требует и документирует `source_config`, `checkpoint_in`, `records`, `checkpoint_out`, `finished`.
- [ ] `checkpoint` зафиксирован как структурированный `Hash`, а не opaque blob.
- [ ] `NullPlugin` возвращает детерминированный результат при одинаковых входных данных.
- [ ] Первый запуск с `checkpoint_in = nil` и сценарий пустого батча покрыты тестами.
- [ ] Покрытие тестами больше 80%.

## Зависимости
- В кодовой базе должно существовать место для ядра `Collect`.
- Должна быть доступна тестовая инфраструктура проекта.
- Следующий плагин источника должен подстраиваться под этот контракт, а не менять его неявно.

## Связанные документы
- Issue: https://github.com/asromanychev/ai-da-collect/issues/1
- Brief: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/issue_1/brief.md`
- Spec Review: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/spec-review-issue_1.md`
- Intermediate Decisions: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/intermediate_solutions/git_issue_1/questions-and-decisions.md`
- Plan: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/issue_1/plan.md`
