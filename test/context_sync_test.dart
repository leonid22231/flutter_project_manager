import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';

void main() {
  group('ContextIdUtils', () {
    test('normalize rejects path separators', () {
      expect(ContextIdUtils.normalize('a/b'), isNull);
      expect(ContextIdUtils.normalize(r'a\b'), isNull);
      expect(ContextIdUtils.normalize(''), isNull);
      expect(ContextIdUtils.normalize('  '), isNull);
      expect(ContextIdUtils.normalize('.'), isNull);
      expect(ContextIdUtils.normalize('..'), isNull);
    });

    test('normalize accepts safe ids', () {
      expect(ContextIdUtils.normalize(' my-project_1 '), 'my-project_1');
      expect(
        ContextIdUtils.normalize('uuid-1234-5678'),
        'uuid-1234-5678',
      );
    });

    test('fromGitLabRemote builds stable slug', () {
      final id = ContextIdUtils.fromGitLabRemote(
        'git@gitlab.com:group/sub/project.git',
      );
      expect(id, 'gitlab.com__group__sub__project');
    });

    test('fromGitLabRemote returns null for GitHub', () {
      expect(
        ContextIdUtils.fromGitLabRemote(
          'git@github.com:org/repo.git',
        ),
        isNull,
      );
    });

    test('resolveForNewProject falls back to uuid', () {
      final id = ContextIdUtils.resolveForNewProject(
        remoteUrl: 'git@github.com:org/repo.git',
      );
      expect(id.contains('-'), isTrue);
      expect(ContextIdUtils.normalize(id), id);
    });
  });

  group('Project.contextId migration', () {
    test('fromJson falls back to id when contextId missing', () {
      final project = Project.fromJson({
        'id': 'abc-123',
        'name': 'Demo',
        'path': '/tmp/demo',
        'addedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(project.contextId, 'abc-123');
    });

    test('toJson includes contextId', () {
      final project = Project(
        id: 'id-1',
        contextId: 'shared-ctx',
        name: 'Demo',
        path: '/tmp/demo',
        addedAt: DateTime(2026, 1, 1),
      );
      expect(project.toJson()['contextId'], 'shared-ctx');
    });
  });

  group('ContextAiMergeService', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('context_merge_test_');
    });

    tearDown(() {
      if (temp.existsSync()) {
        temp.deleteSync(recursive: true);
      }
    });

    test('merges json objects and arrays by id additively', () async {
      final local = Directory('${temp.path}/local')..createSync();
      final remote = Directory('${temp.path}/remote')..createSync();
      final out = Directory('${temp.path}/out');

      File('${local.path}/memories.json').writeAsStringSync(
        jsonEncode({
          'items': [
            {'id': 'a', 'summary': 'local-a'},
            {'id': 'b', 'summary': 'only-local'},
          ],
          'version': 1,
        }),
      );
      File('${remote.path}/memories.json').writeAsStringSync(
        jsonEncode({
          'items': [
            {'id': 'a', 'notes': 'remote-note'},
            {'id': 'c', 'summary': 'only-remote'},
          ],
          'extra': true,
        }),
      );

      await ContextAiMergeService().mergeAdditive(
        localDir: local,
        remoteDir: remote,
        outputDir: out,
      );

      final merged =
          jsonDecode(File('${out.path}/memories.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(merged['extra'], isTrue);
      expect(merged['version'], 1);
      final items = (merged['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 3);
      final a = items.firstWhere((e) => e['id'] == 'a');
      expect(a['summary'], 'local-a');
      expect(a['notes'], 'remote-note');
    });

    test('keeps files present on only one side', () async {
      final local = Directory('${temp.path}/local')..createSync();
      final remote = Directory('${temp.path}/remote')..createSync();
      final out = Directory('${temp.path}/out');

      File('${local.path}/local-only.txt').writeAsStringSync('L');
      File('${remote.path}/remote-only.txt').writeAsStringSync('R');

      await ContextAiMergeService().mergeAdditive(
        localDir: local,
        remoteDir: remote,
        outputDir: out,
      );

      expect(File('${out.path}/local-only.txt').readAsStringSync(), 'L');
      expect(File('${out.path}/remote-only.txt').readAsStringSync(), 'R');
    });
  });
}
