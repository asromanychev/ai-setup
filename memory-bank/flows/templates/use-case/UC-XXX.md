---
title: "UC-XXX: Use Case Name"
doc_kind: use_case
doc_function: template
purpose: Governed wrapper-шаблон use case. Читать, чтобы инстанцировать канонический пользовательский или операционный сценарий.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../../domain/problem.md
status: active
audience: humans_and_agents
template_for: use_case
template_target_path: ../../../use-cases/UC-NNN-short-name.md
canonical_for:
  - use_case_template
---

# UC-XXX: Use Case Name

Этот файл — wrapper-template. Инстанцируемый use case живёт ниже как embedded contract и копируется без wrapper frontmatter.

## Wrapper Notes

Use case фиксирует устойчивый проектный сценарий: trigger, preconditions, основной flow, альтернативы и postconditions. Не уходит в implementation sequence или feature-level verify.

Если сценарий локален и живёт внутри одной issue, оставь его в `SC-*` у соответствующей spec.

## Instantiated Frontmatter

```yaml
title: "UC-NNN: Use Case Name"
doc_kind: use_case
doc_function: canonical
purpose: "Фиксирует устойчивый пользовательский или операционный сценарий проекта."
derived_from:
  - ../domain/problem.md
  # Optional:
  # - ../prd/PRD.md
status: draft
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_test_matrix
```

## Instantiated Body

```markdown
# UC-NNN: Use Case Name

## Goal

Какой результат должен получить actor после успешного выполнения сценария.

## Primary Actor

Кто инициирует сценарий.

## Trigger

Какое событие или намерение запускает flow.

## Preconditions

- Что должно быть истинно до начала сценария.

## Main Flow

1. Первый шаг.
2. Второй шаг.
3. Наблюдаемый результат.

## Alternate Flows / Exceptions

- `ALT-01` Ветвление при ожидаемой альтернативе.
- `EX-01` Сбой, который должен быть корректно обработан.

## Postconditions

- Что истинно после успешного завершения.
- Что остаётся истинным после неуспешного завершения.

## Business Rules

- `BR-01` Правило, которое обязана соблюдать любая реализация этого сценария.

## Traceability

| Upstream / Downstream | References |
| --- | --- |
| PRD | `PRD.md` / `none` |
| Issues | `#NNN`, `#NNN` |
| ADR | `ADR-NNN` / `none` |
```
