---
name: Plan Review 4 — Plugin Contract
description: Ревью plan-v4.md для задачи 0001-plugin-contract
type: review
status: draft
issue: 0001-plugin-contract
reviewed_plan: plan-v4.md
---

# Plan Review: plan-v4.md (Issue #0001)

0 замечаний, план готов к реализации.

## Что подтверждено по grounding

- `plan-v4.md` ссылается только на существующие файлы: `core/lib/collect/plugin.rb`, `core/lib/collect/plugin_registry.rb`, `core/lib/collect/null_plugin.rb`, `spec/core/collect/plugin_contract_spec.rb`, `spec/core/collect/plugin_registry_spec.rb`, `spec/core/collect/null_plugin_spec.rb`, `spec/core/collect/registry_null_plugin_integration_spec.rb`.
- Порядок шагов логичен: сначала изменения контракта `Plugin`, затем поведение `NullPlugin`, затем фиксация и при необходимости исправление `PluginRegistry`, после этого расширение unit/integration тестов и финальная верификация.
- Условный шаг 6 теперь корректно привязан к наблюдаемому результату шага 5, поэтому ветка с изменением `plugin_registry.rb` выполнима и не требует догадок.
- План покрывает acceptance criteria из `spec.md`, включая проверки иммутабельности, ошибок контракта, сценарии `NullPlugin`, интеграцию через `PluginRegistry.default` и финальную проверку покрытия через `CoverageAssertions`.
