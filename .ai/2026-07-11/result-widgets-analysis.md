# Виджеты: парсинг параметров + dual analysis

## Архитектура (static + Cursor CLI)

- `StaticWidgetAnalysisBackend` — быстрый офлайн-скан (`WidgetAnalyzerService`)
- `CursorCliWidgetAnalysisBackend` — фоновое обогащение описаний через `agent -p --mode ask`
- `WidgetAnalysisCoordinator` — сначала static, затем cursor в фоне (если включён в настройках)

## Исправления парсинга

- `DartConstructorParser` — структурные параметры: имя, тип, positional/named, required, default
- Конструктор класса исключается из usages (диапазон строк ctor)
- В usages: только `file:line` + позиционные аргументы (без snippet)

## UI

- Параметры конструктора — столбик с бейджами «позиционный/именованный», «обязательный/необязательный»
- Статус «Обогащение через Cursor CLI...» в тулбаре виджетов
