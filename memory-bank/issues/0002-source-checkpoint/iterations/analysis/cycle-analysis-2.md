# Cycle Analysis — Reprocess of Issue #0002

## Что показал новый процесс

1. Новый workflow сразу сделал видимыми structural gaps старого пакета:
   - active `spec.md` не содержал `REQ-*`, `SC-*`, `CHK-*`, `EVID-*`;
   - active `plan.md` не содержал `PRE-*`, `STEP-*` и чистого runtime gate;
   - у feature не было `acceptance-scenarios.md`, `run-instructions.md`, activation-trace и machine-readable scorecards.

2. Новый workflow дал более сильный сигнал на code-stage:
   - feature-level review сразу увидел, что [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb#L27) и [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb#L1) уже смешивают scope `0002` с downstream orchestration;
   - runtime gate отдельно показал environment blocker: model specs не стартуют без доступной PostgreSQL test DB;
   - старый процесс это знал частично, но не материализовал в machine-readable verdict, который бы сразу блокировал clean activation.

3. Новый workflow лучше подходит для исторического пересбора:
   - старые markdown-итерации сохранены;
   - новые canonical artifacts добавлены без удаления старых;
   - стало возможно явно различать `artifact complete`, `logic looks correct`, `runtime proof missing`.

## Где новый процесс объективно лучше

- Лучше трассировка: требования, сценарии, проверки и evidence теперь связаны явно.
- Лучше stage completeness: по `brief/spec/plan` появились rubric/review/score и activation следы.
- Лучше сравнение между feature package и working tree: mixed-scope файл сразу становится проблемой процесса, а не скрытым знанием ревьюера.
- Лучше работа с historical debt: infrastructure blocker больше не выглядит как просто “не успели прогнать”.

## Где новый процесс объективно хуже

- Он дороже по артефактам и времени: на историческую feature приходится добавлять много process-layer файлов.
- Для старых issues на смешанном working tree code-stage редко будет “чистым”; процесс честнее, но строже и шумнее.
- Без режима `historical reprocess` агенту легко переусердствовать и пытаться “лечить” не feature, а поздние слои репозитория.

## Итоговый сравнительный verdict

Для `0002` новый процесс **лучше**, если цель — качество артефактов, трассировка и честный сигнал о статусе feature.

Для `0002` новый процесс **хуже**, если мерить только скоростью и объёмом документации.

Общий вывод: при этой задаче выигрыш по качеству сильнее, чем стоимость по бюрократии, потому что:
- старый пакет формально выглядел завершённым, но не проходил новые lifecycle gates;
- новый пакет сразу показал два реальных незакрытых места: mixed feature ownership и отсутствующий runtime proof для Rails model suite.
