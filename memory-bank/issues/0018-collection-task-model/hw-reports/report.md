# HW-1 Report — Issue #18: CollectionTask Data Model

**Feature:** CollectionTask — центральная доменная AR-модель с state machine, валидациями и FK-миграциями  
**GitHub Issue:** https://github.com/asromanychev/ai-da-collect/issues/18  
**Документы:** `memory-bank/issues/0018-collection-task-model/`  
**Дата:** 2026-04-13

---

## 1. Затраченное время

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 1 (v1 → активация) | ~10 мин | ~4 мин |
| Spec | 1 (v1 → активация) | ~15 мин | ~6 мин |
| Plan | 1 (v1 → активация) | ~15 мин | ~6 мин |
| Имплементация + review | 1 code iter + 3 runtime fix | ~30 мин | ~15 мин |
| Code review + документация | 1 iter | ~15 мин | ~10 мин |
| **Итого** | | **~85 мин** | **~41 мин** |

Это наиболее трудоёмкая задача из #1–#18 по масштабу: 3 миграции + 1 новая модель с state machine + обновление 3 моделей + 4 spec-файла. Несмотря на это, 0 fix-итераций во всех этапах — все артефакты активированы с v1.

---

## 2. Итерации по этапам

### Brief — 1 итерация (v1 → активация)

weighted_score 4.80. Единственное замечание (не blocker): CS-2 использовал технический термин "ошибка уникальности" вместо observability-формулировки. Не потребовало fix-итерации.

### Spec — 1 итерация (v1 → активация)

weighted_score 4.75. Замечание: отсутствовал SC-13 (collection_mode != polling без poll_interval_seconds). Reviewer рекомендовал добавить на следующей итерации, но это не блокировало активацию. SC-13 был добавлен непосредственно в код и spec.

### Plan — 1 итерация (v1 → активация)

weighted_score 4.60. Замечание: STEP-4b названо нестандартно (в графе — STEP-4). Замечание по test materialization: test DB setup не оформлен как отдельный STEP. Ни одно не было blocker.

Ключевые пропуски, обнаруженные только при runtime:
- Delta STEP-6 и STEP-7 не упоминали `foreign_key: :task_id` → `MissingAttributeError` при первом запуске тестов.
- Migration 3 не содержала DELETE orphans → `PG::ForeignKeyViolation` на dev DB.

Оба исправлены в коде без возврата к fix-циклу, но потребовали остановки и диагностики.

### Имплементация — runtime отклонения

3 блокера при реализации:

| Блокер | Причина | Шаг fix |
|---|---|---|
| `MissingAttributeError` в SC-11 | `belongs_to :collection_task` без `foreign_key: :task_id` | Добавить foreign_key: option в raw_ingest_item.rb и sync_checkpoint.rb |
| `PG::ForeignKeyViolation` в migration 3 | Orphan rows в sync_checkpoints (source_id=193) | Добавить DELETE FROM sync_checkpoints WHERE... перед rename_column |
| `ActiveRecord::EnvironmentMismatchError` при db:schema:load | Предыдущий db:migrate изменил RAILS_ENV=test env | Выполнить db:environment:set, затем db:schema:load |

Все три исправлены в рамках текущего allowlist без fix-цикла.

### Code Review — ready_for_activation (first pass)

weighted_score 4.90. 0 provable defects, 0 scope breaches. 2 runtime-unknown gates (стейл test DB, pre-existing bin/ci rubocop). Вердикт: Эквивалентно.

---

## 3. Качество результата

| Аспект | Оценка |
|---|---|
| Корректность state machine | 10/10 — все переходы верны, InvalidTransitionError протестирован |
| Инварианты (monotonic, immutable, orphan) | 10/10 — double protection: AR + DB level |
| Тест-покрытие | 9/10 — SC-1..SC-12 + SC-13 покрыты; 26/0 |
| Миграции | 9/10 — orphan data fix потребовался, но включён корректно |
| Документация SDD | 10/10 — все этапы, BDD-сценарии, run-instructions, cycle-analysis |

**Общая оценка: 9.6/10**

Потери: 2 runtime блокера в Plan (FK delta, orphan data) которые не были предотвращены на уровне документов.

---

## 4. Что нового по сравнению с предыдущими задачами (#1–#11)

1. **Ручной state machine** без внешнего гема — первый раз в проекте. Pattern: VALID_TRANSITIONS hash + private transition_to!.
2. **Multi-step migration** (3 связанные миграции) с orphan cleanup — самый сложный migration set в проекте.
3. **Non-standard FK naming** (task_id вместо collection_task_id) — потребовало явных `foreign_key:` опций во всех ассоциациях.
4. **Deprecation через xdescribe** — первый раз помечаем тесты pending с комментарием вместо удаления.
5. **Стейл test DB инцидент** — впервые staged validation загрязнила test DB и вызвала failures при возобновлении работы.

---

## 5. Что нужно изменить в промптах

По результатам cycle-analysis-1.md применены следующие изменения:

1. `01-1-generate-brief.md` — Observability gate для Критериев Успеха
2. `01-2-generate-spec.md` — Conditional validation coverage gate
3. `01-3-generate-plan.md` — Non-standard FK delta (10.2) + Orphan data gate (10.3)
4. `02-4-review-code.md` — Non-standard FK association check
5. `MAKE_NEW_ISSUE.md` — Test DB pollution gate в Staged Validation

Подробности: `iterations/analysis/template-improvements-1.md`.

---

## 6. Наблюдения по Context Engineering

**Межсессионный разрыв** — работа была прервана после staged validation и возобновлена через Summary в новой сессии. Это выявило:
- Стейл test DB (RUG-1): данные, созданные в предыдущей сессии, выжили после rollback rspec и вызвали failures.
- Context restoration: Summary корректно передал состояние, но не включил факт загрязнения test DB — агент обнаружил проблему самостоятельно при следующем запуске rspec.

**Lesson:** Staged validation step 6 с RAILS_ENV=test должен всегда заканчиваться db:schema:load как обязательным cleanup шагом.

**Трассировка spec→code**: SC-13 (missing от spec) был добавлен в код без обновления spec.md. Это разрыв трассировки. Conditional validation gate в `01-2-generate-spec.md` предотвращает это в будущих циклах.

---

## Ссылки

- GitHub Issue: https://github.com/asromanychev/ai-da-collect/issues/18
- Active Spec: `memory-bank/issues/0018-collection-task-model/spec.md`
- Active Plan: `memory-bank/issues/0018-collection-task-model/plan.md`
- Cycle Analysis: `memory-bank/issues/0018-collection-task-model/iterations/analysis/cycle-analysis-1.md`
- Template Improvements: `memory-bank/issues/0018-collection-task-model/iterations/analysis/template-improvements-1.md`
- Code Review: `memory-bank/issues/0018-collection-task-model/iterations/code/code-review-1.md`
- Score: `memory-bank/issues/0018-collection-task-model/iterations/code/code-score-1.json`
