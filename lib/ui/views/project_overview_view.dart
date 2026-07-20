import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/l10n/l10n_extensions.dart';
import 'package:project_manager/models/project.dart';

class ProjectOverviewView extends StatelessWidget {
  const ProjectOverviewView({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flutter_dash, color: IdeaColors.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      project.path,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusChip(label: project.status.localized(l10n)),
              if (!project.sdkAvailable) ...[
                const SizedBox(width: 8),
                _StatusChip(
                  label: l10n.sdkIssue,
                  color: IdeaColors.warning,
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final opened = await openInVsCode(project.path);
                  if (!context.mounted || opened) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.openInVsCodeFailed)),
                  );
                },
                icon: const Icon(Icons.code, size: 16),
                label: Text(l10n.openInVsCode),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final opened = await openInCursor(project.path);
                  if (!context.mounted || opened) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.openInCursorFailed)),
                  );
                },
                icon: const Icon(Icons.terminal, size: 16),
                label: Text(l10n.openInCursor),
              ),
            ],          ),
          const SizedBox(height: 24),
          _InfoGrid(project: project),
          const SizedBox(height: 24),
          if (project.description.isNotEmpty) ...[
            _Section(title: l10n.labelDescription, content: project.description),
            const SizedBox(height: 16),
          ],
          if (project.goal.isNotEmpty) ...[
            _Section(title: l10n.labelGoal, content: project.goal),
            const SizedBox(height: 16),
          ],
          if (project.notes.isNotEmpty) ...[
            _Section(title: l10n.labelNotes, content: project.notes),
            const SizedBox(height: 16),
          ],
          if (project.changeHistory.isNotEmpty) ...[
            Text(
              l10n.recentActivity,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...project.changeHistory.reversed.take(5).map(
                  (record) => _ActivityItem(
                    title: record.title,
                    description: record.description,
                    timestamp: record.timestamp,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? IdeaColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: chipColor, fontSize: 11),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _InfoItem(l10n.labelFlutter, project.flutterVersion ?? l10n.notAvailable),
      _InfoItem(l10n.labelDart, project.dartVersion ?? l10n.notAvailable),
      _InfoItem(
        l10n.labelPlatforms,
        project.platforms.isEmpty ? l10n.none : project.platforms.join(', '),
      ),
      _InfoItem(l10n.labelDependencies, '${project.dependencies.length}'),
      _InfoItem(
        l10n.labelAdded,
        project.addedAt.toIso8601String().split('T').first,
      ),
      _InfoItem(l10n.labelWidgets, '${project.widgets.length}'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              width: 180,
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
                    item.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: IdeaColors.textBright,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: IdeaColors.sidebar,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Text(content, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.title,
    required this.description,
    required this.timestamp,
  });

  final String title;
  final String description;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IdeaColors.sidebar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                timestamp.toIso8601String().split('T').first,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
