# HW-1 Report — Issue #0005: Raw Ingest Item Persistence

**Feature:** RawIngestItem — AR-модель для персистентности ingested объектов в PostgreSQL (skip-with-log семантика)  
**GitHub Issue:** https://github.com/asromanychev/ai-da-collect/issues/5  
**Документы:** `memory-bank/issues/0005-raw-ingest-item/`  
**Дата:** 2026-04-07

---

## 1. Затраченное время

| Этап | Итераций | Личное время | Время агента |
|---|---|---|---|
| Brief | 2 (v1→v2) + 2 review | ~15 мин | ~5 мин |
| Spec | 1 (v1 → активация) | ~10 мин | ~5 мин |
| Plan | 1 (v1 → активация) | ~10 мин | ~4 мин |
| Имплементация | 1 code review + 2 runtime fix | ~15 мин | ~8 мин |
| **Итого** | | **~50 мин** | **~22 мин** |

Методика оценки: та же грубая модель, что и в `0001–0004`: ~7 мин личного времени на цикл, ~2-3 мин агента на generation/review. Issue 5 — самый быстрый цикл из пяти задач. Основная стоимость — Brief (1 blocker) и 2 runtime фикса при реализации (AR validation bypass + human_attribute_name).

> После очистки семантики в Brief все последующие этапы прошли за 1 итерацию. Это подтверждает: стоимость Brief-churn не в самом Brief, а в downstream cascade.

---

## 2. Итерации по этапам

### Brief — 2 итерации (brief-v1 → brief-v2)

| Версия | Замечания | Ключевые нарушения |
|---|---|---|
| v1 | 1 blocker | Критерий успеха содержал нераскрытую альтернативу «(upsert или skip-with-log)» |
| **v2** | **0** | — |

**Главная причина churn в Brief:** Критерий успеха #1 содержал нераскрытую альтернативу в скобках. Вместо зафиксированной семантики — открытый выбор «перезапись или пропуск». Это сделало критерий неверифицируемым: невозможно написать тест, который проверяет «правильность», пока не выбрана одна семантика.

Fix: выбрать skip-with-log как единственную семантику и зафиксировать её в Доменном контексте. После этого Критерий успеха стал однозначным, и Brief прошёл review без замечаний.

---

### Spec — 1 итерация (spec-v1 → активация)

| Версия | Результат | Ключевые решения |
|---|---|---|
| **v1** | **Pass (5.0 / 5.0)** | Полная FR/input-branch матрица; adversarial AC для aliasing и duplicate INSERT; явный Preconditions section |

Spec прошла с первого прохода. Ключевые факторы:
- **Bulk-insert semantics явно зафиксированы в FR5:** атомарность через `INSERT ... ON CONFLICT DO NOTHING`, явное разграничение new vs duplicate path.
- **Adversarial AC:** AC6 (metadata aliasing), AC9 (direct duplicate INSERT через `create!`).
- **Неприменимые состояния явно помечены:** Loading, In-progress → Inapplicable.
- **FR/input-branch matrix:** все ветки source/external_id/storage_key/metadata покрыты.

Чистота Brief напрямую ускорила Spec — не нужно было переосмыслять доменные термины.

---

### Plan — 1 итерация (plan-v1 → активация)

| Версия | Результат | Ключевые решения |
|---|---|---|
| **v1** | **Pass (5.0 / 5.0)** | Two-tier gate; explicit AC→test mapping; test DB prerequisite материализован |

Plan прошёл с первого прохода. Ключевые факторы:
- **Two-tier runtime gate** с первого прохода: Шаг 4 (focused: `rspec spec/models/raw_ingest_item_spec.rb`) + Шаг 5 (regression: `rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb`).
- **Test DB prerequisite** явно указан: `rails db:migrate RAILS_ENV=test` в Шаге 4 и в §5.
- **AC→test mapping table** в Шаге 3: каждый из AC1-AC9 (кроме AC8 который в Шаге 5) имеет прямое соответствие.

Уроки из `0004` (отсутствие two-tier gate) напрямую применены здесь.

---

### Имплементация — 1 code review + runtime fix

| Прогон | Результат | Ключевой вывод |
|---|---|---|
| первый запуск | 8/10 examples pass, 2 failures | AC4: blank external_id не поднимал AR error |
| после fix | 10/10 examples pass | `insert` обходит AR validations — нужен explicit guard |
| regression gate | 45/45 examples pass | Existing suite не затронут |

**Детали runtime fix:**

**Баг 1: AR validation bypass через `insert`.** Метод `ingest!` использовал `insert` (bulk insert) с `validates :external_id, presence: true`. Bulk `insert` обходит instance-level AR validations. Результат: `ingest!(external_id: "")` проходил до БД без AR error. Fix: добавить explicit check до `insert`:
```ruby
if normalized_external_id.empty?
  dummy = new(source: source, external_id: normalized_external_id)
  dummy.valid?
  raise ActiveRecord::RecordInvalid.new(dummy)
end
```

