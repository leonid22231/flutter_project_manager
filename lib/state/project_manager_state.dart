import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/core/utils/file_type_utils.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/core/utils/syntax_language.dart';
import 'package:project_manager/models/change_record.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/file_preview_focus.dart';
import 'package:project_manager/models/git_commit_entry.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_productivity.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/project_file_node.dart';
import 'package:project_manager/models/project_status.dart';
import 'package:project_manager/models/validation_result.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/app_release_update.dart';
import 'package:project_manager/services/context_sync_service.dart';
import 'package:project_manager/services/workstation_settings_sync.dart';
import 'package:project_manager/app_version.dart';
import 'package:project_manager/services/cursor_cli_flight.dart';
import 'package:project_manager/services/dependency_resolver_service.dart';
import 'package:project_manager/services/documentation_service.dart';
import 'package:project_manager/services/file_documentation_service.dart';
import 'package:project_manager/services/git_service.dart';
import 'package:project_manager/services/global_package_metadata_service.dart';
import 'package:project_manager/services/project_files_service.dart';
import 'package:project_manager/services/project_storage_service.dart';
import 'package:project_manager/services/project_validator_service.dart';
import 'package:project_manager/services/settings_service.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/analysis/widget_analysis_coordinator.dart';
import 'package:uuid/uuid.dart';

enum WorkspaceTab {
  overview,
  documentation,
  dependencies,
  widgets,
  media,
  gitlab,
  builds,
  analysis,
  agent,
}

enum DetailPanelSection {
  details,
  documentation,
  tasks,
}
class ProjectManagerState extends ChangeNotifier {
  ProjectManagerState({
    ProjectStorageService? storage,
    ProjectValidatorService? validator,
    DocumentationService? documentation,
    ProjectFilesService? filesService,
    FileDocumentationService? fileDocumentation,
    DependencyResolverService? dependencyResolver,
    GlobalPackageMetadataService? globalPackageMetadata,
    WidgetAnalysisCoordinator? widgetAnalysisCoordinator,
    GitService? gitService,
    SettingsService? settingsService,
    ContextSyncService? contextSyncService,
  })  : _storage = storage ?? ProjectStorageService(),
        _validator = validator ?? ProjectValidatorService(),
        _documentation = documentation ?? DocumentationService(),
        _filesService = filesService ?? ProjectFilesService(),
        _fileDocumentation = fileDocumentation ?? FileDocumentationService(),
        _dependencyResolver = dependencyResolver ?? DependencyResolverService(),
        _globalMetadataService =
            globalPackageMetadata ?? GlobalPackageMetadataService(),
        _widgetAnalysisCoordinator =
            widgetAnalysisCoordinator ?? WidgetAnalysisCoordinator(),
        _gitService = gitService ?? GitService(),
        _settingsService = settingsService ?? SettingsService(),
        _contextSyncService = contextSyncService ?? ContextSyncService();

  final ProjectStorageService _storage;
  final ProjectValidatorService _validator;
  final DocumentationService _documentation;
  final ProjectFilesService _filesService;
  final FileDocumentationService _fileDocumentation;
  final DependencyResolverService _dependencyResolver;
  final GlobalPackageMetadataService _globalMetadataService;
  final WidgetAnalysisCoordinator _widgetAnalysisCoordinator;
  final GitService _gitService;
  final SettingsService _settingsService;
  final ContextSyncService _contextSyncService;
  static const _uuid = Uuid();

  List<Project> _projects = [];
  Project? _selectedProject;
  List<ProjectFileNode> _fileTree = [];
  Set<String> _expandedDirectoryPaths = {};
  final List<String> _openFilePaths = [];
  final Map<String, OpenedFile> _openFiles = {};
  String? _activeFilePath;
  FilePreviewFocus? _filePreviewFocus;
  int _filePreviewFocusToken = 0;
  bool _isOpeningFile = false;
  WorkspaceTab _activeTab = WorkspaceTab.overview;
  DetailPanelSection _detailSection = DetailPanelSection.details;
  bool _isLoading = true;
  bool _isLoadingFiles = false;
  bool _isLoadingDependencies = false;
  bool _isLoadingWidgets = false;
  bool _isEnrichingWidgetsWithCursor = false;
  bool _widgetsEnrichedByCursor = false;
  bool _isLoadingGit = false;
  bool _isAddingProject = false;
  String? _lastError;
  Map<String, GlobalPackageMetadata> _globalPackageMetadata = {};
  GitRepositoryStatus? _gitRepositoryStatus;
  ContextSyncStatus _contextSyncStatus = ContextSyncStatus.idle;
  final Map<String, ContextSyncStatus> _statusByContext = {};
  StreamSubscription<FileSystemEvent>? _aiWatchSub;
  Timer? _contextSyncDebounce;
  Timer? _contextSyncInterval;
  Timer? _appUpdateTimer;
  var _aiWatchSuppressCount = 0;
  final Map<String, DateTime> _lastSuccessfulSyncAt = {};
  /// Projects that already received one auto Cursor sync this session.
  /// Only `project-selected` and `ai-watch` set this. `startup` and `interval` do not.
  final Set<String> _autoCursorSyncDone = {};
  /// Bumped on project switch and when semantic indexing starts.
  /// Selection-armed sync (`project-selected`, `ai-watch`, manual) stops when it changes.
  var _syncRunGeneration = 0;
  /// Bumped only when semantic indexing starts, so a project switch does not
  /// cancel `startup` / `interval` sync of other projects.
  var _syncAbortGeneration = 0;
  var _contextSyncQueueRunning = false;
  Future<void>? _contextSyncQueue;
  Future<void> _syncTail = Future<void>.value();
  var _semanticIndexPauseDepth = 0;
  /// Set after a sync error. Startup, interval, and folder watch stay idle
  /// until the user presses sync.
  var _autoSyncPausedAfterError = false;

