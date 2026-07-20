import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ru'),
  ];

  static const fallbackLocale = Locale('en');

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _ru => locale.languageCode == 'ru';

  String _s(String en, String ru) => _ru ? ru : en;

  // General
  String get appTitle => _s('Project Manager', 'Project Manager');
  String get settings => _s('Settings', 'Настройки');
  String get language => _s('Language', 'Язык');
  String get english => _s('English', 'English');
  String get russian => _s('Russian', 'Русский');
  String get cancel => _s('Cancel', 'Отмена');
  String get delete => _s('Delete', 'Удалить');
  String get save => _s('Save', 'Сохранить');
  String get close => _s('Close', 'Закрыть');
  String get browse => _s('Browse', 'Обзор');
  String get validate => _s('Validate', 'Проверить');
  String get refresh => _s('Refresh', 'Обновить');
  String get none => _s('None', 'Нет');
  String get notAvailable => _s('N/A', '—');
  String get empty => _s('empty', 'пусто');
  String get yes => _s('Yes', 'Да');
  String get no => _s('No', 'Нет');
  String get markdown => _s('Markdown', 'Markdown');

  // Toolbar
  String get addProject => _s('Add Project', 'Добавить проект');
  String get exportDocs => _s('Export Docs', 'Экспорт документации');
  String get docsExported =>
      _s('Documentation exported to project data folder.',
          'Документация экспортирована в папку данных проекта.');

  // Sidebar
  String get projects => _s('Projects', 'Проекты');
  String get projectFiles => _s('Project Files', 'Файлы проекта');
  String get refreshFileTree =>
      _s('Refresh file tree', 'Обновить дерево файлов');
  String get noProjectsYet => _s('No projects yet', 'Проектов пока нет');
  String get addProjectHint => _s(
        'Add a Flutter/Dart project to get started.',
        'Добавьте Flutter/Dart проект, чтобы начать.',
      );
  String get selectProjectForFiles => _s(
        'Select a project to browse its files.',
        'Выберите проект для просмотра файлов.',
      );
  String get noFilesFound => _s(
        'No files found in project directory.',
        'Файлы в каталоге проекта не найдены.',
      );

  // Workspace tabs
  String get tabOverview => _s('Overview', 'Обзор');
  String get tabDocumentation => _s('Documentation', 'Документация');
  String get tabDependencies => _s('Dependencies', 'Зависимости');
  String get tabWidgets => _s('Widgets', 'Виджеты');
  String get tabMedia => _s('Media', 'Медиа');
  String get tabGitlab => _s('Git / GitLab', 'Git / GitLab');
  String get tabBuilds => _s('Builds', 'Сборки');
  String get tabAnalysis => _s('Analysis', 'Анализ');
  String get tabAgent => _s('Agent', 'Агент');

  // Detail panel sections
  String get sectionDetails => _s('Details', 'Детали');
  String get sectionDocumentation => _s('Documentation', 'Документация');
  String get sectionTasks => _s('Tasks', 'Задачи');

  // Detail labels
  String get labelName => _s('Name', 'Название');
  String get labelStatus => _s('Status', 'Статус');
  String get labelPath => _s('Path', 'Путь');
  String get labelAdded => _s('Added', 'Добавлен');
  String get labelFlutter => _s('Flutter', 'Flutter');
  String get labelDart => _s('Dart', 'Dart');
  String get labelPlatforms => _s('Platforms', 'Платформы');
  String get labelDependencies => _s('Dependencies', 'Зависимости');
  String get labelWidgets => _s('Widgets', 'Виджеты');
  String get labelLanguage => _s('Language', 'Язык');
  String get labelLines => _s('Lines', 'Строк');
  String get labelSize => _s('Size', 'Размер');
  String get labelDescription => _s('Description', 'Описание');
  String get labelGoal => _s('Goal', 'Цель');
  String get labelNotes => _s('Notes', 'Заметки');
  String get structure => _s('STRUCTURE', 'СТРУКТУРА');
  String get fileSection => _s('FILE', 'ФАЙЛ');
  String get localSections => _s('LOCAL SECTIONS', 'ЛОКАЛЬНЫЕ РАЗДЕЛЫ');
  String get externalLinks => _s('EXTERNAL LINKS', 'ВНЕШНИЕ ССЫЛКИ');
  String get widgetsPending => _s('(pending analysis)', '(ожидает анализа)');

  // Project status
  String projectStatusLabel(String status) => switch (status) {
        'active' => _s('Active', 'Активный'),
        'paused' => _s('Paused', 'Приостановлен'),
        'archived' => _s('Archived', 'Архив'),
        'draft' => _s('Draft', 'Черновик'),
        _ => status,
      };

  // Status bar
  String projectsCount(int count) => _s(
        '$count project(s)',
        _ru ? _pluralProjects(count) : '$count project(s)',
      );

  String _pluralProjects(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count проект';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$count проекта';
    }
    return '$count проектов';
  }

  String sdkVersions(String flutter, String dart) =>
      'Flutter $flutter · Dart $dart';

  String get sdkNotAvailable =>
      _s('SDK not fully available', 'SDK недоступен полностью');

  // Empty state
  String get welcomeTitle =>
      _s('Welcome to Project Manager', 'Добро пожаловать в Project Manager');
  String get welcomeHint => _s(
        'Select a project from the left panel or click "Add Project" '
            'to register a Flutter/Dart project.',
        'Выберите проект на левой панели или нажмите «Добавить проект», '
            'чтобы зарегистрировать Flutter/Dart проект.',
      );

  // Add project dialog
  String get addFlutterProject =>
      _s('Add Flutter/Dart Project', 'Добавить Flutter/Dart проект');
  String get selectProjectFolder => _s(
        'Select Flutter/Dart Project',
        'Выберите Flutter/Dart проект',
      );
  String get projectPath => _s('Project Path *', 'Путь к проекту *');
  String get projectPathHint =>
      _s(r'C:\path\to\flutter_project', r'C:\path\to\flutter_project');
  String get projectName => _s('Project Name', 'Название проекта');
  String get projectNameHint =>
      _s('Auto-detected from pubspec.yaml', 'Из pubspec.yaml');
  String get projectDescription => _s('Description', 'Описание');
  String get projectGoal => _s('Project Goal', 'Цель проекта');
  String get validationPassed => _s('Validation passed', 'Проверка пройдена');
  String get validationFailed => _s('Validation failed', 'Проверка не пройдена');
  String platformsDetected(String platforms) =>
      _s('Platforms: $platforms', 'Платформы: $platforms');
  String dependenciesFound(int count) => _s(
        'Dependencies: $count found',
        'Зависимости: найдено $count',
      );
  String get addingProject => _s('Adding...', 'Добавление...');
  String get flutterSdk => _s('Flutter SDK', 'Flutter SDK');
  String get dartSdk => _s('Dart SDK', 'Dart SDK');
  String sdkDetected(String version) =>
      _s('$version detected', 'обнаружен $version');
  String get sdkNotFound => _s('not found', 'не найден');

  // Overview
  String get recentActivity => _s('Recent Activity', 'Недавняя активность');
  String get sdkIssue => _s('SDK Issue', 'Проблема SDK');

  // Documentation
  String get localDocumentation =>
      _s('Local Documentation', 'Локальная документация');
  String get localDocumentationHint => _s(
        'Documentation is stored locally and can be exported to files.',
        'Документация хранится локально и может быть экспортирована в файлы.',
      );
  String get sections => _s('SECTIONS', 'РАЗДЕЛЫ');
  String get docSectionPlaceholder => _s(
        'Section initialized. Content will appear here as Markdown '
            'when the project is updated or documentation is generated.',
        'Раздел инициализирован. Содержимое появится здесь в формате Markdown '
            'после обновления проекта или генерации документации.',
      );

  String fileDocSectionTitle(String key) => switch (key) {
        'overview' => _s('File Overview', 'Обзор файла'),
        'notes' => _s('Notes', 'Заметки'),
        'widgets' => _s('Widgets', 'Виджеты'),
        'analysis' => _s('Code Analysis', 'Анализ кода'),
        'changelog' => _s('Changelog', 'История изменений'),
        'dependencies' => _s('Dependencies', 'Зависимости'),
        _ => key,
      };

  String get fileDocumentationHeader =>
      _s('FILE DOCUMENTATION', 'ДОКУМЕНТАЦИЯ ФАЙЛА');

  String fileDocumentationHint(String fileName) => _s(
        'Local documentation for "$fileName". '
            'More file-related sections will be added here.',
        'Локальная документация для «$fileName». '
            'Здесь появятся дополнительные разделы, связанные с файлом.',
      );

  String get fileDocFutureHint => _s(
        'This section will be populated automatically as file analysis is implemented.',
        'Этот раздел будет заполняться автоматически после реализации анализа файлов.',
      );

  String docSectionTitle(String key) => switch (key) {
        'overview' => _s('Project Overview', 'Обзор проекта'),
        'changelog' => _s('Changelog', 'История изменений'),
        'dependencies' => _s('Dependencies', 'Зависимости'),
        'widgets' => _s('Widgets', 'Виджеты'),
        'changeNotes' => _s('Change Notes', 'Заметки об изменениях'),
        'codeAnalysis' => _s('Project Analysis', 'Анализ проекта'),
        _ => key,
      };

  // Dependencies view
  String get noDependencies =>
      _s('No dependencies found in pubspec.yaml.', 'Зависимости в pubspec.yaml не найдены.');
  String dependenciesCount(int count) => _s(
        '$count dependencies',
        _ru ? '$count зависимостей' : '$count dependencies',
      );
  String get colPackage => _s('Package', 'Пакет');
  String get colVersion => _s('Version', 'Версия');
  String get colSource => _s('Source', 'Источник');
  String get colChecked => _s('Checked', 'Проверено');
  String get colCurrent => _s('Current', 'Текущая');
  String get colLatest => _s('Latest', 'Новая');
  String get colDescription => _s('Description', 'Описание');
  String get devDependency => _s('dev', 'dev');
  String get loadingDependencies =>
      _s('Loading dependencies...', 'Загрузка зависимостей...');
  String get refreshDependencies =>
      _s('Refresh dependencies', 'Обновить зависимости');
  String get editPackageMetadata =>
      _s('Edit package info', 'Редактировать пакет');
  String get editPackageMetadataTitle =>
      _s('Package metadata', 'Метаданные пакета');
  String get editPackageMetadataHint => _s(
        'Changes apply to this package in all projects.',
        'Изменения применяются к этому пакету во всех проектах.',
      );
  String get packageDescription => _s('Description', 'Описание');
  String get packageNotes => _s('Notes', 'Заметки');
  String get packageUpdateRisks => _s('Update risks', 'Риски обновления');
  String get noDescriptionAvailable => _s(
        'No description available. Click edit to add one.',
        'Описание недоступно. Нажмите «Редактировать», чтобы добавить.',
      );
  String get openInExplorer => _s('Open in Explorer', 'Открыть в проводнике');
  String get openInVsCode => _s('Open in VS Code', 'Открыть в VS Code');
  String get openInVsCodeFailed => _s(
        'Could not launch VS Code. Make sure the code command is available in PATH.',
        'Не удалось открыть VS Code. Убедитесь, что команда code доступна в PATH.',
      );
  String get openInCursor => _s('Open in Cursor', 'Открыть в Cursor');
  String get openInCursorFailed => _s(
        'Could not launch Cursor. Make sure the cursor command is available in PATH.',
        'Не удалось открыть Cursor. Убедитесь, что команда cursor доступна в PATH.',
      );
  String get openOnPubDev => _s('Open on pub.dev', 'Открыть на pub.dev');
  String get openRepository => _s('Open repository', 'Открыть репозиторий');
  String versionArrow(String current, String latest) =>
      _s('$current → $latest', '$current → $latest');
  String get globalMetadataBadge =>
      _s('Global', 'Глобально');

  // File documentation
  String fileDocProjectPackage(String packageName) => _s(
        'Project package: $packageName',
        'Пакет проекта: $packageName',
      );
  String get fileDocProjectFiles =>
      _s('Project files', 'Файлы проекта');
  String get fileDocPackages => _s('Packages', 'Пакеты');
  String get fileDocDartSdk => _s('Dart SDK', 'Dart SDK');
  String get fileDocNoProjectFiles => _s(
        'No project file imports found.',
        'Импорты файлов проекта не найдены.',
      );
  String get fileDocNoPackages => _s(
        'No external package imports found.',
        'Внешние пакеты не найдены.',
      );
  String get fileDocNoSdkImports => _s(
        'No Dart SDK imports found.',
        'Импорты Dart SDK не найдены.',
      );
  String get fileDocStatusLinked => _s('linked', 'связан');
  String get fileDocStatusExternal => _s('external', 'внешний');
  String get fileDocStatusNotFound => _s('not found', 'не найден');
  String fileDocImportsSummary(int files, int packages, int sdk) {
    if (sdk == 0) {
      return _s(
        '$files files · $packages packages',
        '$files файлов · $packages пакетов',
      );
    }
    return _s(
      '$files files · $packages packages · $sdk sdk',
      '$files файлов · $packages пакетов · $sdk sdk',
    );
  }

  // Cursor CLI settings
  String get cursorCliSection => _s('Cursor CLI', 'Cursor CLI');
  String get cursorCliSectionHint => _s(
        'Connect Project Manager to Cursor Agent CLI for future automation workflows.',
        'Подключите Project Manager к Cursor Agent CLI для будущих сценариев автоматизации.',
      );
  String get cursorCliEnabled => _s('Enable Cursor CLI', 'Включить Cursor CLI');
  String get cursorCliCommand => _s('CLI command', 'Команда CLI');
  String get cursorCliCommandHint => _s('agent', 'agent');
  String get cursorCliApiKey => _s('API key', 'API-ключ');
  String get cursorCliApiKeyHint => _s(
        'Optional if CURSOR_API_KEY is set in environment',
        'Необязательно, если CURSOR_API_KEY задан в окружении',
      );
  String get cursorCliUseEnvApiKey => _s(
        'Use CURSOR_API_KEY from environment',
        'Использовать CURSOR_API_KEY из окружения',
      );
  String get cursorCliDefaultModel => _s('Default model', 'Модель по умолчанию');
  String get cursorCliCustomModel => _s('Custom model', 'Своя модель');
  String get cursorCliDefaultMode => _s('Default mode', 'Режим по умолчанию');
  String cursorCliModeLabel(String mode) => switch (mode) {
        'agent' => _s('Agent', 'Agent'),
        'plan' => _s('Plan', 'Plan'),
        'ask' => _s('Ask', 'Ask'),
        _ => mode,
      };
  String get cursorCliInstallTitle => _s('Installation', 'Установка');
  String get cursorCliInstallHint => _s(
        'Install Cursor CLI, then verify with the command below.',
        'Установите Cursor CLI, затем проверьте командой ниже.',
      );
  String get cursorCliVerifyCommand => _s('Verify', 'Проверка');
  String get cursorCliAuthCommand => _s('Authenticate', 'Авторизация');
  String get cursorCliTestConnection =>
      _s('Test connection', 'Проверить подключение');
  String get cursorCliOpenInstallDocs =>
      _s('Installation docs', 'Документация по установке');
  String get cursorCliOpenOverview => _s('CLI overview', 'Обзор CLI');
  String get cursorCliOpenAuthDocs =>
      _s('Authentication docs', 'Документация по авторизации');
  String get cursorCliOpenParametersDocs =>
      _s('CLI parameters', 'Параметры CLI');
  String get cursorCliConnectionOk => _s('Connected', 'Подключено');
  String get cursorCliConnectionFailed =>
      _s('Connection failed', 'Подключение не удалось');
  String cursorCliVersionDetected(String version) =>
      _s('Version: $version', 'Версия: $version');
  String cursorCliModelsFound(int count) => _s(
        '$count models available from CLI',
        'Доступно моделей из CLI: $count',
      );
  String get cursorCliAuthRequired => _s(
        'Run "agent login" or set CURSOR_API_KEY.',
        'Выполните «agent login» или задайте CURSOR_API_KEY.',
      );
  String get copy => _s('Copy', 'Копировать');
  String get copied => _s('Copied', 'Скопировано');
  String get statusBarCursorCliLabel => _s('Cursor CLI', 'Cursor CLI');
  String get statusBarCursorCliConnected =>
      _s('Connected', 'Подключен');
  String get statusBarCursorCliUnavailable =>
      _s('Unavailable', 'Нет доступа');
  String get statusBarCursorCliNoModel => _s('No model', 'Нет модели');
  String get statusBarCursorCliDisabled => _s('Disabled', 'Выключен');
  String get statusBarCursorCliChecking => _s('Checking...', 'Проверка...');
  String statusBarCursorCliConnectedWithModel(String model) => _s(
        'Connected · $model',
        'Подключен · $model',
      );
  String get statusBarContextSyncLabel =>
      _s('Context sync', 'Синхр. контекста');
  String get statusBarContextSyncDisabled => _s('Off', 'Выкл');
  String get statusBarContextSyncSyncing => _s('Syncing…', 'Синхронизация…');
  String get statusBarContextSyncOk => _s('OK', 'OK');
  String get statusBarContextSyncError => _s('Error', 'Ошибка');
  String get statusBarContextSyncIdle => _s('Ready', 'Готово');

  // Agent workspace rework
  String get agentSideProfile => _s('Profile', 'Профиль');
  String get agentSideMemory => _s('Memory', 'Память');
  String get agentSidePending => _s('Learning', 'Обучение');
  String get agentSideIndex => _s('Index', 'Индекс');
  String get agentSideAi => _s('.ai', '.ai');
  String get agentSideAdvanced => _s('Advanced', 'Дополнительно');
  String get agentReadAiOnly => _s('Read: .ai', 'Чтение: .ai');
  String get agentReadRepo => _s('Read: repo', 'Чтение: репо');
  String get agentWriteNone => _s('Write: none', 'Запись: нет');
  String get agentWriteAi => _s('Write: .ai', 'Запись: .ai');
  String get agentWriteProject => _s('Write: project', 'Запись: проект');
  String get agentIndexNow => _s('Index project', 'Индексировать проект');
  String get agentIndexSnapshotOnly =>
      _s('Refresh snapshot only', 'Только снимок структуры');
  String get agentIndexSemantic =>
      _s('Semantic index (Cursor)', 'Семантический индекс (Cursor)');
  String get agentIndexCancel => _s('Cancel indexing', 'Отменить индексацию');
  String get agentIndexContinue =>
      _s('Continue with answers', 'Продолжить с ответами');
  String get agentIndexOpenQuestions =>
      _s('Open questions', 'Открытые вопросы');
  String get agentIndexNoQuestions =>
      _s('No open questions.', 'Нет открытых вопросов.');
  String get agentIndexAnswer => _s('Answer', 'Ответить');
  String get agentIndexSkip => _s('Skip', 'Пропустить');
  String get agentIndexUnknown => _s('Unknown', 'Неизвестно');
  String get agentIndexNotesCount => _s('File notes', 'Заметки по файлам');
  String get agentIndexProgress => _s('Indexing progress', 'Прогресс индексации');
  String get agentIndexWhyNeeded => _s('Why needed', 'Зачем нужно');
  String get agentIndexAnswerHint =>
      _s('Your answer…', 'Ваш ответ…');
  String get agentIndexPreferQuestionsHint => _s(
        'Index asks when unsure — prefer answering over letting the agent invent.',
        'Индекс спрашивает при неясностях — лучше ответить, чем позволить агенту домысливать.',
      );
  String get agentIndexStale => _s('Index stale', 'Индекс устарел');
  String get agentIndexMissing => _s('No index yet', 'Индекса ещё нет');
  String agentIndexReady(String when) =>
      _s('Indexed: $when', 'Индексировано: $when');
  String agentIndexBatchProgress(int current, int total, String folder) => _s(
        'Batch $current/$total · $folder',
        'Пакет $current/$total · $folder',
      );
  String get agentIndexIncluded => _s('Included', 'Включено');
  String get agentIndexExcluded => _s('Excluded / truncated', 'Исключено / обрезано');
  String get uiScaleLabel => _s('UI scale', 'Масштаб интерфейса');
  String uiScaleValue(String value) =>
      _s('Scale: $value', 'Масштаб: $value');
  String get appLogsTitle => _s('Application logs', 'Логи приложения');
  String get appLogsEmpty => _s('No log entries yet.', 'Пока нет записей.');
  String get appLogsClear => _s('Clear logs', 'Очистить логи');
  String get appLogsCopy => _s('Copy logs', 'Копировать логи');
  String get appLogsFollow => _s('Follow latest', 'Следить за новыми');
  String get appLogsFilterSource => _s('Source…', 'Источник…');
  String get appLogsFilterLevel => _s('Level', 'Уровень');
  String get appLogsAllLevels => _s('All levels', 'Все уровни');
  String get appLogsOpen => _s('Logs', 'Логи');
  String get agentIndexLiveThoughts =>
      _s('Agent activity', 'Активность агента');
  String get agentIndexLiveEmpty => _s(
        'Waiting for Cursor agent output…',
        'Ждём вывод Cursor-агента…',
      );
  String agentPendingLearning(int count) =>
      _s('Learning ($count)', 'Обучение ($count)');
  String get agentPendingEmpty =>
      _s('No pending learning candidates.', 'Нет кандидатов на обучение.');
  String get agentConfirmLearning =>
      _s('Confirm selected', 'Подтвердить выбранное');
  String get agentDiscardLearning => _s('Discard', 'Отклонить');
  String get agentImproveProfile =>
      _s('Improve profile', 'Улучшить профиль');
  String get agentRetry => _s('Retry last', 'Повторить последний');
  String get agentExportTranscript =>
      _s('Export transcript', 'Экспорт диалога');
  String agentTranscriptExported(String path) =>
      _s('Transcript saved: $path', 'Диалог сохранён: $path');
  String get agentAttachPath => _s('Attach path', 'Прикрепить путь');
  String get agentAttachPathHint =>
      _s('Absolute file or folder path', 'Абсолютный путь к файлу или папке');
  String get agentAttachMissing =>
      _s('Path not found', 'Путь не найден');
  String get agentShowReasoning => _s('Show steps', 'Показать шаги');
  String get agentHideReasoning => _s('Hide steps', 'Скрыть шаги');
  String agentWorkspaceWelcome(String projectName) => _s(
        'Chat with the project agent for $projectName. Index the repo, manage .ai memory, and ask clarifying questions.',
        'Общайтесь с агентом проекта $projectName. Индексируйте репозиторий, управляйте памятью .ai и задавайте уточняющие вопросы.',
      );
  String get agentChipArchitecture =>
      _s('Explain architecture', 'Объясни архитектуру');
  String get agentChipMemory => _s('What is in memory?', 'Что в memory?');
  String get agentChipUpdateKnowledge =>
      _s('Update knowledge', 'Обнови knowledge');
  String get agentChipIndex => _s('Index the project', 'Проиндексируй проект');
  String get agentChipGaps =>
      _s('What are you missing?', 'Чего тебе не хватает?');
  String get analysisOpenAgent =>
      _s('Open Agent chat', 'Открыть чат Агента');
  String get analysisContextOnlyHint => _s(
        'Analysis focuses on project-context indexing. Full chat lives on the Agent tab.',
        'Анализ отвечает за индексацию project-context. Полный чат — на вкладке Агент.',
      );

  // Widgets
  String get widgetInventory => _s('Widget Inventory', 'Каталог виджетов');
  String get loadingWidgets =>
      _s('Scanning widgets...', 'Сканирование виджетов...');
  String get refreshWidgets =>
      _s('Refresh widgets', 'Обновить виджеты');
  String get widgetsSearchHint =>
      _s('Search widgets...', 'Поиск виджетов...');
  String get widgetsScopeProject => _s('Project', 'Проект');
  String get widgetsScopeFile => _s('File', 'Файл');
  String get widgetsSelectFile => _s('Select file', 'Выберите файл');
  String get noWidgetsFound =>
      _s('No widgets found.', 'Виджеты не найдены.');
  String get widgetsSelectPrompt => _s(
        'Select a widget to inspect details.',
        'Выберите виджет, чтобы посмотреть детали.',
      );
  String get widgetsFilterAll => _s('All', 'Все');
  String get widgetsFilterCustom => _s('Custom', 'Свои');
  String get widgetsFilterLibrary => _s('Library', 'Библиотека');
  String get widgetsLibraryOnly =>
      _s('Library widget', 'Библиотечный виджет');
  String widgetsSummary(int total, int custom, int usages) => _s(
        '$total widgets · $custom custom · $usages usages',
        '$total виджетов · $custom своих · $usages использований',
      );
  String widgetsCustomSummary(int count, int usages) => _s(
        '$count custom widgets · $usages usages',
        '$count своих виджетов · $usages использований',
      );

  // Media
  String get loadingMedia =>
      _s('Scanning assets folder...', 'Сканирование папки assets...');
  String get refreshMedia => _s('Refresh media', 'Обновить медиа');
  String get mediaSearchHint =>
      _s('Search media files...', 'Поиск медиафайлов...');
  String get mediaVisualOnly =>
      _s('Images only', 'Только изображения');
  String get mediaFilterAll => _s('All folders', 'Все папки');
  String get mediaAssetsFolderMissing => _s(
        'The assets folder was not found in this project.',
        'Папка assets не найдена в этом проекте.',
      );
  String get mediaNoFiles => _s(
        'No media files found in assets.',
        'Медиафайлы в assets не найдены.',
      );
  String get mediaNoMatches => _s(
        'No media files match the current filters.',
        'Нет медиафайлов по текущим фильтрам.',
      );
  String get mediaUndeclaredHint => _s(
        'Files with a warning are not declared in pubspec.yaml assets.',
        'Файлы с предупреждением не объявлены в assets pubspec.yaml.',
      );
  String get mediaNotDeclared => _s('Not in pubspec', 'Нет в pubspec');
  String get mediaOtherType => _s('File', 'Файл');
  String mediaSummary(int shown, int total, int undeclared) => _s(
        '$shown of $total media files · $undeclared not in pubspec',
        '$shown из $total медиафайлов · $undeclared не в pubspec',
      );
  String get mediaSelectPrompt => _s(
        'Select a media file to see AppAssets bindings and usages.',
        'Выберите медиафайл, чтобы увидеть AppAssets и использования.',
      );
  String get mediaAppAssetsBindings =>
      _s('AppAssets bindings', 'Привязки AppAssets');
  String get mediaUsages => _s('Usages in code', 'Использования в коде');
  String get mediaNoUsages =>
      _s('No usages found in project code.', 'Использования в коде не найдены.');
  String get mediaOpenFile => _s('Open file', 'Открыть файл');
  String get mediaPreloadListMember =>
      _s('Included in preload list', 'В списке предзагрузки');
  String get mediaTemplateBinding =>
      _s('Template path', 'Шаблон пути');
  String get mediaMethodBinding =>
      _s('Returned by method', 'Возвращается методом');
  String mediaUsageCount(int count) =>
      _s('$count usages', '$count исп.');
  String get mediaFontPreviewSample => _s(
        'The quick brown fox jumps 0123456789',
        'Съешь же ещё этих мягких французских булок 0123456789',
      );
  String get mediaFontUnsupportedFormat => _s(
        'Preview is available for TTF and OTF fonts only.',
        'Предпросмотр доступен только для шрифтов TTF и OTF.',
      );
  String failedToLoadFont(String error) => _s(
        error.isEmpty ? 'Failed to load font.' : 'Failed to load font: $error',
        error.isEmpty
            ? 'Не удалось загрузить шрифт.'
            : 'Не удалось загрузить шрифт: $error',
      );

  // Builds
  String get buildsLoading =>
      _s('Loading build configurations...', 'Загрузка конфигураций сборки...');
  String get refreshBuilds =>
      _s('Refresh builds', 'Обновить сборки');
  String get buildsSearchHint => _s(
        'Search build configurations...',
        'Поиск конфигураций сборки...',
      );
  String buildsSummary(int shown, int total) => _s(
        '$shown of $total build configurations',
        '$shown из $total конфигураций сборки',
      );
  String get buildsStageBuildOnly => _s(
        'Build stage only',
        'Только стадия build',
      );
  String get buildsNoVscodeConfigs => _s(
        'No .vscode/tasks.json found. Showing default Flutter build commands.',
        'Файл .vscode/tasks.json не найден. Показаны стандартные команды сборки Flutter.',
      );
  String get buildsUsingDefaults => _s(
        'Using default Flutter build commands. Add .vscode/tasks.json for project-specific builds.',
        'Используются стандартные команды сборки Flutter. Добавьте .vscode/tasks.json для своих сборок.',
      );
  String buildsUsingDefaultsForPlatforms(String platforms) => _s(
        'Default Flutter builds for: $platforms',
        'Стандартные сборки Flutter для: $platforms',
      );
  String get buildsUsingDefaultsNoPlatforms => _s(
        'No platforms detected. Add .vscode/tasks.json or platform folders to the project.',
        'Платформы не обнаружены. Добавьте .vscode/tasks.json или папки платформ в проект.',
      );
  String get buildsNoMatches => _s(
        'No build configurations match the current filters.',
        'Нет конфигураций сборки по текущим фильтрам.',
      );
  String get buildsSelectPrompt => _s(
        'Select a build configuration to inspect and run it.',
        'Выберите конфигурацию сборки для просмотра и запуска.',
      );
  String get buildsOpenTasksJson =>
      _s('tasks.json', 'tasks.json');
  String get buildsFilterAll => _s('All', 'Все');
  String get buildsFilterTasks => _s('Tasks', 'Задачи');
  String get buildsFilterDefaults => _s('Flutter defaults', 'Flutter по умолчанию');
  String get buildsRun => _s('Run', 'Запустить');
  String get buildsStop => _s('Stop', 'Остановить');
  String get buildsCopyCommand =>
      _s('Copy command', 'Копировать команду');
  String get buildsOpenSource =>
      _s('Open source file', 'Открыть исходный файл');
  String get buildsOutput => _s('Output', 'Вывод');
  String get buildsOutputEmpty =>
      _s('Build output will appear here.', 'Здесь появится вывод сборки.');
  String get buildsStopped => _s('Build stopped.', 'Сборка остановлена.');
  String get buildsCommandCopied =>
      _s('Command copied to clipboard.', 'Команда скопирована в буфер обмена.');
  String get buildsCannotRun => _s(
        'This build configuration cannot be run directly.',
        'Эту конфигурацию сборки нельзя запустить напрямую.',
      );
  String buildsFinished(int exitCode) => _s(
        'Finished with exit code $exitCode.',
        'Завершено с кодом $exitCode.',
      );
  String buildsFailed(Object error) => _s(
        'Build failed: $error',
        'Сборка не удалась: $error',
      );
  String buildsExitCode(int code) =>
      _s('Exit code: $code', 'Код выхода: $code');
  String buildsPreLaunchTask(String task) => _s(
        'preLaunch: $task',
        'preLaunch: $task',
      );
  String get buildsBackgroundTask =>
      _s('background', 'фоновая');
  String get buildsLabelSource => _s('Source', 'Источник');
  String get buildsLabelMode => _s('Mode', 'Режим');
  String get buildsLabelType => _s('Type', 'Тип');
  String get buildsLabelProgram => _s('Program', 'Program');
  String get buildsLabelDevice => _s('Device', 'Устройство');
  String get buildsLabelPreLaunch => _s('Pre-launch task', 'Задача preLaunch');
  String get buildsLabelTaskGroup => _s('Task group', 'Группа задач');
  String get buildsLabelChildren =>
      _s('Configurations', 'Конфигурации');
  String get buildsLabelCommand => _s('Command', 'Команда');
  String get buildsSourceTasks => _s('tasks.json', 'tasks.json');
  String get buildsSourceDefault =>
      _s('flutter default', 'flutter по умолчанию');
  String get buildsModeDebug => _s('debug', 'debug');
  String get buildsModeProfile => _s('profile', 'profile');
  String get buildsModeRelease => _s('release', 'release');
  String get buildsModeAttach => _s('attach', 'attach');
  String get buildsModeBuild => _s('build', 'build');
  String get buildsModeTest => _s('test', 'test');
  String get buildsModeCompound => _s('compound', 'compound');
  String get buildsModeCustom => _s('custom', 'custom');
  String get buildsHistory =>
      _s('Build history', 'История сборок');
  String get buildsHistoryEmpty => _s(
        'No archived builds yet. Successful builds are saved here automatically.',
        'Архивных сборок пока нет. Успешные сборки сохраняются здесь автоматически.',
      );
  String buildsHistoryFiles(int count) => _s(
        '$count file(s)',
        '$count файл(ов)',
      );
  String buildsArchived(String version) => _s(
        'Build archived (version $version).',
        'Сборка сохранена (версия $version).',
      );
  String get buildsArchiveFailed => _s(
        'Build succeeded but artifacts could not be archived.',
        'Сборка завершилась успешно, но артефакты не удалось сохранить.',
      );
  String get buildsOpenArchiveFolder =>
      _s('Open folder', 'Открыть папку');
  String get buildsDeleteArchive =>
      _s('Delete archive', 'Удалить архив');
  String get buildsDeleteArchiveConfirm => _s(
        'Delete this archived build?',
        'Удалить эту сохранённую сборку?',
      );
  String get buildsHistoryArtifacts =>
      _s('Artifacts', 'Артефакты');
  String get buildsHistorySelectArchive => _s(
        'Select an archived build to view its files.',
        'Выберите сохранённую сборку, чтобы посмотреть файлы.',
      );
  String get buildsHistoryFilterAll => _s('All builds', 'Все сборки');
  String get buildsHistoryFilterLocal => _s('Local', 'Локальные');
  String get buildsHistoryFilterGitLab => _s('GitLab CI', 'GitLab CI');
  String get buildsHistorySourceLocal => _s('Local', 'Локально');
  String get buildsHistorySourceGitLab => _s('GitLab CI', 'GitLab CI');
  String get buildsOpenInGitLab => _s('Open in GitLab', 'Открыть в GitLab');
  String get buildsDownloadArtifacts =>
      _s('Download artifacts', 'Скачать артефакты');
  String get buildsLoadingGitLabBuilds =>
      _s('Loading GitLab CI builds...', 'Загрузка сборок GitLab CI...');
  String buildsHistoryLoadingCountdown(int seconds) => _s(
        'Loading GitLab CI builds... ~$seconds sec left',
        'Загрузка сборок GitLab CI... ≈ $seconds с',
      );
  String buildsHistoryLoadingCountdownShort(int seconds) =>
      _s('~$seconds s', '≈ $seconds с');
  String buildsHistoryLoadingElapsed(int seconds) => _s(
        'Loading GitLab CI builds... $seconds s',
        'Загрузка сборок GitLab CI... $seconds с',
      );
  String buildsHistoryLoadingElapsedShort(int seconds) =>
      _s('$seconds s', '$seconds с');
  String get buildsHistoryLoadingAlmostDone =>
      _s('Almost done...', 'Почти готово...');
  String get buildsGitLabBuildsHint => _s(
        'Connect GitLab in Settings and use a GitLab remote to load CI builds.',
        'Подключите GitLab в настройках и используйте GitLab remote для загрузки CI-сборок.',
      );
  String buildsGitLabJobsFromYaml(int count) => _s(
        'Build jobs from .gitlab-ci.yml: $count',
        'Сборочные job из .gitlab-ci.yml: $count',
      );
  String get buildsFilterGitLabCi => _s('GitLab CI', 'GitLab CI');
  String get buildsSourceGitLabCi => _s('GitLab CI', 'GitLab CI');
  String get buildsRunInGitLab => _s('Run in GitLab', 'Запустить в GitLab');
  String buildsGitLabPipelineStarted(int id, String url) => _s(
        'GitLab pipeline #$id started${url.isEmpty ? '.' : ': $url'}',
        'Pipeline GitLab #$id запущен${url.isEmpty ? '.' : ': $url'}',
      );
  String buildsGitLabPipelineFailed(String error) => _s(
        'GitLab pipeline failed: $error',
        'Pipeline GitLab не запущен: $error',
      );
  String get buildsGitLabPipelineRef => _s('Branch', 'Ветка');
  String get buildsPageConfigurations =>
      _s('Configurations', 'Конфигурации');
  String get buildsPageHistory => _s('Build history', 'История сборок');
  String get buildsHistoryLoadMore => _s('Load more', 'Загрузить ещё');
  String get buildsHistoryLoadingMore =>
      _s('Loading more builds...', 'Загрузка сборок...');
  String buildsHistoryPageInfo(int page, int total) => _s(
        'Page $page of $total',
        'Страница $page из $total',
      );
  String get buildsHistoryPreviousPage =>
      _s('Previous page', 'Предыдущая страница');
  String get buildsHistoryNextPage => _s('Next page', 'Следующая страница');

  String get widgetsLabelType => _s('Type', 'Тип');
  String get widgetsLabelUsages => _s('Usages', 'Использования');
  String get widgetsLabelConst => _s('Const', 'Const');
  String get widgetsDefinition => _s('Definition', 'Определение');
  String get widgetsUsages => _s('Usages', 'Использования');
  String get widgetsStateClass => _s('State class', 'State-класс');
  String get widgetsConstructorParams =>
      _s('Constructor params', 'Параметры конструктора');
  String get widgetsNoUsages =>
      _s('No usages found.', 'Использования не найдены.');
  String widgetsUsedIn(String name) =>
      _s('Used in: $name', 'Использовано в: $name');
  String get widgetsPositionalArgs =>
      _s('Positional args', 'Позиционные аргументы');
  String get widgetsNamedArgs => _s('Named args', 'Именованные аргументы');
  String get widgetsParamPositional => _s('positional', 'позиционный');
  String get widgetsParamNamed => _s('named', 'именованный');
  String get widgetsParamRequired => _s('required', 'обязательный');
  String get widgetsParamOptional => _s('optional', 'необязательный');
  String get widgetsEnrichingWithCursor =>
      _s('Enriching with Cursor CLI...', 'Обогащение через Cursor CLI...');
  String get widgetsEnrichedByCursor =>
      _s('Enriched by Cursor', 'Обогащено Cursor');
  String get widgetsCursorCliLog => _s('Cursor CLI log', 'Лог Cursor CLI');
  String get widgetsCursorCliLogEmpty =>
      _s('No Cursor CLI activity yet.', 'Активности Cursor CLI пока нет.');
  String widgetsRecorded(int count) => _s(
        '$count widget(s) recorded',
        _ru ? 'Записано виджетов: $count' : '$count widget(s) recorded',
      );

  // Analysis
  String get codeAnalysis => _s('Project Analysis', 'Анализ проекта');
  String codeAnalysisHint(String projectName) => _s(
        'Ask questions about project "$projectName" using aggregated context '
            'and Cursor Agent CLI.',
        'Задавайте вопросы о проекте «$projectName» на основе собранного '
            'контекста и Cursor Agent CLI.',
      );
  String get analysisContextTitle =>
      _s('Project context file', 'Файл контекста проекта');
  String get analysisContextBuilding =>
      _s('Building project context…', 'Сборка контекста проекта…');
  String analysisContextReady(String date, String size) => _s(
        'Updated $date · $size · .ai/project-context.json',
        'Обновлён $date · $size · .ai/project-context.json',
      );
  String get analysisContextMissing => _s(
        'Context file not generated yet.',
        'Файл контекста ещё не создан.',
      );
  String get analysisRegenerateContext =>
      _s('Regenerate context', 'Пересобрать контекст');
  String get analysisAskPlaceholder =>
      _s('Ask about architecture, dependencies, widgets…', 'Спросите об архитектуре, зависимостях, виджетах…');
  String get analysisAskButton => _s('Ask', 'Спросить');
  String get analysisAsking =>
      _s('Analyzing…', 'Анализ…');
  String get analysisCursorDisabled => _s(
        'Enable Cursor CLI in settings to ask questions.',
        'Включите Cursor CLI в настройках, чтобы задавать вопросы.',
      );
  String analysisWelcome(String projectName) => _s(
        'A full project context file is built from metadata, dependencies, '
            'widgets, media, git, and builds. Ask Cursor Agent anything about '
            '«$projectName».',
        'Создаётся полный файл контекста из метаданных, зависимостей, '
            'виджетов, медиа, git и сборок. Задайте Cursor Agent любой вопрос '
            'о «$projectName».',
      );
  String get analysisSuggestionArchitecture =>
      _s('How is the app structured?', 'Как устроено приложение?');
  String get analysisSuggestionDependencies =>
      _s('Which packages need updates?', 'Какие пакеты нужно обновить?');
  String get analysisSuggestionWidgets =>
      _s('What are the main custom widgets?', 'Какие основные кастомные виджеты?');
  String get analysisSuggestionBuilds =>
      _s('How are release builds configured?', 'Как настроены release-сборки?');
  String get analysisReasoningTitle =>
      _s('Agent reasoning', 'Размышление агента');
  String get analysisReasoningEmpty =>
      _s('No steps yet…', 'Шагов пока нет…');
  String get analysisStreaming =>
      _s('Generating answer…', 'Формирование ответа…');

  // Agent tab
  String get agentSectionIdentity => _s('Identity', 'Личность');
  String get agentSectionSkills => _s('Skills', 'Навыки');
  String get agentSectionSelfAnalysis =>
      _s('Self-analysis', 'Самоанализ');
  String get agentSectionInstructions =>
      _s('Instructions', 'Инструкции');
  String get agentSectionMemory => _s('Memory', 'Память');
  String get agentSectionKnowledge =>
      _s('Knowledge base', 'База знаний');
  String get agentSectionAiFolder => _s('.ai folder', 'Папка .ai');
  String get agentSectionPrompt => _s('System prompt', 'Системный промпт');
  String get agentNameLabel => _s('Agent name', 'Имя агента');
  String get agentSkillsLabel => _s('Skills', 'Навыки');
  String get agentCapabilitiesLabel =>
      _s('Capabilities', 'Возможности');
  String get agentLimitationsLabel =>
      _s('Limitations', 'Ограничения');
  String get agentSelfAnalysisLabel =>
      _s('Self-analysis report', 'Отчёт самоанализа');
  String get agentRunSelfAnalysis =>
      _s('Analyze myself', 'Проанализировать себя');
  String get agentSelfAnalysisProgressTitle =>
      _s('Self-analysis log', 'Лог самоанализа');
  String get agentSelfAnalysisSucceeded =>
      _s('Self-analysis saved to profile.', 'Самоанализ сохранён в профиль.');
  String get agentSelfAnalysisFailed =>
      _s('Self-analysis failed. See log for details.', 'Самоанализ не удался. Смотрите лог.');
  String get agentSelfAnalysisRawOutputLabel =>
      _s('Raw agent output', 'Сырой ответ агента');
  String get agentCancelSelfAnalysis =>
      _s('Cancel', 'Отменить');
  String get agentSelfAnalysisCancelled =>
      _s('Self-analysis cancelled.', 'Самоанализ отменён.');
  String get agentSelfAnalysisTimedOut => _s(
        'Self-analysis stopped: 15 minute limit reached.',
        'Самоанализ остановлен: лимит 15 минут.',
      );
  String get agentSelfAnalysisIdleTimedOut => _s(
        'Self-analysis stopped: no CLI output for 5 minutes.',
        'Самоанализ остановлен: нет вывода от CLI 5 минут.',
      );
  String agentSelfAnalysisElapsed(int minutes, int seconds) => _s(
        'Running: ${minutes}m ${seconds.toString().padLeft(2, '0')}s',
        'Выполняется: ${minutes}м ${seconds.toString().padLeft(2, '0')}с',
      );
  String get agentAnalyzingSelf =>
      _s('Running self-analysis…', 'Выполняется самоанализ…');
  String get agentArchitectureSummaryLabel =>
      _s('Architecture summary', 'Сводка по архитектуре');
  String get agentWorkflowsSummaryLabel =>
      _s('Workflows summary', 'Сводка по процессам');
  String get agentKnowledgeInsightsLabel =>
      _s('Topic insights', 'Инсайты по темам');
  String get agentContextAutoRefreshHint => _s(
        'Context refreshes automatically before each question and learns after each answer.',
        'Контекст обновляется перед каждым вопросом и обучается после каждого ответа.',
      );
  String get agentAboutLabel => _s('About (self-description)', 'О себе');
  String get agentCharacterLabel => _s('Character & tone', 'Характер и тон');
  String get agentInstructionsLabel => _s(
        'Custom instructions (training)',
        'Доп. инструкции (обучение)',
      );
  String get agentInstructionsHint => _s(
        'Rules, preferences, project-specific knowledge for the agent…',
        'Правила, предпочтения, знания о проекте для агента…',
      );
  String get agentMemoryHint => _s(
        'Add a fact the agent should remember…',
        'Добавьте факт, который агент должен запомнить…',
      );
  String get agentMemoryEmpty => _s(
        'No memory entries yet. Add facts to teach the agent.',
        'Память пуста. Добавьте факты для обучения агента.',
      );
  String get agentAddMemory => _s('Add to memory', 'Добавить в память');
  String get agentSaved => _s('Agent profile saved.', 'Профиль агента сохранён.');
  String get agentMemoryAdded =>
      _s('Memory entry added.', 'Запись добавлена в память.');
  String get agentRefreshAiFolder =>
      _s('Refresh .ai listing', 'Обновить список .ai');
  String get agentAiFolderEmpty => _s(
        'The .ai folder is empty or missing.',
        'Папка .ai пуста или отсутствует.',
      );
  String get agentPromptPreviewHint => _s(
        'Preview of the prompt sent to Cursor Agent (without your question).',
        'Предпросмотр промпта для Cursor Agent (без вашего вопроса).',
      );
  String get agentColPath => _s('Path', 'Путь');
  String get agentColSize => _s('Size', 'Размер');
  String get agentColDescription => _s('Description', 'Описание');

  String get featureStructureAnalysis =>
      _s('Structure analysis', 'Анализ структуры');
  String get featureWidgetDiscovery =>
      _s('Widget discovery', 'Поиск виджетов');
  String get featureDependencyTracking =>
      _s('Dependency tracking', 'Отслеживание зависимостей');
  String get featureAgentWorkflow =>
      _s('Agent workflow', 'Agent workflow');

  // Tasks placeholder
  String get tasksTitle => _s('Tasks', 'Задачи');
  String get tasksHint => _s(
        'Task tracking will be available in a future release.',
        'Учёт задач будет доступен в будущих версиях.',
      );

  // File preview
  String get closeFile => _s('Close file', 'Закрыть файл');
  String get viewImage => _s('Image', 'Изображение');
  String get viewText => _s('Text', 'Текст');
  String binaryFilePreview(String size) => _s(
        'Binary file ($size). Preview is not available.',
        'Бинарный файл ($size). Просмотр недоступен.',
      );
  String fileTooLarge(String size, int maxKb) => _s(
        'File is too large ($size). Maximum preview size is $maxKb KB.',
        'Файл слишком большой ($size). Максимальный размер: $maxKb КБ.',
      );
  String get unknownError => _s('Unknown error.', 'Неизвестная ошибка.');
  String get fileSearchHint => _s('Find in file…', 'Поиск в файле…');
  String get fileSearchNoMatches => _s('No matches', 'Нет совпадений');
  String fileSearchMatchCount(int current, int total) => _s(
        '$current of $total',
        '$current из $total',
      );
  String get fileSearchPrevious => _s('Previous match', 'Предыдущее совпадение');
  String get fileSearchNext => _s('Next match', 'Следующее совпадение');
  String get fileCopyAll => _s('Copy all', 'Копировать всё');
  String get fileCopiedToClipboard =>
      _s('Copied to clipboard', 'Скопировано в буфер обмена');

  // Git / GitLab
  String get gitSectionTitle => _s('Repository changes', 'Изменения репозитория');
  String get refreshGitStatus => _s('Refresh git status', 'Обновить статус git');
  String get loadingGitStatus =>
      _s('Checking repository...', 'Проверка репозитория...');
  String get gitNotRepository => _s(
        'This folder is not a Git repository.',
        'Эта папка не является Git-репозиторием.',
      );
  String get gitWorkingTreeClean => _s(
        'Working tree clean — no local changes.',
        'Рабочая копия чистая — локальных изменений нет.',
      );
  String get gitChangesCount => _s('Changes', 'Изменения');
  String gitChangesSummary(int total, int staged, int unstaged, int untracked) =>
      _s(
        '$total changed · $staged staged · $unstaged unstaged · $untracked untracked',
        '$total изменений · $staged в индексе · $unstaged не в индексе · $untracked неотслеж.',
      );
  String get gitBranch => _s('Branch', 'Ветка');
  String get gitUpstream => _s('Upstream', 'Upstream');
  String get gitRemote => _s('Remote', 'Remote');
  String get gitAheadBehind => _s('Ahead / Behind', 'Впереди / Позади');
  String gitAheadBehindValue(int ahead, int behind) =>
      _s('↑$ahead · ↓$behind', '↑$ahead · ↓$behind');
  String get gitFilterAll => _s('All', 'Все');
  String get gitFilterStaged => _s('Staged', 'В индексе');
  String get gitFilterUnstaged => _s('Unstaged', 'Не в индексе');
  String get gitFilterUntracked => _s('Untracked', 'Неотслеж.');
  String get gitOpenInGitLab => _s('Open in GitLab', 'Открыть в GitLab');
  String get gitFileHistory => _s('File history', 'История файла');
  String gitLineHistory(int line) =>
      _s('Line $line history', 'История строки $line');
  String get gitHistoryEmpty =>
      _s('No commits found.', 'Коммиты не найдены.');
  String get gitOpenFileHistoryInGitLab =>
      _s('Open file history in GitLab', 'Открыть историю файла в GitLab');
  String gitOpenLineInGitLab(int line) => _s(
        'Open line $line in GitLab',
        'Открыть строку $line в GitLab',
      );
  String get gitViewHistory => _s('History', 'История');
  String get gitProjectGraph => _s('Project graph', 'Граф проекта');
  String get gitFileGraph => _s('File graph', 'Граф файла');
  String get gitGraphEmpty =>
      _s('No commits found for graph.', 'Коммиты для графа не найдены.');
  String get gitOpenProjectGraphInGitLab => _s(
        'Open repository graph in GitLab',
        'Открыть граф репозитория в GitLab',
      );
  String get gitOpenFileGraphInGitLab => _s(
        'Open file graph in GitLab',
        'Открыть граф файла в GitLab',
      );
  String get gitViewGraph => _s('Graph', 'Граф');
  String get gitGraphViewLanes => _s('Lanes', 'Линии');
  String get gitGraphViewTree => _s('Tree', 'Дерево');
  String gitTreeTipsCount(int count) =>
      _s('$count branch tips', '$count кончиков веток');
  String gitTreeSummary(int tips, int rows) =>
      _s('$tips tips · $rows commits', '$tips веток · $rows коммитов');
  String get gitTreeExpandAll => _s('Expand all', 'Раскрыть все');
  String get gitTreeCollapseAll => _s('Collapse all', 'Свернуть все');
  String get gitTreeExpand => _s('Expand parents', 'Раскрыть родителей');
  String get gitTreeCollapse => _s('Collapse parents', 'Свернуть родителей');
  String get gitConfigureGitLab => _s(
        'Configure GitLab in Settings to verify API access.',
        'Настройте GitLab в параметрах для проверки API.',
      );
  String gitStatusLabel(String status) {
    return switch (status) {
      'untracked' => _s('Untracked', 'Неотслеж.'),
      'modified' => _s('Modified', 'Изменён'),
      'staged' => _s('Staged', 'В индексе'),
      'stagedModified' => _s('Staged + modified', 'Индекс + изменения'),
      'added' => _s('Added', 'Добавлен'),
      'deleted' => _s('Deleted', 'Удалён'),
      'renamed' => _s('Renamed', 'Переименован'),
      'copied' => _s('Copied', 'Скопирован'),
      'conflicted' => _s('Conflicted', 'Конфликт'),
      'ignored' => _s('Ignored', 'Игнорируется'),
      _ => status,
    };
  }

  String get gitlabSection => _s('GitLab', 'GitLab');
  String get gitlabSectionHint => _s(
        'Connect to GitLab API for authentication checks and project links.',
        'Подключение к GitLab API для проверки доступа и ссылок на проект.',
      );
  String get gitlabEnabled => _s('Enable GitLab integration', 'Включить GitLab');
  String get gitlabBaseUrl => _s('GitLab URL', 'URL GitLab');
  String get gitlabToken => _s('Personal access token', 'Personal access token');
  String get gitlabUseEnvToken => _s(
        'Use GITLAB_TOKEN from environment',
        'Использовать GITLAB_TOKEN из окружения',
      );
  String get gitlabTestConnection => _s('Test connection', 'Проверить подключение');
  String get gitlabOpenDocs => _s('Token docs', 'Документация по токену');
  String get gitlabConnectionOk => _s('Connected', 'Подключено');
  String get gitlabConnectionFailed =>
      _s('Connection failed', 'Подключение не удалось');
  String gitlabConnectedAs(String username) =>
      _s('Connected as $username', 'Подключено как $username');

  // Context sync
  String get contextSyncSection =>
      _s('Context sync', 'Синхронизация контекста');
  String get contextSyncSectionHint => _s(
        'Shared GitHub repository for syncing each project’s `.ai` folder across devices.',
        'Общий GitHub-репозиторий для синхронизации папки `.ai` проектов между устройствами.',
      );
  String get contextSyncEnabled =>
      _s('Enable context sync', 'Включить синхронизацию контекста');
  String get contextSyncRepoUrl =>
      _s('Repository for saving', 'Репозиторий для сохранения');
  String get contextSyncIntervalMinutes =>
      _s('Sync interval (minutes)', 'Интервал синхронизации (минуты)');
  String get contextSyncTestRepo =>
      _s('Test repository access', 'Проверить доступ к репозиторию');
  String get contextSyncRepoOk =>
      _s('Repository is reachable', 'Репозиторий доступен');
  String get contextSyncRepoFailed =>
      _s('Repository check failed', 'Проверка репозитория не удалась');
  String get contextSyncProjectSection =>
      _s('Context ID & sync', 'ID контекста и синхронизация');
  String get contextSyncProjectHint => _s(
        'This ID is the folder name in the shared repo. Set the same ID on another project to share `.ai` context.',
        'Этот ID — имя папки в общем репозитории. Укажите тот же ID в другом проекте, чтобы делить контекст `.ai`.',
      );
  String get contextSyncProjectId => _s('ID', 'ID');
  String get contextSyncProjectIdHint =>
      _s('Any ID without path separators', 'Любой ID без разделителей пути');
  String get contextSyncCopyId => _s('Copy ID', 'Копировать ID');
  String get contextSyncIdCopied => _s('ID copied', 'ID скопирован');
  String get contextSyncEditId => _s('Edit ID', 'Изменить ID');
  String get contextSyncGenerateId =>
      _s('Generate new ID', 'Сгенерировать новый ID');
  String get contextSyncNow => _s('Sync now', 'Синхронизировать сейчас');
  String get contextSyncInvalidId => _s(
        'Invalid ID. Do not use / or \\.',
        'Некорректный ID. Нельзя использовать / или \\.',
      );
  String get contextSyncDisabled => _s(
        'Context sync is disabled in app settings',
        'Синхронизация контекста отключена в настройках приложения',
      );
  String get contextSyncIdle => _s('Not synced yet', 'Ещё не синхронизировано');
  String get contextSyncInProgress =>
      _s('Syncing…', 'Синхронизация…');
  String get contextSyncFailed =>
      _s('Sync failed', 'Синхронизация не удалась');
  String contextSyncLastAt(String timestamp) =>
      _s('Last sync: $timestamp', 'Последняя синхронизация: $timestamp');

  String get failedToLoadFile =>
      _s('Failed to load file.', 'Не удалось загрузить файл.');
  String failedToLoadImage(Object error) => _s(
        'Failed to load image: $error',
        'Не удалось загрузить изображение: $error',
      );

  // File types (details panel)
  String get fileTypeImage => _s('Image', 'Изображение');
  String get fileTypeSvg => _s('SVG', 'SVG');
  String get plainText => _s('Plain Text', 'Обычный текст');

  String languageDisplayName(String? languageId) {
    if (languageId == null) return plainText;
    return switch (languageId) {
      'dart' => 'Dart',
      'yaml' => 'YAML',
      'json' => 'JSON',
      'xml' => _s('XML / HTML', 'XML / HTML'),
      'css' => 'CSS',
      'scss' => 'SCSS',
      'javascript' => 'JavaScript',
      'typescript' => 'TypeScript',
      'kotlin' => 'Kotlin',
      'java' => 'Java',
      'swift' => 'Swift',
      'gradle' => 'Gradle',
      'groovy' => 'Groovy',
      'bash' => _s('Shell', 'Shell'),
      'cmake' => 'CMake',
      'markdown' => 'Markdown',
      'sql' => 'SQL',
      'protobuf' => _s('Protocol Buffers', 'Protocol Buffers'),
      'properties' => _s('Properties', 'Properties'),
      'ini' => _s('INI / TOML', 'INI / TOML'),
      'c' => 'C',
      'cpp' => 'C++',
      'rust' => 'Rust',
      'go' => 'Go',
      'python' => 'Python',
      'ruby' => 'Ruby',
      _ => languageId,
    };
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
