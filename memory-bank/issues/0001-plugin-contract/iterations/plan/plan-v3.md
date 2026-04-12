1. Паттерн оркестрации: один агент, последовательное выполнение.
   Порядок зависимостей: сначала точечная правка базового контракта в `core/lib/collect/plugin.rb`, затем реализация недостающего поведения в `core/lib/collect/null_plugin.rb`, после этого — при обнаружении конкретного расхождения — исправление `core/lib/collect/plugin_registry.rb`, и только затем расширение тестов по слоям `Plugin` -> `PluginRegistry` -> `NullPlugin` -> интеграционный сценарий реестра.

2. Grounding по кодовой базе: подтвердить перед изменениями, что файлы `core/lib/collect/plugin.rb`, `core/lib/collect/plugin_registry.rb`, `core/lib/collect/null_plugin.rb`, `spec/core/collect/plugin_contract_spec.rb`, `spec/core/collect/plugin_registry_spec.rb`, `spec/core/collect/null_plugin_spec.rb` и `spec/core/collect/registry_null_plugin_integration_spec.rb` существуют и соответствуют текущей архитектуре ядра `Collect`.
   Зафиксировать, что `plugin_registry.rb` уже реализует требования спецификации и должен изменяться только при обнаружении конкретного расхождения со `spec.md`, без рефакторинга "на всякий случай". Если расхождений нет — файл не входит в реализацию, а корректность его поведения подтверждает шаг 7 (unit-тесты `plugin_registry_spec.rb`).

3. Целевой файл: `core/lib/collect/plugin.rb`
   Конкретное действие: добавить приватный рекурсивный helper `deep_freeze(value)` для `Hash`, `Array` и вложенных элементов; применить его к `source_config` после `deep_dup` в `initialize`; применить его к `normalized_checkpoint(checkpoint_in)` перед передачей в `perform_sync_step`, чтобы `checkpoint_in` внутри `perform_sync_step` был глубоко заморожен (FR 5: глубокое копирование и заморозка входов, инвариант 1: немутируемость входов); применить его к нормализованному результату `sync_step`, чтобы замораживались не только верхний `Hash`, но и все вложенные структуры в `:records` и `:checkpoint_out`.
   Ограничение шага: не переписывать уже корректные части файла, включая `validate_checkpoint!`, приватность `perform_sync_step`, сигнатуры методов и текущие сообщения `ContractError`, если они уже соответствуют спецификации.

4. Целевой файл: `core/lib/collect/null_plugin.rb`
   Конкретное действие: переопределить `initialize(source_config:)`, вызвать `super`, затем валидировать, что `source_config[:records]` или строковый эквивалент содержит `Array`; при нарушении поднимать `ContractError` с сообщением `"NullPlugin source_config must include :records Array"`.
   В этом же файле доработать `perform_sync_step(checkpoint_in:)`: трактовать `nil` и `{}` как `cursor = 0`, отклонять нецелый или отрицательный `cursor` через `ContractError`, при `cursor == 0` возвращать батч из `source_config[:records]`, при `cursor > 0` возвращать `records: []`, а `checkpoint_out[:emitted_records]` считать по фактически возвращённому массиву `records`, чтобы при `cursor > 0` значение было `0`.

5. Целевой файл: `core/lib/collect/plugin_registry.rb`
   Конкретное действие: если в файле найдено конкретное расхождение со `spec.md` (поведение `register`, `fetch`, `build`, нормализация id или состав `default`), исправить только это расхождение без изменения публичного поведения, уже покрытого спецификацией. Если расхождений не обнаружено — файл не изменяется; корректность поведения подтверждает шаг 7 (`spec/core/collect/plugin_registry_spec.rb`).

6. Целевой файл: `spec/core/collect/plugin_contract_spec.rb`
   Конкретное действие: расширить unit-тесты базового класса `Collect::Plugin`, чтобы они проверяли глубокую иммутабельность `source_config` и `checkpoint_in` (включая вложенные структуры), глубокую заморозку вложенных структур в результате `sync_step`, обязательность `.plugin_id` и `#perform_sync_step`, а также ошибки при неполном или неверно типизированном результате.

7. Целевой файл: `spec/core/collect/plugin_registry_spec.rb`
   Конкретное действие: зафиксировать тестами текущее корректное поведение `Collect::PluginRegistry`: эквивалентность Symbol/String через `.to_s`, отказ для класса без `.plugin_id`, отказ при несовпадающем `plugin_id`, проброс ошибки `"unknown plugin id: <id>"`, делегирование `build` в `fetch` + `.new`, и состав `PluginRegistry.default` только с `NullPlugin`. Прохождение этих тестов без изменений в `plugin_registry.rb` подтверждает отсутствие расхождений со спецификацией.

8. Целевой файл: `spec/core/collect/null_plugin_spec.rb`
   Конкретное действие: расширить unit-тесты `Collect::NullPlugin` сценариями валидации `source_config[:records]`, обработкой `checkpoint_in: nil` и `{}`, ошибками для строкового и отрицательного `cursor`, проверкой детерминизма, а также явной фиксацией значения `checkpoint_out[:emitted_records]` как длины фактически возвращённого батча.

9. Целевой файл: `spec/core/collect/registry_null_plugin_integration_spec.rb`
   Конкретное действие: расширить интеграционный сценарий `PluginRegistry.default -> build("null") -> sync_step`, чтобы он подтверждал работу без внешних зависимостей, корректную сборку `NullPlugin` через реестр и ожидаемый end-to-end результат после изменений в контракте и `NullPlugin`.
