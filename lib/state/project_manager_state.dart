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
import 'package:project_manager/models/file_preview_focus.dart';
import 'package:project_manager/models/git_commit_entry.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/project_file_node.dart';
import 'package:project_manager/models/project_status.dart';
import 'package:project_manager/models/validation_result.dart';
import 'package:project_manager/services/context_sync_service.dart';
import 'package:project_manager/services/app_log_service.dart';
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
  StreamSubscription<FileSystemEvent>? _aiWatchSub;
  Timer? _contextSyncDebounce;
  Timer? _contextSyncInterval;
  var _suppressAiWatch = false;
  final Map<String, DateTime> _lastSuccessfulSyncAt = {};
  /// Projects that already received one auto Cursor sync this session.
  final Set<String> _autoCursorSyncDone = {};
  var _syncRunGeneration = 0;

  static const _autoSyncCooldown = Duration(minutes: 2);
  static const _projectSelectDebounce = Duration(seconds: 2);
  static const _aiWatchDebounce = Duration(seconds: 15);
  static const _postSyncSuppress = Duration(seconds: 5);

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
        await _loadProjectFiles(_selectedProject!.path);
        await _resolveDependenciesForSelectedProject();
        await _scanWidgetsForSelectedProject();
        await _refreshGitStatusForSelectedProject();
        _armContextSyncForSelectedProject();
      }
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
      _loadProjectFiles(project.path);
      _resolveDependenciesForSelectedProject();
      _scanWidgetsForSelectedProject();
      _refreshGitStatusForSelectedProject();
      _armContextSyncForSelectedProject();
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
      await _loadProjectFiles(project.path);
      await _resolveDependenciesForSelectedProject();
      await _scanWidgetsForSelectedProject();
      _armContextSyncForSelectedProject();
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

  Future<void> refreshSelectedProject() async {
    final project = _selectedProject;
    if (project == null) return;

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

    await _loadProjectFiles(project.path);
    await _resolveDependenciesForSelectedProject();
    await _scanWidgetsForSelectedProject();
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

  Future<void> syncContextNow() =>
      _runContextSync(reason: 'manual', force: true);

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
      unawaited(_runContextSync(reason: 'interval', force: false));
    });
  }

  void _watchAiDirectory(String projectPath) {
    final aiDir = Directory(ProjectContextPaths.contextDir(projectPath));
    if (!aiDir.existsSync()) {
      aiDir.createSync(recursive: true);
    }
    try {
      _aiWatchSub = aiDir.watch(recursive: true).listen((_) {
        if (_suppressAiWatch) return;
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

  Future<void> _runContextSync({
    String reason = 'auto',
    bool force = false,
  }) async {
    final project = _selectedProject;
    if (project == null) return;

    final syncSettings = await _settingsService.loadContextSyncSettings();
    if (!syncSettings.isActive) {
      _contextSyncStatus = const ContextSyncStatus(
        phase: ContextSyncPhase.idle,
        message: 'Context sync is disabled',
      );
      notifyListeners();
      return;
    }

    final contextId =
        ContextIdUtils.normalize(project.contextId) ?? project.contextId;

    // One auto Cursor sync per project when switching / watching .ai.
    // Interval + manual Sync still allowed.
    final switchAuto = reason == 'project-selected' || reason == 'ai-watch';
    if (!force && switchAuto && _autoCursorSyncDone.contains(project.id)) {
      AppLogService.instance.info(
        'Auto-sync skipped — project already had its Cursor sync',
        source: 'context-sync',
        data: {'reason': reason, 'projectId': project.id},
      );
      return;
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
        return;
      }
    }

    if (_contextSyncService.isSyncing || CursorCliFlight.instance.isBusy) {
      AppLogService.instance.info(
        'Sync skipped — Cursor/sync already busy (no queue)',
        source: 'context-sync',
        data: {
          'reason': reason,
          'projectId': project.id,
          'syncing': _contextSyncService.isSyncing,
          'cursorBusy': CursorCliFlight.instance.isBusy,
          'activeCursorJob': CursorCliFlight.instance.activeJob,
        },
      );
      return;
    }

    final generation = _syncRunGeneration;
    final projectId = project.id;
    final cursorSettings = await _settingsService.loadCursorCliSettings();

    if (switchAuto) {
      _autoCursorSyncDone.add(projectId);
    }

    _suppressAiWatch = true;
    try {
      final status = await _contextSyncService.syncProject(
        project: project,
        syncSettings: syncSettings,
        cursorSettings: cursorSettings,
        onStatus: (s) {
          if (generation != _syncRunGeneration) return;
          _contextSyncStatus = s;
          notifyListeners();
        },
      );

      if (status.lastSyncedAt != null && !status.hasError) {
        _lastSuccessfulSyncAt[contextId] = status.lastSyncedAt!;
      }

      if (generation != _syncRunGeneration ||
          _selectedProject?.id != projectId) {
        AppLogService.instance.warn(
          'Sync UI update discarded (project changed)',
          source: 'context-sync',
          data: {'reason': reason, 'finishedProjectId': projectId},
        );
        return;
      }

      _contextSyncStatus = status;
      notifyListeners();
    } finally {
      await Future<void>.delayed(_postSyncSuppress);
      _suppressAiWatch = false;
      // No queued follow-up sync — one project = one Cursor request.
    }
  }

  @override
  void dispose() {
    _stopContextSyncWatchers();
    super.dispose();
  }
}
