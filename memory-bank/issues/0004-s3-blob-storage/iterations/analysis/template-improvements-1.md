---
issue: 4
title: Template Improvements — S3-Compatible Raw Blob Storage Adapter
type: template-improvements
status: draft
version: v1
date: 2026-04-07
input_cycle_analysis: cycle-analysis-1.md
---

# Template Improvements: Issue #0004 — S3-Compatible Raw Blob Storage Adapter

## Input

- Source analysis: `memory-bank/issues/0004-s3-blob-storage/iterations/analysis/cycle-analysis-1.md`

## Changed Files

- `memory-bank/templates/prompts/01-1-generate-brief.md`
- `memory-bank/templates/prompts/03-1-fix-brief.md`
- `memory-bank/templates/prompts/01-2-generate-spec.md`
- `memory-bank/templates/prompts/02-2-review-spec.md`
- `memory-bank/templates/prompts/01-3-generate-plan.md`
- `memory-bank/templates/prompts/02-3-review-plan.md`
- `memory-bank/templates/prompts/01-4-generate-code.md`
- `memory-bank/templates/prompts/02-4-review-code.md`
- `memory-bank/issues/README.md`
- `memory-bank/issues/EXMAPLES.md`

## Application Table

| Recommendation from cycle-analysis-1.md | Target file | Change type | Status | Materialized change |
|---|---|---|---|---|
| `01-1-generate-brief.md`: add `scope-canonicalization gate` | `memory-bank/templates/prompts/01-1-generate-brief.md` | add gate | apply | Added canonical-scope rule to keep one object of scope consistent across problem, context, success and out-of-scope sections. |
| `03-1-fix-brief.md`: add `term-closure gate` | `memory-bank/templates/prompts/03-1-fix-brief.md` | tighten fix | apply | Added explicit rule that fix must close the undefined term or escalate it as an open blocking question. |
| `01-2-generate-spec.md`: add `runtime-branch split gate` | `memory-bank/templates/prompts/01-2-generate-spec.md` | add gate | apply | Added forced split between grounded runtime branches and branches that must move to `Preconditions` / out of scope / next issue. |
| `02-2-review-spec.md`: require `FR/input branch -> success AC -> invalid-branch AC` matrix | `memory-bank/templates/prompts/02-2-review-spec.md` | tighten review | apply | Added explicit matrix check for union-type, duck-typed, optional and adversarial branches. |
| `01-3-generate-plan.md`: make `two-tier runtime gate` mandatory | `memory-bank/templates/prompts/01-3-generate-plan.md` | add gate | apply | Added requirement to split focused verification from final regression gate when existing suites must remain green. |
| `02-3-review-plan.md`: add `verification-prerequisite closure gate` | `memory-bank/templates/prompts/02-3-review-plan.md` | tighten review | apply | Added check that each final command has earlier observational proof for the exact prerequisites it needs. |
| `01-4-generate-code.md`: add `pre-completion runtime gate` | `memory-bank/templates/prompts/01-4-generate-code.md` | add gate | apply | Added rule forbidding completion on unit-pass only when the plan still contains execution-level final gates. |
| `02-4-review-code.md`: forbid `0 замечаний` under `runtime_unknown` | `memory-bank/templates/prompts/02-4-review-code.md` | tighten review | apply | Added explicit ban on `0 замечаний` while `runtime-unknown gate` remains or scorecard verdict is not `ready_for_activation`. |
| workflow/system gate: add `artifact-completeness gate` | `memory-bank/issues/README.md`, `memory-bank/issues/EXMAPLES.md` | document workflow | apply | Added stage-completion rule that requires canonical stage artifacts before moving forward. |
| workflow/system gate: add `canonical-path gate` | `memory-bank/issues/README.md`, `memory-bank/issues/EXMAPLES.md` | update storage convention | apply | Added authoritative-path rule so only `iterations/<stage>/` artifacts can open workflow gates. |

## Applied Recommendations

1. Materialized a new early Brief boundary rule for single canonical scope selection.
2. Tightened Brief fix behavior so wording churn without measurable closure no longer qualifies as a fix.
3. Forced Spec generation to resolve runtime-dependent branches before they silently leak into scope.
4. Forced Spec review to test branch completeness, not just happy-path prose.
5. Split Plan verification into focused contract checks and explicit regression gate when the spec requires both.
6. Tightened Plan review so runtime prerequisites are proven per final command, not assumed globally.
7. Moved Code completion gate from unit-pass to actual final runtime gate or explicit blocker.
8. Prevented Code review from claiming clean readiness while runtime uncertainty is still open.
9. Added workflow-level artifact completeness requirement to reduce analysis ambiguity.
10. Added workflow-level canonical path requirement to prevent competing authoritative review histories.

## Skipped As Duplicate Or Already Covered

- None. Existing prompts already had partial controls for undefined terms, preconditions, runtime setup and runtime-unknown classification, but none of the cycle-analysis recommendations were fully covered in the required form. They were applied as narrow tightenings rather than duplicated as parallel rules.

## Traceability Notes

- Brief churn (`raw blob` vs broader attachment scope) was closed at the earliest generating prompt rather than duplicated in review.
- Runtime branch leakage (`from_env`-style path) was fixed in Spec generation, with Spec review only strengthened for branch materialization.
- Regression-gate defects were split between Plan generation, Plan review and Code completion/review so each stage owns the narrowest relevant guard.
- Cross-cycle artifact ambiguity was fixed in workflow documentation instead of adding another analysis-only reminder.

## Execution Metadata

- `system`: unknown
- `model`: unknown
- `provider`: unknown
- `execution_date`: 2026-04-07
- `prompt_id`: `memory-bank/templates/prompts/06-1-apply-cycle-improvements.md`

## Runtime Telemetry

- `started_at`: unknown
- `finished_at`: 2026-04-07T06:36:54+03:00
- `elapsed_seconds`: unknown
- `input_tokens`: not available in current runtime
- `output_tokens`: not available in current runtime
- `total_tokens`: not available in current runtime
- `estimated_cost`: not available in current runtime
- `limit_context`: not available in current runtime
