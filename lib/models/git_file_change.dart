enum GitChangeKind {
  untracked,
  modified,
  staged,
  stagedModified,
  added,
  deleted,
  renamed,
  copied,
  conflicted,
  ignored,
}

class GitFileChange {
  const GitFileChange({
    required this.path,
    required this.kind,
    this.oldPath,
    this.staged = false,
    this.unstaged = false,
  });

  final String path;
  final String? oldPath;
  final GitChangeKind kind;
  final bool staged;
  final bool unstaged;

  bool get isUntracked => kind == GitChangeKind.untracked;

  bool get hasStagedChanges =>
      staged ||
      kind == GitChangeKind.staged ||
      kind == GitChangeKind.stagedModified ||
      kind == GitChangeKind.added;

  bool get hasUnstagedChanges =>
      unstaged ||
      kind == GitChangeKind.modified ||
      kind == GitChangeKind.untracked ||
      kind == GitChangeKind.stagedModified ||
      kind == GitChangeKind.deleted;
}
