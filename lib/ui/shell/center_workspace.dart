import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/l10n/l10n_extensions.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/views/agent_view.dart';
import 'package:project_manager/ui/views/analysis_view.dart';
import 'package:project_manager/ui/views/builds_view.dart';
import 'package:project_manager/ui/views/dependencies_view.dart';
import 'package:project_manager/ui/views/documentation_view.dart';
import 'package:project_manager/ui/views/empty_state_view.dart';
import 'package:project_manager/ui/views/file_preview_view.dart';
import 'package:project_manager/ui/views/gitlab_view.dart';
import 'package:project_manager/ui/views/media_view.dart';
import 'package:project_manager/ui/views/project_overview_view.dart';
import 'package:project_manager/ui/views/widgets_view.dart';
import 'package:provider/provider.dart';

class CenterWorkspace extends StatelessWidget {
  const CenterWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;

    if (project == null) {
      return const EmptyStateView();
    }

    final activeFile = state.activeOpenedFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabBar(
          activeTab: state.activeTab,
          hasActiveFile: state.activeFilePath != null,
          onTabSelected: state.showWorkspaceTab,
        ),
        if (state.openFilePaths.isNotEmpty)
          _OpenFilesTabBar(
            openPaths: state.openFilePaths,
            activePath: state.activeFilePath,
            onSelect: state.setActiveFile,
            onClose: state.closeFile,
          ),
        Expanded(
          child: state.isOpeningFile && activeFile == null
              ? const Center(
                  child: CircularProgressIndicator(color: IdeaColors.accent),
                )
              : activeFile != null
                  ? FilePreviewView(
                      openedFile: activeFile,
                      focus: state.filePreviewFocus,
                      focusToken: state.filePreviewFocusToken,
                      onClose: () => state.closeFile(activeFile.path),
                    )
                  : switch (state.activeTab) {
                      WorkspaceTab.overview =>
                        ProjectOverviewView(project: project),
                      WorkspaceTab.documentation =>
                        DocumentationView(project: project),
                      WorkspaceTab.dependencies => const DependenciesView(),
                      WorkspaceTab.widgets => const WidgetsView(),
                      WorkspaceTab.media => const MediaView(),
                      WorkspaceTab.gitlab => const GitLabView(),
                      WorkspaceTab.builds => const BuildsView(),
                      WorkspaceTab.analysis => const AnalysisView(),
                      WorkspaceTab.agent => const AgentView(),
                    },
        ),
      ],
    );
  }
}

class _OpenFilesTabBar extends StatelessWidget {
  const _OpenFilesTabBar({
    required this.openPaths,
    required this.activePath,
    required this.onSelect,
    required this.onClose,
  });

  final List<String> openPaths;
  final String? activePath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: IdeaColors.sidebar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: openPaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final path = openPaths[index];
          final isActive = path == activePath;
          final fileName = path.split(RegExp(r'[/\\]')).last;

          return _OpenFileTab(
            fileName: fileName,
            isActive: isActive,
            onSelect: () => onSelect(path),
            onClose: () => onClose(path),
          );
        },
      ),
    );
  }
}

class _OpenFileTab extends StatelessWidget {
  const _OpenFileTab({
    required this.fileName,
    required this.isActive,
    required this.onSelect,
    required this.onClose,
  });

  final String fileName;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          onClose();
        }
      },
      child: Material(
        color: isActive ? IdeaColors.background : Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? IdeaColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 12,
                color: isActive ? IdeaColors.accent : IdeaColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                fileName,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive
                      ? IdeaColors.textBright
                      : IdeaColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 12,
                  color: isActive
                      ? IdeaColors.textPrimary
                      : IdeaColors.textSecondary,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                tooltip: context.l10n.close,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.activeTab,
    required this.hasActiveFile,
    required this.onTabSelected,
  });

  final WorkspaceTab activeTab;
  final bool hasActiveFile;
  final ValueChanged<WorkspaceTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: WorkspaceTab.values.map((tab) {
            final isActive = tab == activeTab && !hasActiveFile;
            return _TabItem(
              label: tab.localized(l10n),
              isActive: isActive,
              onTap: () => onTabSelected(tab),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? IdeaColors.background : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? IdeaColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? IdeaColors.textBright : IdeaColors.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
