import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_productivity.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class GitProductivitySection extends StatefulWidget {
  const GitProductivitySection({super.key, required this.projectPath});

  final String projectPath;

  @override
  State<GitProductivitySection> createState() => _GitProductivitySectionState();
}

class _GitProductivitySectionState extends State<GitProductivitySection> {
  late Future<GitProductivity> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant GitProductivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _future = _load();
    }
  }

  Future<GitProductivity> _load() {
    return context.read<ProjectManagerState>().loadGitProductivity();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<GitProductivity>(
      future: _future,
      builder: (context, snapshot) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IdeaColors.toolbar,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.gitActivityTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.gitActivityWindow,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(color: IdeaColors.accent)
              else if (snapshot.hasError)
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(color: IdeaColors.error, fontSize: 13),
                )
              else
                _Body(data: snapshot.data!, l10n: l10n),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.l10n});

  final GitProductivity data;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (data.commitCount == 0) {
      return Text(l10n.gitActivityEmpty, style: Theme.of(context).textTheme.bodySmall);
    }

    final shown = data.authors.take(GitProductivity.authorLimit).toList();
    final hidden = data.authors.length - shown.length;
    final maxCommits = shown.fold<int>(
      1,
      (max, author) => author.commits > max ? author.commits : max,
    );
    final maxWeek = data.weeks.fold<int>(
      1,
      (max, week) => week.commits > max ? week.commits : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.gitActivityCommits(data.commitCount)} · ${l10n.gitActivityLines(data.additions, data.deletions)}',
          style: const TextStyle(color: IdeaColors.textBright, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.gitActivityWeeks.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.weeks.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: _WeekBar(
                      week: data.weeks[i],
                      maxCommits: maxWeek,
                      showLabel: i == 0 ||
                          i == data.weeks.length - 1 ||
                          i % 4 == 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.gitActivityAuthors.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < shown.length; i++) ...[
          _AuthorBar(author: shown[i], maxCommits: maxCommits, color: _palette[i % _palette.length], l10n: l10n),
          const SizedBox(height: 8),
        ],
        if (hidden > 0)
          Text(
            l10n.gitActivityMoreAuthors(hidden),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Text(
          l10n.gitActivityRecent.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (final change in data.recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    change.date,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    change.author,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: IdeaColors.textBright, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    change.subject,
                    style: const TextStyle(color: IdeaColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.week,
    required this.maxCommits,
    required this.showLabel,
  });

  final GitWeekActivity week;
  final int maxCommits;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final fraction = week.commits / maxCommits;
    final label = '${week.weekStart.day.toString().padLeft(2, '0')}.${week.weekStart.month.toString().padLeft(2, '0')}';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction.clamp(0.04, 1),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: week.commits == 0
                      ? IdeaColors.panelBorder
                      : IdeaColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          showLabel ? label : '',
          style: const TextStyle(color: IdeaColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}

class _AuthorBar extends StatelessWidget {
  const _AuthorBar({
    required this.author,
    required this.maxCommits,
    required this.color,
    required this.l10n,
  });

  final GitAuthorStats author;
  final int maxCommits;
  final Color color;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                author.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: IdeaColors.textBright, fontSize: 13),
              ),
            ),
            Text(
              '${l10n.gitActivityCommits(author.commits)} · ${l10n.gitActivityLines(author.additions, author.deletions)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: author.commits / maxCommits,
            color: color,
            backgroundColor: IdeaColors.inputBackground,
          ),
        ),
      ],
    );
  }
}

const _palette = <Color>[
  IdeaColors.accent,
  IdeaColors.success,
  IdeaColors.warning,
  IdeaColors.hover,
  Color(0xFF9876AA),
  Color(0xFFCC7832),
];
