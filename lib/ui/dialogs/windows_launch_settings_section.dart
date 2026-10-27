import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/windows_launch_settings.dart';

class WindowsLaunchSettingsSection extends StatefulWidget {
  const WindowsLaunchSettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
    this.error,
  });

  final WindowsLaunchSettings settings;
  final ValueChanged<WindowsLaunchSettings> onChanged;
  final String? error;

  @override
  State<WindowsLaunchSettingsSection> createState() =>
      _WindowsLaunchSettingsSectionState();
}

class _WindowsLaunchSettingsSectionState
    extends State<WindowsLaunchSettingsSection> {
  late final TextEditingController _exeController;

  @override
  void initState() {
    super.initState();
    _exeController = TextEditingController(text: widget.settings.exePath);
  }

  @override
  void dispose() {
    _exeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = widget.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.windowsLaunchSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.windowsLaunchAtLogon,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Switch(
              value: widget.settings.launchAtLogon,
              onChanged: (value) => widget.onChanged(
                widget.settings.copyWith(launchAtLogon: value),
              ),
              activeThumbColor: IdeaColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _exeController,
          decoration: InputDecoration(
            labelText: l10n.windowsLaunchExePath,
            isDense: true,
          ),
          onChanged: (value) => widget.onChanged(
            widget.settings.copyWith(exePath: value),
          ),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IdeaColors.error,
                ),
          ),
        ],
      ],
    );
  }
}
