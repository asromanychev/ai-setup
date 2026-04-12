---
title: Task Workflows
doc_kind: governance
doc_function: canonical
purpose: Маршрутизация задач по типам и базовый цикл разработки. Читать при получении новой задачи для выбора подхода.
derived_from:
  - ../dna/governance.md
  - feature-flow.md
canonical_for:
  - task_routing_rules
  - base_development_cycle
  - workflow_type_selection
  - autonomy_gradient
status: active
audience: humans_and_agents
---

# Task Workflows

## Базовый цикл

Любой workflow — цепочка повторений одного цикла:

```
Артефакт → Ревью → Полировка
                 → Декомпозиция
                 → Принят
```

Артефакт — то, что создаётся на каждом этапе: brief, spec, plan, код, PR, runbook.

## Градиент участия человека

Чем ближе к бизнес-требованиям, тем больше участия человека. Чем ближе к коду и локальному verify, тем больше агент работает автономно.

```
Бизнес-требования  ← человек  |  агент →  Код
  PRD, Use Cases      Brief, Spec, Plan     PR, Тесты
```

## Типы Workflow

### 1. Малая фича

Когда:
- задача понятна;
- scope локален;
- помещается в одну сессию или компактный change set.

Flow: `issue → routing → implementation → review → merge`

### 2. Средняя или большая фича

Когда:
- затрагивает несколько слоёв;
- требует design choices;
- нужны checkpoints и явный execution plan.

Flow: `issue → brief → spec → plan → execution → review → commit`

### 3. Баг-фикс

Flow: `report → reproduction → analysis → fix → regression coverage → review`

### 4. Рефакторинг

Классы:
- по ходу delivery-задачи;
- исследовательский;
- системный (большой change surface).

Исследовательский и системный требуют явного плана и checkpoints.

### 5. Инцидент / PIR

Flow: `incident → timeline → root cause analysis → fixes → prevention work`

## Routing Rules

Используй минимальный workflow, который не теряет контроль над риском.

- Если задача маленькая и понятная — не раздувай до full issue cycle.
- Если задача меняет контракт, schema или требует approvals — поднимай до spec+plan flow.
- Если замечания не уменьшаются от итерации к итерации — проблема upstream, не в коде.

## Полный цикл задачи

Детали каждого шага: [`../issues/MAKE_NEW_ISSUE.md`](../issues/MAKE_NEW_ISSUE.md).  
Lifecycle gates: [`feature-flow.md`](feature-flow.md).
