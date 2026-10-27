import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/project_relocate.dart';
import 'package:provider/provider.dart';

class ProjectTreePanel extends StatelessWidget {
  const ProjectTreePanel({super.key, required this.onAddProject});

  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
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
          else
            Expanded(
              child: ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final isSelected = selected?.id == project.id;
                  final missing = !state.isProjectDirectoryPresent(project);
                  return _ProjectTreeItem(
                    project: project,
                    isSelected: isSelected,
                    missing: missing,
                    onTap: () => state.selectProject(project),
                    onRelocate: missing
                        ? () => pickAndRelocateProject(context, project)
                        : null,
                  );
                },
              ),
            ),
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
    required this.missing,
    required this.onTap,
    this.onRelocate,
  });

  final Project project;
  final bool isSelected;
  final bool missing;
  final VoidCallback onTap;
  final VoidCallback? onRelocate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                missing ? Icons.folder_off_outlined : Icons.folder_outlined,
                size: 16,
                color: missing
                    ? IdeaColors.error
                    : (isSelected
                        ? IdeaColors.accent
                        : IdeaColors.textSecondary),
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
                      missing
                          ? l10n.projectFolderMissing
                          : project.path,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: missing ? IdeaColors.error : null,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onRelocate != null)
                IconButton(
                  tooltip: l10n.chooseProjectFolder,
                  onPressed: onRelocate,
                  icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
