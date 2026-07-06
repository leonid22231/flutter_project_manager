import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/validation_result.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class AddProjectDialog extends StatefulWidget {
  const AddProjectDialog({super.key});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final _pathController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  final _notesController = TextEditingController();

  ProjectValidationResult? _validationResult;
  bool _isValidating = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pathController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _browseDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: context.l10n.selectProjectFolder,
    );
    if (path != null) {
      _pathController.text = path;
      await _validatePath();
    }
  }

  Future<void> _validatePath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _validationResult = null);
      return;
    }

    setState(() => _isValidating = true);
    final state = context.read<ProjectManagerState>();
    final result = await state.validateProjectPath(path);
    if (!mounted) return;

    setState(() {
      _validationResult = result;
      _isValidating = false;
      if (_nameController.text.isEmpty && result.projectName != null) {
        _nameController.text = result.projectName!;
      }
    });
  }

  Future<void> _submit() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    setState(() => _isSubmitting = true);
    final state = context.read<ProjectManagerState>();
    final project = await state.addProject(
      path: path,
      name: _nameController.text,
      description: _descriptionController.text,
      goal: _goalController.text,
      notes: _notesController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (project != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final canSubmit = _validationResult?.isValid == true &&
        !_isSubmitting &&
        !_isValidating;

    return Dialog(
      backgroundColor: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: IdeaColors.panelBorder),
      ),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(onClose: () => Navigator.of(context).pop()),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PathField(
                      controller: _pathController,
                      onBrowse: _browseDirectory,
                      onValidate: _validatePath,
                      isValidating: _isValidating,
                    ),
                    const SizedBox(height: 12),
                    if (_validationResult != null)
                      _ValidationPanel(result: _validationResult!),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.projectName,
                        hintText: l10n.projectNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.projectDescription,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _goalController,
                      decoration: InputDecoration(
                        labelText: l10n.projectGoal,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: l10n.labelNotes,
                      ),
                      maxLines: 2,
                    ),
                    if (state.lastError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: state.lastError!),
                    ],
                  ],
                ),
              ),
            ),
            _DialogActions(
              canSubmit: canSubmit,
              isSubmitting: _isSubmitting || state.isAddingProject,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: IdeaColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(l10n.addFlutterProject,
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.controller,
    required this.onBrowse,
    required this.onValidate,
    required this.isValidating,
  });

  final TextEditingController controller;
  final VoidCallback onBrowse;
  final VoidCallback onValidate;
  final bool isValidating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.projectPath,
              hintText: l10n.projectPathHint,
              suffixIcon: isValidating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      onPressed: onValidate,
                      tooltip: l10n.validate,
                    ),
            ),
            onSubmitted: (_) => onValidate(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(l10n.browse),
            style: OutlinedButton.styleFrom(
              foregroundColor: IdeaColors.textPrimary,
              side: const BorderSide(color: IdeaColors.panelBorder),
            ),
          ),
        ),
      ],
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.result});

  final ProjectValidationResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: result.isValid ? IdeaColors.success : IdeaColors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isValid ? Icons.check_circle : Icons.error,
                size: 16,
                color: result.isValid ? IdeaColors.success : IdeaColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                result.isValid
                    ? l10n.validationPassed
                    : l10n.validationFailed,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      result.isValid ? IdeaColors.success : IdeaColors.error,
                ),
              ),
            ],
          ),
          if (result.sdkInfo != null) ...[
            const SizedBox(height: 8),
            _SdkStatus(sdkInfo: result.sdkInfo!),
          ],
          if (result.platforms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.platformsDetected(result.platforms.join(', ')),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (result.dependencies.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.dependenciesFound(result.dependencies.length),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          ...result.errors.map(
            (issue) => _IssueTile(issue: issue, isError: true),
          ),
          ...result.warnings.map(
            (issue) => _IssueTile(issue: issue, isError: false),
          ),
        ],
      ),
    );
  }
}

class _SdkStatus extends StatelessWidget {
  const _SdkStatus({required this.sdkInfo});

  final SdkInfo sdkInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SdkRow(
          label: l10n.flutterSdk,
          available: sdkInfo.flutterAvailable,
          version: sdkInfo.flutterVersion,
        ),
        const SizedBox(height: 4),
        _SdkRow(
          label: l10n.dartSdk,
          available: sdkInfo.dartAvailable,
          version: sdkInfo.dartVersion,
        ),
      ],
    );
  }
}

class _SdkRow extends StatelessWidget {
  const _SdkRow({
    required this.label,
    required this.available,
    this.version,
  });

  final String label;
  final bool available;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusText = available
        ? (version != null
            ? l10n.sdkDetected(version!)
            : l10n.sdkDetected('').trim())
        : l10n.sdkNotFound;
    return Row(
      children: [
        Icon(
          available ? Icons.check : Icons.close,
          size: 14,
          color: available ? IdeaColors.success : IdeaColors.error,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $statusText',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue, required this.isError});

  final ValidationIssue issue;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.message,
            style: TextStyle(
              fontSize: 12,
              color: isError ? IdeaColors.error : IdeaColors.warning,
            ),
          ),
          if (issue.suggestion != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(
                '→ ${issue.suggestion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IdeaColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IdeaColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.error.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: const TextStyle(color: IdeaColors.error, fontSize: 12)),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.canSubmit,
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isSubmitting ? null : onCancel,
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canSubmit && !isSubmitting ? onSubmit : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add, size: 16),
            label: Text(isSubmitting ? l10n.addingProject : l10n.addProject),
            style: FilledButton.styleFrom(
              backgroundColor: IdeaColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
