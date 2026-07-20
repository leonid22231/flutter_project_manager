# Кнопка «Открыть в Cursor»

## Изменения

- `lib/core/utils/platform_utils.dart` — `openInCursor()`, общий `_runShellCommands`
- `lib/l10n/app_localizations.dart` — `openInCursor`, `openInCursorFailed`
- `lib/ui/views/project_overview_view.dart` — кнопка рядом с VS Code

## Поведение

На Windows сначала ищется `cursor.cmd` в `%LOCALAPPDATA%\Programs\cursor|Cursor\...`, затем команда `cursor` из PATH.
