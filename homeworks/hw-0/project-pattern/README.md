# Project Template

Шаблон для новых проектов с AI-агентом (Claude).

## Как использовать

```sh
cp -r ~/edu/ai-setup/homeworks/hw-0/project-pattern ~/edu/aida/<project-name>
cd ~/edu/aida/<project-name>
```

Затем:
1. Заполни `CLAUDE.md` — опиши проект, стек, команды
2. Раскомментируй нужные инструменты в `.mise.toml`
3. Запусти окружение:

```sh
make install
```

4. Запусти Claude:

```sh
claude
```

## Файлы шаблона

| Файл | Назначение |
|------|-----------|
| `CLAUDE.md` | Контекст для агента: стек, команды, правила проекта |
| `.mise.toml` | Проектные инструменты (node глобальный — не дублируй) |
| `Makefile` | `make install` / `make check` |
| `.gitignore` | Исключает `.env`, логи, `tmp/` |

## Требования

- `node` установлен глобально через mise (`~/.config/mise/config.toml`)
- `claude` доступен глобально — проверь: `which claude`
