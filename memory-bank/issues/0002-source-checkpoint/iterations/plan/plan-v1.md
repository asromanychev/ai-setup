1. Целевой файл: `core/lib/collect/errors.rb`
   Суть шага: проверить precondition из `spec.md`: в кодовой базе до начала реализации должен существовать `Collect::CheckpointAmbiguityError < Collect::Error`.
   Что уже есть в текущем коде: файл существует и уже определяет `Collect::Error`, `Collect::ContractError`, `Collect::UnknownPluginError`.
   Чего не хватает по `spec.md`: класса `Collect::CheckpointAmbiguityError` сейчас нет, хотя спецификация считает его внешней зависимостью.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: существующую иерархию ошибок `ContractError` и `UnknownPluginError`; в рамках данного issue нельзя самовольно расширять `core/lib`, если инфраструктурный precondition не закрыт отдельной задачей.
   Какие зависимости шаг разрешает: даёт наблюдаемый trigger для старта реализации issue; если precondition не выполнен, последующие шаги по модели `Source#sync_checkpoint` блокируются до закрытия внешней зависимости.

2. Целевые файлы: `db/migrate/YYYYMMDDHHMMSS_create_sources.rb`, каталог `db/migrate/`
   Суть шага: создать каталог миграций Rails primary database и первую миграцию для таблицы `sources` с колонками `plugin_type`, `external_id`, `sync_enabled`, `timestamps` и уникальным composite index `(plugin_type, external_id)`.
   Что уже есть в текущем коде: каталог `db/` существует, но содержит только `cache_schema.rb`, `queue_schema.rb`, `seeds.rb`; миграций primary DB нет.
   Чего не хватает по `spec.md`: первичной таблицы `sources` с DB-ограничениями not null, default `false` для `sync_enabled` и unique index.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `db/cache_schema.rb` и `db/queue_schema.rb`, а также конфигурацию отдельных баз; этот issue затрагивает только primary database.
   Какие зависимости шаг разрешает: создаёт базовую схему для модели `Source`, FK из `sync_checkpoints` и дальнейших model specs.

3. Целевые файлы: `db/migrate/YYYYMMDDHHMMSS_create_sync_checkpoints.rb`, каталог `db/migrate/`
   Суть шага: добавить миграцию для таблицы `sync_checkpoints` с `source_id bigint not null`, FK на `sources` с `ON DELETE CASCADE`, `position jsonb not null`, `timestamps` и unique index на `source_id`.
   Что уже есть в текущем коде: после шага 2 будет существовать таблица-родитель `sources`; отдельной таблицы checkpoint сейчас нет.
   Чего не хватает по `spec.md`: DB-гарантии единственности checkpoint на `source_id`, обязательного `position` и каскадного удаления после удаления `Source`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: структуру таблицы `sources`, схемы cache/queue баз и любые поля вне оговорённого контракта `source_id`/`position`.
   Какие зависимости шаг разрешает: завершает минимальную схему БД для обеих моделей и даёт опору для AR-ассоциаций и тестов инвариантов.

4. Целевой файл: `app/models/source.rb`
   Суть шага: создать AR-модель `Source` с `before_validation` нормализацией `plugin_type`/`external_id` через `.to_s`, валидациями присутствия и уникальности пары, проверкой `sync_enabled` на исключение `nil`, `scope :for_sync`, `has_one :sync_checkpoint, dependent: :destroy`, методом `#upsert_checkpoint!(position:)` через `SyncCheckpoint.upsert`, и reader-логикой `sync_checkpoint`, которая возвращает `nil`, объект или поднимает `Collect::CheckpointAmbiguityError` при count > 1.
   Что уже есть в текущем коде: `app/models/application_record.rb` задаёт общий базовый класс AR; самой модели `Source` нет.
   Чего не хватает по `spec.md`: всей доменной логики источника, включая нормализацию, AR-валидаторы, выборку `for_sync`, атомарный upsert checkpoint и защиту от неоднозначности.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: `ApplicationRecord`, поведение стандартного AR type-casting для boolean и любые элементы оркестрации/джоб/API, явно вынесенные из scope.
   Какие зависимости шаг разрешает: вводит основной публичный API issue и создаёт контракт для тестов `Source` и для модели `SyncCheckpoint`.

5. Целевой файл: `app/models/sync_checkpoint.rb`
   Суть шага: создать AR-модель `SyncCheckpoint` с `belongs_to :source` и валидацией `position` на запрет `nil` без валидации содержимого JSON.
   Что уже есть в текущем коде: схемная зависимость будет создана шагом 3; отдельной модели `SyncCheckpoint` сейчас нет.
   Чего не хватает по `spec.md`: AR-слоя для checkpoint, связанного ровно с одним `Source`, и разрешения пустого `{}` при запрете `nil`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: формат payload внутри `position`, plugin-specific валидации и любые дополнительные колонки или callbacks, которых нет в спецификации.
   Какие зависимости шаг разрешает: завершает модельный слой для всех сценариев `upsert_checkpoint!`, FK-инвариантов и specs `SyncCheckpoint`.

