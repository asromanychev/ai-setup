---
title: "ADR-XXX: Short Decision Name"
doc_kind: adr
doc_function: template
purpose: Governed wrapper-шаблон ADR. Читать, чтобы инстанцировать decision record.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: adr
template_target_path: ../../../adr/ADR-NNN-short-decision-name.md
---

# ADR-XXX: Short Decision Name

Этот файл — wrapper-template. Инстанцируемый ADR живёт ниже как embedded contract и копируется без wrapper frontmatter.

## Wrapper Notes

`decision_status: proposed` означает, что текст ADR является предложением и не считается принятым решением до перевода в `accepted`.

## Instantiated Frontmatter

```yaml
title: "ADR-NNN: Short Decision Name"
doc_kind: adr
doc_function: canonical
purpose: "Фиксирует архитектурное или инженерное решение, его decision_status и последствия."
derived_from:
  - ../issues/NNNN-slug/spec.md  # или другой upstream
status: draft
decision_status: proposed
date: YYYY-MM-DD
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
```

## Instantiated Body

```markdown
# ADR-NNN: Short Decision Name

## Контекст

Какую проблему, ограничение, trade-off или архитектурное напряжение нужно разрешить.

## Драйверы решения

- Требования или ограничения, влияющие на выбор.
- KPI, эксплуатационные или продуктовые факторы.
- Зависимости и уже принятые решения.

## Рассмотренные варианты

| Вариант | Плюсы | Минусы | Причина выбора / отказа |
| --- | --- | --- | --- |
| `Option A` | | | |

## Решение

Описание принятого решения, его границ и затронутых компонентов.

## Последствия

### Положительные

### Отрицательные

### Нейтральные / организационные

## Риски и mitigation

## Follow-up

Downstream-документы, задачи или миграции, которые должны последовать.

## Связанные ссылки

- Связанные spec / issues.
- Связанные ADR.
```
