---
title: "PRD-XXX: Product Initiative Name"
doc_kind: prd
doc_function: template
purpose: Governed wrapper-шаблон PRD. Читать, чтобы инстанцировать компактный Product Requirements Document.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../../domain/problem.md
status: active
audience: humans_and_agents
template_for: prd
template_target_path: ../../../prd/PRD-XXX-short-name.md
canonical_for:
  - prd_template
---

# PRD-XXX: Product Initiative Name

Этот файл — wrapper-template. Инстанцируемый PRD живёт ниже как embedded contract и копируется без wrapper frontmatter.

## Wrapper Notes

PRD intentionally lean: фиксирует продуктовую проблему, пользователей, goals, scope и success metrics — не берёт на себя implementation sequencing, architecture decisions или verify/evidence contracts downstream issues.

Опирается на `domain/problem.md`, а не подменяет его.

## Instantiated Frontmatter

```yaml
title: "PRD-XXX: Product Initiative Name"
doc_kind: prd
doc_function: canonical
purpose: "Фиксирует продуктовую проблему, целевых пользователей, goals, scope и success metrics инициативы."
derived_from:
  - ../domain/problem.md
status: draft
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
```

## Instantiated Body

```markdown
# PRD-XXX: Product Initiative Name

## Problem

Какую пользовательскую или бизнес-проблему решает инициатива. Язык проблемы, не решения.

## Users And Jobs

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| `primary-user` | Что хочет сделать | Что мешает сегодня |

## Goals

- `G-01` Обязательный product outcome.
- `G-02` Желательный дополнительный outcome.

## Non-Goals

- `NG-01` Что сознательно не входит в инициативу.

## Product Scope

### In Scope

- Что должно стать возможным для пользователя или системы.

### Out Of Scope

- Что остаётся за границами инициативы.

## UX / Business Rules

- `BR-01` Важное правило продукта.
- `BR-02` Ограничение, которое должна уважать любая downstream issue.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Что измеряем | Baseline | Target | Как проверяем |

## Risks And Open Questions

- `RISK-01` Что может сорвать инициативу.
- `OQ-01` Неизвестность, которая ещё не снята.

## Downstream Issues

| Issue | Why it exists | Status |
| --- | --- | --- |
| `#NNN` | Какой slice реализует | planned / in_progress / done |
```
