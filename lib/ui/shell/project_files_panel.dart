import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project_file_node.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class ProjectFilesPanel extends StatelessWidget {
  const ProjectFilesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;

    return ColoredBox(
      color: IdeaColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: l10n.projectFiles,
            action: project != null
                ? IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: l10n.refreshFileTree,
                    onPressed: state.isLoadingFiles
                        ? null
                        : () => state.reloadProjectFiles(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  )
                : null,
          ),
          Expanded(
            child: project == null
                ? const _NoProjectSelected()
                : state.isLoadingFiles
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: IdeaColors.accent,
                          ),
                        ),
                      )
                    : state.fileTree.isEmpty
                        ? const _EmptyTree()
                        : _FileTreeList(
                            nodes: state.fileTree,
                            projectRoot: project.path,
                            expandedPaths: state.expandedDirectoryPaths,
                            selectedFilePath: state.activeFilePath,
                            openFilePaths: state.openFilePaths,
                            onToggleDirectory: state.toggleDirectory,
                            onSelectFile: state.openFile,
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
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _NoProjectSelected extends StatelessWidget {
  const _NoProjectSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.selectProjectForFiles,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.noFilesFound,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FileTreeList extends StatelessWidget {
  const _FileTreeList({
    required this.nodes,
    required this.projectRoot,
    required this.expandedPaths,
    required this.selectedFilePath,
    required this.openFilePaths,
    required this.onToggleDirectory,
    required this.onSelectFile,
  });

  final List<ProjectFileNode> nodes;
  final String projectRoot;
  final Set<String> expandedPaths;
  final String? selectedFilePath;
  final List<String> openFilePaths;
  final ValueChanged<String> onToggleDirectory;
  final ValueChanged<String> onSelectFile;

  @override
  Widget build(BuildContext context) {
    final flatNodes = _flattenNodes(nodes, expandedPaths, 0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: flatNodes.length,
      itemBuilder: (context, index) {
        final item = flatNodes[index];
        return _FileTreeTile(
          node: item.node,
          depth: item.depth,
          isExpanded: expandedPaths.contains(item.node.path),
          isSelected: selectedFilePath == item.node.path,
          isOpen: openFilePaths.contains(item.node.path),
          onToggleDirectory: onToggleDirectory,
          onSelectFile: onSelectFile,
        );
      },
    );
  }

  List<_FlatTreeItem> _flattenNodes(
    List<ProjectFileNode> nodes,
    Set<String> expandedPaths,
    int depth,
  ) {
    final result = <_FlatTreeItem>[];

    for (final node in nodes) {
      result.add(_FlatTreeItem(node: node, depth: depth));
      if (node.isDirectory &&
          expandedPaths.contains(node.path) &&
          node.children.isNotEmpty) {
        result.addAll(
          _flattenNodes(node.children, expandedPaths, depth + 1),
        );
      }
    }

    return result;
  }
}

class _FlatTreeItem {
  const _FlatTreeItem({required this.node, required this.depth});

  final ProjectFileNode node;
  final int depth;
}

class _FileTreeTile extends StatelessWidget {
  const _FileTreeTile({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.isOpen,
    required this.onToggleDirectory,
    required this.onSelectFile,
  });

  final ProjectFileNode node;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final bool isOpen;
  final ValueChanged<String> onToggleDirectory;
  final ValueChanged<String> onSelectFile;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForNode(node, isExpanded);

    return Material(
      color: isSelected ? IdeaColors.selected : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (node.isDirectory) {
            onToggleDirectory(node.path);
          } else {
            onSelectFile(node.path);
          }
        },
        hoverColor: IdeaColors.hover.withValues(alpha: 0.3),
        child: Padding(
          padding: EdgeInsets.only(
            left: 8.0 + depth * 14.0,
            right: 8,
            top: 3,
            bottom: 3,
          ),
          child: Row(
            children: [
              if (node.isDirectory)
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: IdeaColors.textSecondary,
                )
              else
                const SizedBox(width: 14),
              Icon(icon, size: 14, color: _iconColor(node, isSelected)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? IdeaColors.textBright
                        : IdeaColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOpen && !node.isDirectory)
                Icon(Icons.circle, size: 6, color: IdeaColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForNode(ProjectFileNode node, bool isExpanded) {
    if (node.isDirectory) {
      return isExpanded ? Icons.folder_open : Icons.folder;
    }

    final ext = node.name.contains('.')
        ? node.name.split('.').last.toLowerCase()
        : '';

    return switch (ext) {
      'dart' => Icons.flutter_dash,
      'yaml' || 'yml' => Icons.settings_outlined,
      'md' => Icons.description_outlined,
      'json' => Icons.data_object_outlined,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg' =>
        Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Color _iconColor(ProjectFileNode node, bool isSelected) {
    if (isSelected) return IdeaColors.accent;
    if (node.isDirectory) return IdeaColors.warning;
    if (node.name.endsWith('.dart')) return IdeaColors.accent;
    return IdeaColors.textSecondary;
  }
}
