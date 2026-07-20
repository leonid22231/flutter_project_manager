import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/context_ai_cursor_merge_service.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/context_sync_git_service.dart';

typedef ContextSyncStatusCallback = void Function(ContextSyncStatus status);

/// Orchestrates pull → diff → (merge → write → push) for a project.
///
/// If local `.ai` already matches the remote context folder, sync stops after
/// the diff (no Cursor merge, no write, no push).
class ContextSyncService {
  ContextSyncService({
    ContextSyncGitService? git,
    ContextAiMergeService? additiveMerge,
    ContextAiCursorMergeService? cursorMerge,
  })  : _git = git ?? ContextSyncGitService(),
        _additive = additiveMerge ?? ContextAiMergeService(),
        _cursorMerge = cursorMerge ?? ContextAiCursorMergeService();

  final ContextSyncGitService _git;
  final ContextAiMergeService _additive;
  final ContextAiCursorMergeService _cursorMerge;
  final _log = AppLogService.instance;

  var _syncing = false;
  String? _activeContextId;

  bool get isSyncing => _syncing;

  String? get activeContextId => _activeContextId;

  Future<ContextSyncStatus> syncProject({
    required Project project,
    required ContextSyncSettings syncSettings,
    required CursorCliSettings cursorSettings,
    ContextSyncStatusCallback? onStatus,
  }) async {
    if (!syncSettings.isActive) {
      return const ContextSyncStatus(
        phase: ContextSyncPhase.idle,
        message: 'Context sync is disabled',
      );
    }

    final contextId = ContextIdUtils.normalize(project.contextId);
    if (contextId == null) {
      return const ContextSyncStatus(
        phase: ContextSyncPhase.error,
        error: 'Invalid context ID',
      );
    }

    if (_syncing) {
      _log.info(
        'Sync skipped — already in progress',
        source: 'context-sync',
        data: {
          'requested': contextId,
          'active': _activeContextId,
        },
      );
      return ContextSyncStatus(
        phase: ContextSyncPhase.syncing,
        contextId: _activeContextId ?? contextId,
        message: 'Sync already in progress',
      );
    }

    _syncing = true;
    _activeContextId = contextId;
    final started = DateTime.now();
    var status = ContextSyncStatus(
      phase: ContextSyncPhase.syncing,
      contextId: contextId,
      message: 'Pulling remote context…',
    );
    onStatus?.call(status);
    _log.info(
      'Sync started for $contextId',
      source: 'context-sync',
      data: {
        'repo': syncSettings.repoUrl,
        'cursorMerge': cursorSettings.enabled,
      },
    );

    try {
      final pullStarted = DateTime.now();
      final pull = await _git.pull(syncSettings.repoUrl);
      _log.info(
        'Pull finished',
        source: 'context-sync',
        data: {
          'ok': pull.ok,
          'ms': DateTime.now().difference(pullStarted).inMilliseconds,
          if (!pull.ok) 'error': pull.message,
        },
      );
      if (!pull.ok) {
        status = ContextSyncStatus(
          phase: ContextSyncPhase.error,
          contextId: contextId,
          error: pull.message,
        );
        onStatus?.call(status);
        return status;
      }

      final cloneDir = await _git.getCloneDirectory();
      final remoteContextDir =
          Directory(_git.contextFolderPath(cloneDir, contextId));
      final localAiDir =
          Directory(ProjectContextPaths.contextDir(project.path));

      if (!localAiDir.existsSync()) {
        localAiDir.createSync(recursive: true);
      }

      status = status.copyWith(message: 'Comparing local vs remote…');
      onStatus?.call(status);

      final compareStarted = DateTime.now();
      final diff = _diffTrees(localAiDir, remoteContextDir);
      _log.info(
        diff.isEmpty
            ? 'Context identical — sync not needed'
            : 'Context differs — sync required',
        source: 'context-sync',
        data: {
          'ms': DateTime.now().difference(compareStarted).inMilliseconds,
          'onlyLocal': diff.onlyLocal.length,
          'onlyRemote': diff.onlyRemote.length,
          'changed': diff.changed.length,
          if (diff.onlyLocal.isNotEmpty)
            'onlyLocalSample': diff.onlyLocal.take(5).toList(),
          if (diff.onlyRemote.isNotEmpty)
            'onlyRemoteSample': diff.onlyRemote.take(5).toList(),
          if (diff.changed.isNotEmpty)
            'changedSample': diff.changed.take(5).toList(),
        },
      );

      if (diff.isEmpty) {
        final totalMs = DateTime.now().difference(started).inMilliseconds;
        status = ContextSyncStatus(
          phase: ContextSyncPhase.idle,
          contextId: contextId,
          lastSyncedAt: DateTime.now(),
          message: 'Already in sync',
        );
        onStatus?.call(status);
        _log.info(
          'Sync skipped — no differences',
          source: 'context-sync',
          data: {'totalMs': totalMs, 'contextId': contextId},
        );
        return status;
      }

      status = status.copyWith(message: 'Merging .ai context…');
      onStatus?.call(status);

      final mergeStarted = DateTime.now();
      final workRoot = await _createWorkRoot(contextId);
      final localSnap = Directory(p.join(workRoot.path, 'local_src'));
      final remoteSnap = Directory(p.join(workRoot.path, 'remote_src'));
      await _copyTree(localAiDir, localSnap);
      await _copyTree(remoteContextDir, remoteSnap);

      late final Directory mergedDir;
      if (cursorSettings.enabled) {
        _log.info('Starting Cursor merge…', source: 'context-sync');
        status = status.copyWith(message: 'Merging via Cursor…');
        onStatus?.call(status);
        mergedDir = await _cursorMerge.merge(
          projectId: project.id,
          localDir: localSnap,
          remoteDir: remoteSnap,
          workRoot: workRoot,
          settings: cursorSettings,
        );
        _log.info(
          'Cursor merge done',
          source: 'context-sync',
          data: {
            'ms': DateTime.now().difference(mergeStarted).inMilliseconds,
          },
        );
      } else {
        mergedDir = Directory(p.join(workRoot.path, 'merged'));
        await _additive.mergeAdditive(
          localDir: localSnap,
          remoteDir: remoteSnap,
          outputDir: mergedDir,
        );
        _log.info(
          'Additive merge done',
          source: 'context-sync',
          data: {
            'ms': DateTime.now().difference(mergeStarted).inMilliseconds,
          },
        );
      }

      status = status.copyWith(message: 'Writing local .ai…');
      onStatus?.call(status);

      await _replaceTree(mergedDir, localAiDir);
      await _replaceTree(mergedDir, remoteContextDir);

      status = status.copyWith(message: 'Pushing to remote…');
      onStatus?.call(status);

      final pushStarted = DateTime.now();
      final push = await _git.commitAndPush(
        repoUrl: syncSettings.repoUrl,
        message: 'sync: $contextId',
      );
      _log.info(
        'Push finished',
        source: 'context-sync',
        data: {
          'ok': push.ok,
          'ms': DateTime.now().difference(pushStarted).inMilliseconds,
          if (!push.ok) 'error': push.message,
        },
      );
      if (!push.ok) {
        status = ContextSyncStatus(
          phase: ContextSyncPhase.error,
          contextId: contextId,
          lastSyncedAt: DateTime.now(),
          error: push.message,
          message: 'Local .ai updated; push failed',
        );
        onStatus?.call(status);
        return status;
      }

      final totalMs = DateTime.now().difference(started).inMilliseconds;
      status = ContextSyncStatus(
        phase: ContextSyncPhase.idle,
        contextId: contextId,
        lastSyncedAt: DateTime.now(),
        message: 'Synced',
      );
      onStatus?.call(status);
      _log.info(
        'Sync completed',
        source: 'context-sync',
        data: {'totalMs': totalMs, 'contextId': contextId},
      );
      return status;
    } catch (e) {
      _log.error('Sync failed: $e', source: 'context-sync');
      status = ContextSyncStatus(
        phase: ContextSyncPhase.error,
        contextId: contextId,
        error: '$e',
      );
      onStatus?.call(status);
      return status;
    } finally {
      _syncing = false;
      _activeContextId = null;
    }
  }

