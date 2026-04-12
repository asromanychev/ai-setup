# Memory Bank — вход для AI-агентов

Читай этот файл **первым** в каждой новой сессии. Один факт — одно каноническое место (SSoT); не дублируй содержимое других файлов здесь.

---

## C4 Level 0 — о системе

**ai-da-collect** — сервис **временного буферизованного ingestion**: принимает задания на сбор от внешних агентов (`CollectionTask`), собирает сырой контент через изолированные плагины, буферизует до потребления downstream-агентом, затем удаляет по сигналу или TTL.  
**Аудитория:** команды, которым нужен воспроизводимый изолированный сбор из каналов/источников для аналитики, пайплайнов и ИИ-агентов (семантика и RAG — не здесь).  
**Стек:** Ruby **3.4**, **Rails 8** API-only, **PostgreSQL**, **Redis** + **Sidekiq** (через ActiveJob), **S3-compatible** (заглушка MVP), Docker-first / ENV.  
**MVP (целевой скоуп):** `CollectionTask` API + lifecycle, Telegram-плагин (публичные каналы, оба режима), Bearer auth, cursor pagination, webhooks. **Вне MVP:** нормализация, embeddings, RAG, ИИ-анализ, UI, приватные источники, S3-загрузка вложений.  
**Центральная сущность MVP:** `CollectionTask` — задание на сбор от конкретного `requester_id` с lifecycle `created→queued→collecting→ready→consumed→deleted/failed` (PRD v4, C-1).  
**Подход:** вертикальный слайс по источникам; плагины не пишут в БД — только fetch+map; оркестрация через Job.  
**⚠️ Расхождение код ↔ PRD (2026-04-12):** схема БД ещё на старой модели (`sources`); миграция на `collection_tasks` — issue **#18** (critical, блокирует всё).

---

## Документация (аннотированные ссылки)

### Продуктовые требования

* `memory-bank/prd/PRD.md` → [открыть](prd/PRD.md)  
  **Что:** Vision, целевая аудитория, проблематика, границы MVP (In/Out of Scope), ключевые сценарии, стек и ограничения.  
  **Читать, чтобы:** сверить скоуп любой задачи с MVP, не реализовывать out-of-scope фичи, понять целевую ценность продукта.

### Архитектура и стек (Слой Project)

* `aitlas/ai-da-collect/conventions/docs/architecture.md` → [открыть](../aitlas/ai-da-collect/conventions/docs/architecture.md)  
  **Что:** Компоненты (ядро, плагины, клиенты, джобы), зафиксированный стек, границы сервиса, открытые архитектурные решения.  
  **Читать, чтобы:** менять границы модулей, планировать инфраструктуру (PG, S3, Redis/Sidekiq) или согласовывать новый крупный компонент.

* `core/README.md` → [открыть](../core/README.md)  
  **Что:** Контракт `Collect::Plugin`, семантика `sync_step`, реестр, `NullPlugin`; что уже реализовано в первом слайсе ядра без внешних зависимостей.  
  **Читать, чтобы:** реализовывать или менять плагин, писать тесты оркестрации/чекпойнтов, проверять инварианты шага синка.

* `README.md` → [открыть](../README.md)  
  **Что:** Краткий человеческий вход: что есть в репозитории сейчас, как поставить зависимости и гонять `rspec` / `bin/ci`.  
  **Читать, чтобы:** быстро понять текущее состояние репозитория и команды для локальной проверки до углубления в Memory Bank.

* `memory-bank/project/data-model.md` → [открыть](project/data-model.md)  
  **Что:** Логическая модель `sources` / `sync_checkpoints` / `raw_ingest_items`, индексы дедупа, роль S3; SSoT структуры — `db/schema.rb`.  
  **Читать, чтобы:** писать миграции, ActiveRecord-модели и SQL; согласовывать персистентность с контрактом плагина.

### Домен и бизнес-правила (Слой Domain)

* `aitlas/ai-da-collect/features/00-system-overview.md` → [открыть](../aitlas/ai-da-collect/features/00-system-overview.md)  
  **Что:** Роль сервиса в потоке данных, модель плагинов, первый источник (Telegram), что считается результатом ingestion.  
  **Читать, чтобы:** формулировать требования к фичам, границы «сырьё vs downstream», поведение прогресса и повторных проходов.

* `memory-bank/project/overview.md` → [открыть](project/overview.md)  
  **Что:** Каноническое описание продукта, стека, слоёв (core/plugins/clients/jobs), ограничений и ссылок на Aitlas.  
  **Читать, чтобы:** сверить любое решение с продуктовыми границами и стеком перед спеком или кодом.

* `aitlas/ai-da-collect/features/telegram-public-channels.md` → [открыть](../aitlas/ai-da-collect/features/telegram-public-channels.md)  
  **Что:** Доменные правила первого плагина: публичные каналы, scope/non-scope, конфиг токена, ссылка на DTO и spec issue #6.  
  **Читать, чтобы:** менять Telegram-клиент, маппинг сырья или acceptance-сценарии плагина.

### Доменный контекст (Слой Domain) `[on-demand]`

