import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class EditPackageMetadataDialog extends StatefulWidget {
  const EditPackageMetadataDialog({
    super.key,
    required this.packageName,
    this.initial,
    this.pubDescription,
  });

  final String packageName;
  final GlobalPackageMetadata? initial;
  final String? pubDescription;

  static Future<void> show(
    BuildContext context, {
    required String packageName,
    GlobalPackageMetadata? initial,
    String? pubDescription,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => EditPackageMetadataDialog(
        packageName: packageName,
        initial: initial,
        pubDescription: pubDescription,
      ),
    );
  }

  @override
  State<EditPackageMetadataDialog> createState() =>
      _EditPackageMetadataDialogState();
}

class _EditPackageMetadataDialogState extends State<EditPackageMetadataDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _risksController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _descriptionController = TextEditingController(
      text: initial?.customDescription.isNotEmpty == true
          ? initial!.customDescription
          : (widget.pubDescription ?? ''),
    );
    _notesController = TextEditingController(
      text: initial?.customNotes ?? '',
    );
    _risksController = TextEditingController(
      text: initial?.updateRisks ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _risksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: IdeaColors.panelBorder),
      ),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.editPackageMetadataTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.packageName,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: IdeaColors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.editPackageMetadataHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Field(
                      label: l10n.packageDescription,
                      controller: _descriptionController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: l10n.packageNotes,
                      controller: _notesController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: l10n.packageUpdateRisks,
                      controller: _risksController,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: IdeaColors.panelBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: IdeaColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final metadata = GlobalPackageMetadata(
      packageName: widget.packageName,
      customDescription: _descriptionController.text.trim(),
      customNotes: _notesController.text.trim(),
      updateRisks: _risksController.text.trim(),
    );

    await context.read<ProjectManagerState>().updateGlobalPackageMetadata(
          metadata,
        );

    if (mounted) Navigator.of(context).pop();
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: IdeaColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: IdeaColors.panelBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: IdeaColors.panelBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: IdeaColors.accent),
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }
}
