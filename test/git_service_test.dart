import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/models/git_commit_entry.dart';
import 'package:project_manager/models/git_file_change.dart';
import 'package:project_manager/services/git_service.dart';

void main() {  test('parseGitPorcelainLine handles common statuses', () {
    final modified = parseGitPorcelainLine(' M lib/main.dart');
    expect(modified?.kind, GitChangeKind.modified);
    expect(modified?.path, 'lib/main.dart');

    final staged = parseGitPorcelainLine('M  README.md');
    expect(staged?.kind, GitChangeKind.staged);

    final untracked = parseGitPorcelainLine('?? new_file.dart');
    expect(untracked?.kind, GitChangeKind.untracked);

    final renamed = parseGitPorcelainLine('R  old.dart -> new.dart');
    expect(renamed?.kind, GitChangeKind.renamed);
    expect(renamed?.oldPath, 'old.dart');
    expect(renamed?.path, 'new.dart');
  });

  test('parseGitLabRemote detects https and ssh urls', () {
    final https = parseGitLabRemote('https://gitlab.com/group/project.git');
    expect(https?.host, 'gitlab.com');
    expect(https?.projectPath, 'group/project');

    final ssh = parseGitLabRemote('git@gitlab.example.com:team/app.git');
    expect(ssh?.host, 'gitlab.example.com');
    expect(ssh?.projectPath, 'team/app');
  });

  test('parseGitLabRemote uses configured GitLab host', () {
    final remote = parseGitLabRemote(
      'https://git.company.com/apps/kiosk.git',
      configuredGitLabBaseUrl: 'https://git.company.com',
    );

    expect(remote?.host, 'git.company.com');
    expect(remote?.projectPath, 'apps/kiosk');
  });

  test('parseGitLogOutput parses formatted commit records', () {
    const sep = '\x1e';
    const field = '\x1f';
    final output =
        'abc123${field}abc123${field}Alice${field}alice@example.com${field}2024-01-15T10:30:00Z${field}Fix widget scanner$sep'
        'def456${field}def456${field}Bob${field}bob@example.com${field}invalid${field}Add tests$sep';

    final commits = parseGitLogOutput(output);

    expect(commits, hasLength(2));
    expect(commits[0], isA<GitCommitEntry>());
    expect(commits[0].hash, 'abc123');
    expect(commits[0].shortHash, 'abc123');
    expect(commits[0].author, 'Alice');
    expect(commits[0].email, 'alice@example.com');
    expect(commits[0].committedAt, DateTime.parse('2024-01-15T10:30:00Z'));
    expect(commits[0].subject, 'Fix widget scanner');
    expect(commits[1].hash, 'def456');
    expect(commits[1].committedAt, isNull);
    expect(commits[1].subject, 'Add tests');
  });
}