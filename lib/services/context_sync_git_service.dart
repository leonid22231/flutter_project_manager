import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ContextSyncGitResult {
  const ContextSyncGitResult({
    required this.ok,
    this.stdout = '',
    this.stderr = '',
    this.error,
  });

  final bool ok;
  final String stdout;
  final String stderr;
  final String? error;

  String get message {
    if (error != null && error!.isNotEmpty) return error!;
    if (stderr.trim().isNotEmpty) return stderr.trim();
    return stdout.trim();
  }
}

/// System-git clone/pull/commit/push for the shared context-sync repository.
class ContextSyncGitService {
  ContextSyncGitService({
    this.cloneDirName = 'context_sync_repo',
  });

  static const _storageDirName = 'project_manager';
  static const _defaultBranch = 'main';

  final String cloneDirName;

  Future<void>? _lock;

  Future<T> _withLock<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock;
      } catch (_) {}
    }
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_lock, completer.future)) {
        _lock = null;
      }
    }
  }

  Future<Directory> getCloneDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, _storageDirName, cloneDirName));
  }

  String contextFolderPath(Directory cloneDir, String contextId) =>
      p.join(cloneDir.path, contextId);

  Future<ContextSyncGitResult> testRemote(String repoUrl) async {
    final url = repoUrl.trim();
    if (url.isEmpty) {
      return const ContextSyncGitResult(
        ok: false,
        error: 'Repository URL is empty',
      );
    }
    final result = await _runGit(
      ['ls-remote', url],
      workingDirectory: Directory.systemTemp.path,
    );
    // Empty repo still "reachable" — ls-remote exits 0 with empty output.
    if (result.ok) return result;
    return result;
  }

  Future<ContextSyncGitResult> commitAndPush({
    required String repoUrl,
    required String message,
  }) {
    return _withLock(() async {
      final cloneDir = await getCloneDirectory();
      if (!Directory(p.join(cloneDir.path, '.git')).existsSync()) {
        final cloned = await _ensureCloneUnlocked(repoUrl);
        if (!cloned.ok) return cloned;
      }

      await _ensureLocalBranch(cloneDir.path);

      final status = await _runGit(
        ['status', '--porcelain'],
        workingDirectory: cloneDir.path,
      );
      if (!status.ok) return status;

      if (status.stdout.trim().isNotEmpty) {
        final add = await _runGit(
          ['add', '-A'],
          workingDirectory: cloneDir.path,
        );
        if (!add.ok) return add;

        final commit = await _runGit(
          ['commit', '-m', message],
          workingDirectory: cloneDir.path,
        );
        if (!commit.ok) return commit;
      }

      return _pushCurrentBranch(cloneDir.path);
    });
  }

  Future<ContextSyncGitResult> ensureClone(String repoUrl) {
    return _withLock(() => _ensureCloneUnlocked(repoUrl));
  }

  Future<ContextSyncGitResult> pull(String repoUrl) => ensureClone(repoUrl);

  Future<ContextSyncGitResult> _ensureCloneUnlocked(String repoUrl) async {
    final url = repoUrl.trim();
    if (url.isEmpty) {
      return const ContextSyncGitResult(
        ok: false,
        error: 'Repository URL is empty',
      );
    }

    final cloneDir = await getCloneDirectory();
    final gitDir = Directory(p.join(cloneDir.path, '.git'));

    final remoteInfo = await _inspectRemote(url);
    if (!remoteInfo.reachable) {
      return ContextSyncGitResult(
        ok: false,
        error: remoteInfo.error ?? 'Remote is not reachable',
      );
    }

    if (!gitDir.existsSync()) {
      if (cloneDir.existsSync()) {
        cloneDir.deleteSync(recursive: true);
      }
      cloneDir.parent.createSync(recursive: true);

      if (remoteInfo.isEmpty) {
        return _initEmptyRepo(cloneDir, url);
      }

      final clone = await _runGit(
        ['clone', url, cloneDir.path],
        workingDirectory: cloneDir.parent.path,
      );
      if (!clone.ok) {
        // Empty remotes sometimes fail clone on older git — fall back to init.
        if (_looksLikeEmptyRemoteError(clone.message)) {
          return _initEmptyRepo(cloneDir, url);
        }
        return clone;
      }
      return const ContextSyncGitResult(ok: true);
    }

    final setUrl = await _runGit(
      ['remote', 'set-url', 'origin', url],
      workingDirectory: cloneDir.path,
    );
    if (!setUrl.ok) return setUrl;

    final fetch = await _runGit(
      ['fetch', 'origin'],
      workingDirectory: cloneDir.path,
    );
    // Empty remote: fetch may warn / fail finding HEAD — treat as OK.
    if (!fetch.ok && !_looksLikeEmptyRemoteError(fetch.message)) {
      return fetch;
    }

    if (remoteInfo.isEmpty) {
      await _ensureLocalBranch(cloneDir.path);
      return const ContextSyncGitResult(
        ok: true,
        stdout: 'Remote repository is empty (ready for first push)',
      );
    }

    final branch = remoteInfo.defaultBranch ?? _defaultBranch;
    await _ensureLocalBranch(cloneDir.path, preferred: branch);

    final pullRebase = await _runGit(
      ['pull', '--rebase', 'origin', branch],
      workingDirectory: cloneDir.path,
    );
    if (pullRebase.ok) return pullRebase;

    if (_looksLikeEmptyRemoteError(pullRebase.message)) {
      return const ContextSyncGitResult(ok: true);
    }

    final pull = await _runGit(
      ['pull', 'origin', branch],
      workingDirectory: cloneDir.path,
    );
    if (pull.ok || _looksLikeEmptyRemoteError(pull.message)) {
      return const ContextSyncGitResult(ok: true);
    }
    return pull;
  }

  Future<ContextSyncGitResult> _initEmptyRepo(
    Directory cloneDir,
    String url,
  ) async {
    if (cloneDir.existsSync()) {
      cloneDir.deleteSync(recursive: true);
    }
    cloneDir.createSync(recursive: true);

    final init = await _runGit(
      ['init', '-b', _defaultBranch],
      workingDirectory: cloneDir.path,
    );
    if (!init.ok) {
      // Older git without -b
      final initOld = await _runGit(
        ['init'],
        workingDirectory: cloneDir.path,
      );
      if (!initOld.ok) return initOld;
      await _runGit(
        ['checkout', '-B', _defaultBranch],
        workingDirectory: cloneDir.path,
      );
    }

    final remote = await _runGit(
      ['remote', 'add', 'origin', url],
      workingDirectory: cloneDir.path,
    );
    if (!remote.ok) return remote;

    return const ContextSyncGitResult(ok: true);
  }

  Future<void> _ensureLocalBranch(
    String repoPath, {
    String preferred = _defaultBranch,
  }) async {
    final head = await _runGit(
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: repoPath,
    );
    if (head.ok &&
        head.stdout.trim().isNotEmpty &&
        head.stdout.trim() != 'HEAD') {
      return;
    }
    await _runGit(
      ['checkout', '-B', preferred],
      workingDirectory: repoPath,
    );
  }

  Future<ContextSyncGitResult> _pushCurrentBranch(String repoPath) async {
    final branchResult = await _runGit(
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: repoPath,
    );
    final branch = branchResult.ok &&
            branchResult.stdout.trim().isNotEmpty &&
            branchResult.stdout.trim() != 'HEAD'
        ? branchResult.stdout.trim()
        : _defaultBranch;

    final push = await _runGit(
      ['push', '-u', 'origin', 'HEAD:$branch'],
      workingDirectory: repoPath,
    );
    if (push.ok) return push;

    // Fallback without explicit refspec
    return _runGit(
      ['push', '-u', 'origin', branch],
      workingDirectory: repoPath,
    );
  }

  Future<_RemoteInfo> _inspectRemote(String url) async {
    final heads = await _runGit(
      ['ls-remote', '--heads', url],
      workingDirectory: Directory.systemTemp.path,
    );
    if (!heads.ok) {
      // Try plain ls-remote (also shows HEAD for non-empty repos)
      final any = await _runGit(
        ['ls-remote', url],
        workingDirectory: Directory.systemTemp.path,
      );
      if (!any.ok) {
        return _RemoteInfo(
          reachable: false,
          isEmpty: false,
          error: any.message,
        );
      }
      if (any.stdout.trim().isEmpty) {
        return const _RemoteInfo(reachable: true, isEmpty: true);
      }
      return _RemoteInfo(
        reachable: true,
        isEmpty: false,
        defaultBranch: _parseDefaultBranch(any.stdout),
      );
    }

    if (heads.stdout.trim().isEmpty) {
      return const _RemoteInfo(reachable: true, isEmpty: true);
    }

    return _RemoteInfo(
      reachable: true,
      isEmpty: false,
      defaultBranch: _parseDefaultBranch(heads.stdout) ?? _defaultBranch,
    );
  }

  String? _parseDefaultBranch(String lsRemoteOutput) {
    for (final line in lsRemoteOutput.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.endsWith('\tHEAD') || trimmed.endsWith(' HEAD')) {
        // Usually "hash\tHEAD" — not a branch name. Continue.
        continue;
      }
      final match = RegExp(r'refs/heads/(\S+)').firstMatch(trimmed);
      if (match != null) {
        final name = match.group(1)!;
        if (name == 'main' || name == 'master') return name;
      }
    }
    final first = RegExp(r'refs/heads/(\S+)').firstMatch(lsRemoteOutput);
    return first?.group(1);
  }

  bool _looksLikeEmptyRemoteError(String message) {
    final lower = message.toLowerCase();
    return lower.contains("couldn't find remote ref") ||
        lower.contains('could not find remote ref') ||
        lower.contains('does not appear to be a git repository') ||
        lower.contains('repository is empty') ||
        lower.contains('no remote tracking') ||
        lower.contains('remote ref head') ||
        (lower.contains('fatal:') && lower.contains('head') && lower.contains('remote'));
  }

  Future<ContextSyncGitResult> _runGit(
    List<String> args, {
    required String workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      final ok = result.exitCode == 0;
      return ContextSyncGitResult(
        ok: ok,
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
        error: ok
            ? null
            : (result.stderr?.toString().trim().isNotEmpty == true
                ? result.stderr.toString().trim()
                : 'git ${args.first} failed (exit ${result.exitCode})'),
      );
    } catch (e) {
      return ContextSyncGitResult(
        ok: false,
        error: 'Failed to run git: $e',
      );
    }
  }
}

class _RemoteInfo {
  const _RemoteInfo({
    required this.reachable,
    required this.isEmpty,
    this.defaultBranch,
    this.error,
  });

  final bool reachable;
  final bool isEmpty;
  final String? defaultBranch;
  final String? error;
}
