import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/cursor_cli_bar_status.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/ui/dialogs/add_project_dialog.dart';
import 'package:project_manager/ui/dialogs/settings_dialog.dart';
import 'package:project_manager/ui/shell/center_workspace.dart';
import 'package:project_manager/ui/shell/details_panel.dart';
import 'package:project_manager/ui/shell/project_tree_panel.dart';
import 'package:project_manager/ui/shell/top_action_bar.dart';
import 'package:project_manager/ui/widgets/panel_resize_divider.dart';
import 'package:provider/provider.dart';
import 'package:project_manager/state/project_manager_state.dart';

class IdeShell extends StatelessWidget {
  const IdeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final settings = context.watch<AppSettingsState>();

    if (state.isLoading || settings.isLoading) {
      return const Scaffold(
        backgroundColor: IdeaColors.background,
        body: Center(
          child: CircularProgressIndicator(color: IdeaColors.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: IdeaColors.background,
      body: Column(
        children: [
          TopActionBar(
            onAddProject: () => _showAddProjectDialog(context),
            onSettings: () => _showSettingsDialog(context),
            onRefresh: state.selectedProject != null
                ? () => state.refreshSelectedProject()
                : null,
            onExportDocs: state.selectedProject != null
                ? () => _exportDocs(context, state)
                : null,
          ),
          Expanded(
            child: Row(
              children: [
                ResizableSidePanel(
                  width: settings.leftPanelWidth,
                  child: ProjectTreePanel(
                    onAddProject: () => _showAddProjectDialog(context),
                  ),
                ),
                PanelResizeDivider(
                  axis: Axis.vertical,
                  onDelta: (dx) => settings.setLeftPanelWidth(
                    settings.leftPanelWidth + dx,
                  ),
                ),
                const Expanded(child: CenterWorkspace()),
                if (state.selectedProject != null) ...[
                  PanelResizeDivider(
                    axis: Axis.vertical,
                    onDelta: (dx) => settings.setRightPanelWidth(
                      settings.rightPanelWidth - dx,
                    ),
                  ),
                  ResizableSidePanel(
                    width: settings.rightPanelWidth,
                    child: const DetailsPanel(),
                  ),
                ],
              ],
            ),
          ),
          _StatusBar(state: state, settings: settings),
        ],
      ),
    );
  }

  Future<void> _showAddProjectDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const AddProjectDialog(),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  Future<void> _exportDocs(
    BuildContext context,
    ProjectManagerState state,
  ) async {
    await state.exportDocumentation();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.docsExported),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.state,
    required this.settings,
  });

  final ProjectManagerState state;
  final AppSettingsState settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = state.selectedProject;
    final sdkStatus = project?.sdkAvailable ?? true;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(top: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Text(
            l10n.projectsCount(state.projects.length),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const Spacer(),
          if (project != null) ...[
            Icon(
              sdkStatus ? Icons.check_circle : Icons.warning_amber,
              size: 12,
              color: sdkStatus ? IdeaColors.success : IdeaColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              sdkStatus
                  ? l10n.sdkVersions(
                      project.flutterVersion ?? '?',
                      project.dartVersion ?? '?',
                    )
                  : l10n.sdkNotAvailable,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 12),
            Text(
              '·',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 12),
          ],
          _CursorCliStatusIndicator(settings: settings),
        ],
      ),
    );
  }
}

class _CursorCliStatusIndicator extends StatelessWidget {
  const _CursorCliStatusIndicator({required this.settings});

  final AppSettingsState settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = settings.cursorCliBarStatus;
    final model = settings.cursorCliSettings.defaultModel;

    final (icon, color, label) = switch (status) {
      CursorCliBarStatus.connected => (
          Icons.check_circle,
          IdeaColors.success,
          l10n.statusBarCursorCliConnectedWithModel(model),
        ),
      CursorCliBarStatus.unavailable => (
          Icons.error_outline,
          IdeaColors.error,
          l10n.statusBarCursorCliUnavailable,
        ),
      CursorCliBarStatus.noModel => (
          Icons.warning_amber,
          IdeaColors.warning,
          l10n.statusBarCursorCliNoModel,
        ),
      CursorCliBarStatus.disabled => (
          Icons.link_off,
          IdeaColors.textSecondary,
          l10n.statusBarCursorCliDisabled,
        ),
      CursorCliBarStatus.checking => (
          Icons.sync,
          IdeaColors.accent,
          l10n.statusBarCursorCliChecking,
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '${l10n.statusBarCursorCliLabel}: $label',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
