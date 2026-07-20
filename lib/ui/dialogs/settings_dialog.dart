import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:project_manager/services/settings_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/dialogs/context_sync_settings_section.dart';
import 'package:project_manager/ui/dialogs/cursor_cli_settings_section.dart';
import 'package:project_manager/ui/dialogs/gitlab_settings_section.dart';
import 'package:provider/provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late Locale _selectedLocale;
  late CursorCliSettings _cursorCliSettings;
  late GitLabSettings _gitlabSettings;
  late ContextSyncSettings _contextSyncSettings;
  late double _uiScale;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettingsState>();
    _selectedLocale = settings.locale;
    _cursorCliSettings = settings.cursorCliSettings;
    _gitlabSettings = settings.gitlabSettings;
    _contextSyncSettings = settings.contextSyncSettings;
    _uiScale = settings.uiScale;
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(title: l10n.settings),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.language.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _LanguageOption(
                      label: l10n.english,
                      locale: const Locale('en'),
                      groupValue: _selectedLocale,
                      onChanged: (locale) =>
                          setState(() => _selectedLocale = locale),
                    ),
                    const SizedBox(height: 8),
                    _LanguageOption(
                      label: l10n.russian,
                      locale: const Locale('ru'),
                      groupValue: _selectedLocale,
                      onChanged: (locale) =>
                          setState(() => _selectedLocale = locale),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.uiScaleLabel.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.uiScaleValue(_uiScale.toStringAsFixed(2)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: _uiScale,
                      min: SettingsService.minUiScale,
                      max: SettingsService.maxUiScale,
                      divisions: 11,
                      label: _uiScale.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _uiScale = v),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    CursorCliSettingsSection(
                      settings: _cursorCliSettings,
                      onChanged: (value) =>
                          setState(() => _cursorCliSettings = value),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    GitLabSettingsSection(
                      settings: _gitlabSettings,
                      onChanged: (value) =>
                          setState(() => _gitlabSettings = value),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    ContextSyncSettingsSection(
                      settings: _contextSyncSettings,
                      onChanged: (value) =>
                          setState(() => _contextSyncSettings = value),
                    ),
                  ],
                ),
              ),
            ),
            _DialogActions(
              onCancel: () => Navigator.of(context).pop(),
              onSave: () async {
                final appSettings = context.read<AppSettingsState>();
                await appSettings.setLocale(_selectedLocale);
                await appSettings.setUiScale(_uiScale);
                await appSettings.saveCursorCliSettings(_cursorCliSettings);
                await appSettings.saveGitLabSettings(_gitlabSettings);
                await appSettings.saveContextSyncSettings(_contextSyncSettings);
                if (context.mounted) {
                  context.read<ProjectManagerState>().reloadContextSyncSchedule();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: IdeaColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.locale,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final Locale locale;
  final Locale groupValue;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue.languageCode == locale.languageCode;

    return Material(
      color: isSelected ? IdeaColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () => onChanged(locale),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? IdeaColors.accent : IdeaColors.panelBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 16,
                color: isSelected ? IdeaColors.accent : IdeaColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;

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
          TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
