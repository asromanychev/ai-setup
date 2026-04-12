---
title: Git Workflow
doc_kind: engineering
doc_function: canonical
purpose: Git-конвенции проекта — commits, ветки, PR.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Git Workflow

## Default Branch

`main` — основная ветка. PR мержится в `main`.

## Commits

Проект использует **Conventional Commits**:

```
<type>(<scope>): <short description>
```

Типы: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.  
Примеры из истории: `feat(telegram): add ChannelClient`, `docs(memory-bank): extend WORKFLOW`.

- Описание в imperative или present tense
- Scope — компонент или слой: `telegram`, `core`, `memory-bank`, `ci`, `plugin`
- Ссылка на issue в теле коммита при необходимости: `Closes #18`

## Ветки

- Фича/задача: `feat/<short-slug>` или `fix/<short-slug>`
- Документация: `docs/<short-slug>`
- По возможности — одна ветка на один issue

## Pull Requests

- Перед PR обязателен зелёный `bin/ci` локально
- PR title совпадает с conventional commit summary
- В body: что изменено, как проверено, ссылка на issue

## Worktrees

Не используются в текущем процессе.
