# Progress

**Назначение:** зафиксированные решения, итоги этапов и расхождения документация ↔ код. Обновляй после значимого блока работы.

---

## Итоги этапов

### Этап 1 — Фундамент (закрыто, issues #1–#6)
- **#1** — Контракт `Collect::Plugin`, реестр, `NullPlugin` (`core/lib/collect/`)
- **#2** — Модели `Source`, `SyncCheckpoint` + миграции (`app/models/`, `db/migrate/`)
- **#3** — Оркестрация одного шага синка (`Source#sync_step!` с транзакцией)
- **#4** — S3-совместимый адаптер `BlobStorage` (`app/services/collect/blob_storage.rb`)
- **#5** — Модель `RawIngestItem` + идемпотентная вставка (`app/models/raw_ingest_item.rb`)
- **#6** — Telegram `ChannelClient`: fetch + DTO + retry (`app/clients/telegram/channel_client.rb`)

### Аудит PRD v4 — 2026-04-12
- **PRD обновлён до v4** (VibeContract revision): введены контракты C-1–C-7, центральная сущность изменена с `Source` → `CollectionTask`.
- Артефакты аудита: `audit_step1.json` – `audit_step4.json` в корне репозитория.

---

## Ключевые решения

- **2026-04-12**: Домен пересмотрен. `Source` → `CollectionTask` как центральная сущность MVP.
  - `collection_tasks` заменяет `sources`; добавлены: `requester_id`, `collection_mode`, `webhook_secret`, `state`, `retention_policy`.
  - FK `raw_ingest_items.source_id` → `task_id` (issue #18).
- **2026-04-12**: `BlobStorage` (issue #4) — реализован как заглушка; прямая загрузка вложений в S3 — **out of scope MVP** (PRD v4 §6.2).
- **2026-04-12**: issue #9 (старый API для Sources) закрыт и расщеплён на #20, #21, #22.
- **2026-04-13**: issue #19 ввёл fail-fast `API_KEY`, глобальную Bearer auth для `/tasks*`, публичные исключения для `/health` и `/webhooks/*`, а также фильтрацию `api_key` / `webhook_secret` из логируемых параметров.
- **2026-04-13**: issue #20 добавил HTTP lifecycle API для `CollectionTask`: `POST/GET /tasks`, `GET /tasks/:id`, `POST /tasks/:id/consume`, `DELETE /tasks/:id`, одноразовую выдачу `webhook_secret`, stub `CollectionTaskSyncJob`, фильтрацию deleted tasks и request specs.
- **2026-04-14**: issue #8 завершён: `CollectionTaskSyncJob` реально оркестрирует plugin execution, lifecycle, retry и атомарное сохранение items/checkpoint.
- **2026-04-14**: issue #21 добавил `GET /tasks/:id/items` с stable cursor pagination по `raw_ingest_items.id`, strict validation `after_id/limit`, `404` для deleted task и request-spec проверку индекса `(task_id, id)` через `EXPLAIN`.
- **2026-04-14**: после ручной проверки Telegram flow зафиксировано разделение на два plugin family:
  - `telegram_bot` — только `bot-attached channels`;
  - `telegram_user` — отдельная будущая ветка для public/private channels через user session / MTProto.
- **2026-04-14**: старые Telegram issues #6 и #7 уточнены как `bot-attached only`; создана новая цепочка issues #26–#30 для `telegram_user`.

---

## Известные расхождения (документация ↔ код)

| Расхождение | Статус | Адресовано |
|-------------|--------|------------|
| `db/schema.rb` содержит `sources` вместо `collection_tasks` | ⚠️ ОТКРЫТО | issue #18 |
| `raw_ingest_items.source_id` вместо `task_id` | ⚠️ ОТКРЫТО | issue #18 |
| `sync_checkpoints.source_id` вместо `task_id` | ⚠️ ОТКРЫТО | issue #18 |
| `Source#sync_step!` — legacy orchestration на старой модели | ⚠️ ОТКРЫТО | historical slice, не часть CollectionTask MVP |
| ROADMAP.md описывает 6 фаз старой архитектуры | ⚠️ ОБНОВЛЕНО | см. ROADMAP.md |

---

## Следующие шаги (по приоритету)

1. **#22/#23/#24** — Webhook mode, startup-recovery, health.
2. **#10** — Structured logging.
3. **#11** — CI/GitHub Actions (параллельно).
4. **#26 → #30** — `telegram_user` extension: credential model, MTProto client, separate plugin, job integration, onboarding/audit.
