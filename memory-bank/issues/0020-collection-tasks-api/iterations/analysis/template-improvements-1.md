# Template Improvements 1

- Для задач уровня API lifecycle полезно в будущем заранее фиксировать в spec точную форму success/error JSON, чтобы избежать лишних решений на этапе реализации.
- Для `MAKE_NEW_ISSUE` стоит явно оговаривать, допустим ли временный job-stub, когда enqueue требуется раньше отдельного issue на реализацию worker logic.
