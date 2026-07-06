import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';

class TopActionBar extends StatelessWidget {
  const TopActionBar({
    super.key,
    required this.onAddProject,
    required this.onSettings,
    this.onRefresh,
    this.onExportDocs,
  });

  final VoidCallback onAddProject;
  final VoidCallback onSettings;
  final VoidCallback? onRefresh;
  final VoidCallback? onExportDocs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.add,
            label: l10n.addProject,
            onPressed: onAddProject,
            isPrimary: true,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.refresh,
            label: l10n.refresh,
            onPressed: onRefresh,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.upload_file,
            label: l10n.exportDocs,
            onPressed: onExportDocs,
          ),
          const Spacer(),
          _ActionButton(
            icon: Icons.settings,
            label: l10n.settings,
            onPressed: onSettings,
          ),
          const SizedBox(width: 8),
          _AppTitle(title: l10n.appTitle),
        ],
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flutter_dash, color: IdeaColors.accent, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Tooltip(
      message: label,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: enabled
              ? (isPrimary ? IdeaColors.accent : IdeaColors.textPrimary)
              : IdeaColors.textSecondary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
