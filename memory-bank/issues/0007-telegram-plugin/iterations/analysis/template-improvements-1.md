# Template Improvements 1 — Issue #7

Применённых изменений в общие шаблоны нет.

Проверено по `cycle-analysis-1.md`:

- Конфликт `domain checkpoint` vs `transport resume cursor` оказался специфичным для Telegram/getUpdates и пока не тянет на общий template rule.
- Размещение plugin implementation рядом с pure-Ruby contract тоже project-specific и уже покрывается инженерным здравым смыслом / grounding в spec.

Итог: дубликатов или обязательных template fixes по этому циклу не выявлено.
