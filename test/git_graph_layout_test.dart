import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/git_graph_layout.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/services/git_service.dart';

void main() {
  test('parseGitLogGraphOutput parses parents and decorations', () {
    final output =
        'abc${commitFieldSep}def123${commitFieldSep}abc${commitFieldSep}Alice${commitFieldSep}alice@example.com${commitFieldSep}2024-01-15T10:30:00Z${commitFieldSep} (main)${commitFieldSep}Initial commit${commitRecordSep}'
        'def${commitFieldSep}${commitFieldSep}def${commitFieldSep}Bob${commitFieldSep}bob@example.com${commitFieldSep}2024-01-14T09:00:00Z${commitFieldSep}${commitFieldSep}Root commit$commitRecordSep';

    final entries = parseGitLogGraphOutput(output);

    expect(entries, hasLength(2));
    expect(entries[0].hash, 'abc');
    expect(entries[0].parents, ['def123']);
    expect(entries[0].decorationsLabel, 'main');
    expect(entries[0].subject, 'Initial commit');
    expect(entries[1].parents, isEmpty);
    expect(entries[1].decorations, isNull);
  });

  test('layoutGitCommitGraph assigns lanes for linear history', () {
    final rows = layoutGitCommitGraph([
      const GitCommitGraphEntry(
        hash: 'c2',
        parents: ['c1'],
        shortHash: 'c2',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Second',
      ),
      const GitCommitGraphEntry(
        hash: 'c1',
        parents: [],
        shortHash: 'c1',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'First',
      ),
    ]);

    expect(rows, hasLength(2));
    expect(rows[0].lane, 0);
    expect(rows[0].parentLanes, [0]);
    expect(rows[1].lane, 0);
    expect(rows[1].parentLanes, isEmpty);
  });

  test('layoutGitCommitGraph handles merge commit', () {
    final rows = layoutGitCommitGraph([
      const GitCommitGraphEntry(
        hash: 'merge',
        parents: ['main', 'feature'],
        shortHash: 'merge',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Merge branch',
      ),
      const GitCommitGraphEntry(
        hash: 'main',
        parents: [],
        shortHash: 'main',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Main',
      ),
    ]);

    expect(rows[0].parentLanes, hasLength(2));
    expect(rows[0].laneCount, greaterThanOrEqualTo(2));
  });

  test('buildGitCommitTree groups parents under tips', () {
    final roots = buildGitCommitTree([
      const GitCommitGraphEntry(
        hash: 'c2',
        parents: ['c1'],
        shortHash: 'c2',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Second',
      ),
      const GitCommitGraphEntry(
        hash: 'c1',
        parents: [],
        shortHash: 'c1',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'First',
      ),
    ]);

    expect(roots, hasLength(1));
    expect(roots.first.entry.hash, 'c2');
    expect(roots.first.parentNodes, hasLength(1));
    expect(roots.first.parentNodes.first.entry.hash, 'c1');
  });

  test('flattenGitCommitTree respects expanded nodes', () {
    final roots = buildGitCommitTree([
      const GitCommitGraphEntry(
        hash: 'c2',
        parents: ['c1'],
        shortHash: 'c2',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Second',
      ),
      const GitCommitGraphEntry(
        hash: 'c1',
        parents: [],
        shortHash: 'c1',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'First',
      ),
    ]);

    final collapsed = flattenGitCommitTree(roots, {});
    expect(collapsed, hasLength(1));

    final expanded = flattenGitCommitTree(roots, {'c2'});
    expect(expanded, hasLength(2));
    expect(expanded.last.depth, 1);
  });

  test('flattenGitCommitTree deduplicates shared parents across tips', () {
    final roots = buildGitCommitTree([
      const GitCommitGraphEntry(
        hash: 'tip-a',
        parents: ['shared'],
        shortHash: 'tip-a',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Tip A',
      ),
      const GitCommitGraphEntry(
        hash: 'tip-b',
        parents: ['shared'],
        shortHash: 'tip-b',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Tip B',
      ),
      const GitCommitGraphEntry(
        hash: 'shared',
        parents: [],
        shortHash: 'shared',
        author: 'Alice',
        email: 'a@example.com',
        subject: 'Shared root',
      ),
    ]);

    final expanded = collectGitCommitTreeHashes(roots);
    final rows = flattenGitCommitTree(roots, expanded);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.entry.hash).toSet(), {'tip-a', 'tip-b', 'shared'});
  });
}
