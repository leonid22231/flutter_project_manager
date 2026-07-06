import 'package:flutter/material.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/file_dependencies_doc_section.dart';
import 'package:project_manager/ui/widgets/file_documentation/file_overview_doc_section.dart';
import 'package:project_manager/ui/widgets/file_documentation/file_widgets_doc_section.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:provider/provider.dart';

class FileDocSectionContent extends StatelessWidget {
  const FileDocSectionContent({
    super.key,
    required this.sectionKey,
    required this.openedFile,
    required this.content,
    required this.emptyHint,
  });

  final String sectionKey;
  final OpenedFile openedFile;
  final String content;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (sectionKey == 'overview') {
      return FileOverviewDocSection(openedFile: openedFile);
    }

    if (sectionKey == 'dependencies' && openedFile.dartImportAnalysis != null) {
      final project = context.read<ProjectManagerState>().selectedProject;
      if (project != null) {
        return FileDependenciesDocSection(
          analysis: openedFile.dartImportAnalysis!,
          projectRoot: project.path,
        );
      }
    }

    if (sectionKey == 'widgets' && openedFile.languageId == 'dart') {
      return FileWidgetsDocSection(relativePath: openedFile.relativePath);
    }

    if (content.trim().isEmpty) {
      return DocEmptyState(
        icon: _iconForSection(sectionKey),
        message: emptyHint,
      );
    }

    return DocSectionCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: MarkdownContent(
        data: content,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  IconData _iconForSection(String key) {
    return switch (key) {
      'notes' => Icons.sticky_note_2_outlined,
      'widgets' => Icons.widgets_outlined,
      'analysis' => Icons.analytics_outlined,
      'changelog' => Icons.history,
      'dependencies' => Icons.hub_outlined,
      _ => Icons.description_outlined,
    };
  }
}

IconData fileDocSectionIcon(String key) {
  return switch (key) {
    'overview' => Icons.info_outline,
    'notes' => Icons.sticky_note_2_outlined,
    'widgets' => Icons.widgets_outlined,
    'analysis' => Icons.analytics_outlined,
    'changelog' => Icons.history,
    'dependencies' => Icons.hub_outlined,
    _ => Icons.description_outlined,
  };
}

int? fileDocSectionBadgeCount(String key, OpenedFile openedFile) {
  if (key == 'dependencies' && openedFile.dartImportAnalysis != null) {
    return openedFile.dartImportAnalysis!.imports.length;
  }
  return null;
}

String? fileDocSectionSubtitle(
  String key,
  OpenedFile openedFile,
  AppLocalizations l10n,
  List<WidgetEntry>? projectWidgets,
) {
  if (key == 'dependencies' && openedFile.dartImportAnalysis != null) {
    final analysis = openedFile.dartImportAnalysis!;
    return l10n.fileDocImportsSummary(
      analysis.projectFiles.length,
      analysis.externalPackages.length,
      analysis.dartSdkImports.length,
    );
  }
  if (key == 'widgets' && projectWidgets != null) {
    final count = projectWidgets.forRelativeFile(openedFile.relativePath).length;
    if (count > 0) return l10n.widgetsRecorded(count);
  }
  return null;
}
