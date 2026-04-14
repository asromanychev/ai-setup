---
issue: 2
title: Персистентность источников и контрольных точек синка
status: draft
version: v8
date: 2026-04-12
---

# Specification: Source and SyncCheckpoint Persistence

## 1. Цель решения

Зафиксировать persisted contract для `Source` и `SyncCheckpoint`, чтобы legacy-orchestrator мог читать из БД состав следующего sync и однозначную позицию возобновления по каждому source.

### 1.1 Потребитель решения

- Кто вызывает: orchestration-слой и model-level код вокруг `Source`.
- Когда вызывается: при чтении списка источников для sync и при сохранении новой позиции checkpoint.
- Частота: один и более раз на каждый source в ходе инкрементального sync.
- Модель ответа: синхронный AR API и persisted side-effect в primary database.

## 2. Scope

- `REQ-1`: модель `Source` хранит `plugin_type`, `external_id`, `sync_enabled` и не допускает пустые идентификаторы.
- `REQ-2`: пара `(plugin_type, external_id)` уникальна после нормализации к строкам.
- `REQ-3`: `Source.for_sync` возвращает только записи с `sync_enabled: true`.
- `REQ-4`: `SyncCheckpoint` принадлежит одному `Source`, хранит `position` как `jsonb` и допускает для source не более одной строки.
- `REQ-5`: `Source#upsert_checkpoint!(position:)` создаёт или обновляет единственный checkpoint для source и отвергает `nil` до записи в БД.
- `REQ-6`: `source.sync_checkpoint` различает состояния `0`, `1` и `>1` checkpoint; при `>1` поднимает `Collect::CheckpointAmbiguityError`.

- `NS-1`: orchestration-логика `sync_step!`, вызов registry/plugin и обработка `records/checkpoint_out/finished` не входят в scope этого issue.
- `NS-2`: API, jobs, raw payload storage и `raw_ingest_items` не входят в scope.
- `NS-3`: формат `position` внутри checkpoint не валидируется моделью и остаётся ответственностью plugin contract.

### 2.1 Preconditions

- Класс `Collect::CheckpointAmbiguityError` уже существует в `core/lib/collect/errors.rb`; если его нет, feature-level contract не может считаться материализованным.
- Primary/test PostgreSQL должен быть доступен для model runtime checks; если test DB недоступна, code-stage завершается статусом `runtime_unknown`, а не silent-pass.

## 3. Функциональные требования

1. `Source` нормализует `plugin_type` и `external_id` через `.to_s` до валидаций.
2. `Source` запрещает `plugin_type: nil`, `external_id: nil`, `external_id: ""` и `sync_enabled: nil`.
3. Active Record boolean type-casting для `sync_enabled` считается допустимым входом, если итоговое значение равно `true` или `false`.
4. `Source.for_sync` читает только persisted `sync_enabled: true`.
5. `SyncCheckpoint` запрещает `position: nil`, но допускает `{}`.
6. `Source#upsert_checkpoint!(position:)` выполняет atomic upsert по `source_id` и оставляет в таблице не более одной строки на source.
7. Повторный `upsert_checkpoint!` с тем же `position` идемпотентен.
8. Изменение checkpoint одного source не меняет checkpoint другого source.
9. `source.sync_checkpoint` возвращает `nil` при отсутствии строки, объект при одной строке и ошибку неоднозначности при нескольких строках.

## 4. Uniform

- Success: валидный `Source` сохраняется, `for_sync` возвращает только включённые записи, checkpoint читается или обновляется однозначно.
- Error: невалидные атрибуты source/checkpoint поднимают `ActiveRecord::RecordInvalid`; `position: nil` для upsert поднимает `ArgumentError`; неоднозначный checkpoint поднимает `Collect::CheckpointAmbiguityError`.
- Empty: `Source.for_sync` может вернуть пустой relation; `source.sync_checkpoint` может вернуть `nil`.
- Loading / in progress: неприменимо, потому что это синхронные model/database операции без промежуточного persisted статуса.

