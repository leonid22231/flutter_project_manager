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
import 'package:project_manager/services/context_ai_cursor_merge_service.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/context_sync_git_service.dart';

typedef ContextSyncStatusCallback = void Function(ContextSyncStatus status);

/// Orchestrates pull → merge → write local `.ai` → push for a project.
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

  var _syncing = false;

  bool get isSyncing => _syncing;

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
      return ContextSyncStatus(
        phase: ContextSyncPhase.syncing,
        contextId: contextId,
        message: 'Sync already in progress',
      );
    }

    _syncing = true;
    var status = ContextSyncStatus(
      phase: ContextSyncPhase.syncing,
      contextId: contextId,
      message: 'Pulling remote context…',
    );
    onStatus?.call(status);

    try {
      final pull = await _git.pull(syncSettings.repoUrl);
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

      status = status.copyWith(message: 'Merging .ai context…');
      onStatus?.call(status);

      final workRoot = await _createWorkRoot(contextId);
      final localSnap = Directory(p.join(workRoot.path, 'local_src'));
      final remoteSnap = Directory(p.join(workRoot.path, 'remote_src'));
      await _copyTree(localAiDir, localSnap);
      await _copyTree(remoteContextDir, remoteSnap);

      final needsMerge = _treesDiffer(localSnap, remoteSnap);
      Directory mergedDir;

      if (!needsMerge) {
        mergedDir = localSnap;
      } else if (cursorSettings.enabled) {
        mergedDir = await _cursorMerge.merge(
          localDir: localSnap,
          remoteDir: remoteSnap,
          workRoot: workRoot,
          settings: cursorSettings,
        );
      } else {
        mergedDir = Directory(p.join(workRoot.path, 'merged'));
        await _additive.mergeAdditive(
          localDir: localSnap,
          remoteDir: remoteSnap,
          outputDir: mergedDir,
        );
      }

      status = status.copyWith(message: 'Writing local .ai…');
      onStatus?.call(status);

      await _replaceTree(mergedDir, localAiDir);
      await _replaceTree(mergedDir, remoteContextDir);

      status = status.copyWith(message: 'Pushing to remote…');
      onStatus?.call(status);

      final push = await _git.commitAndPush(
        repoUrl: syncSettings.repoUrl,
        message: 'sync: $contextId',
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

      status = ContextSyncStatus(
        phase: ContextSyncPhase.idle,
        contextId: contextId,
        lastSyncedAt: DateTime.now(),
        message: 'Synced',
      );
      onStatus?.call(status);
      return status;
    } catch (e) {
      status = ContextSyncStatus(
        phase: ContextSyncPhase.error,
        contextId: contextId,
        error: '$e',
      );
      onStatus?.call(status);
      return status;
    } finally {
      _syncing = false;
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

  bool _treesDiffer(Directory a, Directory b) {
    final aFiles = _fileMap(a);
    final bFiles = _fileMap(b);
    if (aFiles.length != bFiles.length) return true;
    for (final entry in aFiles.entries) {
      final other = bFiles[entry.key];
      if (other == null) return true;
      if (other != entry.value) return true;
    }
    return false;
  }

  Map<String, String> _fileMap(Directory root) {
    final map = <String, String>{};
    if (!root.existsSync()) return map;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: root.path);
      try {
        map[relative] = entity.readAsStringSync();
      } catch (_) {
        map[relative] = 'bin:${entity.lengthSync()}:${entity.lastModifiedSync().millisecondsSinceEpoch}';
      }
    }
    return map;
  }
}
