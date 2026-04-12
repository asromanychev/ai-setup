Prerequisite: реализация этого плана стартует только после того, как внешний infrastructure issue добавит `Collect::CheckpointAmbiguityError < Collect::Error` в `core/lib/collect/errors.rb`, как требует `spec.md`; до появления этого класса шаги ниже не выполняются.

1. Целевые файлы: `db/migrate/YYYYMMDDHHMMSS_create_sources.rb`, каталог `db/migrate/`
   Суть шага: создать каталог миграций primary database и первую миграцию для таблицы `sources` с колонками `plugin_type`, `external_id`, `sync_enabled`, `timestamps`, ограничениями `null: false`, default `false` для `sync_enabled` и unique index на `(plugin_type, external_id)`.
   Что уже есть в текущем коде: каталог `db/` существует, но содержит только `cache_schema.rb`, `queue_schema.rb`, `seeds.rb`; миграций primary DB и `db/schema.rb` нет.
   Чего не хватает по `spec.md`: физической таблицы `sources`, на которую будут опираться AR-валидации, `for_sync` и FK для checkpoint.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `db/cache_schema.rb`, `db/queue_schema.rb` и конфигурацию отдельных баз; этот issue вводит схему только для primary database.
   Какие зависимости шаг разрешает: создаёт базовую таблицу для модели `Source` и подготавливает родительскую сторону FK для checkpoint.

2. Целевые файлы: `db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb`, каталог `db/migrate/`
   Суть шага: добавить вторую миграцию для таблицы `sync_checkpoints` с `source_id bigint not null`, foreign key на `sources` с `on_delete: :cascade`, `position jsonb not null`, `timestamps` и unique index на `source_id`.
   Что уже есть в текущем коде: после шага 1 появится таблица `sources`; отдельной таблицы checkpoint пока нет.
   Чего не хватает по `spec.md`: DB-гарантий единственности checkpoint на источник, обязательного `position` и каскадного удаления при удалении `Source`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: структуру `sources`, схемы cache/queue баз и любые поля вне контракта `source_id`/`position`.
   Какие зависимости шаг разрешает: завершает минимальную схему БД для обеих моделей и делает возможными AR-ассоциации и тесты инвариантов.

3. Целевой файл: `app/models/source.rb`
   Суть шага: создать AR-модель `Source` поверх существующего `ApplicationRecord` с `before_validation` нормализацией `plugin_type` и `external_id` через `.to_s`, валидациями присутствия и уникальности пары, явной проверкой `sync_enabled` на запрет `nil`, `scope :for_sync`, `has_one :sync_checkpoint, dependent: :destroy`, методом `#upsert_checkpoint!(position:)` через `SyncCheckpoint.upsert`, и reader-логикой `sync_checkpoint`, которая возвращает `nil`, объект или поднимает `Collect::CheckpointAmbiguityError` при count > 1.
   Что уже есть в текущем коде: `app/models/application_record.rb` уже существует; модели `Source` ещё нет.
   Чего не хватает по `spec.md`: всей доменной логики источника, включая нормализацию, выборку для оркестратора и атомарный upsert checkpoint.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `ApplicationRecord`, стандартный boolean type-casting Active Record и всё, что относится к оркестрации, джобам и API вне scope.
   Какие зависимости шаг разрешает: вводит основной API текущего issue и формирует контракт для model specs.

4. Целевой файл: `app/models/sync_checkpoint.rb`
   Суть шага: создать AR-модель `SyncCheckpoint` с `belongs_to :source` и валидацией `position`, которая запрещает только `nil`, но допускает `{}` и не валидирует структуру JSON.
   Что уже есть в текущем коде: после шага 2 появится схема БД для таблицы; отдельной модели пока нет.
   Чего не хватает по `spec.md`: AR-слоя для checkpoint, связанного ровно с одним `Source`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: формат payload внутри `position`, plugin-specific проверки и дополнительные поля/callbacks вне спецификации.
   Какие зависимости шаг разрешает: завершает модельный слой для всех сценариев `upsert_checkpoint!`, FK-инвариантов и тестов `SyncCheckpoint`.

5. Целевые файлы: `spec/rails_helper.rb`, при необходимости минимальная правка `spec/spec_helper.rb`
   Суть шага: создать отдельный helper для Rails model specs, совместимый с текущим стеком без `rspec-rails`: добавить `core/lib` в `$LOAD_PATH`, сделать `require "collect"`, затем `require_relative "../config/environment"`, вызвать `abort` для production env, выполнить `ActiveRecord::Migration.maintain_test_schema!`, подключить `spec_helper` и определить явный RSpec harness для БД через `config.around(:each, :db)` или эквивалентный hook, который открывает транзакцию и делает rollback после каждого model-примера.
   Что уже есть в текущем коде: `spec/spec_helper.rb` уже загружает coverage, `collect` и plain `rspec`; в `Gemfile` есть `rspec`, но нет `rspec-rails`; `config/database.yml` описывает отдельный `test` env.
   Чего не хватает по `spec.md` и ревью: воспроизводимого bootstrap для model specs на plain RSpec и явной синхронизации test schema без догадок о `use_transactional_tests`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: coverage gate для `core/lib`; helper должен изолировать Rails model specs, а не ломать существующие unit-тесты.
   Какие зависимости шаг разрешает: позволяет писать и запускать model specs на test DB с предсказуемой очисткой данных между примерами.