6. Целевые файлы: `spec/rails_helper.rb`, `spec/spec_helper.rb`
   Суть шага: создать отдельный `spec/rails_helper.rb`, который сначала добавляет `core/lib` в `$LOAD_PATH`, делает `require "collect"`, затем подключает `spec_helper` и Rails environment, а также настраивает `config.use_transactional_tests = true`; `spec/spec_helper.rb` при этом оставить без логических изменений, кроме минимальной совместимости, если её потребует подключение rails specs.
   Что уже есть в текущем коде: `spec/spec_helper.rb` уже поднимает coverage и грузит `core/lib` для unit-тестов ядра.
   Чего не хватает по `spec.md`: отдельного helper’а для model specs Rails с транзакционными тестами и явной загрузкой `collect` до Rails env.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: coverage gate для `core/lib` и текущую конфигурацию unit-тестов, поскольку coverage для `app/models` не входит в gate этого issue.
   Какие зависимости шаг разрешает: позволяет писать и запускать model specs без вмешательства в существующие core/lib tests.

7. Целевой файл: `spec/models/source_spec.rb`
   Суть шага: создать model spec для `Source`, покрывающий AC по валидации `plugin_type`, `external_id`, `sync_enabled`, нормализации `Symbol -> String`, уникальности пары, `for_sync`, `#upsert_checkpoint!`, идемпотентности, независимости checkpoint между разными source, защите от `position: nil` и немутируемости сохранённого `position` после изменения входного Hash.
   Что уже есть в текущем коде: каталога `spec/models/` и tests для `Source` нет; unit-тесты `core/lib` уже существуют и не должны деградировать.
   Чего не хватает по `spec.md`: полного покрытия acceptance criteria и инвариантов для модели `Source`.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: существующие `spec/core/collect/*` и их coverage-назначение; этот шаг должен добавлять Rails model specs, а не заменять unit coverage ядра.
   Какие зависимости шаг разрешает: даёт наблюдаемые тестовые триггеры для корректировки `Source` и подтверждает большую часть функциональных требований issue.

8. Целевой файл: `spec/models/sync_checkpoint_spec.rb`
   Суть шага: создать model spec для `SyncCheckpoint`, покрывающий обязательность `source`, запрет `position: nil`, допустимость `{}`, поведение `source.sync_checkpoint` при 0/1 записях и наблюдаемый trigger для неоднозначности при count > 1 через прямой SQL или иной обход AR-валидаций, если precondition из шага 1 закрыт.
   Что уже есть в текущем коде: отдельного тестового файла и каталога `spec/models/` для checkpoint нет.
   Чего не хватает по `spec.md`: тестового подтверждения AC для `SyncCheckpoint`, каскадного удаления и сценария ambiguity.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: контракт внешней ошибки `Collect::CheckpointAmbiguityError`; если precondition шага 1 не закрыт, этот spec должен зафиксировать блокировку, а не молча подменять тип ошибки другим классом.
   Какие зависимости шаг разрешает: завершает покрытие acceptance criteria по checkpoint и создаёт наблюдаемый источник решений для точечных правок моделей.

9. Целевые файлы: `app/models/source.rb`, `app/models/sync_checkpoint.rb`, `spec/models/source_spec.rb`, `spec/models/sync_checkpoint_spec.rb`
   Суть шага: выполнить только те точечные правки, которые выявлены красными тестами шагов 7-8 или расхождением схемы после миграций; не добавлять условные изменения без конкретного failing trigger.
   Что уже есть в текущем коде: после шагов 4-8 будет первичная реализация и набор наблюдаемых checks.
   Чего не хватает по `spec.md`: только те детали поведения, которые фактически не пройдут AC при первом прогоне.
   Что в этом файле запрещено переписывать без отдельного наблюдаемого расхождения: любые части моделей и тестов, уже проходящие AC, а также scope issue вне AR-моделей и тестов.
   Какие зависимости шаг разрешает: переводит реализацию из draft-состояния в состояние, готовое к финальной верификации без догадок.

10. Целевые файлы: runtime-команды `bundle exec rails db:migrate`, `bundle exec rspec spec/models/source_spec.rb spec/models/sync_checkpoint_spec.rb`, `bundle exec rspec spec/core/collect`
    Суть шага: выполнить финальную верификацию схемы и тестов, убедиться, что model specs зелёные, инварианты БД выполняются, а существующие `core/lib` tests остаются зелёными; если в процессе появился `db/schema.rb`, его состояние должно отражать обе новые таблицы primary DB.
    Какие зависимости шаг разрешает: закрывает acceptance criteria и подтверждает, что изменения не регрессируют существующий набор `core/lib`.
