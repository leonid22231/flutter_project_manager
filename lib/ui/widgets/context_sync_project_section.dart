import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class ContextSyncProjectSection extends StatefulWidget {
  const ContextSyncProjectSection({super.key, required this.project});

  final Project project;

  @override
  State<ContextSyncProjectSection> createState() =>
      _ContextSyncProjectSectionState();
}

class _ContextSyncProjectSectionState extends State<ContextSyncProjectSection> {
  late final TextEditingController _idController;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.project.contextId);
  }

  @override
  void didUpdateWidget(covariant ContextSyncProjectSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.project.contextId != widget.project.contextId) {
      _idController.text = widget.project.contextId;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _saveId(ProjectManagerState state) async {
    final ok = await state.updateProjectContextId(_idController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contextSyncInvalidId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final appSettings = context.watch<AppSettingsState>();
    final status = state.statusForContext(widget.project.contextId);
    final syncEnabled = appSettings.contextSyncSettings.isActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IdeaColors.sidebar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.contextSyncProjectSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.contextSyncProjectHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.machineSettingsSyncHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.contextSyncProjectId.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          if (_editing) ...[
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.contextSyncProjectIdHint,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _saveId(state),
                  style: FilledButton.styleFrom(
                    backgroundColor: IdeaColors.accent,
                  ),
                  child: Text(l10n.save),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editing = false;
                      _idController.text = widget.project.contextId;
                    });
                  },
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    widget.project.contextId,
                    style: const TextStyle(
                      color: IdeaColors.textBright,
                      fontSize: 13,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.contextSyncCopyId,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.project.contextId),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.contextSyncIdCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                ),
                IconButton(
                  tooltip: l10n.contextSyncEditId,
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await state.regenerateProjectContextId();
                    if (!mounted) return;
                    _idController.text =
                        state.selectedProject?.contextId ??
                            ContextIdUtils.generateUuid();
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(l10n.contextSyncGenerateId),
                ),
                OutlinedButton.icon(
                  onPressed: !syncEnabled || status.isSyncing
                      ? null
                      : () => state.syncContextNow(),
                  icon: status.isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 14),
                  label: Text(l10n.contextSyncNow),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _SyncStatusRow(status: status, syncEnabled: syncEnabled),
        ],
      ),
    );
  }
}

class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow({
    required this.status,
    required this.syncEnabled,
  });

  final ContextSyncStatus status;
  final bool syncEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = status.hasError
        ? IdeaColors.error
        : status.isSyncing
            ? IdeaColors.accent
            : IdeaColors.success;
    final text = !syncEnabled
        ? l10n.contextSyncDisabled
        : status.hasError
            ? (status.error ?? l10n.contextSyncFailed)
            : status.isSyncing
                ? (status.message ?? l10n.contextSyncInProgress)
                : status.lastSyncedAt != null
                    ? l10n.contextSyncLastAt(
                        status.lastSyncedAt!.toLocal().toIso8601String(),
                      )
                    : l10n.contextSyncIdle;

    return Row(
      children: [
        Icon(
          status.hasError
              ? Icons.error_outline
              : status.isSyncing
                  ? Icons.sync
                  : Icons.check_circle_outline,
          size: 14,
          color: syncEnabled ? color : IdeaColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
