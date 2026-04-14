# Template Improvements — Reprocess of Issue #0002

## Предлагаемые улучшения workflow

1. Добавить в `memory-bank/issues/README.md` режим `historical reprocess`.
   Причина: пересбор старых issues идёт поверх смешанного working tree, и агенту нужен явный протокол “документируй mixed ownership, но не переписывай downstream код молча”.

2. Добавить в review prompts отдельный gate `feature-purity vs shared carrier`.
   Причина: файлы вроде `app/models/source.rb` могут быть корректными по логике, но уже не feature-pure. Это не всегда баг, но это важный process signal.

3. Добавить в code scorecard стандартный verdict для случая `logic_ok_runtime_blocked`.
   Причина: `runtime_unknown` и `not_ready_for_activation` сейчас покрывают часть кейсов, но historical reprocess часто попадает ровно в состояние “контракт выглядит верным, но runtime не поднят”.

## Статус

В рамках этого reprocess шаблоны проекта не изменялись; улучшения зафиксированы как рекомендации для следующего прохода по workflow.
