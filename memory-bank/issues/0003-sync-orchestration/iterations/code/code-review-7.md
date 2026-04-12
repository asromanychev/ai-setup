---
issue: 3
title: Code Review — One-Step Sync Orchestration
type: code-review
status: draft
version: v1
date: 2026-04-06
---

# Code Review: Issue #0003 — One-Step Sync Orchestration

## Контекст анализа

- `spec.md`: `memory-bank/issues/0003-sync-orchestration/spec.md` (`status: draft`, `v4`) — используется как текущий baseline, хотя статус не `active` ([spec.md:2](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L2), [spec.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L4))
- `plan.md`: `memory-bank/issues/0003-sync-orchestration/plan.md` (`status: active`, `v9`) ([plan.md:2](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L2), [plan.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L4))
- allowlist из плана: только `app/models/source.rb` и `spec/models/source_spec.rb` ([plan.md:95](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L95), [plan.md:147](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L147))
- проанализированный tracked diff: `app/models/source.rb`, `spec/models/source_spec.rb`, `.env.example`, `config/database.yml`
- дополнительно в рабочем дереве есть untracked `lib/collect.rb`, который влияет на runtime-boot ([collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/lib/collect.rb#L1))

## Классы замечаний

### provable defect

Недостаточно данных для доказуемого функционального дефекта. Реализация `sync_step!` и тестовый блок покрывают заявленные FR/AC по статическому анализу ([source.rb:31](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31), [source_spec.rb:124](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L124)).

### scope breach

1. `medium` — вне allowlist изменены `.env.example` и `config/database.yml`, хотя план разрешал правки только в `app/models/source.rb` и `spec/models/source_spec.rb` ([plan.md:95](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L95), [plan.md:147](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L147), [.env.example:7](/home/aromanychev/edu/aida/ai-da-collect/.env.example#L7), [database.yml:5](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml#L5), [database.yml:12](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml#L12)).
2. `medium` — в рабочем дереве присутствует untracked `lib/collect.rb`, который добавляет bootstrap-мост к `core/lib/collect`; это конфликтует с ограничением спеки не менять boot/load-path поведение для решения задачи ([spec.md:31](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L31), [spec.md:37](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L37), [spec.md:119](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L119), [collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/lib/collect.rb#L1)).

### runtime-unknown gate

1. `low` — prerequisite-check из плана (`rails runner "puts Collect::CheckpointAmbiguityError"`) не выполнен в этом review, поэтому нельзя подтвердить, что runtime-пререквизит из спеки выполнен без вспомогательного boot-файла ([plan.md:37](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L37), [plan.md:55](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L55), [spec.md:37](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L37)).
2. `low` — AC про зелёный suite и pending-gate нельзя подтвердить без запуска RSpec; это отдельный runtime gate, а не дефект реализации ([spec.md:142](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L142), [plan.md:62](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L62)).

## 1. Предпосылки

1. Review использует `memory-bank/issues/0003-sync-orchestration/spec.md` как baseline, хотя файл помечен `status: draft`; без этого допущения вывод об эквивалентности к AC теряет формальное основание ([spec.md:4](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L4)).
2. `spec/spec_helper.rb` и `spec/rails_helper.rb` действительно поднимают `Collect` в spec-runtime через `$LOAD_PATH.unshift` и `require "collect"`, поэтому тесты с `Collect::UnknownPluginError` в модели имеют корректный load-context ([spec_helper.rb:5](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L5), [spec_helper.rb:7](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L7), [rails_helper.rb:3](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L3), [rails_helper.rb:5](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L5), [source_spec.rb:206](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L206)).
3. Для вывода об атомарности предполагается стандартная семантика `requires_new: true` в Active Record/PostgreSQL savepoint-transaction; без исполнения это остаётся runtime-gate, а не доказанный факт среды ([source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37), [rails_helper.rb:16](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L16), [source_spec.rb:223](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L223)).

## 2. Инварианты и контракты

1. Инвариант атомарности checkpoint соблюдён по коду: запись нового checkpoint происходит только после `validate_sync_result!` и только внутри `transaction(requires_new: true)`, а сам persistence всё ещё делегирован в существующий `upsert_checkpoint!` ([source.rb:19](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L19), [source.rb:35](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L35), [source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37)).
2. Инвариант отсутствия частичного прогресса на ошибке сохранён: исключения из `build`, `sync_step`, `validate_sync_result!` и `upsert_checkpoint!` не перехватываются и не маскируются, поэтому checkpoint меняется только на happy-path ([source.rb:32](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L32), [source.rb:33](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L33), [source.rb:66](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L66)).
3. Инвариант использования актуальной persisted позиции сохранён: `plugin.sync_step` получает ровно `sync_checkpoint&.position` на момент вызова, без кэша и без промежуточной нормализации ([spec.md:49](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L49), [source.rb:33](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L33)).
4. Инвариант duck-typed независимости сохранён: код не ветвится по классам `registry` и `plugin`, а использует только `build` и `sync_step`; отдельный тест на два анонимных plugin-класса это материализует ([spec.md:58](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L58), [source.rb:32](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L32), [source_spec.rb:256](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L256)).
5. Контракт валидного результата реализован буквально: проверяются `Hash`, наличие ключей `:records`, `:checkpoint_out`, `:finished`, тип `Array` для `records`, тип `Hash` для `checkpoint_out` и boolean для `finished`; `checkpoint_out: {}` проходит, `nil` и `"bad"` отвергаются ([spec.md:51](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L51), [source.rb:66](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L66), [source_spec.rb:189](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L189), [source_spec.rb:322](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L322), [source_spec.rb:330](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L330)).

## 3. Трассировка путей выполнения

1. Happy-path: `registry.build` получает `source.plugin_type` и тот же объект `source_config`, затем plugin получает текущий `checkpoint_in`, результат валидируется, после чего `checkpoint_out` пишется через `upsert_checkpoint!` и исходный `result` возвращается без преобразования ([source.rb:31](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31), [source_spec.rb:138](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L138), [source_spec.rb:177](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L177)).
2. Error-path `registry.build`: исключение выходит наружу до чтения plugin result и до транзакции, checkpoint остаётся прежним; это покрыто и для `ArgumentError`, и для plugin-registry ошибки ([source.rb:32](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L32), [source_spec.rb:151](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L151), [source_spec.rb:204](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L204)).
3. Error-path `plugin.sync_step`: вызов делается ровно один раз, а исключение не оборачивается; persisted checkpoint после этого не меняется ([spec.md:50](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L50), [source.rb:33](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L33), [source_spec.rb:196](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L196), [source_spec.rb:214](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L214)).
4. Error-path invalid result: все обязательные негативные ветки приводят к `ArgumentError` до входа в транзакцию, поэтому checkpoint не может обновиться частично ([source.rb:35](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L35), [source.rb:66](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L66), [source_spec.rb:298](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L298), [source_spec.rb:338](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L338)).
5. Error-path persistence failure: тест моделирует реальный `upsert`, после которого искусственно выбрасывается `ActiveRecord::StatementInvalid`; код на стороне модели действительно содержит отдельный transaction-boundary, но подтверждение rollback остаётся runtime-gate без исполнения ([source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37), [source_spec.rb:223](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L223)).

## 4. Риски и регрессии

1. `scope breach`, `medium` — `.env.example` и `config/database.yml` изменены вне allowlist. Это реальные изменения рабочего дерева, а не гипотеза: добавлен `TEST_DATABASE_URL` и введён fallback через `ENV.fetch`, хотя plan не разрешал эти файлы ([plan.md:95](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L95), [plan.md:147](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L147), [.env.example:7](/home/aromanychev/edu/aida/ai-da-collect/.env.example#L7), [database.yml:5](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml#L5), [database.yml:12](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml#L12)).
2. `scope breach`, `medium` — `lib/collect.rb` добавляет новый bootstrap-мост к `core/lib/collect`, хотя спецификация прямо запрещает маскировать runtime prerequisite bootstrap-хаком. Даже если файл нужен для `rails runner`, он всё равно выходит за scope документа ([spec.md:31](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L31), [spec.md:119](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L119), [collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/lib/collect.rb#L1)).
3. `runtime-unknown gate`, `low` — rollback-сценарий с `and_wrap_original` выглядит корректно, но его истинность зависит от фактической семантики savepoint в текущих версиях PostgreSQL/AR и не доказывается статически ([rails_helper.rb:16](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L16), [source.rb:37](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L37), [source_spec.rb:226](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L226)).
4. `runtime-unknown gate`, `low` — AC про green suite и pending-gate остаётся непроверенным без запуска команды из плана, поэтому это нельзя использовать ни как дефект, ни как закрытое требование ([spec.md:142](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L142), [plan.md:70](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L70)).

## 5. Вердикт по эквивалентности

`Эквивалентно`.

Минимальный доказуемый контрпример по коду не найден. `Source#sync_step!` реализует все функциональные требования из спеки: передача исходного `source_config`, чтение persisted checkpoint, ровно один вызов `plugin.sync_step`, жёсткая валидация shape result, запись checkpoint только после успешной валидации и сохранение duck-typed контракта ([source.rb:31](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31), [source.rb:66](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L66)). Тесты в `spec/models/source_spec.rb` закрывают AC 1-17 по одному или нескольким примерам каждый ([source_spec.rb:138](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L138), [source_spec.rb:343](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L343)). Незакрытыми остаются только `scope breach` и `runtime-unknown gate`, которые по правилам review не переводят verdict в `Неэквивалентно` без доказуемого функционального контрпримера.

## 6. Что проверить тестами

1. Выполнить prerequisite-check `bundle exec rails runner "puts Collect::CheckpointAmbiguityError"` и подтвердить, что runtime поднимается без опоры на spec helpers и без `lib/collect.rb`-хака ([plan.md:43](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L43)).
2. Выполнить pending-gate из плана через JSON formatter и зафиксировать `errors_outside_of_examples_count == 0` и ожидаемый pending-count ([plan.md:70](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L70)).
3. Запустить rollback-сценарий `rolls back checkpoint changes when persistence fails after upsert`, потому что это единственный тест, который materialize-ит savepoint-boundary, но статически не доказывается ([source_spec.rb:223](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L223)).
4. Прогнать весь `spec/models/source_spec.rb` и убедиться, что coverage-hook из `spec/spec_helper.rb` не роняет suite постфактум ([spec_helper.rb:10](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L10), [spec_helper.rb:51](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L51)).
5. Проверить, что внеплановые infra/boot-изменения действительно нужны; если нет, удалить их и подтвердить, что `sync_step!`-ветка остаётся зелёной только с правками в allowlist ([database.yml:5](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml#L5), [collect.rb:1](/home/aromanychev/edu/aida/ai-da-collect/lib/collect.rb#L1)).

## 7. Confidence

`0.88` — код и тесты хорошо трассируются к FR/AC, а доказуемых дефектов нет. До `1.0` мешают два неподтверждённых runtime-факта: реальное прохождение prerequisite-check/green suite и фактическая работа savepoint rollback в текущем окружении.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-4-review-code.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T18:24:40+03:00
- `finished_at`: 2026-04-06T18:30:10+03:00
- `elapsed_seconds`: 330
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
