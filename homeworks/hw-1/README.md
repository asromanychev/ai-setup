# HW-1 Artifact Layout

[![CI](https://github.com/asromanychev/ai-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/asromanychev/ai-setup/actions/workflows/ci.yml)

Эта папка хранит артефакты HW-1 по полному SDD-циклу для issue `#1` проекта `ai-da-collect`.

## Канонический комплект сдачи

- `memory-bank/features/001/brief.md`
- `memory-bank/features/001/spec.md`
- `memory-bank/features/001/plan.md`
- `report.md`

Именно каталог `memory-bank/features/001/` следует считать основным комплектом артефактов для проверки.

## Зеркало по номеру issue

Для совместимости с промптами и альтернативной схемой именования сохранено зеркало:

- `memory-bank/features/issue_1/brief.md`
- `memory-bank/features/issue_1/spec.md`
- `memory-bank/features/issue_1/plan.md`

Содержимое `features/001` и `features/issue_1` синхронизировано и описывает одну и ту же финальную версию фичи.

## Review Bundle-ы

### Codex

- `codex/brief-review-001.md`
- `codex/spec-review-001.md`
- `codex/plan-review-001.md`
- `codex/brief-review-issue_1.md`
- `codex/spec-review-issue_1.md`
- `codex/plan-review-issue_1.md`

### Claude

- `claude/brief-review-001.md`
- `claude/spec-review-001.md`
- `claude/plan-review-001.md`
- `claude/brief-review-issue_1.md`
- `claude/spec-review-issue_1.md`
- `claude/plan-review-issue_1.md`

## Что именно зафиксировано в Feature 001

Финальная версия артефактов больше не допускает произвольную семантику checkpoint. Для `Plugin Contract` принят один явный вариант:

- `checkpoint_in` у контракта - `Hash` или `nil`;
- `NullPlugin` трактует `nil` и `{}` как `cursor = 0`;
- `checkpoint_in[:cursor]` обязан быть неотрицательным `Integer`;
- `checkpoint_out` - структурированный `Hash`, пригодный для следующего шага.

Это изменение синхронизировано с каноническими материалами из `~/edu/aida/ai-da-collect`.

## Evidence и формальные критерии

- CI workflow для репозитория расположен в `.github/workflows/ci.yml`.
- Machine-readable coverage gate `>= 80%` зафиксирован в исходном проекте `ai-da-collect` и отражён в артефактах `spec.md` и `plan.md` этой домашки.
- Итоговый отчёт по всем четырём фичам находится в `report.md`.
