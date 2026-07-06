import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/git_graph_layout.dart';
import 'package:project_manager/core/utils/gitlab_urls.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/ui/widgets/git_commit_graph_painter.dart';
import 'package:project_manager/ui/widgets/git_commit_info_column.dart';
import 'package:project_manager/ui/widgets/git_commit_tree_guide_painter.dart';
import 'package:url_launcher/url_launcher.dart';

class GitCommitTreeView extends StatefulWidget {
  const GitCommitTreeView({
    super.key,
    required this.roots,
    this.gitStatus,
    this.initialExpanded,
  });

  final List<GitCommitTreeNode> roots;
  final GitRepositoryStatus? gitStatus;
  final Set<String>? initialExpanded;

  @override
  State<GitCommitTreeView> createState() => _GitCommitTreeViewState();
}

class _GitCommitTreeViewState extends State<GitCommitTreeView> {
  late Set<String> _expanded;
  List<GitCommitTreeRow>? _cachedRows;
  Set<String>? _cachedExpanded;
  List<GitCommitTreeNode>? _cachedRoots;

  @override
  void initState() {
    super.initState();
    _expanded = Set<String>.from(
      widget.initialExpanded ?? {for (final root in widget.roots) root.entry.hash},
    );
  }

  @override
  void didUpdateWidget(covariant GitCommitTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.roots, widget.roots)) {
      _expanded = Set<String>.from(
        widget.initialExpanded ?? {for (final root in widget.roots) root.entry.hash},
      );
      _cachedRows = null;
      _cachedExpanded = null;
      _cachedRoots = null;
    }
  }

  List<GitCommitTreeRow> get _rows {
    if (_cachedRows != null &&
        identical(_cachedRoots, widget.roots) &&
        setEquals(_cachedExpanded, _expanded)) {
      return _cachedRows!;
    }

    _cachedRoots = widget.roots;
    _cachedExpanded = Set<String>.from(_expanded);
    _cachedRows = flattenGitCommitTree(widget.roots, _expanded);
    return _cachedRows!;
  }

  void _toggleExpanded(String hash) {
    setState(() {
      if (_expanded.contains(hash)) {
        _expanded.remove(hash);
      } else {
        _expanded.add(hash);
      }
    });
  }

  void expandAll() {
    final all = collectGitCommitTreeHashes(widget.roots);
    if (setEquals(all, _expanded)) return;
    setState(() => _expanded = all);
  }

  void collapseAll() {
    setState(() {
      _expanded = {for (final root in widget.roots) root.entry.hash};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roots.isEmpty) {
      return Center(
        child: Text(
          context.l10n.gitGraphEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final rows = _rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.gitTreeSummary(widget.roots.length, rows.length),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              TextButton(
                onPressed: expandAll,
                child: Text(context.l10n.gitTreeExpandAll),
              ),
              TextButton(
                onPressed: collapseAll,
                child: Text(context.l10n.gitTreeCollapseAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemExtent: gitGraphRowHeight,
            cacheExtent: gitGraphRowHeight * 12,
            itemBuilder: (context, index) {
              final row = rows[index];
              return RepaintBoundary(
                child: _GitCommitTreeRowTile(
                  row: row,
                  gitStatus: widget.gitStatus,
                  onToggle: _toggleExpanded,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GitCommitTreeRowTile extends StatelessWidget {
  const _GitCommitTreeRowTile({
    required this.row,
    required this.gitStatus,
    required this.onToggle,
  });

  final GitCommitTreeRow row;
  final GitRepositoryStatus? gitStatus;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final commitUrl = buildGitLabCommitUrl(gitStatus?.gitlabWebUrl, row.entry.hash);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: commitUrl == null
            ? null
            : () async {
                final uri = Uri.parse(commitUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TreeGuideColumn(row: row, onToggle: onToggle),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: GitCommitInfoColumn(entry: row.entry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeGuideColumn extends StatelessWidget {
  const _TreeGuideColumn({
    required this.row,
    required this.onToggle,
  });

  final GitCommitTreeRow row;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final contentWidth = (row.depth + 1) * gitTreeIndentWidth + gitTreeGuideWidth;
    final columnWidth = contentWidth > gitTreeMaxGuideColumnWidth
        ? gitTreeMaxGuideColumnWidth
        : contentWidth;

    final expandButton = row.hasParents
        ? SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              icon: Icon(
                row.isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: IdeaColors.textSecondary,
              ),
              tooltip: row.isExpanded
                  ? context.l10n.gitTreeCollapse
                  : context.l10n.gitTreeExpand,
              onPressed: () => onToggle(row.entry.hash),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            ),
          )
        : const SizedBox(width: 20);

    final guide = Row(
      children: [
        Expanded(
          child: CustomPaint(
            painter: GitCommitTreeGuidePainter(row: row),
            isComplex: true,
            willChange: false,
          ),
        ),
        expandButton,
      ],
    );

    if (contentWidth <= gitTreeMaxGuideColumnWidth) {
      return SizedBox(
        width: columnWidth,
        height: gitGraphRowHeight,
        child: guide,
      );
    }

    return SizedBox(
      width: columnWidth,
      height: gitGraphRowHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: contentWidth,
          height: gitGraphRowHeight,
          child: guide,
        ),
      ),
    );
  }
}
