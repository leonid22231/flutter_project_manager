import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/gitlab_urls.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_commit_entry.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showGitHistoryDialog(
  BuildContext context, {
  required String title,
  required Future<List<GitCommitEntry>> Function() loadCommits,
  required String relativePath,
  GitRepositoryStatus? gitStatus,
  int? line,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => GitHistoryDialog(
      title: title,
      loadCommits: loadCommits,
      relativePath: relativePath,
      gitStatus: gitStatus,
      line: line,
    ),
  );
}

class GitHistoryDialog extends StatefulWidget {
  const GitHistoryDialog({
    super.key,
    required this.title,
    required this.loadCommits,
    required this.relativePath,
    this.gitStatus,
    this.line,
  });

  final String title;
  final Future<List<GitCommitEntry>> Function() loadCommits;
  final String relativePath;
  final GitRepositoryStatus? gitStatus;
  final int? line;

  @override
  State<GitHistoryDialog> createState() => _GitHistoryDialogState();
}

class _GitHistoryDialogState extends State<GitHistoryDialog> {
  late Future<List<GitCommitEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadCommits();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.loadCommits();
    });
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gitStatus = widget.gitStatus;
    final gitlabUrl = widget.line != null
        ? buildGitLabBlameUrl(
            gitStatus?.gitlabWebUrl,
            gitStatus?.branch,
            widget.relativePath,
            widget.line!,
          )
        : buildGitLabFileHistoryUrl(
            gitStatus?.gitlabWebUrl,
            gitStatus?.branch,
            widget.relativePath,
          );

    return Dialog(
      backgroundColor: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: IdeaColors.panelBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18, color: IdeaColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          widget.relativePath,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            color: IdeaColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.refreshGitStatus,
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            if (gitlabUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openUrl(gitlabUrl),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      widget.line != null
                          ? l10n.gitOpenLineInGitLab(widget.line!)
                          : l10n.gitOpenFileHistoryInGitLab,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<GitCommitEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: IdeaColors.accent),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '${snapshot.error}',
                          style: const TextStyle(
                            color: IdeaColors.error,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final commits = snapshot.data ?? const [];
                  if (commits.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.gitHistoryEmpty,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: commits.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final commit = commits[index];
                      final commitUrl = buildGitLabCommitUrl(
                        gitStatus?.gitlabWebUrl,
                        commit.hash,
                      );

                      return InkWell(
                        onTap: commitUrl != null
                            ? () => _openUrl(commitUrl)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    commit.shortHash,
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 11,
                                      color: IdeaColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      commit.author,
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (commit.committedAt != null)
                                    Text(
                                      _formatDate(commit.committedAt!),
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                commit.subject,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
