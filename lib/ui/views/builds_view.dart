import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_history_entry.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/build_archive_service.dart';
import 'package:project_manager/services/build_execution_service.dart';
import 'package:project_manager/services/gitlab_ci_build_service.dart';
import 'package:project_manager/services/vscode_build_config_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:provider/provider.dart';

enum _BuildFilter {
  all,
  tasks,
  defaults,
  gitlabCi,
}

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
  _BuildFilter _filter = _BuildFilter.all;
  _HistoryFilter _historyFilter = _HistoryFilter.all;
  _BuildsPage _page = _BuildsPage.configurations;
  bool _isRunning = false;
  bool _isLoadingHistory = false;
  int? _lastExitCode;
  List<BuildHistoryEntry> _history = const [];
  List<ProjectBuildConfig> _gitlabCiConfigs = const [];
  String? _gitLabBuildsError;
  int _gitLabYamlJobCount = 0;
  final StringBuffer _output = StringBuffer();

  @override
  void dispose() {
    _searchController.dispose();
    _outputController.dispose();
    _executionService.cancel();
    super.dispose();
  }

  void _reload(String projectId, String projectPath, List<String> platforms) {
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
    final gitLabBaseUrl = context.read<AppSettingsState>().gitlabSettings.enabled
        ? context.read<AppSettingsState>().gitlabSettings.normalizedBaseUrl
        : null;
    await context.read<ProjectManagerState>().refreshGitStatus(
          configuredGitLabBaseUrl: gitLabBaseUrl,
        );
    if (!mounted || _loadedProjectId != projectId) return;
    await _loadGitLabCiConfigs(projectPath);
    if (!mounted || _loadedProjectId != projectId) return;
    await _loadHistory(projectId, projectPath);
  }

  Future<void> _loadGitLabCiConfigs(String projectPath) async {
    final appSettings = context.read<AppSettingsState>();
    final gitStatus = context.read<ProjectManagerState>().gitRepositoryStatus;

    if (!appSettings.gitlabSettings.enabled) {
      setState(() => _gitlabCiConfigs = const []);
      return;
    }

    final configs = await _gitlabCiService.listCiJobConfigs(
      settings: appSettings.gitlabSettings,
      connection: appSettings.lastGitLabCheck,
      gitStatus: gitStatus,
      projectRoot: projectPath,
    );

    if (!mounted || _loadedProjectPath != projectPath) return;
    setState(() => _gitlabCiConfigs = configs);
  }

  Future<void> _loadHistory(String projectId, String projectPath) async {
    setState(() => _isLoadingHistory = true);

    try {
      final local = await _archiveService.listArchives(projectId);
      final items = local.map(BuildHistoryEntry.fromLocal).toList();

      String? gitLabError;
      var yamlJobCount = 0;

      if (!mounted || _loadedProjectId != projectId) return;

      final appSettings = context.read<AppSettingsState>();
      final gitStatus = context.read<ProjectManagerState>().gitRepositoryStatus;

      if (appSettings.gitlabSettings.enabled) {
        final result = await _gitlabCiService.listBuilds(
          settings: appSettings.gitlabSettings,
          connection: appSettings.lastGitLabCheck,
          gitStatus: gitStatus,
          projectRoot: projectPath,
        );
        items.addAll(result.builds.map(BuildHistoryEntry.fromGitLab));
        gitLabError = result.error;
        yamlJobCount = result.buildJobNames.length;
      }

      if (!mounted || _loadedProjectId != projectId) return;

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _history = items;
        _gitLabBuildsError = gitLabError;
        _gitLabYamlJobCount = yamlJobCount;
        if (_selectedHistoryId != null &&
            !items.any((entry) => entry.id == _selectedHistoryId)) {
          _selectedHistoryId = null;
        }
        final visible = _filterHistory(items);
        if (_selectedHistoryId == null && visible.isNotEmpty) {
          _selectedHistoryId = visible.first.id;
        }
      });
    } finally {
      if (mounted && _loadedProjectId == projectId) {
        setState(() => _isLoadingHistory = false);
      }
    }
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

  List<ProjectBuildConfig> _filterConfigs(List<ProjectBuildConfig> configs) {
    final query = _searchController.text.trim().toLowerCase();
    return configs.where((config) {
      if (!_matchesFilter(config)) return false;
      if (query.isEmpty) return true;
      if (config.name.toLowerCase().contains(query)) return true;
      if (config.displayCommand.toLowerCase().contains(query)) return true;
      if (config.mode.name.toLowerCase().contains(query)) return true;
      return false;
    }).toList();
  }

  bool _matchesFilter(ProjectBuildConfig config) {
    return switch (_filter) {
      _BuildFilter.all => true,
      _BuildFilter.tasks => config.source == BuildConfigSource.tasksJson,
      _BuildFilter.defaults =>
        config.source == BuildConfigSource.flutterDefault,
      _BuildFilter.gitlabCi => config.source == BuildConfigSource.gitlabCi,
    };
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
      final result = await _gitlabCiService.triggerPipeline(
        settings: appSettings.gitlabSettings,
        connection: appSettings.lastGitLabCheck,
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
                  gitLabError: _gitLabBuildsError,
                  gitLabYamlJobCount: _gitLabYamlJobCount,
                  gitLabEnabled: context
                      .watch<AppSettingsState>()
                      .gitlabSettings
                      .enabled,
                  onFilterChanged: (filter) => setState(() {
                    _historyFilter = filter;
                    final visible = _filterHistory(_history);
                    if (_selectedHistoryId == null ||
                        !visible.any((entry) => entry.id == _selectedHistoryId)) {
                      _selectedHistoryId =
                          visible.isNotEmpty ? visible.first.id : null;
                    }
                  }),
                  onSelect: (id) => setState(() => _selectedHistoryId = id),
                  onRefresh: () =>
                      _refreshGitAndHistory(project.id, project.path),
                  onOpenFolder: openPathInExplorer,
                  onOpenUrl: openExternalUrl,
                  onDeleteLocal: (entry) =>
                      _deleteLocalArchive(context, project.id, entry),
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

              final allConfigs = [
                ...result.configs,
                ..._gitlabCiConfigs,
              ];
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.buildsSummary(
                                  filtered.length,
                                  allConfigs.length,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (result.tasksJsonPath != null)
                              TextButton.icon(
                                onPressed: () =>
                                    state.openFile(result.tasksJsonPath!),
                                icon: const Icon(Icons.task_alt, size: 14),
                                label: Text(l10n.buildsOpenTasksJson),
                              ),
                          ],
                        ),
                        if (result.usingDefaultConfigs)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              result.resolvedPlatforms.isEmpty
                                  ? l10n.buildsUsingDefaultsNoPlatforms
                                  : l10n.buildsUsingDefaultsForPlatforms(
                                      result.resolvedPlatforms.join(', '),
                                    ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (result.errorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            result.errorMessage!,
                            style: const TextStyle(
                              color: IdeaColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final filter in _BuildFilter.values)
                              if (filter != _BuildFilter.defaults ||
                                  result.usingDefaultConfigs)
                                if (filter != _BuildFilter.gitlabCi ||
                                    _gitlabCiConfigs.isNotEmpty)
                                  FilterChip(
                                    label: Text(_filterLabel(l10n, filter)),
                                    selected: _filter == filter,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter),
                                  ),
                          ],
                        ),
                      ],
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
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final config = filtered[index];
                                    return _BuildConfigTile(
                                      config: config,
                                      isSelected: config.id == _selectedConfigId,
                                      l10n: l10n,
                                      onTap: () => setState(
                                        () => _selectedConfigId = config.id,
                                      ),
                                      onRun: config.canRunDirectly && !_isRunning
                                          ? () => _runConfig(
                                                context,
                                                config,
                                                project.id,
                                                project.path,
                                              )
                                          : null,
                                    );
                                  },
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

  String _filterLabel(AppLocalizations l10n, _BuildFilter filter) {
    return switch (filter) {
      _BuildFilter.all => l10n.buildsFilterAll,
      _BuildFilter.tasks => l10n.buildsFilterTasks,
      _BuildFilter.defaults => l10n.buildsFilterDefaults,
      _BuildFilter.gitlabCi => l10n.buildsFilterGitLabCi,
    };
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

class _BuildConfigTile extends StatelessWidget {
  const _BuildConfigTile({
    required this.config,
    required this.isSelected,
    required this.l10n,
    required this.onTap,
    required this.onRun,
  });

  final ProjectBuildConfig config;
  final bool isSelected;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
            children: [
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
                  icon: const Icon(Icons.play_arrow, color: IdeaColors.success),
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
          Padding(
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
    required this.gitLabError,
    required this.gitLabYamlJobCount,
    required this.gitLabEnabled,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onRefresh,
    required this.onOpenFolder,
    required this.onOpenUrl,
    required this.onDeleteLocal,
  });

  final AppLocalizations l10n;
  final List<BuildHistoryEntry> entries;
  final List<BuildHistoryEntry> allEntries;
  final String? selectedEntryId;
  final _HistoryFilter historyFilter;
  final bool isLoading;
  final String? gitLabError;
  final int gitLabYamlJobCount;
  final bool gitLabEnabled;
  final ValueChanged<_HistoryFilter> onFilterChanged;
  final ValueChanged<String> onSelect;
  final VoidCallback onRefresh;
  final Future<void> Function(String path) onOpenFolder;
  final Future<void> Function(String url) onOpenUrl;
  final ValueChanged<BuildHistoryEntry> onDeleteLocal;

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
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IdeaColors.accent,
                    ),
                  ),
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
                    child: Text(
                      isLoading
                          ? l10n.buildsLoadingGitLabBuilds
                          : (allEntries.isEmpty
                              ? (gitLabEnabled
                                  ? l10n.buildsHistoryEmpty
                                  : l10n.buildsGitLabBuildsHint)
                              : l10n.buildsNoMatches),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final isSelected = entry.id == selectedEntryId;
                            return Material(
                              color: isSelected
                                  ? IdeaColors.accent.withValues(alpha: 0.12)
                                  : IdeaColors.sidebar,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isSelected
                                      ? IdeaColors.accent
                                      : IdeaColors.panelBorder,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => onSelect(entry.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'v${entry.projectVersion}',
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
                                          const SizedBox(width: 6),
                                          Text(
                                            entry.platform,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: IdeaColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                      const SizedBox(height: 2),
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
                              ),
                            );
                          },
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
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${selected.configName} · v${selected.projectVersion}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge,
                                          ),
                                        ),
                                        if (selected.isLocal)
                                          TextButton.icon(
                                            onPressed: () => onOpenFolder(
                                              selected.artifactsDirectory!,
                                            ),
                                            icon: const Icon(Icons.folder_open,
                                                size: 14),
                                            label: Text(
                                              l10n.buildsOpenArchiveFolder,
                                            ),
                                          ),
                                        if (selected.isGitLab) ...[
                                          TextButton.icon(
                                            onPressed: selected.gitlabJobWebUrl ==
                                                    null
                                                ? null
                                                : () => onOpenUrl(
                                                      selected.gitlabJobWebUrl!,
                                                    ),
                                            icon: const Icon(Icons.open_in_new,
                                                size: 14),
                                            label: Text(l10n.buildsOpenInGitLab),
                                          ),
                                          TextButton.icon(
                                            onPressed:
                                                selected.gitlabArtifactsDownloadUrl ==
                                                        null
                                                    ? null
                                                    : () => onOpenUrl(
                                                          selected
                                                              .gitlabArtifactsDownloadUrl!,
                                                        ),
                                            icon: const Icon(Icons.download,
                                                size: 14),
                                            label: Text(
                                              l10n.buildsDownloadArtifacts,
                                            ),
                                          ),
                                        ],
                                        if (selected.isLocal)
                                          IconButton(
                                            tooltip: l10n.buildsDeleteArchive,
                                            onPressed: () =>
                                                onDeleteLocal(selected),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      l10n.buildsHistoryFiles(
                                        selected.artifactCount,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        12,
                                      ),
                                      itemCount: selected.artifactFiles.length,
                                      itemBuilder: (context, index) {
                                        final file =
                                            selected.artifactFiles[index];
                                        return ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                            Icons.insert_drive_file_outlined,
                                            size: 14,
                                            color: IdeaColors.textSecondary,
                                          ),
                                          title: Text(
                                            file,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Consolas',
                                              fontSize: 10,
                                              color: IdeaColors.textPrimary,
                                            ),
                                          ),
                                          onTap: () {
                                            if (selected.isLocal) {
                                              onOpenFolder(
                                                p.join(
                                                  selected.artifactsDirectory!,
                                                  file,
                                                ),
                                              );
                                              return;
                                            }
                                            final url = selected
                                                .gitlabArtifactFileWebUrl(file);
                                            if (url != null) {
                                              onOpenUrl(url);
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
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

String _formatArchiveDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
