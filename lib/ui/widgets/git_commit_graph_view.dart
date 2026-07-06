import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/gitlab_urls.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/ui/widgets/git_commit_info_column.dart';
import 'package:project_manager/ui/widgets/git_commit_graph_painter.dart';
import 'package:url_launcher/url_launcher.dart';

class GitCommitGraphView extends StatelessWidget {
  const GitCommitGraphView({
    super.key,
    required this.rows,
    this.gitStatus,
    this.onOpenCommit,
  });

  final List<GitCommitGraphRow> rows;
  final GitRepositoryStatus? gitStatus;
  final void Function(String commitHash)? onOpenCommit;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          context.l10n.gitGraphEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final maxLanes = rows
        .map((row) => row.laneCount)
        .fold<int>(1, (value, lanes) => lanes > value ? lanes : value);
    final graphWidth = maxLanes * gitGraphLaneWidth + 8;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final row = rows[index];
        final commitUrl = buildGitLabCommitUrl(
          gitStatus?.gitlabWebUrl,
          row.entry.hash,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: commitUrl == null
                ? null
                : () async {
                    if (onOpenCommit != null) {
                      onOpenCommit!(row.entry.hash);
                      return;
                    }
                    final uri = Uri.parse(commitUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: gitGraphRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: graphWidth,
                    height: gitGraphRowHeight,
                    child: CustomPaint(
                      painter: GitCommitGraphPainter(row: row),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: GitCommitInfoColumn(entry: row.entry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