  static const _autoSyncCooldown = Duration(minutes: 5);
  static const _projectSelectDebounce = Duration(seconds: 3);
  static const _aiWatchDebounce = Duration(seconds: 20);
  static const _postSyncSuppress = Duration(seconds: 5);
  static const _networkRetryDelays = <Duration>[
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const _networkAttemptsPerPass = 3;

  /// Replaces the post-sync watch suppress wait in tests.
  @visibleForTesting
  Duration debugPostSyncSuppress = _postSyncSuppress;

  /// Replaces network-backoff sleeps in tests. Production waits [duration].
  @visibleForTesting
  Future<void> Function(Duration duration)? debugNetworkDelay;

  List<Project> get projects => List.unmodifiable(_projects);
  Project? get selectedProject => _selectedProject;
  List<ProjectFileNode> get fileTree => List.unmodifiable(_fileTree);
  Set<String> get expandedDirectoryPaths => Set.unmodifiable(_expandedDirectoryPaths);
  List<String> get openFilePaths => List.unmodifiable(_openFilePaths);
  String? get activeFilePath => _activeFilePath;
  OpenedFile? get activeOpenedFile =>
      _activeFilePath != null ? _openFiles[_activeFilePath] : null;
  FilePreviewFocus? get filePreviewFocus => _filePreviewFocus;
  int get filePreviewFocusToken => _filePreviewFocusToken;
  bool get isOpeningFile => _isOpeningFile;
  bool isFileOpen(String path) => _openFiles.containsKey(path);
  WorkspaceTab get activeTab => _activeTab;
  DetailPanelSection get detailSection => _detailSection;
  bool get isLoading => _isLoading;
  bool get isLoadingFiles => _isLoadingFiles;
  bool get isLoadingDependencies => _isLoadingDependencies;
  bool get isLoadingWidgets => _isLoadingWidgets;
  bool get isEnrichingWidgetsWithCursor => _isEnrichingWidgetsWithCursor;
  bool get widgetsEnrichedByCursor => _widgetsEnrichedByCursor;
  bool get isLoadingGit => _isLoadingGit;
  bool get isAddingProject => _isAddingProject;
  String? get lastError => _lastError;
  GitRepositoryStatus? get gitRepositoryStatus => _gitRepositoryStatus;
  ContextSyncStatus get contextSyncStatus => _contextSyncStatus;

  /// Status of one project. The queue's current project does not overwrite it.
  ContextSyncStatus statusForContext(String contextId) =>
      _statusByContext[contextId] ?? ContextSyncStatus.idle;

  void _rememberSyncStatus(ContextSyncStatus status) {
    _contextSyncStatus = status;
    final id = status.contextId;
    if (id != null && id.isNotEmpty) {
      _statusByContext[id] = status;
    }
    notifyListeners();
  }

  /// While semantic indexing runs, auto context-sync must not rewrite `.ai`.
  bool get isSemanticIndexPaused => _semanticIndexPauseDepth > 0;

  void beginSemanticIndexPause() {
    _semanticIndexPauseDepth++;
    // Abort any in-flight sync before it can replaceTree over index/*.
    if (_semanticIndexPauseDepth == 1) {
      _syncRunGeneration++;
      _syncAbortGeneration++;
    }
  }

  void endSemanticIndexPause() {
    if (_semanticIndexPauseDepth > 0) _semanticIndexPauseDepth--;
  }
  Map<String, GlobalPackageMetadata> get globalPackageMetadata =>
      Map.unmodifiable(_globalPackageMetadata);

  GlobalPackageMetadata? globalMetadataFor(String packageName) =>
      _globalPackageMetadata[packageName];

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _globalPackageMetadata = await _globalMetadataService.loadAll();
      _projects = await _storage.loadProjects();
      if (_projects.isNotEmpty && _selectedProject == null) {
        _selectedProject = _projects.first;
        await _openSelectedProject();
      }
      unawaited(_runContextSyncAll(reason: 'startup'));
      _armAppUpdateChecks();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectProject(Project? project) {
    if (project != null && project.id == _selectedProject?.id) {
      return;
    }

    _syncRunGeneration++;
    CursorCliFlight.instance.onProjectSwitched(project?.id);
    _selectedProject = project;
    _clearOpenFiles();
    _activeTab = WorkspaceTab.overview;
    notifyListeners();

    if (project != null) {
      unawaited(_openSelectedProject());
    } else {
      _fileTree = [];
      _expandedDirectoryPaths = {};
      _gitRepositoryStatus = null;
      _stopContextSyncWatchers();
      _contextSyncStatus = ContextSyncStatus.idle;
    }
  }

  void _clearOpenFiles() {
    _openFilePaths.clear();
    _openFiles.clear();
    _activeFilePath = null;
    _filePreviewFocus = null;
    _filePreviewFocusToken = 0;
  }

  void _setFilePreviewFocus(int? line) {
    if (line == null || line <= 0) {
      _filePreviewFocus = null;
      return;
    }
    _filePreviewFocus = FilePreviewFocus(line: line);
    _filePreviewFocusToken++;
  }

  Future<void> openFile(String filePath, {int? line}) async {
    _activeFilePath = filePath;
    _detailSection = DetailPanelSection.details;
    _setFilePreviewFocus(line);

    if (_openFiles.containsKey(filePath)) {
      if (!_openFilePaths.contains(filePath)) {
        _openFilePaths.add(filePath);
      }
      notifyListeners();
      return;
    }

    _isOpeningFile = true;
    notifyListeners();

    try {
      final project = _selectedProject;
      if (project == null) return;

      final preview = await _filesService.readFilePreview(filePath);
      final fileName = p.basename(filePath);
      final relativePath = _filesService.relativePath(project.path, filePath);
      final lineCount = switch (preview.kind) {
        FilePreviewKind.text || FilePreviewKind.svg =>
          preview.content?.split('\n').length ?? 0,
        _ => 0,
      };

      final languageId = isImageFile(fileName)
          ? null
          : syntaxLanguageForFile(fileName);

      final docResult = await _fileDocumentation.initializeForFile(
        projectId: project.id,
        relativePath: relativePath,
        fileName: fileName,
        language: languageId,
        lineCount: lineCount,
        sizeBytes: preview.sizeBytes,
        projectRoot: project.path,
        absoluteFilePath: filePath,
        fileContent: preview.kind == FilePreviewKind.text ||
                preview.kind == FilePreviewKind.svg
            ? preview.content
            : null,
      );

      _openFiles[filePath] = OpenedFile(
        path: filePath,
        fileName: fileName,
        relativePath: relativePath,
        preview: preview,
        lineCount: lineCount,
        languageId: languageId,
        documentationSections: docResult.sections,
        dartImportAnalysis: docResult.dartImportAnalysis,
      );
      if (!_openFilePaths.contains(filePath)) {
        _openFilePaths.add(filePath);
      }
    } finally {
      _isOpeningFile = false;
      notifyListeners();
    }
  }

  void setActiveFile(String filePath) {
    if (!_openFiles.containsKey(filePath)) return;
    _activeFilePath = filePath;
    _detailSection = DetailPanelSection.details;
    notifyListeners();
  }

  void closeFile(String filePath) {
    _openFiles.remove(filePath);
    _openFilePaths.remove(filePath);

    if (_activeFilePath == filePath) {
      _activeFilePath =
          _openFilePaths.isNotEmpty ? _openFilePaths.last : null;
    }
    notifyListeners();
  }

  void closeActiveFile() {
    final path = _activeFilePath;
    if (path != null) closeFile(path);
  }

  void showWorkspaceTab(WorkspaceTab tab) {
    _activeFilePath = null;
    _activeTab = tab;
    notifyListeners();
  }
  void toggleDirectory(String directoryPath) {
    if (_expandedDirectoryPaths.contains(directoryPath)) {
      _expandedDirectoryPaths.remove(directoryPath);
    } else {
      _expandedDirectoryPaths.add(directoryPath);
    }
    notifyListeners();
  }

  Future<void> reloadProjectFiles() async {
    final project = _selectedProject;
    if (project == null) return;
    await _loadProjectFiles(project.path);
  }

  Future<void> _loadProjectFiles(String projectPath) async {
    _isLoadingFiles = true;
    notifyListeners();

    try {
      _fileTree = await _filesService.loadFileTree(projectPath);
      _expandedDirectoryPaths = _defaultExpandedPaths(projectPath, _fileTree);
    } finally {
      _isLoadingFiles = false;
      notifyListeners();
    }
  }

  Set<String> _defaultExpandedPaths(
    String projectPath,
    List<ProjectFileNode> nodes,
  ) {
    final expanded = <String>{};
    const defaultOpen = {'lib', 'test', 'assets'};

    for (final node in nodes) {
      if (node.isDirectory && defaultOpen.contains(node.name)) {
        expanded.add(node.path);
      }
    }

    return expanded;
  }

  void setActiveTab(WorkspaceTab tab) {
    showWorkspaceTab(tab);
  }
  void setDetailSection(DetailPanelSection section) {
    _detailSection = section;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Future<ProjectValidationResult> validateProjectPath(String path) {
    return _validator.validate(path);
  }

  Future<Project?> addProject({
    required String path,
    String? name,
    String description = '',
    String goal = '',
    String notes = '',
  }) async {
    _isAddingProject = true;
    _lastError = null;
    notifyListeners();

    try {
      final validation = await _validator.validate(path);
      if (!validation.isValid) {
        _lastError = validation.errors.map((e) => e.message).join('\n');
        return null;
      }

      final projectId = _uuid.v4();
      final now = DateTime.now();
      final resolvedName = (name?.trim().isNotEmpty ?? false)
          ? name!.trim()
          : validation.projectName ?? path.split(RegExp(r'[/\\]')).last;

      final gitlabSettings = await _settingsService.loadGitLabSettings();
      final gitStatus = await _gitService.getRepositoryStatus(
        path.trim(),
        configuredGitLabBaseUrl: gitlabSettings.normalizedBaseUrl,
      );
      final contextId = ContextIdUtils.resolveForNewProject(
        remoteUrl: gitStatus.remoteUrl,
        configuredGitLabBaseUrl: gitlabSettings.normalizedBaseUrl,
      );

      var project = Project(
        id: projectId,
        contextId: contextId,
        name: resolvedName,
        path: path.trim(),
        description: description.trim(),
        goal: goal.trim(),
        notes: notes.trim(),
        addedAt: now,
        platforms: validation.platforms,
        flutterVersion: validation.sdkInfo?.flutterVersion,
        dartVersion: validation.sdkInfo?.dartVersion,
        dependencies: await _dependencyResolver.resolveProjectDependencies(
          path.trim(),
          globalMetadata: _globalPackageMetadata,
        ),
        status: ProjectStatus.active,
        changeHistory: [],
        widgets: const [],
        documentationLinks: const [],
        isFlutterProject: validation.isFlutterProject,
        structureNotes: validation.structureNotes,
        sdkAvailable: validation.sdkInfo?.allAvailable ?? false,
      );

      final initialRecord = _documentation.createInitialChangeRecord(project);
      project = project.copyWith(changeHistory: [initialRecord]);

      project = await _documentation.initializeDocumentation(project);
      await _storage.saveProject(project);

      _projects = [..._projects, project];
      _selectedProject = project;
      _activeTab = WorkspaceTab.overview;
      await _openSelectedProject();
      return project;
    } catch (e) {
      _lastError = 'Failed to add project: $e';
      return null;
    } finally {
      _isAddingProject = false;
      notifyListeners();
    }
  }

  Future<void> updateProject(Project project) async {
    await _storage.saveProject(project);
    _projects = _projects.map((p) => p.id == project.id ? project : p).toList();
    if (_selectedProject?.id == project.id) {
      _selectedProject = project;
    }
    notifyListeners();
  }

  Future<void> deleteProject(String projectId) async {
    await _storage.deleteProject(projectId);
    _projects = _projects.where((p) => p.id != projectId).toList();
    if (_selectedProject?.id == projectId) {
      _selectedProject = _projects.isNotEmpty ? _projects.first : null;
      _clearOpenFiles();
      if (_selectedProject != null) {
        await _loadProjectFiles(_selectedProject!.path);
      } else {
        _fileTree = [];
        _expandedDirectoryPaths = {};
      }
    }
    notifyListeners();
  }

  Future<void> exportDocumentation() async {
    final project = _selectedProject;
    if (project == null) return;
    await _documentation.exportDocumentation(project);
  }

bool isProjectDirectoryPresent(Project project) {
  final path = project.path.trim();
  if (path.isEmpty) return false;
  final dir = Directory(path);
  if (!dir.existsSync()) return false;
  try {
    final children = dir.listSync(followLinks: false);
    if (children.isEmpty) return true;
    return children.any((entity) => p.basename(entity.path) != '.ai');
  } catch (_) {
    return false;
  }
}

  /// Points an existing project at another folder on this computer.
  /// Returns false when [rawPath] is empty or the directory is missing.
  Future<bool> relocateProjectDirectory(String projectId, String rawPath) async {
    final path = rawPath.trim();
    if (path.isEmpty || !Directory(path).existsSync()) {
      notifyListeners();
      return false;
    }
    final index = _projects.indexWhere((item) => item.id == projectId);
    if (index < 0) return false;

    final updated = _projects[index].copyWith(path: path);
    final switching = _selectedProject?.id != projectId;
    await updateProject(updated);
    if (switching) {
      _syncRunGeneration++;
      CursorCliFlight.instance.onProjectSwitched(projectId);
      _selectedProject = updated;
    }
    await _openSelectedProject();
    return true;
  }

  Future<void> _openSelectedProject() async {
    final project = _selectedProject;
    if (project == null) return;
    if (!isProjectDirectoryPresent(project)) {
      _fileTree = [];
      _expandedDirectoryPaths = {};
      _gitRepositoryStatus = null;
      _stopContextSyncWatchers();
      notifyListeners();
      return;
    }
    await _refreshGitStatusForSelectedProject();
    if (_selectedProject?.id != project.id) return;
    _armContextSyncForSelectedProject();
  }

  Future<void> refreshSelectedProject() async {
    final project = _selectedProject;
    if (project == null) return;
    if (!isProjectDirectoryPresent(project)) {
      _gitRepositoryStatus = null;
      _stopContextSyncWatchers();
      notifyListeners();
      return;
    }

    final validation = await _validator.validate(project.path);
    if (!validation.isValid) {
      _lastError = validation.errors.map((e) => e.message).join('\n');
      notifyListeners();
      return;
    }

    final updated = project.copyWith(
      platforms: validation.platforms,
      flutterVersion: validation.sdkInfo?.flutterVersion,
      dartVersion: validation.sdkInfo?.dartVersion,
      structureNotes: validation.structureNotes,
      sdkAvailable: validation.sdkInfo?.allAvailable ?? false,
    );

    final record = ChangeRecord(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      title: 'Project refreshed',
      description: 'Metadata and dependencies were re-scanned.',
      category: 'system',
    );

    await updateProject(
      updated.copyWith(
        changeHistory: [...updated.changeHistory, record],
      ),
    );

    await _refreshGitStatusForSelectedProject();
  }

  Future<void> refreshGitStatus({String? configuredGitLabBaseUrl}) async {
    await _refreshGitStatusForSelectedProject(
      configuredGitLabBaseUrl: configuredGitLabBaseUrl,
    );
  }

  Future<List<GitCommitEntry>> loadGitFileHistory(String relativePath) async {
    final project = _selectedProject;
    if (project == null) return [];
    return _gitService.getFileHistory(project.path, relativePath);
  }

  Future<List<GitCommitEntry>> loadGitLineHistory(
    String relativePath,
    int line,
  ) async {
    final project = _selectedProject;
    if (project == null || line <= 0) return [];
    return _gitService.getLineHistory(project.path, relativePath, line);
  }

  Future<GitProductivity> loadGitProductivity() async {
    final project = _selectedProject;
    if (project == null) {
      throw StateError('No project selected');
    }
    return _gitService.getProductivity(project.path);
  }

  Future<List<GitCommitGraphRow>> loadGitProjectGraph() async {
    final project = _selectedProject;
    if (project == null) return [];
    return _gitService.getProjectCommitGraph(project.path);
  }

  Future<List<GitCommitGraphRow>> loadGitFileGraph(String relativePath) async {
    final project = _selectedProject;
    if (project == null) return [];
    return _gitService.getFileCommitGraph(project.path, relativePath);
  }

  Future<void> refreshDependencies() async {
    await _resolveDependenciesForSelectedProject();
  }

  Future<void> refreshWidgets({CursorCliSettings? cursorSettings}) async {
    await _scanWidgetsForSelectedProject(
      cursorSettings: cursorSettings,
      enrichWithCursor: true,
    );
  }

  Future<void> _refreshGitStatusForSelectedProject({
    String? configuredGitLabBaseUrl,
  }) async {
    final project = _selectedProject;
    if (project == null) {
      _gitRepositoryStatus = null;
      notifyListeners();
      return;
    }

    _isLoadingGit = true;
    notifyListeners();

    try {
      _gitRepositoryStatus =
          await _gitService.getRepositoryStatus(
        project.path,
        configuredGitLabBaseUrl: configuredGitLabBaseUrl,
      );
    } catch (e) {
      _gitRepositoryStatus = GitRepositoryStatus.error('$e');
    } finally {
      _isLoadingGit = false;
      notifyListeners();
    }
  }

  Future<void> updateGlobalPackageMetadata(
    GlobalPackageMetadata metadata,
  ) async {
    final saved = await _globalMetadataService.save(metadata);
    _globalPackageMetadata = {
      ..._globalPackageMetadata,
      saved.packageName: saved,
    };
    notifyListeners();
  }

  Future<void> _resolveDependenciesForSelectedProject() async {
    final project = _selectedProject;
    if (project == null) return;

    _isLoadingDependencies = true;
    notifyListeners();

    try {
      _globalPackageMetadata = await _globalMetadataService.loadAll();
      final dependencies = await _dependencyResolver.resolveProjectDependencies(
        project.path,
        globalMetadata: _globalPackageMetadata,
      );

      final updated = project.copyWith(dependencies: dependencies);
      await _storage.saveProject(updated);
      _projects =
          _projects.map((p) => p.id == updated.id ? updated : p).toList();
      if (_selectedProject?.id == updated.id) {
        _selectedProject = updated;
      }
    } catch (e) {
      _lastError = 'Failed to resolve dependencies: $e';
    } finally {
      _isLoadingDependencies = false;
      notifyListeners();
    }
  }

  Future<void> _scanWidgetsForSelectedProject({
    CursorCliSettings? cursorSettings,
    bool enrichWithCursor = false,
  }) async {
    final project = _selectedProject;
    if (project == null) return;

    _isLoadingWidgets = true;
    _widgetsEnrichedByCursor = false;
    notifyListeners();

    try {
      final staticResult =
          await _widgetAnalysisCoordinator.analyzeStatic(project.path);
      await _saveWidgets(staticResult.widgets);
      _widgetsEnrichedByCursor = staticResult.enrichedByCursor;

      // Never auto-enrich on project switch — that duplicates Cursor jobs.
      // Enrichment runs only when explicitly requested (Widgets refresh).
      if (enrichWithCursor) {
        final resolvedCursorSettings =
            cursorSettings ?? await _settingsService.loadCursorCliSettings();
        if (resolvedCursorSettings.enabled &&
            !_isEnrichingWidgetsWithCursor &&
            !CursorCliFlight.instance.isBusy &&
            !_contextSyncService.isSyncing) {
          await _enrichWidgetsWithCursor(
            project.id,
            project.path,
            resolvedCursorSettings,
            staticResult.widgets,
          );
        }
      }
    } catch (e) {
      _lastError = 'Failed to scan widgets: $e';
    } finally {
      _isLoadingWidgets = false;
      notifyListeners();
    }
  }

  Future<void> _enrichWidgetsWithCursor(
    String projectId,
    String projectPath,
    CursorCliSettings settings,
    List<WidgetEntry> baseline,
  ) async {
    _isEnrichingWidgetsWithCursor = true;
    CursorCliLogger.instance.info(
      'Background widget enrichment scheduled.',
      source: 'state',
      logRoot: projectPath,
      data: {'widgets': baseline.length},
    );
    notifyListeners();

    try {
      final enriched = await _widgetAnalysisCoordinator.enrichWithCursor(
        projectId: projectId,
        projectRoot: projectPath,
        settings: settings,
        baseline: baseline,
      );
      if (_selectedProject?.path != projectPath) {
        CursorCliLogger.instance.warn(
          'Enrichment result discarded (project changed).',
          source: 'state',
          logRoot: projectPath,
        );
        return;
      }
      await _saveWidgets(enriched.widgets);
      _widgetsEnrichedByCursor = enriched.enrichedByCursor;
    } catch (e) {
      _lastError = 'Cursor widget enrichment failed: $e';
      CursorCliLogger.instance.error(
        'Background enrichment failed: $e',
        source: 'state',
        logRoot: projectPath,
      );
    } finally {
      _isEnrichingWidgetsWithCursor = false;
      notifyListeners();
    }
  }

  Future<void> _saveWidgets(List<WidgetEntry> widgets) async {
    final project = _selectedProject;
    if (project == null) return;

    final updated = project.copyWith(widgets: widgets);
    await _storage.saveProject(updated);
    _projects = _projects.map((p) => p.id == updated.id ? updated : p).toList();
    if (_selectedProject?.id == updated.id) {
      _selectedProject = updated;
    }
  }

  Future<void> syncContextNow() async {
    await _runContextSync(reason: 'manual', force: true);
  }

  @visibleForTesting
  Future<void> runContextSyncAllForTest(String reason) =>
      _runContextSyncAll(reason: reason);

  @visibleForTesting
  Future<void> runContextSyncForTest({
    required String reason,
    bool force = false,
  }) async {
    await _runContextSync(reason: reason, force: force);
  }

  @visibleForTesting
  bool autoCursorSyncDoneForTest(String projectId) =>
      _autoCursorSyncDone.contains(projectId);

  @visibleForTesting
  void debugClearSyncCooldown() => _lastSuccessfulSyncAt.clear();

  @visibleForTesting
  bool get autoSyncPausedAfterErrorForTest => _autoSyncPausedAfterError;

  @visibleForTesting
  Future<void> get debugContextSyncQueue =>
      _contextSyncQueue ?? Future<void>.value();

  @visibleForTesting
  void setProjectsForTest(List<Project> projects, {Project? selected}) {
    _projects = List<Project>.of(projects);
    if (selected != null) _selectedProject = selected;
  }

  /// Same generation bump as [selectProject], without loading files.
  @visibleForTesting
  void debugDetachSelection(Project? project) {
    _syncRunGeneration++;
    CursorCliFlight.instance.onProjectSwitched(project?.id);
    _selectedProject = project;
  }

  void reloadContextSyncSchedule() {
    if (_selectedProject == null) return;
    unawaited(_restartContextSyncInterval());
    unawaited(_runContextSync(reason: 'settings-reload', force: true));
  }

  Future<bool> updateProjectContextId(String rawId) async {
    final project = _selectedProject;
    if (project == null) return false;
    final normalized = ContextIdUtils.normalize(rawId);
    if (normalized == null) {
      _lastError = 'Invalid context ID';
      notifyListeners();
      return false;
    }
    final updated = project.copyWith(contextId: normalized);
    await updateProject(updated);
    _lastSuccessfulSyncAt.remove(normalized);
    _autoCursorSyncDone.remove(updated.id);
    _armContextSyncForSelectedProject(forceSoon: true);
    return true;
  }

  Future<void> regenerateProjectContextId() async {
    final project = _selectedProject;
    if (project == null) return;
    final gitlabSettings = await _settingsService.loadGitLabSettings();
    final gitStatus = await _gitService.getRepositoryStatus(
      project.path,
      configuredGitLabBaseUrl: gitlabSettings.normalizedBaseUrl,
    );
    final next = ContextIdUtils.resolveForNewProject(
      remoteUrl: gitStatus.remoteUrl,
      configuredGitLabBaseUrl: gitlabSettings.normalizedBaseUrl,
    );
    await updateProjectContextId(next);
  }

  /// Arms watchers/interval and schedules a debounced auto-sync.
  void _armContextSyncForSelectedProject({bool forceSoon = false}) {
    _stopContextSyncWatchers();
    final project = _selectedProject;
    if (project == null) return;

    _watchAiDirectory(project.path);
    unawaited(_restartContextSyncInterval());
    _scheduleContextSync(
      reason: forceSoon ? 'context-id-changed' : 'project-selected',
      delay: forceSoon ? Duration.zero : _projectSelectDebounce,
      force: forceSoon,
    );
  }

  void _scheduleContextSync({
    required String reason,
    Duration delay = Duration.zero,
    bool force = false,
  }) {
    _contextSyncDebounce?.cancel();
    _contextSyncDebounce = Timer(delay, () {
      unawaited(_runContextSync(reason: reason, force: force));
    });
  }

  Future<void> _restartContextSyncInterval() async {
    _contextSyncInterval?.cancel();
    final settings = await _settingsService.loadContextSyncSettings();
    if (!settings.isActive) return;
    _contextSyncInterval = Timer.periodic(settings.syncInterval, (_) {
      unawaited(_runContextSyncAll(reason: 'interval'));
    });
  }

  void _watchAiDirectory(String projectPath) {
    if (!Directory(projectPath).existsSync()) return;
    final aiDir = Directory(ProjectContextPaths.contextDir(projectPath));
    if (!aiDir.existsSync()) {
      aiDir.createSync(recursive: true);
    }
    try {
      _aiWatchSub = aiDir.watch(recursive: true).listen((_) {
        if (_aiWatchSuppressCount > 0) return;
        if (_contextSyncService.isSyncing) return;
        _scheduleContextSync(
          reason: 'ai-watch',
          delay: _aiWatchDebounce,
          force: false,
        );
      });
    } catch (_) {
      // Watching may be unsupported on some platforms/filesystems.
    }
  }

  void _stopContextSyncWatchers() {
    _aiWatchSub?.cancel();
    _aiWatchSub = null;
    _contextSyncDebounce?.cancel();
    _contextSyncDebounce = null;
    _contextSyncInterval?.cancel();
    _contextSyncInterval = null;
  }

  /// Syncs every project from the snapshot taken when the queue starts.
  /// A second call while this queue is running does not start another.
  Future<void> _runContextSyncAll({required String reason}) {
    if (_autoSyncPausedAfterError) {
      AppLogService.instance.info(
        'Auto-sync waiting — last sync failed, press sync to retry',
        source: 'context-sync',
        data: {'reason': reason},
      );
      return Future<void>.value();
    }
    if (_contextSyncQueueRunning) {
      AppLogService.instance.info(
        'Context sync queue skipped — already running',
        source: 'context-sync',
        data: {'reason': reason},
      );
      return _contextSyncQueue ?? Future<void>.value();
    }
    _contextSyncQueueRunning = true;
    final snapshot = List<Project>.of(_projects);
    _contextSyncQueue = _drainContextSyncQueue(
      reason: reason,
      projects: snapshot,
    );
    return _contextSyncQueue!;
  }

  Future<void> _drainContextSyncQueue({
    required String reason,
    required List<Project> projects,
  }) async {
    var networkFailures = 0;
    _aiWatchSuppressCount++;
    try {
      final syncSettings = await _settingsService.loadContextSyncSettings();
      if (!syncSettings.isActive) {
        _contextSyncStatus = const ContextSyncStatus(
          phase: ContextSyncPhase.idle,
          message: 'Context sync is disabled',
        );
        notifyListeners();
        return;
      }

      if (projects.isNotEmpty) {
        for (final project in projects) {
          while (true) {
            final status = await _runContextSync(
              reason: reason,
              project: project,
              holdWatchSuppress: false,
            );
            if (!_isNetworkSyncFailure(status)) break;
            final delay = _networkRetryDelays[networkFailures.clamp(
              0,
              _networkRetryDelays.length - 1,
            )];
            networkFailures++;
            await _waitNetwork(delay);
            if (networkFailures >= _networkAttemptsPerPass) {
              _pauseAutoSyncAfterError('network');
              return;
            }
          }
        }
      }
      if (_autoSyncPausedAfterError) return;
      await _syncMachineSettings(syncSettings);
    } finally {
      await Future<void>.delayed(debugPostSyncSuppress);
      if (_aiWatchSuppressCount > 0) _aiWatchSuppressCount--;
      _contextSyncQueueRunning = false;
    }
  }

  Future<void> _syncMachineSettings(ContextSyncSettings syncSettings) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final result = await WorkstationSettingsSync(git: _contextSyncService.git)
        .sync(repoUrl: syncSettings.repoUrl);
    if (result.ok) return;
    _pauseAutoSyncAfterError('settings');
    _rememberSyncStatus(
      ContextSyncStatus(
        phase: ContextSyncPhase.error,
        error: result.error ?? result.message,
        message: 'Machine settings were not saved',
      ),
    );
  }

  void _armAppUpdateChecks() {
    if (kDebugMode) return;
    unawaited(_checkAppUpdate());
    _appUpdateTimer ??= Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_checkAppUpdate());
    });
  }

  Future<void> _checkAppUpdate() async {
    final syncSettings = await _settingsService.loadContextSyncSettings();
    if (!syncSettings.isActive) return;
    await AppReleaseUpdate(git: _contextSyncService.git).check(
      repoUrl: syncSettings.repoUrl,
      currentVersion: appVersion,
    );
  }

  Future<void> _waitNetwork(Duration duration) {
    final hook = debugNetworkDelay;
    if (hook != null) return hook(duration);
    return Future<void>.delayed(duration);
  }

  Future<ContextSyncStatus?> _runContextSync({
    String reason = 'auto',
    bool force = false,
    Project? project,
    bool holdWatchSuppress = true,
  }) {
    final scheduled = _syncTail.then(
      (_) => _runContextSyncBody(
        reason: reason,
        force: force,
        project: project,
        holdWatchSuppress: holdWatchSuppress,
      ),
    );
    _syncTail = scheduled.then((_) {}, onError: (Object _, StackTrace __) {});
    return scheduled;
  }

  Future<ContextSyncStatus?> _runContextSyncBody({
    required String reason,
    required bool force,
    required Project? project,
    required bool holdWatchSuppress,
  }) async {
    final target = project ?? _selectedProject;
    if (target == null) return null;
    if (reason == 'manual') {
      _autoSyncPausedAfterError = false;
    } else if (_autoSyncPausedAfterError &&
        reason != 'startup' &&
        reason != 'interval') {
      AppLogService.instance.info(
        'Auto-sync waiting — last sync failed, press sync to retry',
        source: 'context-sync',
        data: {'reason': reason, 'projectId': target.id},
      );
      return null;
    }
    if (!isProjectDirectoryPresent(target)) {
      AppLogService.instance.info(
        'Sync skipped — project folder was not found',
        source: 'context-sync',
        data: {'reason': reason, 'projectId': target.id, 'path': target.path},
      );
      return null;
    }

    final syncSettings = await _settingsService.loadContextSyncSettings();
    if (!syncSettings.isActive) {
      _contextSyncStatus = const ContextSyncStatus(
        phase: ContextSyncPhase.idle,
        message: 'Context sync is disabled',
      );
      notifyListeners();
      return _contextSyncStatus;
    }

    final contextId =
        ContextIdUtils.normalize(target.contextId) ?? target.contextId;

    // One auto Cursor sync per project when switching / watching .ai.
    // startup, interval, and manual Sync are not limited by this.
    final switchAuto = reason == 'project-selected' || reason == 'ai-watch';
    if (!force && switchAuto && _autoCursorSyncDone.contains(target.id)) {
      AppLogService.instance.info(
        'Auto-sync skipped — project already had its Cursor sync',
        source: 'context-sync',
        data: {'reason': reason, 'projectId': target.id},
      );
      return null;
    }

    if (!force) {
      final last = _lastSuccessfulSyncAt[contextId];
      if (last != null &&
          DateTime.now().difference(last) < _autoSyncCooldown) {
        AppLogService.instance.info(
          'Auto-sync skipped (cooldown)',
          source: 'context-sync',
          data: {
            'reason': reason,
            'contextId': contextId,
            'cooldownSec': _autoSyncCooldown.inSeconds,
            'lastAgoSec': DateTime.now().difference(last).inSeconds,
          },
        );
        return null;
      }
    }

    if (_contextSyncService.isSyncing || CursorCliFlight.instance.isBusy) {
      AppLogService.instance.info(
        'Sync skipped — Cursor/sync already busy (no queue)',
        source: 'context-sync',
        data: {
          'reason': reason,
          'projectId': target.id,
          'syncing': _contextSyncService.isSyncing,
          'cursorBusy': CursorCliFlight.instance.isBusy,
          'activeCursorJob': CursorCliFlight.instance.activeJob,
        },
      );
      return null;
    }

    if (!force && _semanticIndexPauseDepth > 0) {
      AppLogService.instance.info(
        'Auto-sync skipped — semantic index in progress',
        source: 'context-sync',
        data: {
          'reason': reason,
          'projectId': target.id,
          'pauseDepth': _semanticIndexPauseDepth,
        },
      );
      return null;
    }

    final generation = _syncRunGeneration;
    final abortGeneration = _syncAbortGeneration;
    final projectId = target.id;
    // startup and interval keep going if the user selects another project.
    final selectionBound = reason != 'startup' && reason != 'interval';
    final cursorSettings = await _settingsService.loadCursorCliSettings();

    bool stillCurrent() {
      if (selectionBound) {
        return generation == _syncRunGeneration &&
            _selectedProject?.id == projectId;
      }
      return abortGeneration == _syncAbortGeneration;
    }

    if (holdWatchSuppress) _aiWatchSuppressCount++;
    try {
      final status = await _contextSyncService.syncProject(
        project: target,
        syncSettings: syncSettings,
        cursorSettings: cursorSettings,
        shouldContinue: stillCurrent,
        onStatus: (s) {
          if (!stillCurrent()) return;
          _rememberSyncStatus(s);
        },
      );

      final cancelled = status.message == 'Sync cancelled';
      if (cancelled) {
        AppLogService.instance.info(
          'Sync aborted cleanly (no push)',
          source: 'context-sync',
          data: {'reason': reason, 'projectId': projectId},
        );
        return status;
      }

      _noteSyncOutcome(status);

      if (status.lastSyncedAt != null && !status.hasError) {
        _lastSuccessfulSyncAt[contextId] = status.lastSyncedAt!;
        // Mark auto-done only after a real successful run for this project.
        if (switchAuto) {
          _autoCursorSyncDone.add(projectId);
        }
      }

      _rememberSyncStatus(status);
      if (!stillCurrent()) {
        AppLogService.instance.warn(
          'Sync UI update discarded (project changed)',
          source: 'context-sync',
          data: {'reason': reason, 'finishedProjectId': projectId},
        );
        return status;
      }

      return status;
    } finally {
      if (holdWatchSuppress) {
        await Future<void>.delayed(debugPostSyncSuppress);
        if (_aiWatchSuppressCount > 0) _aiWatchSuppressCount--;
      }
    }
  }

  void _pauseAutoSyncAfterError(String reason) {
    if (_autoSyncPausedAfterError) return;
    _autoSyncPausedAfterError = true;
    AppLogService.instance.info(
      'Auto-sync paused until a manual sync',
      source: 'context-sync',
      data: {'reason': reason},
    );
  }

  void _noteSyncOutcome(ContextSyncStatus status) {
    if (!status.hasError) return;
    if (_isNetworkSyncFailure(status)) return;
    final error = status.error ?? '';
    if (error.contains('Project folder was not found')) return;
    _pauseAutoSyncAfterError(error);
  }

  @override
  void dispose() {
    _appUpdateTimer?.cancel();
    _stopContextSyncWatchers();
    super.dispose();
  }
}

bool _isNetworkSyncFailure(ContextSyncStatus? status) {
  if (status == null || !status.hasError) return false;
  final text = (status.error ?? '').toLowerCase();
  if (text.isEmpty) return false;
  const needles = <String>[
    'could not resolve host',
    'could not resolve hostname',
    'temporary failure in name resolution',
    'failed to connect',
    'connection timed out',
    'operation timed out',
    'timed out',
    'network is unreachable',
    'no route to host',
    'could not read from remote repository',
    'the remote end hung up unexpectedly',
    'connection reset',
    'connection refused',
    'recv failure',
    'remote is not reachable',
    'early eof',
    'ssl_error_syscall',
    "couldn't connect to server",
  ];
  return needles.any(text.contains);
}
