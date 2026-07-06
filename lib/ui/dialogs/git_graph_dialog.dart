import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/git_graph_layout.dart';
import 'package:project_manager/core/utils/gitlab_urls.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/ui/widgets/git_commit_graph_view.dart';
import 'package:project_manager/ui/widgets/git_commit_tree_view.dart';
import 'package:url_launcher/url_launcher.dart';

enum GitGraphViewMode { graph, tree }

Future<void> showGitGraphDialog(
  BuildContext context, {
  required String title,
  required Future<List<GitCommitGraphRow>> Function() loadGraph,
  required String scopeLabel,
  GitRepositoryStatus? gitStatus,
  bool isProjectScope = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => GitGraphDialog(
      title: title,
      loadGraph: loadGraph,
      scopeLabel: scopeLabel,
      gitStatus: gitStatus,
      isProjectScope: isProjectScope,
    ),
  );
}

class GitGraphDialog extends StatefulWidget {
  const GitGraphDialog({
    super.key,
    required this.title,
    required this.loadGraph,
    required this.scopeLabel,
    this.gitStatus,
    this.isProjectScope = false,
  });

  final String title;
  final Future<List<GitCommitGraphRow>> Function() loadGraph;
  final String scopeLabel;
  final GitRepositoryStatus? gitStatus;
  final bool isProjectScope;

  @override
  State<GitGraphDialog> createState() => _GitGraphDialogState();
}

class _GitGraphDialogState extends State<GitGraphDialog> {
  late Future<List<GitCommitGraphRow>> _future;
  GitGraphViewMode _viewMode = GitGraphViewMode.graph;

  @override
  void initState() {
    super.initState();
    _future = widget.loadGraph();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.loadGraph();
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
    final gitlabUrl = widget.isProjectScope
        ? buildGitLabNetworkUrl(gitStatus?.gitlabWebUrl, gitStatus?.branch)
        : buildGitLabFileHistoryUrl(
            gitStatus?.gitlabWebUrl,
            gitStatus?.branch,
            widget.scopeLabel,
          );

    return Dialog(
      backgroundColor: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: IdeaColors.panelBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
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
                  const Icon(Icons.account_tree, size: 18, color: IdeaColors.accent),
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
                          widget.scopeLabel,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  SegmentedButton<GitGraphViewMode>(
                    segments: [
                      ButtonSegment(
                        value: GitGraphViewMode.graph,
                        label: Text(l10n.gitGraphViewLanes),
                        icon: const Icon(Icons.timeline, size: 14),
                      ),
                      ButtonSegment(
                        value: GitGraphViewMode.tree,
                        label: Text(l10n.gitGraphViewTree),
                        icon: const Icon(Icons.account_tree_outlined, size: 14),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (selection) {
                      setState(() => _viewMode = selection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  if (gitlabUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(gitlabUrl),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(
                        widget.isProjectScope
                            ? l10n.gitOpenProjectGraphInGitLab
                            : l10n.gitOpenFileGraphInGitLab,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<GitCommitGraphRow>>(
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

                  final rows = snapshot.data ?? const [];
                  if (_viewMode == GitGraphViewMode.graph) {
                    return GitCommitGraphView(
                      rows: rows,
                      gitStatus: gitStatus,
                    );
                  }

                  final entries = [for (final row in rows) row.entry];
                  final treeRoots = buildGitCommitTree(entries);
                  return GitCommitTreeView(
                    key: ValueKey('tree-${entries.length}-${entries.firstOrNull?.hash}'),
                    roots: treeRoots,
                    gitStatus: gitStatus,
                    initialExpanded: defaultExpandedGitCommitTree(treeRoots),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
