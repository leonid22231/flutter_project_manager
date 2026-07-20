import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/agent_index_meta_service.dart';
import 'package:project_manager/services/project_context_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

/// Project-context indexing surface. Full agent chat lives on the Agent tab.
class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key});

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  final _contextService = ProjectContextService();
  final _contextOrchestrator = AgentContextOrchestrator();
  final _indexMetaService = AgentIndexMetaService();

  bool _isBuildingContext = false;
  String? _contextError;
  ProjectContextFileInfo? _contextInfo;
  AgentIndexMeta _indexMeta = const AgentIndexMeta();
  String? _lastProjectId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    if (_lastProjectId == project.id) return;
    _lastProjectId = project.id;
    _contextInfo = _contextService.readExisting(project.path);
    _loadMeta(project.path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_contextInfo == null) {
        _ensureContext(projectId: project.id, force: true);
      }
    });
  }

  Future<void> _loadMeta(String projectRoot) async {
    final meta = await _indexMetaService.load(projectRoot);
    if (!mounted) return;
    setState(() => _indexMeta = meta);
  }

  Future<void> _ensureContext({
    required String projectId,
    bool force = false,
  }) async {
    if (_isBuildingContext) return;
    final state = context.read<ProjectManagerState>();
    final project = state.selectedProject;
    if (project == null || project.id != projectId) return;
    if (!force && _contextInfo != null) return;

    setState(() {
      _isBuildingContext = true;
      _contextError = null;
    });

    final result = await _contextOrchestrator.refreshFullContext(
      ProjectContextRefreshInput(
        project: project,
        gitStatus: state.gitRepositoryStatus,
        globalPackageMetadata: state.globalPackageMetadata,
      ),
      languageCode: context.l10n.locale.languageCode,
    );

    if (!mounted || state.selectedProject?.id != projectId) return;

    if (result.isSuccess) {
      final meta = await _indexMetaService.recordIndex(
        projectRoot: project.path,
        contextPath: result.filePath,
        sizeBytes: result.sizeBytes,
      );
      setState(() {
        _isBuildingContext = false;
        _indexMeta = meta;
        _contextInfo = ProjectContextFileInfo(
          filePath: result.filePath,
          generatedAt: result.generatedAt,
          sizeBytes: result.sizeBytes,
          version: 1,
        );
        _contextError = null;
      });
    } else {
      setState(() {
        _isBuildingContext = false;
        _contextError = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final appSettings = context.watch<AppSettingsState>();
    final project = state.selectedProject;
    if (project == null) return const SizedBox.shrink();

    final generatedLabel = _contextInfo != null
        ? _formatDateTime(_contextInfo!.generatedAt.toLocal())
        : '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.codeAnalysis, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.analysisContextOnlyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IdeaColors.sidebar,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: IdeaColors.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 18, color: IdeaColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      l10n.analysisContextTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_isBuildingContext)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: l10n.analysisRegenerateContext,
                        onPressed: () =>
                            _ensureContext(projectId: project.id, force: true),
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isBuildingContext)
                  Text(l10n.analysisContextBuilding,
                      style: Theme.of(context).textTheme.bodySmall)
                else if (_contextError != null)
                  Text(
                    _contextError!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: IdeaColors.error),
                  )
                else if (_contextInfo != null)
                  Text(
                    l10n.analysisContextReady(
                      generatedLabel,
                      _formatBytes(_contextInfo!.sizeBytes),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Text(l10n.analysisContextMissing,
                      style: Theme.of(context).textTheme.bodySmall),
                if (_indexMeta.isStale) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.agentIndexStale,
                    style: const TextStyle(
                      color: IdeaColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_indexMeta.includedSources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.agentIndexIncluded,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  ..._indexMeta.includedSources.map(
                    (s) => Text('• $s', style: const TextStyle(fontSize: 11)),
                  ),
                ],
                if (!appSettings.cursorCliSettings.enabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.analysisCursorDisabled,
                    style: const TextStyle(
                      color: IdeaColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                context.read<ProjectManagerState>().showWorkspaceTab(
                      WorkspaceTab.agent,
                    ),
            icon: const Icon(Icons.smart_toy_outlined, size: 16),
            label: Text(l10n.analysisOpenAgent),
            style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }
}
