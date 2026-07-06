import 'package:project_manager/models/git_file_change.dart';

class GitRepositoryStatus {
  const GitRepositoryStatus({
    required this.isRepository,
    this.branch,
    this.upstreamBranch,
    this.ahead,
    this.behind,
    this.remoteUrl,
    this.isGitLabRemote = false,
    this.gitlabHost,
    this.gitlabProjectPath,
    this.gitlabWebUrl,
    this.changes = const [],
    this.error,
    required this.checkedAt,
  });

  final bool isRepository;
  final String? branch;
  final String? upstreamBranch;
  final int? ahead;
  final int? behind;
  final String? remoteUrl;
  final bool isGitLabRemote;
  final String? gitlabHost;
  final String? gitlabProjectPath;
  final String? gitlabWebUrl;
  final List<GitFileChange> changes;
  final String? error;
  final DateTime checkedAt;

  bool get isClean => isRepository && error == null && changes.isEmpty;

  bool get hasChanges => changes.isNotEmpty;

  int get stagedCount => changes.where((c) => c.hasStagedChanges).length;

  int get unstagedCount => changes.where((c) => c.hasUnstagedChanges).length;

  int get untrackedCount => changes.where((c) => c.isUntracked).length;

  factory GitRepositoryStatus.notRepository({String? error}) {
    return GitRepositoryStatus(
      isRepository: false,
      error: error,
      checkedAt: DateTime.now(),
    );
  }

  factory GitRepositoryStatus.error(String message) {
    return GitRepositoryStatus(
      isRepository: true,
      error: message,
      checkedAt: DateTime.now(),
    );
  }
}