* `memory-bank/domain/problem.md` → [открыть](domain/problem.md)  
  **Что:** Upstream-слой: продуктовая проблема, целевые пользователи, top-level outcomes, out-of-scope на уровне проекта.  
  **Читать, чтобы:** сформулировать PRD или spec — это их upstream-предпосылка.

### Flows и шаблоны (Lifecycle Governance)

* `memory-bank/flows/README.md` → [открыть](flows/README.md)  
  **Что:** Навигация по lifecycle flows и governed-шаблонам (PRD, use case, ADR).  
  **Читать, чтобы:** создать новый governed-документ или понять lifecycle gates.

* `memory-bank/flows/feature-flow.md` → [открыть](flows/feature-flow.md)  
  **Что:** Stage-based lifecycle от draft до closure, transition gates, taxonomy стабильных идентификаторов (REQ-*, NS-*, SC-*, CHK-*, EVID-*, STEP-* и др.).  
  **Читать, чтобы:** вести issue по lifecycle, трассировать требования к тестам, выбирать нужный stable ID.

* `memory-bank/flows/workflows.md` → [открыть](flows/workflows.md)  
  **Что:** Routing rules: какой тип workflow выбрать (малая фича, баг-фикс, рефакторинг, инцидент).  
  **Читать, чтобы:** при получении новой задачи выбрать минимальный подходящий workflow.

### Governance документации (DNA)

* `memory-bank/dna/README.md` → [открыть](dna/README.md)  
  **Что:** Конституция проектной документации: SSoT-принципы, правила dependency tree, frontmatter schema, lifecycle governed-документов.  
  **Читать, чтобы:** понять кто владеет каким фактом, какой frontmatter обязателен и как поддерживать документацию в консистентном состоянии.

* `memory-bank/glossary.md` → [открыть](glossary.md) `[on-demand]`  
  **Что:** Определения ключевых терминов: SSoT, Canonical Owner, CollectionTask, Plugin, sync_step, Brief/Spec/Plan, ADR и др.  
  **Читать, чтобы:** устранить разночтения терминов между агентами и людьми; первая точка поиска при неясном термине.

* `dependency-tree.md` → [открыть](../dependency-tree.md) `[on-demand]`  
  **Что:** Граф зависимостей (derived_from) всех governed-документов memory-bank; корневые документы и cross-edges.  
  **Читать, чтобы:** понять authority-поток upstream→downstream; при изменении корневого документа определить, что требует sync.

### Инженерные стандарты (Слой Engineering)

* `memory-bank/engineering/README.md` → [открыть](engineering/README.md)  
  **Что:** Индекс engineering-документации: coding style, testing policy, git workflow, autonomy boundaries, ADR.  
  **Читать, чтобы:** быстро найти нужное инженерное правило.

* `memory-bank/engineering/coding-style.md` → [открыть](engineering/coding-style.md)  
  **Что:** Rubocop, service objects, разделение ядра и плагина, клиенты только fetch+маппинг, thread-safety заметки.  
  **Читать, чтобы:** начинать любую разработку и ревью — до первой значимой правки кода.

* `memory-bank/engineering/testing-policy.md` → [открыть](engineering/testing-policy.md)  
  **Что:** RSpec + FactoryBot, `bin/ci`, sufficient coverage, manual-only exceptions, simplify review.  
  **Читать, чтобы:** решить что и как тестировать, определить done-критерий для issue.

* `memory-bank/engineering/autonomy-boundaries.md` → [открыть](engineering/autonomy-boundaries.md)  
  **Что:** Что агент делает без подтверждения, где показывает план, когда эскалирует.  
  **Читать, чтобы:** агент знал границы автономии; человек — ожидаемые контрольные точки.

* `aitlas/ai-da-collect/cursor/rules/README.md` → [открыть](../aitlas/ai-da-collect/cursor/rules/README.md)  
  **Что:** Навигация по профильным правилам Cursor для ai-da-collect (ingestion, плагины, джобы, персистентность, клиенты).  
  **Читать, чтобы:** подобрать тематическое правило под задачу или синхронизировать договорённости с `.cursor/rules/`.

* `memory-bank/WORKFLOW.md` → [открыть](WORKFLOW.md)  
  **Что:** Как агент проходит полный цикл задачи (brief → spec → plan → код → валидация → постмортем); включает раздел о применении `.prompts/`.  
  **Читать, чтобы:** вести работу по issue, стыковать артефакты в `memory-bank/issues/` и соблюдать этапы качества.

* `.prompts/` → [triage](../.prompts/triage.md) · [spec](../.prompts/spec.md) · [implement](../.prompts/implement.md) · [review](../.prompts/review.md) · [resume](../.prompts/resume.md) · [compare](../.prompts/compare.md)  
  **Что:** Системные промпты для праймеринга агента: роль, правила, порядок чтения Memory Bank.  
  **Читать, чтобы:** быстро стартовать новую сессию (`resume`), протриажировать идею (`triage`) или запустить отдельный этап цикла с правильным контекстом.

