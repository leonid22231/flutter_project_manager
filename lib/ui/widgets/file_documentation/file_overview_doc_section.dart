import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/l10n/l10n_extensions.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';

class FileOverviewDocSection extends StatelessWidget {
  const FileOverviewDocSection({super.key, required this.openedFile});

  final OpenedFile openedFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = openedFile.sizeBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocSectionCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IdeaColors.selected,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: IdeaColors.panelBorder),
                ),
                child: Icon(
                  _iconForFile(openedFile.fileName),
                  size: 20,
                  color: IdeaColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      openedFile.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: IdeaColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      openedFile.relativePath,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: IdeaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DocMetaChip(
              icon: Icons.code,
              label: l10n.labelLanguage,
              value: openedFile.languageId.localizedFileType(
                l10n,
                fileName: openedFile.fileName,
              ),
            ),
            if (openedFile.lineCount > 0)
              DocMetaChip(
                icon: Icons.format_list_numbered,
                label: l10n.labelLines,
                value: '${openedFile.lineCount}',
              ),
            if (size != null)
              DocMetaChip(
                icon: Icons.storage_outlined,
                label: l10n.labelSize,
                value: _formatSize(size),
              ),
            DocMetaChip(
              icon: Icons.folder_outlined,
              label: l10n.labelPath,
              value: openedFile.relativePath,
            ),
          ],
        ),
      ],
    );
  }

  IconData _iconForFile(String fileName) {
    if (fileName.endsWith('.dart')) return Icons.flutter_dash;
    if (fileName.endsWith('.yaml') || fileName.endsWith('.yml')) {
      return Icons.settings_outlined;
    }
    if (fileName.endsWith('.md')) return Icons.article_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
