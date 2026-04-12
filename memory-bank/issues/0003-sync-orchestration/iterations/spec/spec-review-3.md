---
name: Sync Orchestration Spec Review 3
description: TAUS-ревью спецификации one-step sync orchestration для issue 0003
type: draft
status: draft
issue: 0003-sync-orchestration
reviews: spec-v3
---

# Spec Review: One-Step Sync Orchestration (Issue #0003)

Проверена спецификация `spec-v3.md`.

## Вердикты по критериям

### 1. T (Testable): Pass

Acceptance Criteria остаются проверяемыми: они фиксируют наблюдаемое поведение на границе `Source#sync_step!`, включая передачу `plugin_type/source_config`, чтение persisted checkpoint, сохранение `checkpoint_out`, откат при ошибках и изоляцию разных `Source`. По каждому AC можно написать unit/model spec без обращения к сети.

### 2. A (Ambiguous-free): Pass

Критичные расплывчатые слова из требований убраны. Для result-контракта и checkpoint semantics документ использует falsifiable формулировки: обязательные ключи, допустимые типы, `{}` vs `nil`, поведение при ошибке и stop condition для внешнего prerequisite.

### 3. U (Uniform): Fail

**Цитата из спеки:** `Source#sync_step!(plugin_registry:, source_config:) принимает объект plugin_registry, который отвечает на build(plugin_type, source_config:), и source_config как Hash.`  
**Цитата из спеки:** `plugin_registry.build(plugin_type, source_config:) должен либо вернуть plugin object, который отвечает на sync_step(checkpoint_in:), либо пробросить исходное исключение без оборачивания со стороны Source#sync_step!.`

**Проблема для AI-агента:** спецификация хорошо покрывает boundary cases для `plugin result`, но не материализует constructor-time boundary cases для входного `source_config`, хотя по правилам ревью их нужно проверять отдельно. Сейчас нет явного сценария и AC для случая, когда `source_config` не соответствует ожиданиям plugin constructor и `build` падает из-за валидации конфигурации. Формально это можно попытаться подвести под общий кейс `plugin_registry.build` raises, но агенту всё ещё приходится догадываться, является ли invalid config частью обязательного поведения текущей фичи или это вне scope. Для `U (Uniform)` этого недостаточно: внешний входной режим должен быть описан явно, а не подразумеваться через общий error bucket.

**Вариант исправления:** добавить в `Сценарии ошибок и состояния` и в `Acceptance Criteria` отдельный кейс уровня конструктора, например:
- если `source_config` не проходит валидацию plugin constructor во время `plugin_registry.build`, исходное исключение пробрасывается без оборачивания;
- persisted checkpoint остаётся прежним;
- `Source#sync_step!` не делает дополнительных попыток нормализации или восстановления конфигурации.

### 4. S (Scoped): Pass

Документ по-прежнему описывает одну фичу, а объём `spec-v3.md` составляет 1499 слов, что укладывается в лимит меньше 1500 слов.

### 5. Scope явно ограничен: Pass

Разделы `Scope` и `Preconditions` явно отделяют содержимое текущего issue от запрещённого: нет расширения в scheduler/API/bootstrap, а внешний runtime prerequisite вынесен в stop condition.

### 6. Инварианты перечислены: Pass

Инварианты перечислены явно, и у каждого есть falsifiable опора в сценариях или AC:
- атомарность и отсутствие частичного прогресса покрыты ошибками `build`, `sync_step`, `upsert_checkpoint!`;
- использование актуальной persisted позиции покрыто кейсами с существующим и отсутствующим checkpoint;
- изоляция источников и независимость от класса покрыты отдельными сценариями и AC.

### 7. Grounding и реализуемость: Pass

Grounding теперь привязан к реальным файлам проекта и честно фиксирует внешний prerequisite: `core/lib` доступен в spec-runtime через `spec/rails_helper.rb` и `spec/spec_helper.rb`, а отсутствие такого prerequisite в application runtime оформлено как явный stop condition, а не скрытое допущение.

## Дополнительные scope-gate проверки

### Module-budget: Pass

Спецификация укладывается в допустимый бюджет модульных зон:
- `app/models`
- `core/lib`
- `spec`

Ссылка на `config/application.rb` используется как grounding для runtime-факта, а не как зона изменений в рамках текущей фичи.

### Precondition hygiene: Pass

Внешний prerequisite теперь оформлен корректно: раздел `Preconditions и stop condition` явно говорит, при каком условии реализация продолжается и когда задача должна быть остановлена как отдельный infrastructure follow-up.

## Итог

1 замечание. Спецификация требует ещё одной доработки перед реализацией.

Fail-критерии:
- `U (Uniform)`

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-06T12:08:12+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
