1. Предпосылки:
   - Анализируется текущий diff рабочего дерева по файлам `core/lib/collect/plugin.rb`, `core/lib/collect/null_plugin.rb`, `spec/core/collect/plugin_contract_spec.rb`, `spec/core/collect/null_plugin_spec.rb`, `spec/core/collect/plugin_registry_spec.rb`, `spec/core/collect/registry_null_plugin_integration_spec.rb`.
   - Ревью выполнено без запуска тестов; пункты Acceptance Criteria про зелёный тестовый набор и покрытие 80% нельзя подтвердить, поэтому для них статус: `Недостаточно данных`.
   - Спецификация считается утверждённой по `memory-bank/issues/0001-plugin-contract/spec.md`.

2. Инварианты и контракты:
   - Контракт базового класса по ошибкам и типам в целом усилен и ближе к спецификации: `Plugin.plugin_id`, `source_config`, `checkpoint_in`, `perform_sync_step` и нормализация результата проверяются в `core/lib/collect/plugin.rb:10`, `core/lib/collect/plugin.rb:16`, `core/lib/collect/plugin.rb:24`, `core/lib/collect/plugin.rb:33`, `core/lib/collect/plugin.rb:47`; это соответствует FR 1-7 в `spec.md:38-49`.
   - Контракт `NullPlugin` по валидации `:records`, обработке `{}` как `cursor: 0`, отказу для нецелого/отрицательного `cursor` и `emitted_records == records.length` реализован в `core/lib/collect/null_plugin.rb:7`, `core/lib/collect/null_plugin.rb:21`, `core/lib/collect/null_plugin.rb:27`, `core/lib/collect/null_plugin.rb:35`; это соответствует `spec.md:48-49`, `spec.md:80-89`, `spec.md:138-145`.
   - Инвариант “глубоко копируется и замораживается” соблюдён не полностью. В `core/lib/collect/plugin.rb:85-88` `deep_dup` копирует значения Hash, но переиспользует исходные ключи; в `core/lib/collect/plugin.rb:72-74` `deep_freeze` замораживает только значения Hash, а не ключи. Это противоречит FR 3 и FR 5 в `spec.md:40-42` и инварианту иммутабельности входов в `spec.md:95`.

3. Трассировка путей выполнения:
   - Happy-path `Plugin#sync_step`: `checkpoint_in` валидируется в `core/lib/collect/plugin.rb:41-45`, затем дублируется и freeze'ится в `core/lib/collect/plugin.rb:37-38`, затем результат валидируется и нормализуется в `core/lib/collect/plugin.rb:47-67`. Для обычных Hash/Array со стабильными ключами это сохраняет поведение из спецификации.
   - Happy-path `NullPlugin` при первом шаге: после валидации `source_config` в `core/lib/collect/null_plugin.rb:7-12` метод `perform_sync_step` выбирает `cursor = 0` для `nil`/`{}` в `core/lib/collect/null_plugin.rb:21-25`, возвращает весь батч в `core/lib/collect/null_plugin.rb:31-39`, затем базовый класс freeze'ит выход в `core/lib/collect/plugin.rb:63-67`.
   - Error-path `NullPlugin` для плохого `cursor`: `checkpoint_in[:cursor] = "abc"` или `-1` отклоняется в `core/lib/collect/null_plugin.rb:27-28`, что совпадает со сценариями `spec.md:80-82`.
   - Изменившееся поведение для `cursor > 0`: `emitted_records` теперь считается от фактически возвращённого `records` в `core/lib/collect/null_plugin.rb:37`, а не от исходного `batch`; это устраняет расхождение со спецификацией `spec.md:49`.
   - Непокрытый path по глубокой копии ключей: если во входном `source_config` или `checkpoint_in` используются мутабельные ключи Hash, они проходят через `deep_dup` без копирования в `core/lib/collect/plugin.rb:85-88`, поэтому последующая внешняя мутация ключевого объекта может изменить уже “замороженную” внутреннюю структуру плагина. Это путь, на котором поведение больше не соответствует FR 3/5.

4. Риски и регрессии:
   - `medium`: Нарушен контракт глубокой копии входов для ключей Hash. В `core/lib/collect/plugin.rb:85-88` ключ Hash не дублируется, а в `core/lib/collect/plugin.rb:72-74` ключи не freeze'ятся. Реальный контрпример: `key = +"cursor"; checkpoint = { key => 0 }; plugin.sync_step(checkpoint_in: checkpoint); key << "_mutated"`. После этого внутренние структуры, построенные из supposedly deep-copied input, разделяют тот же объект ключа, хотя FR 5 требует глубокую копию и отсутствие влияния оригинального объекта (`spec.md:42`, `spec.md:95`).
   - `low`: Добавленные тесты не доказывают описанный выше инвариант, потому что проверяют только верхнеуровневую неизменность/заморозку (`spec/core/collect/plugin_contract_spec.rb:46-58`, `spec/core/collect/plugin_contract_spec.rb:91-99`), но не случай с мутабельными ключами Hash. Риск реален, потому что текущая реализация `deep_dup` именно на ключах делает shallow copy.

5. Вердикт по эквивалентности:
   - `Неэквивалентно`.
   - Минимальный контрпример: создать мутабельный ключ `key = +"records"` и передать `source_config = { key => [] }` либо `checkpoint_in = { key => 0 }`. Из-за `core/lib/collect/plugin.rb:85-88` внутренний Hash использует тот же объект ключа, а `core/lib/collect/plugin.rb:72-74` его не freeze'ит. Это нарушает требование “немедленно глубоко копируется и замораживается” из `spec.md:40-42` и инвариант иммутабельности из `spec.md:95`, следовательно Acceptance Criteria `spec.md:149` не доказан и фактически нарушен для этого класса входов.

6. Что проверить тестами:
   - Передача `source_config` с мутабельным строковым ключом: мутация исходного ключа после `Plugin.new` не должна отражаться на `plugin.source_config`.
   - Передача `checkpoint_in` с мутабельным строковым ключом: мутация исходного ключа после `sync_step` не должна влиять на нормализованный путь выполнения внутри плагина.
   - Глубокая заморозка должна охватывать вложенные Hash-ключи в `source_config`, `checkpoint_in` и `sync_step` result, а не только значения.
   - Полный прогон `bundle exec rspec spec/core/collect/` для подтверждения AC `spec.md:147`.
   - Проверка coverage assertion из `spec/spec_helper.rb` для подтверждения AC `spec.md:148`.

7. Confidence:
   - `0.87` — логика ревью опирается на конкретные строки реализации и спецификации, но без запуска тестов остаётся `Недостаточно данных` по фактической зелёности suite и порогу покрытия.
