import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';

class DocSectionCard extends StatelessWidget {
  const DocSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: child,
    );
  }
}

class DocMetaChip extends StatelessWidget {
  const DocMetaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: IdeaColors.toolbar,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: IdeaColors.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: IdeaColors.textBright,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DocStatusBadge extends StatelessWidget {
  const DocStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DocGroupHeader extends StatelessWidget {
  const DocGroupHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: IdeaColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: IdeaColors.textBright,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: IdeaColors.sidebar,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class DocCodeChip extends StatelessWidget {
  const DocCodeChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: IdeaColors.toolbar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Consolas',
          fontSize: 11,
          color: IdeaColors.accent,
        ),
      ),
    );
  }
}

class DocEmptyState extends StatelessWidget {
  const DocEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DocSectionCard(
      child: Row(
        children: [
          Icon(icon, size: 18, color: IdeaColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
