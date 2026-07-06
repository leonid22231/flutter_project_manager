import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GitLabSettingsSection extends StatefulWidget {
  const GitLabSettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final GitLabSettings settings;
  final ValueChanged<GitLabSettings> onChanged;

  @override
  State<GitLabSettingsSection> createState() => _GitLabSettingsSectionState();
}

class _GitLabSettingsSectionState extends State<GitLabSettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.settings.baseUrl);
    _tokenController =
        TextEditingController(text: widget.settings.personalAccessToken);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _update(GitLabSettings value) => widget.onChanged(value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appSettings = context.watch<AppSettingsState>();
    final check = appSettings.lastGitLabCheck;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gitlabSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 6),
        Text(l10n.gitlabSectionHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _ToggleRow(
          label: l10n.gitlabEnabled,
          value: widget.settings.enabled,
          onChanged: (value) => _update(widget.settings.copyWith(enabled: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrlController,
          decoration: InputDecoration(
            labelText: l10n.gitlabBaseUrl,
            isDense: true,
          ),
          onChanged: (value) =>
              _update(widget.settings.copyWith(baseUrl: value)),
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: l10n.gitlabUseEnvToken,
          value: widget.settings.useEnvironmentToken,
          onChanged: (value) =>
              _update(widget.settings.copyWith(useEnvironmentToken: value)),
        ),
        if (!widget.settings.useEnvironmentToken) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.gitlabToken,
              isDense: true,
            ),
            onChanged: (value) =>
                _update(widget.settings.copyWith(personalAccessToken: value)),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: appSettings.isCheckingGitLab
                  ? null
                  : () => appSettings.checkGitLabConnection(widget.settings),
              icon: appSettings.isCheckingGitLab
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link, size: 14),
              label: Text(l10n.gitlabTestConnection),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(GitLabSettings.docsUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(l10n.gitlabOpenDocs),
            ),
          ],
        ),
        if (check != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                check.connected ? Icons.check_circle : Icons.error_outline,
                size: 14,
                color: check.connected ? IdeaColors.success : IdeaColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  check.connected
                      ? (check.username != null
                          ? l10n.gitlabConnectedAs(check.username!)
                          : l10n.gitlabConnectionOk)
                      : (check.error ?? l10n.gitlabConnectionFailed),
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: IdeaColors.accent,
        ),
      ],
    );
  }
}
