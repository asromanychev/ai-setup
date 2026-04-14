# Run Instructions — Issue #0001: Plugin Contract

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

Пошаговая инструкция ручной проверки контракта ingestion-плагина.

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

---

## 1. Подготовка

### 1.1 Зависимости

```bash
# Находясь в корне репозитория
bundle install

# Убедиться, что core/lib подключён
ls core/lib/collect/
# Ожидаемый вывод: collect.rb, errors.rb, null_plugin.rb, plugin.rb, plugin_registry.rb
```

### 1.2 Проверка окружения

Для этой фичи **не нужны**: PostgreSQL, Redis, Docker, Telegram API Token.  
Весь код живёт в `core/lib/collect/` и тестируется без внешних зависимостей.

```bash
# Убедиться, что spec_helper загружает core/lib
head -5 spec/spec_helper.rb
# Должно содержать: $LOAD_PATH.unshift File.expand_path('../core/lib', __dir__)
```

---

## 2. Проверка сценариев

### Сценарий 1: Happy path — NullPlugin первый шаг

```bash
bundle exec ruby -e "
require 'collect'
r = Collect::PluginRegistry.default
p = r.build('null', source_config: { records: [{ id: 1 }, { id: 2 }] })
result = p.sync_step(checkpoint_in: nil)
puts 'frozen: ' + result.frozen?.to_s
puts 'records: ' + result[:records].inspect
puts 'cursor: ' + result[:checkpoint_out][:cursor].to_s
puts 'emitted: ' + result[:checkpoint_out][:emitted_records].to_s
puts 'finished: ' + result[:finished].to_s
" -I core/lib
```

**Ожидаемый вывод:**
```
frozen: true
records: [{:id=>1}, {:id=>2}]
cursor: 1
emitted: 2
finished: false
```

---

### Сценарий 2: Второй шаг — пустой батч

```bash
bundle exec ruby -e "
require 'collect'
p = Collect::PluginRegistry.default.build('null', source_config: { records: [{ id: 1 }] })
p.sync_step(checkpoint_in: nil)
result2 = p.sync_step(checkpoint_in: { cursor: 1 })
puts 'records empty: ' + result2[:records].empty?.to_s
puts 'cursor: ' + result2[:checkpoint_out][:cursor].to_s
puts 'emitted: ' + result2[:checkpoint_out][:emitted_records].to_s
" -I core/lib
```

**Ожидаемый вывод:**
```
records empty: true
cursor: 2
emitted: 0
```

---

### Сценарий 3: Неизменность checkpoint_in

```bash
bundle exec ruby -e "
require 'collect'
p = Collect::PluginRegistry.default.build('null', source_config: { records: [1] })
checkpoint = { cursor: 0 }
p.sync_step(checkpoint_in: checkpoint)
puts 'original frozen: ' + checkpoint.frozen?.to_s
puts 'original intact: ' + (checkpoint[:cursor] == 0).to_s
" -I core/lib
```

**Ожидаемый вывод:**
```
original frozen: false
original intact: true
```

---

### Сценарий 4: ContractError — неверный source_config

```bash
bundle exec ruby -e "
require 'collect'
begin
  Collect::PluginRegistry.default.build('null', source_config: {})
rescue Collect::ContractError => e
  puts 'error: ' + e.message
end
" -I core/lib
```

**Ожидаемый вывод:**
```
error: NullPlugin source_config must include :records Array
```

---

### Сценарий 5: UnknownPluginError

```bash
bundle exec ruby -e "
require 'collect'
begin
  Collect::PluginRegistry.default.fetch('telegram')
rescue Collect::UnknownPluginError => e
  puts 'error: ' + e.message
end
" -I core/lib
```

**Ожидаемый вывод:**
```
error: unknown plugin id: telegram
```

---

### Сценарий 6: Детерминизм NullPlugin

```bash
bundle exec ruby -e "
require 'collect'
p = Collect::PluginRegistry.default.build('null', source_config: { records: [{ id: 1 }] })
r1 = p.sync_step(checkpoint_in: nil)
r2 = p.sync_step(checkpoint_in: nil)
puts 'deterministic: ' + (r1 == r2).to_s
" -I core/lib
```

**Ожидаемый вывод:**
```
deterministic: true
```

---

### Сценарий 7: ContractError — невалидный cursor

```bash
bundle exec ruby -e "
require 'collect'
p = Collect::PluginRegistry.default.build('null', source_config: { records: [] })
begin
  p.sync_step(checkpoint_in: { cursor: 'abc' })
rescue Collect::ContractError => e
  puts 'error: ' + e.message
end
" -I core/lib
```

**Ожидаемый вывод:**
```
error: NullPlugin checkpoint_in[:cursor] must be a non-negative Integer
```

---

### Сценарий 8: Полный тестовый набор (автоматически)

```bash
bundle exec rspec spec/core/collect/ --format documentation
```

**Ожидаемый вывод:**
```
...
40 examples, 0 failures
Coverage: ≥80% (проверяется через CoverageAssertions в spec_helper.rb)
```

---

## 3. Проверка инвариантов (VibeContract)

### Предусловия

```bash
# Файлы существуют
ls core/lib/collect/{errors,plugin,plugin_registry,null_plugin}.rb core/lib/collect.rb
# Нет внешних зависимостей в core/lib
grep -r "require.*active_record\|require.*redis\|require.*telegram" core/lib/ || echo "чисто"
```

### Постусловия

```bash
# Все тесты зелёные
bundle exec rspec spec/core/collect/ --format progress
# Coverage threshold
bundle exec rspec spec/core/collect/ 2>&1 | tail -5
# Ожидаемый признак: нет вывода "Coverage threshold not met"
```

### Инварианты

```bash
# Результат sync_step всегда frozen
bundle exec ruby -e "
require 'collect'
p = Collect::PluginRegistry.default.build('null', source_config: { records: [1] })
r = p.sync_step(checkpoint_in: nil)
puts r.frozen?                  # true
puts r[:records].frozen?        # true
puts r[:checkpoint_out].frozen? # true
" -I core/lib
```

---

## 4. Что смотреть в логах

- **Признак успеха:** тесты зелёные, нет `Collect::ContractError` при корректных вызовах
- **Признак скрытой ошибки:** `frozen? => false` на результате `sync_step` — значит `deep_freeze` не применяется
- **Coverage failure:** строка `Coverage threshold not met` в выводе rspec — нужны дополнительные тесты

---

## 5. Сброс состояния

```bash
# NullPlugin stateless — сбрасывать нечего
# Для повторного запуска тестов достаточно:
bundle exec rspec spec/core/collect/ --order random
```
