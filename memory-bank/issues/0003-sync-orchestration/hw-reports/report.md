# HW-1 Report — Issue #0003: Sync Orchestration

**Feature:** One-Step Sync Orchestration (Оркестрация одного шага синка)  
**GitHub Issue:** https://github.com/asromanychev/ai-da-collect/issues/3  
**Документы:** `memory-bank/issues/0003-sync-orchestration/`  
**Дата:** 2026-04-06

---

## 1. Затраченное время

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 8 (v1→v8) | ~55 мин | ~18 мин |
| Spec | 5 (v1→v5) | ~35 мин | ~14 мин |
| Plan | 9 (v1→v9) + 11 review | ~85 мин | ~40 мин |
| Имплементация | 8 ревью кода + runtime-check | ~70 мин | ~45 мин |
| **Итого** | | **~4 ч 5 мин** | **~1 ч 57 мин** |

Методика оценки: использована та же грубая модель, что и в `0001`/`0002`: ~7 мин личного времени на цикл генерация/чтение/решение, ~2-3 мин агента на generation/review, плюс отдельное время на поздние code-review/fix циклы и реальные runtime-проверки. У `0003` основное удорожание пришлось на Plan и Code: много итераций ушло не на бизнес-логику, а на prerequisite/runtime-gates, materialization rollback-case и cleanup scope breach.

> Для следующих задач уже имеет смысл вести не только общий журнал времени, но и отдельно логировать `analysis churn` и `runtime/debug churn`: в `0003` они стали основным источником удорожания.

---

## 2. Итерации по этапам

### Brief — 8 итераций (brief-v1 → brief-v8)

| Версия | Замечания | Ключевые нарушения |
|---|---|---|
| v1 | 4 | Solution-artifact leakage в SC, незакрытые термины, субъективные формулировки |
| v2 | 3 | Test-isolation leakage, незакрытый термин `корректный шаг`, напряжённость scope vs `пригодность` |
| v3 | 2 | Противоречие `одинакова` между success/error, терминологическая непоследовательность |
| v4 | 3 | Циклическое определение успеха, неразличимые `ошибка/сбой`, расплывчатое `одинаково` |
| v5 | 3 | Problem/Solution leakage (`атомарно`), незакрытый `успешный результат`, лишнее обобщение по типам источников |
| v6 | 1 | Незакрытый термин `доступным` |
| v7 | 1 | Несогласованный субъект `зарегистрированный плагин` |
| **v8** | **0** | — |

**Главная причина churn в Brief:** агент долго не удерживал жёсткую границу между доменной инвариантой и инженерным способом её проверки. Почти весь цикл крутился вокруг success criteria: туда снова и снова протекали test isolation, bootstrap, транзакционные термины и неоперационализированные слова вроде `пригодный`, `одинаковый`, `доступный`.

---

### Spec — 5 итераций (spec-v1 → spec-v5)

| Версия | Результат | Нарушения |
|---|---|---|
| v1 | Fail (T, A, Invariants, Grounding) | Непроверяемые AC, расплывчатый duck-typed контракт, скрытый runtime prerequisite |
| v2 | Fail (U, Grounding, Precondition hygiene) | Недоматериализованные boundary-cases result shape, неоформленный bootstrap/runtime prerequisite |
| v3 | Fail (U) | Не выделен constructor-time invalid `source_config` как отдельный boundary-case |
| v4 | Pass | 0 замечаний |
| **v5** | **active** | Финальная редакция после успешного review |

**Главная причина churn в Spec:** не базовая логика orchestration, а `precondition hygiene` и materialization boundary-cases. Спека быстро стала хорошей по happy-path, но долго не доводила до буквальной наблюдаемости runtime bootstrap и отдельные adversarial ветки `result`/`source_config`.

---

### Plan — 9 итераций (plan-v1 → plan-v9)

