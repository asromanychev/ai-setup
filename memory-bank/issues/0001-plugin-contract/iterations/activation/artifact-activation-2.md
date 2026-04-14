---
artifact_type: spec
activated_at: 2026-04-05
activated_by: retrospective (new process applied 2026-04-12)
---

# Artifact Activation: spec.md

## Активированный артефакт

- **Тип:** spec
- **Draft-файл:** `iterations/spec/spec-v2.md`
- **Active-файл:** `spec.md` (корень папки issue)

## Источники подтверждения

- **Review-файл:** `iterations/spec/spec-review-2.md`
  - Результат: 0 замечаний, все 7 TAUS-критериев Pass
- **Scorecard:** `iterations/spec/spec-score-2.json`
  - Weighted score: 5.0
  - Ни одного измерения с score ≤ 2
  - Verdict: `ready_for_activation`

## Gate check

- [x] Последний `spec-score-2.json` имеет `verdict = ready_for_activation`
- [x] Ни одно измерение не имеет `score <= 2`
- [x] Markdown review (`spec-review-2.md`) содержит положительный вердикт
- [x] Grounding выполнен: реальные пути файлов зафиксированы в spec.md раздел 6

## История итераций до активации

2 итерации (v1→v2). v1 упустила: (1) неприменимое состояние loading/in-progress не зафиксировано; (2) edge cases для cursor и source_config[:records] отсутствовали. v2 закрыла оба пробела.

## Что скопировано

`iterations/spec/spec-v2.md` → `spec.md` (корень папки issue, с добавлением frontmatter)
