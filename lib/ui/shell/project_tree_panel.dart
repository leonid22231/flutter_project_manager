import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/l10n/l10n_extensions.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/shell/project_files_panel.dart';
import 'package:project_manager/ui/widgets/panel_resize_divider.dart';
import 'package:provider/provider.dart';

class ProjectTreePanel extends StatelessWidget {
  const ProjectTreePanel({super.key, required this.onAddProject});

  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final settings = context.watch<AppSettingsState>();
    final projects = state.projects;
    final selected = state.selectedProject;

    return ColoredBox(
      color: IdeaColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: l10n.projects,
            action: IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: l10n.addProject,
              onPressed: onAddProject,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
          if (projects.isEmpty)
            Expanded(child: _EmptyProjects(onAddProject: onAddProject))
          else ...[
            SizedBox(
              height: settings.projectsPaneHeight,
              child: ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final isSelected = selected?.id == project.id;
                  return _ProjectTreeItem(
                    project: project,
                    isSelected: isSelected,
                    onTap: () => state.selectProject(project),
                  );
                },
              ),
            ),
            PanelResizeDivider(
              axis: Axis.horizontal,
              onDelta: (dy) => settings.setProjectsPaneHeight(
                settings.projectsPaneHeight + dy,
              ),
            ),
            const Expanded(child: ProjectFilesPanel()),
          ],
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
          ),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onAddProject});

  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 32, color: IdeaColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            l10n.noProjectsYet,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addProjectHint,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAddProject,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.addProject),
          ),
        ],
      ),
    );
  }
}

class _ProjectTreeItem extends StatelessWidget {
  const _ProjectTreeItem({
    required this.project,
    required this.isSelected,
    required this.onTap,
  });

  final Project project;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? IdeaColors.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: IdeaColors.hover.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.flutter_dash,
                size: 16,
                color: isSelected ? IdeaColors.accent : IdeaColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        color: isSelected
                            ? IdeaColors.textBright
                            : IdeaColors.textPrimary,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      project.status.localized(context.l10n),
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!project.sdkAvailable)
                Icon(Icons.warning_amber, size: 14, color: IdeaColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}
