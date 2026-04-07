# HW-1: Сводный отчёт — Неделя 1, Полный SDD-цикл

**Проект:** [ai-da-collect](https://github.com/asromanychev/ai-da-collect)  
**Период:** 2026-04-04 — 2026-04-07  
**Фич реализовано:** 4  
**Артефакты:** `memory-bank/features/001`–`004` (brief + spec + plan для каждой)

---

## Структура сдачи

| Фича | Issue | Директория | Brief | Spec | Plan |
|---|---|---|---|---|---|
| Plugin Contract | [#1](https://github.com/asromanychev/ai-da-collect/issues/1) | `memory-bank/features/001/` | brief.md | spec.md | plan.md |
| Source Checkpoint | [#2](https://github.com/asromanychev/ai-da-collect/issues/2) | `memory-bank/features/002/` | brief.md | spec.md | plan.md |
| Sync Orchestration | [#3](https://github.com/asromanychev/ai-da-collect/issues/3) | `memory-bank/features/003/` | brief.md | spec.md | plan.md |
| S3 Blob Storage | [#4](https://github.com/asromanychev/ai-da-collect/issues/4) | `memory-bank/features/004/` | brief.md | spec.md | plan.md |

CI, тесты и README с badge — в репозитории [ai-da-collect](https://github.com/asromanychev/ai-da-collect).

---

## 1. Затраченное время (по фичам)

### Feature 001 — Plugin Contract

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 9 (v1→v9) | ~65 мин | ~20 мин |
| Spec | 2 (v1→v2) | ~15 мин | ~8 мин |
| Plan | 4 (v1→v4) | ~30 мин | ~12 мин |
| Имплементация | 3 ревью кода | ~35 мин | ~25 мин |
| **Итого** | | **~2 ч 25 мин** | **~65 мин** |

### Feature 002 — Source Checkpoint

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 5 (v1→v5) | ~35 мин | ~12 мин |
| Spec | 6 (v1→v6) | ~40 мин | ~18 мин |
| Plan | 7 (v1→v7) + review | ~55 мин | ~24 мин |
| Имплементация | 2 ревью кода + runtime | ~20 мин | ~15 мин |
| **Итого** | | **~2 ч 30 мин** | **~69 мин** |

### Feature 003 — Sync Orchestration

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 8 (v1→v8) | ~55 мин | ~18 мин |
| Spec | 5 (v1→v5) | ~35 мин | ~14 мин |
| Plan | 9 (v1→v9) + review | ~85 мин | ~40 мин |
| Имплементация | 8 ревью кода + runtime | ~70 мин | ~45 мин |
| **Итого** | | **~4 ч 5 мин** | **~1 ч 57 мин** |

### Feature 004 — S3 Blob Storage

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 5 (v1→v5) + review | ~35 мин | ~12 мин |
| Spec | 2 (v1→v2) | ~15 мин | ~8 мин |
| Plan | 2 (v1→v2) | ~15 мин | ~8 мин |
| Имплементация | 1 ревью кода + runtime | ~15 мин | ~10 мин |
| **Итого** | | **~1 ч 20 мин** | **~38 мин** |

### Итог по всем фичам

| | Личное время | Время агента |
|---|---|---|
| Brief (4 фичи) | ~3 ч 10 мин | ~62 мин |
| Spec (4 фичи) | ~1 ч 45 мин | ~48 мин |
| Plan (4 фичи) | ~3 ч 5 мин | ~84 мин |
| Имплементация (4 фичи) | ~2 ч 20 мин | ~95 мин |
| **Всего** | **~10 ч 20 мин** | **~4 ч 49 мин** |

Методика оценки: ~7 мин личного времени на цикл (читать вывод агента + решить что менять + запустить следующий промпт), ~2–3 мин агента на generation/review. Для `0003` и `0004` учтено дополнительное время на runtime-check и debug churn.

---

## 2. Качество результата агента (по фичам)

### Feature 001 — Plugin Contract: **8/10**

**Тесты:** `bundle exec rspec spec/core/collect/` — 40 examples, 0 failures.  
**Что хорошо:** точный grounding по файлам/строкам из spec.md; быстрая сходимость после чистого Brief; корректная реализация `deep_dup`/`deep_freeze`, `NullPlugin`, `PluginRegistry`.  
**Что потребовало правки:** агент не проявлял инициативу в adversarial сценариях (мутабельные ключи Hash) до явного указания; смешивал `runtime-unknown gate` и `provable defect` в code review.

### Feature 002 — Source Checkpoint: **7.5/10**

**Тесты:** `bundle exec rspec spec/core/collect` — 40 examples, 0 failures. Rails model specs (`spec/models/*`) не стартовали в доступной среде из-за `PG::ConnectionBad`.  
**Что хорошо:** быстрый code review (2 итерации); хорошая материализация adversarial сценариев в Spec.  
**Что потребовало правки:** системная недооценка `precondition hygiene` (внешний `CheckpointAmbiguityError`); агент писал желаемые тесты без доказательства их исполнимости в реальной схеме; финальный runtime gate не закрыт из-за отсутствия Postgres.

### Feature 003 — Sync Orchestration: **8.5/10**

**Тесты (финал):**
- `bundle exec rspec spec/models/source_spec.rb` — 37 examples, 0 failures
- `bundle exec rspec --format json` — 85 examples, 0 failures, pending: 0, errors_outside: 0

**Что хорошо:** агент удержал duck-typed orchestration без лишней архитектуры; финальный код сошёлся без доказуемых функциональных дефектов; поздний цикл довёл до materialized runtime-gates.  
**Что потребовало правки:** системная недооценка `precondition hygiene` (runtime-доступность `Collect`); ложные execution signals (`0 pending` ≠ зелёный suite); реальный churn на scope breach (`EXMAPLES.md`, `.env.example`, `config/database.yml`).

### Feature 004 — S3 Blob Storage: **8/10**

**Тесты:** `bundle exec rspec spec/services/collect/blob_storage_spec.rb` — 18 examples, 0 failures. Завершение с exit 1 из-за coverage gate (37.25% < 80%) — не логический дефект, а регрессия проекта. Финальный DB-backed regression gate остался `runtime-unknown`.  
**Что хорошо:** компактная сервисная граница (`Collect::BlobStorage`); Spec и Plan исправились за одну итерацию каждый; allowlist соблюдён, scope breach отсутствует.  
**Что потребовало правки:** агент сначала не удержал `scope-canonicalization`; runtime prerequisite в первой версии Spec был замаскирован как обычный implementation path.

---

## 3. Что нужно изменить в промптах

Сводные рекомендации на основе cycle-analysis по каждой фиче.

### `01-1-generate-brief.md` (генерация Brief)

- **Scope-canonicalization gate:** если issue описывает широкий фон, агент обязан выбрать один канонический объект scope и провести его без подмены через весь Brief.
- **Success-criterion leakage gate:** любой пункт SC должен описывать только наблюдаемое состояние системы или доменный переход. Тесты, bootstrap, API-классы, транзакционные термины, изоляция окружения — блокирующее нарушение.
- **Term-closure gate:** для каждого термина в SC, который задаёт выборку, возобновление или error reaction, агент обязан выписать наблюдаемое различие состояний; если нельзя без Solution Space — вынести в блокирующий open question.

### `02-1-review-brief.md` (ревью Brief)

- **Solution-artifact leakage check:** отдельное блокирующее замечание, если SC начинает перечислять миграции, тесты, фикстуры, БД-движок вместо поведения системы.
- **Root-cause aggregation:** несколько wording-замечаний должны схлопываться к одному корневому semantic defect перед выдачей в следующую итерацию.

### `01-2-generate-spec.md` (генерация Spec)

- **Precondition-hygiene gate:** для каждого runtime/bootstrap prerequisite — либо честный `Preconditions + stop condition`, либо минимальный remedy in scope. Скрытые prerequisites запрещены.
- **Runtime-branch split gate:** любая ветка API, завязанная на `ENV`, secrets или bootstrap, либо полностью grounded в текущем issue, либо вынесена в `Preconditions / out of scope`.
- **Adversarial scenario gate:** для каждого инварианта про immutability/determinism/isolation — немедленно генерировать adversarial сценарий. Без него spec не считается готовой.

### `02-2-review-spec.md` (ревью Spec)

- **Module-budget check:** если документ затрагивает более 3 модульных зон — блокирующий fail.
- **Boundary class matrix:** таблица `FR/input branch -> success AC -> invalid-branch AC` для union-type и duck-typed контрактов. Общий `error`-bucket не засчитывается как покрытие отдельных shape-веток.
- **TAUS check:** явно закрыты ли неприменимые состояния loading/in-progress.

### `01-3-generate-plan.md` (генерация Plan)

- **Delta-first формулировка:** для каждого edit-шага — `что уже есть → чего не хватает → что не трогать`.
- **Observable gate rule:** любой gate сначала доказывает, что runtime/suite загрузились (`boot success`, `errors_outside_of_examples_count == 0`), и только потом считает pending/examples/coverage.
- **Two-tier runtime gate:** отдельно focused verification нового контракта и отдельно final regression gate по существующему suite.

### `02-3-review-plan.md` (ревью Plan)

- **Clean final runtime gate:** последний шаг — только команды и критерий прохождения; любое `если упало — поправить здесь же` является блокирующим нарушением атомарности.
- **Step observability check:** шаг должен уметь различать `suite not loaded` и `0 pending`. Если не умеет — блокирующий дефект.
- **Verification-prerequisite closure:** для каждой финальной команды доказать, что все runtime prerequisites материализованы раньше.

### `01-4-generate-code.md` (генерация кода)

- **Pre-edit runtime gate:** если spec/plan содержат prerequisite по boot/DB/load-path, агент до первой правки обязан подтвердить prerequisite командой или остановиться как `implementation blocker`.
- **Allowlist enforcement:** перед началом правок — сверить allowlist файлов из spec.md/plan.md с фактическими изменениями.

### `02-4-review-code.md` (ревью кода)

- **Provable defect vs runtime-unknown gate:** явно различать — вердикт `Неэквивалентно` только при наличии доказуемого контрпримера в коде.
- **Запрет `0 замечаний`** пока scorecard содержит `verdict = runtime_unknown` и есть незакрытый runtime-unknown gate.
- **Scope-and-runtime context:** перед verdict code review собирает разрешённые файлы из плана, materialized schema, test helpers и фактический diff.

---

## 4. Наблюдения по Context Engineering

- **Чистый Brief резко сокращает итерации на последующих этапах.** Brief с 9 итерациями (001) привёл к Spec за 2 итерации; Brief с 5 итерациями (004) привёл к Spec и Plan за 2 итерации каждый.
- **Главный источник churn во всех фичах — не предметная логика, а executable grounding:** precondition hygiene, test bootstrap, DB state simulation, final runtime gate.
- **Scope lock важнее, чем кажется:** вынос внешних prerequisites (CheckpointAmbiguityError, ENV wiring) в precondition резко чистил Spec и Plan.
- **Разделение этапов на отдельные сессии снижает churn:** когда Brief + Spec + Plan в одной сессии, агент начинал подтягивать детали Spec в Brief.
- **Статический `Эквивалентно` недостаточен для runtime-heavy задач.** У 001 был чистый end-to-end runtime; у 003 потребовался явный `rails runner` и полный `rspec --format json`; у 002 и 004 финальный DB-backed gate остался `runtime-unknown` из-за инфраструктуры.
- **Scorecard дисциплинирует лучше prose review:** именно machine-readable scorecard честно удерживал `runtime_unknown` в 004, несмотря на `0 замечаний` в markdown review.

---

## Ссылки на артефакты

| Фича | Brief | Spec | Plan | Итерации | hw-report |
|---|---|---|---|---|---|
| 001 Plugin Contract | [brief](../../memory-bank/features/001/brief.md) | [spec](../../memory-bank/features/001/spec.md) | [plan](../../memory-bank/features/001/plan.md) | ai-da-collect: `issues/0001-plugin-contract/iterations/` | [report](https://github.com/asromanychev/ai-da-collect/blob/main/memory-bank/issues/0001-plugin-contract/hw-reports/report.md) |
| 002 Source Checkpoint | [brief](../../memory-bank/features/002/brief.md) | [spec](../../memory-bank/features/002/spec.md) | [plan](../../memory-bank/features/002/plan.md) | ai-da-collect: `issues/0002-source-checkpoint/iterations/` | [report](https://github.com/asromanychev/ai-da-collect/blob/main/memory-bank/issues/0002-source-checkpoint/hw-reports/report.md) |
| 003 Sync Orchestration | [brief](../../memory-bank/features/003/brief.md) | [spec](../../memory-bank/features/003/spec.md) | [plan](../../memory-bank/features/003/plan.md) | ai-da-collect: `issues/0003-sync-orchestration/iterations/` | [report](https://github.com/asromanychev/ai-da-collect/blob/main/memory-bank/issues/0003-sync-orchestration/hw-reports/report.md) |
| 004 S3 Blob Storage | [brief](../../memory-bank/features/004/brief.md) | [spec](../../memory-bank/features/004/spec.md) | [plan](../../memory-bank/features/004/plan.md) | ai-da-collect: `issues/0004-s3-blob-storage/iterations/` | [report](https://github.com/asromanychev/ai-da-collect/blob/main/memory-bank/issues/0004-s3-blob-storage/hw-reports/report.md) |
