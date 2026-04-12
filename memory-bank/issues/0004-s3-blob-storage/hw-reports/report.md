# HW-1 Report — Issue #0004: S3 Blob Storage

**Feature:** S3-Compatible Raw Blob Storage Adapter (Хранилище raw blob через S3-совместимый адаптер)  
**GitHub Issue:** https://github.com/asromanychev/ai-da-collect/issues/4  
**Документы:** `memory-bank/issues/0004-s3-blob-storage/`  
**Дата:** 2026-04-07

---

## 1. Затраченное время

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 5 (v1→v5) + 6 review | ~35 мин | ~12 мин |
| Spec | 2 (v1→v2) | ~15 мин | ~8 мин |
| Plan | 2 (v1→v2) | ~15 мин | ~8 мин |
| Имплементация | 1 code review + runtime-check | ~15 мин | ~10 мин |
| **Итого** | | **~1 ч 20 мин** | **~38 мин** |

Методика оценки: использована та же грубая модель, что и в `0001`-`0003`: около ~7 мин личного времени на цикл чтение/решение/следующий прогон, ~2-3 мин агента на generation/review, плюс отдельное время на локальные команды и финальную проверку кода. Для `0004` цикл получился заметно короче предыдущих задач: основная стоимость пришлась на очистку Brief и на поздний runtime-gate для regression suite.

> Если продолжать эту серию, уже имеет смысл отдельно фиксировать `document churn` и `runtime churn`: в `0004` они уже расходятся по источникам стоимости.

---

## 2. Итерации по этапам

### Brief — 5 итераций (brief-v1 → brief-v5)

| Версия | Замечания | Ключевые нарушения |
|---|---|---|
| v1 | 1 blocker | Недоопределённые термины в Success Criteria, конфликт с открытыми вопросами |
| v2 | 1 | Scope drift: широкий архитектурный фон про storage/attachments против фактического blob-only scope |
| v3 | 1 | Термины success-path всё ещё не закрыты наблюдаемым поведением |
| v4 | 1 | Остаточная несогласованность между критерием успеха и границами задачи |
| **v5** | **0** | — |

**Главная причина churn в Brief:** агент несколько циклов подряд не схлопывал задачу до одного канонического объекта scope. Документ начинал с широкого архитектурного фона вокруг object storage, а success-path реально относился только к raw blob. Вторая повторяющаяся проблема — незакрытые термины в критерии успеха: wording менялся, но наблюдаемая граница результата долго оставалась неявной.

---

### Spec — 2 итерации (spec-v1 → spec-v2)

| Версия | Результат | Нарушения |
|---|---|---|
| v1 | Fail (U, Grounding, Preconditions) | IO-ветка осталась только в prose; скрытый runtime-branch через `from_env`; внешний prerequisite не вынесен в `Preconditions` |
| **v2** | **0 замечаний** | — |

**Главная причина churn в Spec:** не happy-path сервиса, а `runtime-branch split`. Первая версия пыталась одновременно держать injectable-конструктор и `from_env`-подобный runtime path, хотя bootstrap/ENV wiring был вне scope. После выноса runtime wiring в precondition и материализации IO-case отдельным AC спека сошлась сразу.

---

### Plan — 2 итерации (plan-v1 → plan-v2)

| Версия | Замечания | Ключевые нарушения |
|---|---|---|
| v1 | 2 | Нет отдельного regression gate для existing suite; secret-free prerequisite остался декларативным |
| **v2** | **0** | — |

**Главная причина churn в Plan:** verification architecture. Первый план умел проверять новый service spec, но не доказывал требование `existing tests remain green` и не превращал тезис "без AWS secrets / без live S3" в наблюдаемую команду. Исправление сработало быстро: план разделили на focused verification и отдельный final regression gate.

---

### Имплементация — 1 ревью кода

| Ревью | Вердикт | Ключевой вывод |
|---|---|---|
| code-review-1 | Эквивалентно* | Код и service spec совпадают со спецификацией; единственный незакрытый риск — DB-backed regression gate |

\* Scorecard при этом честно дала `verdict = runtime_unknown`, потому что финальная команда из `plan.md` не материализовалась локально: `spec/rails_helper.rb` падает на `ActiveRecord::ConnectionNotEstablished`, когда test DB недоступна.

**Фактическая локальная проверка в текущем цикле:**
- `bundle exec rspec spec/services/collect/blob_storage_spec.rb` — **18 examples, 0 failures**
- Команда завершилась с `exit 1` не из-за логического дефекта сервиса, а из-за project-level coverage gate: `Coverage 37.25% is below 80.00%`
- Финальный regression gate из `plan.md` для `spec/models/*` и `spec/core/collect` остался `runtime-unknown` без доступной test DB

Это делает `0004` ближе к `0002`, чем к `0003`: по коду задача выглядит завершённой, но полная runtime-верификация окружения не была доведена до materialized green gate.

