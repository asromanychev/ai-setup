---
title: Domain Documentation Index
doc_kind: domain
doc_function: index
purpose: Навигация по domain-level документации ai-da-collect. Читать для фиксации продуктового контекста, архитектурных границ и бизнес-правил проекта.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Domain Documentation Index

- [`problem.md`](problem.md) — продуктовая проблема, целевые пользователи, top-level outcomes, out-of-scope на уровне проекта. Upstream-слой для PRD и feature specs. Читать первым при формулировке требований.

- [`architecture.md`](architecture.md) — summary слоёв (core/plugins/clients/jobs), стек, границы сервиса. Proxy на `aitlas/ai-da-collect/conventions/docs/architecture.md`. Читать при изменении компонентов, слоёв или инфраструктуры.