| Версия | Замечания | Ключевые нарушения |
|---|---|---|
| v1 | 2 | Ложный pending-gate, незафиксированный runtime prerequisite |
| v2 | 1 | Ненаблюдаемый final gate |
| v3 | 1 | Расхождение между тестовой матрицей и финальным gate |
| v4 | 1 | Неполная materialization test matrix |
| v5 | 1 | Роллбэк-инвариант не наблюдаем в текущем lifecycle транзакций |
| v6 | 1 | То же: нужен явный savepoint-boundary |
| v7 | 1 | AC 17 не изолирует единственную переменную `класс плагина` |
| v8 | 4 | Ложный pending-gate, AC 10 не развёрнут по ключам, не хватает `checkpoint_out` non-Hash case, финальный dry-run gate маскирует boot-failure |
| **v9** | **0** | — |

**Главная причина churn в Plan:** наблюдаемость execution-gates. План несколько раз ломался не в production delta, а в том, как доказать, что suite вообще поднялся, что rollback реально виден как savepoint-boundary, и что тестовая матрица не пропускает независимые ветки контракта.

---

### Имплементация — 8 ревью кода

| Ревью | Вердикт | Ключевой вывод |
|---|---|---|
| code-review-1 | Неэквивалентно | Реализация ещё отсутствовала: нет `sync_step!`, нет тестов |
| code-review-2 | Эквивалентно* | Логика `sync_step!` и тесты уже сходятся по статике; открыты runtime/scope gates |
| code-review-3 | Неэквивалентно | Неполный test artifact и scope breach не позволили признать результат завершённым |
| code-review-4 | Эквивалентно* | Остались внеплановый `EXMAPLES.md` и неподтверждённые runtime-gates |
| code-review-5 | Эквивалентно* | Функционально всё реализовано; всё ещё открыт scope/runtime cleanup |
| code-review-6 | Эквивалентно* | Логика и AC закрыты; rollback и full suite ещё runtime-unknown |
| code-review-7 | Эквивалентно* | После bootstrap/runtime remedу остаются только scope breach и runtime-gates |
| **code-review-8** | **Эквивалентно** | Scope чистый, runtime-gates закрыты фактическим исполнением |

\* Положительный verdict по логике, но не финальная чистая сходимость: оставались `scope breach` и/или `runtime-unknown gate`.

**Фактическая runtime-верификация в финале:**
- `bin/rails runner 'puts Collect::CheckpointAmbiguityError'` — успешно, константа доступна в обычном boot.
- `RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5433/ai_da_collect_test bundle exec rspec spec/models/source_spec.rb` — **37 examples, 0 failures**.
- `RAILS_ENV=test DATABASE_URL=postgresql://ai_da_collect:ai_da_collect@127.0.0.1:5433/ai_da_collect_test bundle exec rspec --format json` — **85 examples, 0 failures, pending_count: 0, errors_outside_of_examples_count: 0**.

Это главное отличие от `0002`: здесь поздний runtime всё-таки был полностью материализован и закрыл и bootstrap prerequisite, и full-suite gate.

---

## 3. Качество результата агента

**Итог:** финальная реализация выглядит полноценной и закрытой end-to-end: `Source#sync_step!` реализован, `Collect` доступен в application runtime через минимальный initializer, целевые model specs и весь suite зелёные, финальный code review — без замечаний.

**Что хорошо:**
- Агент в итоге хорошо удержал duck-typed orchestration без лишней архитектуры: `build -> sync_step -> validate -> upsert`.
- После стабилизации Spec финальная логика в коде сошлась быстро и без доказуемых функциональных дефектов.
- Поздний цикл всё же довёл задачу до materialized runtime-gates, а не остановился на статическом `Эквивалентно`.

**Где потребовалась правка:**
- Агент системно недооценивал `precondition hygiene`: runtime-доступность `Collect` слишком долго существовала как скрытая предпосылка.
- В Plan и Code несколько циклов ушло на ложные execution signals: `0 pending` мог означать не зелёный suite, а сломанный boot.
- Материализация инвариантов была неровной: rollback-case, AC 10 и non-Hash `checkpoint_out` пришлось доводить явно через review.
- Был реальный churn на `scope breach`: сначала `EXMAPLES.md`, позже `.env.example`, `config/database.yml`, `lib/collect.rb`.

**Итоговая оценка качества: 8.5/10.** Сильный конечный результат с полным runtime-подтверждением, но путь до него оказался заметно дороже, чем должен был быть, из-за слабого контроля prerequisites, observability-gates и change-scope.

