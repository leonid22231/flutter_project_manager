import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:provider/provider.dart';

class FileWidgetsDocSection extends StatelessWidget {
  const FileWidgetsDocSection({
    super.key,
    required this.relativePath,
  });

  final String relativePath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = context.watch<ProjectManagerState>().selectedProject;
    if (project == null) return const SizedBox.shrink();

    final widgets = project.widgets.forRelativeFile(relativePath);
    final defined = project.widgets.definedInFile(relativePath);

    if (widgets.isEmpty) {
      return DocEmptyState(
        icon: Icons.widgets_outlined,
        message: l10n.noWidgetsFound,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (defined.isNotEmpty) ...[
          DocSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DocGroupHeader(
                  icon: Icons.widgets_outlined,
                  title: l10n.widgetsDefinition,
                  count: defined.length,
                ),
                const SizedBox(height: 8),
                ...defined.map(
                  (widget) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${widget.name} · ${widget.superType ?? widget.type}',
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        DocSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DocGroupHeader(
                icon: Icons.hub_outlined,
                title: l10n.widgetsUsages,
                count: widgets.fold<int>(0, (sum, w) => sum + w.usageCount),
              ),
              const SizedBox(height: 8),
              ...widgets.expand(
                (widget) => widget.usages
                    .where(
                      (usage) =>
                          usage.filePath.replaceAll(r'\', '/') ==
                          relativePath.replaceAll(r'\', '/'),
                    )
                    .map(
                      (usage) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${usage.filePath}:${usage.line}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: IdeaColors.accent,
                                fontFamily: 'Consolas',
                              ),
                            ),
                            if (usage.positionalArgs.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              ...usage.positionalArgs.map(
                                (arg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: DocCodeChip(text: arg),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
