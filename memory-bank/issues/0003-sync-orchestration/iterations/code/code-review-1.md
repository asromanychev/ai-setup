1. Предпосылки:
   - Анализ выполнен без запуска тестов и без runtime-проверок, только по текущему состоянию рабочего дерева и файлов проекта.
   - Code-scope diff для issue `0003` в рабочем дереве отсутствует: `git diff --stat` показывает только изменение `memory-bank/issues/EXMAPLES.md`, а `git status --short` не показывает изменений в `app/models/source.rb` и `spec/models/source_spec.rb`.
   - Поэтому review трактует текущие содержимое [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) и [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L1) как кандидатную реализацию issue `0003`.
   - Плановый allowlist из [plan.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L94) и [plan.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L153) требует правки в `app/models/source.rb` и `spec/models/source_spec.rb`; фактический список изменённых файлов этому allowlist не соответствует.
   - Runtime prerequisite о доступности `Collect::` в application runtime из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L24) не проверялся исполнением команды, поэтому это остаётся `runtime-unknown gate`, а не доказанным дефектом.

2. Инварианты и контракты:
   - Нарушен основной контракт issue: в [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) определены только `upsert_checkpoint!` и reader `sync_checkpoint`; метод `sync_step!(plugin_registry:, source_config:)`, требуемый FR 1-14 и AC 1-17 из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L33), отсутствует полностью.
   - Инвариант атомарности checkpoint для одного шага синка из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L88) не материализован: текущий код умеет только отдельный `upsert_checkpoint!` в [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L19), но не содержит транзакционной связки `build -> sync_step -> validate -> upsert`.
   - Инвариант использования persisted `checkpoint_in` из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L90) не реализован: в [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31) есть reader checkpoint, но нет вызова plugin c `checkpoint_in: sync_checkpoint&.position`.
   - Инвариант duck-typed orchestration из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L92) не реализован: код не обращается ни к `plugin_registry.build`, ни к `plugin.sync_step`, хотя их контракт зафиксирован в [core/lib/collect/plugin_registry.rb](/home/aromanychev/edu/aida/ai-da-collect/core/lib/collect/plugin_registry.rb#L31) и [core/lib/collect/plugin.rb](/home/aromanychev/edu/aida/ai-da-collect/core/lib/collect/plugin.rb#L24).
   - Тестовый контракт не покрыт: [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L70) заканчивается примерами только для `#upsert_checkpoint!`; `describe "#sync_step!"` отсутствует, поэтому ни один инвариант orchestration не проверяется тестами.

3. Трассировка путей выполнения:
   - Happy-path, требуемый spec: `Source#sync_step!` должен построить plugin через `plugin_registry.build`, прочитать `sync_checkpoint&.position`, вызвать `plugin.sync_step(checkpoint_in:)`, провалидировать `result`, сохранить `checkpoint_out` и вернуть эквивалентный `Hash` ([spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L33)). В текущем коде такого пути нет: после [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L19) идёт только `upsert_checkpoint!`, а класс завершается на [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L52).
   - Минимальный контрпример для happy-path: `source.sync_step!(plugin_registry: registry, source_config: {})` завершится `NoMethodError`, потому что в [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) метод не объявлен.
   - Error-path `plugin_registry.build` exception из FR 4/11 не реализован: код не вызывает `build` вообще, значит не может ни пробросить исходное исключение, ни гарантировать неизменность checkpoint именно в рамках orchestration.
   - Error-path `plugin.sync_step` exception из FR 11 не реализован по той же причине: в коде нет вызова plugin, а значит нет оркестратора, который бы связывал ошибку плагина с сохранением persisted checkpoint.
   - Error-path invalid result shape из FR 7/11 не реализован: приватный валидатор результата отсутствует; никакой код не проверяет обязательные ключи `:records`, `:checkpoint_out`, `:finished`, хотя этот shape объявлен в [core/lib/collect/plugin.rb](/home/aromanychev/edu/aida/ai-da-collect/core/lib/collect/plugin.rb#L47).
   - Поведение вне scope не изменилось: существующий `upsert_checkpoint!` по-прежнему поднимает `ArgumentError` на `nil` и делает `SyncCheckpoint.upsert` ([app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L19)), а reader `sync_checkpoint` по-прежнему проверяет ambiguity ([app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L31)); это не компенсирует отсутствие entry point issue `0003`.

4. Риски и регрессии:
   - `provable defect` | `high` | Основная функциональность issue отсутствует. В [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) нет `sync_step!`, поэтому AC 1-17 из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L113) не могут быть выполнены. Реальный контрпример: любой вызов `source.sync_step!(...)` падает с `NoMethodError`.
   - `provable defect` | `high` | Нет валидации plugin result и транзакционной фиксации `checkpoint_out`. После [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L19) отсутствует код, который проверяет `records`/`checkpoint_out`/`finished` и выполняет `upsert_checkpoint!` внутри orchestration, хотя это обязательный путь из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L39).
   - `provable defect` | `medium` | Adequacy тестов для issue равна нулю: в [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L70) нет ни одного примера для `#sync_step!`, поэтому diff не содержит теста, который мог бы поймать минимальный контрпример `NoMethodError` или отсутствие rollback/result-validation.
   - `scope breach` | `medium` | Фактический change set не совпадает с allowlist из плана. План требует работать в `app/models/source.rb` и `spec/models/source_spec.rb` ([plan.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L94), [plan.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/plan.md#L153)), но `git diff --stat` показывает только `memory-bank/issues/EXMAPLES.md`, а `git status --short` показывает untracked папку `memory-bank/issues/0003-sync-orchestration/`. Это означает отсутствие запланированных code changes и наличие внеплановых документационных изменений.
   - `runtime-unknown gate` | `low` | Runtime prerequisite о доступности `Collect::` без spec boot не подтверждён исполнением, хотя test runtime действительно добавляет `core/lib` через [spec/rails_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb#L3) и [spec/spec_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L5), а application runtime autoload-ит только `lib` через [config/application.rb](/home/aromanychev/edu/aida/ai-da-collect/config/application.rb#L29). Без runtime-проверки нельзя доказать, выполнен ли precondition из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L24).
   - `runtime-unknown gate` | `low` | Green suite и coverage gate не проверялись запуском, поэтому AC "Все существующие тесты остаются зелёными" и coverage assert из [spec/spec_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/spec_helper.rb#L10) остаются неподтверждёнными. Это не основной контрпример, потому что `Неэквивалентно` уже доказано отсутствием метода.

5. Вердикт по эквивалентности:
   - `Неэквивалентно`.
   - Минимальный контрпример: создать `Source` и вызвать `source.sync_step!(plugin_registry: registry, source_config: {})`. В текущем коде метод отсутствует, потому что класс в [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L1) содержит только `upsert_checkpoint!`, `sync_checkpoint` и private helpers и заканчивается на [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L52). Следовательно, хотя бы AC 1, 3, 5, 8, 10 и 17 из [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0003-sync-orchestration/spec.md#L113) нарушены немедленно.

6. Что проверить тестами:
   - Вызов `source.sync_step!(plugin_registry:, source_config:)` передаёт в `registry.build` ровно `source.plugin_type` и тот же `source_config`, без нормализации и fallback.
   - При existing checkpoint `plugin.sync_step` получает `checkpoint_in` из persisted `sync_checkpoint.position`, а при отсутствии checkpoint получает `nil`.
   - Валидный result `{ records:, checkpoint_out:, finished: }` возвращается без искажений и сохраняет `checkpoint_out`, включая случай `records: []` и `checkpoint_out: {}`.
   - Любая ошибка в `plugin_registry.build`, `plugin.sync_step`, валидации result или `upsert_checkpoint!` оставляет старый checkpoint неизменным, включая savepoint-rollback сценарий.
   - Для каждого инварианта result-shape есть отдельный negative test: отсутствие обязательного ключа, `records` не `Array`, `finished` не boolean, `checkpoint_out` равен `nil` или не `Hash`; каждый такой тест должен подтверждать отсутствие изменения persisted checkpoint.

7. Confidence:
   - `0.98`
   - Не 1.0 только потому, что review сделан без diff по code-scope и без runtime-проверок precondition/suite. Однако ключевой вывод доказуем по статическому коду: обязательный метод orchestration отсутствует.

Execution Metadata
- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-4-review-code.md`

Runtime Telemetry
- `started_at`: 2026-04-06T15:42:40+03:00
- `finished_at`: 2026-04-06T15:47:25+03:00
- `elapsed_seconds`: 285
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
