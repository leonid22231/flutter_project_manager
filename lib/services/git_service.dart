import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/git_graph_layout.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/models/git_commit_entry.dart';
import 'package:project_manager/models/git_file_change.dart';
import 'package:project_manager/models/git_productivity.dart';
import 'package:project_manager/models/git_repository_status.dart';

GitFileChange? parseGitPorcelainLine(String line) {
  if (line.isEmpty) return null;

  if (line.startsWith('??')) {
    final path = line.length > 3 ? line.substring(3) : '';
    if (path.isEmpty) return null;
    return GitFileChange(
      path: path,
      kind: GitChangeKind.untracked,
      unstaged: true,
    );
  }

  if (line.length < 4) return null;

  final indexStatus = line[0];
  final workTreeStatus = line[1];
  var pathPart = line.substring(3).trim();
  if (pathPart.isEmpty) return null;

  String? oldPath;
  if (pathPart.contains(' -> ')) {
    final parts = pathPart.split(' -> ');
    oldPath = parts.first;
    pathPart = parts.last;
  }

  final staged = indexStatus != ' ' && indexStatus != '?';
  final unstaged = workTreeStatus != ' ' && workTreeStatus != '?';

  if (indexStatus == '!' || workTreeStatus == '!') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.ignored,
      oldPath: oldPath,
      staged: staged,
      unstaged: unstaged,
    );
  }

  if (indexStatus == 'U' ||
      workTreeStatus == 'U' ||
      indexStatus == 'A' && workTreeStatus == 'A') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.conflicted,
      oldPath: oldPath,
      staged: staged,
      unstaged: unstaged,
    );
  }

  if (indexStatus == 'R' || workTreeStatus == 'R') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.renamed,
      oldPath: oldPath,
      staged: staged,
      unstaged: unstaged,
    );
  }

  if (indexStatus == 'C' || workTreeStatus == 'C') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.copied,
      oldPath: oldPath,
      staged: staged,
      unstaged: unstaged,
    );
  }

  if (indexStatus == 'D' || workTreeStatus == 'D') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.deleted,
      oldPath: oldPath,
      staged: staged,
      unstaged: unstaged,
    );
  }

  if (indexStatus == 'A') {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.added,
      oldPath: oldPath,
      staged: true,
      unstaged: unstaged,
    );
  }

  if (staged && unstaged) {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.stagedModified,
      oldPath: oldPath,
      staged: true,
      unstaged: true,
    );
  }

  if (staged) {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.staged,
      oldPath: oldPath,
      staged: true,
    );
  }

  if (unstaged) {
    return GitFileChange(
      path: pathPart,
      kind: GitChangeKind.modified,
      oldPath: oldPath,
      unstaged: true,
    );
  }

  return null;
}

List<GitFileChange> parseGitPorcelainOutput(String output) {
  final changes = <GitFileChange>[];
  for (final rawLine in output.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty) continue;
    final change = parseGitPorcelainLine(line);
    if (change != null) {
      changes.add(change);
    }
  }
  changes.sort((a, b) => a.path.compareTo(b.path));
  return changes;
}

class GitLabRemoteInfo {
  const GitLabRemoteInfo({
    required this.host,
    required this.projectPath,
    required this.webUrl,
  });

  final String host;
  final String projectPath;
  final String webUrl;
}

GitLabRemoteInfo? parseGitLabRemote(
  String? remoteUrl, {
  String? configuredGitLabBaseUrl,
}) {
  final parsed = parseGitRemoteUrl(remoteUrl);
  if (parsed == null) return null;

  final configuredHost = _hostFromBaseUrl(configuredGitLabBaseUrl);
  final remoteHost = parsed.host.toLowerCase();
  final isGitLab = _looksLikeGitLabHost(parsed.host) ||
      (configuredHost != null && remoteHost == configuredHost);

  if (!isGitLab) return null;

  return GitLabRemoteInfo(
    host: parsed.host,
    projectPath: parsed.projectPath,
    webUrl: parsed.webUrl,
  );
}

class ParsedGitRemote {
  const ParsedGitRemote({
    required this.host,
    required this.projectPath,
    required this.webUrl,
  });

  final String host;
  final String projectPath;
  final String webUrl;
}

