# Project context + Analysis tab

## Файл контекста

Путь: `{projectRoot}/.ai/project-context.json`

Собирается из:
- метаданные проекта (overview)
- зависимости + global package metadata
- виджеты (custom + usages)
- медиа (assets, bindings, usages)
- git status
- build configs (tasks.json / defaults)
- documentation sections + links
- change history (30 записей)
- file structure (depth 2)

## Вкладка «Анализ проекта»

- При открытии автоматически создаёт контекст (если нет)
- Кнопка «Пересобрать контекст»
- Поле вопроса → Cursor Agent CLI (`--mode ask`, `--output-format text`)
- Агент читает `.ai/project-context.json` и может смотреть исходники
- Лог CLI внизу (source: analysis)

## Файлы

- `lib/services/project_context_service.dart`
- `lib/services/analysis/cursor_cli_project_qa_service.dart`
- `lib/ui/views/analysis_view.dart`
- `lib/core/utils/project_context_paths.dart`