Сценарии:
- Дубликат `(plugin_type, external_id)` -> ошибка валидации или DB unique violation.
- Два checkpoint для одного `source_id` -> ошибка неоднозначности при чтении.
- `position: {}` -> допустимое persisted значение.
- `source.destroy` -> связанный checkpoint исчезает из БД.

## 5. Инварианты

1. Для нормализованной пары `(plugin_type, external_id)` существует не более одного `Source`.
2. Для одного `source_id` в штатной схеме существует не более одного checkpoint.
3. `upsert_checkpoint!` не влияет на другие `Source`.
4. После удаления source связанный checkpoint отсутствует.
5. Feature-level contract не требует и не описывает orchestration side-effects вне persisted state.

## 6. Ограничения на реализацию и Grounding

- [app/models/source.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/source.rb): доменная модель source; исторически в файле уже присутствует и downstream-логика, не входящая в scope `0002`.
- [app/models/sync_checkpoint.rb](/home/aromanychev/edu/aida/ai-da-collect/app/models/sync_checkpoint.rb): модель checkpoint.
- [db/schema.rb](/home/aromanychev/edu/aida/ai-da-collect/db/schema.rb): materialized schema для `sources` и `sync_checkpoints`.
- [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb): model checks для source; файл также содержит примеры более позднего orchestration scope.
- [spec/models/sync_checkpoint_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/sync_checkpoint_spec.rb): model checks для checkpoint, включая ambiguity scenario.
- [spec/rails_helper.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/rails_helper.rb): Rails DB bootstrap; при недоступной test DB этот helper падает до старта examples.
- [core/lib/collect/errors.rb](/home/aromanychev/edu/aida/ai-da-collect/core/lib/collect/errors.rb): источник `Collect::CheckpointAmbiguityError`.

Паттерны:
- normalizing callback в `Source`;
- unique indexes в БД как часть инварианта;
- atomic upsert для checkpoint;
- model specs как primary evidence.

## 7. Acceptance Criteria

Acceptance scenarios:
- `SC-1`: валидный source сохраняется и попадает в `for_sync`, если `sync_enabled: true`.
- `SC-2`: duplicate source после нормализации отвергается.
- `SC-3`: source без checkpoint возвращает `nil`, а после `upsert_checkpoint!` читает сохранённый `position`.
- `SC-4`: повторный upsert обновляет checkpoint без создания второй строки.
- `SC-5`: `position: nil` отвергается, а `{}` допускается.
- `SC-6`: повреждённое состояние с двумя checkpoint для одного source сигнализирует `Collect::CheckpointAmbiguityError`.
- `SC-7`: удаление source удаляет checkpoint каскадно.

Traceability:

| SC | Покрывает REQ |
|----|---------------|
| SC-1 | REQ-1, REQ-3 |
| SC-2 | REQ-2 |
| SC-3 | REQ-4, REQ-5, REQ-6 |
| SC-4 | REQ-4, REQ-5 |
| SC-5 | REQ-4, REQ-5 |
| SC-6 | REQ-6 |
| SC-7 | REQ-4 |

Checks and evidence:
- `CHK-1` [ ] `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` -> все feature-level model examples зелёные.
- `CHK-2` [ ] `bundle exec rspec spec/core/collect` -> существующий core contract остаётся зелёным.
- `CHK-3` [ ] В `db/schema.rb` материализованы `sources` и `sync_checkpoints` c нужными unique/FK ограничениями.
- `CHK-4` [ ] В code review нет доказуемого дефекта против `REQ-1`..`REQ-6`.

- `EVID-1` Carrier: [spec/models/source_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/source_spec.rb) и [spec/models/sync_checkpoint_spec.rb](/home/aromanychev/edu/aida/ai-da-collect/spec/models/sync_checkpoint_spec.rb)
- `EVID-2` Carrier: [db/schema.rb](/home/aromanychev/edu/aida/ai-da-collect/db/schema.rb)
- `EVID-3` Carrier: `bundle exec rspec spec/core/collect` -> `40 examples, 0 failures` (2026-04-12)
- `EVID-4` Carrier: `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb` -> `ActiveRecord::ConnectionNotEstablished` / `PG::ConnectionBad` в текущем окружении (2026-04-12)
- `EVID-5` Carrier: `iterations/code/code-review-3.md`
