import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';

class GitCommitInfoColumn extends StatelessWidget {
  const GitCommitInfoColumn({
    super.key,
    required this.entry,
  });

  final GitCommitGraphEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              entry.shortHash,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                height: 1.1,
                color: IdeaColors.accent,
              ),
            ),
            if (entry.decorationsLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.decorationsLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    color: IdeaColors.success,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const Spacer(),
            if (entry.committedAt != null)
              Flexible(
                child: Text(
                  _formatDate(entry.committedAt!),
                  style:
                      Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          entry.subject,
          style: const TextStyle(fontSize: 12, height: 1.15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          entry.author,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
