# Reprocess Report — Issue #0002

**Feature:** Source Checkpoint Persistence  
**GitHub Issue:** https://github.com/asromanychev/ai-da-collect/issues/2  
**Документы:** `memory-bank/issues/0002-source-checkpoint/`  
**Дата:** 2026-04-12

## Что было добавлено

- новые active `brief.md`, `spec.md`, `plan.md` под текущие lifecycle gates;
- `acceptance-scenarios.md` и `run-instructions.md`;
- rubric/review/score для `brief/spec/plan`;
- activation trace для active-артефактов;
- новый code scorecard с явным blocker;
- новый postmortem и comparison layer.

## Сравнение со старым пакетом

### Что стало лучше

- У feature появился нормальный traceability contract: `REQ -> SC -> CHK -> EVID`.
- Стало видно, что старый пакет был не fully complete по новому процессу, хотя выглядел зрелым.
- Code-stage теперь честно различает:
  - логика persistence выглядит корректной;
  - feature scope в коде уже смешан с downstream orchestration;
  - model runtime proof не подтверждён из-за недоступной DB.

### Что стало хуже

- Артефактов стало заметно больше.
- Для historical feature пересбор занял бы больше времени, чем старый lightweight package.
- Новый процесс хуже переносит “грязную историю” репозитория: mixed files сразу всплывают как проблемы процесса.

## Финальный verdict

**Лучше.** Для `0002` новый процесс даёт более полезный результат, чем старый:
- он улучшает качество active-документов;
- добавляет machine-readable gates;
- обнаруживает реальные process/runtime проблемы, которые старый пакет не удерживал достаточно жёстко.

**Цена улучшения:** больше документации и более жёсткий review на старые feature packages.

## Runtime evidence

- `bundle exec rspec spec/core/collect` -> `40 examples, 0 failures`
- `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` -> `ActiveRecord::ConnectionNotEstablished` / `PG::ConnectionBad`
- попытка `RAILS_ENV=test ... bin/rails db:prepare` на `127.0.0.1:5433` -> `connection refused`

## Что осталось незакрытым

1. Для clean code activation нужен доступный PostgreSQL test runtime.
2. Для clean feature isolation нужно либо разделить ownership downstream-логики `sync_step!`, либо явно маркировать shared carrier файлы при reprocess исторических issues.