---

## 4. Что нужно изменить в промптах

Рекомендации основаны на `cycle-analysis-1.md`.

### `01-1-generate-brief.md`
**Что добавить:** `success-criterion leakage gate`. Любой пункт Success Criteria должен описывать только наблюдаемое состояние системы или доменный переход. Если в критерий попали тесты, bootstrap, API, классы, return values, транзакционные термины или условия изоляции окружения — переписывать до сохранения.

### `02-1-review-brief.md`
**Что добавить:** требование сначала схлопывать несколько wording-замечаний к одному корневому semantic defect. В `0003` один и тот же незакрытый инвариант порождал длинную серию косметических правок.

### `01-2-generate-spec.md`
**Что добавить:** обязательный `precondition-hygiene gate`. Для каждого runtime/bootstrap prerequisite агент обязан выбрать ровно одно: либо честный `Preconditions + stop condition`, либо минимальный remedy в scope. Скрытые prerequisites запрещены.

### `02-2-review-spec.md`
**Что добавить:** таблицу `boundary class -> отдельный scenario/AC`. Общий `error`-bucket не должен засчитываться как покрытие constructor invalid config, missing keys, `checkpoint_out: nil`, `checkpoint_out: "bad"` и других shape-веток.

### `01-3-generate-plan.md`
**Что добавить:** `observable gate rule`. Любой observational/final gate сначала доказывает, что runtime/suite вообще загрузились (`boot success`, `errors_outside_of_examples_count == 0`), и только потом считает pending/examples/coverage.

### `02-3-review-plan.md`
**Что добавить:** проверку `step goal -> observable signal -> unique failure mode`. Если шаг не умеет различить `suite not loaded` и `0 pending`, либо `другая входная позиция` и `другой класс плагина`, он должен считаться блокирующе дефектным.

### `01-4-generate-code.md`
**Что добавить:** обязательный `pre-edit runtime gate`. Если active spec/plan содержат prerequisite по boot/DB/load-path, агент до первой правки обязан либо подтвердить prerequisite командой, либо остановиться как `implementation blocker`.

### `03-4-fix-code.md`
**Что добавить:** разведение путей для `scope breach`, `runtime-unknown gate` и `provable defect`. В `0003` поздние fix-циклы несколько раз продолжали переписывать код там, где проблема уже была не в бизнес-логике, а в scope/runtime cleanup.

### `02-4-review-code.md`
**Что добавить:** если code review обнаруживает минимальный runtime remedy, который реально нужен для declared prerequisite, review должен уметь рекомендовать возврат на обновление active spec/plan, а не бесконечно копить `scope breach` против уже корректного кода.

---

## 5. Наблюдения по Context Engineering

- **Curated context по-прежнему лучше raw context:** как только Brief очистился от solution-artifact leakage, Spec сразу стал спорить уже о реальных boundary-cases, а не о доменной путанице.
- **Главный источник churn в `0003` был execution-grounding, а не предметная логика:** prerequisite boot, pending-gates, savepoint observability и чистота финального runtime-сигнала.
- **Materialized prerequisites критичны:** пока runtime-доступность `Collect` была только текстовым допущением, цикл Code постоянно давал ложные боковые проблемы.
- **План должен описывать не только что делать, но и как именно это будет наблюдаемо доказано:** в `0003` слабое место было не в дельтах кода, а в том, что pass/fail нескольких шагов сначала нельзя было однозначно интерпретировать.
- **Статический `Эквивалентно` недостаточен для runtime-heavy задач:** полезно, что цикл довели до фактического `rails runner` и полного `rspec --format json`; без этого `0003` остался бы в промежуточном состоянии, похожем на `0002`.

---

## Ссылки

- Brief (финал): `memory-bank/issues/0003-sync-orchestration/brief.md`
- Spec (финал): `memory-bank/issues/0003-sync-orchestration/spec.md`
- Plan (финал): `memory-bank/issues/0003-sync-orchestration/plan.md`
- Все итерации: `memory-bank/issues/0003-sync-orchestration/iterations/`
- Рекомендации по промптам: `memory-bank/issues/0003-sync-orchestration/iterations/cycle-analysis-1.md`