**Баг 2: human_attribute_name.** Rails humanize для `external_id` генерирует «External» вместо «External id» по умолчанию. Тест ожидал «External id can't be blank». Fix: добавить `human_attribute_name` override по паттерну модели `Source`.

Оба бага были локально решены в рамках allowlist (только `app/models/raw_ingest_item.rb`).

---

## 3. Качество результата агента

**Итог:** самый чистый цикл из пяти задач по соотношению итераций к результату. Ни один этап не потребовал fix-итерации (Brief — 1 fix, но не scope breach; Spec/Plan — активированы с первого прохода). Единственный churn — 2 runtime fixes в имплементации, оба в allowlist.

**Что хорошо:**
- Brief после fix прошёл review сразу — изменение было минимальным и точным.
- Spec с первого прохода потому что FR5 явно описывал bulk-insert и его поведение.
- Plan с первого прохода потому что two-tier gate стал стандартным паттерном.
- Код минимален и соответствует scope: 3 файла, 0 scope breach.
- Adversarial тесты (aliasing, direct duplicate INSERT) материализованы и работают.

**Где потребовалась правка:**
- `insert` обходит AR validations — это системный паттерн, который должен был быть в Spec и Plan явно. Добавлен в шаблоны как `Bulk-insert validation bypass gate`.
- `human_attribute_name` — это project-convention из `Source`, который нужно воспроизводить. Добавлен в `01-4-generate-code.md`.

**Итоговая оценка качества: 9/10.** Цикл компактный, код чистый, оба runtime gates пройдены. Два фикса при реализации — из-за отсутствия явного gate в шаблонах (теперь добавлен).

---

## 4. Что нового по сравнению с предыдущими задачами

| Аспект | 0001–0003 | 0004 | 0005 |
|---|---|---|---|
| Brief iterations | 8–9 | 5 | 2 |
| Spec iterations | 2–5 | 2 | 1 |
| Plan iterations | 2–9 | 2 | 1 |
| Code runtime issues | DB-backed gate | DB-backed gate | AR validation bypass |
| Both runtime gates passed | ✗ (0001-0003) | ✗ | ✓ |
| New template improvements | Scope canon, runtime branch | Runtime gate, DB gate | Semantics-first, bulk-insert bypass |

---

## 5. Что нужно изменить в промптах

Рекомендации основаны на `iterations/analysis/cycle-analysis-1.md` и применены в `iterations/analysis/template-improvements-1.md`.

### `01-1-generate-brief.md`
**Добавлено:** `6.2. Semantics-first gate`. Альтернативы в AC запрещены до выбора одной семантики.

### `02-1-review-brief.md`
**Добавлено:** `1.1. Unresolved-alternative gate`. Нераскрытая альтернатива = автоматически blocker.

### `01-2-generate-spec.md`
**Добавлено:** `Bulk-insert validation bypass gate`. Явное разграничение AR validations (до insert) и DB constraints.

### `01-3-generate-plan.md`
**Добавлено:** `10.1. Bulk-insert validation delta`. Delta шага с `insert` обязана указывать validation guard.

### `01-4-generate-code.md`
**Добавлено:** `Bulk-insert validation guard` + `Human-attribute-name consistency`.

### `02-4-review-code.md`
**Добавлено:** `Bulk-insert validation bypass check`. Отсутствие guard = provable defect high.

---

## 6. Наблюдения по Context Engineering

- **Semantics-first критически важен для Brief:** как только неразрешённая альтернатива была закрыта, все downstream артефакты стали однозначными и прошли без замечаний.
- **Уроки из предыдущих циклов материализуются:** two-tier gate из `0004` был применён в Plan с первого прохода без напоминания.
- **AR `insert` vs validations — системный Ruby/Rails паттерн:** bulk-insert обходит instance callbacks и validations — это нужно держать в голове для любой модели с idempotent insert семантикой.
- **Маленькие задачи быстрее не из-за объёма, а из-за ясности scope:** `0005` быстрее `0004` не потому что модель проще, а потому что skip-with-log vs upsert был выбран явно на Brief уровне.

---

## Ссылки

- Brief (финал): `memory-bank/issues/0005-raw-ingest-item/brief.md`
- Spec (финал): `memory-bank/issues/0005-raw-ingest-item/spec.md`
- Plan (финал): `memory-bank/issues/0005-raw-ingest-item/plan.md`
- Все итерации: `memory-bank/issues/0005-raw-ingest-item/iterations/`
- Cycle analysis: `iterations/analysis/cycle-analysis-1.md`
- Template improvements: `iterations/analysis/template-improvements-1.md`
- Реализация: `app/models/raw_ingest_item.rb`, `db/migrate/20260407000000_create_raw_ingest_items.rb`, `spec/models/raw_ingest_item_spec.rb`
