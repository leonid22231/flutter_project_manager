import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/ui/dialogs/add_project_dialog.dart';
import 'package:project_manager/ui/dialogs/settings_dialog.dart';
import 'package:project_manager/ui/shell/center_workspace.dart';
import 'package:project_manager/ui/shell/project_tree_panel.dart';
import 'package:project_manager/ui/shell/top_action_bar.dart';
import 'package:project_manager/ui/widgets/log_console_overlay.dart';
import 'package:project_manager/ui/widgets/panel_resize_divider.dart';
import 'package:provider/provider.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/services/app_log_service.dart';

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
      body: Stack(
        children: [
          Column(
            children: [
              TopActionBar(
                onAddProject: () => _showAddProjectDialog(context),
                onSettings: () => _showSettingsDialog(context),
                onRefresh: state.selectedProject != null
                    ? () => state.refreshSelectedProject()
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
                  ],
                ),
              ),
              _StatusBar(state: state, settings: settings),
            ],
          ),
          const LogConsoleOverlay(),
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
    final folderMissing =
        project != null && !state.isProjectDirectoryPresent(project);

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
          if (folderMissing) ...[
            const Icon(Icons.folder_off_outlined, size: 12, color: IdeaColors.error),
            const SizedBox(width: 4),
            Text(
              l10n.projectFolderMissing,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IdeaColors.error,
                  ),
            ),
            const SizedBox(width: 12),
          ],
          _ContextSyncStatusIndicator(state: state, settings: settings),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => AppLogService.instance.toggleOverlay(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terminal, size: 12, color: IdeaColors.accent),
                const SizedBox(width: 4),
                Text(
                  l10n.appLogsOpen,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IdeaColors.accent,
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

class _ContextSyncStatusIndicator extends StatelessWidget {
  const _ContextSyncStatusIndicator({
    required this.state,
    required this.settings,
  });

  final ProjectManagerState state;
  final AppSettingsState settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = settings.contextSyncSettings.isActive;
    final status = state.contextSyncStatus;

    final (IconData icon, Color color, String label) = () {
      if (!enabled) {
        return (
          Icons.cloud_off_outlined,
          IdeaColors.textSecondary,
          l10n.statusBarContextSyncDisabled,
        );
      }
      if (status.isSyncing) {
        return (
          Icons.cloud_sync,
          IdeaColors.accent,
          l10n.statusBarContextSyncSyncing,
        );
      }
      if (status.hasError) {
        return (
          Icons.cloud_off,
          IdeaColors.error,
          l10n.statusBarContextSyncError,
        );
      }
      if (status.lastSyncedAt != null) {
        return (
          Icons.cloud_done,
          IdeaColors.success,
          l10n.statusBarContextSyncOk,
        );
      }
      return (
        Icons.cloud_outlined,
        IdeaColors.textSecondary,
        l10n.statusBarContextSyncIdle,
      );
    }();

    final tooltip = !enabled
        ? l10n.contextSyncDisabled
        : status.hasError
            ? (status.error ?? l10n.contextSyncFailed)
            : status.message ?? l10n.statusBarContextSyncLabel;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: !enabled || status.isSyncing
            ? null
            : () => state.syncContextNow(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '${l10n.statusBarContextSyncLabel}: $label',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
