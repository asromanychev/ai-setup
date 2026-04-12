---
title: Architecture — ai-da-collect
doc_kind: domain
doc_function: proxy
purpose: Краткое summary архитектуры сервиса и ссылка на канонический источник. SSoT архитектуры — aitlas/ai-da-collect/conventions/docs/architecture.md.
derived_from:
  - ../../aitlas/ai-da-collect/conventions/docs/architecture.md
status: active
audience: humans_and_agents
---

# Architecture — ai-da-collect

> **SSoT:** [`aitlas/ai-da-collect/conventions/docs/architecture.md`](../../aitlas/ai-da-collect/conventions/docs/architecture.md)  
> Этот файл — proxy-summary. При расхождении — доверять SSoT.

## Стек (зафиксировано)

| Компонент | Технология |
|---|---|
| Runtime | Ruby 3.4, Rails 8 API-only |
| БД | PostgreSQL (метаданные, чекпойнты, ключи идемпотентности) |
| Object storage | S3-compatible (сырые payload и вложения; в PG — ссылки) |
| Фон | Sidekiq (Redis) через ActiveJob |
| Деплой | Docker-first, конфигурация через ENV |

## Слои

| Слой | Ответственность |
|---|---|
| **core** | контракт плагинов, оркестрация sync/incremental, checkpoint, retry |
| **plugins** | изолированные модули по источнику (`plugins/`) |
| **clients** | HTTP/SDK к внешним API; только fetch + маппинг в сырой формат |
| **jobs** | сетевые и длительные проходы по источникам (через ActiveJob) |

## Границы сервиса

- **In:** приём `CollectionTask`, сбор сырого контента, буферизация до потребления downstream.
- **Out:** семантическая нормализация, embeddings, RAG, ИИ-анализ, UI, приватные источники.

## ADR

Принятые архитектурные решения: [`memory-bank/adr/README.md`](../adr/README.md)  
(ADR-001 plugin contract, ADR-002 Rails API+Sidekiq, ADR-003 S3 stub, ADR-004 CollectionTask)
