# hw-1 artifact layout

Эта папка хранит артефакты SDD по GitHub issue.

## Канонический формат сдачи
- `memory-bank/features/001/brief.md`
- `memory-bank/features/001/spec.md`
- `memory-bank/features/001/plan.md`
- `report.md`

Именно каталог `features/001/` считается каноническим комплектом для текущей фичи в формате домашнего задания.

## Дополнительная структура
- `memory-bank/features/issue_<N>/` — issue-oriented зеркало артефактов, если нужно хранить документы по номеру issue
- `codex/` — review-отчёты и промежуточные решения, сгенерированные Codex
- `claude/` — review-отчёты и промежуточные решения, сгенерированные Claude
- `codex/intermediate_solutions/git_issue_<N>/` — найденные неоднозначности и принятые решения для конкретного issue
- `claude/intermediate_solutions/git_issue_<N>/` — аналогично для Claude
- `promts/create_brief_sdd_issue_model_aware.md` — промпт для генерации Brief
- `promts/create_sdd_full_cycle_model_aware.md` — промпт для полного цикла Brief -> Spec -> Plan

## Правило версионирования

Если в каталоге фичи уже существует итоговый файл, новый запуск не должен его перезаписывать. Вместо этого создаётся новая версия рядом:
- `brief_codex_v2.md`
- `spec_claude_v2.md`
- `plan_codex_v3.md`

## Текущая фича
- Brief: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/brief.md`
- Spec: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/spec.md`
- Plan: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/memory-bank/features/001/plan.md`
- Brief Review: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/brief-review-001.md`
- Spec Review: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/spec-review-001.md`
- Plan Review: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/plan-review-001.md`
- Decisions: `/home/aromanychev/edu/ai-setup/homeworks/hw-1/codex/intermediate_solutions/git_issue_1/questions-and-decisions.md`

## Примечание

Каталог `memory-bank/features/issue_1/` оставлен как вспомогательное зеркало, но не является основным маршрутом сдачи.