6. Целевой файл: `spec/models/source_spec.rb`
   Суть шага: создать model spec для `Source`, который через `require "rails_helper"` и DB-tag из шага 5 покрывает AC по валидации `plugin_type`, `external_id`, `sync_enabled`, нормализации `Symbol -> String`, уникальности пары, `for_sync`, `#upsert_checkpoint!`, идемпотентности, независимости checkpoint между разными источниками и немутируемости сохранённого `position` после изменения входного Hash.
   Что уже есть в текущем коде: каталога `spec/models/` и тестов для `Source` нет.
   Чего не хватает по `spec.md`: полного покрытия acceptance criteria и инвариантов для модели `Source`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: существующие `spec/core/collect/*`; этот шаг должен только добавлять Rails model coverage.
   Какие зависимости шаг разрешает: создаёт наблюдаемые красные/зелёные проверки для `Source` и большей части функциональных требований issue.

7. Целевой файл: `spec/models/sync_checkpoint_spec.rb`
   Суть шага: создать model spec для `SyncCheckpoint`, который через `require "rails_helper"` и DB-tag покрывает обязательность `source`, запрет `position: nil`, допустимость `{}`, состояния `source.sync_checkpoint` при 0/1 записи, независимость checkpoint разных источников и каскадное удаление `source.destroy`.
   Что уже есть в текущем коде: тестового файла и каталога `spec/models/` для checkpoint нет.
   Чего не хватает по `spec.md`: тестового подтверждения AC для `SyncCheckpoint` и FK/cascade-инвариантов.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: контракт внешней ошибки `Collect::CheckpointAmbiguityError`; в этом шаге нельзя придумывать обходы, требующие менять production-схему.
   Какие зависимости шаг разрешает: завершает покрытие штатных сценариев checkpoint и оставляет отдельный исполнимый шаг для materialization ambiguity-case.

8. Целевые файлы: `spec/models/sync_checkpoint_spec.rb`, при необходимости локальный SQL setup внутри примера
   Суть шага: добавить отдельный ambiguity-spec с исполнимым setup, который временно снимает unique index на `sync_checkpoints.source_id`, вставляет вторую строку с тем же `source_id` прямым SQL или `insert_all!`, проверяет `source.reload.sync_checkpoint` на `Collect::CheckpointAmbiguityError`, а затем в `ensure` восстанавливает unique index, чтобы целевая схема и остальные примеры оставались консистентными.
   Что уже есть в текущем коде: после шага 7 будет базовый набор specs для checkpoint; постоянный DB-инвариант из шага 2 мешает материализовать повреждённое состояние без временного teardown/rebuild индекса.
   Чего не хватает по `spec.md`: наблюдаемого теста для состояния ambiguity при сохранении целевой production-схемы.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: постоянную миграцию или production-модель ради удобства теста; весь обход должен быть локализован внутри тестового примера.
   Какие зависимости шаг разрешает: закрывает последний acceptance criterion по неоднозначной checkpoint-ситуации без конфликта с DB unique constraint.

9. Целевые файлы: `app/models/source.rb`, `app/models/sync_checkpoint.rb`, `spec/models/source_spec.rb`, `spec/models/sync_checkpoint_spec.rb`, `db/schema.rb`
   Суть шага: выполнить финальную верификацию только воспроизводимыми runtime-командами текущего стека: `bundle exec rails db:migrate` для primary development schema, `RAILS_ENV=test bundle exec rails db:prepare` для test DB, `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb`, затем `bundle exec rspec spec/core/collect`; при красных тестах вносить только те точечные правки в модели/спеки, которые подтверждены failing checks, а `db/schema.rb` зафиксировать как отражение двух новых таблиц primary DB.
   Что уже есть в текущем коде: есть `config/database.yml` с `development` и `test`, есть существующие `spec/core/collect/*`, но нет схемы primary DB и model specs.
   Чего не хватает по `spec.md` и ревью: полного runtime gate, который подготавливает именно test DB и воспроизводит acceptance-проверку на чистом checkout без `rspec-rails`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: любые зелёные части реализации без наблюдаемого failing trigger; шаг должен завершать, а не расширять scope.
   Какие зависимости шаг разрешает: закрывает acceptance criteria, подтверждает отсутствие регрессий в `core/lib` и завершает реализацию issue.
