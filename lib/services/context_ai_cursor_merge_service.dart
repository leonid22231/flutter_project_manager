import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_runner.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/cursor_cli_flight.dart';

/// Merges two `.ai` snapshots via Cursor CLI agent mode, with additive fallback.
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
  }) async {
    final localSnap = Directory(p.join(workRoot.path, 'local'));
    final remoteSnap = Directory(p.join(workRoot.path, 'remote'));
    final merged = Directory(p.join(workRoot.path, 'merged'));

    await _copyTree(localDir, localSnap);
    await _copyTree(remoteDir, remoteSnap);
    if (merged.existsSync()) {
      merged.deleteSync(recursive: true);
    }
    merged.createSync(recursive: true);

    if (!settings.enabled) {
      await _additive.mergeAdditive(
        localDir: localSnap,
        remoteDir: remoteSnap,
        outputDir: merged,
      );
      return merged;
    }

    final prompt = '''
You are merging two versions of a project `.ai` context folder so two devices stay in sync.

Directories:
- local/  — context from this device
- remote/ — context from the shared GitHub sync repository
- merged/ — WRITE the unified result here (create files as needed)

Rules:
1. Preserve all useful information from both sides (memories, knowledge, config, logs metadata, profiles).
2. Prefer additive merges: union JSON keys/arrays by id when present; do not drop entries.
3. For conflicting scalar values, keep the more complete / newer-looking content and note conflicts briefly in merged/MERGE_NOTES.md if needed.
4. Output only under merged/. Mirror the relative file layout of .ai (no nested .ai folder).
5. When done, ensure merged/ contains the full unified context.
''';

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

    final mergedFiles = merged.existsSync()
        ? merged
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => !p.basename(f.path).startsWith('.'))
            .length
        : 0;

    final cursorOk = result != null && !result.failed && mergedFiles > 0;
    if (!cursorOk) {
      if (result == null) {
        _log.info(
          'Cursor merge skipped by flight — additive fallback',
          source: 'context-sync-merge',
        );
      }
      await _additive.mergeAdditive(
        localDir: localSnap,
        remoteDir: remoteSnap,
        outputDir: merged,
      );
    }

    return merged;
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
