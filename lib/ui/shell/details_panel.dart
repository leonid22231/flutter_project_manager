import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/l10n/l10n_extensions.dart';
import 'package:project_manager/models/file_documentation_sections.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/services/documentation_service.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/file_doc_section_content.dart';
import 'package:provider/provider.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;
    if (project == null) return const SizedBox.shrink();

    return ColoredBox(
      color: IdeaColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTabs(
            active: state.detailSection,
            onChanged: state.setDetailSection,
          ),
          Expanded(
            child: switch (state.detailSection) {
              DetailPanelSection.details => _DetailsContent(
                  project: project,
                  openedFile: state.activeOpenedFile,
                ),
              DetailPanelSection.documentation => state.activeOpenedFile != null
                  ? _FileDocumentationContent(
                      openedFile: state.activeOpenedFile!,
                    )
                  : _ProjectDocumentationLinks(project: project),
              DetailPanelSection.tasks => _TasksPlaceholder(),
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.active, required this.onChanged});

  final DetailPanelSection active;
  final ValueChanged<DetailPanelSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: DetailPanelSection.values.map((section) {
          final isActive = section == active;
          return Expanded(
            child: Material(
              color: isActive ? IdeaColors.selected : Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(section),
                child: Center(
                  child: Text(
                    section.localized(l10n),
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? IdeaColors.textBright
                          : IdeaColors.textSecondary,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.project,
    this.openedFile,
  });

  final Project project;
  final OpenedFile? openedFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (openedFile != null) {
      return _FileDetailsContent(openedFile: openedFile!);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _DetailRow(label: l10n.labelName, value: project.name),
        _DetailRow(
          label: l10n.labelStatus,
          value: project.status.localized(l10n),
        ),
        _DetailRow(label: l10n.labelPath, value: project.path),
        _DetailRow(
          label: l10n.labelAdded,
          value: project.addedAt.toIso8601String().split('T').first,
        ),
        _DetailRow(
          label: l10n.labelFlutter,
          value: project.flutterVersion ?? l10n.notAvailable,
        ),
        _DetailRow(
          label: l10n.labelDart,
          value: project.dartVersion ?? l10n.notAvailable,
        ),
        _DetailRow(
          label: l10n.labelPlatforms,
          value: project.platforms.isEmpty
              ? l10n.none
              : project.platforms.join(', '),
        ),
        _DetailRow(
          label: l10n.labelDependencies,
          value: '${project.dependencies.length}',
        ),
        _DetailRow(
          label: l10n.labelWidgets,
          value: '${project.widgets.length}',
        ),
        if (project.structureNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.structure,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...project.structureNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 12, color: IdeaColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FileDetailsContent extends StatelessWidget {
  const _FileDetailsContent({required this.openedFile});

  final OpenedFile openedFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = openedFile.sizeBytes;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          l10n.fileSection,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 10),
        _DetailRow(label: l10n.labelName, value: openedFile.fileName),
        _DetailRow(label: l10n.labelPath, value: openedFile.relativePath),
        _DetailRow(
          label: l10n.labelLanguage,
          value: openedFile.languageId.localizedFileType(
            l10n,
            fileName: openedFile.fileName,
          ),
        ),
        if (openedFile.lineCount > 0)
          _DetailRow(
            label: l10n.labelLines,
            value: '${openedFile.lineCount}',
          ),
        if (size != null)
          _DetailRow(label: l10n.labelSize, value: _formatSize(size)),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              color: IdeaColors.textBright,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDocumentationLinks extends StatelessWidget {
  const _ProjectDocumentationLinks({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          l10n.localSections,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...DocumentationService.sectionKeys.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 14, color: IdeaColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.docSectionTitle(entry.key),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (project.documentationSections.containsKey(entry.key))
                  Icon(Icons.check_circle, size: 12, color: IdeaColors.success),
              ],
            ),
          ),
        ),
        if (project.documentationLinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.externalLinks,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...project.documentationLinks.map(
            (link) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(link.title, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }
}

class _FileDocumentationContent extends StatelessWidget {
  const _FileDocumentationContent({required this.openedFile});

  final OpenedFile openedFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = openedFile.documentationSections;
    final project = context.watch<ProjectManagerState>().selectedProject;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          l10n.fileDocumentationHeader,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.fileDocumentationHint(openedFile.fileName),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...FileDocumentationSections.keys.map((key) {
          final content = sections[key] ?? '';
          final hasContent = content.trim().isNotEmpty ||
              key == 'overview' ||
              (key == 'dependencies' &&
                  openedFile.dartImportAnalysis != null) ||
              (key == 'widgets' &&
                  openedFile.languageId == 'dart' &&
                  (project?.widgets
                          .forRelativeFile(openedFile.relativePath)
                          .isNotEmpty ??
                      false));
          final badgeCount = fileDocSectionBadgeCount(key, openedFile);
          final subtitle =
              fileDocSectionSubtitle(key, openedFile, l10n, project?.widgets);
          return _FileDocSectionTile(
            icon: fileDocSectionIcon(key),
            title: l10n.fileDocSectionTitle(key),
            subtitle: subtitle,
            badgeCount: badgeCount,
            content: content,
            hasContent: hasContent,
            emptyHint: l10n.fileDocFutureHint,
            sectionKey: key,
            openedFile: openedFile,
          );
        }),
      ],
    );
  }
}

class _FileDocSectionTile extends StatefulWidget {
  const _FileDocSectionTile({
    required this.icon,
    required this.title,
    required this.content,
    required this.hasContent,
    required this.emptyHint,
    required this.sectionKey,
    required this.openedFile,
    this.subtitle,
    this.badgeCount,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int? badgeCount;
  final String content;
  final bool hasContent;
  final String emptyHint;
  final String sectionKey;
  final OpenedFile openedFile;

  @override
  State<_FileDocSectionTile> createState() => _FileDocSectionTileState();
}

class _FileDocSectionTileState extends State<_FileDocSectionTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _expanded ? IdeaColors.accent.withValues(alpha: 0.35) : IdeaColors.panelBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: IdeaColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Icon(widget.icon, size: 14, color: IdeaColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: IdeaColors.textBright,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.badgeCount != null)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: IdeaColors.sidebar,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IdeaColors.panelBorder),
                      ),
                      child: Text(
                        '${widget.badgeCount}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  if (widget.hasContent)
                    Icon(Icons.check, size: 12, color: IdeaColors.success),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: FileDocSectionContent(
                sectionKey: widget.sectionKey,
                openedFile: widget.openedFile,
                content: widget.content,
                emptyHint: widget.emptyHint,
              ),
            ),
        ],
      ),
    );
  }
}

class _TasksPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 28, color: IdeaColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              l10n.tasksTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tasksHint,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
