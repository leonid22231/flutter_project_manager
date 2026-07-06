# Flutter Project Manager

Desktop-приложение на Flutter для управления несколькими Flutter-проектами из одного окна: обзор структуры, документация, зависимости, медиа, Git/GitLab и сборки.

![Flutter](https://img.shields.io/badge/Flutter-3.44-blue)
![Dart](https://img.shields.io/badge/Dart-3.12-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

## Возможности

### Проекты и IDE-интерфейс

- Добавление и хранение нескольких Flutter-проектов
- Дерево файлов с быстрым открытием исходников
- Вкладки рабочей области с изменяемыми панелями
- Подсветка синтаксиса Dart, YAML, JSON, Markdown и других форматов
- Русский и английский интерфейс

### Обзор проекта

- Версии Flutter и Dart
- Обнаружение платформ (Android, iOS, Web, Windows, Linux, macOS)
- Проверка структуры каталогов (`lib/`, `android/`, `ios/` и т.д.)

### Документация

- Просмотр и редактирование Markdown-документации проекта
- Экспорт документации

### Зависимости

- Анализ `pubspec.yaml` и `pubspec.lock`
- Сравнение текущих версий с pub.dev
- Поддержка источников: pub, git, path, sdk
- Глобальные заметки по пакетам (описание, риски обновления) — общие для всех проектов

### Виджеты

- Поиск и просмотр виджетов в `lib/`
- Анализ импортов и связей между компонентами

### Медиа

- Обзор изображений и других медиафайлов в проекте
- Превью и навигация по ассетам

### Git / GitLab

- Статус репозитория: ветка, изменения, ahead/behind
- Поддержка self-hosted GitLab (в т.ч. `gitlab.evosoft.xyz`)
- Проверка подключения по Personal Access Token
- Граф коммитов и список изменений

### Сборки

- Запуск задач из `.vscode/tasks.json` с выводом в консоль
- Подстановка `${workspaceFolder}` и других VS Code-переменных
- Стандартные Flutter-сборки по платформам проекта
- Локальный архив успешных сборок и история версий
- GitLab CI: список успешных job'ов, история артефактов, запуск pipeline
- Определение версии из имён файлов артефактов (например `25.0.0-1782982194.apk`)

## Скриншот

Интерфейс в стиле IDE: дерево проекта слева, вкладки по центру, панель деталей справа.

## Требования

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
- Dart 3.12+
- Windows (основная целевая платформа; Linux/macOS — при наличии настроенного Flutter)

## Установка и запуск

```bash
git clone https://github.com/leonid22231/flutter_project_manager.git
cd flutter_project_manager
flutter pub get
flutter run -d windows
```

Сборка release:

```bash
flutter build windows
```

## Настройки

Откройте **Settings** в верхней панели:

| Раздел | Описание |
|--------|----------|
| **GitLab** | URL инстанса, Personal Access Token, проверка подключения |
| **Cursor CLI** | Опциональная интеграция с Agent CLI для автоматизации |

Токен GitLab можно задать в настройках или через переменную окружения `GITLAB_TOKEN` / `GITLAB_PRIVATE_TOKEN`.

## Структура репозитория

```
lib/
  core/          # тема, утилиты
  l10n/          # локализация
  models/        # модели данных
  services/      # Git, GitLab, сборки, зависимости, медиа
  state/         # состояние приложения (Provider)
  ui/            # shell, views, dialogs, widgets
test/            # unit-тесты
```

## Тесты

```bash
flutter test
```

## Лицензия

Проект распространяется как есть, без явной лицензии. Уточняйте условия использования у автора репозитория.
