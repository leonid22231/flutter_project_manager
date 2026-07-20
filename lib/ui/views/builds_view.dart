import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/build_history_sort_utils.dart';
import 'package:project_manager/core/utils/flutter_platform_utils.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_history_entry.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/gitlab_check_result.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/build_archive_service.dart';
import 'package:project_manager/services/build_execution_service.dart';
import 'package:project_manager/services/build_history_logger.dart';
import 'package:project_manager/services/gitlab_ci_build_service.dart';
import 'package:project_manager/services/vscode_build_config_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:provider/provider.dart';

enum _HistoryFilter {
  all,
  local,
  gitlab,
}

enum _BuildsPage {
  configurations,
  history,
}

class BuildsView extends StatefulWidget {
  const BuildsView({super.key});

  @override
  State<BuildsView> createState() => _BuildsViewState();
}

class _BuildsViewState extends State<BuildsView> {
  final _configService = VscodeBuildConfigService();
  final _executionService = BuildExecutionService();
  final _archiveService = BuildArchiveService();
  final _gitlabCiService = GitLabCiBuildService();
  final _searchController = TextEditingController();
  final _outputController = ScrollController();

  Future<ProjectBuildScanResult>? _future;
  String? _loadedProjectPath;
  String? _loadedProjectId;
  String? _selectedConfigId;
  String? _selectedHistoryId;
  _BuildsPage _page = _BuildsPage.configurations;
  _HistoryFilter _historyFilter = _HistoryFilter.all;
  bool _isRunning = false;
  bool _isLoadingHistory = false;
  int? _lastExitCode;
  List<BuildHistoryEntry> _history = const [];
  List<BuildHistoryEntry> _localHistoryEntries = const [];
  List<BuildHistoryEntry> _gitlabHistoryEntries = const [];
  int _gitLabHistoryPage = 1;
  int _gitLabHistoryTotalPages = 1;
  List<ProjectBuildConfig> _gitlabCiConfigs = const [];
  String? _gitLabBuildsError;
  int _gitLabYamlJobCount = 0;
  final Map<int, _CachedGitLabHistoryPage> _gitlabHistoryPageCache = {};
  List<BuildHistoryEntry>? _cachedLocalEntries;
  final StringBuffer _output = StringBuffer();
  final _historyLog = BuildHistoryLogger.instance;
  static const _defaultHistoryLoadEstimateMs = 28000;
  static const _minHistoryLoadEstimateSeconds = 10;
  static const _maxHistoryLoadEstimateSeconds = 90;
  int _lastHistoryLoadEstimateMs = _defaultHistoryLoadEstimateMs;
  Timer? _historyLoadingCountdownTimer;
  DateTime? _historyLoadStartedAt;
  int? _historyLoadEstimateSeconds;
  int? _historyLoadingRemainingSeconds;
  int? _historyLoadingElapsedSeconds;

  @override
  void dispose() {
    _historyLoadingCountdownTimer?.cancel();
    _searchController.dispose();
    _outputController.dispose();
    _executionService.cancel();
    super.dispose();
  }

  void _clearHistoryCache() {
    _gitlabHistoryPageCache.clear();
    _cachedLocalEntries = null;
  }

  bool _isTransientGitLabError(String? error) {
    return error == 'GitLab is not connected.';
  }

