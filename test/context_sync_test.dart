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

    test('normalize keeps UUID lowercase', () {
      expect(
        ContextIdUtils.normalize('  1A6D08F0-2727-40CC-B342-F49056C5D0FC  '),
        '1a6d08f0-2727-40cc-b342-f49056c5d0fc',
      );
    });

    test('same seed words produce same UUID on every call', () {
      final a = ContextIdUtils.fromSeed('Kiosk Cofix');
      final b = ContextIdUtils.fromSeed('  kiosk   cofix ');
      expect(a, b);
      expect(ContextIdUtils.isUuid(a), isTrue);
      expect(
        ContextIdUtils.normalize('Kiosk Cofix'),
        a,
      );
    });

    test('different seeds produce different UUIDs', () {
      expect(
        ContextIdUtils.fromSeed('alpha'),
        isNot(ContextIdUtils.fromSeed('beta')),
      );
    });

    test('fromGitLabRemote builds deterministic UUID from remote', () {
      final id = ContextIdUtils.fromGitLabRemote(
        'git@gitlab.com:group/sub/project.git',
      );
      expect(id, isNotNull);
      expect(ContextIdUtils.isUuid(id!), isTrue);
      expect(
        id,
        ContextIdUtils.fromSeed('gitlab.com__group__sub__project'),
      );
      expect(
        ContextIdUtils.fromGitLabRemote(
          'git@gitlab.com:group/sub/project.git',
        ),
        id,
      );
    });

    test('legacy slug normalizes to same UUID as fromSeed', () {
      const slug = 'gitlab.evosoft.xyz__reklama_cofix__self-service-kiosk';
      expect(
        ContextIdUtils.normalize(slug),
        ContextIdUtils.fromSeed(slug),
      );
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
      expect(ContextIdUtils.isUuid(id), isTrue);
      expect(ContextIdUtils.normalize(id), id);
    });
  });

  group('Project.contextId migration', () {
    test('fromJson converts legacy slug to deterministic UUID', () {
      const slug = 'gitlab.com__group__project';
      final project = Project.fromJson({
        'id': 'abc-123',
        'contextId': slug,
        'name': 'Demo',
        'path': '/tmp/demo',
        'addedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(project.contextId, ContextIdUtils.fromSeed(slug));
      expect(ContextIdUtils.isUuid(project.contextId), isTrue);
    });

    test('fromJson falls back to id when contextId missing', () {
      final project = Project.fromJson({
        'id': '1a6d08f0-2727-40cc-b342-f49056c5d0fc',
        'name': 'Demo',
        'path': '/tmp/demo',
        'addedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(project.contextId, '1a6d08f0-2727-40cc-b342-f49056c5d0fc');
    });

    test('toJson includes contextId', () {
      final project = Project(
        id: 'id-1',
        contextId: '1a6d08f0-2727-40cc-b342-f49056c5d0fc',
        name: 'Demo',
        path: '/tmp/demo',
        addedAt: DateTime(2026, 1, 1),
      );
      expect(
        project.toJson()['contextId'],
        '1a6d08f0-2727-40cc-b342-f49056c5d0fc',
      );
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
