# Memory Bank Issues

Эта директория хранит артефакты задач по GitHub Issue в формате:

`memory-bank/issues/0001-short-slug/`

## Именование папок

- Каждая папка задачи начинается с 4-значного номера issue с ведущими нулями.
- После номера идёт короткий slug на английском языке.
- Пример: `0001-auth-setup`, `0005-pdf-export`.

## Структура папки задачи

Новая структура разделяет артефакты по этапам и хранит не только markdown-документы, но и machine-readable scorecards.

```text
memory-bank/issues/0001-auth-setup/
├── brief.md
├── spec.md
├── plan.md
├── hw-reports/
└── iterations/
    ├── brief/
    │   ├── brief-rubric.json
    │   ├── brief-v1.md
    │   ├── brief-review-1.md
    │   ├── brief-score-1.json
    │   ├── brief-fix-contract-1.json
    │   └── brief-v2.md
    ├── spec/
    │   ├── spec-rubric.json
    │   ├── spec-v1.md
    │   ├── spec-review-1.md
    │   ├── spec-score-1.json
    │   └── spec-fix-contract-1.json
    ├── plan/
    │   ├── plan-rubric.json
    │   ├── plan-v1.md
    │   ├── plan-review-1.md
    │   ├── plan-score-1.json
    │   └── plan-fix-contract-1.json
    ├── code/
    │   ├── code-rubric.json
    │   ├── code-review-1.md
    │   ├── code-score-1.json
    │   └── code-fix-contract-1.json
    ├── activation/
    │   └── artifact-activation-1.md
    └── analysis/
        └── cycle-analysis-1.md
```

## Что хранится на каждом этапе

Для `brief`, `spec`, `plan`, `code` вводятся три обязательных типа артефактов:

- `*-rubric.json`
  Адаптированная под этап рубрика с 5 измерениями, весами и описанием уровней `1`, `3`, `5`.
- `*-score-*.json`
  Итог ревью в machine-readable виде: score по каждому измерению, confidence, evidence, blockers, weighted score, verdict.
- `*-fix-contract-*.json`
  Контракт на исправление: какие измерения надо поднять, какие секции менять, что запрещено трогать.

Markdown-ревью остаются обязательными, но теперь считаются human-readable пояснением к `*-score-*.json`, а не единственным источником истины.

## Draft / Active Workflow

### Draft-артефакты

Все черновики и результаты ревью всегда хранятся в `iterations/<stage>/`.

Правила:
- генерация создает `*-rubric.json` при первом проходе этапа, если файла ещё нет;
- генерация создает `*-v1.md`, повторная правка создает `*-v{N+1}.md`;
- ревью создает пару файлов: `*-review-X.md` и `*-score-X.json`;
- fix-шаг создает `*-fix-contract-X.json` и новую версию документа;
- authoritative артефакты этапа разрешено сохранять только в каноническую подпапку `iterations/<stage>/` с каноническим именованием;
- stray-файлы вне `iterations/<stage>/` не открывают gate следующего этапа и должны быть либо перемещены в канонический путь, либо явно признаны неавторитетными;
- предыдущие версии, scorecards и review-файлы никогда не перезаписываются.

### Active-артефакты

Финальные утвержденные документы лежат в корне папки issue:
- `brief.md`
- `spec.md`
- `plan.md`

Эти файлы считаются актуальными (`active`) и используются следующими шагами пайплайна:
- `spec.md` строится только на утвержденном `brief.md`;
- `plan.md` строится только на утвержденном `spec.md`;
- реализация кода опирается только на утвержденные `spec.md` и `plan.md`.

## Правило продвижения по циклу

Обычный жизненный цикл документа:

1. Генерация создает `*-rubric.json` и `*-v1.md` в `iterations/<stage>/`.
2. Ревью создает `*-review-X.md` и `*-score-X.json`.
3. Правка создает `*-fix-contract-X.json` и новую версию `*-v{N+1}.md`.
4. Документ может быть активирован только если:
   - последний markdown review содержит положительный вердикт;
   - в последнем `*-score-X.json` нет измерений с `score <= 2`;
   - итоговый `verdict` равен `ready_for_activation`.
4.1. Переход к следующей стадии разрешён только после `artifact-completeness gate`:
   - для `brief`, `spec`, `plan`, `code` должны существовать все обязательные артефакты текущего этапа по правилам workflow;
   - отсутствие rubric, scorecard, fix-contract или activation-следа должно либо блокировать переход, либо быть явно зафиксировано как допустимое исключение с причиной;
   - markdown review сам по себе не заменяет отсутствующий machine-readable артефакт.
5. После этого актуальная версия копируется в корень папки issue как active-файл.

## Активация

Активация хранится отдельно в `iterations/activation/`.

`artifact-activation-X.md` обязан фиксировать:
- тип артефакта;
- какой draft-файл был активирован;
- какой review-файл подтвердил качество;
- какой scorecard открыл gate;
- какой active-файл обновлён.

## Анализ цикла

Postmortem и дистилляция правил теперь лежат в `iterations/analysis/`.

`cycle-analysis-X.md` обязан использовать:
- markdown review-файлы;
- `*-score-*.json`;
- `*-fix-contract-*.json`;
- active-документы;
- поздние code-review и фактические изменения кода.

После `cycle-analysis-X.md` может идти материализация улучшений workflow:

- `template-improvements-X.md`
  Отчёт о том, какие изменения реально внесены в `memory-bank/templates` и связанную документацию по итогам cycle analysis.
  Этот шаг нужен, чтобы postmortem не оставался пассивным артефактом.

## Ограничения

- Не использовать draft-файлы как замену active-файлам, если следующий шаг требует утвержденный документ.
- Не смешивать артефакты разных issue в одной папке.
- Не перезаписывать старые версии, review-файлы, scorecards и fix-contracts.
- Не активировать артефакт только по тексту `0 замечаний`, если scorecard содержит blocker.
- Не создавать конкурирующие authoritative артефакты вне канонических stage-папок вроде `iterations/spec-review-1.md` рядом с `iterations/spec/spec-review-1.md`.