ParsedGitRemote? parseGitRemoteUrl(String? remoteUrl) {
  if (remoteUrl == null || remoteUrl.trim().isEmpty) return null;
  final url = remoteUrl.trim();

  final sshMatch = RegExp(
    r'^git@([^:]+):(.+?)(?:\.git)?$',
  ).firstMatch(url);
  if (sshMatch != null) {
    final host = sshMatch.group(1)!;
    final projectPath = sshMatch.group(2)!.replaceAll(r'\', '/');
    return ParsedGitRemote(
      host: host,
      projectPath: projectPath,
      webUrl: 'https://$host/$projectPath',
    );
  }

  final httpsMatch = RegExp(
    r'^(https?://[^/]+)/(.+?)(?:\.git)?/?$',
  ).firstMatch(url);
  if (httpsMatch != null) {
    final baseUrl = httpsMatch.group(1)!;
    final host = Uri.parse(baseUrl).host;
    final projectPath = httpsMatch.group(2)!.replaceAll(r'\', '/');
    return ParsedGitRemote(
      host: host,
      projectPath: projectPath,
      webUrl: '$baseUrl/$projectPath',
    );
  }

  return null;
}

String? _hostFromBaseUrl(String? baseUrl) {
  if (baseUrl == null || baseUrl.trim().isEmpty) return null;
  return Uri.tryParse(baseUrl.trim())?.host.toLowerCase();
}

bool _looksLikeGitLabHost(String host) {
  final lower = host.toLowerCase();
  return lower.contains('gitlab');
}

const commitFieldSep = '\x1f';
const commitRecordSep = '\x1e';

const _commitFieldSep = commitFieldSep;
const _commitRecordSep = commitRecordSep;

String _gitLogGraphFormat() =>
    '%H$_commitFieldSep%P$_commitFieldSep%h$_commitFieldSep%an$_commitFieldSep%ae$_commitFieldSep%ad$_commitFieldSep%d$_commitFieldSep%s$_commitRecordSep';

List<GitCommitEntry> parseGitLogOutput(String output) {
  final commits = <GitCommitEntry>[];
  for (final record in output.split(_commitRecordSep)) {
    final trimmed = record.trim();
    if (trimmed.isEmpty) continue;

    final fields = trimmed.split(_commitFieldSep);
    if (fields.length < 6) continue;

    commits.add(
      GitCommitEntry(
        hash: fields[0],
        shortHash: fields[1],
        author: fields[2],
        email: fields[3],
        committedAt: DateTime.tryParse(fields[4]),
        subject: fields[5],
      ),
    );
  }
  return commits;
}

String _gitPath(String relativePath) => relativePath.replaceAll(r'\', '/');

String _gitOutput(Object? output) {
  if (output == null) return '';
  if (output is String) return output;
  if (output is List<int>) {
    return utf8.decode(output, allowMalformed: true);
  }
  return output.toString();
}

class GitService {
  Future<bool> isGitAvailable() async {
    final result = await _runGit(const ['--version']);
    return result.exitCode == 0;
  }

  Future<GitRepositoryStatus> getRepositoryStatus(
    String projectPath, {
    String? configuredGitLabBaseUrl,
  }) async {
    final checkedAt = DateTime.now();
    final gitDir = Directory(p.join(projectPath, '.git'));
    if (!gitDir.existsSync()) {
      return GitRepositoryStatus.notRepository();
    }

    final inside = await _runGit(
      const ['rev-parse', '--is-inside-work-tree'],
      workingDirectory: projectPath,
    );
    if (inside.exitCode != 0 ||
        _gitOutput(inside.stdout).trim().toLowerCase() != 'true') {
      return GitRepositoryStatus.notRepository(
        error: _extractError(inside),
      );
    }

    try {
      final branch = await _readSingleLine(
        ['branch', '--show-current'],
        projectPath,
      );
      final remoteUrl = await _readSingleLine(
        ['remote', 'get-url', 'origin'],
        projectPath,
        allowFailure: true,
      );
      final upstreamBranch = await _readSingleLine(
        ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
        projectPath,
        allowFailure: true,
      );

      int? ahead;
      int? behind;
      if (upstreamBranch != null && upstreamBranch.isNotEmpty) {
        final counts = await _runGit(
          ['rev-list', '--left-right', '--count', 'HEAD...@{u}'],
          workingDirectory: projectPath,
        );
        if (counts.exitCode == 0) {
          final parts = _gitOutput(counts.stdout).trim().split(RegExp(r'\s+'));
          if (parts.length == 2) {
            ahead = int.tryParse(parts[0]);
            behind = int.tryParse(parts[1]);
          }
        }
      }

      final status = await _runGit(
        const ['status', '--porcelain=v1', '-u'],
        workingDirectory: projectPath,
      );
      if (status.exitCode != 0) {
        return GitRepositoryStatus.error(_extractError(status));
      }

      final changes = parseGitPorcelainOutput(_gitOutput(status.stdout));
      final gitlab = parseGitLabRemote(
        remoteUrl,
        configuredGitLabBaseUrl: configuredGitLabBaseUrl,
      );

      return GitRepositoryStatus(
        isRepository: true,
        branch: branch?.isEmpty == true ? null : branch,
        upstreamBranch: upstreamBranch,
        ahead: ahead,
        behind: behind,
        remoteUrl: remoteUrl,
        isGitLabRemote: gitlab != null,
        gitlabHost: gitlab?.host,
        gitlabProjectPath: gitlab?.projectPath,
        gitlabWebUrl: gitlab?.webUrl,
        changes: changes,
        checkedAt: checkedAt,
      );
    } catch (e) {
      return GitRepositoryStatus.error('$e');
    }
  }

  Future<List<GitCommitEntry>> getFileHistory(
    String projectPath,
    String relativePath, {
    int limit = 50,
  }) async {
    final gitPath = _gitPath(relativePath);
    final result = await _runGit(
      [
        'log',
        '--follow',
        '--date=iso-strict',
        '-n',
        '$limit',
        '--pretty=format:%H$_commitFieldSep%h$_commitFieldSep%an$_commitFieldSep%ae$_commitFieldSep%ad$_commitFieldSep%s$_commitRecordSep',
        '--',
        gitPath,
      ],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      throw Exception(_extractError(result));
    }

    return parseGitLogOutput(_gitOutput(result.stdout));
  }

  Future<List<GitCommitEntry>> getLineHistory(
    String projectPath,
    String relativePath,
    int line, {
    int limit = 30,
  }) async {
    if (line <= 0) return [];

    final gitPath = _gitPath(relativePath);
    final result = await _runGit(
      [
        'log',
        '-L',
        '$line,$line:$gitPath',
        '--date=iso-strict',
        '-n',
        '$limit',
        '--pretty=format:%H$_commitFieldSep%h$_commitFieldSep%an$_commitFieldSep%ae$_commitFieldSep%ad$_commitFieldSep%s$_commitRecordSep',
      ],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      throw Exception(_extractError(result));
    }

    return parseGitLogOutput(_gitOutput(result.stdout));
  }

  Future<GitProductivity> getProductivity(String projectPath) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: GitProductivity.windowDays));
    final sinceArg =
        '${since.year.toString().padLeft(4, '0')}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    final result = await _runGit(
      [
        'log',
        '--all',
        '--date=short',
        '--since=$sinceArg',
        '--numstat',
        '--pretty=format:%x1e%an%x1f%ae%x1f%ad%x1f%h%x1f%s',
      ],
      workingDirectory: projectPath,
    );
    if (result.exitCode != 0) {
      throw Exception(_extractError(result));
    }
    return parseGitProductivity(
      _gitOutput(result.stdout),
      since: since,
      now: now,
    );
  }

  Future<List<GitCommitGraphRow>> getProjectCommitGraph(
    String projectPath, {
    int limit = 80,
  }) async {
    final result = await _runGit(
      [
        'log',
        '--all',
        '--date-order',
        '--date=iso-strict',
        '-n',
        '$limit',
        '--pretty=format:${_gitLogGraphFormat()}',
      ],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      throw Exception(_extractError(result));
    }

    final entries = parseGitLogGraphOutput(_gitOutput(result.stdout));
    return layoutGitCommitGraph(entries);
  }

  Future<List<GitCommitGraphRow>> getFileCommitGraph(
    String projectPath,
    String relativePath, {
    int limit = 50,
  }) async {
    final gitPath = _gitPath(relativePath);
    final result = await _runGit(
      [
        'log',
        '--follow',
        '--date-order',
        '--date=iso-strict',
        '-n',
        '$limit',
        '--pretty=format:${_gitLogGraphFormat()}',
        '--',
        gitPath,
      ],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      throw Exception(_extractError(result));
    }

    final entries = parseGitLogGraphOutput(_gitOutput(result.stdout));
    return layoutGitCommitGraph(entries);
  }

  Future<String?> _readSingleLine(
    List<String> args,
    String workingDirectory, {
    bool allowFailure = false,
  }) async {
    final result = await _runGit(args, workingDirectory: workingDirectory);
    if (result.exitCode != 0) {
      if (allowFailure) return null;
      throw Exception(_extractError(result));
    }
    final value = _gitOutput(result.stdout).trim();
    return value.isEmpty ? null : value;
  }

  Future<ProcessResult> _runGit(
    List<String> args, {
    String? workingDirectory,
  }) async {
    final fullArgs = [
      '-c',
      'i18n.logOutputEncoding=UTF-8',
      '-c',
      'core.quotepath=false',
      ...args,
    ];

    try {
      return Process.run(
        'git',
        fullArgs,
        workingDirectory: workingDirectory,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } catch (e) {
      return ProcessResult(
        1,
        1,
        '',
        'Git is not available: $e',
      );
    }
  }

  String _extractError(ProcessResult result) {
    final stderr = _gitOutput(result.stderr).trim();
    final stdout = _gitOutput(result.stdout).trim();
    if (stderr.isNotEmpty) return stderr;
    if (stdout.isNotEmpty) return stdout;
    return 'Git command failed (exit ${result.exitCode}).';
  }
}
