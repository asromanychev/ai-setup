---
title: Feature Flow
doc_kind: governance
doc_function: canonical
purpose: "Определяет stage-based flow issue-документации и taxonomy стабильных идентификаторов (REQ-*, CHK-*, STEP-* и т.д.). Читать при создании или ведении issue package."
derived_from:
  - ../dna/governance.md
  - ../dna/frontmatter.md
canonical_for:
  - issue_directory_structure
  - issue_document_boundaries
  - feature_flow_stages
  - feature_plan_gate_rules
  - feature_closure_rules
  - feature_identifier_taxonomy
  - feature_traceability_rules
status: active
audience: humans_and_agents
---

# Feature Flow

Определяет порядок появления артефактов задачи. Агент ведёт issue package по стадиям и не создаёт downstream-артефакты раньше, чем созрел upstream-owner.

## Package Rules

1. Все документы одной задачи живут в `memory-bank/issues/NNNN-slug/`.
2. **Issue = vertical slice.** Одна задача — одна единица пользовательской ценности, пронизывающая все затронутые слои.
3. `spec.md` — canonical owner intent и delivery-scoped target outcome.
4. `brief.md` создаётся вместе с issue и остаётся routing-слоем на всём lifecycle.
5. `plan.md` — derived execution-документ. Не должен существовать, пока `spec.md` не стал `status: active`.
6. Черновики хранятся в `iterations/`, финальные активные документы — в корне папки задачи.
7. Смысл стабильных идентификаторов (`REQ-*`, `NS-*`, `CHK-*`, `STEP-*` и т.д.) зафиксирован в секции «Stable Identifiers» ниже.
8. Acceptance scenarios (`SC-*`) покрывают vertical slice end-to-end: от входного события до наблюдаемого результата.
9. Если issue добавляет новый устойчивый сценарий или существенно меняет существующий — создать или обновить `UC-*` в `memory-bank/use-cases/`.

## Lifecycle

```
Issue
  ↓
Brief Ready      brief.md: active
  ↓
Spec Ready       spec.md: active, delivery_status: planned
  ↓
Plan Ready       plan.md: active
  ↓
Execution        delivery_status: in_progress
  ↓
Done             delivery_status: done, plan.md: archived
```

## Transition Gates

### Issue → Brief Ready

- [ ] `brief.md` создан по `../templates/brief-template.md`
- [ ] содержит проблему, стейкхолдера, критерий успеха и Out of Scope
- [ ] rubric scorecard: ни одно измерение `score <= 2`
- [ ] `brief.md` → `status: active`

### Brief Ready → Spec Ready

- [ ] `spec.md` создан по `../templates/spec-template.md`
- [ ] содержит ≥ 1 `REQ-*`, ≥ 1 `NS-*`, ≥ 1 `SC-*`, ≥ 1 `CHK-*`, ≥ 1 `EVID-*`
- [ ] rubric scorecard: ни одно измерение `score <= 2`
- [ ] grounding выполнен: реальные пути файлов и паттерны зафиксированы в spec
- [ ] `spec.md` → `status: active`, `delivery_status: planned`

### Spec Ready → Plan Ready

- [ ] agент выполнил grounding: прошёлся по текущему состоянию системы (relevant paths, patterns, dependencies)
- [ ] `plan.md` создан по `../templates/plan-template.md`
- [ ] содержит ≥ 1 `PRE-*`, ≥ 1 `STEP-*`, ≥ 1 `CHK-*`, ≥ 1 `EVID-*`
- [ ] каждый `STEP-*` ссылается на `REQ-*` или `SC-*` из spec
- [ ] rubric scorecard: ни одно измерение `score <= 2`
- [ ] `plan.md` → `status: active`

### Plan Ready → Execution

- [ ] `spec.md` → `delivery_status: in_progress`
- [ ] все `PRE-*` выполнены или явно помечены как acceptable risk
- [ ] test strategy задана: какие spec-файлы будут добавлены/обновлены

### Execution → Done

- [ ] все `CHK-*` из `spec.md` имеют результат pass в evidence
- [ ] все `EVID-*` заполнены конкретными carriers (CI run, путь к файлу, вывод команды)
- [ ] `bin/ci` зелёный локально
- [ ] simplify review выполнен
- [ ] если issue добавляет/меняет устойчивый сценарий → `UC-*` создан/обновлён
- [ ] `spec.md` → `delivery_status: done`
- [ ] `plan.md` → `status: archived`

### → Cancelled (из любой стадии)

- [ ] `spec.md` → `delivery_status: cancelled` (если существует)
- [ ] `plan.md` отсутствует ∨ `status: archived`

## Stable Identifiers

### Spec IDs (в `spec.md`)

| Prefix | Meaning |
| --- | --- |
| `REQ-*` | scope и обязательные capability |
| `NS-*` | non-scope |
| `ASM-*` | assumptions и рабочие предпосылки |
| `CON-*` | ограничения |
| `INV-*` | инварианты |
| `SC-*` | acceptance scenarios |
| `NEG-*` | negative / edge test cases |
| `CHK-*` | исполнимые проверки |
| `EVID-*` | evidence-артефакты |

### Plan IDs (в `plan.md`)

| Prefix | Meaning |
| --- | --- |
| `PRE-*` | preconditions |
| `OQ-*` | unresolved questions / ambiguities |
| `STEP-*` | атомарные шаги |
| `AG-*` | approval gates для рискованных действий |
| `CP-*` | checkpoints |
| `ER-*` | execution risks |
| `STOP-*` | stop conditions / fallback |

### Required Minimum

1. Любой `spec.md` со `status: active` использует как минимум `REQ-*`, `NS-*`, `SC-*`, `CHK-*`, `EVID-*`.
2. Любой `plan.md` использует как минимум `PRE-*`, `STEP-*`, `CHK-*`, `EVID-*`.
3. При наличии ambiguity или human approval gates используются `OQ-*` и `AG-*`.

### Traceability Contract

1. Scope в `spec.md` фиксируется через `REQ-*`, non-scope через `NS-*`.
2. Verify связывает `REQ-*` с test cases через `SC-*`, traceability matrix, `CHK-*` и `EVID-*`.
3. `plan.md` ссылается на canonical IDs из `spec.md` в колонках `Implements`, `Verifies`, `Evidence IDs`.
4. Если sequencing блокируется неизвестностью — фиксировать как `OQ-*`, не прятать в prose.
5. Если выполнение требует подтверждения человеком — фиксировать через `AG-*`.
