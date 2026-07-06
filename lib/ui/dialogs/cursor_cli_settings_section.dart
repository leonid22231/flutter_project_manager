import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/cursor_cli_check_result.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:provider/provider.dart';

class CursorCliSettingsSection extends StatefulWidget {
  const CursorCliSettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final CursorCliSettings settings;
  final ValueChanged<CursorCliSettings> onChanged;

  @override
  State<CursorCliSettingsSection> createState() =>
      _CursorCliSettingsSectionState();
}

class _CursorCliSettingsSectionState extends State<CursorCliSettingsSection> {
  late final TextEditingController _commandController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _customModelController;
  var _useCustomModel = false;

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(text: widget.settings.cliCommand);
    _apiKeyController = TextEditingController(text: widget.settings.apiKey);
    _useCustomModel = !widget.settings.usesPresetModel;
    _customModelController = TextEditingController(
      text: _useCustomModel ? widget.settings.defaultModel : '',
    );
  }

  @override
  void didUpdateWidget(CursorCliSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.cliCommand != widget.settings.cliCommand &&
        _commandController.text != widget.settings.cliCommand) {
      _commandController.text = widget.settings.cliCommand;
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appSettings = context.watch<AppSettingsState>();
    final cliService = appSettings.cursorCliService;
    final check = appSettings.lastCursorCliCheck;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cursorCliSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 6),
        Text(l10n.cursorCliSectionHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _ToggleRow(
          label: l10n.cursorCliEnabled,
          value: widget.settings.enabled,
          onChanged: (value) => _update(widget.settings.copyWith(enabled: value)),
        ),
        const SizedBox(height: 12),
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cursorCliInstallTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IdeaColors.textBright,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.cursorCliInstallHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              _CommandBlock(
                label: 'PowerShell / Bash',
                command: cliService.installCommandForPlatform(),
              ),
              const SizedBox(height: 8),
              _CommandBlock(
                label: l10n.cursorCliVerifyCommand,
                command: cliService.verifyCommand(widget.settings),
              ),
              const SizedBox(height: 8),
              _CommandBlock(
                label: l10n.cursorCliAuthCommand,
                command: cliService.authCommand(widget.settings),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LinkChip(
                    label: l10n.cursorCliOpenInstallDocs,
                    onTap: () => openExternalUrl(CursorCliSettings.installDocsUrl),
                  ),
                  _LinkChip(
                    label: l10n.cursorCliOpenOverview,
                    onTap: () => openExternalUrl(CursorCliSettings.overviewUrl),
                  ),
                  _LinkChip(
                    label: l10n.cursorCliOpenAuthDocs,
                    onTap: () => openExternalUrl(CursorCliSettings.authDocsUrl),
                  ),
                  _LinkChip(
                    label: l10n.cursorCliOpenParametersDocs,
                    onTap: () =>
                        openExternalUrl(CursorCliSettings.parametersDocsUrl),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FieldLabel(l10n.cursorCliCommand),
        const SizedBox(height: 6),
        TextField(
          controller: _commandController,
          enabled: widget.settings.enabled,
          style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
          decoration: InputDecoration(hintText: l10n.cursorCliCommandHint),
          onChanged: (value) =>
              _update(widget.settings.copyWith(cliCommand: value)),
        ),
        const SizedBox(height: 12),
        _FieldLabel(l10n.cursorCliApiKey),
        const SizedBox(height: 6),
        TextField(
          controller: _apiKeyController,
          enabled: widget.settings.enabled && !widget.settings.useEnvironmentApiKey,
          obscureText: true,
          style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
          decoration: InputDecoration(hintText: l10n.cursorCliApiKeyHint),
          onChanged: (value) => _update(widget.settings.copyWith(apiKey: value)),
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: l10n.cursorCliUseEnvApiKey,
          value: widget.settings.useEnvironmentApiKey,
          enabled: widget.settings.enabled,
          onChanged: (value) =>
              _update(widget.settings.copyWith(useEnvironmentApiKey: value)),
        ),
        const SizedBox(height: 12),
        _FieldLabel(l10n.cursorCliDefaultModel),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _useCustomModel ? '__custom__' : widget.settings.defaultModel,
          decoration: const InputDecoration(isDense: true),
          items: [
            ...CursorCliSettings.presetModels.map(
              (model) => DropdownMenuItem(value: model, child: Text(model)),
            ),
            DropdownMenuItem(
              value: '__custom__',
              child: Text(l10n.cursorCliCustomModel),
            ),
          ],
          onChanged: widget.settings.enabled
              ? (value) {
                  if (value == null) return;
                  if (value == '__custom__') {
                    setState(() => _useCustomModel = true);
                    _update(
                      widget.settings.copyWith(
                        defaultModel: _customModelController.text.trim().isEmpty
                            ? widget.settings.defaultModel
                            : _customModelController.text.trim(),
                      ),
                    );
                  } else {
                    setState(() => _useCustomModel = false);
                    _update(widget.settings.copyWith(defaultModel: value));
                  }
                }
              : null,
        ),
        if (_useCustomModel) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customModelController,
            enabled: widget.settings.enabled,
            style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
            decoration: InputDecoration(hintText: 'composer-2.5'),
            onChanged: (value) =>
                _update(widget.settings.copyWith(defaultModel: value.trim())),
          ),
        ],
        const SizedBox(height: 12),
        _FieldLabel(l10n.cursorCliDefaultMode),
        const SizedBox(height: 6),
        SegmentedButton<CursorCliMode>(
          segments: CursorCliMode.values
              .map(
                (mode) => ButtonSegment(
                  value: mode,
                  label: Text(l10n.cursorCliModeLabel(mode.name)),
                ),
              )
              .toList(),
          selected: {widget.settings.defaultMode},
          onSelectionChanged: widget.settings.enabled
              ? (selection) =>
                  _update(widget.settings.copyWith(defaultMode: selection.first))
              : null,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton.icon(
              onPressed: !widget.settings.enabled || appSettings.isCheckingCursorCli
                  ? null
                  : () => appSettings.checkCursorCliConnection(widget.settings),
              style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
              icon: appSettings.isCheckingCursorCli
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link, size: 16),
              label: Text(l10n.cursorCliTestConnection),
            ),
          ],
        ),
        if (check != null) ...[
          const SizedBox(height: 10),
          _ConnectionStatusCard(result: check),
        ],
      ],
    );
  }

  void _update(CursorCliSettings settings) {
    widget.onChanged(settings);
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.result});

  final CursorCliCheckResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = result.isSuccess;
    final color = ok ? IdeaColors.success : IdeaColors.warning;

    return _InfoCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.warning_amber,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                ok ? l10n.cursorCliConnectionOk : l10n.cursorCliConnectionFailed,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (result.version != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.cursorCliVersionDetected(result.version!),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (result.availableModels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.cursorCliModelsFound(result.availableModels.length),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (result.error != null) ...[
            const SizedBox(height: 6),
            Text(
              result.error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (result.authenticated == false) ...[
            const SizedBox(height: 6),
            Text(
              l10n.cursorCliAuthRequired,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (result.statusMessage != null &&
              result.statusMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IdeaColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: IdeaColors.panelBorder),
              ),
              child: Text(
                result.statusMessage!,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor ?? IdeaColors.panelBorder),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Switch(
          value: value,
          activeThumbColor: IdeaColors.accent,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _CommandBlock extends StatelessWidget {
  const _CommandBlock({
    required this.label,
    required this.command,
  });

  final String label;
  final String command;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: IdeaColors.toolbar,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  command,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: IdeaColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: command));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.copied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Text(l10n.copy, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.open_in_new, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: IdeaColors.accent,
        side: const BorderSide(color: IdeaColors.panelBorder),
      ),
    );
  }
}
