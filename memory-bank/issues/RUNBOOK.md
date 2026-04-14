# Issues Runbook

Общий файл для запуска окружения, приложения и ручной проверки фич.  
Каждый `memory-bank/issues/NNNN-slug/run-instructions.md` должен описывать только feature-specific шаги и ссылаться на этот runbook как на общий baseline.

## Что читать первым

1. `memory-bank/index.md`
2. `memory-bank/issues/RUNBOOK.md`
3. `memory-bank/issues/AGENT_PRIMERING.md`
4. `memory-bank/issues/NNNN-slug/spec.md`
5. `memory-bank/issues/NNNN-slug/plan.md`
6. `memory-bank/issues/NNNN-slug/acceptance-scenarios.md`
7. `memory-bank/issues/NNNN-slug/run-instructions.md`

## 1. Общие принципы

- Сначала подтвердить окружение, потом запускать приложение, потом выполнять focused verification, и только после этого full regression.
- Для ручной проверки по возможности использовать `development` DB, а не `test`, чтобы не загрязнять test schema вне rspec-транзакций.
- Если ручная проверка всё же шла на `RAILS_ENV=test`, после неё выполнить `RAILS_ENV=test bundle exec rails db:schema:load`.
- Проблема подключения к PostgreSQL/Redis/Docker считается blocker окружения, а не дефектом фичи.
- Если issue-specific файл конфликтует с этим runbook, приоритет у issue-specific файла.

## 2. Базовый setup репозитория

```bash
bundle install
```

Если локальный PostgreSQL уже слушает `127.0.0.1:5432`, используй его.  
Если нет, подними инфраструктуру через Docker:

```bash
docker compose up -d postgres redis
```

Проверка PostgreSQL:

```bash
pg_isready -h 127.0.0.1 -p 5432 -U ai_da_collect
```

Проверка Redis:

```bash
redis-cli -h 127.0.0.1 -p 6379 ping
```

## 3. Канонические ENV

### Development

```bash
export RAILS_ENV=development
export API_KEY=test-api-key
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev
```

### Test

```bash
export RAILS_ENV=test
export API_KEY=test-api-key
export DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test
```

## 4. Подготовка БД и boot-check

### Development schema

```bash
RAILS_ENV=development API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails db:prepare
```

### Test schema

```bash
RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rails db:prepare
```

### Приложение стартует

```bash
API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails runner "puts 'ok'"
```

### Маршруты и схема

```bash
API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails routes
API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails db:migrate:status
```

## 5. Базовая схема проверки

### Stage A: дешёвые проверки

```bash
bundle exec ruby -c app/path/to/file.rb
bundle exec ruby -c spec/path/to/file_spec.rb
```

### Stage B: focused verification

Используй команды из issue-specific `run-instructions.md`.  
Если issue-specific файл не дал команду, используй targeted suite из `plan.md`.

### Stage C: regression

```bash
RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rspec
```

## 6. Правила ручной проверки

- Каждому сценарию из `acceptance-scenarios.md` должны соответствовать:
  - команда;
  - ожидаемый результат;
  - отдельная команда проверки или SQL.
- Для HTTP-проверок указывай готовый `curl`.
- Для model/service-проверок указывай `rails runner` или копируемый блок для `rails console`.
- Для проверки данных предпочитай:

```bash
bundle exec rails runner 'puts Model.where(...).pluck(...)'
```

или явный SQL через `psql`.

- Если сценарий зависит от логов, укажи:
  - какой лог читать;
  - что считается сигналом успеха;
  - какой симптом означает скрытую ошибку.

## 7. Сброс состояния

### Сброс development DB

```bash
RAILS_ENV=development API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_dev bundle exec rails db:reset
```

### Сброс test DB

```bash
RAILS_ENV=test API_KEY=test-api-key DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5432/ai_da_collect_test bundle exec rails db:schema:load
```

## 8. Git verification checklist

Перед фиксацией результата агент или человек должен пройти этот чеклист:

```bash
git status --short
git diff --stat
git diff --name-only
```

Потом подтвердить:

1. В diff только файлы из текущего scope и артефакты issue.
2. Нет случайных ENV, логов, временных файлов, локальных дампов.
3. Focused verification зелёная.
4. Full regression зелёная или blocker явно зафиксирован.
5. `run-instructions.md` ссылается на этот runbook и содержит только feature-specific шаги.

## 9. Что должен содержать issue-specific run-instructions

Каждый `memory-bank/issues/NNNN-slug/run-instructions.md` обязан:

- начинаться ссылкой на этот `RUNBOOK.md`;
- ссылаться на `AGENT_PRIMERING.md`, если файл пишет или исполняет ИИ-агент;
- перечислять только feature-specific:
  - focused commands;
  - manual scenarios;
  - invariants;
  - reset notes;
  - известные блокеры именно этой фичи.
