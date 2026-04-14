# Run Instructions — Issue #0002

Общий baseline запуска и git-проверки: [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md)  
Правила праймеринга для ИИ-агента, который исполняет эту инструкцию: [memory-bank/issues/AGENT_PRIMERING.md](../AGENT_PRIMERING.md)

Этот файл — готовый туториал для ручной проверки фичи `Source / SyncCheckpoint persistence`.

Ничего дополнительно искать не нужно: ниже уже подставлены локальные значения из проекта.

## Git verification

После проверки выполни чеклист из [memory-bank/issues/RUNBOOK.md](../RUNBOOK.md#8-git-verification-checklist) и подтверди, что diff ограничен файлами текущей фичи.

## Что проверяем

Нужно руками подтвердить:

1. `Source.for_sync` выбирает только включённые источники.
2. `upsert_checkpoint!` создаёт checkpoint и обновляет его без дублей.
3. `position: {}` допустим, а `position: nil` отвергается.
4. удаление `Source` удаляет связанный checkpoint.
5. если PostgreSQL не поднят, это blocker окружения, а не “успех проверки”.

## Подготовка окружения

### 1. Используй уже запущенный локальный PostgreSQL

На этой машине рабочий и проверенный путь такой:
- user: `ai_da_collect`
- password: `ai_da_collect`
- db: `ai_da_collect_dev`

PostgreSQL должен быть доступен на `127.0.0.1:5432`.

Проверка:

```bash
PGPASSWORD=ai_da_collect psql -h 127.0.0.1 -p 5432 -U ai_da_collect -d ai_da_collect_dev -c 'select current_database(), current_user;'
```

Ожидаемый результат:
- запрос проходит успешно;
- в выводе есть `ai_da_collect_dev` и `ai_da_collect`.

### 2. Docker нужен только если локального PostgreSQL нет

Если на `127.0.0.1:5432` у тебя ничего не слушает, тогда можно поднимать инфраструктуру через compose:

```bash
docker compose up -d postgres redis
```

Но если порт `5432` уже занят локальным PostgreSQL, compose-`postgres` не нужен и может конфликтовать с host-портом.

### 3. Задай переменные окружения

```bash
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev
export RAILS_ENV=development
```

### 4. Подготовь development schema

```bash
bundle exec rails db:prepare
```

Если здесь получаешь ошибку подключения к PostgreSQL, сначала остановись и почини окружение. Дальше проверять саму фичу бессмысленно.

### 5. Подготовь test schema

Для model specs нужен отдельный шаг:

```bash
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test
export RAILS_ENV=test
bundle exec rails db:environment:set
bundle exec rails db:prepare
```

Проверь, что Rails действительно смотрит в test DB:

```bash
bundle exec rails runner 'puts ActiveRecord::Base.connection_db_config.database'
```

Ожидаемый результат:
- печатается `ai_da_collect_test`

Потом вернись в development-окружение для ручных сценариев:

```bash
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev
export RAILS_ENV=development
```

## Быстрая автоматическая проверка

Сразу после подготовки можно выполнить:

```bash
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test
export RAILS_ENV=test
bundle exec rspec spec/core/collect
bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb
```

Ожидаемый результат:
- `spec/core/collect` зелёный;
- `spec/models/source_spec.rb` и `spec/models/sync_checkpoint_spec.rb` зелёные.

Если второй запуск падает только на подключении к БД, это проблема среды, а не логики `0002`.
Если видишь `Validation failed: External id has already been taken`, почти наверняка model specs были запущены не на `ai_da_collect_test`, а на `ai_da_collect_dev`.

## Ручная проверка

Ниже сценарии, которые можно копировать и выполнять как есть.

### Сценарий 1. `for_sync` выбирает только включённые source

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  enabled = Source.create!(plugin_type: "telegram", external_id: "enabled", sync_enabled: true)
  Source.create!(plugin_type: "telegram", external_id: "disabled", sync_enabled: false)

  puts Source.for_sync.pluck(:id) == [enabled.id]
'
```

Ожидаемый результат:
- в stdout печатается `true`

### Сценарий 2. Создание checkpoint и чтение сохранённой позиции

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  source = Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)
  source.upsert_checkpoint!(position: { cursor: 42 })

  puts source.reload.sync_checkpoint.position == { "cursor" => 42 }
'
```

Ожидаемый результат:
- в stdout печатается `true`

### Сценарий 3. Повторный upsert обновляет checkpoint без дублей

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  source = Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)
  source.upsert_checkpoint!(position: { cursor: 42 })
  source.upsert_checkpoint!(position: { cursor: 99 })

  puts source.reload.sync_checkpoint.position == { "cursor" => 99 }
  puts SyncCheckpoint.where(source_id: source.id).count == 1
