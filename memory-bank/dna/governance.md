---
doc_kind: governance
doc_function: canonical
purpose: SSoT implementation и правила dependency tree. Отвечает на вопрос — кто владеет каким фактом.
derived_from:
  - principles.md
status: active
---
# Document Governance

`Governed document` — markdown-файл в `memory-bank/` с валидным YAML frontmatter. Принцип SSoT определён в [principles.md](principles.md). Этот документ описывает механизм его исполнения.

## SSoT Implementation

1. Authoritative только `active`-документы. `draft` не переопределяет `active`.
2. Среди допустимых по status побеждает upstream: сначала `canonical_for`, затем dependency tree.
3. Публикационный статус (`status`) отделён от lifecycle сущности (`delivery_status`, `decision_status`).

## Source Dependency Tree

1. Поле `derived_from` перечисляет прямые upstream-документы. Authority течёт upstream → downstream.
2. Корневой документ — `principles.md`, не имеет `derived_from`. Для каждого `active` non-root документа `derived_from` обязательно.
3. Циклические зависимости запрещены. Изменение upstream может потребовать обновления downstream.

## Governance-specific Frontmatter Fields

Governance-документы (dna/, flows/) используют дополнительные поля:

| Поле | Значения | Назначение |
|-|-|-|
| `doc_kind` | `governance`, `project`, `engineering`, `domain`, `adr`, `use_case` | Тип документа |
| `doc_function` | `canonical`, `index`, `template` | Роль: canonical owner факта, навигационный индекс или шаблон |

Эти поля обязательны для governance-документов и не требуются в domain/ops/engineering документах.
