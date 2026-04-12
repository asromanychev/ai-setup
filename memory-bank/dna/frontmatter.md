---
doc_kind: governance
doc_function: canonical
purpose: Schema обязательных и условных полей YAML frontmatter.
derived_from:
  - governance.md
status: active
---
# Frontmatter Schema

## Обязательные

| Поле | Тип | Описание |
|---|---|---|
| `status` | enum | `draft` / `active` / `archived` |

## Условно обязательные

| Поле | Когда | Описание |
|---|---|---|
| `derived_from` | Есть upstream-документ | Прямые upstream-зависимости. Каждый элемент — строка (путь) или объект `{path, fit}`, где `fit` объясняет scope зависимости |
| `delivery_status` | Документы issues/ (spec, plan) | `planned` / `in_progress` / `done` / `cancelled` |
| `decision_status` | ADR-документы | `proposed` / `accepted` / `superseded` / `rejected` |

## Дополнительные поля

Governed-документы могут содержать дополнительные поля, не описанные в этой schema. Дополнительные поля не требуют регистрации здесь и интерпретируются на уровне конкретного `doc_kind` или flow.

## Примеры

```yaml
---
derived_from:
  - ../../prd/PRD.md
status: active
delivery_status: in_progress
---
```

```yaml
---
derived_from:
  - path: ../../../adr/ADR-001-plugin-contract.md
    fit: "используется контракт Collect::Plugin и семантика sync_step"
status: active
---
```
