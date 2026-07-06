import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/dart_import_analysis.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:provider/provider.dart';

class FileDependenciesDocSection extends StatelessWidget {
  const FileDependenciesDocSection({
    super.key,
    required this.analysis,
    required this.projectRoot,
  });

  final DartImportAnalysis analysis;
  final String projectRoot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.read<ProjectManagerState>();
    final projectFiles = _uniqueEntries(analysis.projectFiles);
    final packages = _uniqueEntries(analysis.externalPackages);
    final sdkImports = _uniqueEntries(analysis.dartSdkImports);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.projectPackageName != null)
          DocSectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: IdeaColors.accent),
                const SizedBox(width: 8),
                Text(
                  l10n.fileDocProjectPackage(analysis.projectPackageName!),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        if (analysis.projectPackageName != null) const SizedBox(height: 10),
        _ImportGroup(
          title: l10n.fileDocProjectFiles,
          icon: Icons.insert_drive_file_outlined,
          entries: projectFiles,
          emptyMessage: l10n.fileDocNoProjectFiles,
          nameBuilder: (entry) => entry.resolvedRelativePath ?? entry.uri,
          onTap: (entry) => _openProjectFile(state, entry),
        ),
        const SizedBox(height: 10),
        _ImportGroup(
          title: l10n.fileDocPackages,
          icon: Icons.extension_outlined,
          entries: packages,
          emptyMessage: l10n.fileDocNoPackages,
          nameBuilder: (entry) => entry.packageName ?? entry.uri,
          onTap: (entry) => _openPackage(entry),
        ),
        if (sdkImports.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ImportGroup(
            title: l10n.fileDocDartSdk,
            icon: Icons.terminal_outlined,
            entries: sdkImports,
            emptyMessage: l10n.fileDocNoSdkImports,
            nameBuilder: (entry) => entry.uri,
          ),
        ],
      ],
    );
  }

  Future<void> _openProjectFile(
    ProjectManagerState state,
    DartImportEntry entry,
  ) async {
    final path = entry.resolvedAbsolutePath ??
        (entry.resolvedRelativePath != null
            ? p.join(projectRoot, entry.resolvedRelativePath!)
            : null);
    if (path == null) return;

    if (entry.targetExists) {
      await state.openFile(path);
      return;
    }

    await openPathInExplorer(p.dirname(path));
  }

  Future<void> _openPackage(DartImportEntry entry) async {
    final name = entry.packageName;
    if (name == null) return;
    await openExternalUrl('https://pub.dev/packages/$name');
  }

  List<DartImportEntry> _uniqueEntries(List<DartImportEntry> entries) {
    final seen = <String>{};
    final unique = <DartImportEntry>[];
    for (final entry in entries) {
      final key = '${entry.resolvedRelativePath ?? entry.uri}|${entry.directive}';
      if (seen.add(key)) unique.add(entry);
    }
    return unique;
  }
}

class _ImportGroup extends StatelessWidget {
  const _ImportGroup({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
    required this.nameBuilder,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final List<DartImportEntry> entries;
  final String emptyMessage;
  final String Function(DartImportEntry entry) nameBuilder;
  final ValueChanged<DartImportEntry>? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DocSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocGroupHeader(icon: icon, title: title, count: entries.length),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            DocEmptyState(icon: icon, message: emptyMessage)
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ImportEntryTile(
                  entry: entry,
                  name: nameBuilder(entry),
                  statusLabel: _statusLabel(l10n, entry),
                  statusColor: _statusColor(entry),
                  onTap: onTap != null ? () => onTap!(entry) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, DartImportEntry entry) {
    if (entry.targetExists) return l10n.fileDocStatusLinked;
    if (entry.isExternalPackage || entry.kind == DartImportKind.package) {
      return l10n.fileDocStatusExternal;
    }
    if (entry.kind == DartImportKind.dartSdk) return 'SDK';
    return l10n.fileDocStatusNotFound;
  }

  Color _statusColor(DartImportEntry entry) {
    if (entry.targetExists) return IdeaColors.success;
    if (entry.isExternalPackage || entry.kind == DartImportKind.package) {
      return IdeaColors.accent;
    }
    if (entry.kind == DartImportKind.dartSdk) return IdeaColors.textSecondary;
    return IdeaColors.warning;
  }
}

class _ImportEntryTile extends StatelessWidget {
  const _ImportEntryTile({
    required this.entry,
    required this.name,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
  });

  final DartImportEntry entry;
  final String name;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IdeaColors.toolbar,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: IdeaColors.hover.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onTap != null
                            ? IdeaColors.accent
                            : IdeaColors.textBright,
                        fontFamily: 'Consolas',
                      ),
                    ),
                    const SizedBox(height: 6),
                    DocCodeChip(text: entry.directive),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DocStatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }
}