  void _startHistoryLoadingCountdown() {
    _historyLoadingCountdownTimer?.cancel();
    _historyLoadStartedAt = DateTime.now();
    _historyLoadEstimateSeconds =
        ((_lastHistoryLoadEstimateMs / 1000) * 1.1).ceil().clamp(
              _minHistoryLoadEstimateSeconds,
              _maxHistoryLoadEstimateSeconds,
            );
    setState(() {
      _historyLoadingRemainingSeconds = _historyLoadEstimateSeconds;
      _historyLoadingElapsedSeconds = null;
    });
    _historyLoadingCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || _historyLoadStartedAt == null) return;
        final elapsed =
            DateTime.now().difference(_historyLoadStartedAt!).inSeconds;
        final remaining = _historyLoadEstimateSeconds! - elapsed;
        setState(() {
          if (remaining > 0) {
            _historyLoadingRemainingSeconds = remaining;
            _historyLoadingElapsedSeconds = null;
          } else {
            _historyLoadingRemainingSeconds = 0;
            _historyLoadingElapsedSeconds = elapsed;
          }
        });
      },
    );
  }

  void _stopHistoryLoadingCountdown({int? elapsedMs}) {
    _historyLoadingCountdownTimer?.cancel();
    _historyLoadingCountdownTimer = null;
    _historyLoadStartedAt = null;
    _historyLoadEstimateSeconds = null;
    if (elapsedMs != null && elapsedMs > 0) {
      _lastHistoryLoadEstimateMs =
          ((_lastHistoryLoadEstimateMs * 2) + elapsedMs) ~/ 3;
      final maxMs = _maxHistoryLoadEstimateSeconds * 1000;
      if (_lastHistoryLoadEstimateMs > maxMs) {
        _lastHistoryLoadEstimateMs = maxMs;
      }
    }
    if (mounted) {
      setState(() {
        _historyLoadingRemainingSeconds = null;
        _historyLoadingElapsedSeconds = null;
      });
    }
  }

  void _reload(String projectId, String projectPath, List<String> platforms) {
    _clearHistoryCache();
    setState(() {
      _loadedProjectPath = projectPath;
      _loadedProjectId = projectId;
      _selectedConfigId = null;
      _selectedHistoryId = null;
      _future = _configService.scanProject(
        projectPath,
        platforms: platforms,
      );
      _output.clear();
      _lastExitCode = null;
      _isRunning = false;
      _history = const [];
      _localHistoryEntries = const [];
      _gitlabHistoryEntries = const [];
      _gitLabHistoryPage = 1;
      _gitLabHistoryTotalPages = 1;
      _gitlabCiConfigs = const [];
      _gitLabBuildsError = null;
      _gitLabYamlJobCount = 0;
    });
    _refreshGitAndHistory(projectId, projectPath);
  }

  Future<void> _refreshGitAndHistory(
    String projectId,
    String projectPath,
  ) async {
    final appSettings = context.read<AppSettingsState>();
    final gitLabBaseUrl = appSettings.gitlabSettings.enabled
        ? appSettings.gitlabSettings.normalizedBaseUrl
        : null;
    await context.read<ProjectManagerState>().refreshGitStatus(
          configuredGitLabBaseUrl: gitLabBaseUrl,
        );
    if (!mounted || _loadedProjectId != projectId) return;
    await _ensureGitLabConnection(appSettings);
    if (!mounted || _loadedProjectId != projectId) return;
    await _loadGitLabCiConfigs(projectPath);
    if (!mounted || _loadedProjectId != projectId) return;
    await _loadHistory(projectId, projectPath);
  }

  Future<GitLabCheckResult?> _ensureGitLabConnection(
    AppSettingsState appSettings,
  ) async {
    if (!appSettings.gitlabSettings.enabled) return null;

    while (appSettings.isLoading && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return appSettings.lastGitLabCheck;

    while (appSettings.isCheckingGitLab && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return appSettings.lastGitLabCheck;

    if (appSettings.lastGitLabCheck?.connected == true) {
      return appSettings.lastGitLabCheck;
    }

    return appSettings.checkGitLabConnection();
  }

  Future<void> _loadGitLabCiConfigs(String projectPath) async {
    final appSettings = context.read<AppSettingsState>();
    final gitStatus = context.read<ProjectManagerState>().gitRepositoryStatus;

    if (!appSettings.gitlabSettings.enabled) {
      setState(() => _gitlabCiConfigs = const []);
      return;
    }

    final connection = await _ensureGitLabConnection(appSettings);
    if (!mounted || _loadedProjectPath != projectPath) return;

    final configs = await _gitlabCiService.listCiJobConfigs(
      settings: appSettings.gitlabSettings,
      connection: connection,
      gitStatus: gitStatus,
      projectRoot: projectPath,
    );

    if (!mounted || _loadedProjectPath != projectPath) return;
    setState(() => _gitlabCiConfigs = configs);
  }

  Future<void> _loadHistory(String projectId, String projectPath) {
    _clearHistoryCache();
    return _loadHistoryPage(
      projectId,
      projectPath,
      page: 1,
      refreshLocal: true,
    );
  }

  Future<void> _loadHistoryPage(
    String projectId,
    String projectPath, {
    required int page,
    bool refreshLocal = false,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _clearHistoryCache();
    }

    final cachedPage = !forceRefresh ? _gitlabHistoryPageCache[page] : null;
    if (cachedPage != null) {
      final localEntries = page == 1 && _cachedLocalEntries != null
          ? _cachedLocalEntries!
          : _localHistoryEntries;

      _historyLog.info(
        'loadHistoryPage cache hit',
        source: 'builds-view',
        data: {
          'projectId': projectId,
          'page': page,
          'builds': cachedPage.entries.length,
        },
      );

      _applyHistoryState(
        projectId: projectId,
        localEntries: localEntries,
        gitlabEntries: cachedPage.entries,
        gitLabError: cachedPage.error != null &&
                _isTransientGitLabError(cachedPage.error)
            ? null
            : (cachedPage.error ?? _gitLabBuildsError),
        yamlJobCount: cachedPage.yamlJobCount,
        gitLabPage: page,
        gitLabTotalPages: cachedPage.totalPages,
      );
      return;
    }

    _historyLog.info(
      'loadHistoryPage start',
      source: 'builds-view',
      data: {
        'projectId': projectId,
        'projectPath': projectPath,
        'page': page,
        'refreshLocal': refreshLocal,
      },
    );

    final loadStarted = Stopwatch()..start();
    _startHistoryLoadingCountdown();
    setState(() => _isLoadingHistory = true);

    try {
      var localEntries = _localHistoryEntries;
      if (refreshLocal || page == 1) {
        final local = await _archiveService.listArchives(projectId);
        localEntries = local.map(BuildHistoryEntry.fromLocal).toList();
      }

      if (!mounted || _loadedProjectId != projectId) return;

      final appSettings = context.read<AppSettingsState>();
      final gitStatus = context.read<ProjectManagerState>().gitRepositoryStatus;

      String? gitLabError;
      var yamlJobCount = _gitLabYamlJobCount;
      var gitlabEntries = _gitlabHistoryEntries;
      var gitLabPage = page;
      var gitLabTotalPages = _gitLabHistoryTotalPages;

      if (appSettings.gitlabSettings.enabled) {
        final connection = await _ensureGitLabConnection(appSettings);
        if (!mounted || _loadedProjectId != projectId) return;

        final result = await _gitlabCiService.listBuilds(
          settings: appSettings.gitlabSettings,
          connection: connection,
          gitStatus: gitStatus,
          projectRoot: projectPath,
          page: page,
        );
        gitlabEntries = result.builds.map(BuildHistoryEntry.fromGitLab).toList();
        gitLabError = result.error;
        yamlJobCount = result.buildJobNames.length;
        gitLabPage = result.currentPage;
        gitLabTotalPages = result.totalPages < 1 ? 1 : result.totalPages;

        _historyLog.info(
          'loadHistoryPage gitlab loaded',
          source: 'builds-view',
          data: {
            'projectPath': projectPath,
            'rawJobs': result.rawJobCount,
            'builds': gitlabEntries.length,
            'page': gitLabPage,
            'totalPages': gitLabTotalPages,
            'hasNextPage': result.hasNextPage,
            'error': result.error,
          },
        );
      } else {
        gitlabEntries = const [];
        gitLabPage = 1;
        gitLabTotalPages = 1;
      }

      if (!mounted || _loadedProjectId != projectId) return;

      if (gitLabError == null || !_isTransientGitLabError(gitLabError)) {
        _gitlabHistoryPageCache[gitLabPage] = _CachedGitLabHistoryPage(
          entries: gitlabEntries,
          totalPages: gitLabTotalPages,
          error: gitLabError,
          yamlJobCount: yamlJobCount,
        );
      }
      if (refreshLocal || page == 1) {
        _cachedLocalEntries = localEntries;
      }

      _applyHistoryState(
        projectId: projectId,
        localEntries: localEntries,
        gitlabEntries: gitlabEntries,
        gitLabError: gitLabError,
        yamlJobCount: yamlJobCount,
        gitLabPage: gitLabPage,
        gitLabTotalPages: gitLabTotalPages,
      );
    } finally {
      _stopHistoryLoadingCountdown(elapsedMs: loadStarted.elapsedMilliseconds);
      if (mounted && _loadedProjectId == projectId) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  List<BuildHistoryEntry> _mergedHistoryEntries({
    required List<BuildHistoryEntry> localEntries,
    required List<BuildHistoryEntry> gitlabEntries,
    required int gitLabPage,
  }) {
    final items = gitLabPage <= 1
        ? [...localEntries, ...gitlabEntries]
        : List<BuildHistoryEntry>.from(gitlabEntries);
    sortBuildHistoryEntries(items);
    return items;
  }

  void _applyHistoryState({
    required String projectId,
    required List<BuildHistoryEntry> localEntries,
    required List<BuildHistoryEntry> gitlabEntries,
    required String? gitLabError,
    required int yamlJobCount,
    required int gitLabPage,
    required int gitLabTotalPages,
  }) {
    final items = _mergedHistoryEntries(
      localEntries: localEntries,
      gitlabEntries: gitlabEntries,
      gitLabPage: gitLabPage,
    );

    setState(() {
      _localHistoryEntries = localEntries;
      _gitlabHistoryEntries = gitlabEntries;
      _history = items;
      _gitLabBuildsError = gitLabError;
      _gitLabYamlJobCount = yamlJobCount;
      _gitLabHistoryPage = gitLabPage;
      _gitLabHistoryTotalPages = math.max(
        _gitLabHistoryTotalPages,
        gitLabTotalPages < 1 ? 1 : gitLabTotalPages,
      );
      if (_selectedHistoryId != null &&
          !items.any((entry) => entry.id == _selectedHistoryId)) {
        _selectedHistoryId = null;
      }
      final visible = _filterHistory(items);
      if (_selectedHistoryId == null && visible.isNotEmpty) {
        _selectedHistoryId = visible.first.id;
      }
    });
  }

  List<BuildHistoryEntry> _filterHistory(List<BuildHistoryEntry> entries) {
    return entries.where((entry) {
      return switch (_historyFilter) {
        _HistoryFilter.all => true,
        _HistoryFilter.local => entry.isLocal,
        _HistoryFilter.gitlab => entry.isGitLab,
      };
    }).toList();
  }

  Future<List<String>> _loadGitLabArtifactDetails(
    BuildHistoryEntry entry,
  ) async {
    final jobId = entry.gitlabJobId;
    final projectPath = _loadedProjectPath;
    if (jobId == null || projectPath == null) return entry.artifactFiles;

    final files = await _gitlabCiService.loadArtifactFilesForJob(
      settings: context.read<AppSettingsState>().gitlabSettings,
      gitStatus: context.read<ProjectManagerState>().gitRepositoryStatus,
      jobId: jobId,
      projectRoot: projectPath,
    );
    return files.isEmpty ? entry.artifactFiles : files;
  }

  List<ProjectBuildConfig> _filterConfigs(List<ProjectBuildConfig> configs) {
    final query = _searchController.text.trim().toLowerCase();
    return configs.where((config) {
      if (query.isEmpty) return true;
      if (config.name.toLowerCase().contains(query)) return true;
      if (config.displayCommand.toLowerCase().contains(query)) return true;
      if (config.mode.name.toLowerCase().contains(query)) return true;
      if (_platformLabel(config).toLowerCase().contains(query)) return true;
      return false;
    }).toList();
  }

  List<ProjectBuildConfig> _mergeVisibleConfigs({
    required List<ProjectBuildConfig> scanned,
    required List<ProjectBuildConfig> gitlabCi,
  }) {
    if (gitlabCi.isEmpty) return scanned;

    final gitlabKeys = {
      for (final config in gitlabCi) _buildConfigDedupeKey(config),
    };

    final localOnly = scanned.where((config) {
      if (config.source == BuildConfigSource.gitlabCi) return false;
      return !gitlabKeys.contains(_buildConfigDedupeKey(config));
    });

    return [...gitlabCi, ...localOnly];
  }

  Future<void> _runGitLabPipeline(
    BuildContext context,
    ProjectBuildConfig config,
    String projectId,
    String projectPath,
  ) async {
    final l10n = context.l10n;
    final appSettings = context.read<AppSettingsState>();
    final gitStatus = context.read<ProjectManagerState>().gitRepositoryStatus;
    final ref = gitStatus?.branch?.trim();
    if (ref == null || ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.buildsGitLabPipelineFailed('No git branch'))),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _lastExitCode = null;
      _output
        ..clear()
        ..writeln('> ${l10n.buildsRunInGitLab}: ${config.name}')
        ..writeln('${l10n.buildsGitLabPipelineRef}: $ref');
    });

    try {
      final connection = await _ensureGitLabConnection(appSettings);
      if (!mounted) return;

      final result = await _gitlabCiService.triggerPipeline(
        settings: appSettings.gitlabSettings,
        connection: connection,
        gitStatus: gitStatus,
        ref: ref,
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (result.isSuccess) {
          _lastExitCode = 0;
          _output.writeln(
            '\n${l10n.buildsGitLabPipelineStarted(result.pipelineId!, result.webUrl ?? '')}',
          );
        } else {
          _lastExitCode = -1;
          _output.writeln(
            '\n${l10n.buildsGitLabPipelineFailed(result.error ?? 'Unknown error')}',
          );
        }
      });
      if (result.isSuccess) {
        await _refreshGitAndHistory(projectId, projectPath);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _lastExitCode = -1;
        _output.writeln('\n${l10n.buildsGitLabPipelineFailed('$error')}');
      });
    }
  }

  Future<void> _runConfig(
    BuildContext context,
    ProjectBuildConfig config,
    String projectId,
    String projectPath,
  ) async {
    final l10n = context.l10n;
    if (!config.canRunDirectly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.buildsCannotRun)),
      );
      return;
    }

    if (config.isGitLabCiJob) {
      await _runGitLabPipeline(context, config, projectId, projectPath);
      return;
    }

    setState(() {
      _isRunning = true;
      _lastExitCode = null;
      _output
        ..clear()
        ..writeln('> ${config.displayCommand}');
    });

    try {
      final exitCode = await _executionService.run(
        config: config,
        workingDirectory: projectPath,
        onOutput: (chunk) {
          if (!mounted) return;
          setState(() => _output.write(chunk));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_outputController.hasClients) {
              _outputController.jumpTo(_outputController.position.maxScrollExtent);
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _lastExitCode = exitCode;
        _output.writeln('\n${l10n.buildsFinished(exitCode)}');
      });

      if (exitCode == 0) {
        final entry = await _archiveService.archiveSuccessfulBuild(
          projectId: projectId,
          projectRoot: projectPath,
          config: config,
          buildOutput: _output.toString(),
          exitCode: exitCode,
        );
        if (!mounted) return;
        if (entry != null) {
          await _loadHistory(projectId, projectPath);
          if (!mounted) return;
          setState(() {
            _selectedHistoryId = 'local:${entry.id}';
            _historyFilter = _HistoryFilter.local;
            _page = _BuildsPage.history;
            _output.writeln('\n${l10n.buildsArchived(entry.projectVersion)}');
          });
        } else {
          setState(() {
            _output.writeln('\n${l10n.buildsArchiveFailed}');
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _lastExitCode = -1;
        _output.writeln('\n${l10n.buildsFailed(error)}');
      });
    }
  }

  Future<void> _stopBuild() async {
    await _executionService.cancel();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _lastExitCode = null;
      _output.writeln('\n${context.l10n.buildsStopped}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;
    final l10n = context.l10n;

    if (project == null) return const SizedBox.shrink();

    if (_loadedProjectPath != project.path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload(project.id, project.path, project.platforms);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          searchController: _searchController,
          onSearchChanged: (_) => setState(() {}),
          onRefresh: () => _reload(project.id, project.path, project.platforms),
          page: _page,
          onPageChanged: (page) => setState(() => _page = page),
        ),
        Expanded(
          child: _page == _BuildsPage.history
              ? _BuildHistoryPanel(
                  l10n: l10n,
                  entries: _filterHistory(_history),
                  allEntries: _history,
                  selectedEntryId: _selectedHistoryId,
                  historyFilter: _historyFilter,
                  isLoading: _isLoadingHistory,
                  loadingRemainingSeconds: _historyLoadingRemainingSeconds,
                  loadingElapsedSeconds: _historyLoadingElapsedSeconds,
                  gitLabError: context.watch<AppSettingsState>().isCheckingGitLab
                      ? null
                      : _gitLabBuildsError,
                  gitLabYamlJobCount: _gitLabYamlJobCount,
                  gitLabEnabled: context
                      .watch<AppSettingsState>()
                      .gitlabSettings
                      .enabled,
                  gitLabHistoryPage: _gitLabHistoryPage,
                  gitLabHistoryTotalPages: _gitLabHistoryTotalPages,
                  onFilterChanged: (filter) => setState(() {
                    _historyFilter = filter;
                    final visible = _filterHistory(_history);
                    if (_selectedHistoryId == null ||
                        !visible.any(
                          (entry) => entry.id == _selectedHistoryId,
                        )) {
                      _selectedHistoryId =
                          visible.isNotEmpty ? visible.first.id : null;
                    }
                  }),
                  onSelect: (id) => setState(() => _selectedHistoryId = id),
                  onRefresh: () =>
                      _refreshGitAndHistory(project.id, project.path),
                  onPageChanged: (page) => _loadHistoryPage(
                    project.id,
                    project.path,
                    page: page,
                  ),
                  onOpenFolder: openPathInExplorer,
                  onOpenUrl: openExternalUrl,
                  onDeleteLocal: (entry) =>
                      _deleteLocalArchive(context, project.id, entry),
                  onLoadGitLabArtifacts: _loadGitLabArtifactDetails,
                )
              : FutureBuilder<ProjectBuildScanResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: IdeaColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        l10n.buildsLoading,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: IdeaColors.error, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final result = snapshot.data;
              if (result == null) return const SizedBox.shrink();

              final allConfigs = _mergeVisibleConfigs(
                scanned: result.configs,
                gitlabCi: _gitlabCiConfigs,
              );
              final filtered = _filterConfigs(allConfigs);
              final selected = filtered.cast<ProjectBuildConfig?>().firstWhere(
                    (config) => config?.id == _selectedConfigId,
                    orElse: () => filtered.isNotEmpty ? filtered.first : null,
                  );

              if (_selectedConfigId == null && selected != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedConfigId = selected.id);
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _BuildsSummaryHeader(
                      l10n: l10n,
                      shownCount: filtered.length,
                      totalCount: allConfigs.length,
                      usingDefaults: result.usingDefaultConfigs,
                      platforms: result.resolvedPlatforms,
                      tasksJsonPath: result.tasksJsonPath,
                      errorMessage: result.errorMessage,
                      onOpenTasksJson: result.tasksJsonPath == null
                          ? null
                          : () => state.openFile(result.tasksJsonPath!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.buildsNoMatches,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                )
                              : _GroupedBuildConfigList(
                                  configs: filtered,
                                  selectedConfigId: _selectedConfigId,
                                  l10n: l10n,
                                  onSelect: (id) =>
                                      setState(() => _selectedConfigId = id),
                                  onRun: (config) => config.canRunDirectly &&
                                          !_isRunning
                                      ? () => _runConfig(
                                            context,
                                            config,
                                            project.id,
                                            project.path,
                                          )
                                      : null,
                                ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 4,
                          child: selected == null
                              ? Center(
                                  child: Text(
                                    l10n.buildsSelectPrompt,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                )
                              : _BuildDetailPanel(
                                  config: selected,
                                  l10n: l10n,
                                  isRunning: _isRunning,
                                  lastExitCode: _lastExitCode,
                                  output: _output.toString(),
                                  outputController: _outputController,
                                  gitBranch: state.gitRepositoryStatus?.branch,
                                  onRun: selected.canRunDirectly && !_isRunning
                                      ? () => _runConfig(
                                            context,
                                            selected,
                                            project.id,
                                            project.path,
                                          )
                                      : null,
                                  onStop: _isRunning && !selected.isGitLabCiJob
                                      ? _stopBuild
                                      : null,
                                  onOpenSource: selected.sourceFile == null
                                      ? null
                                      : () => state.openFile(selected.sourceFile!),
                                  onCopyCommand: () {
                                    Clipboard.setData(
                                      ClipboardData(text: selected.displayCommand),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.buildsCommandCopied),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLocalArchive(
    BuildContext context,
    String projectId,
    BuildHistoryEntry entry,
  ) async {
    if (!entry.isLocal) return;

    final archiveId = entry.id.replaceFirst('local:', '');
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.buildsDeleteArchive),
        content: Text(l10n.buildsDeleteArchiveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _archiveService.deleteArchive(
      projectId: projectId,
      archiveId: archiveId,
    );
    if (!mounted) return;
    await _loadHistory(projectId, _loadedProjectPath!);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.page,
    required this.onPageChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final _BuildsPage page;
  final ValueChanged<_BuildsPage> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_outlined,
                  size: 16, color: IdeaColors.accent),
              const SizedBox(width: 8),
              Text(l10n.tabBuilds, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 12),
              SegmentedButton<_BuildsPage>(
                segments: [
                  ButtonSegment(
                    value: _BuildsPage.configurations,
                    label: Text(l10n.buildsPageConfigurations),
                    icon: const Icon(Icons.tune, size: 14),
                  ),
                  ButtonSegment(
                    value: _BuildsPage.history,
                    label: Text(l10n.buildsPageHistory),
                    icon: const Icon(Icons.history, size: 14),
                  ),
                ],
                selected: {page},
                onSelectionChanged: (selection) =>
                    onPageChanged(selection.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.refreshBuilds,
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (page == _BuildsPage.configurations) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 12, color: IdeaColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.buildsSearchHint,
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: IdeaColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 28),
                  filled: true,
                  fillColor: IdeaColors.inputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _platformDisplayOrder = <String>[
  'Android',
  'iOS',
  'Windows',
  'Web',
  'Linux',
  'macOS',
  'GitLab CI',
  'Other',
];

class _BuildsSummaryHeader extends StatelessWidget {
  const _BuildsSummaryHeader({
    required this.l10n,
    required this.shownCount,
    required this.totalCount,
    required this.usingDefaults,
    required this.platforms,
    this.tasksJsonPath,
    this.errorMessage,
    this.onOpenTasksJson,
  });

  final AppLocalizations l10n;
  final int shownCount;
  final int totalCount;
  final bool usingDefaults;
  final List<String> platforms;
  final String? tasksJsonPath;
  final String? errorMessage;
  final VoidCallback? onOpenTasksJson;

  @override
  Widget build(BuildContext context) {
    final defaultsHint = platforms.isEmpty
        ? l10n.buildsUsingDefaultsNoPlatforms
        : l10n.buildsUsingDefaultsForPlatforms(platforms.join(', '));

    return DocSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: IdeaColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: IdeaColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.construction_outlined,
                  size: 18,
                  color: IdeaColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.buildsSummary(shownCount, totalCount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: IdeaColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: l10n.buildsStageBuildOnly,
                          color: IdeaColors.success,
                        ),
                        if (usingDefaults)
                          _Badge(
                            label: l10n.buildsSourceDefault,
                            color: IdeaColors.warning,
                          ),
                        if (tasksJsonPath != null)
                          _Badge(
                            label: l10n.buildsSourceTasks,
                            color: IdeaColors.accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onOpenTasksJson != null)
                TextButton.icon(
                  onPressed: onOpenTasksJson,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(l10n.buildsOpenTasksJson),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          if (usingDefaults) ...[
            const SizedBox(height: 10),
            Text(
              defaultsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 11, color: IdeaColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupedBuildConfigList extends StatelessWidget {
  const _GroupedBuildConfigList({
    required this.configs,
    required this.selectedConfigId,
    required this.l10n,
    required this.onSelect,
    required this.onRun,
  });

  final List<ProjectBuildConfig> configs;
  final String? selectedConfigId;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelect;
  final VoidCallback? Function(ProjectBuildConfig config) onRun;

  Map<String, List<ProjectBuildConfig>> _groupByPlatform() {
    final grouped = <String, List<ProjectBuildConfig>>{};
    for (final config in configs) {
      final label = _platformLabel(config);
      grouped.putIfAbsent(label, () => []).add(config);
    }
    for (final items in grouped.values) {
      items.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  List<String> _orderedPlatforms(Map<String, List<ProjectBuildConfig>> grouped) {
    final ordered = _platformDisplayOrder
        .where((platform) => grouped.containsKey(platform))
        .toList();
    for (final platform in grouped.keys) {
      if (!ordered.contains(platform)) ordered.add(platform);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByPlatform();
    final platforms = _orderedPlatforms(grouped);

    return CustomScrollView(
      slivers: [
        for (final platform in platforms) ...[
          SliverToBoxAdapter(
            child: _PlatformSectionHeader(
              label: platform,
              icon: _platformIcon(platform),
              color: _platformColor(platform),
              count: grouped[platform]!.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final config = grouped[platform]![index];
                  final color = _platformColor(platform);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BuildConfigTile(
                      config: config,
                      isSelected: config.id == selectedConfigId,
                      l10n: l10n,
                      platformColor: color,
                      platformIcon: _platformIcon(platform),
                      onTap: () => onSelect(config.id),
                      onRun: onRun(config),
                    ),
                  );
                },
                childCount: grouped[platform]!.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }
}

class _PlatformSectionHeader extends StatelessWidget {
  const _PlatformSectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildConfigTile extends StatelessWidget {
  const _BuildConfigTile({
    required this.config,
    required this.isSelected,
    required this.l10n,
    required this.platformColor,
    required this.platformIcon,
    required this.onTap,
    required this.onRun,
  });

  final ProjectBuildConfig config;
  final bool isSelected;
  final AppLocalizations l10n;
  final Color platformColor;
  final IconData platformIcon;
  final VoidCallback onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? IdeaColors.accent.withValues(alpha: 0.06)
          : IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? IdeaColors.accent : IdeaColors.panelBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: platformColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(platformIcon, size: 17, color: platformColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: IdeaColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.displayCommand,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        color: IdeaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: _sourceLabel(l10n, config.source),
                          color: IdeaColors.accent,
                        ),
                        _Badge(
                          label: _modeLabel(l10n, config.mode),
                          color: _modeColor(config.mode),
                        ),
                        if (config.preLaunchTask != null)
                          _Badge(
                            label: l10n.buildsPreLaunchTask(config.preLaunchTask!),
                            color: IdeaColors.warning,
                          ),
                        if (config.isBackground)
                          _Badge(
                            label: l10n.buildsBackgroundTask,
                            color: IdeaColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onRun != null)
                IconButton(
                  tooltip: l10n.buildsRun,
                  onPressed: onRun,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: IdeaColors.success),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildDetailPanel extends StatelessWidget {
  const _BuildDetailPanel({
    required this.config,
    required this.l10n,
    required this.isRunning,
    required this.lastExitCode,
    required this.output,
    required this.outputController,
    this.gitBranch,
    required this.onRun,
    required this.onStop,
    required this.onOpenSource,
    required this.onCopyCommand,
  });

  final ProjectBuildConfig config;
  final AppLocalizations l10n;
  final bool isRunning;
  final int? lastExitCode;
  final String output;
  final ScrollController outputController;
  final String? gitBranch;
  final VoidCallback? onRun;
  final VoidCallback? onStop;
  final VoidCallback? onOpenSource;
  final VoidCallback onCopyCommand;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IdeaColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DocSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: l10n.buildsLabelSource, value: _sourceLabel(l10n, config.source)),
                        _DetailRow(label: l10n.buildsLabelMode, value: _modeLabel(l10n, config.mode)),
                        if (config.type != null)
                          _DetailRow(label: l10n.buildsLabelType, value: config.type!),
                        if (config.program != null)
                          _DetailRow(label: l10n.buildsLabelProgram, value: config.program!),
                        if (config.deviceId != null)
                          _DetailRow(label: l10n.buildsLabelDevice, value: config.deviceId!),
                        if (config.preLaunchTask != null)
                          _DetailRow(
                            label: l10n.buildsLabelPreLaunch,
                            value: config.preLaunchTask!,
                          ),
                        if (config.isGitLabCiJob && gitBranch != null)
                          _DetailRow(
                            label: l10n.buildsGitLabPipelineRef,
                            value: gitBranch!,
                          ),
                        if (config.taskGroup != null)
                          _DetailRow(label: l10n.buildsLabelTaskGroup, value: config.taskGroup!),
                        if (config.childConfigurationNames.isNotEmpty)
                          _DetailRow(
                            label: l10n.buildsLabelChildren,
                            value: config.childConfigurationNames.join(', '),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.buildsLabelCommand,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          config.displayCommand,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            color: IdeaColors.textBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onRun != null)
                        FilledButton.icon(
                          onPressed: onRun,
                          icon: Icon(
                            config.isGitLabCiJob
                                ? Icons.cloud_upload_outlined
                                : Icons.play_arrow,
                            size: 16,
                          ),
                          label: Text(
                            config.isGitLabCiJob
                                ? l10n.buildsRunInGitLab
                                : l10n.buildsRun,
                          ),
                        ),
                      if (onStop != null && !config.isGitLabCiJob)
                        OutlinedButton.icon(
                          onPressed: onStop,
                          icon: const Icon(Icons.stop, size: 16),
                          label: Text(l10n.buildsStop),
                        ),
                      OutlinedButton.icon(
                        onPressed: onCopyCommand,
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(l10n.buildsCopyCommand),
                      ),
                      if (onOpenSource != null)
                        OutlinedButton.icon(
                          onPressed: onOpenSource,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(l10n.buildsOpenSource),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  l10n.buildsOutput,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (isRunning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IdeaColors.accent,
                    ),
                  )
                else if (lastExitCode != null)
                  Text(
                    l10n.buildsExitCode(lastExitCode!),
                    style: TextStyle(
                      fontSize: 11,
                      color: lastExitCode == 0
                          ? IdeaColors.success
                          : IdeaColors.error,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IdeaColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: IdeaColors.panelBorder),
              ),
              child: SingleChildScrollView(
                controller: outputController,
                child: SelectableText(
                  output.isEmpty ? l10n.buildsOutputEmpty : output,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: output.isEmpty
                        ? IdeaColors.textSecondary
                        : IdeaColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: IdeaColors.textBright),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _sourceLabel(AppLocalizations l10n, BuildConfigSource source) {
  return switch (source) {
    BuildConfigSource.tasksJson => l10n.buildsSourceTasks,
    BuildConfigSource.flutterDefault => l10n.buildsSourceDefault,
    BuildConfigSource.gitlabCi => l10n.buildsSourceGitLabCi,
  };
}

String _modeLabel(AppLocalizations l10n, BuildRunMode mode) {
  return switch (mode) {
    BuildRunMode.debug => l10n.buildsModeDebug,
    BuildRunMode.profile => l10n.buildsModeProfile,
    BuildRunMode.release => l10n.buildsModeRelease,
    BuildRunMode.attach => l10n.buildsModeAttach,
    BuildRunMode.build => l10n.buildsModeBuild,
    BuildRunMode.test => l10n.buildsModeTest,
    BuildRunMode.compound => l10n.buildsModeCompound,
    BuildRunMode.custom => l10n.buildsModeCustom,
  };
}

Color _modeColor(BuildRunMode mode) {
  return switch (mode) {
    BuildRunMode.debug => IdeaColors.accent,
    BuildRunMode.profile => IdeaColors.warning,
    BuildRunMode.release => IdeaColors.success,
    BuildRunMode.attach => IdeaColors.textSecondary,
    BuildRunMode.build => IdeaColors.success,
    BuildRunMode.test => IdeaColors.accent,
    BuildRunMode.compound => IdeaColors.warning,
    BuildRunMode.custom => IdeaColors.textSecondary,
  };
}

class _BuildHistoryPanel extends StatelessWidget {
  const _BuildHistoryPanel({
    required this.l10n,
    required this.entries,
    required this.allEntries,
    required this.selectedEntryId,
    required this.historyFilter,
    required this.isLoading,
    this.loadingRemainingSeconds,
    this.loadingElapsedSeconds,
    required this.gitLabError,
    required this.gitLabYamlJobCount,
    required this.gitLabEnabled,
    required this.gitLabHistoryPage,
    required this.gitLabHistoryTotalPages,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onRefresh,
    required this.onPageChanged,
    required this.onOpenFolder,
    required this.onOpenUrl,
    required this.onDeleteLocal,
    required this.onLoadGitLabArtifacts,
  });

  final AppLocalizations l10n;
  final List<BuildHistoryEntry> entries;
  final List<BuildHistoryEntry> allEntries;
  final String? selectedEntryId;
  final _HistoryFilter historyFilter;
  final bool isLoading;
  final int? loadingRemainingSeconds;
  final int? loadingElapsedSeconds;
  final String? gitLabError;
  final int gitLabYamlJobCount;
  final bool gitLabEnabled;
  final int gitLabHistoryPage;
  final int gitLabHistoryTotalPages;
  final ValueChanged<_HistoryFilter> onFilterChanged;
  final ValueChanged<String> onSelect;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(String path) onOpenFolder;
  final Future<void> Function(String url) onOpenUrl;
  final ValueChanged<BuildHistoryEntry> onDeleteLocal;
  final Future<List<String>> Function(BuildHistoryEntry entry)
      onLoadGitLabArtifacts;

  bool get _showPageTabs =>
      gitLabEnabled &&
      historyFilter != _HistoryFilter.local &&
      gitLabHistoryTotalPages > 1;

  String _historyLoadingMessage(AppLocalizations l10n) {
    final remaining = loadingRemainingSeconds;
    if (remaining == null) return l10n.buildsLoadingGitLabBuilds;
    if (remaining > 0) return l10n.buildsHistoryLoadingCountdown(remaining);
    final elapsed = loadingElapsedSeconds;
    if (elapsed != null) return l10n.buildsHistoryLoadingElapsed(elapsed);
    return l10n.buildsLoadingGitLabBuilds;
  }

  String? _historyLoadingShortLabel(AppLocalizations l10n) {
    final remaining = loadingRemainingSeconds;
    if (remaining == null) return null;
    if (remaining > 0) {
      return l10n.buildsHistoryLoadingCountdownShort(remaining);
    }
    final elapsed = loadingElapsedSeconds;
    if (elapsed != null) {
      return l10n.buildsHistoryLoadingElapsedShort(elapsed);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = entries.cast<BuildHistoryEntry?>().firstWhere(
          (entry) => entry?.id == selectedEntryId,
          orElse: () => null,
        );

    return ColoredBox(
      color: IdeaColors.toolbar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  l10n.buildsHistory,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 12),
                if (isLoading) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IdeaColors.accent,
                    ),
                  ),
                  if (loadingRemainingSeconds != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _historyLoadingShortLabel(l10n) ?? '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: IdeaColors.textSecondary,
                          ),
                    ),
                  ],
                ],
                const Spacer(),
                IconButton(
                  tooltip: l10n.refreshBuilds,
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final filter in _HistoryFilter.values)
                  FilterChip(
                    label: Text(_historyFilterLabel(l10n, filter)),
                    selected: historyFilter == filter,
                    onSelected: (_) => onFilterChanged(filter),
                  ),
              ],
            ),
          ),
          if (_showPageTabs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _HistoryPageTabs(
                l10n: l10n,
                currentPage: gitLabHistoryPage,
                totalPages: gitLabHistoryTotalPages,
                isLoading: isLoading,
                onPageSelected: onPageChanged,
              ),
            ),
          if (gitLabEnabled && gitLabYamlJobCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                l10n.buildsGitLabJobsFromYaml(gitLabYamlJobCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (gitLabEnabled && gitLabError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                gitLabError!,
                style: const TextStyle(color: IdeaColors.warning, fontSize: 11),
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: isLoading
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: IdeaColors.accent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _historyLoadingMessage(l10n),
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Text(
                            allEntries.isEmpty
                                ? (gitLabEnabled
                                    ? l10n.buildsHistoryEmpty
                                    : l10n.buildsGitLabBuildsHint)
                                : l10n.buildsNoMatches,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _GroupedBuildHistoryList(
                          entries: entries,
                          selectedEntryId: selectedEntryId,
                          l10n: l10n,
                          onSelect: onSelect,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 4,
                        child: selected == null
                            ? Center(
                                child: Text(
                                  l10n.buildsHistorySelectArchive,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            : _BuildHistoryDetailPanel(
                                entry: selected,
                                l10n: l10n,
                                onOpenFolder: onOpenFolder,
                                onOpenUrl: onOpenUrl,
                                onDeleteLocal: onDeleteLocal,
                                onLoadGitLabArtifacts: onLoadGitLabArtifacts,
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPageTabs extends StatelessWidget {
  const _HistoryPageTabs({
    required this.l10n,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageSelected,
  });

  final AppLocalizations l10n;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: l10n.buildsHistoryPreviousPage,
          onPressed: !isLoading && currentPage > 1
              ? () => onPageSelected(currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var page = 1; page <= totalPages; page++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$page'),
                      selected: page == currentPage,
                      onSelected: isLoading
                          ? null
                          : (_) => onPageSelected(page),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: page == currentPage
                            ? IdeaColors.textBright
                            : IdeaColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.buildsHistoryNextPage,
          onPressed: !isLoading && currentPage < totalPages
              ? () => onPageSelected(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        Text(
          l10n.buildsHistoryPageInfo(currentPage, totalPages),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _GroupedBuildHistoryList extends StatelessWidget {
  const _GroupedBuildHistoryList({
    required this.entries,
    required this.selectedEntryId,
    required this.l10n,
    required this.onSelect,
  });

  final List<BuildHistoryEntry> entries;
  final String? selectedEntryId;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelect;

  Map<String, List<BuildHistoryEntry>> _groupByPlatform() {
    final grouped = <String, List<BuildHistoryEntry>>{};
    for (final entry in entries) {
      final label = _normalizePlatformLabel(entry.platform);
      grouped.putIfAbsent(label, () => []).add(entry);
    }
    for (final items in grouped.values) {
      sortBuildHistoryEntries(items);
    }
    return grouped;
  }

  List<String> _orderedPlatforms(Map<String, List<BuildHistoryEntry>> grouped) {
    final ordered = _platformDisplayOrder
        .where((platform) => grouped.containsKey(platform))
        .toList();
    for (final platform in grouped.keys) {
      if (!ordered.contains(platform)) ordered.add(platform);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByPlatform();
    final platforms = _orderedPlatforms(grouped);

    return CustomScrollView(
      slivers: [
        for (final platform in platforms) ...[
          SliverToBoxAdapter(
            child: _PlatformSectionHeader(
              label: platform,
              icon: _platformIcon(platform),
              color: _platformColor(platform),
              count: grouped[platform]!.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = grouped[platform]![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BuildHistoryTile(
                      entry: entry,
                      isSelected: entry.id == selectedEntryId,
                      l10n: l10n,
                      platformColor: _platformColor(platform),
                      platformIcon: _platformIcon(platform),
                      onTap: () => onSelect(entry.id),
                    ),
                  );
                },
                childCount: grouped[platform]!.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }
}

class _BuildHistoryTile extends StatelessWidget {
  const _BuildHistoryTile({
    required this.entry,
    required this.isSelected,
    required this.l10n,
    required this.platformColor,
    required this.platformIcon,
    required this.onTap,
  });

  final BuildHistoryEntry entry;
  final bool isSelected;
  final AppLocalizations l10n;
  final Color platformColor;
  final IconData platformIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasVersion = _hasKnownVersion(entry.projectVersion);
    final primaryLabel =
        hasVersion ? 'v${entry.projectVersion}' : entry.configName;

    return Material(
      color: isSelected
          ? IdeaColors.accent.withValues(alpha: 0.06)
          : IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? IdeaColors.accent : IdeaColors.panelBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: platformColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(platformIcon, size: 17, color: platformColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: IdeaColors.textBright,
                            ),
                          ),
                        ),
                        _HistorySourceBadge(
                          label: entry.isLocal
                              ? l10n.buildsHistorySourceLocal
                              : l10n.buildsHistorySourceGitLab,
                          color: entry.isLocal
                              ? IdeaColors.success
                              : IdeaColors.accent,
                        ),
                      ],
                    ),
                    if (hasVersion) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.configName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: IdeaColors.textPrimary,
                        ),
                      ),
                    ],
                    if (entry.isGitLab && entry.gitlabRef != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.gitlabRef!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: IdeaColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArchiveDate(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: IdeaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildHistoryDetailPanel extends StatefulWidget {
  const _BuildHistoryDetailPanel({
    required this.entry,
    required this.l10n,
    required this.onOpenFolder,
    required this.onOpenUrl,
    required this.onDeleteLocal,
    required this.onLoadGitLabArtifacts,
  });

  final BuildHistoryEntry entry;
  final AppLocalizations l10n;
  final Future<void> Function(String path) onOpenFolder;
  final Future<void> Function(String url) onOpenUrl;
  final ValueChanged<BuildHistoryEntry> onDeleteLocal;
  final Future<List<String>> Function(BuildHistoryEntry entry)
      onLoadGitLabArtifacts;

  @override
  State<_BuildHistoryDetailPanel> createState() =>
      _BuildHistoryDetailPanelState();
}

class _BuildHistoryDetailPanelState extends State<_BuildHistoryDetailPanel> {
  List<String>? _artifactFiles;
  bool _loadingArtifacts = false;

  @override
  void initState() {
    super.initState();
    _artifactFiles = widget.entry.artifactFiles;
    _maybeLoadArtifacts();
  }

  @override
  void didUpdateWidget(covariant _BuildHistoryDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _artifactFiles = widget.entry.artifactFiles;
      _maybeLoadArtifacts();
    }
  }

  Future<void> _maybeLoadArtifacts() async {
    if (!widget.entry.needsGitLabArtifactDetailLoad) return;

    setState(() => _loadingArtifacts = true);
    try {
      final entryId = widget.entry.id;
      final files = await widget.onLoadGitLabArtifacts(widget.entry);
      if (!mounted || widget.entry.id != entryId) return;
      if (files.isNotEmpty) {
        setState(() => _artifactFiles = files);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingArtifacts = false);
      }
    }
  }

  List<String> get _displayFiles =>
      _artifactFiles ?? widget.entry.artifactFiles;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final l10n = widget.l10n;
    final onOpenFolder = widget.onOpenFolder;
    final onOpenUrl = widget.onOpenUrl;
    final onDeleteLocal = widget.onDeleteLocal;

    return ColoredBox(
      color: IdeaColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _historyDetailTitle(entry),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (entry.isLocal)
                  TextButton.icon(
                    onPressed: () => onOpenFolder(entry.artifactsDirectory!),
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: Text(l10n.buildsOpenArchiveFolder),
                  ),
                if (entry.isGitLab) ...[
                  TextButton.icon(
                    onPressed: entry.gitlabJobWebUrl == null
                        ? null
                        : () => onOpenUrl(entry.gitlabJobWebUrl!),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(l10n.buildsOpenInGitLab),
                  ),
                  TextButton.icon(
                    onPressed: entry.gitlabArtifactsDownloadUrl == null
                        ? null
                        : () => onOpenUrl(entry.gitlabArtifactsDownloadUrl!),
                    icon: const Icon(Icons.download, size: 14),
                    label: Text(l10n.buildsDownloadArtifacts),
                  ),
                ],
                if (entry.isLocal)
                  IconButton(
                    tooltip: l10n.buildsDeleteArchive,
                    onPressed: () => onDeleteLocal(entry),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: IdeaColors.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  l10n.buildsHistoryFiles(_displayFiles.length),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (_loadingArtifacts) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IdeaColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _displayFiles.length,
              itemBuilder: (context, index) {
                final file = _displayFiles[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (entry.isLocal) {
                        onOpenFolder(
                          p.join(entry.artifactsDirectory!, file),
                        );
                        return;
                      }
                      final url = entry.gitlabArtifactFileWebUrl(file);
                      if (url != null) onOpenUrl(url);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 14,
                            color: IdeaColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                color: IdeaColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySourceBadge extends StatelessWidget {
  const _HistorySourceBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _historyFilterLabel(AppLocalizations l10n, _HistoryFilter filter) {
  return switch (filter) {
    _HistoryFilter.all => l10n.buildsHistoryFilterAll,
    _HistoryFilter.local => l10n.buildsHistoryFilterLocal,
    _HistoryFilter.gitlab => l10n.buildsHistoryFilterGitLab,
  };
}

String _platformLabel(ProjectBuildConfig config) {
  final haystack =
      '${config.name} ${config.displayCommand}'.toLowerCase();

  for (final entry in kFlutterPlatformFolders.entries) {
    if (haystack.contains(entry.key) ||
        haystack.contains(entry.value.toLowerCase())) {
      return entry.value;
    }
  }
  if (haystack.contains('apk') ||
      haystack.contains('appbundle') ||
      haystack.contains('android')) {
    return 'Android';
  }
  if (config.isGitLabCiJob) return 'GitLab CI';
  return 'Other';
}

String _normalizePlatformLabel(String platform) {
  final lower = platform.trim().toLowerCase();
  for (final entry in kFlutterPlatformFolders.entries) {
    if (lower == entry.key || lower == entry.value.toLowerCase()) {
      return entry.value;
    }
  }
  if (lower == 'gitlab ci' || lower == 'gitlab') return 'GitLab CI';
  if (lower.isEmpty || lower == 'other') return 'Other';
  return platform;
}

String _buildConfigDedupeKey(ProjectBuildConfig config) {
  return config.name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s:_-]+'), '');
}

bool _hasKnownVersion(String version) {
  final normalized = version.trim().toLowerCase();
  return normalized.isNotEmpty && normalized != 'unknown';
}

String _historyDetailTitle(BuildHistoryEntry entry) {
  if (_hasKnownVersion(entry.projectVersion)) {
    return '${entry.configName} · v${entry.projectVersion}';
  }
  return entry.configName;
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'Android' => Icons.android,
    'iOS' => Icons.phone_iphone,
    'Windows' => Icons.desktop_windows_outlined,
    'Web' => Icons.language,
    'Linux' => Icons.computer_outlined,
    'macOS' => Icons.laptop_mac_outlined,
    'GitLab CI' => Icons.cloud_outlined,
    _ => Icons.build_outlined,
  };
}

Color _platformColor(String platform) {
  return switch (platform) {
    'Android' => const Color(0xFF3DDC84),
    'iOS' => const Color(0xFF8E8E93),
    'Windows' => const Color(0xFF0078D4),
    'Web' => const Color(0xFFFF9800),
    'Linux' => const Color(0xFFFFC107),
    'macOS' => const Color(0xFFA2AAAD),
    'GitLab CI' => const Color(0xFFFC6D26),
    _ => IdeaColors.textSecondary,
  };
}

String _formatArchiveDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

class _CachedGitLabHistoryPage {
  const _CachedGitLabHistoryPage({
    required this.entries,
    required this.totalPages,
    required this.yamlJobCount,
    this.error,
  });

  final List<BuildHistoryEntry> entries;
  final int totalPages;
  final int yamlJobCount;
  final String? error;
}
