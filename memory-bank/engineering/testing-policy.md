---
title: Testing Policy
doc_kind: engineering
doc_function: canonical
purpose: Testing policy репозитория — обязательность покрытия, sufficient coverage, manual-only gaps, simplify review.
derived_from:
  - ../dna/governance.md
  - ../WORKFLOW.md
status: active
audience: humans_and_agents
---

# Testing Policy

## Стек

- **Framework:** RSpec (`bundle exec rspec`)
- **Фабрики:** FactoryBot (`spec/factories/`)
- **CI:** `bin/ci` — обязателен к прохождению перед PR
- **Дополнительные команды:** `bundle exec rubocop` (code style)

## Core Rules

- Любое изменение поведения, которое можно проверить детерминированно, обязано получить automated regression coverage.
- Любой новый или изменённый contract (`Collect::Plugin`, API endpoint, schema) обязан получить contract-level automated verification.
- Любой bugfix обязан добавить regression spec на воспроизводимый сценарий.
- Tests считаются закрывающими риск только если проходят локально (`bin/ci`) и в CI (GitHub Actions).
- Manual-only verify допустим только как явное исключение, не заменяет automated coverage там, где automation реалистична.

## Ownership Split

- Canonical acceptance scenarios delivery-единицы задаются в `spec.md` через `SC-*`.
- `plan.md` владеет только стратегией исполнения: какие spec-файлы будут добавлены/обновлены, какие gaps временно manual-only и почему.

## Что считается Sufficient Coverage

- Покрыт основной changed behavior и ближайший regression path.
- Покрыты новые или изменённые contracts, endpoints, schema или integration boundaries.
- Покрыты критичные failure modes и негативные сценарии из `spec.md`.
- Процент line coverage недостаточен сам по себе: нужен scenario- и contract-level coverage.

## Структура тестов

- Новые unit specs → `spec/` с mirror-структурой к `lib/` или `app/`
- Integration specs, покрывающие несколько слоёв → `spec/integration/` или соответствующий раздел
- Плагины: тестировать через `Collect::NullPlugin` без сети и БД
- Клиенты (Telegram и др.): тестировать через VCR-кассеты или явные заглушки — без live вызовов

## Когда Manual-Only допустим

- Сценарий зависит от live Telegram API, внешних систем или недетерминированной среды
- Для каждого manual-only gap: зафиксировать причину, ручную процедуру и owner follow-up в `plan.md`

## Simplify Review

Отдельный проход после функционального тестирования, до closure:

- Проверить: premature abstraction, глубокая вложенность, дублирование логики, dead code
- Три похожие строки лучше преждевременной абстракции

## Verification Context Separation

1. **Functional verification** — specs проходят, acceptance scenarios покрыты
2. **Simplify review** — код минимально сложен
3. **Acceptance** — end-to-end по `SC-*` из spec

Для small issues допустимо в одной сессии, но simplify review не пропускается.
