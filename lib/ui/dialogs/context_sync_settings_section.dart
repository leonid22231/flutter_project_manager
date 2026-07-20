import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:provider/provider.dart';

class ContextSyncSettingsSection extends StatefulWidget {
  const ContextSyncSettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ContextSyncSettings settings;
  final ValueChanged<ContextSyncSettings> onChanged;

  @override
  State<ContextSyncSettingsSection> createState() =>
      _ContextSyncSettingsSectionState();
}

class _ContextSyncSettingsSectionState
    extends State<ContextSyncSettingsSection> {
  late final TextEditingController _repoUrlController;
  late final TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _repoUrlController = TextEditingController(text: widget.settings.repoUrl);
    _intervalController = TextEditingController(
      text: '${widget.settings.syncIntervalMinutes}',
    );
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _update(ContextSyncSettings value) => widget.onChanged(value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appSettings = context.watch<AppSettingsState>();
    final check = appSettings.lastContextSyncCheck;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contextSyncSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.contextSyncSectionHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.contextSyncEnabled,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Switch(
              value: widget.settings.enabled,
              onChanged: (value) =>
                  _update(widget.settings.copyWith(enabled: value)),
              activeThumbColor: IdeaColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repoUrlController,
          decoration: InputDecoration(
            labelText: l10n.contextSyncRepoUrl,
            hintText: 'git@github.com:org/ai-contexts.git',
            isDense: true,
          ),
          onChanged: (value) =>
              _update(widget.settings.copyWith(repoUrl: value)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _intervalController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.contextSyncIntervalMinutes,
            isDense: true,
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed == null) return;
            _update(widget.settings.copyWith(syncIntervalMinutes: parsed));
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: appSettings.isCheckingContextSync
              ? null
              : () => appSettings.checkContextSyncRepo(widget.settings),
          icon: appSettings.isCheckingContextSync
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link, size: 14),
          label: Text(l10n.contextSyncTestRepo),
        ),
        if (check != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                check.ok ? Icons.check_circle : Icons.error_outline,
                size: 14,
                color: check.ok ? IdeaColors.success : IdeaColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  check.ok
                      ? l10n.contextSyncRepoOk
                      : (check.error ?? l10n.contextSyncRepoFailed),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
