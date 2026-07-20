import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_runner.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/cursor_cli_flight.dart';

/// Merges two `.ai` snapshots via Cursor CLI agent mode, with additive fallback.
///
/// Strategy: additive baseline first (fast, keeps all files), then Cursor
/// refines only [conflictPaths] so multi-device context is merged intelligently
/// without re-deriving the whole tree.
class ContextAiCursorMergeService {
  ContextAiCursorMergeService({
    CursorCliStreamRunner? runner,
    ContextAiMergeService? additiveMerge,
    CursorCliFlight? flight,
  })  : _runner = runner ?? CursorCliStreamRunner(),
        _additive = additiveMerge ?? ContextAiMergeService(),
        _flight = flight ?? CursorCliFlight.instance;

  final CursorCliStreamRunner _runner;
  final ContextAiMergeService _additive;
  final CursorCliFlight _flight;
  final _log = AppLogService.instance;

  Future<Directory> merge({
    required String projectId,
    required Directory localDir,
    required Directory remoteDir,
    required Directory workRoot,
    required CursorCliSettings settings,
    List<String> conflictPaths = const [],
  }) async {
    final localSnap = Directory(p.join(workRoot.path, 'local'));
    final remoteSnap = Directory(p.join(workRoot.path, 'remote'));
    final merged = Directory(p.join(workRoot.path, 'merged'));

    await _copyTree(localDir, localSnap);
    await _copyTree(remoteDir, remoteSnap);

    // Always build a complete additive baseline first.
    await _additive.mergeAdditive(
      localDir: localSnap,
      remoteDir: remoteSnap,
      outputDir: merged,
    );

    if (!settings.enabled) {
      return merged;
    }

    final conflicts = conflictPaths
        .map((e) => e.replaceAll(r'\', '/'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final focusList = conflicts.isEmpty
        ? '(all overlapping files that differ)'
        : conflicts.take(40).map((e) => '- $e').join('\n');

    final prompt = '''
You are merging two versions of a project `.ai` context folder so several devices stay in sync.

Directories:
- local/  — context from this device
- remote/ — context from the shared GitHub sync repository
- merged/ — already contains an additive baseline; REFINE it in place

Priority conflicting paths (same relative path differs on both sides):
$focusList

Rules:
1. Preserve ALL useful information from both sides (memories, knowledge, profiles, config, session summaries). Never drop entries just because one side is newer.
2. Prefer smart unions: for JSON arrays/objects merge by id/key; concatenate unique facts; keep the richer wording when scalars conflict.
3. Rewrite ONLY the conflicting paths listed above under merged/ (create parents as needed). Leave other merged/ files untouched.
4. Do not nest another `.ai` folder. Do not delete unrelated files in merged/.
5. If a conflict cannot be resolved cleanly, keep both variants and briefly note it in merged/MERGE_NOTES.md.
''';

    final beforeCount = _countFiles(merged);

    final result = await _flight.run(
      projectId: projectId,
      job: 'context-sync-merge',
      runner: _runner,
      action: () => _runner.run(
        projectRoot: workRoot.path,
        settings: settings,
        prompt: prompt,
        logSource: 'context-sync-merge',
        maxDuration: const Duration(minutes: 8),
        idleTimeout: const Duration(minutes: 3),
        mode: CursorCliMode.agent,
      ),
    );

    final afterCount = _countFiles(merged);
    final cursorOk = result != null && !result.failed && afterCount > 0;

    if (!cursorOk) {
      if (result == null) {
        _log.info(
          'Cursor merge skipped by flight — keeping additive baseline',
          source: 'context-sync-merge',
        );
      } else if (result.failed) {
        _log.info(
          'Cursor merge failed — keeping additive baseline',
          source: 'context-sync-merge',
          data: {
            'cancelled': result.cancelled,
            'timedOut': result.timedOut || result.idleTimedOut,
            'exitCode': result.exitCode,
          },
        );
      }
      // Baseline already in merged/; nothing else to do.
    } else {
      _log.info(
        'Cursor refined conflicting paths',
        source: 'context-sync-merge',
        data: {
          'conflicts': conflicts.length,
          'filesBefore': beforeCount,
          'filesAfter': afterCount,
        },
      );
    }

    return merged;
  }

  int _countFiles(Directory root) {
    if (!root.existsSync()) return 0;
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !p.basename(f.path).startsWith('.'))
        .length;
  }

  Future<void> _copyTree(Directory source, Directory dest) async {
    if (dest.existsSync()) {
      dest.deleteSync(recursive: true);
    }
    dest.createSync(recursive: true);
    if (!source.existsSync()) return;

    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(dest.path, relative);
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        File(targetPath).parent.createSync(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }
}
