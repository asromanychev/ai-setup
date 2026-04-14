# Acceptance Scenarios — Issue #0001: Plugin Contract

Сценарии приёмки для ручной и автоматической проверки контракта ingestion-плагина.  
Контекст: `core/lib/collect/` — изолированное ядро без ActiveRecord, Redis, Telegram.

---

**Сценарий 1: Happy path — один шаг синка через NullPlugin**

- Дано: `PluginRegistry.default` зарегистрирован, `NullPlugin` под ключом `"null"`, `source_config: { records: [{ id: 1 }, { id: 2 }] }`
- Когда: `registry.build("null", source_config: { records: [{ id: 1 }] }).sync_step(checkpoint_in: nil)`
- Тогда: возвращает замороженный Hash с ключами `:records` (Array), `:checkpoint_out` (Hash с `cursor: 1, emitted_records: 1`), `:finished` (false)
- Как проверить:
  ```ruby
  # rails console или bin/rspec
  require 'collect'
  r = Collect::PluginRegistry.default
  p = r.build("null", source_config: { records: [{ id: 1 }] })
  result = p.sync_step(checkpoint_in: nil)
  puts result.frozen?                          # => true
  puts result[:records]                        # => [{id: 1}]
  puts result[:checkpoint_out][:cursor]        # => 1
  puts result[:checkpoint_out][:emitted_records] # => 1
  puts result[:finished]                       # => false
  ```

---

**Сценарий 2: Второй шаг синка — пустой батч**

- Дано: первый шаг выполнен, `checkpoint_out: { cursor: 1, emitted_records: 1 }`
- Когда: `plugin.sync_step(checkpoint_in: { cursor: 1 })`
- Тогда: возвращает `records: []`, `checkpoint_out: { cursor: 2, emitted_records: 0 }`, `finished: false`
- Как проверить:
  ```ruby
  result2 = p.sync_step(checkpoint_in: { cursor: 1 })
  puts result2[:records].empty?                      # => true
  puts result2[:checkpoint_out][:cursor]             # => 2
  puts result2[:checkpoint_out][:emitted_records]    # => 0
  ```

---

**Сценарий 3: Неизменность оригинального checkpoint_in**

- Дано: `checkpoint = { cursor: 0, extra: "data" }`
- Когда: `plugin.sync_step(checkpoint_in: checkpoint)`
- Тогда: оригинальный объект `checkpoint` не изменён и не заморожен
- Как проверить:
  ```ruby
  checkpoint = { cursor: 0, extra: "data" }
  p.sync_step(checkpoint_in: checkpoint)
  puts checkpoint.frozen?     # => false
  puts checkpoint[:extra]     # => "data"
  ```

---

**Сценарий 4: ContractError при неверном source_config**

- Дано: попытка создать NullPlugin без ключа `:records`
- Когда: `Collect::PluginRegistry.default.build("null", source_config: {})`
- Тогда: поднимается `Collect::ContractError` с сообщением `"NullPlugin source_config must include :records Array"`
- Как проверить:
  ```ruby
  begin
    Collect::PluginRegistry.default.build("null", source_config: {})
  rescue Collect::ContractError => e
    puts e.message  # => "NullPlugin source_config must include :records Array"
  end
  ```

---

**Сценарий 5: UnknownPluginError для неизвестного plugin id**

- Дано: `PluginRegistry.default` зарегистрирован только с `NullPlugin`
- Когда: `registry.fetch("telegram")`
- Тогда: поднимается `Collect::UnknownPluginError` с сообщением `"unknown plugin id: telegram"`
- Как проверить:
  ```ruby
  begin
    Collect::PluginRegistry.default.fetch("telegram")
  rescue Collect::UnknownPluginError => e
    puts e.message  # => "unknown plugin id: telegram"
  end
  ```

---

**Сценарий 6: Идемпотентность NullPlugin (детерминизм)**

- Дано: два вызова с одинаковыми аргументами
- Когда: вызвать `sync_step(checkpoint_in: nil)` дважды на одном экземпляре
- Тогда: оба результата равны между собой
- Как проверить:
  ```ruby
  p = Collect::PluginRegistry.default.build("null", source_config: { records: [{ id: 1 }] })
  r1 = p.sync_step(checkpoint_in: nil)
  r2 = p.sync_step(checkpoint_in: nil)
  puts r1 == r2  # => true
  ```

---

**Сценарий 7: ContractError при невалидном cursor**

- Дано: `checkpoint_in: { cursor: "not_a_number" }`
- Когда: `plugin.sync_step(checkpoint_in: { cursor: "abc" })`
- Тогда: поднимается `Collect::ContractError` с сообщением про non-negative Integer
- Как проверить:
  ```ruby
  begin
    p.sync_step(checkpoint_in: { cursor: "abc" })
  rescue Collect::ContractError => e
    puts e.message.include?("non-negative Integer")  # => true
  end
  ```

---

**Сценарий 8: Изоляция от внешних зависимостей**

- Дано: среда без Telegram, Redis, PostgreSQL
- Когда: запуск полного набора тестов `bundle exec rspec spec/core/collect/`
- Тогда: все тесты проходят, нет require на ActiveRecord/Redis/Net::HTTP/Telegram
- Как проверить:
  ```bash
  bundle exec rspec spec/core/collect/ --format documentation
  # Ожидаемый результат: 40 examples, 0 failures
  # Coverage threshold: ≥80% по core/lib/
  ```