'
```

Ожидаемый результат:
- первая строка `true`
- вторая строка `true`

### Сценарий 4. Пустой hash допустим

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  source = Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)
  checkpoint = SyncCheckpoint.create!(source: source, position: {})

  puts checkpoint.position == {}
'
```

Ожидаемый результат:
- в stdout печатается `true`

### Сценарий 5. `position: nil` отвергается

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  source = Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)

  begin
    source.upsert_checkpoint!(position: nil)
    puts "unexpected-success"
  rescue => e
    puts e.class.name
    puts e.message
  end
'
```

Ожидаемый результат:
- первая строка `ArgumentError`
- во второй строке есть `position must not be nil`

### Сценарий 6. Удаление source удаляет checkpoint

```bash
bundle exec rails runner '
  SyncCheckpoint.delete_all
  Source.delete_all

  source = Source.create!(plugin_type: "telegram", external_id: "ch1", sync_enabled: true)
  source.upsert_checkpoint!(position: { cursor: 7 })
  source.destroy

  puts SyncCheckpoint.where(source_id: source.id).count == 0
'
```

Ожидаемый результат:
- в stdout печатается `true`

## Что считать успешной ручной проверкой

Проверка считается успешной, если:

1. `psql` на `ai_da_collect_dev` проходит.
2. `bundle exec rails db:prepare` для development проходит.
3. `bundle exec rails db:environment:set` и `bundle exec rails db:prepare` для test проходят.
4. Все 6 сценариев выше дают ожидаемый результат.
5. `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` проходит.

## Если что-то пошло не так

- Ошибка подключения к БД: проблема окружения.
- `Validation failed: External id has already been taken` почти во всех model specs: ты, скорее всего, запускаешь их на `ai_da_collect_dev`, а не на `ai_da_collect_test`. Снова выставь:

```bash
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test
export RAILS_ENV=test
bundle exec rails db:environment:set
bundle exec rails runner 'puts ActiveRecord::Base.connection_db_config.database'
```

Правильный вывод: `ai_da_collect_test`.

- `RecordInvalid`, `ArgumentError` не в тех местах, где ожидается: проблема логики фичи.
- Неверный persisted state после `upsert_checkpoint!` или `destroy`: проблема логики фичи.

## Что я уже перепроверил на этой машине

Я прогнал tutorial сам и получил такие результаты:

1. Команда `bundle exec rails db:prepare` без `DATABASE_URL` падает.

Это ожидаемо, потому что [config/database.yml](/home/aromanychev/edu/aida/ai-da-collect/config/database.yml:1) целиком зависит от `ENV["DATABASE_URL"]`.

2. Локальный Postgres на `127.0.0.1:5432` уже существует и принимает логин `ai_da_collect / ai_da_collect`.

3. При попытке идти через `docker compose run --rm app ...` всплыл отдельный blocker окружения:

```text
failed to bind host port 0.0.0.0:5432/tcp: address already in use
```

Это означает, что на машине уже занят порт `5432`, и compose не может заново поднять PostgreSQL с тем же bind.

4. Реально проверенный рабочий путь для этой машины:
- использовать host Postgres на `127.0.0.1:5432`;
- отдельно подготовить `development` и `test` базы;
- для model specs сначала выполнить `db:environment:set` в `test`.

Итог: tutorial уже исправлен по командам и переменным, но если у тебя снова всплывёт ошибка на `5432`, это не проблема фичи `0002`, а конфликт локального PostgreSQL runtime.

## Связанные файлы

- [acceptance-scenarios.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0002-source-checkpoint/acceptance-scenarios.md)
- [spec.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0002-source-checkpoint/spec.md)
- [plan.md](/home/aromanychev/edu/aida/ai-da-collect/memory-bank/issues/0002-source-checkpoint/plan.md)
