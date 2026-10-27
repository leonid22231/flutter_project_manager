import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/ai_folder_reader.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class SelfAnalysisView extends StatefulWidget {
  const SelfAnalysisView({super.key, required this.project});

  final Project project;

  @override
  State<SelfAnalysisView> createState() => _SelfAnalysisViewState();
}

class _SelfAnalysisViewState extends State<SelfAnalysisView> {
  final _orchestrator = AgentContextOrchestrator();
  var _running = false;
  var _report = '';
  var _error = '';
  List<AgentProgressStep> _steps = const [];

  @override
  void initState() {
    super.initState();
    _report = readAiFolder(widget.project.path).selfAnalysis;
  }

  @override
  void didUpdateWidget(covariant SelfAnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.path != widget.project.path) {
      _report = readAiFolder(widget.project.path).selfAnalysis;
      _error = '';
      _steps = const [];
    }
  }

  @override
  void dispose() {
    _orchestrator.cancelSelfAnalysis();
    super.dispose();
  }

  Future<void> _run() async {
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    final state = context.read<ProjectManagerState>();
    final project = state.selectedProject ?? widget.project;
    setState(() {
      _running = true;
      _error = '';
      _steps = const [];
    });

    final result = await _orchestrator.runSelfAnalysis(
      settings: settings,
      contextInput: ProjectContextRefreshInput(
        project: project,
        gitStatus: state.gitRepositoryStatus,
        globalPackageMetadata: state.globalPackageMetadata,
      ),
      appLanguageCode: context.l10n.locale.languageCode,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _steps = progress.steps);
      },
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _steps = result.steps;
      _error = result.error ?? '';
      if (result.profile != null) {
        _report = result.profile!.selfAnalysis;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cliOn = context.watch<AppSettingsState>().cursorCliSettings.enabled;
    final report = _report.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _running || !cliOn ? null : _run,
              style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_outlined, size: 16),
              label: Text(l10n.agentRunSelfAnalysis),
            ),
          ],
        ),
        if (!cliOn) ...[
          const SizedBox(height: 12),
          Text(
            l10n.selfAnalysisNeedsCli,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: IdeaColors.error)),
        ],
        if (_steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.agentSelfAnalysisProgressTitle.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (final step in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                step.text,
                style: TextStyle(
                  color: step.isError
                      ? IdeaColors.error
                      : IdeaColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.agentSelfAnalysisLabel.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          report.isEmpty ? l10n.selfAnalysisEmpty : report,
          style: TextStyle(
            color: report.isEmpty
                ? IdeaColors.textSecondary
                : IdeaColors.textBright,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
