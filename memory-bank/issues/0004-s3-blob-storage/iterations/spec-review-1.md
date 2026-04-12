---
issue: 4
spec_version_reviewed: spec-v1.md
review_number: 1
date: 2026-04-06
verdict: FAIL (3 замечания)
---

# Spec Review #1 — Issue 0004: S3 Blob Storage

## Проверяемый файл
`memory-bank/issues/0004-s3-blob-storage/iterations/spec-v1.md`

---

## TAUS-вердикты

### T (Testable) — Pass
AC содержат конкретные поведенческие условия с точными сообщениями, конкретными аргументами и счётчиком вызовов `put_object`. По каждому AC можно написать автотест.

### A (Ambiguous-free) — Pass
Отсутствуют слова «быстро», «удобно», «корректно обработать», «и т.д.». Все требования сформулированы через конкретные типы, сообщения и поведение.

### U (Uniform) — Fail

**Дефект 1. AC не покрывает сценарий `client` без метода `put_object`.**

Цитата из спеки (таблица сценариев):
> «`client` — объект без метода `put_object` | При вызове `#store` поднимается `NoMethodError`; пробрасывается без оборачивания»

Проблема: сценарий описан в таблице ошибок, но в разделе AC нет ни одного проверяемого критерия, который бы это верифицировал. Нельзя написать автотест без соответствующего AC.

Вариант исправления:
```
- [ ] `storage.store(key: "k", body: "x")`, если `client` — объект без метода `put_object`,
      поднимает `NoMethodError`; исключение не оборачивается.
```

**Дефект 2. Инвариант «отсутствие кэширования ENV» не материализован в AC.**

Цитата из FR п.9:
> «`from_env` не кэширует значения ENV и не сохраняет client между разными вызовами `from_env`»

Проблема: в AC нет falsifiable теста — нет критерия, который мутирует ENV между двумя вызовами `from_env` и проверяет, что второй вызов отражает новое значение (или поднимает `KeyError`).

Вариант исправления:
```
- [ ] Если `S3_BUCKET` был установлен при первом вызове `from_env`, а затем удалён из ENV
      до второго вызова `from_env`, второй вызов поднимает `KeyError`.
```

### S (Scoped) — Pass
Одна фича, ~1100 слов. Затрагивает 2 модульных зоны.

### Scope явно ограничен — Pass

### Инварианты перечислены — Pass

### Grounding и реализуемость — Fail

**Дефект 3. Инвариант «immutability bucket через aliasing» не покрыт AC.**

Цитата из Grounding:
> «Конструктор сохраняет `@bucket` и `@client` как frozen-строку»

Это структурный контракт уровня `freeze`/`isolation`. Согласно правилам спецификации, каждый такой инвариант обязан иметь falsifiable adversarial AC.

Проблема: в таблице adversarial edge cases упомянут aliasing для `key` при вызове `#store`, но aliasing входного `bucket`-аргумента в конструкторе не проверяется.

Вариант исправления:
```
- [ ] `b = "my-bucket"; storage = BlobStorage.new(bucket: b, client: client); b << "_mutated"` —
      последующий вызов `store` использует `"my-bucket"`, а не `"my-bucket_mutated"`.
```

---

## Дополнительные проверки

### Module-budget — Pass
2 зоны (core/lib/collect/, spec/core/collect/).

### Precondition hygiene — Pass
Нет неисполненных prerequisites: `aws-sdk-s3` в Gemfile, load-path настроен в spec_helper.

### Boundary-to-AC completeness — Fail
Три дефекта выше являются boundary-to-AC completeness defects.

---

## Итог

**3 Fail.** Спека не готова к реализации до закрытия всех трёх дефектов.

---

## Execution Metadata

- `system`: unknown
- `model`: claude-sonnet-4-6
- `provider`: Anthropic
- `execution_date`: 2026-04-06
- `prompt_id`: `memory-bank/templates/prompts/02-2-review-spec.md`

## Runtime Telemetry

- `started_at`: 2026-04-06T21:05:00+03:00
- `finished_at`: 2026-04-06T21:08:00+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