---

## 3. Качество результата агента

**Итог:** на уровне кода и локального service contract результат сильный и узко scoped: `Collect::BlobStorage` реализован без scope breach, AC покрыты тестами, adversarial cases для IO и metadata aliasing материализованы. Но end-to-end runtime-готовность задачи не была доказана полностью: финальный DB-backed regression gate остался непройденным в доступной среде.

**Что хорошо:**
- После очистки scope агент быстро сошёлся на компактной и правильной сервисной границе: `new(bucket:, client:)` + `#store`.
- Spec и Plan исправились всего за одну дополнительную итерацию каждый: архитектурный риск был локализован точно.
- Code-cycle не ушёл в лишние зоны проекта: allowlist соблюдён, `core/lib` и bootstrap не затронуты.
- В тестах есть хорошие adversarial проверки: no early `read`, repeated writes, metadata isolation.

**Где потребовалась правка:**
- Агент сначала не удержал `scope-canonicalization`: документ колебался между широкой storage-задачей и blob-only feature.
- В первой версии спеки runtime prerequisite был замаскирован как обычный implementation path через `from_env`.
- В code-review возникло внутреннее противоречие: markdown review закончилось `0 замечаний`, хотя scorecard одновременно зафиксировала `runtime_unknown`.

**Итоговая оценка качества: 8/10.** Для узкого service-layer контракта результат качественный и аккуратный, но процесс всё ещё недодержал главный execution-gate: regression suite c DB prerequisite.

---

## 4. Что нужно изменить в промптах

Рекомендации основаны на `iterations/analysis/cycle-analysis-1.md`.

### `01-1-generate-brief.md`
**Что добавить:** `scope-canonicalization gate`. Если issue описывает широкий storage-фон, а текущая задача покрывает только один подтип артефакта, агент обязан выбрать один канонический объект scope и провести его без подмены через весь Brief.

### `03-1-fix-brief.md`
**Что добавить:** `term-closure gate`. Если review указывает на недоопределённый термин в Success Criteria, исправление должно либо переводить его в наблюдаемое поведение, либо честно выносить в блокирующий open question.

### `01-2-generate-spec.md`
**Что добавить:** `runtime-branch split gate`. Любая ветка API, завязанная на `ENV`, secrets, bootstrap или client construction, должна быть либо полностью grounded в текущем issue, либо вынесена в `Preconditions / out of scope`.

### `02-2-review-spec.md`
**Что добавить:** обязательную матрицу `FR/input branch -> success AC -> invalid-branch AC` для union-type и duck-typed контрактов. Это особенно важно для веток вроде `String или IO-like`.

### `01-3-generate-plan.md`
**Что добавить:** обязательный `two-tier runtime gate`: отдельно focused verification нового контракта и отдельно final regression gate по существующему suite.

### `02-3-review-plan.md`
**Что добавить:** `verification-prerequisite closure gate`. Для каждой финальной команды план должен доказывать, что все её runtime prerequisites наблюдаемо материализованы раньше.

### `01-4-generate-code.md`
**Что добавить:** `pre-completion runtime gate`. Кодовый этап нельзя считать завершённым только по unit/service-pass, если active plan ещё требует DB-backed regression или другой внешний execution prerequisite.

### `02-4-review-code.md`
**Что добавить:** явный запрет на финальную формулу `0 замечаний`, пока scorecard не имеет `verdict = ready_for_activation` и пока остаётся хотя бы один незакрытый `runtime-unknown gate`.

---

## 5. Наблюдения по Context Engineering

- **Чистый scope снова дешевле широкого фона:** как только Brief перестал обещать "storage вообще", а зафиксировал именно raw blob adapter, следующие артефакты резко ускорились.
- **Главный churn `0004` был не в логике кода, а в runtime-hygiene:** `from_env`, secret-free verification и DB-backed regression gate.
- **Canonical artifacts важны не только для порядка, но и для анализа:** у `spec`, `plan`, `code` были rubric/scorecard/activation, а у `brief` analysis пришлось делать по markdown reviews, что хуже для machine-readable сходимости.
- **Scorecard дисциплинирует лучше markdown review:** именно `code-score-1.json` честно удержал verdict `runtime_unknown` и показал, что задача ещё не имеет полного runtime-proof, несмотря на положительный prose verdict.

---

## Ссылки

- Brief (финал): `memory-bank/issues/0004-s3-blob-storage/brief.md`
- Spec (финал): `memory-bank/issues/0004-s3-blob-storage/spec.md`
- Plan (финал): `memory-bank/issues/0004-s3-blob-storage/plan.md`
- Все итерации: `memory-bank/issues/0004-s3-blob-storage/iterations/`
- Рекомендации по промптам: `memory-bank/issues/0004-s3-blob-storage/iterations/analysis/cycle-analysis-1.md`
