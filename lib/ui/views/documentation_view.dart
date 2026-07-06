import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/documentation_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:project_manager/ui/widgets/panel_resize_divider.dart';
import 'package:provider/provider.dart';

class DocumentationView extends StatefulWidget {
  const DocumentationView({super.key, required this.project});

  final Project project;

  @override
  State<DocumentationView> createState() => _DocumentationViewState();
}

class _DocumentationViewState extends State<DocumentationView> {
  late String _selectedSectionKey;

  @override
  void initState() {
    super.initState();
    _selectedSectionKey = DocumentationService.sectionKeys.keys.first;
  }

  @override
  void didUpdateWidget(DocumentationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _selectedSectionKey = DocumentationService.sectionKeys.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<AppSettingsState>();
    final sections = DocumentationService.sectionKeys;
    final content = widget.project.documentationSections[_selectedSectionKey] ?? '';
    final sectionTitle = l10n.docSectionTitle(_selectedSectionKey);
    final isPlaceholder = content.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: settings.docSidebarWidth,
          child: ColoredBox(
            color: IdeaColors.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionsHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final key = sections.keys.elementAt(index);
                      final title = l10n.docSectionTitle(key);
                      final hasContent =
                          (widget.project.documentationSections[key] ?? '')
                              .isNotEmpty;
                      return _SectionListItem(
                        title: title,
                        isSelected: key == _selectedSectionKey,
                        hasContent: hasContent,
                        onTap: () => setState(() => _selectedSectionKey = key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        PanelResizeDivider(
          axis: Axis.vertical,
          onDelta: (dx) => settings.setDocSidebarWidth(
            settings.docSidebarWidth + dx,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewHeader(
                title: sectionTitle,
                isPlaceholder: isPlaceholder,
              ),
              Expanded(
                child: isPlaceholder
                    ? _EmptySectionPlaceholder(sectionTitle: sectionTitle)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DocSectionCard(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: MarkdownContent(
                            data: content,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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

class _SectionsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Text(
        context.l10n.sections,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _SectionListItem extends StatelessWidget {
  const _SectionListItem({
    required this.title,
    required this.isSelected,
    required this.hasContent,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final bool hasContent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? IdeaColors.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: IdeaColors.hover.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: isSelected ? IdeaColors.accent : IdeaColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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
              if (hasContent)
                Icon(Icons.check, size: 12, color: IdeaColors.success),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.title,
    required this.isPlaceholder,
  });

  final String title;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.text_snippet_outlined, size: 16, color: IdeaColors.accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: IdeaColors.textBright,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: IdeaColors.background,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: IdeaColors.panelBorder),
            ),
            child: Text(
              isPlaceholder ? l10n.empty : l10n.markdown,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionPlaceholder extends StatelessWidget {
  const _EmptySectionPlaceholder({required this.sectionTitle});

  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: DocSectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined,
                  size: 40, color: IdeaColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                sectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.docSectionPlaceholder,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
