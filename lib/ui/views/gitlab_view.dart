import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/models/gitlab_check_result.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/git_file_change.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/dialogs/git_graph_dialog.dart';
import 'package:project_manager/ui/dialogs/git_history_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum _GitChangeFilter { all, staged, unstaged, untracked }

class GitLabView extends StatefulWidget {
  const GitLabView({super.key});

  @override
  State<GitLabView> createState() => _GitLabViewState();
}

class _GitLabViewState extends State<GitLabView> {
  _GitChangeFilter _filter = _GitChangeFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final appSettings = context.watch<AppSettingsState>();
    final project = state.selectedProject;
    final l10n = context.l10n;
    final status = state.gitRepositoryStatus;

    if (project == null) return const SizedBox.shrink();

    if (state.isLoadingGit && status == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: IdeaColors.accent),
            const SizedBox(height: 12),
            Text(l10n.loadingGitStatus, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    if (status == null) {
      return const SizedBox.shrink();
    }

    if (!status.isRepository) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            status.error ?? l10n.gitNotRepository,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final filtered = _applyFilter(status.changes, _filter);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.gitSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.gitProjectGraph,
                onPressed: () => showGitGraphDialog(
                  context,
                  title: l10n.gitProjectGraph,
                  loadGraph: state.loadGitProjectGraph,
                  scopeLabel: project.name,
                  gitStatus: status,
                  isProjectScope: true,
                ),
                icon: const Icon(Icons.account_tree_outlined, size: 18),
              ),
              IconButton(
                tooltip: l10n.refreshGitStatus,
                onPressed: state.isLoadingGit
                    ? null
                    : () => state.refreshGitStatus(
                          configuredGitLabBaseUrl:
                              appSettings.gitlabSettings.enabled
                                  ? appSettings.gitlabSettings.normalizedBaseUrl
                                  : null,
                        ),
                icon: state.isLoadingGit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: IdeaColors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RepoInfoCard(
            status: status,
            gitLabCheck: appSettings.lastGitLabCheck,
            gitLabEnabled: appSettings.gitlabSettings.enabled,
            onOpenGitLab: status.gitlabWebUrl == null
                ? null
                : () => _openUrl(status.gitlabWebUrl!),
          ),
          const SizedBox(height: 16),
          if (status.error != null) ...[
            _ErrorBanner(message: status.error!),
            const SizedBox(height: 12),
          ],
          if (status.isClean)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: IdeaColors.success,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.gitWorkingTreeClean,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              l10n.gitChangesSummary(
                status.changes.length,
                status.stagedCount,
                status.unstagedCount,
                status.untrackedCount,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _GitChangeFilter.values.map((filter) {
                return FilterChip(
                  label: Text(_filterLabel(l10n, filter)),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Text(
                l10n.noWidgetsFound,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...filtered.map(
                (change) => _ChangeTile(
                  change: change,
                  l10n: l10n,
                  onTap: () => state.openFile(
                    p.join(project.path, change.path.replaceAll('/', p.separator)),
                  ),
                  onHistory: status.isRepository
                      ? () => showGitHistoryDialog(
                            context,
                            title: l10n.gitFileHistory,
                            loadCommits: () =>
                                state.loadGitFileHistory(change.path),
                            relativePath: change.path,
                            gitStatus: status,
                          )
                      : null,
                  onGraph: status.isRepository
                      ? () => showGitGraphDialog(
                            context,
                            title: l10n.gitFileGraph,
                            loadGraph: () =>
                                state.loadGitFileGraph(change.path),
                            scopeLabel: change.path,
                            gitStatus: status,
                          )
                      : null,
                ),
              ),
          ],
          if (!appSettings.gitlabSettings.enabled) ...[
            const SizedBox(height: 16),
            Text(
              l10n.gitConfigureGitLab,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<GitFileChange> _applyFilter(
    List<GitFileChange> changes,
    _GitChangeFilter filter,
  ) {
    return switch (filter) {
      _GitChangeFilter.all => changes,
      _GitChangeFilter.staged =>
        changes.where((c) => c.hasStagedChanges).toList(),
      _GitChangeFilter.unstaged =>
        changes.where((c) => c.hasUnstagedChanges && !c.isUntracked).toList(),
      _GitChangeFilter.untracked =>
        changes.where((c) => c.isUntracked).toList(),
    };
  }

  String _filterLabel(AppLocalizations l10n, _GitChangeFilter filter) {
    return switch (filter) {
      _GitChangeFilter.all => l10n.gitFilterAll,
      _GitChangeFilter.staged => l10n.gitFilterStaged,
      _GitChangeFilter.unstaged => l10n.gitFilterUnstaged,
      _GitChangeFilter.untracked => l10n.gitFilterUntracked,
    };
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _RepoInfoCard extends StatelessWidget {
  const _RepoInfoCard({
    required this.status,
    required this.gitLabEnabled,
    this.gitLabCheck,
    this.onOpenGitLab,
  });

  final GitRepositoryStatus status;
  final bool gitLabEnabled;
  final GitLabCheckResult? gitLabCheck;
  final VoidCallback? onOpenGitLab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = gitLabCheck;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IdeaColors.toolbar,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status.branch != null)
            _InfoRow(label: l10n.gitBranch, value: status.branch!),
          if (status.upstreamBranch != null)
            _InfoRow(label: l10n.gitUpstream, value: status.upstreamBranch!),
          if (status.ahead != null && status.behind != null)
            _InfoRow(
              label: l10n.gitAheadBehind,
              value: l10n.gitAheadBehindValue(status.ahead!, status.behind!),
            ),
          if (status.remoteUrl != null)
            _InfoRow(label: l10n.gitRemote, value: status.remoteUrl!),
          if (status.isGitLabRemote && onOpenGitLab != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onOpenGitLab,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(l10n.gitOpenInGitLab),
            ),
          ],
          if (gitLabEnabled && check != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  check.connected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 14,
                  color: check.connected
                      ? IdeaColors.success
                      : IdeaColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    check.connected
                        ? (check.username != null
                            ? l10n.gitlabConnectedAs(check.username!)
                            : l10n.gitlabConnectionOk)
                        : (check.error ?? l10n.gitlabConnectionFailed),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: IdeaColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IdeaColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IdeaColors.error.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: IdeaColors.error, fontSize: 12),
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({
    required this.change,
    required this.l10n,
    required this.onTap,
    this.onHistory,
    this.onGraph,
  });

  final GitFileChange change;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback? onHistory;
  final VoidCallback? onGraph;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: IdeaColors.sidebar,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Row(
            children: [
              _StatusBadge(
                label: l10n.gitStatusLabel(change.kind.name),
                color: _colorForKind(change.kind),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      change.path,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: IdeaColors.textBright,
                      ),
                    ),
                    if (change.oldPath != null)
                      Text(
                        '← ${change.oldPath}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              if (onGraph != null) ...[
                IconButton(
                  icon: const Icon(Icons.account_tree_outlined, size: 16),
                  tooltip: l10n.gitViewGraph,
                  onPressed: onGraph,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
              if (onHistory != null) ...[
                IconButton(
                  icon: const Icon(Icons.history, size: 16),
                  tooltip: l10n.gitViewHistory,
                  onPressed: onHistory,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: IdeaColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForKind(GitChangeKind kind) {
    return switch (kind) {
      GitChangeKind.untracked => IdeaColors.textSecondary,
      GitChangeKind.modified || GitChangeKind.stagedModified => IdeaColors.accent,
      GitChangeKind.staged || GitChangeKind.added => IdeaColors.success,
      GitChangeKind.deleted || GitChangeKind.conflicted => IdeaColors.error,
      GitChangeKind.renamed || GitChangeKind.copied => IdeaColors.warning,
      GitChangeKind.ignored => IdeaColors.textSecondary,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
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
