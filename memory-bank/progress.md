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

---

## Известные расхождения (документация ↔ код)

| Расхождение | Статус | Адресовано |
|-------------|--------|------------|
| `db/schema.rb` содержит `sources` вместо `collection_tasks` | ⚠️ ОТКРЫТО | issue #18 |
| `raw_ingest_items.source_id` вместо `task_id` | ⚠️ ОТКРЫТО | issue #18 |
| `sync_checkpoints.source_id` вместо `task_id` | ⚠️ ОТКРЫТО | issue #18 |
| `Source#sync_step!` — оркестрация на старой модели | ⚠️ ОТКРЫТО | issue #8 (обновлён) |
| ROADMAP.md описывает 6 фаз старой архитектуры | ⚠️ ОБНОВЛЕНО | см. ROADMAP.md |

---

## Следующие шаги (по приоритету)

1. **#18** — Мигрировать схему: `collection_tasks` + обновить FKs. **Блокирует всё.**
2. **#19** — Bearer token auth.
3. **#20** — Collection Tasks API (CRUD + lifecycle).
4. **#7** — Telegram Plugin (fetch+map, без записи в БД).
5. **#8** — `CollectionTaskSyncJob` (lifecycle + retry + unique-jobs).
6. **#21/#22/#23/#24** — Items pagination, webhook, startup-recovery, health.
7. **#10** — Structured logging.
8. **#11** — CI/GitHub Actions (параллельно).