* `AGENTS.md` → [открыть](../AGENTS.md) · `CLAUDE.md` → [открыть](../CLAUDE.md)  
  **Что:** Маршрутизация: обязательный протокол Memory Bank без дублирования знаний в корне репозитория.  
  **Читать, чтобы:** настроить новый агент/инструмент на единый вход через этот индекс.

### Операционная документация (Ops)

* `memory-bank/ops/README.md` → [открыть](ops/README.md)  
  **Что:** Индекс ops-документации: dev-окружение, конфигурация.  
  **Читать, чтобы:** быстро найти dev-команды или ENV contract.

* `memory-bank/ops/development.md` → [открыть](ops/development.md)  
  **Что:** Setup, daily commands, staged validation (6 стадий), known pitfalls.  
  **Читать, чтобы:** настроить окружение, запустить тесты или CI.

* `memory-bank/ops/config.md` → [открыть](ops/config.md)  
  **Что:** ENV contract, ownership модель конфигурации, naming conventions.  
  **Читать, чтобы:** добавить новую ENV-переменную или сверить конфигурацию.

### Архитектурные решения (ADR) `[on-demand]`

* `memory-bank/adr/README.md` → [открыть](adr/README.md)  
  **Что:** Реестр Architecture Decision Records (ADR-001..ADR-004 уже приняты).  
  **Читать, чтобы:** не переоткрывать уже принятые решения; заводить новый ADR при нетривиальном выборе.

### Пользовательские сценарии (Use Cases)

* `memory-bank/use-cases/README.md` → [открыть](use-cases/README.md)  
  **Что:** Реестр canonical use cases проекта. Upstream-слой для нескольких issues, реализующих один flow.  
  **Читать, чтобы:** найти canonical owner для trigger/preconditions/main flow; завести UC-* при появлении устойчивого продуктового сценария.

### Roadmap / фичи (Слой Specs & Features)

* `memory-bank/progress.md` → [открыть](progress.md)  
  **Что:** Решения, итоги этапов, расхождения «документация ↔ код», краткие следующие шаги.  
  **Читать, чтобы:** не повторять устаревшие предположения; обновлять после значимого блока работы.

* `memory-bank/activeContext.md` → [открыть](activeContext.md)  
  **Что:** Текущий фокус сессии, контекст ветки/задачи.  
  **Читать, чтобы:** продолжить прерванную работу или передать контекст другому агенту.

* `memory-bank/issues/README.md` → [открыть](issues/README.md)  
  **Что:** Соглашения по папкам задач, структура brief/spec/plan/iterations.  
  **Читать, чтобы:** создавать или разбирать артефакты задач в `memory-bank/issues/<slug>/`.

* `memory-bank/issues/MAKE_NEW_ISSUE.md` → [открыть](issues/MAKE_NEW_ISSUE.md)  
  **Что:** Полный сценарий агента от GitHub Issue до закрытия с артефактами.  
  **Читать, чтобы:** выполнять «одну команду запускает всё» или воспроизводить процесс для новой задачи.

* `memory-bank/ROADMAP.md` → [открыть](ROADMAP.md)  
  **Что:** Фазы работ: фазы 1–6 завершены (issues #1–#6 CLOSED); фаза 7 (текущая) — пересборка под `CollectionTask` (issues #7, #8, #10, #11, #18–#24). Граф зависимостей. Покрытие контрактов C-1–C-7.  
  **Читать, чтобы:** планировать очередность фич; стартовая точка — **#18** (блокирует всё остальное).

* `audit_step1.json` … `audit_step4.json` → в корне репозитория `[on-demand]`  
  **Что:** Артефакты аудита PRD v4 от 2026-04-12: верификация 6 реализованных issues, ревизия оставшихся, нарезка новых, матрица покрытия (32 требования).  
  **Читать, чтобы:** понять историю принятых решений при текущей сессии или трассировать требование к issue.

---

## Быстрая навигация: канон вне `memory-bank/`

| Зона | Путь |
|------|------|
| ADR и соглашения | `aitlas/ai-da-collect/conventions/docs/` |
| Правила Cursor | `aitlas/ai-da-collect/cursor/rules/` (symlink в `.cursor/rules/` при наличии) |
| Поведение источников (расширяемо) | `aitlas/ai-da-collect/features/` |

Контракт ядра в коде: `core/lib/`. Зависимости приложения: корневой `Gemfile` (без `package.json` в текущем репозитории).

---

## Старт сессии по flow

Читай этот индекс первым, затем добирай только нужное:

| Flow | Что читать после этого индекса |
|------|-------------------------------|
| **Triage / Orient** | `prd/PRD.md` → `project/overview.md` → глоссарий (on-demand) |
| **Plan / Implement** | `engineering/coding-style.md` → spec/plan активного issue → `engineering/testing-policy.md` |
| **Resume** | `activeContext.md` (первым) → `ROADMAP.md` → артефакты активного issue |
| **New issue** | `issues/README.md` → `issues/MAKE_NEW_ISSUE.md` → `flows/workflows.md` |
| **Architecture decision** | `adr/README.md` → `flows/templates/adr/ADR-XXX.md` |

Системные промпты для автозагрузки правильного контекста: [`.prompts/`](../.prompts/).

