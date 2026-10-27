import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/latest_ai_task.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/project_relocate.dart';
import 'package:project_manager/ui/views/ai_folder_view.dart';
import 'package:project_manager/ui/views/gitlab_view.dart';
import 'package:project_manager/ui/views/self_analysis_view.dart';
import 'package:project_manager/ui/widgets/context_sync_project_section.dart';
import 'package:provider/provider.dart';

class ProjectHomeView extends StatefulWidget {
  const ProjectHomeView({super.key, required this.project});

  final Project project;

  @override
  State<ProjectHomeView> createState() => _ProjectHomeViewState();
}

enum _HomeMode { overview, ai, selfAnalysis, git }

class _ProjectHomeViewState extends State<ProjectHomeView> {
  var _mode = _HomeMode.overview;

  @override
  void didUpdateWidget(covariant ProjectHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _mode = _HomeMode.overview;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final project = widget.project;
    final missing = !state.isProjectDirectoryPresent(project);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!missing)
          _ModeBar(
            mode: _mode,
            onMode: (mode) => setState(() => _mode = mode),
          ),
        Expanded(
          child: missing
              ? _MissingFolder(project: project)
              : switch (_mode) {
                  _HomeMode.overview => _ProjectSummary(
                      project: project,
                      l10n: l10n,
                      state: state,
                    ),
                  _HomeMode.ai => AiFolderView(project: project),
                  _HomeMode.selfAnalysis =>
                    SelfAnalysisView(project: project),
                  _HomeMode.git => const GitLabView(),
                },
        ),
      ],
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onMode});

  final _HomeMode mode;
  final ValueChanged<_HomeMode> onMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: l10n.tabOverview,
            selected: mode == _HomeMode.overview,
            onTap: () => onMode(_HomeMode.overview),
          ),
          const SizedBox(width: 8),
          _ModeButton(
            label: l10n.agentSectionAiFolder,
            selected: mode == _HomeMode.ai,
            onTap: () => onMode(_HomeMode.ai),
          ),
          const SizedBox(width: 8),
          _ModeButton(
            label: l10n.agentSectionSelfAnalysis,
            selected: mode == _HomeMode.selfAnalysis,
            onTap: () => onMode(_HomeMode.selfAnalysis),
          ),
          const SizedBox(width: 8),
          _ModeButton(
            label: l10n.tabGitlab,
            selected: mode == _HomeMode.git,
            onTap: () => onMode(_HomeMode.git),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor:
            selected ? IdeaColors.textBright : IdeaColors.textSecondary,
        backgroundColor: selected ? IdeaColors.selected : Colors.transparent,
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}

class _MissingFolder extends StatelessWidget {
  const _MissingFolder({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IdeaColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: IdeaColors.error.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.projectFolderMissing,
                      style: const TextStyle(
                        color: IdeaColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.projectFolderMissingHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      project.path,
                      style: const TextStyle(
                        color: IdeaColors.textBright,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => pickAndRelocateProject(context, project),
                style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text(l10n.chooseProjectFolder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectSummary extends StatelessWidget {
  const _ProjectSummary({
    required this.project,
    required this.l10n,
    required this.state,
  });

  final Project project;
  final AppLocalizations l10n;
  final ProjectManagerState state;

  @override
  Widget build(BuildContext context) {
    final branch = state.gitRepositoryStatus?.branch;
    final task = readLatestAiTask(project.path);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(
            project.path,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => pickAndRelocateProject(context, project),
            icon: const Icon(Icons.drive_file_move_outlined, size: 16),
            label: Text(l10n.changeProjectFolder),
          ),
          const SizedBox(height: 16),
          _Fact(
            label: l10n.gitBranch,
            value: (branch == null || branch.isEmpty)
                ? l10n.gitNotRepository
                : branch,
          ),
          const SizedBox(height: 12),
          _Fact(
            label: l10n.latestTask,
            value: task?.title ?? l10n.noLatestTask,
          ),
          const SizedBox(height: 24),
          ContextSyncProjectSection(project: project),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: IdeaColors.textBright, fontSize: 14),
        ),
      ],
    );
  }
}