  Future<Directory> _createWorkRoot(String contextId) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        tmp.path,
        'project_manager_context_sync',
        contextId,
        DateTime.now().millisecondsSinceEpoch.toString(),
      ),
    );
    dir.createSync(recursive: true);
    return dir;
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

  Future<void> _replaceTree(Directory source, Directory dest) async {
    if (dest.existsSync()) {
      dest.deleteSync(recursive: true);
    }
    await _copyTree(source, dest);
  }

  /// Compares local `.ai` vs remote context folder. Ignores noisy log artifacts.
  _ContextDiff _diffTrees(Directory local, Directory remote) {
    final localFiles = _fileMap(local);
    final remoteFiles = _fileMap(remote);
    final onlyLocal = <String>[];
    final onlyRemote = <String>[];
    final changed = <String>[];

    for (final path in localFiles.keys) {
      if (!remoteFiles.containsKey(path)) {
        onlyLocal.add(path);
      } else if (localFiles[path] != remoteFiles[path]) {
        changed.add(path);
      }
    }
    for (final path in remoteFiles.keys) {
      if (!localFiles.containsKey(path)) {
        onlyRemote.add(path);
      }
    }

    return _ContextDiff(
      onlyLocal: onlyLocal,
      onlyRemote: onlyRemote,
      changed: changed,
    );
  }

  Map<String, String> _fileMap(Directory root) {
    final map = <String, String>{};
    if (!root.existsSync()) return map;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: root.path);
      if (_shouldIgnoreRelativePath(relative)) continue;
      try {
        map[relative] = entity.readAsStringSync();
      } catch (_) {
        map[relative] =
            'bin:${entity.lengthSync()}:${entity.lastModifiedSync().millisecondsSinceEpoch}';
      }
    }
    return map;
  }

  /// Local-only / ephemeral files that should not force a sync.
  bool _shouldIgnoreRelativePath(String relative) {
    final normalized = relative.replaceAll(r'\', '/').toLowerCase();
    if (normalized.startsWith('logs/')) return true;
    if (normalized == 'logs') return true;
    if (normalized.endsWith('.log')) return true;
    if (normalized.startsWith('cursor-prompt-')) return true;
    if (normalized.contains('/cursor-prompt-')) return true;
    return false;
  }
}

class _ContextDiff {
  const _ContextDiff({
    required this.onlyLocal,
    required this.onlyRemote,
    required this.changed,
  });

  final List<String> onlyLocal;
  final List<String> onlyRemote;
  final List<String> changed;

  bool get isEmpty =>
      onlyLocal.isEmpty && onlyRemote.isEmpty && changed.isEmpty;
}
