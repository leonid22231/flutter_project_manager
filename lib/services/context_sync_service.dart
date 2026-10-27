import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/core/utils/long_path.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/context_ai_cursor_merge_service.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/context_large_file_split.dart';
import 'package:project_manager/services/context_sync_git_service.dart';

typedef ContextSyncStatusCallback = void Function(ContextSyncStatus status);

/// Returns false when the caller wants the sync aborted (e.g. project switched).
typedef ContextSyncShouldContinue = bool Function();

/// Orchestrates pull → diff → (merge → write → push) for a project.
///
/// If local `.ai` already matches the remote context folder, sync still
/// rewrites oversized files in the clone as parts and pushes that commit
/// when the working tree changed. It does not merge or rewrite `.ai`.
///
/// Cursor is used only when the same paths differ on both sides (smart merge).
/// Asymmetric adds use a fast additive merge.
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

  ContextSyncGitService get git => _git;
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
    ContextSyncShouldContinue? shouldContinue,
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

    bool stillActive() => shouldContinue?.call() ?? true;

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
      if (!stillActive()) {
        return _cancelled(contextId, onStatus);
      }

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

      if (!stillActive()) {
        return _cancelled(contextId, onStatus);
      }

      final cloneDir = await _git.getCloneDirectory();
      final remoteContextDir =
          Directory(_git.contextFolderPath(cloneDir, contextId));
      final projectRoot = Directory(project.path);
      if (!projectRoot.existsSync()) {
        status = ContextSyncStatus(
          phase: ContextSyncPhase.error,
          contextId: contextId,
          error: 'Project folder was not found',
        );
        onStatus?.call(status);
        _log.warn(
          'Sync stopped — project folder was not found',
          source: 'context-sync',
          data: {'path': project.path, 'contextId': contextId},
        );
        return status;
      }

      final localAiDir =
          Directory(ProjectContextPaths.contextDir(project.path));

      if (!localAiDir.existsSync()) {
        localAiDir.createSync();
      }

      status = status.copyWith(message: 'Comparing local vs remote…');
      onStatus?.call(status);
      await Future<void>.delayed(Duration.zero);

      final compareStarted = DateTime.now();
      final diff = await _diffTrees(localAiDir, remoteContextDir);
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
        final clean = await _git.isWorkingTreeClean();
        if (!clean) {
          final normalized = await _git.commitSplitIfNeeded(
            repoUrl: syncSettings.repoUrl,
            message: 'sync: $contextId',
          );
          if (!normalized.ok) {
            status = ContextSyncStatus(
              phase: ContextSyncPhase.error,
              contextId: contextId,
              lastSyncedAt: DateTime.now(),
              error: normalized.message,
              message: 'Local .ai matches; push of split files failed',
            );
            onStatus?.call(status);
            return status;
          }
        }
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

      if (!stillActive()) {
        return _cancelled(contextId, onStatus);
      }

      final remoteCatalog = ContextLargeFileSplit.catalog(remoteContextDir);
      final needsJoin = remoteCatalog.virtuals.any(
        (virtual) =>
            diff.onlyRemote.contains(virtual.relative) ||
            diff.changed.contains(virtual.relative),
      );
      if (needsJoin) {
        await ContextLargeFileSplit.joinInPlace(remoteContextDir);
      }

      status = status.copyWith(message: 'Merging .ai context…');
      onStatus?.call(status);

      final mergeStarted = DateTime.now();
      final workRoot = await _createWorkRoot(contextId);
      final localSnap = Directory(p.join(workRoot.path, 'local_src'));
      final remoteSnap = Directory(p.join(workRoot.path, 'remote_src'));
      await _copyTree(localAiDir, localSnap);
      await _copyTree(remoteContextDir, remoteSnap);

      // Cursor only when the same paths differ — smart multi-context merge.
      // Asymmetric adds/removes use fast additive merge.
      final textConflicts =
          diff.changed.where(contextSyncWantsCursorMerge).toList();
      final needsCursor = cursorSettings.enabled && textConflicts.isNotEmpty;
      if (cursorSettings.enabled &&
          diff.changed.isNotEmpty &&
          textConflicts.isEmpty) {
        _log.info(
          'Cursor merge skipped — differing files are images or other binaries',
          source: 'context-sync',
          data: {'changed': diff.changed.length},
        );
      }
      late final Directory mergedDir;
      if (needsCursor) {
        AppLogService.instance.showOverlay();
        _log.info(
          'Starting Cursor merge (conflicting paths)',
          source: 'context-sync',
          data: {'changed': diff.changed.length},
        );
        status = status.copyWith(message: 'Merging via Cursor…');
        onStatus?.call(status);
        mergedDir = await _cursorMerge.merge(
          projectId: project.id,
          localDir: localSnap,
          remoteDir: remoteSnap,
          workRoot: workRoot,
          settings: cursorSettings,
          conflictPaths: textConflicts,
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
          cursorSettings.enabled
              ? 'Additive merge done (no conflicting paths — Cursor skipped)'
              : 'Additive merge done',
          source: 'context-sync',
          data: {
            'ms': DateTime.now().difference(mergeStarted).inMilliseconds,
            'onlyLocal': diff.onlyLocal.length,
            'onlyRemote': diff.onlyRemote.length,
          },
        );
      }

      if (!stillActive()) {
        return _cancelled(contextId, onStatus);
      }

      status = status.copyWith(message: 'Writing merged .ai to disk…');
      onStatus?.call(status);
      _log.info(
        'Writing merged tree to local .ai and remote clone…',
        source: 'context-sync',
        data: {
          'local': localAiDir.path.replaceAll(r'\', '/'),
          'preserveIndex': true,
        },
      );

      await _replaceTree(mergedDir, localAiDir, preserveIgnored: true);
      await _replaceTree(mergedDir, remoteContextDir);

      if (!stillActive()) {
        return _cancelled(contextId, onStatus);
      }

      status = status.copyWith(message: 'Pushing to remote…');
      onStatus?.call(status);
      _log.info('Pushing sync commit…', source: 'context-sync');

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
        message: needsCursor ? 'Synced (Cursor merge)' : 'Synced',
      );
      onStatus?.call(status);
      _log.info(
        'Sync completed',
        source: 'context-sync',
        data: {
          'totalMs': totalMs,
          'contextId': contextId,
          'usedCursor': needsCursor,
        },
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

  ContextSyncStatus _cancelled(
    String contextId,
    ContextSyncStatusCallback? onStatus,
  ) {
    _log.info(
      'Sync cancelled (project switched or superseded)',
      source: 'context-sync',
      data: {'contextId': contextId},
    );
    final status = ContextSyncStatus(
      phase: ContextSyncPhase.idle,
      contextId: contextId,
      message: 'Sync cancelled',
    );
    onStatus?.call(status);
    return status;
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
      deleteTree(dest);
    }
    dest.createSync(recursive: true);
    if (!source.existsSync()) return;

    final files = <(File, String)>[];
    walkFiles(source, (file, relative) => files.add((file, relative)));
    for (final (file, relative) in files) {
      final targetPath = p.join(dest.path, relative);
      ensureParent(targetPath);
      await longFile(targetPath).writeAsBytes(await file.readAsBytes());
    }
  }

  Future<void> _replaceTree(
    Directory source,
    Directory dest, {
    bool preserveIgnored = false,
  }) async {
    final preserved = <String, List<int>>{};
    if (preserveIgnored && dest.existsSync()) {
      walkFiles(dest, (file, relative) {
        if (!_shouldIgnoreRelativePath(relative)) return;
        try {
          preserved[relative] = file.readAsBytesSync();
        } catch (_) {}
      });
    }

    if (dest.existsSync()) {
      deleteTree(dest);
    }
    await _copyTree(source, dest);

    for (final entry in preserved.entries) {
      final out = File(p.join(dest.path, entry.key));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(entry.value, flush: true);
    }
  }

  /// Compares local `.ai` vs remote context folder. Ignores noisy log artifacts.
  ///
  /// Files stored as parts are compared by hash, without unpacking them.
  /// Other binaries are compared by size and modification time.
  Future<_ContextDiff> _diffTrees(Directory local, Directory remote) async {
    final catalog = ContextLargeFileSplit.catalog(remote);
    final localFiles = await _fileMap(local);
    final remoteFiles = await _fileMap(remote, skip: catalog.skip);
    for (final virtual in catalog.virtuals) {
      remoteFiles[virtual.relative] =
          await ContextLargeFileSplit.partsSignature(virtual.manifest);
    }
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

  static const _statOnlyBytes = 256 * 1024;

  Future<Map<String, String>> _fileMap(
    Directory root, {
    Set<String> skip = const {},
  }) async {
    final map = <String, String>{};
    if (!root.existsSync()) return map;
    final large = <String, File>{};
    walkFiles(root, (file, relative) {
      if (skip.contains(relative)) return;
      if (_shouldIgnoreRelativePath(relative)) return;
      try {
        final length = file.lengthSync();
        final mtime = file.lastModifiedSync().millisecondsSinceEpoch;
        if (length >= ContextLargeFileSplit.githubLimitBytes) {
          large[relative] = file;
          return;
        }
        if (length > _statOnlyBytes || _hasBinaryPrefix(file)) {
          map[relative] = 'bin:$length:$mtime';
          return;
        }
        map[relative] = file.readAsStringSync();
      } catch (_) {
        try {
          map[relative] =
              'bin:${file.lengthSync()}:${file.lastModifiedSync().millisecondsSinceEpoch}';
        } catch (_) {}
      }
    });
    for (final entry in large.entries) {
      map[entry.key] = await ContextLargeFileSplit.fileSignature(entry.value);
    }
    return map;
  }

  bool _hasBinaryPrefix(File file) {
    RandomAccessFile? handle;
    try {
      handle = file.openSync();
      final sample = handle.readSync(512);
      return sample.contains(0);
    } catch (_) {
      return true;
    } finally {
      handle?.closeSync();
    }
  }

  /// Local-only / ephemeral files that should not force a sync.
  bool _shouldIgnoreRelativePath(String relative) {
    final normalized = relative.replaceAll(r'\', '/').toLowerCase();
    if (normalized.startsWith('logs/') || normalized == 'logs') return true;
    if (normalized.endsWith('.log')) return true;
    if (normalized == 'history.log' || normalized.endsWith('/history.log')) {
      return true;
    }
    if (normalized == 'progress.log' || normalized.endsWith('/progress.log')) {
      return true;
    }
    if (normalized.contains('cursor-prompt-')) return true;
    if (normalized.startsWith('chat-export-') ||
        normalized.contains('/chat-export-')) {
      return true;
    }
    // Semantic index is local work-in-progress; never let sync wipe it.
    if (normalized == 'index' || normalized.startsWith('index/')) return true;
    if (normalized == 'merge_notes.md') return true;
    if (normalized.contains('/conflicts/')) return true;
    if (normalized.endsWith('.bak')) return true;
    if (normalized.contains('.backup')) return true;
    // Timestamped context.json backups: context.json.1712… / context.json-…
    if (RegExp(r'(^|/)context\.json[\.\-_]\d').hasMatch(normalized)) {
      return true;
    }
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

/// Cursor is for text that can be merged. Pictures and archives stay on the
/// fast additive merge.
bool contextSyncWantsCursorMerge(String relative) {
  final name = p.basename(relative).toLowerCase();
  const extensions = ['.json', '.md', '.txt', '.yaml', '.yml'];
  return extensions.any(name.endsWith);
}
